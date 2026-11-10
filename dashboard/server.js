'use strict';

// Uses only Node's standard library. Reads tcpdump's TEXT lines via stdin.
// The dashboard intentionally does not capture payloads, credentials or page content.
const http = require('node:http');
const fs = require('node:fs');
const path = require('node:path');

const HOST = '127.0.0.1'; // Local-only; use SSH port forwarding for remote access.
const PORT = Number(process.env.PORT || 3000);
const indexFile = path.join(__dirname, 'public', 'index.html');
const clients = new Set();
const flows = new Map();
const recent = [];
const latestClients = new Map();
const latestDestinations = new Map();
let packetsObserved = 0;
let parseErrors = 0;
let lineBuffer = '';
let lastPacketAt = null;

function labelForPort(port) {
  const labels = { 53: 'DNS', 80: 'HTTP', 123: 'NTP', 443: 'HTTPS / QUIC', 853: 'Encrypted DNS', 22: 'SSH', 25: 'SMTP', 587: 'Mail submission' };
  return labels[port] || 'Other / unknown';
}

function parseTcpdumpLine(line) {
  // Example (tcpdump -tt -q -n):
  // 1762000000.1 IP 10.8.0.2.56000 > 1.1.1.1.443: tcp 0
  // 1762000000.2 IP 10.8.0.2.56001 > 1.1.1.1.53: UDP, length 29
  const match = line.match(/\bIP\s+(\d{1,3}(?:\.\d{1,3}){3})\.(\d+)\s+>\s+(\d{1,3}(?:\.\d{1,3}){3})\.(\d+):\s*(.*)$/);
  if (!match) return null;
  const [, sourceIp, sourcePort, destinationIp, destinationPortRaw, tail] = match;
  const destinationPort = Number(destinationPortRaw);
  const protocol = /\bUDP\b/i.test(tail) ? 'UDP' : /\btcp\b/i.test(tail) ? 'TCP' : 'TCP / UDP';
  return {
    at: new Date().toISOString(), sourceIp,
    sourcePort: Number(sourcePort), destinationIp, destinationPort,
    protocol, service: labelForPort(destinationPort)
  };
}

function onLine(line) {
  const parsed = parseTcpdumpLine(line);
  if (!parsed) {
    if (line.includes(' IP ')) parseErrors += 1;
    return;
  }
  const now = Date.now();
  packetsObserved += 1;
  lastPacketAt = parsed.at;
  latestClients.set(parsed.sourceIp, now);
  latestDestinations.set(parsed.destinationIp, now);
  const key = [parsed.sourceIp, parsed.sourcePort, parsed.destinationIp, parsed.destinationPort, parsed.protocol].join('|');
  const lastSeen = flows.get(key);
  flows.delete(key);
  flows.set(key, now);
  if (!lastSeen || now - lastSeen > 5 * 60_000) {
    recent.unshift(parsed);
    if (recent.length > 100) recent.pop();
  }
  // Bound in-memory maps for a day-long teaching lab, no disk logging.
  if (flows.size > 4000) {
    for (const k of Array.from(flows.keys()).slice(0, 1000)) flows.delete(k);
  }
}

process.stdin.setEncoding('utf8');
process.stdin.on('data', chunk => {
  lineBuffer += chunk;
  let newline = lineBuffer.indexOf('\n');
  while (newline !== -1) {
    onLine(lineBuffer.slice(0, newline));
    lineBuffer = lineBuffer.slice(newline + 1);
    newline = lineBuffer.indexOf('\n');
  }
  if (lineBuffer.length > 16_384) lineBuffer = '';
});

function snapshot() {
  const now = Date.now();
  const activeSources = [...latestClients.entries()]
    .filter(([, t]) => now - t < 60_000).map(([ip]) => ip).sort();
  return {
    time: new Date().toISOString(),
    packetsObserved,
    sourceCount: latestClients.size,
    activeSourceCount: activeSources.length,
    activeSources,
    destinationCount: latestDestinations.size,
    recent,
    lastPacketAt,
    parseErrors,
    disclosure: 'Shows observed IP/port metadata only. HTTPS content and full URLs are not visible.'
  };
}

const server = http.createServer((req, res) => {
  if (req.method !== 'GET') {
    res.writeHead(405).end('Method not allowed');
    return;
  }
  if (req.url === '/' || req.url === '/index.html') {
    res.writeHead(200, {
      'Content-Type': 'text/html; charset=utf-8',
      'Cache-Control': 'no-store',
      'X-Content-Type-Options': 'nosniff',
      'Content-Security-Policy': "default-src 'self'; style-src 'unsafe-inline' 'self'; script-src 'unsafe-inline' 'self'; connect-src 'self'",
      'Referrer-Policy': 'no-referrer'
    });
    fs.createReadStream(indexFile).pipe(res);
    return;
  }
  if (req.url === '/api/snapshot') {
    res.writeHead(200, { 'Content-Type': 'application/json; charset=utf-8', 'Cache-Control': 'no-store' });
    res.end(JSON.stringify(snapshot()));
    return;
  }
  if (req.url === '/events') {
    res.writeHead(200, {
      'Content-Type': 'text/event-stream; charset=utf-8',
      'Cache-Control': 'no-store',
      'Connection': 'keep-alive',
      'X-Accel-Buffering': 'no'
    });
    res.write(`data: ${JSON.stringify(snapshot())}\n\n`);
    clients.add(res);
    req.on('close', () => clients.delete(res));
    return;
  }
  res.writeHead(404).end('Not found');
});

setInterval(() => {
  const message = `data: ${JSON.stringify(snapshot())}\n\n`;
  for (const client of clients) client.write(message);
}, 1000).unref();

server.listen(PORT, HOST, () => {
  process.stderr.write(`VPN lab dashboard listening at http://${HOST}:${PORT}\n`);
  process.stderr.write('No data yet? Connect a consented client and browse a site.\n');
});
