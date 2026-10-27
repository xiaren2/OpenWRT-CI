#!/bin/bash

#安装和更新软件包（diy.sh 是独立进程，必须自带定义，不能依赖 Packages.sh）
UPDATE_PACKAGE() {
	local PKG_NAME=$1
	local PKG_REPO=$2
	local PKG_BRANCH=$3
	local PKG_SPECIAL=$4

	# 清理旧的包(更精确的匹配)
	read -ra PKG_NAMES <<< "$PKG_NAME"
	for NAME in "${PKG_NAMES[@]}"; do
		find feeds/luci/ feeds/packages/ package/ -maxdepth 3 -type d \( -name "$NAME" -o -name "luci-*-$NAME" \) -exec rm -rf {} + 2>/dev/null
	done

	# 克隆仓库
	if [[ $PKG_REPO == http* ]]; then
		local REPO_NAME=$(basename "$PKG_REPO" .git)
	else
		local REPO_NAME=$(echo "$PKG_REPO" | cut -d '/' -f 2)
		PKG_REPO="https://github.com/$PKG_REPO.git"
	fi

	# 检查是否克隆成功
	if ! git clone --depth=1 --single-branch --branch "$PKG_BRANCH" "$PKG_REPO" "package/$REPO_NAME"; then
		echo "错误: 克隆仓库失败 $PKG_REPO"
		return 1
	fi

	# 根据 PKG_SPECIAL 处理包
	case "$PKG_SPECIAL" in
		"pkg")
			for NAME in "${PKG_NAMES[@]}"; do
				# 从仓库根目录搜索,不限制路径结构
				find "./package/$REPO_NAME" -maxdepth 3 -type d \( -name "$NAME" -o -name "luci-*-$NAME" \) -print0 | \
					xargs -0 -I {} cp -rf {} ./package/ 2>/dev/null
			done
			rm -rf "./package/$REPO_NAME/"
			;;
		"name")
			# 避免重命名冲突
			rm -rf "./package/$PKG_NAME"
			mv -f "./package/$REPO_NAME" "./package/$PKG_NAME"
			;;
	esac
}

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
##########################################

UPDATE_PACKAGE "luci-app-ddns-go" "OldCoding/luci-app-ddns-go" "main"
UPDATE_PACKAGE "luci-app-onliner-overview" "https://github.com/xiaren2/luci-app-onliner-overview.git" "new"
UPDATE_PACKAGE "luci-app-tcpdump-master" "https://github.com/xiaren2/luci.git" "main" "pkg"
UPDATE_PACKAGE "luci-app-vnt2" "https://github.com/whzhni1/luci-app-tailscale.git" "main"
UPDATE_PACKAGE "openwrt-bandix" "timsaya/openwrt-bandix" "main"
UPDATE_PACKAGE "luci-app-bandix" "timsaya/luci-app-bandix" "main"
UPDATE_PACKAGE "luci-app-igmpproxy" "xiaren2/luci-app-igmp" "main"


