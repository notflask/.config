# Netzwerk-Tuning für stabilen Ping und schnelle Verbindungen
{ pkgs, ... }:

{
  # ── TCP: BBR statt CUBIC ───────────────────────────────────
  # CUBIC füllt die Puffer im Router, bis Pakete verloren gehen – bei großen
  # Downloads (Steam, Updates) steigt dann der Ping in Spielen/Discord.
  # BBR misst die Bandbreite und hält die Warteschlange klein. `fq` sorgt
  # für das gleichmäßige Senden (Pacing), das BBR voraussetzt.
  boot.kernelModules = [ "tcp_bbr" ];
  boot.kernel.sysctl = {
    "net.core.default_qdisc" = "fq";
    "net.ipv4.tcp_congestion_control" = "bbr";

    # Offene Verbindungen (Browser, Keep-Alive) nach einer Pause nicht
    # wieder langsam anlaufen lassen
    "net.ipv4.tcp_slow_start_after_idle" = 0;
    # Nur wenig ungesendete Daten im Kernel puffern: HTTP/2-Prioritäten im
    # Browser greifen sofort, wichtige Anfragen warten nicht hinter großen
    "net.ipv4.tcp_notsent_lowat" = 131072;
    # Im WireGuard-Tunnel (MTU 1380) hängen Verbindungen sonst, wenn
    # unterwegs ICMP „Fragmentation needed“ verloren geht
    "net.ipv4.tcp_mtu_probing" = 1;
    # TCP Fast Open auch für eingehende Verbindungen
    "net.ipv4.tcp_fastopen" = 3;

    # Größere Puffer, damit schnelle Downloads über ~40 ms VPN-Latenz
    # die Leitung auslasten können (Sendepuffer war auf 4 MB begrenzt)
    "net.core.rmem_max" = 33554432;
    "net.core.wmem_max" = 33554432;
    "net.ipv4.tcp_wmem" = "4096 65536 33554432";
  };

  # ── Realtek-LAN: Energy Efficient Ethernet aus ─────────────
  # Der RTL8111h legt den Link bei wenig Verkehr schlafen; das Aufwachen
  # sorgt für Ping-Spitzen und bei manchen Routern für Link-Abbrüche.
  services.udev.extraRules = ''
    ACTION=="add", SUBSYSTEM=="net", DRIVERS=="r8169", RUN+="${pkgs.ethtool}/bin/ethtool --set-eee $name eee off"
  '';

  # ── WLAN: kein Stromsparmodus ──────────────────────────────
  # Intel-WLAN im Power-Save puffert Pakete → Ping schwankt stark
  networking.networkmanager.wifi.powersave = false;

  environment.systemPackages = [ pkgs.ethtool ];
}
