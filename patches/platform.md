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
| T2a lan1 SGMII (test) | `tree/0005-sbe1v1k-dts-lan1-sgmii.patch` |
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
  do it (2 LEDs per PHY, MMD7 0x8074+, hw control up to 1000M; it has no
  polarity op). However, none of the SBE1V1K
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

## T2a: 0005 lan1 phy-mode `usxgmii` → `sgmii` (test item)

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
- **Initial mode and in-band:** `sgmii`, keeping `managed = "in-band-status"`.
  Two earlier versions failed on hardware (RAM boot, 2026-10-01), each
  with a 1G Mac adapter on lan1 while a 2.5G NAS worked:
  - `2500base-x` + in-band (round 1, also on the eMMC install):
    `phylink_fwnode_phy_connect()` returns early for an in-band 802.3z
    port (`phylink_expects_phy()` is false), so lan1 had no phydev. The
    PHY moved its SerDes to SGMII at 1G; the MAC stayed in 2500BASE-X.
    No link on lan1, no LED.
  - `2500base-x` without `managed`: the PHY is attached
    (`configuring for phy/2500base-x`), phylink follows it to SGMII and
    the link comes up at 1G, but without in-band AN on the SGMII side:
    11 frames sent, 0 received, no DHCP.
  - `sgmii` is not 802.3z, so the PHY is attached; SGMII keeps in-band
    AN as with the original `usxgmii`; at 2.5G the PCS reports
    LINK_INBAND_DISABLE for 2500BASEX, so phylink uses out-of-band
    status there.

- **Not used on this board:** uniphy1 has no `qcom,uniphy-clkout-25mhz`, so
  nothing depends on the USXGMII bring-up path.
- **Risk:** low to moderate. In the worst case lan1 does not come up, and
  wan, lan2 and lan3 are unaffected. Test with the initramfs (RAM boot)
  first: link at 2.5G and 1G (both must pass traffic), and plug/unplug
  cycles. `ls /sys/class/net/lan1/phydev` must exist.
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
  - port@5 has `phy-mode = "sgmii"` (was `2500base-x` in round 1).
  - The dtc warnings are identical with and without 0004/0005: the
    existing `mmc card@0` reg ones only.
- **`checkpatch.pl` on 0411–0415:** clean.

## K6 follow-up: irqbalance

Tested on hardware (RAM boot): the driver set the per-ring hints correctly,
but irqbalance then rewrote every EDMA IRQ affinity to `0-3`. It does not
know the class of these platform IRQs, places them at cache-domain level
(all four Cortex-A73 cores share the L2), and the GIC delivers a `0-3`
IRQ to CPU0. `irqbalance --banmod=qcom_ppe` does not help: irqbalance
cannot map platform IRQs to a module. Banning them by number works, and
irqbalance still spreads the ath12k `ce*` IRQs.

`files/etc/init.d/sbe1v1k-irq` (START=89, before irqbalance) collects the
`rxdesc_*`/`txcmpl_*` IRQ numbers from `/proc/interrupts` and stores them as
`irqbalance.irqbalance.banirq`, writing the config only when the list
changes. Verified: after 30 s of irqbalance, rxdesc_20..23 stay on CPU0..3.

# Round 2

Added on 2026-10-01, on the same base (ImmortalWrt `bf156b68e3`, kernel
6.18.54, round 1 applied). New project rule: fix what can be fixed even
for features this board's owner does not use. Risky changes are "test"
items: each is its own file and can be deleted without touching the
others.

