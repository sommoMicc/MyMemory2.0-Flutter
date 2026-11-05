import test from 'node:test';
import assert from 'node:assert/strict';
import { generateKeyPair, SignJWT } from 'jose';
import { mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { EconomyStore } from '../src/economy.mjs';
import { createAuthService } from '../src/auth.mjs';

const config = { google: { webClientId: 'google-web', iosClientId: 'google-ios', clientIds: ['google-web', 'google-ios'] }, apple: {} };
const requestId = () => crypto.randomUUID();
function setup(options = {}) {
  const store = options.store || new EconomyStore();
  let clock = 1_800_000_000_000;
  const now = () => clock;
  store.now = now;
  const auth = createAuthService({ store, config, now, ...options });
  return { store, auth, now, advance: ms => { clock += ms; }, close: async () => { await auth.close(); store.close(); } };
}
const identity = subject => ({ provider: 'google', issuer: 'https://accounts.google.com', subject });
async function prepare(c, token, subject, operation = 'login') {
  const attempt = c.auth.attempt(token, { provider: 'google', platform: 'web', operation, requestId: requestId() });
  return c.auth.exchange(token, { attemptId: attempt.attemptId, idToken: subject });
}
const accept = (c, token, preview) => c.auth.confirm(token, { confirmationId: preview.confirmationId, confirmReplace: true, requestId: requestId() });

test('guest appearance validates catalog and old name-only clients preserve appearance', async () => {
  const c = setup();
  try {
    const guest = c.store.createProfile();
    c.store.updateProfile(guest.profile.id, { avatarId: 'owl', accentId: 'rose' });
    const renamed = c.store.updateProfile(guest.profile.id, { displayName: 'A\u0000lice' }).profile;
    assert.equal(renamed.displayName, 'Alice'); assert.equal(renamed.avatarId, 'owl'); assert.equal(renamed.accentId, 'rose');
    assert.throws(() => c.store.updateProfile(guest.profile.id, { avatarId: 'https://tracker.test/a' }), { code: 'INVALID_AVATAR' });
    assert.equal(c.auth.providers('web').providers[0].id, 'google');
    const unconfigured = createAuthService({ store: c.store, config: { google: {}, apple: {} } });
    assert.deepEqual(unconfigured.providers('ios').providers, []); await unconfigured.close();
  } finally { await c.close(); }
});

test('linking keeps guest wallet; switching needs confirmation, stays isolated and retry issues one token', async () => {
  const c = setup({ verifyIdentity: async (_, input) => identity(input.idToken) });
  try {
    const first = c.store.createProfile();
    const preview = await prepare(c, first.token, 'google-alice');
    assert.equal(preview.action, 'link'); assert.deepEqual(c.store.profile(first.profile.id).linkedProviders, []);
    const linked = accept(c, first.token, preview);
    assert.equal(linked.profile.id, first.profile.id); assert.equal(linked.profile.gems, 100);
    assert.deepEqual(linked.profile.linkedProviders, ['google']);
    assert.equal(c.store.db.prepare('SELECT COUNT(*) AS n FROM ledger WHERE profile_id=?').get(first.profile.id).n, 1);
    const second = c.store.createProfile();
    const switchPreview = await prepare(c, second.token, 'google-alice');
    assert.equal(switchPreview.action, 'switch');
    assert.throws(() => c.auth.confirm(second.token, { confirmationId: switchPreview.confirmationId, requestId: requestId() }), { code: 'CONFIRM_RESTORE' });
    const restored = accept(c, second.token, switchPreview), retry = accept(c, second.token, switchPreview);
    assert.equal(restored.token, retry.token); assert.equal(restored.profile.id, first.profile.id);
    assert.equal(c.store.profile(second.profile.id).gems, 100);
    const raw = c.store.db.prepare('SELECT proof,result FROM auth_attempts WHERE confirmation_hash IS NOT NULL').all();
    assert.ok(raw.every(row => !String(row.proof).includes('google-alice') && !String(row.result).includes(restored.token)));
  } finally { await c.close(); }
});

test('attempts bind source token, expire, distinguish login/link and prevent identity races', async () => {
  const c = setup({ verifyIdentity: async (_, input) => identity(input.idToken) });
  try {
    const a = c.store.createProfile(), b = c.store.createProfile();
    const attempt = c.auth.attempt(a.token, { provider: 'google', platform: 'web', requestId: requestId() });
    await assert.rejects(c.auth.exchange(b.token, { attemptId: attempt.attemptId, idToken: 'bob' }), { code: 'INVALID_AUTH_ATTEMPT' });
    await assert.rejects(c.auth.exchange(a.token, { attemptId: attempt.attemptId, idToken: 'bob', state: 'wrong' }), { code: 'INVALID_STATE' });
    const p1 = await c.auth.exchange(a.token, { attemptId: attempt.attemptId, idToken: 'bob' });
    const p2 = await prepare(c, b.token, 'bob'); accept(c, a.token, p1);
    assert.throws(() => accept(c, b.token, p2), { code: 'IDENTITY_CONFLICT' });
    await assert.rejects(prepare(c, b.token, 'bob', 'link'), { code: 'IDENTITY_CONFLICT' });
    const expired = await prepare(c, b.token, 'carol'); c.advance(301_000);
    assert.throws(() => accept(c, b.token, expired), { code: 'AUTH_EXPIRED' });
  } finally { await c.close(); }
});

test('fresh verification guards sensitive actions and last method; recovery restores access', async () => {
  const c = setup({ verifyIdentity: async (_, input) => identity(input.idToken) });
  try {
    const guest = c.store.createProfile(); accept(c, guest.token, await prepare(c, guest.token, 'alice'));
    assert.throws(() => c.auth.unlink(guest.token, 'google'), { code: 'LAST_AUTH_METHOD' });
    const recovery = c.store.recovery(guest.profile.id); c.advance(301_000);
    assert.throws(() => c.auth.requireRecent(guest.token), { code: 'REAUTH_REQUIRED' });
    assert.throws(() => c.auth.deleteProfile(guest.token, { confirmDelete: true }), { code: 'REAUTH_REQUIRED' });
    const otherRecovery = c.store.recovery(c.store.createProfile().profile.id);
    assert.throws(() => c.auth.verifyRecovery(guest.token, { recoveryCode: otherRecovery.recoveryCode }), { code: 'INVALID_RECOVERY' });
    c.auth.verifyRecovery(guest.token, { recoveryCode: recovery.recoveryCode });
    const restored = c.store.restore({ recoveryCode: recovery.recoveryCode, confirmReplace: true });
    assert.equal(c.auth.sessions(guest.token).sessions.length, 2);
    c.auth.revokeSession(guest.token, c.auth.sessions(guest.token).sessions.find(item => !item.current).id);
    assert.throws(() => c.store.authenticate(restored.token), { code: 'INVALID_TOKEN' });
    assert.deepEqual(c.auth.unlink(guest.token, 'google').profile.linkedProviders, []);
    assert.equal(c.store.recoveryProfile(recovery.recoveryCode).id, guest.profile.id);
  } finally { await c.close(); }
});

test('real signed Google tokens verify signature, nonce, issuer, audience and expiry', async () => {
  const { publicKey, privateKey } = await generateKeyPair('RS256'), otherKey = await generateKeyPair('RS256');
  const c = setup({ keySets: { google: publicKey } });
  try {
    const guest = c.store.createProfile();
    const attempt = c.auth.attempt(guest.token, { provider: 'google', platform: 'ios', requestId: requestId() });
    const sign = (claims = {}, key = privateKey) => new SignJWT({ nonce: attempt.nonce, ...claims }).setProtectedHeader({ alg: 'RS256' })
      .setIssuer(claims.iss || 'https://accounts.google.com').setSubject('stable-subject').setAudience(claims.aud || 'google-web')
      .setIssuedAt(Math.floor(c.now() / 1000)).setExpirationTime(claims.exp || Math.floor(c.now() / 1000) + 300).sign(key);
    for (const token of [await sign({ nonce: 'wrong' }), await sign({ aud: 'attacker-app' }), await sign({ iss: 'https://evil.example' }),
      await sign({ exp: Math.floor(c.now() / 1000) - 10 }), await sign({}, otherKey.privateKey)])
      await assert.rejects(c.auth.exchange(guest.token, { attemptId: attempt.attemptId, idToken: token }), { code: 'INVALID_IDENTITY' });
    const preview = await c.auth.exchange(guest.token, { attemptId: attempt.attemptId, idToken: await sign() });
    assert.equal(accept(c, guest.token, preview).profile.id, guest.profile.id);
  } finally { await c.close(); }
});

test('encrypted confirmation survives restart and never grants another welcome', async () => {
  const dir = mkdtempSync(join(tmpdir(), 'sommomemory-auth-'));
  let c = setup({ store: new EconomyStore({ dataDir: dir }), verifyIdentity: async (_, input) => identity(input.idToken) });
  const guest = c.store.createProfile(), preview = await prepare(c, guest.token, 'persistent-sub');
  try {
    await c.close(); c = setup({ store: new EconomyStore({ dataDir: dir }), verifyIdentity: async (_, input) => identity(input.idToken) });
    const result = accept(c, guest.token, preview);
    assert.equal(result.profile.id, guest.profile.id); assert.equal(result.profile.gems, 100);
    assert.equal(c.store.db.prepare('SELECT COUNT(*) AS n FROM profiles').get().n, 1);
  } finally { await c.close(); rmSync(dir, { recursive: true, force: true }); }
});

test('Apple encrypted revocation queue is atomic, retries errors and accepts empty successful responses', async () => {
  let failed = true, deleted = null;
  const c = setup({ onProfileDeleted: id => { deleted = id; }, fetch: async () => failed ? new Response('{"error":"server_error"}', { status: 503 }) : new Response(null, { status: 200 }) });
  c.auth.appleSecret = async () => 'test-secret';
  try {
    const guest = c.store.createProfile(), refresh = 'private-refresh-token';
    c.store.db.prepare('INSERT INTO auth_identities(profile_id,provider,issuer,subject,created_at,credential,client_id) VALUES(?,?,?,?,?,?,?)')
      .run(guest.profile.id, 'apple', 'https://appleid.apple.com', 'apple-sub', c.now(), c.auth.encrypt({ refreshToken: refresh, clientId: 'client' }), 'client');
    c.auth.markVerified(c.auth.tokenRow(guest.token).hash);
    assert.throws(() => c.auth.deleteProfile(guest.token, {}), { code: 'CONFIRM_DELETE' });
    assert.equal(c.store.db.prepare('SELECT COUNT(*) AS n FROM auth_revocations').get().n, 0);
    c.auth.deleteProfile(guest.token, { confirmDelete: true });
    assert.equal(deleted, guest.profile.id); assert.equal(c.store.hasProfile(guest.profile.id), false);
    assert.ok(!c.store.db.prepare('SELECT credential FROM auth_revocations').get().credential.includes(refresh));
    await c.auth.maintenance(); assert.equal(c.store.db.prepare('SELECT attempts FROM auth_revocations').get().attempts, 1);
    failed = false; c.advance(61_000); await c.auth.maintenance();
    assert.equal(c.store.db.prepare('SELECT COUNT(*) AS n FROM auth_revocations').get().n, 0);
  } finally { await c.close(); }
});

test('external consent revocation keeps the stable wallet for reconsent and invalidates every session', async () => {
  const c = setup();
  try {
    const guest = c.store.createProfile();
    c.store.db.prepare('INSERT INTO auth_identities(profile_id,provider,issuer,subject,created_at) VALUES(?,?,?,?,?)')
      .run(guest.profile.id, 'apple', 'https://appleid.apple.com', 'apple-stable', c.now());
    c.auth.invalidateIdentity(c.store.db.prepare('SELECT * FROM auth_identities WHERE profile_id=?').get(guest.profile.id));
    assert.throws(() => c.store.authenticate(guest.token), { code: 'INVALID_TOKEN' });
    assert.equal(c.store.profile(guest.profile.id).gems, 100);
    assert.equal(c.store.db.prepare('SELECT profile_id FROM auth_identities WHERE subject=?').get('apple-stable').profile_id, guest.profile.id);
  } finally { await c.close(); }
});

test('deletion leaves only short lived hash tombstones so known devices distinguish deletion from revocation', async () => {
  const c = setup();
  try {
    const guest = c.store.createProfile(); c.auth.deleteProfile(guest.token, { confirmDelete: true });
    assert.throws(() => c.store.authenticate(guest.token), { code: 'PROFILE_DELETED' });
    assert.deepEqual(Object.keys(c.store.db.prepare('SELECT * FROM deleted_tokens').get()), ['hash', 'expires_at']);
    c.advance(32 * 86_400_000); c.store.cleanup();
    assert.throws(() => c.store.authenticate(guest.token), { code: 'INVALID_TOKEN' });
    assert.equal(c.store.db.prepare('SELECT COUNT(*) AS n FROM deleted_tokens').get().n, 0);
  } finally { await c.close(); }
});

test('Apple code exchange encrypts revocation credentials and signed notifications revoke sessions without losing wallet', async () => {
  const { publicKey, privateKey } = await generateKeyPair('RS256');
  const apple = { appId: 'test.apple.app', serviceId: 'test.apple.web', teamId: 'TEAM', keyId: 'KEY',
    privateKeyFile: '/unused-in-test', redirectUri: 'https://example.test/api/v1/auth/callback/apple' };
  let responseToken, posted;
  const c = setup({ config: { ...config, apple }, keySets: { apple: publicKey },
    fetch: async (_, request) => { posted = request.body; return new Response(JSON.stringify({ id_token: responseToken, refresh_token: 'secret-apple-refresh' })); } });
  c.auth.appleSecret = async () => 'test-client-secret';
  try {
    const guest = c.store.createProfile();
    const attempt = c.auth.attempt(guest.token, { provider: 'apple', platform: 'ios', requestId: requestId() });
    const sign = payload => new SignJWT(payload).setProtectedHeader({ alg: 'RS256' }).setIssuer('https://appleid.apple.com')
      .setAudience(apple.appId).setIssuedAt(Math.floor(c.now() / 1000)).setExpirationTime(Math.floor(c.now() / 1000) + 300).sign(privateKey);
    responseToken = await sign({ sub: 'apple-user', nonce: attempt.nonce });
    const preview = await c.auth.exchange(guest.token, { attemptId: attempt.attemptId, idToken: responseToken, authorizationCode: 'one-use-apple-code' });
    accept(c, guest.token, preview);
    assert.equal(posted.get('grant_type'), 'authorization_code'); assert.equal(posted.get('client_id'), apple.appId);
    assert.equal(posted.has('redirect_uri'), false);
    const credential = c.store.db.prepare('SELECT credential FROM auth_identities').get().credential;
    assert.ok(!credential.includes('secret-apple-refresh'));
    assert.equal(c.auth.decrypt(credential).refreshToken, 'secret-apple-refresh');
    const notification = await sign({ jti: 'notification-1', events: JSON.stringify({ type: 'consent-revoked', sub: 'apple-user', event_time: Math.floor(c.now() / 1000) }) });
    assert.deepEqual(await c.auth.notification({ payload: notification }), { received: true });
    assert.deepEqual(await c.auth.notification({ payload: notification }), { received: true });
    assert.throws(() => c.store.authenticate(guest.token), { code: 'INVALID_TOKEN' });
    assert.equal(c.store.profile(guest.profile.id).gems, 100);
    assert.equal(c.store.db.prepare('SELECT credential FROM auth_identities').get().credential, null);
    await assert.rejects(c.auth.notification({ payload: `${notification}corrupt` }), { code: 'INVALID_NOTIFICATION' });
  } finally { await c.close(); }
});

test('Apple Android callback exposes only bound handoff; wrong session and wrong handoff cannot redeem it', async () => {
  const apple = { appId: 'test.apple.app', serviceId: 'test.apple.web', teamId: 'TEAM', keyId: 'KEY',
    privateKeyFile: '/unused-in-test', redirectUri: 'https://example.test/api/v1/auth/callback/apple' };
  const c = setup({ config: { ...config, apple }, verifyIdentity: async () => ({ provider: 'apple', issuer: 'https://appleid.apple.com', subject: 'callback-user' }) });
  try {
    const guest = c.store.createProfile(), other = c.store.createProfile();
    const attempt = c.auth.attempt(guest.token, { provider: 'apple', platform: 'android', requestId: requestId() });
    const callback = await c.auth.callback({ state: attempt.state, code: 'provider-secret-code', id_token: 'provider-secret-token' });
    assert.equal(callback.platform, 'android'); assert.ok(!JSON.stringify(callback).includes('provider-secret'));
    await assert.rejects(c.auth.exchange(other.token, { attemptId: attempt.attemptId, authorizationCode: callback.handoff }), { code: 'INVALID_AUTH_ATTEMPT' });
    await assert.rejects(c.auth.exchange(guest.token, { attemptId: attempt.attemptId, authorizationCode: 'wrong' }), { code: 'INVALID_HANDOFF' });
    const preview = await c.auth.exchange(guest.token, { attemptId: attempt.attemptId, authorizationCode: callback.handoff });
    assert.equal(accept(c, guest.token, preview).profile.id, guest.profile.id);
    await assert.rejects(c.auth.callback({ state: attempt.state, code: 'same-code' }), { code: 'INVALID_STATE' });
  } finally { await c.close(); }
});

test('completed confirmation retries refresh profile but never reinstall or renew a revoked target session', async () => {
  const c = setup({ verifyIdentity: async (_, input) => identity(input.idToken) });
  try {
    const owner = c.store.createProfile(), guest = c.store.createProfile();
    accept(c, owner.token, await prepare(c, owner.token, 'owner-google'));
    const preview = await prepare(c, guest.token, 'owner-google'), result = accept(c, guest.token, preview);
    c.store.updateProfile(owner.profile.id, { displayName: 'Updated' });
    assert.equal(accept(c, guest.token, preview).profile.displayName, 'Updated');
    const count = c.store.db.prepare('SELECT COUNT(*) AS n FROM tokens').get().n;
    c.store.logout(result.token);
    assert.throws(() => accept(c, guest.token, preview), { code: 'AUTH_RESTART_REQUIRED', status: 409 });
    assert.equal(c.store.db.prepare('SELECT COUNT(*) AS n FROM tokens').get().n, count - 1);
    assert.equal(c.store.authenticate(guest.token), guest.profile.id);
  } finally { await c.close(); }
});

test('deleted destination does not report source guest as deleted or install an obsolete preview', async () => {
  const c = setup({ verifyIdentity: async (_, input) => identity(input.idToken) });
  try {
    const owner = c.store.createProfile(), guest = c.store.createProfile();
    accept(c, owner.token, await prepare(c, owner.token, 'owner-google'));
    const preview = await prepare(c, guest.token, 'owner-google');
    c.auth.deleteProfile(owner.token, { confirmDelete: true });
    assert.throws(() => accept(c, guest.token, preview), { code: 'AUTH_RESTART_REQUIRED', status: 409 });
    assert.equal(c.store.authenticate(guest.token), guest.profile.id);
  } finally { await c.close(); }
});

test('expired abandoned Apple proof queues encrypted revoke; explicit relink supersedes obsolete queued revoke', async () => {
  const apple = { appId: 'apple-app', serviceId: 'apple-service', teamId: 'TEAM', keyId: 'KEY', privateKeyFile: '/unused' };
  let called = 0;
  const c = setup({ config: { ...config, apple }, fetch: async () => { called++; return new Response(null, { status: 200 }); },
    verifyIdentity: async () => ({ provider: 'apple', issuer: 'https://appleid.apple.com', subject: 'abandoned-apple',
      credential: { refreshToken: 'private-unconfirmed-refresh', clientId: apple.appId } }) });
  c.auth.appleSecret = async () => 'test';
  const preview = async token => {
    const attempt = c.auth.attempt(token, { provider: 'apple', platform: 'ios', requestId: requestId() });
    return c.auth.exchange(token, { attemptId: attempt.attemptId, idToken: 'test', authorizationCode: 'test' });
  };
  try {
    const guest = c.store.createProfile(); await preview(guest.token);
    c.advance(301_000); c.auth.clean();
    const pending = c.store.db.prepare('SELECT credential FROM auth_revocations').get();
    assert.ok(pending); assert.ok(!pending.credential.includes('private-unconfirmed-refresh'));
    const linked = await preview(guest.token); accept(c, guest.token, linked);
    const proof = c.auth.decrypt(c.store.db.prepare("SELECT proof FROM auth_attempts WHERE status='done'").get().proof);
    assert.equal(proof.identity.credential, null);
    await c.auth.maintenance();
    assert.equal(called, 0); assert.equal(c.store.db.prepare('SELECT COUNT(*) AS n FROM auth_revocations').get().n, 0);
  } finally { await c.close(); }
});

test('an in-flight Apple revocation invalidates pending confirmations rather than linking an already revoked grant', async () => {
  const apple = { appId: 'apple-app', teamId: 'TEAM', keyId: 'KEY', privateKeyFile: '/unused' };
  let release;
  const gate = new Promise(resolve => { release = resolve; });
  const c = setup({ config: { ...config, apple }, fetch: async () => { await gate; return new Response(null, { status: 200 }); },
    verifyIdentity: async () => ({ provider: 'apple', issuer: 'https://appleid.apple.com', subject: 'revoking-apple',
      credential: { refreshToken: 'old-grant', clientId: apple.appId } }) });
  c.auth.appleSecret = async () => 'test';
  const preview = async token => {
    const attempt = c.auth.attempt(token, { provider: 'apple', platform: 'ios', requestId: requestId() });
    return c.auth.exchange(token, { attemptId: attempt.attemptId, idToken: 'test', authorizationCode: 'test' });
  };
  try {
    const guest = c.store.createProfile(); await preview(guest.token); c.advance(301_000); c.auth.clean();
    const pending = await preview(guest.token), maintenance = c.auth.maintenance();
    assert.throws(() => accept(c, guest.token, pending), { code: 'AUTH_RESTART_REQUIRED' });
    await assert.rejects(preview(guest.token), { code: 'AUTH_RESTART_REQUIRED' });
    release(); await maintenance;
    const fresh = await preview(guest.token); accept(c, guest.token, fresh);
    assert.deepEqual(c.store.profile(guest.profile.id).linkedProviders, ['apple']);
  } finally { release(); await c.close(); }
});

test('public auth return origin must be an exact HTTPS origin', async () => {
  const store = new EconomyStore();
  try {
    for (const value of ['javascript:alert(1)', 'https://example.test/path', 'https://user:pass@example.test', 'https://example.test/?x=1'])
      assert.throws(() => createAuthService({ store, config: { ...config, apple: { returnOrigin: value } } }), /AUTH_PUBLIC_ORIGIN/);
  } finally { store.close(); }
});

test('a stale daily Apple refresh failure cannot revoke a newer confirmed credential or its sessions', async () => {
  const c = setup();
  try {
    const guest = c.store.createProfile();
    const oldCredential = c.auth.encrypt({ refreshToken: 'old', clientId: 'client' });
    c.store.db.prepare('INSERT INTO auth_identities(profile_id,provider,issuer,subject,created_at,credential) VALUES(?,?,?,?,?,?)')
      .run(guest.profile.id, 'apple', 'https://appleid.apple.com', 'same-user', c.now(), oldCredential);
    const oldSnapshot = c.store.db.prepare('SELECT * FROM auth_identities WHERE profile_id=?').get(guest.profile.id);
    const freshCredential = c.auth.encrypt({ refreshToken: 'fresh', clientId: 'client' });
    c.store.db.prepare('UPDATE auth_identities SET credential=? WHERE profile_id=?').run(freshCredential, guest.profile.id);
    assert.equal(c.auth.invalidateIdentity(oldSnapshot), false);
    assert.equal(c.store.authenticate(guest.token), guest.profile.id);
    assert.equal(c.store.db.prepare('SELECT credential FROM auth_identities WHERE profile_id=?').get(guest.profile.id).credential, freshCredential);
  } finally { await c.close(); }
});

test('shutdown aborts provider maintenance promptly and preserves pending revocations and live credentials', async () => {
  let started, calls = 0;
  const requestStarted = new Promise(resolve => { started = resolve; });
  const c = setup({ fetch: async (_, { signal }) => {
    calls++; started();
    return new Promise((resolve, reject) => {
      if (signal.aborted) reject(signal.reason);
      else signal.addEventListener('abort', () => reject(signal.reason), { once: true });
    });
  } });
  c.auth.appleSecret = async () => 'test';
  try {
    const guest = c.store.createProfile();
    const liveCredential = c.auth.encrypt({ refreshToken: 'live-refresh', clientId: 'client' });
    c.store.db.prepare('INSERT INTO auth_identities(profile_id,provider,issuer,subject,created_at,credential,checked_at) VALUES(?,?,?,?,?,?,?)')
      .run(guest.profile.id, 'apple', 'https://appleid.apple.com', 'live-subject', c.now(), liveCredential, 0);
    for (const subject of ['abandoned-one', 'abandoned-two']) c.auth.queueRevocation({ provider: 'apple',
      issuer: 'https://appleid.apple.com', subject, credential: { refreshToken: subject, clientId: 'client' } });
    const maintenance = c.auth.maintenance(); await requestStarted;
    let timer;
    try {
      await Promise.race([c.auth.close(), new Promise((resolve, reject) => {
        timer = setTimeout(() => reject(new Error('Authentication shutdown did not abort the request promptly')), 1000);
      })]);
    } finally { clearTimeout(timer); }
    await maintenance;
    assert.equal(calls, 1);
    const queued = c.store.db.prepare('SELECT attempts FROM auth_revocations').all();
    assert.equal(queued.length, 2); assert.ok(queued.every(row => row.attempts === 0));
    const identity = c.store.db.prepare('SELECT credential,checked_at FROM auth_identities WHERE profile_id=?').get(guest.profile.id);
    assert.equal(identity.credential, liveCredential); assert.equal(identity.checked_at, 0);
    assert.equal(c.store.authenticate(guest.token), guest.profile.id);
    await c.auth.maintenance(); assert.equal(calls, 1);
  } finally { await c.close(); }
});

test('signed Apple event_time orders reconsent independently of delivery iat, confirmation and daily checks', async () => {
  const { publicKey, privateKey } = await generateKeyPair('RS256');
  const apple = { appId: 'apple-ordering-app', teamId: 'TEAM', keyId: 'KEY', privateKeyFile: '/unused' };
  const responses = new Map();
  let refreshChecks = 0;
  const c = setup({ config: { ...config, apple }, keySets: { apple: publicKey }, fetch: async (_, { body }) => {
    if (body.get('grant_type') === 'refresh_token') { refreshChecks++; return new Response('{}'); }
    return new Response(JSON.stringify(responses.get(body.get('code'))));
  } });
  c.auth.appleSecret = async () => 'test';
  const seconds = () => Math.floor(c.now() / 1000);
  const sign = (payload, issuedAt = seconds()) => new SignJWT(payload).setProtectedHeader({ alg: 'RS256' })
    .setIssuer('https://appleid.apple.com').setAudience(apple.appId).setIssuedAt(issuedAt).setExpirationTime(seconds() + 600).sign(privateKey);
  const authorize = async (token, operation = 'login') => {
    const attempt = c.auth.attempt(token, { provider: 'apple', platform: 'ios', operation, requestId: requestId() });
    const idToken = await sign({ sub: 'ordered-apple-user', nonce: attempt.nonce });
    const code = requestId(); responses.set(code, { id_token: idToken, refresh_token: `refresh-${code}` });
    return c.auth.exchange(token, { attemptId: attempt.attemptId, idToken, authorizationCode: code });
  };
  const notify = async (eventTime, jti = requestId()) => c.auth.notification({ payload: await sign({ jti,
    events: { type: 'consent-revoked', sub: 'ordered-apple-user', event_time: eventTime } }) });
  try {
    const owner = c.store.createProfile(); accept(c, owner.token, await authorize(owner.token));
    const beforeRevocationGuest = c.store.createProfile();
    const oldProof = await authorize(beforeRevocationGuest.token);
    const firstGrant = seconds(), firstRevocation = firstGrant + 2;
    c.advance(5000);
    const reconsent = await authorize(owner.token, 'reauth');
    // Confirmation occurs later; grant time must remain the signed token's iat.
    const reconsentIssuedAt = seconds(); c.advance(1000); accept(c, owner.token, reconsent);
    const fresh = c.store.db.prepare('SELECT * FROM auth_identities WHERE profile_id=?').get(owner.profile.id);
    assert.equal(fresh.grant_issued_at, reconsentIssuedAt);
    const delayed = await sign({ jti: 'late-revocation', events: {
      type: 'consent-revoked', sub: 'ordered-apple-user', event_time: firstRevocation,
    } });
    // Notification iat is newer than the new grant; only event_time is older.
    await c.auth.notification({ payload: delayed }); await c.auth.notification({ payload: delayed });
    assert.equal(c.store.authenticate(owner.token), owner.profile.id);
    const afterLate = c.store.db.prepare('SELECT * FROM auth_identities WHERE profile_id=?').get(owner.profile.id);
    assert.equal(afterLate.credential, fresh.credential); assert.equal(afterLate.grant_issued_at, reconsentIssuedAt);
    assert.equal(afterLate.revoked_at, firstRevocation);
    assert.throws(() => accept(c, beforeRevocationGuest.token, oldProof), { code: 'AUTH_RESTART_REQUIRED' });
    // A new daily check is not a fresh grant and cannot hide a genuine later revocation.
    c.advance(9000); const laterRevocation = seconds() - 2;
    c.store.db.prepare('UPDATE auth_identities SET checked_at=? WHERE profile_id=?').run(c.now() - 86_400_001, owner.profile.id);
    await c.auth.maintenance(); assert.equal(refreshChecks, 1);
    assert.equal(c.store.db.prepare('SELECT grant_issued_at FROM auth_identities').get().grant_issued_at, reconsentIssuedAt);
    await notify(laterRevocation);
    assert.throws(() => c.store.authenticate(owner.token), { code: 'INVALID_TOKEN' });
    const revoked = c.store.db.prepare('SELECT * FROM auth_identities').get();
    assert.equal(revoked.credential, null); assert.equal(revoked.revoked_at, laterRevocation);
    // A genuinely later explicit reconsent restores the same wallet.
    c.advance(1000); const reconnectGuest = c.store.createProfile();
    const restored = accept(c, reconnectGuest.token, await authorize(reconnectGuest.token));
    assert.equal(restored.profile.id, owner.profile.id); assert.equal(restored.profile.gems, 100);
    await notify(laterRevocation); assert.equal(c.store.authenticate(restored.token), owner.profile.id);
    // Same-second ordering cannot establish a newer grant, so revocation wins.
    await notify(seconds()); assert.throws(() => c.store.authenticate(restored.token), { code: 'INVALID_TOKEN' });
    await assert.rejects(authorize(reconnectGuest.token), { code: 'AUTH_RESTART_REQUIRED' });
  } finally { await c.close(); }
});

test('legacy identity migration keeps grant time unknown and honors signed revocation conservatively', async () => {
  const { publicKey, privateKey } = await generateKeyPair('RS256');
  const apple = { appId: 'legacy-apple-app' };
  const dir = mkdtempSync(join(tmpdir(), 'sommomemory-grant-migration-'));
  let c = setup({ store: new EconomyStore({ dataDir: dir }), config: { ...config, apple }, keySets: { apple: publicKey } });
  const guest = c.store.createProfile();
  try {
    c.store.db.prepare('INSERT INTO auth_identities(profile_id,provider,issuer,subject,created_at,credential,checked_at) VALUES(?,?,?,?,?,?,?)')
      .run(guest.profile.id, 'apple', 'https://appleid.apple.com', 'legacy-apple-subject', c.now(),
        c.auth.encrypt({ refreshToken: 'legacy-private-refresh', clientId: apple.appId }), c.now() + 86_400_000);
    c.store.db.exec('ALTER TABLE auth_identities DROP COLUMN grant_issued_at; ALTER TABLE auth_identities DROP COLUMN revoked_at');
    await c.close();
    c = setup({ store: new EconomyStore({ dataDir: dir }), config: { ...config, apple }, keySets: { apple: publicKey } });
    const migrated = c.store.db.prepare('SELECT * FROM auth_identities').get();
    assert.equal(migrated.grant_issued_at, 0); assert.equal(migrated.revoked_at, 0);
    const now = Math.floor(c.now() / 1000), eventTime = now - 5;
    const signed = await new SignJWT({ jti: 'legacy-revoke', events: {
      type: 'consent-revoked', sub: 'legacy-apple-subject', event_time: eventTime,
    } }).setProtectedHeader({ alg: 'RS256' }).setIssuer('https://appleid.apple.com').setAudience(apple.appId)
      .setIssuedAt(now).setExpirationTime(now + 300).sign(privateKey);
    await c.auth.notification({ payload: signed });
    assert.throws(() => c.store.authenticate(guest.token), { code: 'INVALID_TOKEN' });
    assert.equal(c.store.profile(guest.profile.id).gems, 100);
    assert.equal(c.store.db.prepare('SELECT revoked_at FROM auth_identities').get().revoked_at, eventTime);
  } finally { await c.close(); rmSync(dir, { recursive: true, force: true }); }
});

test('Apple canonical account-deleted event removes the account and missing event_time cannot revoke sessions', async () => {
  const { publicKey, privateKey } = await generateKeyPair('RS256');
  const apple = { appId: 'deletion-apple-app' };
  let deleted = null;
  const c = setup({ config: { ...config, apple }, keySets: { apple: publicKey }, onProfileDeleted: id => { deleted = id; } });
  const seconds = () => Math.floor(c.now() / 1000);
  const sign = events => new SignJWT({ jti: requestId(), events }).setProtectedHeader({ alg: 'RS256' })
    .setIssuer('https://appleid.apple.com').setAudience(apple.appId).setIssuedAt(seconds()).setExpirationTime(seconds() + 300).sign(privateKey);
  try {
    for (const type of ['account-deleted', 'account-delete']) {
      const guest = c.store.createProfile(), sub = `apple-${type}`;
      c.store.db.prepare('INSERT INTO auth_identities(profile_id,provider,issuer,subject,created_at) VALUES(?,?,?,?,?)')
        .run(guest.profile.id, 'apple', 'https://appleid.apple.com', sub, c.now());
      for (const event_time of [undefined, 'invalid', seconds() + 10]) {
        await assert.rejects(c.auth.notification({ payload: await sign({ type: 'consent-revoked', sub, event_time }) }), { code: 'INVALID_NOTIFICATION' });
        assert.equal(c.store.authenticate(guest.token), guest.profile.id);
      }
      await c.auth.notification({ payload: await sign({ type, sub, event_time: seconds() }) });
      assert.equal(deleted, guest.profile.id); assert.equal(c.store.hasProfile(guest.profile.id), false);
      assert.throws(() => c.store.authenticate(guest.token), { code: 'PROFILE_DELETED' });
      assert.equal(c.store.db.prepare('SELECT 1 FROM auth_identities WHERE subject=?').get(sub), undefined);
    }
  } finally { await c.close(); }
});
