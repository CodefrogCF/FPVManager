'use strict';
const test=require('node:test'),assert=require('node:assert/strict');
const C=require('../../web/cesium/index.cjs'),M=require('../../web/features/scenery/scenery_manager.js');
const p={longitude:13.8,latitude:52.4,height:100},center=C.Cartesian3.fromDegrees(p.longitude,p.latitude,p.height);
const flush=()=>new Promise(r=>setImmediate(r));
test('renderer accepts the exact catalog compiled by the Dart provider registry',()=>{
 const catalog=require('../fixtures/scenery/remote_tileset_catalog.json');const [validated]=M.validate(catalog);
 assert.equal(validated.assets[0].kind,'3d-tiles');assert.equal(validated.assets[0].url,'https://provider.example/tileset.json?key=fixture');assert.equal(validated.heightAlignmentMode,'fixed');
});
function item(id='remote') {return {id,name:id,author:'Synthetic provider',sourceUrl:'https://provider.example/terms',license:'CC0-1.0',attribution:'Synthetic fixture',heightDatum:'WGS84 ellipsoid',enabled:true,
 alignment:{...p,ellipsoidHeightM:100,scale:1,rotationDeg:0,opacity:1},heightAlignmentMode:'fixed',physicalCollisionsEnabled:false,loadRadiusM:1000,unloadRadiusM:2000,
 assets:[{kind:'3d-tiles',url:'https://provider.example/'+id+'.json',options:{version:'1.1',maximumScreenSpaceError:16,cachePolicy:'no-store',boundingSphere:{center:[center.x,center.y,center.z],radiusM:100},correction:{}}}]};}
function model(){let destroyed=false;return {modelMatrix:C.Matrix4.clone(C.Matrix4.IDENTITY),root:{transform:C.Matrix4.fromTranslation(new C.Cartesian3(10,20,30))},tileFailed:new C.Event(),tileLoad:new C.Event(),allTilesLoaded:new C.Event(),
 totalMemoryUsageInBytes:1234,destroy(){destroyed=true;},isDestroyed:()=>destroyed};}
