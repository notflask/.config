#!/usr/bin/env bash
# ============================================================
#  Flatpak-NVIDIA-Erweiterung an den laufenden Treiber anpassen
#
#  Sober & Co. brauchen org.freedesktop.Platform.GL.nvidia-<Version> in
#  exakt der Version des geladenen Kernelmoduls – sonst: „Sober couldn't
#  find a supported graphics device“ bzw. schwarzes Fenster. Nach einem
#  Treiber-Update (erst nach dem Neustart aktiv) passt die alte Erweiterung
#  nicht mehr. Läuft beim Login als User-Dienst (flatpak-nvidia-sync).
# ============================================================

set -euo pipefail

ver=$(sed -n 's/.*Module  *\([0-9][0-9.]*\) .*/\1/p' /proc/driver/nvidia/version 2>/dev/null | head -1)
[ -n "$ver" ] || exit 0 # kein NVIDIA-Treiber geladen
ext="org.freedesktop.Platform.GL.nvidia-${ver//./-}"

if ! flatpak info --user "$ext//1.4" >/dev/null 2>&1; then
  echo "flatpak-nvidia-sync: installiere $ext"
  flatpak install --user -y --noninteractive flathub "$ext//1.4"
fi

# Alte Treiber-Erweiterungen entfernen
flatpak list --user --runtime --columns=application |
  grep '^org\.freedesktop\.Platform\.GL\.nvidia-' | grep -vxF "$ext" |
  while read -r old; do flatpak uninstall --user -y --noninteractive "$old//1.4" || true; done
