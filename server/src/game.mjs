import { EventEmitter } from 'node:events';
import { createHash, randomBytes, randomInt, timingSafeEqual } from 'node:crypto';
import { mkdirSync, readFileSync, writeFileSync, renameSync, existsSync } from 'node:fs';
import { join } from 'node:path';

export class GameError extends Error {
  constructor(code, message, { roomPreview } = {}) {
    super(message); this.code = code;
    if (roomPreview) this.roomPreview = roomPreview;
  }
}

const fail = (code, message, details) => { throw new GameError(code, message, details); };
const tokenHash = token => createHash('sha256').update(token).digest('hex');
const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
const themes = ['garden', 'cosmos', 'ocean', 'paola', 'food', 'sports', 'travel'];
const legacyThemes = ['garden', 'cosmos', 'ocean'];

export class GameEngine extends EventEmitter {
  constructor({ dataDir, now = Date.now, mismatchMs = 900, graceMs = 90_000,
    ttlMs = 86_400_000, maxRooms = 500, ownsDeck = (_id, theme) => ['garden', 'cosmos', 'ocean', 'paola'].includes(theme),
    onCompleted } = {}) {
    super();
    this.rooms = new Map();
    this.now = now;
    this.mismatchMs = mismatchMs;
    this.graceMs = graceMs;
    this.ttlMs = ttlMs;
    this.maxRooms = maxRooms;
    this.ownsDeck = ownsDeck;
    this.onCompleted = onCompleted;
    this.pendingRewards = new Map();
    if (dataDir) {
      mkdirSync(dataDir, { recursive: true, mode: 0o700 });
      this.file = join(dataDir, 'rooms.json');
      if (existsSync(this.file)) {
        const stored = JSON.parse(readFileSync(this.file, 'utf8'));
        if (stored.version !== 1 || !Array.isArray(stored.rooms)) throw new Error('Unsupported room store');
        for (const room of stored.rooms) {
          // Recover an unpaid completed round even if its room TTL elapsed offline.
          // Do not persist through settleRewards until every stored room is loaded.
          if (room.phase === 'finished' && room.finishReason === 'completed' && this.onCompleted) {
            try { room.rewards = this.onCompleted(room); }
            catch { this.pendingRewards.set(room.code, this.now() + 5000); }
          }
          if (this.now() - room.updatedAt >= ttlMs && !this.pendingRewards.has(room.code)) continue;
          for (const player of room.players) {
            // Preserve an existing deadline so repeated restarts cannot extend it.
            if (player.connected) player.disconnectedAt = this.now();
            player.connected = false;
          }
          this.rooms.set(room.code, room);
        }
        this.persist();
        this.tick();
      }
    }
  }

  persist() {
    if (!this.file) return;
    const tmp = `${this.file}.tmp`;
    writeFileSync(tmp, JSON.stringify({ version: 1, rooms: [...this.rooms.values()] }), { mode: 0o600 });
    renameSync(tmp, this.file);
  }

  change(room) {
    room.revision++;
    room.updatedAt = this.now();
    this.persist();
    this.settleRewards(room);
    this.emit('change', room.code);
  }

  settleRewards(room) {
    if (room.phase !== 'finished' || room.finishReason !== 'completed' || !this.onCompleted) return false;
    try {
      const rewards = this.onCompleted(room);
      const changed = JSON.stringify(rewards) !== JSON.stringify(room.rewards ?? {});
      room.rewards = rewards;
      this.persist();
      this.pendingRewards.delete(room.code);
      return changed;
    } catch (error) {
      // A wallet outage must not conceal an already committed final game state.
      this.pendingRewards.set(room.code, this.now() + 5000);
      this.emit('rewardError', error);
      return false;
    }
  }

  name(input) {
    if (typeof input !== 'string') fail('INVALID_NAME', 'Inserisci il tuo nome.');
    const name = [...input.trim().replace(/[\p{C}]/gu, '')].slice(0, 24).join('');
    if (!name) fail('INVALID_NAME', 'Inserisci il tuo nome.');
    return name;
  }

  room(code) {
    if (typeof code !== 'string' || !/^[A-Z2-9]{6}$/.test(code.trim().toUpperCase())) {
      fail('ROOM_NOT_FOUND', 'Codice stanza non valido.');
    }
    const room = this.rooms.get(code.trim().toUpperCase());
    if (!room) fail('ROOM_NOT_FOUND', 'Questa stanza non esiste o è scaduta.');
    return room;
  }

  player(room, id) {
    const player = room.players.find(p => p.id === id && !p.left);
    if (!player) fail('NO_SESSION', 'Entra in una stanza per giocare.');
    return player;
  }

  newPlayer(name) {
    const token = randomBytes(32).toString('base64url');
    return { token, player: { id: randomBytes(12).toString('base64url'), name: this.name(name),
      score: 0, connected: true, disconnectedAt: null, left: false, tokenHash: tokenHash(token) } };
  }

