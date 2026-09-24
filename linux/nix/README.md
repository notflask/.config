# NixOS – Gigabyte G5 KF

- Laptop: Intel i5-12500H (Iris Xe) + NVIDIA RTX 4060 Laptop, 1080p@144 Hz
- Desktop: KDE Plasma 6 (Wayland), Login über greetd + tuigreet
- Kanal: `nixos-unstable` (Flake), Systemsprache Deutsch, Zeitzone Europe/Berlin

```
linux/nix/
├── flake.nix
└── hosts/g5/
    ├── configuration.nix          # Boot, Netzwerk, Locale, User, Audio, Laptop
    ├── hardware-configuration.nix # PLATZHALTER – auf dem Laptop neu erzeugen!
    ├── nvidia.nix                 # Hybrid-Grafik (PRIME Offload)
    ├── desktop.nix                # Plasma 6, greetd, Fonts, Tastatur
    └── apps.nix                   # Firefox, Vesktop, Telegram, Spotify
```

## Installation (vom NixOS-ISO)

1. Partitionieren wie im [NixOS-Handbuch](https://nixos.org/manual/nixos/stable/#sec-installation-manual-partitioning)
   (EFI mit Label `boot`, Root als ext4 mit Label `nixos`) und nach `/mnt` mounten.
2. Hardware-Config erzeugen:
   ```sh
   sudo nixos-generate-config --root /mnt
   ```
3. Repo holen und die erzeugte Hardware-Config übernehmen:
   ```sh
   nix-shell -p git
   git clone https://github.com/notflask/.config /mnt/home/flask/.config
   cp /mnt/etc/nixos/hardware-configuration.nix /mnt/home/flask/.config/linux/nix/hosts/g5/
   ```
   `system.stateVersion` in `configuration.nix` auf den Wert aus
   `/mnt/etc/nixos/configuration.nix` setzen.
4. Bus-IDs der GPUs prüfen (siehe unten).
5. Installieren und Passwort setzen:
   ```sh
   cd /mnt/home/flask/.config
   git add -A   # Flakes sehen nur Dateien, die git kennt
   sudo nixos-install --flake ./linux/nix#g5
   sudo nixos-enter --root /mnt -c 'passwd flask'
   sudo nixos-enter --root /mnt -c 'chown -R flask:users /home/flask/.config'
   ```

## Updates / Änderungen übernehmen

```sh
cd ~/.config/linux/nix
sudo nixos-rebuild switch --flake .#g5      # Config anwenden
nix flake update && sudo nixos-rebuild switch --flake .#g5   # System aktualisieren
```

`flake.lock` entsteht beim ersten Build – danach mit committen.

## Hybrid-Grafik

Standardmäßig läuft alles auf der **Intel-iGPU** (Akku, Temperatur, leise).
Die RTX 4060 schaltet sich im Leerlauf komplett ab und wird nur bei Bedarf genutzt:

```sh
nvidia-offload <programm>          # z. B. nvidia-offload glxinfo | grep renderer
```

In KDE geht es auch per Rechtsklick auf die App im Startmenü → Start mit der
dedizierten Grafikkarte (über `switcheroo-control`).
Für Steam-Spiele: Startoptionen `nvidia-offload %command%`.

Externe Monitore funktionieren unter Plasma Wayland direkt. Hängt der Anschluss
an der NVIDIA-GPU, wacht sie dafür auf.

**Bus-IDs prüfen** (in `nvidia.nix` eingetragen: Intel `PCI:0:2:0`, NVIDIA `PCI:1:0:0`):

```sh
lspci -D | grep -Ei 'vga|3d'
# 0000:00:02.0 VGA ... Intel   → PCI:0:2:0
# 0000:01:00.0 VGA ... NVIDIA  → PCI:1:0:0
```

Die Werte in `lspci` sind hexadezimal, NixOS erwartet dezimal (z. B. `0a` → `10`).

> ⚠️ `linux/.config/environment.d/environment.conf` und die Hyprland-Config setzen
> `LIBVA_DRIVER_NAME=nvidia`, `GBM_BACKEND=nvidia-drm` usw. global. Das ist für
> Offload falsch und macht Firefox/Electron-Apps kaputt. **Diese Datei nicht nach
> `~/.config/environment.d/` kopieren**, wenn du die NixOS-Config nutzt.

## Apps

| App | Hinweise |
|---|---|
| Firefox | VA-API-Videodekodierung über Intel (`iHD`), KDE-Dateidialog, KDE-Browserintegration. Prüfen: `about:support` → *Media* → *Hardware Decoding* |
| Vesktop | Discord-Client; Bildschirmfreigabe unter Wayland über das KDE-Portal |
| Telegram | `telegram-desktop` |
| Spotify | Port 57621/TCP + mDNS offen für Spotify Connect im LAN |

## Tastatur

`us,ru,ua,de`, Umschalten mit Alt+Shift. Das ist der Standard für neue
Plasma-Profile. Falls Plasma ihn nicht übernimmt: *Systemeinstellungen → Tastatur → Belegungen*.
