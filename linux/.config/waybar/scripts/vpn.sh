#!/usr/bin/env bash
# Waybar-Modul custom/vpn: Status des WireGuard-Tunnels wg0 (siehe vpn.nix).
#   vpn.sh          JSON für Waybar ausgeben
#   vpn.sh toggle   verbinden/trennen (fragt per Polkit nach dem Passwort)
#
# Farben (style.css): grün = verbunden, orange = verbindet / keine Antwort
# vom Server, rot = getrennt / Fehler / nicht eingerichtet

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

# $1 Symbol, $2 Klasse, $3 Tooltip
out() { printf '{"text":"%s  VPN","class":"%s","tooltip":"%s"}\n' "$1" "$2" "$3"; }

state=$(systemctl is-active "$service" 2>/dev/null)

if [ ! -e /etc/wireguard/$iface.conf ]; then
  out "󰦞" off "VPN nicht eingerichtet\\nvpn import DATEI.conf"
elif [ "$state" = activating ] || [ "$state" = deactivating ]; then
  out "󰦖" pending "VPN verbindet …"
elif [ -d /sys/class/net/$iface ]; then
  ip=$(ip -4 -o addr show "$iface" | awk '{print $4}')
  rx_bytes=$(cat /sys/class/net/$iface/statistics/rx_bytes)
  rx=$(human "$rx_bytes")
  tx=$(human "$(cat /sys/class/net/$iface/statistics/tx_bytes)")
  info="Adresse: $ip\\n↓ $rx   ↑ $tx\\nKill-Switch: aktiv (ohne Tunnel kein Internet)\\n\\nKlick: trennen"
  if [ "$rx_bytes" -eq 0 ]; then
    # Tunnel steht, aber vom Server kam noch nichts zurück
    out "󰦖" pending "VPN: keine Antwort vom Server\\n$info"
  else
    out "󰦝" on "VPN verbunden\\n$info"
  fi
elif [ "$state" = failed ]; then
  out "󰦞" off "VPN-Fehler – journalctl -u $service\\n\\nKlick: erneut verbinden"
else
  out "󰦞" off "VPN getrennt\\nKill-Switch: aus\\n\\nKlick: verbinden"
fi
