#!/usr/bin/env bash
# ============================================================
#  theme.sh – Farben aus dem Hintergrundbild erzeugen (matugen)
#  und Niri, Waybar, Fuzzel, Rofi, Mako sofort daran anpassen.
#
#    theme.sh                      aktuelles Waypaper-Bild nehmen
#    theme.sh BILD                 Farben aus BILD
#    theme.sh -t vibrant -i 1 BILD andere Variante / Quellfarbe
#    theme.sh -s BILD              mögliche Quellfarben anzeigen
#
#  Waypaper ruft es nach jedem Wechsel auf (post_command).
# ============================================================

set -euo pipefail

# Standardwerte – hier ändern, wenn dir ein anderer Stil besser gefällt
type=tonal-spot # tonal-spot content expressive fidelity fruit-salad monochrome neutral rainbow vibrant
mode=dark       # dark light
index=0         # 0 = dominante Farbe, 1–4 = weitere
contrast=0      # -1 … 1

waypaper_config="${XDG_CONFIG_HOME:-$HOME/.config}/waypaper/config.ini"

usage() {
  sed -n '3,11s/^#  \{0,1\}//p' "$0"
  echo "Optionen: -t TYP  -m dark|light  -i 0-4  -c KONTRAST  -s (Quellfarben zeigen)"
}

# Fehler auch sichtbar machen, wenn Waypaper das Skript startet
fail() {
  echo "theme: $*" >&2
  command -v notify-send >/dev/null && notify-send -a theme "Theme" "$*" || true
  exit 1
}

show_sources=false
while getopts "t:m:i:c:sh" opt; do
  case $opt in
    t) type=${OPTARG#scheme-} ;;
    m) mode=$OPTARG ;;
    i) index=$OPTARG ;;
    c) contrast=$OPTARG ;;
    s) show_sources=true ;;
    h) usage; exit 0 ;;
    *) usage >&2; exit 2 ;;
  esac
done
shift $((OPTIND - 1))

# Ohne Argument: das zuletzt in Waypaper gesetzte Bild
image=${1:-}
if [ -z "$image" ] && [ -f "$waypaper_config" ]; then
  image=$(sed -n 's/^wallpaper *= *//p' "$waypaper_config" | cut -d, -f1)
fi
[ -n "$image" ] || fail "Kein Bild angegeben und keins in Waypaper gesetzt."
image=${image/#\~/$HOME}
[ -f "$image" ] || fail "Bild nicht gefunden: $image"

if $show_sources; then
  exec matugen image "$image" --show-source-colors
fi

matugen image "$image" \
  --type "scheme-$type" \
  --mode "$mode" \
  --contrast "$contrast" \
  --source-color-index "$index" \
  --quiet ||
  fail "matugen ist fehlgeschlagen ($image)."

# Neu laden, was die Farben nicht selbst neu einliest
# (Fuzzel, Rofi und Hyprlock lesen sie beim nächsten Start)
if [ -n "${NIRI_SOCKET:-}" ]; then
  niri msg action load-config-file >/dev/null 2>&1 || true
fi
# Unter NixOS heißt der Prozess ".waybar-wrapped", daher beide Namen
pkill -SIGUSR2 -x 'waybar|\.waybar-wrapped' || true
makoctl reload >/dev/null 2>&1 || true
