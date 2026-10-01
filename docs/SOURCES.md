# 各来源固件：我们拿什么、不拿什么

本文记录 SBE1V1K 社区里各个固件、源码树和备份分别值得借鉴什么，以及哪些东西明确不要。
每一项都标了状态，以后来源更新、或者我们的固件往前推进，就在这里改状态。

最后更新：2026-10-01（加入 yangzhg 和论坛帖）

**状态说明**

| 标记 | 含义 |
|---|---|
| ✅ 已采用 | 已经在本仓库的固件里 |
| 🔧 进行中 | 正在做，见对应小节 |
| 📋 待做 | 决定要拿，还没做 |
| 🧪 实验 | 值得试，但要先验证，不进主固件 |
| 📖 参考 | 只拿数据或思路，不拿代码或文件 |
| ❌ 不采用 | 明确不要，后面写了原因 |

## 我们的路线（决定其余取舍的前提）

- **基础**：ImmortalWrt master 源码，打上本仓库的补丁后完整编译（`scripts/src-build.sh`）。
- 内核是自己编译的，所以**全部内核模块也自己编译、自己发布**（`CONFIG_ALL_KMODS`），
  固件默认从本项目的软件源装内核模块，普通软件仍走 ImmortalWrt 官方源。
- 因为可以改内核，原先"只能改模块和用户态"的限制取消了；但每一处内核改动都要有依据，
  并尽量跟上游保持一致、能提交上游的就提交。
- 固件保持纯净：只预装 ImmortalWrt 官方源里的软件，不预装第三方程序（例如 Lucky）。


## 总览

| 来源 | 是什么 | 主要拿什么 | 整体结论 |
|---|---|---|---|
| ImmortalWrt master | 本固件的基础 | 源码、fullcone、中文生态 | 基础 |
| OpenWrt 官方 main | 上游 | 设备支持本身；WiFi 问题对照 | 出问题时先在它上面复现 |
| luckkyboy/SBE1V1K | OpenWrt 官改，7 月后停更 | 补丁 400、`sources.lock` 思路、文档 | 只拿补丁 |
| yintaomu/SBE1V1K-OpenWrt | 基于 luckkyboy，路由器原先跑的 | wifi-scripts 修复、国家码、诊断脚本、回归判定 | 只拿用户态修复 |
| yangzhg/SBE1V1K | luckkyboy 的 fork，WiFi 补丁 105–111 的原作者 | WiFi 补丁原版、wifi-scripts 修复、多项 DTS 平台修复 | 📋 重要来源 |
| OpenWrt 论坛帖 245244 | 社区讨论（271 帖，2026-01 至 09-27） | CPU 调频修复依据、各类实测、免拆机安装、避坑 | 📖 问题和修复的总索引 |
| Jackie264/SBE1V1K、OneNAS-space/Askey_Spectrum_SBE1V1K | 同一作者，专攻 WiFi | #24949 的 ath12k 补丁 | 🔧 WiFi 修复的主要来源 |
| SBE1V1K_immortalwrt_NSS | 把 QSDK NSS/PPE 移植到 6.18 | 踩坑记录、预留内存写法 | NSS 部分不采用 |
| 闭源 LEDE 固件 | 第三方闭源成品，内核 6.12 | 功能清单、风扇参数 | 不采用任何文件 |
| coolsnowwolf/lede 源码 | LEDE 开源树 | 无 | 没有成品和模块源，不当基础 |
| debian-sbe1v1k | QSDK 6.6 内核加 Debian 用户态 | 硬件实测数据、nft 设计思路 | 只拿数据 |
| QSDK 12.5 备份（lingjp 构建） | 备份里的"原厂系统"，实为第三方 QSDK | 硬件参数真值、NSS 参考配置、新版 BDF | 📖 参考，🧪 BDF 实验 |
| 我们的 HTTP U-Boot | 自己维护的 chainloader | large 布局、救砖、RAM boot、netconsole | 配套工具 |

---

## ImmortalWrt snapshot（基础）

