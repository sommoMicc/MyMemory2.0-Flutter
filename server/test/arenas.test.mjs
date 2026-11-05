import test from 'node:test';
import assert from 'node:assert/strict';
import {
  ARENA_CATALOG,
  arenaForCrowns,
  unlockedArenas,
  applyCrownResult,
  validateArenaCatalog,
  buildDeckPool,
  drawRankedDecks,
} from '../src/arenas.mjs';

const arenaIds = arenas => arenas.map(arena => arena.id);

test('catalog is validated and crown thresholds are inclusive', () => {
  assert.equal(typeof ARENA_CATALOG.rankedEnabled, 'boolean');
  assert.deepEqual([0, 99, 100, 299, 300, 599, 600, 900].map(n => arenaForCrowns(n).id), [
    'wild_valley', 'wild_valley', 'coral_bay', 'coral_bay', 'grand_city', 'grand_city', 'space_frontier', 'space_frontier',
  ]);
  assert.deepEqual(arenaIds(unlockedArenas(99)), ['wild_valley']);
  assert.deepEqual(arenaIds(unlockedArenas(300)), ['wild_valley', 'coral_bay', 'grand_city']);
  assert.throws(() => arenaForCrowns(-1), RangeError);
  assert.throws(() => arenaForCrowns(1.5), RangeError);
  assert.throws(() => unlockedArenas(Number.MAX_SAFE_INTEGER + 1), RangeError);
  assert.ok(Object.isFrozen(ARENA_CATALOG) && Object.isFrozen(ARENA_CATALOG.arenas[0]));
  const future = structuredClone(ARENA_CATALOG);
  future.rankedEnabled = true;
  assert.equal(validateArenaCatalog(future), future);
  for (const mutate of [
    c => { c.schemaVersion = 2; },
    c => { c.rankedEnabled = 'false'; },
    c => { c.rules.rankedRounds = 0; },
    c => { delete c.rules.friendlyRounds; },
    c => { c.decks = c.decks.filter(deck => deck.id !== 'paola'); },
    c => { c.decks.find(deck => deck.id === 'paola').arenaId = 'wild_valley'; },
    c => { c.decks.splice(c.decks.findIndex(deck => deck.id === 'farm'), 1); },
  ]) {
    const invalid = structuredClone(ARENA_CATALOG);
    mutate(invalid);
    assert.throws(() => validateArenaCatalog(invalid), TypeError);
  }
});

test('result applies win, loss, draw, historical unlocks, demotion and floor', () => {
  assert.deepEqual(applyCrownResult(100, 100, 'loss'), {
    crowns: 80, peakCrowns: 100, currentArenaId: 'wild_valley', unlockedArenaIds: ['wild_valley', 'coral_bay'],
  });
  assert.equal(applyCrownResult(0, 0, 'loss').crowns, 0);
  assert.equal(applyCrownResult(99, 100, 'win').crowns, 119);
  assert.equal(applyCrownResult(100, 100, 'draw').crowns, 100);
  assert.throws(() => applyCrownResult(101, 100, 'win'), RangeError);
  assert.throws(() => applyCrownResult(0, 0, 'quit'), TypeError);
  assert.throws(() => applyCrownResult(Number.MAX_SAFE_INTEGER, Number.MAX_SAFE_INTEGER, 'win'), RangeError);
});

test('pool unions both owners, deduplicates, and excludes other arenas, Paola and unready content', () => {
  const catalog = structuredClone(ARENA_CATALOG);
  for (const id of ['farm', 'flora', 'insects']) catalog.decks.find(deck => deck.id === id).contentReady = true;
  const before = JSON.stringify(catalog);
  assert.deepEqual(buildDeckPool('wild_valley', ['farm', 'farm'], ['insects', 'insects'], catalog), [
    'garden', 'farm', 'flora', 'insects',
  ]);
  assert.deepEqual(buildDeckPool('wild_valley', [], [], catalog), ['garden', 'farm', 'flora']);
  assert.deepEqual(buildDeckPool('wild_valley', [], ['insects'], catalog).includes('insects'), true);
  const pendingAssets = structuredClone(catalog);
  pendingAssets.decks.find(deck => deck.id === 'farm').contentReady = false;
  assert.ok(!buildDeckPool('wild_valley', ['farm'], [], pendingAssets).includes('farm'));
  assert.equal(JSON.stringify(catalog), before);
  const incomplete = structuredClone(catalog);
  incomplete.decks.find(deck => deck.id === 'farm').contentReady = false;
  incomplete.decks.find(deck => deck.id === 'flora').contentReady = false;
  assert.deepEqual(buildDeckPool('wild_valley', [], [], incomplete), ['garden']);
  assert.ok(!buildDeckPool('wild_valley', ['food', 'paola'], [], catalog).includes('food'));
  assert.ok(!buildDeckPool('wild_valley', ['paola'], [], catalog).includes('paola'));
  assert.throws(() => buildDeckPool('missing', [], []), RangeError);
});

test('draw returns three distinct decks and fails when the playable pool is too small', () => {
  const catalog = structuredClone(ARENA_CATALOG);
  for (const id of ['farm', 'flora']) catalog.decks.find(deck => deck.id === id).contentReady = true;
  let turn = 0;
  const drawn = drawRankedDecks('wild_valley', [], [], catalog, max => turn++ % max);
  assert.equal(drawn.length, 3);
  assert.equal(new Set(drawn).size, 3);
  assert.ok(drawn.every(id => ['garden', 'farm', 'flora'].includes(id)));
  const incomplete = structuredClone(catalog);
  incomplete.decks.find(deck => deck.id === 'farm').contentReady = false;
  incomplete.decks.find(deck => deck.id === 'flora').contentReady = false;
  assert.throws(() => drawRankedDecks('wild_valley', [], [], incomplete), /servono 3 deck giocabili/);
  assert.throws(() => drawRankedDecks('wild_valley', [], [], catalog, max => max), RangeError);
});
