# Niri-Sitzung (Standard im Login). Die Config liegt im Repo:
# linux/.config/niri/config.kdl. Gemeinsames mit Hyprland: desktop.nix
{ lib, pkgs, ... }:

let
  # Alle Spalten des aktuellen Workspaces gleich breit (2 → je 50 %,
  # 3 → je 33,3 % …) und übereinander gestapelte Fenster gleich hoch.
  niri-even-split = pkgs.writeShellApplication {
    name = "niri-even-split";
    runtimeInputs = with pkgs; [ jq ];
    text = ''
      ws=$(niri msg --json workspaces | jq '.[] | select(.is_focused) | .id')
      windows=$(niri msg --json windows | jq --argjson ws "$ws" \
        '[.[] | select(.workspace_id == $ws and (.is_floating | not))]')

      # Pro Spalte ein Fenster – die Breite gilt für die ganze Spalte
      mapfile -t columns < <(jq -r \
        'group_by(.layout.pos_in_scrolling_layout[0]) | .[][0].id' <<<"$windows")
      [ "''${#columns[@]}" -eq 0 ] && exit 0

      width=$(jq -n "100 / ''${#columns[@]}")
      for id in "''${columns[@]}"; do
        niri msg action set-window-width --id "$id" "$width%"
      done
      for id in $(jq -r '.[].id' <<<"$windows"); do
        niri msg action reset-window-height --id "$id"
      done

      # Ansicht zurechtrücken, dann den Fokus zurückgeben. Niri scrollt nur,
      # wenn der Fokus auf eine Spalte wechselt, die über den Rand ragt –
      # daher beide Enden: letzte Spalte (Lücke links), erste (Lücke rechts).
      focused=$(niri msg --json focused-window | jq '.id // empty')
      niri msg action focus-column-last
      niri msg action focus-column-first
      if [ -n "$focused" ]; then
        niri msg action focus-window --id "$focused"
      fi
    '';
  };
in
{
  programs.niri = {
    enable = true;
    useNautilus = false; # KDE-Dateidialog statt Nautilus
  };

  # KWallet statt GNOME-Keyring, KDE-Dateidialog (wie unter Hyprland)
  services.gnome.gnome-keyring.enable = lib.mkForce false;
  xdg.portal.config.niri = {
    "org.freedesktop.impl.portal.FileChooser" = lib.mkForce "kde";
    "org.freedesktop.impl.portal.Secret" = lib.mkForce "kwallet";
  };

  environment.systemPackages = [
    pkgs.xwayland-satellite # X11-Apps (Steam, Spiele) – startet Niri automatisch
    niri-even-split # Super+E
  ];
}
