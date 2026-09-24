#!/usr/bin/env bash
# ============================================================
#  gaming-mode – startet ein Spiel mit allem, was es schnell macht:
#  GameMode, RTX 4060, MangoHud, großer Shader-Cache, NVAPI (DLSS).
#  Wird von gaming.nix als Befehl `gaming-mode` installiert.
# ============================================================

set -euo pipefail

usage() {
  cat <<'HELP'
Benutzung:  gaming-mode [Optionen] <befehl> [argumente]

  Steam-Startoption:  gaming-mode %command%
  Außerhalb Steam:    gaming-mode ./spiel

Optionen (vor dem Befehl):
  --no-hud          ohne MangoHud-Overlay
  --stretch WxH     in WxH rendern und per gamescope auf den ganzen
                    Monitor strecken, z. B. --stretch 1920x1440
  --output WxH      Monitorauflösung für --stretch (Standard: 2560x1440)
  -h, --help        diese Hilfe

MangoHud ein-/ausblenden: Shift rechts + F12
HELP
}

die() {
  echo "gaming-mode: $1" >&2
  exit 1
}

# "1920x1440" → res_w=1920 res_h=1440
parse_res() {
  [[ "$1" =~ ^([0-9]+)x([0-9]+)$ ]] || die "Ungültige Auflösung '$1' (Format: 1920x1440)"
  res_w="${BASH_REMATCH[1]}"
  res_h="${BASH_REMATCH[2]}"
}

hud=1
stretch=""
output="2560x1440"

while [ $# -gt 0 ]; do
  case "$1" in
    --no-hud)
      hud=0
      shift
      ;;
    --stretch | --output)
      [ $# -ge 2 ] || die "$1 braucht eine Auflösung, z. B. 1920x1440"
      if [ "$1" = "--stretch" ]; then stretch="$2"; else output="$2"; fi
      shift 2
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    --)
      shift
      break
      ;;
    *) break ;;
  esac
done

if [ $# -eq 0 ]; then
  usage >&2
  exit 1
fi

# ── RTX 4060 erzwingen (wie nvidia-offload) ──────────────────
export __NV_PRIME_RENDER_OFFLOAD=1
export __NV_PRIME_RENDER_OFFLOAD_PROVIDER=NVIDIA-G0
export __GLX_VENDOR_LIBRARY_NAME=nvidia
export __VK_LAYER_NV_optimus=NVIDIA_only

# ── Shader-Cache: 10 GB, nicht automatisch aufräumen ─────────
# Weniger Ruckler durch Shader-Kompilierung (OpenGL + Vulkan)
export __GL_SHADER_DISK_CACHE=1
export __GL_SHADER_DISK_CACHE_SIZE=10737418240
export __GL_SHADER_DISK_CACHE_SKIP_CLEANUP=1

# ── Proton: NVAPI für DLSS / Reflex in Windows-Spielen ───────
export PROTON_ENABLE_NVAPI=1

# ── MangoHud-Layout, falls keine eigene Config existiert ─────
if [ -z "${MANGOHUD_CONFIG:-}" ] && [ ! -e "${XDG_CONFIG_HOME:-$HOME/.config}/MangoHud/MangoHud.conf" ]; then
  export MANGOHUD_CONFIG="position=top-left,background_alpha=0.4,fps,frametime,frame_timing,gpu_stats,gpu_temp,cpu_stats,cpu_temp,ram,vram"
fi

cmd=(gamemoderun)

if [ -n "$stretch" ]; then
  parse_res "$stretch"
  cmd+=(gamescope -w "$res_w" -h "$res_h")
  parse_res "$output"
  cmd+=(-W "$res_w" -H "$res_h" -S stretch -f --force-grab-cursor)
  if [ "$hud" -eq 1 ]; then
    cmd+=(--mangoapp)
  fi
  cmd+=(--)
elif [ "$hud" -eq 1 ]; then
  cmd+=(mangohud)
fi

exec "${cmd[@]}" "$@"
