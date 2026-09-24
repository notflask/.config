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
    mangohud # FPS-/Frametime-Overlay: mangohud %command%
  ];
}
