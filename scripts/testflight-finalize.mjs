#!/usr/bin/env node
// Uses Apple's current Build Upload / Builds / Beta Groups API schemas.
// Reference: https://developer.apple.com/documentation/appstoreconnectapi/build-uploads
import { readFile, writeFile, rename } from 'node:fs/promises';
import { resolve } from 'node:path';
import { request, BUNDLE } from './asc.mjs';

const APP = '6831015201';
const GROUP = 'd811d09d-3800-4275-b5c3-8a9773439b1d';
const NOTES = 'Nome aggiornato a SommoMemory: verifica il nome visualizzato nell’app e in TestFlight. Sito e servizio online ora usano https://sommomemory.sommomi.cc. Correzione: punteggio, coppia trovata e risultato compaiono solo dopo che le carte hanno finito di aprirsi; il cambio turno aspetta la completa richiusura di una coppia sbagliata. Durante il flip il tavolo resta bloccato, anche con tocchi rapidi. Verifica in locale, online e Bluetooth, con animazioni normali e Riduci movimento. Scenari a tutto schermo con colline, pianeti oppure onde, personaggi e carte animate. Il movimento ambientale si arresta con Riduci movimento o quando l’app è sospesa. Menu, configurazione e partita devono mantenere contrasto e restare senza scorrimento. Carte con flip 3D, illustrazioni offline nelle collezioni Animali, Spazio e Oceano e retro dedicato. Le righe del tabellone hanno sempre lo stesso numero di carte; tutte le carte devono restare visibili senza scorrere su iPhone e iPad, anche in orizzontale. Collezione e difficoltà vengono ricordate. Prova tutti i tabelloni, Riduci movimento, tastiera, risultati, rivincita e multiplayer online tra iOS, Android e web. Bluetooth offline: verifica su telefoni fisici iPhone e Android in entrambe le direzioni host/ospite, con Internet disattivato, permessi e perdita di connessione.';
const args = process.argv.slice(2);
const help = 'Usage: node scripts/testflight-finalize.mjs [--status | --finalize --build=30008] [--additional-tester=EXISTING_TESTER_ID] [--wait=1200] [--receipt=artifacts/testflight-upload.json]\nDefault: one read-only status check. Finalization requires exactly the account holder unless one existing additional tester ID is explicitly allowed. No memberships are changed. --wait polls every 30s, up to 1800s.';

function assert(value, message) { if (!value) throw new Error(message); }
function argument(name) { return args.find(arg => arg.startsWith(`--${name}=`))?.slice(name.length + 3); }
function id(value) { assert(typeof value === 'string' && /^[a-zA-Z0-9-]+$/.test(value), 'Invalid API resource ID.'); return value; }

