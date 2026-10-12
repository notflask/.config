#!/usr/bin/env bash
# ============================================================
#  install.sh – Arch Linux auf dem G5 (i5-12500H, Iris Xe + RTX 4060) einrichten
#  bzw. auf den Stand im Repo bringen.
#
#  Zwei Stile (Befehl `style minimal|glass`, Vorgabe minimal):
#  minimal (eckig, flach) und glass (Liquid Glass).
#
#  Voraussetzung: archinstall mit Limine, btrfs (Standard-Subvolumes),
#  Kernel linux-zen, NetworkManager, Benutzer flask (sudo), ohne Desktop.
#  Repo unter ~/dotfiles. Als NORMALER Benutzer starten (nicht root):
#
#    ~/dotfiles/linux/arch/install.sh               alle Schritte
#    ~/dotfiles/linux/arch/install.sh SCHRITT ...   nur diese Schritte
#
#      repos      pacman.conf (multilib, parallel), System aktualisieren
#      packages   Pakete aus packages.txt und packages-aur.txt (paru)
#      system     /etc, Skripte, Sprache, Benutzer, Schriften, Cursor
#      boot       initramfs (Plymouth), Limine, Kernel-Parameter, Snapper
#      services   systemd-Dienste einschalten
#      user       Dotfiles verlinken, Sitzung (UWSM), Programme ohne Paket
#      network    NetworkManager-Umstellung (zuletzt: kappt kurz das Netz)
#
#  Jeder Schritt darf beliebig oft laufen.
# ============================================================

set -euo pipefail

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
repo=$(cd "$here/../.." && pwd)
user=$(id -un)
home=$HOME
FAILED=()

step() { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }
info() { printf '    %s\n' "$*"; }
warn() { printf '\033[1;33m    %s\033[0m\n' "$*" >&2; }
list() { sed 's/#.*//' "$1" | tr -s ' \t' '\n' | grep -v '^$'; }
sdo() { sudo "$@"; }

check() {
  [ "$(id -u)" -ne 0 ] || { echo "install.sh: als normaler Benutzer starten (nicht root, nicht sudo)" >&2; exit 1; }
  [ -e /etc/arch-release ] || { echo "install.sh: das ist kein Arch Linux" >&2; exit 1; }
  [ "$repo" = "$home/dotfiles" ] || warn "Repo liegt in $repo statt $home/dotfiles – Links zeigen dorthin"
  ping -c1 -W3 archlinux.org >/dev/null 2>&1 || { echo "install.sh: kein Internet" >&2; exit 1; }
  sudo -v
  # sudo-Zeitstempel während des Laufs frisch halten (AUR-Builds dauern)
  (while kill -0 $$ 2>/dev/null; do sudo -n true 2>/dev/null; sleep 50; done) &
}

