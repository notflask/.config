{ config, pkgs, ... }:

{
  # ── KDE Plasma 6 (Wayland) ─────────────────────────────────
  services.desktopManager.plasma6.enable = true;

  # Nicht benötigte Standard-Apps weglassen
  environment.plasma6.excludePackages = with pkgs.kdePackages; [
    elisa # Musik → Spotify
    khelpcenter
    krdp # Remote-Desktop-Server
    kwin-x11 # nur Wayland-Sitzung
    plasma-keyboard # Bildschirmtastatur (kein Touchscreen)
    qtvirtualkeyboard
    qrca # QR-Scanner
    discover # kann unter NixOS keine Pakete verwalten
  ];

  # Electron-Apps (Vesktop usw.) nativ unter Wayland
  environment.sessionVariables.NIXOS_OZONE_WL = "1";

  # ── Login: greetd + tuigreet ───────────────────────────────
  services.greetd = {
    enable = true;
    useTextGreeter = true;
    settings.default_session = {
      user = "greeter";
      command = builtins.concatStringsSep " " [
        "${pkgs.tuigreet}/bin/tuigreet"
        "--time"
        "--remember"
        "--remember-session"
        "--asterisks"
        "--theme 'border=magenta;title=magenta;text=white;prompt=blue;input=white;time=blue;action=blue;button=magenta;container=black'"
        "--sessions ${config.services.displayManager.sessionData.desktops}/share/wayland-sessions"
      ];
    };
  };
  # KWallet beim Login über greetd automatisch entsperren
  security.pam.services.greetd.kwallet = {
    enable = true;
    package = pkgs.kdePackages.kwallet-pam;
  };

  # ── Tastatur: us/ru/ua/de, Umschalten mit Alt+Shift ─────────
  services.xserver.xkb = {
    layout = "us,ru,ua,de";
    options = "grp:alt_shift_toggle";
  };
  # Plasma-Vorgabe (in den Systemeinstellungen änderbar)
  environment.etc."xdg/kxkbrc".text = ''
    [Layout]
    LayoutList=us,ru,ua,de
    Options=grp:alt_shift_toggle
    ResetOldOptions=true
    Use=true
  '';

  # ── Schriften ──────────────────────────────────────────────
  fonts.packages = with pkgs; [
    noto-fonts
    noto-fonts-cjk-sans
    noto-fonts-color-emoji
    nerd-fonts.jetbrains-mono
  ];

  environment.systemPackages = [
    pkgs.kdePackages.filelight # Speicherplatz-Übersicht
  ];
}
