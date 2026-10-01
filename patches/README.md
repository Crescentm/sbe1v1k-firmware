# Patches

`scripts/src-build.sh` applies everything here to a clean ImmortalWrt tree:

| Directory | Applied how | Contents |
|---|---|---|
| `../overlay/` | copied into the tree as is | new files: qualcommbe kernel patches, mac80211/cfg80211 fixes (`package/kernel/mac80211/patches/subsys/`), hostapd fixes (`package/network/services/hostapd/patches/`), a feed package fix, and a host fakeroot fix for user namespaces |
| `tree/` | `git apply` at the tree root | changes to existing files: sysupgrade on the "large" GPT, DTS fixes, kernel version, hostapd/wifi-scripts backports from OpenWrt main |
| `mac80211/` | copied to `package/kernel/mac80211/patches/ath12k/` | ath12k fixes; 970–989 are the test tier |
| `wifi-scripts/` | `patch -p1` in `package/network/config/wifi-scripts` | radio-by-band mapping, no world `country=00`, 6 GHz security, 0 dBm TX power, OWE transition |

Details for the patches added on 2026-10-01 (rounds 1 and 2):

- [platform.md](platform.md): kernel 6.18.54, PPE/EDMA fixes, IRQ spreading,
  WAN LEDs, lan1 2500base-x and QCA8081 hibernation; round 2: watchdog
  bootstatus, PCIe reset, PPE egress/EEE, upstream phylink/LED/regulator/thermal
  fixes, lan2/lan3 LEDs
- [wifi.md](wifi.md): upstream ath12k fixes, regulatory, WSI device id v3,
  reserved host DDR, board.json and iwinfo per-radio filtering; round 2:
  mac80211/cfg80211 stable and wireless.git fixes, more ath12k fixes, hostapd
  and wifi-scripts fixes, 6 GHz mesh

The notes below record where the first WiFi patches came from and their upstream
status. They were first validated against the ImmortalWrt SDK, then built and
tested on hardware from ImmortalWrt master `bf156b68e3`.

---

## WiFi patches

Target: ImmortalWrt snapshot SDK r41341-f44d1535b4 (qualcommbe/ipq95xx, kernel
6.18.52, mac80211 = backports 7.2, PKG_RELEASE 3). Only packages are rebuilt,
so `kmod-ath12k` keeps the snapshot's kernel vermagic.

Status checked on 2026-10-01 against:

- ImmortalWrt master `bf156b68e3` (2026-09-29). Its last published snapshot is still r41341-f44d1535b4 from 2026-09-18.
- OpenWrt main `43ec1e56b4` (2026-10-01). The OpenWrt snapshot is r36743-c759267c92 from 2026-09-30.

None of the patches below are in either tree, and the snapshots do not differ
on any of them. After f44d1535b4, ImmortalWrt master only adds an rtw88 patch to
mac80211. OpenWrt main has one extra wifi-scripts commit, 2de3225246a (provisioning
regdomain). That commit touches `files/lib/wifi/mac80211.uc`, which none of these
patches modify.

"Applies" means the patch applied with `patch -F0` (no fuzz) during a real
`make package/mac80211/{clean,prepare} V=s` in the SDK, after the full
existing series. For wifi-scripts it means the patch applied with `patch -p1 -F0`
to `feeds/base/network/config/wifi-scripts` at f44d1535b4. The patched `.uc`
files pass a `ucode -c` compile check, and `wiphy_radio()` passed a mock test.

## Provenance of the ath12k patches

