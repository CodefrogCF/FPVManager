'use strict';
const test=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),crypto=require('node:crypto');
const C=require('../../web/cesium/index.cjs'),Collision=require('../../web/features/scenery/scenery_collision.js'),Manager=require('../../web/features/scenery/scenery_manager.js'),Maths=require('../../web/features/scenery/scenery_editor_math.js');
const file=fs.readFileSync('test/fixtures/scenery/collision_room.fpc'),buffer=()=>file.buffer.slice(file.byteOffset,file.byteOffset+file.length),mesh=Collision.parse(buffer()),key=crypto.createHash('sha256').update(file).digest('hex')+'.fpc';
const pose={longitude:13.8,latitude:52.4,ellipsoidHeightM:100,rotationDeg:0,pitchDeg:0,rollDeg:0,scale:1,opacity:1};
const geo=p=>{const g=Maths.geographic(C,Maths.point(C,pose,{x:p[0],y:p[1],z:p[2]}));return {longitude:g.longitude,latitude:g.latitude,height:g.ellipsoidHeightM};};
const flush=()=>new Promise(r=>setImmediate(r));
function item(id='custom'){return {id,name:id,author:'FPVManager tests',license:'CC0',enabled:true,heightDatum:'WGS84 ellipsoid',alignment:pose,heightAlignmentMode:'fixed',
 physicalCollisionsEnabled:true,collisionIndependent:true,collisionAsset:'managed/'+key,collisionAssets:['managed/'+key],collisionResources:[{path:'managed/'+key,managed:true,backend:'server',metadata:{localBounds:[0,-15,0,20,15,6],byteLength:file.length}}],
 assets:[{kind:'glb',path:'synthetic.glb'}],loadRadiusM:1000,unloadRadiusM:2000};}
function fixture(extra={}){const models=[],timers=new Map();let timer=0;const viewer={scene:{primitives:{add:m=>{models.push(m);return m;},remove:m=>{models.splice(models.indexOf(m),1);m.destroy?.();}},preUpdate:new C.Event(),requestRender(){}},cesiumWidget:{creditDisplay:{addStaticCredit(){},removeStaticCredit(){}}}};
 const manager=Manager.create(C,viewer,{fetchCatalog:async()=>({schemaVersion:1,sceneries:[item()]}),position:()=>geo([2,0,2]),modelFactory:async()=>({ready:true,errorEvent:new C.Event(),destroy(){}}),collisionFactory:async()=>Collision.parse(buffer()),setTimer:(fn,ms)=>{timers.set(++timer,{fn,ms});return timer;},clearTimer:id=>timers.delete(id),...extra});return {manager,models,timers};}
