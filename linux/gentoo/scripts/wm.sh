#!/usr/bin/env bash
# ============================================================
#  wm – ein Befehl für Niri und Hyprland. Erkennt, welcher
#  Compositor läuft, und übersetzt in `niri msg` bzw. `hyprctl`.
#  Skripte, Taskleiste, hypridle/swayidle und theme.sh müssen das so nicht
#  selbst prüfen.
#  install.sh verlinkt es nach /usr/local/bin.
# ============================================================

set -euo pipefail

usage() {
  cat <<'HELP'
Benutzung:  wm <befehl> [argumente]

  name                 niri, hyprland – oder Fehler, wenn keiner läuft
  autostart            Hintergrund-Programme der Sitzung starten (Taskleiste …)
  reload               Config neu laden
  screens on|off       alle Bildschirme an/aus (hypridle)
  lock                 Bildschirm sperren (hyprlock, sonst gtklock)
  logout               Sitzung beenden (Hyprland: Apps erst sauber schließen)
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

# Sperrbildschirm, nie zwei auf einmal. Vorzugsweise hyprlock, sonst
# gtklock (Aussehen: ~/.config/gtklock, Farben von matugen)
lock() {
  if command -v hyprlock >/dev/null; then
    pidof hyprlock >/dev/null || exec hyprlock
  else
    # Hintergrund: verkleinerte Kopie des Wallpapers (theme.sh), Aussehen
    # aus ~/.config/gtklock/style.css (matugen)
    local wall=${XDG_CACHE_HOME:-$HOME/.cache}/hyprlock/wallpaper.jpg
    local args=(-d) layout=$config/gtklock/layout.ui
    [ -f "$wall" ] && args+=(-b "$wall")
    [ -f "$layout" ] && args+=(-x "$layout")
    pidof gtklock >/dev/null || exec gtklock "${args[@]}"
  fi
  exit 0
}

# Lua-Dispatcher (Hyprland 0.56): hypr_dispatch 'hl.dsp.exit()'
hypr_dispatch() { hyprctl dispatch "$1" >/dev/null; }

# Programm im Hintergrund starten; Ausgaben bleiben beim Compositor
# (Niri: Journal, Hyprland: verworfen)
spawn() { "$@" </dev/null & }

autostart() {
  # Gleich unter Niri und Hyprland (Alt+Tab steckt unter Hyprland in der Taskleiste)
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
    # Hell/Dunkel nach der Sonne: nur den Modus merken und den Timer für den
    # nächsten Wechsel stellen – waypaper färbt gleich danach damit ein
    "$config/matugen/theme-sun.py" --no-apply || true
    # Gesetztes Bild fehlt (frische Installation): Nebel aus dem Repo nehmen
    # (setup.sh legt ihn nach ~/Wallpapers), das erzeugt auch die Farben
    wall=$(sed -n 's/^wallpaper *= *//p' "$config/waypaper/config.ini" 2>/dev/null | cut -d, -f1)
    wall=${wall/#\~/$HOME}
    default=$HOME/Wallpapers/nebel-dunkel.jpg
    if [ ! -e "$wall" ] && [ -e "$default" ]; then
      exec waypaper --wallpaper "$default"
    fi
    exec waypaper --restore
  ) </dev/null &

  # Stil aus ~/.config/g5/style (Befehl `style minimal|islands|frame|glass`,
  # Vorgabe minimal). mako vor der ersten Nachricht starten, sonst holt D-Bus
  # es mit der falschen Config
  case $(cat "$config/g5/style" 2>/dev/null) in
    glass)
      # Liquid Glass: Taskleiste (Quickshell, ~/.config/quickshell/taskbar), mako mit Glas
      spawn mako
      spawn quickshell -p "$config/quickshell/taskbar" ;;
    islands | frame)
      # deckend und rund: Inseln bzw. Rahmen (~/.config/quickshell/islands)
      spawn mako --config "$config/mako/config-soft"
      spawn quickshell -p "$config/quickshell/islands" ;;
    *)
      # minimal: schmale Textleiste oben und mako flach
      spawn mako --config "$config/mako/config-flat"
      spawn quickshell -p "$config/quickshell/minibar" ;;
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
  # Abmelden und Sperren gehen auch ohne Compositor
  if [ "$cmd" = logout ]; then
    exec loginctl terminate-session "${XDG_SESSION_ID:-}"
  fi
  [ "$cmd" = lock ] && lock
  echo "wm: weder Niri noch Hyprland gefunden" >&2
  exit 1
fi

case "$wm:$cmd" in
  *:name) echo "$wm" ;;
  *:autostart) autostart ;;
  *:lock) lock ;;

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
