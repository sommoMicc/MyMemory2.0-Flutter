#!/usr/bin/env node
// Fetch unmodified Noto 2D raster illustrations from an immutable upstream commit.
import { mkdir, writeFile } from 'node:fs/promises';
import { createHash } from 'node:crypto';
import { fileURLToPath } from 'node:url';
import { resolve } from 'node:path';

const ROOT = fileURLToPath(new URL('../', import.meta.url));
const COMMIT = '99701e07d3d1fe1bdbcdb14964547f0fd592966f';
const BASE = `https://raw.githubusercontent.com/googlefonts/noto-emoji/${COMMIT}`;
const SIZE = 512;
const collections = {
  garden: { title: 'Animali', cards: [
    ['fox','1f98a','Volpe'], ['dog','1f436','Cane'], ['cat','1f431','Gatto'],
    ['lion','1f981','Leone'], ['tiger','1f42f','Tigre'], ['monkey','1f435','Scimmia'],
    ['rabbit','1f430','Coniglio'], ['bear','1f43b','Orso'], ['panda','1f43c','Panda'],
    ['koala','1f428','Koala'], ['mouse','1f42d','Topo'], ['pig','1f437','Maiale'],
    ['cow','1f42e','Mucca'], ['frog','1f438','Rana'], ['chicken','1f414','Gallina'],
    ['penguin','1f427','Pinguino'], ['owl','1f989','Gufo'], ['butterfly','1f98b','Farfalla'],
  ] },
  cosmos: { title: 'Spazio', cards: [
    ['rocket','1f680','Razzo'], ['satellite','1f6f0','Satellite'], ['saturn','1fa90','Pianeta con anelli'],
    ['crescent','1f319','Luna crescente'], ['sun','1f31e','Sole'], ['star','2b50','Stella'],
    ['comet','2604','Cometa'], ['telescope','1f52d','Telescopio'], ['alien','1f47d','Alieno'],
    ['ufo','1f6f8','Disco volante'], ['astronaut','1f9d1_200d_1f680','Astronauta'], ['galaxy','1f30c','Galassia'],
    ['earth','1f30d','Terra'], ['shooting-star','1f320','Stella cadente'], ['antenna','1f4e1','Antenna'],
    ['robot','1f916','Robot'], ['globe','1f310','Globo'], ['full-moon','1f315','Luna piena'],
  ] },
  ocean: { title: 'Oceano', cards: [
    ['whale','1f40b','Balena'], ['dolphin','1f42c','Delfino'], ['seal','1f9ad','Foca'],
    ['fish','1f41f','Pesce'], ['tropical-fish','1f420','Pesce tropicale'], ['pufferfish','1f421','Pesce palla'],
    ['shark','1f988','Squalo'], ['octopus','1f419','Polpo'], ['squid','1f991','Calamaro'],
    ['crab','1f980','Granchio'], ['lobster','1f99e','Aragosta'], ['shrimp','1f990','Gambero'],
    ['jellyfish','1fabc','Medusa'], ['coral','1fab8','Corallo'], ['shell','1f41a','Conchiglia'],
    ['turtle','1f422','Tartaruga'], ['anchor','2693','Ancora'], ['sailboat','26f5','Barca a vela'],
  ] },
};

async function download(url) {
  const response = await fetch(url, { redirect:'error', signal:AbortSignal.timeout(30000) });
  if (response.status !== 200) throw new Error(`Download failed (${response.status}): ${url}`);
  return Buffer.from(await response.arrayBuffer());
}