Yang Zhengguo first wrote the SBE1V1K multi-radio ath12k set in
[yangzhg/SBE1V1K@6cc06a408d](https://github.com/yangzhg/SBE1V1K/commit/6cc06a408d6d430648118b3e4a32b633675d7b0d)
(2026-08-26, ath12k 105–111, 400 and subsys/100). Jackie264 then refreshed it
in two places:

- [Jackie264/SBE1V1K@b8bbbe7cc9](https://github.com/Jackie264/SBE1V1K/tree/b8bbbe7cc9c8140a8dd53fd1a9d410bc8195bd0c)
  (2026-09-12) added 701. These files were edited on the web: they use space
  indentation and one has a broken line, so they do not apply.
- [OneNAS-space/Askey_Spectrum_SBE1V1K@b6fc7b1f43](https://github.com/OneNAS-space/Askey_Spectrum_SBE1V1K/tree/b6fc7b1f43e7cd6b37373bda8442cb183992e55b)
  (2026-09-30, auto-generated) is rebased on backports 7.2 with correct tabs,
  but has no patch headers.

So I took the patch body from OneNAS, the newest and the only one that applies. I
took the author and description from yangzhg or Jackie264. Each patch header
records both links.

## mac80211 → `feeds/base/kernel/mac80211/patches/ath12k/`

| File | Origin | Fixes | Upstream status | Applies |
|---|---|---|---|---|
| `950-wifi-ath12k-support-CV-upload-direct-buffer-module.patch` | body from OneNAS 105; header from Jackie264 105 (author Rajat Soni, QCA, [ath12k list 2023-10](https://lists.infradead.org/pipermail/ath12k/2023-October/000889.html)); first carried in yangzhg 6cc06a408d | The firmware advertises DMA ring module id 2. The driver rejects it (`Invalid module id 2`), the whole service-ready TLV parse fails (`failed to parse tlv -22`) and the radio never comes up. Part of [#24949](https://github.com/openwrt/openwrt/issues/24949). | Not in OpenWrt or ImmortalWrt. Not in upstream Linux. | yes |
| `951-wifi-ath12k-support-Wi-Fi-radar-direct-buffer-module.patch` | OneNAS 111; header from Jackie264 111 (author Harish Rachakonda, QSDK [0342](https://github.com/Telecominfraproject/wlan-ap/blob/9e5ede4d16ab7f1beac6e052a773c7958e68638e/feeds/qca-wifi-7/mac80211/patches-qca/ath12k/0342-QSDK-CP-add-WMI_CONFIG_MODULE_WIFI_RADAR-to-enum-wmi.patch)) | Same failure for module id 3 (Wi-Fi radar). Part of #24949. Context depends on 950. | Not upstream. QSDK only. | yes |
| `952-wifi-ath12k-limit-WMI-endpoints-to-QMI-PHY-count.patch` | OneNAS 110; header from Jackie264 110 (author Yang Zhengguo) | Single-PHY QCN9274 firmware rejects the WMI_CONTROL_MAC1 connect (`HTC Service WMI MAC1 connect request failed: 0x1`, `WMI CONTROL service status: -71`). The patch clamps `wmi_ep_count` to the QMI `num_radios`. Main fix for #24949. | Not upstream | yes |
| `953-wifi-ath12k-handle-empty-regulatory-events.patch` | OneNAS 106 (2026-09-30 rewrite for 7.2, smaller than yangzhg's); description adapted from yangzhg/Jackie264 106 | An empty regulatory event now completes `regd_update_completed` and keeps the old regdomain. It no longer causes a WARN_ON with `failed to extract regulatory info`. Seen in #24949 logs. | Not upstream | yes |
| ~~`954-wifi-ath12k-use-WSI-index-for-hardware-group-order.patch`~~ (replaced by `920`, the lore v3 version) | OneNAS 108 (yangzhg 108) | `ab->device_id` is set from the DT WSI index instead of probe order, so the radio order inside the wiphy is stable across boots ([#24370](https://github.com/openwrt/openwrt/issues/24370)). Adds bounds and duplicate checks. | Not merged. The same idea is upstream-pending as [OpenWrt PR #25424](https://github.com/openwrt/openwrt/pull/25424) (open), [lore v3](https://lore.kernel.org/linux-wireless/20260928213322.98949-1-yahoo@perenite.com/). Drop this patch when either lands. | yes |
| `955-wifi-ath12k-allocate-QMI-AFC-memory-region.patch` | Re-created from OneNAS 701 / Jackie264 701 (author Jackie Han) | Allocates the QMI target memory segment type 0xA (AFC_REGION_TYPE in QCA downstream) instead of handing the firmware NULL. The original used a bare `case 10:`. This version adds `AFC_REGION_TYPE = 0xa` to `enum ath12k_qmi_target_mem`. | Not upstream | yes |
| `960-wifi-ath12k-set-per-radio-MAC-address-from-DT.patch` | [OpenWrt PR #23786](https://github.com/openwrt/openwrt/pull/23786) head `933c4211b6` (Kenneth Kasilag); body as refreshed in OneNAS 400 | Each radio uses its DT/nvmem `mac-address` and publishes it in `wiphy->addresses[]` ([#23578](https://github.com/openwrt/openwrt/issues/23578)). | PR #23786 is open (last updated 2026-08-23). luckkyboy/SBE1V1K and yintaomu carry the same text. | yes. The PR/luckkyboy version does **not** apply: hunk 3 fails on 7.2 because `kcalloc` became `kzalloc_objs`. Known minor issue: `wiphy->addresses` is not freed in `ath12k_mac_cleanup_iface_combinations()`, a small leak on unload. |

## wifi-scripts → `feeds/base/network/config/wifi-scripts/` (apply with `patch -p1`)

wifi-scripts has no `patches/` mechanism. The Makefile copies `files-ucode/`
straight from the package directory, so these patches must be applied to the
feed tree. Only `files-ucode` is touched, because `CONFIG_WIFI_SCRIPTS_UCODE=y` is
the default.

| File | Origin | Fixes | Upstream status | Applies |
|---|---|---|---|---|
| `950-wifi-scripts-resolve-multi-radio-index-by-band.patch` | [OpenWrt PR #24639](https://github.com/openwrt/openwrt/pull/24639) `a3b3bb572f` (Jose Tejera), with its review findings fixed | After each boot, maps `wireless.radioN.band` to the radio whose `freq_ranges` cover that band ([#24370](https://github.com/openwrt/openwrt/issues/24370)). | PR open. Labelled "unsafe" by its own author, and nbd has rejected band matching before. See below. | yes. The PR alone also applies (offset 2), but it is buggy: it resolves the index after `phy_suffix`/`ifname_prefix` are derived, and it does not keep the null/-1 sentinel. |
| `951-wifi-scripts-never-apply-world-country-00.patch` | Minimal rewrite of [SBE1V1K_immortalwrt_NSS](https://cnb.cool/minihuber/SBE1V1K_immortalwrt_NSS) `32136c496d`. yintaomu instead hard-coded `US` | ImmortalWrt's `mac80211.uc` writes `country='00'` on 6 GHz and enables every interface. The patch stops `iw reg set 00` from resetting the shared regdomain and stops the 6 GHz radio's `00` being copied into every hostapd config (`country_code=00` is rejected). It prefers the radio's own country. | Not upstream, and ImmortalWrt-specific in practice (OpenWrt disables 5/6 GHz without a country). | yes |
| `952-wifi-scripts-use-SAE-WPA3-EAP-for-WPA2-only-6GHz-APs.patch` | Round 1: runtime version of NSS `534e227e70`. Round 2: replaced by [OpenWrt PR #23914](https://github.com/openwrt/openwrt/pull/23914) plus `wpa=2` on 6 GHz, see [wifi.md](wifi.md) | On 6 GHz only: `psk`→`sae` and `eap`→`eap2`, so PMF is required. The scripts already did `psk-sae`→`sae` and `eap-eap2`→`eap2`. The default `owe` on 6 GHz already sets `ieee80211w=2`. | Not upstream | yes |

How the 950 resolver was chosen among four candidates:

- **PR #24639** has the ordering bug described above.
- **yangzhg's `resolve_radio_for_band()`** (6cc06a408d) has the right ordering and requires exactly one matching radio. It does not keep `radio=-1`.
- **yintaomu (Preview 2)** and the **NSS repo** do an inline or forked `nl80211` dump. NSS moved it into a fresh `ucode` process after the inline lookup silently fell back on hardware. They also add a 4 s per-wiphy setup lock.

The shipped 950 keeps the PR's `wiphy_radio()` helper in `wifi.common`, which uses the
per-wiphy `wiphy_info()` like the rest of the scripts. It fixes the ordering the way
yangzhg did, keeps null/-1, and drops the "channel not disabled" filter. Without
that last change, a world regdomain at first boot would leave the 6 GHz band with
no match. The setup lock is not included.

## Dropped / not included

| Patch | Why |
|---|---|
| Jackie/yangzhg `109-wifi-ath12k-log-WMI-control-service-topology` | Diagnostic logging only. Applies cleanly; add it back if you need #24949 debug output. |
| `200-Revert-wifi-ath12k-convert-tasklet-to-BH-workqueue` (luckkyboy, Jackie) | Dropped upstream. See commit `4ab78459bd` "mac80211: ath12k: drop the BH workqueue revert": kernels 6.12 and 6.18 have BH workqueues, and the revert breaks `ATH12K_AHB`. It is not in the SDK series either. |
| yangzhg `107-…create-symlink-for-each-radio-in-a-wiphy`, `subsys/100-…cfg80211-debugfs-multi-radio` | Already in backports 7.2 (`struct wiphy_radio_cfg`, per-radio debugfs symlinks). Obsolete. |
| yangzhg/Jackie `001-v7.1-…hwmon-temperature-reporting` | Already in backports 7.x. Jackie264 deleted it as well. |
| yangzhg `wifi-detect.uc` EHT320/precedence fix | Out of scope. It only affects the legacy shell `files/` path. Upstream still has the old code. |
| Jackie target patches `0363-net-ethernet-qualcomm-honor-safe-NAPI-budgets` ([PR #25405](https://github.com/openwrt/openwrt/pull/25405), open) and `0364-regulator-qcom_smd-fix-MP5496-supply-names` ([lore](https://lore.kernel.org/r/20251216-qcom_smd-mp5496-supply-fix-v1-1-f9b5e70536de@gmail.com)) | Kernel/target patches. They need our own kernel build and would change vermagic, so they cannot be used with the SDK. The same applies to Jackie264's CMA config and DTS regulator changes. |
| yintaomu/NSS hostapd setup lock with a 4 s sleep, NSS `ctrl_interface` change | Workarounds, not fixes, and not needed for the items above. |
