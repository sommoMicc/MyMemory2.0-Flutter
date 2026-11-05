'use strict';
const $ = id => document.getElementById(id);
const number = value => new Intl.NumberFormat('it-IT', { maximumFractionDigits: 0 }).format(value ?? 0);
const date = (value, short = false) => value == null ? 'Non disponibile' : new Intl.DateTimeFormat('it-IT', { dateStyle: short ? 'short' : 'medium', timeStyle: 'short' }).format(value);
const duration = value => value == null || value < 0 ? '—' : value < 60_000 ? `${Math.round(value / 1000)} s` : `${Math.floor(value / 60_000)} min ${Math.floor(value / 1000) % 60} s`;
const modeName = mode => mode === 'ranked' ? 'Classificata' : 'Amichevole';
const phaseName = phase => ({ waiting: 'In attesa', playing: 'In corso', roundFinished: 'Tra i round', finished: 'Terminata', unavailable: 'Non disponibile' }[phase] || phase);
const deckNames = { garden: 'Animali', cosmos: 'Spazio', ocean: 'Oceano', paola: 'Paola', food: 'Cibo', sports: 'Sport', travel: 'Viaggi' };
let snapshot, view = 'overview', page = 1, busy = false, authenticated = false, searchTimer, pendingRefresh = false;
const node = (tag, text, className) => { const el = document.createElement(tag); if (text != null) el.textContent = text; if (className) el.className = className; return el; };
const clear = id => $(id).replaceChildren();
function message(text = '', login = false) {
  const el = $(login ? 'login-status' : 'dashboard-status'); el.textContent = text;
  if (!login) el.hidden = !text;
}
async function api(path, body) {
  const res = await fetch(`/admin/api/${path}`, { method: body === undefined ? 'GET' : 'POST', credentials: 'same-origin', cache: 'no-store',
    headers: body === undefined ? {} : { 'Content-Type': 'application/json' }, body: body === undefined ? undefined : JSON.stringify(body) });
  const result = await res.json();
  if (!res.ok) {
    if (res.status === 401 && result.error?.code === 'UNAUTHENTICATED') showLogin();
    const error = new Error(result.error?.message || 'Servizio non disponibile.'); error.code = result.error?.code; throw error;
  }
  return result;
}
function showLogin() {
  authenticated = false; snapshot = undefined; $('dashboard').hidden = true; $('login').hidden = false;
  ['metrics','secondary-metrics','chart','arenas','live-preview','live-games','lobbies','match-rows','profile-rows','passkeys'].forEach(clear);
  $('login-button').disabled = !window.PublicKeyCredential;
}
async function showDashboard() {
  authenticated = true; $('login').hidden = true; $('dashboard').hidden = false;
  $('setup-token').value = ''; history.replaceState(null, '', '/admin');
  await refresh();
}
async function perform(button, action, login = false) {
  button.disabled = true; message(login ? 'Segui le istruzioni del dispositivo…' : '', login);
  try { await action(); } catch (error) {
    const text = ['NotAllowedError','AbortError'].includes(error.name) || error.code === 'ERROR_CEREMONY_ABORTED' ? 'Operazione annullata. Puoi riprovare.' : error.message;
    message(text, login || !authenticated);
  } finally { button.disabled = false; }
}
$('login-button').addEventListener('click', () => perform($('login-button'), async () => {
  const optionsJSON = await api('login/options', {});
  const response = await SimpleWebAuthnBrowser.startAuthentication({ optionsJSON });
  await api('login/verify', response); await showDashboard();
}, true));
$('setup-button').addEventListener('click', () => perform($('setup-button'), async () => {
  const setupToken = $('setup-token').value.trim();
  if (!setupToken) throw new Error('Inserisci il codice monouso generato sul server.');
  const optionsJSON = await api('register/options', { setupToken, label: $('setup-label').value });
  const response = await SimpleWebAuthnBrowser.startRegistration({ optionsJSON });
  await api('register/verify', response); await showDashboard();
}, true));
async function logout() {
  try { await api('logout', {}); showLogin(); message('Hai effettuato l’uscita.', true); }
  catch (error) { message(error.message); }
}
$('logout').addEventListener('click', logout);
$('logout-mobile').addEventListener('click', logout);
function setView(next) {
  view = next;
  const titles = { overview: ['Panoramica','Tutto quello che succede in SommoMemory.'], live: ['In diretta','Partite in corso e lobby pronte per la prossima sfida.'],
    history: ['Partite','Le sfide online, dal primo round al risultato.'], users: ['Utenti','I profili e la loro attività sul servizio.'], security: ['Accesso','Le passkey che aprono la tua area riservata.'] };
  $('page-title').textContent = titles[view][0]; $('breadcrumb').textContent = titles[view][0]; $('page-description').textContent = titles[view][1];
  document.querySelectorAll('[data-section]').forEach(el => { el.hidden = el.dataset.section !== view; });
  document.querySelectorAll('[data-view]').forEach(el => { const selected = el.dataset.view === view; el.classList.toggle('selected', selected); if (selected) el.setAttribute('aria-current','page'); else el.removeAttribute('aria-current'); });
  if (view === 'security') void loadKeys().catch(error => message(error.message));
  if (authenticated && view !== 'security') void refresh();
}
document.querySelectorAll('[data-view]').forEach(el => el.addEventListener('click', () => setView(el.dataset.view)));
document.querySelectorAll('[data-go]').forEach(el => el.addEventListener('click', () => setView(el.dataset.go)));
function metric(label, value, note, icon) {
  const el = node('article', null, 'metric'); el.append(node('span',label,'metric-label'),node('span',icon,'metric-icon'),node('div',number(value),'metric-value'),node('p',note,'metric-note')); return el;
}
function mini(label, value, note) {
  const el = node('article',null,'mini-metric'); el.append(node('span',label),node('strong',value),node('small',note)); return el;
}
function renderChart(items) {
  clear('chart');
  if (!items.some(i => i.active || i.matches)) { $('chart').append(node('div','Nessuna attività rilevata nel periodo. Il grafico si popolerà quando i profili contattano il server.','empty')); return; }
  const width = Math.max(260, $('chart').clientWidth - 36);
  const NS = 'http://www.w3.org/2000/svg', svg = document.createElementNS(NS,'svg');
  svg.setAttribute('viewBox',`0 0 ${width} 220`); svg.setAttribute('role','img'); svg.setAttribute('aria-label','Profili attivi e partite iniziate per giorno UTC');
  const title = document.createElementNS(NS,'title'); title.textContent = items.map(i => `${i.day}: ${i.active} profili attivi, ${i.matches} partite`).join('; '); svg.append(title);
  function shape(tag, attrs, text) { const el = document.createElementNS(NS,tag); Object.entries(attrs).forEach(([k,v]) => el.setAttribute(k,v)); if (text != null) el.textContent = text; svg.append(el); return el; }
  const max = Math.max(4,...items.flatMap(i => [i.active,i.matches])), ceil = Math.ceil(max / 4) * 4;
  for (let i = 0; i <= 4; i++) { const y = 185 - i * 39; shape('line',{x1:32,y1:y,x2:width-18,y2:y,class:'grid'}); shape('text',{x:24,y:y+3,'text-anchor':'end'},number(ceil*i/4)); }
  const step = (width - 60) / Math.max(1,items.length), points = [];
  items.forEach((item,i) => {
    const x = 32 + (i + .5) * step, y = 185 - item.active / ceil * 156, height = item.matches / ceil * 156;
    const bar = shape('rect',{x:x-Math.min(13,step/4),y:185-height,width:Math.min(26,step/2),height,rx:3,fill:'#d8c79d'});
    const tip = document.createElementNS(NS,'title'); tip.textContent = `${item.day}: ${item.active} utenti, ${item.matches} partite`; bar.append(tip);
    points.push(`${x},${y}`);
    if (items.length <= Math.floor(width/65) || i % Math.ceil(items.length/Math.max(2,Math.floor(width/85))) === 0) shape('text',{x,y:210,'text-anchor':'middle'},new Intl.DateTimeFormat('it-IT',{day:'numeric',month:'short',timeZone:'UTC'}).format(new Date(`${item.day}T12:00:00Z`)));
  });
  shape('polyline',{points:points.join(' '),fill:'none',stroke:'#75935e','stroke-width':2.5,'stroke-linejoin':'round','stroke-linecap':'round'});
  points.forEach(point => { const [cx,cy]=point.split(','); shape('circle',{cx,cy,r:items.length>30?2:3.5,fill:'#75935e',stroke:'white','stroke-width':1.5}); });
  $('chart').append(svg);
}
function gameCard(room) {
  const card = node('article',null,'game-card'), top = node('div',null,'game-top');
  top.append(node('span',room.code,'room-code'),node('span',phaseName(room.phase),`badge ${room.phase}`));
  const vs = node('div',null,'versus');
  room.players.forEach((p,i) => { if (i) vs.append(node('span','vs','vs')); vs.append(node('span',`${p.connected?'●':'○'} ${p.name}${room.phase==='waiting' && p.ready?' · Pronto':''}`)); });
  if (room.players.length === 1) vs.append(node('span','vs','vs'),node('span','Posto libero'));
  const bottom = node('div',null,'game-bottom'); bottom.append(node('span',modeName(room.mode)),node('span',room.mode==='ranked'?`Round ${room.round}/3`:`${room.pairs} coppie · ${deckNames[room.theme] || room.theme}`));
  card.append(top,vs,bottom); return card;
}
function renderRooms(id, rooms, empty) { clear(id); $(id).append(...(rooms.length ? rooms.map(gameCard) : [node('div',empty,'empty')])); }
function cell(row, text, secondary) { const td=node('td',text); if (secondary) td.append(node('small',secondary)); row.append(td); return td; }
function result(match) {
  if (match.phase !== 'finished') return '—';
  if (match.finish_reason === 'cancelled') return 'Annullata';
  if (match.finish_reason === 'forfeit') return `Abbandono · vince ${match.players.find(p=>p.seat===match.winner_seat)?.name || 'Ospite'}`;
  if (match.winner_seat == null) return 'Pareggio';
  const winner=match.players.find(p=>p.seat===match.winner_seat);
  return `${winner?.name || 'Ospite'} · ${match.mode==='ranked' ? `${winner?.attempts ?? '—'} tentativi` : match.players.map(p=>p.score).join('–')}`;
}
function render(data) {
  const s=data.summary;
  data.decks.forEach(deck => { deckNames[deck.id] = deck.name; });
  $('update-time').textContent=`Aggiornato alle ${new Intl.DateTimeFormat('it-IT',{timeStyle:'medium'}).format(data.generatedAt)}`;
  $('live-count').textContent=number(s.liveMatches+s.lobbies); $('uptime').textContent=`Attivo da ${duration(s.uptimeMs)}`;
  $('metrics').replaceChildren(metric('Utenti attivi · 24 ore',s.active24h,`${number(s.active7d)} negli ultimi 7 giorni`,'♧'),metric('Giocatori connessi',s.connected,`${number(s.connections)} connessioni al servizio`,'◉'),metric('Partite in corso',s.liveMatches,`${number(s.lobbies)} lobby in attesa`,'◫'),metric('Profili totali',s.totalProfiles,`${number(s.newProfiles)} nuovi nel periodo`,'↗'));
  $('secondary-metrics').replaceChildren(mini('Partite iniziate',number(s.startedMatches),'nel periodo selezionato'),mini('Completate',number(s.completed),`${number(s.abandoned)} per abbandono · ${number(s.finished)} terminate`),mini('Durata media',duration(s.duration),'delle partite terminate con orari noti'),mini('Gemme assegnate',number(s.gemsAwarded),`${number(s.deckUnlocks)} sblocchi di deck`));
  renderChart(data.daily); clear('arenas'); const arenaMax=Math.max(1,...data.arenas.map(a=>a.matches));
  data.arenas.forEach(a=>{const row=node('div',null,'arena-row'),track=node('div',null,'arena-track'),bar=node('progress');bar.max=arenaMax;bar.value=a.matches;bar.setAttribute('aria-label',`${a.name}: ${a.matches} partite`);track.append(bar);row.append(node('span',a.name),node('strong',number(a.matches)),track);$('arenas').append(row);});
  if (!data.arenas.length) $('arenas').append(node('p','Le arene non sono ancora attive nella versione online.','empty'));
  const preview=[...data.live,...data.lobbies].slice(0,3);
  renderRooms('live-preview',preview,'Nessuna partita o lobby attiva. Qui compariranno le prossime sfide.');
  renderRooms('live-games',data.live,'Nessuna partita in corso.');renderRooms('lobbies',data.lobbies,'Nessuna lobby in attesa.');
  $('playing-total').textContent=number(data.live.length);$('lobby-total').textContent=number(data.lobbies.length);
  $('coverage').textContent=`Rilevazione attiva dal ${date(data.trackingSince)}. Storico online e attività conservati per 90 giorni. ${number(s.active30d)} profili attivi negli ultimi 30 giorni; ${number(s.savedProfiles)} profili con recupero o account collegato. ${s.pendingRewards ? `${number(s.pendingRewards)} premi in attesa di elaborazione.` : 'Nessun premio in attesa.'} Le attività precedenti all’attivazione e la pratica offline non sono ricostruite.`;
  clear('match-rows');data.matches.items.forEach(m=>{const row=node('tr');cell(row,m.code,date(m.started_at,true));const players=cell(row,null);m.players.forEach(p=>players.append(node('span',`${p.name} · ${number(p.score)}${m.mode==='ranked'?` coppie / ${p.attempts ?? '—'} tentativi`:''}`,'player-name')));cell(row,modeName(m.mode),m.mode==='ranked'?`Round ${m.round}/3`:`${m.pairs} coppie`);cell(row,deckNames[m.theme]||m.theme);const status=cell(row,null);status.append(node('span',phaseName(m.phase),`badge ${m.phase}`));cell(row,result(m));cell(row,m.started_at!=null && m.finished_at!=null?duration(m.finished_at-m.started_at):'—');$('match-rows').append(row);});
  if (!data.matches.items.length) { const row=node('tr'),td=cell(row,'Nessuna partita trovata con questi filtri.');td.colSpan=7;$('match-rows').append(row); }
  page=data.matches.page;$('pagination-label').textContent=`${number(data.matches.total)} partite trovate`;$('page-number').textContent=`${page} / ${data.matches.pages}`;$('previous').disabled=page<=1;$('next').disabled=page>=data.matches.pages;$('export').disabled=!data.matches.items.length;
  clear('profile-rows');data.profiles.forEach(p=>{const row=node('tr');cell(row,p.name||'Ospite',p.id);cell(row,date(p.lastActive,true));cell(row,date(p.createdAt,true));cell(row,number(p.gems));cell(row,p.crowns==null?'—':number(p.crowns));cell(row,p.linkedProviders?number(p.linkedProviders):'Nessuno');$('profile-rows').append(row);});
  if(!data.profiles.length){const row=node('tr'),td=cell(row,'Nessun profilo trovato.');td.colSpan=6;$('profile-rows').append(row);}
  if(s.recordingErrors) message('La registrazione delle statistiche ha incontrato un errore. Lo storico potrebbe essere incompleto.');
  else if(s.pendingRewards) message(`${number(s.pendingRewards)} premi sono in attesa di elaborazione. Il servizio riprova automaticamente.`);
}
async function refresh() {
  if (!authenticated || view==='security') return;
  if (busy) { pendingRefresh=true; return; }
  busy=true;$('refresh').disabled=true;
  const params=new URLSearchParams({days:$('period').value,page:String(page),q:view==='users'?$('user-search').value:$('search').value,mode:$('mode').value,phase:$('phase').value});
  try { const data=await api(`dashboard?${params}`); if(authenticated){snapshot=data;message();render(data);} }
  catch(error){if(authenticated)message(`${error.message} I dati visualizzati potrebbero non essere aggiornati.`);}
  finally{busy=false;$('refresh').disabled=false;if(pendingRefresh){pendingRefresh=false;void refresh();}}
}
$('refresh').addEventListener('click',()=>{if(view==='security')void loadKeys().catch(e=>message(e.message));else void refresh();});
['period','mode','phase'].forEach(id=>$(id).addEventListener('change',()=>{page=1;void refresh();}));
['search','user-search'].forEach(id=>$(id).addEventListener('input',()=>{clearTimeout(searchTimer);searchTimer=setTimeout(()=>{page=1;void refresh();},300);}));
$('previous').addEventListener('click',()=>{page--;void refresh();});$('next').addEventListener('click',()=>{page++;void refresh();});
$('export').addEventListener('click',()=>{
  if(!snapshot)return;
  // Prefix spreadsheet formulas so player-controlled names remain plain data.
  const csvValue=value=>`"${String(value??'').replace(/^[=+@\-\t\r\n]/,"'$&").replaceAll('"','""')}"`;
  const rows=[['Stanza','Inizio','Modalità','Giocatori','Stato','Risultato','Fine'],...snapshot.matches.items.map(m=>[m.code,m.started_at!=null?new Date(m.started_at).toISOString():'',modeName(m.mode),m.players.map(p=>p.name).join(' / '),phaseName(m.phase),result(m),m.finished_at!=null?new Date(m.finished_at).toISOString():''])];
  const url=URL.createObjectURL(new Blob(['\uFEFF'+rows.map(row=>row.map(csvValue).join(';')).join('\r\n')],{type:'text/csv;charset=utf-8'}));const a=node('a');a.href=url;a.download=`sommomemory-partite-${new Date().toISOString().slice(0,10)}-p${page}.csv`;a.click();setTimeout(()=>URL.revokeObjectURL(url),1000);
});
async function loadKeys(){
  const data=await api('passkeys');clear('passkeys');data.items.forEach(k=>{const row=node('div',null,'key-row'),info=node('div',k.label),remove=node('button','Rimuovi');info.append(node('small',`Creata ${date(k.createdAt,true)} · ${k.lastUsedAt?'Ultimo accesso '+date(k.lastUsedAt,true):'Mai usata per accedere'}`));remove.disabled=data.items.length<=1;remove.addEventListener('click',()=>perform(remove,async()=>{if(!window.confirm(`Rimuovere la passkey “${k.label}”? Le sue sessioni admin verranno chiuse.`))return;await api('passkeys/remove',{id:k.id});const status=await api('status');if(!status.authenticated){showLogin();return;}await loadKeys();}));row.append(info,remove);$('passkeys').append(row);});
}
$('add-key').addEventListener('click',()=>perform($('add-key'),async()=>{const optionsJSON=await api('register/options',{label:$('key-label').value||'Passkey di riserva'});const response=await SimpleWebAuthnBrowser.startRegistration({optionsJSON});await api('register/verify',response);$('key-label').value='';message('Passkey aggiunta.');await loadKeys();}));
let lastChartWidth=0;
new ResizeObserver(()=>{const width=$('chart').clientWidth;if(width && width!==lastChartWidth){lastChartWidth=width;if(snapshot)renderChart(snapshot.daily);}}).observe($('chart'));
setInterval(()=>{if(authenticated&&!document.hidden)void refresh();},15_000);
document.addEventListener('visibilitychange',()=>{if(authenticated&&!document.hidden)void refresh();});
(async()=>{
  const params=new URLSearchParams(location.hash.slice(1)),token=params.get('setup');
  if(token){$('setup-token').value=token;$('setup').open=true;history.replaceState(null,'','/admin');}
  try{const status=await api('status');if(status.authenticated){await showDashboard();return;}
    const supported=Boolean(window.PublicKeyCredential&&window.SimpleWebAuthnBrowser&&window.isSecureContext);$('login-button').disabled=!supported;$('setup-button').disabled=!supported;
    if(!status.configured)$('setup').open=true;
    message(!supported?'Apri questa pagina in un browser con supporto passkey, tramite HTTPS o localhost.':status.configured?'Usa Touch ID, Face ID o il tuo gestore di passkey.':'Registra la prima passkey con il codice monouso del server.',true);
  }catch(error){message(error.message,true);}
})();