| Item | Tier | Files |
|---|---|---|
| R1 watchdog bootstatus | fix | `overlay/.../patches-6.18/0416`–`0420` |
| R2 PCIe Root Port reset on link down | dropped | was `overlay/.../patches-6.18/0421`–`0424` |
| R3a PPE egress drain on link down | test | `overlay/.../patches-6.18/0425` |
| R3b PPE multicast DRR slots | test | `overlay/.../patches-6.18/0426` |
| R3c EEE off at the PHYs | test | `overlay/.../patches-6.18/0427` |
| R4a phylink link_state init | fix | `overlay/.../patches-6.18/0428` |
| R4b phylink PCS validation | fix | `overlay/.../patches-6.18/0429` |
| R4c qca808x active-high LEDs | fix | `overlay/.../patches-6.18/0430`, `0431` |
| R4d MP5496 supply names | fix | `overlay/.../patches-6.18/0432` |
| R4e thermal step_wise stale vote | fix | `overlay/.../patches-6.18/0433` |
| R4f dtc warnings | fix | `tree/0030-sbe1v1k-dts-fix-dtc-warnings.patch` |
| R5 fan PWM 1 kHz | dropped | was `tree/0032-sbe1v1k-dts-fan-pwm-1khz.patch` |
| R6 rtpengine kmod on 6.18 | fix | `overlay/feeds/telephony/net/rtpengine/patches/105-kernel-module-use-ccflags-y-instead-of-EXTRA_CFLAGS.patch` |
| R8 lan2/lan3 LEDs | test | `tree/0031-sbe1v1k-dts-lan2-lan3-phy-leds.patch`, `overlay/.../ipq95xx/base-files/etc/board.d/01_leds` |

All the new kernel patches sit in the qualcommbe target directory, even
the generic ones (phylink, thermal, PCI core). Some of them were adapted
to code that only exists after the qualcommbe series (qca808x QCA8084
changes) or after `pending-6.18/737-*` (phylink), and the target
patches are applied last.

## R1: watchdog bootstatus (0416–0420)

- **Symptom:** after a watchdog reset `bootstatus` is 0. qcom-wdt only
  looks at `WDT_STS.EXPIRED_STATUS`, which is already clear when Linux
  boots.
- **0416–0419:** mainline, unchanged, in the order merged:
  - `158dd300b07b` "add support to get the bootstatus from IMEM" (v7.2)
  - `0595f74ea1d3` "report WDIOF_POWERUNDER in bootstatus"
  - `6a393b0ea3cc` "report bootstatus on IPQ9574 and IPQ5332" (IPQ9574:
    1 = watchdog → `WDIOF_CARDRESET`, 32 = power-on → `WDIOF_POWERUNDER`)
  - `2bab791e56d9` "Propagate errors from optional IRQ lookup", a probe
    fix merged with them.

  After 0416–0419 `qcom-wdt.c` is identical to mainline master.
- **0420 (ours):** the IPQ9574 IMEM node and `sram = <&restart_reason>`
  on the watchdog.
  - The IMEM node is Kathiravan Thirumoorthy's "ipq9574: Add the IMEM
    node" v3 5/6, unchanged. It is "changes requested" upstream because
    the reviewers want the IMEM binding posted complete; the node itself
    was not criticised. Nothing newer than v3 exists for IPQ9574.
  - The child node and property follow his IPQ5424 patch (v11 3/3, in
    linux-next).
  - Offset 0x7a4: QSDK 12.x `ipq9574.dtsi` has
    `restart-reason-buf-addr@7a4` in the IMEM at 0x08600000, and its
    `qti_scm_restart_reason.c` decodes 0x1 as NON_SECURE_WATCHDOG and
    0x20 as POWER_ON_RESET, the values mainline uses for IPQ9574.
- **Safety:** the driver only `ioremap()`s and reads 4 bytes at probe.
  `CONFIG_SRAM` is not enabled, so nothing else binds the node. If the
  word holds anything else, bootstatus stays 0. Without 0420 the driver
  falls back to the old check. The watchdog itself is unchanged.
- **Upstream:** 0416–0419 merged; the IPQ9574 DTS part is not posted.

## R2: PCIe Root Port reset after link down (0421–0424, dropped)

Dropped after the code review of 2026-10-01, before any hardware test.
On the frozen path `pcie_do_recovery()` always resets the subordinates,
which with 0423 means a full controller deinit/init with PERST#. ath12k
does a SoC global reset on every power-up and in firmware-crash
recovery, and its own code warns that the link can drop then. A root
port reset under a radio that is probing or recovering can turn MMIO
into an SError (kernel panic) and break firmware-crash recovery, while
ath12k has no PCI error handlers to benefit from the reset anyway. The
notes below are kept for reference.


