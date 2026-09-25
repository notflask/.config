# Apple Color Emoji (macOS 26) als Linux-taugliche TTF
#
# Gebaut von https://github.com/samuelngs/apple-emoji-ttf aus Apples
# Emoji-Grafiken. Nicht von Apple lizenziert – nur für den privaten Gebrauch.
# Neue Version: Release-Tag unten eintragen, hash auf "" setzen, rebuilden
# und den gemeldeten Hash übernehmen.
{ stdenvNoCC, fetchurl }:

stdenvNoCC.mkDerivation rec {
  pname = "apple-color-emoji";
  version = "macos-26-20260722-484daf4e";

  src = fetchurl {
    url = "https://github.com/samuelngs/apple-emoji-ttf/releases/download/${version}/AppleColorEmoji-Linux.ttf";
    hash = "sha256-43x69iZaxKCvbVe8ZehhCad22ZZug0MzRVf2PaSCUW8=";
  };

  dontUnpack = true;

  installPhase = ''
    install -Dm644 $src $out/share/fonts/truetype/AppleColorEmoji.ttf
  '';
}
