#!/usr/bin/env bash
# ============================================================
#  Config anwenden / System aktualisieren
#
#    rebuild.sh            Config anwenden (switch)
#    rebuild.sh update     Pakete aktualisieren (flake.lock, Claude Desktop)
#                          + switch, danach auch Flatpaks (z. B. Sober)
#    rebuild.sh boot       erst beim nächsten Neustart aktiv
#    rebuild.sh test       aktivieren ohne Boot-Eintrag
# ============================================================

set -euo pipefail

FLAKE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOST="g5"

action="${1:-switch}"
update_flatpaks=0
case "$action" in
  update)
    (cd "$FLAKE_DIR" && nix flake update)
    "$FLAKE_DIR/scripts/update-claude-desktop.sh"
    action="switch"
    update_flatpaks=1
    ;;
  switch | boot | test | build | dry-build) ;;
  *)
    sed -n '2,10p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
    exit 1
    ;;
esac

nixos-rebuild "$action" --flake "$FLAKE_DIR#$HOST" --sudo

# Flatpaks nach dem System aktualisieren – so passt auch die NVIDIA-
# Erweiterung der Flatpaks zum gerade installierten Treiber.
if [ "$update_flatpaks" -eq 1 ] && command -v flatpak >/dev/null; then
  flatpak update -y
fi
