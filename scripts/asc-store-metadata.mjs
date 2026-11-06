#!/usr/bin/env node
// Applies the approved 3.1.0 metadata in Italian or English, or uploads screenshots.
// App Store Connect API authentication stays in asc.mjs; signed asset URLs are
// used directly without forwarding the API bearer token.
import { createHash } from 'node:crypto';
import { readFile, readdir, stat, mkdir, writeFile } from 'node:fs/promises';
import { basename, extname, join, resolve, relative } from 'node:path';
import { request } from './asc.mjs';

const APP_ID = '6831015201';
const TARGET_VERSION = '3.1.0';
const LOCALE = process.env.ASC_STORE_LOCALE || 'it';
assert(['it', 'en-US', 'en-GB'].includes(LOCALE), 'Localizzazione store non supportata.');
const ROOT = process.cwd();
const DATA = JSON.parse(await readFile(join(ROOT, `scripts/store-metadata-3.1.${LOCALE}.json`), 'utf8'));
const RECEIPT_DIR = resolve(ROOT, process.env.ASC_STORE_RECEIPT_DIR || 'artifacts/store-30017');
const RECEIPT = join(RECEIPT_DIR, LOCALE === 'it' ? 'apple-metadata.json' : `apple-metadata-${LOCALE}.json`);
const APPLE_HOST = /(^|\.)apple\.com$/i;
const WAIT_MS = 10000;
const MAX_POLLS = 120;

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

function localeMatches(locale) {
  return locale === LOCALE || (LOCALE === 'it' && locale === 'it-IT');
}

function localeRecord(rows, label) {
  const exact = rows.find(row => row.attributes.locale === LOCALE);
  const match = exact || (LOCALE === 'it' ? rows.find(row => row.attributes.locale === 'it-IT') : null);
  assert(match, `Localizzazione ${LOCALE} ${label} non trovata.`);
  return match;
}

async function getAll(path) {
  const all = [];
  let next = path;
  while (next) {
    const page = await request(next);
    all.push(...(page.data || []));
    next = page.links?.next ? new URL(page.links.next).pathname + new URL(page.links.next).search : null;
  }
  return all;
}

async function writeReceipt(payload) {
  await mkdir(RECEIPT_DIR, { recursive: true });
  let existing = {};
  try { existing = JSON.parse(await readFile(RECEIPT, 'utf8')); }
  catch (error) { if (error.code !== 'ENOENT') throw error; }
  const combined = {
    ...existing,
    appId: payload.appId,
    version: payload.version,
    locale: payload.locale,
    [payload.mode]: payload,
    verifiedAt: payload.verifiedAt,
  };
  await writeFile(RECEIPT, `${JSON.stringify(combined, null, 2)}\n`, { mode: 0o600 });
}

function checkTextLimits() {
  const limits = {
    'apple.appName': 30, 'apple.subtitle': 30, 'apple.description': 4000,
    'apple.promotionalText': 170, 'apple.keywords': 100, 'apple.whatsNew': 4000,
    'apple.betaDescription': 4000, 'apple.betaNotes': 4000,
    'play.shortDescription': 80, 'play.fullDescription': 4000, 'play.releaseNotes': 500,
  };
  for (const key of Object.keys(limits)) {
    const value = key.split('.').reduce((item, part) => item[part], DATA);
    assert(typeof value === 'string' && value.length <= limits[key], `${key} supera il limite o non è testo.`);
  }
}

