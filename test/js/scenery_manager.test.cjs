'use strict';
const test=require('node:test');const assert=require('node:assert/strict');
const M=require('../../web/features/scenery/scenery_manager.js');const R=require('../../web/features/terrain/regional_3d.js');
const catalog=require('../../web/assets/scenery/catalog.json');
const ROOT_HEIGHT=catalog.sceneries[0].alignment.ellipsoidHeightM;
// Preserve provider-driven fitting regression coverage with a separate opt-in fixture.
const terrainCatalog=structuredClone(catalog);
terrainCatalog.sceneries[0].heightAlignmentMode='terrain';
terrainCatalog.sceneries[0].requireGroundCalibration=false;
delete terrainCatalog.sceneries[0].heightCalibration;
const flush=()=>new Promise(resolve=>setImmediate(resolve));
function fixture(){const models=[],credits=[],status=[];let p={...catalog.sceneries[0].alignment,height:100},t=0,fn;
 class Matrix4{};Matrix4.fromRotationTranslation=x=>x;Matrix4.multiply=(a,b)=>({a,b});
 const C={Cartesian3:{fromDegrees:(...v)=>v},Transforms:{eastNorthUpToFixedFrame:x=>x},Matrix3:{fromRotationZ:x=>x},Matrix4,Math:{toRadians:v=>v*Math.PI/180},Color:class{constructor(...v){this.values=v;}},Credit:class{constructor(...v){this.values=v;} }};
 const viewer={scene:{primitives:{add:x=>models.push(x),remove:x=>{models.splice(models.indexOf(x),1);x.destroy?.();}},preUpdate:{addEventListener:x=>{fn=x;return ()=>{fn=null;};}},requestRender(){}},cesiumWidget:{creditDisplay:{addStaticCredit:x=>credits.push(x),removeStaticCredit:x=>credits.splice(credits.indexOf(x),1)}}};
 return {C,viewer,models,credits,status,collisionFactory:async()=>{throw Error('No test collider');},position:()=>p,now:()=>t,advance:(next)=>{p=next;t+=1000;fn?.();},onStatus:x=>status.push(x)};
}
test('catalog validates exact aligned model and rejects traversal, invalid transformations and physical collision claims',()=>{
 const [s]=M.validate(catalog);assert.equal(s.alignment.opacity,1);assert.equal(s.alignment.scale,16.023268178233355);assert.equal(s.alignment.rotationDeg,99.7993823133657);assert.ok(Math.abs(s.alignment.ellipsoidHeightM-112.279767885956)<1e-8);assert.equal(s.heightAlignmentMode,'terrain');assert.equal(s.requireGroundCalibration,true);
 for(const transform of [x=>x.assets[0].path='../bad.glb',x=>x.assets[0].path='https://example.com/a.glb',x=>delete x.collisionAsset,x=>x.collisionAsset='../bad.fpc',x=>delete x.alignment.scale,x=>x.sourceUrl='javascript:alert(1)']){const copy=structuredClone(catalog);transform(copy.sceneries[0]);assert.throws(()=>M.validate(copy));}
 assert.throws(()=>M.validate({...catalog,sceneries:[s,s]}));
});
test('scenery loads only nearby, waits for readiness, unloads, retains credits and persists explicit preferences',async()=>{
 const f=fixture(),stored=new Map(),storage={getItem:k=>stored.get(k),setItem:(k,v)=>stored.set(k,v)};
 let loads=0;const model={ready:false,destroy(){this.destroyed=true;}};
 const m=M.create(f.C,f.viewer,{...f,storage,fetchCatalog:async()=>catalog,modelFactory:async(url,cfg)=>{loads++;assert.equal(url,'./assets/scenery/local_reference.glb');assert.equal(cfg.scale,16.023268178233355);return model;}});
 try{await m.initialize();await flush();assert.equal(m.snapshot()[0].state,'loading');assert.equal(f.models.length,1);assert.equal(f.credits.length,1);assert.deepEqual(m.visualOnlyModels(),[model]);model.ready=true;m.tick(true);assert.equal(m.snapshot()[0].state,'ready');
 f.advance({...f.position(),latitude:53});assert.equal(f.models.length,0);assert.equal(f.credits.length,0);assert.equal(model.destroyed,true);assert.equal(m.snapshot()[0].state,'idle');m.setEnabled(catalog.sceneries[0].id,false);f.advance({...catalog.sceneries[0].alignment,height:100});assert.equal(loads,1);assert.equal(JSON.parse([...stored.values()][0])[catalog.sceneries[0].id],false);
 }finally{m.dispose();}
});
test('late model is destroyed after leaving or disabling scenery',async()=>{
 const f=fixture();let resolve;const late=new Promise(r=>resolve=r);const m=M.create(f.C,f.viewer,{...f,fetchCatalog:async()=>catalog,modelFactory:()=>late});
 try{await m.initialize();m.setEnabled(catalog.sceneries[0].id,false);const model={destroy(){this.destroyed=true;}};resolve(model);await flush();assert.equal(model.destroyed,true);assert.equal(f.models.length,0);assert.equal(f.credits.length,0);}finally{m.dispose();}
});
test('regional selection respects Germany outline and altitude hysteresis',()=>{assert.equal(R.inRegion({longitude:13.79,latitude:52.48,height:500}),true);assert.equal(R.inRegion({longitude:8.4,latitude:46.7,height:500}),false);assert.equal(R.inRegion({longitude:13.79,latitude:52.48,height:120000}),false);assert.equal(R.inRegion({longitude:13.79,latitude:52.48,height:90000},true),true);assert.equal(R.inRegion({longitude:14.89,latitude:52.48,height:500},true),false,'the old BB rectangle extended into Poland');});
test('beta regional tiles are opt-in, unload on leaving, and do not change terrain during navigation',async()=>{
 const f=fixture();let busy=false,online=true,regions=[],loads=0;
 const r=R.create(f.C,f.viewer,{...f,enabled:true,online:()=>online,navigationBusy:()=>busy,buildingsRequested:()=>true,onRegionChange:x=>regions.push(x),loadTiles:async()=>{loads++;return {destroy(){this.destroyed=true;}};}});
 try{r.tick(true);await flush();assert.deepEqual(regions,[true]);assert.equal(loads,1);assert.equal(f.credits.length,1);busy=true;f.advance({longitude:8.4,latitude:46.7,height:500});assert.deepEqual(regions,[true]);busy=false;r.tick(true);assert.deepEqual(regions,[true,false]);assert.equal(f.models.length,0);assert.equal(f.credits.length,0);online=false;f.advance({longitude:13.79,latitude:52.48,height:100});assert.equal(loads,1);}finally{r.dispose();}
});
test('terrain alignment keeps horizontal coordinates and accounts for scaled local ground height',()=>{
 const [item]=M.validate(catalog);const result=M.terrainAligned(item,65);
 assert.ok(Math.abs(result.ellipsoidHeightM-(65+2.02575*16.023268178233355))<1e-9);
 for(const k of ['longitude','latitude','rotationDeg','scale','opacity'])assert.equal(result[k],item.alignment[k]);
 assert.throws(()=>M.terrainAligned(item,NaN));
 const bad=structuredClone(catalog);bad.sceneries[0].groundReferenceLocalUp='-2';assert.throws(()=>M.validate(bad));
});
test('loaded scenery adjusts to active terrain and restores original height when provider leaves',async()=>{
 const f=fixture();let key=null,calls=0;const model={ready:true,destroy(){}};
 const m=M.create(f.C,f.viewer,{...f,fetchCatalog:async()=>terrainCatalog,modelFactory:async()=>model,terrainKey:()=>key,sampleGround:async()=>{calls++;return 55;}});
 try{await m.initialize();await flush();m.tick(true);assert.equal(calls,0);key={};m.tick(true);await flush();const s=m.snapshot()[0];assert.equal(s.heightState,'adjusted');assert.equal(s.groundHeightM,55);assert.equal(s.alignment.ellipsoidHeightM,ROOT_HEIGHT);assert.equal(s.heightAlignmentMode,'terrain');assert.equal(model.modelMatrix.a[2],s.effectiveAlignment.ellipsoidHeightM);m.tick(true);assert.equal(calls,1);key=null;m.tick(true);assert.equal(m.snapshot()[0].effectiveAlignment.ellipsoidHeightM,ROOT_HEIGHT);assert.equal(model.modelMatrix.a[2],ROOT_HEIGHT);}finally{m.dispose();}
});
test('late terrain sample cannot change a model after provider change or removal',async()=>{
 const f=fixture();let key={},resolve;const late=new Promise(r=>resolve=r);const model={ready:true,destroy(){}};
 const m=M.create(f.C,f.viewer,{...f,fetchCatalog:async()=>terrainCatalog,modelFactory:async()=>model,terrainKey:()=>key,sampleGround:()=>late});
 try{await m.initialize();await flush();m.tick(true);key=null;m.tick(true);resolve(80);await flush();assert.equal(m.snapshot()[0].effectiveAlignment.ellipsoidHeightM,ROOT_HEIGHT);assert.equal(m.snapshot()[0].groundHeightM,null);assert.equal(model.modelMatrix.a[2],ROOT_HEIGHT);}finally{m.dispose();}
});
test('failed height sample retries without corrupting the original placement',async()=>{
 const f=fixture();const key={};let calls=0;const model={ready:true,destroy(){}};
 const m=M.create(f.C,f.viewer,{...f,fetchCatalog:async()=>terrainCatalog,modelFactory:async()=>model,terrainKey:()=>key,sampleGround:async()=>{if(++calls===1)throw Error('unavailable');return 61;}});
 try{await m.initialize();await flush();m.tick(true);await flush();assert.equal(m.snapshot()[0].heightState,'unavailable');assert.equal(m.snapshot()[0].effectiveAlignment.ellipsoidHeightM,ROOT_HEIGHT);for(let i=0;i<10;i++)f.advance(f.position());await flush();assert.equal(calls,2);assert.equal(m.snapshot()[0].heightState,'adjusted');}finally{m.dispose();}
});

