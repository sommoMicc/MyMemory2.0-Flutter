'use strict';
const CACHE_PREFIX = 'sommomemory-offline-';
const CACHE_NAME = CACHE_PREFIX + '__REVISION__';
const RESOURCES = __RESOURCES__;
const ROOT = new URL('./', self.registration.scope);
const resourceURLs = new Set(RESOURCES.map(file => new URL(file, ROOT).href));

self.addEventListener('install', event => {
  event.waitUntil((async () => {
    try {
      const cache = await caches.open(CACHE_NAME);
      // A failed download must leave the previous complete release usable.
      await cache.addAll(RESOURCES.map(file => new Request(new URL(file, ROOT), { cache: 'reload' })));
      await self.skipWaiting();
    } catch (error) {
      await caches.delete(CACHE_NAME);
      throw error;
    }
  })());
});

self.addEventListener('activate', event => {
  event.waitUntil((async () => {
    for (const name of await caches.keys()) {
      if (name.startsWith(CACHE_PREFIX) && name !== CACHE_NAME) await caches.delete(name);
    }
    await self.clients.claim();
  })());
});

self.addEventListener('fetch', event => {
  const request = event.request;
  const url = new URL(request.url);
  if (request.method !== 'GET' || url.origin !== ROOT.origin ||
      request.headers.has('Authorization')) return;
  const path = url.pathname.slice(ROOT.pathname.length);
  const navigation = request.mode === 'navigate' &&
    (url.pathname === ROOT.pathname || path === 'index.html' || /^invite\/[A-Z0-9]{6}\/?$/i.test(path));
  url.search = '';
  url.hash = '';
  const key = url.href;
  if (!navigation && !resourceURLs.has(key)) return;
  event.respondWith((async () => {
    const cache = await caches.open(CACHE_NAME);
    // Entry scripts and navigation always consult the network first so an
    // online visit sees the current interface immediately after deployment.
    if (navigation || !/\/(assets|canvaskit|icons)\//.test(url.pathname)) {
      try {
        const response = await fetch(request);
        if (response.ok) return response;
      } catch (_) { /* Use the last fully downloaded release below. */ }
    }
    const cached = await cache.match(navigation ? new URL('index.html', ROOT).href : key);
    if (cached) return cached;
    return fetch(request);
  })());
});
