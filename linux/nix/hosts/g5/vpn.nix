# WireGuard-VPN (wg-quick) mit Kill-Switch.
#
# Die Config mit den Schlüsseln liegt nur lokal in /etc/wireguard/wg0.conf,
# nicht im Repo. Einrichten/bedienen mit dem Befehl `vpn`:
#
#   vpn import DATEI.conf [NAME]  Config übernehmen und verbinden; NAME
#                           (Standard: Dateiname) zeigt das Waybar-Popup an
#   vpn name NAME           Profilnamen nachträglich setzen
#   vpn up | down           verbinden / trennen
#   vpn status              Verbindung und Kill-Switch anzeigen
#   vpn unlock | lock       Internet ohne VPN freigeben / wieder sperren
#
# Sperre (vpn-lock.service): Ohne Tunnel gibt es kein Internet, auch nicht
# beim Booten oder nach `vpn down`. Erreichbar bleiben nur LAN/Router.
# `vpn unlock` hebt sie bis zum nächsten Neustart auf.
#
# Kill-Switch: Solange der Tunnel steht, verwirft die Firewall zusätzlich
# jedes Paket, das nicht durch wg0 geht (auch ins LAN).
{ pkgs, ... }:

let
  iface = "wg0";
  fwmark = "51820"; # setzt wg-quick für Table = auto
  conf = "/etc/wireguard/${iface}.conf";
  nameFile = "/etc/wireguard/${iface}.name"; # Profilname fürs Waybar-Popup

  # Regeln wie von Mullvad empfohlen: alles, was nicht über das Interface
  # läuft und nicht die verschlüsselten WireGuard-Pakete selbst sind
  # (fwmark), wird abgelehnt – außer an eigene Adressen (localhost)
  killswitch = pkgs.writeShellApplication {
    name = "vpn-killswitch";
    runtimeInputs = with pkgs; [
      iproute2
      iptables
    ];
    text = ''
      action=$1 dev=$2
      case $action in
        on) op=-I ;;
        off) op=-D ;;
        *) echo "vpn-killswitch on|off INTERFACE" >&2; exit 2 ;;
      esac
      mark=${fwmark}
      for ipt in iptables ip6tables; do
        "$ipt" "$op" OUTPUT ! -o "$dev" -m mark ! --mark "$mark" \
          -m addrtype ! --dst-type LOCAL -j REJECT || [ "$action" = off ]
      done
      # Hat der Tunnel keine IPv6-Adresse, verschluckt der Server IPv6 und jede
      # Verbindung hängt, bis das Programm auf IPv4 ausweicht. Sofort ablehnen,
      # dann nehmen Programme gleich IPv4.
      if [ "$action" = off ]; then
        ip6tables -D OUTPUT -o "$dev" -j REJECT 2>/dev/null || true
      elif [ -z "$(ip -6 -o addr show dev "$dev" scope global)" ]; then
        ip6tables -I OUTPUT -o "$dev" -j REJECT
      fi
    '';
  };

  # Dauerhafte Sperre: erlaubt nur Loopback, den Tunnel, die verschlüsselten
  # WireGuard-Pakete (fwmark) und das lokale Netz (DHCP, Router-DNS für den
  # Endpoint-Namen, Drucker usw.)
  lock = pkgs.writeShellApplication {
    name = "vpn-lock";
    runtimeInputs = [ pkgs.iptables ];
    text = ''
      chain=vpn-lock
      for ipt in iptables ip6tables; do
        while "$ipt" -D OUTPUT -j $chain 2>/dev/null; do :; done
        "$ipt" -F $chain 2>/dev/null || true
        "$ipt" -X $chain 2>/dev/null || true
      done
      [ "''${1:-}" = on ] || exit 0

      for ipt in iptables ip6tables; do
        "$ipt" -N $chain
        "$ipt" -A $chain -o lo -j RETURN
        "$ipt" -A $chain -o ${iface} -j RETURN
        "$ipt" -A $chain -m mark --mark ${fwmark} -j RETURN
      done
      for net in 10.0.0.0/8 172.16.0.0/12 192.168.0.0/16 169.254.0.0/16 224.0.0.0/4 255.255.255.255; do
        iptables -A $chain -d $net -j RETURN
      done
      for net in fe80::/10 fc00::/7 ff00::/8; do
        ip6tables -A $chain -d $net -j RETURN
      done
      for ipt in iptables ip6tables; do
        "$ipt" -A $chain -j REJECT
        "$ipt" -I OUTPUT -j $chain
      done
    '';
  };

  # Für das Waybar-Popup: Endpoint und letzter Handshake, ohne Schlüssel.
  # Per sudoers ohne Passwort erlaubt (unten).
  peerInfo = pkgs.writeShellApplication {
    name = "vpn-peer-info";
    runtimeInputs = [ pkgs.wireguard-tools ];
    text = ''
      wg show ${iface} endpoints | awk 'NR==1 {print "endpoint=" $2}'
      wg show ${iface} latest-handshakes | awk 'NR==1 {print "handshake=" $2}'
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
          name=''${3:-$(basename "$src" .conf)}
          tmp=$(mktemp)
          trap 'rm -f "$tmp"' EXIT
          # Eigene Up/Down-Hooks der Datei entfernen – den Kill-Switch schaltet
          # der systemd-Dienst (unten), damit immer die aktuelle Version läuft.
          # sudo cat, damit auch `vpn import ${conf}` (nur root lesbar) geht.
          sudo cat "$src" | awk '
            /^[[:space:]]*(PreUp|PostUp|PreDown|PostDown)[[:space:]]*=/ { next }
            { print }
          ' > "$tmp"
          sudo install -D -m 600 -o root -g root "$tmp" ${conf}
          echo "$name" | sudo install -m 644 /dev/stdin ${nameFile}
          echo "Gespeichert in ${conf} (Profil: $name)"
          sudo systemctl restart "$service"
          ;;
        name)
          echo "''${2:?Profilnamen angeben}" | sudo install -m 644 /dev/stdin ${nameFile}
          ;;
        up) sudo systemctl start "$service" ;;
        down) sudo systemctl stop "$service" ;;
        lock) sudo systemctl start vpn-lock ;;
        unlock) sudo systemctl stop vpn-lock ;;
        status)
          if systemctl is-active --quiet "$service"; then
            echo "VPN: verbunden (Kill-Switch aktiv)"
            sudo wg show ${iface} | sed -n '/latest handshake\|transfer\|endpoint/p'
          elif systemctl is-active --quiet vpn-lock; then
            echo "VPN: getrennt, Internet gesperrt (vpn unlock zum Freigeben)"
          else
            echo "VPN: getrennt, Internet OFFEN (vpn lock zum Sperren)"
          fi
          ;;
        *) echo "vpn import DATEI [NAME] | name NAME | up | down | lock | unlock | status" >&2; exit 2 ;;
      esac
    '';
  };
