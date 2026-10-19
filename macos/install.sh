#!/usr/bin/env bash
# install.sh (macOS) – Programme (Brewfile), matugen und Dotfiles.
# Jeder Schritt darf beliebig oft laufen.
#
#   ~/dotfiles/macos/install.sh
set -euo pipefail

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
repo=$(cd "$here/.." && pwd)
export PATH="/opt/homebrew/bin:$HOME/.cargo/bin:$HOME/.local/bin:$PATH"
matugen_version=4.2.0 # wie unter Linux

step() { printf '\n\033[1;34m── %s\033[0m\n' "$*"; }
warn() { printf '\033[1;33m  ! %s\033[0m\n' "$*"; }

[ "$(uname)" = Darwin ] || { echo "das ist kein macOS" >&2; exit 1; }

step "Homebrew und Programme"
command -v brew >/dev/null ||
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
# Fremd-Taps: nur die einzelnen Pakete vertrauen, nicht ganze Taps
brew trust --cask nikitabobko/tap/aerospace
brew trust --formula felixkratz/formulae/borders cormacrelf/tap/dark-notify
brew trust --cask d12frosted/emacs-plus/emacs-plus-app
# Altes Emacs.app (emacsformacosx) belegt denselben Platz in /Applications
brew list --cask emacs-app >/dev/null 2>&1 && brew uninstall --cask emacs-app
brew bundle --file "$here/Brewfile"

step "matugen $matugen_version"
[ "$(matugen --version 2>/dev/null)" = "matugen $matugen_version" ] ||
  cargo install --locked matugen --version "$matugen_version"

step "Dotfiles verlinken"
# macOS-eigene Configs und die von Linux geteilten
mkdir -p "$HOME/.config" "$HOME/.local/bin" "$HOME/.local/state" "$HOME/.cache/matugen"
link() {
  local src=$1 dst=$HOME/.config/$2
  if [ -e "$dst" ] && [ ! -L "$dst" ]; then
    mv "$dst" "$dst.bak-$(date +%s)"; warn "$dst gesichert als .bak"
  fi
  ln -sfn "$src" "$dst"
}
for name in aerospace matugen; do link "$repo/macos/.config/$name" "$name"; done
for name in fish nvim emacs tmux ghostty; do link "$repo/linux/.config/$name" "$name"; done
ln -sfn "$repo/macos/.config/matugen/theme.sh" "$HOME/.local/bin/theme"
# Ghostty: macOS-eigene Werte (Schriftgröße) über der geteilten Config
ghostty_mac="$HOME/Library/Application Support/com.mitchellh.ghostty"
mkdir -p "$ghostty_mac"
ln -sfn "$here/ghostty/config.ghostty" "$ghostty_mac/config.ghostty"
mkdir -p "$HOME/Library/Application Support/vesktop/themes" "$HOME/.config/borders"

step "macOS: Fenster ohne Animationen, kein eigenes Kacheln"
# Fenster öffnen/skalieren ohne Animation (AeroSpace wirkt sonst träge)
defaults write -g NSAutomaticWindowAnimationsEnabled -bool false
defaults write -g NSWindowResizeTime -float 0.001
# Eigenes Kacheln von macOS aus: an den Rand ziehen bzw. ⌥ beim Ziehen
# kämpft mit AeroSpace (und ⌥ ist hier die Mod-Taste)
defaults write com.apple.WindowManager EnableTilingByEdgeDrag -bool false
defaults write com.apple.WindowManager EnableTopTilingByEdgeDrag -bool false
defaults write com.apple.WindowManager EnableTilingOptionAccelerator -bool false
defaults write com.apple.WindowManager EnableTiledWindowMargins -bool false
# Mission Control: Fenster nach App gruppieren (AeroSpace versteckt Fenster
# in der Ecke, sonst sind sie dort winzig), Spaces nicht umsortieren
defaults write com.apple.dock expose-group-apps -bool true
defaults write com.apple.dock mru-spaces -bool false
killall Dock 2>/dev/null || true

step "Fish: fisher-Plugins, Tide-Einstellungen"
fish -c 'type -q fisher || curl -fsSL https://raw.githubusercontent.com/jorgebucaran/fisher/main/functions/fisher.fish | source
  fisher update >/dev/null && source ~/.config/fish/tide.fish' || warn "fisher/Tide nicht eingerichtet"

step "Hell/Dunkel: theme.sh bei jedem Wechsel des Erscheinungsbilds"
agent=$HOME/Library/LaunchAgents/local.theme-appearance.plist
mkdir -p "${agent%/*}"
cat >"$agent" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>local.theme-appearance</string>
  <key>ProgramArguments</key>
  <array>
    <string>/opt/homebrew/bin/dark-notify</string>
    <string>-c</string>
    <string>$HOME/.config/matugen/theme.sh</string>
  </array>
  <key>EnvironmentVariables</key>
  <dict>
    <key>PATH</key><string>/opt/homebrew/bin:$HOME/.cargo/bin:/usr/bin:/bin:/usr/sbin:/sbin</string>
  </dict>
  <key>RunAtLoad</key><true/>
  <key>KeepAlive</key><true/>
  <key>StandardErrorPath</key><string>$HOME/.local/state/theme-appearance.log</string>
</dict>
</plist>
PLIST
launchctl bootout "gui/$(id -u)/local.theme-appearance" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "$agent"

step "Farben aus dem aktuellen Hintergrund"
"$HOME/.config/matugen/theme.sh" || warn "theme.sh fehlgeschlagen – später: theme BILD"

step "Fertig"
cat <<TXT
  Einmal von Hand:
  - AeroSpace starten, Bedienungshilfen erlauben (startet danach selbst)
  - Raycast starten: Hotkey ⌘Space (vorher Spotlight in Systemeinstellungen → Tastatur → Kurzbefehle abschalten), Clipboard History einen Hotkey geben
  - Systemeinstellungen → Erscheinungsbild → Automatisch
TXT
