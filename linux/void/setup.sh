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
#      boot       Kernel-Parameter, GRUB, initramfs
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
  # Void schreibt ID="void" (mit Anführungszeichen)
  grep -Eq '^ID="?void"?$' /etc/os-release 2>/dev/null || { echo "setup.sh: das ist kein Void Linux" >&2; exit 1; }
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
  # Nur ein Kernel (linux-mainline): `linux` aus base-system abwählen,
  # bevor xbps es bei einem Update wieder mitbringt
  install -D -m 644 "$here/etc/xbps.d/10-kernel.conf" /etc/xbps.d/10-kernel.conf
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
  ly adw-gtk3 apple-cursor font-jetbrains-mono font-minecraft font-apple-color-emoji
  spicetify-cli gigabyte-control-center claude-desktop atas-x haruneko tradingview
  warp-terminal
  discord spotify msttcorefonts
)
# Login-Animation: Planet mit Schwarzem Loch (ly-community, wie desktop.nix)
blackhole_url=https://codeberg.org/fairyglade/ly-community/raw/commit/fd85d8584545433520f34fb25584b17280f4c0b9/animations/dur/blackhole-smooth-240x67.dur
blackhole_sha256=c28dc5ccfb67802b20fdb4520d360742a2a7329e2f63e06d9b5e2f6a42444415
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
  power-menu term apply nvidia-offload
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
  ln -sfn "$repo/linux/nix/scripts/gpu-info.sh" /usr/local/bin/gpu-info
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

  step "Login: ly"
  # Wie unter NixOS (desktop.nix): Deutsch, Schwarzes Loch als Animation,
  # große Uhr, nur MangoWC als Sitzung (/etc/ly/sessions, startet
  # mango-session). Die übrigen Einstellungen bleiben die von ly.
  if [ -f /etc/ly/config.ini ]; then
    local dur=/etc/ly/blackhole.dur
    if ! echo "$blackhole_sha256  $dur" | sha256sum -c --quiet 2>/dev/null; then
      if curl -fsSL -o "$dur.tmp" "$blackhole_url" &&
        echo "$blackhole_sha256  $dur.tmp" | sha256sum -c --quiet; then
        mv "$dur.tmp" "$dur"
      else
        rm -f "$dur.tmp"
        warn "ly: Animation nicht geladen"
      fi
    fi
    set_ly() { # Schlüssel in /etc/ly/config.ini setzen (auch auskommentierte)
      sed -i -E "s|^#?[[:space:]]*$1[[:space:]]*=.*|$1 = $2|" /etc/ly/config.ini
      grep -qE "^$1 = " /etc/ly/config.ini || echo "$1 = $2" >>/etc/ly/config.ini
    }
    set_ly lang de
    set_ly animation dur_file
    set_ly dur_file_path "$dur"
    set_ly dur_offset_alignment center
    # Pflicht für die 256 Farben der Animation
    set_ly full_color true
    set_ly bigclock en
    set_ly clock "%a %d.%m.%Y %H:%M"
    set_ly waylandsessions /etc/ly/sessions
    set_ly xsessions /etc/ly/xsessions
    install -d /etc/ly/xsessions
    # ly schreibt das Sitzungs-Log nach ~/.local/state und bricht mit
    # „FileNotFound“ ab, wenn der Ordner fehlt (frischer Benutzer)
    as_user mkdir -p "$home/.local/state"
    install -d /etc/skel/.local/state
  else
    warn "ly ist nicht installiert (Schritt custom)"
  fi

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
  # gamemode: Prozess-Priorität und GPU/CPU-Helfer ohne Passwort
  groupadd -f gamemode
  usermod -aG wheel,video,audio,input,kvm,users,gamemode "$user"
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
  ly scx gigabyte-control-center g5-tuning
  vpn-bypass vpn-bypass-dst vpn-lock wg-quick-wg0 vpn-peer-info
)