- ✅ 官方内核和配套模块源（`kmods/6.18.52-1-e99109ac…/`），固件内的软件源已指向它。
- ✅ `kmod-nft-fullcone`：OpenWrt 官方没有。运营商级 NAT 下配合 STUN 打洞时需要全锥形 NAT。
- ✅ `default-settings-chn`（时区、中文、国内镜像）、中文 LuCI 语言包、`autocore`。
- ⚠️ 代价：ImmortalWrt 自带额外补丁。遇到 bug 先在 OpenWrt 官方 snapshot 上复现，再决定报到哪里。
- ⚠️ **snapshot 停更**（2026-10-01 核实）：ImmortalWrt 所有平台的 snapshot 都停在 2026-09-18 的 `r41341-f44d1535b4`；
  OpenWrt 官方 snapshot 是 2026-09-30 的 `r36743-c759267c92`。因此我们缺了上游 9-18 之后的修复，
  包括 SDHCI 复位（`da141cba5c`）。要不要切到 OpenWrt 官方，见文末"待决定"。

## OpenWrt 官方 main

设备支持在 2026-08-23 由 PR #21586 合入上游，ImmortalWrt 已同步。

- ✅（经 ImmortalWrt 继承）DTS、FIT 和 eMMC 镜像、`0:ART` 校准数据提取、U-Boot 环境变量配置。
- ✅（经 ImmortalWrt 继承）合并后修好的 Rev 4.1 无限重启、eMMC 复位失败、以太网 DMA 方向错误。这三项是各官改分支都没有的。
- 📖 仍未解决的问题，就是我们要补的：
  - **#24949**：三块 WiFi 卡间歇性初始化失败（`WMI CONTROL service status: -71`）。
  - **#24370**：radio 和频段的对应关系每次开机变化。修复 PR #24639 未合并。
  - **#23578**：多 radio 的 MAC 不对。修复 PR #23786 未合并。
  - 升级脚本只认 `0:HLOS`，不支持 large 布局。
- ❌ 内核配置相关的开放 PR（#25405 NAPI 预算、#24893 cortex-a73）：要改内核，等上游合并后自然跟进。

## luckkyboy/SBE1V1K

- 🔧 **ath12k 补丁 400**（按 radio 从 DT 设置 MAC，修 #23578）。以 Jackie264 重做后的版本为准，见下文。
- 📖 `sources.lock` 锁定所有来源和哈希的做法。我们在输出目录记录了仓库版本，以后可以扩展成完整的来源锁。
- 📖 中文拆机、备份和安装文档。
- ❌ 补丁 200（回退 BH workqueue）：上游已删除，因为会让 AHB 编译失败。
- ❌ 5 行的极简编译配置：没有 LuCI，也没有常用模块。
- ❌ `lede`、`lede-ppe` 分支：内核 6.12 加 LEDE 体系，PPE 部分只编译通过、没上过机。

## yintaomu/SBE1V1K-OpenWrt（路由器之前运行的固件）

驱动层和 luckkyboy 完全一样，它的修复全在用户态。

- 🔧 **按频率识别 radio**：`resolve_radio_index()` 和 `resolve-radio-index.uc`，修 #24370。会和 PR #24639 对照后取一版。
- 📋 **国家码**：它在 board.d 里写死 `US`，以避开 6G 生成 `country=00` 导致三个 AP 都起不来的问题。我们改成可配置的默认值，而不是写死。
- 📋 `sbe1v1k-diag` 诊断脚本：一次性收集 release、分区、iw、lsmod、过滤后的 dmesg 和日志。放进 `files/`。
- 📋 实机 WiFi 回归的判定标准：hostapd ubus 对象数、SSID 数、日志里不出现 `failed to start vdev`、`add_iface failed`、`Failed to set beacon`。
- 📋 升级包完整性检查（`tar tf` 完整扫描，并要求有 `CONTROL`、`kernel`、`root`）。照搬前要补上对 FIT 格式升级包的放行。
- ❌ 每个频段固定 `sleep 4` 的串行启动锁：只是规避，会让 WiFi 启动多出 8 到 12 秒。等驱动补丁修好后看是否还需要。
- ❌ 锁死 feeds 版本：这正是之前装 luci-compat 时 `libubox` 版本对不上的根源。
- ✅（已用我们自己的版本替代）它的 `platform.sh` 写死 `0:HLOS`，我们改为按分区名识别 large 布局，见 `patches/base-files/`。

## Jackie264/SBE1V1K 与 OneNAS-space/Askey_Spectrum_SBE1V1K

同一作者的两个仓库，是 #24949 驱动修复的唯一来源。来源链：luckkyboy → yangzhg → Jackie264（`main` 与 `bk` 相同，最后提交 2026-09-12）；OneNAS-space 那个仓库 9 月 30 日还在更新。