test('editing ready scenery preserves GLB, resamples height, restores and gates replacement regions',async()=>{
 const f=fixture();const A=require('../../web/features/scenery/scenery_alignment.js');const id=catalog.sceneries[0].id;
 let loads=0,calls=0;const model={ready:true,destroy(){}};const key={};
 const m=M.create(f.C,f.viewer,{...f,fetchCatalog:async()=>terrainCatalog,modelFactory:async()=>{loads++;return model;},terrainKey:()=>key,sampleGround:async()=>{calls++;return 60;}});
 try{await m.initialize();await flush();m.tick(true);await flush();const initial=m.snapshot()[0];
 const alignment=A.nudge(initial.alignment,2,3);
 const polygon=[[0,0],[20,0],[20,20],[0,20]].map(([x,y])=>{const a=A.offset(alignment,x,y);return [a.longitude,a.latitude];});
 m.setEdit(id,{alignment,heightOffsetM:.5,replaceBuildings:true,buildingRegions:[polygon],clipTerrain:true,terrainRegions:[polygon]});
 assert.equal(m.activeRegions('buildings').length,0);await flush();m.tick(true);
 assert.equal(loads,1);assert.equal(calls,2);assert.equal(m.activeRegions('buildings').length,1);assert.equal(m.activeRegions('terrain').length,0,'R8 certified scenery rejects arbitrary visual-only terrain holes after alignment edits');
 assert.ok(Math.abs(m.snapshot()[0].effectiveAlignment.ellipsoidHeightM-(60+2.02575*16.023268178233355+.5))<1e-9);
 m.setEdit(id,{alignment:{...alignment,opacity:.5},replaceBuildings:true,buildingRegions:[polygon]});await flush();assert.equal(m.activeRegions('buildings').length,0);
 m.setEdit(id,null);await flush();assert.deepEqual(m.snapshot()[0].alignment,initial.alignment);assert.equal(m.activeRegions('buildings').length,1);assert.equal(loads,1);
 }finally{m.dispose();}
});
test('regional cuts target only owned collections, restore on navigation and preserve foreign terrain clipping',async()=>{
 const f=fixture();const A=require('../../web/features/scenery/scenery_alignment.js');let busy=false,regions=[];
 const globe={clippingPolygons:undefined};f.viewer.scene.globe=globe;
 f.C.ClippingPolygonCollection=class{static isSupported(){return true;}constructor({polygons}){this.polygons=polygons;}};
 f.C.ClippingPolygon=class{constructor({positions}){this.positions=positions;}};
 const tiles={clippingPolygons:undefined,destroy(){}};
 const r=R.create(f.C,f.viewer,{...f,enabled:true,navigationBusy:()=>busy,buildingsRequested:()=>true,terrainReady:()=>true,buildingRegions:()=>regions,terrainRegions:()=>regions,loadTiles:async()=>tiles});
 try{r.tick(true);await flush();const p=A.DEFAULT;regions=[[[0,0],[20,0],[20,20]].map(([x,y])=>{const q=A.offset(p,x,y);return [q.longitude,q.latitude];})];
 r.tick(true);assert.equal(tiles.clippingPolygons.polygons.length,1);assert.equal(globe.clippingPolygons.polygons.length,1);
 const owned=tiles.clippingPolygons;r.tick(true);assert.equal(tiles.clippingPolygons,owned);
 busy=true;r.tick(true);assert.equal(globe.clippingPolygons,undefined);assert.equal(tiles.clippingPolygons,undefined);
 const foreign={};globe.clippingPolygons=foreign;busy=false;r.tick(true);assert.equal(globe.clippingPolygons,foreign);assert.ok(tiles.clippingPolygons);
 regions=[];r.tick(true);assert.equal(globe.clippingPolygons,foreign);assert.equal(tiles.clippingPolygons,undefined);
 }finally{r.dispose();}
});

