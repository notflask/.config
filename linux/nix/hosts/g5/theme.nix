# Aussehen beider Sitzungen (ohne KDE Plasma).
#
# Alles richtet sich nach dem Hintergrundbild: matugen
# (~/.config/matugen/theme.sh) färbt Niri/Hyprland-Rahmen, Waybar, Rofi,
# Mako, Discord, Spotify, Firefox – und die Apps:
#   GTK:  adw-gtk3 bzw. libadwaita + ~/.config/gtk-{3,4}.0/gtk.css
#   Qt:   Breeze-Stil + Farben aus ~/.config/kdeglobals (auch Dolphin & Co.)
# Hell oder dunkel: `theme.sh -m light|dark` oder Sonne/Mond in der Waybar.
# Fest bleiben nur Cursor (macOS), Icons (Papirus) und TTY/Login (Farben von Vague wie
# im Terminal).
{
  config,
  lib,
  pkgs,
  ...
}:

let
  home = config.users.users.flask.home;

  # macOS-Cursor (pkgs.apple-cursor): „macOS“ schwarz mit weißem Rand,
  # „macOS-White“ weiß. Feste Farbe, folgt dem Hintergrundbild nicht.
  cursorTheme = "macOS";

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
    pkgs.apple-cursor # macOS-Cursor, siehe cursorTheme oben
    pkgs.papirus-icon-theme # Papirus-Dark bzw. Papirus-Light (theme.sh)
    pkgs.adw-gtk3 # GTK3 im libadwaita-Look, Farben per gtk.css
    pkgs.kdePackages.breeze # Qt-Stil
    pkgs.kdePackages.plasma-integration # Qt liest Farben/Icons aus kdeglobals
    pkgs.kdePackages.qqc2-desktop-style # dasselbe für QML-Apps
    pkgs.dconf # theme.sh stellt GTK auf hell/dunkel
  ];

  # Qt-Apps nutzen Farben, Icons und Terminal aus ~/.config/kdeglobals (matugen)
  qt.enable = true;
  environment.sessionVariables = {
    QT_QPA_PLATFORMTHEME = "kde";
    XCURSOR_THEME = cursorTheme;
    XCURSOR_SIZE = "24";
  };

  # GTK-Vorgaben (über das Einstellungs-Portal auch für Flatpaks).
  # theme.sh überschreibt Hell/Dunkel, Thema und Icons.
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

  # Farben usw. beim ersten Login einmal erzeugen (danach bei jedem
  # Wallpaper-Wechsel über Waypaper → theme.sh). Die Markierung trägt eine
  # Nummer: erhöhen, wenn theme.sh nach einem Update einmal laufen muss
  # (v2: Hell/Dunkel).
  systemd.user.services.matugen-first-run = {
    description = "Farben aus dem Hintergrundbild erzeugen (einmalig)";
    wantedBy = [ "graphical-session.target" ];
    after = [ "graphical-session.target" ];
    # theme.sh legt die Datei an, sobald es einmal gelaufen ist
    unitConfig.ConditionPathExists = "!%h/.local/state/matugen-theme-v2.done";
    path = [ "/run/current-system/sw" ]; # theme.sh ruft matugen, niri, hyprctl, makoctl …
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "%h/.config/matugen/theme.sh";
    };
  };

  # Discord (Vencord): matugen schreibt ~/.config/Vencord/themes/matugen.theme.css
  # – einmal aktivieren unter Einstellungen → Vencord → Themes.
  # Das frühere Catppuccin-Theme wird entfernt.
  systemd.tmpfiles.rules = [
    "d ${home}/.config/Vencord 0755 flask users -"
    "d ${home}/.config/Vencord/themes 0755 flask users -"
    "r ${home}/.config/Vencord/themes/catppuccin-mocha-mauve.theme.css"
  ];

  # TTY und Login (ly) in den Farben von Vague (wie Ghostty im Dunkelmodus)
  console.colors = [
    "141415" # Hintergrund
    "d8647e" # rot
    "7fa563" # grün
    "f3be7c" # gelb
    "6e94b2" # blau
    "bb9dbd" # magenta
    "aeaed1" # cyan
    "cdcdcd" # Text
    "606079" # grau
    "e08398"
    "99b782"
    "f5cb96"
    "8ba9c1"
    "c9b1ca"
    "bebeda"
    "d7d7d7"
  ];
}