in
{
  networking.wg-quick.interfaces.${iface} = {
    configFile = conf; # String, damit die Schlüssel nicht im /nix/store landen
    autostart = true; # beim Booten verbinden
  };

  systemd.services."wg-quick-${iface}" = {
    # Ohne importierte Config den Dienst still überspringen statt fehlschlagen
    unitConfig.ConditionPathExists = conf;
    serviceConfig = {
      ExecStartPost = "${killswitch}/bin/vpn-killswitch on ${iface}";
      ExecStopPost = "${killswitch}/bin/vpn-killswitch off ${iface}";
    };
  };

  systemd.services.vpn-lock = {
    description = "VPN-Sperre: ohne Tunnel kein Internet";
    wantedBy = [ "multi-user.target" ];
    wants = [ "network-pre.target" ];
    before = [ "network-pre.target" ];
    unitConfig.ConditionPathExists = conf; # ohne VPN-Config nicht sperren
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${lock}/bin/vpn-lock on";
      ExecStop = "${lock}/bin/vpn-lock off";
    };
  };

  security.sudo.extraRules = [
    {
      groups = [ "wheel" ];
      commands = [
        {
          command = "/run/current-system/sw/bin/vpn-peer-info";
          options = [ "NOPASSWD" ];
        }
      ];
    }
  ];

  # Sonst verwirft der Reverse-Path-Filter die Antworten aus dem Tunnel
  networking.firewall.checkReversePath = "loose";

  environment.systemPackages = [
    vpn
    killswitch
    peerInfo
    pkgs.wireguard-tools
  ];
}
