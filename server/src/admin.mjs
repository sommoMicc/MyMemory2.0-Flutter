import { createHash, randomBytes } from 'node:crypto';
import { existsSync, mkdirSync, readFileSync, writeFileSync, unlinkSync, createReadStream } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { generateRegistrationOptions, verifyRegistrationResponse,
  generateAuthenticationOptions, verifyAuthenticationResponse } from '@simplewebauthn/server';
import { readJsonBody } from './economy-http.mjs';
import { EconomyError } from './economy.mjs';
import { AdminData } from './admin-data.mjs';
const here = dirname(fileURLToPath(import.meta.url));
const hash = value => createHash('sha256').update(value).digest('hex');
const opaque = () => randomBytes(32).toString('base64url');
const fail = (code, message, status = 400) => { throw new EconomyError(code, message, status); };
export function createAdminService({ store, engine, dataDir, addressOf, connections, config = {}, now = Date.now }) {
  const origin = new URL(config.origin ?? process.env.ADMIN_ORIGIN ?? 'https://sommomemory.sommomi.cc');
  if (origin.origin !== origin.href.replace(/\/$/, '') || (origin.protocol !== 'https:' &&
      !(origin.protocol === 'http:' && ['localhost', '127.0.0.1', '[::1]'].includes(origin.hostname))))
    throw new Error('ADMIN_ORIGIN must be an HTTPS origin (HTTP is allowed only on loopback).');
  const expectedOrigin = origin.origin, rpID = origin.hostname, secure = origin.protocol === 'https:';
  const sessionName = secure ? '__Host-sm_admin' : 'sm_admin';
  const challengeName = secure ? '__Host-sm_admin_challenge' : 'sm_admin_challenge';
  const db = store.db;
  const data = new AdminData({ store, engine, connections, now });
  // Tokens never enter source control or logs. A bootstrap token grants enrollment,
  // never access to statistics, and is invalidated after the first verified passkey.
  const setupPath = dataDir ? join(dataDir, 'admin-enrollment.json') : null;
  const keyCount = () => db.prepare('SELECT COUNT(*) n FROM admin_passkeys').get().n;
  if (setupPath && !keyCount() && !existsSync(setupPath)) {
    mkdirSync(dataDir, { recursive: true, mode: 0o700 });
    writeFileSync(setupPath, JSON.stringify({ token: opaque(), expiresAt: now() + 86_400_000 }), { mode: 0o600, flag: 'wx' });
  }
  const enrollment = token => {
    if (!setupPath || typeof token !== 'string' || !/^[A-Za-z0-9_-]{43}$/.test(token)) return null;
    if (db.prepare('SELECT 1 FROM admin_used_enrollments WHERE hash=?').get(hash(token))) return null;
    let setup;
    try { setup = JSON.parse(readFileSync(setupPath, 'utf8')); } catch { return null; }
    if (setup.expiresAt <= now() || typeof setup.token !== 'string' || hash(token) !== hash(setup.token) || (keyCount() && !setup.recovery)) return null;
    return { hash: hash(token), recovery: Boolean(setup.recovery) };
  };
  const validEnrollment = entry => {
    if (!entry || !setupPath || db.prepare('SELECT 1 FROM admin_used_enrollments WHERE hash=?').get(entry.hash)) return false;
    let setup;
    try { setup = JSON.parse(readFileSync(setupPath, 'utf8')); } catch { return false; }
    return setup.expiresAt > now() && typeof setup.token === 'string' && hash(setup.token) === entry.hash && (!keyCount() || setup.recovery === true);
  };
  const challenges = new Map(), counters = new Map();
  const cookieValue = (req, name) => req.headers.cookie?.split(';').map(s => s.trim()).find(s => s.startsWith(`${name}=`))?.slice(name.length + 1);
  const cookie = (res, name, value, seconds) => res.setHeader('Set-Cookie', `${name}=${value}; Path=/; HttpOnly; SameSite=Strict; Max-Age=${seconds}${secure ? '; Secure' : ''}`);
  const session = req => {
    const value = cookieValue(req, sessionName);
    return value && /^[A-Za-z0-9_-]{43}$/.test(value) ? db.prepare('SELECT * FROM admin_sessions WHERE hash=? AND expires_at>?').get(hash(value), now()) : null;
  };
  const requireSession = (req, recent = false) => {
    const s = session(req);
    if (!s) fail('UNAUTHENTICATED', 'Accedi con la tua passkey.', 401);
    if (recent && now() - s.created_at > 300_000) fail('REAUTHENTICATE', 'Accedi di nuovo con la passkey per gestire le chiavi.', 401);
    return s;
  };
  const issueSession = (res, id) => {
    const token = opaque();
    db.prepare('INSERT INTO admin_sessions(hash,credential_id,created_at,expires_at) VALUES(?,?,?,?)').run(hash(token), id, now(), now() + 8 * 3_600_000);
    // Bound retained sessions, even if a browser never explicitly logs out.
    db.prepare('DELETE FROM admin_sessions WHERE hash IN (SELECT hash FROM admin_sessions ORDER BY created_at DESC,rowid DESC LIMIT -1 OFFSET 32)').run();
    cookie(res, sessionName, token, 8 * 3600);
  };
  const challenge = (req, res, value) => {
    if (challenges.size >= 1000) fail('RATE_LIMIT', 'Riprova tra poco.', 429);
    const old = cookieValue(req, challengeName); if (old) challenges.delete(hash(old));
    const token = opaque(); challenges.set(hash(token), { ...value, expiresAt: now() + 300_000 });
    cookie(res, challengeName, token, 300);
  };
  const takeChallenge = (req, type) => {
    const token = cookieValue(req, challengeName), key = token && hash(token), value = challenges.get(key);
    challenges.delete(key);
    if (!value || value.type !== type || value.expiresAt <= now()) fail('CHALLENGE_EXPIRED', 'Richiesta scaduta. Riprova.');
    return value;
  };
  const limit = (req, auth = false) => {
    const time = now();
    for (const [key, value] of counters) if (value.until <= time) counters.delete(key);
    for (const [key, value] of challenges) if (value.expiresAt <= time) challenges.delete(key);
    const key = `${auth ? 'auth' : 'all'}:${addressOf(req)}`;
    let value = counters.get(key);
    if (!value) {
      if (counters.size >= 5000) fail('RATE_LIMIT', 'Riprova più tardi.', 429);
      value = { count: 0, until: time + (auth ? 600_000 : 60_000) }; counters.set(key, value);
    }
    if (++value.count > (auth ? 30 : 240)) fail('RATE_LIMIT', 'Troppe richieste. Riprova più tardi.', 429);
  };
  async function handle(req, res, path) {
    if (path !== '/admin' && !path.startsWith('/admin/')) return false;
    res.setHeader('Cache-Control', 'no-store');
    res.setHeader('Referrer-Policy', 'no-referrer');
    res.setHeader('X-Robots-Tag', 'noindex, nofollow, noarchive');
    res.setHeader('Content-Security-Policy', "default-src 'none'; script-src 'self'; style-src 'self'; img-src 'self' data:; connect-src 'self'; base-uri 'none'; form-action 'self'; frame-ancestors 'none'");
    const reply = (status, value) => { res.writeHead(status, { 'Content-Type': 'application/json; charset=utf-8' }); res.end(JSON.stringify(value)); };
    try {
      limit(req);
      if (path.startsWith('/admin/api/')) {
        if (req.headers['sec-fetch-site'] === 'cross-site' || (req.headers.origin && req.headers.origin !== expectedOrigin))
          fail('ORIGIN_DENIED', 'Origine non autorizzata.', 403);
        if (req.method === 'POST' && req.headers.origin !== expectedOrigin) fail('ORIGIN_DENIED', 'Origine non autorizzata.', 403);
        const route = `${req.method} ${path}`;
        if (route === 'GET /admin/api/status') {
          reply(200, { configured: keyCount() > 0, authenticated: Boolean(session(req)) });
        } else if (route === 'POST /admin/api/register/options') {
          limit(req, true);
          const input = await readJsonBody(req), setup = enrollment(input.setupToken);
          const s = setup ? null : requireSession(req, true);
          if (keyCount() >= 10) fail('KEY_LIMIT', 'Puoi registrare fino a 10 passkey.', 409);
          const options = await generateRegistrationOptions({ rpName: 'SommoMemory Admin', rpID,
            userID: new TextEncoder().encode('sommomemory-administrator'), userName: 'SommoMemory Admin',
            userDisplayName: 'SommoMemory Admin', attestationType: 'none', supportedAlgorithmIDs: [-7, -257],
            authenticatorSelection: { residentKey: 'required', userVerification: 'required' },
            excludeCredentials: db.prepare('SELECT id,transports FROM admin_passkeys').all().map(k => ({ id: k.id, transports: JSON.parse(k.transports) })) });
          challenge(req, res, { type: 'register', challenge: options.challenge, setup,
            sessionHash: s?.hash, label: [...String(input.label || 'La mia passkey').trim()].slice(0, 60).join('') || 'La mia passkey' });
          reply(200, options);
        } else if (route === 'POST /admin/api/register/verify') {
          limit(req, true);
          const input = await readJsonBody(req), entry = takeChallenge(req, 'register');
          const authorized = () => entry.setup ? validEnrollment(entry.setup) : requireSession(req, true).hash === entry.sessionHash;
          if (!authorized()) fail('ENROLLMENT_EXPIRED', 'Attivazione scaduta o già utilizzata.', 403);
          let verification;
          try { verification = await verifyRegistrationResponse({ response: input, expectedChallenge: entry.challenge,
            expectedOrigin, expectedRPID: rpID, requireUserVerification: true, supportedAlgorithmIDs: [-7, -257] }); }
          catch { fail('INVALID_PASSKEY', 'Non è stato possibile verificare la passkey.'); }
          if (!verification.verified) fail('INVALID_PASSKEY', 'Passkey non verificata.');
          // Check again after the asynchronous crypto operation: two tabs cannot
          // use the same bootstrap or a revoked session concurrently.
          if (!authorized()) fail('ENROLLMENT_EXPIRED', 'Attivazione già utilizzata.', 403);
          const { credential } = verification.registrationInfo;
          if (keyCount() >= 10 || db.prepare('SELECT 1 FROM admin_passkeys WHERE id=?').get(credential.id)) fail('KEY_LIMIT', 'Passkey già registrata o limite raggiunto.', 409);
          store.transaction(() => {
            db.prepare('INSERT INTO admin_passkeys(id,public_key,counter,transports,label,created_at) VALUES(?,?,?,?,?,?)')
              .run(credential.id, credential.publicKey, credential.counter, JSON.stringify(credential.transports ?? []), entry.label, now());
            if (entry.setup) db.prepare('INSERT INTO admin_used_enrollments(hash,used_at) VALUES(?,?)').run(entry.setup.hash, now());
            if (entry.setup?.recovery) db.prepare('DELETE FROM admin_sessions').run();
          });
          if (entry.setup) {
            // The consumed hash independently prevents replay even if a private
            // file is restored from backup or cannot currently be removed.
            try { unlinkSync(setupPath); } catch { console.error('Unable to remove consumed admin enrollment file.'); }
          }
          issueSession(res, credential.id); reply(200, { ok: true });
        } else if (route === 'POST /admin/api/login/options') {
          limit(req, true); await readJsonBody(req);
          const options = await generateAuthenticationOptions({ rpID, userVerification: 'required' });
          challenge(req, res, { type: 'login', challenge: options.challenge }); reply(200, options);
        } else if (route === 'POST /admin/api/login/verify') {
          limit(req, true);
          const input = await readJsonBody(req), entry = takeChallenge(req, 'login');
          const key = typeof input.id === 'string' && db.prepare('SELECT * FROM admin_passkeys WHERE id=?').get(input.id);
          if (!key) fail('INVALID_PASSKEY', 'Passkey non riconosciuta.', 401);
          let verification;
          try { verification = await verifyAuthenticationResponse({ response: input, expectedChallenge: entry.challenge,
            expectedOrigin, expectedRPID: rpID, requireUserVerification: true,
            credential: { id: key.id, publicKey: new Uint8Array(key.public_key), counter: key.counter, transports: JSON.parse(key.transports) } }); }
          catch { fail('INVALID_PASSKEY', 'Non è stato possibile verificare la passkey.', 401); }
          if (!verification.verified) fail('INVALID_PASSKEY', 'Passkey non verificata.', 401);
          // A concurrent deletion/recovery must not revive the credential.
          const current = db.prepare('SELECT counter FROM admin_passkeys WHERE id=?').get(key.id);
          if (!current || (current.counter > 0 && verification.authenticationInfo.newCounter <= current.counter)) fail('INVALID_PASSKEY', 'Ripeti l’accesso.', 401);
          db.prepare('UPDATE admin_passkeys SET counter=?,last_used_at=? WHERE id=?').run(verification.authenticationInfo.newCounter, now(), key.id);
          const previous = session(req); if (previous) db.prepare('DELETE FROM admin_sessions WHERE hash=?').run(previous.hash);
          issueSession(res, key.id); reply(200, { ok: true });
        } else {
          const s = requireSession(req);
          if (route === 'GET /admin/api/dashboard') reply(200, data.snapshot(new URL(req.url, expectedOrigin).searchParams));
          else if (route === 'POST /admin/api/logout') {
            await readJsonBody(req); db.prepare('DELETE FROM admin_sessions WHERE hash=?').run(s.hash);
            cookie(res, sessionName, '', 0); reply(200, { ok: true });
          } else if (route === 'GET /admin/api/passkeys') reply(200, { items: db.prepare('SELECT id,label,created_at createdAt,last_used_at lastUsedAt FROM admin_passkeys ORDER BY created_at').all() });
          else if (route === 'POST /admin/api/passkeys/remove') {
            requireSession(req, true); const input = await readJsonBody(req);
            if (keyCount() <= 1) fail('LAST_PASSKEY', 'Registra un’altra passkey prima di rimuovere l’ultima.', 409);
            if (typeof input.id !== 'string' || !db.prepare('DELETE FROM admin_passkeys WHERE id=?').run(input.id).changes) fail('NOT_FOUND', 'Passkey non trovata.', 404);
            reply(200, { ok: true });
          } else fail('NOT_FOUND', 'Pagina non trovata.', 404);
        }
      } else {
        if (!['GET', 'HEAD'].includes(req.method)) fail('METHOD_NOT_ALLOWED', 'Metodo non consentito.', 405);
        const files = {
          '/admin': ['admin.html', 'text/html; charset=utf-8'], '/admin/': ['admin.html', 'text/html; charset=utf-8'],
          '/admin/admin.js': ['admin.js', 'text/javascript; charset=utf-8'], '/admin/admin.css': ['admin.css', 'text/css; charset=utf-8'],
          '/admin/webauthn.js': ['../node_modules/@simplewebauthn/browser/dist/bundle/index.umd.min.js', 'text/javascript; charset=utf-8'],
        };
        if (!Object.hasOwn(files, path)) fail('NOT_FOUND', 'Pagina non trovata.', 404);
        const [file, type] = files[path]; res.writeHead(200, { 'Content-Type': type });
        if (req.method === 'HEAD') res.end(); else createReadStream(join(here, '../public', file)).on('error', () => res.destroy()).pipe(res);
      }
    } catch (error) {
      const safe = error instanceof EconomyError;
      if (!safe) console.error('Admin request failed.');
      const status = safe ? error.status : 500;
      if ([408, 413, 415].includes(status)) res.setHeader('Connection', 'close');
      reply(status, { error: { code: safe ? error.code : 'SERVER_ERROR', message: safe ? error.message : 'Servizio non disponibile. Riprova tra poco.' } });
    }
    return true;
  }
  return { handle, data, close() { data.close(); challenges.clear(); counters.clear(); } };
}
