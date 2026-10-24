#!/usr/bin/env bash
# ============================================================
#  theme.sh – Farben aus dem Hintergrundbild erzeugen (matugen)
#  und Niri, Hyprland, Taskleiste, Rofi, Mako, GTK- und Qt-Apps,
#  Firefox (Pywalfox), Thunderbird, Spotify, Discord und Steam anpassen.
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
type=neutral # tonal-spot content expressive fidelity fruit-salad monochrome neutral rainbow vibrant
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

# Hyprlock bzw. gtklock: verkleinerte Kopie des Bildes (1440p, JPEG). Ein 8K-PNG zu
# dekodieren dauert spürbar, mit der Kopie erscheint die Sperre sofort.
# Im Hintergrund, erst fertig schreiben, dann umbenennen.
lock_wall="$cache/hyprlock/wallpaper.jpg"
mkdir -p "${lock_wall%/*}"
(
  magick "$image[0]" -resize '2560x1440^' -quality 92 "$lock_wall.tmp.jpg" &&
    mv -f "$lock_wall.tmp.jpg" "$lock_wall"
) >/dev/null 2>&1 &

# GTK: Hell/Dunkel, Thema und Icons passend zum Modus. Über das
# Einstellungs-Portal folgen auch Firefox, Electron-Apps, libadwaita und
# Ghostty sofort. Schrift, Cursor (macOS) usw. bleiben bei den Vorgaben aus
# (alte Einträge, die KDE geschrieben hat, fliegen raus).
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
# des Benutzers, sie gehen vor /etc/xdg (dort fest dunkel)
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
# (Niri oder Hyprland, `wm`)
wm reload >/dev/null 2>&1 || true
makoctl reload >/dev/null 2>&1 || true
# btop: Theme „matugen“ einstellen (btop.conf schreibt btop selbst, darum
# nicht in den Dotfiles); SIGUSR2 lässt laufende btop Config und Theme neu lesen
btop_conf="$config/btop/btop.conf"
[ -f "$btop_conf" ] && sed -i 's/^color_theme = .*/color_theme = "matugen"/' "$btop_conf"
pkill -SIGUSR2 -x btop || true
# Ghostty: ab 1.2 lädt SIGUSR2 Konfiguration und Themes neu. Ghostty 1.1
# kennt das Signal nicht – dort BEENDET es alle Terminals. Für 1.1
# stattdessen die neuen Farben per OSC 4/10/11/12 in jedes offene Terminal
# schreiben (wie pywal); neue Fenster lesen themes/matugen ohnehin.
ghostty_version=$(ghostty --version 2>/dev/null | sed -n 's/^Ghostty //p;q')
if [ -n "$ghostty_version" ] &&
  [ "$(printf '%s\n' 1.2.0 "$ghostty_version" | sort -V | head -n1)" = 1.2.0 ]; then
  pkill -SIGUSR2 -x 'ghostty|\.ghostty-wrappe' || true