async function applyText() {
  checkTextLimits();
  const receipt = { appId: APP_ID, version: TARGET_VERSION, locale: LOCALE, mode: 'text', changes: {}, verifiedAt: null };

  const infoRows = await getAll(`/v1/apps/${APP_ID}/appInfos?limit=200`);
  assert(infoRows.length > 0, 'Nessun App Info trovato per l’app.');
  const info = infoRows[0];
  assert(info.attributes.appStoreState === 'PREPARE_FOR_SUBMISSION', 'App Info non modificabile: interrompo prima delle modifiche.');
  const infoLocs = await getAll(`/v1/appInfos/${info.id}/appInfoLocalizations?limit=200`);
  let infoLoc = infoLocs.find(row => localeMatches(row.attributes.locale));
  if (!infoLoc) infoLoc = (await request('/v1/appInfoLocalizations', {
    method: 'POST', body: { data: { type: 'appInfoLocalizations', attributes: { locale: LOCALE, name: DATA.apple.appName, subtitle: DATA.apple.subtitle, privacyPolicyUrl: DATA.privacyURL }, relationships: { appInfo: { data: { type: 'appInfos', id: info.id } } } } },
  })).data;
  const infoAttributes = {
    name: DATA.apple.appName,
    subtitle: DATA.apple.subtitle,
    privacyPolicyUrl: DATA.privacyURL,
  };
  const patchedInfo = await request(`/v1/appInfoLocalizations/${infoLoc.id}`, {
    method: 'PATCH',
    body: { data: { type: 'appInfoLocalizations', id: infoLoc.id, attributes: infoAttributes } },
  });
  assert(patchedInfo?.data?.id === infoLoc.id, 'Aggiornamento App Info senza conferma leggibile.');

  const versions = await getAll(`/v1/apps/${APP_ID}/appStoreVersions?filter[platform]=IOS&limit=200`);
  const target = versions.find(v => v.attributes.versionString === TARGET_VERSION && v.attributes.appStoreState === 'PREPARE_FOR_SUBMISSION');
  const editable = target || versions.find(v => v.attributes.versionString === '1.0' && v.attributes.appStoreState === 'PREPARE_FOR_SUBMISSION');
  assert(editable, 'Serve una versione iOS in PREPARE_FOR_SUBMISSION, versione attuale 1.0 o 3.1.0.');
  if (editable.attributes.versionString !== TARGET_VERSION) {
    const changed = await request(`/v1/appStoreVersions/${editable.id}`, {
      method: 'PATCH',
      body: { data: { type: 'appStoreVersions', id: editable.id, attributes: { versionString: TARGET_VERSION } } },
    });
    assert(changed?.data?.attributes?.versionString === TARGET_VERSION, 'La versione App Store non è passata a 3.1.0.');
  }
  const version = (await request(`/v1/appStoreVersions/${editable.id}`)).data;
  assert(version.attributes.versionString === TARGET_VERSION && version.attributes.appStoreState === 'PREPARE_FOR_SUBMISSION', 'La versione 3.1.0 non è modificabile o non è in preparazione.');

  const versionLocs = await getAll(`/v1/appStoreVersions/${version.id}/appStoreVersionLocalizations?limit=200`);
  let versionLoc = versionLocs.find(row => localeMatches(row.attributes.locale));
  if (!versionLoc) versionLoc = (await request('/v1/appStoreVersionLocalizations', {
    method: 'POST', body: { data: { type: 'appStoreVersionLocalizations', attributes: { locale: LOCALE, description: DATA.apple.description, keywords: DATA.apple.keywords, promotionalText: DATA.apple.promotionalText, marketingUrl: 'https://sommomemory.sommomi.cc', supportUrl: DATA.supportURL }, relationships: { appStoreVersion: { data: { type: 'appStoreVersions', id: version.id } } } } },
  })).data;
  const versionAttributes = {
    description: DATA.apple.description,
    keywords: DATA.apple.keywords,
    promotionalText: DATA.apple.promotionalText,
    marketingUrl: 'https://sommomemory.sommomi.cc',
    supportUrl: DATA.supportURL,
  };
  const patchedVersion = await request(`/v1/appStoreVersionLocalizations/${versionLoc.id}`, {
    method: 'PATCH',
    body: { data: { type: 'appStoreVersionLocalizations', id: versionLoc.id, attributes: versionAttributes } },
  });
  assert(patchedVersion?.data?.id === versionLoc.id, 'Aggiornamento localizzazione App Store senza conferma leggibile.');

  const betaLocs = await getAll(`/v1/apps/${APP_ID}/betaAppLocalizations?limit=200`);
  let betaLoc = betaLocs.find(row => localeMatches(row.attributes.locale));
  if (betaLoc) {
    const patchedBeta = await request(`/v1/betaAppLocalizations/${betaLoc.id}`, {
      method: 'PATCH',
      body: { data: { type: 'betaAppLocalizations', id: betaLoc.id, attributes: { description: DATA.apple.betaDescription } } },
    });
    assert(patchedBeta?.data?.id === betaLoc.id, 'Aggiornamento beta localization senza conferma leggibile.');
  } else {
    const created = await request('/v1/betaAppLocalizations', {
      method: 'POST',
      body: { data: {
        type: 'betaAppLocalizations',
        attributes: { locale: LOCALE, description: DATA.apple.betaDescription },
        relationships: { app: { data: { type: 'apps', id: APP_ID } } },
      } },
    });
    betaLoc = created.data;
  }

  const [infoRead, versionRead, betaRead] = await Promise.all([
    request(`/v1/appInfoLocalizations/${infoLoc.id}`),
    request(`/v1/appStoreVersionLocalizations/${versionLoc.id}`),
    request(`/v1/betaAppLocalizations/${betaLoc.id}`),
  ]);
  const expected = [
    [infoRead.data.attributes, infoAttributes, 'App Info'],
    [versionRead.data.attributes, versionAttributes, 'App Store'],
    [betaRead.data.attributes, { description: DATA.apple.betaDescription }, 'Beta'],
  ];
  for (const [actual, wanted, label] of expected) {
    for (const [key, value] of Object.entries(wanted)) assert(actual[key] === value, `Readback ${label}.${key} non coincide col testo approvato.`);
  }
  receipt.changes = {
    appInfoLocalizationId: infoLoc.id,
    appStoreVersionId: version.id,
    appStoreVersionLocalizationId: versionLoc.id,
    betaAppLocalizationId: betaLoc.id,
    appInfo: infoAttributes,
    appStore: versionAttributes,
    beta: { description: DATA.apple.betaDescription },
    readbackVerified: true,
  };
  receipt.verifiedAt = new Date().toISOString();
  await writeReceipt(receipt);
  console.log(JSON.stringify({ receipt: relative(ROOT, RECEIPT), version: TARGET_VERSION, locale: LOCALE, readbackVerified: true, ids: { appInfoLocalization: infoLoc.id, appStoreVersion: version.id, appStoreVersionLocalization: versionLoc.id, betaAppLocalization: betaLoc.id } }, null, 2));
}

