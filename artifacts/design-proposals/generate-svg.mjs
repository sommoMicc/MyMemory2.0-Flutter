import { readFile, writeFile } from 'node:fs/promises';

const dog = `data:image/png;base64,${(await readFile(new URL('../../app/assets/decks/garden/dog.png', import.meta.url))).toString('base64')}`;
const rabbit = `data:image/png;base64,${(await readFile(new URL('../../app/assets/decks/garden/rabbit.png', import.meta.url))).toString('base64')}`;

const svgOpen = (title, subtitle, colors) => `<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" width="1280" height="900" viewBox="0 0 1280 900">
<defs>
  <filter id="shadow" x="-20%" y="-20%" width="150%" height="160%"><feDropShadow dx="0" dy="7" stdDeviation="7" flood-color="#152341" flood-opacity=".15"/></filter>
  <filter id="hard" x="-20%" y="-20%" width="150%" height="160%"><feDropShadow dx="0" dy="4" stdDeviation="0" flood-color="#172345" flood-opacity=".9"/></filter>
  <clipPath id="phoneClip"><rect x="8" y="8" width="306" height="704" rx="25"/></clipPath>
  <clipPath id="journeyClip"><rect x="20" y="111" width="282" height="88" rx="19"/></clipPath>
  <pattern id="dots" width="18" height="18" patternUnits="userSpaceOnUse"><circle cx="2" cy="2" r="1.4" fill="#fff4d8" opacity=".24"/></pattern>
  <pattern id="tinyDots" width="14" height="14" patternUnits="userSpaceOnUse"><circle cx="3" cy="3" r="1.1" fill="#ffffff" opacity=".35"/></pattern>
</defs>
<rect width="1280" height="900" fill="#f1f3f8"/>
<text x="48" y="49" fill="#67728a" font-family="Outfit,Arial,sans-serif" font-size="12" font-weight="800" letter-spacing="2.1">SOMMOMEMORY  /  PROPOSTA VISIVA</text>
<text x="48" y="91" fill="#18233c" font-family="Outfit,Arial,sans-serif" font-size="32" font-weight="850" letter-spacing="-1.1">${title}</text>
<text x="48" y="119" fill="#5d6880" font-family="Outfit,Arial,sans-serif" font-size="15">${subtitle}</text>
<g transform="translate(882 71)">${colors.map((c, i) => `<circle cx="${i*30}" cy="0" r="10" fill="${c}" stroke="#18233c" stroke-opacity=".16"/>`).join('')}</g>
`;
const close = `</svg>`;
const txt = (x,y,s,text,color='#172345',weight=600,anchor='start',extra='') => `<text x="${x}" y="${y}" text-anchor="${anchor}" fill="${color}" font-family="Outfit,Arial,sans-serif" font-size="${s}" font-weight="${weight}" ${extra}>${text}</text>`;
const rect = (x,y,w,h,r,fill,stroke='none',sw=0,extra='') => `<rect x="${x}" y="${y}" width="${w}" height="${h}" rx="${r}" fill="${fill}" stroke="${stroke}" stroke-width="${sw}" ${extra}/>`;
const img = (href,x,y,w,h) => `<image href="${href}" x="${x}" y="${y}" width="${w}" height="${h}" preserveAspectRatio="xMidYMid meet"/>`;

function brand(mode, C) {
  const dark = mode === 'pop' ? C.ink : C.deep;
  const first = mode === 'pop' ? C.coral : C.orange;
  const second = mode === 'pop' ? C.yellow : C.yellow;
  const logoText = mode === 'pop'
    ? `${txt(54,51,15,'SOMMO',C.cream,900)}${txt(54,62,7,'MEMORY',C.yellow,800,'start','letter-spacing="1.3"')}`
    : txt(53,53,15,'SommoMemory',C.deep,850);
  return `<g>${rect(15,30,24,26,6,first,dark,2,'transform="rotate(-10 27 43)"')}${rect(25,32,24,26,6,second,dark,2,'transform="rotate(10 37 45)"')}${logoText}
    ${rect(210,35,53,25,13,mode==='pop'?C.yellow:'#fff0ae',mode==='pop'?C.ink:'none',mode==='pop'?2:0)}${txt(222,52,10,'◆ 100',dark,850)}
    <circle cx="282" cy="47" r="15" fill="${mode==='pop'?C.coral:C.yellow}" stroke="${dark}" stroke-width="2"/>${txt(282,53,16,'🐱',dark,650,'middle')}
  </g>`;
}