test('Dart-generated FPC preserves windows, doors, floors, ceilings, columns, pipes and beams',()=>{
 assert.equal(mesh.triangleCount,66);assert.equal(Collision.sweep(mesh,[5,5,1],[5,5,5],.25),null,'hollow pipe bore');
 for(const [p,q]of [[[-10,0,2],[10,0,2]],[[-10,9,2],[10,9,2]]])assert.equal(Collision.sweep(mesh,p,q,.25),null,'open passage');
 for(const [p,q]of [[[-10,-5,2],[10,-5,2]],[[2,0,2],[2,0,-2]],[[2,0,2],[2,0,9]],[[6,6,2],[10,6,2]],[[3,5,2],[7,5,2]],[[10,-8,3.2],[10,-4,3.2]]])assert.ok(Collision.sweep(mesh,p,q,.25),'modeled structural surface');
});
test('front/back winding is explicit and double-sided thin surfaces stop high-speed sweeps',()=>{
 assert.ok(Collision.sweep(mesh,[10,-5,2],[-10,-5,2],.25,'front'));assert.equal(Collision.sweep(mesh,[-10,-5,2],[10,-5,2],.25,'front'),null);
 assert.ok(Collision.sweep(mesh,[-10,-5,2],[10,-5,2],.25,'back'));assert.equal(Collision.sweep(mesh,[10,-5,2],[-10,-5,2],.25,'back'),null);
 const hit=Collision.sweep(mesh,[-100,-5,2],[10,-5,2],.25);assert.ok(hit&&-100+110*hit.fraction<=-.245);
});
test('balanced BVH prunes dense geometry without closing gaps or changing hits',()=>{
 const bytes=fs.readFileSync('test/fixtures/scenery/collision_grid.fpc'),m=Collision.parse(bytes.buffer.slice(bytes.byteOffset,bytes.byteOffset+bytes.length)),stats={};
 const hit=Collision.sweep(m,[-5,35.3,35.3],[5,35.3,35.3],.25,'double',stats);assert.ok(hit);assert.ok(stats.triangles<100,m.triangleCount+' triangles must be spatially pruned');assert.ok(stats.nodes<m.nodeCount);
});
test('physical geometry is ready before delayed visuals and survives texture/LOD failure and opacity',async()=>{
 let upload;const gate=new Promise(r=>upload=r),f=fixture({modelFactory:()=>gate});try{await f.manager.initialize();await flush();assert.equal(f.manager.snapshot()[0].collisionReady,true);assert.equal(f.manager.snapshot()[0].state,'loading');assert.ok(f.manager.collision(geo([-10,-5,2]),geo([10,-5,2])));
  const visual={ready:true,errorEvent:new C.Event(),destroy(){}};upload(visual);await flush();f.manager.tick(true);visual.errorEvent.raiseEvent(Error('Synthetic texture failure'));assert.equal(f.manager.snapshot()[0].collisionReady,true);assert.equal(f.models.length,0);assert.equal(f.manager.snapshot()[0].state,'error');
  f.manager.beginAlignment('custom');f.manager.previewAlignment('custom',{...pose,opacity:.2},[]);assert.equal(f.manager.snapshot()[0].collisionReady,true);f.manager.endAlignment('custom');
 }finally{f.manager.dispose();}
});
test('missing geometry pauses only sweeps through its declared region; recovery restores real gaps',async()=>{
 let complete;const f=fixture({collisionFactory:()=>new Promise(r=>complete=r)});try{await f.manager.initialize();await flush();assert.equal(f.manager.collisionAvailability(geo([-10,0,2]),geo([10,0,2])).ready,false);assert.equal(f.manager.collision(geo([-10,0,2]),geo([10,0,2])),false);
  assert.equal(f.manager.collisionAvailability(geo([-30,0,2]),geo([-20,0,2])).ready,true);complete(Collision.parse(buffer()));await flush();assert.equal(f.manager.collisionAvailability(geo([-10,0,2]),geo([10,0,2])).ready,true);assert.equal(f.manager.collision(geo([-10,0,2]),geo([10,0,2])),false);
 }finally{f.manager.dispose();}
});
test('collision timeout releases its slot, rejects late results and supports explicit retry',async()=>{
 let late,calls=0;const f=fixture({collisionFactory:()=>++calls===1?new Promise(r=>late=r):Promise.resolve(Collision.parse(buffer()))});try{await f.manager.initialize();await flush();const pending=[...f.timers.values()].find(t=>t.ms===60000);pending.fn();assert.equal(f.manager.snapshot()[0].collisionState,'error');assert.equal(f.manager.collisionAvailability(geo([-10,0,2]),geo([10,0,2])).ready,false);
  f.manager.retry('custom');await flush();await flush();f.manager.tick(true);assert.equal(f.manager.snapshot()[0].collisionReady,true);late(Collision.parse(buffer()));await flush();assert.equal(f.manager.snapshot()[0].collisionReady,true);
 }finally{f.manager.dispose();}
});
test('concurrent physical loads are single flight and queued scenes progress independently of visuals',async()=>{
 const pending=[];let active=0,max=0;const f=fixture({fetchCatalog:async()=>({schemaVersion:1,sceneries:[item('a'),item('b'),item('c')]}),collisionFactory:()=>{active++;max=Math.max(max,active);return new Promise(r=>pending.push(()=>{active--;r(Collision.parse(buffer()));}));}});
 try{await f.manager.initialize();await flush();for(let i=0;i<3;i++){f.manager.tick(true);await flush();assert.equal(pending.length,i+1);pending[i]();await flush();}assert.equal(max,1);assert.ok(f.manager.snapshot().every(x=>x.collisionReady));}finally{f.manager.dispose();}
});
test('both physics models pause unavailable geometry without inventing collision/failsafe and recover',async()=>{
 const {createSimulator}=require('../../web/features/flight/free_flight.js');for(const physicsModel of ['advanced','legacy']){let ready=false;const s=createSimulator({sampleHeight:async()=>0,renderedHeight:()=>0,captureCamera:()=>({heading:0}),restoreCamera(){},applyPose(){},isTerrainReady:()=>true,onState(){},collisionAvailability:()=>({ready,message:'Synthetic collision loading'})});
  await s.start({longitude:13.8,latitude:52.4,agl:50,flightMode:'acro',physicsModel},new AbortController().signal);try{const start=s.status();s.flightInput({throttle:0});for(let i=0;i<60;i++)s.tick(1/60);const held=s.status();assert.equal(held.height,start.height);assert.equal(held.lastCollision,null);assert.equal(held.failsafe.active,false);assert.match(held.reason,/geometry unavailable/);ready=true;for(let i=0;i<60;i++)s.tick(1/60);assert.ok(s.status().height<start.height);}finally{s.stop();}}
});
test('imported roof collision uses fixed physics steps across 30/60/120 rendered FPS',async()=>{
 const {createSimulator}=require('../../web/features/flight/free_flight.js'),results=[];for(const fps of [30,60,120]){const frame={scale:1,local:p=>[2,0,p.height-100],normal:n=>n?{east:n[0],north:n[1],up:n[2]}:null};const s=createSimulator({sampleHeight:async()=>0,renderedHeight:()=>0,captureCamera:()=>({heading:0}),restoreCamera(){},applyPose(){},isTerrainReady:()=>true,onState(){},modeledCollision:(a,b)=>Collision.contact(mesh,frame,a,b)});
  await s.start({longitude:13.8,latitude:52.4,agl:110,flightMode:'acro',physicsModel:'advanced'},new AbortController().signal);try{s.flightInput({throttle:0});for(let i=0;i<fps*3;i++)s.tick(1/fps);assert.ok(s.status().height>=106.249);results.push(s.status().height);}finally{s.stop();}}
 for(const height of results)assert.ok(Math.abs(height-results[0])<1e-6);
});
test('Legacy custom-mesh contact uses time of impact consistently across render rates',async()=>{
 const {createSimulator}=require('../../web/features/flight/free_flight.js'),heights=[];
 for(const fps of [30,60,120]){const f=fixture();await f.manager.initialize();await flush();await flush();f.manager.tick(true);
  const start=geo([2,0,0]),s=createSimulator({sampleHeight:async()=>0,renderedHeight:()=>0,captureCamera:()=>({heading:0}),restoreCamera(){},applyPose(){},isTerrainReady:()=>true,onState(){},modeledCollision:(a,b)=>f.manager.collision(a,b),collisionAvailability:(a,b)=>f.manager.collisionAvailability(a,b)});
  await s.start({longitude:start.longitude,latitude:start.latitude,agl:110,flightMode:'acro',physicsModel:'legacy'},new AbortController().signal);
  try{s.flightInput({throttle:0});for(let i=0;i<3*fps;i++)s.tick(1/fps);const h=s.status().height;assert.ok(h>=106.249&&h<106.28,String(h));heights.push(h);}finally{s.stop();f.manager.dispose();}
 }
 // Legacy keeps its variable integration; contact remains within the existing 1 cm sweep backoff.
 for(const h of heights)assert.ok(Math.abs(h-heights[0])<=.0101,JSON.stringify(heights));
});
test('unavailable providers retain collision protection across region boundaries and the antimeridian',async()=>{
 const f=fixture({fetchCatalog:async()=>({schemaVersion:1,sceneries:[]})});try{await f.manager.initialize();
  for(const region of [{west:179.9,east:-179.9,south:51,north:53},{west:-180,east:180,south:51,north:53}]){
   f.manager.replaceCatalog({schemaVersion:1,sceneries:[],unavailable:[{id:'unavailable',name:'Unavailable',enabled:true,message:'Synthetic provider unavailable',safetyRegion:region}]});
   assert.equal(f.manager.collisionAvailability({longitude:179.8,latitude:52,height:100},{longitude:-179.8,latitude:52,height:100}).ready,false);
   assert.equal(f.manager.collisionAvailability({longitude:179.8,latitude:50,height:100},{longitude:-179.8,latitude:50,height:100}).ready,true);
  }
 }finally{f.manager.dispose();}
});
test('malformed worker replies and transfer errors reject without leaking a request slot',async()=>{
 const vm=require('node:vm'),source=fs.readFileSync('web/features/scenery/scenery_collision.js','utf8');
 for(const transferError of [false,true]){let live=0;class Worker{constructor(){live++;}postMessage(){if(transferError)throw Error('Synthetic transfer failure');setImmediate(()=>this.onmessage({data:{buffer:new ArrayBuffer(16)}}));}terminate(){live--;}}
  const sandbox={Worker,document:{currentScript:{src:'https://app.example/features/scenery/scenery_collision.js'}},URL,ArrayBuffer,DataView,Float32Array,Uint32Array,Int32Array,DOMException,Promise,Error};sandbox.globalThis=sandbox;vm.runInNewContext(source,sandbox);
  await assert.rejects(sandbox.FPVSceneryCollision.parseAsync(buffer()),transferError?/transfer failure/:/worker result/);assert.equal(live,0);
 }
});
test('RF BVH sees walls and floors in both directions but not real openings',()=>{
 const trace=(a,b,f=5800,r=0)=>Collision.rfTrace(mesh,a,b,1,f,r,{nodes:8192,triangles:4096});
 for(const [a,b] of [[[-10,-5,2],[10,-5,2]],[[2,0,-2],[2,0,9]],[[10,-8,3.2],[10,-4,3.2]]]){
  const forward=trace(a,b),reverse=trace(b,a);assert.ok(forward.complete&&forward.hits.length>0);assert.equal(forward.hits.length,reverse.hits.length);
 }
 assert.ok(trace([2,0,-2],[2,0,9]).hits.length>=2);
 assert.equal(trace([-10,0,2],[10,0,2]).hits.length,0);
 const exhausted=Collision.rfTrace(mesh,[2,0,-2],[2,0,9],1,868,.6,{nodes:1,triangles:1});assert.equal(exhausted.complete,false);
});
test('distant root box is a verified miss even after a scheduler stall, relevant geometry stays uncertain',()=>{
 const expired={nodes:8192,triangles:4096,deadline:performance.now()-1};
 const clear=Collision.rfTrace(mesh,[10000,0,2],[10010,0,2],1,868,.6,expired);
 assert.deepEqual(clear,{hits:[],fresnel:false,complete:true});
 assert.equal(expired.nodes,8192);
 const near=Collision.rfTrace(mesh,[2,0,-2],[2,0,9],1,868,.6,expired);
 assert.equal(near.complete,false);
});
test('RF material defaults, frequency, explicit thickness and validation are independent of physics',()=>{
 const loss=(material,f=5800,extra={},cos=1)=>Collision.rfLoss(Collision.normalizeRf({material,...extra}),f,cos);
 assert.ok(loss('metal')>loss('reinforcedConcrete'));assert.ok(loss('reinforcedConcrete')>loss('glass'));
 assert.ok(loss('concrete',5800)>loss('concrete',868));assert.ok(loss('brick',5800,{thicknessM:.3},.5)>loss('brick',5800,{thicknessM:.3}));
 assert.equal(loss('wood',868,{surfaceLossDb:4,thicknessM:.2,lossDbPerM:10}),6);
 assert.throws(()=>Collision.normalizeRf({material:'magic'}));assert.throws(()=>Collision.normalizeRf({thicknessM:-1}));
});
test('Fresnel envelope identifies a near miss with a wider low frequency zone',()=>{
 const panel={bounds:[0,1,-5,0,5,5],children:[-1,2],vertices:[0,1,-5,0,5,-5,0,5,5,0,1,5],indices:[0,1,2,0,2,3]};
 const trace=f=>Collision.rfTrace(panel,[-50,0,0],[50,0,0],1,f,.6,{nodes:8192,triangles:4096});
 assert.equal(trace(868).hits.length,0);assert.equal(trace(868).fresnel,true);assert.equal(trace(5800).fresnel,false);
});
test('RF manager waits for independent geometry, deduplicates overlapping faces and clears disabled scenes',async()=>{
 const a=item('a'),b=item('b');a.rfMaterials={['managed/'+key]:{material:'metal'}};b.rfMaterials={['managed/'+key]:{material:'glass'}};
 const f=fixture({fetchCatalog:async()=>({schemaVersion:1,sceneries:[a,b]}),modelFactory:()=>new Promise(()=>{})});
 try{await f.manager.initialize();await flush();f.manager.tick(true);await flush();f.manager.tick(true);await flush();
 const p=geo([-10,-5,2]),q=geo([10,-5,2]);const both=f.manager.radioPath(p,q,5800,0);
 assert.ok(both.complete);assert.ok(both.obstructions>0);assert.deepEqual(both.materials,['metal']);
 f.manager.setEnabled('b',false);const one=f.manager.radioPath(p,q,5800,0);assert.equal(one.obstructions,both.obstructions);assert.equal(one.lossDb,both.lossDb);
 f.manager.setEnabled('a',false);const clear=f.manager.radioPath(p,q,5800,0);assert.equal(clear.obstructions,0);assert.equal(clear.lossDb,0);
 }finally{f.manager.dispose();}
});
