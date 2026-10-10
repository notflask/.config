{ pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ./nvidia.nix
    ./desktop.nix
    ./apps.nix
    ./gaming.nix
    ./performance.nix
    ./control-center.nix
    ./theme.nix
    ./dotfiles.nix
    ./fonts.nix
    ./niri.nix
    ./hyprland.nix
    ./vpn.nix
    ./network.nix
  ];

  # ── Boot ───────────────────────────────────────────────────
  boot.loader.systemd-boot.enable = true;
  boot.loader.systemd-boot.configurationLimit = 5;
  # Boot-Menü nur 1 s statt 5 s; ältere Generationen: beim Start Leertaste
  # gedrückt halten, dann bleibt das Menü stehen
  boot.loader.timeout = 1;
  boot.loader.efi.canTouchEfiVariables = true;

  # Start ohne Textflut: Ladebildschirm (Plymouth, Thema "bgrt": Logo des
  # Laptop-Herstellers aus der Firmware + Ladekreis) statt Kernel- und
  # systemd-Meldungen. Fehler landen weiter im Journal (journalctl -b).
  boot.plymouth = {
    enable = true;
    theme = "bgrt";
  };
  boot.consoleLogLevel = 3;
  boot.initrd.verbose = false;
  boot.kernelParams = [
    "quiet"
    "udev.log_level=3"
    "systemd.show_status=auto"
  ];

  # ── Netzwerk ───────────────────────────────────────────────
  networking.hostName = "g5";
  networking.networkmanager.enable = true; # Tuning in network.nix

  # ── Zeit & Sprache ─────────────────────────────────────────
  time.timeZone = "Europe/Berlin";
  i18n.defaultLocale = "de_DE.UTF-8";
  console.keyMap = "us"; # Tastatur bleibt US als erstes Layout

  # Default user shell
  programs.fish.enable = true;

  # ── Benutzer ───────────────────────────────────────────────
  # Passwort setzt scripts/install.sh
  users.users.flask = {
    isNormalUser = true;
    description = "flask";
    shell = pkgs.fish;
    extraGroups = [
      "wheel"
      "networkmanager"
    ];
  };

  # ── Audio ──────────────────────────────────────────────────
  security.rtkit.enable = true;
  services.pulseaudio.enable = false;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  # ── Laptop ─────────────────────────────────────────────────
  hardware.bluetooth.enable = true;
  hardware.bluetooth.powerOnBoot = true;
  hardware.enableRedistributableFirmware = true;
  # Kein thermald: drosselt die CPU auf Gaming-Laptops oft zu früh.
  # Die Firmware (EC) schützt weiterhin vor Überhitzung.
  services.power-profiles-daemon.enable = true;
  services.fwupd.enable = true;
  zramSwap.enable = true; # Tuning in performance.nix

  # Keine Schreibzugriffe beim bloßen Lesen von Dateien
  fileSystems."/".options = [ "noatime" ];

  # Hängende Dienste beim Herunterfahren nach 10 s beenden statt nach 90 s –
  # für System- und Benutzerdienste (Apps der Sitzung, Tray, Autostart)
  systemd.settings.Manager.DefaultTimeoutStopSec = "10s";
  systemd.user.settings.Manager.DefaultTimeoutStopSec = "10s";

  # ── Nix ────────────────────────────────────────────────────
  nixpkgs.config.allowUnfree = true; # NVIDIA-Treiber, Steam, Spotify
  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];
  };
  # Store wöchentlich entdoppeln statt bei jedem Build (rebuild ist schneller)
  nix.optimise.automatic = true;
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 14d";
  };

  environment.systemPackages = with pkgs; [
    git
    curl
    wget
    pciutils
    usbutils
    htop
    btop-cuda # btop mit GPU-Anzeige für die RTX 4060 (NVML)
    fastfetch
  ];

  # Wert aus der von nixos-generate-config erzeugten configuration.nix übernehmen
  # und danach NIE mehr ändern (ist kein Update-Schalter).
  system.stateVersion = "26.05";
}
