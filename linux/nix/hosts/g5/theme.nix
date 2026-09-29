# Aussehen beider Sitzungen (ohne KDE Plasma).
#
# Farben kommen aus dem Hintergrundbild: matugen (~/.config/matugen/theme.sh)
# färbt Niri/Hyprland-Rahmen, Waybar, Rofi, Mako – und auch die Apps:
#   GTK:  adw-gtk3 bzw. libadwaita + ~/.config/gtk-{3,4}.0/gtk.css
#   Qt:   Breeze-Stil + Farben aus ~/.config/kdeglobals (auch Dolphin & Co.)
# Fest bleiben Cursor (Catppuccin), Icons (Papirus), TTY/Login und Discord
# (Catppuccin Mocha).
{
  config,
  lib,
  pkgs,
  ...
}:

let
  flavor = "mocha";
  accent = "mauve"; # Cursor-, Ordner- und Discord-Farbe

  cursorTheme = "catppuccin-${flavor}-${accent}-cursors";
  cursors = pkgs.catppuccin-cursors."${flavor}${lib.toSentenceCase accent}";
  icons = pkgs.catppuccin-papirus-folders.override { inherit flavor accent; };
  discordTheme = pkgs.catppuccin-discord.override {
    flavour = [ flavor ];
    accents = [ accent ];
  };
  discordCss = "catppuccin-${flavor}-${accent}.theme.css";

  home = config.users.users.flask.home;

  gtkSettings = ''
    [Settings]
    gtk-theme-name=adw-gtk3-dark
    gtk-icon-theme-name=Papirus-Dark
    gtk-cursor-theme-name=${cursorTheme}
    gtk-cursor-theme-size=24
    gtk-font-name=Noto Sans 10
    gtk-application-prefer-dark-theme=true
  '';
in
{
  environment.systemPackages = [
    cursors
    icons # Papirus mit Catppuccin-Ordnerfarben
    pkgs.adw-gtk3 # GTK3 im libadwaita-Look, Farben per gtk.css
    pkgs.kdePackages.breeze # Qt-Stil
    pkgs.kdePackages.plasma-integration # Qt liest Farben/Icons aus kdeglobals
    pkgs.kdePackages.qqc2-desktop-style # dasselbe für QML-Apps
    pkgs.dconf # theme.sh setzt die GTK-Vorgaben zurück
  ];

  # Qt-Apps nutzen Farben, Icons und Terminal aus ~/.config/kdeglobals (matugen)
  qt.enable = true;
  environment.sessionVariables = {
    QT_QPA_PLATFORMTHEME = "kde";
    XCURSOR_THEME = cursorTheme;
    XCURSOR_SIZE = "24";
  };

  # GTK-Vorgaben (über das Einstellungs-Portal auch für Flatpaks)
  programs.dconf.profiles.user.databases = [
    {
      settings."org/gnome/desktop/interface" = {
        color-scheme = "prefer-dark";
        gtk-theme = "adw-gtk3-dark";
        icon-theme = "Papirus-Dark";
        cursor-theme = cursorTheme;
        cursor-size = lib.gvariant.mkInt32 24;
        font-name = "Noto Sans 10";
        monospace-font-name = "JetBrains Mono 10";
      };
    }
  ];
  environment.etc."xdg/gtk-3.0/settings.ini".text = gtkSettings;
  environment.etc."xdg/gtk-4.0/settings.ini".text = gtkSettings;

  # Farben für GTK/Qt beim ersten Login einmal erzeugen (danach bei jedem
  # Wallpaper-Wechsel über Waypaper → theme.sh)
  systemd.user.services.matugen-first-run = {
    description = "Farben aus dem Hintergrundbild erzeugen (einmalig)";
    wantedBy = [ "graphical-session.target" ];
    after = [ "graphical-session.target" ];
    # theme.sh legt die Datei an, sobald es einmal gelaufen ist
    unitConfig.ConditionPathExists = "!%h/.local/state/matugen-theme.done";
    path = [ "/run/current-system/sw" ]; # theme.sh ruft matugen, niri, hyprctl, makoctl …
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "%h/.config/matugen/theme.sh";
    };
  };

  # Discord (Vencord): Theme bereitlegen – aktivieren unter
  # Einstellungen → Vencord → Themes
  environment.etc."catppuccin/${discordCss}".source = "${discordTheme}/share/${discordCss}";
  systemd.tmpfiles.rules = [
    "d ${home}/.config/Vencord 0755 flask users -"
    "d ${home}/.config/Vencord/themes 0755 flask users -"
    "L+ ${home}/.config/Vencord/themes/${discordCss} - - - - /etc/catppuccin/${discordCss}"
  ];

  # TTY und Login (ly) in Catppuccin-Mocha-Farben
  console.colors = [
    "1e1e2e" # base
    "f38ba8" # red
    "a6e3a1" # green
    "f9e2af" # yellow
    "89b4fa" # blue
    "f5c2e7" # pink
    "94e2d5" # teal
    "cdd6f4" # text
    "585b70" # surface2
    "f38ba8"
    "a6e3a1"
    "f9e2af"
    "89b4fa"
    "f5c2e7"
    "94e2d5"
    "a6adc8" # subtext0
  ];
}
