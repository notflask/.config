#!/usr/bin/env bash
# Status des WireGuard-Tunnels wg0 für die Taskleiste (Vpn.qml, siehe vpn.nix).
#   vpn.sh          Zustand ausgeben: on | pending | off | open
#   vpn.sh toggle   verbinden/trennen (fragt per Polkit nach dem Passwort)
#
# on = verbunden (grün), pending = verbindet / keine Antwort vom Server
# (orange), off = getrennt, Fehler oder nicht eingerichtet (rot),
# open = getrennt und Sperre aufgehoben, Internet ohne VPN (rot gefüllt)

iface=wg0
service=wg-quick-$iface

if [ "${1:-}" = toggle ]; then
  if systemctl is-active --quiet "$service"; then
    systemctl stop "$service"
  else
    systemctl start "$service"
  fi
  exit
fi

if [ ! -e /etc/wireguard/$iface.conf ]; then
  echo off
  exit
fi

state=$(systemctl is-active "$service" 2>/dev/null)
case $state in
  activating | deactivating)
    echo pending
    exit
    ;;
esac

if [ -d /sys/class/net/$iface ]; then
  # Endpoint und letzter Handshake – schreibt der Dienst vpn-peer-info
  endpoint="" handshake=0
  while IFS='=' read -r k v; do
    case $k in
      endpoint) endpoint=$v ;;
      handshake) handshake=$v ;;
    esac
  done </run/$iface-peer-info 2>/dev/null
  printf -v now '%(%s)T' -1

  # WireGuard erneuert den Handshake alle 2 min; nach 3 min ohne gilt die
  # Verbindung als tot. Ohne Status-Datei: wurde überhaupt etwas empfangen?
  if [ -n "$endpoint" ]; then
    [ "$handshake" -gt 0 ] && [ $((now - handshake)) -le 180 ] && echo on || echo pending
  else
    [ "$(cat /sys/class/net/$iface/statistics/rx_bytes)" -gt 0 ] && echo on || echo pending
  fi
elif [ "$state" != failed ] && ! systemctl is-active --quiet vpn-lock; then
  echo open
else
  echo off
fi
