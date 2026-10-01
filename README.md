# SBE1V1K Firmware

Spectrum / Askey **SBE1V1K**（RTQ7300T，IPQ9570，3×QCN9274）的 ImmortalWrt 固件。

在 ImmortalWrt master 源码上打一小组补丁后完整编译，内核模块随固件一起编译并发布到
[本项目的软件源](https://crescentm.github.io/sbe1v1k-packages/)，所以 `apk add kmod-*`
总能装上和内核匹配的模块。普通软件仍走 ImmortalWrt 官方源。

## 相对 ImmortalWrt 的改动

| 问题 | 改动 |
|---|---|
| CPU 一直停在开机频率，`l5: devm_regulator_register() failed` | DTS：MP5496 电压采用原厂值，去掉 l5；禁用没有驱动的 QCE 节点 |
| 三块 WiFi 卡间歇性初始化失败（`WMI CONTROL service status: -71`，OpenWrt #24949） | ath12k 补丁 950–955 |
| 三个 radio 共用一个 MAC（#23578） | ath12k 补丁 960（OpenWrt PR #23786） |
| radio 与频段的对应关系每次开机变化（#24370） | wifi-scripts 按频段重新映射（OpenWrt PR #24639 的修正版） |
| 6 GHz 生成 `country=00` 导致 AP 起不来 | wifi-scripts 不再下发 `00` |
| lan2/lan3 所在 QSGMII 通道的 CRC 错误 | DTS：QCA8075 发送幅度改为原厂的 300 mV |
| HTTP U-Boot "large" 分区布局下 sysupgrade 写错分区 | `platform.sh` 按分区名识别 `kernel` 分区 |
| ath12k 高负载下掉线 | 首次启动时关闭 packet steering |
| 以太网中断全部压在 CPU0 | EDMA 收发中断按队列分到 4 个核 |
| PPE 驱动的 double free、NAPI 卡死、端口回滚越界、MTU 先改后校验 | PPE/EDMA 修复（OpenWrt PR #24191、#25405 等） |
| WAN 灯乱闪 | RTL8261 LED 驱动支持和 DTS 声明，灯按速率显示 |
| 5 GHz 退回 20 MHz | 5/6 GHz 关闭 20/40 MHz 共存扫描（`noscan`） |
| 开机时 `PHY is undefined`、断电后 `board.json` 为空 | wifi-scripts（OpenWrt PR #25471、#25473） |
| ath12k 的 regulatory 超时、越界读写、GTK rekey 掉线等 | 主线 7.3-rc 和 ath-next 的 ath12k 修复 |
| WiFi 卡拿不到原厂那样的专用内存 | 按原厂给三块 QCN9274 各预留 50 MiB host DDR |
| 看门狗重启后看不出重启原因 | 主线 qcom-wdt bootstatus 支持和 IMEM 节点 |
| 网口断开后 PPE 发送队列卡住、组播队列饿死、EEE 引起断流 | PPE 断链排空、组播 DRR、关闭 EEE（移植 qualcommax PR #24188/#24252，测试档） |
| PCIe 链路掉线后 WiFi 卡无法恢复 | 主线 PCIe root port 复位（测试档） |
| phylink、qca808x LED 极性、MP5496 供电名、温控等上游已修的问题 | 回移主线修复 |
| lan2/lan3 灯不受控、风扇 PWM 频率 | DTS 声明 lan2/lan3 端口灯；风扇 PWM 改为 1 kHz（均为测试档） |
| rtpengine 内核模块在新内核上编不过 | Kbuild 修复（rtpengine 上游 `38700abf0b79`） |
| mac80211/cfg80211 的 use-after-free、mesh、CSA、VLAN 等问题 | Linux 7.2.y 稳定版、7.3-rc 和 wireless.git 的全部相关修复 |
| ath12k 的 MLO、SSR、TX DMA、扫描死锁、监听模式等问题 | 主线、ath-next 和邮件列表的 ath12k 修复；wake_tx_queue 流控等较新的放在测试档 |
| hostapd 的 MLD 重配置、DPP、ACS 死锁、内存越界等问题 | OpenWrt main 的 hostapd/wifi-scripts 修复和 hostap.git 2.12 之后的修复 |
| 6 GHz 上 psk-mixed/wpa 起不来、0 dBm 发射功率无效、MLO 下 `macaddr random` 无效 | wifi-scripts 修复（OpenWrt PR #23914、#25479、#24955 等） |

每个补丁的来源、原作者和上游状态见 [patches/README.md](patches/README.md)。标为**测试档**的补丁各自独立，
出问题时可以单独删掉。

预装：中文 LuCI、fullcone NAT、UPnP、SQM（cake）、WireGuard、irqbalance 及常用诊断工具，
全部来自 ImmortalWrt 官方源，见 [packages.txt](packages.txt)。

## 安装与升级

- **已经在跑 OpenWrt / ImmortalWrt**：在路由器上用 `sysupgrade` 刷 `*-squashfs-sysupgrade.bin`，可以保留配置。
  支持 mainline（`0:HLOS`）和 HTTP U-Boot 的 large 两种分区布局。
- **测试**：`*-initramfs-uImage.itb` 可以只在内存中启动，不写 eMMC。
- 固件下载见 [Releases](https://github.com/Crescentm/sbe1v1k-firmware/releases)：
  - **正式版本**：经过实机测试，软件源永久保留，建议刷这个；
  - **Pre-release**：CI 的日常构建，软件源只保留最近 3 个版本。刷了日常构建的固件，
    在它的软件源被清理后就装不了新的内核模块，需要升级到更新的固件。

升级前请先备份配置（`sysupgrade -b`）。全新安装时 ImmortalWrt 的默认设置是开放 WiFi、root 无密码，
请立即设置密码和 WiFi 加密。

## 自行编译

需要一份 ImmortalWrt 源码（已执行 `./scripts/feeds update -a && ./scripts/feeds install -a`）：

```sh
SRC=/path/to/immortalwrt sh scripts/src-build.sh
```

- 依赖与 OpenWrt 编译环境相同。用 Nix 的话，`nix run .` 会进入一个 FHS 编译环境。
- `STAGE=prepare` 只打补丁、生成配置，不编译。
- 产物在 `out/src-<时间>/`：固件镜像在根目录，软件源在 `feed/`。
- GitHub Actions（`.github/workflows/build.yml`）每周或手动触发，编译后把固件和打包好的软件源
  （`feed-<发布名>.tar.zst`）发布到 Releases；
  [sbe1v1k-packages](https://github.com/Crescentm/sbe1v1k-packages) 再把最近几个版本的软件源发布到 GitHub Pages。
- 软件包签名公钥：[keys/sbe1v1k-apk.pem](keys/sbe1v1k-apk.pem)。

## 许可

本仓库的补丁和脚本以 GPL-2.0 发布，与 OpenWrt / ImmortalWrt 相同。补丁中注明了原作者与出处。
