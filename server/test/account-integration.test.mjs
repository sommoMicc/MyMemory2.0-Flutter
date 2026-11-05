import test from 'node:test';
import assert from 'node:assert/strict';
import { once } from 'node:events';
import { mkdtempSync, readFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { startServer } from '../src/server.mjs';
import { GameEngine } from '../src/game.mjs';

async function open(options = {}) {
  const server = startServer({ port: 0, dataDir: null, authConfig: {}, ...options });
  await once(server.http, 'listening');
  const base = `http://127.0.0.1:${server.http.address().port}`;
  const api = async (path, { method = 'GET', body, token, origin } = {}) => {
    const response = await fetch(`${base}/api/v1/${path}`, { method,
      headers: { ...(body !== undefined ? { 'Content-Type': 'application/json' } : {}),
        ...(token ? { Authorization: `Bearer ${token}` } : {}), ...(origin ? { Origin: origin } : {}) },
      body: body === undefined ? undefined : JSON.stringify(body) });
    return { status: response.status, body: await response.json(), headers: response.headers };
  };
  return { server, base, api };
}

test('unconfigured providers stay hidden and account deletion is available outside the installed app', async () => {
  const { server, base, api } = await open();
  try {
    const providers = await api('auth/providers?platform=web');
    assert.equal(providers.status, 200);
    assert.deepEqual(providers.body.providers, []);
    assert.equal(providers.headers.get('cache-control'), 'no-store');
    assert.equal((await api('auth/providers', { origin: 'https://evil.example' })).status, 403);
    const page = await fetch(`${base}/delete-account`);
    assert.equal(page.status, 200);
    assert.match(page.headers.get('content-type'), /text\/html/);
    const html = await page.text();
    assert.match(html, /SommoMemory/);
    assert.match(html, /href="\/\?account=delete"/);
    assert.match(html, /type="password"/);
    assert.match(html, /aria-live="polite"/);
    assert.match(html, /src="\/account-deletion.js"/);
    const js = await fetch(`${base}/account-deletion.js`);
    assert.equal(js.status, 200);
    assert.match(js.headers.get('content-type'), /javascript/);
    const source = await js.text();
    assert.match(source, /auth\/reauth\/recovery/);
    assert.doesNotMatch(source, /localStorage|sessionStorage|console\./);
  } finally { await server.close(); }
});

test('guest appearance and recovery remain usable with no OAuth configuration', async () => {
  const { server, api } = await open();
  try {
    const created = await api('profiles', { method: 'POST', body: {} });
    assert.equal(created.status, 201);
    const { token, profile } = created.body;
    const changed = await api('profile', { method: 'PATCH', token,
      body: { displayName: 'Volpe', avatarId: 'owl', accentId: 'cosmos' } });
    assert.equal(changed.status, 200);
    assert.equal(changed.body.profile.id, profile.id);
    assert.equal(changed.body.profile.gems, 100);
    assert.equal(changed.body.profile.avatarId, 'owl');
    assert.equal(changed.body.profile.accentId, 'cosmos');
    const legacy = await api('profile', { method: 'PATCH', token, body: { displayName: 'Nome nuovo' } });
    assert.equal(legacy.body.profile.avatarId, 'owl');
    assert.equal(legacy.body.profile.accentId, 'cosmos');
    const activated = await api('profile/recovery', { method: 'POST', token, body: {} });
    assert.equal(activated.status, 200);
    const restored = await api('profiles/restore', { method: 'POST', body: {
      recoveryCode: activated.body.recoveryCode, confirmReplace: true } });
    assert.equal(restored.status, 200);
    assert.equal(restored.body.profile.id, profile.id);
    assert.equal(restored.body.profile.avatarId, 'owl');
    assert.equal(restored.body.profile.gems, 100);
    const sessions = await api('profile/sessions', { token: restored.body.token });
    assert.equal(sessions.status, 200);
    assert.equal(sessions.body.sessions.filter(s => s.current).length, 1);
    assert.equal(JSON.stringify(sessions.body).includes(token), false);
    const recoveryPreview = await api('profiles/restore/preview', { method: 'POST',
      body: { recoveryCode: activated.body.recoveryCode } });
    assert.equal(recoveryPreview.status, 200);
    assert.equal('linkedProviders' in recoveryPreview.body.profile, false);
  } finally { await server.close(); }
});

test('deleting a profile detaches its name from persisted games while the opponent can complete and earn once', async () => {
  const dir = mkdtempSync(join(tmpdir(), 'mymemory-account-game-'));
  const { server, api } = await open({ dataDir: dir });
  try {
    const deleted = (await api('profiles', { method: 'POST', body: {} })).body;
    const survivor = (await api('profiles', { method: 'POST', body: {} })).body;
    const first = server.engine.create({ name: 'Nome da cancellare', profileId: deleted.profile.id, pairs: 6 });
    server.engine.join({ code: first.code, name: 'Avversario', profileId: survivor.profile.id });
    const before = server.engine.state(first.code);
    const result = await api('profile', { method: 'DELETE', token: deleted.token, body: { confirmDelete: true } });
    assert.equal(result.status, 200);
    const room = server.engine.room(first.code);
    assert.equal(room.players[0].profileId, undefined);
    assert.equal(room.players[0].name, 'Giocatore');
    assert.equal(room.turn, before.turn);
    assert.equal(room.phase, 'playing');
    const persisted = readFileSync(join(dir, 'rooms.json'), 'utf8');
    assert.equal(persisted.includes(deleted.profile.id), false);
    assert.equal(persisted.includes('Nome da cancellare'), false);
    for (let card = 0; card < room.pairs; card++) {
      room.board.flatMap((value, i) => value === String(card) ? [i] : [])
        .forEach(i => server.engine.flip(first.code, first.playerId, i));
    }
    assert.equal(room.phase, 'finished');
    assert.equal(server.engine.pendingRewards.size, 0);
    assert.equal(server.economy.profile(survivor.profile.id).gems, 120);
    server.engine.settleRewards(room);
    assert.equal(server.economy.profile(survivor.profile.id).gems, 120);
    assert.equal((await api('profile', { token: deleted.token })).status, 401);
    const restored = new GameEngine({ dataDir: dir });
    assert.equal(restored.room(first.code).players[0].profileId, undefined);
    assert.equal(restored.room(first.code).players[0].name, 'Giocatore');
  } finally { await server.close(); rmSync(dir, { recursive: true, force: true }); }
});