- 🔧 **ath12k 补丁**，只改 `kmod-ath12k`，用 SDK 重编，内核指纹不变：
  - 105 CV upload direct buffer、106 处理空 regulatory 事件、108 按 WSI 序号排硬件组顺序、110 限制 WMI endpoint 数、111 radar direct buffer：针对 #24949。
  - 104 宽频 radio 的 regulatory 范围：在 Jackie264 的仓库里重做过。
  - 400 per-radio MAC：在 Jackie264 的仓库里重做过。
  - 701 内存类型 10：经核实，类型 10 是 `AFC_REGION_TYPE`（6GHz 标准功率 AFC），这个补丁只是给它分配内存，能消掉一行警告。收益小。原补丁用空格缩进，需要重做才能打上。
  - 每个补丁最终取哪个仓库的哪一版、能否干净打上，记录在 `patches/README.md`。
- ❓ 删除了 001 hwmon 温度补丁，原因没写。推测是新版 backports 已自带，未核实。
- ❌ **CMA**（`CONFIG_CMA`/`DMA_CMA`、DTS 里 `cma=256M` 和 256MB 预留）：
  - ImmortalWrt 官方内核没开 `CONFIG_CMA`，开它就要自编内核，官方模块全部装不上。
  - 它想解决的 28MB 大块分配失败，驱动本来就会自动改用小块，不影响 WiFi 起来。
  - 还会长期占掉 1GB 内存里的 256MB。
- 📋 **DTS 电压调节器改动**（更正：原先判为"不采用"是错的）：s1 下限从 725mV 改为 587.5mV，删掉 `l5`，新增 `s2`（700–1000mV）。
  - 依据：论坛 #231 取自原厂 SCP_1.0.5 的 DTB，实测稳定一个月；QSDK 12.5 备份的 DTB 数值完全一致（s1 0x8f6ec–0x106738，s2 0xaae60–0xf4240，没有 l5）。
  - 作用：上游 DTS 里的 `l5` 注册失败（`l5: devm_regulator_register() failed`），连带 cpufreq 无法加载，CPU 停在开机频率。
    论坛 #227–#230：修好后跑到 2208MHz，跑分从 13.76s 降到 5.36s。
  - 我们的路由器上确实有这条报错，而且 `/sys/devices/system/cpu/cpufreq` 是空的。
- ❌ target 补丁 0363 NAPI 预算、0364 MP5496 供电命名：要改内核镜像，等上游（0363 对应 PR #25405）。

## yangzhg/SBE1V1K

luckkyboy 的 fork。作者 Yang Zhengguo 在 2026-08-26 提交了 5 个自己的改动，其余 400 多个提交都是合并进来的上游。
它是 WiFi 补丁 105–111 的**原作者**，Jackie264 后来在此基础上改过。

- 🔧 **ath12k 补丁原版**（提交 `6cc06a408d`）：105、106、107（每个 radio 建符号链接）、108、109（记录 WMI 拓扑）、110、111、400，
  以及 cfg80211 补丁 `subsys/100`（多 radio 的 debugfs）。和 Jackie264 的版本对照后取一版。
- 🔧 **wifi-scripts 修复 #24370**：ucode 版 `mac80211.sh` 里的 `resolve_radio_for_band()`，按频段把保存的 radio 编号重新映射。
  写法比 yintaomu 的干净，是首选候选。上游对应的 PR #24639 仍未合并。
- 📋 **DTS 平台修复**（提交 `f80ffd92ed`，上游都还没有）：
  - QCA8075 的 PQSGMII 发送幅度设为 300mV（`qcom,tx-drive-strength-milliwatt`）：和原厂 SSDK 一致；
    通用的 600mV 默认值会让 PPE port3 那路出现接收 CRC 错误。影响 lan2/lan3。
  - 禁用没有驱动的 `crypto`/`cryptobam` 节点：否则 GCC 的 `sync_state()` 一直挂着，cpufreq-dt 永远延迟加载。
    上游 `6e1fdb9ea1` **只改了 kiwi-dvk 的设备树，没改 SBE1V1K**；我们构建的固件里这两个节点仍是开着的（已解包核实）。
  - SDHCI 复位（补丁 0404）：消除 `mmc0: Reset 0x1 never completed`，论坛 #233 测试 15 次重启 0 次复现，不打时约 1/4。
    上游 `da141cba5c`（9-25）已有同类修复，但我们用的 9-18 snapshot 里没有。
