# NixOS – Gigabyte G5 KF

- Laptop: Intel i5-12500H (Iris Xe) + NVIDIA RTX 4060 Laptop, eDP-1 1080p@144 Hz
- Externer Monitor: LG UltraGear 2K, 1440p@180 Hz (DP-2)
- Desktop: **Niri** (Standard) und **Hyprland**, beide Wayland, ohne KDE Plasma. Login über ly (mit Schwarzem-Loch-Animation), Ladebildschirm mit Herstellerlogo beim Start. Farben aus dem Hintergrundbild, hell oder dunkel
- Kanal: `nixos-unstable` (Flake), Systemsprache Deutsch, Zeitzone Europe/Berlin

```
linux/nix/
├── flake.nix
├── hosts/g5/
│   ├── configuration.nix          # Boot, Netzwerk, Locale, User, Audio, Laptop
│   ├── hardware-configuration.nix # PLATZHALTER – install.sh ersetzt ihn
│   ├── nvidia.nix                 # Grafik: Desktop auf der RTX 4060
│   ├── desktop.nix                # Basis beider Sitzungen: Login, Portale, KWallet, KDE-Apps, mako, hypridle
│   ├── apps.nix                   # Firefox, Discord, Telegram, Spotify, ATAS X, Claude (Code/Desktop), agy
│   ├── gaming.nix                 # Steam, GameMode, MangoHud, gamescope, Lutris, Recorder, Flatpak
│   ├── performance.nix            # scx_lavd, NTSYNC, Split-Lock, Energieprofil
│   ├── network.nix                # TCP BBR, LAN ohne EEE, WLAN ohne Power-Save
│   ├── theme.nix                  # GTK/Qt-Grundlage (Farben: matugen), Cursor, Icons, TTY
│   ├── dotfiles.nix               # nvim/tmux/ghostty verlinken + Werkzeuge
│   ├── fonts.nix                  # Schriften: Dotfiles, Windows, alle Schriftsysteme
│   ├── niri.nix                   # Niri-Sitzung (Standard)
│   └── hyprland.nix               # Hyprland-Sitzung (UWSM, Übersicht-Plugin)
├── pkgs/claude-desktop/           # Claude Desktop (.deb → NixOS)
├── pkgs/atas-x/                   # ATAS X (Linux-Alpha → NixOS)
└── scripts/
    ├── install.sh                 # automatische Installation vom Live-ISO
    ├── rebuild.sh                 # Config anwenden / System aktualisieren
    ├── gpu-info.sh                # welcher Anschluss hängt an welcher GPU?
    ├── gaming-mode.sh             # Spiele-Starter (als Befehl `gaming-mode` installiert)
    ├── sober-setup.sh             # Sober: MangoHud, Shader-Cache (Befehl `sober-setup`)
    ├── wm.sh                      # `wm`: ein Befehl für Niri und Hyprland (Autostart, Reload, Bildschirme …)
    ├── update-claude-desktop.sh   # neueste Claude-Desktop-Version eintragen
    ├── update-atas-x.sh           # neueste ATAS-X-Version eintragen
    └── (Monitore stehen direkt in niri/config.kdl bzw. hypr/hyprland.lua)
```

## Installation

**Minimal-ISO** (nixos.org/download, x86_64) auf den Ventoy-Stick kopieren. Im BIOS
(meist F2) **Secure Boot aus**, über F12 den Stick im **UEFI-Modus** starten.
Mit LAN-Kabel ist das Netz sofort da (WLAN sonst: `nmtui`). Dann:

```sh
git clone https://github.com/notflask/.config dotfiles
sudo ./dotfiles/linux/nix/scripts/install.sh /dev/nvme0n1
```

Plattenname vorher mit `lsblk` prüfen. Das Skript

1. **löscht die ganze Platte** (Bestätigung durch Eintippen des Namens) und legt
   1 GiB EFI + Rest ext4 an,
2. erzeugt `hardware-configuration.nix` und übernimmt `system.stateVersion`,
3. liest die PCI-Adressen der GPUs aus und trägt sie in `nvidia.nix` ein,
4. kopiert das Repo nach `/home/flask/dotfiles`, installiert und fragt nach dem
   Passwort für `flask`.

**Dual-Boot / eigene Partitionen:** selbst partitionieren, Root nach `/mnt` und die
EFI-Partition nach `/mnt/boot` einhängen, dann `install.sh --mounted`.
Die Windows-EFI-Partition ist meist nur 100 MB – zu klein für mehrere NixOS-Generationen.
Besser eine eigene EFI-Partition mit ≥ 1 GiB anlegen.

