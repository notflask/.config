# System-Tweaks für Leistung und gleichmäßige Frametimes
{ pkgs, ... }:

{
  # ── CPU-Scheduler: scx_lavd (sched_ext) ────────────────────
  # Für Gaming entwickelt (Steam Deck), soll Ruckler unter Last
  # reduzieren. Stürzt er ab, übernimmt automatisch der normale
  # Kernel-Scheduler. Auf P-/E-Kern-CPUs Wirkung mit MangoHud
  # vergleichen – zum Abschalten `enable = false` setzen.
  services.scx = {
    enable = true;
    scheduler = "scx_lavd";
    extraArgs = [ "--performance" ];
  };

  # ── NTSYNC: schnelle Windows-Synchronisation für Proton ────
  # Proton / GE-Proton nutzen /dev/ntsync automatisch (z. B. Diablo IV)
  boot.kernelModules = [ "ntsync" ];
  services.udev.extraRules = ''
    KERNEL=="ntsync", MODE="0666"
  '';

  # ── Split-Lock-Bremse aus (wie SteamOS) ────────────────────
  # Der Kernel bremst sonst Programme mit Split-Locks absichtlich aus –
  # einige Windows-Spiele ruckeln dadurch stark.
  boot.kernel.sysctl."kernel.split_lock_mitigate" = 0;

  # ── Energieprofil „Leistung“ beim Start setzen ─────────────
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
}