do_services() {
  step "runit-Dienste"
  local d s
  for d in "$here"/sv/*/; do
    s=$(basename "$d")
    install -d "/etc/sv/$s"
    cp -rT "$d" "/etc/sv/$s"
    # Ausgabe ins Systemlog (socklog, `sudo svlogtail`) statt auf die Konsole
    if [ ! -e "/etc/sv/$s/log" ]; then
      install -d "/etc/sv/$s/log"
      printf '#!/bin/sh\nexec vlogger -t %s -p daemon\n' "$s" >"/etc/sv/$s/log/run"
    fi
    chmod 755 "/etc/sv/$s"/run "/etc/sv/$s"/log/run
    [ ! -e "/etc/sv/$s/finish" ] || chmod 755 "/etc/sv/$s/finish"
  done
  for s in "${services[@]}"; do
    if [ ! -d "/etc/sv/$s" ]; then
      warn "Dienst $s fehlt (Paket nicht installiert?)"
      continue
    fi
    [ -e "/var/service/$s" ] || { ln -s "/etc/sv/$s" /var/service/; info "an: $s"; }
  done
  # NetworkManager übernimmt das Netz (WLAN-Daten neu eingeben: nmtui),
  # ly läuft auf tty2 statt der Text-Anmeldung
  for s in dhcpcd wpa_supplicant agetty-tty2; do
    [ -e "/var/service/$s" ] && rm "/var/service/$s" && info "aus: $s"
  done
  return 0
}

# ── boot ─────────────────────────────────────────────────────────────────
do_boot() {
  step "Kernel: nur linux-mainline"
  # Der normale `linux` kommt vom Installer mit. Entfernt wird eine alte
  # Kernel-Serie aber erst, wenn sie nicht mehr läuft – also nach dem ersten
  # Start mit dem neuen Kernel. Das gilt auch, wenn linux-mainline später auf
  # eine neue Serie springt (7.2 → 7.3): Bis der neue Kernel einmal gestartet
  # ist, bleibt der alte im Boot-Menü als Rückfall.
  local main running p series
  main=$(xbps-query -p run_depends linux-mainline 2>/dev/null | grep -oE '^linux[0-9]+\.[0-9]+' | head -n1)
  running=linux$(uname -r | cut -d. -f1,2)
  if [ -n "$main" ]; then
    for p in linux linux-headers; do
      xbps-query "$p" >/dev/null 2>&1 && xbps-remove -y "$p"
    done
    for p in $(xbps-query -l | awk '{print $2}' | sed -E 's/-[^-]+$//' | grep -E '^linux[0-9]+\.[0-9]+(-headers)?$'); do
      series=${p%-headers}
      [ "$series" = "$main" ] && continue
      if [ "$series" = "$running" ]; then
        info "$p läuft gerade – wird nach dem Neustart entfernt (setup.sh boot bzw. update)"
        continue
      fi
      xbps-remove -y "$p"
    done
  else
    warn "linux-mainline ist nicht installiert (Schritt packages)"
  fi

  step "Kernel-Parameter und GRUB"
  # Wie configuration.nix/performance.nix: ohne Textflut starten (ohne
  # Plymouth: runit beendet es nicht, ly wartete dann minutenlang auf sein TTY),
  # Watchdogs aus, Kernel unterbricht sofort (preempt=full wie CachyOS)
  local cmdline="loglevel=3 quiet udev.log_level=3 nowatchdog preempt=full nvidia-drm.modeset=1"
  # TTY und ly in den Farben von Vague (theme.nix: console.colors)
  cmdline="$cmdline vt.default_red=0x14,0xd8,0x7f,0xf3,0x6e,0xbb,0xae,0xcd,0x60,0xe0,0x99,0xf5,0x8b,0xc9,0xbe,0xd7 vt.default_grn=0x14,0x64,0xa5,0xbe,0x94,0x9d,0xae,0xcd,0x60,0x83,0xb7,0xcb,0xa9,0xb1,0xbe,0xd7 vt.default_blu=0x15,0x7e,0x63,0x7c,0xb2,0xbd,0xd1,0xcd,0x79,0x98,0x82,0x96,0xc1,0xca,0xda,0xd7"
  sed -i -E "s|^#?GRUB_CMDLINE_LINUX_DEFAULT=.*|GRUB_CMDLINE_LINUX_DEFAULT=\"$cmdline\"|" /etc/default/grub
  # Dual-Boot mit NixOS (DUALBOOT.md): Liegt systemd-boot von NixOS auf der
  # gemeinsamen EFI-Partition, startet GRUB es über einen eigenen Eintrag,
  # und das Menü wartet 5 s. Ist NixOS entfernt, verschwindet beides wieder.
  local esp="" timeout=1
  for d in /boot/efi /efi /boot; do
    [ -f "$d/EFI/systemd/systemd-bootx64.efi" ] && { esp=$d; break; }
  done
  if [ -n "$esp" ]; then
    cat >/etc/grub.d/41_nixos <<'GRUB'
#!/bin/sh
# Erzeugt von linux/void/setup.sh (Dual-Boot) – NixOS über systemd-boot
cat <<'ENTRY'
menuentry "NixOS" --class nixos {
	insmod part_gpt
	insmod fat
	insmod chain
	search --no-floppy --file --set=root /EFI/systemd/systemd-bootx64.efi
	chainloader /EFI/systemd/systemd-bootx64.efi
}
ENTRY
GRUB
    chmod 755 /etc/grub.d/41_nixos
    timeout=5
    info "NixOS gefunden ($esp/EFI/systemd) – Eintrag im Boot-Menü"
  else
    rm -f /etc/grub.d/41_nixos
  fi
  # Boot-Menü 1 s (Esc hält an), mit NixOS 5 s; ein noch nicht entfernter
  # alter Kernel steht unter „Erweiterte Optionen“
  sed -i -E "s|^#?GRUB_TIMEOUT=.*|GRUB_TIMEOUT=$timeout|" /etc/default/grub
  if xbps-query plymouth >/dev/null 2>&1; then
    xbps-remove -Ry plymouth || warn "Plymouth ließ sich nicht entfernen"
  fi
  info "initramfs neu bauen (alle Kernel)…"
  dracut --regenerate-all --force >/dev/null
  update-grub
}

# ── user ─────────────────────────────────────────────────────────────────
# Configs aus linux/.config, die nach ~/.config verlinkt werden
# (dotfiles.nix; niri und hypr braucht es unter Void nicht)
linked=(
  nvim tmux ghostty quickshell rofi mako matugen waypaper
  MangoHud sioyek mango gtklock swayidle
)
mizu_rev=426e89a4d05c038feaab4a2855351da8b6a4f5fa
# GE-Proton: dieselbe Version wie proton-ge-bin in nixpkgs
proton_ge=GE-Proton11-7
proton_ge_sha256=c5448b76a230384e2d7bc6beb5ccb97bafb7e2c3b6c527cb03a1a546bbcb00a0

do_user() {
  step "Dotfiles für $user verlinken"
  local name dst d
  # Was root hier angelegt hat (z. B. ein Programm unter sudo), gehört dem
  # Benutzer – sonst scheitern die Links mit „Keine Berechtigung“
  for d in .config .local .cache; do
    [ -e "$home/$d" ] && find "$home/$d" -xdev -user root -exec chown -h "$user:$user" {} +
  done
  as_user mkdir -p "$home/.config" "$home/.local/share/applications" "$home/.local/bin"
  for name in "${linked[@]}"; do
    dst=$home/.config/$name
    if [ -d "$dst" ] && [ ! -L "$dst" ]; then
      warn "$dst ist ein echter Ordner – bleibt (erst löschen, dann setup.sh user)"
      continue
    fi
    as_user ln -sfn "$repo/linux/.config/$name" "$dst"
  done
  # fastfetch: eigene Config mit großem Void-Logo (config.jsonc ist die von
  # NixOS) – ein Ordner mit Link statt Link auf den ganzen Ordner
  [ -L "$home/.config/fastfetch" ] && as_user rm "$home/.config/fastfetch"
  as_user mkdir -p "$home/.config/fastfetch"
  as_user ln -sfn "$repo/linux/.config/fastfetch/void.jsonc" "$home/.config/fastfetch/config.jsonc"
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

  step "GE-Proton (in Steam unter Kompatibilität wählbar, wie gaming.nix)"
  local compat=$home/.local/share/Steam/compatibilitytools.d
  if [ ! -d "$compat/$proton_ge-x86_64" ]; then
    local tgz=$home/.cache/$proton_ge-x86_64.tar.gz
    as_user mkdir -p "$compat"
    if as_user curl -fsSL -o "$tgz" \
      "https://github.com/GloriousEggroll/proton-ge-custom/releases/download/$proton_ge/$proton_ge-x86_64.tar.gz" &&
      echo "$proton_ge_sha256  $tgz" | sha256sum -c --quiet; then
      as_user tar -xzf "$tgz" -C "$compat"
    else
      warn "GE-Proton nicht geladen"
    fi
    rm -f "$tgz"
  fi

  step "Flatpak (Sober), Discord-Starter, Split-Tunneling"
  as_user flatpak remote-add --user --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
  # Ghostty aus Menüs/Rofi ebenfalls im Stil von Void (linux/void/bin/term)
  if [ -f /usr/share/applications/com.mitchellh.ghostty.desktop ]; then
    sed 's|^Exec=ghostty|Exec=/usr/local/bin/term|' /usr/share/applications/com.mitchellh.ghostty.desktop |
      as_user tee "$home/.local/share/applications/com.mitchellh.ghostty.desktop" >/dev/null
  fi
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