Nach dem ersten Login die erzeugten Dateien ins Repo übernehmen:

```sh
cd ~/dotfiles
git add linux/nix
git commit -m "G5: hardware-configuration und flake.lock"
git push
```

## Alltag

```sh
rebuild          # Config-Änderungen anwenden
rebuild update   # System, Claude Desktop, ATAS X + Flatpaks aktualisieren
```

`rebuild` holt vorher neue Commits von GitHub (nur Fast-Forward; die von
`theme` erzeugten Farbdateien verwirft es dafür) und erzeugt danach das Theme
neu, wenn sich die Templates geändert haben. Ohne Pull:
`REBUILD_NO_PULL=1 rebuild`.

## Dotfiles

Das Repo liegt in `~/dotfiles`. Beim Booten werden diese Configs nach `~/.config`
verlinkt (`dotfiles.nix`):

| `~/.config/…` | → Repo |
|---|---|
| `nvim` | `linux/.config/nvim` |
| `sioyek` | `linux/.config/sioyek` (PDF-Betrachter für Typst/Mathe-Notizen) |
| `tmux` | `linux/.config/tmux` |
| `ghostty` | `linux/.config/ghostty` |
| `niri`, `hypr`, `waybar`, `rofi`, `mako`, `wlogout`, `matugen`, `waypaper` | für Niri und Hyprland |

Du bearbeitest die Dateien also direkt im Repo – Änderungen wirken sofort, `sync.sh`
erkennt die Links und überspringt sie. Weitere Configs verlinken: Namen in
`dotfiles.nix` unter `linked` ergänzen, `rebuild`, neu starten.
Existiert in `~/.config` schon ein echter Ordner mit dem Namen, wird er nicht
überschrieben – erst löschen.

**Neovim (LazyVim):** Compiler, tree-sitter, ripgrep, fd, lazygit, Node.js und cmake
sind installiert, `nix-ld` sorgt dafür, dass die von Mason geladenen Programme
(clangd usw.) laufen. Für vimtex fehlt nur noch eine TeX-Distribution – bei Bedarf
`texliveMedium` in `dotfiles.nix` ergänzen (einige GB groß).

**Typst (Mathe-Notizen):** `typst`, `tinymist` (Sprachserver) und `typstyle`
(Formatierer) kommen aus nixpkgs – Mason-Binaries laufen unter NixOS unzuverlässig.
Das LazyVim-Extra `lang.typst` (`lazyvim.json`) liefert Syntax, Diagnose und
Browser-Vorschau; `nvim/lua/plugins/typst.lua` stellt tinymist ein.

| Taste (in `.typ`) | Wirkung |
|---|---|
| Speichern (`:w`) | tinymist schreibt `datei.pdf` neben die Quelle; sioyek lädt sie selbst neu |
| `<leader>co` | PDF in sioyek öffnen (`should_launch_new_window 0`: ein Fenster, mit gleicher Seite) |
| `<leader>cp` / `<leader>cP` | Browser-Vorschau / Hauptdatei festlegen (Extra) |

Sioyek: Config in `sioyek/prefs_user.config` (dunkle PDFs, sanftes Scrollen),
Tasten in `keys_user.config` (Strg+D / Strg+U = halbe Seite).
Beim ersten `nvim` installiert Lazy die Typst-Plugins und ändert `lazy-lock.json`.


## Schriften (`fonts.nix`)

| Gruppe | Schriften |
|---|---|
| Aus deinen Dotfiles | Inter, JetBrains Mono (+ Nerd Font), IBM Plex Sans/Mono, Fira Code, Nerd-Font-Symbole |
| Windows | Arial, Times New Roman, Courier New, Verdana, Georgia, Tahoma, Trebuchet, Comic Sans, Impact, Webdings, Calibri, Cambria, Consolas, Candara, Constantia, Corbel |
| Alle Schriftsysteme | Noto (Latein, Kyrillisch, Griechisch, Arabisch, Hebräisch, Indisch, Thai …), Noto CJK (Chinesisch, Japanisch, Koreanisch), Amiri (Arabisch), Vazirmatn (Persisch), Noto Color Emoji |

