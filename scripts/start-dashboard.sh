#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$ROOT"

if ! ip link show wg0 >/dev/null 2>&1; then
  echo 'wg0 is not running. Try: sudo systemctl start wg-quick@wg0' >&2
  exit 1
fi
if ! command -v node >/dev/null 2>&1; then
  echo 'Node.js is missing. Install it before starting.' >&2
  exit 1
fi

echo 'Starting live traffic metadata monitor for VPN clients.'
echo 'Dashboard URL (on VPN server): http://127.0.0.1:3000'
echo 'If using Windows CMD remotely, forward port 3000 over SSH (see README).'
echo 'This records source/destination IPs and ports; not web page contents.'
echo
sudo tcpdump -tt -q -l -n -i wg0 'ip and src net 10.8.0.0/24 and (tcp or udp)' | node dashboard/server.js
