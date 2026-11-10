'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const { spawn } = require('node:child_process');
const path = require('node:path');
const fs = require('node:fs');

const script = path.join(__dirname, '..', 'dashboard', 'server.js');
const samples = fs.readFileSync(path.join(__dirname, '..', 'samples', 'sample-traffic.txt'), 'utf8');

async function getJsonWithRetry(url, attempts = 60) {
  let error;
  for (let i = 0; i < attempts; i++) {
    try {
      const response = await fetch(url);
      assert.equal(response.status, 200);
      return await response.json();
    } catch (err) {
      error = err;
      await new Promise(resolve => setTimeout(resolve, 75));
    }
  }
  throw error;
}

test('dashboard exposes only metadata for synthetic traffic', async () => {
  const port = 35000 + Math.floor(Math.random() * 20000);
  const child = spawn(process.execPath, [script], {
    env: { ...process.env, PORT: String(port) },
    stdio: ['pipe', 'ignore', 'pipe']
  });
  let errors = '';
  child.stderr.on('data', data => { errors += String(data); });
  try {
    child.stdin.write(samples);
    child.stdin.end();
    const base = `http://127.0.0.1:${port}`;
    const stats = await getJsonWithRetry(`${base}/api/snapshot`);
    assert.equal(stats.packetsObserved, 5);
    assert.equal(stats.sourceCount, 2);
    assert.equal(stats.destinationCount, 4);
    assert.equal(stats.activeSourceCount, 2);
    assert.equal(stats.recent.length, 5);
    assert.equal(stats.recent[0].service, 'HTTPS / QUIC');
    assert.ok(!('payload' in stats.recent[0]));
    const page = await fetch(base);
    assert.equal(page.status, 200);
    assert.match(await page.text(), /VPN Traffic Observatory/);
    const notFound = await fetch(`${base}/unknown`);
    assert.equal(notFound.status, 404);
    const eventRes = await fetch(`${base}/events`);
    assert.equal(eventRes.status, 200);
    assert.match(eventRes.headers.get('content-type'), /text\/event-stream/);
    await eventRes.body.cancel();
  } finally {
    child.kill();
  }
  assert.match(errors, /listening/);
});
