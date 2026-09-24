#!/usr/bin/env bash
# ============================================================
#  NixOS-Installation für den Gigabyte G5 KF – vom Live-ISO
#
#  Repo auf dem Live-System holen und Skript starten:
#    git clone https://github.com/notflask/.config dotfiles
#    sudo ./dotfiles/linux/nix/scripts/install.sh /dev/nvme0n1
#
#  Modi:
#    install.sh <disk>     Platte KOMPLETT löschen, partitionieren,
#                          installieren (1 GiB EFI + Rest ext4)
#    install.sh --mounted  Partitionen selbst angelegt und unter /mnt
#                          (+ /mnt/boot) eingehängt, z. B. für Dual-Boot
# ============================================================

set -euo pipefail

HOST="g5"
USER_NAME="flask"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_SRC="$(cd "$SCRIPT_DIR/../../.." && pwd)"
TARGET_REPO="/mnt/home/$USER_NAME/dotfiles"
FLAKE_DIR="$TARGET_REPO/linux/nix"
HOST_DIR="$FLAKE_DIR/hosts/$HOST"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

step() { echo -e "\n${GREEN}==> $1${NC}"; }
warn() { echo -e "${YELLOW}  ! $1${NC}"; }
die() {
  echo -e "${RED}  ✗ $1${NC}" >&2
  exit 1
}

usage() {
  sed -n '2,15p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
  exit 1
}

# ── Prüfungen ────────────────────────────────────────────────
[ $# -eq 1 ] || usage
[ "$(id -u)" -eq 0 ] || die "Bitte mit sudo ausführen."
[ -d /sys/firmware/efi ] || die "Nicht im UEFI-Modus gebootet (systemd-boot braucht UEFI)."
command -v nixos-install >/dev/null || die "nixos-install nicht gefunden – bitte vom NixOS-Live-ISO starten."
[ -f "$REPO_SRC/linux/nix/flake.nix" ] || die "flake.nix nicht gefunden unter $REPO_SRC/linux/nix"

# ── Partitionieren ───────────────────────────────────────────
partition_disk() {
  local disk="$1"
  [ -b "$disk" ] || die "$disk ist kein Blockgerät."
  [ "$(lsblk -dno TYPE "$disk")" = "disk" ] || die "$disk ist keine ganze Platte (z. B. /dev/nvme0n1 angeben)."
  if lsblk -no MOUNTPOINTS "$disk" | grep -q .; then
    die "Auf $disk ist noch etwas eingehängt – erst aushängen."
  fi

  local p=""
  [[ "$disk" =~ [0-9]$ ]] && p="p" # nvme0n1 → nvme0n1p1, sda → sda1
  local boot_part="${disk}${p}1"
  local root_part="${disk}${p}2"

  step "Aktueller Inhalt von $disk"
  lsblk -o NAME,SIZE,FSTYPE,LABEL,MODEL "$disk"
  echo
  echo -e "${RED}ALLE DATEN AUF $disk WERDEN GELÖSCHT (auch Windows, falls vorhanden).${NC}"
  read -rp "Zum Bestätigen den Gerätenamen eintippen ($(basename "$disk")): " answer
  [ "$answer" = "$(basename "$disk")" ] || die "Abgebrochen."

  step "Partitioniere $disk (1 GiB EFI + Rest ext4)"
  wipefs -a "$disk"
  parted -s "$disk" -- \
    mklabel gpt \
    mkpart ESP fat32 1MiB 1GiB \
    set 1 esp on \
    mkpart root ext4 1GiB 100%
  udevadm settle

  step "Formatiere"
  mkfs.fat -F 32 -n boot "$boot_part"
  mkfs.ext4 -F -L nixos "$root_part"

  step "Hänge unter /mnt ein"
  mount "$root_part" /mnt
  mkdir -p /mnt/boot
  mount -o umask=077 "$boot_part" /mnt/boot
}

case "$1" in
  --mounted)
    mountpoint -q /mnt || die "/mnt ist nicht eingehängt."
    mountpoint -q /mnt/boot || die "/mnt/boot (EFI-Partition) ist nicht eingehängt."
    ;;
  -h | --help) usage ;;
  /dev/*) partition_disk "$1" ;;
  *) usage ;;
esac

# ── Hardware-Config ──────────────────────────────────────────
step "Erzeuge hardware-configuration.nix"
nixos-generate-config --root /mnt

# ── Repo auf das Zielsystem kopieren ─────────────────────────
step "Kopiere Repo nach ${TARGET_REPO#/mnt}"
[ -e "$TARGET_REPO" ] && die "$TARGET_REPO existiert schon – bitte prüfen und ggf. selbst entfernen."
mkdir -p "$(dirname "$TARGET_REPO")"
cp -r --no-preserve=ownership "$REPO_SRC" "$TARGET_REPO"
cp /mnt/etc/nixos/hardware-configuration.nix "$HOST_DIR/hardware-configuration.nix"

# ── stateVersion übernehmen ──────────────────────────────────
state_version="$(sed -n 's/.*system\.stateVersion = "\([^"]*\)".*/\1/p' /mnt/etc/nixos/configuration.nix | head -1)"
if [ -n "$state_version" ]; then
  sed -i "s/system\.stateVersion = \"[^\"]*\"/system.stateVersion = \"$state_version\"/" "$HOST_DIR/configuration.nix"
  echo "  stateVersion = $state_version"
else
  warn "stateVersion nicht gefunden – Wert aus der Config bleibt."
fi

# ── GPU-Adressen ermitteln ───────────────────────────────────
step "Suche GPUs"
intel_pci=""
nvidia_pci=""
for dev in /sys/bus/pci/devices/*; do
  [[ "$(cat "$dev/class")" == 0x03* ]] || continue # Display-Controller
  case "$(cat "$dev/vendor")" in
    0x8086) intel_pci="$(basename "$dev")" ;;
    0x10de) nvidia_pci="$(basename "$dev")" ;;
  esac
done
echo "  Intel:  ${intel_pci:-nicht gefunden}"
echo "  NVIDIA: ${nvidia_pci:-nicht gefunden}"
if [ -n "$intel_pci" ] && [ -n "$nvidia_pci" ]; then
  sed -i \
    -e "s/intelPci = \"[^\"]*\"/intelPci = \"$intel_pci\"/" \
    -e "s/nvidiaPci = \"[^\"]*\"/nvidiaPci = \"$nvidia_pci\"/" \
    "$HOST_DIR/nvidia.nix"
else
  warn "Nicht beide GPUs gefunden (dGPU im BIOS deaktiviert?) – Standardwerte bleiben."
fi

# Flakes sehen nur Dateien, die git kennt
git -C "$TARGET_REPO" -c safe.directory='*' add -A linux/nix

# ── Installation ─────────────────────────────────────────────
step "Installiere NixOS (dauert eine Weile)"
nixos-install --flake "$FLAKE_DIR#$HOST" --no-root-passwd

step "Passwort für $USER_NAME setzen"
until nixos-enter --root /mnt -c "passwd $USER_NAME"; do
  warn "Nochmal versuchen."
done

nixos-enter --root /mnt -c "chown -R $USER_NAME:users /home/$USER_NAME"

step "Fertig!"
cat <<'MSG'
  • Neustarten:  reboot
  • Nach dem ersten Login:
      monitors    # eDP-1 + DP-2 einrichten
      gpu-info    # welcher Anschluss an welcher GPU hängt
  • hardware-configuration.nix, nvidia.nix und flake.lock ins Repo committen.
MSG
