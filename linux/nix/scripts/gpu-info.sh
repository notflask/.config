#!/usr/bin/env bash
# ============================================================
#  Zeigt GPUs, deren Stromzustand und welcher Bildschirm-
#  Anschluss an welcher GPU hängt.
# ============================================================

set -euo pipefail

gpu_name() {
  case "$(cat "$1/vendor")" in
    0x8086) echo "Intel" ;;
    0x10de) echo "NVIDIA" ;;
    *) echo "unbekannt" ;;
  esac
}

echo "── GPUs ─────────────────────────────────────────"
for dev in /sys/bus/pci/devices/*; do
  [[ "$(cat "$dev/class")" == 0x03* ]] || continue
  driver="$(basename "$(readlink -f "$dev/driver" 2>/dev/null)" 2>/dev/null || echo -)"
  power="$(cat "$dev/power/runtime_status" 2>/dev/null || echo -)"
  printf "  %-7s %s  Treiber: %-8s Status: %s\n" "$(gpu_name "$dev")" "$(basename "$dev")" "$driver" "$power"
done

echo
echo "── Anschlüsse ───────────────────────────────────"
for conn in /sys/class/drm/card*-*; do
  [ -f "$conn/status" ] || continue
  name="${conn##*/}"
  name="${name#card*-}"
  pci="$(readlink -f "$conn/device/device")"
  status="$(cat "$conn/status")"
  mark=""
  [ "$status" = "connected" ] && mark="  ◀ angeschlossen"
  printf "  %-12s → %-7s%s\n" "$name" "$(gpu_name "$pci")" "$mark"
done

echo
echo "── Modus ────────────────────────────────────────"
if [ -f /etc/specialisation ]; then
  echo "  Boot-Eintrag: $(cat /etc/specialisation)"
else
  echo "  Boot-Eintrag: normal (PRIME Offload)"
fi
echo "  KWIN_DRM_DEVICES=${KWIN_DRM_DEVICES:-<nicht gesetzt → KWin auf Intel>}"

cat <<'MSG'

Für CS2 auf dem externen Monitor: Kabel an einen Anschluss stecken, der
an der NVIDIA hängt, und im Boot-Eintrag „gaming“ starten.
MSG