function pngDimensions(buffer) {
  const signature = Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]);
  assert(buffer.length >= 24 && buffer.subarray(0, 8).equals(signature) && buffer.toString('ascii', 12, 16) === 'IHDR', 'File PNG non valido.');
  const colorType = buffer[25];
  const channels = { 0: 1, 2: 3, 3: 3, 4: 2, 6: 4 }[colorType];
  assert(channels, 'Tipo colore PNG non valido.');
  let ended = false;
  for (let offset = 8; offset < buffer.length;) {
    assert(offset + 12 <= buffer.length, 'Chunk PNG incompleto.');
    const length = buffer.readUInt32BE(offset);
    const type = buffer.toString('ascii', offset + 4, offset + 8);
    const end = offset + 12 + length;
    assert(end <= buffer.length, `${type}: lunghezza chunk PNG non valida.`);
    let crc = 0xffffffff;
    for (const byte of buffer.subarray(offset + 4, end - 4)) {
      crc ^= byte;
      for (let bit = 0; bit < 8; bit++) crc = (crc >>> 1) ^ ((crc & 1) ? 0xedb88320 : 0);
    }
    assert(((crc ^ 0xffffffff) >>> 0) === buffer.readUInt32BE(end - 4), `${type}: CRC PNG non valido.`);
    if (type === 'sBIT') assert(length === channels, 'sBIT PNG non coerente con il tipo colore.');
    offset = end;
    if (type === 'IEND') {
      assert(length === 0 && offset === buffer.length, 'Terminazione PNG non valida.');
      ended = true;
    }
  }
  assert(ended, 'Terminazione PNG mancante.');
  return { width: buffer.readUInt32BE(16), height: buffer.readUInt32BE(20) };
}