Standard: Noto Sans / Noto Serif, Monospace JetBrains Mono – für fehlende Zeichen
springen automatisch Noto CJK, Noto Arabic, Nerd-Font-Symbole und Emoji ein.

Nicht dabei sind Schriften, die Microsoft nicht frei herausgibt (z. B. Segoe UI,
Microsoft YaHei, SimSun) – Noto deckt dieselben Sprachen ab.

## Niri und Hyprland

KDE Plasma ist entfernt. Es gibt zwei Sitzungen mit denselben Programmen,
Farben und Tastenkürzeln:

- **Niri** (Standard): Fenster als Spalten auf einem endlos scrollbaren Band.
  Config: `linux/.config/niri/config.kdl`
- **Hyprland**: klassisches Tiling (dwindle), jedes neue Fenster teilt das
  aktive, alles bleibt sichtbar. Config: `linux/.config/hypr/hyprland.lua`
  (seit Hyprland 0.55 in Lua, nicht mehr `hyprland.conf`)

**Wechseln:** im Login (ly) mit ↑/↓ in die Sitzungszeile, dann mit **←/→**
*Niri* oder *Hyprland (uwsm-managed)* wählen. ly merkt sich Benutzer und Sitzung.
F1 schaltet aus, F2 startet neu. Die Animation läuft auf der Textkonsole und hat
dort nur 16 Farben.

### Tastenkürzel (in beiden gleich)

| Taste | Aktion |
|---|---|
| Super+T | Ghostty |
| Super+D / Super+Leertaste | Rofi (Apps starten) |
| Super+O | Übersicht (Hyprland: Plugin *hyprtasking*, Rechtsklick wählt die Arbeitsfläche) |
| Super+Q | Fenster schließen |
| Super+Pfeile / H J K L | Fokus (hoch/runter am Rand: nächste Arbeitsfläche) |
| Super+Strg+Pfeile / H J K L | Fenster verschieben (hoch/runter am Rand: auf die nächste Arbeitsfläche) |
| Super+Home / End (+Strg) | Fokus auf erste/letzte Spalte (Fenster dorthin) |
| Super+Shift+Pfeile / H J K | Fokus auf anderen Monitor (Super+Shift+Strg: Fenster mitnehmen) |
| Super+1…9, Super+Strg+1…9 | Arbeitsfläche wechseln / Fenster dorthin |
| Super+U / I, Bild↓ / Bild↑, Super+Mausrad | nächste / vorige Arbeitsfläche (+Strg: Fenster mitnehmen, +Shift: Arbeitsfläche verschieben) |
| Super+[ / ], Super+, / . | Fenster in Spalte bzw. Tabs aufnehmen / herauslösen |
| Super+R, Super+Shift+R, Super+Strg+Shift+R | Breiten ⅓ → ½ → ⅔ durchschalten (Super+Strg+R: zurück) |
| Super+E | alle Fenster gleichmäßig aufteilen |
| Super+F / Super+M / Super+Strg+F / Super+Shift+F | maximieren / Vollbild |
| Super+C, Super+Strg+C | zentrieren |
| Super+Minus / Gleich (+Shift) | schmaler / breiter (niedriger / höher) |
| Super+V / Super+Shift+V | schwebend ↔ gekachelt / Fokus dazwischen wechseln |
| Super+W | Tabs |
| Super+Shift+S | Screenshot mit Zeichnen (Satty, siehe *Screenshots*) |
| Druck | Screenshot eines Bereichs → Clipboard + `~/Screenshots` |
| Super+Shift+L | Sperren (Hyprlock) |
| Super+Strg+V | Zwischenablage-Verlauf (Enter: kopieren, Shift+Entf: löschen) |
| Super+Shift+E | Ausschalt-Menü (wlogout: Sperren, Abmelden, Standby, Neustart, Aus) |
| Alt+Tab / Alt+Shift+Tab | Fenster wechseln (Hyprland: hyprshell mit Vorschau) |
| Super+Shift+/ | wichtige Tastenkürzel |

`hypr/hyprland.lua` ist eine 1:1-Übersetzung von `niri/config.kdl`: gleiche
Reihenfolge, gleiche Tasten, gleiche Regeln. Weil Hyprland keine Spalten hat
(dwindle), wirken Spalten-Aktionen dort auf das Fenster bzw. die Teilung:
Breiten-Presets stellen die Teilung auf ⅓/½/⅔, Tab-Spalten sind
Fenstergruppen mit Tabs, „erste/letzte Spalte“ ist das Fenster ganz links/rechts.
Nur die Tasten fürs Bildschirmteilen (Super+Strg+Shift+F/M/C) gibt es in
Hyprland nicht – dort fragt Hyprland beim Teilen, was gesendet wird.
Rundung: Hyprland erlaubt höchstens 20 statt 24 px.

