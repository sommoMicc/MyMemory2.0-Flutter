import { DECKS } from './economy.mjs';
const DAY = 86_400_000;
const safePlayer = (player, room, seat) => ({ seat, name: player.name, connected: player.connected,
  ready: room.lobbyReady?.includes(player.id) ?? false, score: player.score,
  attempts: player.individual?.attempts ?? null });
export class AdminData {
  constructor({ store, engine, now = Date.now, connections = () => 0 }) {
    this.store = store; this.db = store.db; this.engine = engine; this.now = now; this.connections = connections;
    this.started = now();
    this.catalog = store.catalog ?? { decks: DECKS.map(d => ({ ...d, name: ({ garden: 'Animali', cosmos: 'Spazio', ocean: 'Oceano', paola: 'Paola', food: 'Cibo', sports: 'Sport', travel: 'Viaggi' })[d.id] || d.id })), arenas: [] };
    this.hasCrowns = this.db.prepare('PRAGMA table_info(profiles)').all().some(c => c.name === 'crowns');
    this.failures = 0;
    this.observe = code => {
      try { const room = engine.rooms.get(code); if (room) this.record(room); }
      catch { this.failures++; console.error('Admin match recording failed.'); }
    };
    this.onRemoved = code => {
      try { this.removed(code); }
      catch { this.failures++; console.error('Admin room archival failed.'); }
    };
    engine.on('change', this.observe);
    engine.on('removed', this.onRemoved);
    for (const room of engine.rooms.values()) this.record(room);
    const current = new Set([...engine.rooms.values()].map(r => r.matchType === 'ranked' ? r.matchId : r.roundId));
    for (const row of this.db.prepare("SELECT id FROM admin_matches WHERE phase IN ('playing','roundFinished')").all())
      if (!current.has(row.id)) this.db.prepare("UPDATE admin_matches SET phase='unavailable',updated_at=? WHERE id=?").run(now(), row.id);
    this.cleanup();
  }
  record(room) {
    const id = room.matchType === 'ranked' ? room.matchId : room.roundId;
    if (!id || room.phase === 'waiting') return;
    const scores = room.matchType === 'ranked' ? this.engine.totalScores(room) : null;
    const attempts = room.matchType === 'ranked' ? this.engine.totalAttempts(room) : null;
    this.store.transaction(() => {
      this.db.prepare(`INSERT INTO admin_matches(id,code,mode,arena_id,theme,pairs,phase,started_at,finished_at,
        observed_at,updated_at,finish_reason,round,winner_seat) VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?)
        ON CONFLICT(id) DO UPDATE SET phase=excluded.phase,theme=excluded.theme,finished_at=excluded.finished_at,
        updated_at=excluded.updated_at,finish_reason=excluded.finish_reason,round=excluded.round,winner_seat=excluded.winner_seat`)
        .run(id, room.code, room.matchType ?? 'friendly', room.arenaId ?? null, room.theme, room.pairs,
          room.phase, room.matchStartedAt ?? null, room.finishedAt ?? null, this.now(), this.now(),
          room.finishReason ?? null, room.roundIndex ?? 1,
          room.winnerId ? room.players.findIndex(p => p.id === room.winnerId) : null);
      room.players.forEach((p, seat) => this.db.prepare(`INSERT INTO admin_match_players(match_id,seat,profile_id,score,attempts)
        VALUES(?,?,?,?,?) ON CONFLICT(match_id,seat) DO UPDATE SET profile_id=excluded.profile_id,score=excluded.score,attempts=excluded.attempts`)
        .run(id, seat, p.profileId && this.store.hasProfile(p.profileId) ? p.profileId : null,
          scores ? scores[p.id] : p.score, attempts ? attempts[p.id] : null));
    });
  }
  cleanup() {
    const cutoff = this.now() - 90 * DAY;
    this.db.prepare('DELETE FROM admin_activity WHERE last_at<?').run(cutoff);
    // An ongoing match is retained until it finishes, expires or disappears.
    this.db.prepare(`DELETE FROM admin_matches WHERE updated_at<? AND phase IN ('finished','unavailable')`).run(cutoff);
    this.db.prepare('DELETE FROM admin_sessions WHERE expires_at<=?').run(this.now());
  }
  snapshot(params = new URLSearchParams()) {
    const now = this.now(), days = [1, 7, 30, 90].includes(Number(params.get('days'))) ? Number(params.get('days')) : 7;
    const since = now - days * DAY;
    const trackingSince = this.db.prepare("SELECT value FROM admin_meta WHERE key='tracking_since'").get().value;
    const count = (sql, ...args) => this.db.prepare(sql).get(...args).n;
    const rooms = [...this.engine.rooms.values()];
    const live = rooms.filter(r => ['playing', 'roundFinished'].includes(r.phase));
    const lobbies = rooms.filter(r => r.phase === 'waiting');
    const connected = new Set(rooms.flatMap(r => r.players.filter(p => p.connected && !p.left).map(p => p.profileId || p.id))).size;
    const active = span => count('SELECT COUNT(DISTINCT profile_id) n FROM admin_activity WHERE last_at>=?', now - span * DAY);
    const outcomes = this.db.prepare(`SELECT COUNT(*) finished,
      COALESCE(SUM(finish_reason='completed'),0) completed,
      COALESCE(SUM(finish_reason='forfeit'),0) abandoned,
      AVG(CASE WHEN started_at IS NOT NULL AND finished_at>=started_at THEN finished_at-started_at END) duration
      FROM admin_matches WHERE finished_at>=?`).get(since);
    const daily = [];
    for (let i = days; i >= 0; i--) {
      const day = new Date(now - i * DAY).toISOString().slice(0, 10);
      const from = Math.max(Date.parse(`${day}T00:00:00Z`), since), to = Date.parse(`${day}T00:00:00Z`) + DAY;
      if (to <= trackingSince) continue;
      daily.push({ day, active: count('SELECT COUNT(*) n FROM admin_activity WHERE day=? AND last_at>=?', day, since),
        matches: count('SELECT COUNT(*) n FROM admin_matches WHERE started_at>=? AND started_at<?', from, to) });
    }
    const mode = ['friendly', 'ranked'].includes(params.get('mode')) ? params.get('mode') : '';
    const phase = ['playing', 'roundFinished', 'finished', 'unavailable'].includes(params.get('phase')) ? params.get('phase') : '';
    const query = (params.get('q') || '').slice(0, 80).trim().toLowerCase();
    const where = ['m.observed_at>=?'], args = [since];
    if (mode) { where.push('m.mode=?'); args.push(mode); }
    if (phase) { where.push('m.phase=?'); args.push(phase); }
    if (query) {
      where.push(`(instr(lower(m.code),?)>0 OR EXISTS(SELECT 1 FROM admin_match_players mp JOIN profiles p ON p.id=mp.profile_id
        WHERE mp.match_id=m.id AND instr(lower(p.display_name),?)>0))`); args.push(query, query);
    }
    const clause = where.join(' AND ');
    const total = count(`SELECT COUNT(*) n FROM admin_matches m WHERE ${clause}`, ...args);
    const page = Math.min(Math.max(1, Math.floor(Number(params.get('page')) || 1)), Math.max(1, Math.ceil(total / 25)));
    const matches = this.db.prepare(`SELECT m.* FROM admin_matches m WHERE ${clause} ORDER BY m.observed_at DESC,m.id LIMIT 25 OFFSET ?`)
      .all(...args, (page - 1) * 25).map(m => ({ ...m, players: this.db.prepare(`SELECT mp.seat,mp.score,mp.attempts,
        COALESCE(NULLIF(p.display_name,''),'Ospite') name FROM admin_match_players mp LEFT JOIN profiles p ON p.id=mp.profile_id
        WHERE mp.match_id=? ORDER BY mp.seat`).all(m.id) }));
    const roomView = r => ({ code: r.code, mode: r.matchType ?? 'friendly', phase: r.phase, arenaId: r.arenaId,
      theme: r.theme, pairs: r.pairs, round: r.roundIndex ?? 1, createdAt: r.createdAt ?? null,
      updatedAt: r.updatedAt, startedAt: r.matchStartedAt ?? null,
      players: r.players.map((p, i) => safePlayer(p, r, i)) });
    return { generatedAt: now, trackingSince,
      days, summary: { connected, connections: this.connections(), liveMatches: live.length, lobbies: lobbies.length,
        totalProfiles: count('SELECT COUNT(*) n FROM profiles'), active24h: active(1), active7d: active(7), active30d: active(30),
        newProfiles: count('SELECT COUNT(*) n FROM profiles WHERE created_at>=?', since),
        savedProfiles: count(`SELECT COUNT(*) n FROM profiles p WHERE activated=1 OR EXISTS(SELECT 1 FROM auth_identities a WHERE a.profile_id=p.id)`),
        startedMatches: count('SELECT COUNT(*) n FROM admin_matches WHERE started_at>=?', since), ...outcomes,
        pendingRewards: this.engine.pendingRewards.size, recordingErrors: this.failures,
        gemsAwarded: count("SELECT COALESCE(SUM(delta),0) n FROM ledger WHERE created_at>=? AND delta>0 AND (source LIKE 'game:%' OR source LIKE 'ranked:%')", since),
        deckUnlocks: count('SELECT COUNT(*) n FROM ledger WHERE created_at>=? AND delta<0', since),
        uptimeMs: now - this.started, retentionDays: 90 },
      daily, live: live.map(roomView), lobbies: lobbies.map(roomView), matches: { items: matches, total, page, pages: Math.max(1, Math.ceil(total / 25)) },
      decks: this.catalog.decks.map(d => ({ id: d.id, name: d.name })),
      arenas: this.catalog.arenas.map(a => ({ id: a.id, name: a.name,
        matches: count('SELECT COUNT(*) n FROM admin_matches WHERE arena_id=? AND started_at>=?', a.id, since) })),
      profiles: this.db.prepare(`SELECT p.id,p.display_name name,p.gems,${this.hasCrowns ? 'p.crowns' : 'NULL'} crowns,p.created_at createdAt,
        (SELECT MAX(last_at) FROM admin_activity a WHERE a.profile_id=p.id) lastActive,
        (SELECT COUNT(*) FROM auth_identities i WHERE i.profile_id=p.id) linkedProviders
        FROM profiles p WHERE (?='' OR instr(lower(p.display_name),?)>0 OR instr(lower(p.id),?)>0)
        ORDER BY COALESCE(lastActive,p.created_at) DESC LIMIT 50`).all(query, query, query),
    };
  }
  removed(code) {
    // Preserve finished results; a vanished active room is not a completed game.
    this.db.prepare("UPDATE admin_matches SET phase='unavailable',updated_at=? WHERE code=? AND phase IN ('playing','roundFinished')").run(this.now(), code);
  }
  close() { this.engine.off('change', this.observe); this.engine.off('removed', this.onRemoved); }
}
