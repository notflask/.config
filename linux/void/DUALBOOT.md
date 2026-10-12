# Void neben NixOS: ausprobieren, Spiele holen, NixOS entfernen

Drei Phasen:

1. **Platz schaffen und Void daneben installieren.** NixOS bleibt unangetastet startbar
2. **Void ausprobieren** und Spiele, Spielstände und Daten aus NixOS holen
3. **NixOS entfernen** und den frei gewordenen Platz für Spiele nutzen

Die Platte sieht vorher so aus (von `linux/nix/scripts/install.sh`):

```
nvme0n1
├─nvme0n1p1   1 GiB   vfat   EFI-Partition (NixOS: /boot, systemd-boot und Kernel)
└─nvme0n1p2   Rest    ext4   NixOS
```

und während der Testphase so:

```
nvme0n1
├─nvme0n1p1   1 GiB   vfat   EFI-Partition, gemeinsam (Void: /boot/efi)
├─nvme0n1p2   kleiner ext4   NixOS
└─nvme0n1p3   neu     ext4   Void
```

> **Einfacher und sicherer:** Hat der Laptop einen zweiten M.2-Platz, Void auf
> eine zweite SSD installieren. Dann entfällt Schritt 1, und an der NixOS-Platte
> ändert sich gar nichts.

## Vorher: sichern

Verkleinern ist meistens harmlos, kann aber schiefgehen (Stromausfall, Tippfehler).
Deshalb **vorher** auf einen USB-Stick oder eine externe Platte kopieren:

- `~/` ohne Spiele: Dokumente, `~/Screenshots`, `~/.ssh`, `~/.gnupg`
- `/etc/wireguard/wg0.conf` (VPN)
- alles, was nicht im Repo und nicht in einer Cloud liegt

Und unter NixOS nachsehen, wie viel Platz die Spiele brauchen:

```sh
df -h /
du -sh ~/.local/share/Steam/steamapps ~/Games 2>/dev/null
```

## Phase 1: Platz schaffen und Void installieren

Alles hier sind Befehle zum Abtippen. Zeilen mit `#` sind Erklärungen und
werden nicht eingegeben. **Die Partitionsnummern genau prüfen:**
`nvme0n1p1` (EFI) und `nvme0n1p2` (NixOS) werden **nie** formatiert.

### 1.1 Unter NixOS: nachsehen

```sh
lsblk -f        # Plattenname (meist nvme0n1) und die Partitionen p1, p2
df -h /         # Spalte „Used“: so viel belegt NixOS gerade
```

Merk dir eine Zahl **NIX** = belegter Platz + 20, in GiB. Beispiel: 180G
belegt, dann `NIX=200`. So groß bleibt NixOS, der Rest wird Void.

Passt es? Der Rest muss für Void reichen: etwa 60 GiB für das System plus die
Spiele, die du rüberkopieren willst. Beispiel 1 TB Platte (≈ 930 GiB), NIX=200:
Void bekommt ≈ 730 GiB. Reicht es nicht, erst unter NixOS Spiele deinstallieren,
die du nicht brauchst, dann neu nachsehen.

Heißt die Platte nicht `nvme0n1`, in allen Befehlen unten entsprechend ersetzen.

### 1.2 Vom Ventoy-Stick starten

Void-ISO: `void-live-x86_64-…-base.iso` (**glibc**, nicht musl) von
https://voidlinux.org/download auf den Ventoy-Stick kopieren.

1. Laptop aus, Stick rein, einschalten und **F12** drücken (bei manchen
   Gigabyte-Modellen F7). Secure Boot muss aus sein, wie bei NixOS
2. Den USB-Stick wählen, im Ventoy-Menü die Void-ISO, dann
   **Boot in normal mode**
3. Im Void-Menü den ersten Eintrag nehmen
4. Anmelden: Benutzer `root`, Passwort `voidlinux`

Die Tastatur ist US, wie bei dir gewohnt.

### 1.3 Internet

Am einfachsten: **Handy per USB anschließen und USB-Tethering einschalten**,
oder LAN-Kabel. Das funktioniert sofort, dann direkt `ping` testen.

WLAN von Hand:

```sh
ip link                                   # WLAN-Gerät ablesen, z. B. wlp0s20f3
wpa_passphrase "WLAN-NAME" "PASSWORT" >> /etc/wpa_supplicant/wpa_supplicant.conf
wpa_supplicant -B -i wlp0s20f3 -c /etc/wpa_supplicant/wpa_supplicant.conf
dhcpcd wlp0s20f3                          # „already running“ ist in Ordnung
ping -c 3 voidlinux.org                   # Antworten kommen: Internet geht
```

