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

    # Kein NMI-Watchdog (siehe Watchdogs unten)
    "kernel.nmi_watchdog" = 0;
  };

  # ── Watchdogs aus (wie CachyOS) ────────────────────────────
  # Der Soft-/NMI-Watchdog prüft regelmäßig jeden Kern auf Hänger und weckt
  # sie dafür per Interrupt – kleine, unregelmäßige Unterbrechungen. Die
  # Hardware-Watchdogs (iTCO, Intel-OC) nutzt hier niemand: systemd hat
  # RuntimeWatchdog unter NixOS aus. Gewinn klein, aber kostenlos.
  boot.kernelParams = [
    "nowatchdog"
    # ── Kernel unterbricht sofort, nicht erst beim nächsten Takt ──
    # Seit 6.18 ist "lazy" Standard (gut für Durchsatz): ein Prozess, der
    # gerade wach wird (Eingabe, Audio, Compositor), wartet bis zu 1 ms auf
    # den nächsten Tick. "full" wie bei CachyOS: kürzere Wege von Maus/Taste
    # bis zum Bild. Zurück: Zeile löschen (Prüfen: dmesg | grep Preempt).
    "preempt=full"
  ];
  boot.blacklistedKernelModules = [
    "iTCO_wdt"
    "intel_oc_wdt"
  ];

  # ── CPU taktet nach Warten auf Daten sofort hoch ───────────
  # intel_pstate hebt den Mindesttakt kurz an, wenn ein Prozess nach
  # Ein-/Ausgabe (Laden, Netzwerk, Eingaben) weiterläuft – weniger Mikro-
  # Ruckler beim Nachladen. Windows macht das ähnlich.
  systemd.tmpfiles.rules = [
    "w /sys/devices/system/cpu/intel_pstate/hwp_dynamic_boost - - - - 1"
  ];

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

  # ── Dauerleistung der CPU begrenzen ────────────────────────
  # Firmware-Modus „Leistung“ erlaubt der CPU dauerhaft 90 W (PL1). Der
  # i5-12500H ist für 45 W gebaut und teilt die Heatpipes mit der RTX 4060:
  # Mit Spiel + Discord-Stream lief er bei 98 °C und 100 % Lüfter ständig ins
  # Thermal-Throttling (43 von 112 min) – der Takt springt, alles ruckelt.
  # 55 W hielten ihn sicher unter der Grenze, kosteten aber Leistung bei
  # Dauerlast; 65 W als Mittelweg. Kurze Spitzen (PL2, 120 W) bleiben.
  # Prüfen: cat /sys/class/powercap/intel-rapl:0/constraint_0_power_limit_uw
  # und /sys/devices/system/cpu/cpu0/thermal_throttle/package_throttle_count
  systemd.services.cpu-power-limit =
    let
      watts = 65;
    in
    {
      description = "CPU-Dauerleistung (PL1) auf ${toString watts} W begrenzen";
      wantedBy = [
        "graphical.target"
        "post-resume.target" # nach Suspend neu setzen
      ];
      # nach dem Firmware-Modus und dem Energieprofil, die PL1 neu setzen können
      after = [
        "performance-power-profile.service"
        "gigabyte-control-center.service"
        "post-resume.target"
      ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${pkgs.runtimeShell} -c 'echo ${toString (watts * 1000000)} > /sys/class/powercap/intel-rapl:0/constraint_0_power_limit_uw'";
      };
    };
}
