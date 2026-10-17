#!/usr/bin/env bash
# configure.sh – Gentoo-Grundsystem für das G5 vom Live-System aus installieren
#
#   sudo ./configure.sh /dev/nvme0n1     Platte LÖSCHEN, partitionieren, installieren
#   sudo ./configure.sh --mounted        Root unter /mnt/gentoo, ESP unter /mnt/gentoo/efi
#                                        (Dual-Boot / eigene Partitionen)
#   sudo ./configure.sh --resume         nach Abbruch weitermachen (Platte bleibt)
#
# Danach: neu starten, als flask anmelden, ~/dotfiles/linux/gentoo/install.sh
set -Eeuo pipefail

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
repo=$(cd "$here/../.." && pwd)
# shellcheck source=lib.sh
. "$here/lib.sh"
trap 'die "Fehler in ${BASH_SOURCE[0]##*/} Zeile $LINENO: $BASH_COMMAND"' ERR

# Werte aus config/g5.json (system.*); Umgebungsvariablen haben Vorrang
g5cfg() {
  command -v python3 >/dev/null || return 0
  python3 -c 'import json,sys; print(json.load(open(sys.argv[1])).get("system",{}).get(sys.argv[2],""))' "$here/config/g5.json" "$1" 2>/dev/null || true
}
USERNAME=${USERNAME:-$(g5cfg user)}; USERNAME=${USERNAME:-flask}
HOSTNAME_G5=${HOSTNAME_G5:-$(g5cfg hostname)}; HOSTNAME_G5=${HOSTNAME_G5:-g5}
TZ_G5=${TZ_G5:-$(g5cfg timezone)}; TZ_G5=${TZ_G5:-Europe/Berlin}
LOCALE_G5=${LOCALE_G5:-$(g5cfg locale)}; LOCALE_G5=${LOCALE_G5:-de_DE.UTF-8}
KERNEL_PKG=${KERNEL_PKG:-$(g5cfg kernel)}; KERNEL_PKG=${KERNEL_PKG:-sys-kernel/gentoo-kernel}
target=/mnt/gentoo
state=/var/lib/g5-configure
profile=default/linux/amd64/23.0/desktop/systemd
vt_colors="vt.default_red=0x14,0xd8,0x7f,0xf3,0x6e,0xbb,0xae,0xcd,0x60,0xe0,0x99,0xf5,0x8b,0xc9,0xbe,0xd7 vt.default_grn=0x14,0x64,0xa5,0xbe,0x94,0x9d,0xae,0xcd,0x60,0x83,0xb7,0xcb,0xa9,0xb1,0xbe,0xd7 vt.default_blu=0x15,0x7e,0x63,0x7c,0xb2,0xbd,0xd1,0xcd,0x79,0x98,0x82,0x96,0xc1,0xca,0xda,0xd7"

# ════════════════════════════ Live-System ════════════════════════════

live_checks() {
  [ "$(id -u)" -eq 0 ] || die "als root starten (sudo)"
  [ -d /sys/firmware/efi/efivars ] || die "nicht im UEFI-Modus gestartet (BIOS: UEFI, Secure Boot aus)"
  local t
  for t in curl tar xz sha256sum mount chroot blkid findmnt; do have "$t" || die "fehlt im Live-System: $t"; done
  curl -fsS --max-time 15 -o /dev/null https://distfiles.gentoo.org/ || die "kein Internet (WLAN: nmtui / net-setup / iwctl)"
}

part_name() { case $1 in *[0-9]) echo "${1}p$2" ;; *) echo "$1$2" ;; esac; }

