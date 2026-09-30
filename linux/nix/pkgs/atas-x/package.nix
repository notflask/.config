# ATAS X – Orderflow-/Volumenanalyse (ATAS-Plattform auf .NET 10 + Avalonia)
#
# Offiziell gibt es ATAS X nur für Windows und macOS. Auf ATAS' Update-Server
# liegt aber ein Linux-Build im Alpha-Kanal (platformx_linux_alpha/) – der
# wird hier unverändert verpackt und mit der .NET-10-Laufzeit aus nixpkgs
# gestartet. Einstellungen, Workspaces, Datenbank und Logs landen in
# ~/.config/ATAS/, der App-Ordner im Nix-Store bleibt schreibgeschützt.
# Der eingebaute Updater kann daher nichts ändern.
#
# Version/Hash stehen in source.json – aktualisiert von
# scripts/update-atas-x.sh (läuft automatisch bei `rebuild update`).
{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  makeWrapper,
  copyDesktopItems,
  makeDesktopItem,
  python3,
  dotnetCorePackages,
  fontconfig,
  freetype,
  zlib,
  icu,
  openssl,
  openal,
  libGL,
  vulkan-loader,
  libxkbcommon,
  wayland,
  libx11,
  libxext,
  libxi,
  libxcursor,
  libxrandr,
  libxrender,
  libice,
  libsm,
}:

let
  source = lib.importJSON ./source.json;
  dotnet-runtime = dotnetCorePackages.runtime_10_0;

  # Werden zur Laufzeit per dlopen geladen (Avalonia/X11, OpenGL/Vulkan,
  # GLFW, Sound über OpenAL, .NET: ICU + OpenSSL)
  runtimeLibs = [
    fontconfig
    icu
    openssl
    openal
    libGL
    vulkan-loader
    libxkbcommon
    wayland
    libx11
    libxext
    libxi
    libxcursor
    libxrandr
    libxrender
    libice
    libsm
  ];
in
stdenv.mkDerivation {
  pname = "atas-x";
  inherit (source) version;

  src = fetchurl { inherit (source) url sha256; };
  sourceRoot = "net10.0";

  nativeBuildInputs = [
    autoPatchelfHook
    makeWrapper
    copyDesktopItems
    python3
  ];

  buildInputs = [
    stdenv.cc.cc.lib # libstdc++ für den .NET-Starter
    fontconfig
    freetype
    zlib
    libx11 # GLFW
  ];

  # Kopie des ganzen Programms (publish/) und Bibliotheken für Windows,
  # macOS und andere CPUs werden nicht gebraucht
  postPatch = ''
    rm -rf publish
    find runtimes -mindepth 1 -maxdepth 1 ! -name linux-x64 -exec rm -rf {} +
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/lib/atas-x
    cp -r . $out/lib/atas-x/

    makeWrapper "$out/lib/atas-x/ATAS X" $out/bin/atas-x \
      --set DOTNET_ROOT ${dotnet-runtime}/share/dotnet \
      --prefix LD_LIBRARY_PATH : ${lib.makeLibraryPath runtimeLibs}

    python3 ${./extract-icon.py} OFT.Platform.Avalonia.dll $out/share/icons/hicolor

    runHook postInstall
  '';

  desktopItems = [
    (makeDesktopItem {
      name = "atas-x";
      desktopName = "ATAS X";
      genericName = "Trading-Plattform";
      comment = "Orderflow- und Volumenanalyse";
      exec = "atas-x";
      icon = "atas-x";
      categories = [
        "Office"
        "Finance"
      ];
      startupWMClass = "ATAS X";
    })
  ];

  meta = {
    description = "ATAS X – Plattform für Orderflow- und Volumenanalyse (Linux-Alpha)";
    homepage = "https://atas.net/atas-x/";
    license = lib.licenses.unfree;
    sourceProvenance = [ lib.sourceTypes.binaryBytecode ];
    platforms = [ "x86_64-linux" ];
    mainProgram = "atas-x";
  };
}
