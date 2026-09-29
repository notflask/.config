# Grafik: Intel Iris Xe (i5-12500H) + NVIDIA RTX 4060 Laptop
#
# Der Desktop (Niri bzw. Hyprland) läuft komplett auf der RTX 4060. Spiele auf
# dem externen Monitor (am NVIDIA-Anschluss) gehen ohne Umweg über die iGPU
# direkt raus → mehr FPS, weniger Latenz. Die Intel-iGPU treibt nur noch den
# internen Bildschirm (eDP-1), das Bild dafür wird von der NVIDIA kopiert.
# Die dGPU ist dauerhaft an – gedacht für den Betrieb am Netzteil.
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
    # VA-API für die Intel-iGPU – kann (anders als nvidia-vaapi-driver)
    # auch kodieren.
    extraPackages = [ pkgs.intel-media-driver ];
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

  # Sonst halten Wayland-Compositoren unnötig viel VRAM fest (Empfehlung aus
  # dem Niri-Wiki, gilt genauso für Hyprland). Unter NixOS heißt der
  # Hyprland-Prozess wegen des Wrappers ".Hyprland-wrapped".
  environment.etc."nvidia/nvidia-application-profiles-rc.d/50-limit-free-buffer-pool-in-wayland-compositors.json".text =
    builtins.toJSON {
      rules =
        map
          (procname: {
            pattern = {
              feature = "procname";
              matches = procname;
            };
            profile = "Limit Free Buffer Pool On Wayland Compositors";
          })
          [
            "niri"
            ".niri-wrapped"
            "Hyprland"
            ".Hyprland-wrapped"
          ];
      profiles = [
        {
          name = "Limit Free Buffer Pool On Wayland Compositors";
          settings = [
            {
              key = "GLVidHeapReuseRatio";
              value = 0;
            }
          ];
        }
      ];
    };

  # Hält den Treiberzustand (inkl. Taktsperre unten) auch ohne aktive Clients
  hardware.nvidia.nvidiaPersistenced = true;

  # ── Mindesttakt für die GPU ────────────────────────────────
  # Im Leerlauf fällt die 4060 auf ~480 MHz. Startet dann eine Animation
  # (Workspace-/Fensterwechsel in Niri/Hyprland), braucht der Treiber ein paar
  # hundert ms zum Hochtakten → die ersten Bilder ruckeln. Mit festem
  # Mindesttakt ist jede Animation sofort flüssig. Kostet ~10–15 W im
  # Leerlauf. Zurücksetzen: `sudo nvidia-smi -rgc`
  systemd.services.nvidia-min-clock = {
    description = "Mindesttakt für die NVIDIA-GPU setzen";
    wantedBy = [
      "multi-user.target"
      "post-resume.target" # nach Suspend neu setzen
    ];
    after = [
      "nvidia-persistenced.service"
      "post-resume.target"
    ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${config.hardware.nvidia.package.bin}/bin/nvidia-smi --lock-gpu-clocks=1500,3105";
    };
  };

  # Feste Namen für die GPUs (cardN kann sich zwischen Boots ändern)
  services.udev.extraRules = ''
    KERNEL=="card*", SUBSYSTEM=="drm", KERNELS=="${intelPci}", SYMLINK+="dri/intel-igpu"
    KERNEL=="card*", SUBSYSTEM=="drm", KERNELS=="${nvidiaPci}", SYMLINK+="dri/nvidia-dgpu"
    KERNEL=="renderD*", SUBSYSTEM=="drm", KERNELS=="${nvidiaPci}", SYMLINK+="dri/nvidia-render"
    KERNEL=="renderD*", SUBSYSTEM=="drm", KERNELS=="${intelPci}", SYMLINK+="dri/intel-render"
  '';

  environment.sessionVariables = {
    # Hyprland rendert auf der NVIDIA (erste GPU), der interne Bildschirm wird
    # von dort kopiert. Niri: render-drm-device in niri/config.kdl
    AQ_DRM_DEVICES = "/dev/dri/nvidia-dgpu:/dev/dri/intel-igpu";
    # Videodekodierung (Firefox) auf derselben GPU wie der Desktop.
    # nvidia-vaapi-driver braucht Firefox ohne RDD-Sandbox für den Decoder.
    LIBVA_DRIVER_NAME = "nvidia";
    NVD_BACKEND = "direct";
    MOZ_DISABLE_RDD_SANDBOX = "1";
  };
}