function fixture(options={}){
 let camera={...p},aircraft=null,online=true,clock=0;const models=[],credits=[],loaded=[],signals=[],timers=new Map();let timerId=0;
 const viewer={scene:{primitives:{add:m=>models.push(m),remove:m=>{const i=models.indexOf(m);if(i>=0)models.splice(i,1);m.destroy();}},preUpdate:new C.Event(),requestRender(){}},cesiumWidget:{creditDisplay:{addStaticCredit:c=>credits.push(c),removeStaticCredit:c=>credits.splice(credits.indexOf(c),1)}}};
 const manager=M.create(C,viewer,{fetchCatalog:async()=>({schemaVersion:1,sceneries:[item()]}),position:()=>camera,flightPosition:()=>aircraft,canStreamRemote:()=>online,now:()=>clock,
 setTimer:fn=>{timers.set(++timerId,fn);return timerId;},clearTimer:id=>timers.delete(id),
 tilesetFactory:async(url,opts,signal)=>{const m=model();loaded.push({m,url,opts});signals.push(signal);return m;},...options});
 return {manager,models,credits,loaded,signals,timers,setCamera:v=>camera=v,setAircraft:v=>aircraft=v,setOnline:v=>online=v,tick(){clock+=1000;manager.tick(true);}};
}
test('remote provider preserves its root/model transforms, SSE and visible attribution',async()=>{
 const f=fixture();try{await f.manager.initialize();await flush();f.tick();
  assert.equal(f.manager.snapshot()[0].state,'ready');assert.equal(f.loaded[0].opts.maximumScreenSpaceError,16);
  assert.ok(C.Matrix4.equals(f.models[0].modelMatrix,C.Matrix4.IDENTITY));assert.ok(C.Matrix4.equals(f.models[0].root.transform,C.Matrix4.fromTranslation(new C.Cartesian3(10,20,30))));
  assert.equal(f.credits.length,1);assert.match(f.credits[0].html,/Synthetic fixture/);assert.equal(f.manager.visualOnlyModels()[0],f.models[0]);
  assert.equal(f.manager.snapshot()[0].remoteBytes,1234);
 }finally{f.manager.dispose();}assert.equal(f.credits.length,0);
});
test('dataset coverage and aircraft location prevent camera-only flight unloads',async()=>{
 const f=fixture();try{f.setCamera({longitude:0,latitude:0,height:100});f.setAircraft(p);await f.manager.initialize();await flush();f.tick();assert.equal(f.models.length,1);
  f.setAircraft({longitude:0,latitude:0,height:100});f.tick();assert.equal(f.models.length,0);assert.equal(f.signals[0].aborted,true);
  f.setCamera(p);f.tick();await flush();f.tick();assert.equal(f.models.length,1);assert.equal(f.loaded.length,2);
 }finally{f.manager.dispose();}
});
test('loaded provider bounds take precedence over older preflight coverage',async()=>{
 const remote=model();remote.boundingSphere=new C.BoundingSphere(C.Cartesian3.fromDegrees(14.8,52.4,100),1000);
 const f=fixture({tilesetFactory:async()=>remote});
 try{await f.manager.initialize();await flush();f.setCamera({longitude:14.8,latitude:52.4,height:100});f.tick();assert.equal(f.models.length,1);assert.equal(f.manager.snapshot()[0].state,'ready');}
 finally{f.manager.dispose();}
});
test('offline transitions abort external loads and recover online without touching local scenes',async()=>{
 const local={...item('local'),assets:[{kind:'glb',path:'synthetic.glb'}]};const f=fixture({fetchCatalog:async()=>({schemaVersion:1,sceneries:[item(),local]}),modelFactory:async()=>({ready:true,destroy(){}})});
 try{await f.manager.initialize();await flush();f.tick();assert.equal(f.models.length,2);f.setOnline(false);f.tick();assert.equal(f.models.length,1);
  const status=f.manager.snapshot();assert.equal(status.find(x=>x.id==='remote').errorCategory,'OFFLINE');assert.equal(status.find(x=>x.id==='local').state,'ready');
  f.setOnline(true);f.tick();await flush();f.tick();assert.equal(f.models.length,2);
 }finally{f.manager.dispose();}
});
test('a slow or unavailable external header cannot starve bundled/managed scenery',async()=>{
 let reject;const pending=new Promise((_resolve,r)=>reject=r),local={...item('local'),assets:[{kind:'glb',path:'synthetic.glb'}]};
 const f=fixture({fetchCatalog:async()=>({schemaVersion:1,sceneries:[item(),local]}),tilesetFactory:()=>pending,modelFactory:async()=>({ready:true,destroy(){}})});
 try{await f.manager.initialize();await flush();f.tick();assert.equal(f.manager.snapshot().find(x=>x.id==='local').state,'ready');assert.equal(f.models.length,1);
  reject(Object.assign(Error('HTTP 404'),{statusCode:404}));await flush();assert.equal(f.manager.snapshot().find(x=>x.id==='remote').state,'error');assert.equal(f.models.length,1);
 }finally{f.manager.dispose();}
});
test('late completions cannot resurrect a removed, disabled or replaced provider',async()=>{
 let finish,signal;const pending=new Promise(r=>finish=r),late=model();const f=fixture({tilesetFactory:(_url,_opts,s)=>{signal=s;return pending;}});
 await f.manager.initialize();f.manager.replaceCatalog({schemaVersion:1,sceneries:[],unavailable:[]});assert.equal(signal.aborted,true);finish(late);await flush();assert.equal(late.isDestroyed(),true);assert.equal(f.models.length,0);f.manager.dispose();
});
test('tile failures keep already loaded geometry and expose degraded status; successful loads recover',async()=>{
 const f=fixture();try{await f.manager.initialize();await flush();f.tick();const m=f.models[0];
  m.tileFailed.raiseEvent({url:'https://provider.example/tile?key=private',message:'Request has failed. Status Code: 503'});
  let status=f.manager.snapshot()[0];assert.equal(status.state,'ready');assert.equal(status.streamingState,'degraded');assert.equal(status.tileErrorCategory,'HTTP_ERROR');assert.ok(!status.tileError.includes('private'));assert.equal(f.models.length,1);
  m.tileLoad.raiseEvent({});m.allTilesLoaded.raiseEvent();status=f.manager.snapshot()[0];assert.equal(status.streamingState,'ready');assert.equal(status.tileError,null);assert.equal(status.tileFailures,1);
 }finally{f.manager.dispose();}
});
test('load timeouts release request slots and allow an explicit retry',async()=>{
 let finish;const gate=new Promise(r=>finish=r),late=model();let calls=0,signal;const f=fixture({tilesetFactory:(_u,_o,s)=>{signal=s;return ++calls===1?gate:Promise.resolve(model());}});
 try{await f.manager.initialize();f.timers.values().next().value();assert.equal(signal.aborted,true);assert.equal(f.manager.snapshot()[0].state,'error');
  f.manager.retry('remote');await flush();f.tick();assert.equal(f.models.length,1);finish(late);await flush();assert.equal(late.isDestroyed(),true);assert.equal(f.models.length,1);
 }finally{f.manager.dispose();}
});
test('remote cache targets are shared and nearby capacity remains bounded',async()=>{
 const f=fixture({fetchCatalog:async()=>({schemaVersion:1,sceneries:Array.from({length:5},(_,i)=>item('remote-'+i))})});
 try{await f.manager.initialize();for(let i=0;i<10;i++){await flush();f.tick();}assert.equal(f.models.length,4);
  assert.equal(f.models.reduce((n,m)=>n+m.cacheBytes,0),128*1024*1024);assert.equal(f.manager.snapshot().find(x=>x.id==='remote-4').errorCategory,'RESOURCE_LIMIT');
  f.manager.setEnabled('remote-0',false);for(let i=0;i<3;i++){await flush();f.tick();}assert.equal(f.models.length,4);assert.equal(f.manager.snapshot().find(x=>x.id==='remote-4').state,'ready');
 }finally{f.manager.dispose();}
});
test('obsolete provider probes are cancelled and cannot publish new metadata',async()=>{
 const jobs=[];const f=fixture({probeTileset:(_url,{signal})=>new Promise((resolve,reject)=>{jobs.push({resolve,signal});signal.addEventListener('abort',()=>reject(new DOMException('Aborted','AbortError')));})});
 try{const a=f.manager.inspectTileset('https://provider.example/a.json','no-store');const rejected=assert.rejects(a,/CANCELLED/);
  const b=f.manager.inspectTileset('https://provider.example/b.json','no-store');await rejected;assert.equal(jobs[0].signal.aborted,true);jobs[1].resolve({version:'1.1'});assert.deepEqual(await b,{version:'1.1'});
 }finally{f.manager.dispose();}
});
