# Hyprland als zweite Sitzung neben Niri – im Login (ly) mit ←/→ wählbar.
# Die Config liegt im Repo: linux/.config/hypr/hyprland.lua (Lua, ab Hyprland 0.55).
# Gemeinsames mit Niri (Waybar, mako, Polkit, KDE-Apps …): desktop.nix
{ pkgs, ... }:

let
  # Übersicht (Super+O), unterstützt Hyprland 0.56 mit Lua-Config.
  # Fester Pfad, damit hyprland.lua das Plugin ohne Store-Pfad laden kann.
  hyprtasking = pkgs.hyprlandPlugins.hyprtasking;

  # Alt+Tab (~/.config/hyprshell). Alpha statt 4.10.8 aus nixpkgs: erst ab
  # 4.11 gibt es Fenster-Vorschauen (HYPRSHELL_EXPERIMENTAL=1, hyprland.lua).
  # Zurück auf pkgs.hyprshell, sobald nixpkgs 4.11 hat.
  hyprshell = pkgs.hyprshell.overrideAttrs (
    final: old: {
      version = "4.11.0-alpha.1";
      src = pkgs.fetchFromGitHub {
        owner = "H3rmt";
        repo = "hyprshell";
        tag = "v${final.version}";
        hash = "sha256-LEtHGr9NzGBfd3kOuzdnCfcQV3hQRoU3lzDV7iCDhgA=";
      };
      cargoDeps = pkgs.rustPlatform.fetchCargoVendor {
        inherit (final) pname version src;
        hash = "sha256-2GTICUypGVWcwSOuydT8BcejDffpcobIbSiJgwOIrrg=";
      };
      # 4.11 braucht zusätzlich libdbus und libgbm (Fenster-Aufnahme)
      buildInputs = old.buildInputs ++ [
        pkgs.dbus
        pkgs.libgbm
      ];
      # Tests der Alpha nicht mitbauen (upstream baut auch ohne)
      doCheck = false;
    }
  );

  # Druck: Bereich wählen → Clipboard + ~/Screenshots (wie Niris Screenshot)
  screenshot = pkgs.writeShellApplication {
    name = "screenshot";
    runtimeInputs = with pkgs; [
      grim
      slurp
      wl-clipboard
      libnotify
    ];
    text = ''
      dir="$HOME/Screenshots"
      mkdir -p "$dir"
      file="$dir/Screenshot from $(date '+%Y-%m-%d %H-%M-%S').png"
      geom=$(slurp -d -b '#1e1e2e66' -c '#cba6f7' -w 2) || exit 0
      grim -g "$geom" "$file"
      wl-copy --type image/png <"$file"
      notify-send -a Screenshot -i "$file" "Screenshot kopiert" "''${file##*/}"
    '';
  };

  # Super+Shift+/: alle Tastenkürzel mit Beschreibung (wie Niris Hotkey-Overlay)
  hypr-keybinds = pkgs.writeShellApplication {
    name = "hypr-keybinds";
    runtimeInputs = with pkgs; [
      jq
      rofi
      util-linux # column
    ];
    text = ''
      hyprctl binds -j | jq -r '
        def bit($m; $b): (($m / $b) | floor) % 2 == 1;
        def mods($m): [
          (if bit($m; 64) then "Super" else empty end),
          (if bit($m; 4) then "Strg" else empty end),
          (if bit($m; 8) then "Alt" else empty end),
          (if bit($m; 1) then "Shift" else empty end)
        ];
        def key: {
          "slash": "/", "bracketleft": "[", "bracketright": "]",
          "comma": ",", "period": ".", "minus": "-", "equal": "=",
          "mouse_down": "Mausrad ↓", "mouse_up": "Mausrad ↑",
          "mouse:272": "linke Maustaste", "mouse:273": "rechte Maustaste"
        }[.] // .;
        .[] | select(.has_description)
        | "\(mods(.modmask) + [.key | key] | join(" + "))\t\(.description)"' |
        column -t -s "$(printf '\t')" |
        rofi -dmenu -i -no-custom -p "Tastenkürzel" >/dev/null || true
    '';
  };
in
{
  programs.hyprland = {
    enable = true;
    # UWSM startet graphical-session.target (mako, Polkit, hypridle, Autostart)
    # und beendet beim Abmelden alles sauber – wie niri-session unter Niri
    withUWSM = true;
  };

  environment.etc."hyprland/plugins/libhyprtasking.so".source =
    "${hyprtasking}/lib/libhyprtasking.so";

  # Wie unter Niri: KDE-Dateidialog, Passwörter über KWallet
  xdg.portal.config.hyprland = {
    default = [
      "hyprland"
      "gtk"
    ];
    "org.freedesktop.impl.portal.FileChooser" = "kde";
    "org.freedesktop.impl.portal.Secret" = "kwallet";
  };

  environment.systemPackages = [
    pkgs.hyprshutdown # Abmelden: schließt Apps erst sauber
    screenshot # Druck
    hypr-keybinds # Super+Shift+/
    # Alt+Tab mit Fenster-Vorschau (Niri hat das eingebaut), ~/.config/hyprshell
    hyprshell
  ];
}
