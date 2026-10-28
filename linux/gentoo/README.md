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

Schritte einzeln: `repos packages system extras plugins services user network`, dazu `spotify` und `codex`.

Spotify (`media-sound/spotify`) kommt direkt von Spotifys Mirror und ist im ebuild auf einen festen Build festgelegt. Nimmt Spotify den vom Server, scheitert `emerge` schon beim Download (nur „Failed to emerge“, kein Build-Log – Spotify fehlt dann still). `install.sh` legt deshalb ein kleines lokales Overlay (`/var/db/repos/local`, aktiv über `/etc/portage/repos.conf/local.conf`) mit dem aktuellen Build an; tut sonst nichts, wenn das offizielle ebuild noch lädt. `update` frischt es auf, `install.sh spotify` macht nur das. Nach dem ersten Spotify-Start: `g5 setup spicetify`.

Ohne Gentoo-Paket, von `extras` direkt vom Hersteller: Claude Desktop (.deb), TradingView (Snap), GE-Proton, Spicetify, GPU Screen Recorder UI, CachyOS-Ananicy-Regeln. Gigabyte Control Center, mizu, opal, hyprtasking aus dem Quelltext.

ChatGPT / Codex Desktop wird ebenfalls durch `extras` installiert, einzeln mit `install.sh codex`. Der geprüfte x86_64-Build **26.1023.51421** kommt von OpenAI über eine feste Versions-URL mit SHA256-Prüfung. [scripts/codex-app.py](scripts/codex-app.py) installiert ihn unter `~/.local/share/chatgpt/`, legt die Starter `chatgpt` und `codex-app` sowie **ChatGPT (Codex)** im App-Menü an und entfernt Menüleiste und Fensterknöpfe. Die bestehende Codex-CLI und ihre Konfiguration werden nicht ersetzt. Offline: `python3 ~/dotfiles/linux/gentoo/scripts/codex-app.py /pfad/chatgpt_26.1023.51421_amd64.deb`.

Gentoo ist von OpenAI nicht offiziell unterstützt. Version und Fenster-Patch sind bewusst gemeinsam festgelegt: Aktualisierungen erst nach Anpassung und Prüfung dieses Installers; unbekannte Archive werden vor der Installation abgelehnt. Rückgängig: App beenden, `resources/app.asar.before-minimal` über `resources/app.asar` im Versionsverzeichnis kopieren, App erneut öffnen.

Matugen erzeugt `~/.cache/matugen/chatgpt-theme.json`; der Desktop übernimmt Hintergrund, Text-, Akzent- und semantische Farben sowie Hell/Dunkel über seine nativen Appearance-Einstellungen. Neue Wallpaper-Farben werden in laufenden Fenstern automatisch geladen. Eigene Schriftarten, Kontrast und Transparenz-Einstellungen bleiben erhalten. Beim ersten Einrichten einmal `~/.config/matugen/theme.sh` ausführen. Zum Nachrüsten einer älteren Installation die Desktop-App vorher beenden und `install.sh codex` erneut ausführen.

## Alltag

- Logs: `~/.local/state/g5-install.log`, `/var/log/g5-configure.log`; Fehler und Warnungen stehen gesammelt am Ende jedes Laufs.
- `update` – Overlays syncen, `@world` mit Snapshot davor/danach (`emerge-snap`), Plugins, Extras, Spicetify, Flatpak.
- `g5` – zentrale Einstellungen in `config/g5.json` (Stil, Monitore, Leistung, Spiele, VPN, Apps), Profile (`g5 profile use quiet|max|battery`), `g5 setup …` und `g5 doctor` (prüft das ganze System). Doku: [config/CONFIG.md](config/CONFIG.md).
- `vpn` – alles zum VPN: `vpn up|down|status|import`, `vpn bypass BEFEHL` (am VPN vorbei, früher `novpn`), `vpn app add|remove`, `vpn domain add|remove` (früher `vpn-split`).
- `gaming-mode [--stretch WxH] %command%` – Spiel mit GameMode, MangoHud, RTX 4060; gestreckt per gamescope, Zeiger bleibt im Spiel (`gaming-mode --help`).
- `style minimal|mono|islands|frame|glass`, `theme` wie unter Arch. Emoji-Auswahl: Super+. (Fenster aus Gruppe lösen jetzt Super+Shift+,).
- Kernel-Optionen: `/etc/kernel/config.d/g5.config`, Kommandozeile: `/etc/kernel/cmdline`, danach `emerge --config sys-kernel/gentoo-kernel`.

## Unterschiede zu Arch

| Arch | Gentoo |
|---|---|
| linux-zen | `gentoo-kernel` (stabil, lokal gebaut, 1000 Hz) + `preempt=full`; NVIDIA wird bei jedem Kernel-Update automatisch neu gebaut |
| Limine + limine-snapper-sync | systemd-boot (installkernel); Snapshots per `snapper`, nicht im Boot-Menü |
| mkinitcpio | dracut |
| paru / AUR | Portage + Binhost, GURU, hyproverlay, steam-overlay |
| pacman-Hooks | `/etc/portage/bashrc` (Vencord, Spicetify-Rechte) |
