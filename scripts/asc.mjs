#!/usr/bin/env node
// App Store Connect access: no key material or bearer token is logged or persisted.
import { readFile, mkdir, writeFile } from 'node:fs/promises';
import { createPrivateKey, sign, X509Certificate } from 'node:crypto';
import { homedir } from 'node:os';
import { join } from 'node:path';
import { pathToFileURL } from 'node:url';

const API = 'https://api.appstoreconnect.apple.com';
const CONFIG = join(homedir(), '.codex/credentials/appstoreconnect/config.json');
export const BUNDLE = 'cc.sommomi.mymemory';

export async function request(path, { method = 'GET', body } = {}) {
  if (!path.startsWith('/v1/') && !path.startsWith('/v2/')) throw new Error('Only App Store Connect API paths are allowed.');
  const config = JSON.parse(await readFile(CONFIG, 'utf8'));
  const now = Math.floor(Date.now() / 1000);
  const header = Buffer.from(JSON.stringify({ alg: 'ES256', kid: config.key_id, typ: 'JWT' })).toString('base64url');
  const payload = Buffer.from(JSON.stringify({ iss: config.issuer_id, iat: now - 5, exp: now + 300, aud: 'appstoreconnect-v1' })).toString('base64url');
  const privateKey = createPrivateKey(await readFile(config.private_key_path));
  const unsigned = `${header}.${payload}`;
  const signature = sign('sha256', Buffer.from(unsigned), { key: privateKey, dsaEncoding: 'ieee-p1363' }).toString('base64url');
  const response = await fetch(new URL(path, API), {
    method,
    redirect: 'error',
    headers: { Authorization: `Bearer ${unsigned}.${signature}`, 'Content-Type': 'application/json' },
    ...(body ? { body: JSON.stringify(body) } : {}),
  });
  const result = response.status === 204 ? null : await response.json();
  if (!response.ok) throw new Error(`App Store Connect ${response.status}: ${result?.errors?.map(e => `${e.code}: ${e.detail || e.title}`).join('; ') || 'Request failed'}`);
  return result;
}

export async function bundleId() {
  const result = await request(`/v1/bundleIds?filter[identifier]=${BUNDLE}&limit=20`);
  return result.data.find(item => item.attributes.identifier === BUNDLE);
}

async function status() {
  const [apps, bundles, certificates, profiles] = await Promise.all([
    request(`/v1/apps?filter[bundleId]=${BUNDLE}&limit=20`),
    request(`/v1/bundleIds?filter[identifier]=${BUNDLE}&limit=20`),
    request('/v1/certificates?limit=200'),
    request('/v1/profiles?limit=200&fields[profiles]=name,profileState,profileType,expirationDate'),
  ]);
  console.log(JSON.stringify({
    apps: apps.data.map(({id,attributes:a}) => ({ id, name:a.name, bundleId:a.bundleId })),
    bundles: bundles.data.map(({id,attributes:a}) => ({ id, name:a.name, identifier:a.identifier, platform:a.platform, seedId:a.seedId })),
    certificates: certificates.data.map(({id,attributes:a}) => ({ id, type:a.certificateType, name:a.displayName, serialNumber:a.serialNumber, expirationDate:a.expirationDate, ...(a.certificateContent ? {sha1:new X509Certificate(Buffer.from(a.certificateContent,'base64')).fingerprint.replaceAll(':','')} : {}) })),
    profiles: profiles.data.filter(({attributes:a}) => a.name.toLowerCase().includes('mymemory')).map(({id,attributes}) => ({id,...attributes})),
  }, null, 2));
}

async function registerBundle() {
  const existing = await bundleId();
  if (existing) { console.log(`Bundle already registered: ${existing.id}`); return; }
  const result = await request('/v1/bundleIds', { method:'POST', body:{ data:{type:'bundleIds',attributes:{identifier:BUNDLE,name:'MyMemory',platform:'IOS'}} } });
  console.log(`Registered ${BUNDLE}: ${result.data.id}`);
}

async function provision(certificateId) {
  if (!certificateId) throw new Error('Pass the verified distribution certificate ID.');
  const bundle = await bundleId();
  if (!bundle) throw new Error('Register the bundle ID first.');
  const existing = await request(`/v1/bundleIds/${bundle.id}/profiles?limit=200`);
  let profile = existing.data.find(p => p.attributes.profileType === 'IOS_APP_STORE' && p.attributes.profileState === 'ACTIVE');
  if (!profile) {
    const result = await request('/v1/profiles', {method:'POST', body:{data:{type:'profiles',attributes:{name:'MyMemory App Store',profileType:'IOS_APP_STORE'},relationships:{bundleId:{data:{type:'bundleIds',id:bundle.id}},certificates:{data:[{type:'certificates',id:certificateId}]}}}}});
    profile = result.data;
  }
  if (!profile.attributes.profileContent) profile = (await request(`/v1/profiles/${profile.id}`)).data;
  const directory = join(homedir(),'Library/Developer/Xcode/UserData/Provisioning Profiles');
  await mkdir(directory,{recursive:true});
  const target = join(directory, `${profile.attributes.uuid}.mobileprovision`);
  await writeFile(target,Buffer.from(profile.attributes.profileContent,'base64'),{mode:0o600});
  console.log(JSON.stringify({id:profile.id,name:profile.attributes.name,uuid:profile.attributes.uuid,expirationDate:profile.attributes.expirationDate,installed:target},null,2));
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  const [command = 'status', argument] = process.argv.slice(2);
  try {
    if (command === 'status') await status();
    else if (command === 'register-bundle') await registerBundle();
    else if (command === 'provision-appstore') await provision(argument);
    else throw new Error('Usage: node scripts/asc.mjs [status|register-bundle|provision-appstore CERTIFICATE_ID]');
  } catch (error) { console.error(error.message); process.exitCode = 1; }
}