- **Symptom:** when a QCN9274 link drops (firmware crash, link
  instability), the link stays down until reboot.
- **Patches**, all from mainline (Manivannan Sadhasivam,
  "pci-port-reset-v9", merged for v7.3):
  - 0421 `3fc686d550f6` "PCI/ERR: Add support for resetting the Root
    Ports in a platform-specific way", clean;
  - 0422 `4c99bace4f4e` "PCI: host-common: Add link down handling for
    Root Ports", context-only adaptation (6.18 lacks
    `pci_reset_bridge()` and `pci_host_common_d3cold_possible()`);
  - 0423 `4d88cb82a6d9` "PCI: qcom: Implement .reset_root_port() and
    use for link down", context-only adaptation (6.18 lacks
    `PARF_LTSSM_STATE_MASK`, `qcom_pcie->reset`, OPP helpers and
    per-port PERST# lists), no functional change;
  - 0424 `0b967a82e7b3` "arm64: dts: qcom: ipq9574: Add missing PCIe
    global IRQs" (Kathiravan Thirumoorthy). Without it the feature
    never triggers: 6.18's `ipq9574.dtsi` has no "global" interrupt.

  About 190 changed lines. Every symbol used exists in 6.18
  (`dw_pcie_setup_rc`, `dw_pcie_wait_for_link`, `pcie_do_recovery`,
  `for_each_pci_bridge`…). `CONFIG_PCIEAER`, `PCIEPORTBUS` and
  `PCIE_QCOM` are on, so the AER recovery path is used.
- **Trigger:** the link-down bit of `PARF_INT_ALL_STATUS` on the
  "global" IRQ. The thread calls `pci_host_handle_link_down()` →
  `pcie_do_recovery()` → `bridge->reset_root_port()`, which waits for
  the flush, deinits and re-inits the host, retrains and waits for the
  link.
- **Not taken:** `b99a594cfdd0` "ipq9574: Add PCIe bridge node". The
  feature does not need it, and it would clash with our board's own
  `pcie@0` nodes and needs the mixed PERST#/PHY handling 6.18 lacks.
- **Limits:**
  - ath12k has no `pci_error_handlers`, so the link comes back but the
    radio is not re-initialised by the kernel. Recovery reports
    "device recovery failed" and the radio needs a driver rebind or a
    reboot. Mainline behaves the same.
  - The probe now writes `PARF_INT_ALL_MASK = LINK_DOWN | MSI_DEV_0_7`.
    The MSI bits are the hardware default, but if the global IRQ also
    fires for every MSI on IPQ9574, it would cost CPU under Wi-Fi load.
    See the checklist.
  - The PARF flush bits are generic Qualcomm definitions. Upstream was
    not tested on IPQ. If they differ here, the reset logs "Flush
    completion failed" and does nothing.
- **Upstream:** merged in mainline (v7.3).

## R3: PPE egress and EEE (0425–0427, test)

Source: [openwrt/openwrt#24188](https://github.com/openwrt/openwrt/pull/24188)
"qualcommax: qca_ppe: fix per-port egress wedges" (Julius Bairaktaris,
merged about 2026-09-22) and #24252 (folded into it). They target the
IPQ807x `qca_ppe` driver. The qca-ssdk idea comes from commit
`30c10e7f` "enable and disable loopback for xgmac to fix qm stuck issue".

**Register mapping (IPQ807x qca_ppe → IPQ9574 qcom-ppe):**

| Register / field | IPQ807x | IPQ9574 (`ppe_regs.h`) | qca-ssdk (APPE) |
|---|---|---|---|
| `PORT_BRIDGE_CTRL.TXMAC_EN` | 0x060300 + 4·p, bit 16 | 0x60300, +4, BIT(16) | `hppe_fdb_reg.h`; L2 base 0x060000 for APPE in `hsl_dev.c` |
| XGMAC `RX_CONFIG.LM` | port MAC CSR + 0x4, bit 10 | 0x500000 + (p−1)·0x4000 + 0x4; LM added as BIT(10) | `hppe_xgportctrl_reg.h` LM offset 10; xgmac_id = port − 1 on APPE |
| XGMAC RE / TE | bit 0 / bit 0 | `XGMAC_RXEN` / `XGMAC_TXEN` | same |
| L0 flow map / C/E flow cfg | 0x402000 / 0x404000 / 0x406000 | same addresses and fields | — |

qca-ssdk runs the same link-down sequence for APPE (IPQ95xx) in
`qca_hppe_mac_sw_sync_task()`: gate off, `mdelay(10)`, RX MAC off,
1 ms XGMAC loopback pulse. qcom-ppe already does #24188's commit 1 (gate
TXMAC_EN off first on link down, set it last on link up).

