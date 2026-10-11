# WireGuard-VPN (wg-quick) mit Kill-Switch.
#
# Die Config mit den Schlüsseln liegt nur lokal in /etc/wireguard/wg0.conf,
# nicht im Repo. Einrichten/bedienen mit dem Befehl `vpn`:
#
#   vpn import DATEI.conf [NAME]  Config übernehmen und verbinden; NAME
#                           (Standard: Dateiname) ist der Profilname
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
#
# Split-Tunneling – am VPN vorbei (auch an Kill-Switch und Sperre vorbei):
#   novpn BEFEHL [ARG...]   ein Programm samt Kindprozessen, z. B. in Steam
#                           als Startoption: novpn gaming-mode %command%
#   vpn-split domain-add ZIEL   Ziele für alle Programme (z. B. Seiten im
#                           Browser), stehen in /var/lib/vpn-bypass/domains
#   vpn-split add APP_ID    App immer am VPN vorbei starten (Startmenü, Rofi …)
# Bequemer: VPN-Fenster in der Taskleiste (quickshell/taskbar/VpnPanel.qml).
# Programme unter novpn bekommen nur IPv4, solange der Tunnel kein IPv6 hat.
{ pkgs, ... }:

let
  iface = "wg0";
  fwmark = "51820"; # setzt wg-quick für Table = auto
  conf = "/etc/wireguard/${iface}.conf";
  nameFile = "/etc/wireguard/${iface}.name"; # Profilname

  # Ziele am VPN vorbei, eins pro Zeile: Domains (alle 10 min neu aufgelöst,
  # nur IPv4) oder IPv4-Adressen/-Netze. Bei CDNs wechseln die Adressen
  # öfter – dann trifft es nicht jede Verbindung. Bearbeiten über
  # `vpn-split domain-add|domain-remove` bzw. das VPN-Fenster.
  bypassFile = "/var/lib/vpn-bypass/domains";

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
      # Hat der Tunnel kein IPv6, versuchen Programme trotzdem IPv6 (der Router
      # verteilt ja Adressen). Das REJECT oben hilft kaum: Der Kernel drosselt
      # die ICMPv6-Antworten, jeder Versuch hängt ~1 s, bis auf IPv4
      # ausgewichen wird (z. B. Bilder von Pinterest). Deshalb IPv6 außer LAN
      # auf eine unreachable-Route legen – connect() scheitert sofort.
      if [ "$action" = off ]; then
        ip -6 rule del not fwmark "$mark" table "$mark" 2>/dev/null || true
        ip -6 rule del table main suppress_prefixlength 0 2>/dev/null || true
        ip -6 route flush table "$mark" 2>/dev/null || true
      elif [ -z "$(ip -6 -o addr show dev "$dev" scope global)" ]; then
        ip -6 route replace unreachable default table "$mark"
        if [ -z "$(ip -6 rule show table "$mark")" ]; then
          ip -6 rule add not fwmark "$mark" table "$mark"
          ip -6 rule add table main suppress_prefixlength 0
        fi
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

  # Für die Taskleiste (vpn.sh): Endpoint und letzter Handshake, ohne Schlüssel.
  # `wg show` braucht root – deshalb schreibt ein Dienst (unten) die Werte
  # alle 5 s in eine lesbare Datei, statt dass die Taskleiste alle 5 s sudo aufruft.
  peerInfoFile = "/run/${iface}-peer-info";
  peerInfo = pkgs.writeShellApplication {
    name = "vpn-peer-info";
    runtimeInputs = with pkgs; [
      wireguard-tools
      gawk
      coreutils
    ];
    text = ''
      while true; do
        {
          wg show ${iface} endpoints | awk 'NR==1 {print "endpoint=" $2}'
          wg show ${iface} latest-handshakes | awk 'NR==1 {print "handshake=" $2}'
        } >${peerInfoFile}.tmp && mv ${peerInfoFile}.tmp ${peerInfoFile}
        sleep 5
      done
    '';
  };

  # Split-Tunneling: Pakete am VPN vorbei bekommen die Markierung der
  # verschlüsselten WireGuard-Pakete (fwmark). Dann nimmt die Routing-Regel
  # von wg-quick die normale Route, Kill-Switch und Sperre lassen sie durch.
  # Die Absenderadresse wurde aber schon für wg0 gewählt – MASQUERADE setzt
  # die richtige. Die Verbindung merkt sich die Umleitung (connmark), damit sie
  # nicht reißt, wenn sich die Adressliste ändert.
  #   novpn       Kette in mangle/OUTPUT: entscheidet pro Paket
  #   novpn-app   Programme in novpn.slice (vpn-bypass-app, beim Start von novpn)
  #   novpn-dst   Ziele aus bypassFile (vpn-bypass-dst, Timer)
  #   novpn-mark  markiert Paket und Verbindung
  connmark = "0x10000/0x10000";
  bypass = pkgs.writeShellApplication {
    name = "vpn-bypass";
    runtimeInputs = [ pkgs.iptables ];
    text = ''
      for ipt in iptables ip6tables; do
        while "$ipt" -t mangle -D OUTPUT -j novpn 2>/dev/null; do :; done
        while "$ipt" -t nat -D POSTROUTING ! -o ${iface} -m connmark --mark ${connmark} -j MASQUERADE 2>/dev/null; do :; done
        for chain in novpn novpn-app novpn-dst novpn-mark; do
          "$ipt" -t mangle -F $chain 2>/dev/null || true
        done
        for chain in novpn novpn-app novpn-dst novpn-mark; do
          "$ipt" -t mangle -X $chain 2>/dev/null || true
        done
      done
      [ "''${1:-}" = on ] || exit 0

      for ipt in iptables ip6tables; do
        for chain in novpn novpn-app novpn-dst novpn-mark; do
          "$ipt" -t mangle -N $chain
        done
        "$ipt" -t mangle -A novpn-mark -j MARK --set-mark ${fwmark}
        "$ipt" -t mangle -A novpn-mark -j CONNMARK --set-xmark ${connmark}

        "$ipt" -t mangle -A novpn -o lo -j RETURN
        "$ipt" -t mangle -A novpn -m mark --mark ${fwmark} -j RETURN
        "$ipt" -t mangle -A novpn -m connmark --mark ${connmark} -j MARK --set-mark ${fwmark}
        "$ipt" -t mangle -A novpn -m mark --mark ${fwmark} -j RETURN
        "$ipt" -t mangle -A novpn -j novpn-app
        "$ipt" -t mangle -A novpn -j novpn-dst
        "$ipt" -t mangle -A OUTPUT -j novpn

        "$ipt" -t nat -A POSTROUTING ! -o ${iface} -m connmark --mark ${connmark} -j MASQUERADE
      done
    '';
  };

  # Regel für novpn.slice des aufrufenden Benutzers (per sudo ohne Passwort,
  # siehe unten). iptables löst den Pfad beim Anlegen auf, die Slice muss also
  # schon da sein – novpn-anchor hält sie die ganze Sitzung über offen.
  bypassApp = pkgs.writeShellApplication {
    name = "vpn-bypass-app";
    runtimeInputs = [ pkgs.iptables ];
    text = ''
      uid=''${SUDO_UID:?nur über sudo aufrufen}
      path=user.slice/user-$uid.slice/user@$uid.service/novpn.slice
      if [ ! -d "/sys/fs/cgroup/$path" ]; then
        echo "vpn-bypass-app: $path fehlt (läuft novpn-anchor?)" >&2
        exit 1
      fi
      for ipt in iptables ip6tables; do
        "$ipt" -t mangle -F novpn-app
        "$ipt" -t mangle -A novpn-app -m cgroup --path "$path" -j novpn-mark
      done
    '';
  };

  bypassDst = pkgs.writeShellApplication {
    name = "vpn-bypass-dst";
    runtimeInputs = with pkgs; [
      iptables
      getent
      gawk
      coreutils
    ];
    text = ''
      # erst alles auflösen, dann die Kette in einem Rutsch ersetzen
      hosts=()
      if [ -f ${bypassFile} ]; then
        mapfile -t hosts < <(grep -v '^[[:space:]]*\(#\|$\)' ${bypassFile})
      fi
      addrs=()
      for host in "''${hosts[@]}"; do
        if [[ $host =~ ^[0-9./]+$ ]]; then
          addrs+=("$host")
        else
          while read -r addr; do
            addrs+=("$addr")
          done < <(getent ahostsv4 "$host" | awk '{ print $1 }' | sort -u)
        fi
      done
      iptables -t mangle -F novpn-dst
      for addr in "''${addrs[@]}"; do
        iptables -t mangle -A novpn-dst -d "$addr" -j novpn-mark
      done
    '';
  };

  novpn = pkgs.writeShellApplication {
    name = "novpn";
    runtimeInputs = [ pkgs.systemd ];
    text = ''
      if [ $# -eq 0 ]; then
        echo "novpn BEFEHL [ARG...]   startet BEFEHL am VPN vorbei" >&2
        exit 2
      fi
      systemctl --user start novpn-anchor.service
      # Klappt das nicht, läuft das Programm eben durchs VPN
      /run/wrappers/bin/sudo -n ${bypassApp}/bin/vpn-bypass-app ||
        echo "novpn: Regel nicht gesetzt, $1 läuft durchs VPN" >&2
      exec systemd-run --user --scope --quiet --collect --slice=novpn -- "$@"
    '';
  };

  # Ziel zur Liste hinzufügen/entfernen und gleich anwenden. Per sudo ohne
  # Passwort (unten), deshalb nur Domainnamen und IPv4-Adressen/-Netze.
  bypassEdit = pkgs.writeShellApplication {
    name = "vpn-bypass-edit";
    runtimeInputs = with pkgs; [
      coreutils
      gnugrep
    ];
    text = ''
      action=''${1:-} target=''${2:-}
      target=''${target,,}
      if ! [[ $target =~ ^[a-z0-9]([a-z0-9.-]{0,251}[a-z0-9])?$ || $target =~ ^[0-9]{1,3}(\.[0-9]{1,3}){3}(/[0-9]{1,2})?$ ]]; then
        echo "vpn-bypass-edit: ungültiges Ziel: $target" >&2
        exit 2
      fi
      install -d -m 755 ${builtins.dirOf bypassFile}
      touch ${bypassFile}
      chmod 644 ${bypassFile}
      case $action in
        add) grep -qxF -- "$target" ${bypassFile} || echo "$target" >>${bypassFile} ;;
        remove)
          grep -vxF -- "$target" ${bypassFile} >${bypassFile}.tmp || true
          mv ${bypassFile}.tmp ${bypassFile}
          ;;
        *) echo "vpn-bypass-edit add|remove ZIEL" >&2; exit 2 ;;
      esac
      ${bypassDst}/bin/vpn-bypass-dst
    '';
  };

  # Split-Tunneling für den Benutzer (Apps und Ziele), scripts/vpn-split.sh
  vpnSplit = pkgs.writeShellApplication {
    name = "vpn-split";
    runtimeInputs = with pkgs; [
      coreutils
      gnugrep
      gnused
    ];
    text = ''
      bypass_file=${bypassFile}
      bypass_edit=${bypassEdit}/bin/vpn-bypass-edit
    '' + builtins.readFile ../../scripts/vpn-split.sh;
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

  # Läuft nur, solange der Tunnel steht
  systemd.services.vpn-peer-info = {
    description = "WireGuard-Status für die Taskleiste";
    wantedBy = [ "wg-quick-${iface}.service" ];
    bindsTo = [ "wg-quick-${iface}.service" ];
    after = [ "wg-quick-${iface}.service" ];
    serviceConfig = {
      ExecStart = "${peerInfo}/bin/vpn-peer-info";
      ExecStopPost = "${pkgs.coreutils}/bin/rm -f ${peerInfoFile}";
      Restart = "on-failure";
    };
  };

  # ── Split-Tunneling ──────────────────────────────────────────
  systemd.services.vpn-bypass = {
    description = "VPN-Split-Tunneling: Ketten anlegen";
    wantedBy = [ "multi-user.target" ];
    wants = [ "network-pre.target" ];
    before = [ "network-pre.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${bypass}/bin/vpn-bypass on";
      ExecStop = "${bypass}/bin/vpn-bypass off";
    };
  };

  systemd.services.vpn-bypass-dst = {
    description = "VPN-Split-Tunneling: Ziele auflösen";
    wantedBy = [ "vpn-bypass.service" ];
    requires = [ "vpn-bypass.service" ];
    after = [
      "vpn-bypass.service"
      "network-online.target"
    ];
    wants = [ "network-online.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${bypassDst}/bin/vpn-bypass-dst";
    };
  };

  systemd.timers.vpn-bypass-dst = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnActiveSec = "10min";
      OnUnitActiveSec = "10min";
    };
  };

  # Hält novpn.slice offen, damit die Regel von vpn-bypass-app gültig bleibt
  systemd.user.services.novpn-anchor = {
    description = "Platzhalter für novpn.slice";
    wantedBy = [ "default.target" ];
    serviceConfig = {
      Slice = "novpn.slice";
      ExecStart = "${pkgs.coreutils}/bin/sleep infinity";
    };
  };

  security.sudo.extraRules = [
    {
      groups = [ "wheel" ];
      commands = [
        {
          command = "${bypassApp}/bin/vpn-bypass-app";
          options = [ "NOPASSWD" ];
        }
        {
          command = "${bypassEdit}/bin/vpn-bypass-edit";
          options = [ "NOPASSWD" ];
        }
      ];
    }
  ];

  # Sonst verwirft der Reverse-Path-Filter die Antworten aus dem Tunnel
  networking.firewall.checkReversePath = "loose";

  # VPN an/aus und Sperre ohne Passwort (Taskleiste, wie Mullvad), nur für
  # die angemeldete Sitzung von wheel-Benutzern
  security.polkit.extraConfig = ''
    polkit.addRule(function (action, subject) {
      if (action.id == "org.freedesktop.systemd1.manage-units" &&
          subject.isInGroup("wheel") && subject.local && subject.active) {
        var unit = action.lookup("unit"), verb = action.lookup("verb");
        if ((unit == "wg-quick-${iface}.service" || unit == "vpn-lock.service") &&
            (verb == "start" || verb == "stop" || verb == "restart"))
          return polkit.Result.YES;
      }
    });
  '';

  environment.systemPackages = [
    vpn
    novpn
    vpnSplit
    killswitch
    pkgs.wireguard-tools
  ];
}
