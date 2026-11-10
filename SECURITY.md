# Security Policy

## Reporting issues

Please do **not** include VPN private keys, client configuration files, internal/public home IP addresses, real packet captures, passwords, or sensitive logs in a public issue. If a vulnerability could expose users or secrets, contact the repository maintainer privately using GitHub's **Report a vulnerability** feature (if enabled), rather than creating a public issue.

## Design and supported usage

This repository is an **educational lab**, not a hardened managed-VPN product. It uses WireGuard for encryption and a localhost-only Node.js dashboard for **metadata-only** monitoring. The dashboard has no authentication by itself. Never forward TCP/3000 from your router or expose the dashboard over public interfaces.

- Keep Linux and WireGuard updated.
- Limit SSH access and use trusted SSH keys.
- Treat every peer private key and WireGuard `.conf` file as a secret.
- Do not commit real traffic, login secrets, WireGuard state or packet captures.
- Deploy on a dedicated test device or VM; setup scripts modify routing and firewall rules.
- Capture metadata only for devices you own or where participants explicitly consent.
- Real deployments need key rotation/revocation, retention controls, access control, IPv6 support, and a policy review.

For networking and setup questions, open a regular issue with sanitized, non-sensitive reproduction steps.