# Configuration lines to append to .config
provided_config_lines=(
  # "CONFIG_PACKAGE_luci-app-zerotier=y"
  #  "CONFIG_PACKAGE_luci-i18n-zerotier-zh-cn=y"
  "CONFIG_PACKAGE_luci-app-tailscale=y"
  "CONFIG_PACKAGE_luci-i18n-tailscale-zh-cn=y"
   # "CONFIG_PACKAGE_luci-app-adguardhome=n"
 #   "CONFIG_PACKAGE_luci-i18n-adguardhome-zh-cn=n"
  #  "CONFIG_PACKAGE_luci-app-poweroff=y"
   # "CONFIG_PACKAGE_luci-i18n-poweroff-zh-cn=y"
   # "CONFIG_PACKAGE_cpufreq=y"
  #  "CONFIG_PACKAGE_luci-app-cpufreq=y"
   # "CONFIG_PACKAGE_luci-i18n-cpufreq-zh-cn=y"
    "CONFIG_PACKAGE_luci-app-ttyd=y"
    "CONFIG_PACKAGE_luci-i18n-ttyd-zh-cn=y"
    "CONFIG_PACKAGE_ttyd=y"
  #  "CONFIG_PACKAGE_luci-app-homeproxy=y"
  #  "CONFIG_PACKAGE_luci-i18n-homeproxy-zh-cn=y"
    "CONFIG_PACKAGE_luci-app-ddns-go=y"
    "CONFIG_PACKAGE_luci-i18n-ddns-go-zh-cn=y"
  #  "CONFIG_PACKAGE_luci-app-argon-config=y"
  #  "CONFIG_PACKAGE_luci-app-argon=n"
    #"CONFIG_PACKAGE_nano=y"
    "CONFIG_BUSYBOX_CONFIG_LSUSB=n"
 #  "CONFIG_PACKAGE_luci-app-netspeedtest=y"
   # "CONFIG_PACKAGE_luci-app-vlmcsd=y"
    "CONFIG_COREMARK_OPTIMIZE_O3=y"
    "CONFIG_COREMARK_ENABLE_MULTITHREADING=y"
    "CONFIG_COREMARK_NUMBER_OF_THREADS=6"
    #"CONFIG_PACKAGE_luci-theme-design=y"
    "CONFIG_PACKAGE_luci-app-filetransfer=y"
    "CONFIG_PACKAGE_openssh-sftp-server=y"
   # "CONFIG_PACKAGE_luci-app-frpc=y" 
   #apk还是opkg
  #  "CONFIG_OPKG_USE_CURL=y"
  #  "CONFIG_PACKAGE_opkg=y"   
   "CONFIG_USE_APK=y"
    "CONFIG_PACKAGE_apk-openssl=y"
	
   # "CONFIG_PACKAGE_luci-app-tailscale=y"
    #"CONFIG_PACKAGE_luci-app-msd_lite=y"
   # "CONFIG_PACKAGE_luci-app-lucky=y"
   # "CONFIG_PACKAGE_luci-app-gecoosac=y"
	"CONFIG_PACKAGE_kmod-wireguard=y"
    "CONFIG_PACKAGE_wireguard-tools=y"
	"CONFIG_PACKAGE_luci-proto-wireguard=y"
  # "CONFIG_PACKAGE_luci-app-cifs-mount=y"
	"CONFIG_PACKAGE_kmod-fs-cifs=y"
    "CONFIG_PACKAGE_cifsmount=y"
   # "CONFIG_PACKAGE_luci-app-onliner=y"
	 "CONFIG_PACKAGE_luci-app-onliner-overview=y"
    "CONFIG_PACKAGE_luci-theme-bootstrap=y"
	 "CONFIG_PACKAGE_luci-app-tcpdump=y"
	 "CONFIG_PACKAGE_luci-app-tcpdump-zh-cn=y"
	# "CONFIG_PACKAGE_ddnsto=y"
	#  "CONFIG_PACKAGE_luci-app-ddnsto=y"
	# "CONFIG_PACKAGE_luci-app-ddnsto-zh-cn=y"
	 # "CONFIG_PACKAGE_luci-app-aurora-config=y"
	#  "CONFIG_PACKAGE_luci-app-mini-diskmanager=y"
)
# 修改"CONFIG_USE_APK=n"和WRT-core里的，会将apk源替换为ipk，如用apk，opkg相关也应删除

