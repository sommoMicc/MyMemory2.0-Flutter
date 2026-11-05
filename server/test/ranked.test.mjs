import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { ARENA_CATALOG } from '../src/arenas.mjs';
import { EconomyStore } from '../src/economy.mjs';
import { GameEngine } from '../src/game.mjs';

const catalog = structuredClone(ARENA_CATALOG);
catalog.rankedEnabled = true;
for (const d of catalog.decks) d.contentReady = true;
const caps = { supportedFeatures: ['ranked-v1', 'ranked-attempts-v1'], supportedDecks: catalog.decks.map(d => d.id) };
const makeEngine = (store, options = {}) => new GameEngine({ ...options, catalog,
  getProfile: id => store.profile(id), ownsDeck: (id, deck) => store.ownsDeck(id, deck),
  onRankedSettlement: room => store.settleRanked(room) });
function finishRound(engine, code) {
  const room = engine.room(code);
  const pairs = [...new Set(room.board)].map(value => room.board.flatMap((v, i) => v === value ? [i] : []));
  for (const player of room.players) for (const [a, b] of pairs) { engine.flip(code, player.id, a); engine.flip(code, player.id, b); }
}

test('ranked freezes union, plays three distinct rounds and settles exactly once after restart', () => {
  const dir = mkdtempSync(join(tmpdir(), 'ranked-'));
  let store;
  try {
    store = new EconomyStore({ dataDir: dir, catalog });
    const host = store.createProfile().profile, guest = store.createProfile().profile;
    store.db.prepare('INSERT INTO owned_decks(profile_id,deck_id) VALUES(?,?)').run(guest.id, 'insects');
    let engine = makeEngine(store, { dataDir: dir });
    const a = engine.create({ name: 'A', matchType: 'ranked', arenaId: 'wild_valley', profileId: host.id, ...caps });
    assert.throws(() => engine.join({ code: a.code, name: 'A', profileId: host.id, ...caps }), { code: 'SAME_PROFILE' });
    assert.throws(() => engine.join({ code: a.code, name: 'B', profileId: guest.id, ...caps, supportedDecks: caps.supportedDecks.filter(d => d !== 'insects') }), { code: 'UPDATE_REQUIRED' });
    assert.equal(engine.room(a.code).players.length, 1);
    const b = engine.join({ code: a.code, name: 'B', profileId: guest.id, ...caps });
    assert.ok(engine.room(a.code).rankedPool.includes('insects'));
    assert.equal(new Set(engine.room(a.code).roundDecks).size, 3);
    assert.throws(() => engine.create({ name: 'A', matchType: 'ranked', arenaId: 'wild_valley', profileId: host.id, ...caps }), { code: 'RANKED_BUSY' });
    const room = engine.room(a.code), matchId = room.matchId;
    for (let round = 1; round <= 3; round++) {
      assert.equal(room.roundIndex, round);
      assert.equal(new Set(room.board).size, 12);
      assert.ok(engine.state(a.code).cards.every(card => card === null));
      finishRound(engine, a.code);
      if (round < 3) {
        assert.equal(room.phase, 'roundFinished');
        engine.nextRound(a.code, a.playerId); engine.nextRound(a.code, b.playerId);
      }
    }
    assert.equal(room.phase, 'finished');
    assert.equal(room.roundResults.length, 3);
    assert.equal(store.db.prepare('SELECT COUNT(*) AS n FROM ranked_matches WHERE match_id=?').get(matchId).n, 1);
    const beforeA = store.profile(host.id), beforeB = store.profile(guest.id);
    assert.equal(beforeA.gems, 120); assert.equal(beforeB.gems, 120);
    assert.equal(beforeA.crowns + beforeB.crowns, 0);
    assert.equal(room.winnerId, null);
    store.close();
    store = new EconomyStore({ dataDir: dir, catalog });
    engine = makeEngine(store, { dataDir: dir });
    assert.equal(engine.room(a.code).matchId, matchId);
    assert.equal(store.profile(host.id).crowns, beforeA.crowns);
    assert.equal(store.profile(guest.id).crowns, beforeB.crowns);
    assert.equal(store.profile(host.id).gems, 120);
  } finally { store?.close(); rmSync(dir, { recursive: true, force: true }); }
});