function phoneShell(x, y, label, mode, C) {
  return `<g transform="translate(${x} ${y})">
    ${txt(8,-12,11,label.toUpperCase(), '#748099',850,'start','letter-spacing="1.5"')}
    ${rect(0,0,322,720,34,'#101827')}${rect(8,8,306,704,25,C.bg,'none',0,'clip-path="url(#phoneClip)"')}
    <g clip-path="url(#phoneClip)">
      ${mode==='pop'?`<rect x="8" y="8" width="306" height="704" fill="url(#dots)"/>`:''}
      ${txt(25,25,9,'9:41',mode==='pop'?C.cream:C.deep,750)}${txt(291,25,8,'●  ●  ▰',mode==='pop'?C.cream:C.deep,700,'end')}
      ${label==='Home' ? brand(mode,C) : ''}
    </g>
  `;
}

function drawHome(mode, x, y, C) {
  let s = phoneShell(x,y,'Home',mode,C);
  const fg = mode==='pop' ? C.cream : C.deep;
  s += txt(23,95,19,'Modalità di gioco',fg,850,'start','letter-spacing="-.5"');
  if (mode==='pop') {
    s += `${rect(20,111,282,88,17,C.navy,C.ink,2,'filter="url(#hard)"')}${txt(34,188,8,'MAZZO ATTUALE  ·  ANIMALI',C.yellow,800,'start','letter-spacing=".8"')}
      ${rect(152,124,45,57,10,C.coral,C.ink,2,'transform="rotate(-9 174 152)"')}${txt(174,158,20,'≋',C.cream,800,'middle','transform="rotate(-9 174 152)"')}
      ${rect(201,122,48,60,10,C.cream,C.ink,2,'transform="rotate(7 225 151)"')}${img(dog,204,124,42,55)}`;
  } else {
    s += `<rect x="20" y="111" width="282" height="88" rx="19" fill="#16c5d2" stroke="#fff" stroke-width="2"/>
      <g clip-path="url(#journeyClip)">
      <ellipse cx="58" cy="189" rx="62" ry="29" fill="#58bd4e"/><ellipse cx="274" cy="190" rx="69" ry="32" fill="#49ae47"/>
      <path d="M38 173 C82 139 214 146 267 121" fill="none" stroke="#fff0a8" stroke-width="3" stroke-dasharray="2 8" stroke-linecap="round"/>
      <circle cx="67" cy="162" r="11" fill="#ffca38" stroke="#fff" stroke-width="2"/><circle cx="251" cy="129" r="11" fill="#ffca38" stroke="#fff" stroke-width="2"/>
      </g>
      ${txt(34,188,8,'MAZZO ATTUALE  ·  ANIMALI',C.deep,800,'start','letter-spacing=".8"')}
      ${rect(158,122,47,58,12,'#fff4d8','#fff',2,'transform="rotate(-9 181 151)"')}${img(dog,161,124,41,54)}`;
  }
  const modes = [
    ['1P','Singolo','Un giocatore',mode==='pop'?C.yellow:'#fff1b4'],
    ['2P','In due','Un dispositivo',mode==='pop'?C.coral:'#ffdc81'],
    ['◎','Online','Due dispositivi',mode==='pop'?C.sky:'#bcebed'],
    ['ᛒ','Bluetooth','Senza Internet',mode==='pop'?C.cream:'#ffc2a0'],
  ];
  modes.forEach(([icon,title,sub,color],i) => {
    const cx = 20 + (i%2)*144, cy = 212 + Math.floor(i/2)*126;
    const rr = mode==='pop' ? 12 : 18;
    s += `${rect(cx,cy,138,118,rr,color,mode==='pop'?C.ink:'#fff',mode==='pop'?2:2,mode==='pop'?'filter="url(#hard)"':'filter="url(#shadow)"')}
      ${rect(cx+11,cy+10,38,37,mode==='pop'?10:19,mode==='pop'?C.cream:'#ffca38',mode==='pop'?C.ink:'none',mode==='pop'?2:0)}
      ${txt(cx+30,cy+36,icon==='◎'?25:14,icon,C.deep,900,'middle')}
      ${txt(cx+11,cy+78,14,title,C.deep,850)}${txt(cx+11,cy+95,9,sub,C.deep,600)}${txt(cx+124,cy+99,16,mode==='pop'?'↗':'›',C.orange,850,'middle')}`;
  });
  const bannerFill = mode==='pop' ? C.navy : '#fff3c5';
  const bannerStroke = mode==='pop' ? C.ink : '#fff';
  s += `${rect(20,474,282,64,16,bannerFill,bannerStroke,2,mode==='pop'?'filter="url(#hard)"':'filter="url(#shadow)"')}
      <circle cx="49" cy="506" r="17" fill="${C.yellow}"/><text x="49" y="511" text-anchor="middle" fill="${C.deep}" font-family="Arial,sans-serif" font-size="14" font-weight="800">♛</text>
      ${txt(76,498,11,'Valle Selvaggia',mode==='pop'?C.cream:C.deep,850)}
      ${txt(76,515,9,'0 corone · prossimo traguardo: 100',mode==='pop'?C.cream:C.deep,600)}
      ${txt(284,511,19,'›',mode==='pop'?C.yellow:C.orange,850,'middle')}`;
  return s+`</g>`;
}

