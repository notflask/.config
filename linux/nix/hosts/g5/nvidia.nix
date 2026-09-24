# Hybrid-Grafik: Intel Iris Xe (i5-12500H) + NVIDIA RTX 4060 Laptop
#
# Zwei Boot-Einträge:
#
#   NixOS (Standard)  PRIME Offload. KWin läuft auf der Intel-iGPU, die RTX 4060
#                     schläft im Leerlauf (Akku, leise). Bei Bedarf:
#                       nvidia-offload <programm>
#                     oder Rechtsklick im KDE-Startmenü → dedizierte Grafikkarte.
#
#   NixOS (gaming)    KWin läuft auf der RTX 4060. Spiele auf dem externen
#                     Monitor (am NVIDIA-Anschluss) gehen ohne Umweg über die
#                     iGPU direkt raus → mehr FPS, weniger Latenz. Die dGPU ist
#                     dauerhaft an (am Netzteil benutzen).
#
# Die PCI-Adressen setzt scripts/install.sh automatisch. Manuell prüfen:
#   lspci -D | grep -Ei 'vga|3d'
{
  config,
  lib,
  pkgs,
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

    # Verschiebt Leistung dynamisch zwischen CPU und GPU (nvidia-powerd)
    dynamicBoost.enable = true;

    # dGPU im Leerlauf komplett abschalten (RTD3)
    powerManagement.enable = true;
    powerManagement.finegrained = true;

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

  # GPU-Auswahl im KDE-Kontextmenü („dedizierte Grafikkarte“)
  services.switcherooControl.enable = true;

  # Videobeschleunigung über die Intel-iGPU (nicht global auf nvidia setzen!)
  environment.sessionVariables.LIBVA_DRIVER_NAME = "iHD";

  # ── Boot-Eintrag „gaming“ ──────────────────────────────────
  specialisation.gaming.configuration = {
    system.nixos.tags = [ "gaming" ];
    environment.etc."specialisation".text = "gaming"; # für scripts/rebuild.sh

    # dGPU treibt den Desktop → muss wach bleiben
    hardware.nvidia.powerManagement.finegrained = lib.mkForce false;

    environment.sessionVariables = {
      # KWin rendert auf der NVIDIA, der interne Bildschirm wird von dort kopiert
      KWIN_DRM_DEVICES = "/dev/dri/nvidia-dgpu:/dev/dri/intel-igpu";
      # Firefox-Videodekodierung auf derselben GPU wie der Desktop
      LIBVA_DRIVER_NAME = lib.mkForce "nvidia";
      NVD_BACKEND = "direct";
      MOZ_DISABLE_RDD_SANDBOX = "1";
    };

    # thermald drosselt die CPU auf manchen Gaming-Laptops zu früh;
    # die Firmware (EC) schützt weiterhin vor Überhitzung.
    services.thermald.enable = lib.mkForce false;

    # Energieprofil „Leistung“ beim Start setzen
    systemd.services.gaming-power-profile = {
      description = "Energieprofil auf Leistung setzen";
      wantedBy = [ "multi-user.target" ];
      after = [ "power-profiles-daemon.service" ];
      requires = [ "power-profiles-daemon.service" ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${pkgs.power-profiles-daemon}/bin/powerprofilesctl set performance";
      };
    };
  };
}