test('forfeit and simultaneous disconnect settle once with no gem reward', () => {
  let now = 0;
  const store = new EconomyStore({ catalog, now: () => now });
  try {
    const host = store.createProfile().profile, guest = store.createProfile().profile;
    const engine = makeEngine(store, { now: () => now });
    const a = engine.create({ name: 'A', matchType: 'ranked', arenaId: 'wild_valley', profileId: host.id, ...caps });
    const b = engine.join({ code: a.code, name: 'B', profileId: guest.id, ...caps });
    engine.disconnect(a.code, a.playerId); now += 90_001; engine.tick();
    assert.equal(engine.room(a.code).finishReason, 'forfeit');
    assert.equal(store.profile(guest.id).crowns, 20);
    assert.equal(store.profile(host.id).crowns, 0);
    assert.equal(store.profile(guest.id).gems, 100);
    store.settleRanked(engine.room(a.code));
    assert.equal(store.profile(guest.id).crowns, 20);
    const c = engine.create({ name: 'C', matchType: 'ranked', arenaId: 'wild_valley', profileId: host.id, ...caps });
    const d = engine.join({ code: c.code, name: 'D', profileId: guest.id, ...caps });
    engine.disconnect(c.code, c.playerId); now += 10_000; engine.disconnect(c.code, d.playerId);
    now += 80_001; engine.tick(); assert.equal(engine.room(c.code).phase, 'playing');
    now += 10_000; engine.tick(); assert.equal(engine.room(c.code).finishReason, 'cancelled');
    assert.equal(store.profile(guest.id).crowns, 20);
  } finally { store.close(); }
});

test('two real WebSocket clients complete a ranked match without exposing covered cards or profile IDs', async () => {
  const { once } = await import('node:events');
  const { default: WebSocket } = await import('ws');
  const { startServer } = await import('../src/server.mjs');
  const store = new EconomyStore({ catalog });
  const engine = makeEngine(store);
  const server = startServer({ port: 0, dataDir: null, engine, economy: store });
  await once(server.http, 'listening');
  const clients = [];
  async function connect() {
    const ws = new WebSocket(`ws://127.0.0.1:${server.http.address().port}/ws`);
    clients.push(ws);
    const queue = [], waiting = [];
    ws.on('message', raw => { const value = JSON.parse(raw); waiting.length ? waiting.shift()(value) : queue.push(value); });
    await once(ws, 'open');
    return { send: value => ws.send(JSON.stringify(value)), next: () => queue.length ? Promise.resolve(queue.shift()) : new Promise(resolve => waiting.push(resolve)) };
  }
  try {
    const owner = store.createProfile(), guest = store.createProfile();
    const a = await connect(), b = await connect();
    a.send({ type: 'create', name: 'A', matchType: 'ranked', arenaId: 'wild_valley', profileToken: owner.token, ...caps });
    const sa = await a.next(); assert.equal(sa.type, 'session'); await a.next();
    b.send({ type: 'join', name: 'B', code: sa.code, profileToken: guest.token, ...caps });
    let state = await a.next(); const sb = await b.next(); assert.equal(sb.type, 'session'); assert.deepEqual(await b.next(), state);
    assert.ok(state.cards.every(card => card === null));
    assert.equal(JSON.stringify(state).includes(owner.profile.id), false);
    const players = { [sa.playerId]: a, [sb.playerId]: b };
    for (let round = 1; round <= 3; round++) {
      const room = engine.room(sa.code);
      const solution = [...new Set(room.board)].flatMap(value => room.board.flatMap((v, i) => v === value ? [i] : []));
      for (const id of [sa.playerId, sb.playerId]) for (const index of solution) {
        players[id].send({ type: 'flip', index });
        const stateA = await a.next(), stateB = await b.next();
        assert.equal(stateA.type, 'state'); assert.equal(stateB.type, 'state');
        state = stateA;
        if (id === sa.playerId && room.players[1].score === 0) assert.ok(stateB.cards.every(card => card === null));
        if (id === sb.playerId && room.players[0].score === 12) assert.equal(stateA.matched.length, 24);
      }
      if (round < 3) {
        assert.equal(state.phase, 'roundFinished');
        a.send({ type: 'nextRound' }); await a.next(); await b.next();
        b.send({ type: 'nextRound' }); state = await a.next(); assert.equal((await b.next()).phase, state.phase);
        assert.equal(state.roundIndex, round + 1);
      }
    }
    assert.equal(state.phase, 'finished'); assert.equal(state.roundResults.length, 3);
    assert.equal(store.profile(owner.profile.id).gems, 120);
    assert.equal(store.profile(guest.profile.id).gems, 120);
  } finally { for (const ws of clients) ws.terminate(); await server.close(); store.close(); }
});

