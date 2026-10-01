# Platform and kernel patches

Kernel, PPE/EDMA, PHY and DTS changes for the SBE1V1K. They sit on top of
ImmortalWrt master `bf156b68e3` plus `tree/0001`–`0002`. Status checked on
2026-10-01.

| Item | Files |
|---|---|
| K1 kernel 6.18.54 | `tree/0003-kernel-bump-6.18-to-6.18.54.patch` |
| K2 EDMA Rx skb reuse | `overlay/target/linux/qualcommbe/patches-6.18/0410-net-ethernet-qualcomm-ppe-fix-freed-skb-reuse-in-rx-reaping.patch` |
| K3 NAPI budgets | `overlay/.../patches-6.18/0363-net-ethernet-qualcomm-honor-safe-NAPI-budgets.patch` |
| K3 NAPI disable hang | `overlay/.../patches-6.18/0411-net-ethernet-qualcomm-ppe-track-NAPI-enable-state.patch` |
| K4 port init unwind | `overlay/.../patches-6.18/0412-net-ethernet-qualcomm-ppe-fix-port-init-unwind.patch` |
| K5 MTU validation | `overlay/.../patches-6.18/0413-net-ethernet-qualcomm-ppe-validate-MTU-before-applying-it.patch` |
| K6 RPS / IRQ spread | `overlay/.../patches-6.18/0414-net-ethernet-qualcomm-ppe-fix-RPS-and-IRQ-distribution.patch` |
| L1 WAN LEDs | `overlay/target/linux/generic/hack-6.18/744-net-phy-realtek-add-rtl826x-led-support.patch`, `tree/0004-sbe1v1k-dts-wan-phy-leds.patch`, `overlay/target/linux/qualcommbe/ipq95xx/base-files/etc/board.d/01_leds` |
| T2a lan1 2500base-x (test) | `tree/0005-sbe1v1k-dts-lan1-2500base-x.patch` |
| T2b QCA8081 hibernation off (test) | `overlay/.../patches-6.18/0415-net-phy-qca808x-disable-hibernation-on-QCA8081.patch` |

`overlay/.../patches-6.18` means `overlay/target/linux/qualcommbe/patches-6.18`.
Those patches apply after the existing 0350–0362 and 0400–0403, in name
order. 0363 lands right after 0362.

## K1: kernel 6.18.52 → 6.18.54