test('flight masks require ready physical mesh and terrain, stale collider loads cannot reactivate scenery',async()=>{
 const f=fixture();let resolve;const model={ready:true,destroy(){}};const id=catalog.sceneries[0].id;
 const m=M.create(f.C,f.viewer,{...f,fetchCatalog:async()=>terrainCatalog,modelFactory:async()=>model,collisionFactory:(_url,signal)=>new Promise(r=>{resolve=r;assert.equal(signal.aborted,false);})});
 try{await m.initialize();await flush();m.tick(true);assert.equal(m.snapshot()[0].collisionState,'loading');assert.equal(m.activeRegions('buildings').length,1);assert.equal(m.activeRegions('buildings',true).length,0);
 resolve({triangleCount:4,byteLength:100});await flush();assert.equal(m.snapshot()[0].collisionReady,true);assert.equal(m.activeRegions('buildings',true).length,1);assert.equal(m.activeRegions('terrain',true).length,0);
 m.retry(id);await flush();m.tick(true);m.setEnabled(id,false);resolve({triangleCount:4});await flush();assert.equal(m.snapshot()[0].collisionReady,false);assert.equal(m.activeRegions('buildings',true).length,0);
 }finally{m.dispose();}
});
test('missing collider preserves visual scenery but prevents replacement during flight',async()=>{
 const f=fixture();const m=M.create(f.C,f.viewer,{...f,fetchCatalog:async()=>catalog,modelFactory:async()=>({ready:true,destroy(){}})});
 try{await m.initialize();await flush();m.tick(true);assert.equal(m.snapshot()[0].state,'ready');assert.equal(m.snapshot()[0].collisionState,'error');assert.equal(m.activeRegions('buildings',true).length,0);assert.equal(m.collision(f.position(),f.position()),false);}finally{m.dispose();}
});
test('during navigation only collision-backed building masks are applied; terrain remains intact',async()=>{
 const f=fixture();let busy=false,physical=false;const regions=[catalog.sceneries[0].buildingRegions[0]];
 f.viewer.scene.globe={clippingPolygons:undefined};f.C.ClippingPolygonCollection=class{static isSupported(){return true;}constructor(o){this.polygons=o.polygons;}};f.C.ClippingPolygon=class{constructor(o){this.positions=o.positions;}};
 const tiles={clippingPolygons:undefined,destroy(){}};
 const r=R.create(f.C,f.viewer,{...f,enabled:true,navigationBusy:()=>busy,buildingsRequested:()=>true,terrainReady:()=>true,buildingRegions:()=>regions,flightBuildingRegions:()=>physical?regions:[],terrainRegions:()=>regions,loadTiles:async()=>tiles});
 try{r.tick(true);await flush();busy=true;r.tick(true);assert.equal(tiles.clippingPolygons,undefined);physical=true;r.tick(true);assert.ok(tiles.clippingPolygons);assert.equal(f.viewer.scene.globe.clippingPolygons,undefined);physical=false;r.tick(true);assert.equal(tiles.clippingPolygons,undefined);}finally{r.dispose();}
});


