# Dotfiles aus dem Repo (~/dotfiles) + Werkzeuge, die sie brauchen.
#
# Die Configs werden beim Booten nach ~/.config verlinkt – du bearbeitest
# sie direkt im Repo, Änderungen wirken sofort. Existiert dort schon ein
# echter Ordner, bleibt er unangetastet (erst löschen, dann neu starten).
{ pkgs, ... }:

let
  user = "flask";
  home = "/home/${user}";
  repo = "${home}/dotfiles";

  # Genutzte Configs aus linux/.config/
  linked = [
    "nvim"
    "tmux"
    "ghostty"
    # Niri- und Hyprland-Sitzung
    "fastfetch"
    "niri"
    "waybar"
    "rofi"
    "mako"
    "wlogout"
    "matugen"
    "waypaper"
    "hypr" # Hyprland, hyprlock, hypridle
    "hyprshell" # Alt+Tab unter Hyprland
    "MangoHud" # FPS-Overlay (gaming-mode), Farben von matugen
    "sioyek" # PDF-Betrachter für Typst-Notizen
  ];
in
{
  systemd.tmpfiles.rules = [
    "d ${home}/.config 0755 ${user} users -"
  ]
  ++ map (name: "L ${home}/.config/${name} - - - - ${repo}/linux/.config/${name}") linked
  ++ [
    # Warp: Themes verlinkt; settings.toml nur als Startwert kopiert, weil
    # Warp die Datei selbst umschreibt (ein Symlink meldet Änderungen nicht)
    "d ${home}/.local/share 0755 ${user} users -"
    "d ${home}/.local/share/warp-terminal 0755 ${user} users -"
    "L ${home}/.local/share/warp-terminal/themes - - - - ${repo}/linux/.local/share/warp-terminal/themes"
    "d ${home}/.config/warp-terminal 0755 ${user} users -"
    "C ${home}/.config/warp-terminal/settings.toml - ${user} users - ${repo}/linux/.config/warp-terminal/settings.toml"
  ];

  # ── Neovim (LazyVim) ───────────────────────────────────────
  programs.neovim = {
    enable = true;
    defaultEditor = true;
  };

  # Von Mason heruntergeladene Programme (clangd usw.) und von uv
  # installierte Python-Versionen laufen sonst nicht
  programs.nix-ld.enable = true;

  environment.systemPackages = with pkgs; [
    # LazyVim
    gcc
    gnumake
    tree-sitter
    ripgrep
    fd
    unzip
    nodejs
    lazygit
    gh # GitHub-CLI (PRs), einmalig: gh auth login
    # cmake-tools.nvim / vimtex
    cmake
    sioyek

    # Typst (Mathe-Notizen): Compiler, Sprachserver für Neovim, Formatter.
    # Nix statt Mason, weil Mason-Binaries unter NixOS nicht zuverlässig laufen
    typst
    tinymist
    typstyle

    # Python-Versionen verwalten: `uv python install` (läuft dank nix-ld)
    uv

    # Terminal
    ghostty
    tmux
    fzf # tmux-fzf
    wl-clipboard
  ];

  # ~/.local/bin in den PATH (dort legt `uv python install` python/python3 ab)
  environment.localBinInPath = true;

  # Kurzbefehle für die Skripte im Repo
  environment.shellAliases = {
    rebuild = "${repo}/linux/nix/scripts/rebuild.sh";
    gpu-info = "${repo}/linux/nix/scripts/gpu-info.sh";
    theme = "${repo}/linux/.config/matugen/theme.sh";
  };
}