# Dateien aus einem Overlay-Ordner nach / kopieren (Rechte bleiben)
overlay() {
  local src=$1 dst=$2 f rel
  while IFS= read -r -d '' f; do
    rel=${f#"$src"/}
    sdo install -D -m "$(stat -c %a "$f")" "$f" "$dst/$rel"
  done < <(find "$src" -type f -print0)
}

have() { command -v "$1" >/dev/null 2>&1; }

# Pakete: erst gesammelt (schnell), bei Fehler einzeln; was pacman nicht kennt, holt paru
pkg_install() {
  local p
  sdo pacman -S --needed --noconfirm "$@" && return 0
  warn "Sammelinstallation fehlgeschlagen – einzeln, danach über paru"
  for p in "$@"; do
    pacman -Qq "$p" >/dev/null 2>&1 && continue
    sdo pacman -S --needed --noconfirm "$p" >/dev/null 2>&1 && continue
    if have paru && paru -S --needed --noconfirm --skipreview "$p"; then continue; fi
    FAILED+=("$p")
  done
}

aur_install() {
  local p
  have paru || { warn "paru fehlt"; FAILED+=("$@"); return 0; }
  paru -S --needed --noconfirm --skipreview "$@" && return 0
  warn "AUR-Sammelinstallation fehlgeschlagen – einzeln"
  for p in "$@"; do
    pacman -Qq "$p" >/dev/null 2>&1 && continue
    paru -S --needed --noconfirm --skipreview "$p" || FAILED+=("$p")
  done
}

# Download mit SHA-256-Prüfung: fetch URL ZIEL SHA256
fetch() {
  local url=$1 out=$2 sha=${3:-}
  curl -fsSL --retry 3 --connect-timeout 20 -o "$out" "$url" || return 1
  [ -z "$sha" ] || echo "$sha  $out" | sha256sum -c --quiet
}

# ── repos ────────────────────────────────────────────────────────────────
do_repos() {
  step "pacman: multilib, parallele Downloads, System aktualisieren"
  sdo sed -i -E 's/^#(ParallelDownloads).*/\1 = 10/; s/^#(Color)$/\1/' /etc/pacman.conf
  if ! grep -q '^\[multilib\]' /etc/pacman.conf; then
    sdo sed -i -E '/^#\[multilib\]$/,/^#Include/ s/^#//' /etc/pacman.conf
  fi
  grep -q '^\[multilib\]' /etc/pacman.conf || warn "multilib ließ sich nicht einschalten – /etc/pacman.conf prüfen"
  sdo pacman -Syu --noconfirm
}

# ── packages ─────────────────────────────────────────────────────────────
do_packages() {
  step "paru (AUR-Helfer)"
  # Aus dem Quelltext statt paru-bin: paru-bin ist gegen eine feste libalpm
  # gebaut und startet nach einem pacman-Update nicht mehr („libalpm.so.15:
  # cannot open shared object file“). Darum prüfen, ob paru wirklich läuft.
  if ! paru --version >/dev/null 2>&1; then
    sdo pacman -S --needed --noconfirm base-devel git rust
    # paru-bin samt Debug-Paket weg (sonst Dateikonflikt mit paru-debug)
    local old_paru
    old_paru=$(pacman -Qq paru-bin paru-bin-debug 2>/dev/null) || true
    [ -z "$old_paru" ] || sdo pacman -Rdd --noconfirm $old_paru
    local tmp
    tmp=$(mktemp -d)
    git clone --depth 1 https://aur.archlinux.org/paru.git "$tmp/paru"
    (cd "$tmp/paru" && makepkg -si --noconfirm)
    rm -rf "$tmp"
  fi

  step "Pakete aus packages.txt"
  mapfile -t pkgs < <(list "$here/packages.txt")
  pkg_install "${pkgs[@]}"

  step "AUR-Pakete aus packages-aur.txt"
  mapfile -t aur < <(list "$here/packages-aur.txt")
  aur_install "${aur[@]}"
}

# ── system ───────────────────────────────────────────────────────────────
blackhole_url=https://codeberg.org/fairyglade/ly-community/raw/commit/fd85d8584545433520f34fb25584b17280f4c0b9/animations/dur/blackhole-smooth-240x67.dur
blackhole_sha256=c28dc5ccfb67802b20fdb4520d360742a2a7329e2f63e06d9b5e2f6a42444415
gbcc_commit=d0dc074726ba410bf70b06c77ec5acf16843c1ed

do_system() {
  step "Systemdateien (/etc, /usr/local)"
  overlay "$here/files/etc" /etc
  overlay "$here/files/usr" /usr
  sdo chmod 440 /etc/sudoers.d/g5
  sdo visudo -cq -f /etc/sudoers.d/g5 || { sdo rm -f /etc/sudoers.d/g5; warn "sudoers.d/g5 fehlerhaft – entfernt"; }

  # root-Hilfsprogramme kopieren statt verlinken (laufen als root bzw. per sudo ohne Passwort)
  sdo install -d /usr/local/sbin /usr/local/libexec
  sdo install -m 755 "$here"/files/sbin/* /usr/local/sbin/
  sdo install -m 755 "$here/files/libexec/g5-tuning" "$here/files/libexec/vpn-peer-info" /usr/local/libexec/
  sdo install -D -m 755 "$here/files/sleep/g5-tuning" /usr/lib/systemd/system-sleep/g5-tuning
  sdo install -d -m 755 /var/lib/vpn-bypass
  sdo touch /var/lib/vpn-bypass/domains

  # Befehle für den Benutzer: Links ins Repo (Änderungen wirken sofort)
  sdo install -d /usr/local/bin
  local c
  for c in "$here"/files/bin/*; do
    sdo ln -sfn "$c" "/usr/local/bin/$(basename "$c")"
  done
  sdo ln -sfn "$here/scripts/wm.sh" /usr/local/bin/wm
  sdo ln -sfn "$here/scripts/gaming-mode.sh" /usr/local/bin/gaming-mode
  sdo ln -sfn "$here/scripts/flatpak-nvidia-sync.sh" /usr/local/bin/flatpak-nvidia-sync
  sdo ln -sfn "$repo/linux/.config/matugen/theme.sh" /usr/local/bin/theme
  sdo ln -sfn "$here/scripts/gpu-info.sh" /usr/local/bin/gpu-info
  printf '#!/bin/sh\nexec bash %s "$@"\n' "$here/scripts/sober-setup.sh" | sdo tee /usr/local/bin/sober-setup >/dev/null
  sdo chmod 755 /usr/local/bin/sober-setup
  sdo install -d -m 755 /etc/wireguard

  step "Sprache, Zeit, Name"
  sdo sed -i -E 's/^#?(de_DE\.UTF-8 UTF-8)/\1/; s/^#?(en_US\.UTF-8 UTF-8)/\1/' /etc/locale.gen
  sdo locale-gen >/dev/null
  echo LANG=de_DE.UTF-8 | sdo tee /etc/locale.conf >/dev/null
  echo KEYMAP=us | sdo tee /etc/vconsole.conf >/dev/null
  sdo hostnamectl set-hostname g5
  sdo timedatectl set-timezone Europe/Berlin
  sdo timedatectl set-ntp true || true

  step "Benutzer $user"
  sdo groupadd -f gamemode
  getent group realtime >/dev/null || sdo groupadd -r realtime
  sdo usermod -aG wheel,video,audio,input,kvm,users,gamemode,realtime "$user"
  [ "$(getent passwd "$user" | cut -d: -f7)" = /usr/bin/fish ] || sdo chsh -s /usr/bin/fish "$user"

  step "Dateisystem: noatime für /"
  if awk '$2 == "/" && $4 !~ /noatime/ {found = 1} END {exit !found}' /etc/fstab; then
    sdo cp /etc/fstab /etc/fstab.bak
    sdo sed -i -E '/^[^#].*[[:space:]]\/[[:space:]]/ { s/relatime/noatime/; /noatime/! s/([[:space:]]\/[[:space:]]+[a-z0-9]+[[:space:]]+)([^[:space:]]+)/\1\2,noatime/ }' /etc/fstab
    info "/etc/fstab: noatime für / (Sicherung: /etc/fstab.bak)"
  fi

  step "Login: ly (Deutsch, Schwarzes Loch, Hyprland)"
  if [ -f /etc/ly/config.ini ]; then
    local dur=/etc/ly/blackhole.dur tmp
    if ! echo "$blackhole_sha256  $dur" | sha256sum -c --quiet 2>/dev/null; then
      tmp=$(mktemp)
      if fetch "$blackhole_url" "$tmp" "$blackhole_sha256"; then sdo install -m 644 "$tmp" "$dur"; else warn "ly: Animation nicht geladen"; fi
      rm -f "$tmp"
    fi
    set_ly() { # Schlüssel in /etc/ly/config.ini setzen (auch auskommentierte)
      sdo sed -i -E "s|^#?[[:space:]]*$1[[:space:]]*=.*|$1 = $2|" /etc/ly/config.ini
      grep -qE "^$1 = " /etc/ly/config.ini || echo "$1 = $2" | sdo tee -a /etc/ly/config.ini >/dev/null
    }
    set_ly lang de
    set_ly animation dur_file
    set_ly dur_file_path "$dur"
    set_ly dur_offset_alignment center
    set_ly full_color true # Pflicht für die 256 Farben der Animation
    set_ly bigclock en
    set_ly clock "%a %d.%m.%Y %H:%M"
    set_ly waylandsessions /etc/ly/sessions
    set_ly xsessions /etc/ly/xsessions
    sdo install -d /etc/ly/xsessions
  else
    warn "ly ist nicht installiert (Schritt packages)"
  fi

  step "Schriften ohne Paket: Apple-Emoji, Minecraftia, Monocraft; Cursor macOS"
  local fdir=/usr/local/share/fonts/g5 tmp
  sdo install -d "$fdir"
  tmp=$(mktemp -d)
  [ -e "$fdir/AppleColorEmoji-Linux.ttf" ] || {
    fetch "https://github.com/samuelngs/apple-emoji-ttf/releases/download/macos-26-20260722-484daf4e/AppleColorEmoji-Linux.ttf" \
      "$tmp/emoji.ttf" e37c7af6265ac4a0af6d57bc65e86109a776d9966e8343334557f63da482516f &&
      sdo install -m 644 "$tmp/emoji.ttf" "$fdir/AppleColorEmoji-Linux.ttf" || warn "Apple-Emoji nicht geladen"; }
  [ -e "$fdir/Monocraft.ttf" ] || {
    fetch "https://github.com/IdreesInc/Monocraft/releases/download/v4.2.1/Monocraft-ttf.zip" "$tmp/mono.zip" \
      897faffbef8cc27fadd0d5aa51872ab5f908e22a89bb8fa5b191366025d503e0 &&
      unzip -qjo "$tmp/mono.zip" '*.ttf' -d "$tmp/mono" && sdo install -m 644 "$tmp"/mono/*.ttf "$fdir/" || warn "Monocraft nicht geladen"; }
  [ -e "$fdir/minecraftia.ttf" ] || {
    fetch "https://fontlibrary.org/assets/downloads/minecraftia/71962a7e3d4a70435c030466a12f1d63/minecraftia.zip" "$tmp/mc.zip" &&
      unzip -qjo "$tmp/mc.zip" '*.ttf' -d "$tmp/mc" && sdo install -m 644 "$tmp"/mc/*.ttf "$fdir/" || warn "Minecraftia nicht geladen"; }
  if [ ! -d /usr/share/icons/macOS ]; then
    fetch "https://github.com/ful1e5/apple_cursor/releases/download/v2.0.1/macOS.tar.xz" "$tmp/cur.tar.xz" \
      9c6e5e13b068ce51a9e90a9abd6ce232ec7d25d4ceb05aa8ac76efbb99c76762 &&
      sdo tar -xJf "$tmp/cur.tar.xz" -C /usr/share/icons || warn "macOS-Cursor nicht geladen"
  fi
  rm -rf "$tmp"
  sdo fc-cache -f >/dev/null
  have dconf && sdo dconf update

  step "Gigabyte Control Center (aus dem Quelltext)"
  if [ "$(cat /var/lib/g5-gbcc.rev 2>/dev/null)" != "$gbcc_commit" ]; then
    tmp=$(mktemp -d)
    if (cd "$tmp" && git init -q && git fetch -q --depth 1 https://github.com/notflask/gigabyte-control-center.git "$gbcc_commit" &&
      git checkout -q FETCH_HEAD && python -m build --wheel --no-isolation >/dev/null &&
      sdo python -m installer --prefix /usr dist/*.whl &&
      sdo install -Dm644 gigabyte-control-center.desktop /usr/share/applications/gigabyte-control-center.desktop &&
      sed 's/#000000/#8e939e/' gbcc/data/gbcc.svg | sdo tee /usr/share/icons/hicolor/scalable/apps/gigabyte-control-center.svg >/dev/null &&
      sdo install -d /usr/share/icons/hicolor/symbolic/apps &&
      sed 's/#000000/#2e3436/' gbcc/data/gbcc.svg | sdo tee /usr/share/icons/hicolor/symbolic/apps/gigabyte-control-center-symbolic.svg >/dev/null); then
      echo "$gbcc_commit" | sdo tee /var/lib/g5-gbcc.rev >/dev/null
    else
      warn "Gigabyte Control Center nicht gebaut"; FAILED+=(gigabyte-control-center)
    fi
    rm -rf "$tmp"
  fi

  do_plugins

  step "Firewall und Kernel-Einstellungen sofort anwenden"
  sdo sysctl --quiet --system || true
  sdo udevadm control --reload && sdo udevadm trigger --subsystem-match=drm || true
  sdo /usr/local/sbin/vencord-patch || true
  [ -d /opt/spotify ] && { sdo chmod a+wr /opt/spotify; sdo chmod -R a+wr /opt/spotify/Apps; }
  have gamescope && sdo setcap cap_sys_nice+ep /usr/bin/gamescope || true
}

# ── plugins ──────────────────────────────────────────────────────────────
# hyprtasking (Übersicht, Super+O im Glas-Stil) direkt von raybbian bauen:
# Das AUR-Paket ist ein veralteter Fork und baut nicht mehr. Ein Plugin muss
# genau zur installierten Hyprland-Version passen – hyprpm.toml im Repo nennt
# dafür je Version den passenden Commit. `update` ruft diesen Schritt nach
# jedem Update auf; gebaut wird nur, wenn sich Hyprland geändert hat.
hyprtasking_repo=https://github.com/raybbian/hyprtasking.git

do_plugins() {
  step "Hyprland-Übersicht (hyprtasking) für die installierte Hyprland-Version"
  local hv tmp commit
  hv=$(pacman -Q hyprland 2>/dev/null | awk '{print $2}' | cut -d- -f1) || true
  [ -n "$hv" ] || { warn "Hyprland nicht installiert"; return 0; }
  if [ "$(cat /var/lib/g5-hyprtasking.ver 2>/dev/null)" = "$hv" ] && [ -e /etc/hyprland/plugins/libhyprtasking.so ]; then
    info "passt schon zu Hyprland $hv"
    return 0
  fi
  sdo pacman -S --needed --noconfirm meson ninja cmake >/dev/null
  tmp=$(mktemp -d)
  if git clone -q "$hyprtasking_repo" "$tmp/ht"; then
    commit=$(awk -v v="#v$hv" '{ sub(/[ \t]+$/, "") } substr($0, length($0) - length(v) + 1) == v {print; exit}' "$tmp/ht/hyprpm.toml" | grep -oE '"[0-9a-f]{40}"' | tail -1 | tr -d '"') || true
    [ -n "$commit" ] && git -C "$tmp/ht" checkout -q "$commit" || info "kein fester Stand für Hyprland $hv – nehme den neuesten"
    if (cd "$tmp/ht" && meson setup build --buildtype=release >/dev/null && meson compile -C build >/dev/null); then
      sdo install -Dm755 "$tmp/ht/build/libhyprtasking.so" /etc/hyprland/plugins/libhyprtasking.so
      echo "$hv" | sdo tee /var/lib/g5-hyprtasking.ver >/dev/null
      info "gebaut für Hyprland $hv"
    else
      warn "hyprtasking nicht gebaut – Super+O (Übersicht) geht im Glas-Stil nicht"; FAILED+=(hyprtasking)
    fi
  else
    warn "hyprtasking: Quelltext nicht geladen"; FAILED+=(hyprtasking)
  fi
  rm -rf "$tmp"
}

# ── boot ─────────────────────────────────────────────────────────────────
vt_colors="vt.default_red=0x14,0xd8,0x7f,0xf3,0x6e,0xbb,0xae,0xcd,0x60,0xe0,0x99,0xf5,0x8b,0xc9,0xbe,0xd7 vt.default_grn=0x14,0x64,0xa5,0xbe,0x94,0x9d,0xae,0xcd,0x60,0x83,0xb7,0xcb,0xa9,0xb1,0xbe,0xd7 vt.default_blu=0x15,0x7e,0x63,0x7c,0xb2,0xbd,0xd1,0xcd,0x79,0x98,0x82,0x96,0xc1,0xca,0xda,0xd7"

do_boot() {
  step "initramfs mit Plymouth (Thema bgrt)"
  if [ ! -d /usr/share/plymouth/themes/bgrt ]; then
    warn "Plymouth-Thema bgrt fehlt – nehme spinner"
    sdo sed -i 's/^Theme=.*/Theme=spinner/' /etc/plymouth/plymouthd.conf
  fi
  sdo mkinitcpio -P

  step "Kernel-Parameter und Limine"
  # Wurzel- und Verschlüsselungs-Parameter von archinstall übernehmen, den Rest setzen wir
  local base="" tok extras
  for tok in $(cat /proc/cmdline); do
    case $tok in
      root=* | rootflags=* | rootfstype=* | rw | resume=* | cryptdevice=* | rd.luks* | luks.*) base="$base $tok" ;;
    esac
  done
  [[ $base == *" rw"* ]] || base="$base rw"
  # ohne Textflut (Plymouth), Watchdogs aus,
  # Kernel unterbricht sofort (preempt=full wie CachyOS), zram statt zswap
  extras="quiet splash loglevel=3 udev.log_level=3 rd.udev.log_level=3 systemd.show_status=auto"
  extras="$extras nowatchdog preempt=full nvidia-drm.modeset=1 zswap.enabled=0 $vt_colors"
  local esp="" d
  for d in /boot /efi /boot/efi; do
    [ "$(findmnt -no FSTYPE "$d" 2>/dev/null)" = vfat ] && { esp=$d; break; }
  done
  [ -n "$esp" ] || { warn "EFI-Partition nicht gefunden – Limine-Schritt übersprungen"; return 0; }

  if ! have limine-update; then
    warn "limine-mkinitcpio-hook fehlt (Schritt packages) – Parameter bitte von Hand in $esp/limine.conf eintragen:"
    info "$base $extras"
    return 0
  fi
  local cfg=/etc/default/limine
  sdo touch $cfg
  sdo sed -i '/^# >>> g5$/,/^# <<< g5$/d' $cfg
  sdo tee -a $cfg >/dev/null <<EOF
# >>> g5 (von linux/arch/install.sh)
ESP_PATH="$esp"
TARGET_OS_NAME="Arch Linux"
ENABLE_LIMINE_FALLBACK=yes
MAX_SNAPSHOT_ENTRIES=10
KERNEL_CMDLINE[default]="${base# } $extras"
# <<< g5
EOF
  if sdo limine-update; then
    # Eine ältere limine.conf von archinstall an anderer Stelle würde die neue überstimmen
    if [ -f "$esp/limine.conf" ] && grep -q 'splash' "$esp/limine.conf"; then
      local f bak=/root/limine-conf-backup
      sdo install -d $bak
      while IFS= read -r -d '' f; do
        [ "$f" = "$esp/limine.conf" ] && continue
        sdo mv "$f" "$bak/$(echo "$f" | tr / _)" && info "alte Limine-Config nach $bak verschoben: $f"
      done < <(sudo find "$esp" -iname limine.conf -print0)
    else
      warn "limine-update hat $esp/limine.conf nicht wie erwartet geschrieben – bitte prüfen, bevor du neu startest"
    fi
  else
    warn "limine-update fehlgeschlagen – bestehende Limine-Config bleibt unverändert"
  fi

  step "Snapshots (btrfs + snapper + Limine-Menü)"
  if [ "$(findmnt -no FSTYPE /)" = btrfs ] && have snapper; then
    if ! sdo snapper list-configs | grep -q '^root '; then
      sdo umount /.snapshots 2>/dev/null || true
      sdo rmdir /.snapshots 2>/dev/null || true
      sdo snapper -c root create-config /
    fi
    # nur Vorher/Nachher-Snapshots von snap-pac, keine stündlichen
    sdo snapper -c root set-config TIMELINE_CREATE=no NUMBER_LIMIT=10 NUMBER_LIMIT_IMPORTANT=5
  else
    info "Root ist nicht btrfs oder snapper fehlt – ohne Snapshots"
  fi
}