test('R32: missing terrain height keeps even a loaded FPC collider inactive',async()=>{
 const f=fixture();let provider=null;
 const model={ready:true,show:true,destroy(){}};
 const m=M.create(f.C,f.viewer,{...f,fetchCatalog:async()=>catalog,
   modelFactory:async()=>model,
   collisionFactory:async()=>({triangleCount:10,byteLength:256}),
   terrainKey:()=>provider,
   sampleGround:async()=>41});
 try{
   await m.initialize();await flush();m.tick(true);await flush();
   assert.equal(m.snapshot()[0].collisionState,'ready');
   assert.equal(model.show,false);
   assert.equal(m.snapshot()[0].collisionReady,false,
       'A hidden, uncalibrated model must never create physical flight collisions');
   provider={name:'bkg'};m.tick(true);await flush();
   assert.equal(model.show,true);
   assert.equal(m.snapshot()[0].collisionReady,true);
   provider=null;m.tick(true);await flush();
   assert.equal(model.show,false);
   assert.equal(m.snapshot()[0].collisionReady,false);
 }finally{m.dispose();}
});

test('R33: BKG switch automatically restores calibrated Rüdersdorf when local terrain tiles arrive',async()=>{
 const f=fixture();let key={name:'world'},regional=false,tilesReady=true,tileProgress,loads=0;
 const model={ready:true,show:true,destroy(){}};
 f.viewer.scene.globe={tileLoadProgressEvent:{addEventListener:fn=>{tileProgress=fn;return ()=>{tileProgress=null;};}}};
 const m=M.create(f.C,f.viewer,{...f,fetchCatalog:async()=>catalog,
   modelFactory:async()=>{loads++;return model;},
   terrainKey:()=>key,regionalHeightMode:()=>regional,
   sampleGround:async()=>{if(regional&&!tilesReady)throw Error('DGM5 tiles not yet rendered');return regional?79:46;}});
 try{
   await m.initialize();await flush();m.tick(true);await flush();
   assert.equal(model.show,true);
   assert.equal(m.snapshot()[0].heightState,'adjusted');
   regional=true;key={name:'BKG DGM5'};tilesReady=false;m.tick(true);await flush();
   assert.equal(model.show,false,'missing DGM5 calibration must not show a wrongly placed model');
   assert.equal(m.snapshot()[0].heightState,'unavailable');
   tilesReady=true;tileProgress(0);
   await new Promise(resolve=>setTimeout(resolve,10));await flush();
   assert.equal(m.snapshot()[0].heightState,'adjusted');
   assert.equal(model.show,true,'tile arrival must restore scenery without user toggling it');
   assert.equal(loads,1,'provider switch must not reload the local GLB');
 }finally{m.dispose();}
});