- **0425 drain on link down (ours):** after closing the gate, wait
  10 ms. On XGMAC ports (2.5G/10G: lan1, wan) set LM for 1 ms after RX
  is off and before TX goes off; a loopback already set is left alone.
  It sleeps in `mac_link_down()`, which phylink calls from process
  context. Cost: 10–12 ms per link down.
- **0426 multicast DRR slots (ours):** move each port's multicast
  queues to its idle unicast slots 12–15 so they no longer share an L0
  DRR node with unicast queue 0. On IPQ807x that pairing latched to
  about one dequeue per second. **Speculative on IPQ9574:** its L1
  level already puts both of a port's L0 flows on one DRR node, and the
  latch was never seen here. It also changes QoS: multicast gets an
  equal DRR share against unicast instead of strict priority. A/B test
  only.
- **0427 EEE off (ours, based on #24188 commit 2):** the PPE MACs do not
  do LPI, but without `mac_*_tx_lpi` ops phylink leaves the PHYs
  advertising EEE. qca-ssdk disables EEE on every port at init. Empty
  ops make phylink call `phy_disable_eee()`, and `ethtool --set-eee`
  returns EOPNOTSUPP. This also covers the forum's EEE latency jitter on
  the 10G WAN.
- **Evidence of the hazard on IPQ9574:** none direct. No qualcommbe
  issue reports "carrier up, no TX". The trigger is a deep egress queue
  at link loss, which becomes likely with PPE offload (PR #24178,
  open).
- **Conflict note:** #24178 adds `ppe_port_bridge_txmac_set()` in
  `ppe_port.c` and would conflict textually with 0425.

## R4: generic upstream fixes

- **0428 phylink "initialise link_state before a forced major config"**
  (`113998aa372f`, net, 2026-09-04): not in 6.18.54 or the stable
  queue. On this board `force_major_config` is never set (qcom-ppe does
  not use the fwnode PCS provider), so this is hardening. Zero risk.
- **0429 phylink "correctly validate returned PCS in
  phylink_inband_caps"** (`f2849b1fd059`): vanilla 6.18.54 has it, but
  `pending-6.18/737-02` rewrites the function back to a plain NULL
  check. Adapted to the 737-02 code; noted in the header.
- **0430/0431 qca808x active-high LED polarity** (Donggeun Yoo, net-next
  `5117ce8c35d1`, `f1b4766d67bb`, queued for v7.4, marked "never worked",
  no stable). Today an `active-high` LED node makes `led_polarity_set`
  fail with -EINVAL, the PHY probe fails and phylib falls back to genphy.
  0431 keeps the bit across soft resets; its context was adapted to the
  QCA8084 code. **Our lan1 nodes (`active-low`) behave exactly as
  before.**
- **0432 regulator qcom_smd "change MP5496 supply names"** (Gabor Juhos,
  v1 2025-12-16, the only version, patchwork "handled-elsewhere", not
  merged):
  - Cause of "Supply for s1 (s1) resolved to itself": the MP5496 table
    uses the output's own name as its supply name. Our s1 has no
    `*-supply` and no `regulator-name`, so the name lookup finds the
    regulator itself. The core then uses the dummy supply, so the
    message is cosmetic.
  - With the patch the supply names become `vdd_s1`, `vdd_s2_l2_l3` and
    `vdd_l4_l5`; the lookup finds nothing and silently uses the dummy.
  - Interaction with our DTS (no l5, no supply properties): none. No
    in-tree DTS uses `s1-supply` and the like, so the ABI change hits
    nobody.
- **0433 thermal step_wise "fix stale mitigation vote with non-zero
  lower bounds"** (`ec0d89150a93`, 2026-09-22, in the 6.18 stable
  queue). Our fan maps use lower = upper = 1/2/3 on one zone, so a quick
  temperature drop across two trips could leave the fan one step too
  high. **Drop it when the kernel moves to 6.18.55**, which should carry
  it.
