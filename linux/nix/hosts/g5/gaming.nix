# Gaming: Steam (CS2 nativ, Diablo IV über Proton), GameMode, MangoHud,
# gamescope, Lutris (Battle.net)
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

  # Energieprofil „Leistung“ beim Start setzen
  systemd.services.performance-power-profile = {
    description = "Energieprofil auf Leistung setzen";
    wantedBy = [ "multi-user.target" ];
    after = [ "power-profiles-daemon.service" ];
    requires = [ "power-profiles-daemon.service" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.power-profiles-daemon}/bin/powerprofilesctl set performance";
    };
  };

  environment.systemPackages = with pkgs; [
    gaming-mode # gaming-mode %command%
    mangohud # FPS-/Frametime-Overlay
    lutris # Battle.net & andere Launcher
  ];
}
