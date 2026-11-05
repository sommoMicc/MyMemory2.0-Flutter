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
  const server = startServer({ port: 0, engine: new GameEngine() });
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
  const server = startServer({ port: 0, engine: new GameEngine() });
  await once(server.http, 'listening');
  const ws = new WebSocket(`ws://127.0.0.1:${server.http.address().port}/ws`, { origin: 'https://evil.example' });
  try {
    const [error] = await once(ws, 'error');
    assert.match(error.message, /403/);
  } finally { await server.close(); }
});
