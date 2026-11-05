import test from 'node:test';
import assert from 'node:assert/strict';
import { once } from 'node:events';
import WebSocket from 'ws';
import { startServer } from '../src/server.mjs';
import { GameEngine } from '../src/game.mjs';

async function connect(url, options) {
  const ws = new WebSocket(url, options);
  const queue = [], waiters = [];
  ws.on('message', raw => {
    const value = JSON.parse(raw);
    if (waiters.length) waiters.shift()(value);
    else queue.push(value);
  });
  await once(ws, 'open');
  return { ws, send: value => ws.send(JSON.stringify(value)), next: () => queue.length ?
    Promise.resolve(queue.shift()) : new Promise(resolve => waiters.push(resolve)) };
}

test('real WebSocket clients create, join, receive identical public state, and reconnect', async () => {
  const server = startServer({ port: 0, dataDir: null, engine: new GameEngine() });
  await once(server.http, 'listening');
  const port = server.http.address().port;
  const url = `ws://127.0.0.1:${port}/ws`;
  try {
    const a = await connect(url), b = await connect(url);
    a.send({ type: 'create', name: 'Alice', pairs: 6, theme: 'ocean' });
    const sessionA = await a.next();
    assert.equal(sessionA.type, 'session');
    assert.equal((await a.next()).phase, 'waiting');
    b.send({ type: 'join', name: 'Bob', code: sessionA.code });
    const stateA = await a.next();
    const sessionB = await b.next(), stateB = await b.next();
    assert.deepEqual(stateA, stateB);
    assert.ok(stateA.cards.every(c => c === null));
    b.send({ type: 'flip', index: 0 });
    assert.equal((await b.next()).code, 'NOT_YOUR_TURN');
    a.send({ type: 'flip', index: 0 });
    assert.deepEqual(await a.next(), await b.next());
    b.ws.terminate();
    assert.equal((await a.next()).players[1].connected, false);
    const resumed = await connect(url);
    resumed.send({ type: 'resume', code: sessionB.code, token: sessionB.token });
    assert.equal((await resumed.next()).playerId, sessionB.playerId);
    assert.equal((await resumed.next()).players[1].connected, true);
    assert.equal((await a.next()).players[1].connected, true);
    const health = await fetch(`http://127.0.0.1:${port}/healthz`).then(r => r.json());
    assert.equal(health.ok, true);
    assert.equal(health.protocol, 1);
    assert.ok(!(JSON.stringify(health).includes(sessionA.code)));
    assert.equal((await fetch(`http://127.0.0.1:${port}/privacy`)).status, 200);
  } finally { await server.close(); }
});

test('unknown origins cannot open WebSocket connections', async () => {
  const server = startServer({ port: 0, dataDir: null, engine: new GameEngine() });
  await once(server.http, 'listening');
  const ws = new WebSocket(`ws://127.0.0.1:${server.http.address().port}/ws`, { origin: 'https://evil.example' });
  try {
    const [error] = await once(ws, 'error');
    assert.match(error.message, /403/);
  } finally { await server.close(); }
});

test('legacy sockets cannot occupy or resume a new-deck seat; capable clients join and legacy garden still works', async () => {
  const server = startServer({ port: 0, dataDir: null });
  await once(server.http, 'listening');
  const url = `ws://127.0.0.1:${server.http.address().port}/ws`;
  const supportedDecks = ['garden', 'cosmos', 'ocean', 'paola', 'food', 'sports', 'travel'];
  try {
    const host = await connect(url), old = await connect(url);
    host.send({ type: 'create', name: 'A', pairs: 18, theme: 'paola', supportedDecks });
    const first = await host.next();
    assert.equal(first.type, 'session');
    await host.next();
    old.send({ type: 'join', code: first.code, name: 'Vecchia app' });
    assert.deepEqual(await old.next(), { type: 'error', code: 'UPDATE_REQUIRED', message: 'Aggiorna SommoMemory per giocare con questa collezione.' });
    assert.equal(server.engine.room(first.code).players.length, 1);
    assert.equal(server.engine.room(first.code).phase, 'waiting');
    const capable = await connect(url);
    capable.send({ type: 'join', code: first.code, name: 'Nuova app', supportedDecks });
    const second = await capable.next();
    assert.equal(second.type, 'session');
    assert.equal((await capable.next()).theme, 'paola');
    assert.equal((await host.next()).phase, 'playing');
    capable.ws.terminate();
    assert.equal((await host.next()).players[1].connected, false);
    const resumed = await connect(url);
    resumed.send({ type: 'resume', code: second.code, token: second.token });
    assert.equal((await resumed.next()).code, 'UPDATE_REQUIRED');
    assert.equal(server.engine.room(first.code).players[1].connected, false);
    resumed.send({ type: 'resume', code: second.code, token: second.token, supportedDecks });
    assert.equal((await resumed.next()).playerId, second.playerId);
    assert.equal((await resumed.next()).players[1].connected, true);
    await host.next();
    // A rejected legacy join left the socket free for a supported garden room.
    old.send({ type: 'create', name: 'Vecchia app', pairs: 6, theme: 'garden' });
    const garden = await old.next();
    assert.equal(garden.type, 'session');
    assert.equal((await old.next()).phase, 'waiting');
    const newGuest = await connect(url);
    newGuest.send({ type: 'join', code: garden.code, name: 'Nuova app', supportedDecks });
    assert.equal((await newGuest.next()).type, 'session');
    assert.equal((await newGuest.next()).theme, 'garden');
    assert.equal((await old.next()).phase, 'playing');
  } finally { await server.close(); }
});

