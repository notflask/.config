# Gaming: Steam (CS2 nativ, Diablo IV über Proton), GameMode, MangoHud,
# gamescope, Lutris (Battle.net), GPU Screen Recorder
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

  environment.systemPackages = with pkgs; [
    gaming-mode # gaming-mode %command%
    mangohud # FPS-/Frametime-Overlay
    lutris # Battle.net & andere Launcher
  ];
}