- **tree/0030 dtc warnings:** see the next section.
- **Checked and not taken:**
  - 2026 dts: `bd2dc325db8c` (USB wrapper IRQs, only for dtbs_check and
    suspend), `53f5d2d61a1c` (eMMC details; our board DTS already has
    them and it conflicts), `65991dedc8c1` (moves the MP5496 references
    out of the dtsi, no functional change, renames our `ipq9574_s1`
    label).
  - `fedcff16a9b6` qmp-usb runtime PM at boot, `346ba8464635` qmp-usb
    regulator load, `0aae2c731758` cqhci endianness, `52957cdad30f`
    sdhci-msm wrapped keys, the tsens wake IRQ, `0fe1e3e8f338` phylink
    link_gpio: none applies to this hardware or 6.18 feature set.
  - `f2090ebdb59d` smem `qcom_smem_is_available`: it would break 6.18,
    which lacks its prerequisite `7a94d5f31b54`.
  - Unmerged suspend-only qusb2 and dwc3-qcom fixes, sdhci-msm vqmmc,
    tsens limits, new Realtek PHY IDs: not applicable yet.
  - Already in our tree (no action): qusb2 `1ca52c0983c3`, qmp-usb
    `142c55933792`, tsens `e28ef2f3ccea`, realtek `202fef9bbbf5`,
    `510a283f4d12`, `8744b63e8a9a`, phylink `e5db987f5d7f`,
    `5ba017f9efef`, `a940003f44e7`, pwm-fan `26d5ff797685`, qca807x
    `2bb995e6155c`, OpenWrt PRs 24191, 24218, 25405, 24033, 25344.
  - pcs-qcom-ipq9574 and qcom-ppe have had no mainline fixes since 6.18.
  - Worth a hardware check by analogy: OpenWrt PR #24566 (qualcommax,
    QCA8081 2.5G egress corruption from a stale port 5 TX clock mux).
    Look at the nss_cc port5 TX clock parent in
    `/sys/kernel/debug/clk/clk_summary` and run an iperf TX test on lan1.

## R4f: tree/0030 dtc warnings

Before (ImmortalWrt DTS plus round 1):

```
Warning (reg_format): /soc@0/mmc@7804000/card@0:reg: property has invalid length (4 bytes) (#address-cells == 2, #size-cells == 1)
Warning (pci_device_reg): Failed prerequisite 'reg_format'   (and 3 more)
Warning (avoid_default_addr_size): .../card@0: Relying on default #address-cells / #size-cells value
```

The failed `reg_format` check also switched off the PCI checks. With
only the MMC part fixed, they show two more:

```
Warning (pci_device_reg): /soc@0/pcie@18000000/pcie@0,0:reg: PCI reg config space address cells 2 and 3 must be 0
Warning (pci_device_reg): /soc@0/pcie@20000000/pcie@0:reg: PCI reg config space address cells 2 and 3 must be 0
```

0030 adds `#address-cells = <1>; #size-cells = <0>;` to `&sdhc_1`, sets
the pcie2/pcie3 root port `reg` to all zeros (like pcie1) and renames
`pcie@0,0` to `pcie@0`. Linux takes the devfn from the first reg cell,
which was already 0, so the nodes match the same devices. After it the
DTB builds with **no dtc warnings**. These are the same changes as
OneNAS b6fc7b1f43. Not taken from that commit: its `cma=256M` /
reserved CMA pool, which is a policy choice rather than a fix.