const directory = resolve(ROOT,'app/assets/decks');
await mkdir(directory,{recursive:true});
const assets = [];
for (const [theme,collection] of Object.entries(collections)) {
  await mkdir(resolve(directory,theme),{recursive:true});
  const cards = await Promise.all(collection.cards.map(async ([name,codepoint,label],value) => {
    const sourcePath=`2D/png/${SIZE}/emoji_u${codepoint}.png`;
    const url=`${BASE}/${sourcePath}`;
    const bytes=await download(url);
    if(bytes.subarray(0,8).toString('hex')!=='89504e470d0a1a0a' || bytes.readUInt32BE(16)!==SIZE || bytes.readUInt32BE(20)!==SIZE) throw new Error(`Invalid PNG dimensions: ${url}`);
    const asset=`assets/decks/${theme}/${name}.png`;
    await writeFile(resolve(ROOT,'app',asset),bytes);
    return {theme,value,name,label,asset,sourcePath,url,width:SIZE,height:SIZE,bytes:bytes.length,sha256:createHash('sha256').update(bytes).digest('hex')};
  }));
  assets.push(...cards);
  console.log(`${collection.title}: ${cards.length} verified ${SIZE}×${SIZE} PNGs`);
}
const license=await download('https://www.apache.org/licenses/LICENSE-2.0.txt');
const copyright=await download(`${BASE}/2D/svg/LICENSE`);
await writeFile(resolve(directory,'LICENSE-APACHE-2.0.txt'),license);
await writeFile(resolve(directory,'UPSTREAM-NOTICE.txt'),copyright);
const notice=`Noto Emoji 2D illustrations\nCopyright 2013 Google, Inc. All Rights Reserved.\n\nThese 54 unmodified PNG image resources are from Google Fonts Noto Emoji:\nhttps://github.com/googlefonts/noto-emoji\nPinned commit: ${COMMIT}\nUpstream directory: 2D/png/${SIZE}/\nLicense: Apache License, Version 2.0 (see LICENSE-APACHE-2.0.txt).\nThe upstream image copyright/license notice is retained in UPSTREAM-NOTICE.txt.\n\nSommoMemory selects and orders the images into Animali, Spazio and Oceano.\nNo Noto font files, flags or Noto 3D artwork are included.\n`;
await writeFile(resolve(directory,'NOTICE.txt'),notice);
await writeFile(resolve(directory,'manifest.json'),JSON.stringify({source:'Google Noto Emoji 2D',repository:'https://github.com/googlefonts/noto-emoji',commit:COMMIT,license:'Apache-2.0',imageSize:SIZE,collections:Object.fromEntries(Object.entries(collections).map(([key,value])=>[key,{title:value.title,count:value.cards.length}])),assets},null,2)+'\n');
const lines=["import 'package:flutter/foundation.dart';","import 'package:flutter/services.dart';",'', '// IDs and ordering are part of the multiplayer card-value mapping. Do not reorder.', 'const Map<String, String> deckNames = {'];
for(const [key,value] of Object.entries(collections)) lines.push(`  '${key}': '${value.title}',`);
lines.push('};','','const Map<String, List<String>> deckAssets = {');
for(const theme of Object.keys(collections)) {
  lines.push(`  '${theme}': [`);
  for(const asset of assets.filter(a=>a.theme===theme))lines.push(`    '${asset.asset}',`);
  lines.push('  ],');
}
lines.push('};','','const Map<String, List<String>> deckLabels = {');
for(const theme of Object.keys(collections)) {
  lines.push(`  '${theme}': [`);
  for(const asset of assets.filter(a=>a.theme===theme))lines.push(`    '${asset.label}',`);
  lines.push('  ],');
}
lines.push('};','',`String? deckAsset(String theme, int value) {\n  final assets = deckAssets[theme];\n  return assets != null && value >= 0 && value < assets.length ? assets[value] : null;\n}`,`\nString? deckCover(String theme) => deckAsset(theme, 0);`,`\nString? deckLabel(String theme, int value) {\n  final labels = deckLabels[theme];\n  return labels != null && value >= 0 && value < labels.length ? labels[value] : null;\n}`,`\nbool _licensesRegistered = false;\nFuture<void> registerDeckLicenses() async {\n  if (_licensesRegistered) return;\n  final notice = await rootBundle.loadString('assets/decks/NOTICE.txt');\n  final upstream = await rootBundle.loadString('assets/decks/UPSTREAM-NOTICE.txt');\n  final license = await rootBundle.loadString('assets/decks/LICENSE-APACHE-2.0.txt');\n  LicenseRegistry.addLicense(() => Stream.value(\n    LicenseEntryWithLineBreaks(const ['Noto Emoji 2D — deck illustrations'], '$notice\\n$upstream\\n$license'),\n  ));\n  _licensesRegistered = true;\n}`);
const dart=lines.join('\n')+'\n';
await writeFile(resolve(ROOT,'app/lib/decks.dart'),dart);
console.log(`Bundled ${assets.length} assets, ${(assets.reduce((total,a)=>total+a.bytes,0)/1024).toFixed(0)} KiB total; manifest and licenses saved.`);
