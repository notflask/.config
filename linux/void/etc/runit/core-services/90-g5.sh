# Wird von runit beim Booten vor allen Diensten ausgeführt (wie
# network-pre.target unter NixOS): Firewall, Split-Tunneling-Ketten und
# VPN-Sperre stehen, bevor NetworkManager eine Verbindung aufbaut.
# Die Dienste vpn-bypass und vpn-lock halten den Zustand danach.
msg "g5: Firewall und VPN-Sperre..."
/usr/local/sbin/g5-firewall on || true
/usr/local/sbin/vpn-bypass on || true
[ -e /etc/wireguard/wg0.conf ] && { /usr/local/sbin/vpn-lock on || true; }
