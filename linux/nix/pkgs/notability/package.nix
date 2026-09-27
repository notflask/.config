# Notability gibt es nur für iPad/Mac. Unter Linux läuft die offizielle
# Web-App (notability.com/app) – hier als eigenes Fenster mit Eintrag im
# Startmenü: Chromium im App-Modus (von Notability empfohlen) mit eigenem
# Profil, damit Login und Fenster vom normalen Browser getrennt bleiben.
{
  lib,
  writeShellScriptBin,
  makeDesktopItem,
  symlinkJoin,
  chromium,
}:

let
  launcher = writeShellScriptBin "notability" ''
    exec ${lib.getExe chromium} \
      --user-data-dir="''${XDG_DATA_HOME:-$HOME/.local/share}/notability" \
      --no-first-run \
      --no-default-browser-check \
      --app=https://notability.com/app "$@"
  '';

  desktopItem = makeDesktopItem {
    name = "notability";
    desktopName = "Notability";
    genericName = "Notizen";
    comment = "Notizen, PDFs, Audio mit Transkript (Notability Web)";
    exec = "notability";
    icon = "notability";
    categories = [
      "Office"
      "Education"
    ];
    # App-ID, die Chromium im App-Modus setzt (--class greift unter Wayland nicht)
    startupWMClass = "chrome-notability.com__app-Default";
  };
in
symlinkJoin {
  name = "notability-web";
  paths = [
    launcher
    desktopItem
  ];
  # Icon aus dem Web-App-Manifest von notability.com (512×512)
  postBuild = ''
    install -Dm644 ${./notability.png} $out/share/icons/hicolor/512x512/apps/notability.png
  '';
}
