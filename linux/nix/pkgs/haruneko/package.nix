# HaruNeko – Manga-, Anime- und Novel-Downloader (Nachfolger von HakuNeko)
#
# Für Linux gibt es nur ein Snap mit eigenem Electron. Daraus wird nur die
# eigentliche App (resources/app, wenige hundert KB) genommen und mit dem
# Electron aus nixpkgs gestartet – passend zur Hauptversion, mit der das
# Snap gebaut wurde (`electron` in source.json). Die Oberfläche selbst lädt
# die App von app.hakuneko.download, Einstellungen und Lesezeichen landen
# in ~/.config/hakuneko-electron/.
#
# Version/Hash stehen in source.json – aktualisiert von
# scripts/update-haruneko.sh (läuft automatisch bei `rebuild update`).
{
  lib,
  pkgs,
  stdenvNoCC,
  fetchurl,
  squashfsTools,
  makeWrapper,
  copyDesktopItems,
  makeDesktopItem,
  electron,
}:

let
  source = lib.importJSON ./source.json;
  # Fällt auf das Standard-Electron zurück, falls nixpkgs die Version nicht hat
  electron' = pkgs."electron_${source.electron}" or electron;

  icon = fetchurl {
    url = "https://raw.githubusercontent.com/manga-download/haruneko/f8e87b4ad2e35b2b22f88002a23006cd784e209c/app/res/darwin/app.iconset/icon_256x256.png";
    hash = "sha256-/3OAe99zI7hh2nLguWyLxmGF27MpTTbUkcPMWNWCcr4=";
  };
in
stdenvNoCC.mkDerivation {
  pname = "haruneko";
  inherit (source) version;

  src = fetchurl { inherit (source) url sha256; };

  nativeBuildInputs = [
    squashfsTools
    makeWrapper
    copyDesktopItems
  ];

  unpackPhase = ''
    runHook preUnpack
    unsquashfs -q -d snap $src resources/app
    runHook postUnpack
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/lib/haruneko
    cp -r snap/resources/app $out/lib/haruneko/

    makeWrapper ${lib.getExe electron'} $out/bin/haruneko \
      --add-flags $out/lib/haruneko/app \
      --add-flags "\''${NIXOS_OZONE_WL:+\''${WAYLAND_DISPLAY:+--ozone-platform-hint=auto}}"

    install -Dm644 ${icon} $out/share/icons/hicolor/256x256/apps/haruneko.png

    runHook postInstall
  '';

  desktopItems = [
    (makeDesktopItem {
      name = "haruneko";
      desktopName = "HaruNeko";
      genericName = "Manga-Downloader";
      comment = "Manga, Anime und Novels herunterladen";
      exec = "haruneko";
      icon = "haruneko";
      categories = [
        "Network"
        "Graphics"
      ];
      startupWMClass = "hakuneko-electron";
    })
  ];

  meta = {
    description = "HaruNeko – Manga-, Anime- und Novel-Downloader";
    homepage = "https://github.com/manga-download/haruneko";
    license = lib.licenses.unlicense;
    platforms = [ "x86_64-linux" ];
    mainProgram = "haruneko";
  };
}
