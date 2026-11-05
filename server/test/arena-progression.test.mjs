import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { DatabaseSync } from 'node:sqlite';
import { EconomyStore } from '../src/economy.mjs';

const progression = profile => ({ crowns: profile.crowns, peakCrowns: profile.peakCrowns,
  currentArenaId: profile.currentArenaId, unlockedArenaIds: profile.unlockedArenaIds });

test('pre-arena profiles migrate without changing wallet, purchases, credentials or sessions', () => {
  const dataDir = mkdtempSync(join(tmpdir(), 'memory-arena-migration-'));
  let store;
  try {
    store = new EconomyStore({ dataDir });
    const { profile, token } = store.createProfile();
    const { recoveryCode } = store.recovery(profile.id, { displayName: 'Alice' });
    // Set up a representative wallet and purchased collection before migration.
    store.db.prepare('UPDATE profiles SET gems=350 WHERE id=?').run(profile.id);
    store.db.prepare('INSERT INTO owned_decks(profile_id,deck_id) VALUES(?,?)').run(profile.id, 'food');
    store.db.prepare('UPDATE profiles SET gems=150 WHERE id=?').run(profile.id);
    store.db.prepare('INSERT INTO auth_identities(profile_id,provider,issuer,subject,created_at,credential,client_id) VALUES(?,?,?,?,?,?,?)')
      .run(profile.id, 'apple', 'issuer', 'subject', 1, 'credential', 'client');
    const before = store.profile(profile.id);
    const ledger = store.ledger(profile.id);
    store.close(); store = undefined;

    const legacy = new DatabaseSync(join(dataDir, 'economy.sqlite'));
    legacy.exec('ALTER TABLE profiles DROP COLUMN crowns; ALTER TABLE profiles DROP COLUMN peak_crowns; ALTER TABLE profiles DROP COLUMN legacy_decks');
    legacy.close();

    store = new EconomyStore({ dataDir });
    const migrated = store.profile(store.authenticate(token));
    assert.deepEqual(progression(migrated), { crowns: 0, peakCrowns: 0,
      currentArenaId: 'wild_valley', unlockedArenaIds: ['wild_valley'] });
    for (const field of ['id', 'displayName', 'gems', 'revision', 'recoveryVersion', 'linkedProviders'])
      assert.deepEqual(migrated[field], before[field]);
    assert.ok(['cosmos', 'ocean', 'food'].every(deck => migrated.ownedDecks.includes(deck)));
    assert.deepEqual(migrated.legacyDecks, ['cosmos', 'ocean']);
    assert.deepEqual(store.ledger(profile.id), ledger);
    assert.equal(store.db.prepare('SELECT credential FROM auth_identities WHERE profile_id=?').get(profile.id).credential, 'credential');
    const restored = store.restore({ recoveryCode, confirmReplace: true });
    assert.equal(store.authenticate(restored.token), profile.id);
    assert.deepEqual(progression(restored.profile), progression(migrated));
    assert.equal(restored.profile.gems, 150);
    assert.ok(restored.profile.ownedDecks.includes('food'));

    // Only the test writes simulated future ranked results; no crown mutation API exists.
    store.db.prepare('UPDATE profiles SET crowns=80,peak_crowns=100 WHERE id=?').run(profile.id);
    store.close(); store = undefined;
    store = new EconomyStore({ dataDir });
    const expected = { crowns: 80, peakCrowns: 100, currentArenaId: 'wild_valley',
      unlockedArenaIds: ['wild_valley', 'coral_bay'] };
    assert.deepEqual(progression(store.profile(store.authenticate(token))), expected);
    assert.deepEqual(progression(store.restore({ recoveryCode, confirmReplace: true }).profile), expected);
    assert.equal(store.profile(profile.id).gems, 150);
    assert.deepEqual(store.ledger(profile.id), ledger);
  } finally { store?.close(); rmSync(dataDir, { recursive: true, force: true }); }
});

test('new profiles expose zero crowns without changing existing free collections', () => {
  const store = new EconomyStore();
  try {
    const { profile } = store.createProfile();
    assert.deepEqual(progression(profile), { crowns: 0, peakCrowns: 0,
      currentArenaId: 'wild_valley', unlockedArenaIds: ['wild_valley'] });
    assert.equal(profile.gems, 100);
    assert.deepEqual(profile.legacyDecks, []);
    assert.ok(!profile.ownedDecks.includes('cosmos') && !profile.ownedDecks.includes('ocean'));
  } finally { store.close(); }
});
