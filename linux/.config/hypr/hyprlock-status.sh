#!/usr/bin/env bash
# Anzeige für hyprlock (cmd[...] in hyprlock.conf)
#
#   hyprlock-status.sh media   laufender Titel – Interpret (leer ohne Musik)

case ${1:-} in
  media)
    [ "$(playerctl status 2>/dev/null)" = Playing ] || exit 0
    title=$(playerctl metadata title 2>/dev/null)
    artist=$(playerctl metadata artist 2>/dev/null)
    [ -n "$title" ] || exit 0
    line="󰎆  $title${artist:+  ·  $artist}"
    # Zu lange Titel kürzen
    [ "${#line}" -gt 60 ] && line="${line:0:57}…"
    # Pango-Markup: &, < und > maskieren
    line=${line//&/&amp;}
    line=${line//</&lt;}
    line=${line//>/&gt;}
    echo "$line"
    ;;
esac
