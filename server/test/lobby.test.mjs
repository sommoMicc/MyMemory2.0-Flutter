import test from 'node:test';
import assert from 'node:assert/strict';
import { EconomyStore } from '../src/economy.mjs';
import { GameEngine } from '../src/game.mjs';
import { ARENA_CATALOG } from '../src/arenas.mjs';

const caps = { supportedFeatures: ['ranked-v1', 'ranked-attempts-v1', 'lobby-v1'], supportedDecks: ARENA_CATALOG.decks.map(d => d.id) };
function fixture(now = () => 0) {
  const store = new EconomyStore({ now });
  const engine = new GameEngine({ now, getProfile: id => store.profile(id), ownsDeck: (id, theme) => store.ownsDeck(id, theme), onRankedSettlement: room => store.settleRanked(room) });
  return { store, engine };
}

test('two ranked lobby seats wait until both ready; leaving guest releases the same code', () => {
  const { store, engine } = fixture();
  try {
    const a = store.createProfile().profile, b = store.createProfile().profile, c = store.createProfile().profile;
    const host = engine.create({ name: 'A', matchType: 'ranked', arenaId: 'wild_valley', profileId: a.id, ...caps });
    assert.throws(() => engine.join({ code: host.code, name: 'Old', profileId: b.id, supportedDecks: caps.supportedDecks, supportedFeatures: ['ranked-v1'] }), { code: 'UPDATE_REQUIRED' });
    const guest = engine.join({ code: host.code, name: 'B', profileId: b.id, ...caps });
    assert.throws(() => engine.resume({ code: host.code, token: guest.token, supportedDecks: caps.supportedDecks, supportedFeatures: ['ranked-v1'] }), { code: 'UPDATE_REQUIRED' });
    let state = engine.state(host.code);
    assert.equal(state.phase, 'waiting'); assert.equal(state.lobbyMode, true);
    assert.deepEqual(state.lobbyReady, []); assert.deepEqual(state.roundDecks, []);
    assert.ok(state.cards.every(card => card === null));
    assert.deepEqual(state.players.map(p => p.id), [host.playerId, guest.playerId]);
    engine.ready(host.code, host.playerId, true);
    engine.leave(host.code, guest.playerId);
    state = engine.state(host.code);
    assert.equal(state.code, host.code); assert.deepEqual(state.lobbyReady, []);
    assert.deepEqual(state.players.map(p => p.id), [host.playerId]);
    assert.throws(() => engine.resume({ code: host.code, token: guest.token, ...caps }), { code: 'INVALID_SESSION' });
    assert.equal(store.profile(a.id).gems, 100); assert.equal(store.profile(b.id).crowns, 0);
    const next = engine.join({ code: host.code, name: 'C', profileId: c.id, ...caps });
    engine.ready(host.code, host.playerId, true);
    assert.equal(engine.state(host.code).phase, 'waiting');
    engine.ready(host.code, next.playerId, true);
    state = engine.state(host.code);
    assert.equal(state.phase, 'playing'); assert.equal(state.roundDecks.length, 3);
    assert.ok(state.cards.every(card => card === null));
  } finally { store.close(); }
});

test('guest timeout frees seat without rewards; host timeout closes lobby', () => {
  let now = 0;
  const { store, engine } = fixture(() => now);
  try {
    const a = store.createProfile().profile, b = store.createProfile().profile;
    const host = engine.create({ name: 'A', matchType: 'ranked', arenaId: 'wild_valley', profileId: a.id, ...caps });
    const guest = engine.join({ code: host.code, name: 'B', profileId: b.id, ...caps });
    engine.ready(host.code, host.playerId, true);
    engine.disconnect(host.code, guest.playerId);
    assert.deepEqual(engine.state(host.code).lobbyReady, []);
    now += 90_001; engine.tick();
    assert.equal(engine.room(host.code).players.length, 1);
    assert.equal(store.db.prepare('SELECT COUNT(*) AS n FROM ranked_matches').get().n, 0);
    assert.equal(store.profile(a.id).gems, 100); assert.equal(store.profile(b.id).crowns, 0);
    const other = engine.create({ name: 'B', matchType: 'ranked', arenaId: 'wild_valley', profileId: b.id, ...caps });
    engine.leave(other.code, other.playerId); assert.equal(engine.rooms.has(other.code), false);
    engine.disconnect(host.code, host.playerId); now += 90_001; engine.tick();
    assert.equal(engine.rooms.has(host.code), false);
  } finally { store.close(); }
});

