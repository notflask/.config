#!/usr/bin/env bash
# ============================================================
#  wm – ein Befehl für Niri und Hyprland. Erkennt, welcher Compositor
#  läuft, und übersetzt in `niri msg` bzw. `hyprctl`. Skripte, Taskleiste,
#  hypridle, wlogout und theme.sh müssen das so nicht selbst prüfen.
#  Wird von desktop.nix als Befehl `wm` installiert.
# ============================================================

set -euo pipefail

usage() {
  cat <<'HELP'
Benutzung:  wm <befehl> [argumente]

  name                 niri, hyprland – oder Fehler, wenn keiner läuft
  autostart            Hintergrund-Programme der Sitzung starten (Taskleiste …)
  reload               Config neu laden
  screens on|off       alle Bildschirme an/aus (hypridle)
  logout               Sitzung beenden (Hyprland: Apps erst sauber schließen)
  output-size          Größe des aktiven Monitors in logischen Pixeln: "B H"
  find-window APP_ID   ID des ersten Fensters mit dieser App-ID/Klasse
  focused-window       ID des fokussierten Fensters
  focus-window ID      Fenster fokussieren (ID von find-window)
  cursor NAME [GRÖSSE] Cursor-Thema sofort übernehmen
  hotkeys              Liste der Tastenkürzel zeigen
HELP
}

runtime=${XDG_RUNTIME_DIR:-/run/user/$(id -u)}
config=${XDG_CONFIG_HOME:-$HOME/.config}

hypr_socket() { echo "$runtime/hypr/$1/.socket.sock"; }

# Erst die Umgebung, aber nur, wenn der Socket noch lebt – eine tmux-
# Sitzung aus einer früheren Anmeldung (oder dem anderen Compositor) trägt
# sonst veraltete Werte mit. Ohne Treffer (systemd-Dienst ohne Umgebung)
# den neuesten lebenden Socket nehmen und exportieren, damit `niri msg`
# und `hyprctl` ihn finden.
detect() {
  if [ -n "${NIRI_SOCKET:-}" ] && [ -S "$NIRI_SOCKET" ]; then
    echo niri
    return
  fi
  if [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ] &&
    [ -S "$(hypr_socket "$HYPRLAND_INSTANCE_SIGNATURE")" ]; then
    echo hyprland
    return
  fi

  local s newest="" kind=""
  for s in "$runtime"/niri.*.sock "$runtime"/hypr/*/.socket.sock; do
    [ -S "$s" ] || continue
    if [ -z "$newest" ] || [ "$s" -nt "$newest" ]; then
      newest=$s
    fi
  done
  case $newest in
    "$runtime"/niri.*) kind=niri ;;
    "$runtime"/hypr/*) kind=hyprland ;;
  esac
  if [ "$kind" = niri ] && NIRI_SOCKET=$newest niri msg version >/dev/null 2>&1; then
    export NIRI_SOCKET=$newest
    echo niri
  elif [ "$kind" = hyprland ]; then
    local sig=${newest%/.socket.sock}
    sig=${sig##*/}
    if HYPRLAND_INSTANCE_SIGNATURE=$sig hyprctl version >/dev/null 2>&1; then
      export HYPRLAND_INSTANCE_SIGNATURE=$sig
      echo hyprland
    fi
  fi
}

# Lua-Dispatcher (Hyprland 0.56): hypr_dispatch 'hl.dsp.exit()'
hypr_dispatch() { hyprctl dispatch "$1" >/dev/null; }

# Programm im Hintergrund starten; Ausgaben bleiben beim Compositor
# (Niri: Journal, Hyprland: verworfen)
spawn() { "$@" </dev/null & }

