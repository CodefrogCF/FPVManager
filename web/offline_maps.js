(function(root,factory){if(typeof module==='object'&&module.exports)module.exports=factory();else root.FPVOfflineMaps=factory();})(typeof globalThis!=='undefined'?globalThis:this,function(){
 'use strict';
 const budget=256*1024*1024,cacheName='fpvmanager-offline-maps-v1';
 function source(key){
  if(key==='terrain/layer.json')return 'https://3d.geo.admin.ch/ch.swisstopo.terrain.3d/v1/layer.json';
  let m=key.match(/^terrain\/(?:(20[0-9]{6})\/)?(\d{1,2})\/(\d{1,7})\/(\d{1,7})\.terrain$/);
  if(m){const [,date,z,x,y]=m;if(+z>18||+x>=2*2**+z||+y>=2**+z)return null;
   return `https://3d.geo.admin.ch/ch.swisstopo.terrain.3d/v1/${date?date+'/':''}${z}/${x}/${y}.terrain`;}
  m=key.match(/^imagery\/(topographic|relief)\/(\d{1,2})\/(\d{1,7})\/(\d{1,7})\.(jpeg|png)$/);
  if(!m)return null;
  const [,style,z,x,y,ext]=m,relief=style==='relief';
  if(+z>19||+x>=2**+z||+y>=2**+z||ext!==(relief?'png':'jpeg'))return null;
  return `https://wmts.geo.admin.ch/1.0.0/${relief?'ch.swisstopo.swissalti3d-reliefschattierung':'ch.swisstopo.pixelkarte-farbe'}/default/current/3857/${z}/${x}/${y}.${ext}`;
 }
 function includes(region,key){
  if(key==='terrain/layer.json'||key==='terrain/0/0/0.terrain')return true;
  const parts=key.split('/'),terrain=parts[0]==='terrain';
  if(terrain&&parts.length===5&&/^20[0-9]{6}$/.test(parts[1]))parts.splice(1,1);
  if(terrain&&parts.join('/')==='terrain/0/0/0.terrain')return true;
  if(terrain&&parts.length!==4)return false;
  if(!terrain&&(parts.length!==5||parts[1]!==region.style))return false;
  const z=Number(parts[terrain?1:2]),x=Number(parts[terrain?2:3]),y=Number(parts.at(-1).split('.')[0]);
  if(z>(terrain?region.terrainLevel:region.imageryLevel))return false;
  const n=2**z,tileX=lon=>Math.floor((lon+180)/360*(terrain?2*n:n)),
   tileY=lat=>terrain?Math.floor((lat+90)/180*n):Math.floor((1-Math.log(Math.tan(lat*Math.PI/180)+1/Math.cos(lat*Math.PI/180))/Math.PI)/2*n);
  return x>=tileX(region.west)&&x<=tileX(region.east)&&y>=Math.min(tileY(region.south),tileY(region.north))&&y<=Math.max(tileY(region.south),tileY(region.north));
 }
 async function boundedBytes(response,max=4*1024*1024){
  if(!response.ok||response.type==='opaque')throw new Error('Map resource unavailable');
  const reader=response.body.getReader(),parts=[];let size=0;
  try{while(true){const {done,value}=await reader.read();if(done)break;if((size+=value.byteLength)>max)throw new Error('Map resource too large');parts.push(value);}}
  finally{await reader.cancel().catch(()=>{});}
  const bytes=new Uint8Array(size);let offset=0;for(const part of parts){bytes.set(part,offset);offset+=part.length;}return bytes;
 }
 function sanitize(key,bytes){
  if(key.endsWith('.json')){
   if(bytes.length>1024*1024)throw new Error('Terrain metadata too large');
   const meta=JSON.parse(new TextDecoder('utf-8',{fatal:true}).decode(bytes));
   if(meta.format!=='quantized-mesh-1.0'||meta.projection!=='EPSG:4326')throw new Error('Unsupported terrain metadata');
   if(!Array.isArray(meta.tiles)||meta.tiles.length!==1||typeof meta.tiles[0]!=='string'||
    !/^(20[0-9]{6}\/)?\{z\}\/\{x\}\/\{y\}\.terrain(\?v=\{version\})?$/.test(meta.tiles[0]))throw new Error('Unsupported terrain template');
   delete meta.parentUrl;meta.tiles=[meta.tiles[0].split('?')[0]];
   return {bytes:new TextEncoder().encode(JSON.stringify(meta)),mime:'application/json'};
  }
  const png=key.endsWith('.png'),jpeg=key.endsWith('.jpeg');
  if(png&&(bytes.length<8||bytes[0]!==137||bytes[1]!==80||bytes[2]!==78||bytes[3]!==71)||
   jpeg&&(bytes.length<4||bytes[0]!==255||bytes[1]!==216)||!png&&!jpeg&&bytes.length<88)throw new Error('Invalid map resource');
  return {bytes,mime:png?'image/png':jpeg?'image/jpeg':'application/octet-stream'};
 }
 function createTransport({caches,fetch,root,Response:Reply=Response,now=()=>new Date()}){
  const pending=new Map(),downloadQueue=[];let activeDownloads=0,writes=Promise.resolve(),usageRevision=null,usedBytes=0;
  async function acquire(){if(activeDownloads<8){activeDownloads++;return;}await new Promise(resolve=>downloadQueue.push(resolve));}
  function release(){if(downloadQueue.length)downloadQueue.shift()();else activeDownloads--;}
  async function config(cache){const response=await cache.match(root+'regions.json');return response?response.json():{revision:0,regions:[]};}
  async function load(key,cacheOnly=false){
   const remote=source(key);if(!remote)throw new Error('Unsupported map source');
   const cache=await caches.open(cacheName+':'+root),url=root+key,old=await cache.match(url);
   if(old){
    if(cacheOnly&&key==='terrain/layer.json'){
     const data=cachedTerrainMetadata(new Uint8Array(await old.arrayBuffer()),(await cache.keys()).map(r=>r.url.substring(root.length)));
     return new Reply(data,{headers:old.headers});
    }
    if(cacheOnly&&key.endsWith('.terrain'))return new Reply(withoutTerrainMetadata(new Uint8Array(await old.arrayBuffer())),{headers:old.headers});
    return old;
   }
   if(cacheOnly)throw new Error('Offline map resource missing');
   const original=await config(cache);
   await acquire();
   const controller=new AbortController(),timer=setTimeout(()=>controller.abort(),12000);
   let data,noStore;
   try{const response=await fetch(remote,{credentials:'omit',redirect:'error',signal:controller.signal,
    headers:key.startsWith('terrain/')&&!key.endsWith('.json')?{Accept:'application/vnd.quantized-mesh;extensions=metadata,application/octet-stream;q=0.9'}:{}});
    noStore=/no-store|private/i.test(response.headers.get('cache-control')??'');data=sanitize(key,await boundedBytes(response));}
   finally{clearTimeout(timer);release();}
   const reply=new Reply(data.bytes,{headers:{'content-type':data.mime,'cache-control':'no-store','x-fpv-size':String(data.bytes.length),'x-fpv-fetched-at':now().toISOString()}});
   if(!noStore&&original.regions.some(r=>includes(r,key))){
    const write=async()=>{
     const current=await config(cache);if(current.revision!==original.revision)return;
     // Recount once after region edits or a worker restart, not for each tile.
     if(usageRevision!==current.revision){
      usedBytes=0;
      for(const request of await cache.keys())usedBytes+=Number((await cache.match(request))?.headers.get('x-fpv-size')??0);
      usageRevision=current.revision;
     }
     if(usedBytes+data.bytes.length<=budget){
      await cache.put(url,reply.clone());
      usedBytes+=data.bytes.length;
      if(!(await config(cache)).regions.some(r=>includes(r,key)))await cache.delete(url);
     }
    };
    writes=writes.then(write,write);await writes.catch(()=>{});
   }
   return reply;
  }
  return {load(key,cacheOnly=false){
   const id=`${cacheOnly}:${key}`;if(pending.has(id))return pending.get(id).then(r=>r.clone());
   if(pending.size>=256)return Promise.reject(new Error('Map request queue is full'));
   const promise=load(key,cacheOnly).finally(()=>pending.delete(id));pending.set(id,promise);return promise.then(r=>r.clone());
  }};
 }
 function cachedTerrainMetadata(bytes,keys){
  const meta=JSON.parse(new TextDecoder().decode(bytes)),date=meta.tiles[0].match(/^(20[0-9]{6})\//)?.[1],levels=new Map();
  for(const key of keys){const m=key.match(/^terrain\/(?:(20[0-9]{6})\/)?(\d{1,2})\/(\d{1,7})\/(\d{1,7})\.terrain$/);
   if(!m||m[1]!==date||+m[2]>18)continue;
   const z=+m[2],x=+m[3],y=+m[4];if(!levels.has(z))levels.set(z,[]);
   levels.get(z).push({startX:x,endX:x,startY:y,endY:y});
  }
  const max=Math.max(0,...levels.keys());delete meta.metadataAvailability;
  meta.available=Array.from({length:max+1},(_,z)=>levels.get(z)??[]);meta.maxzoom=max;
  meta.extensions=(meta.extensions??[]).filter(e=>e!=='metadata');
  return new TextEncoder().encode(JSON.stringify(meta));
 }
 // Quantized Mesh extension 4 advertises live descendants. Its geometry and
 // every other extension stay byte-identical; cached availability lives in JSON.
 function withoutTerrainMetadata(bytes){
  const view=new DataView(bytes.buffer,bytes.byteOffset,bytes.byteLength);
  let offset=88;
  function u32(){if(offset+4>bytes.length)throw new Error('Truncated quantized mesh');const n=view.getUint32(offset,true);offset+=4;return n;}
  const vertices=u32(),width=vertices>65536?4:2;
  offset+=vertices*6;offset=Math.ceil(offset/width)*width;
  const triangles=u32();offset+=triangles*3*width;
  for(let i=0;i<4;i++){const count=u32();offset+=count*width;}
  if(offset>bytes.length)throw new Error('Truncated quantized mesh');
  const parts=[bytes.subarray(0,offset)];let removed=false;
  while(offset<bytes.length){
   const start=offset,id=bytes[offset++],length=u32();offset+=length;
   if(offset>bytes.length)throw new Error('Invalid quantized mesh extension');
   if(id===4)removed=true;else parts.push(bytes.subarray(start,offset));
  }
  if(!removed)return bytes;
  const result=new Uint8Array(parts.reduce((n,p)=>n+p.length,0));let out=0;
  for(const part of parts){result.set(part,out);out+=part.length;}return result;
 }
 return {source,includes,boundedBytes,sanitize,cachedTerrainMetadata,withoutTerrainMetadata,createTransport,cacheName,budget};
});
