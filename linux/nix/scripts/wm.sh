#!/usr/bin/env bash
# ============================================================
#  wm – ein Befehl für Niri, Hyprland und MangoWC. Erkennt, welcher
#  Compositor läuft, und übersetzt in `niri msg`, `hyprctl` bzw. `mmsg`.
#  Skripte, Taskleiste, hypridle/swayidle und theme.sh müssen das so nicht
#  selbst prüfen.
#  NixOS: desktop.nix installiert es als Befehl `wm`.
#  Void Linux (MangoWC): linux/void/setup.sh verlinkt es nach /usr/local/bin.
# ============================================================

set -euo pipefail

usage() {
  cat <<'HELP'
Benutzung:  wm <befehl> [argumente]

  name                 niri, hyprland, mango – oder Fehler, wenn keiner läuft
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
  if [ -n "${MANGO_INSTANCE_SIGNATURE:-}" ] && [ -S "$MANGO_INSTANCE_SIGNATURE" ]; then
    echo mango
    return
  fi

  local s newest="" kind=""
  for s in "$runtime"/niri.*.sock "$runtime"/hypr/*/.socket.sock "$runtime"/mango-*.sock; do
    [ -S "$s" ] || continue
    if [ -z "$newest" ] || [ "$s" -nt "$newest" ]; then
      newest=$s
    fi
  done
  case $newest in
    "$runtime"/niri.*) kind=niri ;;
    "$runtime"/hypr/*) kind=hyprland ;;
    "$runtime"/mango-*) kind=mango ;;
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
  elif [ "$kind" = mango ] && MANGO_INSTANCE_SIGNATURE=$newest mmsg get version >/dev/null 2>&1; then
    export MANGO_INSTANCE_SIGNATURE=$newest
    echo mango
  fi
}

# MangoWC: Befehl an den Compositor, z. B. mango_dispatch reload_config
mango_dispatch() { mmsg dispatch "$@" >/dev/null; }

# Sperrbildschirm, nie zwei auf einmal. hyprlock gibt es unter Void nicht,
# dort gtklock (Aussehen: ~/.config/gtklock, Farben von matugen)
lock() {
  if command -v hyprlock >/dev/null; then
    pidof hyprlock >/dev/null || exec hyprlock
  else
    # Hintergrund: verkleinerte Kopie des Wallpapers (theme.sh), Aussehen
    # aus ~/.config/gtklock/style.css (matugen)
    local wall=${XDG_CACHE_HOME:-$HOME/.cache}/hyprlock/wallpaper.jpg
    local args=(-d)
    [ -f "$wall" ] && args+=(-b "$wall")
    pidof gtklock >/dev/null || exec gtklock "${args[@]}"
  fi
  exit 0
}

# Lua-Dispatcher (Hyprland 0.56): hypr_dispatch 'hl.dsp.exit()'
hypr_dispatch() { hyprctl dispatch "$1" >/dev/null; }

# Programm im Hintergrund starten; Ausgaben bleiben beim Compositor
# (Niri: Journal, Hyprland: verworfen)
spawn() { "$@" </dev/null & }

# Ohne systemd (Void Linux): was unter NixOS systemd-Benutzerdienste
# starten (desktop.nix, theme.nix, apps.nix, gaming.nix)
autostart_without_systemd() {
  local state=${XDG_STATE_HOME:-$HOME/.local/state}
  # Audio: PipeWire lädt WirePlumber und den Pulse-Server selbst
  # (/etc/pipewire/pipewire.conf.d, linux/void/setup.sh)
  pgrep -u "$(id -u)" -x pipewire >/dev/null || spawn pipewire
  # Passwortabfragen (Polkit). Sein Autostart-Eintrag gilt nur für KDE
  spawn /usr/libexec/polkit-kde-authentication-agent-1
  # XDG-Autostart: KWallet entsperren, Blueman, GPU Screen Recorder,
  # Gigabyte Control Center, „Beim Login starten“ von Discord/Telegram
  spawn dex --autostart --environment mango
  # Auto-Sperre (~/.config/swayidle/config, wie hypridle.conf)
  spawn swayidle -w
  # Webcam-Einstellungen wiederherstellen (cameractrls)
  command -v cameractrlsd >/dev/null && spawn cameractrlsd
  # Flatpak-NVIDIA-Erweiterung passend zum Treiber (Sober)
  command -v flatpak-nvidia-sync >/dev/null && spawn flatpak-nvidia-sync
  # Farben beim ersten Login einmal aus dem Hintergrundbild erzeugen
  [ -e "$state/matugen-theme-v2.done" ] || spawn "$config/matugen/theme.sh"
}

autostart() {
  [ -d /run/systemd/system ] || autostart_without_systemd

  # Gleich unter Niri, Hyprland und MangoWC (Alt+Tab steckt unter Hyprland in der Taskleiste)
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

  if [ "$wm" = mango ]; then
    # Void/MangoWC: minimaler Stil – schmale Textleiste oben und mako flach
    # (vor der ersten Nachricht starten, sonst holt D-Bus mako mit dem
    # Glas-Stil aus ~/.config/mako/config)
    spawn mako --config "$config/mako/config-flat"
    spawn quickshell -p "$config/quickshell/minibar"
  else
    # Taskleiste (Quickshell, ~/.config/quickshell/taskbar)
    spawn quickshell -p "$config/quickshell/taskbar"
  fi
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
  echo "wm: weder Niri, Hyprland noch MangoWC gefunden" >&2
  exit 1
fi

case "$wm:$cmd" in
  *:name) echo "$wm" ;;
  *:autostart) autostart ;;
  *:lock) lock ;;

  niri:reload) niri msg action load-config-file >/dev/null ;;
  hyprland:reload) hyprctl reload >/dev/null ;;
  mango:reload) mango_dispatch reload_config ;;

  *:screens)
    state=${1:?on oder off}
    case $state in on | off) ;; *)
      echo "wm screens: on oder off, nicht: $state" >&2
      exit 2
      ;;
    esac
    if [ "$wm" = niri ]; then
      niri msg action "power-$state-monitors"
    elif [ "$wm" = mango ]; then
      action=sleep_monitor
      [ "$state" = on ] && action=wakeup_monitor
      for mon in $(mmsg get all-monitors | jq -r '.monitors[].name'); do
        mango_dispatch "$action,$mon"
      done
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
  mango:logout) exec mmsg dispatch quit ;;


  niri:find-window)
    niri msg --json windows |
      jq -r --arg app "${1:?App-ID fehlt}" 'first(.[] | select(.app_id == $app)) | .id // empty'
    ;;
  hyprland:find-window)
    hyprctl clients -j |
      jq -r --arg app "${1:?Klasse fehlt}" 'first(.[] | select(.class == $app)) | .address // empty'
    ;;
  mango:find-window)
    mmsg get all-clients |
      jq -r --arg app "${1:?App-ID fehlt}" 'first(.clients[] | select(.appid == $app)) | .id // empty'
    ;;

  niri:focused-window) niri msg --json focused-window | jq -r '.id // empty' ;;
  hyprland:focused-window) hyprctl activewindow -j | jq -r '.address // empty' ;;
  mango:focused-window) mmsg get focusing-client | jq -r '.id // empty' ;;

  niri:focus-window) niri msg action focus-window --id "${1:?ID fehlt}" ;;
  hyprland:focus-window) hypr_dispatch "hl.dsp.focus({ window = \"address:${1:?Adresse fehlt}\" })" ;;
  mango:focus-window) mango_dispatch focusid "client,${1:?ID fehlt}" ;;

  # Niri liest den Cursor aus niri/config.kdl und lädt die Datei bei
  # Änderungen selbst neu
  niri:cursor) : "${1:?Name fehlt}" ;;
  hyprland:cursor) hyprctl setcursor "${1:?Name fehlt}" "${2:-24}" >/dev/null ;;
  # MangoWC liest den Cursor aus mango/config.conf (cursor_theme)
  mango:cursor) : "${1:?Name fehlt}" ;;

  niri:hotkeys) niri msg action show-hotkey-overlay ;;
  hyprland:hotkeys) exec hypr-keybinds ;;
  # Alle bind=-Zeilen aus mango/config.conf, lesbar gemacht
  mango:hotkeys)
    grep -hE '^bind[a-z]*=' "$config/mango/config.conf" |
      sed -E 's/^bind[a-z]*=//' |
      awk -F, '{
        mods = ($1 == "NONE" || $1 == "none") ? "" : $1 " + "
        gsub(/SUPER/, "Super", mods); gsub(/CTRL/, "Strg", mods)
        gsub(/ALT/, "Alt", mods); gsub(/SHIFT/, "Shift", mods); gsub(/\+/, " + ", mods)
        gsub(/  +/, " ", mods)
        action = $3; for (i = 4; i <= NF; i++) action = action " " $i
        printf "%s%s\t%s\n", mods, $2, action
      }' |
      column -t -s "$(printf '\t')" |
      rofi -dmenu -i -no-custom -p "Tastenkürzel" -theme "$config/rofi/flat.rasi" >/dev/null || true
    ;;

  *)
    echo "wm: unbekannter Befehl: $cmd" >&2
    usage >&2
    exit 2
    ;;
esac
