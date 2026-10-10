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
{ inputs, ... }:

{
  imports = [ inputs.gigabyte-control-center.nixosModules.default ];

  services.gigabyte-control-center = {
    enable = true;
    group = "users"; # wer Einstellungen ändern darf
  };
}
