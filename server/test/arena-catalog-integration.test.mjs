import test from 'node:test';
import assert from 'node:assert/strict';
import { ARENA_CATALOG } from '../src/arenas.mjs';
import { EconomyStore } from '../src/economy.mjs';
import { GameEngine } from '../src/game.mjs';

const capabilities = {
  supportedDecks: ARENA_CATALOG.decks.map(deck => deck.id),
  supportedFeatures: ['ranked-v1', 'ranked-attempts-v1'],
};

for (const arena of ARENA_CATALOG.arenas) {
  test(`${arena.name}: real catalog, opponent purchase, three rounds and permanent unlocks`, () => {
    assert.equal(ARENA_CATALOG.rankedEnabled, true);
    const store = new EconomyStore();
    let now = 1000;
    const engine = new GameEngine({
      now: () => now,
      mismatchMs: 1,
      getProfile: id => store.profile(id),
      ownsDeck: (id, deck) => store.ownsDeck(id, deck),
      onRankedSettlement: room => store.settleRanked(room),
    });
    try {
      const host = store.createProfile().profile;
      const guest = store.createProfile().profile;
      for (const profile of [host, guest]) {
        store.db.prepare('UPDATE profiles SET crowns=?,peak_crowns=?,gems=500 WHERE id=?')
          .run(arena.minCrowns, arena.minCrowns, profile.id);
      }
      const premium = ARENA_CATALOG.decks.find(deck => deck.arenaId === arena.id && deck.price > 0);
      const purchase = store.unlock(guest.id, { deckId: premium.id, requestId: `purchase-${arena.id}` });
      assert.equal(purchase.unlocked, true);
      assert.equal(store.ownsDeck(host.id, premium.id), false);
      const a = engine.create({
        name: 'Host', profileId: host.id, matchType: 'ranked', arenaId: arena.id, ...capabilities,
      });
      const b = engine.join({ name: 'Guest', profileId: guest.id, code: a.code, ...capabilities });
      const room = engine.room(a.code);
      assert.equal(room.rankedPool.length, 4);
      assert.ok(room.rankedPool.includes(premium.id));
      assert.equal(new Set(room.roundDecks).size, 3);
      assert.ok(room.roundDecks.every(id => ARENA_CATALOG.decks.find(deck => deck.id === id).arenaId === arena.id));

      for (let round = 1; round <= 3; round++) {
        assert.equal(room.roundIndex, round);
        assert.ok(engine.state(a.code).cards.every(value => value === null));
        // One additional failed attempt for the guest on the same board.
        const second = room.board.findIndex(value => value !== room.board[0]);
        engine.flip(a.code, b.playerId, 0);
        engine.flip(a.code, b.playerId, second);
        now++; engine.tick();
        for (const playerId of [a.playerId, b.playerId]) {
          for (const value of new Set(room.board)) {
            const pair = room.board.flatMap((card, index) => card === value ? [index] : []);
            engine.flip(a.code, playerId, pair[0]);
            engine.flip(a.code, playerId, pair[1]);
          }
        }
        if (round < 3) {
          assert.equal(room.phase, 'roundFinished');
          assert.equal(store.profile(host.id).crowns, arena.minCrowns);
          assert.equal(store.profile(host.id).gems, 500);
          engine.nextRound(a.code, a.playerId);
          engine.nextRound(a.code, b.playerId);
        }
      }

      assert.equal(room.phase, 'finished');
      assert.equal(room.winnerId, a.playerId);
      assert.deepEqual(engine.state(a.code, a.playerId).totalAttempts, { [a.playerId]: 36, [b.playerId]: 39 });
      assert.equal(store.profile(host.id).crowns, arena.minCrowns + 20);
      assert.equal(store.profile(guest.id).crowns, Math.max(0, arena.minCrowns - 20));
      assert.equal(store.profile(guest.id).peakCrowns, arena.minCrowns);
      assert.ok(store.profile(guest.id).unlockedArenaIds.includes(arena.id));
      assert.equal(store.ownsDeck(guest.id, premium.id), true);
      assert.equal(store.profile(host.id).gems, 520);
      assert.equal(store.profile(guest.id).gems, 520 - premium.price);
      store.settleRanked(room);
      assert.equal(store.profile(host.id).crowns, arena.minCrowns + 20);
      assert.equal(store.profile(host.id).gems, 520);
    } finally {
      store.close();
    }
  });
}