partition() {
  local disk=$1 ans esp root
  [ -b "$disk" ] || die "keine Platte: $disk (lsblk)"
  findmnt -rno SOURCE | grep -q "^$disk" && die "$disk ist eingehängt – erst aushängen"
  lsblk -o NAME,SIZE,MODEL,FSTYPE,LABEL "$disk"
  printf '\n\033[1;31mALLE Daten auf %s werden gelöscht.\033[0m Zum Bestätigen den Namen eintippen (%s): ' "$disk" "$(basename "$disk")"
  read -r ans
  [ "$ans" = "$(basename "$disk")" ] || die "abgebrochen"

  step "Partitionieren: 1 GiB EFI + btrfs"
  have wipefs && wipefs -af "$disk"
  sfdisk --label gpt "$disk" <<EOF
size=1GiB, type=uefi, name=EFI
type=linux, name=gentoo
EOF
  udevadm settle 2>/dev/null || sleep 2
  esp=$(part_name "$disk" 1)
  root=$(part_name "$disk" 2)
  mkfs.vfat -F 32 -n EFI "$esp"
  mkfs.btrfs -f -L gentoo "$root"

  mount "$root" "$target"
  local sv
  for sv in @ @home @snapshots @var_log @var_tmp; do btrfs subvolume create "$target/$sv"; done
  umount "$target"
  mount_all "$root" "$esp"
}

mount_all() {
  local root=$1 esp=$2 o="noatime,compress=zstd:1,space_cache=v2"
  mkdir -p "$target"
  findmnt -n "$target" >/dev/null || mount -o "$o,subvol=@" "$root" "$target"
  mkdir -p "$target"/{home,.snapshots,var/log,var/tmp,efi}
  findmnt -n "$target/home" >/dev/null || mount -o "$o,subvol=@home" "$root" "$target/home"
  findmnt -n "$target/.snapshots" >/dev/null || mount -o "$o,subvol=@snapshots" "$root" "$target/.snapshots"
  findmnt -n "$target/var/log" >/dev/null || mount -o "$o,subvol=@var_log" "$root" "$target/var/log"
  findmnt -n "$target/var/tmp" >/dev/null || mount -o "$o,subvol=@var_tmp" "$root" "$target/var/tmp"
  findmnt -n "$target/efi" >/dev/null || mount "$esp" "$target/efi"
}

remount_resume() {
  findmnt -n "$target" >/dev/null && return 0
  local root esp
  root=$(blkid -L gentoo) || die "keine Partition mit Label gentoo – selbst einhängen und --mounted nutzen"
  esp=$(blkid -L EFI) || die "keine EFI-Partition mit Label EFI gefunden"
  mount_all "$root" "$esp"
}

stage3() {
  if [ -e "$target/etc/gentoo-release" ]; then info "Stage3 ist schon entpackt"; return 0; fi
  step "Stage3 (desktop, systemd) laden und prüfen"
  local base=https://distfiles.gentoo.org/releases/amd64/autobuilds latest file tmp
  latest=$(curl -fsSL "$base/latest-stage3-amd64-desktop-systemd.txt") || die "Stage3-Liste nicht ladbar"
  file=$(sed -n 's/^\([0-9TZ]*\/stage3-amd64-desktop-systemd-[0-9TZ]*\.tar\.xz\) .*/\1/p' <<<"$latest" | head -1)
  [ -n "$file" ] || die "Stage3-Name nicht gefunden"
  tmp=$target/stage3.tar.xz
  fetch "$base/$file" "$tmp" || die "Download fehlgeschlagen"
  fetch "$base/$file.sha256" "$tmp.sha256" || die "Prüfsumme nicht ladbar"
  local want
  want=$(grep -oE '^[0-9a-f]{64} ' "$tmp.sha256" | head -1 | tr -d ' ')
  [ -n "$want" ] || want=$(grep -A1 -i 'sha256' "$tmp.sha256" | grep -oE '[0-9a-f]{64}' | head -1)
  echo "$want  $tmp" | sha256sum -c --quiet || die "Prüfsumme falsch – Download kaputt"
  if have gpg && [ -f /usr/share/openpgp-keys/gentoo-release.asc ] && fetch "$base/$file.asc" "$tmp.asc"; then
    gpg --batch --import /usr/share/openpgp-keys/gentoo-release.asc 2>/dev/null
    gpg --batch --verify "$tmp.asc" "$tmp" 2>/dev/null && info "Signatur ok" || die "Signatur ungültig"
  fi
  step "Stage3 entpacken"
  tar xpf "$tmp" --xattrs-include='*.*' --numeric-owner -C "$target"
  rm -f "$tmp" "$tmp.sha256" "$tmp.asc"
}

