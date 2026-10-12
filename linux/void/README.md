# Void Linux – Gigabyte G5 KF (MangoWC)

Dieselben Apps und Einstellungen wie unter NixOS (`linux/nix`), aber auf
**Void Linux** (glibc, runit statt systemd) und mit **MangoWC** als
Fenstermanager.

- Laptop: Intel i5-12500H (Iris Xe) + NVIDIA RTX 4060 Laptop, eDP-1 1080p@144 Hz
- Externer Monitor: LG UltraGear 2K, 1440p@180 Hz (DP-2)
- Desktop: **MangoWC**: wie dwm (Tags 1–9, Layouts zum Umschalten), dazu ein
  Scroll-Layout wie Niri. Login über greetd/tuigreet
- Stil: **anders als unter NixOS, ganz minimal**: eckige Fenster mit 1px-Rahmen,
  keine Effekte, keine Animationen, schmale Textleiste oben, großes Void-Logo
  in fastfetch. Das Wallpaper ist die einzige Deko, und die Farben kommen wie
  gehabt daraus (matugen), hell oder dunkel
- Kernel: `linux-mainline` (neuester, wie bei Arch). Der normale `linux`
  bleibt als Rückfall im Boot-Menü

> **Stand:** Diese Konfiguration ist auf echter Hardware noch nicht
> gestartet worden. Geprüft wurde sie in einem Void-chroot: Alle Pakete
> lösen sich in den offiziellen Repos auf, und die MangoWC-Config besteht
> `mango -p`. Alle Skripte bestehen shellcheck, die eigenen Rezepte `xlint`.
> Beim ersten Start also dabeibleiben und `~/.local/state/mango.log` im Auge behalten.

## Warum MangoWC?

| | |
|---|---|
| **Wie dwm, aber Wayland** | MangoWC ist ein Fork von dwl („dwm für Wayland“): Tags statt Arbeitsflächen, mehrere Tags gleichzeitig ansehen, Layouts per Taste |
| **Wie Niri** | Das Standard-Layout ist `scroller`: Neue Fenster kommen rechts daneben, man scrollt durch |
| **Gaming** | Tearing für Spiele (`allow_tearing`, CS2 wie unter Hyprland), VRR nur im Vollbild, explizite Synchronisation (`syncobj`), Direct Scanout, Maus bleibt im Spiel. Ohne Effekte bleibt die GPU ganz fürs Spiel |
| **In Void** | Offizielles Paket `mangowc`. Hyprland gibt es bei Void nicht, niri schon (bleibt aber außen vor) |

NVIDIA: MangoWC baut wie Sway/SwayFX auf wlroots auf. Dass Sway NVIDIA als
„unsupported“ bezeichnet, ist eine Haltung der Sway-Entwickler, keine
technische Sperre: Mit dem 595er-Treiber (offene Module, GBM, explizite
Synchronisation) läuft wlroots auf NVIDIA. MangoWC verweigert den Start nicht.

```
linux/void/
├── README.md
├── setup.sh            # einrichten bzw. auf den Stand im Repo bringen (wie nixos-rebuild)
├── update.sh           # Befehl `update`: Pull, neue Versionen, setup.sh, Flatpak
├── update-sources.sh   # neue Versionen von Claude Desktop, ATAS X, HaruNeko, TradingView, Warp
├── packages.txt        # Pakete aus den Void-Repos (nach NixOS-Modulen sortiert)
├── srcpkgs/            # eigene xbps-src-Rezepte (alles, was Void nicht hat)
├── sv/                 # runit-Dienste: VPN, scx, Control Center, Leistung
├── sbin/               # root-Hilfsprogramme: Firewall, Kill-Switch, Sperre, Split-Tunneling
├── bin/                # Befehle: mango-session, vpn, novpn, scratch-term, screenshot …
├── etc/                # wird nach /etc kopiert (sysctl, udev, greetd, sudoers, Firefox …)
└── usr/                # wird nach /usr kopiert (Firefox-Vorgaben, Standby-Hook)
```

Gemeinsam mit NixOS (`linux/.config`): nvim, Ghostty, matugen, Rofi, mako …,
dazu `linux/nix/scripts/wm.sh` (der Befehl `wm` kann jetzt Niri, Hyprland und
MangoWC) und `vpn-split.sh`. Nur für Void (der minimale Stil):

