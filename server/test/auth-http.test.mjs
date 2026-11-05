import test from 'node:test';
import assert from 'node:assert/strict';
import { once } from 'node:events';
import { startServer } from '../src/server.mjs';

test('Apple callbacks require form_post and expose only session-bound handoff, with strict origin handling elsewhere', async () => {
  const server = startServer({ port: 0, dataDir: null,
    authConfig: { apple: { appId: 'apple-app', serviceId: 'apple-service', teamId: 'TEAM', keyId: 'KEY',
      privateKeyFile: '/unused', redirectUri: 'https://example.test/api/v1/auth/callback/apple' } },
    verifyIdentity: async () => ({ provider: 'apple', issuer: 'https://appleid.apple.com', subject: 'http-apple-user' }) });
  await once(server.http, 'listening');
  const base = `http://127.0.0.1:${server.http.address().port}/api/v1`;
  try {
    const guest = server.economy.createProfile();
    const attempt = server.auth.attempt(guest.token, { provider: 'apple', platform: 'android', requestId: crypto.randomUUID() });
    const get = await fetch(`${base}/auth/callback/apple?id_token=must-not-be-accepted&state=${attempt.state}`);
    assert.equal(get.status, 405); assert.equal(get.headers.get('allow'), 'POST');
    assert.ok(!(await get.text()).includes('must-not-be-accepted'));
    const callbackBody = { state: attempt.state, code: 'secret-apple-code', id_token: 'secret-apple-token' };
    const request = input => fetch(`${base}/auth/callback/apple`, { method: 'POST', redirect: 'manual',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded', Origin: 'https://appleid.apple.com' }, body: input });
    const duplicate = await request(`state=${attempt.state}&state=another&code=invalid`);
    assert.equal(duplicate.status, 400);
    const callback = await request(new URLSearchParams(callbackBody));
    assert.equal(callback.status, 303);
    const location = callback.headers.get('location');
    assert.ok(!location.includes('secret-apple'));
    assert.match(location, /^intent:\/\/callback\?code=[A-Za-z0-9_-]{43}&state=/);
    assert.equal(callback.headers.get('cache-control'), 'no-store');
    assert.equal(callback.headers.get('referrer-policy'), 'no-referrer');
    const handoff = new URL(location.split('#')[0]).searchParams.get('code');
    const exchange = await fetch(`${base}/auth/exchange`, { method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${guest.token}` },
      body: JSON.stringify({ attemptId: attempt.attemptId, authorizationCode: handoff }) });
    assert.equal(exchange.status, 200);
    const preview = await exchange.json(); assert.equal(preview.action, 'link');
    const forbidden = await fetch(`${base}/auth/providers`, { headers: { Origin: 'https://evil.example' } });
    assert.equal(forbidden.status, 403);
    assert.deepEqual(server.economy.profile(guest.profile.id).linkedProviders, []);
  } finally { await server.close(); }
});