enter_chroot() {
  step "Repo nach /home/$USERNAME/dotfiles kopieren"
  mkdir -p "$target/home/$USERNAME"
  if [ "$(realpath "$repo")" != "$(realpath -m "$target/home/$USERNAME/dotfiles")" ]; then
    rm -rf "$target/home/$USERNAME/dotfiles"
    cp -a "$repo" "$target/home/$USERNAME/dotfiles"
  fi
  cp --dereference --remove-destination /etc/resolv.conf "$target/etc/resolv.conf"
  local m
  findmnt -n "$target/proc" >/dev/null || mount --types proc /proc "$target/proc"
  for m in sys dev; do
    findmnt -n "$target/$m" >/dev/null || { mount --rbind "/$m" "$target/$m"; mount --make-rslave "$target/$m"; }
  done
  findmnt -n "$target/run" >/dev/null || { mount --bind /run "$target/run"; mount --make-slave "$target/run"; }
  [ -L /dev/shm ] && { rm /dev/shm; mkdir /dev/shm; mount -t tmpfs -o nosuid,nodev,noexec shm /dev/shm; chmod 1777 /dev/shm; } || true
  step "chroot"
  chroot "$target" /usr/bin/env -i HOME=/root TERM="${TERM:-linux}" PATH=/usr/sbin:/usr/bin:/sbin:/bin \
    USERNAME="$USERNAME" HOSTNAME_G5="$HOSTNAME_G5" TZ_G5="$TZ_G5" LOCALE_G5="$LOCALE_G5" KERNEL_PKG="$KERNEL_PKG" \
    /bin/bash "/home/$USERNAME/dotfiles/linux/gentoo/configure.sh" --chroot
}

finish_live() {
  step "Aushängen"
  cp -f /tmp/g5-configure-live.log "$target/var/log/" 2>/dev/null || true
  ln -sf ../run/systemd/resolve/stub-resolv.conf "$target/etc/resolv.conf"
  sync
  umount -R "$target" 2>/dev/null || umount -lR "$target" || true
  report
  info "Logs im neuen System: /var/log/g5-configure.log, /var/log/g5-configure-live.log"
  step "Fertig. Neu starten (Stick ziehen), als $USERNAME anmelden, dann:"
  info "nmtui   (falls WLAN)"
  info "\$HOME/dotfiles/linux/gentoo/install.sh"
}

# ════════════════════════════ chroot ════════════════════════════

done_step() { [ -e "$state/$1" ]; }
mark() { mkdir -p "$state"; touch "$state/$1"; }
run() { done_step "$1" && { info "$1: schon erledigt"; return 0; }; "do_$1"; mark "$1"; }