### 1.4 NixOS verkleinern

```sh
xbps-install -Syu xbps                    # Paketmanager aktualisieren (bei Frage: y)
xbps-install -Sy parted
NIX=200                                   # deine Zahl aus 1.1
e2fsck -f /dev/nvme0n1p2                  # Dateisystem prüfen, muss fehlerfrei sein
resize2fs /dev/nvme0n1p2 ${NIX}G          # Dateisystem verkleinern (dauert etwas)
parted /dev/nvme0n1 resizepart 2 $((NIX+2))GiB
# parted warnt „Shrinking a partition can cause data loss“: Yes eintippen
resize2fs /dev/nvme0n1p2                  # füllt die Partition wieder genau aus
e2fsck -f /dev/nvme0n1p2                  # noch einmal prüfen
```

Die Partition wird 1 GiB größer als das Dateisystem gesetzt, damit nichts
abgeschnitten wird. Bricht `resize2fs` mit „No space left“ ab, ist `NIX` zu
klein: größere Zahl nehmen und ab `resize2fs` wiederholen. Bis hier ist NixOS
unverändert startbar.

### 1.5 Partition für Void anlegen

```sh
parted /dev/nvme0n1 -- mkpart void ext4 $((NIX+2))GiB 100%
lsblk /dev/nvme0n1                        # jetzt gibt es nvme0n1p3
mkfs.ext4 -L void /dev/nvme0n1p3          # NUR p3!
```

### 1.6 Void installieren

```sh
mount /dev/nvme0n1p3 /mnt
mkdir -p /mnt/boot/efi
mount /dev/nvme0n1p1 /mnt/boot/efi        # EFI-Partition von NixOS mitbenutzen, NICHT formatieren
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
ESP=$(blkid -s UUID -o value /dev/nvme0n1p1)
echo "LABEL=void / ext4 defaults,noatime 0 1" > /etc/fstab
echo "UUID=$ESP /boot/efi vfat defaults,umask=0077 0 2" >> /etc/fstab
echo "tmpfs /tmp tmpfs defaults,nosuid,nodev 0 0" >> /etc/fstab
cat /etc/fstab                            # drei Zeilen, bei UUID steht etwas wie 1A2B-3C4D
ln -s /etc/sv/dbus /etc/sv/NetworkManager /etc/runit/runsvdir/default/
grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=void
xbps-reconfigure -fa                      # Kernel-Image und GRUB-Menü erzeugen
exit
```

Zurück im Live-System:

```sh
umount -R /mnt
reboot                                    # Stick abziehen, sobald der Bildschirm schwarz wird
```

GRUB liegt jetzt neben systemd-boot auf der gemeinsamen EFI-Partition
(`EFI/void`) und startet als Erstes.

### 1.7 Void einrichten

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

`setup.sh` findet NixOS auf der EFI-Partition und trägt es ins Boot-Menü ein
(„NixOS“, 5 Sekunden Wartezeit).

### Zwischen beiden wechseln

- **Boot-Menü (GRUB):** „Void Linux“ oder „NixOS“. NixOS startet dann sein
  gewohntes systemd-boot-Menü
- **Notfalls über das Firmware-Menü** (F12): „void“ bzw. „Linux Boot Manager“
  (NixOS)
- Ein `rebuild` unter NixOS kann sich wieder an die erste Stelle der
  Startreihenfolge setzen. Dann startet direkt NixOS. Zurück nach Void über
  F12, und dort einmal `sudo setup.sh boot` (setzt GRUB wieder nach vorn)

## Phase 2: ausprobieren und Daten holen

In Ruhe testen: Spiele, Discord-Stream, VPN, beide Monitore, Standby. NixOS
bleibt bis dahin vollständig da.

### 2.1 NixOS unter Void einhängen (nur lesen)

```sh
sudo mkdir -p /mnt/nixos
sudo mount -o ro /dev/nvme0n1p2 /mnt/nixos
```

Dein Benutzer hat unter beiden Systemen dieselbe Nummer (UID 1000). Deshalb
kannst du deine Dateien ohne `sudo` lesen.

### 2.2 Steam-Spiele

Steam unter Void einmal starten und anmelden (legt die Ordner an), dann
**schließen** und kopieren:

```sh
rsync -aH --info=progress2 \
  /mnt/nixos/home/flask/.local/share/Steam/steamapps/ \
  ~/.local/share/Steam/steamapps/
```