async function screenshotFiles(rootDir) {
  const root = resolve(rootDir);
  const output = [];
  for (const [folder, displayType, width, height] of [
    ['iphone', 'APP_IPHONE_67', 1320, 2868],
    ['ipad', 'APP_IPAD_PRO_3GEN_129', 2064, 2752],
  ]) {
    const directory = join(root, folder);
    let names;
    try { names = await readdir(directory); }
    catch (error) { if (error.code === 'ENOENT') continue; throw error; }
    for (const name of names.sort((a, b) => a.localeCompare(b, 'en'))) {
      const path = join(directory, name);
      const fileStat = await stat(path);
      if (!fileStat.isFile()) continue;
      const extension = extname(name).toLowerCase();
      if (extension === '.json') continue; // Capture provenance sidecars are not store assets.
      assert(extension === '.png', `${path}: sono supportati solo PNG; convertire prima JPEG in PNG standard.`);
      const bytes = await readFile(path);
      const dimensions = pngDimensions(bytes);
      assert(dimensions.width === width && dimensions.height === height, `${path}: ${dimensions.width}x${dimensions.height}, attesi ${width}x${height}.`);
      output.push({ path, fileName: basename(path), displayType, width, height, bytes, fileSize: bytes.length, md5: createHash('md5').update(bytes).digest('hex') });
    }
  }
  assert(output.length > 0, 'Nessuna immagine PNG trovata in iphone/ o ipad/.');
  for (const item of output) assert(item.fileName.length <= 255, `Nome file troppo lungo: ${item.fileName}`);
  const groups = new Map();
  for (const item of output) groups.set(item.displayType, (groups.get(item.displayType) || 0) + 1);
  for (const [type, count] of groups) assert(count <= 10, `${type}: massimo 10 screenshot per set.`);
  return output;
}

async function loadVersionLocalization() {
  const versions = await getAll(`/v1/apps/${APP_ID}/appStoreVersions?filter[platform]=IOS&limit=200`);
  const version = versions.find(v => v.attributes.versionString === TARGET_VERSION && v.attributes.appStoreState === 'PREPARE_FOR_SUBMISSION');
  assert(version, 'Screenshot caricabili solo per la versione 3.1.0 in PREPARE_FOR_SUBMISSION.');
  const locs = await getAll(`/v1/appStoreVersions/${version.id}/appStoreVersionLocalizations?limit=200`);
  return { version, localization: localeRecord(locs, 'App Store') };
}

async function screenshotSet(localizationId, displayType) {
  const sets = await getAll(`/v1/appStoreVersionLocalizations/${localizationId}/appScreenshotSets?limit=200`);
  let set = sets.find(row => row.attributes.screenshotDisplayType === displayType);
  if (!set) {
    const created = await request('/v1/appScreenshotSets', {
      method: 'POST',
      body: { data: {
        type: 'appScreenshotSets',
        attributes: { screenshotDisplayType: displayType },
        relationships: { appStoreVersionLocalization: { data: { type: 'appStoreVersionLocalizations', id: localizationId } } },
      } },
    });
    set = created.data;
  }
  return set;
}

