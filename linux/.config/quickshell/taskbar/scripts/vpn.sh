#!/usr/bin/env bash
# Status des WireGuard-Tunnels wg0 für die Taskleiste (Vpn.qml).
#   vpn.sh          Zustand ausgeben: on | pending | off | open, danach
#                   Details als SCHLÜSSEL=WERT (name, endpoint, handshake,
#                   rx, tx, lock) für das VPN-Fenster (VpnPanel.qml)
#   vpn.sh toggle   verbinden/trennen
#   vpn.sh lock | unlock   Internet ohne VPN sperren / freigeben
# Ohne Passwort über die Polkit-Regel (gentoo/files/etc/polkit-1/rules.d/50-vpn.rules).
#
# on = verbunden (grün), pending = verbindet / keine Antwort vom Server
# (orange), off = getrennt, Fehler oder nicht eingerichtet (rot),
# open = getrennt und Sperre aufgehoben, Internet ohne VPN (rot gefüllt)

iface=wg0
service=wg-quick-$iface

svc_start() { systemctl start "$1"; }
svc_stop() { systemctl stop "$1"; }
svc_active() { systemctl is-active --quiet "$1"; }
svc_state() { systemctl is-active "$1" 2>/dev/null; }
configured() { [ -e /etc/wireguard/$iface.conf ]; }
name_file=/etc/wireguard/$iface.name

case ${1:-} in
  toggle)
    if svc_active "$service"; then
      svc_stop "$service"
    else
      svc_start "$service"
    fi
    exit
    ;;
  lock) svc_start vpn-lock; exit ;;
  unlock) svc_stop vpn-lock; exit ;;
esac

endpoint="" handshake=0 rx=0 tx=0
details() {
  echo "name=$(cat "$name_file" 2>/dev/null)"
  configured && echo setup=yes || echo setup=no
  echo "endpoint=$endpoint"
  echo "handshake=$handshake"
  echo "rx=$rx"
  echo "tx=$tx"
  svc_active vpn-lock && echo lock=on || echo lock=off
}
trap details EXIT

if ! configured; then
  echo off
  exit
fi

state=$(svc_state "$service")
case $state in
  activating | deactivating)
    echo pending
    exit
    ;;
esac

if [ -d /sys/class/net/$iface ]; then
  # Endpoint und letzter Handshake – schreibt der Dienst vpn-peer-info
  while IFS='=' read -r k v; do
    case $k in
      endpoint) endpoint=$v ;;
      handshake) handshake=$v ;;
    esac
  done </run/$iface-peer-info 2>/dev/null
  printf -v now '%(%s)T' -1
  read -r rx </sys/class/net/$iface/statistics/rx_bytes
  read -r tx </sys/class/net/$iface/statistics/tx_bytes

  # WireGuard erneuert den Handshake alle 2 min; nach 3 min ohne gilt die
  # Verbindung als tot. Ohne Status-Datei: wurde überhaupt etwas empfangen?
  if [ -n "$endpoint" ]; then
    [ "$handshake" -gt 0 ] && [ $((now - handshake)) -le 180 ] && echo on || echo pending
  else
    [ "$(cat /sys/class/net/$iface/statistics/rx_bytes)" -gt 0 ] && echo on || echo pending
  fi
elif [ "$state" != failed ] && ! svc_active vpn-lock; then
  echo open
else
  echo off
fi
