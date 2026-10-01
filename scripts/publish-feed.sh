#!/bin/sh
# Add one build's packages to a checkout of the package feed site.
#
#   scripts/publish-feed.sh OUT_DIR SITE_DIR [KEEP]
#
# OUT_DIR is a src-build.sh output (with feed/ and release); SITE_DIR is the
# working tree that is served by GitHub Pages. The newest KEEP releases
# (default 5) are kept, so firmware that is a few builds old can still
# install kmods matching its kernel.
set -eu

out=${1:?output directory}
site=${2:?site directory}
keep=${3:-5}

die() { echo "error: $*" >&2; exit 1; }

[ -f "$out/release" ] && [ -d "$out/feed" ] || die "$out is not a build output"
release=$(cat "$out/release")
case "$release" in */*|.*|"") die "bad release name '$release'" ;; esac

rm -rf "${site:?}/$release"
mkdir -p "$site/$release"
cp -a "$out/feed/." "$site/$release/"
touch "$site/.nojekyll"

# Newest first; keep the list stable across runs.
list="$site/releases.txt"
{ echo "$release"; [ -f "$list" ] && grep -v -x -F "$release" "$list" || true; } \
	> "$list.new"
mv "$list.new" "$list"

head -n "$keep" "$list" > "$list.keep"
tail -n +"$((keep + 1))" "$list" | while read -r old; do
	[ -n "$old" ] && rm -rf "${site:?}/$old"
done
mv "$list.keep" "$list"

{
	echo '<!doctype html><meta charset="utf-8"><title>SBE1V1K packages</title>'
	echo '<h1>SBE1V1K package feed</h1>'
	echo '<p>Kernel modules and packages built with each firmware release.'
	echo 'Firmware points at its own release directory below.</p><ul>'
	while read -r r; do
		echo "<li><a href=\"$r/\">$r</a></li>"
	done < "$list"
	echo '</ul>'
} > "$site/index.html"

echo "published $release; releases kept: $(wc -l < "$list")"
