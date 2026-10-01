# WiFi patch notes (2026-10-01)

This file records the WiFi patches added on 2026-10-01 on top of the set
described in [README.md](README.md): where each one came from, what it fixes,
how it was checked, and what happened to the older local patches 952–954.

Base: ImmortalWrt master `bf156b68e3`, mac80211 = backports 7.2
(`PKG_RELEASE:=4`), kernel 6.18.52, iwinfo `66bdd1a0` (2026-05-26).

Tiers:

- **adopt**: upstream fixes (mainline, ath-next) or small, reviewed pending
  fixes that address a problem this board can hit. Meant to stay.
- **test**: performance or memory-layout changes. Each one is a separate file
  and can be deleted without touching the others (970–978 come last in the
  series for that reason; see "Removing test patches").

## Validation (all patches together)

Done in a separate worktree (`~/owrt/wt-wifi`, `bf156b68e3`) on the build host:

- `STAGE=prepare` of `scripts/src-build.sh` succeeds with this set: overlay copied,
  tree patches 0001, 0002, 0006, 0010, 0011 applied with `git apply`,
  then wifi-scripts 950–952 applied with `patch -F0`.
- The ath12k series (OpenWrt's own patches, then 900–978) applies with GNU
  `patch -p1 -F0`: no fuzz, no offsets, no rejects. All files were regenerated
  from a git tree with the full series applied, so the line numbers are exact.
- `make package/kernel/mac80211/{clean,compile} -j16 V=s` (kernel 6.18.52) builds
  `kmod-ath12k-6.18.52.7.2-r4`. The ath12k build prints no compiler warnings;
  the only messages are modpost's usual "missing MODULE_DESCRIPTION()"
  notes. The first build failed in modpost because 970 called the unexported
  `irq_can_set_affinity()`; 970 was fixed (see its row).
- `make package/network/utils/iwinfo/{clean,compile}`: 101 applies with no
  offset or fuzz, no warnings. Built `libiwinfo20230701-2026.05.26~66bdd1a0-r1`.
- `make package/network/config/wifi-scripts/{clean,compile}`: built `wifi-scripts-1.0-r4`.
- `ipq9570-sbe1v1k.dts` with 0006 goes through cpp + the kernel's dtc
  without errors. The decompiled DTB shows each card referencing its own
  region plus the shared MLO region.
- I also checked the platform agent's `0003-kernel-bump-6.18-to-6.18.54` together with
  this set: all tree patches applied with `git apply` in name order
  (0001, 0002, 0003, 0006, 0010, 0011), then wifi-scripts 950–952. Applying
  wifi-scripts 950–952 before 0010/0011 also works. Their 0004/0005 did not
  exist yet.
- `wifi-detect.uc` (the only ucode file changed here) passes `ucode -c`. Its
  native-module imports were stubbed, because the host ucode has no
  nl80211/fs modules.
- None of this has run on hardware yet.

## ath12k → `patches/mac80211/` (copied to `package/kernel/mac80211/patches/ath12k/`)

Order: 900–911 upstream backports, 920–923 pending fixes, 950–960 local, 970–978 test.

### Upstream (mainline / ath-next), tier adopt

| File | Source | Author | Fixes | Notes |
|---|---|---|---|---|
| `900-wifi-ath12k-avoid-setting-320MHz-support-on-non-6GHz-band` | mainline [eaf478b3ea68](https://github.com/torvalds/linux/commit/eaf478b3ea68) | Nicolas Escande | The 2.4/5 GHz bands advertise 320 MHz EHT PHY capabilities, and so do beacons on those bands (W8) | clean |
| `901-wifi-ath12k-fix-survey-indexing-across-bands` | mainline [c42b27336eef](https://github.com/torvalds/linux/commit/c42b27336eef) | Matthew Leach | On a single-wiphy multi-radio device, survey (channel busy time) data for 5/6 GHz comes from the 2.4 GHz slots. Moves the survey table to `ath12k_hw` (W6) | backported: context in `core.h` (data_lock comment, `struct ath12k_hw`) and `ath12k_mac_hw_allocate()` differs in 7.2. Code unchanged |
| `902-wifi-ath12k-correctly-copy-the-hint-BSSID-in-WMI-scan-request` | mainline [7b0bd40e97a0](https://github.com/torvalds/linux/commit/7b0bd40e97a0) | Jeff Johnson | Wrong copy size for the hint BSSID in the scan command (W8 hardening) | clean |
| `903-wifi-ath12k-avoid-buffer-overread-in-ath12k_wmi_op_rx` | mainline [7698656a2f7b](https://github.com/torvalds/linux/commit/7698656a2f7b) | Jeff Johnson | Reads past a short WMI event (W8 hardening) | clean |
| `904-wifi-ath12k-fix-overreads-in-csa_switch_count_event` | mainline [878654eb78c6](https://github.com/torvalds/linux/commit/878654eb78c6) | Jeff Johnson | Reads past a CSA switch count event (W8 hardening) | clean |
| `905-wifi-ath12k-validate-TLV-length-in-process_tpc_stats` | mainline [8e415b806848](https://github.com/torvalds/linux/commit/8e415b806848) | Jeff Johnson | Unchecked TLV length in TPC stats (W8 hardening) | clean |
| `906-wifi-ath12k-fix-stride-mismatch-in-mac_phy_caps_parse` | mainline [4c6eb712a91f](https://github.com/torvalds/linux/commit/4c6eb712a91f) | Jeff Johnson | Heap overflow when firmware sends short MAC/PHY capability TLVs (W4) | clean |
| `907-wifi-ath12k-fix-encrypted-EAPOL-TX-in-encap-offload-mode` | mainline [1e33f8acd837](https://github.com/torvalds/linux/commit/1e33f8acd837) | Reshma Immaculate Rajkumar | EAPOL frames sent encrypted during rekey in Ethernet encap offload mode, so clients drop them (W5) | clean |
| `908-wifi-ath12k-signal-regd-update-completion-when-reg-event-is-dropped` | ath.git [f2576dc0f894](https://git.kernel.org/pub/scm/linux/kernel/git/ath/ath.git/commit/?id=f2576dc0f894ef33045ba7ed057ec417988bba8a) | Baochen Qiang | "Timeout while waiting for regulatory update" at bring-up when the country is unchanged (W3) | clean |
| `909-wifi-ath12k-use-per-radio-ab-in-ath12k_mac_hw_register` | ath.git [af8d103b2b23](https://git.kernel.org/pub/scm/linux/kernel/git/ath/ath.git/commit/?id=af8d103b2b23f8cf9a1a72b15b3873bad53470df) | Baochen Qiang | In a multi-device wiphy, the country code and `current_cc_support` were taken from the first device for all radios (W3) | clean |
| `910-wifi-ath12k-protect-new_alpha2-access-with-base_lock` | ath.git [04497f2a7721](https://git.kernel.org/pub/scm/linux/kernel/git/ath/ath.git/commit/?id=04497f2a77216f27f60463c9b3d84c3c8f2cf62c) | Baochen Qiang | Unlocked read of `new_alpha2` (W3) | needs 909 first, as in the upstream series |
| `911-wifi-ath12k-skip-setting-country-code-during-registration-when-unchanged` | ath.git [8ab8a5ee16b2](https://git.kernel.org/pub/scm/linux/kernel/git/ath/ath.git/commit/?id=8ab8a5ee16b2fcb06837039dc42405ed53866fec) | Baochen Qiang | Sends a redundant set-country command and waits for it at registration (W3) | clean after 909/910 |

### Pending upstream / third party, tier adopt

| File | Source | Author | Fixes | Notes |
|---|---|---|---|---|
| `920-wifi-ath12k-assign-device-id-from-the-WSI-index` | [patchwork v3](https://patchwork.kernel.org/project/linux-wireless/patch/20260928213322.98949-1-yahoo@perenite.com/), also the head of [OpenWrt PR #25424](https://github.com/openwrt/openwrt/pull/25424) | Benoit Masson | The radio order inside the wiphy (and the wiphy's parent device) changes between boots ([#24370](https://github.com/openwrt/openwrt/issues/24370)) (W1) | **Replaces our 954.** Same behaviour as 954 (`device_id = wsi->index`). 954 also had bounds and duplicate checks, which v3 does not need: `ath12k_core_get_wsi_index()` only returns indices that come from walking the ring, so they are unique and below `num_devices`. With either patch, index 0 is the WSI controller (pcie2, 6 GHz) and the wiphy hangs off that device, so the current firmware already behaves this way |
| `921-wifi-ath12k-fix-freq-range-overflow-when-reg-rules-not-yet-parsed` | [patchwork](https://patchwork.kernel.org/project/linux-wireless/patch/apl2QtZu6EwGL0dD@mpf-ESPRIMO-P9012/) | Michael Pfeifroth | `freq_low` stays at INT_MAX before the 5/6 GHz rules arrive and overflows into an empty range; AP start then fails with "Failed to set beacon parameters" (W2) | clean. Tested-on QCN9274 |
| `922-wifi-ath12k-validate-MAC-PHY-capability-count-before-saving` | [patchwork](https://patchwork.kernel.org/project/linux-wireless/patch/20260925121739.2061979-1-yaojiale02@163.com/) | Jiale Yao | Writes past `mac_phy_info[]` when firmware advertises too many PHYs (W4) | **Watch:** the second check rejects the whole service-ready event if the number of MAC/PHY TLVs differs from the PHY count in the HW mode bitmaps. A device whose firmware does this then fails to come up, and a WSI group with it goes down too. With 906 alone, the missing entries would just be zero. If a radio fails with `invalid number of MAC/PHY caps`, delete 922 |
| `923-wifi-ath12k-skip-uncreated-links-on-scan-failure` | [Quarx2k/OpenWRT-BE7000 962](https://github.com/Quarx2k/OpenWRT-BE7000/blob/912ec81c992f1c8029bf128164021c2d3aec117d/package/kernel/mac80211/patches/ath12k/962-ath12k-skip-uncreated-links-on-scan-failure.patch) (branch be7000-snapshot) | Nickolai Semendiaev | NULL `arvif->ar` dereference in the scan-failure cleanup for links without a vdev (W7) | renumbered 962 → 923. Not submitted upstream |

### Local patches (existing)

| File | Change today |
|---|---|
| `950`, `951` | Unchanged, byte for byte |
| `952-wifi-ath12k-limit-WMI-endpoints-to-QMI-PHY-count` | Unchanged and still needed. W4 (906/922) only hardens how WMI MAC/PHY capabilities are parsed. It does not touch the HTC WMI endpoint count, so the `WMI_CONTROL_MAC1` / `-71` failure (#24949) is still fixed only by 952 |
| `953-wifi-ath12k-complete-regulatory-update-on-empty-reg-event` | **Rewritten, replaces `953-wifi-ath12k-handle-empty-regulatory-events`.** The old 953 did two things. (1) It assigned `pdev_idx` before validation, so the DROP path completes the waiter: upstream 908 now does exactly that. (2) It handled events with no rules: upstream does not cover this. Without it, such an event still returns -EINVAL before the PHY ID is read, prints "failed to extract regulatory info", hits WARN_ON and leaves the waiter to time out. The new 953 keeps only (2), in 10 lines: the parser stores `phy_id` and returns -ENODATA, and the handler keeps the current regdomain and completes the update for that PHY. It also drops the old patch's second copy of the alpha2/status parsing |
| `954-wifi-ath12k-use-WSI-index-for-hardware-group-order` | **Deleted**, replaced by 920 (upstream v3) |
| `955`, `960` | Unchanged in content; 960 was regenerated (line numbers only). 955 adds `AFC_REGION_TYPE` to the dynamic allocation; 978 does the same for the reserved region |

### Test tier

| File | Source | Author | Purpose | Notes |
|---|---|---|---|---|
| `970-wifi-ath12k-enable-threaded-NAPI-when-DP-IRQ-affinity-is-unavailable` | mainline [74e1a4762c79](https://github.com/torvalds/linux/commit/74e1a4762c79) | Hangtian Zhu | Threaded NAPI for DP interrupts when their affinity cannot be set (the DWC PCIe MSI on IPQ9574 cannot), so RX is not stuck on one CPU's softirq (T1) | backported: `irq_can_set_affinity()` is not exported by kernel 6.18 (the first build failed in modpost: `"irq_can_set_affinity" [ath12k.ko] undefined`). A local helper does the same check with the exported `irq_get_irq_data()` and `irqd_can_balance()`. Interacts with packet steering/irqbalance: compare throughput and the "drops under load" symptom from README |
| `971-wifi-ath12k-flush-REO-queue-extension-descriptors-before-freeing-qdesc` | [patchwork](https://patchwork.kernel.org/project/linux-wireless/patch/20260831151011.2336305-1-sebastian.salmhofer@salmtek.com/) | Sebastian Salmhofer | REO may still use the queue extension descriptors after the host frees the qdesc (use-after-free under station churn) (T2) | clean |
| `972-wifi-ath12k-set-congestion-control-max-MSDU-count` | mainline [e23d90cfcbe2](https://github.com/torvalds/linux/commit/e23d90cfcbe2) | Thiraviyam Mariyappan | Raises the firmware's TQM MSDU limit to the TX descriptor count: fewer TQM drops with many clients (T3) | clean. `ath12k_mac_start()` fails if the WMI command cannot be sent |
| `973-wifi-ath12k-reduce-RX-SRNG-interrupt-timer-threshold-to-200us` | mainline [6b31c3451b12](https://github.com/torvalds/linux/commit/6b31c3451b12) | Thiraviyam Mariyappan | RX SRNG interrupt timer threshold of 200 us (T4) | clean |
| `974-wifi-ath12k-use-different-RX-release-ring-sizes-per-memory-profile` | mainline [534459ac562b](https://github.com/torvalds/linux/commit/534459ac562b) | Pavankumar Nandeshwar | RX release ring 1024 → 16384 entries (default profile) against OOR bursts (T4) | backported: in 7.2 the default-profile context has `rxdma_monitor_dst_ring_size = 8092`, so that hunk was rebuilt by hand |
| `975-wifi-ath12k-use-per-device-max-QMI-chunk-size` | ath.git [4e286c780d75](https://git.kernel.org/pub/scm/linux/kernel/git/ath/ath.git/commit/?id=4e286c780d75831a169b0489afd015214838affd) | Baochen Qiang | Per-device QMI retry chunk size; no change for QCN9274 (2 MB) (T5) | backported: the warning format is `%d` in 7.2 |
| `976-wifi-ath12k-clear-chunk-paddr-and-size-in-free_target_mem_chunk` | ath.git [a1af8645cf2d](https://git.kernel.org/pub/scm/linux/kernel/git/ath/ath.git/commit/?id=a1af8645cf2dcdac5c6b3929e1dcb2274ca9f27e) | Baochen Qiang | Stale paddr/size of freed QMI chunks (T5) | clean |
| `977-wifi-ath12k-align-QMI-target-memory-to-64-KB` | ath.git [f7f05c443361](https://git.kernel.org/pub/scm/linux/kernel/git/ath/ath.git/commit/?id=f7f05c443361ebaa503e054e882633913273b3fa) | Baochen Qiang | Unaligned QMI chunks use up firmware TLB entries and can crash it; chunks are now 64 KB aligned (T5) | backported: no `of_reserved_mem.h` include and `%d` formats in 7.2; new code unchanged |
| `978-wifi-ath12k-use-reserved-host-DDR-for-PCI-devices` | new, after NSS repo `317-ath12k-use-reserved-pci-host-ddr` + `315-ath12k-share-fixed-mlo-memory` (JiaY-shi) | — | Gives each QCN9274 its firmware memory from a DT reserved region (stock QSDK layout) instead of 2 MB DMA chunks, and one shared MLO global region for the WSI group (T6) | see below |

#### 978 + `patches/tree/0006` (T6, reserved host DDR)

Why not port 315/317 as they are: 315 rewrites the MLO memory code for a
mixed IPQ5332 (AHB) + QCN9274 group and conflicts with 976/977 in every free
path. 317 gives AFC segments (type 0xA, which 955 handles) a NULL address and
leaks its mappings when the firmware asks for memory again after a restart.
978 is written for backports 7.2 and keeps 317's design:

- `ath12k_pci_probe()` sets `ATH12K_FLAG_FIXED_MEM_REGION` only if the DT node
  has `memory-region-names = "host-ddr-mem", ...`. Without 0006 the new code
  never runs.
- Host DDR, M3 dump, pageable, CALDB, LPASS and AFC segments go into
  `host-ddr-mem`, each 64 KB aligned (same reason as 977).
- MLO global memory comes from `mlo-global-mem`, mapped once per group. Each
  segment sits at its cumulative offset, so all three cards give their firmware
  the same addresses. That MLO memory is cleared with `memset_io()`, since a
  plain `memset()` on an ioremap() mapping can fault on arm64.
- If the region is too small or missing, the driver logs a clear error
  (`host-ddr-mem too small…`, `no mlo-global-mem…`) and that device does not
  come up. It does not fall back to dynamic allocation.

DTS (0006): the per-card regions are `qcn9224_pcie1@0x50f00000`,
`qcn9224_pcie2@0x54100000` and `qcn9224_pcie3@0x57300000`, 0x3200000 (50 MiB)
each. The MLO region `mlo_global_mem0` is 0x1200000 (18 MiB), allocated
dynamically with 1 MiB alignment. Each region goes to the card on the
controller with the same number: pcie1 @ 0x10000000 is 2.4 GHz
(`Askey-SBE1V1K_1`), pcie2 @ 0x20000000 is 6 GHz (`_4`, WSI controller) and
pcie3 @ 0x18000000 is 5 GHz (`_2`). Checks:

- No overlap with ipq9574.dtsi (bootloader 0x4a100000, sbl, tz 0x4a600000,
  smem up to 0x4ab00000) or with tzapp 0x49b00000–0x4a100000. The fixed
  regions span 0x50f00000–0x5a500000.
- The chainloader U-Boot loads the FIT at 0x60000000, above them.
- The NSS tree used an MLO size of 0x1100000 (17 MiB). The stock QSDK 12.5 DTB
  value is 0x1200000, and that is what 0006 uses.
- This costs 168 MiB of the board's 2 GiB of RAM permanently. Today's dynamic path uses about 30 MiB
  per card.
- Risk: the NSS project booted with these regions (d39d06d7ce reached
  userspace). Its later boot failures were traced to other changes
  (PPE/NSS DTS, radio-count cap), not to these regions. Even so, test this
  first with the initramfs image. If WiFi does not come up, remove 0006, or
  both 0006 and 978.

### Removing test patches

970–978 come after every adopt-tier and local patch. I checked removals with
GNU `patch -F0` over the full series:

- Each of 970, 971, 972, 973, 974, 977 and 978 can be deleted on its own.
- 975 → 976 → 977 are one upstream series: 977 needs both 975 and 976. You can
  delete 977, 976+977, or all three.
- All of 970–978 can be deleted together.
- Each of 920–923 can also be deleted on its own.

978 has no context in common with 970–977, so it can stay without them.

## Tree patches (`patches/tree/`, `git apply` at the tree root)

| File | Source | Fixes | Notes |
|---|---|---|---|
| `0006-sbe1v1k-dts-qcn9274-host-ddr.patch` | this repo (layout from the NSS repo / stock DTB) | T6 DTS part, see above | Touches only `reserved-memory` and the three `wifi@0` nodes of `ipq9570-sbe1v1k.dts`. Generated against the tree with 0001+0002 applied. **test** |
| `0010-wifi-scripts-fsync-board.json-before-replacing-it.patch` | [OpenWrt PR #25471](https://github.com/openwrt/openwrt/pull/25471) head `436b4d6b14` (Patrick Lawler) | A power cut within ~30 s of a board.json rewrite can leave an empty `/etc/board.json` on UBIFS ("PHY is undefined" forever) (W9) | unchanged. busybox `fsync` is enabled by default (`BUSYBOX_DEFAULT_FSYNC=y`). Our rootfs is on eMMC, where a delayed write can leave the same empty file |
| `0011-wifi-scripts-keep-board.json-entries-of-phys-not-up-yet.patch` | [OpenWrt PR #25473](https://github.com/openwrt/openwrt/pull/25473) head `bd091da887` (Patrick Lawler, latest on 2026-09-30) | board.json is rewritten 2–3 times per boot while phys are still probing, and entries of phys that are not up yet are dropped (W9) | rebased on 0010: both PRs bump `PKG_RELEASE` 2→3, so 0011 bumps 3→4. `wifi-detect.uc` hunks unchanged |

Both touch only `files/usr/share/hostap/wifi-detect.uc` and the Makefile, and
our wifi-scripts 950–952 touch only `files-ucode/`. So the two sets are
independent and apply in either order. The `prepare` run applied the tree patches first, then
wifi-scripts 950–952 with `patch -F0`.

## iwinfo → `overlay/package/network/utils/iwinfo/patches/`

| File | Source | Fixes | Notes |
|---|---|---|---|
| `101-nl80211-filter-split-radio-capabilities.patch` | [Quarx2k/OpenWRT-BE7000 101](https://github.com/Quarx2k/OpenWRT-BE7000/blob/912ec81c992f1c8029bf128164021c2d3aec117d/package/network/utils/iwinfo/patches/101-nl80211-filter-split-radio-capabilities.patch) (Nickolai Semendiaev) | `iwinfo radioN freqlist/htmodelist` (and so LuCI) lists every band's channels and widths of the shared wiphy for each radio. The patch filters them by the radio's nl80211 frequency ranges (W11) | ImmortalWrt has only `100-multi_radio.patch` (identical to Quarx2k's) and the same iwinfo commit `66bdd1a0`, so the number 101 is free. **Changed:** the original picks the radio by the UCI `radio` index alone. Ours also reads the UCI `band`, and if that radio does not cover the band, it uses the first radio that does, as wifi-scripts 950 does at runtime. Otherwise a config written with another radio order would show the 6 GHz channel list for the 2.4 GHz radio. `PKG_RELEASE` of iwinfo is not bumped: the Makefile is outside the files this change may edit |

## Not done / follow-ups

- `PKG_RELEASE` of mac80211 and iwinfo is not bumped. The existing local
  patches did not bump it either.
- Hardware testing on the SBE1V1K: test 922, 970, 972, 978 and 0006 first,
  using the initramfs image.

---

# Round 2 (2026-10-01, second pass)

New rule for this round: fix everything that can be fixed, also for features
the owner does not use (MLO, mesh, 802.11r, dynamic VLAN, monitor, SSR,
STA mode), because other users of the public firmware may use them. Risky
changes are separate **test** patches that can be deleted one by one.

Base: ImmortalWrt master `bf156b68e3`, kernel 6.18.54 (tree/0003),
mac80211 = backports 7.2 (= Linux v7.2) `PKG_RELEASE:=4`, hostapd
`831364bf02` (2026-08-07, hostap 2.12) `PKG_RELEASE` 3 → 4 (tree/0019).

Where things live (numbering reserved for WiFi):

| Kind | Path | Adopt | Test |
|---|---|---|---|
| mac80211/cfg80211 | `overlay/package/kernel/mac80211/patches/subsys/` | 900–964 | 970, 980–983 |
| ath12k | `patches/mac80211/` | 924–949 | 982–985 (plus round-1 970–978; 980/981 dropped) |
| hostapd C code | `overlay/package/network/services/hostapd/patches/` | 071, 900–917, 930, 931 | 950, 980 |
| hostapd ucode/Makefile, wifi-scripts outside `files-ucode` | `patches/tree/` | 0012–0017, 0019 (0018 unused) | — |
| wifi-scripts `files-ucode` | `patches/wifi-scripts/` | 952 (rewritten), 953–955 | — |

## Round 2 validation

Build host `~/owrt/wt-wifi` (ImmortalWrt `bf156b68e3`), recipe rsynced to
`~/fw-wifi`, `STAGE=prepare` of `scripts/src-build.sh`:

- `prepare` succeeds with the whole recipe as of 2026-10-01 16:00, including
  the platform patches of that time: overlay copied, tree patches 0001–0006,
  0010–0017, 0019, 0030–0032 applied with `git apply` in name order, then
  wifi-scripts 950–955 with `patch -F0`.
- `make target/linux/compile -j16` (6.18.54 with the platform overlay of
  that time), then `make package/kernel/mac80211/{clean,compile} -j16 V=s`:
  all three variants (regular, sdio, smallbuffers) built
  `kmod-{cfg80211,mac80211,ath12k}-6.18.54.7.2-r4`. All 70 new subsys
  patches (900–964, 970, 980–983) and all 62 ath12k patches applied in
  every variant with no fuzz and no offset (the only offsets in the log
  are ImmortalWrt's own ath10k/982, 988, 991). No compiler warning in `net/mac80211`,
  `net/wireless` or `ath12k`.
- `make package/network/services/hostapd/{clean,compile} -j16 V=s` with
  extra variants enabled as `=m`: wpad-openssl (image), wpad-basic-mbedtls,
  wpad-mbedtls, wpad-wolfssl, wpad-mesh-openssl, hostapd-basic-mbedtls,
  hostapd-openssl, wpa-supplicant-openssl, wpa-supplicant-mini: all nine built
  (`…2026.08.07~831364bf-r4`), no warnings, no offsets. The same nine also
  build with `CONFIG_DRIVER_11BE_SUPPORT=` (no 802.11be: the path that
  OpenWrt PR #25509 fixes in tree/0012).
- `make package/network/config/wifi-scripts/{clean,compile}`: `wifi-scripts-1.0-r4`.
- `make package/network/utils/iwinfo/{clean,compile}`: unchanged from
  round 1 (101 applies without offset; ImmortalWrt's own 100 has offsets).
- Series checks on the Linux VM with GNU `patch -p1 -F0` from a clean
  backports 7.2 tarball, all directories in quilt order: 291 patches, no
  fuzz; removal checks below. hostapd: 85 patches on hostap `831364bf02`, no
  fuzz, no offset. Changed `.uc` files pass `ucode -c` (SDK host ucode, native
  modules stubbed).
- Nothing has run on hardware.

## mac80211 / cfg80211 → `overlay/package/kernel/mac80211/patches/subsys/`

OpenWrt builds mac80211 from backports 7.2 (= Linux v7.2), so the
mac80211/cfg80211 fixes that went into Linux 6.18.54 (the kernel's own copy,
unused) and into 7.2.y stable are missing from the modules we ship. These
patches add them. They sort after ImmortalWrt's subsys 110–600 and before
the `ath/`…`ath12k/` directories.

Sources, in this order of preference:

1. **stable linux-7.2.y** (7.2.8): every mac80211/cfg80211 commit after v7.2,
   because they were already picked for the 7.2 code base. That covers all
   mac80211/cfg80211 items of [OpenWrt PR #25516](https://github.com/openwrt/openwrt/pull/25516)
   (mac80211 6.18.54 for 25.12) that are not in v7.2 itself; the rest of
   that PR's list is already in v7.2 (checked one by one).
2. **mainline v7.3-rc1..rc5** fixes that are not in 7.2.y.
3. **wireless.git main**: fixes queued for v7.3 that are not in a release yet.

Tier **adopt** = 900–964, tier **test** = 970 (own mesh fix, see the mesh
section) and 980–983.

| File | Source | Author | Fixes | Notes |
|---|---|---|---|---|
| `900` fix per-STA profile length in cross-link CSA parsing | 7.2.y 0b56ad971fa0 (mainline 4a0bd262df) | Zhao Li | STA/MLO: CSA element parsing reads 3 bytes past a per-STA profile | clean |
| `901` send TWT teardown to peer after setup TX failure | 7.2.y c8ae335c4823 | Zhao Li | TWT teardown sent to the wrong address after an unacked setup | clean |
| `902` clean up color-change beacon data on errors | 7.2.y 4e0a67fbe3d9 | Zhao Li | memory leak on a failed BSS color change request (HE AP) | clean |
| `903` skip unused probe response countdown offsets | 7.2.y cb04dd061d33 | Zhao Li | CSA/color change: writes byte 0 of the probe response template | clean |
| `904` disconnect on CSA to channel 0 | 7.2.y eef374088450 | Johannes Berg | STA: ignores a CSA to channel 0 | clean |
| `905` stop PMSR before P2P and NAN teardown | 7.2.y db3439ad11ac | Zhao Li | FTM measurements left running on teardown | clean |
| `906` include TIM bitmap control for buffered S1G mcast traffic | 7.2.y 9f04f9b14416 | Lachlan Hodges | S1G only; taken with the stable set | clean |
| `907` don't get the radio mask for netdev-less wdevs | 7.2.y 7166da84a7fe | Johannes Berg | **multi-radio**: NULL dereference in `cfg80211_calculate_bi_data()` for P2P-device/NAN wdevs | clean |
| `908` check IP header size in `cfg80211_classify8021d()` | 7.2.y 65893c8d28f2 | Johannes Berg | reads past a short IP frame when choosing the TID | clean |
| `909` don't free driver-owned scan requests | 7.2.y cf6da29d1799 | Johannes Berg | use-after-free when an interface goes down during a scan | clean |
| `910` only group hidden BSSes with beacon entries | 7.2.y 332ea1502c46 | Johannes Berg | scan list corruption with hidden SSIDs | clean |
| `911` don't filter by BSS type when removing stale entries | 7.2.y 0aa44982125c | Johannes Berg | BSS rbtree collision/WARN after the AP switches channel | clean |
| `912` fix NAN regulatory enforcement | 7.2.y 9580c87b0210 | Johannes Berg | NAN only | clean; touches `reg.c`, `ath/404` still applies unchanged |
| `913` don't start a ROC while scanning | 7.2.y 58b806f69905 | Johannes Berg | remain-on-channel started during a scan (hostapd off-channel TX, DPP) | clean |
| `914` don't warn when an IBSS has no channel to scan | 7.2.y 23d51c0bc18f | Johannes Berg | spurious WARN after a regdomain change | clean |
| `915` don't offload TC setup on AP_VLAN interfaces | 7.2.y ea3ef2165e47 | Johannes Berg | WDS/dynamic VLAN: TC offload requests sent to the driver for virtual AP_VLANs | clean |
| `916` suppress chanctx warning for debugfs reset | 7.2.y 7aca529c0d8d | Johannes Berg | WARN on a debugfs-triggered HW restart | clean |
| `917` abort chanswitch when leaving a mesh | 7.2.y d222fdc973bb | Johannes Berg | **mesh**: crash in CSA finalize when the mesh is left during a channel switch | clean |
| `918` reset state when starting AP fails | 7.2.y 6eac225f59c1 | Johannes Berg | **AP**: after a failed AP start, a later scan restarts beaconing on the dead interface (WARN/crash) | clean |
| `919` reset the LED state when ifup fails | 7.2.y de6f9561db57 | Johannes Berg | LED TPT timer left running | clean |
| `920` only operate on TDLS peers in the TDLS code | 7.2.y 0cd452ccaa5c | Johannes Berg | STA: TDLS ops on the AP station | clean |
| `921` unlist vifs when their netdev is unregistered | 7.2.y 821bab0456df | Johannes Berg | use-after-free when a netns holding the wiphy dies | clean |
| `922` don't allow injecting frames wider than the chanctx | 7.2.y c69718519a81 | Johannes Berg | monitor injection with a too-wide bandwidth | clean |
| `923` reset the AP_VLAN tailroom counter on ifdown | 7.2.y 875835377d8d | Johannes Berg | WDS/VLAN: counter WARN after repeated AP_VLAN up/down | clean |
| `924` require a peer station for TDLS setup confirm | 7.2.y 1c0a5c96473b | Johannes Berg | WARN | clean |
| `925` don't allow link changes when iface is down | 7.2.y 1cf42768fa08 | Johannes Berg | MLO: WARN | clean |
| `926` don't RCU-dereference the mesh CSA settings we just set | 7.2.y 15c408bae4f1 | Johannes Berg | mesh CSA: lockdep splat | clean |
| `927` don't access the TSF of a down interface | 7.2.y c68c947e3489 | Johannes Berg | WARN via debugfs | clean |
| `928` add HE 6 GHz capability in the scan elems len | 7.2.y 9d83c08dcce8 | Johannes Berg | **6 GHz**: probe-request IE space too small by the HE 6 GHz capability element | clean |
| `929` mesh: reset the CSA state when leaving | 7.2.y ba5bf83a81e8 | Johannes Berg | **mesh**: leaks `ifmsh->csa`, stale CSA after rejoining | clean (needs 917/926) |
| `930` mesh: release the channel if start fails | 7.2.y 4a4e3fa77ea3 | Johannes Berg | **mesh**: chanctx leak + WARN when mesh start fails | clean |
| `931` set up the TX info early to fix failure paths | 7.2.y 03d67414bd05 | Johannes Berg | TX status for failed frames not reported to hostapd | clean |
| `932` avoid WARN in set_bitrate_mask when sdata not in driver | 7.2.y c4ee5685af44 | Rik van Riel | WARN | clean |
| `933` avoid out-of-bounds read for empty PREQ elements | 7.2.y 3beddbd56946 | Ivan Pustogarov | **mesh**: 1-byte over-read on a malformed PREQ | clean |
| `934` refuse to make a monitor active when it has no queue | 7.2.y 46c223468537 | Devin Wittmayer | NULL deref in drivers with an "active" monitor | clean |
| `935` restore netns_immutable on failures | 7.2.y e6660383ebf5 | Johannes Berg | netns move failure leaves netdevs movable | **adapted**: backports keeps a `LINUX_VERSION_IS_GEQ()` switch between `netns_immutable` and `netns_local` |
| `936` undo netns switch if renaming the wiphy fails | 7.2.y 739b7bf3942d | Johannes Berg | inconsistent netns after a failed rename | **adapted**: same switch inside the new helper |
| `937` get the wiphy out of a dying network namespace | 7.2.y b949b2720688 | Johannes Berg | crash (garbage netns) when a netns holding the wiphy dies | clean after 935/936 |
| `938` ibss: ref BSS entry for joined event | 7.2.y b0e3f019e461 | Johannes Berg | IBSS WARN race with scan flush | context only: `CONFIG_CFG80211_WEXT` is `CPTCFG_…` in backports |
| `939` change `mesh_setup::ie_len` to `size_t` | mainline c706dc5da6e1 (v7.3-rc1) | Srinivas Achary | **mesh**: JOIN_MESH IEs longer than 255 bytes are truncated (u8) | clean. Relevant to 6 GHz mesh (large IEs), see the mesh section |
| `940` Avoid UNPROT_BEACON on AP interfaces | mainline 5e20d72350df (v7.3-rc1) | Dhanavandhana Kannan | **AP**: hostapd logs "unhandled event" for every unprotected neighbour beacon (log spam with beacon protection) | clean |
| `941` ibss: read deauth reason_code after frame length check | mainline aa4c0a649903 | Shahar Tzarfati | over-read | clean |
| `942` use ifa_dev from event argument | mainline e5b14e9ae82b | Yuyang Huang | STA: ARP filter not updated on address removal | clean |
| `943` fix monitor min_def bandwidth | mainline 43473cc1b0dc | Johannes Berg | monitor added to a running chanctx narrows its min width | clean |
| `944` don't apply peer rates to off-channel frames | mainline f5dd0626d2b0 (v7.3-rc4) | Johannes Berg | WARN in rate control for scan/off-channel frames to a known station | clean |
| `945` don't drop scan probe requests for lack of peer rates | mainline 23c68b4aaf5e (v7.3-rc4) | Johannes Berg | follow-up to 944 | clean |
| `946` count only matching reservations in reserved switch | wireless.git 437f3727b4fd | Zhiling Zou | multi-vif/multi-link channel switch (CSA) validation | clean |
| `947` keep paired old chanctx alive | wireless.git 3412e9a80078 | Zhiling Zou | use-after-free in chanctx replacement (CSA with several vifs) | clean |
| `948` release mesh path quota on failed additions | wireless.git 7325a44474f2 | Zhao Li | **mesh**: path counter leak until no new paths can be added | clean |
| `949` account proxy paths against the mesh path limit | wireless.git a5f35d4b112a | Zhao Li | **mesh**: proxy path churn drives the path counter negative | clean |
| `950` drain PS delivery work during station teardown | wireless.git 67a9e80c3ca2 | Zhao Li | AP/mesh: driver notified about a removed station (power save) | clean |
| `951` drop oversized fragments to avoid extra_len overflow | wireless.git 5e4f3509793b | Yuchao Zhang | defragmentation length overflow | clean |
| `952` fix mesh fast xmit path deletion UAF | wireless.git ee3aadc43ea6 | Zihan Xi | **mesh**: use-after-free in the fast-xmit cache | clean |
| `953` minstrel_ht: validate fixed rate index | wireless.git 15fb9e3cea55 | Yuqi Xu | out-of-bounds via debugfs `fixed_rate_idx` | clean (ath12k does not use minstrel; other drivers do) |
| `954` handle empty FILS association request payload | wireless.git 5bfd4b0b40b7 | Yuqi Xu | FILS STA | clean |
| `955` fix RTS threshold setting for single-radio PHY | wireless.git 9eda41e32263 | Stanislaw Gruszka | RTS threshold ignored on single-radio PHYs since per-radio RTS | clean |
| `956` validate TX status rate metadata | wireless.git 6bdcdb31318c | Yuqi Xu | out-of-bounds in minstrel_ht | clean |
| `957` shut down RX BA session timer on teardown | wireless.git e588e83e5c7a | Zhao Li | use-after-free of the BA session timer | clean |
| `958` preserve hidden-group beacon IE ownership | wireless.git cc45f313d855 | Zhao Li | double free of borrowed beacon IEs after a channel switch | clean |
| `959` prevent AP VLAN tx from other interfaces | wireless.git 7f93ca31f7fd | Felix Fietkau | **VLAN isolation**: a unicast frame sent on one VLAN interface reaches a station of another VLAN of the same BSS | clean |
| `960` set info->band for 802.3 encap offload frames | wireless.git 4febc02cd02f | Felix Fietkau | **ath12k (encap offload)**: rate lookup uses band 0 for 802.3 frames on non-MLD interfaces | clean |
| `961` reject invalid 320 MHz CSA bandwidth | wireless.git 56e236759f0a | Ruide Cao | STA: uninitialised width from a bogus CSA | clean |
| `962` fix slab-out-of-bounds read in `ieee80211_monitor_select_queue()` | wireless.git 6f63e919fe1e | Cen Zhang | monitor injection over-read | clean |
| `963` fix RCU dereference in throughput estimate | mainline aa0069bd920a | Johannes Berg | fixes OpenWrt's own subsys/361 (lockdep) | **adapted** to the older form of 361 OpenWrt carries |
| `964` keep fallback association elements alive | wireless.git a10a2f80476d | Zhao Li | STA: use-after-free when associating to a non-transmitted MBSSID profile | **adapted**: declaration context differs |
| `980` verify if AP_VLAN belongs to the correct AP | mainline ba7a79b9bc87 (v7.3-rc4) | Slawomir Stepien | `NL80211_ATTR_STA_VLAN` may point at a VLAN of another AP | **test**. Requires the AP_VLAN to have the AP netdev's MAC. This does not break dynamic VLAN on an AP MLD (checked in the code review): hostapd's `hostapd_vlan_if_add()` uses the MLD address when `mld_ap` is set, and mac80211 already binds an AP_VLAN to its AP only when the addresses match (`ieee80211_check_concurrent_iface()`) |
| `981` do not support direct add of station to AP_VLAN interfaces | mainline 4ae3128c2303 | Slawomir Stepien | prerequisite of 983 | **test** |
| `982` move link_id validation earlier in `nl80211_new_station()` | mainline e3d1acb02767 | Slawomir Stepien | prerequisite of 983 | **test** |
| `983` check if AP has been started or joined a mesh before adding new station | mainline a842cfc1d6d8 | Slawomir Stepien | syzbot: station added to a non-beaconing AP/mesh | **test** (new -ENETDOWN for early NEW_STATION) |

The test group 980–983 only guards against root-only misuse that syzbot
found. 983 needs 981 and 982; 980 is independent. Delete all four, or 980
alone, or 981–983 together.

Not taken:

| Commit | Why |
|---|---|
| 8ff047b9c7 "clarify and tighten key checks" (v7.3-rc1) | Rejects key installs that used to be accepted. No bug for our users, real risk for wpa_supplicant/hostapd corner cases (IBSS/mesh/AP_VLAN). |
| f4e72e3758 "reduce RTNL holding in regulatory enforcement" | Restructures enforcement into new works, written against the 7.3 NAN code. Hung-task report from syzbot only. |
| f13e573ab3 "notify driver before destroying assoc link" | Only matters for drivers with a `mgd_complete_tx` that frees per-link state; ath12k has none. 75-line reshuffle in the STA state machine. |
| a3262f61d1, 3002812cbe, peer probing (1c3f880ed0, b17e206e99), cookie rework (9967538044…), NAN/UHR/S1G features | Features or cleanups, not fixes |
| 0ca7040f20 + dd40677999 | A commit and its revert; net zero |
| be919eed5e "skip default WMM setup for AP_VLAN links" | Already in the tree as subsys/391 |

## 6 GHz 802.11s mesh: "new peer notification" flood

Report: [forum t/245244 post 271](https://forum.openwrt.org/t/245244/271)
(2026-09-27): on 6 GHz, `wpa_supplicant[…]: wl0.0-mesh0: new peer notification
for …` is logged over and over, with wpad mbedtls, openssl and wolfssl; the
two MT76 mesh nodes are fine. That single log line is all the thread has
(no follow-up, no debug log, build and encryption unknown).

How the line is produced: mac80211 `mesh_sta_info_alloc()` sends
`NL80211_CMD_NEW_PEER_CANDIDATE` for **every** matching beacon while it has
no station for that address (user-space MPM); wpa_supplicant logs the line
for each event and calls `mesh_mpm_add_peer()`. So a flood means the kernel
never keeps a station for the peer. Five ways that can happen, each with a
different trace:

| | Cause | Other trace | Status |
|---|---|---|---|
| A | Peering never completes (open retries run out → HOLDING → `ap_free_sta()` deletes the kernel station → next beacon notifies again; with SAE, alternating PMKSA/full SAE) | only "new peer notification" at default log level | **most likely, not confirmed**: needs a debug log or capture. No ath12k 6 GHz peering bug found in the code |
| B | Station add fails every time | `Driver failed to insert …` + ath12k warnings | possible |
| C | wpa_supplicant keeps a stale entry after the kernel dropped the station; `mesh_mpm_add_peer()` then returns silently. Kernel station removals are never reported for mesh (`nl80211_del_station_event()` handles only AP SME and IBSS) | silent until `mesh_max_inactivity` (300 s) | real gap → **hostapd 950** |
| D | Beacon IEs truncated to 255 bytes in the event (u8 `ie_len`, fixed by dfb67ae569) | `Could not parse beacon from` | **not in our firmware**: dfb67ae569 is in v7.2 (backports 7.2 has `size_t ie_len`). Possible on OpenWrt 25.12 builds with backports 6.18.39 |
| E | Single wiphy, several radios: management frames from every radio reach every interface, and `mesh_matches_local()` does not compare the primary channel (except for 6 GHz peers with 6 GHz operation info), so a 5 GHz mesh beacon with the same mesh ID matches the 6 GHz mesh and vice versa | candidates with another band's MAC | real bug on this board (one wiphy, 3 radios) → **subsys 970**. MT76 nodes have one wiphy per band, which fits "MT76 nodes are fine" |

`mesh_setup::ie_len` (subsys 939) does not explain it: JOIN_MESH only
carries the RSN element (~20–26 bytes). hostap.git after `831364bf02` has no
6 GHz mesh fix (only AMPE decryption cleanups), mainline 7.3-rc only mesh
CSA fixes (subsys 917/926/929), ath-next none, and OpenWrt has no issue/PR
about it (related: #24661, #24080, #24509).

| File | Source | Author | Fixes | Notes |
|---|---|---|---|---|
| `overlay/…/mac80211/patches/subsys/970-wifi-mac80211-mesh-ignore-beacons-from-other-channels.patch` | own work | Crescentm | E: on a multi-radio wiphy, mesh beacons/probe responses from the other radios' channels (and off-channel scan results, 2.4 GHz adjacent-channel leakage) become peer candidates/stations | **test**. Drops them unless the channel is the mesh operating channel (`bss_conf.chanreq.oper.chan`, same expression `mesh_matches_local()` uses). Applies `-F0` between 964 and 980 |
| `overlay/…/hostapd/patches/950-mesh-restart-peering-when-the-driver-lost-a-known-peer.patch` | own work | Crescentm | C: candidate event for a peer wpa_supplicant still tracks is ignored until the inactivity timer | **test**. On such an event asks the driver (`get_inact_sec` → -ENOENT); if the station is gone, logs `mesh: Peer … lost its driver entry - restart peering`, frees the stale entry and re-adds the peer; otherwise behaves as before. Builds in all nine hostapd variants |

What to ask a reporter for: `wpa_cli -p /var/run/wpa_supplicant -i <mesh-if>
log_level DEBUG` with `logread -f | grep -E "mesh|MESH|SAE|peer|Driver failed|parse beacon"`,
`iw event -t -f`, `iw dev <mesh-if> station dump` every second, `dmesg | grep ath12k`,
`uci show wireless`, and whether the MAC in the notifications is the peer's 6 GHz MAC
(another band's MAC → E). Signatures: only notifications + "HOLDING" → A;
"Driver failed to insert" → B; "lost its driver entry" (with 950) → C;
"Could not parse beacon" → D.

## ath12k → `patches/mac80211/` (adopt 924–949, test 982–985)

Candidates were the ath12k commits in v7.2..v7.3-rc5, linux-7.2.y, ath.git
`ath-next` (ath-next-20260927) and the linux-wireless patchwork queue of the
last four months. "clean" means the upstream diff applied unchanged.

### Upstream (mainline / 7.2.y / ath-next), tier adopt

| File | Source | Author | Fixes | Notes |
|---|---|---|---|---|
| `924-wifi-ath12k-fix-TLV32-length-mask` | 7.2.y de3e55613780 = mainline [d762bbc08ca7](https://github.com/torvalds/linux/commit/d762bbc08ca7) | Miaoqing Pan | `HAL_TLV_HDR_LEN` overlapped the user-ID bits, so 32-bit TLV lengths (monitor) were wrong | clean |
| `925-wifi-ath12k-tighten-RX-monitor-TLV-bounds-check` | mainline [fffa54aeaeb2](https://github.com/torvalds/linux/commit/fffa54aeaeb2) | Miaoqing Pan | RX monitor TLV walk could read a header past the end of the status buffer | backported: upstream sits on three QCC2072 32-bit-TLV refactors that are not taken; the same check is applied to the 7.2 loop |
| `926-wifi-ath12k-reset-REOQ-LUT-addresses-before-firmware-stop` | mainline [fe2b006c15f6](https://github.com/torvalds/linux/commit/fe2b006c15f6) | Aishwarya R | **SSR/unload**: REOQ LUT registers written after the firmware was stopped (invalid target access on rmmod and firmware-ready error paths) | clean. Tested-on QCN9274 |
| `927-wifi-ath12k-advertise-ieee_link_id-in-vdev-start-MLO-params` | 7.2.y 850211b0ba6c = mainline [784f7dabf5d3](https://github.com/torvalds/linux/commit/784f7dabf5d3) | Manish Dharanenthiran | **MLO**: firmware built the partner per-STA profile from hw_link_id instead of the MLD link id | clean. Tested-on QCN9274 |
| `928-wifi-ath12k-Advertise-multicast-Ethernet-encapsulation-offload-support` | 7.2.y 2d3cb65c4846 = mainline e47d6c9bb416 | Tamizh Chelvam Raja | Multicast frames are also sent in 802.3 form; MLO mcast replication clones HW-encap frames | Feature, but stable took it as the base of 933; 933 and 934 need it. The mac80211 side (`IEEE80211_OFFLOAD_ENCAP_MCAST`) is in backports 7.2. **Watch multicast** (IPTV, mDNS) |
| `929-…Skip-setting-RX_FLAG_8023-for-Ethernet-II-DIX-frames-in-monitor-mode` | mainline [5a2b5d6a5a4a](https://github.com/torvalds/linux/commit/5a2b5d6a5a4a) | Sushant Butta | monitor delivery must give 802.11 frames | clean; 930 needs it |
| `930-…Skip-peer-link-info-update-in-rx_status-for-monitor-MSDUs` | mainline [56f8f12c1a3c](https://github.com/torvalds/linux/commit/56f8f12c1a3c) | Sushant Butta | monitor path parsed monitor skbs as `hal_rx_desc` (garbage peer/link id), dp_lock per MSDU | clean. Tested-on QCN9274 |
| `931-wifi-ath12k-fix-dp_link_peer-dangling-references-on-AP-vdev-rollback` | 7.2.y af405d216316 = mainline [f066e1a93703](https://github.com/torvalds/linux/commit/f066e1a93703) | Baochen Qiang | **AP**: use-after-free when AP vdev creation fails | clean |
| `932-wifi-ath12k-fix-MLO-peer-delete-race` | 7.2.y 329b10ddc919 = mainline [01cc0f59aac3](https://github.com/torvalds/linux/commit/01cc0f59aac3) | Baochen Qiang | **MLO**: "Timeout in receiving peer delete response" when an MLO client leaves | backported: comment context (901) |
| `933-…Set-IEEE80211_OFFLOAD_ENCAP_4ADDR-after-tx_encap_type-vdev-param` | 7.2.y 1f77d0c58b6a = mainline be72d6aecea4 | Tamizh Chelvam Raja | **WDS/4addr**: offload flag left set when the vdev param failed | clean, needs 928 |
| `934-…skip-MLO-multicast-links-during-crash-recovery-in-Tx-path` | mainline [43c521c11ce8](https://github.com/torvalds/linux/commit/43c521c11ce8) | Pavankumar Nandeshwar | **MLO + SSR**: mcast copies for links of a crashed device, "failed to transmit frame" spam | clean on 928. Tested-on QCN9274 |
| `935-wifi-ath12k-clear-dangling-channel-pointers-on-error-paths` | ath.git 507478f6f938 | Linkai Gong | double free on the band setup error path (6 GHz copy/paste bug) | clean |
| `936-wifi-ath12k-fix-DMA-unwind-for-ext-MSDU-descriptor-retry` | ath.git 4de5a8a0eddd | Rameshkumar Sundaram | TCL ring full: ext descriptor unmapped twice, MSDU mapping leaked | clean. Tested-on QCN9274 |
| `937-wifi-ath12k-fix-stale-skb-pointers-after-aligned-TX-payload-shift` | ath.git 6c40719489c8 | Baochen Qiang | stale pointers after the TX alignment shift/realloc | clean |
| `938-wifi-ath12k-fix-truncated-TX-buffer-DMA-address-in-MSDU-ext-descriptor` | ath.git 979ecb88ed35 | Baochen Qiang | BUF_PTR_HI hard-coded to 0 | clean. Only matters above 4 GB (not on this 2 GB board) |
| `939-wifi-ath12k-Free-allocated-CE-IRQs-on-request_irq-failure` | ath.git 12ca935af2e6 | Aaradhana Sahu | CE IRQ leak on probe failure | clean. Tested-on QCN9274 |
| `940-wifi-ath12k-Free-allocated-external-IRQs-on-request_irq-failure` | ath.git 9a78703ec4a8 | Aaradhana Sahu | DP IRQ/NAPI leak on probe failure | backported without upstream's dependency on 74e1a4762c79 (our test 970), so 970 still applies; needs 939 |
| `941-wifi-ath12k-preserve-PPDU-state-across-monitor-status-buffers` | ath.git 69b2d06dafa4 | Kang Yang | stale `ppdu_continuation` leaks into the next monitor session | clean |
| `942-wifi-ath12k-fix-out-of-bounds-access-on-TX-stats-arrays` | ath.git c8f83d3389d1 | Pardeep Kaur | out-of-bounds write in TX completion stats (hot path, index from HW) | clean. Tested-on QCN9274 |
| `949-wifi-ath12k-correct-monitor-destination-ring-size` | 7.2.y e482f9ee9776 = mainline 913998f903fb | Aaradhana Sahu | monitor destination ring 8092 → 8192 (typo) | clean. Sits before 974 as upstream does; **974's context now needs 949** |

### Pending upstream (patchwork), tier adopt

| File | Source | Author | Fixes | Notes |
|---|---|---|---|---|
| `943-wifi-ath12k-convert-scan-timeout-to-wiphy-delayed-work` | [patchwork v4](https://patchwork.kernel.org/project/linux-wireless/patch/20260915065750.981425-1-runyu.xiao@seu.edu.cn/) | Runyu Xiao | **deadlock**: `mac_op_stop` (wiphy lock held) cancels the scan timeout work synchronously while that work waits for the wiphy lock. Cc stable | clean; `wiphy_delayed_work_*` exist in 7.2 |
| `944-wifi-ath12k-prevent-scan-during-firmware-recovery` | [patchwork v2 2/3](https://patchwork.kernel.org/project/linux-wireless/patch/20260804175004.1761075-3-jtornosm@redhat.com/) | Jose Ignacio Tornos Martinez | **SSR**: NULL dereference in `hw_scan` when a scan arrives during recovery; now -EBUSY | clean; works without 1/3 (test 982) |
| `945-wifi-ath12k-fix-NULL-dereference-in-hw-scan-cleanup-path` | [patchwork](https://patchwork.kernel.org/project/linux-wireless/patch/20260902010117.3225320-1-acelan.kao@canonical.com/) | Chia-Lin Kao (AceLan) | NULL `arvif->ar` in the `hw_scan` abort loop | **replaces round-1 923** (Quarx2k 962): same fix (`!ar` vs `!is_created`, which are set and cleared together); 945 is the version posted upstream and answered by the maintainer |
| `946-wifi-ath12k-fix-EHT-GI-reporting-in-monitor-mode` | [patchwork](https://patchwork.kernel.org/project/linux-wireless/patch/20260909081929.122174-1-rmxpzlb@gmail.com/) | Frank Zhang | EHT GI stored in `he_gi` (wrong radiotap/rates). Cc stable | clean, one line |
| `947-wifi-ath12k-release-QMI-handle-on-late-init-failures` | [patchwork v3 2/2](https://patchwork.kernel.org/project/linux-wireless/patch/20260718074026.3085688-3-lgs201920130244@gmail.com/) | Guangshuo Li | QMI handle leak on probe failure | clean |
| `948-wifi-ath12k-Reserve-space-for-a-string-terminator` | [patchwork 2/3](https://patchwork.kernel.org/project/linux-wireless/patch/20260926121250.3258285-3-yaojiale02@163.com/) | Jiale Yao | debugfs `htt_stats_type` over-read | clean; three Reviewed-by |

### Test tier

| File | Source | Author | Purpose | Notes |
|---|---|---|---|---|
| ~~`980`/`981` wake_tx_queue flow control (patchwork v7 2/4, 4/4)~~ | Jose Ignacio Tornos Martinez | | **dropped** after the code review: during firmware-crash recovery the new wake function reads the TCL ring through a freed `tp_addr` before `ieee80211_tx_dequeue()` honours the stopped queues; on an AP MLD it picks `assoc_link_id` (0) for non-MLO clients and can stall the TXQ. Not merged upstream |
| `982-wifi-ath12k-fix-MLO-station-firmware-crash-recovery` | [patchwork v2 1/3](https://patchwork.kernel.org/project/linux-wireless/patch/20260804175004.1761075-2-jtornosm@redhat.com/) | Jose Ignacio Tornos Martinez | keeps ATH12K_FLAG_RECOVERY until `reconfig_complete` and skips WMI to dead firmware during SSR | changes SSR timing for AP too; WCN7850 STA tested only. Context needs 932. Keep 983 with it |
| `983-wifi-ath12k-clear-recovery-flag-when-starting-a-hw-skipped-by-recovery` | new | Crescentm | follow-up to 982 | with 982, a crash while all interfaces are down left RECOVERY set forever (every scan -EBUSY via 944); clears it on OFF→ON start for radios whose firmware is up. Harmless without 982 |
| `984-wifi-ath12k-skip-connection_loss_work-for-MLO-beacon-miss` | [patchwork v2 3/3](https://patchwork.kernel.org/project/linux-wireless/patch/20260804175004.1761075-4-jtornosm@redhat.com/) | Jose Ignacio Tornos Martinez | MLO **STA** disconnected every ~16 s | STA only |
| `985-wifi-ath12k-set-STA-EHT-MU-mode-before-peer-assoc` | [patchwork](https://patchwork.kernel.org/project/linux-wireless/patch/20260915055117.546723-1-hangtian.zhu@oss.qualcomm.com/) | Hangtian Zhu | STA mode never set `WMI_VDEV_PARAM_SET_EHT_MU_MODE` before peer assoc | STA only, no review yet. If the firmware rejects the param, association aborts: delete 985 if STA mode stops associating |

### Changes to round-1 files

- `923-wifi-ath12k-skip-uncreated-links-on-scan-failure` **deleted**, replaced by 945 (see above).
- `979` (monitor ring size, first written as a test-tier slot because 974's
  context contained `8092`) moved to **949**; 974's context line was changed
  to `8192` and its note updated, so 974 now matches upstream.
- 953, 960, 970, 972, 974, 978: hunk line numbers refreshed; their `+`/`-`
  lines are byte-identical to before.

### Removal checks (full re-apply with `patch -F0` each time)

- Each of 970–978, 982–985 can be deleted on its own (some later patches then
  apply with an offset, never with fuzz), except: 975 → 976 → 977 as in
  round 1; 982 should keep 983.
- All of 970–985 can be deleted together.
- Adopt-tier dependencies: 933 and 934 need 928; 930 needs 929; 940 needs
  939; 974 (test) needs 949.

### Not taken (ath12k)

| Candidate | Why |
|---|---|
| 7.2.y f2dd3a8580 (ML-STA auth timeout), 3dfa1b8ccf (rx_mpdu_start layout) | QCC2072 only; no-op on QCN9274 |
| 7.2.y c78e691240, 39520ff5cd, 8d66010645 (QMI reserved memory refactor) | AHB/IPQ5332 only |
| mainline 58aeb41249 (MAC buffer ring 4096) | QCN9274 has `rx_mac_buf_ring = false`: no effect |
| mainline af50baccaa (DTIM stick mode for STA) | gated on `supports_sta_ps`, false on QCN9274 |
| mainline e264a3dbe8, 9d1d61121b, 4c09bbf0c1 | QCC2072 32-bit TLV refactors (925 adapted without them) |
| mainline 6c90f68f97 | big-endian only |
| ath-next Kang Yang monitor fixes 4dfe8e3ac7, d8e8eac3fc, 1a10a55855, 8b1d2f4c38, 97b144b82e, febe1f8cbc | only reachable with `rxdma1_enable = false` (WCN7850/QCC2072); QCN9274 uses the other monitor path. 69b2d06daf (941) is the one that touches QCN9274 state |
| ath-next 640240adbd | debugfs label cosmetics |
| ath-next stats/refactors, AHB multi-PD, IPQ5332 AP_VLAN, 06cca100ad (calibration variant: ImmortalWrt 700 already does it) | features/cleanups or other SoCs |
| patchwork 14625291 Revert "add panic handler" | the sleep-in-atomic comes from the WCN7850 MHI wakeup; QCN9274 has no wakeup op, and the panic handler is useful here |
| patchwork 14849207/8 (IDR mutation 4/5, 5/5) | changes requested, reviewers found a new UAF window |
| patchwork 14816407 (dp_peer on MLO reconnect) | rejected upstream |
| QRTR/MHI series | need net/qrtr and MHI core changes |

## hostapd and wifi-scripts

OpenWrt main versus ImmortalWrt `bf156b68e3` (content diff of
`package/network/services/hostapd` and `package/network/config/wifi-scripts`,
then `git log` for authorship): 14 OpenWrt commits are missing, all by Felix
Fietkau, all ported. OpenWrt did not bump `PKG_SOURCE_VERSION` (both on hostap
2.12 `831364bf02`), so instead the post-2.12 security/robustness fixes from
hostap.git main are backported as 900–917. With everything applied, the
hostapd package equals OpenWrt main except for our additions; ImmortalWrt's
own wifi-scripts changes (`vendor_vht`, `ssid=ImmortalWrt`, `disabled='0'`)
are kept, and 2de3225246 keeps `country='00'` on 6 GHz unless a provisioned
country exists (our wifi-scripts 951 still handles `00`).

### hostapd C patches → `overlay/package/network/services/hostapd/patches/`

| File | Source | Author | Fixes | Notes |
|---|---|---|---|---|
| `071-VLAN-increase-netlink-buffer-size` | OpenWrt main c071e440ba | Felix Fietkau | dynamic VLAN netlink socket overflows during reconfiguration bursts ("No buffer space available"), VLAN events lost | OpenWrt file name kept so it disappears on the next ImmortalWrt sync; hunk line numbers refreshed |
| `900-WNM-Fix-WNM-sleep-mode-support-for-larger-group-mana` | hostap 1faad63cd | Jouni Malinen | heap overflow with WNM sleep mode + BIP-GMAC/CMAC-256 | clean |
| `901-WNM-Fix-subelement-length-check-WNM-sleep-mode-exit` | hostap dd81452ef | Jouni Malinen | STA over-read on a malformed WNM sleep exit | clean |
| `902-WNM-Fix-group-key-parsing-from-WNM-sleep-mode-exit` | hostap a0528607c | Jouni Malinen | STA ignores BIGTK with 256-bit group management ciphers | needs 901 |
| `903-RADIUS-Fix-Message-Authenticator-attribute-validatio` | hostap aa02cfa56 | Jouni Malinen | 16-byte OOB read/write on a malformed RADIUS Message-Authenticator (crash) | clean |
| `904-AP-MLD-Use-a-larger-buffer-for-association-response` | hostap c64dce6da | Jouni Malinen | **MLO**: (Re)Assoc Response buffer too small for large MLEs | clean |
| `905-AP-MLD-Resize-the-temporary-buffer-for-MLE-construct` | hostap 8a5291522 | Jouni Malinen | **MLO**: MLE temporary buffer overflow | clean |
| `906-AP-MLD-Check-remaining-room-in-Key-Delivery-element-` | hostap 93ed7afaa | Jouni Malinen | **MLO**: Key Delivery element overflow with many links | clean |
| `907-Fix-PMKSA-entry-removal` | hostap e691ab4ce | Jouni Malinen | infinite loop in `pmksa_cache_remove()` (STA) | clean |
| `908-FT-Fix-off-by-2-buffer-bounds-check-in-wpa_ft_proces` | hostap fcae90b60 | Brandon Arrendondo | **802.11r**: 2-byte overwrite building an FT reassoc response with RIC | clean |
| `909-Fix-OOB-read-of-HE-Capabilities-optional-field-in-ge` | hostap 895fd5881 | Brandon Arrendondo | OOB read of HE caps from a malicious AP (STA) | clean |
| `910-EHT-Fix-OOB-read-in-hostapd_parse_link_reconf_req_st` | hostap 652a34915 | Brandon Arrendondo | **MLO**: 1-byte OOB read in ML reconfiguration requests | clean |
| `911-AP-Fix-OOB-read-of-STA-s-HE-MCS-map-in-check_valid_h` | hostap 6cf41afd5 | Brandon Arrendondo | OOB read of a short HE caps element on a 160 MHz AP | clean |
| `912-EAP-PEAP-server-Fix-SoH-vendor-specific-TLV-length-c` | hostap 4b5965e61 | Brandon Arrendondo | OOB read in the PEAP server SoH TLV | clean |
| `913-SAE-Make-sure-the-needed-state-is-available-in-sae_w` | hostap 0605d9ddc | Jouni Malinen | NULL use in SAE confirm error paths | clean |
| `914-AP-Avoid-NULL-as-snprintf-s-argument-for-BSS-transit` | hostap 9f6ee4d90 | Brandon Arrendondo | NULL `%s` in BSS-TM-QUERY | clean |
| `915-EAP-PEAP-server-Fix-NULL-deref-on-TLS-encrypt-failur` | hostap 0da59aadc | Brandon Arrendondo | PEAP server crash on resumed TLS 1.3 when encryption fails | clean |
| `916-nl80211-Update-AP-MLD-active_links-bitmap-during-sta` | hostap 4a9a301a2 | Manish Dharanenthiran | **MLO**: active_links not set on START_AP, link stop/remove works on a stale bitmap | clean |
| `917-nl80211-Add-FT-SAE-AKMs-to-the-fallback-key_mgmt-cap` | hostap 43ee60e13 | Wei Zhang | wpa_supplicant never selects FT-SAE on drivers without AKM lists (mac80211) | clean; STA |
| `930-AP-MLD-Break-the-mutual-ACS-deferral-between-partner` | [OpenWrt PR #25321](https://github.com/openwrt/openwrt/pull/25321) head 21956d2836 | Nilanka de Silva | **MLO + ACS**: with `channel=auto` on two or more links, each link defers to the other until the retry cap, then one link is disabled | renumbered from 361, unchanged |
| `931-AP-find-unassociated-MLD-stations-in-ap_get_link_sta` | [OpenWrt PR #24878](https://github.com/openwrt/openwrt/pull/24878) head aede7845d1 | Alexander Astrovsky | **MLO**: auth TX status of an MLD STA re-authenticating from a new link address is not matched, so WLAN_STA_AUTH is never set | renumbered from 195; `!is_zero_ether_addr` guard added as asked in review |
| `950-mesh-restart-peering-when-the-driver-lost-a-known-peer` | own work | Crescentm | see the mesh section | **test** |
| `980-AP-keep-the-configured-width-on-5-6-GHz-if-the-20-40` | own work | Crescentm | 5/6 GHz falls back to HT20 when the 20/40 coexistence scan cannot be requested (EBUSY retries exhausted; three radios share one wiphy) and `noscan` was cleared | **test**. On 5/6 GHz `check_40mhz_5g()` can only swap primary/secondary, never forbid 40 MHz, so skipping it equals `noscan=1`; 2.4 GHz keeps the HT20 fallback |

Removal: each of 900–931, 950, 980 can be deleted on its own, except 902
needs 901.

### Tree patches (`patches/tree/`)

| File | Source | Author | Fixes | Notes |
|---|---|---|---|---|
| `0012-hostapd-backport-DPP-fixes-from-OpenWrt-main` | OpenWrt main fcd9dbf534, 27b8aa25f8, 24723ba310 + [PR #25509](https://github.com/openwrt/openwrt/pull/25509) head 70927026ba | Felix Fietkau; Andrea Pesaresi | DPP GAS comeback via ucode; DPP answered on the wrong MLD link; chirp field misnamed; 27b8aa25f8 breaks the build without 802.11be (#25509) | four commits in one mbox |
| `0013-hostapd-backport-MLD-reconfiguration-fixes-from-OpenWrt-main` | OpenWrt main 79444dcc68, 4c6992b13b, 87623c1e67, 9a81bf528d, b833ad3511 | Felix Fietkau | **MLO**: MLD and BSSes torn down on SSID-level changes; duplicate BSSID on reload; radio-0 link without the MLD address (~30 % unicast loss); control socket not moved on rename; uninitialised rename result | the 2026-09-29 MLD batch |
| `0014-hostapd-backport-ubus-BTM-and-MBO-methods-from-OpenWrt-main` | OpenWrt main aa99fb89a0, 400c79e6b6 | Felix Fietkau | feature sync: `mbo_assoc_disallow`, BTM query answering, beacon_req channel reports (used by steering daemons) | can be dropped on its own; 0016 applies without it |
| `0015-wifi-scripts-backport-fixes-from-OpenWrt-main` | OpenWrt main 54a6f4ee1e, 2de3225246 | Felix Fietkau | "dpp is not present in the schema"; regdomain from the provisioning partition (survives factory reset) | clean against ImmortalWrt's `mac80211.uc` |
| `0016-hostapd-fix-memory-leaks-and-a-NULL-dereference-in-ubus-code` | [OpenWrt PR #25339](https://github.com/openwrt/openwrt/pull/25339) head ab8903a1a3 (4 commits) + local refresh | Matthew Cather; Crescentm | rfkill config leaked per interface; assoc frame taxonomy leaked per STA; BTM neighbour list leaked; NULL ubus ctx in VLAN teardown (crash) | 5th entry refreshes the line numbers of the package's 601/803 |
| `0017-wifi-scripts-fix-macaddr-random-on-MLO-interfaces` | [OpenWrt PR #24955](https://github.com/openwrt/openwrt/pull/24955) head 6d18f7aff8 | Kamil Bienkiewicz | `macaddr random` on an MLO iface: "Failed to create MLD … invalid MAC address" | Makefile bump dropped. The MLD address is redrawn on every reload (documented in the PR) |
| `0019-hostapd-bump-PKG_RELEASE` | own | Crescentm | hostapd 3 → 4, so our feed's hostapd differs from ImmortalWrt's | conflicts if ImmortalWrt bumps; then drop it |

wifi-scripts `PKG_RELEASE` is not bumped again: 0010/0011 already take it to 4.

### wifi-scripts → `patches/wifi-scripts/`

| File | Source | Author | Fixes | Notes |
|---|---|---|---|---|
| `952-wifi-scripts-use-SAE-WPA3-EAP-for-WPA2-only-6GHz-APs` | [OpenWrt PR #23914](https://github.com/openwrt/openwrt/pull/23914) head eb7da52137 + `wpa=2` | Michael Pfeifroth; Crescentm | 6 GHz AP refused with psk/eap/wpa/psk-mixed/wpa-mixed | **rewritten** (file name kept): the PR's code (`psk`/`psk-sae` → `sae`, `eap`/`eap-eap2` → `eap2`) replaces our round-1 code, plus `config.wpa = 2` on 6 GHz, because the PR alone still leaves `wpa=1/3` for psk-mixed/wpa/wpa-mixed ("Pre-RSNA security methods are not allowed in 6 GHz", and no PMF for wpa < 2). A mock run over all 13 encryption values gives sae/eap2 with wpa=2; `none` stays 0. If #23914 is merged, 952 shrinks to the wpa line |
| `953-wifi-scripts-fix-handling-for-0-dBm-TX-power-setting` | [OpenWrt PR #25479](https://github.com/openwrt/openwrt/pull/25479) head 9f2d64a219 | Shiji Yang | `txpower=0` became `auto` (full power) | Makefile bump dropped; #24637 is a duplicate |
| `954-wifi-scripts-fix-wdev-fallback-to-use-sprintf-instead-of-printf` | [OpenWrt PR #24621](https://github.com/openwrt/openwrt/pull/24621) e22c137bee | Alexander Astrovsky | wdev fallback (mesh without wpa_supplicant mesh support, monitor): only the last iface per radio is set up, stale ifaces never removed | |
| `955-wifi-scripts-fix-active_ifnames-for-OWE-transition-interfaces` | [OpenWrt PR #24621](https://github.com/openwrt/openwrt/pull/24621) 2589982754 | Alexander Astrovsky | OWE transition ifname missing from the wdev keep list | needs 954 |

### Not taken (hostapd / wifi-scripts)

| PR / commit | Why |
|---|---|
| #23181 (defer FT key upload) | mac80211 change that deliberately leaves `SW_CRYPTO_CONTROL` drivers (ath10k/11k/12k) unchanged, so no effect on ath12k; patchwork state "Deferred" (Johannes wants the SMD work first). Its hostapd half only makes sense with it |
| #24880 (MLO mgmt_tx link STA lookup) | mac80211; review found that dropping the `mlo_sta` gate sets link_id=0 on non-MLD vifs and hits a WARN_ON; no update since 09-02 |
| #24649 | the MBO uninitialised-value bug is already fixed in bf156b68e3 |
| #24891 | review: silently drops the `wpa_auth_sta_no_wpa()` call |
| #24879 | changes the EAPOL PAE state machine, many revisions |
| #24970 | out-of-bounds only when no ≤80 MHz MCS map matches; low value |
| #24889 | legacy shell `hostapd.sh`, unused with ucode |
| #25349 | unreviewed hardening of common.uc/ap.uc, which 950/952 also patch |
| #24670, #25337, #24641, #23889, #24899, #23860 | feature, performance, default-behaviour change, STA cipher pinning, open review questions, conflicts with 0011 |
| hostap af4da04e5 (RSNXE in per-STA profile) | does not cherry-pick onto this series |
| hostap 97494e94e (MLD inactivity across links) | needs a kernel attribute backports 7.2 lacks; on an older kernel the `NLM_F_DUMP` fallback could read another station's data |

## Round 2: hardware test checklist

Use the initramfs image first. Before anything else, check that `dmesg` has
no new WARN/BUG and that `logread` has no hostapd crash on a plain
three-radio AP setup. Then, roughly in order of risk:

1. **Bring-up and stop/start** (subsys 918, 930; ath12k 926, 939, 940, 943,
   947): all three radios come up; `wifi down; wifi up` 20 times; run
   `iw dev <ap> scan` and `wifi down` at the same moment (943 deadlock).
2. **Multicast in Ethernet-encap mode** (ath12k 928, 933, 934; subsys 960):
   IPTV/mDNS/iperf UDP multicast to MLO and non-MLO clients; frames go out on
   every link; no `skb copy/clone failure`. If multicast breaks, test without
   928+933+934 first.
3. **MLO AP** (2.4+5+6 MLD) with an MLO client, plus a non-MLO SSID on 6 GHz
   (ath12k 927, 931, 932; hostapd 904–906, 910, 916, 931, tree 0013):
   many associate/disassociate cycles, no "Timeout in receiving peer delete
   response"; change the SSID or add a BSS and `wifi reload`: the client
   stays associated, no "Duplicate BSSID"/"Restart interface"; link 0's
   address equals the MLD address. `channel=auto` on 2–3 links (hostapd 930):
   all links come up within 1–2 min. `macaddr random` on an MLO iface (0017).
4. **SSR** (ath12k 926, 934, 944, 945; test 982+983):
   `echo assert > /sys/kernel/debug/ath12k/*/simulate_fw_crash` with traffic
   and an MLO client, and once with all WiFi down followed by `wifi up`;
   scans work afterwards; `iw scan` in a loop during recovery does not oops.
5. **6 GHz security** (wifi-scripts 952): psk2, psk-mixed, wpa2 and eap on
   6 GHz each come up as SAE/WPA3-EAP with `wpa=2`, `ieee80211w=2` in
   `/var/run/hostapd-phy*.conf`. `txpower 0` shows 0.00 dBm (953).
6. **Mesh** (subsys 917, 926, 929, 930, 933, 939, 948, 949, 952; test 970;
   hostapd test 950): 6 GHz SAE mesh to another node; "new peer notification"
   at most once per peering attempt; peer reaches ESTAB. Mesh on 5 and 6 GHz
   with the same mesh ID: each mesh interface lists only peers of its own
   band (970). `iw dev <mesh> station del <peer>` while up: one
   "lost its driver entry - restart peering", re-peers in seconds (950).
   Leave the mesh during a channel switch (917/929).
7. **Dynamic VLAN / WDS** (subsys 915, 923, 959; test 980; hostapd 071,
   tree 0016): RADIUS-assigned VLANs and a 4addr client; `wifi down/up`
   cycles; no "No buffer space available"; a station in VLAN A does not get
   unicast sent on VLAN B (959). Also try VLANs on an MLO AP (subsys 980).
8. **20/40 coexistence** (hostapd test 980): clear `noscan` on 5 GHz with
   HT40/VHT80, start all radios together: log shows "keeping the configured
   channel width" and `iw dev` shows 80 MHz, not 20.
9. **TX under load** (ath12k 936, 937, 942): iperf TCP/UDP with many
   clients; note any "failed to transmit frame" (980/981 flow control was
   dropped, so some drops under overload are expected).
10. **Enterprise / 802.11r** (hostapd 903, 908, 912, 915, 917): WPA-EAP with
    RADIUS and with the internal EAP server (PEAP); FT roaming between two
    APs, including FT-SAE with a wpa_supplicant client.
11. **Monitor mode** on a QCN9274 radio (ath12k 924, 925, 929, 930, 941, 946,
    949; subsys 922, 934, 943, 962): capture EHT traffic 10+ minutes, check
    radiotap GI, no slab growth; stop/start the monitor.
12. **STA mode** (subsys 904, 942, 944, 945, 961, 964; ath12k test 984, 985):
    QCN9274 as a client of an EHT AP; if association fails after "failed to
    submit vdev param eht txbf", delete 985; MLO client for 5 minutes
    without periodic disconnects (984).
13. **Stable-only items**, no special test: netns (935–937), TDLS
    (920, 924), IBSS (914, 938, 941), FILS (954), minstrel (953, 956).

## Round 2: not done / open

- **Mesh flood root cause** not confirmed: no logs beyond one line. 970 and
  950 cover two proven gaps (E, C); cause A (peering never completes on
  6 GHz) needs a debug log and a 6 GHz capture from an affected user.
- **#23181 (defer FT key upload), #24880 (MLO mgmt_tx link STA)**: not
  taken (no effect on ath12k / unresolved review bug), see above.
- **mac80211 8ff047b9c7, f4e72e3758, f13e573ab3** not taken (behaviour
  change / restructuring / no ath12k effect).
- **ath12k mailing-list items** in the adopt tier (943–948) are not merged
  upstream yet; drop or replace them when the final versions land.
- **OpenWrt hostapd sync**: 071 and tree 0012–0017 are OpenWrt main / PR
  content; when ImmortalWrt merges them, delete the matching files (tree
  patches will stop applying, which is the signal).
- `PKG_RELEASE` of mac80211 is still not bumped (kmods change with the
  kernel version anyway); hostapd is bumped to 4 (0019).
- No hardware test yet.

## wifi-scripts 956: load the wireless config written at first boot

Found on the round 2 RAM boot (2026-10-01): on a fresh install no radio
came up until `wifi up`. `/etc/config/wireless` is written by the
ieee80211 hotplug handler after netifd has started, and
`network.wireless retry` only retries devices netifd already knows.
956 reloads netifd when `wifi config` changed the file. Tested on the
RAM boot by deleting the config and running the new handler: 0 → 3
radios up; a second run with no change does not reload. Same code in
OpenWrt main (`10-wifi-detect`), not reported upstream yet.

## Code review before the third RAM boot (2026-10-01)

Read-only reviews of all WiFi patches against the patched trees and
upstream (stable 7.2.y, mainline, wireless.git, ath.git, patchwork,
hostap.git, OpenWrt main and PRs). Every adopted patch matched upstream
or was traced as equivalent. Changes made:

- **ath12k 980/981 dropped** (see the table): use of a freed ring pointer
  during firmware-crash recovery, wrong link on an AP MLD, and the series
  is not merged upstream.
- **ath12k 983:** when the hw is off during a crash, reconfig_complete
  never runs, so `is_reset`/`reset_count` stayed set and every later
  crash waited 20 s and counted as failed; 983 now does that bookkeeping.
- **ath12k 943:** the hw_scan abort and remove_interface paths now also
  cancel `scan.timeout`.
- **subsys 970:** also drops mesh peering action frames and probe
  requests received on another radio's channel, not only beacons.
- **wifi-scripts 952:** TKIP is removed from `wpa_pairwise` on 6 GHz, so
  `psk2+tkip` style configs come up as well.
- **Notes corrected:** subsys 980 does not break dynamic VLAN on an MLD.

Known and left as is:
- wifi-scripts 950 remaps the radio index only in `mac80211.sh`; netifd
  and the hostapd MLD radio mask still use the configured index. With
  ath12k 920 the radio order is fixed, so no remap happens on this board.
- hostapd 950 (mesh stale peer restart) has no rate limit; no code path
  that would make it loop was found.
- ath12k 978 has no fallback to DMA chunks if a reserved region is too
  small (check the boot log for "host-ddr-mem too small" / "no
  mlo-global-mem").
