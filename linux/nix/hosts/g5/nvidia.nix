# Grafik: Intel Iris Xe (i5-12500H) + NVIDIA RTX 4060 Laptop
#
# KWin (der Desktop) läuft komplett auf der RTX 4060. Spiele auf dem externen
# Monitor (am NVIDIA-Anschluss) gehen ohne Umweg über die iGPU direkt raus →
# mehr FPS, weniger Latenz. Die Intel-iGPU treibt nur noch den internen
# Bildschirm (eDP-1), das Bild dafür wird von der NVIDIA kopiert.
# Die dGPU ist dauerhaft an – gedacht für den Betrieb am Netzteil.
#
# Die PCI-Adressen setzt scripts/install.sh automatisch. Manuell prüfen:
#   lspci -D | grep -Ei 'vga|3d'
{
  config,
  lib,
  ...
}:

let
  intelPci = "0000:00:02.0";
  nvidiaPci = "0000:01:00.0";

  # "0000:01:00.0" → "PCI:1:0:0" (NixOS erwartet dezimale Werte)
  toBusId =
    addr:
    let
      m = builtins.match "[0-9a-fA-F]+:([0-9a-fA-F]+):([0-9a-fA-F]+)\\.([0-7])" addr;
      dec = i: toString (lib.fromHexString (builtins.elemAt m i));
    in
    "PCI:${dec 0}:${dec 1}:${builtins.elemAt m 2}";
in
{
  services.xserver.videoDrivers = [
    "modesetting"
    "nvidia"
  ];

  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  hardware.nvidia = {
    package = config.boot.kernelPackages.nvidiaPackages.stable;
    open = true; # offene Kernel-Module, empfohlen ab Turing/RTX 20
    modesetting.enable = true;
    nvidiaSettings = true;

    # Verschiebt Leistung dynamisch zwischen CPU und GPU (nvidia-powerd)
    dynamicBoost.enable = true;

    # VRAM über Suspend retten; dGPU bleibt aber immer an (kein RTD3)
    powerManagement.enable = true;
    powerManagement.finegrained = false;

    prime = {
      offload.enable = true;
      offload.enableOffloadCmd = true; # stellt `nvidia-offload` bereit
      intelBusId = toBusId intelPci;
      nvidiaBusId = toBusId nvidiaPci;
    };
  };

  # Feste Namen für die GPUs (cardN kann sich zwischen Boots ändern)
  services.udev.extraRules = ''
    KERNEL=="card*", SUBSYSTEM=="drm", KERNELS=="${intelPci}", SYMLINK+="dri/intel-igpu"
    KERNEL=="card*", SUBSYSTEM=="drm", KERNELS=="${nvidiaPci}", SYMLINK+="dri/nvidia-dgpu"
  '';

  environment.sessionVariables = {
    # KWin rendert auf der NVIDIA, der interne Bildschirm wird von dort kopiert
    KWIN_DRM_DEVICES = "/dev/dri/nvidia-dgpu:/dev/dri/intel-igpu";
    # Videodekodierung (Firefox) auf derselben GPU wie der Desktop.
    # nvidia-vaapi-driver braucht Firefox ohne RDD-Sandbox für den Decoder.
    LIBVA_DRIVER_NAME = "nvidia";
    NVD_BACKEND = "direct";
    MOZ_DISABLE_RDD_SANDBOX = "1";
  };
}