provided_config_lines+=(
    #"CONFIG_PACKAGE_luci-app-diskman=y"
    #"CONFIG_PACKAGE_luci-i18n-diskman-zh-cn=y"
	
#	docker相关内容
  #  "CONFIG_PACKAGE_luci-app-docker=m"
  #  "CONFIG_PACKAGE_luci-i18n-docker-zh-cn=m"
 #   "CONFIG_PACKAGE_luci-app-dockerman=m"
 #   "CONFIG_PACKAGE_luci-i18n-dockerman-zh-cn=m"
    #"CONFIG_PACKAGE_luci-app-podman=y"
    #"CONFIG_PACKAGE_podman=y"
 #   "CONFIG_PACKAGE_iptables-mod-extra=y"
 #   "CONFIG_PACKAGE_ip6tables-nft=y"
 #   "CONFIG_PACKAGE_ip6tables-mod-fullconenat=y"
 #   "CONFIG_PACKAGE_iptables-mod-fullconenat=y"
  #  "CONFIG_PACKAGE_libip4tc=y"
  #  "CONFIG_PACKAGE_libip6tc=y"
  #   "CONFIG_PACKAGE_kmod-ip6tables=y"
 #    "CONFIG_PACKAGE_kmod-ipt-conntrack=y"
   #  "CONFIG_PACKAGE_kmod-ipt-extra=y"
   #  "CONFIG_PACKAGE_kmod-ipt-nat=y"
   #  "CONFIG_PACKAGE_kmod-ipt-nat6=y"
    # "CONFIG_PACKAGE_kmod-ipt-physdev=y"
  #   "CONFIG_PACKAGE_kmod-nf-ipt6=y"
   #  "CONFIG_PACKAGE_kmod-nf-ipvs=y"
  #   "CONFIG_PACKAGE_kmod-nf-nat6=y"
 # "CONFIG_PACKAGE_iptables-mod-conntrack-extra=y"
 #    "CONFIG_PACKAGE_kmod-br-netfilter=y"
 	# "CONFIG_PACKAGE_kmod-dummy=y"
 	"CONFIG_PACKAGE_kmod-veth=y"
	
	 # "CONFIG_PACKAGE_luci-app-openlist2=y"
 #   "CONFIG_PACKAGE_luci-i18n-openlist2-zh-cn=y"
    #"CONFIG_PACKAGE_fdisk=y"
    #"CONFIG_PACKAGE_parted=y"
#	"CONFIG_PACKAGE_luci-app-homeproxy=y"
#    "CONFIG_PACKAGE_luci-app-passwall=y"
#    "CONFIG_PACKAGE_luci-app-passwall_INCLUDE_Shadowsocks_Libev_Client=y"
    "CONFIG_PACKAGE_luci-app-passwall_INCLUDE_Shadowsocks_Libev_Server=n"
    "CONFIG_PACKAGE_luci-app-passwall_INCLUDE_ShadowsocksR_Libev_Client=n"
    "CONFIG_PACKAGE_luci-app-passwall_INCLUDE_Simple_Obfs=n"
    "CONFIG_PACKAGE_luci-app-passwall_INCLUDE_SingBox=n"
    "CONFIG_PACKAGE_luci-app-passwall_INCLUDE_Trojan_Plus=n"
    "CONFIG_PACKAGE_luci-app-passwall_INCLUDE_V2ray_Plugin=n"
    "CONFIG_PACKAGE_htop=y"
    #"CONFIG_PACKAGE_fuse-utils=y"
    "CONFIG_PACKAGE_tcpdump=y"
    #"CONFIG_PACKAGE_sgdisk=y"
    "CONFIG_PACKAGE_openssl-util=y"
    #"CONFIG_PACKAGE_resize2fs=y"
   # "CONFIG_PACKAGE_qrencode=y"
    "CONFIG_PACKAGE_smartmontools-drivedb=y"
    "CONFIG_PACKAGE_usbutils=y"
    "CONFIG_PACKAGE_default-settings=y"
    "CONFIG_PACKAGE_default-settings-chn=y"
   
  
   

    #"CONFIG_PACKAGE_automount=y"
 #   "CONFIG_PACKAGE_luci-app-frps=y"
    #"CONFIG_PACKAGE_luci-app-ssr-plus=y"
    #"CONFIG_PACKAGE_luci-app-passwall2=y"
    "CONFIG_PACKAGE_luci-app-samba4=y"
    "CONFIG_PACKAGE_libicu=y"
    "CONFIG_PACKAGE_icu=y"
    "CONFIG_PACKAGE_luci-app-openclash=y"
    #"CONFIG_PACKAGE_luci-app-quickfile=y"
    #"CONFIG_PACKAGE_quickfile=y"
	"CONFIG_PACKAGE_luci-app-wolplus=y"
#"CONFIG_PACKAGE_luci-app-diskman=y"
"CONFIG_PACKAGE_luci-app-omcproxy=y"
"CONFIG_PACKAGE_luci-app-ttyd=y"
#"CONFIG_PACKAGE_luci-app-msd_lite=y"
"CONFIG_PACKAGE_luci-app-tcpdump=y"
"CONFIG_PACKAGE_luci-app-bandix=y"
"CONFIG_PACKAGE_luci-app-filemanager=y"
#"CONFIG_PACKAGE_luci-app-ngrokc=y"
"CONFIG_PACKAGE_luci-app-igmpproxy=y"
#"CONFIG_PACKAGE_luci-app-mini-diskmanager=y"
"CONFIG_PACKAGE_luci-app-uhttpd=y"
#"CONFIG_PACKAGE_luci-app-wifihistory=n"
"CONFIG_PACKAGE_luci-app-wechatpush=y"
#"CONFIG_PACKAGE_luci-app-netwiz=y"
"CONFIG_PACKAGE_tcpdump=y"
"CONFIG_PACKAGE_bandix=y"
"CONFIG_PACKAGE_igmpproxy=y"
)

# 把上面的插件配置写入 .config（缺这段，数组里的插件一个都不会生效）
for line in "${provided_config_lines[@]}"; do
    echo "$line" >> .config
done

#修改ttyd为免密
install -Dm755 "${GITHUB_WORKSPACE}/Scripts/99_ttyd-nopass.sh" "package/base-files/files/etc/uci-defaults/99_ttyd-nopass"

#修改软件源地址，当是opkg的时候
#install -Dm755 "${GITHUB_WORKSPACE}/Scripts/99-distfeeds.conf" "package/emortal/default-settings/files/99-distfeeds.conf"
#sed -i '/define Package\/default-settings\/install/a \
#\t$(INSTALL_DIR) $(1)/etc\n\t$(INSTALL_DATA) ./files/99-distfeeds.conf $(1)/etc/99-distfeeds.conf' \
#package/emortal/default-settings/Makefile
#sed -i "/exit 0/i\\
#[ -f \'/etc/99-distfeeds.conf\' ] && mv \'/etc/99-distfeeds.conf\' \'/etc/opkg/distfeeds.conf\'\n\
#sed -ri \'/check_signature/s@^[^#]@#&@\' /etc/opkg.conf\n" "package/emortal/default-settings/files/99-default-settings"
