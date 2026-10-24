#!/usr/bin/env bash
# ============================================================
#  theme.sh (macOS) – Hintergrundbild setzen, Farben daraus
#  erzeugen (matugen) und Ghostty, Neovim, Emacs, fish, btop,
#  Claude Code, Vesktop, Helium und die Fensterrahmen anpassen.
#
#    theme BILD                    Bild als Hintergrund setzen + Farben
#    theme                         Farben aus dem zuletzt gesetzten Bild
#    theme -t vibrant -i 1 BILD    andere Variante / Quellfarbe
#    theme -s BILD                 mögliche Quellfarben anzeigen
#
#  Hell/Dunkel kommt vom System (Erscheinungsbild). dark-notify ruft
#  das Skript bei jedem Wechsel mit „light“ bzw. „dark“ auf
#  (LaunchAgent aus macos/install.sh).
# ============================================================

set -euo pipefail

# Standardwerte – wie unter Linux (linux/.config/matugen/theme.sh)
type=neutral # tonal-spot content expressive fidelity fruit-salad monochrome neutral rainbow vibrant
index=0      # 0 = dominante Farbe, 1–4 = weitere
contrast=0   # -1 … 1

config="$HOME/.config"
state="$HOME/.local/state"
cache="$HOME/.cache"
# Zuletzt gesetztes Bild
wall_file="$state/wallpaper"

usage() {
  sed -n '3,15s/^#  \{0,1\}//p' "$0"
  echo "Optionen: -t TYP  -i 0-4  -c KONTRAST  -s (Quellfarben zeigen)"
}

# Fehler auch sichtbar machen, wenn dark-notify das Skript startet
fail() {
  echo "theme: $*" >&2
  osascript -e "display notification \"$*\" with title \"Theme\"" >/dev/null 2>&1 || true
  exit 1
}

show_sources=false
while getopts "t:i:c:sh" opt; do
  case $opt in
    t) type=${OPTARG#scheme-} ;;
    i) index=$OPTARG ;;
    c) contrast=$OPTARG ;;
    s) show_sources=true ;;
    h) usage; exit 0 ;;
    *) usage >&2; exit 2 ;;
  esac
done
shift $((OPTIND - 1))

# dark-notify übergibt den neuen Modus; sonst das System fragen
case ${1:-} in
  light | dark) mode=$1; shift ;;
  # Nicht AppleInterfaceStyle: bei „Automatisch“ fehlt der Schlüssel auch nachts
  *) if [ "$(osascript -e 'tell application "System Events" to tell appearance preferences to get dark mode' 2>/dev/null)" = true ]
     then mode=dark; else mode=light; fi ;;
esac

image=${1:-}
set_wallpaper=false
if [ -n "$image" ]; then
  set_wallpaper=true
else
  image=$(cat "$wall_file" 2>/dev/null || true)
  # Noch nichts über theme gesetzt: das aktuelle Bild des Systems
  [ -n "$image" ] || image=$(osascript -e \
    'tell application "System Events" to get picture of current desktop' 2>/dev/null || true)
  # Dynamische/Systembilder haben keinen Pfad
  [ "$image" = "missing value" ] && image=
fi
[ -n "$image" ] || fail "Kein Bild angegeben und keins gesetzt."
image=${image/#\~/$HOME}
[ -f "$image" ] || fail "Bild nicht gefunden: $image"
# Absoluter Pfad (Systemeinstellungen und die gespeicherte Datei brauchen ihn)
image=$(cd "$(dirname "$image")" && pwd)/$(basename "$image")

if $show_sources; then
  exec matugen image "$image" --show-source-colors
fi

# Hintergrund auf allen Monitoren setzen. AeroSpace nutzt nur einen
# macOS-Schreibtisch, das reicht also für alle Arbeitsflächen.
if $set_wallpaper; then
  osascript - "$image" >/dev/null <<'OSA' || fail "Hintergrund nicht gesetzt (Bedienungshilfen/Automation für System Events erlauben)."
on run argv
  tell application "System Events" to tell every desktop to set picture to (item 1 of argv)
end run
OSA
  mkdir -p "$state" && printf '%s\n' "$image" >"$wall_file"
fi

# -c: matugen sucht seine Config auf macOS sonst in ~/Library/Application Support
matugen image "$image" -c "$config/matugen/config.toml" \
  --type "scheme-$type" \
  --mode "$mode" \
  --contrast "$contrast" \
  --source-color-index "$index" \
  --quiet ||
  fail "matugen ist fehlgeschlagen ($image)."

# Helium: Chromium nimmt sonst weiter die alten Farben aus dem Cache des Themes
rm -f "$HOME/.local/share/helium-theme/Cached Theme.pak"

# Fensterrahmen: bordersrc erneut ausführen, das laufende borders übernimmt
# die Farben (läuft es nicht, startet AeroSpace es beim nächsten Start)
if [ -f "$config/borders/bordersrc" ]; then
  chmod +x "$config/borders/bordersrc"
  pgrep -xq borders && { "$config/borders/bordersrc" >/dev/null 2>&1 & }
fi

# btop: Theme „matugen“ einstellen; SIGUSR2 lässt laufende btop neu lesen
btop_conf="$config/btop/btop.conf"
[ -f "$btop_conf" ] && sed -i '' 's/^color_theme = .*/color_theme = "matugen"/' "$btop_conf"
pkill -USR2 -x btop || true
# Ghostty (ab 1.2): SIGUSR2 lädt Konfiguration und Themes neu
pkill -USR2 -x ghostty || true
# Neovim und Emacs laden ihr Farbschema selbst neu, sobald matugen schreibt

# Vesktop: Theme in die Liste der aktiven eintragen, falls es fehlt
# (danach lädt Vesktop die Datei bei jeder Änderung selbst neu)
vc_settings="$HOME/Library/Application Support/vesktop/settings/settings.json"
if [ -f "$vc_settings" ] && command -v jq >/dev/null &&
  ! jq -e '.enabledThemes // [] | index("matugen.theme.css")' "$vc_settings" >/dev/null 2>&1; then
  tmp=$(mktemp) &&
    jq '.enabledThemes = ((.enabledThemes // []) + ["matugen.theme.css"])' "$vc_settings" >"$tmp" &&
    mv "$tmp" "$vc_settings" || rm -f "$tmp"
fi

# fish/Tide: Prompt-Farben als Universal-Variablen; offene Shells
# übernehmen sie sofort (fish/conf.d/matugen-tide.fish)
[ -f "$cache/matugen/tide-colors.fish" ] && command -v fish >/dev/null &&
  { fish "$cache/matugen/tide-colors.fish" || true; }
exit 0
