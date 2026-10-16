#!/usr/bin/env bash
# ============================================================
#  gaming-mode – startet ein Spiel mit allem, was es schnell und stabil
#  macht: RTX 4060, GameMode (im Spielprozess, MangoHud zeigt es an),
#  MangoHud, großer Shader-Cache, NVAPI/DLSS, NTSYNC – und auf Wunsch
#  gestreckt (gamescope) mit Zeiger, der im Spiel bleibt.
#
#  Standardwerte: config/g5.json → gaming (g5 config set gaming.stretch 1920x1440)
#  install.sh verlinkt es als Befehl `gaming-mode`.
# ============================================================
set -euo pipefail

usage() {
  cat <<'HELP'
Benutzung:  gaming-mode [Optionen] <befehl> [argumente]

  Steam-Startoption:  gaming-mode %command%
                      gaming-mode --stretch 1920x1440 %command%
  Außerhalb Steam:    gaming-mode ./spiel

Optionen (vor dem Befehl; Standard aus config/g5.json → gaming):
  --stretch WxH       in WxH rendern, per gamescope auf den Monitor strecken
  --native            nicht strecken, auch wenn g5.json es vorgibt (ohne gamescope)
  --monitor NAME      Monitor fürs Spiel (Standard: gaming.monitor, z. B. DP-2)
  --refresh HZ        Bildrate gestreckt (Standard: Monitor − 3 Hz, passt zu VRR)
  --cursor MODUS      grab     gamescope sperrt die Maus (Kamera), Hyprland hält den
                               Zeiger zusätzlich im Fenster (Menüs) – Standard
                      confine  Hyprland hält den Zeiger im Fenster – in Shootern
                               bleibt die Kamera am Fensterrand hängen
                      free     keine Einschränkung
  --grab-cursor       = --cursor grab
  --grab-keys         alle Tasten ans Spiel, auch Super (in gamescope: Super+G)
  --wayland           Proton-Wayland-Treiber (PROTON_ENABLE_WAYLAND=1): Spiel direkt
                      unter Hyprland, Maus über Wayland; gestreckt wird mit der
                      Vollbild-Auflösung im Spiel (z. B. 1920x1440) – ohne gamescope
  --sdl               gamescope mit SDL- statt Wayland-Backend
  --filter F          Skalierfilter: linear (Standard), nearest, fsr, nis
  --no-hud | --hud    MangoHud aus/an (im Spiel: Shift rechts + F12)
  --dry-run           nur zeigen, was gestartet würde
  -h, --help          diese Hilfe

Protokoll des letzten Starts: ~/.local/state/g5/gaming-mode.log
HELP
}

die() { echo "gaming-mode: $1" >&2; exit 1; }

# ── Standardwerte aus der Konfiguration (eine jq-Abfrage) ───────────
cfg=${XDG_CACHE_HOME:-$HOME/.cache}/g5/config.json
[ -r "$cfg" ] || cfg=/etc/g5/g5.json
monitor=DP-2 stretch="" refresh=0 hud=true cursor=grab grab_keys=false
if [ -r "$cfg" ] && command -v jq >/dev/null; then
  eval "$(jq -r '.gaming // {} | @sh "monitor=\(.monitor // "DP-2") stretch=\(.stretch // "") refresh=\(.refresh // 0) hud=\(.hud // true) cursor=\(.cursor // "grab") grab_keys=\(.grab_keys // false)"' "$cfg")"
fi
sdl=0 filter=linear dry=0 wayland=0

while [ $# -gt 0 ]; do
  case $1 in
    --stretch) [ $# -ge 2 ] || die "--stretch braucht WxH"; stretch=$2; shift 2 ;;
    --native) stretch=""; shift ;;
    --monitor) [ $# -ge 2 ] || die "--monitor braucht einen Namen"; monitor=$2; shift 2 ;;
    --refresh) [[ ${2:-} =~ ^[0-9]+$ ]] || die "--refresh braucht eine Zahl"; refresh=$2; shift 2 ;;
    --cursor) case ${2:-} in confine | grab | free) cursor=$2 ;; *) die "--cursor confine|grab|free" ;; esac; shift 2 ;;
    --grab-cursor) cursor=grab; shift ;;
    --grab-keys) grab_keys=true; shift ;;
    --sdl) sdl=1; shift ;;
    --wayland) wayland=1; stretch=""; shift ;;
    --filter) case ${2:-} in linear | nearest | fsr | nis) filter=$2 ;; *) die "--filter linear|nearest|fsr|nis" ;; esac; shift 2 ;;
    --no-hud) hud=false; shift ;;
    --hud) hud=true; shift ;;
    --dry-run) dry=1; shift ;;
    --output) shift 2 ;; # alte Option: Monitorgröße kommt jetzt von Hyprland
    -h | --help) usage; exit 0 ;;
    --) shift; break ;;
    -*) die "unbekannte Option $1 (gaming-mode --help)" ;;
    *) break ;;
  esac
