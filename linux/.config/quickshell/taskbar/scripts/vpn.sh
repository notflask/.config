#!/usr/bin/env bash
# Status des WireGuard-Tunnels wg0 für die Taskleiste (Vpn.qml, siehe vpn.nix).
#   vpn.sh          Zustand ausgeben: on | pending | off | open, danach
#                   Details als SCHLÜSSEL=WERT (name, endpoint, handshake,
#                   rx, tx, lock) für das VPN-Fenster (VpnPanel.qml)
#   vpn.sh toggle   verbinden/trennen
#   vpn.sh lock | unlock   Internet ohne VPN sperren / freigeben
# Ohne Passwort: NixOS über die Polkit-Regel in vpn.nix, Void Linux über
# sudo-Regeln für `sv` (linux/void/etc/sudoers.d/g5-vpn).
#
# on = verbunden (grün), pending = verbindet / keine Antwort vom Server
# (orange), off = getrennt, Fehler oder nicht eingerichtet (rot),
# open = getrennt und Sperre aufgehoben, Internet ohne VPN (rot gefüllt)

iface=wg0
service=wg-quick-$iface

if [ -d /run/systemd/system ]; then
  svc_start() { systemctl start "$1"; }
  svc_stop() { systemctl stop "$1"; }
  svc_active() { systemctl is-active --quiet "$1"; }
  svc_state() { systemctl is-active "$1" 2>/dev/null; }
  configured() { [ -e /etc/wireguard/$iface.conf ]; }
  name_file=/etc/wireguard/$iface.name
else
  # Void Linux (runit): Zustand aus /run/vpn – die Dienste in linux/void/sv
  # legen dort NAME.up, NAME.starting bzw. NAME.failed an (der Status von
  # runit selbst ist nur für root lesbar)
  svc_start() { sudo -n sv up "$1"; }
  svc_stop() { sudo -n sv down "$1"; }
  svc_active() { [ -e "/run/vpn/$1.up" ]; }
  # /etc/wireguard ist nur für root lesbar – der Dienst sagt, ob es eine
  # Config gibt, und legt den Profilnamen ab (linux/void/sv/wg-quick-wg0)
  configured() { [ ! -e "/run/vpn/$service.noconf" ]; }
  name_file=/run/vpn/$iface.name
  svc_state() {
    if [ -e "/run/vpn/$1.starting" ]; then
      echo activating
    elif [ -e "/run/vpn/$1.up" ]; then
      echo active
    elif [ -e "/run/vpn/$1.failed" ]; then
      echo failed
    else
      echo inactive
    fi
  }
fi

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
