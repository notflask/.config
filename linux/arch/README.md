# Arch Linux auf dem G5

`install.sh` richtet einen frischen Arch (archinstall) so ein wie NixOS (`linux/nix`)
bzw. Void (`linux/void`): Treiber, Tuning, Hyprland, alle Programme.

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

## Was es tut

| Bereich | Umsetzung |
|---|---|
| Kernel / GPU | linux-zen, `nvidia-open-dkms` 595er, PAT, `nvidia-drm.modeset=1`, Intel i915 früh im initramfs, Hyprland rendert auf der RTX 4060 (`AQ_DRM_DEVICES`), Mindesttakt 1500 MHz, nvidia-powerd (Dynamic Boost) |
| Leistung | `preempt=full`, `nowatchdog`, ntsync, BBR, sysctl/zram wie `performance.nix`, BFQ für NVMe, PL1 65 W, Energieprofil „performance“, gamemode + Lüfterkurve, ananicy-cpp. Kein scx (Zen-Kernel, EEVDF reicht) |
| Boot | Limine über `limine-mkinitcpio-hook` (`/etc/default/limine`), **Plymouth** (Thema bgrt) wie in `configuration.nix`, snapper + snap-pac + `limine-snapper-sync`: Snapshots vor jedem Update, im Limine-Menü wählbar |
| Sitzung | ly (Schwarzes Loch) → UWSM → Hyprland; Benutzerdienste wie NixOS (mako, Polkit, swayidle, matugen …) |
| Netz | NetworkManager, WLAN ohne Stromsparmodus, WireGuard-Kill-Switch/Sperre/Split-Tunneling (`vpn`, `novpn`) über systemd-Units, Firewall wie `networking.firewall` |
| Programme | Discord (+Vencord per pacman-Hook), Telegram, Spotify + Spicetify, Steam + GE-Proton + gamescope + MangoHud + Lutris, Firefox (Pywalfox, uBlock Origin, Tempo-Einstellungen), Warp, TradingView, Claude Code/Desktop, Gigabyte Control Center, Sober (Flatpak), mizu, opal, Schriften inkl. Apple-Emoji |

Nicht dabei (wie gewünscht): ATAS X, Haruneko.

## Nach der Installation

- WireGuard: `vpn import DATEI.conf` (Schlüssel liegen nur lokal).
- Discord: einmal starten; Vencord aktivieren unter Einstellungen → Vencord → Themes.
- Spotify einmal starten und anmelden, dann `spicetify-setup`.
- Sober: `sober-setup`.
- Hyprland-Übersicht (Super+O) braucht das AUR-Paket `hyprtasking`; ohne läuft sonst alles.
- Prüfen: `gpu-info`, `nvidia-smi`, `sudo snapper list`, `sudo limine-snapper-sync`, `dmesg | grep Preempt`.
- Updates: `update` (paru + Spicetify + Flatpak).

## Hinweis

Das Skript wurde ohne Arch-Rechner geschrieben (Paketnamen gegen archlinux.org/AUR geprüft,
Syntax geprüft, aber nicht auf der Hardware gelaufen). Pakete, die nicht gefunden werden, meldet es am
Ende gesammelt; der Rest läuft durch.
