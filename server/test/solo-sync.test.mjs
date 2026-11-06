import test from 'node:test';
import assert from 'node:assert/strict';
import { randomBytes } from 'node:crypto';
import { mkdtempSync, readFileSync, readdirSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { once } from 'node:events';
import { EconomyStore } from '../src/economy.mjs';
import { startServer } from '../src/server.mjs';

let next = 0;
const key = () => `offline_request_${++next}`;
const complete = (extra = {}) => {
  const board = Array.from({ length: 12 }, (_, index) => Math.floor(index / 2));
  return { kind: 'complete', requestId: key(), gameId: key(), theme: 'garden', pairs: 6,
    board, moves: board.map((_, index) => index), ...extra };
};

test('first offline guest registration is retryable across restart with one welcome grant and hashed credentials', () => {
  const dataDir = mkdtempSync(join(tmpdir(), 'sommomemory-offline-bootstrap-'));
  const bootstrapToken = randomBytes(32).toString('base64url');
  let store = new EconomyStore({ dataDir });
  try {
    const first = store.bootstrapGuest({ bootstrapToken });
    assert.equal(store.authenticate(first.token), first.profile.id);
    assert.equal(first.token, bootstrapToken);
    const game = complete();
    store.soloOperation(first.profile.id, game);
    store.close();
    store = new EconomyStore({ dataDir });
    const retried = store.bootstrapGuest({ bootstrapToken });
    assert.equal(retried.profile.id, first.profile.id);
    assert.equal(retried.profile.gems, 120);
    assert.equal(store.db.prepare('SELECT COUNT(*) n FROM profiles').get().n, 1);
    assert.equal(store.ledger(first.profile.id).entries.filter(entry => entry.source === 'welcome').length, 1);
    for (const name of readdirSync(dataDir).filter(name => name.startsWith('economy.sqlite')))
      assert.equal(readFileSync(join(dataDir, name)).includes(bootstrapToken), false);
    store.logout(bootstrapToken);
    assert.throws(() => store.bootstrapGuest({ bootstrapToken }), { code: 'INVALID_TOKEN' });
    // Deletion retains only the established short-lived token tombstone, also
    // for an initial registration credential that was subsequently logged out.
    store.deleteProfile(first.profile.id, { confirmDelete: true });
    assert.throws(() => store.bootstrapGuest({ bootstrapToken }), { code: 'PROFILE_DELETED' });
    assert.equal(store.db.prepare('SELECT COUNT(*) n FROM offline_bootstraps').get().n, 0);
  } finally { store.close(); rmSync(dataDir, { recursive: true, force: true }); }
});

test('unlimited solo completions and ordered unlocks merge once, survive lost responses and never assign crowns', () => {
  let now = 1000;
  const store = new EconomyStore({ now: () => now });
  try {
    const id = store.createProfile().profile.id;
    const deck = store.catalog.decks.find(item => item.arenaId === 'wild_valley' && item.price > 0);
    const games = Array.from({ length: 110 }, () => complete());
    for (const game of games) store.soloOperation(id, { ...game, crowns: 600, peakCrowns: 600 });
    assert.equal(store.profile(id).gems, 2300);
    assert.equal(store.profile(id).crowns, 0);
    assert.equal(store.profile(id).peakCrowns, 0);
    assert.deepEqual(store.profile(id).soloBestAttempts, { '6': 6 });
    const unlock = { requestId: key(), kind: 'unlock', deckId: deck.id };
    assert.equal(store.soloOperation(id, unlock).operation.unlocked, true);
    // Requests are durably remembered even beyond ticket and request-cache TTLs.
    now += 365 * 86_400_000;
    store.cleanup();
    for (const game of games) store.soloOperation(id, game);
    const retry = store.soloOperation(id, unlock);
    assert.equal(retry.profile.gems, 2300 - deck.price);
    assert.equal(retry.operation.unlocked, true);
    assert.equal(store.soloOperation(id, { ...unlock, requestId: key() }).operation.alreadyOwned, true);
    assert.equal(store.ledger(id).entries.filter(item => item.source === `unlock:${deck.id}`).length, 1);
    assert.equal(store.soloOperation(id, { ...games[0], requestId: key() }).operation.reward.granted, false);
    assert.equal(store.profile(id).gems, 2300 - deck.price);
    assert.throws(() => store.soloOperation(id, { ...games[0], theme: 'farm' }), { code: 'IDEMPOTENCY_CONFLICT' });
    assert.throws(() => store.soloOperation(id, { ...games[0], requestId: key(), theme: 'farm' }), { code: 'IDEMPOTENCY_CONFLICT' });
    const other = store.createProfile().profile.id;
    assert.throws(() => store.soloOperation(other, { ...games[0], requestId: key() }), { code: 'GAME_ALREADY_CLAIMED' });
  } finally { store.close(); }
});

test('solo sync validates deck access, board and complete transcript before any wallet mutation', () => {
  const store = new EconomyStore();
  try {
    const id = store.createProfile().profile.id;
    for (const game of [complete({ pairs: 7 }), complete({ theme: 'missing' }),
      complete({ board: Array(12).fill(0) }), complete({ board: Array.from({ length: 12 }, (_, index) => `${index >> 1}`) }),
      complete({ board: [0, 0] }), complete({ moves: [] }), complete({ moves: [0, 0] }),
      complete({ moves: Array.from({ length: 13 }, (_, index) => index) })])
      assert.throws(() => store.soloOperation(id, game), error => ['INVALID_GAME', 'INVALID_TRANSCRIPT'].includes(error.code));
    assert.throws(() => store.soloOperation(id, complete({ theme: 'food' })), { code: 'DECK_LOCKED' });
    assert.throws(() => store.soloOperation(id, { requestId: key(), kind: 'unlock', deckId: 'food' }), { code: 'ARENA_LOCKED' });
    assert.throws(() => store.soloOperation(id, { requestId: key(), kind: 'ranked', crowns: 600 }), { code: 'INVALID_OPERATION' });
    assert.equal(store.profile(id).gems, 100);
    assert.deepEqual(store.profile(id).soloBestAttempts, {});
    assert.equal(store.db.prepare('SELECT COUNT(*) n FROM solo_operations').get().n, 0);
  } finally { store.close(); }
});

test('multi-device purchases do not overdraw and deferred purchases can retry after later completions', () => {
  const store = new EconomyStore();
  try {
    const id = store.createProfile().profile.id;
    const [a, b] = store.catalog.decks.filter(item => item.arenaId === 'wild_valley' && item.price > 0);
    const one = { requestId: key(), kind: 'unlock', deckId: a.id };
    const two = { requestId: key(), kind: 'unlock', deckId: b.id };
    while (store.profile(id).gems < Math.max(a.price, b.price)) store.soloOperation(id, complete());
    store.soloOperation(id, one);
    assert.throws(() => store.soloOperation(id, two), { code: 'INSUFFICIENT_GEMS' });
    assert.ok(store.profile(id).gems >= 0);
    while (store.profile(id).gems < b.price) store.soloOperation(id, complete());
    assert.equal(store.soloOperation(id, two).operation.unlocked, true);
    assert.ok(store.profile(id).ownedDecks.includes(a.id));
    assert.ok(store.profile(id).ownedDecks.includes(b.id));
    assert.ok(store.profile(id).gems >= 0);
  } finally { store.close(); }
});

test('solo records merge by minimum attempts per difficulty across out-of-order devices and restart', () => {
  const dataDir = mkdtempSync(join(tmpdir(), 'sommomemory-solo-records-'));
  let store = new EconomyStore({ dataDir });
  try {
    const id = store.createProfile().profile.id;
    const imperfect = complete();
    imperfect.moves.unshift(0, 2);
    assert.equal(store.soloOperation(id, imperfect).profile.soloBestAttempts['6'], 7);
    store.soloOperation(id, complete());
    store.soloOperation(id, complete({ moves: imperfect.moves }));
    const eight = Array.from({ length: 16 }, (_, index) => index >> 1);
    store.soloOperation(id, complete({ pairs: 8, board: eight, moves: eight.map((_, index) => index) }));
    store.close(); store = new EconomyStore({ dataDir });
    assert.deepEqual(store.profile(id).soloBestAttempts, { '6': 6, '8': 8 });
    store.deleteProfile(id, { confirmDelete: true });
    assert.equal(store.db.prepare('SELECT COUNT(*) n FROM solo_records').get().n, 0);
    assert.equal(store.db.prepare('SELECT COUNT(*) n FROM solo_operations').get().n, 0);
  } finally { store.close(); rmSync(dataDir, { recursive: true, force: true }); }
});

test('real HTTP offline bootstrap and solo replay authenticate requests and return fresh snapshots', async () => {
  const server = startServer({ port: 0, dataDir: null });
  await once(server.http, 'listening');
  const base = `http://127.0.0.1:${server.http.address().port}/api/v1`;
  const send = async (path, data, token) => {
    const response = await fetch(`${base}${path}`, { method: 'POST', headers: {
      'Content-Type': 'application/json', ...(token ? { Authorization: `Bearer ${token}` } : {}),
    }, body: JSON.stringify(data) });
    return { status: response.status, body: await response.json() };
  };
  try {
    const bootstrapToken = randomBytes(32).toString('base64url');
    const guest = await send('/profiles', { bootstrapToken });
    assert.equal(guest.status, 201);
    const game = complete();
    assert.equal((await send('/solo/operations', game)).status, 401);
    const results = await Promise.all(Array.from({ length: 5 }, () => send('/solo/operations', game, bootstrapToken)));
    assert.ok(results.every(result => result.status === 200 && result.body.profile.gems === 120));
    assert.ok(results.every(result => result.body.operation.requestId === game.requestId));
    assert.deepEqual(results[0].body.profile.soloBestAttempts, { '6': 6 });
    const retried = await send('/profiles', { bootstrapToken });
    assert.equal(retried.body.profile.id, guest.body.profile.id);
    assert.equal(retried.body.profile.gems, 120);
    for (let index = 0; index < 12; index++) {
      const registrationRetry = await send('/profiles', { bootstrapToken });
      assert.equal(registrationRetry.status, 201);
      assert.equal(registrationRetry.body.profile.id, guest.body.profile.id);
    }
    // Large offline backlogs do not consume the ordinary 240-request profile
    // budget or block other actions by the same shared network address.
    for (let index = 0; index < 245; index++)
      assert.equal((await send('/solo/operations', complete(), bootstrapToken)).status, 200);
    const snapshot = await fetch(`${base}/profile`, { headers: { Authorization: `Bearer ${bootstrapToken}` } });
    assert.equal(snapshot.status, 200);
    assert.equal((await snapshot.json()).profile.gems, 5020);
  } finally { await server.close(); }
});
