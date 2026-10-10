#!/usr/bin/env bash
# Hell/dunkel umschalten (Sonne/Mond in der Taskleiste, Status.qml):
# ~/.config/matugen/theme.sh -T. Den aktuellen Modus liest die Leiste
# selbst aus ~/.local/state/theme-mode.
#
# Ein zweiter Klick, während noch umgeschaltet wird, zählt nicht. Eigene
# Sitzung (setsid), damit der Wechsel nicht mit der Leiste abbricht (Firefox,
# Ghostty … kämen sonst nie dran). Sperre nur für den Lauf selbst: fd 9 wird
# dem Skript nicht vererbt, sonst hielten Nachzügler sie noch Sekunden fest.
setsid -f bash -c '
  exec 9>"${XDG_RUNTIME_DIR:-/tmp}/theme-toggle.lock"
  flock -n 9 || exit 0
  exec "${XDG_CONFIG_HOME:-$HOME/.config}/matugen/theme.sh" -T 9>&-
' >/dev/null 2>&1
