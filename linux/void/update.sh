#!/usr/bin/env bash
# ============================================================
#  update.sh – System aktualisieren (wie `rebuild update` unter NixOS)
#
#    update            neue Commits holen, Quellen der eigenen Pakete
#                      aktualisieren, dann alle Schritte von setup.sh
#                      (Void-Pakete, eigene Pakete, Configs, Dienste)
#    update --no-pull  ohne GitHub (lokaler Stand)
#
#  Danach Flatpaks (Sober) und Spicetify. Farben neu erzeugen, wenn sich
#  die matugen-Vorlagen geändert haben: theme
# ============================================================

set -euo pipefail

here=$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)
repo=$(git -C "$here" rev-parse --show-toplevel)

# Von theme.sh (matugen) erzeugt, aber im Repo als Startwerte eingecheckt –
# vor dem Pull verwerfen, theme.sh erzeugt sie danach neu (wie rebuild.sh)
generated=(
  linux/.config/gtklock/style.css
  linux/.config/mako/config
  linux/.config/mako/config-flat
  linux/.config/fastfetch/void.jsonc
  linux/.config/ghostty/themes/matugen
  linux/.config/rofi/colors.rasi
  linux/.config/quickshell/taskbar/colors.css
  linux/.config/quickshell/taskbar/glass.css
)

if [ "${1:-}" != --no-pull ] && git -C "$repo" rev-parse --verify --quiet '@{u}' >/dev/null; then
  if git -C "$repo" fetch --quiet; then
    if [ "$(git -C "$repo" rev-list --count 'HEAD..@{u}')" -gt 0 ]; then
      for file in "${generated[@]}"; do
        git -C "$repo" ls-files --error-unmatch -- "$file" >/dev/null 2>&1 &&
          git -C "$repo" checkout -- "$file"
      done
      if git -C "$repo" merge --ff-only --quiet '@{u}'; then
        echo "update: neue Änderungen geholt:"
        git -C "$repo" log --oneline 'HEAD@{1}..HEAD' || true
        # in der neuen Fassung weitermachen
        exec "$here/update.sh" --no-pull
      fi
      echo "update: konnte nicht vorspulen (eigene Commits?) – lokaler Stand" >&2
    fi
  else
    echo "update: GitHub nicht erreichbar – lokaler Stand" >&2
  fi
fi

"$here/update-sources.sh" || echo "update: Quellen nicht aktualisiert, baue die alten Versionen" >&2
sudo "$here/setup.sh"

if command -v flatpak >/dev/null; then
  flatpak update --user -y
fi
command -v spicetify-setup >/dev/null && { spicetify-setup || true; }
"$repo/linux/.config/matugen/theme.sh" >/dev/null 2>&1 || true