# ── services ─────────────────────────────────────────────────────────────
do_services() {
  step "systemd-Dienste"
  local s
  for s in NetworkManager bluetooth power-profiles-daemon upower fstrim.timer systemd-timesyncd \
    nvidia-persistenced nvidia-powerd nvidia-suspend nvidia-resume nvidia-hibernate \
    g5-firewall vpn-bypass vpn-bypass-dst.timer vpn-lock vpn-peer-info gigabyte-control-center g5-tuning \
    ananicy-cpp snapper-cleanup.timer limine-snapper-sync; do
    sdo systemctl enable "$s" >/dev/null 2>&1 && info "an: $s" || info "übersprungen: $s (nicht vorhanden)"
  done
  # Login: ly (Dienstname je nach Paketversion)
  if [ -e /usr/lib/systemd/system/ly@.service ]; then
    sdo systemctl disable getty@tty2.service >/dev/null 2>&1 || true
    sdo systemctl enable ly@tty2.service
  elif [ -e /usr/lib/systemd/system/ly.service ]; then
    sdo systemctl disable getty@tty2.service >/dev/null 2>&1 || true
    sdo systemctl enable ly.service
  else
    warn "ly-Dienst nicht gefunden"
  fi
  # Benutzerdienste der Sitzung
  sdo install -d /etc/systemd/user/graphical-session.target.wants
  for s in polkit-agent swayidle cameractrlsd flatpak-nvidia-sync matugen-first-run; do
    sdo ln -sfn "/etc/systemd/user/$s.service" "/etc/systemd/user/graphical-session.target.wants/$s.service"
  done
  # mako startet `wm autostart` je nach Stil – kein Dienst, sonst käme immer dieselbe Config
  # Ab jetzt regeln NetworkManager+openresolv das Netz (Schritt network)
  sdo systemctl disable systemd-networkd.service systemd-networkd.socket systemd-resolved.service >/dev/null 2>&1 || true
}

