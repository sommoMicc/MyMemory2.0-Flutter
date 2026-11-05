#!/usr/bin/env node
// Run as the service user, with the private persistent data directory mounted.
// This never accesses player credentials or removes existing passkeys.
import { randomBytes } from 'node:crypto';
import { mkdirSync, writeFileSync } from 'node:fs';
import { resolve, dirname, join } from 'node:path';
const args = process.argv.slice(2);
const value = name => args.find(a => a.startsWith(`--${name}=`))?.slice(name.length + 3);
const dataDir = value('data-dir') || process.env.DATA_DIR;
const output = value('output');
if (!dataDir || !output) {
  console.error('Usage: node scripts/admin-enroll.mjs --data-dir=/private/data --output=/private/admin-activation.txt [--origin=https://sommomemory.sommomi.cc] [--recover]');
  process.exit(1);
}
const origin = new URL(value('origin') || 'https://sommomemory.sommomi.cc');
if ((origin.protocol !== 'https:' && !(origin.protocol === 'http:' && ['localhost','127.0.0.1','[::1]'].includes(origin.hostname))) || origin.pathname !== '/' || origin.search || origin.hash || origin.username || origin.password) throw new Error('Use an HTTPS origin, or HTTP loopback for local development.');
const token = randomBytes(32).toString('base64url'), expiresAt = Date.now() + 30 * 60_000;
const recovery = args.includes('--recover'), target = resolve(output);
mkdirSync(resolve(dataDir), { recursive: true, mode: 0o700 });
mkdirSync(dirname(target), { recursive: true, mode: 0o700 });
// Refuse to overwrite an arbitrary destination; private activation artifacts
// are intentionally created outside the repository and never printed.
writeFileSync(target, `SommoMemory · Attivazione admin\n\nApri: ${origin.origin}/admin\nCodice monouso: ${token}\nScade: ${new Date(expiresAt).toISOString()}\n\nLa passkey viene creata sul tuo dispositivo. Dopo l’attivazione elimina questo file.\n`, { mode: 0o600, flag: 'wx' });
writeFileSync(join(resolve(dataDir), 'admin-enrollment.json'), JSON.stringify({ token, expiresAt, recovery }), { mode: 0o600 });
console.log(`Codice monouso salvato in ${target}. Valido per 30 minuti. Nessuna passkey è stata generata sul server.`);
