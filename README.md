# iStore OS 固件 | 定制的麻烦自行 fork 修改

[![iStore使用文档](https://img.shields.io/badge/使用文档-iStore%20OS-brightgreen?style=flat-square)](https://doc.linkease.com/zh/guide/istoreos) [![最新固件下载](https://img.shields.io/badge/最新固件下载-Releases-blue?style=flat-square)](../../releases/latest)

![支持设备](https://img.shields.io/badge/支持设备:-blueviolet.svg?style=flat-square) ![H88K](https://img.shields.io/badge/H88K-blue.svg?style=flat-square) ![H66K](https://img.shields.io/badge/H66K-blue.svg?style=flat-square) ![H68K](https://img.shields.io/badge/H68K-blue.svg?style=flat-square) ![H69K](https://img.shields.io/badge/H69K-blue.svg?style=flat-square) ![R5S](https://img.shields.io/badge/R5S-blue.svg?style=flat-square) ![R6S](https://img.shields.io/badge/R6S-blue.svg?style=flat-square) ![R66S](https://img.shields.io/badge/R66S-blue.svg?style=flat-square) ![R68S](https://img.shields.io/badge/R68S-blue.svg?style=flat-square) ![STATION P2](https://img.shields.io/badge/STATION%20P2-blue.svg?style=flat-square) ![T68M](https://img.shields.io/badge/T68M-blue.svg?style=flat-square) ![Orange Pi 5 Plus](https://img.shields.io/badge/Orange%20Pi%205%20Plus-blue.svg?style=flat-square) ![Radxa ROCK 5T](https://img.shields.io/badge/Radxa%20ROCK%205T-blue.svg?style=flat-square) ![Panther X2](https://img.shields.io/badge/Panther%20X2-blue.svg?style=flat-square)

## 关于本仓库

本仓库由维护者从原作者 **[xiaomeng9597/Actions-iStoreOS-RK35XX-24.10](https://github.com/xiaomeng9597/Actions-iStoreOS-RK35XX-24.10)** fork 而来，在保留原 Actions 与配置流程的基础上，**增加了对 Panther X2（黑豹 X2，RK3566）在 iStoreOS 24.10 / OpenWrt 6.x 主线上的适配**。Panther X2 相关改动以本仓库中的 `configfiles/dts/rk3568/`、`diy-part2-6.x.sh`、`configfiles/config_data-6.x.txt` 及说明为准。

## 默认配置

- IP: `http://192.168.100.1` or `http://iStoreOS.lan/`
- 用户名: `root`
- 密码: `password`
- 如果设备只有一个网口，则此网口就是 `LAN` , 如果大于一个网口, 默认第一个网口是 `WAN` 口, 其它都是 `LAN`
- 如果要修改 `LAN` 口 `IP` , 首页有个内网设置，或者用命令 `quickstart` 修改
- 北京时间每天 `0:00` 定时编译, `Release` 中只保留不同架构的最新版本
- 历史版本在 `Actions` 中选择一个已经运行完成且成功的 `workflow` 在页面底部可以看到 `Artifacts`, `Artifacts` 需要登录 Github 才能下载
- 请把要加入的插件配置项填写在仓库 “configfiles/config_data-6.x.txt” 文件里面，假如你直接填写到 “armv8/.config” 文件里面绝对会丢你新加的配置项，因为每天会定时执行同步文件 “Sync Files” 工作流会自动更新.config为istoreos官方最新的配置文件。
- 自行定制时需要注意这几点：假如你禁用了 “Sync Files” 工作流的话，那插件配置项就要填写到 “armv8/.config” 文件里面才行，反之你没禁用 “Sync Files” 工作流的话，那插件配置项就要填写到 “configfiles/config_data-6.x.txt” 文件里面才行。
- 使用此仓库必须设置机密token，Actions云编译固件时需要用到，其他人无法看到的（通常在仓库设置里面，严禁在仓库可视代码中填写，否则后果自负），机密键名为 `ACCESS_TOKEN`

## Panther X2（RK3566）支持说明

以下为 **iStoreOS 24.10**（`istoreos/istoreos` 分支 `istoreos-24.10`，目标 **rockchip / armv8**，内核 **6.6**）下的适配说明，与旧版 **仅 rk35xx 目标 + 5.10 内核** 的仓库（例如参考用的 [iStoreOS-RK35XX](https://github.com/xiaomeng9597/iStoreOS-RK35XX)）在架构上不同，**不能**把旧版 `.config` 或设备树原样照搬。

### 硬件与固件

| 项目 | 说明 |
| ---- | ---- |
| SoC | Rockchip RK3566 |
| 有线网卡 | 单千兆（设备树中为 `gmac1` + RGMII PHY） |
| 无线 | 博通 AP6236（SDIO，`brcmfmac`，需板级 `panther,x2` 固件别名） |
| 存储 | eMMC + microSD（与参考设备树一致） |
| 串口调试 | `stdout-path = serial2:1500000n8`（1500000 8N1） |

### 本仓库中的实现要点

1. **设备树** `configfiles/dts/rk3568/rk3566-panther-x2.dts`  
   - 使用内核树内 `<rockchip/rk3566.dtsi>` 与 `rk3568-ramoops.dtsi`，按 **Linux 6.6 / iStoreOS armv8** 的 USB、PHY 命名（如 `usb_host0_xhci`、`usb2phy0_host` 等）重写 USB 与 **combphy** 部分，而不是沿用旧 BSP 中的 `usbdrd_dwc3` 等节点。  
   - 为 USB3/PHY 增加与板级供电一致的 `regulator-fixed`（由 `vcc5v0_sys` 派生），避免无 GPIO 控制的 USB 供电在设备树上缺失。  
   - 无头路由场景下将 **HDMI / VOP** 置为 `disabled`，去掉旧版中依赖 BSP 多媒体节点名的段落，避免与主线设备树不匹配。  
   - 版权与致谢见设备树文件头注释（原始板级描述来自 tdleiyao；24.10 适配说明见同文件）。

2. **镜像与软件包**  
   - 在构建时向 `target/linux/rockchip/image/legacy.mk` 注入 `Device/panther_x2`（与现有 `Device/Legacy/rk3566` 一致），指定 `DEVICE_DTS := rk3568/rk3566-panther-x2`，并打包 `kmod-brcmfmac`、`wpad-basic-mbedtls` 与 **`brcmfmac-firmware-panther-x2`**（见 `configfiles/packages/panther-x2-firmware/`）。  
   - 固件二进制仍自 **[xiaomeng9597/brcmfmac_sdio-firmware](https://github.com/xiaomeng9597/brcmfmac_sdio-firmware)** 构建安装，并为 `compatible = "panther,x2"` 安装带 `panther,x2` 别名的文件名，供 `brcmfmac` 匹配。

3. **RK3566 机型脚本（可选稳定性补丁）**  
   - `httpubus`、`ubus-examine.sh`：在部分 RK3566 机型上缓解 ubus/rpcd 异常（仅当 `board_name` 为 `panther,x2` 时启用）。  
   - `opwifi`：延迟拉起 WiFi，便于 SDIO 固件与驱动就绪（同样仅匹配 `panther,x2`）。  
   以上逻辑参考旧 RK35XX 仓库中对黑豹 X2 的做法，脚本范围已收窄为仅 Panther X2，避免影响其它机型。

### 编译与配置

- **启用机型**：在 `configfiles/config_data-6.x.txt` 中已增加  
  `CONFIG_TARGET_DEVICE_rockchip_armv8_DEVICE_panther_x2=y` 与  
  `CONFIG_PACKAGE_brcmfmac-firmware-panther-x2=y`（若关闭 Sync 工作流，请同步改 `armv8/.config`）。  
- **合成固件包名**（多 profile 编译时产物之一）：  
  `istoreos-rockchip-armv8-panther_x2-squashfs-sysupgrade.img.gz`  
- **刷机**：请使用 **sysupgrade** 对应分区方案；首次刷入前请自行确认分区与引导（U-Boot / 介质）与官方或社区教程一致，变砖风险自负。

### 与旧版 iStoreOS-RK35XX（rk35xx / 5.10）的差异摘要

| 项目 | 旧仓库（rk35xx） | 本仓库（24.10 / armv8） |
| ---- | ------------------ | ------------------------- |
| 目标与内核 | `rockchip_rk35xx`，5.10 | `rockchip_armv8`，6.6 |
| 设备树路径与 USB | BSP 风格节点 | 按 istoreos-24.10 中 `rk3566-roc-pc` 等参考改写 |
| Kconfig 符号 | `CONFIG_TARGET_DEVICE_rockchip_rk35xx_DEVICE_panther_x2` | `CONFIG_TARGET_DEVICE_rockchip_armv8_DEVICE_panther_x2` |

## 支持架构

### RK33xx 架构

| 设备       | 包名称                                                                    |
| ---------- | ------------------------------------------------------------------------- |
| R2S        | istoreos-rockchip-armv8-friendlyarm_nanopi-r2s-squashfs-sysupgrade.img.gz |
| R4S        | istoreos-rockchip-armv8-friendlyarm_nanopi-r4s-squashfs-sysupgrade.img.gz |
| R4SE       | istoreos-rockchip-armv8-friendlyarm_nanopi-r4se-squashfs-sysupgrade.img.gz |
| ROCK-PI-4A | istoreos-rockchip-armv8-radxa_rock-pi-squashfs-sysupgrade.img.gz  |
| ROCKPRO64  | istoreos-rockchip-armv8-pine64_rockpro64-squashfs-sysupgrade.img.gz  |

### ARMv8/RK35xx 架构

| 设备           | 包名称                                                                   |
| -------------- | ------------------------------------------------------------------------ |
| H66K/H68K/H69K | istoreos-rockchip-armv8-hinlink_opc-h6xk-squashfs-sysupgrade.img.gz       |
| H88K           | istoreos-rockchip-armv8-hinlink_h88k-squashfs-sysupgrade.img.gz           |
| NANOPI-R5S     | istoreos-rockchip-armv8-friendlyarm_nanopi-r5s-squashfs-sysupgrade.img.gz |
| NANOPI-R6S     | istoreos-rockchip-armv8-friendlyarm_nanopi-r6s-squashfs-sysupgrade.img.gz |
| R66S/R68S      | istoreos-rockchip-armv8-fastrhino_r6xs-squashfs-sysupgrade.img.gz         |
| STATION-P2     | istoreos-rockchip-armv8-firefly_station-p2-squashfs-sysupgrade.img.gz     |
| T68M     | istoreos-rockchip-armv8-lyt_t68m-squashfs-sysupgrade.img.gz     |
| Orange-Pi-5-Plus     | istoreos-rockchip-armv8-xunlong_orangepi-5-plus-squashfs-sysupgrade.img.gz     |
| Radxa ROCK 5T     | istoreos-rockchip-armv8-radxa_rock-5t-squashfs-sysupgrade.img.gz     |
| **Panther X2** | **istoreos-rockchip-armv8-panther_x2-squashfs-sysupgrade.img.gz**     |

### x86 架构

| 启动       | 包名称                                              |
| ---------- | --------------------------------------------------- |
| X86-64     | istoreos-x86-64-generic-squashfs-combined.img.gz    |
| X86-64-EFI | storeos-x86-64-generic-squashfs-combined-efi.img.gz |

## 鸣谢

- 本仓库 **fork 自** [xiaomeng9597/Actions-iStoreOS-RK35XX-24.10](https://github.com/xiaomeng9597/Actions-iStoreOS-RK35XX-24.10)，感谢原作者提供的 Actions 流程、配置同步方式与 RK35xx 插件基底。
- **Panther X2** 板级设备树原始作者：**tdleiyao**（见 `rk3566-panther-x2.dts`  SPDX 注释）；旧版 **iStoreOS-RK35XX** 仓库中的 DTS、WiFi 固件包与 RK3566 脚本为本次 24.10 适配的重要参考。
- **博通 SDIO 固件仓库**：[xiaomeng9597/brcmfmac_sdio-firmware](https://github.com/xiaomeng9597/brcmfmac_sdio-firmware)。
- [istoreos](https://github.com/istoreos/istoreos) 及上游 OpenWrt 24.10 / Linux 6.6 设备树与 Rockchip 维护者。
- [P3TERX/Actions-OpenWrt](https://github.com/P3TERX/Actions-OpenWrt)
- [Microsoft Azure](https://azure.microsoft.com)
- [GitHub Actions](https://github.com/features/actions)
- [OpenWrt](https://github.com/openwrt/openwrt)
- [Lean&#39;s OpenWrt](https://github.com/coolsnowwolf/lede)
- [tmate](https://github.com/tmate-io/tmate)
- [mxschmitt/action-tmate](https://github.com/mxschmitt/action-tmate)
- [csexton/debugger-action](https://github.com/csexton/debugger-action)
- [Cowtransfer](https://cowtransfer.com)
- [WeTransfer](https://wetransfer.com/)
- [Mikubill/transfer](https://github.com/Mikubill/transfer)
- [softprops/action-gh-release](https://github.com/softprops/action-gh-release)
- [ActionsRML/delete-workflow-runs](https://github.com/ActionsRML/delete-workflow-runs)
- [dev-drprasad/delete-older-releases](https://github.com/dev-drprasad/delete-older-releases)
- [peter-evans/repository-dispatch](https://github.com/peter-evans/repository-dispatch)
- [draco-china/istoreos-actions](https://github.com/draco-china/istoreos-actions)

## 捐赠
- 如果你觉得此系统好用的话，请我喝一杯82年的凉白开吧，感谢！

-支付宝-
# <img src="https://raw.githubusercontent.com/xiaomeng9597/webfiles/refs/heads/main/zfb.jpg" alt="支付宝收款码" width="200" />

-微信-
# <img src="https://raw.githubusercontent.com/xiaomeng9597/webfiles/refs/heads/main/weixin.jpg" alt="微信收款码" width="200" />