test('R33: failed BKG fitting retries on its own even without a tile-ready event',async()=>{
 const f=fixture();let elapsed=0,available=false,calls=0,sequence=0;
 const timers=new Map(),setTimer=(fn,delay)=>{const id=++sequence;timers.set(id,{fn,due:elapsed+delay});return id;};
 const clearTimer=id=>timers.delete(id);
 const advance=ms=>{elapsed+=ms;for(const [id,t] of [...timers])if(t.due<=elapsed){timers.delete(id);t.fn();}};
 const model={ready:true,show:true,destroy(){}};
 const provider={name:'BKG DGM5'};
 const m=M.create(f.C,f.viewer,{...f,now:()=>elapsed,setTimer,clearTimer,
   fetchCatalog:async()=>catalog,modelFactory:async()=>model,
   terrainKey:()=>provider,regionalHeightMode:()=>true,
   sampleGround:async()=>{calls++;if(!available)throw Error('DGM5 is loading');return 80;}});
 try{
   await m.initialize();await flush();m.tick(true);await flush();
   assert.equal(calls,1);assert.equal(model.show,false);
   available=true;advance(2500);await flush();
   assert.equal(calls,2);assert.equal(model.show,true);
   assert.equal(m.snapshot()[0].heightState,'adjusted');
 }finally{m.dispose();}
});
