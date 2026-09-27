# Niri als zweite Sitzung neben KDE – im Login (tuigreet) mit F3 wählbar.
# Die Niri-Config selbst liegt im Repo: linux/.config/niri/config.kdl
{ lib, pkgs, ... }:

let
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

  # Alle Spalten des aktuellen Workspaces gleich breit (2 → je 50 %,
  # 3 → je 33,3 % …) und übereinander gestapelte Fenster gleich hoch.
  niri-even-split = pkgs.writeShellApplication {
    name = "niri-even-split";
    runtimeInputs = with pkgs; [ jq ];
    text = ''
      ws=$(niri msg --json workspaces | jq '.[] | select(.is_focused) | .id')
      windows=$(niri msg --json windows | jq --argjson ws "$ws" \
        '[.[] | select(.workspace_id == $ws and (.is_floating | not))]')

      # Pro Spalte ein Fenster – die Breite gilt für die ganze Spalte
      mapfile -t columns < <(jq -r \
        'group_by(.layout.pos_in_scrolling_layout[0]) | .[][0].id' <<<"$windows")
      [ "''${#columns[@]}" -eq 0 ] && exit 0

      width=$(jq -n "100 / ''${#columns[@]}")
      for id in "''${columns[@]}"; do
        niri msg action set-window-width --id "$id" "$width%"
      done
      for id in $(jq -r '.[].id' <<<"$windows"); do
        niri msg action reset-window-height --id "$id"
      done

      # Ansicht zurechtrücken, dann den Fokus zurückgeben. Niri scrollt nur,
      # wenn der Fokus auf eine Spalte wechselt, die über den Rand ragt –
      # daher beide Enden: letzte Spalte (Lücke links), erste (Lücke rechts).
      focused=$(niri msg --json focused-window | jq '.id // empty')
      niri msg action focus-column-last
      niri msg action focus-column-first
      if [ -n "$focused" ]; then
        niri msg action focus-window --id "$focused"
      fi
    '';
  };
in
{
  programs.niri = {
    enable = true;
    useNautilus = false; # KDE-Dateidialog statt Nautilus
  };

  # KDE bleibt Standard (das Niri-Modul würde Niri vorgeben)
  services.displayManager.defaultSession = "plasma";

  # Wie unter KDE: KWallet statt GNOME-Keyring, KDE-Dateidialog
  # → Passwörter und gespeicherte Logins sind in beiden Sitzungen dieselben.
  services.gnome.gnome-keyring.enable = lib.mkForce false;
  xdg.portal.config.niri = {
    "org.freedesktop.impl.portal.FileChooser" = lib.mkForce "kde";
    "org.freedesktop.impl.portal.Secret" = lib.mkForce "kwallet";
  };

  # Qt-Apps nutzen auch unter Niri das KDE-Farbschema (Catppuccin)
  environment.sessionVariables.QT_QPA_PLATFORMTHEME = "kde";

  # Sperrbildschirm (Super+Alt+L) inkl. PAM
  programs.hyprlock.enable = true;

  # Programme, die deine Niri-/Waybar-Config startet
  environment.systemPackages = with pkgs; [
    xwayland-satellite # X11-Apps (Steam, Spiele) – startet Niri automatisch
    waybar
    fuzzel # Starter unter Hyprland
    rofi # Spotlight-Starter (Super+Space)
    awww # Hintergrund mit Übergängen (Backend für Waypaper)
    waypaper
    matugen
    cliphist
    wl-clip-persist # Zwischenablage überlebt das Schließen der Quell-App
    playerctl
    imagemagick # abgerundete Cover im Waybar-Medienwidget
    brightnessctl
    pavucontrol
    wlogout
    mako # makoctl (Theme neu laden)
    libnotify # notify-send
    screenshot-edit # Super+Shift+S
    niri-even-split # Super+E
  ];

  # Nur in der Niri-Sitzung: Polkit-Agent (Passwortabfragen) und
  # Benachrichtigungen – unter KDE übernimmt das Plasma selbst.
  systemd.user.services = {
    niri-polkit-agent = {
      description = "KDE-Polkit-Agent für Niri";
      wantedBy = [ "niri.service" ];
      partOf = [ "niri.service" ];
      after = [ "niri.service" ];
      serviceConfig = {
        ExecStart = "${pkgs.kdePackages.polkit-kde-agent-1}/libexec/polkit-kde-authentication-agent-1";
        Restart = "on-failure";
      };
    };
    niri-notifications = {
      description = "Benachrichtigungen (mako) für Niri";
      wantedBy = [ "niri.service" ];
      partOf = [ "niri.service" ];
      after = [ "niri.service" ];
      serviceConfig = {
        ExecStart = "${pkgs.mako}/bin/mako";
        Restart = "on-failure";
      };
    };
  };

  # NVIDIA: Niri sonst mit unnötig hohem VRAM-Verbrauch (Empfehlung aus dem Niri-Wiki)
  environment.etc."nvidia/nvidia-application-profiles-rc.d/50-limit-free-buffer-pool-in-wayland-compositors.json".text =
    builtins.toJSON {
      rules = [
        {
          pattern = {
            feature = "procname";
            matches = "niri";
          };
          profile = "Limit Free Buffer Pool On Wayland Compositors";
        }
      ];
      profiles = [
        {
          name = "Limit Free Buffer Pool On Wayland Compositors";
          settings = [
            {
              key = "GLVidHeapReuseRatio";
              value = 0;
            }
          ];
        }
      ];
    };
}
