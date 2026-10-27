#######################################
#DIY Settings
#######################################
WRT_IP="192.168.68.1"
WRT_NAME="OWRT"
WRT_WIFI="OWRT"
#修改immortalwrt.lan关联IP
sed -i "s/192\.168\.[0-9]*\.[0-9]*/$WRT_IP/g" $(find ./feeds/luci/modules/luci-mod-system/ -type f -name "flash.js")

WIFI_SH=$(find ./target/linux/{mediatek/filogic,qualcommax}/base-files/etc/uci-defaults/ -type f -name "*set-wireless.sh")
WIFI_UC="./package/network/config/wifi-scripts/files/lib/wifi/mac80211.uc"
if [ -f "$WIFI_SH" ]; then
	#修改WIFI名称
	sed -i "s/BASE_SSID='.*'/BASE_SSID='$WRT_SSID'/g" $WIFI_SH
	#修改WIFI密码
	sed -i "s/BASE_WORD='.*'/BASE_WORD='$WRT_WORD'/g" $WIFI_SH
elif [ -f "$WIFI_UC" ]; then
	#修改WIFI名称
	sed -i "s/ssid='.*'/ssid='$WRT_SSID'/g" $WIFI_UC
	#修改WIFI密码
#	sed -i "s/key='.*'/key='$WRT_WORD'/g" $WIFI_UC
	#修改WIFI地区
	#sed -i "s/country='.*'/country='CN'/g" $WIFI_UC
	#修改WIFI加密
	#sed -i "s/encryption='.*'/encryption='psk2+ccmp'/g" $WIFI_UC
fi

CFG_FILE="./package/base-files/files/bin/config_generate"
#修改默认IP地址
sed -i "s/192\.168\.[0-9]*\.[0-9]*/$WRT_IP/g" $CFG_FILE
#修改默认主机名
sed -i "s/hostname='.*'/hostname='$WRT_NAME'/g" $CFG_FILE


##########################################
# 替换 immortalwrt 自带 Athena LED
##########################################

echo "替换 emortal Athena LED"

rm -rf package/emortal/luci-app-athena-led
rm -rf package/emortal/athena-led

#test分支
#git clone --depth=1 -b js \
#主支
git clone --depth=1 \
https://github.com/xiaren2/JDC-AX6600-Athena-LED-Controller.git \
package/_athena_tmp
#git clone --depth=1 https://github.com/xiaren2/JDC-AX6600-Athena-LED-Controller.git package/_athena_tmp

mv package/_athena_tmp/athena-led package/emortal/
mv package/_athena_tmp/luci-app-athena-led package/emortal/

rm -rf package/_athena_tmp

# 启用新包
echo "CONFIG_PACKAGE_luci-app-athena-led=y" >> .config
# 只删除这个设备里的 i18n，不删除整行
sed -i '/define Device\/jdcloud_re-cs-02/,/endef/ s/\s*luci-i18n-athena-led-zh-cn//g' \
target/linux/qualcommax/image/ipq60xx.mk

# 确保 .config 里没有旧的 i18n
sed -i '/luci-i18n-athena-led-zh-cn/d' .config

##########################################

##########################################
# 添加 rtp2httpd 流媒体转发服务器 (package 模式，强制覆盖官方旧版)
##########################################

# 1) 直接克隆到你指定的 package 目录（编译时会优先扫 package/）
git clone --depth=1 \
  https://github.com/stackia/rtp2httpd.git \
  package/rtp2httpd

# 2) 如果后面还会执行 ./scripts/feeds install -a，先把官方 feeds 里的同名包清掉，防止被覆盖
rm -rf feeds/packages/net/rtp2httpd
rm -rf feeds/luci/applications/luci-app-rtp2httpd

# 3) 启用包
echo "CONFIG_PACKAGE_rtp2httpd=y" >> .config
echo "CONFIG_PACKAGE_luci-app-rtp2httpd=y" >> .config
echo "✅ 已启用 rtp2httpd 流媒体转发服务器 (通过 package/ 方式集成，覆盖官方旧版)"

