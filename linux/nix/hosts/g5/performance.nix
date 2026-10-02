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
  boot.kernel.sysctl = {
    "kernel.split_lock_mitigate" = 0;

    # ── Speicher: keine Hänger unter Last ──
    # zram (configuration.nix) ist komprimierter RAM, kein langsamer
    # Datenträger: lieber früh dorthin auslagern als den Cache von Spiel
    # und Browser zu verwerfen (Werte aus dem ArchWiki für zram)
    "vm.swappiness" = 180;
    "vm.page-cluster" = 0;
    "vm.watermark_boost_factor" = 0;
    "vm.watermark_scale_factor" = 125;
    # Nicht im Hintergrund RAM umsortieren – das kostet unregelmäßig
    # CPU-Zeit mitten im Spiel (wie SteamOS)
    "vm.compaction_proactiveness" = 0;
    # Geänderte Daten spätestens ab 256 MB wegschreiben statt ab 20 % des
    # RAM (≈3 GB): Steam-Downloads und Shader-Caches erzeugen sonst große
    # Schreibschübe, bei denen alles kurz hängt
    "vm.dirty_bytes" = 268435456;
    "vm.dirty_background_bytes" = 67108864;
  };

  # ── Energieprofil „Leistung“ beim Start setzen ─────────────
  systemd.services.performance-power-profile = {
    description = "Energieprofil auf Leistung setzen";
    # graphical.target, nicht multi-user.target: power-profiles-daemon startet
    # erst nach multi-user.target (After= in seiner Unit), wantedBy multi-user
    # hieße aber „vor multi-user.target“ → Kreis, systemd strich den Dienst
    # bei jedem Start ("Job … deleted to break ordering cycle")
    wantedBy = [ "graphical.target" ];
    after = [ "power-profiles-daemon.service" ];
    requires = [ "power-profiles-daemon.service" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.power-profiles-daemon}/bin/powerprofilesctl set performance";
    };
  };
}
