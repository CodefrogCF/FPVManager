const test=require('node:test'),assert=require('node:assert/strict');
const M=require('../../web/offline_maps.js'),C=require('../../web/cesium/index.cjs');
const {createAdapters,defaultImagery}=require('../../web/map_providers.js');
const fs=require('node:fs');
const region={id:'test',name:'test',west:8.39,south:46.69,east:8.41,north:46.71,style:'topographic',imageryLevel:14,terrainLevel:12};
test('the pinned Cesium engine reads an offline real quantized mesh without live availability',async()=>{
 const originalBytes=new Uint8Array(fs.readFileSync('test/fixtures/offline/root.terrain'));
 const binary=M.withoutTerrainMetadata(originalBytes);
 assert.ok(binary.length<originalBytes.length);
 assert.deepEqual(binary.slice(0,100),originalBytes.slice(0,100));
 assert.deepEqual(M.withoutTerrainMetadata(binary),binary);
 assert.throws(()=>M.withoutTerrainMetadata(originalBytes.slice(0,90)),/mesh/);
 const sanitized=M.sanitize('terrain/layer.json',new Uint8Array(fs.readFileSync('test/fixtures/offline/layer.json')));
 const local=JSON.parse(new TextDecoder().decode(M.cachedTerrainMetadata(sanitized.bytes,['terrain/20250101/0/0/0.terrain','terrain/20250101/0/1/0.terrain'])));
 const original=C.Resource._Implementations.loadWithXhr;
 C.Resource._Implementations.loadWithXhr=(url,responseType,method,data,headers,deferred)=>{
  assert.match(url,/cacheOnly=1/);
  if(url.includes('layer.json'))deferred.resolve(JSON.stringify(local));
  else {assert.match(url,/20250101\/0\/0\/0.terrain/);deferred.resolve(binary.buffer.slice(binary.byteOffset,binary.byteOffset+binary.byteLength));}
  return {abort(){}};
 };
 try {
  const provider=await C.CesiumTerrainProvider.fromUrl(new C.Resource({url:'https://fixture.invalid/terrain/',queryParameters:{cacheOnly:'1'}}));
  const data=await provider.requestTileGeometry(0,0,0);
  assert.ok(data instanceof C.QuantizedMeshTerrainData);
  assert.equal(provider.availability.computeMaximumLevelAtPosition(C.Cartographic.fromDegrees(-100,40)),0);
  assert.equal(data.isChildAvailable(0,0,0,0),false);
  const height=data.interpolateHeight(provider.tilingScheme.tileXYToRectangle(0,0,0),C.Math.toRadians(-100),C.Math.toRadians(40));
  assert.ok(Number.isFinite(height));
 } finally {C.Resource._Implementations.loadWithXhr=original;}
});
function setup({noStore=false,defer}={}){
 const root='https://app.test/offline/maps/',rows=new Map();let calls=0,fail=false;
 const cache={async match(key){return rows.get(typeof key==='string'?key:key.url)?.clone();},async put(key,value){rows.set(key,value.clone());},
  async keys(){return [...rows.keys()].map(url=>({url}));},async delete(key){return rows.delete(key);}};
 rows.set(root+'regions.json',new Response(JSON.stringify({revision:1,regions:[region]})));
 const transport=M.createTransport({root,caches:{open:async()=>cache},fetch:async(url,options)=>{
  calls++;assert.equal(options.credentials,'omit');assert.equal(options.redirect,'error');
  assert.ok(['wmts.geo.admin.ch','3d.geo.admin.ch'].includes(new URL(url).hostname));if(fail)throw new Error('offline');
  if(defer)await defer();
  return new Response(new Uint8Array([255,216,255,217]),{headers:{...(noStore?{'cache-control':'no-store'}:{})}});
 }});
 return {transport,cache,root,rows,get calls(){return calls;},set fail(v){fail=v;}};
}
test('only supported official resources can be cached; dated terrain and TMS bounds are preserved',()=>{
 assert.match(M.source('imagery/topographic/14/8573/5773.jpeg'),/^https:\/\/wmts.geo.admin.ch\//);
 assert.equal(M.source('imagery/satellite/0/0/0.jpeg'),null);
 for(const key of ['../secret','https://attacker.invalid','imagery/topographic/4/999/0.jpeg','terrain/19/0/0.terrain'])assert.equal(M.source(key),null);
 assert.equal(M.includes(region,'terrain/20250101/0/0/0.terrain'),true);
 assert.equal(M.includes(region,'terrain/0/1/0.terrain'),true);
 assert.equal(M.includes(region,'imagery/topographic/0/0/0.jpeg'),true);
 const meta={format:'quantized-mesh-1.0',projection:'EPSG:4326',tiles:['20250101/{z}/{x}/{y}.terrain?v={version}'],metadataAvailability:10,parentUrl:'https://attacker.invalid/'};
 const sanitized=JSON.parse(new TextDecoder().decode(M.sanitize('terrain/layer.json',new TextEncoder().encode(JSON.stringify(meta))).bytes));
 assert.deepEqual(sanitized.tiles,['20250101/{z}/{x}/{y}.terrain']);assert.equal(sanitized.metadataAvailability,10);assert.equal(sanitized.parentUrl,undefined);
 assert.match(M.source('terrain/20250101/18/1/1.terrain'),/v1\/20250101\/18\/1\/1.terrain$/);
});
test('offline reads never use the network; failed updates retain the prior cached tile',async()=>{
 const p=setup(),key='imagery/topographic/0/0/0.jpeg';
 await p.transport.load(key);assert.equal(p.calls,1);
 assert.equal((await p.transport.load(key,true)).headers.get('x-fpv-size'),'4');assert.equal(p.calls,1);
 await assert.rejects(p.transport.load('terrain/0/0/0.terrain',true),/missing/);assert.equal(p.calls,1);
 p.fail=true;await assert.rejects(p.transport.load('terrain/0/0/0.terrain'),/offline/);
 assert.equal((await p.transport.load(key,true)).status,200);
});

test('offline terrain availability lists only stored tiles and never claims missing detailed heights',()=>{
 const meta=new TextEncoder().encode(JSON.stringify({format:'quantized-mesh-1.0',projection:'EPSG:4326',tiles:['20250101/{z}/{x}/{y}.terrain'],metadataAvailability:10,extensions:['metadata','octvertexnormals']}));
 const local=JSON.parse(new TextDecoder().decode(M.cachedTerrainMetadata(meta,['terrain/20250101/0/0/0.terrain','terrain/20250101/0/1/0.terrain','terrain/20250101/2/4/3.terrain'])));
 assert.equal(local.metadataAvailability,undefined);assert.equal(local.maxzoom,2);
 assert.deepEqual(local.available[2],[{startX:4,endX:4,startY:3,endY:3}]);
 assert.deepEqual(local.extensions,['octvertexnormals']);
});
test('no-store and cleared-region responses cannot be persisted',async()=>{
 const p=setup({noStore:true});await p.transport.load('imagery/topographic/0/0/0.jpeg');assert.equal(p.rows.size,1);
});
test('clearing a region during a response does not recreate deleted browser tiles',async()=>{
 let entered,release;
 const started=new Promise(r=>entered=r),wait=new Promise(r=>release=r);
 const p=setup({defer:()=>{entered();return wait;}}),pending=p.transport.load('imagery/topographic/0/0/0.jpeg');
 await started;await p.cache.put(p.root+'regions.json',new Response(JSON.stringify({revision:2,regions:[]})));release();
 await pending;assert.equal(p.rows.size,1);
});
test('the browser tile budget prevents unbounded growth without blocking displayed tiles',async()=>{
 const p=setup();p.rows.set(p.root+'imagery/topographic/0/0/0.jpeg',new Response('full',{headers:{'x-fpv-size':String(M.budget)}}));
 const response=await p.transport.load('imagery/topographic/1/1/0.jpeg');
 assert.equal(response.status,200);assert.equal(p.rows.size,2);
});

test('a profile-sized burst queues rather than rejecting the ninth tile; transport stays bounded and deduplicated',async()=>{
 let release,active=0,peak=0;
 const gate=new Promise(r=>release=r);
 const p=setup({defer:async()=>{active++;peak=Math.max(peak,active);await gate;active--;}});
 const jobs=Array.from({length:24},(_,i)=>p.transport.load(`imagery/topographic/6/${i}/0.jpeg`));
 const duplicate=p.transport.load('imagery/topographic/6/0/0.jpeg');
 while(p.calls<8)await new Promise(r=>setImmediate(r));
 assert.equal(p.calls,8);release();
 const replies=await Promise.all([...jobs,duplicate]);
 assert.equal(replies.every(r=>r.status===200),true);
 assert.equal(p.calls,24);assert.equal(peak,8);
});
test('cached provider URLs retain Cesium query flags and custom providers keep their actual attribution',async()=>{
 const fake={...C,UrlTemplateImageryProvider:class{constructor(options){Object.assign(this,options);}},
  GridImageryProvider:class{},
  CesiumTerrainProvider:{fromUrl:async resource=>resource}};
 const adapters=createAdapters(fake,{cacheRoot:'https://app.test/offline/maps/',cacheOnly:true});
 const image=adapters.imagery('topographic',true);
 assert.match(image.url,/offline\/maps\/imagery\/topographic\/.*cacheOnly=1$/);
 const terrain=await adapters.terrain();assert.equal(terrain.getDerivedResource({url:'layer.json'}).queryParameters.cacheOnly,'1');
 assert.equal(terrain.getDerivedResource({url:'20250101/0/0/0.terrain'}).queryParameters.cacheOnly,'1');
 const custom={...defaultImagery.topographic,url:'https://custom.test/tiles/{z}/{x}/{y}.jpeg'};
 const other=createAdapters(fake,{cacheRoot:'https://app.test/offline/maps/',imagery:{topographic:custom}});
 assert.equal(other.imagery('topographic').url,custom.url);
 assert.ok(adapters.imagery('satellite',true) instanceof fake.GridImageryProvider);
});