test('failed forfeit settlement survives restart and blocks concurrent ranked games until retry', () => {
  const dir = mkdtempSync(join(tmpdir(), 'ranked-retry-'));
  let store;
  try {
    store = new EconomyStore({ dataDir: dir, catalog });
    const a = store.createProfile().profile, b = store.createProfile().profile;
    let engine = makeEngine(store, { dataDir: dir });
    const sa = engine.create({ name: 'A', matchType: 'ranked', arenaId: 'wild_valley', profileId: a.id, ...caps });
    engine.join({ code: sa.code, name: 'B', profileId: b.id, ...caps });
    engine.onRankedSettlement = () => { throw new Error('temporary database outage'); };
    engine.leave(sa.code, sa.playerId);
    assert.equal(engine.room(sa.code).finishReason, 'forfeit');
    assert.throws(() => engine.create({ name: 'B', matchType: 'ranked', arenaId: 'wild_valley', profileId: b.id, ...caps }), { code: 'RANKED_BUSY' });
    assert.equal(store.profile(b.id).crowns, 0);
    store.close(); store = new EconomyStore({ dataDir: dir, catalog });
    engine = makeEngine(store, { dataDir: dir });
    assert.equal(store.profile(b.id).crowns, 20);
    assert.equal(store.profile(b.id).gems, 100);
    store.settleRanked(engine.room(sa.code));
    assert.equal(store.profile(b.id).crowns, 20);
  } finally { store?.close(); rmSync(dir, { recursive: true, force: true }); }
});

test('join checks arena and reconnect checks the entire pool before seat changes', () => {
  const store = new EconomyStore({ catalog });
  try {
    const a = store.createProfile().profile, b = store.createProfile().profile;
    const engine = makeEngine(store);
    const sa = engine.create({ name: 'A', matchType: 'ranked', arenaId: 'wild_valley', profileId: a.id, ...caps });
    store.db.prepare('UPDATE profiles SET crowns=100,peak_crowns=100 WHERE id=?').run(b.id);
    assert.throws(() => engine.join({ code: sa.code, name: 'B', profileId: b.id, ...caps }), { code: 'ARENA_MISMATCH' });
    assert.equal(engine.room(sa.code).players.length, 1);
    store.db.prepare('UPDATE profiles SET crowns=0 WHERE id=?').run(b.id);
    store.db.prepare('INSERT INTO owned_decks(profile_id,deck_id) VALUES(?,?)').run(b.id, 'insects');
    const sb = engine.join({ code: sa.code, name: 'B', profileId: b.id, ...caps });
    engine.disconnect(sa.code, sb.playerId);
    assert.throws(() => engine.resume({ code: sa.code, token: sb.token, ...caps, supportedDecks: caps.supportedDecks.filter(d => d !== 'insects') }), { code: 'UPDATE_REQUIRED' });
    assert.equal(engine.room(sa.code).players[1].connected, false);
    engine.resume({ code: sa.code, token: sb.token, ...caps });
    assert.equal(engine.room(sa.code).players[1].connected, true);
  } finally { store.close(); }
});

