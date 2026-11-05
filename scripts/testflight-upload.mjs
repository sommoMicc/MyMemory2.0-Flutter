#!/usr/bin/env node
// Direct App Store Connect Build Upload API (4.1+). No key/token files are made.
import { readFile, writeFile, mkdir, rename } from 'node:fs/promises';
import { createHash } from 'node:crypto';
import { execFileSync } from 'node:child_process';
import { basename, resolve } from 'node:path';
import { request, BUNDLE } from './asc.mjs';

const args = process.argv.slice(2);
const commitOnly = args.includes('--commit-only');
const files = args.filter(argument => !argument.startsWith('--'));
if (files.length !== 1 || args.some(argument => argument.startsWith('--') && argument !== '--commit-only') || !files[0].endsWith('.ipa')) throw new Error('Usage: node scripts/testflight-upload.mjs [--commit-only] /absolute/path/MyMemory.ipa');
const file = files[0];
const target = resolve(file);
const entries = execFileSync('/usr/bin/unzip', ['-Z1', target], { encoding:'utf8' }).split('\n');
const infoPath = entries.find(path => /^Payload\/[^/]+\.app\/Info\.plist$/.test(path));
if (!infoPath) throw new Error('IPA has no main app Info.plist');
const infoBytes = execFileSync('/usr/bin/unzip', ['-p', target, infoPath]);
const info = JSON.parse(execFileSync('/usr/bin/plutil', ['-convert','json','-o','-','-'], { input:infoBytes,encoding:'utf8' }));
if (info.CFBundleIdentifier !== BUNDLE) throw new Error('IPA bundle does not match MyMemory');
const version = String(info.CFBundleShortVersionString), build = String(info.CFBundleVersion);
const bytes = await readFile(target);
const hash = createHash('sha256').update(bytes).digest('hex');
// Build Upload currently accepts MD5 file checksums at commit time. Keep
// SHA-256 in the local receipt for artifact identity.
const deliveryHash = createHash('md5').update(bytes).digest('hex');
const receiptPath = 'artifacts/testflight-upload.json';
async function saveReceipt(receipt) {
  const temporary = `${receiptPath}.${process.pid}.tmp`;
  await writeFile(temporary, JSON.stringify(receipt,null,2)+'\n');
  await rename(temporary, receiptPath);
}
// Only GET and this checksum PATCH are retried. Never retry reservation POSTs.
async function recoverableRequest(path, options) {
  for (let attempt = 0; ; attempt++) {
    try { return await request(path, options); }
    catch (error) {
      const networkFailure = error instanceof TypeError || ['UND_ERR_CONNECT_TIMEOUT','ETIMEDOUT','ECONNRESET'].includes(error.cause?.code);
      if (!networkFailure || attempt >= 2) throw error;
      console.log(`Retrying ${options?.method ?? 'GET'} after a temporary connection failure (${attempt+1}/2).`);
      await new Promise(resolve => setTimeout(resolve, 1500 * (attempt+1)));
    }
  }
}
async function commitFile(receipt) {
  const uploadId = receipt.buildUploadId, uploadFileId = receipt.buildUploadFileId;
  const resourceId = /^[a-zA-Z0-9-]+$/;
  if (receipt.appId !== '6831015201' || receipt.bundleId !== BUNDLE || receipt.version !== version || receipt.build !== build || receipt.sha256 !== hash || !resourceId.test(uploadId ?? '') || !resourceId.test(uploadFileId ?? '')) throw new Error('Existing receipt does not match this exact native IPA.');
  const upload = (await recoverableRequest(`/v1/buildUploads/${uploadId}`)).data;
  if (upload.attributes.cfBundleShortVersionString !== version || upload.attributes.cfBundleVersion !== build || upload.attributes.platform !== 'IOS') throw new Error('Apple upload does not match this native IPA.');
  const related = await recoverableRequest(`/v1/buildUploads/${uploadId}/relationships/buildUploadFiles?limit=200`);
  if (!related.data.some(item => item.id === uploadFileId)) throw new Error('Receipt file does not belong to this exact Apple upload.');
  const metadata = (await recoverableRequest(`/v1/buildUploadFiles/${uploadFileId}`)).data;
  if (metadata.attributes.fileSize !== bytes.length || metadata.attributes.uti !== 'com.apple.ipa' || metadata.attributes.assetType !== 'ASSET') throw new Error('Apple file reservation does not match this IPA.');
  const committedChecksum = metadata.attributes.sourceFileChecksums?.file;
  if (committedChecksum && (committedChecksum.algorithm !== 'MD5' || committedChecksum.hash !== deliveryHash)) throw new Error('Apple file checksum differs from this native IPA.');
  let committed = metadata;
  if (metadata.attributes.assetDeliveryState?.state !== 'COMPLETE') {
    committed = (await recoverableRequest(`/v1/buildUploadFiles/${uploadFileId}`,{method:'PATCH',body:{data:{type:'buildUploadFiles',id:uploadFileId,attributes:{uploaded:true,sourceFileChecksums:{file:{algorithm:'MD5',hash:deliveryHash}}}}}})).data;
  }
  receipt.committedAt ??= new Date().toISOString();
  receipt.assetDeliveryState = committed.attributes.assetDeliveryState;
  if (commitOnly) receipt.commitRecovered = true;
  await saveReceipt(receipt);
  console.log(JSON.stringify({buildUploadId:uploadId,buildUploadFileId:uploadFileId,assetDeliveryState:receipt.assetDeliveryState}));
  const status = await recoverableRequest(`/v1/buildUploads/${uploadId}?include=build`);
  console.log(JSON.stringify({buildUploadId:uploadId,state:status.data.attributes.state,build:status.data.relationships?.build?.data}));
}
if (commitOnly) {
  const receipt = JSON.parse(await readFile(receiptPath,'utf8'));
  console.log(`Recovering checksum commit only for ${version} (${build}); no reservations or binary uploads will be created.`);
  await commitFile(receipt);
} else {
const apps = await request(`/v1/apps?filter[bundleId]=${BUNDLE}`);
const app = apps.data.find(item => item.attributes.bundleId === BUNDLE);
if (!app) throw new Error('Create the App Store Connect app record first.');
console.log(`Uploading ${app.attributes.name} ${version} (${build}), ${bytes.length} bytes, SHA-256 ${hash}`);
const upload = await request('/v1/buildUploads', {method:'POST',body:{data:{type:'buildUploads',attributes:{cfBundleShortVersionString:version,cfBundleVersion:build,platform:'IOS'},relationships:{app:{data:{type:'apps',id:app.id}}}}}});
const uploadId=upload.data.id;
await mkdir('artifacts',{recursive:true});
const receipt = {appId:app.id,bundleId:BUNDLE,version,build,sha256:hash,buildUploadId:uploadId,createdAt:new Date().toISOString()};
await saveReceipt(receipt);
console.log(`Build upload created: ${uploadId}`);
const reservation = await request('/v1/buildUploadFiles',{method:'POST',body:{data:{type:'buildUploadFiles',attributes:{fileName:basename(target),fileSize:bytes.length,uti:'com.apple.ipa',assetType:'ASSET'},relationships:{buildUpload:{data:{type:'buildUploads',id:uploadId}}}}}});
const uploadFile=reservation.data;
receipt.buildUploadFileId=uploadFile.id;
receipt.binaryPartsUploaded = [];
await saveReceipt(receipt);
const operations=uploadFile.attributes.uploadOperations;
if (!operations?.length) throw new Error('Apple did not return an upload operation.');
for (let i=0;i<operations.length;i++) {
  const operation=operations[i];
  const url=new URL(operation.url);
  if (url.protocol!=='https:' || url.username || url.password) throw new Error('Invalid upload URL returned by Apple.');
  const {offset,length}=operation;
  if (!Number.isInteger(offset)||!Number.isInteger(length)||offset<0||length<1||offset+length>bytes.length) throw new Error('Invalid byte range returned by Apple.');
  const headers=Object.fromEntries((operation.requestHeaders??[]).map(header=>[header.name,header.value]));
  // Only the reservation's upload headers are sent here. Never send the ASC JWT.
  const response=await fetch(url,{method:operation.method,headers,body:bytes.subarray(offset,offset+length),redirect:'error',signal:AbortSignal.timeout(300000)});
  if(!response.ok) throw new Error(`Apple binary upload failed: HTTP ${response.status}, part ${i+1}`);
  receipt.binaryPartsUploaded.push({part:i+1,offset,length});
  await saveReceipt(receipt);
  console.log(`Uploaded part ${i+1}/${operations.length}`);
}
receipt.binaryUploadCompleteAt = new Date().toISOString();
await saveReceipt(receipt);
await commitFile(receipt);
}
