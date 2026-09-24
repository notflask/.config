# Claude Desktop (offizielle Linux-Beta von Anthropic, nur als .deb verfügbar)
#
# Das .deb wird entpackt und in einer FHS-Umgebung gestartet: Für die App sieht
# das System dort aus wie Ubuntu (/usr/lib, /usr/share …), dadurch laufen auch
# die mitgelieferten Hilfsprogramme (Claude Code, Cowork) unverändert.
#
# Version/Hash stehen in source.json – aktualisiert von
# scripts/update-claude-desktop.sh (läuft automatisch bei `rebuild update`).
{
  lib,
  stdenvNoCC,
  fetchurl,
  dpkg,
  buildFHSEnv,
  runCommand,
  OVMF,
}:

let
  source = lib.importJSON ./source.json;

  unpacked = stdenvNoCC.mkDerivation {
    pname = "claude-desktop-unpacked";
    inherit (source) version;

    src = fetchurl { inherit (source) url sha256; };

    nativeBuildInputs = [ dpkg ];

    unpackPhase = ''
      runHook preUnpack
      # ohne setuid-Bit von chrome-sandbox (im Nix-Store nicht erlaubt);
      # Electron nutzt dann die User-Namespace-Sandbox
      dpkg-deb --fsys-tarfile $src | tar -x --no-same-owner --no-same-permissions
      runHook postUnpack
    '';

    installPhase = ''
      runHook preInstall
      mkdir -p $out
      cp -r usr/lib usr/share $out/
      runHook postInstall
    '';

    # Unverändert lassen – läuft in der FHS-Umgebung
    dontFixup = true;
  };

  # UEFI-Firmware für Cowork unter den Debian-Pfaden (/usr/share/OVMF/…)
  ovmfDebianPaths = runCommand "ovmf-debian-paths" { } ''
    mkdir -p $out/share/OVMF
    for n in OVMF_CODE OVMF_VARS; do
      ln -s ${OVMF.fd}/FV/$n.fd $out/share/OVMF/$n.fd
      ln -s ${OVMF.fd}/FV/$n.fd $out/share/OVMF/''${n}_4M.fd
    done
  '';
in
buildFHSEnv {
  pname = "claude-desktop";
  inherit (source) version;

  targetPkgs =
    pkgs: with pkgs; [
      unpacked

      # Electron / Chromium
      glib
      gtk3
      pango
      cairo
      gdk-pixbuf
      atk
      at-spi2-atk
      at-spi2-core
      nspr
      nss
      cups
      dbus
      expat
      libdrm
      libgbm
      libglvnd
      vulkan-loader
      libxkbcommon
      systemd # libudev
      alsa-lib
      libpulseaudio
      fontconfig
      freetype
      libx11
      libxcomposite
      libxdamage
      libxext
      libxfixes
      libxrandr
      libxcb
      libxtst
      libxscrnsaver
      libxshmfence
      # Debian-Abhängigkeiten der App
      libnotify
      libsecret
      libuuid
      libappindicator-gtk3 # Tray-Symbol
      xdg-utils
      stdenv.cc.cc.lib # libstdc++ (node-pty)
      # Claude Code in der App
      git
      # Cowork (VM): QEMU, virtiofsd, UEFI-Firmware
      qemu_kvm
      virtiofsd
      ovmfDebianPaths
    ];

  runScript = "${unpacked}/lib/claude-desktop/claude-desktop";

  # Unter Wayland nativ statt über XWayland
  profile = ''
    export ELECTRON_OZONE_PLATFORM_HINT=auto
  '';

  extraInstallCommands = ''
    mkdir -p $out/share
    cp -r ${unpacked}/share/icons $out/share/
    install -Dm644 ${unpacked}/share/applications/com.anthropic.Claude.desktop \
      $out/share/applications/com.anthropic.Claude.desktop
  '';

  meta = {
    description = "Claude Desktop – offizielle Linux-Beta von Anthropic";
    homepage = "https://claude.ai/download";
    license = lib.licenses.unfree;
    platforms = [ "x86_64-linux" ];
    mainProgram = "claude-desktop";
  };
}