async function uploadPart(operation, bytes) {
  const url = new URL(operation.url);
  assert(url.protocol === 'https:' && APPLE_HOST.test(url.hostname), 'URL di upload non HTTPS o host non Apple: rifiutato.');
  assert(operation.method === 'PUT', `Metodo upload non supportato: ${operation.method}`);
  const offset = Number(operation.offset ?? 0);
  const length = Number(operation.length ?? (bytes.length - offset));
  assert(Number.isInteger(offset) && Number.isInteger(length) && offset >= 0 && length > 0 && offset + length <= bytes.length, 'Intervallo upload non valido.');
  const headers = Object.fromEntries((operation.requestHeaders || []).map(({ name, value }) => [name, value]));
  assert(!Object.keys(headers).some(key => key.toLowerCase() === 'authorization'), 'Header Authorization non ammesso sull’URL firmato asset.');
  const response = await fetch(url, { method: 'PUT', headers, body: bytes.subarray(offset, offset + length), redirect: 'error' });
  if (!response.ok) throw new Error(`Upload asset fallito (${response.status}).`);
}

function sleep(ms) { return new Promise(resolvePromise => setTimeout(resolvePromise, ms)); }

async function uploadScreenshot(item, set, existingRows) {
  const completeSame = existingRows.find(row => row.attributes.assetDeliveryState?.state === 'COMPLETE' && row.attributes.fileName === item.fileName && String(row.attributes.sourceFileChecksum || '').toLowerCase() === item.md5);
  if (completeSame) return { id: completeSame.id, fileName: item.fileName, state: 'COMPLETE', checksum: item.md5, skipped: true };
  const filenameCollision = existingRows.find(row => row.attributes.fileName === item.fileName);
  if (filenameCollision && filenameCollision.attributes.fileSize === item.fileSize && filenameCollision.attributes.assetDeliveryState?.state === 'UPLOAD_COMPLETE') {
    // A completed upload can keep processing after the command's wait window.
    // Resume its status checks; never reserve or transmit the same asset again.
    let current = filenameCollision;
    for (let attempt = 0; attempt < MAX_POLLS && current.attributes.assetDeliveryState?.state === 'UPLOAD_COMPLETE'; attempt++) {
      await sleep(WAIT_MS);
      current = (await request(`/v1/appScreenshots/${filenameCollision.id}`)).data;
    }
    assert(current.attributes.assetDeliveryState?.state === 'COMPLETE', `${item.fileName}: screenshot ancora in elaborazione o fallito.`);
    assert(String(current.attributes.sourceFileChecksum || '').toLowerCase() === item.md5, `${item.fileName}: checksum dell'asset ripreso diverso dal file locale.`);
    return { id: current.id, fileName: item.fileName, state: 'COMPLETE', checksum: item.md5, skipped: true, resumed: true };
  }
  assert(!filenameCollision, `${item.fileName}: nome già presente con checksum diverso o stato non COMPLETE; non sovrascrivo screenshot esistenti.`);

  const reserved = await request('/v1/appScreenshots', {
    method: 'POST',
    body: { data: {
      type: 'appScreenshots',
      attributes: { fileName: item.fileName, fileSize: item.fileSize },
      relationships: { appScreenshotSet: { data: { type: 'appScreenshotSets', id: set.id } } },
    } },
  });
  const reservation = reserved.data;
  assert(reservation?.id && Array.isArray(reservation.attributes.uploadOperations) && reservation.attributes.uploadOperations.length, 'La reservation screenshot non contiene operazioni di upload.');
  const operations = [...reservation.attributes.uploadOperations].sort((a, b) => a.offset - b.offset);
  for (const operation of operations) await uploadPart(operation, item.bytes);
  const committed = await request(`/v1/appScreenshots/${reservation.id}`, {
    method: 'PATCH',
    body: { data: { type: 'appScreenshots', id: reservation.id, attributes: { uploaded: true, sourceFileChecksum: item.md5 } } },
  });
  let state = committed.data?.attributes?.assetDeliveryState?.state || 'UPLOAD_COMPLETE';
  for (let attempt = 0; attempt < MAX_POLLS && !['COMPLETE', 'FAILED'].includes(state); attempt++) {
    await sleep(WAIT_MS);
    const current = await request(`/v1/appScreenshots/${reservation.id}`);
    state = current.data.attributes.assetDeliveryState?.state || 'UPLOAD_COMPLETE';
  }
  assert(state === 'COMPLETE', `${item.fileName}: processamento screenshot ${state === 'FAILED' ? 'FAILED' : 'senza esito dopo il timeout'}.`);
  return { id: reservation.id, fileName: item.fileName, state, checksum: item.md5, skipped: false };
}

