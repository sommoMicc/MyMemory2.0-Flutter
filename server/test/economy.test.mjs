import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, readFileSync, readdirSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { DatabaseSync } from 'node:sqlite';
import { EconomyStore } from '../src/economy.mjs';
import { GameEngine } from '../src/game.mjs';

const solution = board => [...new Set(board)].flatMap(value => board.flatMap((card, index) => card === value ? [index] : []));
let next = 0;
const key = () => `request_${++next}`;
const ticket = (store, id, options = {}) => store.issueTicket(id, { mode: 'solo', pairs: 6, theme: 'garden', requestId: key(), ...options }).ticket;
function complete(store, id, options) {
  const game = ticket(store, id, options);
  return store.claim(id, { ticketId: game.id, moves: solution(game.board), requestId: key() });
}

test('Paola is free for existing profiles and anonymous 18-pair online rooms without a wallet charge', () => {
  const dataDir = mkdtempSync(join(tmpdir(), 'sommomemory-paola-'));
  let store;
  try {
    store = new EconomyStore({ dataDir });
    const existing = store.createProfile();
    assert.equal(store.db.prepare('SELECT COUNT(*) AS count FROM owned_decks WHERE profile_id=?').get(existing.profile.id).count, 0);
    store.close(); store = undefined;
    store = new EconomyStore({ dataDir });
    const profile = store.profile(store.authenticate(existing.token));
    assert.ok(profile.ownedDecks.includes('paola'));
    assert.equal(profile.gems, 100);
    assert.equal(store.unlock(profile.id, { deckId: 'paola', requestId: key() }).alreadyOwned, true);
    assert.equal(store.profile(profile.id).gems, 100);
    assert.equal(store.ledger(profile.id).entries.length, 1);
    assert.equal(ticket(store, profile.id, { theme: 'paola', pairs: 18 }).board.length, 36);
    const engine = new GameEngine();
    const host = engine.create({ name: 'Paola', pairs: 18, theme: 'paola', supportedDecks: ['paola'] });
    engine.join({ code: host.code, name: 'Ospite', supportedDecks: ['paola'] });
    const room = engine.room(host.code);
    assert.equal(engine.state(host.code).theme, 'paola');
    assert.equal(room.board.length, 36);
    assert.deepEqual([...new Set(room.board)].sort((a, b) => Number(a) - Number(b)), Array.from({ length: 18 }, (_, i) => String(i)));
    assert.ok(engine.state(host.code).cards.every(card => card === null));
  } finally { store?.close(); rmSync(dataDir, { recursive: true, force: true }); }
});