## R5: tree/0032 fan PWM 1 kHz (dropped)

Dropped after the first RAM boot (2026-10-01): the router made a
continuous audible tone, as expected from a fan driven at 1 kHz. The
board keeps its 25 kHz period. The notes below are kept for reference.


- **Board:** `pwms = <&pwm 3 40000 0>` (25 kHz) since the board was
  added in January. Cooling levels are 36/72/128/255 at trips
  40/50/65/80 °C.
- **Forum (thread 245244):**
  - posts 45, 51 and 53 (motolav, Feb 2026): the Delta ASB0512HA is
    quiet and usable over its whole range at 1 kHz, weak at 5–10 kHz,
    noisy at 2.5 kHz;
  - Delta specifies 1 kHz for similar fans (THA series);
  - post 67 (Mar 2026): "PWM is still semi-broken".
- **Driver:** those tests predate qualcommbe 0403 (Kenneth Kasilag, June
  2026). Before it, pwm-ipq fixed `pwm_div` at its maximum, so periods
  below about 655 µs were stretched and duty cycles were scaled wrongly.
  That explains part of the bad results above 1 kHz. Simulating 0403's
  divider search at the 100 MHz ADSS PWM clock:
  - 25 kHz: pre_div 0, pwm_div 3999;
  - 1 kHz: pre_div 1, pwm_div 49999.

  Both are exact. 1 kHz has finer duty steps.
- **Change:** period 1000000 ns. Cooling levels and trips are unchanged.
- **Status:** test item. The justification is the fan maker's frequency
  and the forum's listening test, but that test ran on the old driver.
  Compare by ear and by temperature against 25 kHz (drop the patch) at
  each cooling level. Upstream: none.

## R6: rtpengine (feed telephony)

- **Failure** (`make package/feeds/telephony/rtpengine/compile V=s`,
  variant no-transcode, built because `CONFIG_ALL_KMODS` selects
  `kmod-ipt-rtpengine`):

  ```
  xt_RTPENGINE.c:39:10: fatal error: linux/netfilter/xt_RTPENGINE.h: No such file or directory
  ```

- **Cause:** `kernel-module/Makefile` of mr11.5.1.49 passes
  `-D__RE_EXTERNAL` and the version through `EXTRA_CFLAGS`, which kbuild
  stopped honouring in 6.15 (`e966ad0edd00`). Without the define the
  module includes the in-kernel header path instead of its own
  `xt_RTPENGINE.h`.
- **Fix:** `105-kernel-module-use-ccflags-y-instead-of-EXTRA_CFLAGS.patch`
  is upstream rtpengine `38700abf0b79` (Richard Fuchs, 2025-05-28),
  extended to the `__RE_EXTERNAL` line that mr11.5 still has.
  `ccflags-y` works on old kernels as well.
- **Result:** `kmod-ipt-rtpengine-6.18.54.11.5.1.49-r1.apk` builds,
  vermagic 6.18.54.
- **Feed tree:** the overlay copies the file into
  `feeds/telephony/net/rtpengine/patches/`. `src-build.sh` does not
  git-clean `feeds/`, so the file stays there and is not removed when
  this repo drops it. It would also collide if the telephony feed ever
  adds its own 105. The telephony feed (HEAD `5d68d53`) has no fix yet;
  upstream telephony should get the same patch.
- **Upstream:** fixed in rtpengine master by `38700abf0b79` (May 2025),
  not on the mr11.5 branch; the OpenWrt telephony feed still ships
  mr11.5.1.49.

## R8: lan2/lan3 LEDs (tree/0031, test)