async function uploadScreenshots(directory, replaceExisting = false) {
  const files = await screenshotFiles(directory);
  const { version, localization } = await loadVersionLocalization();
  const receipt = { appId: APP_ID, version: TARGET_VERSION, locale: localization.attributes.locale, mode: 'screenshots', versionId: version.id, localizationId: localization.id, screenshots: [], verifiedAt: null };
  await Promise.all([...new Set(files.map(item => item.displayType))].map(async displayType => {
    const set = await screenshotSet(localization.id, displayType);
    let existing = await getAll(`/v1/appScreenshotSets/${set.id}/appScreenshots?limit=200`);
    const items = files.filter(item => item.displayType === displayType);
    // Independent files may process at very different speeds on Apple's servers.
    // Reserve and send them together; restore the requested order after all finish.
    const uploaded = await Promise.all(items.map(item => uploadScreenshot(item, set, existing)));
    const desired = uploaded.map(result => result.id);
    receipt.screenshots.push(...uploaded.map(result => ({ displayType, ...result })));
    if (replaceExisting) {
      // Keep the previous images until every replacement has processed fully.
      existing = await getAll(`/v1/appScreenshotSets/${set.id}/appScreenshots?limit=200`);
      for (const row of existing.filter(row => !desired.includes(row.id))) {
        await request(`/v1/appScreenshots/${row.id}`, { method: 'DELETE' });
      }
      await request(`/v1/appScreenshotSets/${set.id}/relationships/appScreenshots`, {
        method: 'PATCH', body: { data: desired.map(id => ({ type: 'appScreenshots', id })) },
      });
      const readback = await getAll(`/v1/appScreenshotSets/${set.id}/appScreenshots?limit=200`);
      assert(readback.length === desired.length && readback.every((row, i) => row.id === desired[i] && row.attributes.assetDeliveryState?.state === 'COMPLETE'), `${displayType}: readback delle sostituzioni non coincide.`);
    }
  }));
  receipt.screenshots.sort((a, b) => a.displayType.localeCompare(b.displayType) || a.fileName.localeCompare(b.fileName));
  receipt.replacedExisting = replaceExisting;
  receipt.verifiedAt = new Date().toISOString();
  await writeReceipt(receipt);
  console.log(JSON.stringify({ receipt: relative(ROOT, RECEIPT), version: TARGET_VERSION, locale: receipt.locale, replacedExisting: replaceExisting, screenshots: receipt.screenshots.map(({ id, fileName, displayType, state, skipped }) => ({ id, fileName, displayType, state, skipped })) }, null, 2));
}

async function main(args) {
  const textMode = args.includes('--apply-text');
  const screenshotArg = args.find(arg => arg.startsWith('--screenshots='));
  assert(Number(textMode) + Number(Boolean(screenshotArg)) === 1, 'Uso: node scripts/asc-store-metadata.mjs --apply-text | --screenshots=DIR');
  if (textMode) await applyText();
  else if (args.includes('--validate-only')) {
    const files = await screenshotFiles(screenshotArg.slice('--screenshots='.length));
    console.log(JSON.stringify({ locale: LOCALE, validated: files.length, apiCalled: false }));
  }
  else await uploadScreenshots(screenshotArg.slice('--screenshots='.length), args.includes('--replace-existing'));
}

try {
  await main(process.argv.slice(2));
} catch (error) {
  console.error(error.message);
  process.exitCode = 1;
}
