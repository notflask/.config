# Gaming: Steam (CS2 nativ, Diablo IV über Proton), GameMode, MangoHud,
# gamescope, Lutris (Battle.net), GPU Screen Recorder, Sober (Roblox)
#
# Spiele starten – Steam-Startoption:
#   gaming-mode %command%
# Details: scripts/gaming-mode.sh und README.md
{ pkgs, ... }:

let
  gaming-mode = pkgs.writeShellApplication {
    name = "gaming-mode";
    runtimeInputs = with pkgs; [
      gamemode
      mangohud
      gamescope
    ];
    text = builtins.readFile ../../scripts/gaming-mode.sh;
  };
in
{
  programs.steam = {
    enable = true;
    localNetworkGameTransfers.openFirewall = true;
    # GE-Proton zusätzlich zu Valves Proton (in Steam unter Kompatibilität wählbar)
    extraCompatPackages = [ pkgs.proton-ge-bin ];
  };

  # CPU-Governor, Prozess-Priorität usw. während des Spielens
  programs.gamemode = {
    enable = true;
    enableRenice = true;
    settings.general.renice = 10;
  };

  # Micro-Compositor für Stretched-Auflösungen (gaming-mode --stretch)
  programs.gamescope.enable = true;

  # ── GPU Screen Recorder (ShadowPlay-Stil) ──────────────────
  # Overlay mit Alt+Z: Aufnahme, Replay („Instant Replay“), Streaming.
  # Nimmt über die GPU auf (NVENC) → praktisch kein FPS-Verlust.
  programs.gpu-screen-recorder = {
    enable = true;
    ui.enable = true;
  };

  # Overlay beim Login im Hintergrund starten (Alt+Z öffnet es)
  environment.etc."xdg/autostart/gpu-screen-recorder-ui.desktop".text = ''
    [Desktop Entry]
    Type=Application
    Name=GPU Screen Recorder
    Exec=gsr-ui launch-daemon
    NoDisplay=true
  '';

  # ── Roblox: Sober (gibt es nur als Flatpak) ────────────────
  services.flatpak.enable = true;

  # Flathub einrichten, Sober installieren, Flatpaks aktuell halten –
  # inkl. der passenden NVIDIA-Erweiterung nach Treiber-Updates.
  # Läuft 2 Minuten nach dem Booten und dann täglich (bremst den Start nicht).
  # Sofort ausführen: sudo systemctl start flatpak-sober
  systemd.services.flatpak-sober = {
    description = "Flathub + Sober einrichten, Flatpaks aktualisieren";
    wants = [ "network-online.target" ];
    after = [ "network-online.target" ];
    path = [ pkgs.flatpak ];
    serviceConfig.Type = "oneshot";
    script = ''
      flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
      if ! flatpak info org.vinegarhq.Sober >/dev/null 2>&1; then
        flatpak install -y --noninteractive flathub org.vinegarhq.Sober
      fi
      flatpak update -y --noninteractive
      # Sober immer auf der RTX 4060
      flatpak override --system \
        --env=__NV_PRIME_RENDER_OFFLOAD=1 \
        --env=__GLX_VENDOR_LIBRARY_NAME=nvidia \
        --env=__VK_LAYER_NV_optimus=NVIDIA_only \
        org.vinegarhq.Sober
    '';
  };
  systemd.timers.flatpak-sober = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "2min";
      OnUnitActiveSec = "1d";
    };
  };

  environment.systemPackages = with pkgs; [
    gaming-mode # gaming-mode %command%
    mangohud # FPS-/Frametime-Overlay
    lutris # Battle.net & andere Launcher
  ];
}