test('associated domain files are public JSON, including the root iOS alias, without SPA fallback', async () => {
  const server = startServer({ port: 0, dataDir: null });
  await once(server.http, 'listening');
  const base = `http://127.0.0.1:${server.http.address().port}`;
  try {
    const association = await fetch(`${base}/.well-known/apple-app-site-association`);
    assert.equal(association.status, 200);
    assert.equal(association.headers.get('content-type'), 'application/json');
    assert.equal(association.headers.get('set-cookie'), null);
    const aasa = await association.json();
    assert.ok(JSON.stringify(aasa).includes('L6CS7PYA4B.cc.sommomi.mymemory'));
    assert.deepEqual(await fetch(`${base}/apple-app-site-association`).then(r => r.json()), aasa);
    const android = await fetch(`${base}/.well-known/assetlinks.json`);
    assert.equal(android.status, 200);
    assert.equal(android.headers.get('content-type'), 'application/json');
    const statements = await android.json();
    assert.equal(statements[0].target.package_name, 'cc.sommomi.mymemory');
    assert.ok(statements[0].target.sha256_cert_fingerprints.includes('CF:88:45:9A:49:8A:E9:C3:68:EE:97:B9:BF:DC:C7:4B:EA:BF:6C:1A:A7:31:40:CF:F3:93:1C:AD:85:A9:73:13'));
  } finally { await server.close(); }
});

test('a cached prior web release cannot conceal a newly deployed interface', async () => {
  const { mkdtemp, writeFile, rm } = await import('node:fs/promises');
  const { tmpdir } = await import('node:os');
  const { join, resolve } = await import('node:path');
  const { execFileSync } = await import('node:child_process');
  const webDir = await mkdtemp(join(tmpdir(), 'mymemory-web-upgrade-'));
  const helper = resolve(import.meta.dirname, '../../scripts/prepare-web.mjs');
  const bootstrap = 'const fallback="main.dart.js"; const build={"mainJsPath":"main.dart.js"};';
  const build = async text => {
    await writeFile(join(webDir, 'main.dart.js'), text);
    await writeFile(join(webDir, 'flutter_bootstrap.js'), bootstrap);
    execFileSync(process.execPath, [helper, webDir]);
  };
  await build('old interface with slogans');
  const server = startServer({ port: 0, dataDir: null, webDir, engine: new GameEngine() });
  await once(server.http, 'listening');
  const base = `http://127.0.0.1:${server.http.address().port}`;
  try {
    const entry = async () => {
      const response = await fetch(`${base}/flutter_bootstrap.js`);
      assert.equal(response.headers.get('cache-control'), 'no-cache');
      return (await response.text()).match(/"mainJsPath":"([^"]+)"/)[1];
    };
    const oldPath = await entry();
    const browserCache = new Map([[oldPath, await fetch(`${base}/${oldPath}`).then(r => r.text())]]);
    await build('compact interface without slogans');
    const newPath = await entry();
    assert.notEqual(newPath, oldPath);
    assert.equal(browserCache.has(newPath), false);
    const updated = await fetch(`${base}/${newPath}`);
    assert.equal(updated.headers.get('cache-control'), 'no-cache');
    assert.equal(await updated.text(), 'compact interface without slogans');
    execFileSync(process.execPath, [helper, webDir]);
    assert.equal(await entry(), newPath);
  } finally { await server.close(); await rm(webDir, { recursive: true, force: true }); }
});