  capabilities(supportedDecks) {
    const supported = supportedDecks === undefined ? legacyThemes : supportedDecks;
    if (!Array.isArray(supported) || supported.length > 10 ||
        supported.some(id => typeof id !== 'string' || !themes.includes(id)) ||
        new Set(supported).size !== supported.length) {
      fail('INVALID_CAPABILITIES', 'Invia un elenco valido delle collezioni supportate.');
    }
    return supported;
  }

  assertSupported(theme, supportedDecks) {
    const supported = this.capabilities(supportedDecks);
    if (!supported.includes(theme)) fail('UPDATE_REQUIRED', 'Aggiorna SommoMemory per giocare con questa collezione.');
  }

  roomPreview(room) {
    return { code: room.code, phase: room.phase,
      players: room.players.slice(0, 2).map(({ id, name, score, connected }) => ({ id, name, score, connected })),
      winnerId: room.winnerId, finishReason: room.finishReason };
  }

  preview({ code }) {
    this.tick();
    const room = this.room(code);
    if (room.players.length !== 2 || !['playing', 'finished'].includes(room.phase))
      fail('ROOM_NOT_FOUND', 'Questa anteprima non è disponibile.');
    return this.roomPreview(room);
  }

  create({ name, pairs = 8, theme = 'garden', profileId, supportedDecks }) {
    this.tick();
    if (![6, 8, 12, 18].includes(pairs) || !themes.includes(theme)) {
      fail('INVALID_OPTIONS', 'Scegli un tema e una difficoltà validi.');
    }
    this.assertSupported(theme, supportedDecks);
    if (!this.ownsDeck(profileId, theme)) fail('DECK_LOCKED', 'Sblocca questa collezione prima di ospitare la partita.');
    if (this.rooms.size >= this.maxRooms) fail('SERVER_FULL', 'Il servizio è occupato. Riprova tra poco.');
    const { player, token } = this.newPlayer(name);
    if (profileId) player.profileId = profileId;
    let code;
    do { code = Array.from({ length: 6 }, () => alphabet[randomInt(alphabet.length)]).join(''); }
    while (this.rooms.has(code));
    const room = { code, pairs, theme, phase: 'waiting', players: [player], board: [],
      matched: [], selected: [], turn: null, starter: 0, revision: 0, rematch: [],
      lockedUntil: null, winnerId: null, finishReason: null, updatedAt: this.now() };
    this.rooms.set(code, room);
    this.change(room);
    return { code, token, playerId: player.id };
  }

  join({ code, name, profileId, supportedDecks }) {
    this.tick();
    const room = this.room(code);
    this.capabilities(supportedDecks);
    // Full-room previews contain no card/theme data and need no rendering support.
    if (room.phase !== 'waiting' || room.players.length !== 1)
      fail('ROOM_FULL', 'La stanza è già al completo.', { roomPreview: this.roomPreview(room) });
    this.assertSupported(room.theme, supportedDecks);
    const { player, token } = this.newPlayer(name);
    if (profileId) player.profileId = profileId;
    room.players.push(player);
    this.start(room);
    this.change(room);
    return { code: room.code, token, playerId: player.id };
  }

  start(room) {
    room.roundId = randomBytes(24).toString('base64url');
    room.rewards = {};
    room.board = Array.from({ length: room.pairs * 2 }, (_, i) => String(i % room.pairs));
    for (let i = room.board.length - 1; i > 0; i--) {
      const j = randomInt(i + 1);
      [room.board[i], room.board[j]] = [room.board[j], room.board[i]];
    }
    room.players.forEach(p => { p.score = 0; });
    room.phase = 'playing';
    room.turn = room.players[room.starter].id;
    room.matched = [];
    room.selected = [];
    room.rematch = [];
    room.lockedUntil = null;
    room.winnerId = null;
    room.finishReason = null;
  }

  resume({ code, token, supportedDecks }) {
    this.tick();
    const room = this.room(code);
    this.assertSupported(room.theme, supportedDecks);
    if (typeof token !== 'string' || token.length > 128) fail('INVALID_SESSION', 'Sessione non valida.');
    const hash = Buffer.from(tokenHash(token), 'hex');
    const player = room.players.find(p => !p.left && timingSafeEqual(Buffer.from(p.tokenHash, 'hex'), hash));
    if (!player) fail('INVALID_SESSION', 'La sessione è scaduta. Crea o raggiungi una nuova stanza.');
    player.connected = true;
    player.disconnectedAt = null;
    this.change(room);
    return { code: room.code, token, playerId: player.id };
  }

  disconnect(code, id) {
    const room = this.rooms.get(code);
    if (!room) return;
    const player = room.players.find(p => p.id === id && !p.left);
    if (!player || !player.connected) return;
    player.connected = false;
    player.disconnectedAt = this.now();
    this.change(room);
  }

