#!/usr/bin/env bash
# ============================================================
#  dotfiles/sync.sh  –  Configs → Repo synchronisieren
#  Verwendung:
#    ./sync.sh          # alles synchronisieren
#    ./sync.sh nvim     # nur einen Abschnitt
# ============================================================

set -euo pipefail

# ── Konfiguration ────────────────────────────────────────────
DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WIN_USER="${WIN_USER:-flask}" # anpassen oder als Env-Variable setzen
WIN_HOME="/mnt/c/Users/$WIN_USER"
WIN_APPDATA="$WIN_HOME/AppData/Roaming"

# ── Farben ───────────────────────────────────────────────────
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

ok() { echo -e "${GREEN}  ✓ $1${NC}"; }
warn() { echo -e "${YELLOW}  ! $1${NC}"; }
err() { echo -e "${RED}  ✗ $1${NC}"; }

# ── Hilfsfunktion: kopieren wenn Quelle existiert ────────────
sync_file() {
  local src="$1"
  local dst_dir="$2"
  local label="$3"

  if [ ! -e "$src" ]; then
    warn "$label – Quelle nicht gefunden: $src"
    return
  fi

  mkdir -p "$dst_dir"

  if [ -d "$src" ]; then
    cp -r "$src/." "$dst_dir/"
  else
    cp "$src" "$dst_dir/"
  fi

  ok "$label"
}

# ── Einzelne Abschnitte ──────────────────────────────────────

sync_nvim() {
  echo "── Neovim ──────────────────────────────────────"
  sync_file \
    "$HOME/.config/nvim" \
    "$DOTFILES/linux/.config/nvim" \
    "nvim config"
}

sync_glazewm() {
  echo "── GlazeWM ─────────────────────────────────────"
  sync_file \
    "$WIN_HOME/.glzr/glazewm" \
    "$DOTFILES/windows/glazewm" \
    "glazewm config"
  sync_file \
    "$WIN_HOME/.glzr/zebar" \
    "$DOTFILES/windows/zebar" \
    "zebar config"
}

sync_vscode() {
  echo "── VS Code ─────────────────────────────────────"
  sync_file \
    "$WIN_APPDATA/Code/User/settings.json" \
    "$DOTFILES/windows/vscode" \
    "vscode settings.json"
  sync_file \
    "$WIN_APPDATA/Code/User/keybindings.json" \
    "$DOTFILES/windows/vscode" \
    "vscode keybindings.json"
  sync_file \
    "$WIN_APPDATA/Code/User/snippets" \
    "$DOTFILES/windows/vscode/snippets" \
    "vscode snippets"
}

sync_hypr() {
  echo "── Hyprland ────────────────────────────────────"
  sync_file \
    "$HOME/.config/hypr" \
    "$DOTFILES/linux/.config/hypr" \
    "hypr config"
}

sync_niri() {
  echo "── Niri ────────────────────────────────────"
  sync_file \
    "$HOME/.config/niri" \
    "$DOTFILES/linux/.config/niri" \
    "niri config"
}

sync_fuzzel() {
  echo "── Fuzzel ────────────────────────────────────"
  sync_file \
    "$HOME/.config/fuzzel" \
    "$DOTFILES/linux/.config/fuzzel" \
    "fuzzel config"
}

sync_matugen() {
  echo "── Matugen ─────────────────────────────────────"
  sync_file \
    "$HOME/.config/matugen" \
    "$DOTFILES/linux/.config/matugen" \
    "matugen config"
}

sync_waybar() {
  echo "── Waybar ──────────────────────────────────────"
  sync_file \
    "$HOME/.config/waybar" \
    "$DOTFILES/linux/.config/waybar" \
    "waybar config"
}

sync_waypaper() {
  echo "── Waypaper ────────────────────────────────────"
  sync_file \
    "$HOME/.config/waypaper" \
    "$DOTFILES/linux/.config/waypaper" \
    "waypaper config"
}

sync_wofi() {
  echo "── Wofi ────────────────────────────────────────"
  sync_file \
    "$HOME/.config/wofi" \
    "$DOTFILES/linux/.config/wofi" \
    "wofi config"
}

sync_sioyek() {
  echo "── Sioyek ──────────────────────────────────────"
  sync_file \
    "$WIN_APPDATA/sioyek/prefs.config" \
    "$DOTFILES/windows/sioyek" \
    "sioyek prefs.config"
  sync_file \
    "$WIN_APPDATA/sioyek/keys.config" \
    "$DOTFILES/windows/sioyek" \
    "sioyek keys.config"
}

sync_tmux() {
  echo "── Tmux ──────────────────────────────────────"
  sync_file \
    "$HOME/.config/tmux" \
    "$DOTFILES/linux/.config/tmux" \
    "tmux config"
}

# ── Git commit & push ────────────────────────────────────────

git_push() {
  echo "── Git ─────────────────────────────────────────"
  cd "$DOTFILES"

  if [ -z "$(git status --porcelain)" ]; then
    warn "Keine Änderungen – nichts zu committen."
    return
  fi

  git add .
  TIMESTAMP=$(date '+%Y-%m-%d %H:%M')
  git commit -m "sync: $TIMESTAMP"
  git push
  ok "Gepusht nach GitHub"
}

# ── Dispatcher ───────────────────────────────────────────────

echo ""
echo "╔══════════════════════════════════════╗"
echo "║        dotfiles sync.sh              ║"
echo "╚══════════════════════════════════════╝"
echo ""

TARGET="${1:-all}"

case "$TARGET" in
nvim) sync_nvim ;;
glazewm) sync_glazewm ;;
vscode) sync_vscode ;;
sioyek) sync_sioyek ;;
hypr) sync_hypr ;;
matugen) sync_matugen ;;
waybar) sync_waybar ;;
waypaper) sync_waypaper ;;
wofi) sync_wofi ;;
tmux) sync_tmux ;;
all)
  sync_nvim
  sync_hypr
  sync_matugen
  sync_waybar
  sync_waypaper
  sync_wofi
  sync_glazewm
  sync_vscode
  sync_sioyek
  sync_tmux
  sync_niri
  sync_fuzzel
  git_push
  ;;
*)
  err "Unbekanntes Ziel: $TARGET"
  echo "  Gültige Optionen: all | nvim | hypr | matugen | waybar | waypaper | wofi | glazewm | vscode | sioyek | tmux | niri | fuzzel"
  exit 1
  ;;
esac

echo ""
echo -e "${GREEN}Fertig!${NC}"
