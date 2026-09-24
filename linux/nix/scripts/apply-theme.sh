#!/usr/bin/env bash
# ============================================================
#  apply-theme – Catppuccin auf Plasma, Qt- und GTK-Apps anwenden
#  Wird von theme.nix als Befehl `apply-theme` installiert, die
#  Theme-Namen kommen von dort (THEME_*-Variablen).
#
#    apply-theme          jetzt anwenden
#    apply-theme --once   nur beim ersten Login (Autostart)
# ============================================================

set -euo pipefail

: "${THEME_LOOKANDFEEL:?}" "${THEME_COLORSCHEME:?}" "${THEME_CURSOR:?}"
: "${THEME_ICONS:?}" "${THEME_DISCORD_CSS:?}"

marker="${XDG_STATE_HOME:-$HOME/.local/state}/apply-theme.done"

if [ "${1:-}" = "--once" ] && [ -e "$marker" ]; then
  exit 0
fi

# Einzelne Schritte dürfen scheitern (z. B. „ist schon aktiv“)
run() {
  "$@" || echo "apply-theme: '$*' fehlgeschlagen – übersprungen" >&2
}

# Globales Design: Farbschema, Fensterdekoration, Splash
run plasma-apply-lookandfeel --apply "$THEME_LOOKANDFEEL"
# Einzeln nachziehen – das Globale Design verweist auf andere Cursor-Namen.
# KDE überträgt Farben, Cursor und Icons automatisch auf GTK-Apps.
run plasma-apply-colorscheme "$THEME_COLORSCHEME"
run plasma-apply-cursortheme "$THEME_CURSOR"
run plasma-changeicons "$THEME_ICONS"

# Vesktop: Theme bereitlegen (aktivieren unter Einstellungen → Themes)
vesktop_themes="${XDG_CONFIG_HOME:-$HOME/.config}/vesktop/themes"
mkdir -p "$vesktop_themes"
ln -sf "$THEME_DISCORD_CSS" "$vesktop_themes/"

mkdir -p "$(dirname "$marker")"
touch "$marker"
echo "Catppuccin angewendet. Laufende Apps ggf. neu starten."
