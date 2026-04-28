#!/bin/bash
#===============================================
# Description: DIY script
# File name: diy-script.sh
# Lisence: MIT
# Author: P3TERX
# Blog: https://p3terx.com
#===============================================

# 修改uhttpd配置文件，启用nginx
# sed -i "/.*uhttpd.*/d" .config
# sed -i '/.*\/etc\/init.d.*/d' package/network/services/uhttpd/Makefile
# sed -i '/.*.\/files\/uhttpd.init.*/d' package/network/services/uhttpd/Makefile
sed -i "s/:80/:81/g" package/network/services/uhttpd/files/uhttpd.config
sed -i "s/:443/:4443/g" package/network/services/uhttpd/files/uhttpd.config
cp -a $GITHUB_WORKSPACE/configfiles/etc/* package/base-files/files/etc/
# ls package/base-files/files/etc/

# 默认 LAN IPv4（GitHub Actions 通过 ISTOREOS_LAN_IP 传入；本地可 export 后编译）
bash "$GITHUB_WORKSPACE/configfiles/scripts/install-lan-uci-default.sh"

# Panther X2 (RK3566): device tree + image recipe + firmware + RK3566-specific init
cp -f $GITHUB_WORKSPACE/configfiles/dts/rk3568/rk3566-panther-x2.dts target/linux/rockchip/dts/rk3568/
if ! grep -q "define Device/panther_x2" target/linux/rockchip/image/legacy.mk 2>/dev/null; then
	sed -i '/^TARGET_DEVICES += firefly_station-m2$/r '"$GITHUB_WORKSPACE"'/configfiles/patches/rockchip-armv8-panther-x2-legacy.mk.fragment' target/linux/rockchip/image/legacy.mk
fi
mkdir -p package/firmware
cp -a $GITHUB_WORKSPACE/configfiles/packages/panther-x2-firmware package/firmware/
cp -f $GITHUB_WORKSPACE/configfiles/httpubus package/base-files/files/etc/init.d/httpubus
cp -f $GITHUB_WORKSPACE/configfiles/ubus-examine.sh package/base-files/files/bin/ubus-examine.sh
cp -f $GITHUB_WORKSPACE/configfiles/opwifi package/base-files/files/etc/init.d/opwifi
chmod 755 package/base-files/files/etc/init.d/httpubus package/base-files/files/etc/init.d/opwifi
chmod 755 package/base-files/files/bin/ubus-examine.sh
mkdir -p package/base-files/files/etc/rc.d
ln -sf ../init.d/httpubus package/base-files/files/etc/rc.d/S99httpubus
ln -sf ../init.d/opwifi package/base-files/files/etc/rc.d/S99opwifi

# 追加自定义内核配置项
# Fix for rockchip_dmac PM runtime warning and clock subsystem hang
echo "CONFIG_PSI=y
CONFIG_KPROBES=y
CONFIG_PM=y
CONFIG_PM_CLK=y
CONFIG_PM_GENERIC_DOMAINS=y
CONFIG_PM_GENERIC_DOMAINS_OF=y
CONFIG_DMADEVICES=y
CONFIG_PL330_DMA=y
CONFIG_ROCKCHIP_DMAMUX=y" >> target/linux/rockchip/armv8/config-6.6


# 集成CPU性能跑分脚本
cp -f $GITHUB_WORKSPACE/configfiles/coremark/coremark-arm64 package/base-files/files/bin/coremark-arm64
cp -f $GITHUB_WORKSPACE/configfiles/coremark/coremark-arm64.sh package/base-files/files/bin/coremark.sh
chmod 755 package/base-files/files/bin/coremark-arm64
chmod 755 package/base-files/files/bin/coremark.sh


# 复制dts设备树文件到指定目录下
cp -a $GITHUB_WORKSPACE/configfiles/dts/rk3588/* target/linux/rockchip/dts/rk3588/


# iStoreOS-settings
[ -d package/default-settings ] || git clone --depth=1 -b main https://github.com/xiaomeng9597/istoreos-settings package/default-settings


# 定时限速插件
[ -d package/luci-app-eqosplus ] || git clone --depth=1 https://github.com/sirpdboy/luci-app-eqosplus package/luci-app-eqosplus
