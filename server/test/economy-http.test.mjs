import test from 'node:test';
import assert from 'node:assert/strict';
import { once } from 'node:events';
import WebSocket from 'ws';
import { startServer } from '../src/server.mjs';

const solution = board => [...new Set(board)].flatMap(value => board.flatMap((card, index) => card === value ? [index] : []));
async function fixture() {
  const server = startServer({ port: 0, dataDir: null });
  await once(server.http, 'listening');
  const base = `http://127.0.0.1:${server.http.address().port}`;
  const api = async (path, { token, method = 'GET', data, headers = {} } = {}) => {
    const response = await fetch(`${base}/api/v1${path}`, { method, headers: {
      ...(token ? { Authorization: `Bearer ${token}` } : {}), ...(data !== undefined ? { 'Content-Type': 'application/json' } : {}), ...headers,
    }, ...(data !== undefined ? { body: JSON.stringify(data) } : {}) });
    return { status: response.status, body: response.status === 204 ? null : await response.json(), headers: response.headers };
  };
  return { server, base, api };
}

test('real HTTP concurrent unlock/claims are atomic, authenticated and idempotent', async () => {
  const { server, api } = await fixture();
  try {
    const { body: guest } = await api('/profiles', { method: 'POST', data: {} });
    const token = guest.token;
    server.economy.db.prepare('UPDATE profiles SET crowns=300,peak_crowns=300 WHERE id=?').run(guest.profile.id);
    const catalog = await api('/catalog');
    for (const deck of server.economy.catalog.decks.filter(d => d.contentReady))
      assert.ok(catalog.body.decks.some(item => item.id === deck.id && item.price === deck.price));
    assert.equal(catalog.body.rankedEnabled, server.economy.catalog.rankedEnabled);
    assert.equal((await api('/profile')).status, 401);
    for (let game = 0; game < 5; game++) {
      const { body: issued } = await api('/games/tickets', { token, method: 'POST', data: { mode: 'solo', pairs: 6, theme: 'garden', requestId: `game_request_${game}` } });
      const data = { ticketId: issued.ticket.id, moves: solution(issued.ticket.board), requestId: `claim_request_${game}` };
      const claims = await Promise.all(Array.from({ length: 8 }, (_, retry) => api('/games/claims', { token, method: 'POST', data: { ...data, requestId: `${data.requestId}_${retry}` } })));
      assert.ok(claims.every(c => c.status === 200));
      assert.equal(claims.filter(c => c.body.reward.granted).length, 1);
    }
    assert.equal((await api('/profile', { token })).body.profile.gems, 200);
    const unlocks = await Promise.all(Array.from({ length: 12 }, (_, i) => api('/wallet/unlock', { token, method: 'POST', data: { deckId: 'food', requestId: `unlock_request_${i}` } })));
    assert.ok(unlocks.every(result => result.status === 200 && result.body.profile.gems === 0));
    assert.equal(unlocks.filter(result => result.body.unlocked).length, 1);
    assert.equal((await api('/profile/ledger', { token })).body.entries.filter(e => e.source === 'unlock:food').length, 1);
    const activation = await api('/profile/recovery', { token, method: 'POST', data: {} });
    const restored = await api('/profiles/restore', { method: 'POST', data: { recoveryCode: activation.body.recoveryCode, confirmReplace: true } });
    assert.equal(restored.body.profile.gems, 0);
    assert.ok(restored.body.profile.ownedDecks.includes('food'));
    assert.equal((await api('/profile/logout', { token, method: 'POST', data: {} })).status, 200);
    assert.equal((await api('/profile', { token })).status, 401);
    assert.equal((await api('/profile', { token: restored.body.token })).status, 200);
  } finally { await server.close(); }
});

