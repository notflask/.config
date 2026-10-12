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

### 1.1 Zwei USB-Sticks vorbereiten

- **GParted Live** (https://gparted.org/livecd.php) zum Verkleinern
- **Void** (https://voidlinux.org/download): `void-live-x86_64-…-base.iso`,
  unbedingt **glibc**, nicht musl

Mit `dd` oder Ventoy auf die Sticks schreiben.
Mit Ventoy reicht ein Stick für beide ISOs.

### 1.2 NixOS verkleinern (GParted Live)

Vom GParted-Stick starten. Das Boot-Menü kommt beim Einschalten mit **F12**
(bei manchen Gigabyte-Modellen F7), das BIOS mit F2.

1. `nvme0n1p2` (ext4, NixOS) auswählen, **Größe ändern/Verschieben**
2. „Freier Platz danach“ auf die Größe für Void setzen:
   **Systemgröße (~100 GB) + Spiele, die du rüberholen willst**. Beispiel:
   300 GB Spiele, dann 400 GB für Void
3. **Anwenden** und warten. GParted prüft das Dateisystem vorher selbst

Nichts formatieren, nichts löschen, nur verkleinern. Danach einmal NixOS starten
und prüfen, ob alles läuft.

### 1.3 Void installieren

Vom Void-Stick starten, als `root` anmelden (Passwort `voidlinux`) und
`void-installer` starten:

| Menüpunkt | Einstellung |
|---|---|
| Keyboard | `us` |
| Network | WLAN oder Kabel |
| Source | Network |
| Hostname | `g5` |
| Locale, Timezone | `de_DE.UTF-8`, `Europe/Berlin` |
| User account | `flask`, Gruppen inklusive `wheel` |
| Bootloader | Platte `/dev/nvme0n1`, GRUB, **nicht** „graphical terminal“ |
| Partition | `cfdisk` auf `/dev/nvme0n1`: im **freien Platz** eine neue Partition „Linux filesystem“ anlegen (wird `nvme0n1p3`), Write, Quit. **p1 und p2 nicht anfassen** |
| Filesystems | `nvme0n1p1` → `vfat`, Mountpunkt **`/boot/efi`**, Frage nach neuem Dateisystem: **Nein** (sonst ist NixOS nicht mehr startbar) |
| | `nvme0n1p3` → `ext4`, Mountpunkt **`/`**, neues Dateisystem: Ja |
| | `nvme0n1p2` (NixOS) **nicht** eintragen |

Dann „Install“. GRUB landet neben systemd-boot auf der gemeinsamen
EFI-Partition (`EFI/void`).

### 1.4 Void einrichten

Neu starten. Jetzt startet GRUB (Void). Als `flask` anmelden:

```sh
sudo xbps-install -Su xbps git
git clone https://github.com/notflask/.config ~/dotfiles
cd ~/dotfiles && git checkout void-mango
sudo linux/void/setup.sh
```

`setup.sh` findet NixOS auf der EFI-Partition und trägt es ins Boot-Menü ein
(„NixOS“, 5 Sekunden Wartezeit). Neu starten, ly erscheint, MangoWC startet.
Danach einmal `update`, das entfernt den Installer-Kernel.

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