test('ranked arena and capabilities are revalidated before start, and old clients auto-start', () => {
  const { store, engine } = fixture();
  try {
    const a = store.createProfile().profile, b = store.createProfile().profile;
    const host = engine.create({ name: 'A', matchType: 'ranked', arenaId: 'wild_valley', profileId: a.id, ...caps });
    const guest = engine.join({ code: host.code, name: 'B', profileId: b.id, ...caps });
    engine.ready(host.code, host.playerId, true);
    store.db.prepare('UPDATE profiles SET crowns=100,peak_crowns=100 WHERE id=?').run(b.id);
    assert.throws(() => engine.ready(host.code, guest.playerId, true), { code: 'ARENA_MISMATCH' });
    assert.equal(engine.room(host.code).phase, 'waiting');
    assert.deepEqual(engine.state(host.code).lobbyReady, [host.playerId]);
    engine.leave(host.code, guest.playerId); engine.leave(host.code, host.playerId);
    const old = engine.create({ name: 'Old', theme: 'garden' });
    engine.join({ code: old.code, name: 'Other' });
    assert.equal(engine.state(old.code).phase, 'playing');
    assert.equal(engine.state(old.code).lobbyMode, false);
  } finally { store.close(); }
});

test('real WebSocket lobby retains host while guest leaves and new guest starts with ready', async () => {
  const { once } = await import('node:events');
  const { default: WebSocket } = await import('ws');
  const { startServer } = await import('../src/server.mjs');
  const server = startServer({ port: 0, dataDir: null });
  await once(server.http, 'listening');
  const sockets = [];
  async function connect() {
    const ws = new WebSocket(`ws://127.0.0.1:${server.http.address().port}/ws`); sockets.push(ws);
    const queue = [], waiters = [];
    ws.on('message', raw => { const msg = JSON.parse(raw); waiters.length ? waiters.shift()(msg) : queue.push(msg); });
    await once(ws, 'open');
    return { send: msg => ws.send(JSON.stringify(msg)), next: () => queue.length ? Promise.resolve(queue.shift()) : new Promise(resolve => waiters.push(resolve)) };
  }
  try {
    const host = await connect(), guest = await connect();
    host.send({ type: 'create', name: 'A', theme: 'garden', ...caps });
    const session = await host.next(); assert.equal(session.type, 'session'); assert.equal((await host.next()).lobbyMode, true);
    guest.send({ type: 'join', name: 'B', code: session.code, ...caps });
    const joined = await host.next(); assert.equal(joined.phase, 'waiting');
    assert.equal((await guest.next()).type, 'session'); assert.equal((await guest.next()).players.length, 2);
    guest.send({ type: 'leave' }); assert.equal((await guest.next()).type, 'left');
    assert.equal((await host.next()).players.length, 1);
    const replacement = await connect();
    replacement.send({ type: 'join', name: 'C', code: session.code, ...caps });
    assert.equal((await host.next()).players.length, 2);
    const guestSession = await replacement.next(); await replacement.next();
    host.send({ type: 'ready', ready: true });
    assert.equal((await host.next()).phase, 'waiting'); await replacement.next();
    replacement.send({ type: 'ready', ready: true });
    assert.equal((await host.next()).phase, 'playing'); assert.equal((await replacement.next()).phase, 'playing');
    assert.notEqual(guestSession.playerId, session.playerId);
  } finally { for (const socket of sockets) socket.terminate(); await server.close(); }
});
