import { createServer } from 'node:http';
import { createReadStream, existsSync, statSync } from 'node:fs';
import { dirname, extname, resolve, sep } from 'node:path';
import { fileURLToPath } from 'node:url';
import { WebSocket, WebSocketServer } from 'ws';
import { GameEngine, GameError } from './game.mjs';

const here = dirname(fileURLToPath(import.meta.url));
const mime = { '.html': 'text/html; charset=utf-8', '.js': 'text/javascript', '.mjs': 'text/javascript',
  '.json': 'application/json', '.wasm': 'application/wasm', '.css': 'text/css', '.png': 'image/png',
  '.jpg': 'image/jpeg', '.svg': 'image/svg+xml', '.ico': 'image/x-icon', '.woff2': 'font/woff2',
  '.ttf': 'font/ttf', '.bin': 'application/octet-stream' };

export function startServer({ port = Number(process.env.PORT || 8787), host = process.env.HOST || '127.0.0.1',
  dataDir = process.env.DATA_DIR || resolve(here, '../data'),
  webDir = process.env.WEB_DIR || resolve(here, '../../app/build/web'),
  allowedOrigins = process.env.ALLOWED_ORIGINS || 'https://mymemory.sommomi.cc,http://localhost:8080,http://127.0.0.1:8080',
  trustProxy = process.env.TRUST_PROXY === '1', engine: providedEngine } = {}) {
  const engine = providedEngine || new GameEngine({ dataDir });
  const sockets = new Map();
  const byAddress = new Map();
  const origins = new Set(allowedOrigins.split(',').map(s => s.trim()));
  const send = (ws, value) => {
    if (ws.readyState === WebSocket.OPEN && ws.bufferedAmount < 256 * 1024) ws.send(JSON.stringify(value));
    else if (ws.bufferedAmount >= 256 * 1024) ws.terminate();
  };
  const sessionsFor = code => [...sockets.values()].filter(s => s.code === code);

  const http = createServer((req, res) => {
    res.setHeader('X-Content-Type-Options', 'nosniff');
    res.setHeader('Referrer-Policy', 'strict-origin-when-cross-origin');
    res.setHeader('Permissions-Policy', 'camera=(), microphone=(), geolocation=()');
    if (req.method !== 'GET' && req.method !== 'HEAD') { res.writeHead(405); res.end(); return; }
    let pathname;
    try { pathname = decodeURIComponent(new URL(req.url, 'http://localhost').pathname); }
    catch { res.writeHead(400); res.end(); return; }
    if (pathname === '/healthz') {
      res.writeHead(200, { 'Content-Type': 'application/json', 'Cache-Control': 'no-store' });
      res.end(JSON.stringify({ ok: true, service: 'mymemory', protocol: 1, rooms: engine.rooms.size }));
      return;
    }
    let path;
    if (['/privacy', '/privacy/', '/support', '/support/'].includes(pathname)) {
      path = resolve(here, '../public', pathname.includes('privacy') ? 'privacy.html' : 'support.html');
    } else {
      path = resolve(webDir, `.${pathname}`);
      if (path !== resolve(webDir) && !path.startsWith(resolve(webDir) + sep)) { res.writeHead(403); res.end(); return; }
      if (existsSync(path) && statSync(path).isDirectory()) path = resolve(path, 'index.html');
      if (!existsSync(path) && !extname(pathname)) path = resolve(webDir, 'index.html');
    }
    if (!existsSync(path) || !statSync(path).isFile()) { res.writeHead(404); res.end('Not found'); return; }
    res.writeHead(200, { 'Content-Type': mime[extname(path)] || 'application/octet-stream',
      'Cache-Control': ['.html', '.js', '.mjs', '.json'].includes(extname(path)) ? 'no-cache' : 'public, max-age=3600' });
    if (req.method === 'HEAD') res.end();
    else createReadStream(path).on('error', () => res.destroy()).pipe(res);
  });
  const wss = new WebSocketServer({ noServer: true, maxPayload: 4096, perMessageDeflate: false });
  http.on('upgrade', (req, socket, head) => {
    const origin = req.headers.origin;
    const path = req.url?.split('?')[0];
    if (path !== '/ws' || (origin && !origins.has(origin))) {
      socket.end('HTTP/1.1 403 Forbidden\r\nConnection: close\r\n\r\n'); return;
    }
    const address = trustProxy && req.headers['x-forwarded-for'] ?
      String(req.headers['x-forwarded-for']).split(',')[0].trim() : req.socket.remoteAddress;
    if ((byAddress.get(address) || 0) >= 32) {
      socket.end('HTTP/1.1 429 Too Many Requests\r\nConnection: close\r\n\r\n'); return;
    }
    wss.handleUpgrade(req, socket, head, ws => wss.emit('connection', ws, req, address));
  });

  engine.on('change', code => {
    const state = engine.state(code);
    for (const { ws } of sessionsFor(code)) send(ws, state);
  });
  engine.on('removed', code => {
    for (const session of sessionsFor(code)) {
      sockets.delete(session.ws);
      send(session.ws, { type: 'error', code: 'ROOM_EXPIRED', message: 'La stanza è scaduta. Crea una nuova partita.' });
      send(session.ws, { type: 'left' });
    }
  });

  wss.on('connection', (ws, req, address) => {
    byAddress.set(address, (byAddress.get(address) || 0) + 1);
    ws.alive = true;
    ws.on('pong', () => { ws.alive = true; });
    let windowStart = Date.now(), count = 0;
    ws.on('message', (raw, isBinary) => {
      if (Date.now() - windowStart > 10_000) { windowStart = Date.now(); count = 0; }
      if (++count > 30) { ws.close(1008, 'Rate limit'); return; }
      try {
        if (isBinary) throw new GameError('INVALID_MESSAGE', 'Invia un messaggio valido.');
        let message;
        try { message = JSON.parse(raw.toString()); }
        catch { throw new GameError('INVALID_MESSAGE', 'Invia un messaggio valido.'); }
        if (!message || typeof message !== 'object' || Array.isArray(message)) {
          throw new GameError('INVALID_MESSAGE', 'Invia un messaggio valido.');
        }
        const current = sockets.get(ws);
        if (['create', 'join', 'resume'].includes(message.type)) {
          if (current) throw new GameError('ALREADY_JOINED', 'Esci prima dalla partita attuale.');
          const session = engine[message.type](message);
          const previous = [...sockets.values()].find(s => s.code === session.code && s.playerId === session.playerId);
          if (previous) {
            sockets.delete(previous.ws);
            previous.ws.close(4001, 'Session resumed on another connection');
          }
          sockets.set(ws, { ws, ...session });
          send(ws, { type: 'session', ...session });
          send(ws, engine.state(session.code));
        } else if (message.type === 'ping') send(ws, { type: 'pong', time: Date.now() });
        else {
          if (!current) throw new GameError('NO_SESSION', 'Entra in una stanza per giocare.');
          switch (message.type) {
            case 'flip': engine.flip(current.code, current.playerId, message.index); break;
            case 'rematch': engine.rematch(current.code, current.playerId); break;
            case 'leave':
              sockets.delete(ws);
              engine.leave(current.code, current.playerId);
              send(ws, { type: 'left' });
              break;
            default: throw new GameError('INVALID_MESSAGE', 'Azione non riconosciuta.');
          }
        }
      } catch (error) {
        if (!(error instanceof GameError)) console.error('Request failed:', error.message);
        send(ws, { type: 'error', code: error instanceof GameError ? error.code : 'SERVER_ERROR',
          message: error instanceof GameError ? error.message : 'Errore del servizio. Riprova tra poco.' });
      }
    });
    ws.on('close', () => {
      byAddress.set(address, Math.max(0, (byAddress.get(address) || 1) - 1));
      if (byAddress.get(address) === 0) byAddress.delete(address);
      const session = sockets.get(ws);
      sockets.delete(ws);
      if (session) engine.disconnect(session.code, session.playerId);
    });
    ws.on('error', () => { /* close handles session cleanup */ });
  });
  const tick = setInterval(() => {
    try { engine.tick(); } catch (error) { console.error('Room maintenance failed:', error.message); }
  }, 100);
  tick.unref();
  const heartbeat = setInterval(() => {
    for (const ws of wss.clients) {
      if (!ws.alive) { ws.terminate(); continue; }
      ws.alive = false;
      ws.ping();
    }
  }, 20_000);
  heartbeat.unref();
  http.listen(port, host);
  return { http, wss, engine, close: async () => {
    clearInterval(tick); clearInterval(heartbeat);
    for (const ws of wss.clients) ws.terminate();
    await new Promise(resolveClose => wss.close(resolveClose));
    await new Promise(resolveClose => http.close(resolveClose));
  } };
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const server = startServer();
  server.http.on('listening', () => console.log(`MyMemory listening on ${JSON.stringify(server.http.address())}`));
  let shuttingDown = false;
  const stop = async () => {
    if (shuttingDown) return;
    shuttingDown = true;
    await server.close();
    process.exit(0);
  };
  process.on('SIGTERM', stop);
  process.on('SIGINT', stop);
}
