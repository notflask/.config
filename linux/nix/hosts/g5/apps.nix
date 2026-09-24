{ pkgs, ... }:

{
  # ── Firefox ────────────────────────────────────────────────
  # KDE-Integration (plasma-browser-integration) bringt das Plasma-Modul mit.
  programs.firefox = {
    enable = true;
    languagePacks = [
      "de"
      "en-US"
    ];
    preferencesStatus = "default"; # nur Voreinstellungen, in about:config änderbar
    preferences = {
      # Hardware-Videodekodierung über VA-API (NVIDIA)
      "media.ffmpeg.vaapi.enabled" = true;
      "widget.dmabuf.force-enabled" = true; # nötig für VA-API auf NVIDIA
      # KDE-Dateidialog statt GTK
      "widget.use-xdg-desktop-portal.file-picker" = 1;
      "widget.use-xdg-desktop-portal.mime-handler" = 1;
    };
  };

  # ── Messenger, Musik, KI-Tools ──────────────────────────────────────
  environment.systemPackages = with pkgs; [
    vesktop # Discord-Client mit funktionierendem Wayland-Screensharing
    telegram-desktop
    spotify

    # KI-Coding-Tools im Terminal: `claude` (Claude Code), `agy` (Antigravity CLI).
    # Updates kommen über `rebuild update`, nicht über die eingebauten Updater.
    claude-code
    antigravity-cli

    # Claude Desktop (Linux-Beta, aus dem offiziellen .deb verpackt)
    (callPackage ../../pkgs/claude-desktop/package.nix { })
  ];

  # Cowork in Claude Desktop startet Aufgaben in einer VM (QEMU/KVM)
  users.users.flask.extraGroups = [ "kvm" ];
  boot.kernelModules = [ "vhost_vsock" ];

  # Spotify Connect / Geräte im lokalen Netz finden
  networking.firewall = {
    allowedTCPPorts = [ 57621 ];
    allowedUDPPorts = [ 5353 ];
  };
}
