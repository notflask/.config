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

Es legt 1 GiB EFI + btrfs (`@ @home @snapshots @var_log @var_tmp`, zstd) an, lädt und prüft Stage3 *desktop/systemd*, richtet Binhost (x86-64-v3), Overlays (hyproverlay, GURU, steam-overlay), systemd-boot, dracut, Plymouth (bgrt + Gentoo-Logo, Theme `g5`), Kernel mit (gentoo-kernel, 1000 Hz über `/etc/kernel/config.d/g5.config`), NVIDIA 595 (open), Snapper, Tuning (`files/etc`) und den Benutzer ein.

## 2. Desktop und Programme

Neu starten, als `flask` anmelden (Konsole), WLAN mit `nmtui`, dann:

```sh
~/dotfiles/linux/gentoo/install.sh
```

Schritte einzeln: `repos packages system extras plugins services user network`, dazu `spotify`.

Spotify (`media-sound/spotify`) kommt direkt von Spotifys Mirror und ist im ebuild auf einen festen Build festgelegt. Nimmt Spotify den vom Server, scheitert `emerge` schon beim Download (nur „Failed to emerge“, kein Build-Log – Spotify fehlt dann still). `install.sh` legt deshalb ein kleines lokales Overlay (`/var/db/repos/local`, aktiv über `/etc/portage/repos.conf/local.conf`) mit dem aktuellen Build an; tut sonst nichts, wenn das offizielle ebuild noch lädt. `update` frischt es auf, `install.sh spotify` macht nur das. Nach dem ersten Spotify-Start: `g5 setup spicetify`.

Ohne Gentoo-Paket, von `extras` direkt vom Hersteller: Claude Desktop (.deb), TradingView (Snap), GE-Proton, Spicetify, GPU Screen Recorder UI, CachyOS-Ananicy-Regeln. Gigabyte Control Center, mizu, opal, hyprtasking aus dem Quelltext.

## Alltag

- Logs: `~/.local/state/g5-install.log`, `/var/log/g5-configure.log`; Fehler und Warnungen stehen gesammelt am Ende jedes Laufs.
- `update` – Overlays syncen, `@world` mit Snapshot davor/danach (`emerge-snap`), Plugins, Extras, Spicetify, Flatpak.
- `g5` – zentrale Einstellungen in `config/g5.json` (Stil, Monitore, Leistung, Spiele, VPN, Apps), Profile (`g5 profile use quiet|max|battery`), `g5 setup …` `g5 doctor` (prüft das ganze System) und `g5 audit` (jetzt `update` oder lieber später?). Doku: [config/CONFIG.md](config/CONFIG.md).
- `vpn` – alles zum VPN: `vpn up|down|status|import`, `vpn bypass BEFEHL` (am VPN vorbei, früher `novpn`), `vpn app add|remove`, `vpn domain add|remove` (früher `vpn-split`).
- `gaming-mode [--stretch WxH] %command%` – Spiel mit GameMode, MangoHud, RTX 4060; gestreckt per gamescope, Zeiger bleibt im Spiel (`gaming-mode --help`).
- `style minimal|islands|frame|glass`, `theme` wie unter Arch. Emoji-Auswahl: Super+. (Fenster aus Gruppe lösen jetzt Super+Shift+,).
- Kernel-Optionen: `/etc/kernel/config.d/g5.config`, Kommandozeile: `/etc/kernel/cmdline`, danach `emerge --config sys-kernel/gentoo-kernel`.

## Unterschiede zu Arch

| Arch | Gentoo |
|---|---|
| linux-zen | `gentoo-kernel` (stabil, lokal gebaut, 1000 Hz) + `preempt=full`; NVIDIA wird bei jedem Kernel-Update automatisch neu gebaut |
| Limine + limine-snapper-sync | systemd-boot (installkernel); Snapshots per `snapper`, nicht im Boot-Menü |
| mkinitcpio | dracut |
| paru / AUR | Portage + Binhost, GURU, hyproverlay, steam-overlay |
| pacman-Hooks | `/etc/portage/bashrc` (Vencord, Spicetify-Rechte) |