- ❌ 内核补丁 0362（MP5496 供电命名）、0363（NAPI 预算）：要改内核。上面的 DTS 删掉 `l5` 已能消除供电报错。
- 📖 默认 SSID 按频段命名、6G 默认 OWE。我们沿用你自己的无线配置，不需要。
- 📖 `SBE1V1K-ROOT.md`：原厂固件 `warehouse_api` 命令注入 root（论坛 #154）。我们已有 chainloader，用不上。
- 📖 分支 `sbe1v1k-qsdk-1.5.3`（2026-09-19）：基于原厂 QSDK 1.5.3 的"生产固件"工具，保留厂商内核、闭源 WiFi、
  NSS/ECM/PPE 加速，把运营商那套软件换成标准 OpenWrt 用户态（论坛 #251）。
  **这是目前唯一能用上硬件加速的路线**，但被绑死在厂商 5.4 内核上，和我们"跟上游"的目标冲突。只作为 NSS 实验的参考。
- 📖 分支 `sbe1v1k-qsdk12-stockabi`：QSDK 12.2 原厂 ABI 镜像流程的早期版本。

## OpenWrt 论坛帖 245244

<https://forum.openwrt.org/t/spectrum-sbe1v1k-ipq9574-openwrt-support/245244>，共 271 帖，最后一帖 2026-09-27。下面用 #帖号 引用。

- 📋 **CPU 调频修复**（#227–#231）：见上面 Jackie264 和 yangzhg 两节的 DTS 项。这是目前收益最大的单项改动。
- 📋 **关闭 packet steering**（#243）：开着时 WiFi 在高并发下掉线。你路由器上现在是 `packet_steering=2`（开）。用 uci-defaults 默认关掉。
- 📖 **Rev 4.1 的内核加载地址**（#259–#269）：Rev 4.1 的 U-Boot 占用 0x41000000，加载地址必须 ≥0x42000000。
  上游现在用 0x42200000（PR #25344）。我们镜像里是 0x42080000，能启动，只是会打印一条地址未对齐的警告。你的机器 ART 里写的是 `REV:4`。
- 📖 **免拆机救砖**（#250，yangzhg）：DHCP option 43 设为 `askey` 就能触发原厂的 Reset 恢复流程，TFTP 加载后只在内存里启动。
  和我们已经在用的"按住 Reset 走 TFTP"是同一个原厂机制。
- 📖 原厂 U-Boot 从内存启动的镜像上限约 31MiB（#185）。
- 📖 WiFi 的几种临时绕过（#146、#147、#152）：按 MAC 规律（2.4G/5G/6G = MAC/MAC+1/MAC+2）重映射 radio 的 init 脚本、
  单 MLO AP 配置、降级到 WBE.1.4.1 固件以避开 WSI。有了正式的 wifi-scripts 修复就都不需要。降级固件会牺牲 WSI/MLO。
- 📖 PR #25424（按 WSI 序号排硬件组，benoitm974）：#270 说它可能修好了 radio 乱序。截至 2026-10-01 仍未合并，和补丁 108 是同一思路。
- 📖 风扇：Delta ASB0512HA，1kHz PWM 效果最好（#40–#54）。上游风扇驱动仍是半修好状态，以后单独评估。
- ❌ WAN LED 修复（#245）：依赖 realtek PHY LED 的内核补丁，我们用不了。
- ❌ EEE 导致 10G PHY 抖动的修复（#190，danpawlik `b7771ca`）：是内核补丁。路由器上 `ethtool --set-eee` 也不支持，用户态没法绕过。
- 📖 新发现的仓库：
  - `YYH2913/http-uboot`：我们 chainloader 的原始上游。
  - `insalata-fresca/openwrt-dr9574`（codeberg）：同为 IPQ9574 + 3×QCN9274 的 Wallys DR9574 主线移植，查 WMI 问题时可以参考。
  - `GlassWing833/SBE1V1K_QWRT_SOC_AUTH_SCRIPT`：QWRT 的 SoC 鉴权脚本，和我们无关。
- 📖 原厂固件下载地址：`http://scpfirmware.tau.spectrum.net/SCP_<ver>-SBE1V1K-prod.simg`，有 1.0.5、1.1.3.1、1.4.1、1.5.3 几个版本（#55、#246），
  可以拿来提取原厂 DTB 对照。
- 📖 未解决：6GHz 802.11s mesh 刷屏 `new peer notification`（#271）；lan1 2.5G 长时间断开后不重新链接（#237，只有一例，无法复现）。

