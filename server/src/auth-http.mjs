import { randomBytes } from 'node:crypto';
import { EconomyError } from './economy.mjs';
import { readJsonBody } from './economy-http.mjs';

async function formBody(req) {
  if (!/^application\/x-www-form-urlencoded(?:\s*;.*)?$/i.test(req.headers['content-type'] || ''))
    throw new EconomyError('CONTENT_TYPE', 'Formato del callback non valido.', 415);
  let size = 0;
  const chunks = [];
  const timer = setTimeout(() => req.destroy(), 10_000);
  try {
    for await (const chunk of req) {
      size += chunk.length;
      if (size > 64 * 1024) throw new EconomyError('BODY_TOO_LARGE', 'Richiesta troppo grande.', 413);
      chunks.push(chunk);
    }
  } finally { clearTimeout(timer); }
  const params = new URLSearchParams(Buffer.concat(chunks).toString('utf8'));
  for (const name of ['state', 'code', 'id_token', 'error'])
    if (params.getAll(name).length > 1) throw new EconomyError('INVALID_BODY', 'Callback non valido.');
  return Object.fromEntries(params);
}

export function authHttp(auth) {
  const counters = new Map();
  function limit(address, kind, max = 50) {
    const time = auth.now(), key = `${kind}:${address}`;
    for (const [entry, value] of counters) if (value.until <= time) counters.delete(entry);
    let counter = counters.get(key);
    if (!counter) {
      if (counters.size >= 10_000) throw new EconomyError('RATE_LIMIT', 'Riprova più tardi.', 429);
      counter = { count: 0, until: time + 600_000 }; counters.set(key, counter);
    }
    if (++counter.count > max) throw new EconomyError('RATE_LIMIT', 'Troppi tentativi. Riprova più tardi.', 429);
  }
  const handler = async (req, res, pathname, { origins, addressOf } = {}) => {
    const owns = pathname.startsWith('/api/v1/auth/') || /^\/api\/v1\/profile\/(identities|sessions)(\/|$)/.test(pathname);
    if (!owns) return false;
    const reply = (status, data) => {
      res.writeHead(status, { 'Content-Type': 'application/json; charset=utf-8', 'Cache-Control': 'no-store' });
      res.end(JSON.stringify(data));
    };
    try {
      const callback = pathname === '/api/v1/auth/callback/apple';
      const notification = pathname === '/api/v1/auth/notifications/apple';
      const origin = req.headers.origin;
      if (!callback && !notification && origin && !origins?.has(origin)) throw new EconomyError('ORIGIN_DENIED', 'Origine non autorizzata.', 403);
      if (!callback && !notification && origin) { res.setHeader('Access-Control-Allow-Origin', origin); res.setHeader('Vary', 'Origin'); }
      res.setHeader('Cache-Control', 'no-store');
      res.setHeader('Referrer-Policy', 'no-referrer');
      if (req.method === 'OPTIONS' && !callback && !notification) {
        res.writeHead(204, { 'Access-Control-Allow-Methods': 'GET,POST,DELETE,OPTIONS',
          'Access-Control-Allow-Headers': 'Authorization,Content-Type', 'Access-Control-Max-Age': '600' }); res.end(); return true;
      }
      limit(addressOf?.(req) || req.socket.remoteAddress, callback ? 'callback' : 'auth', notification ? 300 : 60);
      const route = `${req.method} ${pathname}`;
      if (route === 'GET /api/v1/auth/providers') {
        const platform = new URL(req.url, 'http://localhost').searchParams.get('platform') || 'web';
        reply(200, auth.providers(platform)); return true;
      }
      if (route === 'POST /api/v1/auth/notifications/apple') {
        reply(200, await auth.notification(await readJsonBody(req))); return true;
      }
      if (callback) {
        if (req.method !== 'POST') { res.setHeader('Allow', 'POST'); throw new EconomyError('METHOD_NOT_ALLOWED', 'Usa il callback Apple form_post.', 405); }
        if (new URL(req.url, 'http://localhost').search) throw new EconomyError('INVALID_BODY', 'I dati del callback devono essere inviati nel corpo della richiesta.');
        const input = await formBody(req);
        const result = await auth.callback(input);
        if (result.platform === 'android') {
          res.writeHead(303, { Location: `intent://callback?code=${result.handoff}&state=${result.state}#Intent;package=cc.sommomi.mymemory;scheme=signinwithapple;end` }); res.end();
        } else {
          const nonce = randomBytes(16).toString('base64url');
          const origin = new URL(auth.config.apple.returnOrigin || 'https://sommomemory.sommomi.cc').origin;
          res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8',
            'Content-Security-Policy': `default-src 'none'; script-src 'nonce-${nonce}'; base-uri 'none'; frame-ancestors 'none'` });
          res.end(`<!doctype html><html lang="it"><meta charset="utf-8"><title>Accesso SommoMemory</title><p>Accesso verificato. Puoi tornare a SommoMemory.</p><script nonce="${nonce}">if(window.opener){window.opener.postMessage(${JSON.stringify({ type: 'sommomemory-auth', state: result.state, authorizationCode: result.handoff })},${JSON.stringify(origin)});window.close();}</script></html>`);
        }
        return true;
      }
      const token = req.headers.authorization?.match(/^Bearer ([A-Za-z0-9_-]{43})$/)?.[1];
      auth.tokenRow(token);
      let result;
      if (route === 'POST /api/v1/auth/attempts') result = auth.attempt(token, await readJsonBody(req));
      else if (route === 'POST /api/v1/auth/exchange') result = await auth.exchange(token, await readJsonBody(req));
      else if (route === 'POST /api/v1/auth/confirm') result = auth.confirm(token, await readJsonBody(req));
      else if (route === 'POST /api/v1/auth/reauth/recovery') result = auth.verifyRecovery(token, await readJsonBody(req));
      else if (route === 'GET /api/v1/profile/identities') result = auth.identities(token);
      else if (route === 'GET /api/v1/profile/sessions') result = auth.sessions(token);
      else if (req.method === 'DELETE' && /^\/api\/v1\/profile\/identities\/(apple|google)$/.test(pathname)) {
        await readJsonBody(req); result = auth.unlink(token, pathname.split('/').at(-1));
      } else if (req.method === 'DELETE' && /^\/api\/v1\/profile\/sessions\/[A-Za-z0-9_-]{24}$/.test(pathname)) {
        await readJsonBody(req); result = auth.revokeSession(token, pathname.split('/').at(-1));
      } else throw new EconomyError('NOT_FOUND', 'Servizio non trovato.', 404);
      reply(200, result);
    } catch (error) {
      const safe = error instanceof EconomyError;
      // Do not log external token responses, subjects, authorization codes or request bodies.
      if (!safe) console.error('Authentication request failed');
      const status = safe ? error.status : 500;
      if ([408, 413, 415].includes(status)) res.setHeader('Connection', 'close');
      reply(status, { error: { code: safe ? error.code : 'SERVER_ERROR', message: safe ? error.message : 'Errore del servizio. Riprova più tardi.' } });
    }
    return true;
  };
  handler.close = () => counters.clear();
  return handler;
}
