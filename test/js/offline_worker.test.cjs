const test=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),vm=require('node:vm');
const {createHash,webcrypto}=require('node:crypto');
const Maps=require('../../web/offline_maps.js');
function harness({corrupt=false,active=false}={}){
 const scope='https://app.test/fpv/',version='a'.repeat(64),listeners=new Map(),buckets=new Map();let network=true,calls=0,claimed=false;
 const files={'index.html':'<html>Offline app</html>','flutter_bootstrap.js':'bootstrap','main.dart.js':'application'};
 const manifest={version,assets:Object.entries(files).map(([path,text])=>({path,size:Buffer.byteLength(text),sha256:createHash('sha256').update(text).digest('hex')}))};
 const normalize=k=>typeof k==='string'?k:k.url;
 const caches={async open(name){if(!buckets.has(name))buckets.set(name,new Map());const rows=buckets.get(name);return {
  async match(key){return rows.get(normalize(key))?.clone();},async put(key,value){rows.set(normalize(key),value.clone());},
  async delete(key){return rows.delete(normalize(key));},async keys(){return [...rows.keys()].map(url=>({url}));}};},
  async keys(){return [...buckets.keys()];},async delete(name){return buckets.delete(name);}};
 const fetch=async input=>{calls++;if(!network)throw new Error('offline');const url=typeof input==='string'?input:input.url??String(input);
  const path=new URL(url).pathname.substring('/fpv/'.length);
  if(path==='offline_asset_manifest.json')return new Response(JSON.stringify(manifest));
  return new Response((corrupt&&path==='main.dart.js')?'tampered':files[path]??'other',{headers:{'content-type':path.endsWith('.html')?'text/html':'application/javascript'}});
 };
 const self={location:{href:scope+'offline_service_worker.js?v='+version},registration:{scope,active:active?{}:null},clients:{async claim(){claimed=true;}},
  async skipWaiting(){},addEventListener(name,fn){listeners.set(name,fn);}};
 vm.runInNewContext(fs.readFileSync(require.resolve('../../web/offline_service_worker.js'),'utf8'),{
  self,caches,fetch,URL,Response,Headers,TextDecoder,TextEncoder,Uint8Array,crypto:webcrypto,
  FPVOfflineMaps:Maps,importScripts(){},setTimeout,clearTimeout,AbortController});
 async function event(name){let promise;listeners.get(name)({waitUntil(value){promise=value;}});await promise;}
 async function request(path){let promise;listeners.get('fetch')({request:new Request(scope+path),respondWith(value){promise=value;}});return promise;}
 return {event,request,buckets,caches,scope,version,get claimed(){return claimed;},get calls(){return calls;},set network(value){network=value;}};
}
test('a verified complete app snapshot starts offline with no mixing of network versions',async()=>{
 const p=harness();await p.event('install');await p.event('activate');assert.equal(p.claimed,true);
 p.network=false;const before=p.calls;
 assert.match(await(await p.request('')).text(),/Offline app/);
 assert.equal(await(await p.request('main.dart.js')).text(),'application');assert.equal(p.calls,before);
 await assert.rejects(p.request('api/private.json'),/offline/);
});
test('incomplete or tampered deployment cannot replace the prior offline snapshot',async()=>{
 const p=harness({corrupt:true,active:true});
 const oldName='fpvmanager-app:'+p.scope+':old';await p.caches.open(oldName);
 await assert.rejects(p.event('install'),/integrity/);
 assert.ok(p.buckets.has(oldName));assert.equal([...p.buckets.keys()].some(n=>n.startsWith('fpvmanager-app:'+p.scope+':'+p.version)),false);
 assert.equal(p.claimed,false);
});
test('a cached-only missing tile returns an explicit failure without contacting a provider',async()=>{
 const p=harness();const before=p.calls;
 const response=await p.request('offline/maps/terrain/20250101/0/0/0.terrain?cacheOnly=1');
 assert.equal(response.status,404);assert.equal(p.calls,before);
});

test('evicted app assets recover online only when they match the active version',async()=>{
 const p=harness();await p.event('install');await p.event('activate');
 const name=[...p.buckets.keys()].find(n=>n.startsWith('fpvmanager-app:'+p.scope+':'));
 const cache=await p.caches.open(name);await cache.delete(p.scope+'main.dart.js');
 p.network=false;assert.equal((await p.request('main.dart.js')).status,503);
 p.network=true;assert.equal(await(await p.request('main.dart.js')).text(),'application');
 p.network=false;assert.equal(await(await p.request('main.dart.js')).text(),'application');
});
