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
  # Eigene Sitzung (setsid): matugen/theme.sh sendet Waybar SIGUSR2, und
  # Waybar beendet beim Neuladen die Kindprozesse seiner Module. Ohne setsid
  # bricht der Wechsel mittendrin ab (Firefox, Ghostty … kämen nie dran).
  # Sperre nur für den Lauf selbst: fd 9 wird dem Skript nicht vererbt, sonst
  # hielten die Nachzügler im Hintergrund sie noch Sekunden fest.
  setsid -f bash -c '
    exec 9>"${XDG_RUNTIME_DIR:-/tmp}/waybar-theme.lock"
    flock -n 9 || exit 0
    exec "${XDG_CONFIG_HOME:-$HOME/.config}/matugen/theme.sh" -T 9>&-
  ' >/dev/null 2>&1
  exit 0
fi

mode=$(cat "$mode_file" 2>/dev/null)
if [ "$mode" = light ]; then
  icon=󰖨 tooltip="Hell · Klick: dunkel"
else
  mode=dark icon=󰖔 tooltip="Dunkel · Klick: hell"
fi
printf '{"text":"<span font_family=%s size=%s rise=%s>%s</span>","class":"%s","tooltip":"%s"}\n' \
  "'Symbols Nerd Font'" "'13pt'" "'-1pt'" "$icon" "$mode" "$tooltip"
