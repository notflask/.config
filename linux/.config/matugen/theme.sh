#!/usr/bin/env bash
# ============================================================
#  theme.sh – Farben aus dem Hintergrundbild erzeugen (matugen)
#  und Niri, Hyprland, Waybar, Rofi, Mako, GTK- und Qt-Apps,
#  Cursor, Firefox (Pywalfox), Spotify und Discord anpassen.
#
#    theme.sh                      aktuelles Waypaper-Bild nehmen
#    theme.sh BILD                 Farben aus BILD
#    theme.sh -m light             hell (bleibt gespeichert), -m dark dunkel
#    theme.sh -T                   zwischen hell und dunkel umschalten
#    theme.sh -t vibrant -i 1 BILD andere Variante / Quellfarbe
#    theme.sh -s BILD              mögliche Quellfarben anzeigen
#
#  Waypaper ruft es nach jedem Wechsel auf (post_command).
# ============================================================

set -euo pipefail

# Standardwerte – hier ändern, wenn dir ein anderer Stil besser gefällt
type=tonal-spot # tonal-spot content expressive fidelity fruit-salad monochrome neutral rainbow vibrant
index=0         # 0 = dominante Farbe, 1–4 = weitere
contrast=0      # -1 … 1

config="${XDG_CONFIG_HOME:-$HOME/.config}"
state="${XDG_STATE_HOME:-$HOME/.local/state}"
cache="${XDG_CACHE_HOME:-$HOME/.cache}"
waypaper_config="$config/waypaper/config.ini"
# Hell oder dunkel: gilt, bis es mit -m oder -T geändert wird
mode_file="$state/theme-mode"

usage() {
  sed -n '3,13s/^#  \{0,1\}//p' "$0"
  echo "Optionen: -t TYP  -m dark|light  -T  -i 0-4  -c KONTRAST  -s (Quellfarben zeigen)"
}

# Fehler auch sichtbar machen, wenn Waypaper das Skript startet
fail() {
  echo "theme: $*" >&2
  command -v notify-send >/dev/null && notify-send -a theme "Theme" "$*" || true
  exit 1
}

mode=$(cat "$mode_file" 2>/dev/null || true)
[ "$mode" = light ] || mode=dark

show_sources=false
new_mode=
while getopts "t:m:i:c:sTh" opt; do
  case $opt in
    t) type=${OPTARG#scheme-} ;;
    m) new_mode=$OPTARG ;;
    T) if [ "$mode" = dark ]; then new_mode=light; else new_mode=dark; fi ;;
    i) index=$OPTARG ;;
    c) contrast=$OPTARG ;;
    s) show_sources=true ;;
    h) usage; exit 0 ;;
    *) usage >&2; exit 2 ;;
  esac
done
shift $((OPTIND - 1))

if [ -n "$new_mode" ]; then
  case $new_mode in
    dark | light) mode=$new_mode ;;
    *) fail "Modus muss dark oder light sein, nicht: $new_mode" ;;
  esac
  mkdir -p "$state" && echo "$mode" >"$mode_file"
fi

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

# GTK: Hell/Dunkel, Thema und Icons passend zum Modus. Über das
# Einstellungs-Portal folgen auch Firefox, Electron-Apps, libadwaita und
# Ghostty sofort. Schrift, Cursorgröße usw. bleiben bei den Vorgaben aus
# theme.nix (alte Einträge, die KDE geschrieben hat, fliegen raus).
if [ "$mode" = light ]; then
  scheme=prefer-light gtk_theme=adw-gtk3 icon_theme=Papirus-Light
else
  scheme=prefer-dark gtk_theme=adw-gtk3-dark icon_theme=Papirus-Dark
fi
dconf write /org/gnome/desktop/interface/color-scheme "'$scheme'" >/dev/null 2>&1 || true
dconf write /org/gnome/desktop/interface/gtk-theme "'$gtk_theme'" >/dev/null 2>&1 || true
dconf write /org/gnome/desktop/interface/icon-theme "'$icon_theme'" >/dev/null 2>&1 || true
for key in cursor-size font-name; do
  dconf reset "/org/gnome/desktop/interface/$key" >/dev/null 2>&1 || true
done

# Neu laden, was die Farben nicht selbst neu einliest
# (Rofi und Hyprlock lesen sie beim nächsten Start)
if [ -n "${NIRI_SOCKET:-}" ]; then
  niri msg action load-config-file >/dev/null 2>&1 || true
fi
if [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
  hyprctl reload >/dev/null 2>&1 || true
fi
# Unter NixOS heißt der Prozess ".waybar-wrapped", daher beide Namen
pkill -SIGUSR2 -x 'waybar|\.waybar-wrapped' || true
makoctl reload >/dev/null 2>&1 || true
# Firefox (Pywalfox) übernimmt Farben und Hell/Dunkel sofort, wenn es läuft
pywalfox update >/dev/null 2>&1 || true
pywalfox "$mode" >/dev/null 2>&1 || true

# Qt-/KDE-Apps lesen ~/.config/kdeglobals sofort neu (Signal wie beim
# Farbschema-Wechsel in Plasma: PaletteChanged)
dbus-send --session --type=signal /KGlobalSettings \
  org.kde.KGlobalSettings.notifyChange int32:0 int32:0 >/dev/null 2>&1 || true

# Cursor in den neuen Farben (theme-cursor aus theme.nix, dauert ein paar
# Sekunden – deshalb zum Schluss). Jede Farbkombination bekommt einen
# eigenen Namen, sonst laden Niri und GTK den Cursor nicht neu.
if command -v theme-cursor >/dev/null &&
  read -r fill outline <"$cache/matugen/cursor-colors" &&
  cursor=$(theme-cursor "$fill" "$outline"); then
  printf '%s\ncursor {\n    xcursor-theme "%s"\n}\n' \
    "// Erzeugt von theme.sh (Cursor in den Farben des Hintergrundbilds)" \
    "$cursor" >"$config/niri/cursor.kdl"
  if [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
    hyprctl setcursor "$cursor" 24 >/dev/null 2>&1 || true
  fi
  dconf write /org/gnome/desktop/interface/cursor-theme "'$cursor'" >/dev/null 2>&1 || true
fi

# Für den einmaligen Lauf beim ersten Login (theme.nix)
mkdir -p "$state" && touch "$state/matugen-theme-v2.done"
