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
