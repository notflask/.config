#!/usr/bin/env bash
# ============================================================
#  setup.sh – Void Linux auf dem G5 einrichten bzw. auf den Stand
#  im Repo bringen (das Gegenstück zu `nixos-rebuild switch`).
#
#    sudo ./setup.sh               alle Schritte (Erstinstallation und
#                                  nach jeder Änderung im Repo)
#    sudo ./setup.sh SCHRITT ...   nur diese Schritte, in dieser Reihenfolge:
#
#      repos      nonfree/multilib-Repos, System aktualisieren
#      packages   Pakete aus packages.txt
#      custom     eigene Pakete (srcpkgs/) und Discord/Spotify/MS-Schriften
#                 mit xbps-src bauen und installieren, Vencord
#      system     /etc, Hilfsprogramme, Befehle, Sprache, Benutzer, Firewall
#      services   runit-Dienste einschalten
#      boot       Kernel-Parameter, GRUB, initramfs, Ladebildschirm
#      user       Dotfiles verlinken, pipx/cargo/Flatpak, Claude Code, Spicetify
#
#  Jeder Schritt darf beliebig oft laufen. Das Repo muss unter
#  ~/dotfiles liegen (wie unter NixOS), Benutzer: der, der sudo aufruft.
# ============================================================

set -euo pipefail

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
repo=$(cd "$here/../.." && pwd)
user=${SUDO_USER:-flask}
home=$(getent passwd "$user" | cut -d: -f6)

step() { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }
info() { printf '    %s\n' "$*"; }
warn() { printf '\033[1;33m    %s\033[0m\n' "$*" >&2; }
as_user() { sudo -u "$user" -H -- "$@"; }

check() {
  [ "$(id -u)" -eq 0 ] || { echo "setup.sh: bitte mit sudo starten" >&2; exit 1; }
  grep -q '^ID=void' /etc/os-release 2>/dev/null || { echo "setup.sh: das ist kein Void Linux" >&2; exit 1; }
  [ "$(xbps-uhelper arch)" = x86_64 ] ||
    { echo "setup.sh: braucht Void mit glibc (x86_64), nicht musl – NVIDIA und Steam laufen nur mit glibc" >&2; exit 1; }
  [ "$user" != root ] && [ -n "$home" ] || { echo "setup.sh: mit sudo als normaler Benutzer starten" >&2; exit 1; }
  [ "$repo" = "$home/dotfiles" ] || warn "Repo liegt in $repo statt $home/dotfiles – Links zeigen dorthin"
}

# Pakete aus einer Liste (Kommentare nach #)
list() { sed 's/#.*//' "$1" | tr -s ' \t' '\n' | grep -v '^$'; }

# ── repos ────────────────────────────────────────────────────────────────
do_repos() {
  step "Repos (nonfree, multilib) und System aktualisieren"
  xbps-install -Sy void-repo-nonfree void-repo-multilib void-repo-multilib-nonfree
  xbps-install -Syu xbps
  xbps-install -Syu
}

# ── packages ─────────────────────────────────────────────────────────────
do_packages() {
  step "Pakete aus packages.txt"
  mapfile -t pkgs < <(list "$here/packages.txt")
  xbps-install -Sy "${pkgs[@]}"
}

# ── custom ───────────────────────────────────────────────────────────────
# Eigene Rezepte (srcpkgs/) plus Pakete, die Void nur als Rezept hat, weil
# sie nicht weiterverteilt werden dürfen (restricted)
custom_pkgs=(
  adw-gtk3 apple-cursor font-jetbrains-mono font-minecraft font-apple-color-emoji
  spicetify-cli gigabyte-control-center claude-desktop atas-x haruneko tradingview
  warp-terminal
  discord spotify msttcorefonts
)
vencord_version=v1.4.2
vencord_sha256=52642c8521a866ad241c10337144a4f513672c54b9c86a8169954785054c815d

