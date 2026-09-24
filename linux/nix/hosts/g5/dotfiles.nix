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
    # Niri-Sitzung
    "niri"
    "waybar"
    "fuzzel"
    "matugen"
    "waypaper"
    "hypr" # hyprlock.conf (Sperrbildschirm)
  ];
in
{
  systemd.tmpfiles.rules = [
    "d ${home}/.config 0755 ${user} users -"
  ]
  ++ map (name: "L ${home}/.config/${name} - - - - ${repo}/linux/.config/${name}") linked;

  # ── Neovim (LazyVim) ───────────────────────────────────────
  programs.neovim = {
    enable = true;
    defaultEditor = true;
  };

  # Von Mason heruntergeladene Programme (clangd usw.) laufen sonst nicht
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
    # cmake-tools.nvim / vimtex
    cmake
    sioyek

    # Terminal
    ghostty
    tmux
    fzf # tmux-fzf
    wl-clipboard
  ];

  # Kurzbefehle für die Skripte im Repo
  environment.shellAliases = {
    rebuild = "${repo}/linux/nix/scripts/rebuild.sh";
    monitors = "${repo}/linux/nix/scripts/monitors.sh";
    gpu-info = "${repo}/linux/nix/scripts/gpu-info.sh";
  };
}
