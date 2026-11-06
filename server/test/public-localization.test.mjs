import test from 'node:test';
import assert from 'node:assert/strict';
import { once } from 'node:events';
import { readFileSync } from 'node:fs';
import { runInNewContext } from 'node:vm';
import { startServer } from '../src/server.mjs';

test('English public pages and deletion script are served with the same protections as Italian', async () => {
  const server = startServer({ port: 0, dataDir: null, authConfig: {} });
  await once(server.http, 'listening');
  const base = `http://127.0.0.1:${server.http.address().port}`;
  try {
    for (const page of ['privacy', 'support', 'delete-account']) {
      const italian = await fetch(`${base}/${page}`);
      const itHtml = await italian.text();
      assert.match(itHtml, /lang="it"/);
      for (const suffix of ['', '/']) {
        const response = await fetch(`${base}/en/${page}${suffix}`);
        assert.equal(response.status, 200);
        assert.equal(response.headers.get('content-type'), italian.headers.get('content-type'));
        assert.equal(response.headers.get('cache-control'), italian.headers.get('cache-control'));
        assert.equal(response.headers.get('content-security-policy'), italian.headers.get('content-security-policy'));
        assert.equal(response.headers.get('referrer-policy'), italian.headers.get('referrer-policy'));
        const html = await response.text();
        assert.match(html, /lang="en"/);
        assert.match(html, /href="\/en\/(privacy|support|delete-account)"/);
        assert.equal((html.match(/<h2\b/g) || []).length, (itHtml.match(/<h2\b/g) || []).length);
        assert.equal((html.match(/<p\b/g) || []).length, (itHtml.match(/<p\b/g) || []).length);
        const head = await fetch(`${base}/en/${page}${suffix}`, { method: 'HEAD' });
        assert.equal(head.status, 200);
        assert.equal(await head.text(), '');
      }
    }
    const deletion = await fetch(`${base}/en/delete-account`);
    assert.match(await deletion.text(), /src="\/en\/account-deletion.js"/);
    const script = await fetch(`${base}/en/account-deletion.js`);
    assert.equal(script.status, 200);
    assert.match(script.headers.get('content-type'), /javascript/);
    const source = await script.text();
    assert.match(source, /auth\/reauth\/recovery/);
    assert.doesNotMatch(source, /localStorage|sessionStorage|console\./);
    assert.equal((await fetch(`${base}/en/delete-account`, { method: 'POST' })).status, 405);
  } finally { await server.close(); }
});

test('English deletion page translates server errors and keeps preview, confirmation and cleanup behaviour', async () => {
  const elements = new Map();
  const document = { getElementById(id) {
    if (!elements.has(id)) elements.set(id, { hidden: false, value: '', textContent: '',
      handlers: {}, addEventListener(event, handler) { this.handlers[event] = handler; }, focus() {} });
    return elements.get(id);
  } };
  const requests = [];
  let invalid = true;
  const fetch = async (path, options) => {
    requests.push({ path, options });
    if (invalid) return { ok: false, json: async () => ({ error: { code: 'INVALID_RECOVERY', message: 'Codice di recupero non valido.' } }) };
    return { ok: true, json: async () => ({ token: 'test-session', profile: { displayName: 'Giocatore', gems: 100, ownedDecks: ['garden'] } }) };
  };
  runInNewContext(readFileSync(new URL('../public/en/account-deletion.js', import.meta.url), 'utf8'), { document, fetch, AbortSignal });
  const get = id => document.getElementById(id);
  get('recovery-code').value = 'SMM-test';
  await get('recovery-form').handlers.submit({ preventDefault() {} });
  assert.equal(get('status').textContent, 'Invalid recovery code.');
  invalid = false;
  await get('recovery-form').handlers.submit({ preventDefault() {} });
  assert.equal(get('profile-summary').textContent, 'Giocatore · 100 gems · 1 collection');
  assert.equal(get('preview').hidden, false);
  assert.equal(requests.some(request => request.options.method === 'DELETE'), false);
  await get('confirm-delete').handlers.click();
  assert.equal(get('status').textContent, 'The SommoMemory profile and its associated data have been deleted.');
  assert.deepEqual(requests.slice(-4).map(request => request.path), [
    '/api/v1/profiles/restore', '/api/v1/auth/reauth/recovery', '/api/v1/profile', '/api/v1/profile/logout',
  ]);
  assert.equal(requests.at(-2).options.method, 'DELETE');
  assert.equal(requests.at(-2).options.body, '{"confirmDelete":true}');
  assert.equal(requests.at(-2).options.headers.Authorization, 'Bearer test-session');
});
