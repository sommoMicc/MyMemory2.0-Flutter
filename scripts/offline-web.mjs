import { readFile, readdir, writeFile } from 'node:fs/promises';
import { createHash } from 'node:crypto';
import { join } from 'node:path';

export async function prepareOfflineWeb(root, entrypoint) {
  // Small protocol fixtures do not contain a complete Flutter application.
  try { await readFile(join(root, 'index.html')); }
  catch (error) { if (error.code === 'ENOENT') return; throw error; }
  const files = ['index.html', 'flutter_bootstrap.js', entrypoint];
  async function collect(directory) {
    let entries;
    try { entries = await readdir(join(root, directory), { withFileTypes: true }); }
    catch (error) { if (error.code === 'ENOENT') return; throw error; }
    for (const entry of entries) {
      const relative = `${directory}/${entry.name}`;
      if (entry.isDirectory()) await collect(relative);
      else if (!relative.endsWith('.map') && !relative.endsWith('.symbols') &&
          (directory !== 'canvaskit' || !/^(skwasm|wimp)/.test(entry.name))) {
        files.push(relative);
      }
    }
  }
  await collect('assets');
  await collect('canvaskit');
  await collect('icons');
  for (const name of ['favicon.png', 'manifest.json']) {
    try { await readFile(join(root, name)); files.push(name); }
    catch (error) { if (error.code !== 'ENOENT') throw error; }
  }
  files.sort();
  const revision = createHash('sha256');
  for (const file of files) {
    revision.update(file).update('\0').update(await readFile(join(root, file)));
  }
  const template = await readFile(new URL('./offline-worker.template.js', import.meta.url), 'utf8');
  // A change to cache behavior must also use a fresh cache, even if the game's
  // resources are identical, so a failed install cannot remove the active one.
  revision.update(template);
  const worker = template
    .replace('__REVISION__', revision.digest('hex').slice(0, 20))
    .replace('__RESOURCES__', JSON.stringify(files));
  await writeFile(join(root, 'memory_service_worker.js'), worker);
}