elif [ -f "$config/ghostty/themes/matugen" ]; then
  osc=$(awk -F' *= *' '
    $1 == "foreground"   { printf "\033]10;%s\033\\", $2 }
    $1 == "background"   { printf "\033]11;%s\033\\", $2 }
    $1 == "cursor-color" { printf "\033]12;%s\033\\", $2 }
    $1 == "palette"      { printf "\033]4;%s;%s\033\\", $2, $3 }
  ' "$config/ghostty/themes/matugen")
  for term_pid in $(pgrep -x 'ghostty|\.ghostty-wrappe'); do
    for shell_pid in $(pgrep -P "$term_pid"); do
      tty=$(readlink "/proc/$shell_pid/fd/0" 2>/dev/null) || continue
      case $tty in /dev/pts/*) [ -w "$tty" ] && printf '%s' "$osc" >"$tty" 2>/dev/null ;; esac
    done
  done
fi
# Neovim lädt das Farbschema selbst neu, sobald matugen colors/matugen.lua
# schreibt (Dateiüberwachung in plugins/ui.lua)
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
# Telegram Desktop: Palette (matugen) + einfarbiger Chat-Hintergrund als
# .tdesktop-theme (ZIP), flach wie Discord. Von außen lässt sich das Theme
# nicht anwenden: `Telegram -- Datei` öffnet inzwischen „Weiterleiten an …“
# statt der Vorschau (bei jedem Wechsel, auch nach der Sonne). Darum nur die
# Datei bauen; anwenden per Hand (Datei in „Gespeicherte Nachrichten“ ziehen
# und dort anklicken).
tg_dir="$cache/matugen/telegram"
if [ -f "$tg_dir/colors.tdesktop-theme" ]; then
  tg_bg=$(sed -n 's/^windowBg: *\(#[0-9a-fA-F]*\);.*/\1/p' "$tg_dir/colors.tdesktop-theme")
  tg_theme="$cache/matugen/matugen.tdesktop-theme"
  rm -f "$tg_dir/background.jpg"
  magick -size 64x64 "xc:${tg_bg:-#000000}" "$tg_dir/tiled.png" 2>/dev/null &&
    python3 -I -c 'import sys, zipfile
with zipfile.ZipFile(sys.argv[1] + ".tmp", "w") as z:
    for f in sys.argv[2:]: z.write(f, f.rsplit("/", 1)[1])' \
      "$tg_theme" "$tg_dir/colors.tdesktop-theme" "$tg_dir/tiled.png" &&
    mv -f "$tg_theme.tmp" "$tg_theme"
fi
# Steam (Millennium): Theme „matugen“ neu bauen; Steam übernimmt die Farben
# beim nächsten Start
[ -d "$HOME/.local/share/Steam" ] &&
  { "$config/matugen/steam-theme.py" || echo "theme: steam-theme.py fehlgeschlagen" >&2; }
# Firefox (Pywalfox) übernimmt Farben und Hell/Dunkel sofort, wenn es läuft
# (Profil liegt unter ~/.config/mozilla, nicht im Standardpfad ~/.mozilla)
ff_profile=$(ls -d "$HOME"/.config/mozilla/firefox/*.default* 2>/dev/null | head -n1)
# userChrome.css für die Adressleisten-Vorschläge ins Profil kopieren
if [ -n "$ff_profile" ] && [ -f "$cache/matugen/firefox-userChrome.css" ]; then
  mkdir -p "$ff_profile/chrome"
  cp -f "$cache/matugen/firefox-userChrome.css" "$ff_profile/chrome/userChrome.css"
fi
# Benachrichtigungen: Ghostty schickt sein Symbol nur als Namen; mako sucht
# zuerst in ~/.cache/matugen/icons (icon-path in mako-flat.ini). Dort liegt
# eine Kopie in zwei Tönen aus matugen (Graustufen → ink … paper).
if [ -f "$cache/matugen/icon-colors.sh" ]; then
  . "$cache/matugen/icon-colors.sh"
  # in allen Größen, die die App mitbringt (mako nimmt die passendste)
  for src in /usr/share/icons/hicolor/*/apps/com.mitchellh.ghostty.png; do
    [ -f "$src" ] || continue
    dst="$cache/matugen/icons/${src#/usr/share/icons/hicolor/}"
    mkdir -p "${dst%/*}"
    # Farbe aus den Graustufen, Transparenz vom Original
    magick "$src" \( -clone 0 -alpha off -colorspace gray +level-colors "$ink,$paper" \) \
      \( -clone 0 -alpha extract \) -delete 0 -compose CopyOpacity -composite \
      "$dst" 2>/dev/null || true
  done
fi

# fish/Tide: Prompt-Farben als Universal-Variablen setzen; offene Shells
# übernehmen sie sofort (fish/conf.d/matugen-tide.fish)
[ -f "$cache/matugen/tide-colors.fish" ] && command -v fish >/dev/null &&
  { fish "$cache/matugen/tide-colors.fish" || true; }

# Thunderbird: userChrome.css in jedes Profil (~/.config/thunderbird, alt
# ~/.thunderbird) kopieren und Benutzer-Stylesheets per user.js erlauben.
# Thunderbird liest die Datei nur beim Start.
tb_css="$cache/matugen/thunderbird-userChrome.css"
tb_pref='user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);'
if [ -f "$tb_css" ]; then
  for tb_profile in "$config"/thunderbird/*/ "$HOME"/.thunderbird/*/; do
    [ -f "$tb_profile/prefs.js" ] || continue
    mkdir -p "$tb_profile/chrome"
    cp -f "$tb_css" "$tb_profile/chrome/userChrome.css"
    [ -f "$cache/matugen/thunderbird-userContent.css" ] &&
      cp -f "$cache/matugen/thunderbird-userContent.css" "$tb_profile/chrome/userContent.css"
    grep -qsF "$tb_pref" "$tb_profile/user.js" || echo "$tb_pref" >>"$tb_profile/user.js"
  done
fi
# Der Socket liegt in $TMPDIR (Standard /tmp); unter Waypaper/Niri kann TMPDIR
# abweichen, dann findet pywalfox den Daemon nicht. Fehler landen im Log.
pwf() {
  TMPDIR=/tmp pywalfox ${ff_profile:+--profile-path "$ff_profile"} "$@" \
    >>"$state/pywalfox.log" 2>&1 || echo "pywalfox $* fehlgeschlagen" >>"$state/pywalfox.log"
}
# Erst den Modus, dann die Farben: sonst überholt ein noch laufendes
# `update` den Moduswechsel und Firefox bleibt im alten Modus.
# Im Hintergrund, damit der Wechsel nicht wartet. Firefox setzt sein Thema beim
# Wechsel des System-Schemas ggf. zurück, daher ein zweiter Durchgang.
# Der Modus wird jedes Mal neu gelesen, damit ein schnelles Zurückschalten nicht
# von einem noch laufenden älteren Durchgang überholt wird.
(
  for wait in 0 4; do
    sleep "$wait"
    pwf "$(cat "$mode_file")"; sleep 1; pwf update
  done
) >/dev/null 2>&1 &

# Qt-/KDE-Apps lesen ~/.config/kdeglobals sofort neu (Signal wie beim
# Farbschema-Wechsel in Plasma: PaletteChanged)
dbus-send --session --type=signal /KGlobalSettings \
  org.kde.KGlobalSettings.notifyChange int32:0 int32:0 >/dev/null 2>&1 || true

# Für den einmaligen Lauf beim ersten Login
mkdir -p "$state" && touch "$state/matugen-theme-v2.done"