test('welcome, recovery/rotation, device logout and deletion never create or merge balances', () => {
  const store = new EconomyStore();
  try {
    const guest = store.createProfile(), another = store.createProfile();
    assert.equal(guest.profile.gems, 100);
    assert.equal(guest.profile.recoveryVersion, 0);
    assert.deepEqual(guest.profile.ownedDecks, ['garden', 'cosmos', 'ocean', 'paola']);
    const activated = store.recovery(guest.profile.id, { displayName: ' Alice\n' });
    assert.equal(activated.profile.displayName, 'Alice');
    assert.equal(activated.profile.recoveryVersion, 1);
    assert.throws(() => store.recovery(guest.profile.id), { code: 'RECOVERY_ALREADY_ACTIVE' });
    assert.equal(store.recoveryProfile(activated.recoveryCode.toLowerCase()).id, guest.profile.id);
    assert.throws(() => store.restore({ recoveryCode: activated.recoveryCode }), { code: 'CONFIRM_RESTORE' });
    const restored = store.restore({ recoveryCode: activated.recoveryCode, confirmReplace: true });
    assert.equal(restored.profile.gems, 100);
    assert.notEqual(restored.token, guest.token);
    assert.equal(store.authenticate(restored.token), store.authenticate(guest.token));
    assert.equal(store.ledger(guest.profile.id).entries.filter(e => e.source === 'welcome').length, 1);
    assert.equal(store.profile(another.profile.id).gems, 100);
    complete(store, guest.profile.id);
    assert.equal(store.profile(guest.profile.id).gems, 120);
    const rotated = store.recovery(guest.profile.id, {}, true);
    assert.equal(rotated.profile.recoveryVersion, 2);
    assert.equal(store.profile(guest.profile.id).recoveryVersion, 2);
    assert.equal(rotated.profile.id, guest.profile.id);
    assert.equal(rotated.profile.gems, 120);
    assert.equal(store.authenticate(guest.token), guest.profile.id);
    assert.equal(store.authenticate(restored.token), guest.profile.id);
    assert.throws(() => store.recoveryProfile(activated.recoveryCode), { code: 'INVALID_RECOVERY' });
    assert.equal(store.recoveryProfile(rotated.recoveryCode).gems, 120);
    store.logout(guest.token);
    assert.throws(() => store.authenticate(guest.token), { code: 'INVALID_TOKEN' });
    assert.equal(store.authenticate(restored.token), guest.profile.id);
    assert.throws(() => store.deleteProfile(guest.profile.id, {}), { code: 'CONFIRM_DELETE' });
    store.deleteProfile(guest.profile.id, { confirmDelete: true });
    assert.throws(() => store.authenticate(restored.token), { code: 'INVALID_TOKEN' });
    assert.throws(() => store.recoveryProfile(rotated.recoveryCode), { code: 'INVALID_RECOVERY' });
    assert.equal(store.db.prepare('SELECT COUNT(*) AS count FROM ledger WHERE profile_id=?').get(guest.profile.id).count, 0);
    assert.equal(store.profile(another.profile.id).gems, 100);
  } finally { store.close(); }
});

test('validated complete transcript pays once, rejects fake/malformed/incomplete moves and expires', () => {
  let now = 1000;
  const store = new EconomyStore({ now: () => now });
  try {
    const { profile } = store.createProfile();
    const game = ticket(store, profile.id);
    const moves = solution(game.board);
    for (const bad of [[], [0], [...moves, 0], [0, 0, ...moves], moves.map(String), [999, ...moves], moves.slice(0, -1)])
      assert.throws(() => store.claim(profile.id, { ticketId: game.id, moves: bad, requestId: key() }), { code: 'INVALID_TRANSCRIPT' });
    assert.equal(store.profile(profile.id).gems, 100);
    const requestId = key();
    assert.equal(store.claim(profile.id, { ticketId: game.id, moves, requestId }).reward.granted, true);
    assert.equal(store.claim(profile.id, { ticketId: game.id, moves, requestId }).profile.gems, 120);
    assert.equal(store.claim(profile.id, { ticketId: game.id, moves, requestId: key() }).reward.granted, false);
    assert.throws(() => store.claim(profile.id, { ticketId: game.id, moves: [], requestId }), { code: 'IDEMPOTENCY_CONFLICT' });
    const expiring = ticket(store, profile.id);
    now += 30 * 86_400_000;
    assert.throws(() => store.claim(profile.id, { ticketId: expiring.id, moves: solution(expiring.board), requestId: key() }), { code: 'TICKET_EXPIRED' });
  } finally { store.close(); }
});

test('permanent unlocks are atomic/idempotent and never overdraw or double charge', () => {
  const store = new EconomyStore();
  try {
    const { profile } = store.createProfile();
    assert.throws(() => store.unlock(profile.id, { deckId: 'food', requestId: key() }), { code: 'INSUFFICIENT_GEMS' });
    for (let i = 0; i < 5; i++) complete(store, profile.id);
    const requestId = key();
    const unlocked = store.unlock(profile.id, { deckId: 'food', requestId });
    assert.equal(unlocked.profile.gems, 0);
    assert.equal(unlocked.unlocked, true);
    assert.equal(store.unlock(profile.id, { deckId: 'food', requestId }).profile.gems, 0);
    assert.equal(store.unlock(profile.id, { deckId: 'food', requestId: key() }).alreadyOwned, true);
    assert.throws(() => store.unlock(profile.id, { deckId: 'sports', requestId }), { code: 'IDEMPOTENCY_CONFLICT' });
    assert.throws(() => store.unlock(profile.id, { deckId: 'sports', requestId: key() }), { code: 'INSUFFICIENT_GEMS' });
    assert.equal(store.ledger(profile.id).entries.filter(e => e.source === 'unlock:food').length, 1);
    assert.equal(ticket(store, profile.id, { theme: 'food' }).theme, 'food');
    assert.throws(() => ticket(store, profile.id, { theme: 'travel' }), { code: 'DECK_LOCKED' });
  } finally { store.close(); }
});

