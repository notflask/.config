# Gaming: Steam (CS2 läuft nativ), GameMode, MangoHud
#
# CS2-Startoptionen in Steam:
#   gamemoderun nvidia-offload %command%
{ pkgs, ... }:

{
  programs.steam = {
    enable = true;
    localNetworkGameTransfers.openFirewall = true;
  };

  # CPU-Governor, Prozess-Priorität usw. während des Spielens
  programs.gamemode = {
    enable = true;
    enableRenice = true;
    settings.general.renice = 10;
  };

  environment.systemPackages = with pkgs; [
    mangohud # FPS-/Frametime-Overlay: mangohud %command%
  ];
}