| Datei | |
|---|---|
| `mango/config.conf` | MangoWC: eckig, 1px, keine Effekte/Animationen |
| `quickshell/minibar/` | Textleiste oben: Tags (I II III …), Layout, Fenstertitel; rechts Tray, Tastatur, VPN, Lautstärke, Akku, Uhr |
| `rofi/flat.rasi` | Starter und Ausschalt-Menü (`power-menu`) als eckiger Kasten |
| `matugen/templates/mako-flat.ini` | Benachrichtigungen flach (→ `mako/config-flat`) |
| `matugen/templates/gtklock.css` | Sperrbildschirm: Uhr auf dem Wallpaper, eckiges Passwortfeld |
| `fastfetch/void.jsonc` | großes Void-Logo, mehr Zeilen |
| `swayidle/config` | Auto-Sperre wie hypridle.conf |

Die Leiste in `quickshell/minibar`: Tag anklicken wechselt, Mausrad blättert;
„vpn“ grün/gelb/rot, Klick verbindet bzw. trennt, „VPN AUS“ heißt Internet ohne
VPN; Lautstärke: Mausrad ändert, Klick stumm, Rechtsklick pavucontrol; Tray:
Linksklick App, Rechtsklick Menü.

Für den Look wie in den Videos: Terminals mit `fastfetch`, `cmatrix -b` oder
`tty-clock -c` über ein stimmungsvolles Foto als Wallpaper (Waypaper). Die Farben
von Rahmen, Leiste und Menüs ziehen beim Wechsel mit.

## Installation

1. **Void installieren**: ISO `void-live-x86_64-*-base.iso` (**glibc**, nicht
   musl; NVIDIA und Steam laufen nur mit glibc). Im Installer
   (`sudo void-installer`): Benutzer `flask` mit Gruppe `wheel`, Bootloader
   GRUB (EFI), Netzwerk per DHCP bzw. WLAN. Plattenverschlüsselung kann
   der Installer nicht selbst. Wer sie will, richtet LUKS vorher von Hand ein
   (Void-Handbuch „Full Disk Encryption“).
2. Nach dem ersten Start als `flask`:
   ```sh
   sudo xbps-install -Su xbps git
   git clone https://github.com/notflask/.config ~/dotfiles
   cd ~/dotfiles && git checkout void-mango
   sudo linux/void/setup.sh
   ```
   Das dauert: Über 900 Pakete, dazu baut `xbps-src` Discord, Spotify, die
   MS-Schriften und die eigenen Pakete (`srcpkgs/`).
3. Neu starten. greetd/tuigreet fragt nach dem Passwort und startet MangoWC.
   WLAN danach mit `nmtui` verbinden (NetworkManager ersetzt dhcpcd/wpa_supplicant).
4. Einmal nach dem ersten Login:
   - **VPN**: `vpn import ~/Downloads/xyz.conf Name`
   - **Discord**: einmal starten (lädt die App nach), dann `sudo ~/dotfiles/linux/void/setup.sh custom` → Vencord
   - **Spotify**: einmal starten und anmelden, dann `spicetify-setup`
   - **Roblox**: `flatpak install --user flathub org.vinegarhq.Sober`, dann `sober-setup`

Einzelne Schritte: `sudo setup.sh system` (nur /etc und Befehle),
`setup.sh services`, `setup.sh user` (Dotfiles, pipx, Claude Code) usw. Siehe `setup.sh`.

## Alltag

| Befehl | |
|---|---|
| `update` | alles aktualisieren (wie `rebuild update`) |
| `sudo ~/dotfiles/linux/void/setup.sh` | Änderungen im Repo anwenden (wie `rebuild`) |
| `theme`, `theme -m light` | Farben neu erzeugen / hell–dunkel |
| `vpn status`, `vpn up`, `vpn unlock` … | wie unter NixOS |
| `novpn BEFEHL` | Programm am VPN vorbei (Steam: `novpn gaming-mode %command%`) |
| `gaming-mode %command%` | Steam-Startoption, wie unter NixOS |
| `sudo sv status /var/service/*` | Dienste (statt `systemctl status`) |
| `sudo svlogtail` | Systemlog (statt `journalctl`) |
| `wm hotkeys` (Super+Shift+/) | alle Tastenkürzel |

