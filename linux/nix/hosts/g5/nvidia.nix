# Hybrid-Grafik: Intel Iris Xe (i5-12500H) + NVIDIA RTX 4060 Laptop
#
# PRIME Offload: Alles läuft standardmäßig auf der Intel-iGPU (Akku, Temperatur).
# Die NVIDIA-GPU wird nur bei Bedarf genutzt:
#   nvidia-offload <programm>
# oder in KDE: Rechtsklick auf die App im Startmenü → Start mit dedizierter Grafikkarte
# (dafür sorgt switcheroo-control).
#
# Bus-IDs prüfen:  lspci -D | grep -Ei 'vga|3d'
#   0000:00:02.0 → "PCI:0:2:0"   0000:01:00.0 → "PCI:1:0:0"
# (hexadezimal → dezimal umrechnen, falls Werte > 9)
{ config, pkgs, ... }:

{
  services.xserver.videoDrivers = [
    "modesetting"
    "nvidia"
  ];

  hardware.graphics = {
    enable = true;
    enable32Bit = true;
    extraPackages = with pkgs; [
      intel-media-driver # VA-API für Intel (iHD) – Videodekodierung in Firefox
      vpl-gpu-rt # Intel QuickSync (oneVPL)
    ];
  };

  hardware.nvidia = {
    package = config.boot.kernelPackages.nvidiaPackages.stable;
    open = true; # offene Kernel-Module, empfohlen ab Turing/RTX 20
    modesetting.enable = true;
    nvidiaSettings = true;

    # dGPU im Leerlauf komplett abschalten (RTD3)
    powerManagement.enable = true;
    powerManagement.finegrained = true;

    prime = {
      offload.enable = true;
      offload.enableOffloadCmd = true; # stellt `nvidia-offload` bereit
      intelBusId = "PCI:0:2:0";
      nvidiaBusId = "PCI:1:0:0";
    };
  };

  # GPU-Auswahl im KDE-Kontextmenü („dedizierte Grafikkarte“)
  services.switcherooControl.enable = true;

  # Videobeschleunigung über die Intel-iGPU (nicht global auf nvidia setzen!)
  environment.sessionVariables.LIBVA_DRIVER_NAME = "iHD";
}