- **Wiring evidence:**
  - Each port has two LEDs. Today Linux leaves the QCA8075 LED pins at
    the chip defaults: at 1G both blink together.
  - The stock QSDK 12.5 DTB has `led_source@3/@6/@9`: mode normal, speed
    all, blink enabled, active high.
  - qca-ssdk `fal_led.c` maps a source to port = source / 3 + 1 and
    pin = source % 3. That gives pin 0 of SSDK ports 2–4, i.e. PHYs
    0x11–0x13. lan2 is 0x12 and lan3 is 0x13; 0x11 is not used on this
    board.
  - `malibu_phy.c`: pin 0 is LED_100N (MMD7 0x8074), pin 1 is LED_1000N
    (0x8076). These are the registers qca807x uses for LED index 0 and 1.
- **Nodes:** `led@0` yellow and `led@1` green, function LAN,
  `default-state = "keep"`. LED class names are
  `90000.mdio-1:12:{yellow,green}:lan` and `…:13:…`.
- **Deliberately not like lan1:**
  - **No `led@2`.** qca807x accepts index 0 and 1 only; any other index
    registers but fails with -EINVAL once hw control is set.
  - **No `active-low`/`active-high`.** qca807x has no
    `led_polarity_set`, so either property makes `of_phy_led()` fail,
    which **fails the PHY probe and takes PPE ports 3/4 down with it**.
    The pins keep the chip's polarity, which already lights them on
    link. The stock "active high" therefore cannot be expressed with
    this driver; adding `led_polarity_set` to qca807x would need the
    QCA8075 polarity register, which no source we have documents.
- **01_leds:**
  - green: `link_1000 tx rx`;
  - yellow: `link_100 link_10 tx rx`.

  qca807x offloads link_10/100/1000, tx and rx. board.d only runs when
  `board.json` is created, so an upgrade that keeps the configuration
  needs `rm /etc/board.json; /bin/board_detect` or the LED settings
  added by hand.
- **If the colours are swapped on the hardware:** exchange
  `LED_COLOR_ID_YELLOW` and `LED_COLOR_ID_GREEN` in both nodes of 0031.
  01_leds then needs no change.

## Round 2 validation

Run on 2026-10-01 in `~/owrt/wt-plat` (ImmortalWrt `bf156b68e3`), with
everything in this repo applied, including the WiFi agent's files:

- **`STAGE=prepare`:** OK. The new overlay files (kernel patches, the
  rtpengine patch, 01_leds) are copied, and tree 0030–0032 (0032 since dropped) apply after
  0001–0011.
- **`make target/linux/{clean,prepare} V=s`:** every generic and
  qualcommbe patch applies, none with fuzz or offset. 0424 was refreshed onto 0420.
- **`make target/linux/compile -j16 V=s`:** OK, with no compiler
  warnings from the kernel. `System.map` has
  `pci_host_handle_link_down`, `qcom_pcie_reset_root_port` and
  `qca808x_led_polarity_set`. `.config` has `QCOM_WDT`, `PCIE_QCOM`,
  `PCIEAER`, `PCI_HOST_COMMON`, `QCA807X_PHY`, `QCA808X_PHY`,
  `THERMAL_GOV_STEP_WISE` and `REGULATOR_QCOM_SMD_RPM` built in.
- **`make package/kernel/linux/compile -j16`:** OK
  (`kmod-qcom-ppe-6.18.54-r1.apk`).
- **`make package/feeds/telephony/rtpengine/{clean,compile} V=s`:** OK.
  Before 105 it failed as described in R6.
- **DTB** (same cpp + dtc command and flags as `Image/BuildDTB`):
  - no dtc warnings (before: the `card@0` reg warnings);
  - `sram@8600000` / `restartreason-sram@7a4` present, and the watchdog
    has `sram = <&restart_reason>`;
  - pcie0–3 list `"global"` as their 9th interrupt;
  - the root ports are `pcie@0` with all-zero reg;
  - `&sdhc_1` has `#address-cells = <1>; #size-cells = <0>`;
  - `ethernet-phy@18` and `@19` have `led@0` (colour 6, yellow) and
    `led@1` (colour 2, green), no polarity property;
  - `pwms = <&pwm 3 1000000 0>`.
- **`checkpatch.pl --strict`:** 0425–0427 clean. 0420's only remaining
  warning is "unknown commit id", because checkpatch ran without git.
