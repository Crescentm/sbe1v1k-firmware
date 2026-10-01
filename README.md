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

每个补丁的来源、原作者和上游状态见 [patches/README.md](patches/README.md)。

预装：中文 LuCI、fullcone NAT、UPnP、SQM（cake）、WireGuard、irqbalance 及常用诊断工具，
全部来自 ImmortalWrt 官方源，见 [packages.txt](packages.txt)。

## 安装与升级

- **已经在跑 OpenWrt / ImmortalWrt**：在路由器上用 `sysupgrade` 刷 `*-squashfs-sysupgrade.bin`，可以保留配置。
  支持 mainline（`0:HLOS`）和 HTTP U-Boot 的 large 两种分区布局。
- **测试**：`*-initramfs-uImage.itb` 可以只在内存中启动，不写 eMMC。
- 固件下载见 [Releases](https://github.com/Crescentm/sbe1v1k-firmware/releases)。

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