### Gemeinsam in beiden

- Waybar, Rofi, mako (Benachrichtigungen), wlogout (Power-Knopf), Satty,
  Zwischenablage mit Verlauf (cliphist), EasyEffects.
- Animationen: Niris Standard (Federn für Fenster und Arbeitsflächen,
  Öffnen/Schließen in 150 ms), Leisten und Menüs ohne Animation.
- Hintergrundbild über **Waypaper** aus `~/Wallpapers`. Matugen färbt daraus
  alles passend ein, siehe *Theme*.
- Passwortabfragen über den KDE-Polkit-Agenten, gespeicherte Logins in
  **KWallet** (wird beim Login mit dem Passwort entsperrt), KDE-Dateidialog.
- Programme mit „Beim Login starten“ (Autostart) laufen in beiden Sitzungen,
  ebenso der GPU Screen Recorder.
- X11-Programme (Steam, viele Spiele): Niri startet dafür xwayland-satellite,
  Hyprland hat XWayland eingebaut.
- Monitore stehen in der jeweiligen Config (eDP-1 144 Hz, DP-2 180 Hz). VRR auf
  dem LG ist nur für Spiele aktiv.

### Auto-Sperre (hypridle)

Nach 5 Minuten ohne Eingabe wird der interne Bildschirm dunkler, nach
10 Minuten wird gesperrt, nach 11 Minuten gehen die Bildschirme aus. Das
passiert nicht, solange ein Video läuft oder gespielt wird. Vor dem Standby
wird immer gesperrt.
Zeiten ändern: `linux/.config/hypr/hypridle.conf`, danach
`systemctl --user restart hypridle`.

### KDE-Apps ohne Plasma

Dolphin (Dateien), Gwenview (Bilder), Okular (PDF), Ark (Archive), Filelight
und die KWallet-Verwaltung sind einzeln installiert. Sie sind Standard für
Ordner, Bilder, PDFs und Archive. USB-Sticks und Handys (MTP) lassen sich in
Dolphin einhängen. *Terminal hier öffnen* startet Ghostty.
Bluetooth: Symbol im Tray (Blueman) bzw. *Bluetooth-Manager* über Rofi.

## Grafik

Das System ist auf maximale Leistung ausgelegt (Betrieb am Netzteil):

- **Der Desktop (Niri bzw. Hyprland) läuft auf der RTX 4060.** Das Spielbild geht direkt an den
  LG-Monitor, nur der interne Bildschirm (eDP-1, fest an der Intel-iGPU) wird kopiert.
  Läuft der Desktop dagegen auf der Intel-GPU, muss jedes Bild einmal hin und zurück
  kopiert werden. Das kostet FPS und bringt Latenz.
- Die dGPU ist immer an, Dynamic Boost verteilt die Leistung zwischen CPU und GPU.
- Energieprofil „Leistung“ ab dem Start, kein `thermald` (drosselt sonst zu früh).

Für Akku ist das nicht gedacht: die RTX 4060 frisst auch im Leerlauf Strom.

**Anschlüsse prüfen:** `gpu-info` zeigt, welcher Anschluss an welcher GPU
hängt. Den LG-Monitor an einen **NVIDIA-Anschluss** stecken (beim G5 KF
typischerweise HDMI / Mini-DP; mit `gpu-info` verifizieren).

## Bildschirme

Die Monitore stehen direkt in den Configs, ein eigenes Skript braucht es
nicht mehr:

- Niri: `output`-Blöcke in `linux/.config/niri/config.kdl`
- Hyprland: `hl.monitor(...)` in `linux/.config/hypr/hyprland.lua`

