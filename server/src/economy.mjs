import { DatabaseSync } from 'node:sqlite';
import { createHash, createHmac, randomBytes, randomInt } from 'node:crypto';
import { chmodSync, existsSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';

export const DECKS = Object.freeze([
  { id: 'garden', price: 0, free: true }, { id: 'cosmos', price: 0, free: true },
  { id: 'ocean', price: 0, free: true }, { id: 'paola', price: 0, free: true },
  { id: 'food', price: 200, free: false },
  { id: 'sports', price: 300, free: false }, { id: 'travel', price: 400, free: false },
]);
export const RULES = Object.freeze({ welcomeGems: 100, completionGems: 20,
  ticketLifetimeDays: 30, maxTicketsPerDay: 100, maxTranscriptMoves: 4000 });
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
  constructor({ dataDir, now = Date.now, maxProfiles = 200_000 } = {}) {
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
      CREATE INDEX IF NOT EXISTS tokens_profile ON tokens(profile_id);
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
    this.cleanup();
  }
  close() { this.db.close(); }
  cleanup() {
    this.transaction(() => {
      this.db.prepare('DELETE FROM tickets WHERE expires_at<=?').run(this.now());
      this.db.prepare('DELETE FROM requests WHERE created_at<?').run(this.now() - 31 * DAY);
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
    return { id: row.id, displayName: row.display_name, activated: Boolean(row.activated),
      recoveryVersion: row.recovery_version, gems: row.gems, ownedDecks: [...freeDecks, ...owned], revision: row.revision };
  }
  authenticate(token) {
    if (typeof token !== 'string' || !/^[A-Za-z0-9_-]{43}$/.test(token))
      fail('INVALID_TOKEN', 'Sessione del profilo non valida.', 401);
    const row = this.db.prepare('SELECT profile_id FROM tokens WHERE hash=?').get(digest(token));
    if (!row) fail('INVALID_TOKEN', 'Sessione del profilo non valida.', 401);
    return row.profile_id;
  }
  issueToken(id) {
    const token = opaque();
    this.db.prepare('INSERT INTO tokens(hash,profile_id,created_at) VALUES(?,?,?)').run(digest(token), id, this.now());
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
  updateProfile(id, { displayName }) {
    const name = cleanName(displayName);
    this.db.prepare('UPDATE profiles SET display_name=?,revision=revision+1 WHERE id=?').run(name, id);
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
      return { token: this.issueToken(profile.id), profile };
    });
  }
  logout(token) { this.db.prepare('DELETE FROM tokens WHERE hash=?').run(digest(token)); return { loggedOut: true }; }
  deleteProfile(id, { confirmDelete }) {
    if (confirmDelete !== true) fail('CONFIRM_DELETE', 'Conferma l’eliminazione del profilo.', 409);
    this.transaction(() => {
      this.profile(id);
      this.db.prepare('DELETE FROM profiles WHERE id=?').run(id);
      for (const round of this.db.prepare('SELECT id,participants FROM online_rounds').all()) {
        const ids = JSON.parse(round.participants);
        if (ids.includes(id)) this.db.prepare('UPDATE online_rounds SET participants=? WHERE id=?').run(json(ids.filter(other => other !== id)), round.id);
      }
    });
    return { deleted: true };
  }
  ownsDeck(id, theme) {
    return freeDecks.includes(theme) || Boolean(id && this.db.prepare('SELECT 1 FROM owned_decks WHERE profile_id=? AND deck_id=?').get(id, theme));
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
    const deck = DECKS.find(d => d.id === deckId);
    if (!deck) fail('INVALID_DECK', 'Collezione non valida.');
    return this.transaction(() => {
      const result = this.idempotent(id, 'unlock', requestId, { deckId }, () => {
        const profile = this.profile(id);
        if (this.ownsDeck(id, deckId)) return { unlocked: false, alreadyOwned: true, deckId };
        if (profile.gems < deck.price) fail('INSUFFICIENT_GEMS', 'Non hai ancora abbastanza gemme.', 409);
        this.db.prepare('UPDATE profiles SET gems=gems-?,revision=revision+1 WHERE id=?').run(deck.price, id);
        this.db.prepare('INSERT INTO owned_decks(profile_id,deck_id) VALUES(?,?)').run(id, deckId);
        this.db.prepare('INSERT INTO ledger(profile_id,source,delta,created_at) VALUES(?,?,?,?)')
          .run(id, `unlock:${deckId}`, -deck.price, this.now());
        return { unlocked: true, alreadyOwned: false, deckId };
      });
      return { ...result, profile: this.profile(id) };
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
    if (!['solo', 'local', 'bluetooth'].includes(mode) || ![6, 8, 12, 18].includes(pairs) || !DECKS.some(d => d.id === theme))
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
  ledger(id) {
    return { entries: this.db.prepare('SELECT source,delta,created_at AS createdAt FROM ledger WHERE profile_id=? ORDER BY id DESC LIMIT 50').all(id) };
  }
}