test('Bluetooth guest capability permits one different profile without deck ownership, no replay or recycled slot', () => {
  const store = new EconomyStore();
  try {
    const host = store.createProfile().profile, guest = store.createProfile().profile, intruder = store.createProfile().profile;
    for (let i = 0; i < 5; i++) complete(store, host.id);
    store.unlock(host.id, { deckId: 'food', requestId: key() });
    const requestId = key();
    const game = ticket(store, host.id, { mode: 'bluetooth', theme: 'food', requestId });
    const retry = ticket(store, host.id, { mode: 'bluetooth', theme: 'food', requestId });
    assert.deepEqual(retry, game);
    assert.equal(store.ownsDeck(guest.id, 'food'), false);
    const claim = { ticketId: game.id, moves: solution(game.board), guestClaimToken: game.guestClaimToken };
    assert.throws(() => store.claim(guest.id, { ...claim, guestClaimToken: 'x'.repeat(43), requestId: key() }), { code: 'INVALID_GUEST_CLAIM' });
    assert.equal(store.claim(guest.id, { ...claim, requestId: key() }).profile.gems, 120);
    assert.equal(store.claim(host.id, { ...claim, requestId: key() }).profile.gems, 20);
    assert.equal(store.claim(host.id, { ...claim, requestId: key() }).reward.granted, false);
    assert.throws(() => store.claim(intruder.id, { ...claim, requestId: key() }), { code: 'GUEST_ALREADY_CLAIMED' });
    store.deleteProfile(guest.id, { confirmDelete: true });
    assert.throws(() => store.claim(intruder.id, { ...claim, requestId: key() }), { code: 'GUEST_ALREADY_CLAIMED' });
  } finally { store.close(); }
});

test('batch preparation rolls back completely and rate/capacity limits bound issuance', () => {
  const store = new EconomyStore();
  try {
    const { profile } = store.createProfile();
    const good = { mode: 'solo', pairs: 6, theme: 'garden', requestId: key() };
    assert.throws(() => store.issueBatch(profile.id, { requests: [good, { ...good, theme: 'food', requestId: key() }] }), { code: 'DECK_LOCKED' });
    assert.equal(store.db.prepare('SELECT COUNT(*) AS count FROM tickets').get().count, 0);
    assert.throws(() => store.issueBatch(profile.id, { requests: [null] }), { code: 'INVALID_GAME' });
    assert.equal(store.issueBatch(profile.id, { requests: [good] }).tickets.length, 1);
    for (let i = 1; i < 100; i++) ticket(store, profile.id);
    assert.throws(() => ticket(store, profile.id), { code: 'TICKET_LIMIT' });
    assert.equal(store.db.prepare('SELECT COUNT(*) AS count FROM tickets').get().count, 100);
  } finally { store.close(); }
});

