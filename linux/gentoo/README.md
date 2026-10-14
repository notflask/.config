# Gentoo auf dem G5

Zwei Skripte: `configure.sh` installiert vom Live-System das Grundsystem mit allen Tweaks, `install.sh` danach Desktop, Programme und Dotfiles.

## 1. Grundsystem (Live-USB)

Gentoo-Minimal-ISO (oder jedes Live-Linux mit bash, curl, sfdisk, mkfs.btrfs) im **UEFI-Modus**, Secure Boot aus.

```sh
git clone -b gentoo https://github.com/notflask/.config dotfiles
sudo ./dotfiles/linux/gentoo/configure.sh /dev/nvme0n1   # Platte LÖSCHEN
```

- Eigene Partitionen / Dual-Boot: Root nach `/mnt/gentoo`, ESP nach `/mnt/gentoo/efi`, dann `configure.sh --mounted`.
- Abbruch (Netz, Build-Fehler): `configure.sh --resume` macht beim letzten Schritt weiter.
- Variablen: `USERNAME`, `HOSTNAME_G5`, `TZ_G5`, `LOCALE_G5`, `KERNEL_PKG` (Standard `sys-kernel/gentoo-kernel`; `gentoo-kernel-bin` = vorgebaut, 300 Hz).

Es legt 1 GiB EFI + btrfs (`@ @home @snapshots @var_log @var_tmp`, zstd) an, lädt und prüft Stage3 *desktop/systemd*, richtet Binhost (x86-64-v3), Overlays (hyproverlay, GURU, steam-overlay), systemd-boot, dracut, Plymouth (bgrt), Kernel mit (gentoo-kernel, 1000 Hz über `/etc/kernel/config.d/g5.config`), NVIDIA 595 (open), Snapper, Tuning (`files/etc`) und den Benutzer ein.

## 2. Desktop und Programme

Neu starten, als `flask` anmelden (Konsole), WLAN mit `nmtui`, dann:

```sh
~/dotfiles/linux/gentoo/install.sh
```

Schritte einzeln: `repos packages system extras plugins services user network`.

Ohne Gentoo-Paket, von `extras` direkt vom Hersteller: Claude Desktop (.deb), TradingView (Snap), GE-Proton, Spicetify, GPU Screen Recorder UI, CachyOS-Ananicy-Regeln. Gigabyte Control Center, mizu, opal, hyprtasking aus dem Quelltext.

## Alltag

- Logs: `~/.local/state/g5-install.log`, `/var/log/g5-configure.log`; Fehler und Warnungen stehen gesammelt am Ende jedes Laufs.
- `update` – Overlays syncen, `@world` mit Snapshot davor/danach (`emerge-snap`), Plugins, Extras, Spicetify, Flatpak.
- `style minimal|glass`, `theme`, `vpn`, `novpn`, `gaming-mode` wie unter Arch.
- Kernel-Optionen: `/etc/kernel/config.d/g5.config`, Kommandozeile: `/etc/kernel/cmdline`, danach `emerge --config sys-kernel/gentoo-kernel`.

## Unterschiede zu Arch

| Arch | Gentoo |
|---|---|
| linux-zen | `gentoo-kernel` (stabil, lokal gebaut, 1000 Hz) + `preempt=full`; NVIDIA wird bei jedem Kernel-Update automatisch neu gebaut |
| Limine + limine-snapper-sync | systemd-boot (installkernel); Snapshots per `snapper`, nicht im Boot-Menü |
| mkinitcpio | dracut |
| paru / AUR | Portage + Binhost, GURU, hyproverlay, steam-overlay |
| pacman-Hooks | `/etc/portage/bashrc` (Vencord, Spicetify-Rechte) |
