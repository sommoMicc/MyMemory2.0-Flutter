// Operational data stays in the existing private SQLite volume.
export function adminSchema(db, now = Date.now()) {
  db.exec(`
    CREATE TABLE IF NOT EXISTS admin_meta (key TEXT PRIMARY KEY, value INTEGER NOT NULL);
    CREATE TABLE IF NOT EXISTS admin_used_enrollments (hash TEXT PRIMARY KEY, used_at INTEGER NOT NULL);
    CREATE TABLE IF NOT EXISTS admin_passkeys (
      id TEXT PRIMARY KEY, public_key BLOB NOT NULL, counter INTEGER NOT NULL,
      transports TEXT NOT NULL, label TEXT NOT NULL, created_at INTEGER NOT NULL, last_used_at INTEGER
    );
    CREATE TABLE IF NOT EXISTS admin_sessions (
      hash TEXT PRIMARY KEY, credential_id TEXT NOT NULL REFERENCES admin_passkeys(id) ON DELETE CASCADE,
      created_at INTEGER NOT NULL, expires_at INTEGER NOT NULL
    );
    CREATE TABLE IF NOT EXISTS admin_activity (
      profile_id TEXT NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
      day TEXT NOT NULL, last_at INTEGER NOT NULL, PRIMARY KEY(profile_id,day)
    );
    CREATE INDEX IF NOT EXISTS admin_activity_time ON admin_activity(last_at);
    CREATE TABLE IF NOT EXISTS admin_matches (
      id TEXT PRIMARY KEY, code TEXT NOT NULL, mode TEXT NOT NULL, arena_id TEXT, theme TEXT,
      pairs INTEGER NOT NULL, phase TEXT NOT NULL, started_at INTEGER, finished_at INTEGER,
      observed_at INTEGER NOT NULL, updated_at INTEGER NOT NULL, finish_reason TEXT,
      round INTEGER NOT NULL, winner_seat INTEGER
    );
    CREATE INDEX IF NOT EXISTS admin_matches_time ON admin_matches(observed_at);
    CREATE TABLE IF NOT EXISTS admin_match_players (
      match_id TEXT NOT NULL REFERENCES admin_matches(id) ON DELETE CASCADE,
      seat INTEGER NOT NULL, profile_id TEXT REFERENCES profiles(id) ON DELETE SET NULL,
      score INTEGER NOT NULL, attempts INTEGER, PRIMARY KEY(match_id,seat)
    );
  `);
  db.prepare("INSERT OR IGNORE INTO admin_meta(key,value) VALUES('tracking_since',?)").run(now);
}

export function recordActivity(db, id, now) {
  if (!id) return;
  db.prepare(`INSERT INTO admin_activity(profile_id,day,last_at) SELECT ?,?,? WHERE EXISTS(SELECT 1 FROM profiles WHERE id=?)
    ON CONFLICT(profile_id,day) DO UPDATE SET last_at=excluded.last_at WHERE last_at<excluded.last_at-60000`)
    .run(id, new Date(now).toISOString().slice(0, 10), now, id);
}
