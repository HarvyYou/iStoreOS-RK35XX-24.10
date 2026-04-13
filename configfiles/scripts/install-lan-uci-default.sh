#!/bin/bash
# Install uci-defaults snippet to set default LAN IPv4 at first boot.
# Reads ISTOREOS_LAN_IP from environment; default 192.168.100.1.
# Must be run with OpenWrt tree as current working directory (same as diy-part2).

set -e
LAN_IP="${ISTOREOS_LAN_IP:-192.168.100.1}"
if ! echo "$LAN_IP" | grep -qE '^([0-9]{1,3}\.){3}[0-9]{1,3}$'; then
	echo "install-lan-uci-default: invalid ISTOREOS_LAN_IP='$LAN_IP', using 192.168.100.1"
	LAN_IP=192.168.100.1
fi

OUT="package/base-files/files/etc/uci-defaults/zzz-istoreos-lan-ip"
mkdir -p "$(dirname "$OUT")"
{
	echo "#!/bin/sh"
	echo "# Baked at build time (ISTOREOS_LAN_IP=$LAN_IP)"
	echo "uci -q set network.lan.ipaddr='$LAN_IP'"
	echo "uci -q commit network"
	echo "exit 0"
} > "$OUT"
chmod +x "$OUT"
echo "install-lan-uci-default: wrote $OUT (LAN=$LAN_IP)"
