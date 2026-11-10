#!/usr/bin/env bash
set -euo pipefail

if [[ "${EUID}" -ne 0 ]]; then
  echo "Run with sudo: sudo bash scripts/add-client.sh phone PUBLIC_IP_OR_DDNS" >&2
  exit 1
fi
if [[ $# -ne 2 ]]; then
  echo "Usage: sudo bash scripts/add-client.sh CLIENT_NAME PUBLIC_IP_OR_DDNS" >&2
  exit 1
fi

NAME="$1"
ENDPOINT="$2"
if [[ ! "$NAME" =~ ^[a-zA-Z0-9_-]{1,32}$ ]]; then
  echo 'Client name may contain letters, digits, - and _ only.' >&2
  exit 1
fi
if [[ ! "$ENDPOINT" =~ ^[a-zA-Z0-9.-]+$ ]]; then
  echo 'Endpoint must be an IP address or DNS hostname, without scheme or port.' >&2
  exit 1
fi
if [[ ! -f /etc/wireguard/wg0.conf ]]; then
  echo 'Set up the server first.' >&2
  exit 1
fi

CLIENT_DIR=/etc/wireguard/clients
umask 077
mkdir -p "$CLIENT_DIR"
if [[ -e "$CLIENT_DIR/${NAME}.conf" ]]; then
  echo "Client '${NAME}' already exists. Pick a different name." >&2
  exit 1
fi

CLIENT_IP=''
for i in $(seq 2 254); do
  candidate="10.8.0.${i}"
  if ! grep -Fq "AllowedIPs = ${candidate}/32" /etc/wireguard/wg0.conf; then
    CLIENT_IP="$candidate"
    break
  fi
done
if [[ -z "$CLIENT_IP" ]]; then
  echo 'No free addresses in 10.8.0.0/24.' >&2
  exit 1
fi

wg genkey | tee "$CLIENT_DIR/${NAME}.key" | wg pubkey > "$CLIENT_DIR/${NAME}.pub"
CLIENT_PRIVATE_KEY=$(cat "$CLIENT_DIR/${NAME}.key")
CLIENT_PUBLIC_KEY=$(cat "$CLIENT_DIR/${NAME}.pub")
SERVER_PUBLIC_KEY=$(cat /etc/wireguard/server.pub)

cat > "$CLIENT_DIR/${NAME}.conf" <<CONFIG
[Interface]
PrivateKey = ${CLIENT_PRIVATE_KEY}
Address = ${CLIENT_IP}/32
DNS = 1.1.1.1

[Peer]
PublicKey = ${SERVER_PUBLIC_KEY}
Endpoint = ${ENDPOINT}:51820
AllowedIPs = 0.0.0.0/0, ::/0
PersistentKeepalive = 25
CONFIG
chmod 0600 "$CLIENT_DIR/${NAME}."{key,pub,conf}

cat >> /etc/wireguard/wg0.conf <<CONFIG

# Client: ${NAME}
[Peer]
PublicKey = ${CLIENT_PUBLIC_KEY}
AllowedIPs = ${CLIENT_IP}/32
CONFIG
chmod 0600 /etc/wireguard/wg0.conf
wg set wg0 peer "$CLIENT_PUBLIC_KEY" allowed-ips "${CLIENT_IP}/32"

echo "Client created: $NAME | VPN IP: $CLIENT_IP"
echo "Private client configuration: $CLIENT_DIR/${NAME}.conf"
echo "To view it securely: sudo cat $CLIENT_DIR/${NAME}.conf"
echo 'Import the config into your WireGuard client; never publish the private key.'
echo 'Client traffic is IPv4-routed; IPv6 is intentionally not provided in this lab.'