function drawBoard(mode, x, y, C) {
  let s = phoneShell(x,y,'Tabellone · Animali',mode,C);
  const fg = mode==='pop' ? C.cream : C.deep;
  if (mode==='isles') s += `<path d="M0 197 Q120 158 322 194 V720 H0 Z" fill="#8ad65a"/><path d="M0 253 Q176 210 322 242 V720 H0 Z" fill="#60c34f" opacity=".8"/><rect x="12" y="153" width="284" height="489" rx="20" fill="#f0ffd0" opacity=".48"/>`;
  s += `${txt(22,49,21,'‹',fg,700)}<circle cx="57" cy="42" r="13" fill="#fff4d8"/>${txt(57,47,13,'🐾','#124c65',700,'middle')}${txt(78,47,15,'Animali',fg,850)}${txt(292,46,11,'0:16',fg,850,'end')}`;
  const statY=64;
  [[18,'COPPIE','1/12'],[165,'TENTATIVI','2']].forEach(([sx,l,v])=> {
    s += `${rect(sx,statY,143,52,13,mode==='pop'?C.cream:'#fff3c5',mode==='pop'?C.ink:'#fff',mode==='pop'?2:1,mode==='pop'?'filter="url(#hard)"':'filter="url(#shadow)"')}
      ${txt(sx+11,statY+19,8,l,mode==='pop'?C.deep:C.deep,750,'start','letter-spacing=".7"')}${txt(sx+130,statY+39,21,v,C.deep,850,'end')}`;
  });
  s += `${rect(103,124,112,23,12,mode==='pop'?C.yellow:C.yellow,mode==='pop'?C.ink:'#fff',mode==='pop'?2:1)}${txt(159,140,10,'1 / 12 coppie',C.deep,850,'middle')}`;
  const startX=17,startY=158,cw=67,ch=72,g=5;
  for (let i=0;i<24;i++) {
    const cx=startX+(i%4)*(cw+g), cy=startY+Math.floor(i/4)*(ch+5);
    const matched=i<2, face=i===2;
    const fill=matched?C.yellow:face?(mode==='pop'?C.cream:'#fff4d8'):(mode==='pop'?C.cobalt:'#10aebf');
    const stroke=mode==='pop'?C.ink:'#d8fbf4';
    s += rect(cx,cy,cw,ch,mode==='pop'?9:12,fill,stroke,2,mode==='pop'?'filter="url(#hard)"':'filter="url(#shadow)"');
    if (matched) s += img(dog,cx+8,cy+7,51,56)+txt(cx+57,cy+12,8,'✦',C.deep,900,'middle');
    else if (face) s += img(rabbit,cx+8,cy+7,51,56);
    else if (mode==='pop') s += `<circle cx="${cx+32}" cy="${cy+36}" r="18" fill="none" stroke="${C.yellow}" stroke-width="2"/><path d="M${cx+22} ${cy+36}l7 -7 6 7m2 0l5 -5 4 5" fill="none" stroke="${C.yellow}" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"/>`;
    else s += `<circle cx="${cx+32}" cy="${cy+36}" r="19" fill="none" stroke="#b7f0e9" stroke-width="2"/><path d="M${cx+23} ${cy+36}l6 -7 6 7m2 0l5 -5 4 5" fill="none" stroke="#d7faf1" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"/>`;
  }
  return s+`</g>`;
}