Darin liegen die Spiele (`common/`), die `appmanifest_*.acf` (daran erkennt
Steam sie als installiert), die Proton-Präfixe mit lokalen Spielständen
(`compatdata/`) und der Shader-Cache. Steam wieder starten: Die Spiele sind
installiert, ohne neuen Download. Höchstens kurz „Wird überprüft“.

### 2.3 Battle.net (Lutris), Roblox (Sober)

```sh
rsync -aH --info=progress2 /mnt/nixos/home/flask/Games/ ~/Games/
rsync -aH /mnt/nixos/home/flask/.local/share/lutris/ ~/.local/share/lutris/
rsync -aH /mnt/nixos/home/flask/.config/lutris/ ~/.config/lutris/
# Sober: nur die Einstellungen, anmelden musst du dich ohnehin neu
rsync -aH /mnt/nixos/home/flask/.var/app/org.vinegarhq.Sober/ ~/.var/app/org.vinegarhq.Sober/
```

### 2.4 Sonstige Daten

Was du brauchst, zum Beispiel:

```sh
cd /mnt/nixos/home/flask
rsync -aH Documents Downloads Pictures Screenshots .ssh .gnupg ~/
rsync -aH .config/ATAS/ ~/.config/ATAS/                         # ATAS X: Workspaces, Datenbank
rsync -aH .local/share/TelegramDesktop/ ~/.local/share/TelegramDesktop/   # Telegram ohne neues Anmelden
rsync -aH .local/share/kwalletd/ ~/.local/share/kwalletd/       # gespeicherte Passwörter
sudo cat /mnt/nixos/etc/wireguard/wg0.conf > /tmp/wg0.conf
vpn import /tmp/wg0.conf Name && rm /tmp/wg0.conf
```

Firefox: Das Profil (`~/.config/mozilla`) nur übernehmen, wenn Firefox unter
Void gleich neu oder neuer ist (`firefox --version` unter beiden). Sonst
einfach mit dem Firefox-Konto synchronisieren.

Zum Schluss: `sudo umount /mnt/nixos`

## Phase 3: NixOS entfernen

Erst, wenn unter Void alles läuft und alles kopiert ist.

### 3.1 NixOS aus dem Boot entfernen

```sh
# GRUB als Rückfall-Bootloader eintragen (EFI/BOOT/BOOTX64.EFI war bisher systemd-boot)
sudo grub-install --target=x86_64-efi --efi-directory=/boot/efi --removable
# systemd-boot, NixOS-Kernel und Boot-Einträge von der EFI-Partition löschen
sudo rm -rf /boot/efi/EFI/systemd /boot/efi/EFI/nixos /boot/efi/loader
# „Linux Boot Manager“ aus der Firmware-Liste entfernen
sudo efibootmgr                    # Nummer von „Linux Boot Manager“ ablesen, z. B. 0001
sudo efibootmgr -b 0001 -B
# NixOS-Eintrag aus GRUB entfernen (setup.sh merkt, dass es weg ist)
sudo ~/dotfiles/linux/void/setup.sh boot
```

Neu starten und prüfen, ob Void normal startet.

### 3.2 Die NixOS-Partition zur Spiele-Partition machen

Die alte NixOS-Partition liegt **vor** der Void-Partition. Void lässt sich
nicht einfach nach vorn vergrößern (das ginge nur mit GParted und Verschieben,
langsam und riskanter). Deshalb wird daraus eine eigene Partition für Spiele:

```sh
lsblk -f                                   # sicherstellen: nvme0n1p2 ist ext4 „nixos“
sudo wipefs -a /dev/nvme0n1p2
sudo mkfs.ext4 -L spiele /dev/nvme0n1p2
sudo mkdir -p /home/flask/Spiele
echo "LABEL=spiele /home/flask/Spiele ext4 defaults,noatime 0 2" | sudo tee -a /etc/fstab
sudo mount /home/flask/Spiele && sudo chown flask:flask /home/flask/Spiele
```

In Steam unter **Einstellungen → Speicher** den Ordner `/home/flask/Spiele`
als Bibliothek hinzufügen und große Spiele dorthin verschieben (Steam kann
das selbst: Spiel auswählen → „Verschieben“). Neue Spiele landen ab dann
ebenfalls dort, wenn du die Bibliothek als Standard setzt.

Wer lieber eine einzige große Partition will: in GParted Live erst die neue
`p2` löschen, dann `p3` (Void) nach links verschieben und vergrößern. Das
dauert lange und sollte nur mit Backup passieren.

Fertig: Nur noch Void, die Spiele sind da, und der Platz von NixOS gehört den
Spielen.
