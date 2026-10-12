# Arch Linux auf dem G5

`install.sh` richtet einen frischen Arch (archinstall) ein: Treiber, Tuning, Hyprland, alle Programme.

## Vor dem Skript (archinstall)

- Bootloader **Limine**, Dateisystem **btrfs** (Standard-Subvolumes), Kernel **linux-zen**,
  Netzwerk **NetworkManager**, Benutzer `flask` mit sudo, **kein** Desktop-Profil, keine Treiber-Auswahl.
- Nach dem Neustart: Netz (`nmtui`), dann

```sh
sudo pacman -S --needed git
git clone <repo> ~/dotfiles && git -C ~/dotfiles switch arch
~/dotfiles/linux/arch/install.sh        # als normaler Benutzer, nicht mit sudo
```

Danach neu starten und im Login (ly) Hyprland wählen. Einzelne Schritte:
`install.sh repos|packages|system|boot|services|user|network`.

## Zwei Stile

`style minimal` (Vorgabe) und `style glass` schalten sofort um (Hyprland, Leiste, mako, Starter, fastfetch);
die Wahl steht in `~/.config/g5/style`.

| | minimal | glass (Liquid Glass) |
|---|---|---|
| Fenster | eckig, flach, 1 px Rahmen, keine Effekte | abgerundet, Blur, Glas |
| Leiste | schmale Textleiste (`quickshell/minibar`) | Taskleiste (`quickshell/taskbar`) |
| Terminal / Starter | `term`, Rofi flat | Ghostty mit Blur, Rofi Spotlight-Glas |
| mako, fastfetch | flach, großes Logo | Glas, kleines Logo |
| Übersicht Super+O | – | hyprtasking (von raybbian passend zur Hyprland-Version gebaut, `install.sh plugins`) |

## Was es tut

| Bereich | Umsetzung |
|---|---|
| Kernel / GPU | linux-zen, `nvidia-open-dkms` 595er, PAT, `nvidia-drm.modeset=1`, Intel i915 früh im initramfs, Hyprland rendert auf der RTX 4060 (`AQ_DRM_DEVICES`), Mindesttakt 1500 MHz, nvidia-powerd (Dynamic Boost) |
| Leistung | `preempt=full`, `nowatchdog`, ntsync, BBR, sysctl/zram, BFQ für NVMe, PL1 65 W, Energieprofil „performance“, gamemode + Lüfterkurve, ananicy-cpp. Kein scx (Zen-Kernel, EEVDF reicht) |
| Boot | Limine über `limine-mkinitcpio-hook` (`/etc/default/limine`), **Plymouth** (Thema bgrt), snapper + snap-pac + `limine-snapper-sync`: Snapshot vor jedem Update, im Limine-Menü wählbar |
| Sitzung | ly (Schwarzes Loch) → UWSM → Hyprland; Benutzerdienste (Polkit, swayidle, matugen …) |
| Netz | NetworkManager, WLAN ohne Stromsparmodus, WireGuard-Kill-Switch/Sperre/Split-Tunneling (`vpn`, `novpn`) über systemd-Units, Firewall |
| Programme | Discord (+Vencord per pacman-Hook), Telegram, Spotify + Spicetify, Steam + GE-Proton + gamescope + MangoHud + Lutris, Firefox (Pywalfox, uBlock Origin, Tempo-Einstellungen), Warp, TradingView, Claude Code/Desktop, Gigabyte Control Center, Sober (Flatpak), mizu, opal, Schriften inkl. Apple-Emoji |

## Nach der Installation

- WireGuard: `vpn import DATEI.conf` (Schlüssel liegen nur lokal).
- Discord: einmal starten; Vencord aktivieren unter Einstellungen → Vencord → Themes.
- Spotify einmal starten und anmelden, dann `spicetify-setup`. Sober: `sober-setup`.
- Prüfen: `gpu-info`, `nvidia-smi`, `sudo snapper list`, `dmesg | grep Preempt`.
- Updates: `update` (paru + Spicetify + Flatpak).

## Hinweis

Das Skript wurde ohne Arch-Rechner geschrieben (Paketnamen gegen archlinux.org/AUR geprüft, Syntax
geprüft, aber nicht auf der Hardware gelaufen). Pakete, die nicht gefunden werden, meldet es am Ende
gesammelt; der Rest läuft durch.