# bei jedem Lauf (auch --resume): Portage-Dateien aus dem Repo; Steam-32-Bit erst in install.sh
portage_files() {
  mkdir -p /etc/portage/{package.use,package.accept_keywords,package.license,package.mask,sets}
  cp "$here/portage/package.use/g5" /etc/portage/package.use/g5
  rm -f /etc/portage/package.use/steam
  cp "$here"/portage/package.accept_keywords/* /etc/portage/package.accept_keywords/
  cp "$here"/portage/package.license/* /etc/portage/package.license/
  cp "$here"/portage/package.mask/* /etc/portage/package.mask/
  cp "$here"/portage/sets/* /etc/portage/sets/
  mkdir -p /etc/portage/env /etc/portage/package.env /var/cache/ccache
  cp "$here"/portage/env/* /etc/portage/env/
  cp "$here"/portage/package.env/* /etc/portage/package.env/
  printf 'max_size = 5G\ncompression = true\n' >/var/cache/ccache/ccache.conf
}

do_portage() {
  step "Portage: Repository, Profil, make.conf, Binhost"
  set +u; source /etc/profile; set -u
  emerge-webrsync -q || emerge-webrsync
  eselect profile set "$profile" || die "Profil $profile fehlt"
  local threads ram jobs
  threads=$(nproc)
  ram=$(awk '/MemTotal/ {print int($2/1048576)}' /proc/meminfo)
  jobs=$(( ram / 2 < threads ? ram / 2 : threads ))
  [ "$jobs" -ge 1 ] || jobs=1
  mkdir -p /etc/portage/{package.use,package.accept_keywords,package.license,package.mask,binrepos.conf,sets,repos.conf}
  [ -f /etc/portage/make.conf.stage3 ] || cp /etc/portage/make.conf /etc/portage/make.conf.stage3
  sed -e "s/@MAKEOPTS@/-j$jobs -l$threads/" -e "s/@THREADS@/$threads/" \
    "$here/portage/make.conf" >/etc/portage/make.conf
  portage_files
  rm -f /etc/portage/binrepos.conf/*
  cp "$here/portage/binrepos.conf/gentoo.conf" /etc/portage/binrepos.conf/
  getuto || warn "getuto fehlgeschlagen – Binärpakete evtl. ohne Signaturprüfung nicht nutzbar"
}

do_locale() {
  step "Zeit, Sprache, Name"
  ln -sf "../usr/share/zoneinfo/$TZ_G5" /etc/localtime
  grep -q "^$LOCALE_G5" /etc/locale.gen || echo "$LOCALE_G5 UTF-8" >>/etc/locale.gen
  grep -q '^en_US.UTF-8' /etc/locale.gen || echo "en_US.UTF-8 UTF-8" >>/etc/locale.gen
  locale-gen
  printf 'LANG=%s\nLC_MESSAGES=%s\n' "$LOCALE_G5" "$LOCALE_G5" >/etc/locale.conf
  echo KEYMAP=us >/etc/vconsole.conf
  echo "$HOSTNAME_G5" >/etc/hostname
  printf '127.0.0.1 localhost\n::1 localhost\n127.0.1.1 %s\n' "$HOSTNAME_G5" >/etc/hosts
  env-update >/dev/null
  set +u; source /etc/profile; set -u
}

do_repos() {
  step "Overlays: hyproverlay, GURU, steam-overlay"
  emerge_try app-eselect/eselect-repository dev-vcs/git
  cp "$here/portage/repos.conf" /etc/portage/repos.conf/g5.conf
  local r
  for r in hyproverlay guru steam-overlay; do
    emaint sync -r "$r" || warn "Sync von $r fehlgeschlagen"
  done
  spotify_overlay
}

do_world() {
  step "System aktualisieren (Profil desktop/systemd, meist Binärpakete)"
  emerge --ask=n --oneshot --update --newuse sys-apps/systemd || die "systemd (mit systemd-boot) fehlgeschlagen"
  emerge --ask=n -uDN @world || emerge --ask=n -uDN --keep-going=y @world || die "@world fehlgeschlagen – Ausgabe prüfen, dann --resume"
}

do_boot() {
  step "Bootloader: systemd-boot, dracut, Plymouth"
  emerge_try sys-apps/systemd sys-kernel/installkernel sys-kernel/dracut sys-boot/plymouth sys-fs/btrfs-progs sys-fs/dosfstools
  findmnt -n /efi >/dev/null || die "/efi ist nicht eingehängt"
  bootctl install --esp-path=/efi || bootctl install --esp-path=/efi --no-variables
  mkdir -p /efi/loader
  printf 'timeout 1\nconsole-mode keep\neditor no\n' >/efi/loader/loader.conf
  local root_uuid sub rootdev
  rootdev=$(findmnt -no SOURCE / | sed 's/\[.*//')
  root_uuid=$(blkid -s UUID -o value "$rootdev")
  sub=$(findmnt -no OPTIONS / | grep -oE 'subvol=[^,]+' | head -1 | sed 's|subvol=/|subvol=|') || true
  local rootargs="root=UUID=$root_uuid rw"
  [ "$(findmnt -no FSTYPE /)" = btrfs ] && rootargs="$rootargs rootfstype=btrfs ${sub:+rootflags=$sub}"
  mkdir -p /etc/kernel/config.d /etc/dracut.conf.d
  cp "$here/files/etc/kernel/config.d/g5.config" /etc/kernel/config.d/
  sed -e "s|@ROOT@|$rootargs|" -e "s|@VT@|$vt_colors|" "$here/files/etc/kernel/cmdline.tpl" >/etc/kernel/cmdline
  cp "$here/files/etc/dracut.conf.d/g5.conf" /etc/dracut.conf.d/
  install -D -m644 "$here/files/etc/plymouth/plymouthd.conf" /etc/plymouth/plymouthd.conf
  # g5 = bgrt mit Gentoo-Logo; braucht die Spinner-Bilder im eigenen ImageDir
  local pt=/usr/share/plymouth/themes
  mkdir -p "$pt/g5"
  cp "$pt"/spinner/*.png "$pt/g5/"
  install -m644 "$here"/files/usr/share/plymouth/themes/g5/{g5.plymouth,watermark.png} "$pt/g5/"
  plymouth-set-default-theme g5 2>/dev/null || plymouth-set-default-theme bgrt 2>/dev/null || plymouth-set-default-theme spinner || true
}

do_kernel() {
  step "Kernel ($KERNEL_PKG), Firmware, Microcode, NVIDIA"
  # ccache vor dem Kernel: package.env/g5 baut Kernel und Module damit
  emerge_try dev-util/ccache sys-kernel/linux-firmware sys-firmware/intel-microcode sys-firmware/sof-firmware
  emerge --ask=n --noreplace "$KERNEL_PKG" || die "Kernel-Build fehlgeschlagen"
  eselect kernel set 1 2>/dev/null || true
  emerge_try x11-drivers/nvidia-drivers app-laptop/tuxedo-drivers
  emerge --ask=n --config "$KERNEL_PKG" || warn "initramfs neu erzeugen fehlgeschlagen"
  ls /efi/loader/entries/*.conf >/dev/null 2>&1 || die "kein Boot-Eintrag in /efi/loader/entries – kernel-install prüfen"
}

do_base() {
  step "Basis-Pakete (@g5-base)"
  mapfile -t pkgs < <(list "$here/portage/sets/g5-base")
  emerge_try "${pkgs[@]}"
}

do_tuning() {
  step "Leistungs-Tweaks und Systemdateien"
  SUDO="" overlay "$here/files/etc" /etc
  rm -f /etc/kernel/cmdline.tpl
  install -d /usr/local/sbin /usr/local/libexec /usr/lib/systemd/system-sleep /var/lib/vpn-bypass /etc/wireguard /etc/g5
  command -v python3 >/dev/null && python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); d.pop("$schema",None); json.dump(d,open("/etc/g5/g5.json","w"),indent=2)' "$here/config/g5.json" || true
  install -m755 "$here"/files/sbin/* /usr/local/sbin/
  install -m755 "$here"/files/libexec/* /usr/local/libexec/
  install -m755 "$here/files/sleep/g5-tuning" /usr/lib/systemd/system-sleep/g5-tuning
  touch /var/lib/vpn-bypass/domains
  install -d /etc/sudoers.d
  chmod 440 /etc/sudoers.d/g5
  visudo -cq -f /etc/sudoers.d/g5 2>/dev/null || rm -f /etc/sudoers.d/g5
  echo '%wheel ALL=(ALL:ALL) ALL' >/etc/sudoers.d/00-wheel
  chmod 440 /etc/sudoers.d/00-wheel
  install -d /etc/security/limits.d /etc/sudoers.d
  printf '@audio - rtprio 95\n@audio - memlock unlimited\n' >/etc/security/limits.d/90-g5-audio.conf
}

do_fstab() {
  step "fstab"
  [ -f /etc/fstab.stage3 ] || cp /etc/fstab /etc/fstab.stage3
  {
    echo "# erzeugt von configure.sh"
    findmnt -rn -o SOURCE,TARGET,FSTYPE,OPTIONS --submounts / | while read -r src tgt fs opts; do
      case $fs in btrfs | vfat | ext4 | xfs) ;; *) continue ;; esac
      local dev=${src%%\[*} uuid
      uuid=$(blkid -s UUID -o value "$dev") || continue
      if [ "$fs" = btrfs ]; then
        local sv
        sv=$(grep -oE 'subvol=[^,]+' <<<"$opts" | sed 's|subvol=/|subvol=|')
        echo "UUID=$uuid $tgt btrfs noatime,compress=zstd:1,space_cache=v2${sv:+,$sv} 0 0"
      elif [ "$fs" = vfat ]; then
        echo "UUID=$uuid $tgt vfat umask=0077,noatime 0 2"
      else
        echo "UUID=$uuid $tgt $fs noatime 0 1"
      fi
    done
  } >/etc/fstab
  cat /etc/fstab
}

do_user() {
  step "Benutzer $USERNAME"
  emerge_try app-admin/sudo app-shells/fish
  local g
  for g in gamemode realtime plugdev; do getent group "$g" >/dev/null || groupadd -r "$g"; done
  if ! id "$USERNAME" >/dev/null 2>&1; then
    useradd -m -G wheel,video,audio,input,kvm,users,usb,plugdev,gamemode,realtime -s /bin/fish "$USERNAME" 2>/dev/null ||
      useradd -m -G wheel,video,audio,input,kvm,users -s /bin/fish "$USERNAME"
  fi
  usermod -aG wheel,video,audio,input,kvm,users,gamemode,realtime "$USERNAME" 2>/dev/null || true
  chown -R "$USERNAME:$USERNAME" "/home/$USERNAME"
  until passwd "$USERNAME"; do warn "nochmal"; done
  passwd -l root >/dev/null || true
}

do_services() {
  step "Dienste"
  systemd-machine-id-setup
  systemctl preset-all --preset-mode=enable-only >/dev/null 2>&1 || true
  local s
  for s in NetworkManager bluetooth power-profiles-daemon upower fstrim.timer systemd-timesyncd systemd-boot-update \
    systemd-resolved nvidia-persistenced nvidia-powerd g5-firewall g5-tuning vpn-bypass vpn-bypass-dst.timer vpn-peer-info; do
    # reenable statt enable: entfernt Links aus einem alten [Install]-Abschnitt
    # (z. B. g5-tuning früher an multi-user.target → Ordnungs-Kreis beim Booten)
    systemctl reenable "$s" >/dev/null 2>&1 && info "an: $s" || info "übersprungen: $s"
  done
  systemctl disable systemd-networkd >/dev/null 2>&1 || true
  systemctl enable systemd-resolved >/dev/null 2>&1 || true
  ln -sf ../run/systemd/resolve/stub-resolv.conf /etc/resolv.conf
}

do_snapper() {
  [ "$(findmnt -no FSTYPE /)" = btrfs ] || { info "kein btrfs – ohne Snapshots"; return 0; }
  step "Snapper"
  emerge_try app-backup/snapper
  if ! snapper --no-dbus list-configs 2>/dev/null | grep -q '^root '; then
    local remount=0
    if findmnt -n /.snapshots >/dev/null; then umount /.snapshots; remount=1; fi
    rmdir /.snapshots 2>/dev/null || true
    snapper --no-dbus -c root create-config /
    if [ $remount = 1 ]; then
      btrfs subvolume delete /.snapshots
      mkdir /.snapshots
      mount /.snapshots
    fi
    chmod 750 /.snapshots
  fi
  snapper --no-dbus -c root set-config TIMELINE_CREATE=no NUMBER_LIMIT=10 NUMBER_LIMIT_IMPORTANT=5
  systemctl enable snapper-cleanup.timer >/dev/null 2>&1 || true
}

chroot_main() {
  [ -e /etc/gentoo-release ] || die "--chroot nur im Ziel-System"
  start_log /var/log/g5-configure.log
  set +u; source /etc/profile; set -u
  done_step portage && portage_files
  run portage
  run locale
  run repos
  run world
  run boot
  run kernel
  run base
  run tuning
  run fstab
  run snapper
  run user
  run services
  report
}

# ════════════════════════════ Start ════════════════════════════

[ "${1:-}" = --chroot ] || [ "$(id -u)" -ne 0 ] || start_log /tmp/g5-configure-live.log
case ${1:-} in
  --chroot) chroot_main ;;
  --mounted)
    live_checks
    findmnt -n "$target" >/dev/null || die "$target ist nicht eingehängt"
    findmnt -n "$target/efi" >/dev/null || die "ESP nicht unter $target/efi eingehängt"
    stage3; enter_chroot; finish_live ;;
  --resume)
    live_checks; remount_resume; stage3; enter_chroot; finish_live ;;
  /dev/*)
    live_checks; partition "$1"; stage3; enter_chroot; finish_live ;;
  *)
    sed -n '2,9s/^# \{0,1\}//p' "$0"; exit 2 ;;
esac
