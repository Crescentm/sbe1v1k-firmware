#!/bin/sh
# Build the SBE1V1K firmware, all kmods and the package feed from the
# ImmortalWrt source tree. Runs inside the Linux builder.
#
#   SRC=~/owrt/immortalwrt   source tree (cloned, feeds installed)
#   UPDATE=1                 fetch and move to origin/master first
#   JOBS=N                   parallel jobs (default: nproc)
#   STAGE=prepare            stop after patching and configuring
#   FEED_URL=https://...     where this build's packages will be published
#   RELEASE=name             feed directory for this build (default:
#                            <ImmortalWrt version>-<firmware repo commit>)
set -eu

REPO=$(cd "$(dirname "$0")/.." && pwd)
SRC=${SRC:-$HOME/owrt/immortalwrt}
JOBS=${JOBS:-$(nproc)}
STAGE=${STAGE:-all}
OUT=${OUT:-$REPO/out/src-$(date +%Y%m%d-%H%M%S)}

die() { echo "error: $*" >&2; exit 1; }
log() { echo "==> $*"; }

[ -d "$SRC/.git" ] || die "source tree not found at $SRC"
cd "$SRC"

if [ "${UPDATE:-0}" = 1 ]; then
	log "updating source and feeds"
	git fetch -q origin
	git checkout -q -B master origin/master
	./scripts/feeds update -a
	./scripts/feeds install -a
fi

log "resetting tree to $(git rev-parse --short HEAD)"
git reset -q --hard
git clean -q -fd -- target package include scripts config tools toolchain
rm -rf files

log "applying tree patches"
for p in "$REPO"/patches/tree/*.patch; do
	[ -e "$p" ] || continue
	git apply --check "$p" || die "does not apply: $(basename "$p")"
	git apply "$p"
	echo "    $(basename "$p")"
done

# ath12k patches are applied by the mac80211 package build itself.
for p in "$REPO"/patches/mac80211/*.patch; do
	[ -e "$p" ] || continue
	cp "$p" package/kernel/mac80211/patches/ath12k/
	echo "    mac80211/$(basename "$p")"
done

# wifi-scripts installs files-ucode/ straight from the package directory,
# so its fixes are patched into the tree rather than via patches/.
for p in "$REPO"/patches/wifi-scripts/*.patch; do
	[ -e "$p" ] || continue
	patch -p1 -N -F0 -s --no-backup-if-mismatch \
		-d package/network/config/wifi-scripts < "$p" ||
		die "does not apply: wifi-scripts/$(basename "$p")"
	echo "    wifi-scripts/$(basename "$p")"
done

log "staging files/"
mkdir files
cp -a "$REPO/files/." files/
find files \( -name '._*' -o -name .DS_Store \) -delete

log "configuring"
{
	cat "$REPO/config/seed.config"
	grep -v -E '^[[:space:]]*(#|$)' "$REPO/packages.txt" |
		sed 's/^\(.*\)$/CONFIG_PACKAGE_\1=y/'
} > .config
make defconfig >/dev/null

missing=
for p in $(grep -v -E '^[[:space:]]*(#|$)' "$REPO/packages.txt"); do
	grep -q "^CONFIG_PACKAGE_$p=y" .config || missing="$missing $p"
done
[ -z "$missing" ] || die "packages not selected after defconfig:$missing"
grep -q '^CONFIG_TARGET_qualcommbe_ipq95xx_DEVICE_askey_sbe1v1k=y' .config ||
	die "device not selected"
./scripts/diffconfig.sh > "$REPO/config/last.diffconfig"

# The kernel is our own build, so its kmods (and the target packages) must
# come from our feed; everything else may come from ImmortalWrt. Packages we
# built are listed too so the image's libraries resolve to matching builds.
FEED_URL=${FEED_URL:-https://crescentm.github.io/sbe1v1k-packages}
RELEASE=${RELEASE:-$(./scripts/getver.sh)-$(cd "$REPO" &&
	git rev-parse --short HEAD 2>/dev/null || echo local)}
arch=$(sed -n 's/^CONFIG_TARGET_ARCH_PACKAGES="\(.*\)"$/\1/p' .config)
# Only feeds the image itself installs from end up with an index here.
our_feeds="base luci packages"
feeds="base luci packages routing telephony video"
mkdir -p files/etc/apk/repositories.d
{
	echo "# SBE1V1K firmware $RELEASE"
	echo "$FEED_URL/$RELEASE/targets/qualcommbe/ipq95xx/packages/packages.adb"
	for f in $our_feeds; do
		echo "$FEED_URL/$RELEASE/packages/$arch/$f/packages.adb"
	done
	for f in $feeds; do
		echo "https://downloads.immortalwrt.org/snapshots/packages/$arch/$f/packages.adb"
	done
} > files/etc/apk/repositories.d/distfeeds.list
echo "$RELEASE" > files/etc/sbe1v1k-release
log "release $RELEASE, feed $FEED_URL/$RELEASE"

[ "$STAGE" = prepare ] && { log "prepared; stopping"; exit 0; }

log "downloading sources"
make download -j"$JOBS"

log "building with $JOBS jobs"
# Like the buildbots: a package built only for the feed (=m, e.g. from
# ALL_KMODS) may fail without stopping the build; anything in the image (=y)
# may not. Failures are listed in failed-packages.txt. They are not retried
# serially (that rebuilds everything left on one core); rerun with V=s.
log "make output: $SRC/build-make.log"
if ! make -j"$JOBS" IGNORE_ERRORS=m > "$SRC/build-make.log" 2>&1; then
	grep 'ERROR: package' "$SRC/build-make.log" || tail -30 "$SRC/build-make.log"
	die "build failed"
fi

for f in targets/qualcommbe/ipq95xx/packages $(for g in $our_feeds; do
		echo "packages/$arch/$g"; done); do
	[ -f "bin/$f/packages.adb" ] || die "feed bin/$f has no index"
done

mkdir -p "$OUT/feed/targets/qualcommbe/ipq95xx" "$OUT/feed/packages"
for f in bin/targets/qualcommbe/ipq95xx/*; do
	[ "$(basename "$f")" = packages ] || cp -a "$f" "$OUT/"
done
cp -a bin/targets/qualcommbe/ipq95xx/packages \
	"$OUT/feed/targets/qualcommbe/ipq95xx/"
cp -a "bin/packages/$arch" "$OUT/feed/packages/"
echo "$RELEASE" > "$OUT/release"
git rev-parse HEAD > "$OUT/immortalwrt-rev"
grep -o 'ERROR: package/[^ ]* failed to build.*' "$SRC/build-make.log" \
	> "$OUT/failed-packages.txt" || true
(cd "$REPO" && git rev-parse --short HEAD 2>/dev/null || echo uncommitted) \
	> "$OUT/firmware-repo-rev"
log "output: $OUT"
ls "$OUT"
