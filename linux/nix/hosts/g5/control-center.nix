# Gigabyte Control Center – Ersatz für das „Fn Control Center“ aus Windows
#
# Der G5 KF ist innen ein Clevo-Board; die tuxedo-drivers (vom Modul
# eingeschaltet) sprechen dessen Firmware an. Das Programm kommt aus
# github:notflask/gigabyte-control-center (Input in flake.nix):
#   - Leistungsmodi: Leise, Energiesparen, Unterhaltung, Leistung
#   - Tastaturbeleuchtung: Farbe, Helligkeit, an/aus
#   - Lüfter: Automatik, Maximum, fest oder eigene Kurve (ab 90 °C immer 100 %)
#
# Tray-Symbol (startet per XDG-Autostart): Klick → Schnellmenü, Hover →
# aktuelle Einstellungen. `gbcc-gui --popup` öffnet das Schnellmenü auch per
# Tastenkürzel, `gbcc` ist die Kommandozeile. Farben kommen aus dem Qt-Thema
# (kdeglobals von matugen, theme.nix).
{ config, inputs, ... }:

let
  gbcc = "${config.services.gigabyte-control-center.package}/bin/gbcc";
in
{
  imports = [ inputs.gigabyte-control-center.nixosModules.default ];

  services.gigabyte-control-center = {
    enable = true;
    group = "users"; # wer Einstellungen ändern darf
    # Firmware-Modus „Leistung“ wie im Windows-Control-Center: höhere
    # Leistungsgrenzen und Lüfterkurve der Firmware. Gilt beim Start, bis im
    # Tray ein anderer Modus gewählt wird – der bleibt dann gespeichert.
    profile = "performance";
  };

  # ── Lüfter-Preset fürs Spielen ─────────────────────────────
  # GameMode (gaming-mode / gamemoderun, siehe gaming.nix) schaltet beim
  # Spielstart auf eine Kurve, die früh kühlt: CPU und RTX 4060 halten so
  # länger hohe Takte, statt am Limit zu drosseln. Ab 85 °C 100 %, ab 90 °C
  # erzwingt der Dienst ohnehin 100 %. Nach dem Spiel zurück auf Automatik.
  programs.gamemode.settings.custom = {
    start = "${gbcc} fan curve 50:25,60:40,70:60,78:80,85:100";
    end = "${gbcc} fan auto";
  };
}
