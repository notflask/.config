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

  # GSR rät die nötige NVENC-API-Version aus der FFmpeg-Hauptversion
  # (FFmpeg 9 → 13.1). nixpkgs baut FFmpeg aber mit nv-codec-headers-12
  # (API 12.1), die der 595er-Treiber (13.0) kann. Ohne Patch: „your nvidia
  # driver only supports nvenc api version 13.0“ → Aufnahme per CPU (libx264)
  # → Ruckler in CS2. Overlay, damit auch gsr-ui den gepatchten Recorder nutzt.
  nixpkgs.overlays = [
    (final: prev: {
      gpu-screen-recorder = prev.gpu-screen-recorder.overrideAttrs (old: {
        postPatch = (old.postPatch or "") + ''
          substituteInPlace src/codec_query/nvenc.c \
            --replace-fail "NVENCAPI_PACKED_VERSION(13, 1)" "NVENCAPI_PACKED_VERSION(12, 1)"
        '';
      });
    })
  ];

  # Overlay beim Login im Hintergrund starten (Alt+Z öffnet es)
  environment.etc."xdg/autostart/gpu-screen-recorder-ui.desktop".text = ''
    [Desktop Entry]
    Type=Application
    Name=GPU Screen Recorder
    Exec=gsr-ui launch-daemon
    NoDisplay=true
  '';

  # ── Flatpak (für Sober/Roblox, siehe README) ───────────────
  services.flatpak.enable = true;

  environment.systemPackages = with pkgs; [
    gaming-mode # gaming-mode %command%
    mangohud # FPS-/Frametime-Overlay
    lutris # Battle.net & andere Launcher
  ];
}