test('REST rejects malicious origins, invalid bodies, excess data, guesses, and never leaks credentials', async () => {
  const { server, base, api } = await fixture();
  try {
    assert.equal((await api('/catalog', { headers: { Origin: 'https://evil.example' } })).status, 403);
    const allowed = await api('/catalog', { headers: { Origin: 'https://sommomemory.sommomi.cc' } });
    assert.equal(allowed.headers.get('access-control-allow-origin'), 'https://sommomemory.sommomi.cc');
    assert.equal(allowed.headers.get('cache-control'), 'no-store');
    assert.equal((await api('/catalog', { method: 'OPTIONS', headers: { Origin: 'https://sommomemory.sommomi.cc' } })).status, 204);
    assert.equal((await fetch(`${base}/api/v1/profiles`, { method: 'POST', body: '{}' })).status, 415);
    assert.equal((await api('/profiles', { method: 'POST', data: [] })).status, 400);
    assert.equal((await fetch(`${base}/api/v1/profiles`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: '{' })).status, 400);
    const huge = await api('/profiles', { method: 'POST', data: { excess: 'x'.repeat(70_000) } });
    assert.equal(huge.status, 413);
    assert.equal(huge.body.error.code, 'BODY_TOO_LARGE');
    const created = await api('/profiles', { method: 'POST', data: {} });
    assert.equal(created.status, 201);
    const profile = await api('/profile', { token: created.body.token });
    assert.equal(JSON.stringify(profile.body).includes(created.body.token), false);
    assert.equal(Object.keys(profile.body.profile).some(name => /token|hash|recoveryCode/i.test(name)), false);
    for (let i = 0; i < 20; i++) assert.equal((await api('/profiles/restore/preview', { method: 'POST', data: { recoveryCode: 'bad' } })).status, 401);
    assert.equal((await api('/profiles/restore/preview', { method: 'POST', data: { recoveryCode: 'bad' } })).status, 429);
  } finally { await server.close(); }
});

test('WebSocket enforces owned host deck, allows guest access, and does not leak profile credentials', async () => {
  const { server, api } = await fixture();
  const clients = [];
  async function connect() {
    const ws = new WebSocket(`ws://127.0.0.1:${server.http.address().port}/ws`);
    clients.push(ws);
    const queue = [], waits = [];
    ws.on('message', raw => { const message = JSON.parse(raw); if (waits.length) waits.shift()(message); else queue.push(message); });
    await once(ws, 'open');
    return { send: message => ws.send(JSON.stringify(message)), next: () => queue.length ? Promise.resolve(queue.shift()) : new Promise(resolve => waits.push(resolve)) };
  }
  try {
    const { body: owner } = await api('/profiles', { method: 'POST', data: {} });
    const host = await connect();
    host.send({ type: 'create', name: 'A', pairs: 6, theme: 'food', profileToken: owner.token, supportedDecks: ['food'] });
    assert.equal((await host.next()).code, 'DECK_LOCKED');
    // Fund only through the actual validated completion mechanism.
    for (let game = 0; game < 5; game++) {
      const result = server.economy.issueTicket(owner.profile.id, { mode: 'solo', pairs: 6, theme: 'garden', requestId: `issue_game_${game}` });
      server.economy.claim(owner.profile.id, { ticketId: result.ticket.id, moves: solution(result.ticket.board), requestId: `finish_game_${game}` });
    }
    server.economy.db.prepare('UPDATE profiles SET crowns=300,peak_crowns=300 WHERE id=?').run(owner.profile.id);
    await api('/wallet/unlock', { token: owner.token, method: 'POST', data: { deckId: 'food', requestId: 'unlock_food_1' } });
    host.send({ type: 'create', name: 'A', pairs: 6, theme: 'food', profileToken: owner.token, supportedDecks: ['food'] });
    const session = await host.next();
    assert.equal(session.type, 'session');
    assert.equal((await host.next()).theme, 'food');
    const guest = await connect();
    guest.send({ type: 'join', name: 'B', code: session.code, profileId: owner.profile.id, supportedDecks: ['food'] });
    assert.equal((await guest.next()).type, 'session');
    const state = await guest.next();
    assert.equal(state.phase, 'playing');
    assert.ok(state.cards.every(card => card === null));
    assert.equal(JSON.stringify(state).includes(owner.token), false);
    assert.equal(JSON.stringify(state).includes(owner.profile.id), false);
    assert.equal(server.engine.room(session.code).players[1].profileId, undefined);
  } finally { for (const ws of clients) ws.terminate(); await server.close(); }
});
