#!/usr/bin/env bash
# install.sh (macOS) – Programme (Brewfile), matugen, Dotfiles, Shell und
# Systemeinstellungen. Jeder Schritt darf beliebig oft laufen.
#
#   Neuer Mac (holt das Repo nach ~/dotfiles):
#     curl -fsSL https://raw.githubusercontent.com/notflask/.config/master/macos/install.sh | bash
#   Danach / zum Aktualisieren:
#     ~/dotfiles/macos/install.sh
set -euo pipefail

export PATH="/opt/homebrew/bin:/opt/homebrew/sbin:$HOME/.cargo/bin:$HOME/.local/bin:$PATH"
matugen_version=4.2.0 # wie unter Linux

step() { printf '\n\033[1;34m── %s\033[0m\n' "$*"; }
warn() { printf '\033[1;33m  ! %s\033[0m\n' "$*"; }

[ "$(uname)" = Darwin ] || { echo "das ist kein macOS" >&2; exit 1; }

here=$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)
# Über curl | bash gestartet: Homebrew (bringt git über die Command Line
# Tools mit), Repo klonen und das Skript von dort neu starten. Eingaben
# (Passwort, Rückfragen) kommen vom Terminal, nicht aus der Pipe.
if [ ! -f "$here/Brewfile" ]; then
  dotfiles=${DOTFILES:-$HOME/dotfiles}
  step "Homebrew"
  command -v brew >/dev/null || /bin/bash -c \
    "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" </dev/tty
  step "Dotfiles nach $dotfiles"
  if [ -d "$dotfiles/.git" ]; then git -C "$dotfiles" pull --ff-only || warn "git pull fehlgeschlagen"
  else git clone https://github.com/notflask/.config "$dotfiles"; fi
  exec bash "$dotfiles/macos/install.sh" </dev/tty
fi
repo=$(cd "$here/.." && pwd)

step "Homebrew und Programme"
command -v brew >/dev/null ||
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
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
for name in aerospace matugen karabiner; do link "$repo/macos/.config/$name" "$name"; done
for name in fish nvim emacs tmux ghostty; do link "$repo/linux/.config/$name" "$name"; done
ln -sfn "$repo/macos/.config/matugen/theme.sh" "$HOME/.local/bin/theme"
# Ghostty: macOS-eigene Werte (Schriftgröße) über der geteilten Config
ghostty_mac="$HOME/Library/Application Support/com.mitchellh.ghostty"
mkdir -p "$ghostty_mac"
ln -sfn "$here/ghostty/config.ghostty" "$ghostty_mac/config.ghostty"
mkdir -p "$HOME/Library/Application Support/vesktop/themes" "$HOME/.config/borders"

step "Fish: Standard-Shell, PATH, fisher-Plugins, Tide-Einstellungen"
fish_bin=/opt/homebrew/bin/fish
grep -qx "$fish_bin" /etc/shells || echo "$fish_bin" | sudo tee -a /etc/shells >/dev/null
[ "$(dscl . -read "/Users/$USER" UserShell | awk '{print $2}')" = "$fish_bin" ] ||
  chsh -s "$fish_bin" || warn "chsh fehlgeschlagen – von Hand: chsh -s $fish_bin"
# fish liest /etc/paths, kennt Homebrew unter /opt/homebrew aber nicht
fish -c 'fish_add_path -U /opt/homebrew/bin /opt/homebrew/sbin ~/.cargo/bin ~/.local/bin'
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

step "Systemeinstellungen (Dock, Mission Control, Tempo)"
# Dock nur bei Bedarf – AeroSpace kachelt den ganzen Bildschirm
defaults write com.apple.dock autohide -bool true
defaults write com.apple.dock show-recents -bool false
# Von AeroSpace empfohlen: Mission Control gruppiert Fenster nach App
# (sonst winzige Fenster), ein Space über alle Monitore (ab Abmelden)
defaults write com.apple.dock expose-group-apps -bool true
defaults write com.apple.spaces spans-displays -bool true
defaults write com.apple.dock mru-spaces -bool false
# Eigenes Kacheln von macOS aus: an den Rand ziehen bzw. ⌥ beim Ziehen
# kämpft mit AeroSpace
defaults write com.apple.WindowManager EnableTilingByEdgeDrag -bool false
defaults write com.apple.WindowManager EnableTopTilingByEdgeDrag -bool false
defaults write com.apple.WindowManager EnableTilingOptionAccelerator -bool false
defaults write com.apple.WindowManager EnableTiledWindowMargins -bool false
# Flott: Dock ohne Verzögerung, kurze Mission-Control-Animation, keine
# Öffnen-Animation für Fenster, schnelle Tastenwiederholung (ab Abmelden)
defaults write com.apple.dock autohide-delay -float 0
defaults write com.apple.dock autohide-time-modifier -float 0.15
defaults write com.apple.dock expose-animation-duration -float 0.1
defaults write -g NSAutomaticWindowAnimationsEnabled -bool false
defaults write -g NSWindowResizeTime -float 0.001
defaults write -g KeyRepeat -int 2
defaults write -g InitialKeyRepeat -int 15
defaults write -g ApplePressAndHoldEnabled -bool false
killall Dock 2>/dev/null || true

step "Farben aus dem aktuellen Hintergrund"
"$HOME/.config/matugen/theme.sh" || warn "theme.sh fehlgeschlagen – später: theme BILD"

step "Fertig"
cat <<TXT
  Einmal von Hand:
  - AeroSpace starten, Bedienungshilfen erlauben (startet danach selbst)
  - Karabiner-Elements starten, Treiber/Systemerweiterung und Eingabeüberwachung erlauben
  - Raycast starten: Hotkey ⌥Space, Clipboard History einen Hotkey geben
  - Helium: Systemeinstellungen → Desktop & Dock → Standard-Webbrowser;
    chrome://extensions → Entwicklermodus → „Entpackte Erweiterung laden“ →
    ⌘⇧G, ~/.local/share/helium-theme (nach neuem Hintergrund wiederholen)
  - Systemeinstellungen → Erscheinungsbild → Automatisch
  - einmal ab- und wieder anmelden (Spaces über alle Monitore, fish als Shell)
TXT
