#!/usr/bin/env bash
# Waybar-Modul custom/vpn: Status des WireGuard-Tunnels wg0 (siehe vpn.nix).
#   vpn.sh          JSON für Waybar ausgeben (Tooltip mit Pango-Markup)
#   vpn.sh toggle   verbinden/trennen (fragt per Polkit nach dem Passwort)
#
# Farben (style.css): grün = verbunden, orange = verbindet / keine Antwort
# vom Server, rot = getrennt / Fehler / nicht eingerichtet,
# rot gefüllt = getrennt und Sperre aufgehoben (Internet ohne VPN)

iface=wg0
service=wg-quick-$iface
rates=${XDG_RUNTIME_DIR:-/tmp}/waybar-vpn-rates

if [ "${1:-}" = toggle ]; then
  if systemctl is-active --quiet "$service"; then
    systemctl stop "$service"
  else
    systemctl start "$service"
  fi
  pkill -RTMIN+8 -x 'waybar|\.waybar-wrapped'
  exit
fi

# Farben wie in style.css (Catppuccin)
green='#a6e3a1' orange='#fab387' red='#f38ba8' dim='#9399b2'

human() { numfmt --to=iec --suffix=B --format=%.1f "$1" 2>/dev/null || echo "${1}B"; }

# Dauer in Sekunden → „1 h 5 min“, „3 min“, „12 s“
dur() {
  local s=$1
  if [ "$s" -ge 3600 ]; then echo "$((s / 3600)) h $((s % 3600 / 60)) min"
  elif [ "$s" -ge 60 ]; then echo "$((s / 60)) min"
  else echo "$s s"; fi
}

# $1 Farbe, $2 Symbol, $3 Überschrift
head_line() { printf '<span size="large" weight="bold" foreground="%s">%s  %s</span>\n' "$1" "$2" "$3"; }
# Tabellenzeile: Beschriftung in fester Breite, damit die Werte untereinander stehen
row() { printf '<tt><span foreground="%s">%-11s</span></tt> %s\n' "$dim" "$1" "$2"; }
hint() { printf '<span foreground="%s" size="small">%s</span>' "$dim" "$1"; }

# $1 Symbol, $2 Klasse, $3 Tooltip (Markup)
out() {
  local t=$3
  t=${t//\\/\\\\}
  t=${t//\"/\\\"}
  t=${t//$'\n'/\\n}
  printf '{"text":"<span font_family=%s size=%s rise=%s>%s</span>  VPN","class":"%s","tooltip":"%s"}\n' \
    "'Symbols Nerd Font'" "'13pt'" "'-1pt'" "$1" "$2" "$t"
}

profile=$(cat /etc/wireguard/$iface.name 2>/dev/null)
profile=${profile//&/&amp;} profile=${profile//</&lt;} profile=${profile//>/&gt;}
state=$(systemctl is-active "$service" 2>/dev/null)
now=$(date +%s)

if [ ! -e /etc/wireguard/$iface.conf ]; then
  out "󰦞" off "$(head_line "$red" 󰦞 'VPN nicht eingerichtet')

$(hint 'vpn import DATEI.conf [NAME]')"

elif [ "$state" = activating ] || [ "$state" = deactivating ]; then
  out "󰦖" pending "$(head_line "$orange" 󰦖 'VPN verbindet …')"

elif [ -d /sys/class/net/$iface ]; then
  addr=$(ip -4 -o addr show "$iface" | awk '{print $4}')
  mtu=$(cat /sys/class/net/$iface/mtu)
  rx=$(cat /sys/class/net/$iface/statistics/rx_bytes)
  tx=$(cat /sys/class/net/$iface/statistics/tx_bytes)
  dns=$(awk '/^nameserver/ {printf "%s%s", sep, $2; sep=", "}' /etc/resolv.conf)

  # Aktuelle Geschwindigkeit aus der Differenz zum letzten Aufruf
  speed=""
  if read -r t0 rx0 tx0 < "$rates" 2>/dev/null && [ "$now" -gt "$t0" ] && [ "$rx" -ge "$rx0" ]; then
    dt=$((now - t0))
    speed="↓ $(human $(((rx - rx0) / dt)))/s   ↑ $(human $(((tx - tx0) / dt)))/s"
  fi
  echo "$now $rx $tx" > "$rates"

  # Endpoint und Handshake (braucht root, per sudoers freigegeben)
  endpoint="" handshake=0
  while IFS='=' read -r k v; do
    case $k in
      endpoint) endpoint=$v ;;
      handshake) handshake=$v ;;
    esac
  done < <(sudo -n /run/current-system/sw/bin/vpn-peer-info 2>/dev/null)

  since=$(systemctl show -P ActiveEnterTimestamp "$service")
  since_s=$(date -d "$since" +%s 2>/dev/null || echo "$now")

  if [ -z "$endpoint" ]; then
    hs_age=0
    hs="–"
  elif [ "$handshake" -gt 0 ]; then
    hs_age=$((now - handshake))
    hs="vor $(dur "$hs_age")"
  else
    hs_age=999999
    hs="noch keiner"
  fi
  # WireGuard erneuert den Handshake alle 2 min; nach 3 min ohne gilt die
  # Verbindung als tot. Ohne sudo-Info auf empfangene Bytes zurückfallen.
  if [ -n "$endpoint" ]; then alive=$([ "$hs_age" -le 180 ] && echo 1)
  else alive=$([ "$rx" -gt 0 ] && echo 1); fi

  body="$(row Profil "<b>${profile:-unbekannt}</b>")
$(row Server "${endpoint:-–}")
$(row Adresse "$addr")
$(row DNS "$dns")
$(row Handshake "$hs")
$(row Verbunden "seit $(date -d "@$since_s" +%H:%M) · $(dur $((now - since_s)))")

$(row Jetzt "${speed:-…}")
$(row Gesamt "↓ $(human "$rx")   ↑ $(human "$tx")")
$(row MTU "$mtu")

$(row Kill-Switch "<span foreground=\"$green\">aktiv</span> · nur über den Tunnel")"
  body+=$'\n'
  [ -z "$profile" ] && body+=$'\n'"$(hint 'Profilname fehlt: vpn name NAME')"
  body+=$'\n'"$(hint 'Klick: trennen')"

  if [ -n "$alive" ]; then
    out "󰦝" on "$(head_line "$green" 󰦝 'VPN verbunden')
$body"
  else
    out "󰦖" pending "$(head_line "$orange" 󰦖 'Keine Antwort vom Server')
$body"
  fi

elif [ "$state" = failed ]; then
  out "󰦞" off "$(head_line "$red" 󰦞 'VPN-Fehler')
$(row Profil "${profile:-unbekannt}")

$(hint "journalctl -u $service")
$(hint 'Klick: erneut verbinden')"

else
  rm -f "$rates"
  if systemctl is-active --quiet vpn-lock; then
    out "󰦞" off "$(head_line "$red" 󰦞 'VPN getrennt')
$(row Profil "${profile:-unbekannt}")
$(row Internet "<span foreground=\"$green\">gesperrt</span> · nur LAN erreichbar")

$(hint 'vpn unlock: Internet ohne VPN freigeben')
$(hint 'Klick: verbinden')"
  else
    out "󰦞" open "$(head_line "$red" 󰦞 'VPN getrennt')
$(row Profil "${profile:-unbekannt}")
$(row Internet "<span foreground=\"$red\" weight=\"bold\">OFFEN · ohne VPN!</span>")

$(hint 'vpn lock: wieder sperren')
$(hint 'Klick: verbinden')"
  fi
fi
