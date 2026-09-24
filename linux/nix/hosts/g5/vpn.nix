# WireGuard-VPN (wg-quick) mit Kill-Switch.
#
# Die Config mit den Schlüsseln liegt nur lokal in /etc/wireguard/wg0.conf,
# nicht im Repo. Einrichten/bedienen mit dem Befehl `vpn`:
#
#   vpn import DATEI.conf   Config übernehmen (+ Kill-Switch eintragen), verbinden
#   vpn up | down           verbinden / trennen
#   vpn status              Verbindung und Kill-Switch anzeigen
#
# Kill-Switch: Solange der Tunnel steht, verwirft die Firewall jedes Paket,
# das nicht durch wg0 geht (auch wenn der Server nicht erreichbar ist).
# Nach `vpn down` ist das Internet wieder normal offen.
{ pkgs, ... }:

let
  iface = "wg0";
  conf = "/etc/wireguard/${iface}.conf";

  # Regeln wie von Mullvad empfohlen: alles, was nicht über das Interface
  # läuft und nicht die verschlüsselten WireGuard-Pakete selbst sind
  # (fwmark), wird abgelehnt – außer an eigene Adressen (localhost)
  killswitch = pkgs.writeShellApplication {
    name = "vpn-killswitch";
    runtimeInputs = with pkgs; [
      iptables
      wireguard-tools
    ];
    text = ''
      action=$1 dev=$2
      case $action in
        on) op=-I ;;
        off) op=-D ;;
        *) echo "vpn-killswitch on|off INTERFACE" >&2; exit 2 ;;
      esac
      mark=$(wg show "$dev" fwmark)
      for ipt in iptables ip6tables; do
        "$ipt" "$op" OUTPUT ! -o "$dev" -m mark ! --mark "$mark" \
          -m addrtype ! --dst-type LOCAL -j REJECT || [ "$action" = off ]
      done
    '';
  };

  vpn = pkgs.writeShellApplication {
    name = "vpn";
    runtimeInputs = with pkgs; [
      gawk
      iptables
      wireguard-tools
    ];
    text = ''
      service=wg-quick-${iface}
      case ''${1:-status} in
        import)
          src=''${2:?Pfad zur WireGuard-.conf angeben}
          tmp=$(mktemp)
          trap 'rm -f "$tmp"' EXIT
          # Eigene Up/Down-Hooks der Datei durch den Kill-Switch ersetzen
          awk '
            /^[[:space:]]*(PreUp|PostUp|PreDown|PostDown)[[:space:]]*=/ { next }
            { print }
            /^\[Interface\]/ {
              print "PostUp = ${killswitch}/bin/vpn-killswitch on %i"
              print "PreDown = ${killswitch}/bin/vpn-killswitch off %i"
            }
          ' "$src" > "$tmp"
          sudo install -D -m 600 -o root -g root "$tmp" ${conf}
          echo "Gespeichert in ${conf}"
          sudo systemctl restart "$service"
          ;;
        up) sudo systemctl start "$service" ;;
        down) sudo systemctl stop "$service" ;;
        status)
          if systemctl is-active --quiet "$service"; then
            echo "VPN: verbunden (Kill-Switch aktiv)"
            sudo wg show ${iface} | sed -n '/latest handshake\|transfer\|endpoint/p'
          else
            echo "VPN: getrennt"
          fi
          ;;
        *) echo "vpn import DATEI | up | down | status" >&2; exit 2 ;;
      esac
    '';
  };
in
{
  networking.wg-quick.interfaces.${iface} = {
    configFile = conf; # String, damit die Schlüssel nicht im /nix/store landen
    autostart = true; # beim Booten verbinden
  };

  # Sonst verwirft der Reverse-Path-Filter die Antworten aus dem Tunnel
  networking.firewall.checkReversePath = "loose";

  environment.systemPackages = [
    vpn
    killswitch
    pkgs.wireguard-tools
  ];
}