## Tastenkürzel (wie Niri)

| Taste | |
|---|---|
| Super+T, Super+` | Ghostty, Wegwerf-Terminal |
| Super+Leertaste / Super+D | Rofi |
| Super+Q | Fenster schließen |
| Super+←/→/↑/↓, Super+H/J/K/L | Fokus (oben/unten wechselt am Rand den Tag) |
| Super+Strg+Pfeile | Fenster verschieben |
| Super+1…9, Super+Strg+1…9 | Tag ansehen / Fenster auf Tag |
| Super+Alt+1…9 | Tag *zusätzlich* ansehen (dwm) |
| Super+N | Layout weiter: scroller → tile → fair → dwindle → monocle |
| Super+E / Super+W | alle gleich groß (fair) / Tabs (monocle) |
| Super+R, Super+−/= | Breite durchschalten / ändern |
| Super+F, Super+Shift+F | maximieren, Vollbild |
| Super+V, Super+C | schweben, zentrieren |
| Super+O | Übersicht |
| Alt+Tab | Fensterwechsel mit Vorschau |
| Super+Shift+S, Druck | Screenshot mit Zeichnen / direkt |
| Super+Strg+V | Zwischenablage-Verlauf |
| Super+Shift+L, Super+Shift+E | sperren, Ausschalt-Menü (Rofi) |
| Super+Shift+C | MangoWC-Config neu laden |

## Was anders ist als unter NixOS

| NixOS | Void |
|---|---|
| Niri / Hyprland | MangoWC |
| ly mit Schwarzem Loch | greetd + tuigreet (Text, merkt sich den Benutzer) |
| Glas-Look, Windows-Taskleiste unten | minimal: eckig, 1px, Textleiste oben |
| hyprlock / hypridle | gtklock (Farben von matugen, Wallpaper als Hintergrund) / swayidle, gleiche Zeiten |
| systemd-Dienste | runit (`sv/`), Sitzungsprogramme in `wm autostart` |
| systemd-Slice `novpn.slice` | eigene cgroup `/sys/fs/cgroup/novpn` (`novpn-join` per sudo) |
| Polkit-Regel fürs VPN | sudo-Regeln für `sv up/down` (`etc/sudoers.d/g5`) |
| NixOS-Firewall | `g5-firewall` (gleiche offenen Ports) |
| Rollback auf ältere Generationen | **gibt es nicht**. Nur der zweite Kernel im Boot-Menü (Erweiterte Optionen) |
| Pakete aus nixpkgs | Void-Repos + `srcpkgs/` (xbps-src) + pipx/cargo |

Nicht übernommen:
- **Antigravity CLI** (`agy`): kein Void-Paket und keine bekannte Linux-Quelle. Bei Bedarf von Hand installieren
- **Hyprland-Übersicht** (hyprtasking) und **Niris Dynamic Cast**: MangoWC hat eine eigene Übersicht (Super+O). Beim Teilen wählt man den Bildschirm im Dialog von xdg-desktop-portal-wlr

## Wenn etwas nicht geht

- **Schwarzer Bildschirm nach dem Login**: `~/.local/state/mango.log` lesen.
  In `bin/mango-session` testweise `WLR_DRM_DEVICES` auf nur
  `/dev/dri/nvidia-dgpu` setzen, bei Cursor-Problemen `export WLR_NO_HARDWARE_CURSORS=1`
- **Tearing klappt nicht**: in `mango-session` `export WLR_DRM_NO_ATOMIC=1` (laut MangoWC-Doku bei manchen GPUs nötig)
- **Kein Ton**: `pgrep -a pipewire`, sonst neu anmelden. Die Links liegen unter `/etc/pipewire/pipewire.conf.d`
- **Paket baut nicht** (neue Upstream-Version): `linux/void/update-sources.sh NAME`, dann `sudo setup.sh custom`
- **Neuer Kernel startet nicht**: im GRUB-Menü „Erweiterte Optionen“ → den `linux`-Kernel (6.x) wählen
