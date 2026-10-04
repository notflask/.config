#!/usr/bin/env bash
# ============================================================
#  theme.sh – Farben aus dem Hintergrundbild erzeugen (matugen)
#  und Niri, Hyprland, Waybar, Rofi, Mako, GTK- und Qt-Apps,
#  Firefox (Pywalfox), Spotify und Discord anpassen.
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
# Ghostty sofort. Schrift, Cursor (macOS) usw. bleiben bei den Vorgaben aus
# theme.nix (alte Einträge, die KDE geschrieben hat, fliegen raus).
if [ "$mode" = light ]; then
  scheme=prefer-light gtk_theme=adw-gtk3 icon_theme=Papirus-Light
else
  scheme=prefer-dark gtk_theme=adw-gtk3-dark icon_theme=Papirus-Dark
fi
dconf write /org/gnome/desktop/interface/color-scheme "'$scheme'" >/dev/null 2>&1 || true
dconf write /org/gnome/desktop/interface/gtk-theme "'$gtk_theme'" >/dev/null 2>&1 || true
dconf write /org/gnome/desktop/interface/icon-theme "'$icon_theme'" >/dev/null 2>&1 || true
for key in cursor-size cursor-theme font-name; do
  dconf reset "/org/gnome/desktop/interface/$key" >/dev/null 2>&1 || true
done
# Dasselbe für Apps, die dconf nicht lesen (Electron-Apps wie Claude oder
# Discord in „System“, Apps in FHS-Umgebungen): GTK-Einstellungsdateien
# des Benutzers, sie gehen vor /etc/xdg (theme.nix, dort fest dunkel)
[ "$mode" = dark ] && prefer_dark=true || prefer_dark=false
for gtk in gtk-3.0 gtk-4.0; do
  mkdir -p "$config/$gtk"
  cat >"$config/$gtk/settings.ini" <<INI
# Erzeugt von theme.sh ($mode) – hier nichts ändern
[Settings]
gtk-theme-name=$gtk_theme
gtk-icon-theme-name=$icon_theme
gtk-cursor-theme-name=macOS
gtk-cursor-theme-size=24
gtk-font-name=Noto Sans 10
gtk-application-prefer-dark-theme=$prefer_dark
INI
done

# Sober (Flatpak) sieht ~/.config nicht: MangoHud-Farben dorthin kopieren
sober_mango="$HOME/.var/app/org.vinegarhq.Sober/config/MangoHud"
[ -d "$sober_mango" ] && cp -f "$config/MangoHud/MangoHud.conf" "$sober_mango/" 2>/dev/null || true

# Neu laden, was die Farben nicht selbst neu einliest
# (Rofi und Hyprlock lesen sie beim nächsten Start)
# (Niri oder Hyprland, `wm` aus desktop.nix)
wm reload >/dev/null 2>&1 || true
# Unter NixOS heißt der Prozess ".waybar-wrapped", daher beide Namen
pkill -SIGUSR2 -x 'waybar|\.waybar-wrapped' || true
makoctl reload >/dev/null 2>&1 || true
# Ghostty (1.3+): Konfiguration samt Theme-Datei neu einlesen
pkill -SIGUSR2 -x 'ghostty|\.ghostty-wrappe' || true
# Discord (Vencord): Theme in die Liste der aktiven eintragen, falls es fehlt
# (Vencord lädt die Datei danach bei jeder Änderung selbst neu; läuft Discord
# gerade, übernimmt es die Liste erst beim nächsten Start)
vc_settings="$config/Vencord/settings/settings.json"
if [ -f "$vc_settings" ] && command -v jq >/dev/null &&
  ! jq -e '.enabledThemes // [] | index("matugen.theme.css")' "$vc_settings" >/dev/null 2>&1; then
  tmp=$(mktemp) &&
    jq '.enabledThemes = ((.enabledThemes // []) + ["matugen.theme.css"])' "$vc_settings" >"$tmp" &&
    mv "$tmp" "$vc_settings" || rm -f "$tmp"
fi
# Firefox (Pywalfox) übernimmt Farben und Hell/Dunkel sofort, wenn es läuft
pywalfox update >/dev/null 2>&1 || true
pywalfox "$mode" >/dev/null 2>&1 || true

# Qt-/KDE-Apps lesen ~/.config/kdeglobals sofort neu (Signal wie beim
# Farbschema-Wechsel in Plasma: PaletteChanged)
dbus-send --session --type=signal /KGlobalSettings \
  org.kde.KGlobalSettings.notifyChange int32:0 int32:0 >/dev/null 2>&1 || true

# Für den einmaligen Lauf beim ersten Login (theme.nix)
mkdir -p "$state" && touch "$state/matugen-theme-v2.done"