Beide: DP-2 mit 2560x1440 @ 180 Hz rechts neben eDP-1 (1920x1080 @ 144 Hz),
VRR auf DP-2 nur für Spiele. Anschlussnamen anzeigen: `niri msg outputs`
bzw. `hyprctl monitors`.

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
gaming-mode --stretch 1920x1440 %command%  # gestreckt über gamescope (CS2: siehe unten)
gaming-mode ./spiel                      # außerhalb von Steam
```

MangoHud-Layout: `linux/.config/matugen/templates/MangoHud.conf` (Farben vom
Hintergrundbild, erzeugt nach `~/.config/MangoHud/MangoHud.conf`). Oben links als
Glas-Tabelle: FPS mit Ampelfarbe, Durchschnitt und 1%-Low, Frametime-Graph,
GPU/CPU mit Last, Temperatur, Takt, Verbrauch, VRAM/RAM, dazu Drosselung,
GameMode, NTSYNC und VSync/Tearing. **Shift rechts + F9** setzt Durchschnitt
und 1%-Low zurück.

Allgemein für alle Spiele: **Netzteil dran**, Vollbild, V-Sync im Spiel aus.
VRR schalten Niri und Hyprland für Spiele automatisch ein.

## CS2

Steam → CS2 → Eigenschaften → Startoptionen.

**Native Auflösung (2560x1440):**

```
gaming-mode %command% -fullscreen +fps_max 0
```

**Stretched 1920x1440 (4:3 auf 16:9 gestreckt):**

```
SDL_VIDEO_DRIVER=wayland SDL_VIDEO_WAYLAND_MODE_SCALING=stretch gaming-mode %command% -fullscreen +fps_max 0
```

Im Spiel dann *Video → Seitenverhältnis 4:3, Auflösung 1920x1440*. CS2 läuft
damit direkt als Wayland-App, und seine SDL-Bibliothek (SDL 3) streckt die
1920x1440 selbst auf den ganzen LG-Monitor – ohne schwarze Ränder und ohne
gamescope. Einziger Nachteil: kein Steam-Overlay.

`gaming-mode --stretch 1920x1440` (über gamescope) geht auch, aber unter Niri
flackert das Bild dort ab und zu – ohne gamescope nicht.

Unter Hyprland öffnen Spiele auf einer eigenen leeren Arbeitsfläche
(Regel `games-own-workspace`): Alt+Tab wechselt dann nur die Fläche, statt
dem Spiel das Vollbild zu nehmen – sonst fällt Stretched auf Fenstermodus
zurück und das Spiel wird gekachelt. Damit der Zeiger dabei nicht auf den
Laptop-Bildschirm rutscht, hält `games-confine-pointer` ihn im Spiel, solange
es den Fokus hat.

Die Spiele-Regeln greifen über den Fensternamen (`cs2`, `steam_app_…`,
`gamescope`, Sober). Unter Hyprland zeigt `hyprctl clients` die Namen,
unter Niri `niri msg windows`.

**Tweaks:**

- `+fps_max 0` = ungebremst, niedrigste Latenz. **Unter Hyprland** darf CS2
  dabei tearen (Fensterregel `cs2-tearing`) – am schnellsten, dafür mit
  Bildrissen über 180 FPS. Niri kennt kein Tearing.
- Alternativ `+fps_max 175`: bleibt knapp unter 180 Hz im VRR-Bereich → kein
  Tearing, sehr gleichmäßig, minimal mehr Latenz.
- `-vulkan` brauchst du nicht (unter Linux Standard), `-high` und `-novid` wirken
  unter Linux bzw. in CS2 nicht – GameMode übernimmt die Priorität.
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

## Screenshots

**Super+Shift+S** → Bereich mit der Maus aufziehen → in **Satty** zeichnen
(Pfeil, Linie, Rechteck, Ellipse, Text, Marker, Freihand, Nummern, Verpixeln,
Zuschneiden) → **Enter** (oder *Kopieren*) kopiert ins Clipboard **und**
speichert nach `~/Screenshots`, dann schließt Satty. **Esc** bricht ab.

**Druck** ohne Zeichnen: Niri öffnet seine eingebaute Auswahl, unter Hyprland
wird ein Bereich aufgezogen – beides landet im Clipboard und in `~/Screenshots`.

## Roblox: Sober

[Sober](https://sober.vinegarhq.org) ist ein inoffizieller Roblox-Client für Linux und
gibt es nur als Flatpak. Flatpak ist aktiviert, Sober einmalig installieren:

```sh
flatpak remote-add --user --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
flatpak install --user -y flathub org.vinegarhq.Sober
```

Danach im Startmenü *Sober* öffnen und mit dem Roblox-Konto anmelden.

**OpenGL statt Vulkan einschalten** (Rechtsklick auf Sober im Startmenü →
*Settings*, oder `"use_opengl": true` in
`~/.var/app/org.vinegarhq.Sober/config/sober/config.json`): Mit Vulkan kann man
unter Niri mit NVIDIA nirgends tippen (Chat, Suche), siehe niri-wm/niri#2682.
Über X11 (`--socket=x11`) ginge das Tippen auch, bringt aber beim Laden
Ruckler bis hin zum Mauszeiger. Der erste Start nach dem Umstellen ruckelt
kurz, bis der Shader-Cache gebaut ist.
Aktualisiert wird Sober mit `rebuild update` (bzw. `flatpak update`).

**Einmalig danach: `sober-setup`** (Benutzerebene, kein sudo, wiederholbar). Es

- installiert die Flatpak-Erweiterung `org.freedesktop.Platform.VulkanLayer.MangoHud//25.08`
  und setzt die Overrides für MangoHud (Ein-/Ausblenden: Shift rechts + F12),
