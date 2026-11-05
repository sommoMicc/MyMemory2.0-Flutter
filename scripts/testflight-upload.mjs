#!/usr/bin/env node
// Direct App Store Connect Build Upload API (4.1+). No key/token files are made.
import { readFile, writeFile, mkdir } from 'node:fs/promises';
import { createHash } from 'node:crypto';
import { execFileSync } from 'node:child_process';
import { basename, resolve } from 'node:path';
import { request, BUNDLE } from './asc.mjs';

const file = process.argv[2];
if (!file || !file.endsWith('.ipa')) throw new Error('Usage: node scripts/testflight-upload.mjs /absolute/path/MyMemory.ipa');
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
const apps = await request(`/v1/apps?filter[bundleId]=${BUNDLE}`);
const app = apps.data.find(item => item.attributes.bundleId === BUNDLE);
if (!app) throw new Error('Create the App Store Connect app record first.');
console.log(`Uploading ${app.attributes.name} ${version} (${build}), ${bytes.length} bytes, SHA-256 ${hash}`);
const upload = await request('/v1/buildUploads', {method:'POST',body:{data:{type:'buildUploads',attributes:{cfBundleShortVersionString:version,cfBundleVersion:build,platform:'IOS'},relationships:{app:{data:{type:'apps',id:app.id}}}}}});
const uploadId=upload.data.id;
await mkdir('artifacts',{recursive:true});
const receipt = {appId:app.id,bundleId:BUNDLE,version,build,sha256:hash,buildUploadId:uploadId,createdAt:new Date().toISOString()};
await writeFile('artifacts/testflight-upload.json',JSON.stringify(receipt,null,2)+'\n');
console.log(`Build upload created: ${uploadId}`);
const reservation = await request('/v1/buildUploadFiles',{method:'POST',body:{data:{type:'buildUploadFiles',attributes:{fileName:basename(target),fileSize:bytes.length,uti:'com.apple.ipa',assetType:'ASSET'},relationships:{buildUpload:{data:{type:'buildUploads',id:uploadId}}}}}});
const uploadFile=reservation.data;
receipt.buildUploadFileId=uploadFile.id;
await writeFile('artifacts/testflight-upload.json',JSON.stringify(receipt,null,2)+'\n');
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
  console.log(`Uploaded part ${i+1}/${operations.length}`);
}
const committed=await request(`/v1/buildUploadFiles/${uploadFile.id}`,{method:'PATCH',body:{data:{type:'buildUploadFiles',id:uploadFile.id,attributes:{uploaded:true,sourceFileChecksums:{file:{algorithm:'MD5',hash:deliveryHash}}}}}});
receipt.committedAt=new Date().toISOString();
receipt.assetDeliveryState=committed.data.attributes.assetDeliveryState;
await writeFile('artifacts/testflight-upload.json',JSON.stringify(receipt,null,2)+'\n');
console.log(JSON.stringify({buildUploadId:uploadId,buildUploadFileId:uploadFile.id,assetDeliveryState:receipt.assetDeliveryState}));
const status=await request(`/v1/buildUploads/${uploadId}?include=build`);
console.log(JSON.stringify({buildUploadId:uploadId,state:status.data.attributes.state,build:status.data.relationships?.build?.data}));
