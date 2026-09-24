# Catppuccin Mocha für alles: Plasma, Qt- und GTK-Apps, Cursor, Icons,
# Konsole/Login, Vesktop.
#
# GTK-Apps (Firefox usw.) nutzen Breeze-GTK – KDE überträgt das
# Farbschema automatisch darauf, dadurch sehen Qt und GTK gleich aus.
#
# Angewendet wird das Theme beim ersten Login (apply-theme --once).
# Erneut anwenden, z. B. nach Akzent-Wechsel:  apply-theme
{ lib, pkgs, ... }:

let
  flavor = "mocha";
  accent = "mauve"; # rosewater flamingo pink mauve red maroon peach yellow green teal sky sapphire blue lavender

  Flavor = lib.toSentenceCase flavor;
  Accent = lib.toSentenceCase accent;

  kdeTheme = pkgs.catppuccin-kde.override {
    flavour = [ flavor ];
    accents = [ accent ];
  };
  cursors = pkgs.catppuccin-cursors."${flavor}${Accent}";
  icons = pkgs.catppuccin-papirus-folders.override { inherit flavor accent; };
  discordTheme = pkgs.catppuccin-discord.override {
    flavour = [ flavor ];
    accents = [ accent ];
  };
  discordCss = "catppuccin-${flavor}-${accent}.theme.css";

  apply-theme = pkgs.writeShellApplication {
    name = "apply-theme";
    runtimeInputs = with pkgs.kdePackages; [
      plasma-workspace # plasma-apply-*, plasma-changeicons
    ];
    runtimeEnv = {
      THEME_LOOKANDFEEL = "Catppuccin-${Flavor}-${Accent}";
      THEME_COLORSCHEME = "Catppuccin${Flavor}${Accent}";
      THEME_CURSOR = "catppuccin-${flavor}-${accent}-cursors";
      THEME_ICONS = "Papirus-Dark";
      THEME_DISCORD_CSS = "/etc/catppuccin/${discordCss}";
    };
    text = builtins.readFile ../../scripts/apply-theme.sh;
  };
in
{
  environment.systemPackages = [
    kdeTheme # Globales Design, Farbschema, Fensterdekoration
    cursors
    icons # Papirus mit Catppuccin-Ordnerfarben
    apply-theme
  ];

  # Stabiler Pfad für Vesktop (wird bei jedem Rebuild aktualisiert)
  environment.etc."catppuccin/${discordCss}".source = "${discordTheme}/share/${discordCss}";

  # Beim ersten Login automatisch anwenden
  environment.etc."xdg/autostart/apply-theme.desktop".text = ''
    [Desktop Entry]
    Type=Application
    Name=Catppuccin-Theme anwenden
    Exec=${apply-theme}/bin/apply-theme --once
    NoDisplay=true
  '';

  # TTY und Login (tuigreet) in Catppuccin-Mocha-Farben
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
