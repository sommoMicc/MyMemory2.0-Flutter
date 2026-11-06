#!/usr/bin/env node
// Flutter's generated entrypoint has a stable name. Use its content hash so a
// browser that has cached a prior release cannot keep serving the old UI.
import { readFile, writeFile } from 'node:fs/promises';
import { createHash } from 'node:crypto';
import { resolve, join } from 'node:path';
import { prepareOfflineWeb } from './offline-web.mjs';
const root = resolve(process.argv[2] ?? 'app/build/web');
const bytes = await readFile(join(root, 'main.dart.js'));
const hash = createHash('sha256').update(bytes).digest('hex').slice(0, 16);
const filename = `main.${hash}.dart.js`;
const bootstrapPath = join(root, 'flutter_bootstrap.js');
const bootstrap = await readFile(bootstrapPath, 'utf8');
if (bootstrap.includes(filename)) {
  const existing = await readFile(join(root, filename));
  if (!existing.equals(bytes)) throw new Error('Versioned web entrypoint content mismatch');
} else {
  const original = '"mainJsPath":"main.dart.js"';
  if (bootstrap.split(original).length !== 2) throw new Error('Expected one Flutter JavaScript entrypoint');
  await writeFile(join(root, filename), bytes);
  await writeFile(bootstrapPath, bootstrap.replace(original, `"mainJsPath":"${filename}"`));
}
await prepareOfflineWeb(root, filename);
console.log(`Web entrypoint: ${filename}`);