- **Source:** OpenWrt `411a8112dd` "kernel: bump 6.18 to 6.18.53" and
  `142619bac5` "kernel: bump 6.18 to 6.18.54". Both are by Edoardo Pinci
  and were merged by Hauke Mehrtens in
  [openwrt/openwrt#25331](https://github.com/openwrt/openwrt/pull/25331)
  on 2026-09-30.
- **Port:** both commits are applied with `git apply --3way` on
  `bf156b68e3`. Everything applies except one deletion:
  `generic/backport-6.18/895-v7.2-Bluetooth-btusb-Add-Mercusys-MA530-…`. It
  went upstream in 6.18.53, and ImmortalWrt never carried it, so it is
  excluded. The patch touches every 6.18 target, not just qualcommbe,
  exactly as upstream does.
- **ImmortalWrt-only patches:** `make target/linux/{clean,prepare} V=s`
  applied all 509 generic and qualcommbe patches without fuzz. Only
  `generic/backport-6.18/705-02-v6.19-net-phy-motorcomm-Add-support-for-PHY-LEDs-on-YT8531.patch`
  applied at offset -1, and its quilt refresh is included in 0003. Nothing
  else needed a refresh.
- **Hash:** `LINUX_KERNEL_HASH-6.18.54 = 9df30b02…eacac` matches the
  sha256 of `linux-6.18.54.tar.xz` from cdn.kernel.org, checked by hand.
  The toolchain's kernel-headers build then unpacked that tarball.
- **Risk:** low. This is a stable update that OpenWrt has merged.
- **Upstream:** merged in OpenWrt main. Drop 0003 once ImmortalWrt master
  merges it.

## K2: 0410 EDMA Rx freed-skb reuse (double free)

- **Source:** [openwrt/openwrt#24191](https://github.com/openwrt/openwrt/pull/24191),
  head `0611091dd2` (hurrian/openwrt-w1700k `ppe-skb-fix`). Author
  Kenneth Kasilag (hurrian). Copied verbatim, and quilt left it unchanged.
- **Fixes:**
  - `edma_rx_reap()` only reloaded `next_skb` on the delivery paths. A frame
    from an unmapped source port was freed, and its skb was then processed
    again as the next descriptor's buffer: a double free, or a freed skb
    passed up the stack.
  - The page-mode last segment wrote `ip_summed` through a freed skb.
  - A linear skb that failed `pskb_may_pull()` was freed twice.
- **Risk:** low. The change is small and keeps the existing loop structure.
- **Upstream:** the PR is open.

## K3a: 0363 honor safe NAPI budgets

- **Source:** [openwrt/openwrt#25405](https://github.com/openwrt/openwrt/pull/25405),
  head `40005c1753` (Jackie264). Author Yang Zhengguo, also signed off by
  Jackie Han. Copied verbatim. The filename 0363 was free, since
  ImmortalWrt stops at 0362.
- **Fixes:** NAPI was registered with fixed `edma_hw_info` weights. Tx used
  512, more than `NAPI_POLL_WEIGHT`, which makes the core warn, and the
  validated module parameters were ignored. The patch registers the module
  parameters and caps both budgets at 64.
- **Risk:** low. Each Tx completion poll handles at most 64 descriptors
  instead of 512.
- **Upstream:** the PR is open.

## K3b: 0411 track NAPI enable state (double `napi_disable()` hang)

- **Source:** our own patch (Crescentm). The bug was reported in
  [openwrt/openwrt#24209](https://github.com/openwrt/openwrt/pull/24209)
  (Xiaomi BE7000), whose `0900-net-qcom-ppe-fix-napi-disable-hang` by
  Timofey Maykov skips `napi_disable()` when `NAPI_STATE_SCHED` is set. The
  reviewer pointed out that this test is fragile: SCHED is also set while
  an enabled NAPI is scheduled, which would skip a needed disable. It is
  credited with `Reported-by`.
- **Fix:** each Rx and Tx-completion ring now has a `napi_enabled` flag:
  - enable runs only when the ring is added and not yet enabled;
  - disable runs only when the ring is enabled;
  - delete disables only an enabled ring, then calls `netif_napi_del()`.
- **Hangs fixed:**
  - `edma_cfg_rx_napi_disable()` followed by `edma_cfg_rx_napi_delete()`,
    in both the `edma_hw_configure()` error path and `edma_destroy()`;
  - Tx NAPI deleted after `ndo_stop`, or never enabled, in
    `edma_port_destroy()` and in the `edma_port_setup()` error path.
- **Port teardown order:** `edma_port_destroy()` now calls
  `unregister_netdev()` first, then destroys phylink, the rings and NAPI,
  and the stats, and calls `free_netdev()` last. It used to free the
  per-CPU stats and disable the rings while the netdev could still
  transmit, and it destroyed phylink after `free_netdev()`.
- **Risk:** low. Only the probe-failure and remove paths change. On the
  normal open/close path the guards only prevent double calls.
- **Upstream:** none. It is suitable for the qualcommbe PPE series.

## K4: 0412 port init unwind

- **Source:** PR #24209 `0902-net-qcom-ppe-fix-port-unwind` by Timofey
  Maykov. Author kept, with an extension noted in the patch.
- **Fixes:** after an EDMA port setup failure, `i` became -1, and the
  `while (i)` clock loop then walked `port[-2]`, `port[-3]` and so on (an
  oops). The extension also unwinds the ports already set up after a DT
  `reg`/phy-mode, clock or MAC init failure. Before, those left registered
  netdevs behind a failed probe, in a devm-freed array. It also releases
  the clocks of the failing port.
- **Risk:** low. Error paths only.
- **Upstream:** PR #24209 is open, and its 0902 covers only the
  EDMA-setup case.

## K5: 0413 MTU validation (our own)

- `edma_port_change_mtu()` set `netdev->mtu` before
  `ppe_port_set_maxframe()` validated it, so a rejected MTU stayed
  visible to the stack. It now programs the hardware first and then calls
  `WRITE_ONCE(netdev->mtu, mtu)`.
- `max_mtu` was `ETH_MAX_MTU`. The driver adds `ETH_HLEN` to the MTU and
  requires the result to be at most `PPE_PORT_MAC_MAX_FRAME_SIZE -
  ETH_FCS_LEN`. No VLAN allowance is added anywhere in the driver, so the
  real limit is 0x3000 − 14 − 4 = **12270**. `PPE_PORT_MAC_MAX_FRAME_SIZE`
  moved to `ppe_port.h`, and `PPE_PORT_MAX_MTU` was added.
- **Not changed:** the PPE MTU/MRU is still MTU + 14, so a VLAN tag is not
  counted. That is the existing driver behaviour.
- **Risk:** very low.
- **Upstream:** none.

## K6: 0414 RPS and IRQ distribution

- **Source:** Dedrimer/SBE1V1K `testing`
  [`3ee40aeeec`](https://github.com/Dedrimer/SBE1V1K/commit/3ee40aeeec0b3f1b0ccb2a32dee2e85af8ce4a11)
  `0563-…-fix-rps-and-irq-distribution.patch`. Author Dedrimer, kept, with
  the changes listed in the header.
- **Fixes:**
  - The `net.edma.rps_bitmap_cores` sysctl was ignored, because the hash
    map was always built from `EDMA_RX_DEFAULT_BITMAP`. The map is now
    built from the sysctl's bits.
  - Every rxdesc and txcmpl IRQ sat on CPU0, as seen on the router.
- **IRQ placement:** Rx ring *i* gets the queues of core *i*, because
  QID2RID maps queue group *i* to ring 20+*i*. Tx completion ring *i*
  serves CPU `i % num_possible_cpus()`, the same formula as
  `edma_cfg_tx_napi_add()`. Dedrimer used the absolute ring id modulo 4.
  That gives the same result here (ring_start 20 and 8), but it is fragile.
- **Decision, `irq_set_affinity_and_hint()` once after all IRQs are
  requested:** it sets the effective affinity and publishes
  `/proc/irq/N/affinity_hint`. The driver never re-applies it, so it does
  not fight irqbalance. irqbalance ≥ 1.8 ignores hints, so it may still
  move the IRQs. The hint is cleared with `irq_update_affinity_hint(irq,
  NULL)` before `free_irq()`.
  - Not `irq_update_affinity_hint()` alone: that only publishes the hint
    and leaves every IRQ on CPU0 unless something acts on it.
  - Not managed affinity (`IRQD_AFFINITY_MANAGED`): that would forbid moving
    the IRQs at all.
- **Risk:** low. A failure to set affinity is only a warning.
- **Upstream:** none. Dedrimer's testing branch only.

## L1: WAN LED (RTL8261BE)

- **Driver:** `generic/hack-6.18/744-net-phy-realtek-add-rtl826x-led-support.patch`.
  - Source: hurrian/openwrt-w1700k
    [`274fa5f99f`](https://github.com/hurrian/openwrt-w1700k/commit/274fa5f99f02c154712ba2e178fdb97cde85d242),
    author Kenneth Kasilag. Upstream it was `hack-6.18/743`. OneNAS
    `b6fc7b1f43` carries the same patch.
  - Renumbered to 744 so it applies after ImmortalWrt's
    `pending-6.18/742` and `743`; hack applies after pending in any case.
    The code is unchanged and was only refreshed for offsets.
  - It adds `led_hw_is_supported`, `led_hw_control_get` and
    `led_hw_control_set` to every rtl826x-family entry: RTL8251L, RTL8254B,
    RTL8261BE, RTL8261N, RTL8264 and RTL8264B. It uses the VEND1 21+2n/22+2n
    register pair, up to 6 LEDs.
  - No helper is duplicated. The existing `rtl8261x_led_*` helpers
    (pending 721-02, RTL8261C/D) program a different register block, VEND2
    0xd032+ and LCR6/7, so they cannot be reused.
  - The patch has no `led_brightness_set`, so these LEDs can only be driven
    by offloaded netdev rules. Every rule set used in 01_leds is
    offloadable.
- **DTS:** `tree/0004-sbe1v1k-dts-wan-phy-leds.patch` adds `leds{}` under
  `rtl8261be_0`: led@0 amber/WAN and led@1 green/WAN, from hurrian
  `4824815669`.
- **board.d:** ImmortalWrt has no ipq95xx `01_leds`, so it is a new
  overlay file. Its content comes from hurrian 4824815669 / OneNAS
  b6fc7b1f43:
  - `lan1:green`: link_2500 / link_1000 + tx/rx
  - `lan1:yellow`: link_1000 / link_100 + tx/rx
  - `wan:green`: link_10000 / 5000 / 2500 + tx/rx
  - `wan:amber`: link_1000 / link_100 + tx/rx

  The lan1 LEDs already exist in the DTS: QCA8081 led@0 yellow, led@2
  green, active-low.
- **QCA8075 (lan2/lan3) LEDs: not added.** The mainline qca807x driver can
  do it (2 LEDs per PHY, MMD7 0x8074+, hw control up to 1000M, polarity
  through the shared qca808x helpers). However, none of the SBE1V1K
  sources show how the lan2/lan3 LEDs are wired: hurrian, OneNAS,
  yangzhg/Jackie264, the NSS/QSDK tree and our local trees give no LED
  index, colour or polarity. qca807x LED pins can also be GPIOs. Guessing
  could light the wrong LED or drive a pin used for something else. Add
  them once the stock SSDK LED configuration or a board photo or probe
  shows the wiring.
- **Risk:** low for boards without LED nodes, since nothing changes. On the
  SBE1V1K the RTL826x register map comes only from hurrian's work. It
  could not be checked against a datasheet; the Realtek SDK copies (TIP
  wlan-ap rtk) have no LED code. hurrian ships it on this board.
- **Upstream:** not in OpenWrt or ImmortalWrt.

## T2a: 0005 lan1 phy-mode `usxgmii` → `2500base-x` (test item)

- **Driver facts checked in the 6.18.54 tree:**
  - qca808x fills `possible_interfaces` with SGMII and 2500BASEX only.
  - `qca808x_read_status()` sets `phydev->interface` to 2500BASEX at 2.5G
    and SGMII otherwise.
  - phylink, in INBAND mode with a PHY, follows `phy_state.interface` and
    does a major reconfig. So on link-up the PCS already runs SGMII or
    2500BASE-X today, and `usxgmii` only selected the pre-link
    configuration, including the USXGMII/XPCS PLL bring-up from 0357–0361.
- **PCS (`pcs-qcom-ipq9574`):** 2500BASEX is supported: PCS_MODE_2500BASEX,
  MISC2 SGMII_PLUS, 312.5 MHz. `pcs_inband_caps` returns
  LINK_INBAND_DISABLE for 2500BASEX and DISABLE|ENABLE for SGMII.
- **PPE:** 2500BASEX is in `mac_interfaces[]` and selects XGMAC; SGMII
  selects GMAC.
- **In-band setting:** `managed = "in-band-status"` stays. Per
  `phylink_pcs_neg_mode()`:
  - 2500BASEX with a PHY whose `inband_caps` are unknown resolves to
    PHYLINK_PCS_NEG_OUTBAND / MLO_AN_PHY without a warning;
  - SGMII keeps in-band AN, as it does now.

  The 8devices Kiwi uses `2500base-x` on the same uniphy1/port 5 without
  `managed`. Both work.
- **Not used on this board:** uniphy1 has no `qcom,uniphy-clkout-25mhz`, so
  nothing depends on the USXGMII bring-up path.
- **Risk:** low to moderate. In the worst case lan1 does not come up, and
  wan, lan2 and lan3 are unaffected. Test with the initramfs (RAM boot)
  first: link at 2.5G and 1G, and plug/unplug cycles.
- **Upstream:** not upstream.

## T2b: 0415 QCA8081 hibernation off (test item)

- **Register:** `QCA808X_DBG_AN_TEST` (debug register 0xb), bit 15
  `QCA808X_HIBERNATION_EN`. This is the same register and bit that
  mainline `qca808x_cable_test_start()` clears.
- **Where:** the patch clears it in `qca808x_config_init()`, the QCA8081
  entry only. QCA8084 has its own `config_init`. The driver is built in
  (`CONFIG_QCA808X_PHY=y`) and already carries the qualcommbe 0302–0312
  changes, so the patch lives in the qualcommbe target rather than
  generic/hack. `config_init` runs again after soft reset, after resume,
  and after a cable test.
- **Risk:** low. The cost is a little idle power on an unplugged lan1. It
  is a test item for lan1 link-detect behaviour.
- **Upstream:** none. at803x has the opt-in `qca,disable-hibernation-mode`
  for AR803x. A DT-gated version would be the upstreamable form.

## Validation

Run on 2026-10-01 in a separate worktree of ImmortalWrt `bf156b68e3`, with
everything in this repo applied, including the WiFi agent's
0006/0010/0011 and the mac80211 patches:

- **`STAGE=prepare`:** OK. All overlay files are copied and every tree,
  mac80211 and wifi-scripts patch applies.
- **`make target/linux/{clean,prepare} V=s`:** all patches apply, none
  with fuzz or offset.
- **`make target/linux/compile -j16 V=s`:** OK.
  - Kernel 6.18.54, `vmlinux`, all modules.
  - 0 compiler warnings in the whole log, and none in `qualcomm/ppe`,
    `phy/realtek`, `phy/qcom` or `pcs`.
- **`make package/kernel/linux/compile -j16`:** OK.
  - Produced `kmod-qcom-ppe-6.18.54-r1.apk`, `kmod-phy-realtek-6.18.54-r1.apk`
    and `kmod-pcs-qcom-ipq9574-6.18.54-r1.apk`.
  - `qcom-ppe.ko` has vermagic 6.18.54 and contains the new affinity code.
  - `realtek.ko` exports `rtl826x_led_hw_*`.
  - qca808x is built in (`=y`) and compiled into `vmlinux`.
- **DTB:** built with the same cpp + dtc command and flags as
  `Image/BuildDTB` in `include/image.mk`, then decompiled.
  - The RTL8261BE node has `leds { led@0 amber "wan"; led@1 green "wan" }`.
  - port@5 has `phy-mode = "2500base-x"`.
  - The dtc warnings are identical with and without 0004/0005: the
    existing `mmc card@0` reg ones only.
- **`checkpatch.pl` on 0411–0415:** clean.
