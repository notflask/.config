# Schriften: alles aus den Dotfiles + Windows-Schriften + (fast) alle
# Schriftsysteme der Welt (Chinesisch, Japanisch, Koreanisch, Arabisch,
# Persisch, Hebräisch, Kyrillisch, Indisch, Thai …) + Apple-Emoji.
{ pkgs, lib, ... }:

let
  # Emoji-Schriften, die Apps ausdrücklich anfordern – alle auf Apple umbiegen
  otherEmojiFonts = [
    "Noto Color Emoji"
    "Noto Emoji"
    "Twemoji"
    "Twemoji Mozilla"
    "Segoe UI Emoji"
    "EmojiOne Color"
    "JoyPixels"
    "Blobmoji"
  ];
in
{
  fonts.enableDefaultPackages = true;

  fonts.packages = with pkgs; [
    # ── Aus deinen Dotfiles ──────────────────────────────────
    inter # waybar, wofi
    jetbrains-mono # ghostty ("JetBrains Mono")
    nerd-fonts.jetbrains-mono # mit Icons ("JetBrainsMono Nerd Font")
    nerd-fonts.symbols-only # Icons als Fallback für jede Schrift (LazyVim usw.)
    ibm-plex # vscode, obsidian-style.css
    fira-code # zebar
    minecraftia # Spotify (Spicetify)
    monocraft # Fallback für Minecraftia (mehr Zeichen)

    # ── Windows ──────────────────────────────────────────────
    corefonts # Arial, Times New Roman, Courier New, Verdana, Georgia, Tahoma, Impact …
    vista-fonts # Calibri, Cambria, Consolas, Candara, Constantia, Corbel
    liberation_ttf # maßgleicher Ersatz für Arial/Times/Courier
    carlito # maßgleich zu Calibri
    caladea # maßgleich zu Cambria
    gelasio # maßgleich zu Georgia

    # ── Alle Schriftsysteme ──────────────────────────────────
    noto-fonts # Latein, Kyrillisch, Griechisch, Arabisch, Hebräisch, Indisch, Thai …
    noto-fonts-cjk-sans # Chinesisch, Japanisch, Koreanisch
    noto-fonts-cjk-serif
    noto-fonts-color-emoji # nur noch Reserve, siehe Apple-Emoji unten
    amiri # klassisches Arabisch
    vazirmatn # Persisch
    dejavu_fonts

    # ── Emoji ────────────────────────────────────────────────
    (callPackage ../../pkgs/apple-emoji/package.nix { }) # "Apple Color Emoji"
  ];

  # Standard-Schriften (Fallback-Reihenfolge)
  fonts.fontconfig.defaultFonts = {
    sansSerif = [
      "Noto Sans"
      "Noto Sans CJK SC"
      "Noto Sans Arabic"
    ];
    serif = [
      "Noto Serif"
      "Noto Serif CJK SC"
      "Noto Naskh Arabic"
    ];
    monospace = [
      "JetBrains Mono"
      "Noto Sans Mono CJK SC"
      "Symbols Nerd Font Mono"
    ];
    emoji = [
      "Apple Color Emoji"
      "Noto Color Emoji"
    ];
  };

  # Apple-Emoji überall: Apps, die ausdrücklich eine andere Emoji-Schrift
  # verlangen (Noto, Twemoji, Segoe …), bekommen stattdessen Apple Color Emoji.
  # Firefox fragt fontconfig dafür nicht, siehe font.name-list.emoji in apps.nix.
  #
  # Minecraftia kennt kein Kyrillisch. Für Apps, die nur einen einzelnen
  # Font-Namen entgegennehmen (z. B. Telegram Desktop → Settings → Chat
  # Settings → "Font family" = Minecraftia), sonst würde für Russisch die
  # normale fontconfig-Standardschrift statt Monocraft (hat Kyrillisch)
  # einspringen. Spicetify (Spotify) bekommt die Fallback-Kette bereits
  # direkt per CSS in apps.nix und ist davon unabhängig.
  fonts.fontconfig.localConf = ''
    <?xml version="1.0"?>
    <!DOCTYPE fontconfig SYSTEM "fonts.dtd">
    <fontconfig>
    ${lib.concatMapStrings (font: ''
      <alias binding="strong">
        <family>${font}</family>
        <prefer><family>Apple Color Emoji</family></prefer>
      </alias>
    '') otherEmojiFonts}
      <match target="pattern">
        <test name="family"><string>Minecraftia</string></test>
        <edit name="family" mode="append" binding="strong"><string>Monocraft</string></edit>
      </match>
    </fontconfig>
  '';
}