- schaltet den NVIDIA-Shader-Cache auf 4 GB ohne automatisches Aufräumen
  (Roblox kompiliert sonst nach Cache-Bereinigung Shader neu → Ruckler),
- gibt Sober den Discord-Socket („Spielt Roblox“),
- kopiert `MangoHud.conf` in die Sandbox; `theme.sh` hält die Kopie bei
  Themenwechsel aktuell.

`sober-setup off` setzt die Overrides zurück, `sober-setup status` zeigt sie.
GameMode ist in Sober schon an (`enable_gamemode`).

Das HUD ist immer dunkel mit heller Schrift (auch im Hellmodus), weil es über dem
Spiel liegt, nicht über dem Desktop.

Da Sober inoffiziell ist, kann ein Roblox-Update es zeitweise kaputt machen – dann auf
ein Sober-Update warten.

## KI-Coding-Tools

| Befehl | Programm | Erster Start |
|---|---|---|
| `claude` | Claude Code | `claude` → im Browser mit dem Claude-Konto anmelden |
| `agy` | Antigravity CLI (Google) | `agy` → mit dem Google-Konto anmelden |

Beide werden über `rebuild update` aktualisiert, nicht über ihre eigenen Updater.

## Claude Desktop

Die offizielle Linux-Beta von Anthropic gibt es nur als `.deb` für Ubuntu/Debian.
`pkgs/claude-desktop/` verpackt genau dieses `.deb` für NixOS: Es läuft in einer
FHS-Umgebung, die für die App wie Ubuntu aussieht – dadurch funktionieren auch die
mitgelieferten Teile (Claude Code, Cowork) unverändert.

- Starten: *Claude* im Startmenü oder `claude-desktop`, dann mit dem Claude-Konto anmelden.
- **Updates:** `rebuild update` holt automatisch die neueste Version aus Anthropics
  Paketquelle (`scripts/update-claude-desktop.sh` schreibt `pkgs/claude-desktop/source.json`).
- **Cowork** (Aufgaben in einer VM): QEMU, virtiofsd und UEFI-Firmware sind dabei, du bist
  in der Gruppe `kvm`, `vhost_vsock` wird geladen. Im BIOS muss **Intel VT-x**
  (Virtualisierung) aktiv sein.
- Nicht in der Linux-Beta (von Anthropic): Computer Use, Diktieren.

## ATAS X

Offiziell gibt es ATAS X nur für Windows und macOS. Auf ATAS' Update-Server liegt
aber ein Linux-Build im Alpha-Kanal (`platformx_linux_alpha`, .NET 10 + Avalonia).
`pkgs/atas-x/` verpackt ihn unverändert und startet ihn mit der .NET-Laufzeit aus nixpkgs.

- Starten: *ATAS X* im Startmenü oder `atas-x`, dann mit dem ATAS-Konto anmelden.
- Einstellungen, Workspaces, Datenbank und Logs liegen in `~/.config/ATAS/`.
- Der Starter setzt `TZDIR`, falls die Sitzung es nicht tut (Hyprland/UWSM):
  Ohne findet .NET unter NixOS keine Zeitzonen, und ATAS stürzt nach dem Login ab.
- **Updates:** `rebuild update` holt den neuesten Linux-Build
  (`scripts/update-atas-x.sh` schreibt `pkgs/atas-x/source.json`). Der eingebaute
  Updater kann im schreibgeschützten Nix-Store nichts ändern.
- Der Linux-Build hinkt der Windows-Beta hinterher und wird von ATAS nicht
  unterstützt. Läuft über XWayland (in Niri über xwayland-satellite).
