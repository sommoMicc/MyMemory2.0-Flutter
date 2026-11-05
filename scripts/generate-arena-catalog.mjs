#!/usr/bin/env node
import { readFile, writeFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import path from 'node:path';
import { validateArenaCatalog } from '../server/src/arenas.mjs';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const source = path.join(root, 'server/catalog/arenas.v1.json');
const output = path.join(root, 'app/lib/arena_catalog_data.g.dart');
const data = JSON.parse(await readFile(source, 'utf8'));
validateArenaCatalog(data);
const rendered = `// GENERATED FILE. Do not edit; run scripts/generate-arena-catalog.mjs.\nconst arenaCatalogData = ${dart(data)};\n`;

function dart(value, indent = 2) {
  const pad = ' '.repeat(indent);
  if (Array.isArray(value)) return `<Object?>[\n${value.map(v => `${pad}  ${dart(v, indent + 2)},`).join('\n')}\n${pad}]`;
  if (value && typeof value === 'object') return `<String, Object?>{\n${Object.entries(value).map(([k, v]) => `${pad}  ${JSON.stringify(k)}: ${dart(v, indent + 2)},`).join('\n')}\n${pad}}`;
  return JSON.stringify(value);
}

if (process.argv.includes('--check')) {
  let current;
  try { current = await readFile(output, 'utf8'); } catch {}
  if (current !== rendered) {
    console.error('Arena catalog Dart output is missing or stale. Run node scripts/generate-arena-catalog.mjs.');
    process.exitCode = 1;
  }
} else {
  await writeFile(output, rendered);
}
