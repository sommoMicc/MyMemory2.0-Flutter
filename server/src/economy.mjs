import { DatabaseSync } from 'node:sqlite';
import { adminSchema, recordActivity } from './admin-schema.mjs';
import { createHash, createHmac, randomBytes, randomInt } from 'node:crypto';
import { chmodSync, existsSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';
import { ARENA_CATALOG, arenaForCrowns, unlockedArenas, applyCrownResult } from './arenas.mjs';

export const DECKS = Object.freeze([
  { id: 'garden', price: 0, free: true }, { id: 'cosmos', price: 0, free: true },
  { id: 'ocean', price: 0, free: true }, { id: 'paola', price: 0, free: true },
  { id: 'food', price: 200, free: false },
  { id: 'sports', price: 300, free: false }, { id: 'travel', price: 400, free: false },
]);
export const RULES = Object.freeze({ welcomeGems: 100, completionGems: 20,
  ticketLifetimeDays: 30, maxTicketsPerDay: 100, maxTranscriptMoves: 4000 });
export const PROFILE_AVATARS = Object.freeze(['fox', 'cat', 'dog', 'panda', 'owl', 'rocket', 'star', 'flower']);
export const PROFILE_ACCENTS = Object.freeze(['forest', 'ocean', 'cosmos', 'sunset', 'rose']);
const DAY = 86_400_000;
const digest = value => createHash('sha256').update(value).digest('hex');
const opaque = () => randomBytes(32).toString('base64url');
const json = value => JSON.stringify(value);
const freeDecks = DECKS.filter(d => d.free).map(d => d.id);
export class EconomyError extends Error {
  constructor(code, message, status = 400) { super(message); this.code = code; this.status = status; }
}
const fail = (code, message, status) => { throw new EconomyError(code, message, status); };
const requestKey = input => {
  if (typeof input !== 'string' || !/^[A-Za-z0-9_-]{8,80}$/.test(input))
    fail('INVALID_REQUEST_ID', 'Identificativo della richiesta non valido.');
  return input;
};
const cleanName = value => {
  if (typeof value !== 'string') fail('INVALID_NAME', 'Nome non valido.');
  return [...value.trim().replace(/[\p{C}]/gu, '')].slice(0, 24).join('');
};
const recoveryHash = input => {
  if (typeof input !== 'string' || input.length > 100) fail('INVALID_RECOVERY', 'Codice di recupero non valido.', 401);
  const normalized = input.toUpperCase().replace(/[\s-]/g, '');
  if (!/^SMM[A-HJ-NP-Z2-9]{32}$/.test(normalized)) fail('INVALID_RECOVERY', 'Codice di recupero non valido.', 401);
  return digest(normalized);
};

// Single-process synchronous SQLite transactions serialize every wallet mutation.
// WAL + FULL synchronization also preserve committed ledger entries after restart.
export class EconomyStore {
  constructor({ dataDir, now = Date.now, maxProfiles = 200_000, catalog = ARENA_CATALOG } = {}) {
    this.catalog = catalog;
    this.now = now;
    this.maxProfiles = maxProfiles;
    let database = ':memory:';
    if (dataDir) {
      mkdirSync(dataDir, { recursive: true, mode: 0o700 });
      database = join(dataDir, 'economy.sqlite');
      const keyPath = join(dataDir, 'economy-capability.key');
      if (!existsSync(keyPath)) {
        if (existsSync(database)) throw new Error('Economy capability key is missing; restore the matching private key backup.');
        writeFileSync(keyPath, randomBytes(32), { mode: 0o600, flag: 'wx' });
      }
      chmodSync(keyPath, 0o600);
      this.capabilityKey = readFileSync(keyPath);
      if (this.capabilityKey.length !== 32) throw new Error('Invalid economy capability key');
    } else this.capabilityKey = randomBytes(32);
    this.db = new DatabaseSync(database);
    if (dataDir) chmodSync(database, 0o600);
    this.db.exec(`PRAGMA foreign_keys=ON; PRAGMA journal_mode=WAL; PRAGMA synchronous=FULL;
      PRAGMA busy_timeout=5000;
      CREATE TABLE IF NOT EXISTS profiles (
        id TEXT PRIMARY KEY, display_name TEXT NOT NULL DEFAULT '', gems INTEGER NOT NULL CHECK(gems>=0),
        activated INTEGER NOT NULL DEFAULT 0, recovery_hash TEXT UNIQUE, recovery_version INTEGER NOT NULL DEFAULT 0,
        revision INTEGER NOT NULL DEFAULT 1,
        created_at INTEGER NOT NULL
      );
      CREATE TABLE IF NOT EXISTS tokens (
        hash TEXT PRIMARY KEY, profile_id TEXT NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
        created_at INTEGER NOT NULL
      );
      CREATE TABLE IF NOT EXISTS auth_identities (
        profile_id TEXT NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
        provider TEXT NOT NULL, issuer TEXT NOT NULL, subject TEXT NOT NULL,
        created_at INTEGER NOT NULL, credential TEXT, client_id TEXT,
        checked_at INTEGER NOT NULL DEFAULT 0,
        grant_issued_at INTEGER NOT NULL DEFAULT 0, revoked_at INTEGER NOT NULL DEFAULT 0,
        PRIMARY KEY(provider,issuer,subject), UNIQUE(profile_id,provider)
      );
      CREATE INDEX IF NOT EXISTS tokens_profile ON tokens(profile_id);
      CREATE TABLE IF NOT EXISTS deleted_tokens (hash TEXT PRIMARY KEY, expires_at INTEGER NOT NULL);
      CREATE TABLE IF NOT EXISTS owned_decks (
        profile_id TEXT NOT NULL REFERENCES profiles(id) ON DELETE CASCADE, deck_id TEXT NOT NULL,
        PRIMARY KEY(profile_id,deck_id)
      );
      CREATE TABLE IF NOT EXISTS ledger (
        id INTEGER PRIMARY KEY, profile_id TEXT NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
        source TEXT NOT NULL, delta INTEGER NOT NULL, created_at INTEGER NOT NULL,
        UNIQUE(profile_id,source)
      );
      CREATE TABLE IF NOT EXISTS requests (
        profile_id TEXT NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
        kind TEXT NOT NULL, request_id TEXT NOT NULL, payload_hash TEXT NOT NULL, result TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        PRIMARY KEY(profile_id,kind,request_id)
      );
      CREATE TABLE IF NOT EXISTS tickets (
        id TEXT PRIMARY KEY, owner_id TEXT NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
        guest_id TEXT REFERENCES profiles(id) ON DELETE SET NULL, guest_hash TEXT,
        mode TEXT NOT NULL, pairs INTEGER NOT NULL, theme TEXT NOT NULL, seed TEXT NOT NULL,
        board TEXT NOT NULL, created_at INTEGER NOT NULL, expires_at INTEGER NOT NULL,
        guest_claimed INTEGER NOT NULL DEFAULT 0
      );
      CREATE INDEX IF NOT EXISTS tickets_owner ON tickets(owner_id,created_at);
      CREATE TABLE IF NOT EXISTS online_rounds (
        id TEXT PRIMARY KEY, participants TEXT NOT NULL, claimed INTEGER NOT NULL DEFAULT 0,
        receipt TEXT NOT NULL DEFAULT '{}'
      );
      CREATE TABLE IF NOT EXISTS offline_bootstraps (
        hash TEXT PRIMARY KEY, profile_id TEXT NOT NULL UNIQUE REFERENCES profiles(id) ON DELETE CASCADE,
        created_at INTEGER NOT NULL
      );
      CREATE TABLE IF NOT EXISTS solo_operations (
        profile_id TEXT NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
        request_id TEXT NOT NULL, payload_hash TEXT NOT NULL, result TEXT NOT NULL,
        created_at INTEGER NOT NULL, PRIMARY KEY(profile_id,request_id)
      );
      CREATE TABLE IF NOT EXISTS solo_games (
        game_id TEXT PRIMARY KEY, profile_id TEXT NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
        proof_hash TEXT NOT NULL, created_at INTEGER NOT NULL
      );
      CREATE TABLE IF NOT EXISTS solo_records (
        profile_id TEXT NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
        pairs INTEGER NOT NULL, best_attempts INTEGER NOT NULL,
        PRIMARY KEY(profile_id,pairs)
      );`);
    // Forward-only additions also accommodate an interrupted pre-release setup.
    if (!this.db.prepare('PRAGMA table_info(requests)').all().some(c => c.name === 'created_at'))
      this.db.exec('ALTER TABLE requests ADD COLUMN created_at INTEGER NOT NULL DEFAULT 0');
    if (!this.db.prepare('PRAGMA table_info(online_rounds)').all().some(c => c.name === 'receipt'))
      this.db.exec("ALTER TABLE online_rounds ADD COLUMN receipt TEXT NOT NULL DEFAULT '{}'");
    if (!this.db.prepare('PRAGMA table_info(profiles)').all().some(c => c.name === 'recovery_version')) {
      this.db.exec('ALTER TABLE profiles ADD COLUMN recovery_version INTEGER NOT NULL DEFAULT 0');
      this.db.exec('UPDATE profiles SET recovery_version=1 WHERE activated=1');
    }
    const columns = (table) => this.db.prepare(`PRAGMA table_info(${table})`).all().map(c => c.name);
    // Provider-signed Unix seconds; legacy rows stay unknown rather than guessing
    // authorization time from a local creation date or daily refresh backoff.
    for (const name of ['grant_issued_at', 'revoked_at'])
      if (!columns('auth_identities').includes(name)) this.db.exec(`ALTER TABLE auth_identities ADD COLUMN ${name} INTEGER NOT NULL DEFAULT 0`);
    if (!columns('profiles').includes('avatar_id')) this.db.exec("ALTER TABLE profiles ADD COLUMN avatar_id TEXT NOT NULL DEFAULT 'fox'");
    if (!columns('profiles').includes('accent_id')) this.db.exec("ALTER TABLE profiles ADD COLUMN accent_id TEXT NOT NULL DEFAULT 'forest'");
    if (!columns('profiles').includes('legacy_decks')) {
      this.transaction(() => {
        this.db.exec("ALTER TABLE profiles ADD COLUMN legacy_decks TEXT NOT NULL DEFAULT '[]'");
        this.db.exec(`UPDATE profiles SET legacy_decks='["cosmos","ocean"]'`);
      });
    }
    for (const name of ['crowns', 'peak_crowns'])
      if (!columns('profiles').includes(name)) this.db.exec(`ALTER TABLE profiles ADD COLUMN ${name} INTEGER NOT NULL DEFAULT 0`);
    this.db.exec(`CREATE TABLE IF NOT EXISTS ranked_matches (
      match_id TEXT PRIMARY KEY, receipt TEXT NOT NULL, created_at INTEGER NOT NULL
    )`);
    for (const [name, type] of [['id', 'TEXT'], ['device_name', "TEXT NOT NULL DEFAULT ''"],
      ['last_used_at', 'INTEGER NOT NULL DEFAULT 0'], ['verified_at', 'INTEGER NOT NULL DEFAULT 0'],
      ['expires_at', 'INTEGER NOT NULL DEFAULT 0']]) {
      if (!columns('tokens').includes(name)) this.db.exec(`ALTER TABLE tokens ADD COLUMN ${name} ${type}`);
    }
    for (const row of this.db.prepare('SELECT hash FROM tokens WHERE id IS NULL').all())
      this.db.prepare('UPDATE tokens SET id=? WHERE hash=?').run(randomBytes(18).toString('base64url'), row.hash);
    this.db.exec('CREATE UNIQUE INDEX IF NOT EXISTS tokens_id ON tokens(id)');
    adminSchema(this.db, this.now());
    this.cleanup();
  }
  close() { this.db.close(); }
  cleanup() {
    this.transaction(() => {
      this.db.prepare('DELETE FROM tickets WHERE expires_at<=?').run(this.now());
      this.db.prepare('DELETE FROM requests WHERE created_at<?').run(this.now() - 31 * DAY);
      this.db.prepare('DELETE FROM deleted_tokens WHERE expires_at<=?').run(this.now());
    });
  }
  transaction(action) {
    this.db.exec('BEGIN IMMEDIATE');
    try { const result = action(); this.db.exec('COMMIT'); return result; }
    catch (error) { this.db.exec('ROLLBACK'); throw error; }
  }
  profile(id) {
    const row = this.db.prepare('SELECT * FROM profiles WHERE id=?').get(id);
    if (!row) fail('INVALID_PROFILE', 'Profilo non disponibile. Ripristinalo con il codice di recupero.', 401);
    const owned = this.db.prepare('SELECT deck_id FROM owned_decks WHERE profile_id=? ORDER BY deck_id').all(id).map(d => d.deck_id);
    const linkedProviders = this.db.prepare('SELECT provider FROM auth_identities WHERE profile_id=? ORDER BY provider').all(id).map(item => item.provider);
    const legacyDecks = JSON.parse(row.legacy_decks);
    const arenaIds = unlockedArenas(row.peak_crowns).map(arena => arena.id);
    const availableFree = this.catalog.decks.filter(deck => deck.contentReady && deck.price === 0 &&
      (deck.id === 'paola' || arenaIds.includes(deck.arenaId))).map(deck => deck.id);
    const soloBestAttempts = Object.fromEntries(this.db.prepare('SELECT pairs,best_attempts FROM solo_records WHERE profile_id=? ORDER BY pairs')
      .all(id).map(record => [String(record.pairs), record.best_attempts]));
    return { id: row.id, displayName: row.display_name, activated: Boolean(row.activated),
      recoveryEnabled: Boolean(row.activated), avatarId: row.avatar_id, accentId: row.accent_id, linkedProviders,
      recoveryVersion: row.recovery_version, gems: row.gems, ownedDecks: [...new Set([...availableFree, ...legacyDecks, ...owned])], legacyDecks, revision: row.revision,
      crowns: row.crowns, peakCrowns: row.peak_crowns, currentArenaId: arenaForCrowns(row.crowns).id,
      unlockedArenaIds: unlockedArenas(row.peak_crowns).map(arena => arena.id), soloBestAttempts };
  }
  hasProfile(id) { return Boolean(this.db.prepare('SELECT 1 FROM profiles WHERE id=?').get(id)); }
  authenticate(token) {
    if (typeof token !== 'string' || !/^[A-Za-z0-9_-]{43}$/.test(token))
      fail('INVALID_TOKEN', 'Sessione del profilo non valida.', 401);
    const row = this.db.prepare('SELECT profile_id,expires_at FROM tokens WHERE hash=?').get(digest(token));
    if (!row) {
      if (this.db.prepare('SELECT 1 FROM deleted_tokens WHERE hash=? AND expires_at>?').get(digest(token), this.now()))
        fail('PROFILE_DELETED', 'Questo profilo è stato eliminato.', 401);
      fail('INVALID_TOKEN', 'Sessione del profilo non valida.', 401);
    }
    if (row.expires_at && row.expires_at <= this.now()) fail('INVALID_TOKEN', 'Sessione del profilo non valida.', 401);
    this.db.prepare('UPDATE tokens SET last_used_at=? WHERE hash=?').run(this.now(), digest(token));
    this.markActive(row.profile_id);
    return row.profile_id;
  }
  markActive(id) { recordActivity(this.db, id, this.now()); }
  issueToken(id, { verified = false, deviceName = '' } = {}) {
    const token = opaque();
    this.markActive(id);
    this.db.prepare('INSERT INTO tokens(hash,profile_id,created_at,id,device_name,last_used_at,verified_at,expires_at) VALUES(?,?,?,?,?,?,?,?)')
      .run(digest(token), id, this.now(), randomBytes(18).toString('base64url'), String(deviceName).slice(0, 80), this.now(), verified ? this.now() : 0,
        this.profile(id).linkedProviders.length ? this.now() + 90 * DAY : 0);
    // Recovery can add devices without invalidating their existing sessions.
    const excess = this.db.prepare('SELECT hash FROM tokens WHERE profile_id=? ORDER BY created_at DESC,rowid DESC LIMIT -1 OFFSET 32').all(id);
    for (const old of excess) this.db.prepare('DELETE FROM tokens WHERE hash=?').run(old.hash);
    return token;
  }
  createProfile() {
    return this.transaction(() => {
      if (this.db.prepare('SELECT COUNT(*) AS count FROM profiles').get().count >= this.maxProfiles)
        fail('CAPACITY', 'Il servizio è occupato. Riprova più tardi.', 503);
      const id = randomBytes(18).toString('base64url');
      this.db.prepare('INSERT INTO profiles(id,gems,created_at) VALUES(?,?,?)').run(id, RULES.welcomeGems, this.now());
      this.db.prepare('INSERT INTO ledger(profile_id,source,delta,created_at) VALUES(?,?,?,?)')
        .run(id, 'welcome', RULES.welcomeGems, this.now());
      return { token: this.issueToken(id), profile: this.profile(id) };
    });
  }
  hasBootstrap(bootstrapToken) {
    return typeof bootstrapToken === 'string' && /^[A-Za-z0-9_-]{43}$/.test(bootstrapToken) &&
      Boolean(this.db.prepare('SELECT 1 FROM offline_bootstraps WHERE hash=?').get(digest(bootstrapToken)));
  }
  bootstrapGuest({ bootstrapToken }) {
    if (typeof bootstrapToken !== 'string' || !/^[A-Za-z0-9_-]{43}$/.test(bootstrapToken))
      fail('INVALID_BOOTSTRAP', 'Credenziale del profilo locale non valida.');
    const hash = digest(bootstrapToken);
    return this.transaction(() => {
      const prior = this.db.prepare('SELECT profile_id FROM offline_bootstraps WHERE hash=?').get(hash);
      if (prior) {
        if (!this.hasProfile(prior.profile_id)) fail('PROFILE_DELETED', 'Questo profilo è stato eliminato.', 401);
        // A lost registration response can be retried, but cannot revive a
        // session revoked by logout, device management, or account expiry.
        const id = this.authenticate(bootstrapToken);
        if (id !== prior.profile_id) fail('INVALID_BOOTSTRAP', 'Credenziale del profilo locale non valida.', 401);
        return { token: bootstrapToken, profile: this.profile(id) };
      }
      if (this.db.prepare('SELECT 1 FROM deleted_tokens WHERE hash=? AND expires_at>?').get(hash, this.now()))
        fail('PROFILE_DELETED', 'Questo profilo è stato eliminato.', 401);
      if (this.db.prepare('SELECT 1 FROM tokens WHERE hash=?').get(hash))
        fail('INVALID_BOOTSTRAP', 'Credenziale del profilo locale non valida.', 401);
      if (this.db.prepare('SELECT COUNT(*) AS count FROM profiles').get().count >= this.maxProfiles)
        fail('CAPACITY', 'Il servizio è occupato. Riprova più tardi.', 503);
      const id = randomBytes(18).toString('base64url');
      this.db.prepare('INSERT INTO profiles(id,gems,created_at) VALUES(?,?,?)').run(id, RULES.welcomeGems, this.now());
      this.db.prepare('INSERT INTO ledger(profile_id,source,delta,created_at) VALUES(?,?,?,?)')
        .run(id, 'welcome', RULES.welcomeGems, this.now());
      this.db.prepare('INSERT INTO offline_bootstraps(hash,profile_id,created_at) VALUES(?,?,?)').run(hash, id, this.now());
      this.db.prepare('INSERT INTO tokens(hash,profile_id,created_at,id,last_used_at) VALUES(?,?,?,?,?)')
        .run(hash, id, this.now(), randomBytes(18).toString('base64url'), this.now());
      this.markActive(id);
      return { token: bootstrapToken, profile: this.profile(id) };
    });
  }
  updateProfile(id, input) {
    const { displayName, avatarId, accentId } = input;
    if (avatarId !== undefined && !PROFILE_AVATARS.includes(avatarId)) fail('INVALID_AVATAR', 'Avatar non valido.');
    if (accentId !== undefined && !PROFILE_ACCENTS.includes(accentId)) fail('INVALID_ACCENT', 'Colore non valido.');
    if (displayName === undefined && avatarId === undefined && accentId === undefined) fail('INVALID_PROFILE_UPDATE', 'Scegli cosa modificare.');
    const current = this.profile(id);
    this.db.prepare('UPDATE profiles SET display_name=?,avatar_id=?,accent_id=?,revision=revision+1 WHERE id=?')
      .run(displayName === undefined ? current.displayName : cleanName(displayName), avatarId ?? current.avatarId, accentId ?? current.accentId, id);
    return { profile: this.profile(id) };
  }
  recovery(id, { displayName } = {}, rotate = false) {
    return this.transaction(() => {
      const profile = this.profile(id);
      if (profile.activated && !rotate) fail('RECOVERY_ALREADY_ACTIVE', 'Il codice è già attivo. Ruotalo per crearne uno nuovo.', 409);
      if (displayName !== undefined) this.db.prepare('UPDATE profiles SET display_name=? WHERE id=?').run(cleanName(displayName), id);
      const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
      const raw = Array.from({ length: 32 }, () => alphabet[randomInt(32)]).join('');
      const recoveryCode = `SMM-${raw.match(/.{4}/g).join('-')}`;
      this.db.prepare('UPDATE profiles SET activated=1,recovery_hash=?,recovery_version=recovery_version+1,revision=revision+1 WHERE id=?').run(recoveryHash(recoveryCode), id);
      return { recoveryCode, profile: this.profile(id) };
    });
  }
  recoveryProfile(recoveryCode) {
    const row = this.db.prepare('SELECT id FROM profiles WHERE recovery_hash=?').get(recoveryHash(recoveryCode));
    if (!row) fail('INVALID_RECOVERY', 'Codice di recupero non valido.', 401);
    return this.profile(row.id);
  }
  restore({ recoveryCode, confirmReplace }) {
    if (confirmReplace !== true) fail('CONFIRM_RESTORE', 'Conferma prima di sostituire il profilo locale.', 409);
    return this.transaction(() => {
      const profile = this.recoveryProfile(recoveryCode);
      return { token: this.issueToken(profile.id, { verified: true }), profile };
    });
  }
  logout(token) { this.db.prepare('DELETE FROM tokens WHERE hash=?').run(digest(token)); return { loggedOut: true }; }
  deleteProfile(id, { confirmDelete }, beforeDelete = () => {}) {
    if (confirmDelete !== true) fail('CONFIRM_DELETE', 'Conferma l’eliminazione del profilo.', 409);
    this.transaction(() => {
      this.profile(id);
      beforeDelete();
      this.db.prepare('INSERT OR REPLACE INTO deleted_tokens(hash,expires_at) SELECT hash,? FROM tokens WHERE profile_id=?')
        .run(this.now() + 31 * DAY, id);
      this.db.prepare('INSERT OR REPLACE INTO deleted_tokens(hash,expires_at) SELECT hash,? FROM offline_bootstraps WHERE profile_id=?')
        .run(this.now() + 31 * DAY, id);
      this.db.prepare('DELETE FROM profiles WHERE id=?').run(id);
      for (const round of this.db.prepare('SELECT id,participants FROM online_rounds').all()) {
        const ids = JSON.parse(round.participants);
        if (ids.includes(id)) this.db.prepare('UPDATE online_rounds SET participants=? WHERE id=?').run(json(ids.filter(other => other !== id)), round.id);
      }
    });
    return { deleted: true };
  }
  ownsDeck(id, theme) {
    if (!id) return freeDecks.includes(theme);
    return this.profile(id).ownedDecks.includes(theme);
  }
  idempotent(id, kind, key, payload, action) {
    requestKey(key);
    const hash = digest(json(payload));
    const prior = this.db.prepare('SELECT payload_hash,result FROM requests WHERE profile_id=? AND kind=? AND request_id=?').get(id, kind, key);
    if (prior) {
      if (prior.payload_hash !== hash) fail('IDEMPOTENCY_CONFLICT', 'Identificativo già usato per una richiesta diversa.', 409);
      return JSON.parse(prior.result);
    }
    const result = action();
    if (this.db.prepare('SELECT COUNT(*) AS count FROM requests WHERE profile_id=?').get(id).count >= 10_000)
      fail('REQUEST_LIMIT', 'Hai già molte richieste recenti. Riprova più tardi.', 429);
    this.db.prepare('INSERT INTO requests(profile_id,kind,request_id,payload_hash,result,created_at) VALUES(?,?,?,?,?,?)').run(id, kind, key, hash, json(result), this.now());
    return result;
  }
  unlock(id, { deckId, requestId }) {
    const deck = this.catalog.decks.find(d => d.id === deckId && d.contentReady);
    if (!deck) fail('INVALID_DECK', 'Collezione non valida.');
    return this.transaction(() => {
      const result = this.idempotent(id, 'unlock', requestId, { deckId }, () => this.unlockDeck(id, deck));
      return { ...result, profile: this.profile(id) };
    });
  }
  unlockDeck(id, deck) {
    const deckId = deck.id, profile = this.profile(id);
    if (profile.ownedDecks.includes(deckId)) return { unlocked: false, alreadyOwned: true, deckId };
    if (!profile.unlockedArenaIds.includes(deck.arenaId)) fail('ARENA_LOCKED', 'Raggiungi questa arena prima di sbloccare la collezione.', 403);
    if (profile.gems < deck.price) fail('INSUFFICIENT_GEMS', 'Non hai ancora abbastanza gemme.', 409);
    this.db.prepare('UPDATE profiles SET gems=gems-?,revision=revision+1 WHERE id=?').run(deck.price, id);
    this.db.prepare('INSERT INTO owned_decks(profile_id,deck_id) VALUES(?,?)').run(id, deckId);
    this.db.prepare('INSERT INTO ledger(profile_id,source,delta,created_at) VALUES(?,?,?,?)')
      .run(id, `unlock:${deckId}`, -deck.price, this.now());
    return { unlocked: true, alreadyOwned: false, deckId };
  }
  soloOperation(id, input) {
    const { requestId, kind } = input;
    requestKey(requestId);
    let payload;
    if (kind === 'complete') {
      const { gameId, theme, pairs, board, moves } = input;
      requestKey(gameId);
      if (![6, 8, 12, 18].includes(pairs) || !this.catalog.decks.some(d => d.id === theme && d.contentReady) ||
          !Array.isArray(board) || board.length !== pairs * 2 ||
          board.some(card => !Number.isInteger(card) || card < 0 || card >= pairs) ||
          Array.from({ length: pairs }, (_, card) => board.filter(value => value === card).length).some(count => count !== 2))
        fail('INVALID_GAME', 'Opzioni della partita non valide.');
      this.validateTranscript({ pairs, board: json(board) }, moves);
      payload = { kind, gameId, theme, pairs, board, moves };
    } else if (kind === 'unlock') {
      const { deckId } = input;
      if (!this.catalog.decks.some(d => d.id === deckId && d.contentReady)) fail('INVALID_DECK', 'Collezione non valida.');
      payload = { kind, deckId };
    } else fail('INVALID_OPERATION', 'Operazione di avanzamento non valida.');
    const hash = digest(json(payload));
    return this.transaction(() => {
      this.profile(id);
      const prior = this.db.prepare('SELECT payload_hash,result FROM solo_operations WHERE profile_id=? AND request_id=?').get(id, requestId);
      if (prior) {
        if (prior.payload_hash !== hash) fail('IDEMPOTENCY_CONFLICT', 'Identificativo già usato per una richiesta diversa.', 409);
        return { profile: this.profile(id), operation: JSON.parse(prior.result) };
      }
      let result;
      if (kind === 'complete') {
        const { gameId, theme, pairs, board, moves } = payload;
        const proofHash = digest(json({ theme, pairs, board, moves }));
        const played = this.db.prepare('SELECT profile_id,proof_hash FROM solo_games WHERE game_id=?').get(gameId);
        if (played && played.profile_id !== id) fail('GAME_ALREADY_CLAIMED', 'Questa partita appartiene a un altro profilo.', 409);
        if (played && played.proof_hash !== proofHash) fail('IDEMPOTENCY_CONFLICT', 'Identificativo già usato per una partita diversa.', 409);
        if (!this.ownsDeck(id, theme)) fail('DECK_LOCKED', 'Sblocca questa collezione prima di giocare.', 403);
        this.db.prepare('INSERT OR IGNORE INTO solo_games(game_id,profile_id,proof_hash,created_at) VALUES(?,?,?,?)')
          .run(gameId, id, proofHash, this.now());
        this.recordSolo(id, pairs, moves.length / 2);
        result = { reward: { gameId, gems: RULES.completionGems, granted: this.grant(id, `solo:${gameId}`) } };
      } else {
        result = this.unlockDeck(id, this.catalog.decks.find(d => d.id === payload.deckId));
      }
      const operation = { requestId, kind, ...result };
      // These receipts do not expire with prepared tickets. A device can come
      // back online months later or retry after a committed response was lost.
      this.db.prepare('INSERT INTO solo_operations(profile_id,request_id,payload_hash,result,created_at) VALUES(?,?,?,?,?)')
        .run(id, requestId, hash, json(operation), this.now());
      return { profile: this.profile(id), operation };
    });
  }
  guestToken(ticketId) { return createHmac('sha256', this.capabilityKey).update(`bluetooth-guest:${ticketId}`).digest('base64url'); }
  ticketView(row, includeCapability = false) {
    const ticket = { id: row.id, mode: row.mode, pairs: row.pairs, theme: row.theme,
      seed: row.seed, board: JSON.parse(row.board), expiresAt: row.expires_at };
    if (includeCapability && row.mode === 'bluetooth') ticket.guestClaimToken = this.guestToken(row.id);
    return ticket;
  }
  newTicket(id, input) {
    if (!input || typeof input !== 'object' || Array.isArray(input)) fail('INVALID_GAME', 'Opzioni della partita non valide.');
    const { mode, pairs, theme, requestId } = input;
    if (!['solo', 'local', 'bluetooth'].includes(mode) || ![6, 8, 12, 18].includes(pairs) || !this.catalog.decks.some(d => d.id === theme && d.contentReady))
      fail('INVALID_GAME', 'Opzioni della partita non valide.');
    this.profile(id);
    if (!this.ownsDeck(id, theme)) fail('DECK_LOCKED', 'Sblocca questa collezione prima di ospitare la partita.', 403);
    const result = this.idempotent(id, 'ticket', requestId, { mode, pairs, theme }, () => {
      this.db.prepare('DELETE FROM tickets WHERE expires_at<=?').run(this.now());
      this.db.prepare('DELETE FROM requests WHERE created_at<?').run(this.now() - 31 * DAY);
      if (this.db.prepare('SELECT COUNT(*) AS count FROM tickets').get().count >= 100_000)
        fail('CAPACITY', 'Il servizio è occupato. Riprova più tardi.', 503);
      const count = this.db.prepare('SELECT COUNT(*) AS count FROM tickets WHERE owner_id=? AND created_at>?').get(id, this.now() - DAY).count;
      if (count >= RULES.maxTicketsPerDay) fail('TICKET_LIMIT', 'Hai già preparato molte partite. Riprova domani.', 429);
      const ticketId = randomBytes(24).toString('base64url');
      const seed = randomBytes(16).toString('hex');
      const board = Array.from({ length: pairs * 2 }, (_, i) => String(i % pairs));
      for (let i = board.length - 1; i > 0; i--) { const j = randomInt(i + 1); [board[i], board[j]] = [board[j], board[i]]; }
      this.db.prepare('INSERT INTO tickets(id,owner_id,guest_hash,mode,pairs,theme,seed,board,created_at,expires_at) VALUES(?,?,?,?,?,?,?,?,?,?)')
        .run(ticketId, id, mode === 'bluetooth' ? digest(this.guestToken(ticketId)) : null, mode, pairs, theme, seed, json(board), this.now(), this.now() + RULES.ticketLifetimeDays * DAY);
      return { ticketId };
    });
    const row = this.db.prepare('SELECT * FROM tickets WHERE id=?').get(result.ticketId);
    if (!row || row.expires_at <= this.now()) fail('TICKET_EXPIRED', 'Questa partita è scaduta. Preparane una nuova.', 410);
    return { ticket: this.ticketView(row, true) };
  }
  issueTicket(id, input) { return this.transaction(() => this.newTicket(id, input)); }
  issueBatch(id, { requests }) {
    if (!Array.isArray(requests) || !requests.length || requests.length > 12)
      fail('INVALID_BATCH', 'Prepara da una a dodici partite alla volta.');
    return this.transaction(() => ({ tickets: requests.map(input => this.newTicket(id, input).ticket) }));
  }
  validateTranscript(row, moves) {
    if (!Array.isArray(moves) || moves.length < row.pairs * 2 || moves.length > RULES.maxTranscriptMoves)
      fail('INVALID_TRANSCRIPT', 'La partita non risulta completa.');
    const board = JSON.parse(row.board), matched = new Set();
    let first = null;
    for (const index of moves) {
      if (!Number.isInteger(index) || index < 0 || index >= board.length || matched.has(index) || first === index || matched.size === board.length)
        fail('INVALID_TRANSCRIPT', 'Sequenza delle carte non valida.');
      if (first === null) first = index;
      else { if (board[first] === board[index]) { matched.add(first); matched.add(index); } first = null; }
    }
    if (first !== null || matched.size !== board.length) fail('INVALID_TRANSCRIPT', 'La partita non risulta completa.');
  }
  recordSolo(id, pairs, attempts) {
    this.db.prepare(`INSERT INTO solo_records(profile_id,pairs,best_attempts) VALUES(?,?,?)
      ON CONFLICT(profile_id,pairs) DO UPDATE SET best_attempts=MIN(best_attempts,excluded.best_attempts)`)
      .run(id, pairs, attempts);
  }
  grant(id, source) {
    if (!this.db.prepare('SELECT id FROM profiles WHERE id=?').get(id)) return false;
    const prior = this.db.prepare('SELECT 1 FROM ledger WHERE profile_id=? AND source=?').get(id, source);
    if (prior) return false;
    this.db.prepare('INSERT INTO ledger(profile_id,source,delta,created_at) VALUES(?,?,?,?)').run(id, source, RULES.completionGems, this.now());
    this.db.prepare('UPDATE profiles SET gems=gems+?,revision=revision+1 WHERE id=?').run(RULES.completionGems, id);
    return true;
  }
  claim(id, { ticketId, moves, requestId, guestClaimToken }) {
    if (typeof ticketId !== 'string' || !/^[A-Za-z0-9_-]{32}$/.test(ticketId)) fail('INVALID_TICKET', 'Partita non valida.');
    return this.transaction(() => {
      this.profile(id);
      const row = this.db.prepare('SELECT * FROM tickets WHERE id=?').get(ticketId);
      if (!row) fail('INVALID_TICKET', 'Partita non disponibile.', 404);
      if (row.expires_at <= this.now()) fail('TICKET_EXPIRED', 'Questa partita è scaduta.', 410);
      if (row.owner_id !== id) {
        if (row.mode !== 'bluetooth' || typeof guestClaimToken !== 'string' || guestClaimToken.length !== 43 || digest(guestClaimToken) !== row.guest_hash)
          fail('INVALID_GUEST_CLAIM', 'Invito al premio non valido.', 403);
        if ((row.guest_id && row.guest_id !== id) || (row.guest_claimed && !row.guest_id))
          fail('GUEST_ALREADY_CLAIMED', 'Il premio ospite è già stato assegnato.', 409);
      }
      const result = this.idempotent(id, 'claim', requestId, { ticketId, moves }, () => {
        this.validateTranscript(row, moves);
        if (row.mode === 'solo' && row.owner_id === id) this.recordSolo(id, row.pairs, moves.length / 2);
        if (row.owner_id !== id) this.db.prepare('UPDATE tickets SET guest_id=?,guest_claimed=1 WHERE id=?').run(id, ticketId);
        return { reward: { gameId: ticketId, gems: RULES.completionGems, granted: this.grant(id, `game:${ticketId}`) } };
      });
      return { ...result, profile: this.profile(id) };
    });
  }
  rewardOnline(room) {
    if (room.phase !== 'finished' || room.finishReason !== 'completed' || !room.roundId) return {};
    const ids = [...new Set(room.players.map(p => p.profileId).filter(Boolean))];
    if (!ids.length) return {};
    return this.transaction(() => {
      this.db.prepare('INSERT OR IGNORE INTO online_rounds(id,participants) VALUES(?,?)').run(room.roundId, json(ids));
      const row = this.db.prepare('SELECT * FROM online_rounds WHERE id=?').get(room.roundId);
      if (row.claimed) return JSON.parse(row.receipt);
      const receipt = {};
      for (const id of JSON.parse(row.participants)) {
        if (this.grant(id, `game:${room.roundId}`)) {
          const player = room.players.find(p => p.profileId === id);
          if (player) receipt[player.id] = { gems: RULES.completionGems, granted: true };
        }
      }
      this.db.prepare('UPDATE online_rounds SET claimed=1,receipt=? WHERE id=?').run(json(receipt), room.roundId);
      return receipt;
    });
  }
  settleRanked(room) {
    if (room.phase !== 'finished' || !room.matchId) return {};
    return this.transaction(() => {
      const prior = this.db.prepare('SELECT receipt FROM ranked_matches WHERE match_id=?').get(room.matchId);
      if (prior) return JSON.parse(prior.receipt);
      const players = room.players;
      const cancelled = room.finishReason === 'cancelled' || players.length !== 2 ||
        players.some(p => !p.profileId || !this.hasProfile(p.profileId)) || players[0].profileId === players[1].profileId;
      const receipt = {};
      if (!cancelled) for (const player of players) {
        const row = this.db.prepare('SELECT crowns,peak_crowns FROM profiles WHERE id=?').get(player.profileId);
        const outcome = room.winnerId === null ? 'draw' : room.winnerId === player.id ? 'win' : 'loss';
        const { crowns, peakCrowns: peak } = applyCrownResult(row.crowns, row.peak_crowns, outcome, this.catalog);
        this.db.prepare('UPDATE profiles SET crowns=?,peak_crowns=?,revision=revision+1 WHERE id=?').run(crowns, peak, player.profileId);
        const granted = room.finishReason === 'completed' && this.grant(player.profileId, `ranked:${room.matchId}`);
        receipt[player.id] = { gems: granted ? RULES.completionGems : 0, granted: Boolean(granted), crownsDelta: crowns - row.crowns };
      }
      this.db.prepare('INSERT INTO ranked_matches(match_id,receipt,created_at) VALUES(?,?,?)').run(room.matchId, json(receipt), this.now());
      return receipt;
    });
  }
  ledger(id) {
    return { entries: this.db.prepare('SELECT source,delta,created_at AS createdAt FROM ledger WHERE profile_id=? ORDER BY id DESC LIMIT 50').all(id) };
  }
}