test('persistent restart retains wallet, tickets and hashed credentials without double welcome/reward', () => {
  const dataDir = mkdtempSync(join(tmpdir(), 'sommomemory-economy-'));
  let store;
  try {
    store = new EconomyStore({ dataDir });
    const { profile, token } = store.createProfile();
    const { recoveryCode } = store.recovery(profile.id);
    const requestId = key();
    const game = ticket(store, profile.id, { mode: 'bluetooth', requestId });
    store.claim(profile.id, { ticketId: game.id, moves: solution(game.board), requestId: key() });
    store.close(); store = undefined;
    const legacy = new DatabaseSync(join(dataDir, 'economy.sqlite'));
    legacy.exec('ALTER TABLE profiles DROP COLUMN recovery_version');
    legacy.close();
    const files = readdirSync(dataDir).filter(name => name.startsWith('economy.sqlite'));
    for (const name of files) {
      const data = readFileSync(join(dataDir, name)).toString();
      for (const secret of [token, recoveryCode, game.guestClaimToken]) assert.equal(data.includes(secret), false);
    }
    store = new EconomyStore({ dataDir });
    assert.equal(store.authenticate(token), profile.id);
    assert.equal(store.recoveryProfile(recoveryCode).gems, 120);
    assert.equal(store.recoveryProfile(recoveryCode).recoveryVersion, 1);
    assert.deepEqual(ticket(store, profile.id, { mode: 'bluetooth', requestId }), game);
    assert.equal(store.claim(profile.id, { ticketId: game.id, moves: solution(game.board), requestId: key() }).profile.gems, 120);
    assert.equal(store.ledger(profile.id).entries.filter(e => e.source === 'welcome').length, 1);
  } finally { store?.close(); rmSync(dataDir, { recursive: true, force: true }); }
});

test('online authority rewards actual completion once per profile/round, never forfeits, with public receipts', () => {
  const store = new EconomyStore();
  try {
    const a = store.createProfile().profile, b = store.createProfile().profile;
    const engine = new GameEngine({ ownsDeck: (id, theme) => store.ownsDeck(id, theme), onCompleted: room => store.rewardOnline(room) });
    assert.throws(() => engine.create({ name: 'A', theme: 'food', profileId: a.id, supportedDecks: ['food'] }), { code: 'DECK_LOCKED' });
    const host = engine.create({ name: 'A', pairs: 6, profileId: a.id });
    const guest = engine.join({ code: host.code, name: 'B', profileId: b.id });
    const room = engine.room(host.code), firstRound = room.roundId;
    for (const index of solution(room.board)) engine.flip(host.code, host.playerId, index);
    assert.deepEqual(engine.state(host.code).rewards, { [host.playerId]: { gems: 20, granted: true }, [guest.playerId]: { gems: 20, granted: true } });
    assert.equal(store.profile(a.id).gems, 120);
    engine.change(room);
    assert.equal(store.profile(a.id).gems, 120);
    assert.equal(store.profile(b.id).gems, 120);
    engine.rematch(host.code, host.playerId); engine.rematch(host.code, guest.playerId);
    assert.notEqual(room.roundId, firstRound);
    assert.deepEqual(engine.state(host.code).rewards, {});
    engine.leave(guest.code, guest.playerId);
    assert.equal(store.profile(a.id).gems, 120);
    const same = engine.create({ name: 'A', pairs: 6, profileId: a.id });
    engine.join({ code: same.code, name: 'A2', profileId: a.id });
    const sameRoom = engine.room(same.code);
    for (const index of solution(sameRoom.board)) engine.flip(same.code, same.playerId, index);
    assert.equal(store.profile(a.id).gems, 140);
    assert.equal(Object.keys(engine.state(same.code).rewards).length, 1);
    assert.equal(JSON.stringify(engine.state(same.code)).includes(a.id), false);
  } finally { store.close(); }
});

test('a completed persisted online round recovers payment even after room TTL, without a second payment', () => {
  const dataDir = mkdtempSync(join(tmpdir(), 'sommomemory-reward-recovery-'));
  const store = new EconomyStore({ dataDir });
  try {
    let now = 1000;
    const { profile } = store.createProfile();
    // Simulate a crash after the room commit and before its ledger callback.
    const original = new GameEngine({ dataDir, now: () => now });
    const host = original.create({ name: 'A', pairs: 6, profileId: profile.id });
    original.join({ code: host.code, name: 'B' });
    const room = original.room(host.code);
    for (const index of solution(room.board)) original.flip(host.code, host.playerId, index);
    assert.equal(store.profile(profile.id).gems, 100);
    now += 2 * 86_400_000;
    new GameEngine({ dataDir, now: () => now, onCompleted: value => store.rewardOnline(value) });
    assert.equal(store.profile(profile.id).gems, 120);
    new GameEngine({ dataDir, now: () => now, onCompleted: value => store.rewardOnline(value) });
    assert.equal(store.profile(profile.id).gems, 120);
  } finally { store.close(); rmSync(dataDir, { recursive: true, force: true }); }
});