async function main() {
  if (args.includes('--help')) { console.log(help); return; }
  assert(args.every(arg => ['--status', '--finalize'].includes(arg) || /^--(build|wait|receipt|additional-tester)=.+$/.test(arg)), help);
  const finalize = args.includes('--finalize');
  assert(!(finalize && args.includes('--status')), 'Choose --status or --finalize.');
  const expectedBuild = argument('build');
  assert(args.filter(arg => arg.startsWith('--additional-tester=')).length <= 1, 'Only one explicit additional tester ID is supported.');
  const additionalTesterId = argument('additional-tester');
  if (additionalTesterId !== undefined) id(additionalTesterId);
  assert(!finalize || /^\d+$/.test(expectedBuild ?? ''), '--finalize requires --build=EXPECTED_BUILD to prevent editing an old receipt.');
  const wait = Number(argument('wait') ?? 0);
  assert(Number.isInteger(wait) && wait >= 0 && wait <= 1800, '--wait must be 0–1800 seconds.');
  const path = resolve(argument('receipt') ?? 'artifacts/testflight-upload.json');
  const receipt = JSON.parse(await readFile(path, 'utf8'));
  assert(receipt.appId === APP && receipt.bundleId === BUNDLE, 'Receipt does not identify the MyMemory app.');
  assert(/^\d+$/.test(receipt.build) && /^\d+\.\d+(?:\.\d+)?$/.test(receipt.version), 'Invalid receipt version/build.');
  assert(!expectedBuild || receipt.build === expectedBuild, `Receipt build ${receipt.build} does not match expected ${expectedBuild}.`);
  const uploadId = id(receipt.buildUploadId);
  const app = (await request(`/v1/apps/${APP}?fields[apps]=bundleId`)).data;
  assert(app.id === APP && app.attributes.bundleId === BUNDLE, 'App Store identity mismatch.');

  async function save(fields) {
    const current = JSON.parse(await readFile(path, 'utf8'));
    assert(current.buildUploadId === uploadId && current.build === receipt.build, 'Receipt changed while finalization was running; stopped.');
    const temporary = `${path}.${process.pid}.tmp`;
    await writeFile(temporary, JSON.stringify({ ...current, ...fields }, null, 2) + '\n');
    await rename(temporary, path);
  }

  const deadline = Date.now() + wait * 1000;
  let build;
  for (;;) {
    const upload = (await request(`/v1/buildUploads/${uploadId}?include=build`)).data;
    const attributes = upload.attributes;
    assert(attributes.cfBundleVersion === receipt.build && attributes.cfBundleShortVersionString === receipt.version && attributes.platform === 'IOS', 'Apple upload does not match receipt version/build/platform.');
    const uploadState = attributes.state?.state;
    const buildId = upload.relationships?.build?.data?.id;
    if (buildId) {
      assert(!receipt.buildId || receipt.buildId === buildId, 'Receipt build ID differs from upload relationship.');
      const response = await request(`/v1/builds/${id(buildId)}?include=app,preReleaseVersion,buildBetaDetail,betaBuildLocalizations`);
      build = response.data;
      const version = response.included?.find(item => item.type === 'preReleaseVersions');
      assert(build.relationships?.app?.data?.id === APP && build.attributes.version === receipt.build && version?.attributes.version === receipt.version && version.attributes.platform === 'IOS', 'Processed build does not belong to the expected MyMemory release.');
      build.included = response.included ?? [];
    }
    console.log(JSON.stringify({ version: receipt.version, build: receipt.build, uploadState, buildProcessingState: build?.attributes.processingState ?? null }));
    // Status mode leaves both Apple resources and the receipt unchanged.
    if (finalize) await save({ processingState: uploadState, buildProcessingState: build?.attributes.processingState ?? null, ...(build ? { buildId: build.id } : {}), lastCheckedAt: new Date().toISOString() });
    assert(uploadState !== 'FAILED' && !['FAILED', 'INVALID'].includes(build?.attributes.processingState), `Apple rejected the build: ${JSON.stringify(attributes.state?.errors ?? [])}`);
    if (uploadState === 'COMPLETE' && build?.attributes.processingState === 'VALID') break;
    if (Date.now() >= deadline) { process.exitCode = 2; console.log('Processing pending. Run this command again when Apple finishes.'); return; }
    await new Promise(resolve => setTimeout(resolve, Math.min(30000, deadline - Date.now())));
  }
  assert(!build.attributes.expired, 'The processed build is expired.');
  const betaDetail = build.included.find(item => item.type === 'buildBetaDetails');
  if (!finalize) {
    console.log(JSON.stringify({ buildId: build.id, internalBuildState: betaDetail?.attributes.internalBuildState ?? null, readOnly: true }));
    return;
  }

  // Validate the complete existing membership before any remote mutation.
  // The optional flag allows distribution to an already-present tester only;
  // it never creates/invites a tester or changes group membership.
  const checked = await request(`/v1/betaGroups/${GROUP}?include=app,betaTesters,builds`);
  const group = checked.data;
  assert(group.attributes.isInternalGroup === true && group.attributes.publicLinkEnabled !== true && group.relationships?.app?.data?.id === APP, 'Existing internal group identity/privacy mismatch.');
  const owners = (await request('/v1/users?filter[roles]=ACCOUNT_HOLDER&fields[users]=username')).data;
  const memberIds = group.relationships?.betaTesters?.data?.map(item => item.id) ?? [];
  const testers = checked.included?.filter(item => item.type === 'betaTesters' && memberIds.includes(item.id)) ?? [];
  assert(owners.length === 1, 'Exactly one account holder must be identifiable.');
  const ownerMatches = testers.filter(tester => tester.attributes.email?.toLowerCase() === owners[0].attributes.username?.toLowerCase());
  assert(ownerMatches.length === 1, 'The existing account-holder tester must remain in the internal group.');
  const ownerTesterId = ownerMatches[0].id;
  assert(additionalTesterId !== ownerTesterId, 'The additional tester must be a different existing member.');
  const expectedTesterIds = new Set([ownerTesterId, ...(additionalTesterId ? [additionalTesterId] : [])]);
  assert(memberIds.length === expectedTesterIds.size && testers.length === expectedTesterIds.size && memberIds.every(memberId => expectedTesterIds.has(memberId)), 'Internal group membership differs from the explicitly authorized tester IDs. Default is account holder only.');

  if (build.attributes.usesNonExemptEncryption !== false) {
    await request(`/v1/builds/${build.id}`, { method: 'PATCH', body: { data: { type: 'builds', id: build.id, attributes: { usesNonExemptEncryption: false } } } });
  }
  const localization = build.included.find(item => item.type === 'betaBuildLocalizations' && item.attributes.locale === 'it');
  if (localization) {
    if (localization.attributes.whatsNew !== NOTES) await request(`/v1/betaBuildLocalizations/${id(localization.id)}`, { method: 'PATCH', body: { data: { type: 'betaBuildLocalizations', id: localization.id, attributes: { whatsNew: NOTES } } } });
  } else {
    await request('/v1/betaBuildLocalizations', { method: 'POST', body: { data: { type: 'betaBuildLocalizations', attributes: { locale: 'it', whatsNew: NOTES }, relationships: { build: { data: { type: 'builds', id: build.id } } } } } });
  }
  const builds = (await request(`/v1/betaGroups/${GROUP}/relationships/builds?limit=200`)).data;
  if (!builds.some(item => item.id === build.id)) await request(`/v1/betaGroups/${GROUP}/relationships/builds`, { method: 'POST', body: { data: [{ type: 'builds', id: build.id }] } });

  const [verifiedBuilds, verifiedTesters, detail] = await Promise.all([
    request(`/v1/betaGroups/${GROUP}/relationships/builds?limit=200`),
    request(`/v1/betaGroups/${GROUP}/relationships/betaTesters?limit=200`),
    request(`/v1/builds/${build.id}/buildBetaDetail`),
  ]);
  assert(verifiedBuilds.data.some(item => item.id === build.id) && verifiedTesters.data.length === expectedTesterIds.size && verifiedTesters.data.every(item => expectedTesterIds.has(item.id)), 'Final group relationship verification failed.');
  const internalState = detail.data.attributes.internalBuildState;
  assert(['READY_FOR_BETA_TESTING', 'IN_BETA_TESTING'].includes(internalState), `Build attached but internal state is ${internalState}.`);
  await save({ buildId: build.id, buildProcessingState: 'VALID', processingState: 'COMPLETE', readyForInternalTesting: true, internalBuildState: internalState, betaGroupId: GROUP, betaGroupName: group.attributes.name, internalTesterCount: expectedTesterIds.size, additionalTesterIds: additionalTesterId ? [additionalTesterId] : [], groupAssignmentPending: false, notesLocale: 'it', finalizedAt: new Date().toISOString() });
  console.log(JSON.stringify({ finalized: true, version: receipt.version, build: receipt.build, buildId: build.id, internalBuildState: internalState, group: group.attributes.name, testerCount: expectedTesterIds.size }));
}

main().catch(error => { console.error(error.message); process.exitCode = 1; });