done
[ $# -gt 0 ] || { usage >&2; exit 1; }
[ -z "$stretch" ] || [[ $stretch =~ ^[0-9]+x[0-9]+$ ]] || die "Ungültige Auflösung '$stretch' (Format: 1920x1440)"

log_dir=${XDG_STATE_HOME:-$HOME/.local/state}/g5
mkdir -p "$log_dir"
log=$log_dir/gaming-mode.log

# ── Umgebung fürs Spiel ──────────────────────────────────────────────
# RTX 4060 erzwingen (wie nvidia-offload)
export __NV_PRIME_RENDER_OFFLOAD=1
export __NV_PRIME_RENDER_OFFLOAD_PROVIDER=NVIDIA-G0
export __GLX_VENDOR_LIBRARY_NAME=nvidia
export __VK_LAYER_NV_optimus=NVIDIA_only
# Shader-Cache 10 GB, nie aufräumen → weniger Ruckler durch Kompilieren
export __GL_SHADER_DISK_CACHE=1
export __GL_SHADER_DISK_CACHE_SIZE=10737418240
export __GL_SHADER_DISK_CACHE_SKIP_CLEANUP=1
# Proton: DLSS/Reflex (NVAPI) und NTSYNC (gleichmäßigere Frametimes)
export PROTON_ENABLE_NVAPI=1
export PROTON_USE_NTSYNC=1
# Wine-Wayland: das Spiel ist ein echtes Wayland-Fenster (Zeigersperre über
# Hyprland), Auflösungswechsel im Spiel skaliert Wine auf den ganzen Monitor
[ "$wayland" = 1 ] && export PROTON_ENABLE_WAYLAND=1
# MangoHud-Layout, falls keine eigene Config existiert
if [ -z "${MANGOHUD_CONFIG:-}" ] && [ ! -e "${XDG_CONFIG_HOME:-$HOME/.config}/MangoHud/MangoHud.conf" ]; then
  export MANGOHUD_CONFIG="position=top-left,background_alpha=0.4,fps,frametime,frame_timing,gpu_stats,gpu_temp,cpu_stats,cpu_temp,ram,vram,gamemode"
fi
# Steam startet mit niedriger Platten-Priorität (bin/steam) – das Spiel normal
ionice -c 2 -n 4 -p $$ 2>/dev/null || true

# ── Hyprland: Monitor ────────────────────────────────────────────────
hypr=0
if [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ] && command -v hyprctl >/dev/null; then
  hypr=1
fi
out_w=2560 out_h=1440 out_hz=180
if [ "$hypr" = 1 ]; then
  read -r out_w out_h out_hz < <(hyprctl monitors -j | jq -r --arg m "$monitor" \
    'first(.[] | select(.name == $m)) // first(.[] | select(.focused)) | "\(.width) \(.height) \(.refreshRate | round)"') || true
fi
[ "$refresh" -gt 0 ] || refresh=$((out_hz > 63 ? out_hz - 3 : out_hz))

# ── Befehl zusammenbauen ─────────────────────────────────────────────
# GameMode und MangoHud gehören IN den Spielprozess (innerhalb von
# gamescope): nur dann registriert GameMode das Spiel selbst und MangoHud
# zeigt „GAMEMODE“ an. Vorher stand gamemoderun vor gamescope – registriert
# war nur gamescope.
inner=(gamemoderun)
[ "$hud" = true ] && inner+=(mangohud)

cmd=()
if [ -n "$stretch" ]; then
  command -v gamescope >/dev/null || die "gamescope fehlt (emerge gui-wm/gamescope)"
  cmd=(gamescope --backend "$([ $sdl = 1 ] && echo sdl || echo wayland)")
  cmd+=(-w "${stretch%x*}" -h "${stretch#*x}" -W "$out_w" -H "$out_h" -r "$refresh")
  cmd+=(-S stretch -F "$filter" -f)
  # gamescope auf der RTX 4060 zusammensetzen (dort hängt auch der LG) –
  # sonst kopiert es jedes Bild zwischen den GPUs hin und her
  dev=/sys/bus/pci/devices/0000:01:00.0
  if [ -r "$dev/vendor" ]; then
    cmd+=(--prefer-vk-device "$(sed 's/^0x//' "$dev/vendor"):$(sed 's/^0x//' "$dev/device")")
  fi
  [ "$cursor" = grab ] && cmd+=(--force-grab-cursor)
  [ "$grab_keys" = true ] && cmd+=(--grab)
  cmd+=(--)
fi
cmd+=("${inner[@]}" "$@")

if [ "$dry" = 1 ]; then
  printf '%q ' "${cmd[@]}"; echo
  exit 0
fi

{
  echo "== $(date '+%F %T')  monitor=$monitor ${out_w}x${out_h}@${out_hz} stretch=${stretch:-nein} wayland=$wayland refresh=$refresh cursor=$cursor hud=$hud"
  printf '%q ' "${cmd[@]}"; echo
} >"$log"

# Spiel auf dem gewünschten Monitor öffnen: Fokus + Zeiger dorthin
if [ "$hypr" = 1 ]; then
  hyprctl dispatch "hl.dsp.focus({ monitor = \"$monitor\" })" >/dev/null 2>&1 || true
fi

# Gestreckt: sobald das gamescope-Fenster da ist (gleiche PID wie dieses
# Skript, exec unten):
#  1. Fenster fokussieren und den Zeiger in seine Mitte setzen. Eine
#     Zeigersperre (Kamera) greift unter Wayland erst, wenn der Zeiger über
#     dem Fenster ist – mit cursor.no_warps und Fokus per Klick passierte das
#     nie von selbst: Kamera tot, Menüs taub, bis ein Moduswechsel Hyprland
#     den Zeiger neu zuordnen ließ.
#  2. bei --cursor confine Tag g5-confine (Regel in hypr/hyprland.lua):
#     der Zeiger bleibt im Spiel, auch wenn es ihn in Menüs zeigt.
if [ "$hypr" = 1 ] && [ -n "$stretch" ]; then
  pid=$$
  (
    # bis zu 60 s: erst wenn das Fenster wirklich den Fokus hat UND der Zeiger
    # darin liegt, ist es geschafft (gamescope baut das Vollbild-Fenster in
    # den ersten Sekunden noch um – ein einzelner Versuch ging ins Leere)
    tagged=0
    for _ in $(seq 120); do
      sleep 0.5
      kill -0 "$pid" 2>/dev/null || exit 0
      win=$(hyprctl clients -j | jq -r --argjson p "$pid" \
        'first(.[] | select(.pid == $p and .mapped)) | "\(.address) \(.at[0]) \(.at[1]) \(.size[0]) \(.size[1])"')
      [ -n "$win" ] || continue
      read -r addr x y w h <<<"$win"
      # Tag auch bei grab: Unreal-Spiele (ARC Raiders) geben in Menüs die
      # Sperre frei – dann hält Hyprland den Zeiger trotzdem im Spiel
      if [ "$cursor" != free ] && [ $tagged = 0 ]; then
        hyprctl dispatch "hl.dsp.window.tag({ tag = \"+g5-confine\", window = \"address:$addr\" })" >>"$log" 2>&1 && tagged=1
      fi
      active=$(hyprctl activewindow -j | jq -r '.pid // 0')
      read -r cx cy < <(hyprctl cursorpos | tr -d ',')
      # mindestens einmal selbst versetzen (s. u.), auch wenn der Zeiger schon
      # zufällig über dem Fenster liegt – sonst meldet Hyprland gamescope nie,
      # dass der Zeiger da ist
      if [ "${moved:-0}" -ge 1 ] && [ "$active" = "$pid" ] && [ "$cx" -ge "$x" ] && [ "$cx" -lt $((x + w)) ] && [ "$cy" -ge "$y" ] && [ "$cy" -lt $((y + h)) ]; then
        echo "gaming-mode: Fokus und Zeiger im Spiel" >>"$log"
        break
      fi
      # no_warps kurz aus, damit Hyprland den Zeiger tatsächlich versetzt
      hyprctl eval 'hl.config({ cursor = { no_warps = false } })' >/dev/null 2>&1
      hyprctl dispatch "hl.dsp.focus({ window = \"address:$addr\" })" >>"$log" 2>&1
      hyprctl dispatch "hl.dsp.cursor.move({ x = $((x + w / 2 + 1)), y = $((y + h / 2)) })" >/dev/null 2>&1
      hyprctl dispatch "hl.dsp.cursor.move({ x = $((x + w / 2)), y = $((y + h / 2)) })" >>"$log" 2>&1
      hyprctl eval 'hl.config({ cursor = { no_warps = true } })' >/dev/null 2>&1
      moved=$((${moved:-0} + 1))
      sleep 1 # gamescope Zeit geben, die Sperre zu setzen
    done

    # Das eigentliche Spiel startet in gamescope erst 10–30 s später
    # (Steam, Proton, Ladebildschirm). gamescope setzt die Maussperre für das
    # Fenster, das gerade den Fokus hat, und erst, wenn es danach selbst den
    # Tastaturfokus neu bekommt – genau das tat Alt+Tab von Hand.
    # Deshalb: gamescopes eigenen X-Server beobachten. Jedes Mal, wenn dort
    # ein neues Fenster den Fokus bekommt (Launcher → Ladebild → Spiel) und
    # 3 s bleibt, einmal „Alt+Tab“: Fokus auf ein echtes Fenster des anderen
    # Monitors und zurück, Zeiger in die Mitte. Nur solange das Spiel vorn
    # ist – nie Fokus klauen. Höchstens 6-mal, nur in den ersten 3 Minuten.
    [ -n "${addr:-}" ] || exit 0 # Fenster nie erschienen
    disp=""
    for _ in $(seq 30); do
      r=$(pgrep -P "$pid" -x gamescopereaper | head -1)
      [ -n "$r" ] && disp=$(tr '\0' '\n' <"/proc/$r/environ" 2>/dev/null | sed -n 's/^DISPLAY=//p')
      [ -n "$disp" ] && break
      sleep 1
    done
    [ -n "$disp" ] || { echo "gaming-mode: DISPLAY von gamescope nicht gefunden" >>"$log"; exit 0; }

    alt_tab() {
      local mon other
      mon=$(hyprctl clients -j | jq -r --arg a "$addr" 'first(.[] | select(.address == $a)) | .monitor')
      other=$(hyprctl clients -j | jq -r --arg a "$addr" --argjson m "${mon:-0}" \
        'first(.[] | select(.address != $a and .mapped and .monitor != $m and .workspace.id > 0)) | .address // empty')
      hyprctl eval 'hl.config({ cursor = { no_warps = false } })' >/dev/null 2>&1
      if [ -n "$other" ]; then
        hyprctl dispatch "hl.dsp.focus({ window = \"address:$other\" })" >/dev/null 2>&1
      else
        hyprctl dispatch "hl.dsp.focus({ monitor = \"$(hyprctl monitors -j | jq -r --arg m "$monitor" 'first(.[] | select(.name != $m)) | .name // empty')\" })" >/dev/null 2>&1
      fi
      sleep 0.25
      hyprctl dispatch "hl.dsp.focus({ window = \"address:$addr\" })" >/dev/null 2>&1
      hyprctl dispatch "hl.dsp.cursor.move({ x = $((x + w / 2)), y = $((y + h / 2)) })" >/dev/null 2>&1
      hyprctl eval 'hl.config({ cursor = { no_warps = true } })' >/dev/null 2>&1
    }

    last="" since=0 done_for="" count=0
    for t in $(seq 360); do
      sleep 0.5
      kill -0 "$pid" 2>/dev/null || exit 0
      fw=$(xprop -display "$disp" -root GAMESCOPE_FOCUSED_WINDOW 2>/dev/null | sed -n 's/.* = //p')
      [ -n "$fw" ] && [ "$fw" != 0 ] || continue
      if [ "$fw" != "$last" ]; then
        last=$fw since=$t
        continue
      fi
      [ "$fw" != "$done_for" ] && [ $((t - since)) -ge 6 ] || continue
      [ "$(hyprctl activewindow -j | jq -r '.pid // 0')" = "$pid" ] || continue
      alt_tab
      done_for=$fw count=$((count + 1))
      echo "gaming-mode: Alt+Tab für Spielfenster $fw" >>"$log"
      [ $count -lt 6 ] || exit 0
    done
  ) </dev/null >/dev/null 2>&1 &
  disown
fi

exec "${cmd[@]}" 2>> >(tail -c 200000 >>"$log")