test('incomplete free arena stays disabled even with owned paid decks', () => {
  const incomplete = structuredClone(catalog);
  for (const deck of incomplete.decks) if (deck.arenaId === 'wild_valley' && deck.price === 0 && deck.id !== 'garden') deck.contentReady = false;
  const store = new EconomyStore({ catalog: incomplete });
  try {
    const p = store.createProfile().profile;
    const engine = new GameEngine({ catalog: incomplete, getProfile: id => store.profile(id) });
    assert.throws(() => engine.create({ name: 'A', matchType: 'ranked', arenaId: 'wild_valley', profileId: p.id, ...caps }), { code: 'RANKED_UNAVAILABLE' });
  } finally { store.close(); }
});

test('profile edits cannot assign crowns or historical progression', () => {
  const store = new EconomyStore({ catalog });
  try {
    const profile = store.createProfile().profile;
    assert.throws(() => store.updateProfile(profile.id, { crowns: 600, peakCrowns: 600 }), { code: 'INVALID_PROFILE_UPDATE' });
    const updated = store.updateProfile(profile.id, { displayName: 'A', crowns: 600, peakCrowns: 600 }).profile;
    assert.equal(updated.crowns, 0);
    assert.equal(updated.peakCrowns, 0);
    assert.deepEqual(updated.unlockedArenaIds, ['wild_valley']);
  } finally { store.close(); }
});

test('invalid ranked join leaves waiting room unchanged and deleting a profile cancels without reward', () => {
  const store = new EconomyStore({ catalog });
  try {
    const a = store.createProfile().profile, b = store.createProfile().profile;
    const engine = makeEngine(store);
    const sa = engine.create({ name: 'A', matchType: 'ranked', arenaId: 'wild_valley', profileId: a.id, ...caps });
    const before = JSON.stringify(engine.room(sa.code));
    assert.throws(() => engine.join({ code: sa.code, name: '', profileId: b.id, ...caps }), { code: 'INVALID_NAME' });
    assert.equal(JSON.stringify(engine.room(sa.code)), before);
    engine.join({ code: sa.code, name: 'B', profileId: b.id, ...caps });
    store.deleteProfile(a.id, { confirmDelete: true });
    engine.detachProfile(a.id);
    assert.equal(engine.room(sa.code).finishReason, 'cancelled');
    assert.equal(store.profile(b.id).crowns, 0);
    assert.equal(store.profile(b.id).gems, 100);
    assert.equal(store.db.prepare('SELECT COUNT(*) AS n FROM ranked_matches').get().n, 1);
  } finally { store.close(); }
});

test('settlement uses injected catalog crown rules and waiting room closes on profile deletion', () => {
  const custom = structuredClone(catalog);
  Object.assign(custom.rules, { crownsWin: 13, crownsLoss: -7, crownsDraw: 2, crownsFloor: 3 });
  const store = new EconomyStore({ catalog: custom });
  try {
    const a = store.createProfile().profile, b = store.createProfile().profile;
    store.db.prepare('UPDATE profiles SET crowns=5,peak_crowns=5 WHERE id=?').run(a.id);
    const engine = new GameEngine({ catalog: custom, getProfile: id => store.profile(id),
      onRankedSettlement: room => store.settleRanked(room) });
    const waiting = engine.create({ name: 'A', matchType: 'ranked', arenaId: 'wild_valley', profileId: a.id, ...caps });
    store.deleteProfile(a.id, { confirmDelete: true });
    engine.detachProfile(a.id);
    assert.equal(engine.rooms.has(waiting.code), false);
    assert.equal(store.db.prepare('SELECT COUNT(*) AS n FROM ranked_matches').get().n, 0);
    const c = store.createProfile().profile;
    store.db.prepare('UPDATE profiles SET crowns=5,peak_crowns=5 WHERE id=?').run(c.id);
    const match = { phase: 'finished', matchId: 'custom_rules', finishReason: 'forfeit', winnerId: 'winner',
      players: [{ id: 'loser', profileId: c.id }, { id: 'winner', profileId: b.id }] };
    const receipt = store.settleRanked(match);
    assert.equal(receipt.loser.crownsDelta, -2);
    assert.equal(receipt.winner.crownsDelta, 13);
    assert.equal(store.profile(c.id).crowns, 3);
    assert.equal(store.profile(b.id).crowns, 13);
    assert.deepEqual(store.settleRanked(match), receipt);
  } finally { store.close(); }
});

