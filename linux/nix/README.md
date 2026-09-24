# NixOS – Gigabyte G5 KF

- Laptop: Intel i5-12500H (Iris Xe) + NVIDIA RTX 4060 Laptop, eDP-1 1080p@144 Hz
- Externer Monitor: LG UltraGear 2K, 1440p@180 Hz (DP-2)
- Desktop: KDE Plasma 6 (Wayland), Login über greetd + tuigreet
- Kanal: `nixos-unstable` (Flake), Systemsprache Deutsch, Zeitzone Europe/Berlin

```
linux/nix/
├── flake.nix
├── hosts/g5/
│   ├── configuration.nix          # Boot, Netzwerk, Locale, User, Audio, Laptop
│   ├── hardware-configuration.nix # PLATZHALTER – install.sh ersetzt ihn
│   ├── nvidia.nix                 # Hybrid-Grafik + Boot-Eintrag „gaming“
│   ├── desktop.nix                # Plasma 6, greetd, Fonts, Tastatur
│   ├── apps.nix                   # Firefox, Vesktop, Telegram, Spotify
│   └── gaming.nix                 # Steam, GameMode, MangoHud
└── scripts/
    ├── install.sh                 # automatische Installation vom Live-ISO
    ├── rebuild.sh                 # Config anwenden / System aktualisieren
    ├── gpu-info.sh                # welcher Anschluss hängt an welcher GPU?
    └── monitors.sh                # eDP-1 + DP-2 (180 Hz, VRR) einrichten
```

## Installation

NixOS-ISO (Minimal oder Graphical) per USB booten – im **UEFI-Modus**, Secure Boot aus.
Netzwerk verbinden (WLAN: `nmtui`), dann:

```sh
git clone https://github.com/notflask/.config
sudo ./.config/linux/nix/scripts/install.sh /dev/nvme0n1
```

Plattenname vorher mit `lsblk` prüfen. Das Skript

1. **löscht die ganze Platte** (Bestätigung durch Eintippen des Namens) und legt
   1 GiB EFI + Rest ext4 an,
2. erzeugt `hardware-configuration.nix` und übernimmt `system.stateVersion`,
3. liest die PCI-Adressen der GPUs aus und trägt sie in `nvidia.nix` ein,
4. kopiert das Repo nach `/home/flask/.config`, installiert und fragt nach dem
   Passwort für `flask`.

**Dual-Boot / eigene Partitionen:** selbst partitionieren, Root nach `/mnt` und die
EFI-Partition nach `/mnt/boot` einhängen, dann `install.sh --mounted`.
Die Windows-EFI-Partition ist meist nur 100 MB – zu klein für mehrere NixOS-Generationen.
Besser eine eigene EFI-Partition mit ≥ 1 GiB anlegen.

Nach dem ersten Login `hardware-configuration.nix`, `nvidia.nix` und `flake.lock`
committen.

## Alltag

```sh
~/.config/linux/nix/scripts/rebuild.sh          # Config-Änderungen anwenden
~/.config/linux/nix/scripts/rebuild.sh update   # System aktualisieren
```

`rebuild.sh` bleibt im Boot-Eintrag „gaming“ automatisch im Gaming-Modus.

## Grafik: zwei Boot-Einträge

| Boot-Eintrag | KWin rendert auf | dGPU | Wofür |
|---|---|---|---|
| **NixOS** (Standard) | Intel iGPU | schläft im Leerlauf | Akku, Surfen, leise |
| **NixOS (gaming)** | RTX 4060 | immer an | am Netzteil, externer Monitor, CS2 |

**Warum zwei Modi?** Im Standardmodus zeichnet die Intel-GPU den Desktop. Ein Spiel
auf der NVIDIA muss jedes Bild erst zur Intel-GPU kopieren und bei einem Monitor am
NVIDIA-Anschluss wieder zurück. Das kostet FPS und bringt Latenz. Im Gaming-Modus
läuft KWin selbst auf der NVIDIA: das Spielbild geht direkt an den LG-Monitor, nur
der interne Bildschirm wird kopiert. Zusätzlich ist dort `thermald` aus und das
Energieprofil auf „Leistung“.

Standard-Eintrag ändern: im Bootmenü den Eintrag markieren und `d` drücken.

Einzelne Programme im Standardmodus auf der NVIDIA starten:

```sh
nvidia-offload <programm>
```

oder Rechtsklick im KDE-Startmenü → mit dedizierter Grafikkarte starten.

**Anschlüsse prüfen:** `scripts/gpu-info.sh` zeigt, welcher Anschluss an welcher GPU
hängt und ob die NVIDIA gerade schläft. Den LG-Monitor an einen **NVIDIA-Anschluss**
stecken (beim G5 KF typischerweise HDMI / Mini-DP; mit `gpu-info.sh` verifizieren).

## Bildschirme

Nach dem ersten Login in Plasma:

```sh
~/.config/linux/nix/scripts/monitors.sh
```

Setzt DP-2 auf 2560x1440 @ 180 Hz, VRR automatisch, primär, rechts neben eDP-1
(1920x1080 @ 144 Hz). Andere Anschlussnamen: `EXTERNAL=HDMI-A-1 monitors.sh`.
KDE merkt sich das pro Monitor-Kombination.

## CS2

Steam → CS2 → Eigenschaften → Startoptionen:

```
gamemoderun nvidia-offload %command%
```

- Im Boot-Eintrag **gaming** starten, Netzteil dran.
- Im Spiel: Vollbild, V-Sync aus, `fps_max` nach Geschmack.
- VRR (FreeSync/G-Sync Compatible) ist in `monitors.sh` auf „automatisch“.
- Für minimale Latenz: *Systemeinstellungen → Anzeige → Tearing erlauben* (optional).
- FPS/Frametimes messen: `mangohud gamemoderun nvidia-offload %command%`.

## Apps

| App | Hinweise |
|---|---|
| Firefox | VA-API-Videodekodierung (Intel im Standard, NVIDIA im Gaming-Modus), KDE-Dateidialog, KDE-Browserintegration. Prüfen: `about:support` → *Media* |
| Vesktop | Discord-Client; Bildschirmfreigabe unter Wayland über das KDE-Portal |
| Telegram | `telegram-desktop` |
| Spotify | Port 57621/TCP + mDNS offen für Spotify Connect im LAN |
| Steam | CS2 läuft nativ |

> ⚠️ `linux/.config/environment.d/environment.conf` setzt `LIBVA_DRIVER_NAME=nvidia`,
> `GBM_BACKEND=nvidia-drm` usw. global. Das bricht den Standardmodus (Firefox,
> Electron-Apps). **Nicht nach `~/.config/environment.d/` kopieren.**

## Tastatur

`us,ru,ua,de`, Umschalten mit Alt+Shift. Das ist der Standard für neue
Plasma-Profile. Falls Plasma ihn nicht übernimmt: *Systemeinstellungen → Tastatur → Belegungen*.
