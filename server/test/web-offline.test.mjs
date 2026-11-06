import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtemp, mkdir, writeFile, readFile, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import vm from 'node:vm';
import { prepareOfflineWeb } from '../../scripts/offline-web.mjs';

async function fixture(t) {
  const root = await mkdtemp(join(tmpdir(), 'memory-offline-'));
  t.after(() => rm(root, { recursive: true, force: true }));
  for (const dir of ['assets/decks/garden', 'canvaskit/chromium']) await mkdir(join(root, dir), { recursive: true });
  const files = {
    'index.html': 'game shell',
    'flutter_bootstrap.js': 'current bootstrap',
    'main.current.dart.js': 'current game',
    'assets/decks/garden/fox.png': 'fox image',
    'assets/AssetManifest.bin': 'asset manifest',
    'canvaskit/chromium/canvaskit.wasm': 'local renderer',
  };
  for (const [name, content] of Object.entries(files)) await writeFile(join(root, name), content);
  await prepareOfflineWeb(root, 'main.current.dart.js');
  return { root, files };
}

function worker(source, files, storage = new Map()) {
  const origin = 'https://memory.example/';
  const handlers = new Map();
  const key = input => typeof input === 'string' ? input : input.url;
  let offline = false, skip = 0, claimed = 0;
  const fetch = async input => {
    if (offline) throw new Error('offline');
    const file = new URL(key(input)).pathname.slice(1);
    return new Response(files[file] ?? 'not found', { status: Object.hasOwn(files, file) ? 200 : 404 });
  };
  const caches = {
    keys: async () => [...storage.keys()],
    delete: async name => storage.delete(name),
    open: async name => {
      if (!storage.has(name)) storage.set(name, new Map());
      const values = storage.get(name);
      return {
        addAll: async requests => {
          for (const request of requests) {
            const response = await fetch(request);
            if (!response.ok) throw new Error('missing resource');
            values.set(key(request), response.clone());
          }
        },
        match: async input => values.get(key(input))?.clone(),
      };
    },
  };
  const self = {
    registration: { scope: origin },
    addEventListener: (event, callback) => handlers.set(event, callback),
    skipWaiting: async () => { skip++; },
    clients: { claim: async () => { claimed++; } },
  };
  vm.runInNewContext(source, { self, caches, fetch, URL, Request });
  return {
    storage,
    get skip() { return skip; },
    get claimed() { return claimed; },
    offline: value => { offline = value; },
    async event(name) {
      let pending;
      handlers.get(name)({ waitUntil: promise => { pending = promise; } });
      await pending;
    },
    async request(path, { mode = 'cors', method = 'GET', headers = {} } = {}) {
      let response;
      handlers.get('fetch')({
        request: { url: new URL(path, origin).href, mode, method, headers: new Headers(headers) },
        respondWith: promise => { response = promise; },
      });
      return response ? await response : null;
    },
  };
}

test('offline browser reload keeps shell, every deck and local renderer without caching profiles', async t => {
  const { root, files } = await fixture(t);
  const runtime = worker(await readFile(join(root, 'memory_service_worker.js'), 'utf8'), files);
  await runtime.event('install');
  await runtime.event('activate');
  assert.equal(runtime.skip, 1);
  assert.equal(runtime.claimed, 1);
  runtime.offline(true);
  for (const [path, expected] of Object.entries(files)) {
    const response = await runtime.request(path, { mode: path === 'index.html' ? 'navigate' : 'cors' });
    assert.equal(await response.text(), expected);
  }
  assert.equal(await (await runtime.request('/invite/ABC234', { mode: 'navigate' })).text(), 'game shell');
  for (const path of ['/api/v1/profile', '/api/v1/solo/operations', '/admin', '/delete-account', '/privacy', 'https://other.example/']) {
    assert.equal(await runtime.request(path, { mode: 'navigate' }), null);
  }
  assert.equal(await runtime.request('/index.html', { headers: { Authorization: 'Bearer secret' } }), null);
  assert.equal(await runtime.request('/index.html', { method: 'POST' }), null);
});

test('online entrypoints stay fresh; failed updates preserve the complete offline release', async t => {
  const { root, files } = await fixture(t);
  const priorSource = await readFile(join(root, 'memory_service_worker.js'), 'utf8');
  const prior = worker(priorSource, files);
  await prior.event('install');
  const priorCache = [...prior.storage.keys()][0];
  files['flutter_bootstrap.js'] = 'new bootstrap online';
  assert.equal(await (await prior.request('flutter_bootstrap.js')).text(), 'new bootstrap online');
  await writeFile(join(root, 'main.current.dart.js'), 'updated game');
  await prepareOfflineWeb(root, 'main.current.dart.js');
  const nextSource = await readFile(join(root, 'memory_service_worker.js'), 'utf8');
  assert.notEqual(nextSource, priorSource);
  const updated = worker(nextSource, files, prior.storage);
  updated.offline(true);
  await assert.rejects(updated.event('install'), /offline/);
  assert.deepEqual([...prior.storage.keys()], [priorCache]);
  prior.offline(true);
  assert.equal(await (await prior.request('index.html', { mode: 'navigate' })).text(), 'game shell');
  updated.offline(false);
  await updated.event('install');
  await updated.event('activate');
  assert.equal(prior.storage.size, 1);
  assert.equal(prior.storage.has(priorCache), false);
});
