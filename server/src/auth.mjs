import { createCipheriv, createDecipheriv, createHash, createHmac, randomBytes } from 'node:crypto';
import { readFileSync } from 'node:fs';
import { createRemoteJWKSet, importPKCS8, jwtVerify, SignJWT } from 'jose';
import { EconomyError, PROFILE_AVATARS, PROFILE_ACCENTS } from './economy.mjs';
import { authHttp } from './auth-http.mjs';

const MINUTE = 60_000, DAY = 86_400_000;
const opaque = () => randomBytes(32).toString('base64url');
const hash = value => createHash('sha256').update(value).digest('hex');
const fail = (code, message, status = 400) => { throw new EconomyError(code, message, status); };
const keyPattern = /^[A-Za-z0-9_-]{8,80}$/;
const googleKeys = createRemoteJWKSet(new URL('https://www.googleapis.com/oauth2/v3/certs'));
const appleKeys = createRemoteJWKSet(new URL('https://appleid.apple.com/auth/keys'));

export function loadAuthConfig(env = process.env) {
  const list = value => [...new Set((value || '').split(',').map(s => s.trim()).filter(Boolean))];
  const google = { webClientId: env.AUTH_GOOGLE_WEB_CLIENT_ID || '', iosClientId: env.AUTH_GOOGLE_IOS_CLIENT_ID || '',
    androidClientId: env.AUTH_GOOGLE_ANDROID_CLIENT_ID || '' };
  google.clientIds = list([google.webClientId, google.iosClientId, google.androidClientId, env.AUTH_GOOGLE_CLIENT_IDS].join(','));
  const apple = { appId: env.AUTH_APPLE_APP_ID || 'cc.sommomi.mymemory', serviceId: env.AUTH_APPLE_SERVICE_ID || '',
    teamId: env.AUTH_APPLE_TEAM_ID || '', keyId: env.AUTH_APPLE_KEY_ID || '', privateKeyFile: env.AUTH_APPLE_PRIVATE_KEY_FILE || '',
    redirectUri: env.AUTH_APPLE_REDIRECT_URI || '', returnOrigin: env.AUTH_PUBLIC_ORIGIN || 'https://sommomemory.sommomi.cc' };
  return { google, apple };
}

export function createAuthService(options) { return new AuthService(options); }

