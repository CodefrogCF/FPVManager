'use strict';
const test=require('node:test'),assert=require('node:assert/strict');
const C=require('../../web/cesium/index.cjs'),M=require('../../web/features/scenery/scenery_manager.js');
const {gpuTimer}=require('../../web/core/scene_performance.js');
const MiB=1024*1024,origin={latitude:46.7,longitude:8.4,height:100};
const offset=m=>({...origin,latitude:origin.latitude+m/111195});
const flush=()=>new Promise(r=>setImmediate(r));
function scene(id,m=0){const p=offset(m);return {id,name:id,author:'Fixture',license:'CC0',heightDatum:'WGS84 ellipsoid',enabled:true,
 alignment:{...p,ellipsoidHeightM:100,scale:1,rotationDeg:0,opacity:1},heightAlignmentMode:'fixed',physicalCollisionsEnabled:false,
 assets:[{kind:'glb',path:id+'.glb'}],loadRadiusM:1000,unloadRadiusM:1500};}
function fixture(items,options={}){
 let camera=origin,aircraft=null,t=0,route=[];const models=[],credits=[],loaded=[],destroyed=[];
 const viewer={scene:{primitives:{add:m=>models.push(m),remove:m=>{const i=models.indexOf(m);assert.ok(i>=0);models.splice(i,1);m.destroy();}},preUpdate:new C.Event(),requestRender(){}},cesiumWidget:{creditDisplay:{addStaticCredit:c=>credits.push(c),removeStaticCredit:c=>credits.splice(credits.indexOf(c),1)}}};
 const makeModel=url=>({ready:true,show:true,statistics:{geometryByteLength:2*MiB,texturesByteLength:4*MiB,trianglesLength:100},texturesReadyEvent:new C.Event(),destroy(){destroyed.push(url);}});
 const manager=M.create(C,viewer,{fetchCatalog:async()=>({schemaVersion:1,sceneries:items}),position:()=>camera,flightPosition:()=>aircraft,routeLookahead:()=>route,now:()=>t,
 modelFactory:async url=>{loaded.push(url);return makeModel(url);},...options});
 return {manager,models,credits,loaded,destroyed,makeModel,move:m=>{camera=offset(m);},air:m=>{aircraft=m===null?null:offset(m);},route:m=>{route=m.map(offset);},tick:()=>{t+=500;manager.tick(true);},async settle(n=3){for(let i=0;i<n;i++){await flush();this.tick();}}};
}
test('aircraft priority beats catalog order and waiting visual assets recover after memory is released',async()=>{
 const f=fixture([scene('far',-800),scene('near',800)],{streaming:{localBudgetBytes:64*MiB}});f.air(800);
 try{await f.manager.initialize();await f.settle(5);assert.deepEqual(f.loaded,['./assets/scenery/near.glb']);assert.equal(f.manager.snapshot().find(e=>e.id==='far').errorCategory,'LOCAL_BUDGET');
  f.air(null);f.move(-1000);await f.settle(5);assert.deepEqual(f.loaded,['./assets/scenery/near.glb','./assets/scenery/far.glb']);assert.equal(f.models.length,1);assert.equal(f.destroyed.length,1);
 }finally{f.manager.dispose();}
});
test('bounded route lookahead preloads only inside hysteresis band and nearby motion extrapolates',async()=>{
 const f=fixture([scene('ahead',1200),scene('distant',5000)]);
 try{f.route([250,5000]);await f.manager.initialize();await f.settle();assert.deepEqual(f.loaded,['./assets/scenery/ahead.glb']);
  f.route([]);f.move(0);await f.settle();assert.equal(f.models.length,1);f.move(-500);await f.settle();assert.equal(f.models.length,0);
 }finally{f.manager.dispose();}
 const p=M.predictPoint(offset(0),offset(30),1);assert.ok(M.distanceM(p,offset(120))<.1);assert.equal(M.predictPoint(offset(0),offset(500),1),null);
 const anti=M.predictPoint({latitude:0,longitude:179.9995,height:100},{latitude:0,longitude:-179.9999,height:100},1);assert.ok(anti&&anti.longitude>-180&&anti.longitude<-179.99);
});
test('cancelled local factory holds its admission slot until settled and stale output is destroyed',async()=>{
 let finish,calls=0;const f=fixture([scene('a'),scene('b',3000)],{modelFactory:url=>++calls===1?new Promise(r=>finish=r):Promise.resolve(f.makeModel(url))});
 try{await f.manager.initialize();f.move(3000);f.tick();await flush();assert.equal(calls,1);assert.equal(f.manager.performanceSnapshot().localInFlight,1);finish(f.makeModel('late'));await f.settle();assert.equal(calls,2);assert.ok(f.destroyed.includes('late'));assert.equal(f.models.length,1);
 }finally{f.manager.dispose();}
});
test('repeated activation releases primitives, credits, timers and collision data; diagnostics history is bounded',async()=>{
 const item=scene('repeat');Object.assign(item,{physicalCollisionsEnabled:true,collisionAsset:'mesh.fpc',collisionAssets:['mesh.fpc']});
 const mesh={triangleCount:20,byteLength:1024};const f=fixture([item],{collisionFactory:async()=>mesh,diagnosticsEnabled:()=>true});
 try{await f.manager.initialize();for(let i=0;i<140;i++){
  f.move(0);await f.settle();assert.equal(f.models.length,1);assert.equal(f.manager.performanceSnapshot().activeCollisionTriangles,20);
  f.models[0].texturesReadyEvent.raiseEvent();f.move(1200);f.tick();assert.equal(f.models.length,1,'hysteresis');
  f.move(1700);f.tick();const d=f.manager.performanceSnapshot();assert.equal(d.residentModels,0);assert.equal(d.collisionBytes,0);assert.equal(d.localAdmissionBytes,0);assert.equal(f.credits.length,0);
 }
 const d=f.manager.performanceSnapshot();assert.equal(d.loadSamples.length,128);assert.ok(d.loadSamples.every(s=>s.textureReadyMs!==null));assert.equal(f.loaded.length,f.destroyed.length);f.manager.resetPerformance();assert.equal(f.manager.performanceSnapshot().loadSamples.length,0);
 }finally{f.manager.dispose();}
});
test('preset-specific visual assets and tile LOD preserve collision input',async()=>{
 const item=scene('variant');item.visualLods={'variant.glb':{low:{path:'variant_low.glb',estimatedBytes:16*MiB},high:{path:'variant_high.glb',estimatedBytes:32*MiB}}};
 Object.assign(item,{physicalCollisionsEnabled:true,collisionAsset:'mesh.fpc',collisionAssets:['mesh.fpc']});
 for(const preset of ['low','balanced','high']){
  const collisionPaths=[];const f=fixture([item],{streaming:{preset},collisionFactory:async url=>{collisionPaths.push(url);return {triangleCount:10,byteLength:4096};}});
  try{await f.manager.initialize();await f.settle();assert.equal(f.loaded[0],`./assets/scenery/variant${preset==='balanced'?'':'_'+preset}.glb`);assert.deepEqual(collisionPaths,['./assets/scenery/mesh.fpc']);assert.equal(f.manager.performanceSnapshot().activeCollisionTriangles,10);}
  finally{f.manager.dispose();}
 }
 const asset={options:{maximumScreenSpaceError:16,qualityScreenSpaceError:{high:5}}};
 assert.equal(M.qualityOptions(asset,M.streamingOptions({preset:'low'})).maximumScreenSpaceError,32);
 assert.equal(M.qualityOptions(asset,M.streamingOptions({preset:'high'})).maximumScreenSpaceError,5);
 assert.throws(()=>M.streamingOptions({preset:'invalid'}));assert.throws(()=>M.streamingOptions({maxVisualLoads:0}));
 const bad=structuredClone(item);bad.visualLods['variant.glb'].low.path='../escape.glb';assert.throws(()=>M.validate({schemaVersion:1,sceneries:[bad]}));
});
test('GPU timer never reads unready results, bounds queued queries and cleans up on disjoint/stop',()=>{
 let active=null,ready=false,disjoint=false,live=0,read=0;const ms=[];
 const gl={CURRENT_QUERY:1,QUERY_RESULT_AVAILABLE:2,QUERY_RESULT:3,getExtension:()=>({TIME_ELAPSED_EXT:4,GPU_DISJOINT_EXT:5}),
 createQuery(){live++;return {};},deleteQuery(){live--;},getQuery:()=>active,getParameter:()=>disjoint,
 beginQuery(_,q){assert.equal(active,null);active=q;},endQuery(){active=null;},getQueryParameter(q,p){if(p===2)return ready;assert.equal(ready,true);read++;return 3e6;}};
 const timer=gpuTimer(gl,v=>ms.push(v));assert.equal(timer.supported,true);
 for(let i=0;i<20;i++){timer.pre();timer.post();}assert.equal(live,8);assert.equal(read,0);
 ready=true;timer.pre();timer.post();assert.equal(ms.length,8);assert.ok(ms.every(v=>v===3));assert.equal(live,1);
 disjoint=true;timer.pre();assert.equal(live,0);assert.equal(active,null);timer.clear();assert.equal(live,0);
 assert.equal(gpuTimer(null,()=>{}).supported,false);
});
test('managed package LOD uses the verified storage backend and does not change collision resources',async()=>{
 const key=c=>`managed/${c.repeat(64)}.glb`, item=scene('package');
 item.assets=[{kind:'glb',path:key('a'),managed:true,backend:'server',estimatedBytes:4*MiB}];
 item.visualLods={[key('a')]:{low:{path:key('b'),estimatedBytes:2*MiB,backend:'cache'},high:{path:key('c'),estimatedBytes:8*MiB}}};
 Object.assign(item,{physicalCollisionsEnabled:true,collisionAsset:'mesh.fpc',collisionAssets:['mesh.fpc']});
 for(const [preset,expected] of [['low','b'],['balanced','a'],['high','c']]){
  const requests=[], collision=[];
  const f=fixture([item],{streaming:{preset},managedUrl:async asset=>{requests.push(asset);return {url:asset.path,release(){}};},collisionFactory:async url=>{collision.push(url);return {triangleCount:10,byteLength:4096};}});
  try{await f.manager.initialize();await f.settle();assert.equal(requests.length,1);assert.equal(requests[0].path,key(expected));assert.equal(requests[0].backend,'server');assert.deepEqual(collision,['./assets/scenery/mesh.fpc']);}finally{f.manager.dispose();}
 }
 const bad=structuredClone(item);bad.visualLods[key('a')].low.path='other.glb';assert.throws(()=>M.validate({schemaVersion:1,sceneries:[bad]}));
});