# ── user ─────────────────────────────────────────────────────────────────
linked=(nvim tmux ghostty quickshell rofi mako matugen waypaper hypr MangoHud sioyek gtklock swayidle)
mizu_rev=426e89a4d05c038feaab4a2855351da8b6a4f5fa
opal_rev=abd7ace2de249e5539e5c49c712ae1a82e158595

do_user() {
  step "Dotfiles für $user verlinken"
  local name dst
  mkdir -p "$home/.config" "$home/.local/share/applications" "$home/.local/bin"
  for name in "${linked[@]}"; do
    dst=$home/.config/$name
    if [ -d "$dst" ] && [ ! -L "$dst" ]; then
      warn "$dst ist ein echter Ordner – bleibt (erst löschen, dann install.sh user)"
      continue
    fi
    ln -sfn "$repo/linux/.config/$name" "$dst"
  done
  mkdir -p "$home/.local/share/warp-terminal" "$home/.config/warp-terminal" "$home/.config/Vencord/themes"
  ln -sfn "$repo/linux/.local/share/warp-terminal/themes" "$home/.local/share/warp-terminal/themes"
  [ -e "$home/.config/warp-terminal/settings.toml" ] ||
    cp "$repo/linux/.config/warp-terminal/settings.toml" "$home/.config/warp-terminal/settings.toml"
  xdg-user-dirs-update || true
  mkdir -p "$home/Wallpapers"
  cp -n "$here"/wallpapers/* "$home/Wallpapers/" 2>/dev/null || true

  step "Sitzung: UWSM-Umgebung"
  mkdir -p "$home/.config/uwsm"
  cat >"$home/.config/uwsm/env" <<'EOF'
# Umgebung der Sitzung (UWSM)
export PATH="$HOME/.local/bin:$PATH"
# Videodekodierung (Firefox) auf derselben GPU wie der Desktop
export LIBVA_DRIVER_NAME=nvidia
export NVD_BACKEND=direct
export MOZ_DISABLE_RDD_SANDBOX=1
# Electron-Apps, Warp und Qt nativ unter Wayland
export ELECTRON_OZONE_PLATFORM_HINT=auto
export WARP_ENABLE_WAYLAND=1
export QT_QPA_PLATFORM="wayland;xcb"
# Qt-Apps nutzen Farben, Icons und Terminal aus ~/.config/kdeglobals (matugen)
export QT_QPA_PLATFORMTHEME=kde
export XCURSOR_THEME=macOS
export XCURSOR_SIZE=24
EOF
  cat >"$home/.config/uwsm/env-hyprland" <<'EOF'
# Hyprland rendert auf der RTX 4060, der interne Bildschirm bekommt das Bild
# kopiert (Feste Namen: udev/rules.d/90-g5.rules)
export AQ_DRM_DEVICES=/dev/dri/nvidia-dgpu:/dev/dri/intel-igpu
EOF

  step "Starter: Discord"
  if [ -f /usr/share/applications/discord.desktop ]; then
    sed 's|^Exec=.*|Exec=/usr/local/bin/discord|' /usr/share/applications/discord.desktop >"$home/.local/share/applications/discord.desktop"
  fi

  step "Stil (minimal oder glass)"
  [ -e "$home/.config/g5/style" ] || /usr/local/bin/style minimal
  /usr/local/bin/style | sed 's/^/    Stil: /'

  step "Programme ohne Paket (pipx, cargo)"
  # Firefox (Pywalfox): Native-Messaging-Host liest die Farben von matugen
  [ -x "$home/.local/bin/pywalfox" ] || pipx install pywalfox || warn "pywalfox nicht installiert"
  printf '#!/bin/sh\nexec %s/.local/bin/pywalfox start\n' "$home" | sdo tee /usr/local/libexec/pywalfox-host >/dev/null
  sdo chmod 755 /usr/local/libexec/pywalfox-host
  sdo install -d /usr/lib/mozilla/native-messaging-hosts
  sdo tee /usr/lib/mozilla/native-messaging-hosts/pywalfox.json >/dev/null <<'JSON'
{
  "name": "pywalfox",
  "description": "Automatically theme your browser using the colors generated by Pywal",
  "path": "/usr/local/libexec/pywalfox-host",
  "type": "stdio",
  "allowed_extensions": ["pywalfox@frewacom.org"]
}
JSON
  # mizu (PDF-Viewer) und opal (Screenshots mit Zeichnen), derselbe Stand wie in flake.lock
  if [ "$(cat "$home/.cache/mizu.rev" 2>/dev/null)" != "$mizu_rev" ]; then
    if cargo install --locked --root "$home/.local" --git https://github.com/notflask/mizu --rev "$mizu_rev" mizu; then
      echo "$mizu_rev" >"$home/.cache/mizu.rev"
      cat >"$home/.local/share/applications/io.github.notflask.Mizu.desktop" <<'DESKTOP'
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
      warn "mizu nicht gebaut"; FAILED+=(mizu)
    fi
  fi
  if [ "$(cat "$home/.cache/opal.rev" 2>/dev/null)" != "$opal_rev" ]; then
    cargo install --locked --root "$home/.local" --git https://github.com/notflask/opal --rev "$opal_rev" opal &&
      echo "$opal_rev" >"$home/.cache/opal.rev" || { warn "opal nicht gebaut"; FAILED+=(opal); }
  fi

  step "Flatpak (Sober/Roblox), Split-Tunneling"
  flatpak remote-add --user --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo || true
  flatpak list --user --app 2>/dev/null | grep -q Sober ||
    flatpak install --user -y flathub org.vinegarhq.Sober || warn "Sober nicht installiert (später: flatpak install --user flathub org.vinegarhq.Sober)"
  vpn-split sync || true

  step "Spotify mit Spicetify"
  if have spotify && have spicetify; then
    spicetify-setup || warn "Spicetify: einmal Spotify starten und anmelden, dann spicetify-setup"
  fi
}

# ── network ──────────────────────────────────────────────────────────────
# Zuletzt: resolv.conf wechselt von systemd-resolved auf openresolv, das Netz
# ist dabei ein paar Sekunden weg.
do_network() {
  step "NetworkManager + openresolv (WireGuard-DNS)"
  if [ -L /etc/resolv.conf ]; then sdo rm -f /etc/resolv.conf; fi
  sdo systemctl stop systemd-resolved.service >/dev/null 2>&1 || true
  sdo systemctl restart NetworkManager.service
  sleep 5
  sdo resolvconf -u || true
  ping -c1 -W5 archlinux.org >/dev/null 2>&1 && info "Netz ok" || warn "kein Netz nach der Umstellung – nmtui bzw. Neustart prüfen"
}

# ── main ─────────────────────────────────────────────────────────────────
all=(repos packages system boot services user network)
# plugins läuft in system mit; einzeln: install.sh plugins (nach Hyprland-Updates)
check
[ $# -gt 0 ] || set -- "${all[@]}"
for s in "$@"; do
  case $s in
    repos | packages | system | plugins | boot | services | user | network) "do_$s" ;;
    *) echo "install.sh: unbekannter Schritt: $s (${all[*]})" >&2; exit 2 ;;
  esac
done
if [ ${#FAILED[@]} -gt 0 ]; then
  warn "Nicht installiert/gebaut: ${FAILED[*]}"
fi
step "Fertig. Neu starten, danach im Login (ly) Hyprland wählen. Details: linux/arch/README.md"