export class AuthService {
  constructor({ store, config = loadAuthConfig(), now = Date.now, verifyIdentity, fetch: fetcher = globalThis.fetch,
    onProfileDeleted = () => {}, keySets = { google: googleKeys, apple: appleKeys } } = {}) {
    this.store = store; this.db = store.db; this.now = now; this.config = config;
    this.verifyOverride = verifyIdentity; this.fetch = fetcher; this.onProfileDeleted = onProfileDeleted;
    this.keys = keySets;
    this.revokingSubjects = new Set();
    this.shutdownController = new AbortController();
    if (config.apple?.returnOrigin) {
      let origin;
      try { origin = new URL(config.apple.returnOrigin); } catch { throw new Error('AUTH_PUBLIC_ORIGIN must be an HTTPS origin'); }
      if (origin.protocol !== 'https:' || origin.username || origin.password || origin.search || origin.hash || origin.pathname !== '/')
        throw new Error('AUTH_PUBLIC_ORIGIN must be an HTTPS origin without credentials, path, query or fragment');
    }
    // Domain separation keeps authentication ciphertext independent of game capabilities.
    this.encryptionKey = createHmac('sha256', store.capabilityKey).update('sommomemory-auth-encryption-v1').digest();
    this.db.exec(`CREATE TABLE IF NOT EXISTS auth_attempts (
      id TEXT PRIMARY KEY, token_hash TEXT NOT NULL REFERENCES tokens(hash) ON DELETE CASCADE,
      provider TEXT NOT NULL, platform TEXT NOT NULL, operation TEXT NOT NULL,
      nonce TEXT NOT NULL, state TEXT NOT NULL UNIQUE, created_at INTEGER NOT NULL, expires_at INTEGER NOT NULL,
      status TEXT NOT NULL DEFAULT 'new', proof TEXT, confirmation_hash TEXT, handoff_hash TEXT,
      request_id TEXT NOT NULL, result TEXT, UNIQUE(token_hash,request_id)
    );
    CREATE TABLE IF NOT EXISTS auth_revocations (
      id TEXT PRIMARY KEY, credential TEXT NOT NULL, created_at INTEGER NOT NULL, next_at INTEGER NOT NULL,
      attempts INTEGER NOT NULL DEFAULT 0
    );
    CREATE TABLE IF NOT EXISTS auth_notifications (id TEXT PRIMARY KEY, expires_at INTEGER NOT NULL);`);
    if (!this.db.prepare('PRAGMA table_info(auth_attempts)').all().some(column => column.name === 'identity_hash'))
      this.db.exec('ALTER TABLE auth_attempts ADD COLUMN identity_hash TEXT');
    this.http = authHttp(this);
    this.clean();
  }
  encrypt(value) {
    const iv = randomBytes(12), cipher = createCipheriv('aes-256-gcm', this.encryptionKey, iv);
    const data = Buffer.concat([cipher.update(JSON.stringify(value), 'utf8'), cipher.final()]);
    return Buffer.concat([iv, cipher.getAuthTag(), data]).toString('base64url');
  }
  decrypt(value) {
    const bytes = Buffer.from(value, 'base64url');
    const decipher = createDecipheriv('aes-256-gcm', this.encryptionKey, bytes.subarray(0, 12));
    decipher.setAuthTag(bytes.subarray(12, 28));
    return JSON.parse(Buffer.concat([decipher.update(bytes.subarray(28)), decipher.final()]).toString('utf8'));
  }
  identityTag(identity) {
    return createHmac('sha256', this.encryptionKey).update(`identity:${identity.provider}:${identity.issuer}:${identity.subject}`).digest('hex');
  }
  providerConfig(provider, platform) {
    if (!['ios', 'android', 'web'].includes(platform)) fail('INVALID_PLATFORM', 'Piattaforma non valida.');
    if (provider === 'google') {
      const g = this.config.google || {};
      if (!g.webClientId || !g.clientIds?.length || (platform === 'ios' && !g.iosClientId)) return null;
      return { id: 'google', clientId: platform === 'ios' ? g.iosClientId : g.webClientId, serverClientId: g.webClientId };
    }
    if (provider === 'apple') {
      const a = this.config.apple || {};
      if (!a.teamId || !a.keyId || !a.privateKeyFile || !a.appId) return null;
      if (platform !== 'ios' && (!a.serviceId || !a.redirectUri || !/^https:\/\//.test(a.redirectUri))) return null;
      return { id: 'apple', clientId: platform === 'ios' ? a.appId : a.serviceId, redirectUri: a.redirectUri || '' };
    }
    return null;
  }
  providers(platform = 'web') {
    return { providers: ['apple', 'google'].map(p => this.providerConfig(p, platform)).filter(Boolean),
      avatars: PROFILE_AVATARS, accents: PROFILE_ACCENTS };
  }
  tokenRow(token) {
    this.store.authenticate(token);
    return this.db.prepare('SELECT * FROM tokens WHERE hash=?').get(hash(token));
  }
  requireRecent(token) {
    const row = this.tokenRow(token);
    if (this.store.profile(row.profile_id).linkedProviders.length &&
      (!row.verified_at || row.verified_at < this.now() - 5 * MINUTE))
      fail('REAUTH_REQUIRED', 'Verifica di nuovo l’accesso per continuare.', 403);
    return row;
  }
  verifyRecovery(token, { recoveryCode }) {
    const row = this.tokenRow(token);
    if (this.store.recoveryProfile(recoveryCode).id !== row.profile_id)
      fail('INVALID_RECOVERY', 'Il codice appartiene a un altro profilo.', 401);
    this.markVerified(row.hash);
    return { verified: true, expiresAt: this.now() + 5 * MINUTE };
  }
  markVerified(tokenHash) { this.db.prepare('UPDATE tokens SET verified_at=? WHERE hash=?').run(this.now(), tokenHash); }
  attempt(token, { provider, platform, operation = 'login', requestId }) {
    const row = this.tokenRow(token), config = this.providerConfig(provider, platform);
    if (!config) fail('PROVIDER_UNAVAILABLE', 'Questo metodo di accesso non è disponibile.', 503);
    if (!['login', 'link', 'reauth'].includes(operation) || !keyPattern.test(requestId || ''))
      fail('INVALID_AUTH_ATTEMPT', 'Richiesta di accesso non valida.');
    if (operation === 'link') this.requireRecent(token);
    const old = this.db.prepare('SELECT * FROM auth_attempts WHERE token_hash=? AND request_id=?').get(row.hash, requestId);
    if (old) {
      if (old.provider !== provider || old.platform !== platform || old.operation !== operation)
        fail('IDEMPOTENCY_CONFLICT', 'Identificativo già usato per un’altra operazione.', 409);
      if (old.expires_at <= this.now()) fail('AUTH_EXPIRED', 'L’accesso è scaduto. Riprova.', 410);
      return this.attemptView(old);
    }
    this.clean();
    if (this.db.prepare('SELECT COUNT(*) AS n FROM auth_attempts WHERE token_hash=?').get(row.hash).n >= 20)
      fail('AUTH_LIMIT', 'Troppi accessi recenti. Riprova più tardi.', 429);
    const item = { id: opaque(), token_hash: row.hash, provider, platform, operation, nonce: opaque(), state: opaque(),
      created_at: this.now(), expires_at: this.now() + 10 * MINUTE, request_id: requestId };
    this.db.prepare(`INSERT INTO auth_attempts(id,token_hash,provider,platform,operation,nonce,state,created_at,expires_at,request_id)
      VALUES(?,?,?,?,?,?,?,?,?,?)`).run(item.id, row.hash, provider, platform, operation, item.nonce, item.state, item.created_at, item.expires_at, requestId);
    return this.attemptView(item);
  }
  attemptView(item) {
    return { attemptId: item.id, nonce: item.nonce, state: item.state, expiresAt: item.expires_at,
      ...this.providerConfig(item.provider, item.platform) };
  }
  getAttempt(token, id) {
    const row = this.tokenRow(token);
    const attempt = typeof id === 'string' ? this.db.prepare('SELECT * FROM auth_attempts WHERE id=? AND token_hash=?').get(id, row.hash) : null;
    if (!attempt) fail('INVALID_AUTH_ATTEMPT', 'Accesso non valido.', 401);
    if (attempt.expires_at <= this.now()) fail('AUTH_EXPIRED', 'L’accesso è scaduto. Riprova.', 410);
    return attempt;
  }
  async appleSecret(clientId) {
    const a = this.config.apple;
    const key = await importPKCS8(readFileSync(a.privateKeyFile, 'utf8'), 'ES256');
    return new SignJWT({}).setProtectedHeader({ alg: 'ES256', kid: a.keyId }).setIssuer(a.teamId)
      .setSubject(clientId).setAudience('https://appleid.apple.com').setIssuedAt().setExpirationTime('5m').sign(key);
  }
  async postApple(path, values) {
    this.shutdownController.signal.throwIfAborted();
    const response = await this.fetch(`https://appleid.apple.com/auth/${path}`, {
      method: 'POST', headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: new URLSearchParams(values), signal: AbortSignal.any([this.shutdownController.signal, AbortSignal.timeout(10_000)]) });
    const text = await response.text();
    let result = {};
    try { if (text) result = JSON.parse(text); }
    catch { fail('PROVIDER_ERROR', 'Risposta Apple non valida. Riprova.', 503); }
    if (!response.ok) {
      if (result.error === 'invalid_grant') fail('PROVIDER_REVOKED', 'L’autorizzazione Apple non è più valida.', 401);
      fail('PROVIDER_ERROR', 'Apple non è disponibile. Riprova.', 503);
    }
    return result;
  }
  async verify(provider, input, attempt) {
    if (this.verifyOverride) return this.verifyOverride(provider, input, attempt);
    if (typeof input.idToken !== 'string' || input.idToken.length > 16_384)
      fail('INVALID_IDENTITY', 'Credenziale di accesso non valida.', 401);
    const config = this.providerConfig(provider, attempt.platform);
    if (!config) fail('PROVIDER_UNAVAILABLE', 'Metodo di accesso non disponibile.', 503);
    let payload;
    try {
      ({ payload } = await jwtVerify(input.idToken, this.keys[provider],
        { issuer: provider === 'google' ? ['https://accounts.google.com', 'accounts.google.com'] : 'https://appleid.apple.com',
          audience: provider === 'google' ? this.config.google.clientIds : config.clientId,
          algorithms: ['RS256'], clockTolerance: 5, requiredClaims: ['sub', 'iat', 'exp', 'nonce'], currentDate: new Date(this.now()) }));
    } catch { fail('INVALID_IDENTITY', 'Credenziale di accesso non valida o scaduta.', 401); }
    if (payload.nonce !== attempt.nonce || typeof payload.sub !== 'string' || !payload.sub || payload.sub.length > 255 ||
      !Number.isSafeInteger(payload.iat) || payload.iat <= 0 || payload.iat * 1000 > this.now() + 5000 ||
      (provider === 'google' && payload.azp !== undefined && !this.config.google.clientIds.includes(payload.azp)))
      fail('INVALID_IDENTITY', 'La credenziale non corrisponde a questo accesso.', 401);
    let credential = null;
    if (provider === 'apple') {
      if (typeof input.authorizationCode !== 'string' || !input.authorizationCode || input.authorizationCode.length > 4096)
        fail('INVALID_IDENTITY', 'Codice Apple non valido.', 401);
      const tokens = await this.postApple('token', { client_id: config.clientId, client_secret: await this.appleSecret(config.clientId),
        code: input.authorizationCode, grant_type: 'authorization_code',
        ...(attempt.platform !== 'ios' ? { redirect_uri: config.redirectUri } : {}) });
      let verified;
      try { ({ payload: verified } = await jwtVerify(tokens.id_token, this.keys.apple, { issuer: 'https://appleid.apple.com',
        audience: config.clientId, algorithms: ['RS256'], currentDate: new Date(this.now()) })); }
      catch { fail('INVALID_IDENTITY', 'Conferma Apple non valida.', 401); }
      if (verified.sub !== payload.sub || verified.nonce !== attempt.nonce || typeof tokens.refresh_token !== 'string')
        fail('INVALID_IDENTITY', 'Conferma Apple non valida.', 401);
      credential = { refreshToken: tokens.refresh_token, clientId: config.clientId };
    }
    return { provider, issuer: provider === 'google' ? 'https://accounts.google.com' : 'https://appleid.apple.com',
      subject: payload.sub, credential, grantIssuedAt: provider === 'apple' ? payload.iat : 0 };
  }
  async exchange(token, input) {
    const attempt = this.getAttempt(token, input.attemptId);
    if (attempt.status === 'revoked') fail('AUTH_RESTART_REQUIRED', 'L’autorizzazione è cambiata. Ripeti l’accesso.', 409);
    if (attempt.status === 'ready' || attempt.status === 'done') {
      if (attempt.handoff_hash && hash(input.authorizationCode || '') !== attempt.handoff_hash)
        fail('INVALID_HANDOFF', 'Ritorno dall’accesso non valido.', 401);
      return this.preview(attempt);
    }
    if (attempt.status !== 'new') fail('AUTH_IN_PROGRESS', 'Accesso già in corso. Riprova.', 409);
    if (input.state !== undefined && input.state !== attempt.state) fail('INVALID_STATE', 'Accesso non valido.', 401);
    this.db.prepare("UPDATE auth_attempts SET status='checking' WHERE id=? AND status='new'").run(attempt.id);
    let identity;
    try {
      identity = await this.verify(attempt.provider, input, attempt);
      return this.prepare(attempt, identity);
    } catch (error) {
      if (identity) this.queueAbandoned(identity);
      this.db.prepare("UPDATE auth_attempts SET status='new' WHERE id=? AND status='checking'").run(attempt.id);
      if (error instanceof EconomyError) throw error;
      fail('PROVIDER_ERROR', 'Il servizio di accesso non è disponibile. Riprova.', 503);
    }
  }
  prepare(attempt, identity, handoff = null) {
    // Authentication may have been revoked while the network validation was pending.
    const source = this.db.prepare('SELECT profile_id FROM tokens WHERE hash=?').get(attempt.token_hash);
    if (!source || !this.store.hasProfile(source.profile_id)) fail('INVALID_TOKEN', 'Sessione non valida.', 401);
    if (this.now() >= attempt.expires_at) fail('AUTH_EXPIRED', 'L’accesso è scaduto.', 410);
    if (identity.provider !== attempt.provider || !identity.issuer || !identity.subject)
      fail('INVALID_IDENTITY', 'Identità non valida.', 401);
    if (this.revokingSubjects.has(this.identityTag(identity)))
      fail('AUTH_RESTART_REQUIRED', 'La revoca precedente è ancora in corso. Ripeti l’accesso fra poco.', 409);
    const linked = this.db.prepare('SELECT * FROM auth_identities WHERE provider=? AND issuer=? AND subject=?')
      .get(identity.provider, identity.issuer, identity.subject);
    this.requireCurrentGrant(identity, linked);
    let action;
    if (attempt.operation === 'reauth') {
      if (!linked || linked.profile_id !== source.profile_id) fail('WRONG_ACCOUNT', 'Usa un metodo già collegato a questo profilo.', 409);
      action = 'reauth';
    } else if (linked) {
      if (linked.profile_id === source.profile_id) action = 'same';
      else if (attempt.operation === 'link') fail('IDENTITY_CONFLICT', 'Questo accesso appartiene a un altro profilo.', 409);
      else action = 'switch';
    } else {
      if (this.db.prepare('SELECT 1 FROM auth_identities WHERE profile_id=? AND provider=?').get(source.profile_id, identity.provider))
        fail('PROVIDER_ALREADY_LINKED', 'Un altro account di questo provider è già collegato.', 409);
      action = 'link';
    }
    const confirmationId = opaque();
    const proof = { identity, action, targetId: linked?.profile_id || source.profile_id, confirmationId };
    this.db.prepare("UPDATE auth_attempts SET status='ready',proof=?,confirmation_hash=?,handoff_hash=?,expires_at=?,identity_hash=? WHERE id=?")
      .run(this.encrypt(proof), hash(confirmationId), handoff ? hash(handoff) : null, this.now() + 5 * MINUTE, this.identityTag(identity), attempt.id);
    return this.preview(this.db.prepare('SELECT * FROM auth_attempts WHERE id=?').get(attempt.id));
  }
  preview(attempt) {
    const proof = this.decrypt(attempt.proof);
    if (!this.store.hasProfile(proof.targetId)) fail('AUTH_RESTART_REQUIRED', 'Il profilo trovato non è più disponibile. Ripeti l’accesso.', 409);
    return { confirmationId: proof.confirmationId, action: proof.action, profile: this.store.profile(proof.targetId), expiresAt: attempt.expires_at };
  }
  requireCurrentGrant(identity, linked) {
    if (identity.provider === 'apple' && linked?.revoked_at &&
      (!Number.isSafeInteger(identity.grantIssuedAt) || identity.grantIssuedAt <= linked.revoked_at))
      fail('AUTH_RESTART_REQUIRED', 'L’autorizzazione è stata revocata. Ripeti l’accesso.', 409);
  }
  confirm(token, { confirmationId, confirmReplace, requestId }) {
    const source = this.tokenRow(token);
    if (typeof confirmationId !== 'string' || !keyPattern.test(requestId || '')) fail('INVALID_CONFIRMATION', 'Conferma non valida.');
    return this.store.transaction(() => {
      const attempt = this.db.prepare('SELECT * FROM auth_attempts WHERE token_hash=? AND confirmation_hash=?').get(source.hash, hash(confirmationId));
      if (attempt?.status === 'revoked') fail('AUTH_RESTART_REQUIRED', 'L’autorizzazione è cambiata. Ripeti l’accesso.', 409);
      if (!attempt || !['ready', 'done'].includes(attempt.status)) fail('INVALID_CONFIRMATION', 'Conferma non valida.', 401);
      if (attempt.expires_at <= this.now()) fail('AUTH_EXPIRED', 'La conferma è scaduta.', 410);
      if (attempt.status === 'done') {
        const cached = this.decrypt(attempt.result);
        if (cached.token) {
          try { this.store.authenticate(cached.token); }
          catch { fail('AUTH_RESTART_REQUIRED', 'La sessione precedente non è più valida. Ripeti l’accesso.', 409); }
        }
        if (!this.store.hasProfile(cached.profile.id)) fail('AUTH_RESTART_REQUIRED', 'Il profilo trovato non è più disponibile. Ripeti l’accesso.', 409);
        return { ...cached, profile: this.store.profile(cached.profile.id) };
      }
      const proof = this.decrypt(attempt.proof), { identity, action, targetId } = proof;
      if (this.revokingSubjects.has(this.identityTag(identity)))
        fail('AUTH_RESTART_REQUIRED', 'La revoca precedente è ancora in corso. Ripeti l’accesso fra poco.', 409);
      if (!this.store.hasProfile(targetId)) fail('AUTH_RESTART_REQUIRED', 'Il profilo trovato non è più disponibile. Ripeti l’accesso.', 409);
      if (action === 'switch' && confirmReplace !== true) fail('CONFIRM_RESTORE', 'Conferma il cambio di profilo.', 409);
      if (action === 'link' && this.store.profile(source.profile_id).linkedProviders.length) this.requireRecent(token);
      const existing = this.db.prepare('SELECT * FROM auth_identities WHERE provider=? AND issuer=? AND subject=?').get(identity.provider, identity.issuer, identity.subject);
      this.requireCurrentGrant(identity, existing);
      if ((action === 'link' && existing && existing.profile_id !== targetId) ||
        (action !== 'link' && (!existing || existing.profile_id !== targetId)))
        fail('IDENTITY_CONFLICT', 'Il collegamento è cambiato. Ripeti l’accesso.', 409);
      if (action === 'link') {
        const other = this.db.prepare('SELECT * FROM auth_identities WHERE profile_id=? AND provider=?').get(targetId, identity.provider);
        if (other && other.subject !== identity.subject) fail('PROVIDER_ALREADY_LINKED', 'Un altro account è già collegato.', 409);
        if (!existing) this.db.prepare('INSERT INTO auth_identities(profile_id,provider,issuer,subject,created_at,credential,client_id,checked_at,grant_issued_at) VALUES(?,?,?,?,?,?,?,?,?)')
          .run(targetId, identity.provider, identity.issuer, identity.subject, this.now(), identity.credential ? this.encrypt(identity.credential) : null,
            identity.credential?.clientId || null, this.now(), identity.grantIssuedAt || 0);
        this.db.prepare('UPDATE profiles SET revision=revision+1 WHERE id=?').run(targetId);
        this.db.prepare('UPDATE tokens SET expires_at=? WHERE profile_id=? AND expires_at=0').run(this.now() + 90 * DAY, targetId);
      } else if (identity.credential) {
        // Only explicit, nonce-bound authorization advances grant time. Daily
        // refresh checks must never make an earlier revocation appear obsolete.
        this.db.prepare('UPDATE auth_identities SET credential=?,client_id=?,checked_at=?,grant_issued_at=? WHERE provider=? AND issuer=? AND subject=? AND grant_issued_at<=?')
          .run(this.encrypt(identity.credential), identity.credential.clientId, this.now(), identity.grantIssuedAt || 0,
            identity.provider, identity.issuer, identity.subject, identity.grantIssuedAt || 0);
      }
      let result;
      if (action === 'switch') result = { token: this.store.issueToken(targetId, { verified: true }), profile: this.store.profile(targetId) };
      else { this.markVerified(source.hash); result = { profile: this.store.profile(targetId) }; }
      this.db.prepare("UPDATE auth_attempts SET status='done',result=?,proof=? WHERE id=?")
        .run(this.encrypt(result), this.encrypt({ ...proof, identity: { ...identity, credential: null } }), attempt.id);
      return result;
    });
  }
  identities(token) {
    const row = this.tokenRow(token);
    return { identities: this.db.prepare('SELECT provider,created_at AS createdAt FROM auth_identities WHERE profile_id=? ORDER BY provider').all(row.profile_id) };
  }
  sessions(token) {
    const row = this.tokenRow(token);
    return { sessions: this.db.prepare('SELECT id,device_name AS deviceName,created_at AS createdAt,last_used_at AS lastUsedAt,hash FROM tokens WHERE profile_id=? AND (expires_at=0 OR expires_at>?) ORDER BY created_at DESC').all(row.profile_id, this.now())
      .map(({ hash: tokenHash, ...session }) => ({ ...session, current: tokenHash === row.hash })) };
  }
  revokeSession(token, sessionId) {
    const row = this.requireRecent(token);
    const removed = this.db.prepare('DELETE FROM tokens WHERE id=? AND profile_id=?').run(sessionId, row.profile_id);
    if (!removed.changes) fail('SESSION_NOT_FOUND', 'Dispositivo non trovato.', 404);
    return { revoked: true, current: sessionId === row.id };
  }
  queueRevocation(identity) {
    if (identity.provider === 'apple' && identity.credential) {
      const credential = typeof identity.credential === 'string' ? this.decrypt(identity.credential) : identity.credential;
      this.db.prepare('INSERT INTO auth_revocations(id,credential,created_at,next_at) VALUES(?,?,?,?)')
        .run(opaque(), this.encrypt({ ...credential, subject: identity.subject, issuer: identity.issuer }), this.now(), this.now());
    }
  }
  queueAbandoned(identity) {
    if (identity.provider === 'apple' && identity.credential &&
      !this.db.prepare('SELECT 1 FROM auth_identities WHERE provider=? AND issuer=? AND subject=?').get(identity.provider, identity.issuer, identity.subject))
      this.queueRevocation(identity);
  }
  unlink(token, provider) {
    const row = this.requireRecent(token);
    return this.store.transaction(() => {
      const profile = this.store.profile(row.profile_id);
      const identity = this.db.prepare('SELECT * FROM auth_identities WHERE profile_id=? AND provider=?').get(row.profile_id, provider);
      if (!identity) fail('IDENTITY_NOT_FOUND', 'Metodo di accesso non trovato.', 404);
      if (profile.linkedProviders.length === 1 && !profile.recoveryEnabled)
        fail('LAST_AUTH_METHOD', 'Conserva un codice di recupero o collega un altro metodo prima di continuare.', 409);
      this.queueRevocation(identity);
      this.db.prepare('DELETE FROM auth_identities WHERE profile_id=? AND provider=?').run(row.profile_id, provider);
      this.db.prepare('UPDATE profiles SET revision=revision+1 WHERE id=?').run(row.profile_id);
      return { profile: this.store.profile(row.profile_id) };
    });
  }
  deleteProfile(token, input) {
    const row = this.requireRecent(token);
    if (input.confirmDelete !== true) fail('CONFIRM_DELETE', 'Conferma l’eliminazione del profilo.', 409);
    const result = this.store.deleteProfile(row.profile_id, input, () => {
      for (const identity of this.db.prepare('SELECT * FROM auth_identities WHERE profile_id=?').all(row.profile_id)) this.queueRevocation(identity);
    });
    this.onProfileDeleted(row.profile_id);
    return result;
  }
  async callback(input) {
    const attempt = typeof input.state === 'string' ? this.db.prepare('SELECT * FROM auth_attempts WHERE state=?').get(input.state) : null;
    if (!attempt || attempt.provider !== 'apple' || attempt.platform === 'ios' || attempt.expires_at <= this.now() || attempt.status !== 'new')
      fail('INVALID_STATE', 'Questo accesso non è più valido.', 401);
    if (input.error) fail('AUTH_CANCELLED', 'Accesso annullato.');
    this.db.prepare("UPDATE auth_attempts SET status='checking' WHERE id=?").run(attempt.id);
    let identity;
    try {
      identity = await this.verify('apple', { idToken: input.id_token, authorizationCode: input.code }, attempt);
      const handoff = opaque();
      this.prepare(attempt, identity, handoff);
      return { platform: attempt.platform, state: attempt.state, handoff };
    } catch (error) {
      if (identity) this.queueAbandoned(identity);
      this.db.prepare("UPDATE auth_attempts SET status='new' WHERE id=? AND status='checking'").run(attempt.id);
      throw error;
    }
  }
  async notification({ payload: signed }) {
    if (typeof signed !== 'string' || signed.length > 16_384) fail('INVALID_NOTIFICATION', 'Notifica non valida.', 401);
    let payload;
    try { ({ payload } = await jwtVerify(signed, this.keys.apple, { issuer: 'https://appleid.apple.com',
      audience: [this.config.apple.appId, this.config.apple.serviceId].filter(Boolean), algorithms: ['RS256'],
      requiredClaims: ['iat', 'jti', 'events'], maxTokenAge: '1h', currentDate: new Date(this.now()) })); }
    catch { fail('INVALID_NOTIFICATION', 'Notifica non valida.', 401); }
    if (typeof payload.jti !== 'string' || !payload.jti || payload.jti.length > 255)
      fail('INVALID_NOTIFICATION', 'Notifica non valida.', 401);
    if (this.db.prepare('SELECT 1 FROM auth_notifications WHERE id=?').get(payload.jti)) return { received: true };
    let event;
    try { event = typeof payload.events === 'string' ? JSON.parse(payload.events) : payload.events; } catch { fail('INVALID_NOTIFICATION', 'Notifica non valida.'); }
    if (!event || typeof event.sub !== 'string') fail('INVALID_NOTIFICATION', 'Notifica non valida.');
    // Apple signs the occurrence time separately from the notification's iat.
    // A delayed delivery may be signed after a newer authorization completed.
    const stateChange = ['consent-revoked', 'account-deleted', 'account-delete'].includes(event.type);
    if (stateChange && (!Number.isSafeInteger(event.event_time) || event.event_time <= 0 || event.event_time > Math.floor(this.now() / 1000) + 5))
      fail('INVALID_NOTIFICATION', 'Data della notifica non valida.');
    const identity = this.db.prepare("SELECT * FROM auth_identities WHERE provider='apple' AND issuer='https://appleid.apple.com' AND subject=?").get(event.sub);
    if (identity && stateChange) {
      // Canonical Apple event is account-deleted; keep the old internal spelling
      // account-delete as an alias for compatibility with existing integrations.
      if (event.type === 'account-deleted' || event.type === 'account-delete') {
        this.store.deleteProfile(identity.profile_id, { confirmDelete: true }); this.onProfileDeleted(identity.profile_id);
      } else this.invalidateIdentity(identity, { revokedAt: event.event_time });
    }
    this.db.prepare('INSERT INTO auth_notifications(id,expires_at) VALUES(?,?)').run(payload.jti, this.now() + DAY);
    return { received: true };
  }
  invalidateIdentity(identity, { revokedAt = 0 } = {}) {
    return this.store.transaction(() => {
      const current = this.db.prepare('SELECT profile_id,credential,grant_issued_at FROM auth_identities WHERE provider=? AND issuer=? AND subject=?')
        .get(identity.provider, identity.issuer, identity.subject);
      // An old daily token check can finish after a new authorization. Its result
      // must not invalidate that newly confirmed grant or its sessions.
      if (!current || current.profile_id !== identity.profile_id || current.credential !== identity.credential) return false;
      if (revokedAt) this.db.prepare('UPDATE auth_identities SET revoked_at=MAX(revoked_at,?) WHERE provider=? AND issuer=? AND subject=?')
        .run(revokedAt, identity.provider, identity.issuer, identity.subject);
      // Ignore only strictly older events. Same-second timestamps cannot prove
      // which happened last, so revocation wins until a later authorization.
      if (revokedAt && revokedAt < current.grant_issued_at) return false;
      // Keep the stable subject association so a later reconsent restores this
      // exact wallet, including when Apple was its only recovery method.
      this.db.prepare('UPDATE auth_identities SET credential=NULL,checked_at=?,revoked_at=MAX(revoked_at,?) WHERE provider=? AND issuer=? AND subject=?')
        .run(this.now(), revokedAt, identity.provider, identity.issuer, identity.subject);
      this.db.prepare('DELETE FROM tokens WHERE profile_id=?').run(identity.profile_id);
      this.db.prepare('UPDATE profiles SET revision=revision+1 WHERE id=?').run(identity.profile_id);
      return true;
    });
  }
  clean() {
    for (const attempt of this.db.prepare("SELECT proof FROM auth_attempts WHERE expires_at<=? AND status='ready' AND proof IS NOT NULL").all(this.now()))
      this.queueAbandoned(this.decrypt(attempt.proof).identity);
    this.db.prepare('DELETE FROM auth_attempts WHERE expires_at<=?').run(this.now());
    this.db.prepare('DELETE FROM auth_notifications WHERE expires_at<=?').run(this.now());
    this.db.prepare('DELETE FROM auth_revocations WHERE created_at<?').run(this.now() - 30 * DAY);
  }
  maintenance() {
    if (this.closed) return Promise.resolve();
    return this.maintenancePromise ??= this.runMaintenance().finally(() => { this.maintenancePromise = null; });
  }
  async runMaintenance() {
    try {
      this.clean();
      for (const row of this.db.prepare('SELECT * FROM auth_revocations WHERE next_at<=? ORDER BY created_at LIMIT 10').all(this.now())) {
        if (this.closed) return;
        let revokingTag;
        try {
          const credential = this.decrypt(row.credential);
          // A later explicit relink/reconsent supersedes the old cancellation or
          // unlink request. Revoking its old refresh token would revoke the new grant too.
          if (credential.subject && this.db.prepare("SELECT 1 FROM auth_identities WHERE provider='apple' AND issuer=? AND subject=?")
            .get(credential.issuer || 'https://appleid.apple.com', credential.subject)) {
            this.db.prepare('DELETE FROM auth_revocations WHERE id=?').run(row.id); continue;
          }
          if (credential.subject) {
            revokingTag = this.identityTag({ provider: 'apple', issuer: credential.issuer || 'https://appleid.apple.com', subject: credential.subject });
            this.revokingSubjects.add(revokingTag);
            this.db.prepare("UPDATE auth_attempts SET status='revoked',proof=NULL,handoff_hash=NULL WHERE identity_hash=? AND status='ready'").run(revokingTag);
          }
          await this.postApple('revoke', { client_id: credential.clientId, client_secret: await this.appleSecret(credential.clientId),
            token: credential.refreshToken, token_type_hint: 'refresh_token' });
          if (this.closed) return;
          this.db.prepare('DELETE FROM auth_revocations WHERE id=?').run(row.id);
        } catch (error) {
          if (this.closed || error.name === 'AbortError') return;
          if (error.code === 'PROVIDER_REVOKED') {
            this.db.prepare('DELETE FROM auth_revocations WHERE id=?').run(row.id); continue;
          }
          this.db.prepare('UPDATE auth_revocations SET attempts=attempts+1,next_at=? WHERE id=?')
            .run(this.now() + Math.min(DAY, 60_000 * 2 ** Math.min(row.attempts, 10)), row.id);
        } finally { if (revokingTag) this.revokingSubjects.delete(revokingTag); }
      }
      if (this.closed) return;
      for (const identity of this.db.prepare("SELECT * FROM auth_identities WHERE provider='apple' AND credential IS NOT NULL AND checked_at<? LIMIT 5").all(this.now() - DAY)) {
        if (this.closed) return;
        try {
          const credential = this.decrypt(identity.credential);
          await this.postApple('token', { client_id: credential.clientId, client_secret: await this.appleSecret(credential.clientId),
            refresh_token: credential.refreshToken, grant_type: 'refresh_token' });
        } catch (error) {
          if (this.closed || error.name === 'AbortError') return;
          if (error.code === 'PROVIDER_REVOKED') this.invalidateIdentity(identity);
        }
        if (this.closed) return;
        // Also back off transient provider errors; never invalidate on network failure.
        this.db.prepare('UPDATE auth_identities SET checked_at=? WHERE provider=? AND issuer=? AND subject=? AND profile_id=? AND credential IS ?')
          .run(this.now(), identity.provider, identity.issuer, identity.subject, identity.profile_id, identity.credential);
      }
    } finally { /* The owner awaits maintenance before closing SQLite. */ }
  }
  handle(req, res, pathname, context) { return this.http(req, res, pathname, context); }
  async close() {
    this.closed = true;
    this.shutdownController.abort(new DOMException('Authentication service is closing', 'AbortError'));
    this.http.close?.();
    await this.maintenancePromise;
  }
}
