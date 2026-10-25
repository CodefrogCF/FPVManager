const version=new URL(self.location.href).searchParams.get('v');
importScripts('offline_maps.js'+(version?'?v='+encodeURIComponent(version):''));
const scope=self.registration.scope,root=new URL('offline/maps/',scope).href;
const appPrefix='fpvmanager-app:'+scope+':',controlName='fpvmanager-app-control:'+scope;
const pointer=new URL('__fpv_active_app',scope).href;
const transport=FPVOfflineMaps.createTransport({caches,fetch,root});
let installed=null,active=null;
async function storedManifest(){
 if(active)return active;
 const response=await(await caches.open(controlName)).match(pointer);
 return active=response?await response.json():null;
}
function assetUrl(path){
 if(typeof path!=='string'||path.startsWith('/')||path.includes('..')||path.includes('\\')||path.includes('?')||path.includes('#'))throw new Error('Invalid application asset path');
 const url=new URL(path,scope);if(!url.href.startsWith(scope))throw new Error('Invalid application asset origin');return url.href;
}
async function verifiedAsset(asset){
 const response=await fetch(assetUrl(asset.path),{cache:'reload',credentials:'same-origin',redirect:'error'});
 if(/no-store|private/i.test(response.headers.get('cache-control')??''))throw new Error('Host disallows application caching');
 const bytes=await FPVOfflineMaps.boundedBytes(response,20*1024*1024);
 const digest=[...new Uint8Array(await crypto.subtle.digest('SHA-256',bytes))].map(n=>n.toString(16).padStart(2,'0')).join('');
 if(bytes.length!==asset.size||digest!==asset.sha256)throw new Error('Application snapshot integrity mismatch');
 const headers=new Headers(response.headers);headers.delete('content-encoding');headers.set('content-length',String(bytes.length));
 return new Response(bytes,{headers});
}
async function installSnapshot(){
 if(!version)return; // flutter run / development: map caching only.
 const response=await fetch(new URL('offline_asset_manifest.json',scope),{cache:'no-store',credentials:'same-origin',redirect:'error'});
 const manifest=JSON.parse(new TextDecoder().decode(await FPVOfflineMaps.boundedBytes(response,1024*1024)));
 if(manifest.version!==version||!Array.isArray(manifest.assets)||manifest.assets.length>2000||!/^[0-9a-f]{64}$/.test(version))throw new Error('Invalid application manifest');
 let total=0;
 for(const asset of manifest.assets){
  assetUrl(asset.path);
  if(!Number.isSafeInteger(asset.size)||asset.size<0||asset.size>20*1024*1024||!/^[0-9a-f]{64}$/.test(asset.sha256)||(total+=asset.size)>256*1024*1024)throw new Error('Application snapshot exceeds limits');
 }
 if(!['index.html','flutter_bootstrap.js','main.dart.js'].every(path=>manifest.assets.some(a=>a.path===path)))throw new Error('Incomplete application snapshot');
 const nonce=crypto.getRandomValues(new Uint8Array(8));
 const name=appPrefix+version+':'+[...nonce].map(n=>n.toString(16).padStart(2,'0')).join(''),cache=await caches.open(name);
 try{
  // Sequential reads bound memory and let a failed deployment retain the old worker.
  for(const asset of manifest.assets){
   await cache.put(assetUrl(asset.path),await verifiedAsset(asset));
  }
  installed={name,version,paths:manifest.assets.map(a=>a.path),assets:manifest.assets};
  await cache.put(new URL('__fpv_manifest',scope).href,new Response(JSON.stringify(installed)));
  await(await caches.open(controlName)).put(new URL('__fpv_pending_'+version,scope).href,new Response(JSON.stringify(installed)));
 }catch(error){await caches.delete(name);throw error;}
}
self.addEventListener('install',event=>event.waitUntil((async()=>{
 await installSnapshot();
 // Existing clients finish with their current coherent application snapshot.
 if(!self.registration.active)await self.skipWaiting();
})()));
self.addEventListener('activate',event=>event.waitUntil((async()=>{
 if(version){
  const control=await caches.open(controlName);
  if(!installed){const saved=await control.match(new URL('__fpv_pending_'+version,scope).href);if(!saved)throw new Error('Application snapshot missing');installed=await saved.json();}
  const cache=await caches.open(installed.name);
  if(!await cache.match(new URL('__fpv_manifest',scope).href))throw new Error('Application snapshot unavailable');
  await(await caches.open(controlName)).put(pointer,new Response(JSON.stringify(installed)));active=installed;
  await control.delete(new URL('__fpv_pending_'+version,scope).href);
  for(const name of await caches.keys())if(name.startsWith(appPrefix)&&name!==installed.name)await caches.delete(name);
 }
 await self.clients.claim();
})()));
self.addEventListener('fetch',event=>{
 const request=event.request,url=new URL(request.url);
 if(request.method!=='GET'||url.origin!==new URL(scope).origin||!url.href.startsWith(scope))return;
 if(url.href.startsWith(root)){
  const key=url.pathname.substring(new URL(root).pathname.length);
  if(key==='regions.json')return;
  event.respondWith(transport.load(key,url.searchParams.get('cacheOnly')==='1')
   .catch(()=>new Response('Offline resource unavailable',{status:404,headers:{'content-type':'text/plain','cache-control':'no-store'}})));
  return;
 }
 if(!version||url.pathname===new URL('offline_asset_manifest.json',scope).pathname)return;
 event.respondWith((async()=>{
  const snapshot=await storedManifest();if(!snapshot)return fetch(request);
  const relative=url.pathname.substring(new URL(scope).pathname.length),path=relative===''?'index.html':decodeURIComponent(relative);
  if(!snapshot.paths.includes(path))return fetch(request);
  const cache=await caches.open(snapshot.name),saved=await cache.match(assetUrl(path));
  if(saved)return saved;
  // Repair eviction only with bytes verified against the active snapshot.
  const asset=snapshot.assets?.find(a=>a.path===path);
  if(asset){try{
   const restored=await verifiedAsset(asset);await cache.put(assetUrl(path),restored.clone());return restored;
  }catch(_){} }
  return new Response('Offline application resource missing. Reopen online.',{status:503,headers:{'content-type':'text/plain'}});
 })());
});