test('independent boards isolate reveals and mismatch locks; resume restores only the caller board', () => {
  const dir = mkdtempSync(join(tmpdir(), 'ranked-private-'));
  let now = 1000, store;
  try {
    store = new EconomyStore({ dataDir: dir, catalog, now: () => now });
    let engine = makeEngine(store, { dataDir: dir, now: () => now, mismatchMs: 100 });
    const a = store.createProfile().profile, b = store.createProfile().profile;
    const host = engine.create({ name: 'A', matchType: 'ranked', arenaId: 'wild_valley', profileId: a.id, ...caps });
    const guest = engine.join({ code: host.code, name: 'B', profileId: b.id, ...caps });
    const room = engine.room(host.code);
    const mismatch = room.board.findIndex(v => v !== room.board[0]);
    engine.flip(host.code, host.playerId, 0);
    assert.equal(engine.state(host.code, host.playerId).cards[0], room.board[0]);
    assert.equal(engine.state(host.code, guest.playerId).cards[0], null);
    engine.flip(host.code, guest.playerId, 0);
    engine.flip(host.code, host.playerId, mismatch);
    assert.equal(engine.state(host.code, host.playerId).players[0].attempts, 1);
    assert.equal(engine.state(host.code, guest.playerId).players[1].attempts, 0);
    assert.throws(() => engine.flip(host.code, host.playerId, 1), { code: 'BOARD_LOCKED' });
    const pair = room.board.findIndex((v, i) => i !== 0 && v === room.board[0]);
    engine.flip(host.code, guest.playerId, pair);
    assert.equal(engine.state(host.code, guest.playerId).matched.length, 2);
    assert.deepEqual(engine.state(host.code, host.playerId).matched, []);
    engine.disconnect(host.code, host.playerId);
    store.close(); store = new EconomyStore({ dataDir: dir, catalog, now: () => now });
    engine = makeEngine(store, { dataDir: dir, now: () => now, mismatchMs: 100 });
    engine.resume({ code: host.code, token: host.token, ...caps });
    engine.resume({ code: host.code, token: guest.token, ...caps });
    assert.equal(engine.state(host.code, host.playerId).selected.length, 2);
    assert.equal(engine.state(host.code, guest.playerId).matched.length, 2);
    assert.equal(engine.state(host.code, guest.playerId).cards[mismatch], null);
    now += 101; engine.tick();
    assert.deepEqual(engine.state(host.code, host.playerId).selected, []);
    assert.equal(engine.state(host.code, guest.playerId).matched.length, 2);
  } finally { store?.close(); rmSync(dir, { recursive: true, force: true }); }
});

test('old ranked capability is rejected before creating or resuming a seat', () => {
  const store = new EconomyStore({ catalog });
  try {
    const a = store.createProfile().profile, engine = makeEngine(store);
    assert.throws(() => engine.create({ name: 'A', matchType: 'ranked', arenaId: 'wild_valley', profileId: a.id,
      supportedDecks: caps.supportedDecks, supportedFeatures: ['ranked-v1'] }), { code: 'UPDATE_REQUIRED' });
    const host = engine.create({ name: 'A', matchType: 'ranked', arenaId: 'wild_valley', profileId: a.id, ...caps });
    assert.throws(() => engine.resume({ code: host.code, token: host.token,
      supportedDecks: caps.supportedDecks, supportedFeatures: ['ranked-v1'] }), { code: 'UPDATE_REQUIRED' });
    assert.equal(engine.state(host.code, host.playerId).players[0].connected, true);
  } finally { store.close(); }
});
