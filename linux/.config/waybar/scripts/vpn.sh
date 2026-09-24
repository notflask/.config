#!/usr/bin/env bash
# Waybar-Modul custom/vpn: Status des WireGuard-Tunnels wg0 (siehe vpn.nix).
#   vpn.sh          JSON für Waybar ausgeben
#   vpn.sh toggle   verbinden/trennen (fragt per Polkit nach dem Passwort)

iface=wg0
service=wg-quick-$iface

if [ "${1:-}" = toggle ]; then
  if systemctl is-active --quiet "$service"; then
    systemctl stop "$service"
  else
    systemctl start "$service"
  fi
  pkill -RTMIN+8 -x 'waybar|\.waybar-wrapped'
  exit
fi

human() { numfmt --to=iec --suffix=B "$1" 2>/dev/null || echo "${1}B"; }

if [ ! -e /etc/wireguard/$iface.conf ]; then
  printf '{"text":"󰖂","class":"missing","tooltip":"VPN nicht eingerichtet\\nvpn import DATEI.conf"}\n'
elif [ -d /sys/class/net/$iface ]; then
  ip=$(ip -4 -o addr show "$iface" | awk '{print $4}')
  rx=$(human "$(cat /sys/class/net/$iface/statistics/rx_bytes)")
  tx=$(human "$(cat /sys/class/net/$iface/statistics/tx_bytes)")
  printf '{"text":"󰦝 VPN","class":"connected","tooltip":"VPN verbunden (%s)\\nAdresse: %s\\n↓ %s   ↑ %s\\nKill-Switch: aktiv\\n\\nKlick: trennen"}\n' \
    "$iface" "$ip" "$rx" "$tx"
elif systemctl is-failed --quiet "$service"; then
  printf '{"text":"󰦞 VPN","class":"failed","tooltip":"VPN-Fehler – journalctl -u %s\\n\\nKlick: erneut verbinden"}\n' "$service"
else
  printf '{"text":"󰦞","class":"disconnected","tooltip":"VPN getrennt\\nKill-Switch: aus\\n\\nKlick: verbinden"}\n'
fi