autostart() {
  # Gleich unter Niri und Hyprland
  spawn playerctld daemon # merkt sich den zuletzt aktiven Player
  spawn easyeffects --service-mode --hide-window
  spawn wl-paste --type text --watch cliphist store
  spawn wl-paste --type image --watch cliphist store
  # Zwischenablage behalten, wenn die App schließt, aus der kopiert wurde
  spawn wl-clip-persist --clipboard regular
  # Hintergrund: waypaper erst, wenn awww-daemon antwortet (sonst geht
  # die Wiederherstellung beim Login manchmal ins Leere)
  spawn awww-daemon
  (
    for _ in $(seq 50); do
      awww query >/dev/null 2>&1 && break
      sleep 0.1
    done
    exec waypaper --restore
  ) </dev/null &

  # Taskleiste (Quickshell, ~/.config/quickshell/taskbar)
  spawn quickshell -p "$config/quickshell/taskbar"

  case $1 in
    hyprland)
      # Alt+Tab mit Fenster-Vorschau (Niri hat das eingebaut);
      # HYPRSHELL_EXPERIMENTAL=1 schaltet die Vorschau statt App-Icons ein
      spawn env HYPRSHELL_EXPERIMENTAL=1 hyprshell run -c "$config/hyprshell/config.toml"
      ;;
  esac
}

cmd=${1:-}
[ $# -gt 0 ] && shift
case $cmd in
  "" | -h | --help | help)
    usage
    exit 0
    ;;
esac

wm=$(detect)
if [ -z "$wm" ]; then
  # Abmelden geht auch ohne Compositor
  if [ "$cmd" = logout ]; then
    exec loginctl terminate-session "${XDG_SESSION_ID:-}"
  fi
  echo "wm: weder Niri noch Hyprland gefunden" >&2
  exit 1
fi

case "$wm:$cmd" in
  *:name) echo "$wm" ;;
  *:autostart) autostart "$wm" ;;

  niri:reload) niri msg action load-config-file >/dev/null ;;
  hyprland:reload) hyprctl reload >/dev/null ;;

  *:screens)
    state=${1:?on oder off}
    case $state in on | off) ;; *)
      echo "wm screens: on oder off, nicht: $state" >&2
      exit 2
      ;;
    esac
    if [ "$wm" = niri ]; then
      niri msg action "power-$state-monitors"
    else
      action=disable
      [ "$state" = on ] && action=enable
      hypr_dispatch "hl.dsp.dpms({ action = \"$action\" })"
    fi
    ;;

  niri:logout) exec niri msg action quit --skip-confirmation ;;
  hyprland:logout)
    # hyprshutdown schließt erst alle Fenster sauber (ungesicherte Daten)
    if command -v hyprshutdown >/dev/null; then
      exec hyprshutdown
    fi
    exec hyprctl dispatch 'hl.dsp.exit()'
    ;;

  niri:output-size)
    niri msg --json focused-output | jq -r '.logical | "\(.width) \(.height)"'
    ;;
  hyprland:output-size)
    hyprctl -j monitors |
      jq -r '.[] | select(.focused) | "\(.width / .scale | floor) \(.height / .scale | floor)"'
    ;;

  niri:find-window)
    niri msg --json windows |
      jq -r --arg app "${1:?App-ID fehlt}" 'first(.[] | select(.app_id == $app)) | .id // empty'
    ;;
  hyprland:find-window)
    hyprctl clients -j |
      jq -r --arg app "${1:?Klasse fehlt}" 'first(.[] | select(.class == $app)) | .address // empty'
    ;;

  niri:focused-window) niri msg --json focused-window | jq -r '.id // empty' ;;
  hyprland:focused-window) hyprctl activewindow -j | jq -r '.address // empty' ;;

  niri:focus-window) niri msg action focus-window --id "${1:?ID fehlt}" ;;
  hyprland:focus-window) hypr_dispatch "hl.dsp.focus({ window = \"address:${1:?Adresse fehlt}\" })" ;;

  # Niri liest den Cursor aus niri/config.kdl und lädt die Datei bei
  # Änderungen selbst neu
  niri:cursor) : "${1:?Name fehlt}" ;;
  hyprland:cursor) hyprctl setcursor "${1:?Name fehlt}" "${2:-24}" >/dev/null ;;

  niri:hotkeys) niri msg action show-hotkey-overlay ;;
  hyprland:hotkeys) exec hypr-keybinds ;;

  *)
    echo "wm: unbekannter Befehl: $cmd" >&2
    usage >&2
    exit 2
    ;;
esac
