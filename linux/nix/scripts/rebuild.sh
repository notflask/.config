#!/usr/bin/env bash
# ============================================================
#  Config anwenden / System aktualisieren
#
#    rebuild.sh            Config anwenden (switch)
#    rebuild.sh update     Pakete aktualisieren (flake.lock, Claude Desktop,
#                          ATAS X, HaruNeko)
#                          + switch, danach auch Flatpaks (z. B. Sober)
#    rebuild.sh boot       erst beim nächsten Neustart aktiv
#    rebuild.sh test       aktivieren ohne Boot-Eintrag
#
#  Holt vorher neue Commits von GitHub (nur Fast-Forward) und erzeugt
#  danach die Farben neu (theme), wenn sich die Templates geändert haben.
#  Ohne GitHub: REBUILD_NO_PULL=1 rebuild
# ============================================================

set -euo pipefail

FLAKE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO="$(git -C "$FLAKE_DIR" rev-parse --show-toplevel 2>/dev/null || true)"
HOST="g5"

# Von theme.sh (matugen) erzeugt, aber im Repo als Startwerte eingecheckt –
# lokal also fast immer geändert. Vor dem Pull verwerfen, theme.sh erzeugt
# sie danach neu.
generated=(
  linux/.config/hypr/colors.lua
  linux/.config/hypr/hyprlock-colors.conf
  linux/.config/mako/config
  linux/.config/niri/colors.kdl
  linux/.config/rofi/colors.rasi
  linux/.config/waybar/colors.css
  linux/.config/waybar/glass.css
)

warn() { echo "rebuild: $*" >&2; }

# Neue Commits holen. Klappt das nicht (offline, eigene Commits, eigene
# Änderungen an denselben Dateien), wird mit dem lokalen Stand gebaut.
# Danach startet das Skript in seiner neuen Fassung neu (Bash liest die
# Datei beim Ausführen nach und nach – sie darf sich nicht unter der Hand
# ändern).
pull() {
  [ -n "$REPO" ] && [ -z "${REBUILD_NO_PULL:-}" ] || return 0
  git -C "$REPO" rev-parse --verify --quiet '@{u}' >/dev/null ||
    { warn "Branch ohne Upstream – nichts geholt"; return 0; }
  git -C "$REPO" fetch --quiet ||
    { warn "GitHub nicht erreichbar – baue den lokalen Stand"; return 0; }
  [ "$(git -C "$REPO" rev-list --count 'HEAD..@{u}')" -gt 0 ] || return 0

  local file
  for file in "${generated[@]}"; do
    git -C "$REPO" ls-files --error-unmatch -- "$file" >/dev/null 2>&1 &&
      git -C "$REPO" checkout -- "$file"
  done
  export REBUILD_PULLED=1 # theme danach auf jeden Fall neu erzeugen
  if git -C "$REPO" merge --ff-only --quiet '@{u}'; then
    echo "rebuild: neue Änderungen geholt:"
    git -C "$REPO" log --oneline 'HEAD@{1}..HEAD' || true
    REBUILD_NO_PULL=1 REBUILD_PULLED=1 exec "$REPO/linux/nix/scripts/rebuild.sh" "$@"
  else
    warn "Konnte nicht vorspulen (eigene Commits oder Änderungen) – baue den lokalen Stand"
  fi
}

# Farben neu erzeugen, wenn sich Templates oder theme.sh seit dem letzten
# Mal geändert haben (egal ob per rebuild oder von Hand gepullt) oder eben
# Farbdateien verworfen wurden. Nur in einer laufenden Sitzung – sonst
# übernimmt das der nächste Login.
retheme() {
  [ -n "$REPO" ] || return 0
  [ -n "${NIRI_SOCKET:-}${HYPRLAND_INSTANCE_SIGNATURE:-}" ] || return 0
  local matugen="$REPO/linux/.config/matugen"
  local stamp="${XDG_STATE_HOME:-$HOME/.local/state}/theme-templates.sha256"
  local sum
  sum=$(cat "$matugen/theme.sh" "$matugen/config.toml" "$matugen"/templates/* | sha256sum)
  if [ -z "${REBUILD_PULLED:-}" ] && [ "$sum" = "$(cat "$stamp" 2>/dev/null)" ]; then
    return 0
  fi
  echo "rebuild: Theme wird neu erzeugt …"
  if "$matugen/theme.sh"; then
    mkdir -p "$(dirname "$stamp")" && echo "$sum" >"$stamp"
  else
    warn "theme ist fehlgeschlagen"
  fi
}

action="${1:-switch}"
update_flatpaks=0
case "$action" in
  update)
    pull "$@"
    (cd "$FLAKE_DIR" && nix flake update)
    "$FLAKE_DIR/scripts/update-claude-desktop.sh"
    "$FLAKE_DIR/scripts/update-atas-x.sh"
    "$FLAKE_DIR/scripts/update-haruneko.sh"
    action="switch"
    update_flatpaks=1
    ;;
  switch | boot | test | build | dry-build)
    pull "$@"
    ;;
  *)
    sed -n '2,15p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
    exit 1
    ;;
esac

# Auch wenn der Build scheitert: die verworfenen Farbdateien wiederherstellen
trap retheme EXIT

nixos-rebuild "$action" --flake "$FLAKE_DIR#$HOST" --sudo

# Flatpaks nach dem System aktualisieren – so passt auch die NVIDIA-
# Erweiterung der Flatpaks zum gerade installierten Treiber.
if [ "$update_flatpaks" -eq 1 ] && command -v flatpak >/dev/null; then
  flatpak update -y
fi