function notes(mode, x, C) {
  const isPop=mode==='pop';
  const label=isPop?'LINGUAGGIO VISIVO':'LINGUAGGIO VISIVO';
  const bulletColor=isPop?C.coral:C.green;
  const list=isPop
    ? ['Fondo cobalto quasi piatto; pattern a coppie molto tenue.','Quattro modalità come tessere, ognuna col suo colore.','Bordi scuri da 2–3 px e ombre corte, senza superfici lattiginose.','Il giallo segnala una coppia trovata e rimane stabile.']
    : ['Valle illustrata come punto di partenza del viaggio.','La tappa successiva è visibile con il suo traguardo di corone.','Pulsanti plastici e personaggi familiari, coerenti con le arene.','Centro del tabellone più calmo per tenere leggibili le carte.'];
  const wrap = (value, max=46) => {
    const words=value.split(' '), lines=[]; let line='';
    for (const word of words) { const next=line ? `${line} ${word}` : word; if (next.length>max && line) { lines.push(line); line=word; } else line=next; }
    if (line) lines.push(line); return lines;
  };
  let bullets=''; let yy=318;
  for (const item of list) {
    const lines=wrap(item,45);
    bullets += `<circle cx="35" cy="${yy-4}" r="4" fill="${bulletColor}"/>`;
    lines.forEach((line,idx)=>{ bullets += txt(50,yy+idx*16,12,line,'#3f4b63',600); });
    yy += Math.max(lines.length*16,16)+24;
  }
  return `<g transform="translate(${x} 142)">${rect(0,0,440,700,24,'#fff')}
    ${txt(28,42,10,label,'#748099',850,'start','letter-spacing="1.5"')}
    ${txt(28,82,24,isPop?'Carte come oggetti':'Un viaggio tra arene','#18233c',850)}
    ${txt(28,108,13,isPop?'Sala giochi pop':'Isole in gioco','#5d6880',600)}
    ${rect(28,134,384,1,0,'#e5e8ef')}
    ${txt(28,168,11,'PALETTE', '#748099',850,'start','letter-spacing="1.3"')}
    ${C.swatches.map((c,i)=>`${rect(28+i*65,184,55,40,11,c,'#18233c22',1)}${txt(55+i*65,242,9,c.toUpperCase(),'#657087',700,'middle')}`).join('')}
    ${txt(28,287,11,'REGOLE DI DESIGN','#748099',850,'start','letter-spacing="1.3"')}
    ${bullets}
  </g>`;
}

const pop={
  bg:'#2446d8',ink:'#172345',navy:'#1b318f',cobalt:'#2446d8',cream:'#fff4d8',yellow:'#ffe34c',coral:'#ff593b',sky:'#93e6ed',orange:'#ff593b',green:'#48b84a',deep:'#124c65',
  swatches:['#2446d8','#ffe34c','#ff593b','#fff4d8','#172345'],
};
const isles={
  bg:'#10bcd0',ink:'#124c65',navy:'#125d69',cobalt:'#10aebf',cream:'#fff4d8',yellow:'#ffca38',coral:'#ff6a2e',sky:'#bcebed',orange:'#ff6a2e',green:'#48b84a',deep:'#124c65',
  swatches:['#10bcd0','#48b84a','#ffca38','#ff6a2e','#124c65'],
};

const popSvg=svgOpen('A · Sala giochi pop','Contrasti forti, modalità a tessere e carte che sembrano componenti di un gioco da tavolo.',pop.swatches)
  +drawHome('pop',48,145,pop)+drawBoard('pop',398,145,pop)+notes('pop',790,pop)+close;
const islesSvg=svgOpen('B · Isole in gioco','Un’avventura illustrata in cui le arene e il progresso diventano parte del paesaggio.',isles.swatches)
  +drawHome('isles',48,145,isles)+drawBoard('isles',398,145,isles)+notes('isles',790,isles)+close;

await writeFile(new URL('./A-sala-giochi-pop.svg',import.meta.url),popSvg);
await writeFile(new URL('./B-isole-in-gioco.svg',import.meta.url),islesSvg);
