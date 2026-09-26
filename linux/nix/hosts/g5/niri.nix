# Niri als zweite Sitzung neben KDE – im Login (tuigreet) mit F3 wählbar.
# Die Niri-Config selbst liegt im Repo: linux/.config/niri/config.kdl
{ lib, pkgs, ... }:

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