- **Not compiled:** the userspace rtpengine daemon (no image or feed
  selects it), and an image (not needed for these checks).

## Round 2 hardware checklist

RAM boot (initramfs) first.

1. **Boot and Ethernet:**
   - all four ports come up; lan2/lan3 PHYs probe (no -EINVAL in
     `dmesg | grep -i qca807`);
   - EEE off (0427): `ethtool --show-eee` cannot show it (no
     get_eee in the EDMA ethtool ops, and phylink returns -EOPNOTSUPP
     for a MAC without LPI capabilities). Read the PHY EEE advertisement
     (MMD7.60, e.g. with phytool) or check the link partner;
   - no PHY attach errors in dmesg (0427 makes phylink write the PHY
     clock-stop bit on every PHY at attach).
2. **Watchdog (0416–0420):**
   - `cat /sys/class/watchdog/watchdog0/bootstatus` after a normal boot
     (expect 0, or 16 = `WDIOF_POWERUNDER` after a cold power-on;
     seen on the first round 2 RAM boot after a power cycle);
   - `echo c > /proc/sysrq-trigger` or stop the feeder
     (`ubus call system watchdog '{"magicclose":true,"stop":true}'`) and
     wait for the reset; afterwards bootstatus should be 32
     (`WDIOF_CARDRESET`). If it stays 0, read the raw word:
     `devmem 0x086007a4` (busybox devmem, if built).
3. **PCIe:** 0421–0424 were dropped (see R2); all three radios come
   up.
4. **Link flaps (0425–0427):**
   - plug/unplug each port 20 times, including under iperf load;
   - after each replug, traffic must flow;
   - no "phylink" or "ppe" errors in dmesg.
5. **Multicast (0426):** mDNS/IPTV/multicast iperf through lan ports
   while unicast is saturated. Compare with 0426 removed.
6. **LEDs (0030/0031 + 01_leds):**
   - `ls /sys/class/leds` shows `90000.mdio-1:12:{green,yellow}:lan`
     and `:13:`;
   - at 1G green lights and blinks; at 100M yellow does. If the colours
     are the other way round, swap them in 0031;
   - on an upgraded config: `rm /etc/board.json; board_detect` and
     check `uci show system | grep lan2`.
7. **Fan:** no audible tone at any cooling level (0032 was dropped for
   this).
8. **Regulators (0432):** `dmesg | grep -i "resolved to itself"` is
   empty, cpufreq still scales up to 2.2 GHz.
9. **rtpengine (feed):** `apk add kmod-ipt-rtpengine` and
    `modprobe xt_RTPENGINE` load without errors.

## Code review before the third RAM boot (2026-10-01)

A read-only review of every round 1 and round 2 platform patch against
the patched 6.18.54 tree and upstream found:

- **tree/0002, s1 boot voltage (fixed).** With min and max set, the
  regulator core applies the minimum at registration because
  `rpm_reg_get_voltage()` returns 0. The stock 587.5 mV minimum would
  run the CPU at its boot clock on 587.5 mV until cpufreq takes over.
  The 725 mV minimum (and ImmortalWrt's comment) is back; it equals the
  lowest OPP. s2 is no longer described: Linux has no consumer for it,
  and registering it only dropped it to 700 mV at boot.
- **sbe1v1k-irq (fixed).** It deleted the whole `banirq` list, including
  user entries. It now remembers its own numbers in
  `irqbalance.irqbalance.sbe1v1k_banirq` and replaces only those.
  Tested on the router with a copy of the config.
- **0421–0424 (dropped),** see R2.
- **Docs:** EEE check, bootstatus values, qca807x polarity and LED index
  statements corrected.
- Everything else (0363, 0410–0415, 0416–0420, 0425–0433, 744, tree
  0004/0006/0030/0031, rtpengine, 99-sbe1v1k-defaults) matched upstream
  or was traced as correct, including 0425's sleep in `mac_link_down()`
  (all callers run in process context under `state_mutex`).
