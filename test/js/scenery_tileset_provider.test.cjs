'use strict';
const test=require('node:test'),assert=require('node:assert/strict');
const C=require('../../web/cesium/index.cjs'),T=require('../../web/features/scenery/scenery_tileset_provider.js'),Loading=require('../../web/features/scene/scene_tile_loading.js');
const center=C.Cartesian3.fromDegrees(13.8,52.4,100),pivot={longitude:13.8,latitude:52.4,ellipsoidHeightM:100};
function document(version='1.1'){return {asset:{version,copyright:'Synthetic CC0-1.0'},geometricError:50,root:{boundingVolume:{sphere:[center.x,center.y,center.z,10]},geometricError:0}};}
const response=doc=>new Response(JSON.stringify(doc),{headers:{'content-type':'application/json'}});
const options={version:'1.1',cachePolicy:'no-store',maximumScreenSpaceError:16,boundingSphere:{center:[center.x,center.y,center.z],radiusM:10}};
for(const version of ['1.0','1.1'])test('pinned Cesium probes georeferencing and version '+version+' without attaching visuals',async()=>{
 const requests=[];const data=await T.probe(C,'https://tiles.example/tileset.json',{fetcher:async(url,config)=>{requests.push({url,config});return response(document(version));}});
 assert.equal(data.version,version);assert.ok(Math.abs(data.anchor.longitude-13.8)<1e-8);assert.ok(Math.abs(data.anchor.latitude-52.4)<1e-8);assert.ok(Math.abs(data.anchor.heightM-100)<1e-5);
 assert.equal(data.copyright,'Synthetic CC0-1.0');assert.equal(requests.length,1);assert.equal(requests[0].config.credentials,'omit');assert.equal(requests[0].config.referrerPolicy,'no-referrer');assert.equal(requests[0].config.cache,'no-store');
 assert.ok(Object.keys(requests[0].config.headers).every(k=>!k.toLowerCase().includes('fpv')));
});
test('HTTPS endpoint validation rejects credentials, fragments and unsafe schemes',()=>{
 for(const value of ['http://tiles.example/root.json','file:///root.json','javascript:alert(1)','https://u:p@tiles.example/root.json','https://tiles.example/root.json#key'])assert.throws(()=>T.safeUrl(value));
 assert.equal(T.safeUrl('https://tiles.example/root.json?key=fixture'),'https://tiles.example/root.json?key=fixture');
});
test('embedded glTF buffers remain local and unsafe inline document types are rejected',async()=>{
 const scope=T.createScope(C,{fetcher:async()=>{throw Error('Must decode locally');}});
 try{const root=scope.resource('https://tiles.example/root.json');const bytes=await root.getDerivedResource({url:'data:application/octet-stream;base64,AQID'}).fetchArrayBuffer();assert.deepEqual(Array.from(new Uint8Array(bytes)),[1,2,3]);
  assert.throws(()=>root.getDerivedResource({url:'data:text/html;base64,PGgxPng8L2gxPg=='}));
 }finally{scope.dispose();}
});
test('Cesium-supported bounding-volume extensions are preserved rather than rewritten',async()=>{
 const doc=document();doc.extensionsRequired=['3DTILES_bounding_volume_S2'];doc.root.boundingVolume={extensions:{'3DTILES_bounding_volume_S2':{token:'89c25',minimumHeight:0,maximumHeight:100}}};
 const meta=await T.probe(C,'https://tiles.example/root.json',{fetcher:async()=>response(doc)});assert.ok(meta.boundingSphere.radiusM>0);assert.equal(meta.version,'1.1');
});
test('1.1 multiple contents, implicit subtrees and antimeridian regions remain intact',async()=>{
 const doc=document();doc.root={boundingVolume:{region:[3,-.2,-3,.2,0,100]},geometricError:10,contents:[{uri:'{level}/{x}/{y}.glb'},{uri:'overlay/{level}/{x}/{y}.glb'}],implicitTiling:{subdivisionScheme:'QUADTREE',subtreeLevels:4,availableLevels:10,subtrees:{uri:'{level}/{x}/{y}.subtree'}}};
 const before=structuredClone(doc);await T.validateDocument(doc,'https://tiles.example/root.json');assert.deepEqual(doc,before);
});
test('malformed transforms, volumes, versions and content URLs fail explicitly',async()=>{
 const changes=[d=>d.asset.version='2.0',d=>delete d.root,d=>d.root.transform=[1,2],d=>d.root.boundingVolume.sphere[3]=-1,d=>d.root.content={uri:'file:///secret'},d=>d.root.contents={},d=>d.root.refine='UNKNOWN',d=>d.root.children=[null]];
 for(const mutate of changes){const doc=document();mutate(doc);await assert.rejects(T.validateDocument(doc,'https://tiles.example/root.json'),e=>['UNSUPPORTED','INVALID_TILESET','INVALID_URL'].includes(e.category));}
});
test('required unsupported extensions are rejected by the pinned Cesium loader',async()=>{
 const doc=document();doc.extensionsRequired=['UNSUPPORTED_fixture_extension'];
 await assert.rejects(T.probe(C,'https://tiles.example/root.json',{fetcher:async()=>response(doc)}),e=>T.describe(e).category==='UNSUPPORTED');
});
test('HTTP and network/CORS errors remain distinct and never expose URL queries',async()=>{
 await assert.rejects(T.probe(C,'https://tiles.example/root.json?key=private',{fetcher:async()=>new Response('',{status:404})}),e=>T.describe(e).category==='HTTP_ERROR');
 const detail=T.describe(new TypeError('Failed to fetch https://tiles.example/root.json?key=private'));
 assert.equal(detail.category,'NETWORK_OR_CORS');assert.ok(!detail.message.includes('private'));assert.equal(T.describe({message:'Request has failed. Status Code: 503'}).category,'HTTP_ERROR');
});
test('scoped resources keep same-origin queries but do not copy secrets to another origin',async()=>{
 const seen=[];const scope=T.createScope(C,{cachePolicy:'provider',fetcher:async(url,config)=>{seen.push({url,config});return new Response('data');}});
 try{
  const root=scope.resource('https://tiles.example/a/root.json?key=private');
  await root.getDerivedResource({url:'child.bin'}).fetchArrayBuffer();
  await root.getDerivedResource({url:'https://cdn.example/child.bin?own=value'}).fetchArrayBuffer();
  assert.match(seen[0].url,/key=private/);assert.ok(!seen[1].url.includes('private'));assert.match(seen[1].url,/own=value/);
  assert.equal(seen[0].config.cache,'default');assert.ok(Object.keys(seen[1].config.headers).every(k=>!k.toLowerCase().includes('fpv')));
 }finally{scope.dispose();}
});
test('cooperative root preparation also avoids cross-origin query inheritance',async()=>{
 const doc=document();doc.root.content={uri:'https://cdn.example/model.glb?own=ok'};
 const fragments=new Map();await Loading.partition(doc,'https://tiles.example/root.json?key=private',{maxNodes:4,makeUrl:value=>{const key='https://local.example/'+fragments.size;fragments.set(key,value);return key;}});
 const wide=document();wide.root.children=Array.from({length:200},(_,i)=>({...document().root,content:{uri:i===0?'https://cdn.example/tile.glb':'same/'+i+'.glb'}}));
 const prepared=await Loading.partition(wide,'https://tiles.example/root.json?key=private',{maxNodes:8,makeUrl:value=>{const key='https://local.example/'+fragments.size;fragments.set(key,value);return key;}});
 const json=JSON.stringify([prepared,...fragments.values()]);assert.ok(!json.includes('cdn.example/tile.glb?key='));assert.ok(json.includes('same/'));
});
test('large root headers use the existing partition registry and release it on destroy',async()=>{
 let loader;const doc=document();doc.root.children=Array.from({length:200},(_,i)=>({...document().root,geometricError:0,content:{uri:'tile/'+i+'.glb'}}));
 const sourceTransform=C.Matrix4.pack(C.Transforms.eastNorthUpToFixedFrame(center),[]);doc.root.transform=sourceTransform;
 const model=await T.load(C,'https://tiles.example/root.json',{cachePolicy:'no-store',maximumScreenSpaceError:20},{fetcher:async()=>response(doc),loaderFactory:c=>(loader=Loading.create(c))});
 assert.ok(loader.status().liveFragments>0);assert.deepEqual(C.Matrix4.pack(model.root.transform,[]),sourceTransform);assert.equal(model.maximumScreenSpaceError,20);model.destroy();assert.equal(loader.status().liveFragments,0);assert.equal(loader.status().liveBytes,0);
});
test('identity corrections preserve source matrices; ENU offsets and rotations compose around the pivot',()=>{
 assert.deepEqual(C.Matrix4.pack(T.correctionMatrix(C,pivot,{}),[]),C.Matrix4.pack(C.Matrix4.IDENTITY,[]));
 const source=C.Matrix4.fromTranslation(new C.Cartesian3(1,2,3));const tileset={modelMatrix:C.Matrix4.clone(source)};
 T.applyCorrection(C,tileset,pivot,{},source);assert.deepEqual(C.Matrix4.pack(tileset.modelMatrix,[]),C.Matrix4.pack(source,[]));
 const d=T.correctionMatrix(C,pivot,{eastM:10,northM:20,upM:3,headingDeg:90,scale:2});
 const moved=C.Matrix4.multiplyByPoint(d,center,new C.Cartesian3()),enu=C.Transforms.eastNorthUpToFixedFrame(center);
 const expected=C.Matrix4.multiplyByPoint(enu,new C.Cartesian3(10,20,3),new C.Cartesian3());assert.ok(C.Cartesian3.distance(moved,expected)<1e-7);
 const p=C.Matrix4.multiplyByPoint(enu,new C.Cartesian3(1,0,0),new C.Cartesian3()),p2=C.Matrix4.multiplyByPoint(d,p,new C.Cartesian3());
 const expected2=C.Matrix4.multiplyByPoint(enu,new C.Cartesian3(10,18,3),new C.Cartesian3());assert.ok(C.Cartesian3.distance(p2,expected2)<1e-7);
});
test('activation measures the distance to coverage, including corrected dateline datasets',()=>{
 assert.equal(T.distance(C,{longitude:13.8,latitude:52.4,height:100},options.boundingSphere,pivot,{}),0);
 assert.ok(T.distance(C,{longitude:14.8,latitude:52.4,height:100},options.boundingSphere,pivot,{})>50000);
 const sphere={center:[...Object.values(C.Cartesian3.fromDegrees(179.9999,0,0))],radiusM:1000};
 assert.equal(T.distance(C,{longitude:-179.9999,latitude:0,height:0},sphere,{longitude:179.9999,latitude:0,ellipsoidHeightM:0},{}),0);
});
test('timeouts abort the underlying Fetch and released scopes cannot issue further requests',async()=>{
 const timers=new Map();let n=0,aborted=false;
 const scope=T.createScope(C,{setTimer:fn=>{timers.set(++n,fn);return n;},clearTimer:id=>timers.delete(id),fetcher:(_url,options)=>new Promise((_resolve,reject)=>{options.signal.addEventListener('abort',()=>{aborted=true;reject(new DOMException('Aborted','AbortError'));});})});
 const resource=scope.resource('https://tiles.example/a.bin');resource.retryAttempts=0;
 const request=resource.fetchArrayBuffer();await new Promise(r=>setImmediate(r));timers.values().next().value();await assert.rejects(request,e=>e.category==='TIMEOUT');assert.equal(aborted,true);
 scope.dispose();await assert.rejects(resource.fetchArrayBuffer(),e=>e.category==='CANCELLED');
});
test('scope cancellation and response limits never turn missing data into a successful tileset',async()=>{
 const abort=new AbortController();abort.abort();await assert.rejects(T.probe(C,'https://tiles.example/root.json',{signal:abort.signal,fetcher:async()=>response(document())}));
 let cancelled=false;const scope=T.createScope(C,{fetcher:async()=>new Response(new ReadableStream({pull(c){c.enqueue(new Uint8Array(8*1024*1024));},cancel(){cancelled=true;}}))});
 try{const r=scope.resource('https://tiles.example/huge.bin');r.retryAttempts=0;await assert.rejects(r.fetchArrayBuffer(),e=>e.category==='RESOURCE_LIMIT');assert.equal(cancelled,true);}finally{scope.dispose();}
});
