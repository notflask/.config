#!/usr/bin/env bash
# ============================================================
#  Config anwenden / System aktualisieren
#
#    rebuild.sh            Config anwenden (switch)
#    rebuild.sh update     Pakete aktualisieren (flake.lock) + switch
#    rebuild.sh boot       erst beim nächsten Neustart aktiv
#    rebuild.sh test       aktivieren ohne Boot-Eintrag
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
    sed -n '2,9p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
    exit 1
    ;;
esac

nixos-rebuild "$action" --flake "$FLAKE_DIR#$HOST" --sudo
