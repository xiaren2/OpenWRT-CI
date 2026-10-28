#!/bin/sh
# 硬件流量卸载排除默认配置
# 依赖 firewall4 补丁 900-flow-offload-exclusions.patch
#
# flow_offloading_exclude_ips      不参与卸载的 IPv4 网段（往返这些网段的
#                                  TCP/UDP 转发流保持软件路径，仅填合法 CIDR）
# flow_offloading_exclude_devices  不参与卸载的接口（该口所有流量保持软件
#                                  路径，会失去硬件加速，按需启用）

uci -q batch <<'EOF'
set firewall.@defaults[0].flow_offloading='0'
set firewall.@defaults[0].flow_offloading_hw='0'
add_list firewall.@defaults[0].flow_offloading_exclude_ips='192.168.1.0/24'
commit firewall
EOF

# 示例：排除 lan1 口（取消注释即可）
# uci add_list firewall.@defaults[0].flow_offloading_exclude_devices='lan1'
# uci commit firewall
