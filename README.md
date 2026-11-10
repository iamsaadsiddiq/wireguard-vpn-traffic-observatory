# WireGuard VPN Traffic Observatory

[![Node.js](https://img.shields.io/badge/Node.js-18%2B-339933?logo=nodedotjs&logoColor=white)](https://nodejs.org)
[![WireGuard](https://img.shields.io/badge/VPN-WireGuard-88171A?logo=wireguard&logoColor=white)](https://www.wireguard.com/)
[![CI](https://github.com/iamsaadsiddiq/wireguard-vpn-traffic-observatory/actions/workflows/ci.yml/badge.svg)](https://github.com/iamsaadsiddiq/wireguard-vpn-traffic-observatory/actions)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

A **self-hosted WireGuard VPN gateway and real-time network metadata dashboard** built for the **30 Days, 30 Projects** challenge. Explore VPN tunneling, routing, NAT, IPv4 addressing, packet headers, DNS, Node.js, and server-sent events—all with a Windows CMD-friendly workflow.

> **Learning lab, not a production VPN service.** WireGuard supplies proven VPN encryption. The monitoring component shows IP addresses, transport protocols, destination ports, and recent flows from devices you own or participants who have explicitly consented. It does **not** decrypt HTTPS, read messages/passwords, or reveal full browsing URLs.

## Highlights

| Feature | Implementation |
| --- | --- |
| Encrypted VPN | WireGuard with per-device public/private keys |
| IPv4 internet gateway | Ubuntu IP forwarding, firewall forwarding rules, and NAT |
| Traffic observation | `tcpdump` textual headers on `wg0`; no payload logging |
| Live dashboard | Node.js HTTP server and browser Server-Sent Events |
| Local demo | One-command Windows CMD launcher and synthetic sample data |
| Secure dashboard access | Loopback-only listener with SSH port forwarding |
| Tests | Node.js built-in test runner; GitHub Actions on every push |
| Runtime dependencies | None beyond Node.js standard library |

## Architecture

```text
       Remote client (phone / Windows)
                  |
         encrypted WireGuard UDP
                  |  port 51820
                  v
     Public IP (home router or VPS)
                  |
        [home: UDP port forward]
                  v
     Ubuntu VPN gateway  10.8.0.1/24
         /                    \
        /                      \
   wg0 tunnel               tcpdump -tt -q
        |                 (IP/port metadata only)
        |                         |
 IPv4 forwarding + NAT            v
        |                   Node.js HTTP + SSE
        v                         |
     Internet             127.0.0.1:3000
                                  |
                            SSH -L port forward
                                  |
                         Local browser dashboard
```

### What can you observe?

**Yes:** virtual client IPv4 addresses, destination IPv4 addresses, transport protocols, port numbers, approximate recent activity, and packet counts. **Sometimes:** domains from separately captured unencrypted DNS. **No:** HTTPS contents, precise visited page URLs, encrypted chats, or passwords. A shared destination IP or port does not uniquely identify a website.

## Requirements

- Windows 10/11 with **Node.js 18+** and CMD for the simulated demo. Use built-in SSH/SCP for managing Linux.
- A dedicated **Ubuntu** PC/VM or VPS with sudo rights, internet access, and SSH for running the real VPN.
- At home: a **reachable public IPv4**, router support for forwarding **UDP 51820**, and preferably a LAN DHCP reservation for the Ubuntu host.
- One test phone or another device with the official WireGuard client.

**Important:** An ordinary home `192.168.x.x` address is not publicly routable. If your ISP uses carrier-grade NAT (CGNAT), normal port forwarding won't enable an inbound home VPN. A VPS has its **own** public exit IP; it does *not* automatically use your home Wi-Fi public IP.

## Quick start — Windows CMD demo

Clone the repository, install Node.js, then run:

```cmd
git clone https://github.com/iamsaadsiddiq/wireguard-vpn-traffic-observatory.git
cd wireguard-vpn-traffic-observatory
node -v
run-demo.cmd
```

Open **http://127.0.0.1:3000**. You'll see **five synthetic packets** in the dashboard. This demo does not establish a VPN and does not capture any real traffic. Stop with **Ctrl+C**.

On any supported platform, run the integration test:

```bash
npm test
```

## Real VPN setup — Ubuntu

**1. Copy the source to your dedicated Ubuntu host**, then log in with SSH. From Windows CMD, for example:

```cmd
scp -r wireguard-vpn-traffic-observatory student@192.168.1.50:~/
ssh student@192.168.1.50
```

Replace the example username and address with your server's information. For a VPS, use the server's public IP.

**2. Install and configure the WireGuard gateway on Ubuntu:**

```bash
cd ~/wireguard-vpn-traffic-observatory
sudo bash scripts/setup-server.sh
sudo wg show
```

This configures the WireGuard interface `wg0` at `10.8.0.1/24`, UDP **51820**, IPv4 forwarding, and an `iptables` masquerade rule on the detected outgoing interface. It changes firewall and network settings; **use a dedicated learning machine, not production infrastructure**.

For a home deployment, forward **UDP 51820** on the router to the Ubuntu host's LAN IP. For a VPS, allow the port in the cloud firewall.

**3. Generate a test client's config on Ubuntu:**

```bash
sudo bash scripts/add-client.sh phone YOUR_PUBLIC_IP_OR_DDNS
sudo cat /etc/wireguard/clients/phone.conf
```

Import the generated configuration privately into the [official WireGuard client](https://www.wireguard.com/install/). Protect the configuration: it contains the **client private key**. This teaching script generates keys on the server for convenience; production VPNs should generate each private key **on the client** and send the server only a public key.

Turn on the tunnel while your phone uses **mobile data**, not your home Wi-Fi. Check your public exit address and `sudo wg show` for a recent handshake. A home-hosted gateway should exit through the home ISP's public IP; a VPS gateway exits through the VPS IP.

**IPv6 limitation:** This lab routes IPv4 only. The provided client profile routes `::/0` into the tunnel without implementing IPv6 forwarding; IPv6 destinations may not work. Production deployments need an explicit IPv6 routing and firewall plan.

## Live traffic metadata

Start the metadata collector on Ubuntu:

```bash
cd ~/wireguard-vpn-traffic-observatory
bash scripts/start-dashboard.sh
```

The shell script runs `tcpdump` on the **inside** of the VPN interface and pipes textual TCP/UDP header information to an **unprivileged Node.js** server. The server listens only on `127.0.0.1:3000`, uses in-memory state, and avoids persisting packet captures.

From a **second Windows CMD window**, securely forward that port:

```cmd
ssh -L 3000:127.0.0.1:3000 student@192.168.1.50
```

Open **http://127.0.0.1:3000** on Windows to see recent flows and client VPN IPs. Do **not** open dashboard port 3000 to the public internet; there is no web login layer.

### Optional DNS demonstration

With consent, you can inspect ordinary unencrypted DNS on the tunnel:

```bash
sudo tcpdump -i wg0 -n -l -vv 'src net 10.8.0.0/24 and udp dst port 53'
```

Encrypted DNS, caching, CDNs, and multiplexed connections make domain attribution incomplete and uncertain. This monitoring dashboard intentionally does not log DNS names.

## Repository layout

```text
dashboard/server.js          Node HTTP/SSE API and packet metadata parser
dashboard/public/index.html  Responsive traffic dashboard
scripts/setup-server.sh      Ubuntu WireGuard gateway setup
scripts/add-client.sh        Add a single test WireGuard peer
scripts/start-dashboard.sh   Live packet-metadata pipeline
samples/sample-traffic.txt   Synthetic packets for the Windows demo
test/dashboard.test.js       Dependency-free integration tests
run-demo.cmd                 Launch the simulated demo in CMD
publish-to-github.cmd        Optional GitHub CLI publishing helper
.github/workflows/ci.yml     Automated checks
SECURITY.md                  Security and privacy policy
LICENSE                      MIT license
```

## Troubleshooting

| Problem | Check |
| --- | --- |
| No WireGuard handshake | Endpoint IP/DDNS, UDP 51820, router forwarding, cloud firewall, CGNAT, matching peer keys |
| Handshake but no internet | `sysctl net.ipv4.ip_forward`, routing, forwarding firewall, and NAT interface |
| IP works but domains fail | Client DNS resolver and network restrictions |
| No entries in dashboard | Client traffic on `wg0`; verify `sudo wg show` and `tcpdump` |
| Can't open local dashboard | Port 3000 conflict, Node process, and SSH `-L` forwarding |
| Same-home-Wi-Fi client fails | Test off-site via mobile data; hairpin NAT might not be available |

Useful diagnostics on Ubuntu:

```bash
sudo wg show
sudo systemctl status wg-quick@wg0
ip -4 route show default
sudo iptables -S FORWARD
sudo iptables -t nat -S POSTROUTING
```

## Security & privacy

- Monitor **only your own devices or explicitly consenting participants**.
- **Never commit** WireGuard private keys, real `.conf` profiles, `.pcap` files, or logs. The repository includes `.gitignore` safeguards.
- Keep the Node dashboard on `127.0.0.1`; SSH tunnel for access. No authentication, quotas, user administration, or production-grade access control are provided.
- Keep your server patched; revoke compromised peers. Traffic metadata can itself be sensitive.
- The gateway never breaks end-to-end HTTPS encryption. Read [SECURITY.md](SECURITY.md) before deployment.

## Next experiments

1. Compare routes and public IPs before/after connecting to WireGuard.
2. Compare **outer encrypted** WireGuard UDP packets with **inner decrypted packet headers** on `wg0`.
3. Add a safe peer nickname mapping and per-peer byte counters from `wg show`.
4. Add optional consent-based DNS logging with a short retention policy.
5. Implement properly routed IPv6, key revocation, and a hardened authenticated dashboard.

## References

- [WireGuard quick start](https://www.wireguard.com/quickstart/)
- [WireGuard install guide](https://www.wireguard.com/install/)
- [Ubuntu WireGuard default gateway](https://ubuntu.com/server/docs/wireguard-vpn-defaultgw/)