test('temporary wallet failure still publishes finished board and retries the same reward without losing it on leave', () => {
  const store = new EconomyStore();
  try {
    let now = 1000, unavailable = true;
    const { profile } = store.createProfile();
    const engine = new GameEngine({ now: () => now, onCompleted: room => {
      if (unavailable) throw new Error('temporary disk error');
      return store.rewardOnline(room);
    } });
    const host = engine.create({ name: 'A', pairs: 6, profileId: profile.id });
    const guest = engine.join({ code: host.code, name: 'B' });
    const room = engine.room(host.code), states = [];
    engine.on('change', code => states.push(engine.state(code)));
    for (const index of solution(room.board)) engine.flip(host.code, host.playerId, index);
    assert.equal(states.at(-1).phase, 'finished');
    assert.deepEqual(states.at(-1).rewards, {});
    assert.throws(() => engine.rematch(host.code, host.playerId), { code: 'REWARD_PENDING' });
    engine.leave(host.code, host.playerId); engine.leave(guest.code, guest.playerId);
    assert.equal(engine.rooms.has(host.code), true);
    unavailable = false; now += 5000; engine.tick();
    assert.equal(store.profile(profile.id).gems, 120);
    assert.deepEqual(states.at(-1).rewards, { [host.playerId]: { gems: 20, granted: true } });
    now += 5000; engine.tick();
    assert.equal(store.profile(profile.id).gems, 120);
  } finally { store.close(); }
});

test('restart isolates a failed reward hook, restores completed and active rooms, then retries once', () => {
  const dataDir = mkdtempSync(join(tmpdir(), 'sommomemory-restore-isolation-'));
  const store = new EconomyStore({ dataDir });
  try {
    let now = 1000, attempts = 0;
    const { profile } = store.createProfile();
    const original = new GameEngine({ dataDir, now: () => now });
    const finished = original.create({ name: 'A', pairs: 6, profileId: profile.id });
    original.join({ code: finished.code, name: 'B' });
    for (const index of solution(original.room(finished.code).board)) original.flip(finished.code, finished.playerId, index);
    const active = original.create({ name: 'C', pairs: 6 });
    const other = original.join({ code: active.code, name: 'D' });
    original.flip(active.code, active.playerId, 0);
    const before = original.state(active.code);
    const restored = new GameEngine({ dataDir, now: () => now, onCompleted: room => {
      if (++attempts === 1) throw new Error('temporary ledger outage');
      return store.rewardOnline(room);
    } });
    assert.equal(restored.rooms.size, 2);
    assert.equal(restored.state(finished.code).phase, 'finished');
    assert.equal(restored.pendingRewards.has(finished.code), true);
    assert.deepEqual(restored.state(active.code).cards, before.cards);
    assert.equal(JSON.parse(readFileSync(join(dataDir, 'rooms.json'), 'utf8')).rooms.length, 2);
    restored.resume(active); restored.resume(other);
    assert.equal(restored.state(active.code).players.every(p => p.connected), true);
    assert.equal(store.profile(profile.id).gems, 100);
    now += 5000; restored.tick();
    assert.equal(store.profile(profile.id).gems, 120);
    assert.equal(restored.pendingRewards.size, 0);
    now += 5000; restored.tick();
    assert.equal(store.profile(profile.id).gems, 120);
    assert.equal(store.ledger(profile.id).entries.filter(e => e.source === `game:${original.room(finished.code).roundId}`).length, 1);
  } finally { store.close(); rmSync(dataDir, { recursive: true, force: true }); }
});
