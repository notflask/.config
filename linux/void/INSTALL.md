# Void installieren: NixOS komplett ersetzen

Die ganze Platte wird gelöscht und Void neu installiert. Alles hier sind
Befehle zum Abtippen; Zeilen mit `#` sind Erklärungen.

> **Alles auf der Platte ist danach weg**, auch die Steam-Spiele. Die lädt
> Steam unter Void neu herunter. Wer sie behalten will, nimmt lieber
> [DUALBOOT.md](DUALBOOT.md) oder kopiert sie vorher auf eine externe Platte.

## 0. Unter NixOS sichern

Auf einen USB-Stick oder eine externe Platte kopieren:

- `/etc/wireguard/wg0.conf` (VPN): `sudo cp /etc/wireguard/wg0.conf /pfad/zum/stick/`
- `~/.ssh`, `~/.gnupg`, Dokumente, Bilder, `~/Screenshots`, Downloads
- `~/.config/ATAS` (ATAS-Workspaces), `~/.local/share/TelegramDesktop`
- alles, was nicht im Repo oder in einer Cloud liegt

Dann den Plattennamen ablesen, meist `nvme0n1`:

```sh
lsblk
```

Heißt sie anders, in allen Befehlen unten entsprechend ersetzen.

## 1. Vom Ventoy-Stick starten

Void-ISO `void-live-x86_64-…-base.iso` (**glibc**, nicht musl) von
https://voidlinux.org/download auf den Ventoy-Stick kopieren.

1. Laptop aus, Stick rein, einschalten und **F12** drücken (bei manchen
   Gigabyte-Modellen F7). Secure Boot muss aus sein, wie bei NixOS
2. USB-Stick wählen, im Ventoy-Menü die Void-ISO, dann **Boot in normal mode**
3. Im Void-Menü den ersten Eintrag nehmen
4. Anmelden: Benutzer `root`, Passwort `voidlinux`

## 2. Internet

Am einfachsten: **Handy per USB anschließen und USB-Tethering einschalten**,
oder LAN-Kabel. Dann nur:

```sh
ping -c 3 voidlinux.org
```

WLAN von Hand:

```sh
ip link                                   # WLAN-Gerät ablesen, z. B. wlp0s20f3
wpa_passphrase "WLAN-NAME" "PASSWORT" >> /etc/wpa_supplicant/wpa_supplicant.conf
wpa_supplicant -B -i wlp0s20f3 -c /etc/wpa_supplicant/wpa_supplicant.conf
dhcpcd wlp0s20f3                          # „already running“ ist in Ordnung
ping -c 3 voidlinux.org
```

## 3. Platte löschen und neu aufteilen

```sh
lsblk                                     # richtige Platte? Der Stick ist sda o. ä., NICHT nehmen
xbps-install -Syu xbps                    # bei Frage: y
xbps-install -Sy parted
wipefs -a /dev/nvme0n1                    # ab hier ist NixOS weg
parted -s /dev/nvme0n1 -- mklabel gpt \
  mkpart ESP fat32 1MiB 1GiB set 1 esp on \
  mkpart void ext4 1GiB 100%
mkfs.fat -F 32 -n EFI /dev/nvme0n1p1
mkfs.ext4 -L void /dev/nvme0n1p2
```

## 4. Void installieren

```sh
mount /dev/nvme0n1p2 /mnt
mkdir -p /mnt/boot/efi
mount /dev/nvme0n1p1 /mnt/boot/efi
mkdir -p /mnt/var/db/xbps/keys
cp /var/db/xbps/keys/* /mnt/var/db/xbps/keys/
XBPS_ARCH=x86_64 xbps-install -Sy -r /mnt -R https://repo-default.voidlinux.org/current \
  base-system grub-x86_64-efi NetworkManager git
cp /etc/resolv.conf /mnt/etc/
for d in dev proc sys; do mount --rbind /$d /mnt/$d; mount --make-rslave /mnt/$d; done
chroot /mnt /bin/bash
```

Jetzt bist du im neuen System:

```sh
passwd                                    # root-Passwort festlegen
useradd -m -G wheel,video,audio,input flask
passwd flask                              # dein Passwort
echo '%wheel ALL=(ALL:ALL) ALL' > /etc/sudoers.d/wheel
echo g5 > /etc/hostname
ln -sf /usr/share/zoneinfo/Europe/Berlin /etc/localtime
echo "LABEL=void / ext4 defaults,noatime 0 1" > /etc/fstab
echo "LABEL=EFI /boot/efi vfat defaults,umask=0077 0 2" >> /etc/fstab
echo "tmpfs /tmp tmpfs defaults,nosuid,nodev 0 0" >> /etc/fstab
ln -s /etc/sv/dbus /etc/sv/NetworkManager /etc/runit/runsvdir/default/
grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=void
# zusätzlich als Standard-Bootloader, falls die Firmware den Eintrag vergisst
grub-install --target=x86_64-efi --efi-directory=/boot/efi --removable
xbps-reconfigure -fa                      # Kernel-Image und GRUB-Menü erzeugen
exit
```

Zurück im Live-System:

```sh
umount -R /mnt
reboot                                    # Stick abziehen, sobald der Bildschirm schwarz wird
```

## 5. Einrichten

GRUB startet Void, eine Textanmeldung erscheint. Als `flask` anmelden:

```sh
sudo nmtui                                # „Activate a connection“, WLAN wählen, Passwort
sudo xbps-install -Su xbps git
git clone https://github.com/notflask/.config ~/dotfiles
cd ~/dotfiles && git checkout void-mango
sudo linux/void/setup.sh                  # dauert lange (Pakete, eigene Pakete bauen)
sudo reboot
```

Nach dem Neustart erscheint ly: Passwort eingeben, MangoWC startet. Dann im
Terminal (Super+T) einmal `update`; das entfernt den Installer-Kernel, nur
`linux-mainline` bleibt.

## 6. Daten zurück

Stick einstecken (Dolphin hängt ihn ein), dann zum Beispiel:

```sh
vpn import /run/media/flask/STICK/wg0.conf Name
cp -a /run/media/flask/STICK/.ssh ~/ && chmod 700 ~/.ssh
```

Den Rest (Wallpaper, Discord, Spotify, Roblox) unter
[README.md → Installation, Schritt 4](README.md#installation).