## SBE1V1K_immortalwrt_NSS

上游是 VIKINGYFY/immortalwrt，把 QSDK 的 SSDK、PPE、NSS-DP、ECM 整套移植到 6.18。真机上 NSS/PPE 从没工作过：一加载就整机复位，连有线网口都丢了。

- 🧪 **三块 WiFi 卡各预留 50MB host-DDR 内存加 MLO 共享区**（DTS 片段和补丁 317、315）。Debian 版和 QSDK 备份都独立印证了这个需求。要改 DTS，留作后续实验。
- 📋 **6G 首次启动默认开 PMF**（`99-sbe1v1k-6ghz-pmf`）和**拒绝 `country=00`** 的 hostapd 补丁，与 yintaomu 的方案对照后取一版。
- 📖 首次启动无线默认关闭、不桥接到 LAN 的策略：适用于全新安装；从现有配置升级时用不上。
- 📖 FIT 解压后大小检查（保守上限 64MiB）：用原厂 U-Boot 从内存启动大镜像前，先查一下大小。
- 📖 内存 TFTP 启动和直接写 eMMC 恢复的流程文档。
- 📖 NSS 的失败原因：SSDK 向时钟控制器请求了 port5 不支持的 960MHz、1.152GHz。这是 NSS 实验分支的第一个坑。
- ❌ 整套 QSDK 加速栈、CPU 类型改 a73、经第三方分支跟上游、把 BDF 等厂商二进制提交进仓库。

## 闭源 LEDE 固件

已逐文件比对，**里面没有任何能用的专有二进制**：

- WiFi 固件和 BDF 与上游哈希相同；
- `regulatory.db` 比上游旧；
- 169 个内核模块是给 6.12 编译的，我们用 6.18，加载不了；
- 其余全是开源软件。

- 📖 真机跑通过的功能组合：中文 LuCI、DDNS、UPnP、nlbwmon、BBR、conntrack 调优。我们的包列表按需挑选。
- 📖 它证明了 6.12 LTS 在这台机器上稳定，可以作为 6.18 出大问题时的退路。
- 📖 风扇温控参数：转速 36/72/128/255，对应 40/50/65/80°C。上游 DTS 已有风扇温控，只在需要调风扇时对照。
- ❌ 不安全的默认设置：root 密码 `password`、首次启动 WiFi 开放、vsftpd 默认开启、关闭软件包签名校验。
- ❌ iptables 旧防火墙、对这台机器无效的 turboacc。

## debian-sbe1v1k

QSDK 6.6 厂商内核加 Debian 用户态，仓库里没有可直接移植的内核补丁。

- 📖 硬件实测数据：
  - board_id 对应关系（pcie1=0x01、pcie2=0x04、pcie3=0x02）；
  - ART 布局，0xF4000 起有出厂信息槽；
  - MAC 索引、QCA8081 的 LED 低有效。
- 📖 nftables 设计：只删自己建的表，不 flush 整个规则集；masquerade 不加 random，保持端点无关映射。以后写自定义防火墙脚本时参考。
- 📖 多 WAN 同时用 ICMP 和 TCP 探测（以后如需 mwan3 再参考）。
- 📖 构建时检查 `modules.dep`。我们用官方内核，暂不需要。
- 📖 ECM/PPE 卸载会导致 LAN 断流，推测与 VLAN 过滤网桥有关。这是 NSS 实验的风险提示。
- ❌ eMMC 限速 48MHz（QSDK 备份证明可以跑 HS400、384MHz）、隧道流量无条件放行、构建时从 GitHub 拉 master 不做校验。

## QSDK 12.5 备份（`sbe1v1k-qsdk-backup.tar` 中的"原厂系统"）

不是 Spectrum 原厂固件，而是第三方（lingjp）构建的 QSDK 12.5，内核 5.4.213。但它是**唯一在这台机器上跑通整套 QSDK 硬件加速的系统**，作为硬件参数的参考最可信。（备份由用户自行保存，不随仓库发布。）

- 📖 **硬件参数真值**：
  - PCIe 与频段对应：pci@10000000 是 2.4G（board_id 1），pci@20000000 是 6G（board_id 4），pci@18000000 是 5G（board_id 2）。
  - 每块卡 50MiB host-DDR，MLO 共享 18MiB。
  - eMMC 跑 HS400、384MHz。
  - LED、按键、风扇的 GPIO。