do_custom() {
  step "Eigene Pakete mit xbps-src bauen"
  local vp=$home/.cache/void-packages
  if [ ! -d "$vp/.git" ]; then
    as_user git clone --depth 1 https://github.com/void-linux/void-packages.git "$vp"
  else
    as_user git -C "$vp" pull --ff-only --quiet || warn "void-packages: pull fehlgeschlagen, baue mit dem alten Stand"
  fi
  # Eigene Rezepte drüberkopieren (nicht verlinken: xbps-src mag keine Links)
  for dir in "$here"/srcpkgs/*/; do
    as_user rm -rf "$vp/srcpkgs/$(basename "$dir")"
    as_user cp -r "$dir" "$vp/srcpkgs/"
  done
  as_user sh -c "grep -qx XBPS_ALLOW_RESTRICTED=yes '$vp/etc/conf' 2>/dev/null || echo XBPS_ALLOW_RESTRICTED=yes >>'$vp/etc/conf'"
  [ -d "$vp/masterdir-x86_64" ] || [ -d "$vp/masterdir" ] || as_user "$vp/xbps-src" binary-bootstrap

  local p failed=() built=() upd=() new=()
  for p in "${custom_pkgs[@]}"; do
    info "baue $p"
    if as_user "$vp/xbps-src" pkg "$p"; then built+=("$p"); else failed+=("$p"); fi
  done
  # Installieren bzw. aktualisieren (die lokalen Repos zusätzlich zu den offiziellen)
  for p in "${built[@]}"; do
    if xbps-query "$p" >/dev/null 2>&1; then upd+=("$p"); else new+=("$p"); fi
  done
  local repos=(-R "$vp/hostdir/binpkgs" -R "$vp/hostdir/binpkgs/nonfree")
  [ ${#new[@]} -eq 0 ] || xbps-install -Sy "${repos[@]}" "${new[@]}"
  [ ${#upd[@]} -eq 0 ] || xbps-install -Syu "${repos[@]}" "${upd[@]}"
  [ ${#failed[@]} -eq 0 ] || warn "nicht gebaut: ${failed[*]} (Log oben; update-sources.sh holt neue Versionen)"

  # Discord mit Vencord (statt pkgs.discord.override { withVencord = true; }).
  # Discord lädt die eigentliche App beim ersten Start nach – erst danach
  # gibt es etwas zu patchen. Nach Discord-Updates erneut ausführen.
  if command -v discord >/dev/null; then
    local cli=$home/.cache/VencordInstallerCli-$vencord_version
    if [ ! -x "$cli" ]; then
      as_user curl -fsSL -o "$cli" \
        "https://github.com/Vendicated/VencordInstaller/releases/download/$vencord_version/VencordInstallerCli-Linux"
      if echo "$vencord_sha256  $cli" | sha256sum -c --quiet; then
        chmod +x "$cli"
      else
        rm -f "$cli"
        warn "Vencord-Installer: Prüfsumme falsch, nicht ausgeführt"
      fi
    fi
    # läuft als root und findet Discord des Benutzers über SUDO_USER
    if [ -x "$cli" ] && ! { SUDO_USER=$user "$cli" -install -branch stable || SUDO_USER=$user "$cli" -repair -branch stable; }; then
      warn "Vencord: Discord einmal starten, dann erneut: sudo setup.sh custom"
    fi
  fi

  # Spicetify schreibt in den Spotify-Ordner (spicetify-setup)
  if [ -d /usr/libexec/spotify ]; then
    chgrp -R users /usr/libexec/spotify
    chmod -R g+w /usr/libexec/spotify
  fi
}

# ── system ───────────────────────────────────────────────────────────────
# Dateien aus einem Overlay-Ordner nach / kopieren (Rechte bleiben)
overlay() {
  local src=$1 dst=$2 f rel
  while IFS= read -r -d '' f; do
    rel=${f#"$src"/}
    install -D -m "$(stat -c %a "$f")" "$f" "$dst/$rel"
  done < <(find "$src" -type f -print0)
}

# Befehle für den Benutzer: Links ins Repo (Änderungen wirken sofort)
user_commands=(
  mango-session screenshot screenshot-edit scratch-term clipboard-history
  screen-power session-logout novpn vpn vpn-split discord spicetify-setup
)

do_system() {
  step "Systemdateien (/etc, /usr/local)"
  overlay "$here/etc" /etc
  overlay "$here/usr" /usr
  # root-Hilfsprogramme kopieren statt verlinken: sie laufen als root bzw.
  # per sudo ohne Passwort und dürfen nicht im Home änderbar sein
  install -d /usr/local/sbin
  install -m 755 "$here"/sbin/* /usr/local/sbin/
  chmod 440 /etc/sudoers.d/g5
  visudo -cq -f /etc/sudoers.d/g5 || { rm -f /etc/sudoers.d/g5; warn "sudoers.d/g5 fehlerhaft – entfernt"; }

  install -d /usr/local/bin
  local c
  for c in "${user_commands[@]}"; do
    ln -sfn "$here/bin/$c" "/usr/local/bin/$c"
  done
  # dieselben Skripte wie unter NixOS
  ln -sfn "$repo/linux/nix/scripts/wm.sh" /usr/local/bin/wm
  ln -sfn "$repo/linux/nix/scripts/gaming-mode.sh" /usr/local/bin/gaming-mode
  ln -sfn "$repo/linux/nix/scripts/flatpak-nvidia-sync.sh" /usr/local/bin/flatpak-nvidia-sync
  ln -sfn "$repo/linux/.config/matugen/theme.sh" /usr/local/bin/theme
  ln -sfn "$here/update.sh" /usr/local/bin/update
  printf '#!/bin/sh\nexec bash %s "$@"\n' "$repo/linux/nix/scripts/sober-setup.sh" >/usr/local/bin/sober-setup
  chmod 755 /usr/local/bin/sober-setup

  # Firefox (Pywalfox): Native-Messaging-Host liest die Farben von matugen
  install -d /usr/local/libexec
  printf '#!/bin/sh\nexec %s/.local/bin/pywalfox start\n' "$home" >/usr/local/libexec/pywalfox-host
  chmod 755 /usr/local/libexec/pywalfox-host
  install -d /usr/lib/mozilla/native-messaging-hosts
  cat >/usr/lib/mozilla/native-messaging-hosts/pywalfox.json <<'JSON'
{
  "name": "pywalfox",
  "description": "Automatically theme your browser using the colors generated by Pywal",
  "path": "/usr/local/libexec/pywalfox-host",
  "type": "stdio",
  "allowed_extensions": ["pywalfox@frewacom.org"]
}
JSON

  step "Sprache, Zeit, Name"
  echo g5 >/etc/hostname
  ln -sfn /usr/share/zoneinfo/Europe/Berlin /etc/localtime
  sed -i -E 's/^#?(de_DE\.UTF-8 UTF-8)/\1/; s/^#?(en_US\.UTF-8 UTF-8)/\1/' /etc/default/libc-locales
  xbps-reconfigure -f glibc-locales >/dev/null
  echo LANG=de_DE.UTF-8 >/etc/locale.conf
  set_rc() { # rc.conf: Schlüssel setzen oder ersetzen
    if grep -qE "^#?$1=" /etc/rc.conf; then
      sed -i -E "s|^#?$1=.*|$1=$2|" /etc/rc.conf
    else
      echo "$1=$2" >>/etc/rc.conf
    fi
  }
  set_rc KEYMAP us
  set_rc HARDWARECLOCK '"UTC"'
  # cgroup v2: novpn (Split-Tunneling) braucht eine eigene cgroup
  set_rc CGROUP_MODE unified

  step "Benutzer $user"
  usermod -aG wheel,video,audio,input,kvm,users "$user"
  [ "$(getent passwd "$user" | cut -d: -f7)" = /usr/bin/fish ] || chsh -s /usr/bin/fish "$user"

  step "Dateisystem, Audio, Aussehen"
  # Keine Schreibzugriffe beim bloßen Lesen (configuration.nix: noatime)
  if awk '$2 == "/" && $4 !~ /noatime/ {found = 1} END {exit !found}' /etc/fstab; then
    cp /etc/fstab /etc/fstab.bak
    awk 'BEGIN {OFS = "\t"} $2 == "/" && $4 !~ /noatime/ {$4 = $4 ",noatime"} {print}' /etc/fstab.bak >/etc/fstab
    info "/etc/fstab: noatime für / (Sicherung: /etc/fstab.bak)"
  fi
  # PipeWire startet WirePlumber und den Pulse-Server selbst (Void-Handbuch)
  install -d /etc/pipewire/pipewire.conf.d
  ln -sfn /usr/share/examples/wireplumber/10-wireplumber.conf /etc/pipewire/pipewire.conf.d/
  ln -sfn /usr/share/examples/pipewire/20-pipewire-pulse.conf /etc/pipewire/pipewire.conf.d/
  # ALSA-Programme über PipeWire
  install -d /etc/alsa/conf.d
  ln -sfn /usr/share/alsa/alsa.conf.d/50-pipewire.conf /etc/alsa/conf.d/
  ln -sfn /usr/share/alsa/alsa.conf.d/99-pipewire-default.conf /etc/alsa/conf.d/
  command -v dconf >/dev/null && dconf update
  install -d -m 755 /var/lib/vpn-bypass
  touch /var/lib/vpn-bypass/domains

  step "Firewall und Kernel-Einstellungen sofort anwenden"
  /usr/local/sbin/g5-firewall on
  sysctl --quiet --system || true
  udevadm control --reload && udevadm trigger --subsystem-match=drm || true
}

# ── services ─────────────────────────────────────────────────────────────
services=(
  dbus elogind polkitd NetworkManager bluetoothd chronyd cronie
  socklog-unix nanoklogd power-profiles-daemon nvidia-powerd zramen
  greetd scx gigabyte-control-center g5-tuning
  vpn-bypass vpn-bypass-dst vpn-lock wg-quick-wg0 vpn-peer-info
)

do_services() {
  step "runit-Dienste"
  local d s
  for d in "$here"/sv/*/; do
    s=$(basename "$d")
    install -d "/etc/sv/$s"
    install -m 755 "$d"/* "/etc/sv/$s/"
  done
  for s in "${services[@]}"; do
    if [ ! -d "/etc/sv/$s" ]; then
      warn "Dienst $s fehlt (Paket nicht installiert?)"
      continue
    fi
    [ -e "/var/service/$s" ] || { ln -s "/etc/sv/$s" /var/service/; info "an: $s"; }
  done
  # NetworkManager übernimmt das Netz (WLAN-Daten neu eingeben: nmtui)
  for s in dhcpcd wpa_supplicant; do
    [ -e "/var/service/$s" ] && rm "/var/service/$s" && info "aus: $s"
  done
  return 0
}

# ── boot ─────────────────────────────────────────────────────────────────
do_boot() {
  step "Kernel-Parameter und Ladebildschirm"
  # Wie configuration.nix/performance.nix: ohne Textflut starten,
  # Watchdogs aus, Kernel unterbricht sofort (preempt=full wie CachyOS)
  local cmdline="loglevel=3 quiet splash udev.log_level=3 nowatchdog preempt=full nvidia-drm.modeset=1"
  sed -i -E "s|^#?GRUB_CMDLINE_LINUX_DEFAULT=.*|GRUB_CMDLINE_LINUX_DEFAULT=\"$cmdline\"|" /etc/default/grub
  # Boot-Menü 1 s; ältere Kernel unter „Erweiterte Optionen“ (Esc hält an)
  sed -i -E 's|^#?GRUB_TIMEOUT=.*|GRUB_TIMEOUT=1|' /etc/default/grub
  plymouth-set-default-theme bgrt 2>/dev/null || warn "Plymouth-Thema bgrt nicht gefunden"
  info "initramfs neu bauen (alle Kernel)…"
  dracut --regenerate-all --force >/dev/null
  update-grub
}

# ── user ─────────────────────────────────────────────────────────────────
# Configs aus linux/.config, die nach ~/.config verlinkt werden
# (dotfiles.nix; niri und hypr braucht es unter Void nicht)
linked=(
  nvim tmux ghostty fastfetch quickshell rofi mako matugen waypaper
  MangoHud sioyek mango gtklock swayidle
)
mizu_rev=426e89a4d05c038feaab4a2855351da8b6a4f5fa

do_user() {
  step "Dotfiles für $user verlinken"
  local name dst
  as_user mkdir -p "$home/.config" "$home/.local/share/applications" "$home/.local/bin"
  for name in "${linked[@]}"; do
    dst=$home/.config/$name
    if [ -d "$dst" ] && [ ! -L "$dst" ]; then
      warn "$dst ist ein echter Ordner – bleibt (erst löschen, dann setup.sh user)"
      continue
    fi
    as_user ln -sfn "$repo/linux/.config/$name" "$dst"
  done
  # Warp: Themes verlinkt, settings.toml nur als Startwert (Warp schreibt sie selbst)
  as_user mkdir -p "$home/.local/share/warp-terminal" "$home/.config/warp-terminal" "$home/.config/Vencord/themes"
  as_user ln -sfn "$repo/linux/.local/share/warp-terminal/themes" "$home/.local/share/warp-terminal/themes"
  [ -e "$home/.config/warp-terminal/settings.toml" ] ||
    as_user cp "$repo/linux/.config/warp-terminal/settings.toml" "$home/.config/warp-terminal/settings.toml"
  as_user xdg-user-dirs-update || true

  step "Programme ohne Void-Paket (pipx, cargo, Installer)"
  # Hintergrund-Auswahl und Firefox-Farben (Python, mit GTK/GObject vom System)
  [ -x "$home/.local/bin/waypaper" ] ||
    as_user pipx install --system-site-packages waypaper || warn "waypaper nicht installiert"
  [ -x "$home/.local/bin/pywalfox" ] ||
    as_user pipx install pywalfox || warn "pywalfox nicht installiert"
  # Claude Code (offizieller Installer, aktualisiert sich selbst)
  [ -x "$home/.local/bin/claude" ] ||
    as_user bash -c 'curl -fsSL https://claude.ai/install.sh | bash' || warn "Claude Code nicht installiert"
  # mizu (PDF-Viewer, github:notflask/mizu – derselbe Stand wie in flake.lock)
  if [ "$(as_user cat "$home/.cache/mizu.rev" 2>/dev/null)" != "$mizu_rev" ]; then
    if as_user cargo install --locked --root "$home/.local" \
      --git https://github.com/notflask/mizu --rev "$mizu_rev" mizu; then
      as_user sh -c "echo $mizu_rev >'$home/.cache/mizu.rev'"
      as_user tee "$home/.local/share/applications/io.github.notflask.Mizu.desktop" >/dev/null <<'DESKTOP'
[Desktop Entry]
Type=Application
Name=mizu
Comment=PDF- und EPUB-Viewer
Exec=mizu %f
Icon=application-pdf
MimeType=application/pdf;application/epub+zip;
Categories=Office;Viewer;
DESKTOP
    else
      warn "mizu nicht gebaut"
    fi
  fi

  step "Flatpak (Sober), Discord-Starter, Split-Tunneling"
  as_user flatpak remote-add --user --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
  # Discord über den Starter mit GPU-Wahl (linux/void/bin/discord)
  if [ -f /usr/share/applications/discord.desktop ]; then
    sed 's|^Exec=.*|Exec=/usr/local/bin/discord|' /usr/share/applications/discord.desktop |
      as_user tee "$home/.local/share/applications/discord.desktop" >/dev/null
  fi
  as_user vpn-split sync || true

  step "Spotify mit Spicetify"
  if command -v spotify >/dev/null && command -v spicetify >/dev/null; then
    as_user spicetify-setup || warn "Spicetify: einmal Spotify starten und anmelden, dann spicetify-setup"
  fi
}

# ── main ─────────────────────────────────────────────────────────────────
all=(repos packages custom system services boot user)
check
[ $# -gt 0 ] || set -- "${all[@]}"
for s in "$@"; do
  case $s in
    repos | packages | custom | system | services | boot | user) "do_$s" ;;
    *) echo "setup.sh: unbekannter Schritt: $s (${all[*]})" >&2; exit 2 ;;
  esac
done
step "Fertig. Nach der Erstinstallation: neu starten."
