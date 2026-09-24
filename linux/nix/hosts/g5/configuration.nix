{ pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ./nvidia.nix
    ./desktop.nix
    ./apps.nix
    ./gaming.nix
    ./performance.nix
    ./theme.nix
    ./dotfiles.nix
    ./fonts.nix
    ./niri.nix
  ];

  # ── Boot ───────────────────────────────────────────────────
  boot.loader.systemd-boot.enable = true;
  boot.loader.systemd-boot.configurationLimit = 5;
  boot.loader.efi.canTouchEfiVariables = true;

  # ── Netzwerk ───────────────────────────────────────────────
  networking.hostName = "g5";
  networking.networkmanager.enable = true;

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
  zramSwap.enable = true;

  # ── Nix ────────────────────────────────────────────────────
  nixpkgs.config.allowUnfree = true; # NVIDIA-Treiber, Steam, Spotify
  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];
    auto-optimise-store = true;
  };
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
    fastfetch
  ];

  # Wert aus der von nixos-generate-config erzeugten configuration.nix übernehmen
  # und danach NIE mehr ändern (ist kein Update-Schalter).
  system.stateVersion = "26.05";
}