- 📖 **WiFi 超时参考**：WMI 15 秒、HTC 6 秒。分析 #24949 时与 ath12k 的默认值对比。
- 📖 **NSS 实验分支的参考配置**：
  - 端口模式：port6 USXGMII/uniphy2，port5 SGMII/uniphy1，port3/4 QSGMII/uniphy0；
  - SSDK 只用 125 和 312.5MHz 两种时钟；
  - 参考源码：CodeLinaro NHSS.QSDK.12.5。
  - 另外，QSDK 的 WiFi 加速依赖闭源 qca-wifi，用 ath12k 时做不了，硬件加速只能覆盖有线转发。
- 🧪 **QSDK 12.5 的 BDF**：各社区版本用的 BDF（`5ed8477a…`）是从更旧的 12.2 BDF 改 4 字节得来的，和 12.5 实际加载的差 1450 到 7228 字节。可以用 SDK 重编 `ipq-wifi` 做 A/B 测试。
- ❌ 它自己的 bug：LED 引脚同时被配成 PWM；WiFi 固件 WBE.1.4 比上游的 1.6 旧。

## 我们自己的 HTTP U-Boot（chainloader）

不在固件里，但决定了固件怎么装、怎么测。仓库：<https://github.com/Crescentm/http-uboot>。

- ✅ large 布局迁移（包括从 28 分区 QSDK 布局迁移），已在设备上用过。
- 🔧 RAM boot：网页上传 FIT 直接从内存启动，不写 eMMC。已编译，未上机。
- 🔧 netconsole：基于上游待合入的 lwIP netconsole 补丁系列（James Hilliard，patchwork series 521255）。恢复模式下自动广播到 UDP 6666，不用拆机接串口。已编译，未上机。
- 📖 原厂 U-Boot 内置 TFTP 自动升级通道（按住 Reset 开机，从 `172.16.252.252` 拉取 `rtq7300t_boot_auto_upgrade_fw.img`）：救砖保底，不依赖 chainloader。

---

## 汇总：主固件的待办

| 项目 | 来源 | 状态 |
|---|---|---|
| large 布局 sysupgrade | 自己 | ✅ |
| fullcone、UPnP、irqbalance、SQM、WireGuard、中文 LuCI | ImmortalWrt 源 | ✅ |
| ath12k 补丁（#24949、#23578）：mac80211/950–955、960 | yangzhg → OneNAS、PR #23786 | 🔧 已就绪，待编译上机 |
| 按频段识别 radio（#24370）：wifi-scripts/950 | PR #24639 修正版（参考 yangzhg 的顺序） | 🔧 已就绪，待编译上机 |
| `country=00` 处理、6G 强制 SAE/PMF：wifi-scripts/951、952 | NSS 版 | 🔧 已就绪，待编译上机 |
| `sbe1v1k-diag` 诊断脚本 | yintaomu | 📋 |
| 升级包完整性检查（放行 FIT） | yintaomu | 📋 |
| WiFi 回归测试：10 次冷启动检查三频 | yintaomu 判定标准 | 📋 |
| DTS：修 CPU 调频（删 l5、调整 s1/s2、禁用 crypto）：tree/0002 | 论坛 #231、yangzhg、QSDK 备份 | 🔧 已就绪，待编译上机 |
| DTS：QCA8075 发送幅度 300mV：tree/0002（SDHCI 复位已在 ImmortalWrt master 里） | yangzhg | 🔧 已就绪，待编译上机 |
| 默认关闭 packet steering：files/etc/uci-defaults/99-sbe1v1k-defaults | 论坛 #243 | 🔧 已就绪，待编译上机 |
| WiFi 预留内存（DTS） | NSS 版、Debian、QSDK | 🧪 |
| QSDK 12.5 BDF | QSDK 备份 | 🧪 |
| PPE 硬件流表卸载（实验分支） | QSDK 备份、NSS 版的踩坑记录 | 🧪 |

## 已决定

- **2026-10-01：改为从 ImmortalWrt master 源码编译**（`scripts/src-build.sh`），全部内核模块自己编译、自己发布软件源。
  原因：官方 snapshot 停更，而且论坛确认的几项修复需要改内核。先在本地出完整固件，之后再搬到 GitHub Actions，
  固件和软件源都发布在 GitHub 上。
- 改为源码编译后，"要改内核"的修复都可以重新评估：0363 NAPI 预算、0364 MP5496 供电命名、10G 口 EEE 抖动、WAN LED。
- 每个补丁的来源和打补丁的情况见 `patches/README.md`。