- **Grafik:** Oberfläche und Charts zeichnen per OpenGL (GLX). Der Starter
  (`apps.nix`) legt beides fest auf die RTX 4060 (wie `nvidia-offload`), sonst
  fällt Avalonia unbemerkt auf CPU-Rendering zurück. Prüfen: Läuft ATAS X, steht
  „ATAS X“ in `nvidia-smi`.
- **Bildrate:** Avalonia rendert unter X11 fest mit 60 fps. Das Paket setzt den
  Wert beim Bauen auf 120 fps (`pkgs/atas-x/raise-frame-rate.py`, mehr lässt die
  Stelle im Code nicht zu). Die Charts sind davon unabhängig und laufen mit VSync
  im Takt des Monitors.

## Aufnahme & Replay: GPU Screen Recorder

Wie ShadowPlay: startet beim Login im Hintergrund, **Alt+Z** öffnet das Overlay.
Aufgenommen wird über den Video-Encoder der RTX 4060 (NVENC) – das kostet praktisch
keine FPS.

- **Replay** (die letzten X Sekunden rückwirkend speichern): im Overlay *Replay*
  einschalten, Länge und Qualität einstellen. Ab dann läuft es im Hintergrund mit,
  per Hotkey speicherst du den Clip.
- **Aufnahme** und **Streaming** ebenfalls über das Overlay.
- Alle Hotkeys stehen im Overlay unter *Einstellungen* (Symbol rechts) und lassen
  sich dort ändern.
- Beim ersten Mal fragt das System eventuell, welcher Bildschirm aufgenommen werden darf.

Clips landen standardmäßig in `~/Videos`.

## Leistungs-Tweaks (`performance.nix`)

| Tweak | Wirkung |
|---|---|
| **scx_lavd** (CPU-Scheduler, `--performance`) | für Gaming gebaut (Steam Deck), soll Ruckler reduzieren, wenn nebenbei Discord/Firefox laufen |
| **NTSYNC** | schnellere Synchronisation für Windows-Spiele unter Proton (Diablo IV), bessere Frametimes |
| **Split-Lock-Bremse aus** | wie SteamOS – verhindert starke Ruckler in einzelnen Windows-Spielen |
| **Energieprofil „Leistung“** | ab dem Start aktiv |
| **Speicher** (zram-Tuning, Schreib-Puffer 256 MB, keine Hintergrund-Kompaktierung) | keine Hänger, wenn RAM knapp wird oder Steam/Shader-Caches viel schreiben |
| **NVIDIA PAT** (`NVreg_UsePageAttributeTable=1`) | schnellerer Zugriff der CPU auf den Grafikspeicher |
| **i915 in der initrd** | Intel-Treiber vor NVIDIA → keine minutenlangen Hänger von Electron-Apps nach dem Start |
| **`noatime`** | keine Schreibzugriffe beim bloßen Lesen |
| **Waybar ohne Polling** | Energieprofil per D-Bus statt alle 2 s `powerprofilesctl`, VPN-Status ohne `sudo` alle 5 s |

`scx_lavd` ist auf Intel-CPUs mit P- und E-Kernen nicht immer besser. Vergleiche
mit MangoHud (FPS und 1%-Lows): in `performance.nix` `services.scx.enable = false`
setzen, `rebuild`, nochmal testen. Status prüfen: `systemctl status scx`.

**Außerhalb der Config, aber wichtig:**
- **RAM im Dual-Channel?** `sudo dmidecode -t memory` – bei nur einem Riegel verliert
  CS2 sehr viele FPS. Ein zweiter gleicher Riegel ist dann das beste Upgrade.
- **Kühlung:** Laptop hinten erhöht aufstellen, Lüfter ab und zu reinigen.

## Theme: Farben aus dem Hintergrundbild

**Matugen** erzeugt aus dem Wallpaper ein Farbschema und färbt damit alles:
Fensterrahmen (Niri und Hyprland), Waybar, Rofi, mako, Sperrbildschirm,
**die Apps** – wahlweise **hell oder dunkel**:

