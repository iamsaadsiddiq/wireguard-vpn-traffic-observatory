#!/usr/bin/env bash
set -euo pipefail

if [[ "${EUID}" -ne 0 ]]; then
  echo "Run with sudo: sudo bash scripts/setup-server.sh" >&2
  exit 1
fi

if [[ -e /etc/wireguard/wg0.conf ]]; then
  echo "Existing /etc/wireguard/wg0.conf detected; refusing to overwrite it." >&2
  exit 1
fi

apt-get update
DEBIAN_FRONTEND=noninteractive apt-get install -y wireguard iptables tcpdump nodejs npm

WAN_IF=$(ip -4 route show default | awk '/default/ {print $5; exit}')
if [[ -z "$WAN_IF" ]]; then
  echo "Cannot detect internet-facing network interface. Check 'ip route'." >&2
  exit 1
fi

install -d -m 0700 /etc/wireguard /etc/wireguard/clients
umask 077
wg genkey | tee /etc/wireguard/server.key | wg pubkey > /etc/wireguard/server.pub
SERVER_PRIVATE_KEY=$(cat /etc/wireguard/server.key)

cat > /etc/wireguard/wg0.conf <<CONFIG
[Interface]
Address = 10.8.0.1/24
ListenPort = 51820
PrivateKey = ${SERVER_PRIVATE_KEY}
PostUp = iptables -I FORWARD 1 -i %i -o ${WAN_IF} -j ACCEPT; iptables -I FORWARD 1 -i ${WAN_IF} -o %i -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT; iptables -t nat -A POSTROUTING -s 10.8.0.0/24 -o ${WAN_IF} -j MASQUERADE
PostDown = iptables -D FORWARD -i %i -o ${WAN_IF} -j ACCEPT; iptables -D FORWARD -i ${WAN_IF} -o %i -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT; iptables -t nat -D POSTROUTING -s 10.8.0.0/24 -o ${WAN_IF} -j MASQUERADE
CONFIG
chmod 0600 /etc/wireguard/wg0.conf /etc/wireguard/server.key

printf 'net.ipv4.ip_forward = 1\n' > /etc/sysctl.d/70-vpn-lab-routing.conf
sysctl -p /etc/sysctl.d/70-vpn-lab-routing.conf

if command -v ufw >/dev/null 2>&1; then
  ufw allow 51820/udp || true
fi

systemctl enable --now wg-quick@wg0

echo
printf 'VPN is configured. External interface: %s\n' "$WAN_IF"
echo 'VPN network: 10.8.0.0/24 | Server tunnel address: 10.8.0.1'
echo 'Listen UDP: 51820'
echo 'Public server key (safe to share with clients):'
cat /etc/wireguard/server.pub
echo
echo 'NEXT: sudo bash scripts/add-client.sh phone YOUR_PUBLIC_IP_OR_DDNS'
echo 'At home: forward router UDP 51820 to this Ubuntu device LAN address.'
echo 'On VPS: also allow UDP 51820 in your cloud firewall.'