  flip(code, id, index) {
    this.tick();
    const room = this.room(code);
    const player = this.player(room, id);
    if (room.phase !== 'playing') fail('NOT_PLAYING', 'La partita non è in corso.');
    if (room.players.some(p => !p.connected)) fail('OPPONENT_OFFLINE', 'Attendi che l’altro giocatore si ricolleghi.');
    if (room.turn !== id) fail('NOT_YOUR_TURN', 'Aspetta il tuo turno.');
    if (room.lockedUntil !== null) fail('BOARD_LOCKED', 'Aspetta che le carte si richiudano.');
    if (!Number.isInteger(index) || index < 0 || index >= room.board.length ||
        room.matched.includes(index) || room.selected.includes(index)) {
      fail('INVALID_CARD', 'Questa carta non è disponibile.');
    }
    room.selected.push(index);
    if (room.selected.length === 2) {
      const [first, second] = room.selected;
      if (room.board[first] === room.board[second]) {
        room.matched.push(first, second);
        room.selected = [];
        player.score++;
        if (room.matched.length === room.board.length) this.finish(room, 'completed');
      } else room.lockedUntil = this.now() + this.mismatchMs;
    }
    this.change(room);
  }

  finish(room, reason, winnerId) {
    room.phase = 'finished';
    room.turn = null;
    room.lockedUntil = null;
    room.selected = [];
    room.finishReason = reason;
    room.rematch = [];
    const [a, b] = room.players;
    room.winnerId = winnerId ?? (a.score === b.score ? null : a.score > b.score ? a.id : b.id);
  }

  rematch(code, id) {
    this.tick();
    const room = this.room(code);
    this.player(room, id);
    if (room.phase !== 'finished') fail('NOT_FINISHED', 'Completa prima questa partita.');
    if (this.pendingRewards.has(room.code)) fail('REWARD_PENDING', 'Il premio è in elaborazione. Riprova tra poco.');
    if (!this.ownsDeck(room.players[0].profileId, room.theme)) fail('DECK_LOCKED', 'Il profilo dell’host deve possedere questa collezione.');
    if (room.players.some(p => !p.connected || p.left)) fail('OPPONENT_OFFLINE', 'L’altro giocatore deve essere nella stanza.');
    if (!room.rematch.includes(id)) room.rematch.push(id);
    if (room.rematch.length === 2) {
      room.starter = 1 - room.starter;
      this.start(room);
    }
    this.change(room);
  }

  leave(code, id) {
    const room = this.rooms.get(code);
    if (!room) return;
    const player = this.player(room, id);
    player.left = true;
    player.connected = false;
    player.disconnectedAt = this.now();
    player.tokenHash = tokenHash(randomBytes(32));
    if (room.phase === 'waiting' || (room.players.every(p => p.left) && !this.pendingRewards.has(room.code))) {
      this.remove(room.code);
    } else {
      if (room.phase === 'playing') this.finish(room, 'forfeit', room.players.find(p => p.id !== id).id);
      room.rematch = [];
      this.change(room);
    }
  }

  remove(code) {
    this.rooms.delete(code);
    this.pendingRewards.delete(code);
    this.persist();
    this.emit('removed', code);
  }

  tick() {
    const now = this.now();
    for (const room of [...this.rooms.values()]) {
      if (this.pendingRewards.has(room.code)) {
        if (now >= this.pendingRewards.get(room.code) && this.settleRewards(room)) {
          room.revision++;
          this.persist();
          this.emit('change', room.code);
        }
        if (this.pendingRewards.has(room.code)) continue;
      }
      if (now - room.updatedAt >= this.ttlMs) { this.remove(room.code); continue; }
      if (room.phase !== 'finished') {
        const expired = room.players.filter(p => !p.connected && now - p.disconnectedAt >= this.graceMs);
        if (expired.length > 0) {
          if (room.players.length === 1 || expired.length === room.players.length) this.remove(room.code);
          else {
            expired.forEach(p => { p.left = true; });
            this.finish(room, 'forfeit', room.players.find(p => !expired.includes(p)).id);
            this.change(room);
          }
          continue;
        }
      }
      if (room.lockedUntil !== null && now >= room.lockedUntil) {
        room.selected = [];
        room.lockedUntil = null;
        room.turn = room.players.find(p => p.id !== room.turn).id;
        this.change(room);
      }
    }
  }

  state(code) {
    const room = this.room(code);
    return { type: 'state', code: room.code, pairs: room.pairs, theme: room.theme,
      roundId: room.roundId ?? null,
      rewards: room.rewards ?? {},
      phase: room.phase, turn: room.turn,
      cards: Array.from({ length: room.pairs * 2 }, (_, i) =>
        room.matched.includes(i) || room.selected.includes(i) ? room.board[i] : null),
      matched: [...room.matched], selected: [...room.selected],
      players: room.players.map(({ id, name, score, connected }) => ({ id, name, score, connected })),
      revision: room.revision, rematch: [...room.rematch], lockedUntil: room.lockedUntil,
      winnerId: room.winnerId, finishReason: room.finishReason };
  }
}
