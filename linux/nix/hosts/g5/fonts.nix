# Schriften: alles aus den Dotfiles + Windows-Schriften + (fast) alle
# Schriftsysteme der Welt (Chinesisch, Japanisch, Koreanisch, Arabisch,
# Persisch, Hebräisch, Kyrillisch, Indisch, Thai …) + Emoji.
{ pkgs, ... }:

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
    noto-fonts-color-emoji
    amiri # klassisches Arabisch
    vazirmatn # Persisch
    dejavu_fonts
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
    emoji = [ "Noto Color Emoji" ];
  };
}
