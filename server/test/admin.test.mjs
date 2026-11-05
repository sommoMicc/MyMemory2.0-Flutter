import test from 'node:test';
import assert from 'node:assert/strict';
import { once } from 'node:events';
import { mkdtempSync, readFileSync, writeFileSync, existsSync, rmSync, statSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { createHash, generateKeyPairSync, randomBytes, sign } from 'node:crypto';
import { isoCBOR } from '@simplewebauthn/server/helpers';
import { startServer } from '../src/server.mjs';
import { GameEngine } from '../src/game.mjs';
import { EconomyStore } from '../src/economy.mjs';
import { AdminData } from '../src/admin-data.mjs';
const origin = 'http://localhost:8787';
const b64 = bytes => Buffer.from(bytes).toString('base64url');
const sha = bytes => createHash('sha256').update(bytes).digest();
// An actual ES256 authenticator: exercise production verification and signatures,
// not a stub that returns "verified" for arbitrary browser input.
function authenticator() {
  const { privateKey, publicKey } = generateKeyPairSync('ec', { namedCurve: 'prime256v1' });
  const jwk = publicKey.export({ format: 'jwk' }), id = randomBytes(32);
  const cose = isoCBOR.encode(new Map([[1,2],[3,-7],[-1,1],[-2,Buffer.from(jwk.x,'base64url')],[-3,Buffer.from(jwk.y,'base64url')]]));
  const client = (type, challenge, from) => Buffer.from(JSON.stringify({ type, challenge, origin: from, crossOrigin: false }));
  return {
    id: b64(id),
    register(challenge, { from = origin, uv = true } = {}) {
      const length = Buffer.alloc(2); length.writeUInt16BE(id.length);
      const authData = Buffer.concat([sha('localhost'),Buffer.from([uv?0x45:0x41]),Buffer.alloc(4),Buffer.alloc(16),length,id,cose]);
      return { id:b64(id),rawId:b64(id),type:'public-key',clientExtensionResults:{},response:{
        clientDataJSON:b64(client('webauthn.create',challenge,from)),
        attestationObject:b64(isoCBOR.encode(new Map([['fmt','none'],['attStmt',new Map()],['authData',authData]]))),transports:['internal'] } };
    },
    login(challenge,{ from=origin, uv=true, counter=1, tamper=false, rp='localhost' }={}) {
      const count=Buffer.alloc(4);count.writeUInt32BE(counter);
      const authData=Buffer.concat([sha(rp),Buffer.from([uv?5:1]),count]),clientData=client('webauthn.get',challenge,from);
      const signature=sign('sha256',Buffer.concat([authData,sha(clientData)]),privateKey);if(tamper)signature[signature.length-1]^=1;
      return {id:b64(id),rawId:b64(id),type:'public-key',clientExtensionResults:{},response:{authenticatorData:b64(authData),clientDataJSON:b64(clientData),signature:b64(signature),userHandle:b64(Buffer.from('sommomemory-administrator'))}};
    },
  };
}
async function fixture() {
  const dir=mkdtempSync(join(tmpdir(),'sommomemory-admin-'));
  const server=startServer({port:0,dataDir:dir,adminConfig:{origin}});await once(server.http,'listening');
  const base=`http://127.0.0.1:${server.http.address().port}`;
  let cookies=new Map();
  const request=async(path,body,extra={})=>{
    const response=await fetch(base+path,{method:body===undefined?'GET':'POST',headers:{...(body===undefined?{}:{Origin:origin,'Content-Type':'application/json'}),Cookie:[...cookies].map(([k,v])=>`${k}=${v}`).join('; '),...extra},body:body===undefined?undefined:JSON.stringify(body)});
    for(const header of response.headers.getSetCookie()){const [name,value]=header.split(';')[0].split('=');cookies.set(name,value);}
    return response;
  };
  const post=async(path,body={})=>{const r=await request('/admin/api/'+path,body);return {status:r.status,body:await r.json(),headers:r.headers};};
  const setup=()=>JSON.parse(readFileSync(join(dir,'admin-enrollment.json'),'utf8')).token;
  const register=async(key,token=setup())=>{const opts=await post('register/options',{setupToken:token,label:'Mac di Michele'});assert.equal(opts.status,200);return post('register/verify',key.register(opts.body.challenge));};
  return {server,dir,base,request,post,setup,register,clearCookies:()=>{cookies=new Map();},close:async()=>{await server.close();rmSync(dir,{recursive:true,force:true});}};
}

test('admin is private, origin checked, never cached, and bootstrap alone cannot read data',async()=>{
  const f=await fixture();try{
    assert.equal((await f.request('/admin/api/dashboard')).status,401);
    assert.equal((await f.request('/admin/api/passkeys')).status,401);
    const page=await f.request('/admin',undefined,{'Sec-Fetch-Site':'cross-site'});
    assert.equal(page.status,200);assert.equal(page.headers.get('cache-control'),'no-store');assert.match(page.headers.get('content-security-policy'),/frame-ancestors 'none'/);
    const html=await page.text();assert.match(html,/Accedi con passkey/);assert.ok(!html.includes(f.setup()));
    assert.equal((statSync(join(f.dir,'admin-enrollment.json')).mode&0o777),0o600);
    for(const path of ['admin.js','admin.css','webauthn.js']) assert.equal((await f.request('/admin/'+path)).status,200);
    assert.equal((await f.request('/admin/missing')).status,404);
    assert.equal((await f.request('/admin/api/status',undefined,{'Sec-Fetch-Site':'cross-site'})).status,403);
    assert.equal((await f.request('/admin/api/register/options',{setupToken:f.setup()},{Origin:'https://evil.example'})).status,403);
    assert.equal((await f.request('/admin/api/login/options',{}, {Origin:''})).status,403);
    const opts=await f.post('register/options',{setupToken:f.setup()});assert.equal(opts.status,200);
    assert.equal(opts.body.authenticatorSelection.userVerification,'required');assert.equal(opts.body.authenticatorSelection.residentKey,'required');
    assert.equal((await f.request('/admin/api/dashboard')).status,401);
    assert.equal((await f.post('register/options',{setupToken:'a'.repeat(43)})).status,401);
  }finally{await f.close();}
});

test('real passkey enrollment, signed login, replay protection, signature checks, expiry and logout',async()=>{
  const f=await fixture();try{
    const key=authenticator(),token=f.setup();
    const registered=await f.register(key);assert.equal(registered.status,200);
    assert.match(registered.headers.get('set-cookie'),/HttpOnly; SameSite=Strict/);
    assert.ok(!existsSync(join(f.dir,'admin-enrollment.json')));
    assert.equal((await f.request('/admin/api/dashboard')).status,200);
    const stored=f.server.economy.db.prepare('SELECT * FROM admin_passkeys').get();assert.equal(stored.label,'Mac di Michele');assert.ok(stored.public_key.length);
    assert.equal((await f.post('logout')).status,200);assert.equal((await f.request('/admin/api/dashboard')).status,401);
    assert.equal((await f.post('register/options',{setupToken:token})).status,401);
    for(const invalid of [{from:'https://evil.example'},{uv:false},{tamper:true},{rp:'evil.example'}]){
      const opts=await f.post('login/options');const response=key.login(opts.body.challenge,invalid);
      assert.equal((await f.post('login/verify',response)).status,401);
      assert.equal((await f.request('/admin/api/dashboard')).status,401);
    }
    const opts=await f.post('login/options'),response=key.login(opts.body.challenge);
    assert.equal((await f.post('login/verify',response)).status,200);
    assert.equal((await f.post('login/verify',response)).status,400);
    assert.equal((await f.request('/admin/api/dashboard')).status,200);
    // An attacker cannot replay a counter under a fresh challenge.
    const repeated=await f.post('login/options');assert.equal((await f.post('login/verify',key.login(repeated.body.challenge))).status,401);
    f.server.economy.db.prepare('UPDATE admin_sessions SET expires_at=0').run();
    assert.equal((await f.request('/admin/api/dashboard')).status,401);
  }finally{await f.close();}
});

test('enrollment rejects wrong origin, missing verification, missing challenges and expired bootstrap',async()=>{
  const f=await fixture();try{
    const key=authenticator();
    for(const invalid of [{from:'https://evil.example'},{uv:false}]){
      const opts=await f.post('register/options',{setupToken:f.setup()});
      assert.equal((await f.post('register/verify',key.register(opts.body.challenge,invalid))).status,400);
      assert.ok(existsSync(join(f.dir,'admin-enrollment.json')));
    }
    const opts=await f.post('register/options',{setupToken:f.setup()});f.clearCookies();
    assert.equal((await f.post('register/verify',key.register(opts.body.challenge))).status,400);
    const file=join(f.dir,'admin-enrollment.json'),entry=JSON.parse(readFileSync(file));entry.expiresAt=0;writeFileSync(file,JSON.stringify(entry));
    assert.equal((await f.post('register/options',{setupToken:entry.token})).status,401);
  }finally{await f.close();}
});

test('only recent passkey sessions can manage keys, last key stays, removal revokes sessions',async()=>{
  const f=await fixture();try{
    const first=authenticator(),second=authenticator();await f.register(first);
    assert.equal((await f.post('passkeys/remove',{id:first.id})).status,409);
    const options=await f.post('register/options',{label:'Riserva'});assert.equal(options.status,200);
    assert.equal((await f.post('register/verify',second.register(options.body.challenge))).status,200);
    assert.equal((await f.post('passkeys/remove',{id:second.id})).status,200);
    assert.equal((await f.request('/admin/api/dashboard')).status,401);
    const login=await f.post('login/options');await f.post('login/verify',first.login(login.body.challenge));
    f.server.economy.db.prepare('UPDATE admin_sessions SET created_at=created_at-301000').run();
    assert.equal((await f.post('register/options',{})).status,401);
    assert.equal((await f.request('/admin/api/dashboard')).status,200);
  }finally{await f.close();}
});

test('an initial bootstrap cannot bypass existing keys and recovery revokes previous sessions',async()=>{
  const f=await fixture();try{
    const key=authenticator(),token=f.setup();await f.register(key);
    // Recreating an initial bootstrap file cannot bypass an existing passkey.
    const file=join(f.dir,'admin-enrollment.json');writeFileSync(file,JSON.stringify({token,expiresAt:Date.now()+60000}));
    await f.post('logout');assert.equal((await f.post('register/options',{setupToken:token})).status,401);
    const recoveryToken=b64(randomBytes(32));
    writeFileSync(file,JSON.stringify({token:recoveryToken,expiresAt:Date.now()+60000,recovery:true}));
    assert.equal((await f.register(authenticator(),recoveryToken)).status,200);
    assert.equal(f.server.economy.db.prepare('SELECT COUNT(*) n FROM admin_sessions').get().n,1);
    writeFileSync(file,JSON.stringify({token:recoveryToken,expiresAt:Date.now()+60000,recovery:true}));
    await f.post('logout');
    assert.equal((await f.post('register/options',{setupToken:recoveryToken})).status,401);
  }finally{await f.close();}
});

test('activity is deduplicated, matches survive rematch/restart, and deletion anonymizes history',()=>{
  let now=Date.UTC(2026,10,5,12);const dir=mkdtempSync(join(tmpdir(),'sommomemory-admin-data-'));
  let store=new EconomyStore({dataDir:dir,now:()=>now});
  let engine=new GameEngine({dataDir:dir,now:()=>now});
  let data=new AdminData({store,engine,now:()=>now});
  try{
    const a=store.createProfile(),b=store.createProfile();store.updateProfile(a.profile.id,{displayName:'<script>secret</script>'});
    store.authenticate(a.token);store.authenticate(a.token);store.issueToken(a.profile.id);
    assert.equal(data.snapshot().summary.active24h,2);
    assert.equal(store.db.prepare('SELECT COUNT(*) n FROM admin_activity').get().n,2);
    const host=engine.create({name:'A',pairs:6,profileId:a.profile.id}),guest=engine.join({code:host.code,name:'B',profileId:b.profile.id});
    const room=engine.room(host.code),firstId=room.roundId;now+=120000;
    engine.finish(room,'completed',host.playerId);engine.change(room);
    let snap=data.snapshot();assert.equal(snap.summary.startedMatches,1);assert.equal(snap.summary.completed,1);assert.equal(snap.summary.duration,120000);
    assert.equal(snap.matches.items.length,1);assert.equal(snap.matches.items[0].players[0].name,'<script>secret</script>');
    for(const secret of [host.token,guest.token,a.token,b.token,'recovery_hash','public_key','board','capabilityKey'])assert.ok(!JSON.stringify(snap).includes(secret));
    engine.rematch(host.code,host.playerId);engine.rematch(host.code,guest.playerId);assert.notEqual(room.roundId,firstId);
    assert.equal(data.snapshot().summary.startedMatches,2);
    store.deleteProfile(a.profile.id,{confirmDelete:true});
    snap=data.snapshot();assert.equal(snap.summary.active24h,1);assert.equal(snap.matches.items[0].players[0].name,'Ospite');assert.ok(!JSON.stringify(snap).includes('<script>secret</script>'));
    data.close();store.close();store=new EconomyStore({dataDir:dir,now:()=>now});engine=new GameEngine({dataDir:dir,now:()=>now});data=new AdminData({store,engine,now:()=>now});
    assert.equal(data.snapshot().matches.total,2);
    now+=86400000;engine.tick();now+=91*86400000;data.cleanup();assert.equal(store.db.prepare('SELECT COUNT(*) n FROM admin_matches').get().n,0);assert.equal(data.snapshot().summary.active30d,0);
  }finally{data.close();store.close();rmSync(dir,{recursive:true,force:true});}
});

test('lobbies are not matches, ranked rounds share one match and unavailable rooms are explicit',()=>{
  let now=Date.now();const store=new EconomyStore({now:()=>now}),engine=new GameEngine({now:()=>now});const data=new AdminData({store,engine,now:()=>now});
  try{
    const host=engine.create({name:'A',pairs:6,supportedFeatures:['lobby-v1']});
    assert.equal(data.snapshot().matches.total,0);assert.equal(data.snapshot().lobbies.length,1);
    const guest=engine.join({code:host.code,name:'B',supportedFeatures:['lobby-v1']});engine.ready(host.code,host.playerId,true);engine.ready(host.code,guest.playerId,true);
    assert.equal(data.snapshot().matches.total,1);assert.equal(data.snapshot().lobbies.length,0);
    const room=engine.room(host.code);room.matchType='ranked';room.matchId='ranked-test';room.roundIndex=1;room.roundResults=[];engine.change(room);
    room.roundIndex=2;room.roundId='second-round';engine.change(room);room.roundIndex=3;room.roundId='third-round';engine.change(room);
    assert.equal(data.snapshot().matches.items.filter(m=>m.mode==='ranked').length,1);
    now+=1000;data.removed(host.code);assert.ok(data.snapshot().matches.items.every(m=>m.phase==='unavailable'));
    assert.equal(data.snapshot(new URLSearchParams('mode=ranked')).matches.total,1);
    assert.equal(data.snapshot(new URLSearchParams('q=does-not-exist')).matches.total,0);
    assert.equal(data.snapshot(new URLSearchParams('page=NaN')).matches.page,1);
  }finally{data.close();store.close();}
});


test('two independent browser challenges cannot consume the same enrollment twice',async()=>{
  const f=await fixture();try{
    const first=authenticator(),second=authenticator(),token=f.setup();
    const a=await f.post('register/options',{setupToken:token});
    const cookieA=a.headers.get('set-cookie').split(';')[0];
    f.clearCookies();
    const b=await f.post('register/options',{setupToken:token});
    const cookieB=b.headers.get('set-cookie').split(';')[0];
    const results=await Promise.all([
      f.request('/admin/api/register/verify',first.register(a.body.challenge),{Cookie:cookieA}),
      f.request('/admin/api/register/verify',second.register(b.body.challenge),{Cookie:cookieB}),
    ]);
    assert.deepEqual(results.map(r=>r.status).sort(),[200,403]);
    assert.equal(f.server.economy.db.prepare('SELECT COUNT(*) n FROM admin_passkeys').get().n,1);
  }finally{await f.close();}
});

test('admin authentication has a bounded per-address rate limit',async()=>{
  const f=await fixture();try{
    for(let i=0;i<30;i++)assert.equal((await f.post('login/options')).status,200);
    assert.equal((await f.post('login/options')).status,429);
    assert.equal((await f.request('/admin/api/dashboard')).status,401);
  }finally{await f.close();}
});


test('admin supports the existing production economy without arenas or crowns',()=>{
  const store=new EconomyStore(),engine=new GameEngine();
  store.db.exec('ALTER TABLE profiles DROP COLUMN crowns');
  delete store.catalog;
  const data=new AdminData({store,engine});
  try {
    store.db.prepare("INSERT INTO profiles(id,display_name,gems,created_at) VALUES('legacy','Legacy',100,?)").run(Date.now());
    const snapshot=data.snapshot();
    assert.equal(snapshot.profiles[0].crowns,null);
    assert.equal(snapshot.arenas.length,0);
    assert.equal(snapshot.decks.find(d=>d.id==='garden').name,'Animali');
  } finally { data.close();store.close(); }
});
