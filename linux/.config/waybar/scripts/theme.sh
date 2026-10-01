#!/usr/bin/env bash
# Waybar-Modul custom/theme: hell/dunkel anzeigen und umschalten.
#   theme.sh          JSON für Waybar ausgeben (Symbol = aktueller Modus)
#   theme.sh toggle   umschalten (~/.config/matugen/theme.sh -T)
#
# Nach dem Umschalten lädt matugen/theme.sh Waybar neu (SIGUSR2),
# dabei wird das Symbol neu gelesen.

mode_file=${XDG_STATE_HOME:-$HOME/.local/state}/theme-mode

if [ "${1:-}" = toggle ]; then
  # Ein zweiter Klick, während noch umgeschaltet wird, zählt nicht
  exec flock -n "${XDG_RUNTIME_DIR:-/tmp}/waybar-theme.lock" \
    "${XDG_CONFIG_HOME:-$HOME/.config}/matugen/theme.sh" -T
fi

mode=$(cat "$mode_file" 2>/dev/null)
if [ "$mode" = light ]; then
  icon=󰖨 tooltip="Hell · Klick: dunkel"
else
  mode=dark icon=󰖔 tooltip="Dunkel · Klick: hell"
fi
printf '{"text":"<span font_family=%s size=%s rise=%s>%s</span>","class":"%s","tooltip":"%s"}\n' \
  "'Symbols Nerd Font'" "'13pt'" "'-1pt'" "$icon" "$mode" "$tooltip"
