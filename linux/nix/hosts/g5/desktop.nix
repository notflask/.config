{ config, pkgs, ... }:

{
  # ── KDE Plasma 6 (Wayland) ─────────────────────────────────
  services.desktopManager.plasma6.enable = true;

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

  # ── Tastatur ───────────────────────────────────────────────
  # Standard für neue Plasma-Profile; später in den Systemeinstellungen änderbar.
  services.xserver.xkb = {
    layout = "us,ru,ua,de";
    options = "grp:alt_shift_toggle";
  };

  # ── Schriften ──────────────────────────────────────────────
  fonts.packages = with pkgs; [
    noto-fonts
    noto-fonts-cjk-sans
    noto-fonts-color-emoji
    nerd-fonts.jetbrains-mono
  ];

  # ── Werkzeuge ──────────────────────────────────────────────
  programs.neovim = {
    enable = true;
    defaultEditor = true;
  };

  environment.systemPackages = with pkgs; [
    ghostty
    tmux
    wl-clipboard
    kdePackages.kate
    kdePackages.ark
    kdePackages.filelight
  ];
}
