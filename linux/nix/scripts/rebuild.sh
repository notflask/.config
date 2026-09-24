#!/usr/bin/env bash
# ============================================================
#  Config anwenden / System aktualisieren
#
#    rebuild.sh            Config anwenden (switch)
#    rebuild.sh update     Pakete aktualisieren (flake.lock) + switch
#    rebuild.sh boot       erst beim nächsten Neustart aktiv
#    rebuild.sh test       aktivieren ohne Boot-Eintrag
#
#  Im Boot-Eintrag „gaming“ bleibt das System im Gaming-Modus.
# ============================================================

set -euo pipefail

FLAKE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOST="g5"

action="${1:-switch}"
case "$action" in
  update)
    (cd "$FLAKE_DIR" && nix flake update)
    action="switch"
    ;;
  switch | boot | test | build | dry-build) ;;
  *)
    sed -n '2,12p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
    exit 1
    ;;
esac

args=("$action" --flake "$FLAKE_DIR#$HOST" --sudo)

# Sonst würde `switch` aus dem Gaming-Modus in den Normalmodus wechseln
if [ -f /etc/specialisation ] && [[ "$action" == switch || "$action" == test ]]; then
  args+=(--specialisation "$(cat /etc/specialisation)")
fi

nixos-rebuild "${args[@]}"
