'use strict';
const {test}=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs');
const R=require('../../web/features/scenery/scenery_replacement.js'),A=require('../../web/features/scenery/scenery_alignment.js'),M=require('../../web/features/scenery/scenery_manager.js'),Collision=require('../../web/features/scenery/scenery_collision.js');
const C=require('../../web/cesium/index.cjs'),pose={longitude:13.8,latitude:52.4,ellipsoidHeightM:100,rotationDeg:0,pitchDeg:0,rollDeg:0,scale:1,opacity:1};
const polygon=(x0,y0,x1,y1)=>[[x0,y0],[x1,y0],[x1,y1],[x0,y1]].map(([x,y])=>{const p=A.offset(pose,x,y);return [p.longitude,p.latitude];});
const region={polygon:polygon(1,-10,19,10),minimumUpM:-.1,maximumUpM:.1,seamToleranceM:.5};
const config=()=>({schemaVersion:1,buildings:{enabled:true,regions:[structuredClone(region.polygon)],features:[{provider:'swisstopo',property:'uuid',id:'building-1'}]},terrain:{enabled:true,regions:[structuredClone(region)]}});
const data=fs.readFileSync('test/fixtures/scenery/collision_room.fpc'),mesh=Collision.parse(data.buffer.slice(data.byteOffset,data.byteOffset+data.length)),frame=Collision.transform(pose);
const geo=(x,y,z)=>{const world=C.Matrix4.multiplyByPoint(A.modelMatrix(C,pose),new C.Cartesian3(x,y,z),new C.Cartesian3()),p=C.Cartographic.fromCartesian(world);return {longitude:C.Math.toDegrees(p.longitude),latitude:C.Math.toDegrees(p.latitude),height:p.height};};
const flush=()=>new Promise(r=>setImmediate(r));
function fixture(extra={}){
 class Collection{static isSupported(){return yes;}constructor({polygons}){this.polygons=polygons;this.enabled=true;}}
 let yes=true,build=[region.polygon],terrain=[region.polygon],features=config().buildings.features,ready=true,provider={};
 const tile={show:true,clippingPolygons:undefined,tileVisible:new C.Event(),tileUnload:new C.Event()},globe={clippingPolygons:undefined},viewer={scene:{globe,preUpdate:new C.Event(),requestRender(){}}};
 const manager=R.create({...C,ClippingPolygonCollection:Collection,ClippingPolygon:class{constructor(x){Object.assign(this,x);}}},viewer,{buildingTargets:()=>[{key:'swisstopo',tileset:tile}],buildingRegions:()=>build,buildingFeatures:()=>features,terrainRegions:()=>terrain,terrainReady:()=>ready,terrainKey:()=>provider,...extra});
 return {manager,tile,globe,viewer,switchProvider(){provider={};},set(v){if(v.build)build=v.build;if(v.terrain)terrain=v.terrain;if(v.features)features=v.features;if(v.yes!==undefined)yes=v.yes;if(v.ready!==undefined)ready=v.ready;manager.sync();}};
}
test('replacement contract validates polygons, IDs and ground bands independently',()=>{
 assert.deepEqual(R.normalize(config(),pose),config());
 for(const change of [c=>c.buildings.regions[0].push(c.buildings.regions[0][0]),c=>c.buildings.features.push({...c.buildings.features[0]}),c=>c.terrain.regions[0].maximumUpM=-1,c=>c.terrain.regions[0].seamToleranceM=5,c=>c.buildings.features[0].provider='other']){const c=config();change(c);assert.throws(()=>R.normalize(c,pose));}
 const c=config();c.buildings.enabled=false;assert.equal(R.normalize(c,pose).terrain.enabled,true);
});
test('polygon union partitions outside terrain, concavities, disconnected gaps and antimeridian',()=>{
 const p=[[0,0],[2,0],[2,2],[0,2]],q=[[1,0],[3,0],[3,2],[1,2]],from={longitude:-1,latitude:1},to={longitude:4,latitude:1};
 assert.deepEqual(R.outsideIntervals(from,to,[p,q]),[[0,.2],[.8,1]]);assert.deepEqual(R.outsideIntervals(from,to,[q,p]),[[0,.2],[.8,1]]);
 assert.equal(R.outsideIntervals({longitude:.5,latitude:1},{longitude:1.5,latitude:1},[p]).length,0);
 const separated=[p,q.map(([x,y])=>[x+4,y])];assert.equal(R.outsideIntervals(from,{longitude:8,latitude:1},separated).length,3);
 const concave=[[0,0],[3,0],[3,3],[2,3],[2,1],[1,1],[1,3],[0,3]];
 assert.equal(R.outsideIntervals({longitude:.5,latitude:2},{longitude:2.5,latitude:2},[concave]).length,1);
 assert.equal(R.outsideIntervals({longitude:179.9,latitude:0},{longitude:-179.9,latitude:0},[[[179.8,-1],[-179.8,-1],[-179.8,1],[179.8,1]]]).length,0);
 assert.equal(R.inside({longitude:4,latitude:1},p),false);
});
test('owned masks restore base geometry and preserve foreign tunnel clipping and depth settings',()=>{
 const f=fixture();try{f.manager.sync();assert.ok(f.globe.clippingPolygons&&f.tile.clippingPolygons);const rev=f.manager.revision();f.manager.sync();assert.equal(f.manager.revision(),rev);
  const depth=true;f.globe.depthTestAgainstTerrain=depth;f.set({terrain:[]});assert.equal(f.globe.clippingPolygons,undefined);assert.equal(f.globe.depthTestAgainstTerrain,depth);assert.ok(f.tile.clippingPolygons);
  const foreign={length:1};f.globe.clippingPolygons=foreign;f.set({terrain:[region.polygon]});assert.equal(f.globe.clippingPolygons,foreign);assert.equal(f.manager.terrainMaskActive(region.polygon),false);assert.match(f.manager.status().errors.join(),/Another feature/);
  f.set({build:[]});assert.equal(f.tile.clippingPolygons,undefined);f.globe.clippingPolygons=undefined;f.manager.sync();assert.equal(f.manager.terrainMaskActive(region.polygon),true);
  f.globe.clippingPolygons.enabled=false;assert.equal(f.manager.terrainMaskActive(region.polygon),false);
 }finally{f.manager.dispose();assert.equal(f.tile.tileVisible.numberOfListeners,0);assert.equal(f.globe.clippingPolygons,undefined);}
});
test('unsupported masks and provider changes never create physical terrain exceptions',()=>{
 const f=fixture();try{f.set({yes:false});assert.equal(f.manager.terrainMaskActive(region.polygon),false);assert.deepEqual(f.manager.terrainIntervals(geo(-1,0,0),geo(21,0,0)),[[0,1]]);f.set({yes:true});assert.equal(f.manager.terrainMaskActive(region.polygon),true);f.switchProvider();assert.equal(f.manager.terrainMaskActive(region.polygon),false,'provider switch revokes a still-attached mask before the next frame');f.manager.sync();assert.equal(f.manager.terrainMaskActive(region.polygon),true);f.set({ready:false});assert.equal(f.globe.clippingPolygons,undefined);}finally{f.manager.dispose();}
});
test('stable feature exclusions persist on tile revisits, preserve other IDs and release references on unload',()=>{
 const f=fixture(),feature=(id,show=true)=>({show,getProperty:k=>k==='uuid'?id:undefined}),one=feature('building-1'),two=feature('other'),hidden=feature('building-1',false),tile={content:{featuresLength:3,getFeature:i=>[one,two,hidden][i]}};
 try{f.manager.sync();f.tile.tileVisible.raiseEvent(tile);assert.equal(one.show,false);assert.equal(two.show,true);assert.equal(f.manager.status().hiddenFeatures,2);one.show=true;f.tile.tileVisible.raiseEvent(tile);assert.equal(one.show,false);
  f.set({features:[]});assert.equal(one.show,true);assert.equal(hidden.show,false);assert.equal(f.tile.tileVisible.numberOfListeners,0);
  f.set({features:config().buildings.features});f.tile.tileVisible.raiseEvent(tile);f.tile.tileUnload.raiseEvent(tile);assert.equal(f.manager.status().hiddenFeatures,0);
 }finally{f.manager.dispose();}
});
test('terrain perimeter evaluation uses actual physical ground and rejects seams, missing tiles and holes',()=>{
 const points=R.seamPoints(region,pose),heights=points.map(p=>R.ground([mesh],frame,region,{...p,height:100}));
 assert.ok(points.length>=20);assert.equal(R.evaluate([mesh],frame,region,points,heights).approved,true);
 assert.equal(R.evaluate([mesh],frame,region,points,heights.map(h=>h+1)).approved,false);heights[0]=NaN;assert.equal(R.evaluate([mesh],frame,region,points,heights).approved,false);
 const missing={...region,polygon:polygon(-5,-5,-1,5)};assert.equal(R.evaluate([mesh],frame,missing,R.seamPoints(missing,pose),R.seamPoints(missing,pose).map(()=>100)).approved,false);
});
function managed(extra={}){
 let provider={},perturb=0,resolver;const viewer={scene:{primitives:{add:x=>x,remove(){}},preUpdate:new C.Event(),requestRender(){}},cesiumWidget:{creditDisplay:{addStaticCredit(){},removeStaticCredit(){}}}};
 const item={id:'custom',name:'Custom',author:'Tests',license:'CC0',enabled:true,heightDatum:'WGS84 ellipsoid',alignment:pose,heightAlignmentMode:'fixed',physicalCollisionsEnabled:true,collisionIndependent:true,collisionAsset:'synthetic.fpc',collisionAssets:['synthetic.fpc'],collisionResources:[{path:'synthetic.fpc',managed:false}],assets:[{kind:'glb',path:'synthetic.glb'}],replacement:config()};
 const manager=M.create(C,viewer,{fetchCatalog:async()=>({schemaVersion:1,sceneries:[item]}),position:()=>geo(2,0,2),terrainKey:()=>provider,modelFactory:async()=>({ready:true,destroy(){}}),collisionFactory:async()=>mesh,sampleSeamGround:async points=>points.map(p=>R.ground([mesh],frame,region,{...p,height:100})+perturb),...extra});
 return {manager,item,setProvider(){provider={};},setMismatch(v){perturb=v;}};
}
async function settle(f){for(let i=0;i<8;i++){await flush();f.manager.tick(true);}}
test('generic masks activate with visual/collision/height readiness and restore on disable, unload and editing',async()=>{
 const f=managed();try{await f.manager.initialize();await settle(f);assert.equal(f.manager.activeRegions('terrain',true).length,1);assert.equal(f.manager.activeRegions('buildings',true).length,1);assert.equal(f.manager.buildingFeatures().length,1);
  const point=geo(2,0,2);assert.ok(Math.abs(f.manager.replacementHeight(point,()=>true)-100)<.01);assert.equal(f.manager.replacementHeight(point,()=>false),undefined);
  assert.equal(f.manager.replacementPassage(geo(2,0,2),geo(18,0,2),()=>true),true);assert.equal(f.manager.replacementPassage(geo(-2,0,2),geo(18,0,2),()=>true),false);
  f.manager.beginAlignment('custom');assert.equal(f.manager.activeRegions('terrain').length,0);assert.equal(f.manager.activeRegions('buildings').length,0);f.manager.endAlignment('custom');await settle(f);assert.equal(f.manager.activeRegions('terrain').length,1);
  f.manager.setEnabled('custom',false);assert.equal(f.manager.activeRegions('terrain').length,0);assert.equal(f.manager.activeRegions('buildings').length,0);
 }finally{f.manager.dispose();}
});
test('provider changes immediately revoke terrain approval and failed rechecks retain base ground',async()=>{
 const f=managed();try{await f.manager.initialize();await settle(f);assert.equal(f.manager.activeRegions('terrain').length,1);f.setProvider();assert.equal(f.manager.activeRegions('terrain').length,0);f.setMismatch(1);await settle(f);assert.equal(f.manager.activeRegions('terrain').length,0);assert.equal(f.manager.snapshot()[0].replacementChecks[0].approved,false);assert.equal(f.manager.activeRegions('buildings').length,1);}finally{f.manager.dispose();}
});
test('missing collision data never opens terrain while building-only replacement remains independent',async()=>{
 const f=managed({collisionFactory:async()=>{throw Error('Missing collider');}});try{await f.manager.initialize();await settle(f);assert.equal(f.manager.activeRegions('terrain',true).length,0);assert.equal(f.manager.activeRegions('buildings',true).length,1);}finally{f.manager.dispose();}
});
test('stale seam responses and repeated errors cannot reopen superseded regions',async()=>{
 let resolve;const f=managed({sampleSeamGround:()=>new Promise(r=>resolve=r)});try{await f.manager.initialize();await settle(f);assert.equal(f.manager.activeRegions('terrain').length,0);f.manager.setEnabled('custom',false);resolve(Array(128).fill(100));await settle(f);assert.equal(f.manager.activeRegions('terrain').length,0);}finally{f.manager.dispose();}
});
test('base model envelope cache is invalidated by replacement revision',()=>{
 const {FPVSceneModelCollision}=require('../../web/features/scene/scene_environment.js');let revision=0,show=true,clock=0,pending;
 const event=new C.Event(),viewer={scene:{mode:C.SceneMode.SCENE3D,sampleHeightSupported:true,sampleHeight:()=>show?110:undefined,globe:{getHeight:()=>100},postRender:event}};
 const manager=FPVSceneModelCollision.create(C,viewer,{hasVisibleModels:()=>true,exclusionRevision:()=>revision,now:()=>clock,setTimer:f=>{pending=f;return 1;},clearTimer(){}});manager.setEnabled(true);
 const p={longitude:13.8,latitude:52.4,height:110};manager.collision(p,p);event.raiseEvent();pending();revision++;show=false;assert.equal(manager.collision(p,p),false,'removed roof must not produce a cached invisible contact');manager.dispose();
});
test('bounded seam timeout recovers on retry and rejects the old response',async()=>{
 let calls=0,late,next=0;const timers=new Map(),f=managed({sampleSeamGround:points=>++calls===1?new Promise(r=>late=r):Promise.resolve(points.map(p=>R.ground([mesh],frame,region,{...p,height:100}))),setTimer:(fn,ms)=>{timers.set(++next,{fn,ms});return next;},clearTimer:id=>timers.delete(id)});
 try{await f.manager.initialize();await settle(f);assert.equal(f.manager.snapshot()[0].replacementState,'pending');const pending=[...timers.values()];assert.equal(pending.length,1);pending[0].fn();assert.equal(f.manager.snapshot()[0].replacementState,'unavailable');assert.equal(f.manager.activeRegions('terrain').length,0);
  f.manager.retry('custom');await settle(f);assert.equal(f.manager.activeRegions('terrain').length,1);late([]);await settle(f);assert.equal(f.manager.activeRegions('terrain').length,1);
 }finally{f.manager.dispose();}
});
test('overlapping scenes use union masks and the highest physical ground independent of catalog order',async()=>{
 for(const reversed of [false,true]){let definitions;const f=managed({fetchCatalog:async()=>({schemaVersion:1,sceneries:definitions})});definitions=[structuredClone(f.item),{...structuredClone(f.item),id:'upper',alignment:{...pose,ellipsoidHeightM:100.1}}];if(reversed)definitions.reverse();
  try{await f.manager.initialize();await settle(f);assert.equal(f.manager.activeRegions('terrain').length,2);const h=f.manager.replacementHeight(geo(2,0,2),()=>true);assert.ok(h>100.09&&h<100.11,String(h));f.manager.setEnabled('upper',false);assert.equal(f.manager.activeRegions('terrain').length,1);assert.ok(f.manager.replacementHeight(geo(2,0,2),()=>true)<100.01);}finally{f.manager.dispose();}
 }
});
test('both physics modes can descend inside replaced terrain while physical floors remain collidable',async()=>{
 const {createSimulator}=require('../../web/features/flight/free_flight.js');
 for(const physicsModel of ['advanced','legacy']){const f=managed();await f.manager.initialize();await settle(f);const start=geo(2,0,2),s=createSimulator({sampleHeight:async()=>101,renderedHeight:p=>f.manager.replacementHeight(p,()=>true)??101,captureCamera:()=>({heading:0}),restoreCamera(){},applyPose(){},isTerrainReady:()=>true,onState(){},modeledCollision:(a,b)=>f.manager.collision(a,b)});
  try{await s.start({longitude:start.longitude,latitude:start.latitude,agl:2,flightMode:'acro',physicsModel},new AbortController().signal);s.flightInput({throttle:0});for(let i=0;i<180;i++)s.tick(1/60);assert.ok(s.status().height<101&&s.status().height>=100.24,physicsModel+': '+s.status().height);assert.equal(s.status().failsafe.active,false);}finally{s.stop();f.manager.dispose();}
 }
});

 test('revision-driven frame reconciliation skips unchanged work but notices providers and foreign clipping',()=>{
 let revision=0,reads=0;const f=fixture({regionRevision:()=>revision,buildingRegions:()=>{reads++;return [region.polygon];}});
 try{f.manager.sync();const first=f.tile.clippingPolygons;for(let i=0;i<1200;i++)f.viewer.scene.preUpdate.raiseEvent();
 assert.equal(reads,1);assert.equal(f.manager.diagnostics().skippedSyncs,1200);assert.equal(f.tile.clippingPolygons,first);
 revision++;f.manager.sync();assert.equal(reads,2);f.switchProvider();f.manager.sync();assert.equal(reads,3);
 f.tile.show=false;f.manager.sync();assert.equal(f.tile.clippingPolygons,undefined);
 f.tile.show=true;f.manager.sync();assert.ok(f.tile.clippingPolygons);
 const foreign={enabled:true};f.tile.clippingPolygons=foreign;f.manager.sync();assert.equal(f.tile.clippingPolygons,foreign);
 f.tile.clippingPolygons=undefined;f.manager.sync();assert.notEqual(f.tile.clippingPolygons,undefined);
 }finally{f.manager.dispose();}
 });

test('mask plan revision tracks async readiness and immediately revokes cached physical exceptions',async()=>{
 const f=managed();try{await f.manager.initialize();const start=f.manager.replacementRevision();await settle(f);const ready=f.manager.replacementRevision();assert.ok(ready>start);
 const p=geo(2,0,2);assert.ok(Math.abs(f.manager.replacementHeight(p,()=>true)-100)<.01);
 for(let i=0;i<1200;i++){assert.equal(f.manager.replacementRevision(),ready);assert.equal(f.manager.replacementHeight(p,()=>false),undefined);}
 f.setProvider();assert.ok(f.manager.replacementRevision()>ready);assert.equal(f.manager.replacementHeight(p,()=>true),undefined);assert.equal(f.manager.replacementPassage(p,geo(18,0,2),()=>true),false);
 await settle(f);assert.ok(Math.abs(f.manager.replacementHeight(p,()=>true)-100)<.01);
 f.manager.beginAlignment('custom');assert.equal(f.manager.replacementHeight(p,()=>true),undefined);f.manager.endAlignment('custom');await settle(f);
 f.manager.setEnabled('custom',false);assert.equal(f.manager.replacementHeight(p,()=>true),undefined);
 }finally{f.manager.dispose();}
});
