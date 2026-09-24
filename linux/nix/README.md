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
│   ├── nvidia.nix                 # Grafik: Desktop auf der RTX 4060
│   ├── desktop.nix                # Plasma 6, greetd, Fonts, Tastatur
│   ├── apps.nix                   # Firefox, Vesktop, Telegram, Spotify
│   └── gaming.nix                 # Steam, GameMode, MangoHud, gamescope, Lutris
└── scripts/
    ├── install.sh                 # automatische Installation vom Live-ISO
    ├── rebuild.sh                 # Config anwenden / System aktualisieren
    ├── gpu-info.sh                # welcher Anschluss hängt an welcher GPU?
    ├── gaming-mode.sh             # Spiele-Starter (als Befehl `gaming-mode` installiert)
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

## Grafik

Das System ist auf maximale Leistung ausgelegt (Betrieb am Netzteil):

- **KWin (der Desktop) läuft auf der RTX 4060.** Das Spielbild geht direkt an den
  LG-Monitor, nur der interne Bildschirm (eDP-1, fest an der Intel-iGPU) wird kopiert.
  Läuft der Desktop dagegen auf der Intel-GPU, muss jedes Bild einmal hin und zurück
  kopiert werden. Das kostet FPS und bringt Latenz.
- Die dGPU ist immer an, Dynamic Boost verteilt die Leistung zwischen CPU und GPU.
- Energieprofil „Leistung“ ab dem Start, kein `thermald` (drosselt sonst zu früh).

Für Akku ist das nicht gedacht: die RTX 4060 frisst auch im Leerlauf Strom.

**Anschlüsse prüfen:** `scripts/gpu-info.sh` zeigt, welcher Anschluss an welcher GPU
hängt. Den LG-Monitor an einen **NVIDIA-Anschluss** stecken (beim G5 KF
typischerweise HDMI / Mini-DP; mit `gpu-info.sh` verifizieren).

## Bildschirme

Nach dem ersten Login in Plasma:

```sh
~/.config/linux/nix/scripts/monitors.sh
```

Setzt DP-2 auf 2560x1440 @ 180 Hz, VRR automatisch, primär, rechts neben eDP-1
(1920x1080 @ 144 Hz). Andere Anschlussnamen: `EXTERNAL=HDMI-A-1 monitors.sh`.
KDE merkt sich das pro Monitor-Kombination.

## Spiele starten: `gaming-mode`

`gaming-mode` ist ein Befehl (Quelle: `scripts/gaming-mode.sh`), der ein Spiel mit
allem startet, was es schnell macht:

| Was | Wozu |
|---|---|
| GameMode | CPU auf Leistung, höhere Priorität, Bildschirmsperre aus |
| NVIDIA-Variablen | Spiel läuft garantiert auf der RTX 4060 (Vulkan + OpenGL) |
| MangoHud | FPS, Frametimes, GPU/CPU-Last + Temperatur, RAM/VRAM – **Shift rechts + F12** blendet ein/aus |
| Shader-Cache 10 GB | weniger Ruckler durch Shader-Kompilierung, auch nach Updates |
| `PROTON_ENABLE_NVAPI=1` | DLSS / Reflex in Windows-Spielen über Proton |

```
gaming-mode %command%                    # Steam-Startoption, für jedes Spiel
gaming-mode --no-hud %command%           # ohne Overlay
gaming-mode --stretch 1920x1440 %command%  # gestreckt über gamescope
gaming-mode ./spiel                      # außerhalb von Steam
```

Eigenes MangoHud-Layout: `~/.config/MangoHud/MangoHud.conf` anlegen – dann wird
das eingebaute Layout nicht benutzt.

Allgemein für alle Spiele: **Netzteil dran**, Vollbild, V-Sync im Spiel aus.
VRR ist über `monitors.sh` aktiv.

## CS2

Steam → CS2 → Eigenschaften → Startoptionen.

**Native Auflösung (2560x1440):**

```
gaming-mode %command% -fullscreen +fps_max 0
```

**Stretched 1920x1440 (4:3 auf 16:9 gestreckt):**

```
gaming-mode --stretch 1920x1440 %command% -fullscreen +fps_max 0
```

Im Spiel dann *Video → Seitenverhältnis 4:3, Auflösung 1920x1440*. gamescope
rendert das Spiel in 1920x1440 und streckt es auf den ganzen LG-Monitor – ohne
schwarze Ränder. Ohne gamescope geht das unter Wayland nicht, KDE würde Balken
anzeigen. Die Maus ist dabei fest im Spiel eingefangen (`--force-grab-cursor`).

**Tweaks:**

- `+fps_max 0` = ungebremst, niedrigste Latenz. Zusammen mit *Systemeinstellungen →
  Anzeige → Tearing erlauben* am schnellsten, dafür mit Tearing.
- Alternativ `+fps_max 175`: bleibt knapp unter 180 Hz im VRR-Bereich → kein
  Tearing, sehr gleichmäßig, minimal mehr Latenz.
- `-vulkan` brauchst du nicht (unter Linux Standard), `-high` und `-novid` wirken
  unter Linux bzw. in CS2 nicht – GameMode übernimmt die Priorität.
- gamescope kostet etwas Leistung. Wenn du die FPS vergleichen willst: MangoHud
  zeigt sie in beiden Varianten an.
- Die ersten Runden nach einem Update können kurz ruckeln (Shader werden gebaut),
  danach greift der Cache.

## Diablo IV

Normale Auflösung, kein Stretched.

**Steam-Version:**

1. Steam → Diablo IV → Eigenschaften → *Kompatibilität* → Proton erzwingen,
   **Proton Experimental** oder **GE-Proton** (ist installiert).
2. Startoptionen:
   ```
   gaming-mode %command%
   ```
3. Im Spiel: Vollbild, 2560x1440, **DLSS** auf *Qualität* (funktioniert dank NVAPI).
   Die RTX 4060 hat 8 GB VRAM → Texturqualität *Hoch* statt *Ultra*, sonst
   gibt es Nachladeruckler.

**Battle.net-Version:** In Lutris den Battle.net-Installer hinzufügen und Diablo IV
darüber installieren. Danach in Lutris beim Battle.net-Eintrag unter
*Konfigurieren → Systemoptionen → Befehlspräfix* `gaming-mode` eintragen.

Der erste Start dauert länger (Shader-Kompilierung, DirectX 12 → Vulkan), danach
läuft es aus dem Cache.

## Apps

| App | Hinweise |
|---|---|
| Firefox | VA-API-Videodekodierung über NVIDIA, KDE-Dateidialog, KDE-Browserintegration. Prüfen: `about:support` → *Media* |
| Vesktop | Discord-Client; Bildschirmfreigabe unter Wayland über das KDE-Portal |
| Telegram | `telegram-desktop` |
| Spotify | Port 57621/TCP + mDNS offen für Spotify Connect im LAN |
| Steam | CS2 nativ, Diablo IV über Proton / GE-Proton |
| Lutris | Battle.net und andere Launcher |

> ⚠️ `linux/.config/environment.d/environment.conf` **nicht** nach
> `~/.config/environment.d/` kopieren: Die Datei setzt Pfade einer normalen Distro
> (`/usr/share/...`, `XDG_DATA_DIRS`), die es unter NixOS nicht gibt, und überschreibt
> damit die NixOS-Pfade. Alles Nötige für NVIDIA setzt `nvidia.nix`.

## Tastatur

`us,ru,ua,de`, Umschalten mit Alt+Shift. Das ist der Standard für neue
Plasma-Profile. Falls Plasma ihn nicht übernimmt: *Systemeinstellungen → Tastatur → Belegungen*.
