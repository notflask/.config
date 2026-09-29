# Gemeinsame Grundlage für beide Sitzungen (Niri und Hyprland) – ohne KDE Plasma:
# Login, Tastatur, Portale, Passwortabfragen, Benachrichtigungen, KWallet,
# KDE-Apps (Dolphin, Gwenview, Okular, Ark) und die Wayland-Werkzeuge, die
# beide Configs starten. Eigenes pro Sitzung: niri.nix und hyprland.nix.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  kde = pkgs.kdePackages;

  # Screenshot mit Zeichnen (wie Shottr/Spectacle): Bereich aufziehen →
  # Satty (Pfeil, Rechteck, Text, Marker, Verpixeln …) → Enter (oder der
  # Kopieren-Knopf) kopiert ins Clipboard, speichert nach ~/Screenshots
  # und schließt.
  screenshot-edit = pkgs.writeShellApplication {
    name = "screenshot-edit";
    runtimeInputs = with pkgs; [
      grim
      slurp
      satty
      wl-clipboard
    ];
    text = ''
      mkdir -p "$HOME/Screenshots"
      geom=$(slurp -d -b '#1e1e2e66' -c '#cba6f7' -w 2) || exit 0
      grim -g "$geom" -t ppm - | satty --filename - \
        --output-filename "$HOME/Screenshots/Screenshot from %Y-%m-%d %H-%M-%S.png" \
        --copy-command wl-copy \
        --early-exit copy save \
        --actions-on-enter save-to-clipboard,save-to-file \
        --save-after-copy \
        --actions-on-escape exit \
        --initial-tool arrow
    '';
  };

  # Bildschirme aus/an (hypridle) – je nachdem, welcher Compositor läuft
  screen-power = pkgs.writeShellApplication {
    name = "screen-power";
    text = ''
      state=''${1:?on oder off}
      if [ -n "''${NIRI_SOCKET:-}" ]; then
        niri msg action "power-$state-monitors"
      elif [ -n "''${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
        action=disable
        if [ "$state" = on ]; then
          action=enable
        fi
        hyprctl dispatch "hl.dsp.dpms({ action = \"$action\" })"
      fi
    '';
  };

  # Abmelden aus der laufenden Sitzung (wlogout, siehe wlogout/layout)
  session-logout = pkgs.writeShellApplication {
    name = "session-logout";
    text = ''
      if [ -n "''${NIRI_SOCKET:-}" ]; then
        exec niri msg action quit --skip-confirmation
      elif [ -n "''${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
        # hyprshutdown schließt erst alle Fenster sauber (ungesicherte Daten)
        if command -v hyprshutdown >/dev/null; then
          exec hyprshutdown
        fi
        exec hyprctl dispatch 'hl.dsp.exit()'
      fi
      exec loginctl terminate-session "''${XDG_SESSION_ID:-}"
    '';
  };

  # Wegwerf-Terminal (Super+`): schwebt oben mittig über allem (Fensterregel
  # com.flask.scratchpad in niri/config.kdl bzw. hypr/hyprland.lua). Nochmal
  # drücken (oder Super+Q) schließt es und beendet alles, was darin lief –
  # auch Hintergrundprozesse, denn es läuft als eigener systemd-Dienst und
  # systemd räumt beim Beenden die ganze cgroup ab. Ist es offen, aber nicht
  # fokussiert, holt die Taste es nur nach vorn.
  scratch-term = pkgs.writeShellApplication {
    name = "scratch-term";
    runtimeInputs = with pkgs; [ jq ];
    text = ''
      app_id=com.flask.scratchpad
      unit=scratchpad.service

      if [ -n "''${NIRI_SOCKET:-}" ]; then
        id=$(niri msg --json windows | jq --arg app "$app_id" \
          'first(.[] | select(.app_id == $app)) | .id // empty')
        focused=$(niri msg --json focused-window | jq '.id // empty')
        focus() { niri msg action focus-window --id "$1"; }
      elif [ -n "''${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
        id=$(hyprctl clients -j | jq -r --arg app "$app_id" \
          'first(.[] | select(.class == $app)) | .address // empty')
        focused=$(hyprctl activewindow -j | jq -r '.address // empty')
        focus() { hyprctl dispatch "hl.dsp.focus({ window = \"address:$1\" })" >/dev/null; }
      else
        id=""
        focused=""
      fi

      if [ -n "$id" ]; then
        if [ "$id" = "$focused" ]; then
          systemctl --user stop "$unit"
        else
          focus "$id"
        fi
        exit 0
      fi

      # Reste eines vorigen Laufs (z. B. hängender Prozess) wegräumen
      systemctl --user stop "$unit" 2>/dev/null || true
      systemd-run --user --unit="$unit" --collect --quiet \
        ghostty --class="$app_id" \
          --gtk-single-instance=false \
          --confirm-close-surface=false \
          --working-directory=home
    '';
  };

  # Login-Animation: Planet mit Schwarzem Loch (ly-community, frei nutzbar).
  # Die Textkonsole zeigt nur 16 Farben – gröber als im ly-README.
  blackhole = pkgs.fetchurl {
    url = "https://codeberg.org/fairyglade/ly-community/raw/commit/fd85d8584545433520f34fb25584b17280f4c0b9/animations/dur/blackhole-smooth-240x67.dur";
    hash = "sha256-wo3FzPtngCsg/bRSDTYHQqKnMp4vY+Btm14vakJERBU=";
  };

  # Nur diese beiden im Login anbieten. Das Hyprland-Paket bringt zusätzlich
  # eine Sitzung ohne UWSM mit – die startet graphical-session.target nicht,
  # dann fehlen mako, Polkit, hypridle usw.
  greeterSessions = pkgs.runCommand "greeter-sessions" { } ''
    mkdir -p $out
    for s in niri hyprland-uwsm; do
      f=${config.services.displayManager.sessionData.desktops}/share/wayland-sessions/$s.desktop
      if [ ! -e "$f" ]; then
        echo "Sitzung $s.desktop fehlt" >&2
        exit 1
      fi
      ln -s "$f" $out/
    done
  '';
in
{
  # ── Login: ly ───────────────────────────────────────────
  # Sitzung im Login mit ←/→ wählen, ly merkt sich Benutzer und Sitzung.
  # F1 ausschalten, F2 neu starten.
  services.displayManager.ly = {
    enable = true;
    settings = {
      lang = "de";
      animation = "dur_file";
      # Pflicht: fehlt der Schlüssel, hält ly die Config für veraltet, schaltet
      # auf 8 Farben – und verweigert das 256-Farben-Schwarze-Loch
      # („error: InvalidColorFormat“)
      full_color = true;
      dur_file_path = "${blackhole}";
      dur_offset_alignment = "center";
      waylandsessions = "${greeterSessions}";
      bigclock = "en";
      clock = "%a %d.%m.%Y %H:%M";
    };
  };

  # KWallet beim Login entsperren (gespeicherte Passwörter wie unter KDE).
  # ly nutzt den login-Stack; pam_kwallet_init (unten) reicht das
  # Login-Passwort an kwalletd weiter.
  security.pam.services.login.kwallet = {
    enable = true;
    package = kde.kwallet-pam;
  };

  # Electron-Apps (Discord usw.) nativ unter Wayland
  environment.sessionVariables.NIXOS_OZONE_WL = "1";

  # ── Tastatur: us/ru/ua/de, Umschalten mit Alt+Shift ─────────
  # Niri und Hyprland setzen das Layout in ihrer eigenen Config.
  services.xserver.xkb = {
    layout = "us,ru,ua,de";
    options = "grp:alt_shift_toggle";
  };

  # ── Portale: Dateidialog von KDE, Passwörter über KWallet ──
  # Die Zuordnung pro Sitzung steht in niri.nix / hyprland.nix.
  xdg.portal = {
    enable = true;
    extraPortals = [
      kde.xdg-desktop-portal-kde # Dateidialog
      kde.kwallet # Secret-Portal
      pkgs.xdg-desktop-portal-gtk # Einstellungen (Dunkelmodus, Schrift) für GTK-Apps
    ];
  };

  # ── Dienste für beide Sitzungen ────────────────────────────
  # graphical-session.target starten Niri (niri-session) und Hyprland (UWSM).
  systemd.user.services = {
    polkit-agent = {
      description = "KDE-Polkit-Agent (Passwortabfragen)";
      wantedBy = [ "graphical-session.target" ];
      partOf = [ "graphical-session.target" ];
      after = [ "graphical-session.target" ];
      serviceConfig = {
        ExecStart = "${kde.polkit-kde-agent-1}/libexec/polkit-kde-authentication-agent-1";
        Restart = "on-failure";
      };
    };
    # Benachrichtigungen: die Unit bringt mako selbst mit (systemd.packages
    # unten) – so startet auch die D-Bus-Aktivierung genau diese Instanz
    mako.wantedBy = [ "graphical-session.target" ];
    pam-kwallet-init = {
      description = "KWallet mit dem Login-Passwort entsperren";
      wantedBy = [ "graphical-session.target" ];
      partOf = [ "graphical-session.target" ];
      after = [ "graphical-session.target" ];
      # Setzt pam_kwallet beim Login (ly); fehlt es, gibt es nichts zu tun
      unitConfig.ConditionEnvironment = "PAM_KWALLET5_LOGIN";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${kde.kwallet-pam}/libexec/pam_kwallet_init";
      };
    };
    # hypridle-Befehle (hypr/hypridle.conf) brauchen niri, hyprctl, loginctl …
    hypridle.path = [ "/run/current-system/sw" ];
    # Nach einem Rebuild zeigt der KDE-Cache (sycoca) sonst auf alte
    # Store-Pfade – „Öffnen mit“ in Dolphin wäre leer (wie im Plasma-Modul)
    rebuild-sycoca = {
      description = "KDE-Programmliste neu aufbauen";
      wantedBy = [ "graphical-session-pre.target" ];
      serviceConfig.Type = "oneshot";
      script = ''rm -f "''${XDG_CACHE_HOME:-$HOME/.cache}/ksycoca"*'';
    };
  };
  systemd.packages = [ pkgs.mako ];
  system.userActivationScripts.rebuildSycoca = ''
    rm -f "''${XDG_CACHE_HOME:-$HOME/.cache}/ksycoca"*
  '';

  # Autostart-Einträge (/etc/xdg/autostart, ~/.config/autostart) in beiden
  # Sitzungen ausführen – z. B. GPU Screen Recorder oder „Beim Login starten“
  # von Discord/Telegram. Unter Hyprland macht das UWSM ohnehin.
  systemd.user.targets.xdg-desktop-autostart.wantedBy = [ "graphical-session.target" ];

  # Sperrbildschirm (hyprlock) inkl. PAM, dazu hypridle (Auto-Sperre,
  # Config: linux/.config/hypr/hypridle.conf) – für beide Sitzungen
  programs.hyprlock.enable = true;
  services.hypridle.enable = true;

  # ── KDE-Apps ohne Plasma ───────────────────────────────────
  environment.systemPackages =
    (with kde; [
      dolphin
      dolphin-plugins
      ark # Archive
      gwenview # Bilder
      okular # PDF
      filelight # Speicherplatz-Übersicht
      kwalletmanager
      kwallet # kwalletd6
      # Dolphin: Netzwerk, Handy (MTP), Vorschaubilder, „als Admin öffnen“
      kio
      kio-extras
      kio-fuse
      kio-admin
      ffmpegthumbs
      kdegraphics-thumbnailers
      kimageformats
      qtimageformats # webp, avif …
      qtsvg
      qtwayland
      kservice # kbuildsycoca6
      breeze-icons # Rückfall-Icons für KDE-Apps
    ])
    ++ (with pkgs; [
      hicolor-icon-theme
      xdg-terminal-exec # Terminal-Apps (nvim, btop) aus Menüs in Ghostty öffnen

      # Programme, die die Niri- und Hyprland-Config starten
      waybar
      rofi # Spotlight-Starter (Super+Space)
      awww # Hintergrund mit Übergängen (Backend für Waypaper)
      waypaper
      matugen
      cliphist
      wl-clip-persist # Zwischenablage überlebt das Schließen der Quell-App
      playerctl
      imagemagick # abgerundete Cover im Waybar-Medienwidget
      jq # wlogout/launch.sh
      brightnessctl
      pavucontrol
      wlogout
      mako # makoctl (Theme neu laden)
      libnotify # notify-send
      screenshot-edit # Super+Shift+S
      session-logout # wlogout → Abmelden
      scratch-term # Super+`
      screen-power # hypridle
    ]);

  # Wie im Plasma-Modul: KDE-Apps finden Daten anderer Pakete (Dienstmenüs,
  # Farbschemata, Benachrichtigungen) nur, wenn ganz /share verlinkt ist
  environment.pathsToLink = [ "/share" ];

  # Ohne Plasma fehlt das Programm-Menü, aus dem KDE „Öffnen mit“ und die
  # Standard-Apps liest – dieses nimmt einfach alle installierten Programme
  environment.etc."xdg/menus/applications.menu".text = ''
    <!DOCTYPE Menu PUBLIC "-//freedesktop//DTD Menu 1.0//EN"
      "http://www.freedesktop.org/standards/menu-spec/1.0/menu.dtd">
    <Menu>
      <Name>Applications</Name>
      <DefaultAppDirs/>
      <DefaultDirectoryDirs/>
      <Include><All/></Include>
    </Menu>
  '';
  environment.etc."xdg/xdg-terminals.list".text = ''
    com.mitchellh.ghostty.desktop
  '';

  # Standard-Apps (eigene Auswahl in ~/.config/mimeapps.list hat Vorrang)
  xdg.mime.defaultApplications =
    let
      for = app: types: lib.genAttrs types (_: app);
    in
    for "org.kde.dolphin.desktop" [ "inode/directory" ]
    // for "org.kde.okular.desktop" [
      "application/pdf"
      "application/epub+zip"
    ]
    // for "org.kde.gwenview.desktop" [
      "image/png"
      "image/jpeg"
      "image/gif"
      "image/webp"
      "image/avif"
      "image/heif"
      "image/bmp"
      "image/tiff"
      "image/svg+xml"
    ]
    // for "org.kde.ark.desktop" [
      "application/zip"
      "application/x-7z-compressed"
      "application/x-rar"
      "application/vnd.rar"
      "application/x-tar"
      "application/x-compressed-tar"
      "application/x-xz-compressed-tar"
      "application/x-zstd-compressed-tar"
      "application/gzip"
    ];

  # USB-Sticks einhängen, Handys (MTP), kio-fuse – bisher vom Plasma-Modul
  services.udisks2.enable = true;
  services.upower.enable = true;
  programs.fuse.enable = true;
  services.udev.packages = [
    pkgs.libmtp.out
    pkgs.media-player-info
  ];
  # Bluetooth-Geräte verbinden (bluedevil gab es nur mit Plasma):
  # Symbol im Tray bzw. „Bluetooth-Manager“ über Rofi
  services.blueman.enable = true;
}
