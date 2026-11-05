import { DECKS, RULES, EconomyError } from './economy.mjs';

const BODY_LIMIT = 64 * 1024;
const invalid = () => new EconomyError('INVALID_BODY', 'Invia un oggetto JSON valido.');
export async function readJsonBody(req) {
  if (!/^application\/json(?:\s*;.*)?$/i.test(req.headers['content-type'] || ''))
    throw new EconomyError('CONTENT_TYPE', 'Usa il formato JSON.', 415);
  const length = Number(req.headers['content-length']);
  if (Number.isFinite(length) && length > BODY_LIMIT) throw new EconomyError('BODY_TOO_LARGE', 'Richiesta troppo grande.', 413);
  const bytes = await new Promise((resolve, reject) => {
    let count = 0, done = false;
    const chunks = [];
    const timer = setTimeout(() => finish(new EconomyError('BODY_TIMEOUT', 'Richiesta incompleta.', 408)), 10_000);
    const finish = (error) => {
      if (done) return;
      done = true;
      clearTimeout(timer);
      if (error) { req.pause(); reject(error); }
      else resolve(Buffer.concat(chunks));
    };
    req.on('data', chunk => {
      if (done) return;
      count += chunk.length;
      if (count > BODY_LIMIT) return finish(new EconomyError('BODY_TOO_LARGE', 'Richiesta troppo grande.', 413));
      chunks.push(chunk);
    });
    req.on('end', () => finish());
    req.on('aborted', () => finish(invalid()));
    req.on('error', () => finish(invalid()));
  });
  let result;
  try { result = JSON.parse(bytes.toString('utf8')); } catch { throw invalid(); }
  if (!result || typeof result !== 'object' || Array.isArray(result)) throw invalid();
  return result;
}
const body = readJsonBody;

export function economyApi({ store, origins, addressOf, now = Date.now, auth }) {
  const counters = new Map();
  function limit(key, max, span) {
    const time = now();
    if (counters.size > 5000) for (const [entry, item] of counters) if (item.until <= time) counters.delete(entry);
    const current = counters.get(key);
    if (!current || current.until <= time) {
      if (counters.size >= 10_000 && !current) throw new EconomyError('RATE_LIMIT', 'Riprova più tardi.', 429);
      counters.set(key, { count: 1, until: time + span });
    } else if (++current.count > max) throw new EconomyError('RATE_LIMIT', 'Troppe richieste. Riprova più tardi.', 429);
  }
  return async (req, res, pathname) => {
    const reply = (status, value) => {
      res.writeHead(status, { 'Content-Type': 'application/json; charset=utf-8', 'Cache-Control': 'no-store' });
      res.end(JSON.stringify(value));
    };
    try {
      const origin = req.headers.origin;
      if (origin && !origins.has(origin)) throw new EconomyError('ORIGIN_DENIED', 'Origine non autorizzata.', 403);
      if (origin) { res.setHeader('Access-Control-Allow-Origin', origin); res.setHeader('Vary', 'Origin'); }
      if (req.method === 'OPTIONS') {
        res.writeHead(204, { 'Access-Control-Allow-Methods': 'GET,POST,PATCH,DELETE,OPTIONS',
          'Access-Control-Allow-Headers': 'Authorization,Content-Type', 'Access-Control-Max-Age': '600' });
        res.end(); return;
      }
      const address = addressOf(req);
      limit(`all:${address}`, 240, 600_000);
      if (pathname === '/api/v1/catalog' && req.method === 'GET') {
        const existing = new Set(DECKS.map(deck => deck.id));
        const additional = store.catalog.decks.filter(deck => deck.contentReady && !existing.has(deck.id))
          .map(deck => ({ id: deck.id, price: deck.price, free: deck.price === 0 }));
        reply(200, { decks: [...DECKS, ...additional], rules: RULES,
          arenas: store.catalog.arenas, rankedEnabled: store.catalog.rankedEnabled }); return;
      }
      if (pathname === '/api/v1/profiles' && req.method === 'POST') {
        limit(`create:${address}`, 10, 86_400_000);
        await body(req);
        reply(201, store.createProfile()); return;
      }
      if (pathname === '/api/v1/profiles/restore/preview' || pathname === '/api/v1/profiles/restore') {
        if (req.method !== 'POST') throw new EconomyError('METHOD_NOT_ALLOWED', 'Metodo non valido.', 405);
        limit(`restore:${address}`, 20, 600_000);
        const input = await body(req);
        if (pathname.endsWith('/preview')) {
          const { linkedProviders, recoveryEnabled, ...profile } = store.recoveryProfile(input.recoveryCode);
          reply(200, { profile });
        } else reply(200, store.restore(input));
        return;
      }
      const token = req.headers.authorization?.match(/^Bearer ([A-Za-z0-9_-]{43})$/)?.[1];
      const id = store.authenticate(token);
      let result;
      const route = `${req.method} ${pathname}`;
      if (route === 'GET /api/v1/profile') result = { profile: store.profile(id) };
      else if (route === 'GET /api/v1/profile/ledger') result = store.ledger(id);
      else if (route === 'PATCH /api/v1/profile') result = store.updateProfile(id, await body(req));
      else if (route === 'DELETE /api/v1/profile') result = auth ? auth.deleteProfile(token, await body(req)) : store.deleteProfile(id, await body(req));
      else if (route === 'POST /api/v1/profile/recovery') { auth?.requireRecent(token); result = store.recovery(id, await body(req)); }
      else if (route === 'POST /api/v1/profile/recovery/rotate') { auth?.requireRecent(token); result = store.recovery(id, await body(req), true); }
      else if (route === 'POST /api/v1/profile/logout') { await body(req); result = store.logout(token); }
      else if (route === 'POST /api/v1/wallet/unlock') result = store.unlock(id, await body(req));
      else if (route === 'POST /api/v1/games/tickets') result = store.issueTicket(id, await body(req));
      else if (route === 'POST /api/v1/games/tickets/batch') result = store.issueBatch(id, await body(req));
      else if (route === 'POST /api/v1/games/claims') result = store.claim(id, await body(req));
      else throw new EconomyError('NOT_FOUND', 'Servizio non trovato.', 404);
      reply(200, result);
    } catch (error) {
      const safe = error instanceof EconomyError;
      if (!safe) console.error('Economy request failed:', error.message);
      const status = safe ? error.status : 500;
      if ([408, 413, 415].includes(status)) res.setHeader('Connection', 'close');
      reply(status, { error: { code: safe ? error.code : 'SERVER_ERROR',
        message: safe ? error.message : 'Errore del servizio. Riprova più tardi.' } });
    }
  };
}