| Bereich | Wie |
|---|---|
| GTK-Apps (Firefox u. a.) | Thema *adw-gtk3* / *adw-gtk3-dark* bzw. libadwaita, Farben in `~/.config/gtk-3.0/gtk.css` und `gtk-4.0/gtk.css` |
| Qt- und KDE-Apps (Dolphin, Okular …) | Breeze-Stil, Farben in `~/.config/kdeglobals` |
| Cursor | macOS (`pkgs.apple-cursor`, fest – folgt dem Wallpaper nicht); Wechsel zu `macOS-White` über `cursorTheme` in `theme.nix`, `hyprland.lua`, `niri/config.kdl` |
| Icons | Papirus-Light bzw. Papirus-Dark |
| Discord (Vencord) | `matugen.theme.css` (Aufbau von *midnight*) → `theme.sh` trägt es selbst unter „aktive Themes“ ein (läuft Discord, einmal neu starten) |
| Spotify | Spicetify, Spotifys eigenes Layout, Farben von matugen und Korrekturen für den Hellmodus (festes Weiß in Spotifys CSS ersetzt) – live per Symlink + Extension (`apps.nix`) |
| Firefox | Pywalfox (Farben + hell/dunkel), Webseiten folgen hell/dunkel |
| Ghostty, Neovim | hell *Solarized Osaka Light* ([craftzdog/solarized-osaka.nvim](https://github.com/craftzdog/solarized-osaka.nvim)), dunkel *Vague* (schwarzer Hintergrund) – schalten mit um |
| TTY, Login (ly), Ladebildschirm | Farben von Vague bzw. Plymouth *bgrt* (Herstellerlogo) – fest |

**Wallpaper wechseln:** in Waypaper ein Bild wählen – danach läuft automatisch
`theme` (`linux/.config/matugen/theme.sh`). Qt-Apps, Waybar, mako, die
Rahmen und Hell/Dunkel passen sich sofort an. Laufende GTK-Apps übernehmen neue Farben nach einem Neustart.

**Hell/dunkel:** Klick auf Sonne/Mond in der Waybar schaltet um. Der Modus
bleibt gespeichert (`~/.local/state/theme-mode`) und gilt auch für jedes
neue Wallpaper.

```sh
theme                 # Farben aus dem aktuellen Wallpaper neu erzeugen
theme -m light        # hell (bleibt so), -m dark dunkel
theme -T              # hell ↔ dunkel
theme -t vibrant      # kräftigere Variante (auch: expressive, fidelity, …)
theme -s BILD         # mögliche Quellfarben eines Bildes anzeigen
```

Beim ersten Login nach einer Umstellung läuft `theme` einmal von selbst.

**Apps mit eigenem Theme-System:**
- **Telegram:** *Einstellungen → Chat-Einstellungen → Theme*.
- **Steam:** eigener Skin, bleibt dunkel wie gewohnt.

## Apps

| App | Hinweise |
|---|---|
| Firefox | VA-API-Videodekodierung über NVIDIA, KDE-Dateidialog. Prüfen: `about:support` → *Media* |
| Dolphin, Gwenview, Okular, Ark, Filelight | KDE-Apps ohne Plasma (Dateien, Bilder, PDF, Archive, Speicherplatz) |
| Discord | Offizieller Client mit Vencord; Anrufe über Discords eigene Engine wie unter Windows |
| Telegram | `telegram-desktop` |
| Spotify | Port 57621/TCP + mDNS offen für Spotify Connect im LAN |
| Steam | CS2 nativ, Diablo IV über Proton / GE-Proton |
| Lutris | Battle.net und andere Launcher |
| GPU Screen Recorder | Aufnahme, Replay, Streaming – Alt+Z |
| Sober | Roblox (Flatpak) |
| Claude Code, Antigravity CLI | `claude`, `agy` im Terminal |
| Claude Desktop | Linux-Beta, aus dem offiziellen `.deb` |
| ATAS X | Orderflow-Analyse, Linux-Alpha von ATAS' Update-Server |

## Tastatur

`us,ru,ua,de`, Umschalten mit Alt+Shift. Steht in beiden Configs
(`niri/config.kdl`, `hypr/hyprland.lua`), Waybar zeigt das aktive Layout.

## Umstieg von KDE

Nach dem ersten `rebuild` mit dieser Config:

1. **Einmal neu starten** – UWSM (für Hyprland) stellt D-Bus auf dbus-broker um.
2. Im Login (jetzt ly) einmal die Sitzung mit ←/→ wählen.
3. Alte KDE-Einstellungen in `~/.config` (z. B. `plasma*`, `kwinrc`,
   `kglobalshortcutsrc`) stören nicht und können gelöscht werden.
   `~/.config/kdeglobals` überschreibt matugen.
