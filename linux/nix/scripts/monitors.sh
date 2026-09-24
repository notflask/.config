#!/usr/bin/env bash
# ============================================================
#  Bildschirme in KDE Plasma einrichten (einmalig nach Login):
#    eDP-1  interner Bildschirm  1920x1080 @ 144 Hz  links
#    DP-2   LG UltraGear 2K      2560x1440 @ 180 Hz  rechts, primär, VRR
#
#  Andere Anschlussnamen:  INTERNAL=eDP-1 EXTERNAL=HDMI-A-1 monitors.sh
#  Namen anzeigen:         kscreen-doctor -o
# ============================================================

set -euo pipefail

INTERNAL="${INTERNAL:-eDP-1}"
EXTERNAL="${EXTERNAL:-DP-2}"

command -v kscreen-doctor >/dev/null || {
  echo "kscreen-doctor nicht gefunden – läuft KDE Plasma?" >&2
  exit 1
}

outputs="$(kscreen-doctor -o | sed 's/\x1b\[[0-9;]*m//g')"
for out in "$INTERNAL" "$EXTERNAL"; do
  if ! grep -Eq "^Output: [0-9]+ $out( |$)" <<<"$outputs"; then
    echo "Ausgang '$out' nicht gefunden. Vorhanden:" >&2
    grep '^Output:' <<<"$outputs" | awk '{print "  " $3}' >&2
    exit 1
  fi
done

kscreen-doctor \
  "output.$EXTERNAL.enable" \
  "output.$EXTERNAL.mode.2560x1440@180" \
  "output.$EXTERNAL.scale.1" \
  "output.$EXTERNAL.position.1920,0" \
  "output.$EXTERNAL.priority.1" \
  "output.$EXTERNAL.vrrpolicy.automatic" \
  "output.$INTERNAL.enable" \
  "output.$INTERNAL.mode.1920x1080@144" \
  "output.$INTERNAL.scale.1" \
  "output.$INTERNAL.position.0,0" \
  "output.$INTERNAL.priority.2"

echo "Fertig. KDE merkt sich die Anordnung für diese Monitor-Kombination."
