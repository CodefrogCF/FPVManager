'use strict';
const test=require('node:test'),assert=require('node:assert/strict'),C=require('../../web/cesium/index.cjs');
const Manager=require('../../web/features/scenery/scenery_manager.js'),M=require('../../web/features/scenery/scenery_editor_math.js'),Collision=require('../../web/features/scenery/scenery_collision.js');
const pose={longitude:13.8,latitude:52.4,ellipsoidHeightM:100,rotationDeg:0,pitchDeg:0,rollDeg:0,scale:1,opacity:1},flush=()=>new Promise(r=>setImmediate(r));
function mesh(){const out=new ArrayBuffer(16+(9+3+6+2)*4);new Uint32Array(out,0,4).set([0x31435046,3,1,1]);new Float32Array(out,16,9).set([0,-10,-10,0,10,-10,0,0,10]);new Uint32Array(out,52,3).set([0,1,2]);new Float32Array(out,64,6).set([0,-10,-10,0,10,10]);new Int32Array(out,88,2).set([-1,1]);return Collision.parse(out);}
function fixture(extra={}){
 const models=[],writes=[];let point={longitude:pose.longitude,latitude:pose.latitude,height:100},loads=0;
 const item={id:'site',name:'Synthetic',author:'Tests',license:'CC0',heightDatum:'WGS84 ellipsoid',enabled:true,alignment:pose,heightAlignmentMode:'fixed',physicalCollisionsEnabled:true,collisionAsset:'wall.fpc',loadRadiusM:1000,unloadRadiusM:2000,assets:[{kind:'glb',path:'test.glb'}],...extra.item};
 const viewer={scene:{primitives:{add:m=>models.push(m),remove:m=>{models.splice(models.indexOf(m),1);m.destroy();}},preUpdate:new C.Event(),requestRender(){}},cesiumWidget:{creditDisplay:{addStaticCredit(){},removeStaticCredit(){}}}};
 const manager=Manager.create(C,viewer,{fetchCatalog:async()=>({schemaVersion:1,sceneries:[item]}),position:()=>point,storage:{getItem(){return null;},setItem(...args){writes.push(args);}},modelFactory:async()=>{loads++;return {ready:true,destroy(){this.destroyed=true;}};},collisionFactory:async()=>mesh(),...extra});
 return {manager,models,writes,get loads(){return loads;},setPoint:p=>point=p,item};
}
test('preview shares full ENU transforms with collision sweeps without reloading assets',async()=>{
 const f=fixture();try{await f.manager.initialize();await flush();await flush();f.manager.tick(true);assert.equal(f.manager.snapshot()[0].collisionReady,true);
  f.manager.beginAlignment('site');const a=M.translate(C,{...pose,rotationDeg:37,pitchDeg:15,rollDeg:-8,scale:2},5,7,3);f.manager.previewAlignment('site',a,[]);
  const geo=local=>{const p=M.geographic(C,M.point(C,a,local));return {longitude:p.longitude,latitude:p.latitude,height:p.ellipsoidHeightM};};
  assert.ok(f.manager.collision(geo({x:-20,y:0,z:0}),geo({x:20,y:0,z:0})),'the common collision sweep follows the rendered transform');
  assert.ok(C.Matrix4.equalsEpsilon(f.models[0].modelMatrix,M.matrix(C,{...a,scale:1}),1e-7));assert.equal(f.models[0].scale,2);assert.equal(f.loads,1);assert.equal(f.writes.length,0);
  f.manager.endAlignment('site');assert.ok(C.Matrix4.equalsEpsilon(f.models[0].modelMatrix,M.matrix(C,pose),1e-7));assert.equal(f.models[0].scale,1);assert.equal(f.loads,1);
 }finally{f.manager.dispose();}
});
test('disabled scenery is temporarily pinned and cancellation restores its enable preference',async()=>{
 const f=fixture({item:{enabled:false}});try{await f.manager.initialize();assert.equal(f.models.length,0);f.manager.beginAlignment('site');await flush();await flush();f.manager.tick(true);assert.equal(f.models.length,1);
  f.setPoint({longitude:0,latitude:0,height:100});f.manager.tick(true);assert.equal(f.models.length,1);f.manager.endAlignment('site');assert.equal(f.models.length,0);assert.equal(f.manager.snapshot()[0].enabled,false);assert.equal(f.writes.length,0);
 }finally{f.manager.dispose();}
});
test('cancel restores a terrain-calibrated result without resetting its altitude',async()=>{
 const key={},f=fixture({item:{heightAlignmentMode:'terrain',groundReferenceLocalUp:0,requireGroundCalibration:true},terrainKey:()=>key,sampleGround:async()=>82});
 try{await f.manager.initialize();for(let i=0;i<4;i++){await flush();f.manager.tick(true);}const initial=f.manager.snapshot()[0];assert.equal(initial.heightState,'adjusted');assert.equal(initial.effectiveAlignment.ellipsoidHeightM,82);
  f.manager.beginAlignment('site');f.manager.previewAlignment('site',{...pose,ellipsoidHeightM:300},[]);f.manager.endAlignment('site');assert.deepEqual(f.manager.snapshot()[0].effectiveAlignment,initial.effectiveAlignment);assert.equal(f.manager.snapshot()[0].heightState,'adjusted');
 }finally{f.manager.dispose();}
});
test('models finishing during a draft use its newest transform, then restore on cancel',async()=>{
 let finish;const promise=new Promise(r=>finish=r),f=fixture({modelFactory:()=>promise});try{await f.manager.initialize();f.manager.beginAlignment('site');const a={...pose,scale:3,rotationDeg:55};f.manager.previewAlignment('site',a,[]);const model={ready:true,destroy(){}};finish(model);await flush();f.manager.tick(true);assert.equal(model.scale,3);assert.ok(C.Matrix4.equalsEpsilon(model.modelMatrix,M.matrix(C,{...a,scale:1}),1e-7));f.manager.endAlignment('site');assert.equal(model.scale,1);
 }finally{f.manager.dispose();}
});
test('selection resolves owned model primitives and ignores unrelated globe objects',async()=>{
 const f=fixture();try{await f.manager.initialize();await flush();assert.equal(f.manager.selectedScenery(f.models[0]),'site');assert.equal(f.manager.selectedScenery({}),null);}finally{f.manager.dispose();}
});
test('mixed 3D Tiles, local visuals and collision assets receive the same world correction',async()=>{
 const T=require('../../web/features/scenery/scenery_tileset_provider.js'),pivot=C.Cartesian3.fromDegrees(pose.longitude,pose.latitude,pose.ellipsoidHeightM),options={version:'1.1',cachePolicy:'no-store',maximumScreenSpaceError:16,boundingSphere:{center:[pivot.x,pivot.y,pivot.z],radiusM:50},correction:{}};
 const remote={kind:'3d-tiles',url:'https://example.invalid/tileset.json',options},f=fixture({item:{assets:[remote,{kind:'glb',path:'test.glb'}]},tilesetFactory:async()=>({modelMatrix:C.Matrix4.clone(C.Matrix4.IDENTITY),destroy(){},tileLoad:new C.Event(),tileFailed:new C.Event(),allTilesLoaded:new C.Event()})});
 try{await f.manager.initialize();await flush();await flush();f.manager.tick(true);f.manager.beginAlignment('site');const c={eastM:12,northM:8,upM:4,headingDeg:25,pitchDeg:10,rollDeg:-5,scale:1.4},d=T.correctionMatrix(C,pose,c);f.manager.previewAlignment('site',pose,[{correction:c}]);
  assert.ok(C.Matrix4.equalsEpsilon(f.models[0].modelMatrix,d,1e-7));const local=f.models[1],actual=C.Matrix4.multiplyByUniformScale(local.modelMatrix,local.scale,new C.Matrix4()),expected=C.Matrix4.multiply(d,M.matrix(C,pose),new C.Matrix4());assert.ok(C.Matrix4.equalsEpsilon(actual,expected,1e-7));
  const geo=p=>{const world=C.Matrix4.multiplyByPoint(d,M.point(C,pose,p),new C.Cartesian3()),g=M.geographic(C,world);return {longitude:g.longitude,latitude:g.latitude,height:g.ellipsoidHeightM};};assert.ok(f.manager.collision(geo({x:-20,y:0,z:0}),geo({x:20,y:0,z:0})));
  f.manager.endAlignment('site');assert.ok(C.Matrix4.equals(f.models[0].modelMatrix,C.Matrix4.IDENTITY));assert.ok(C.Matrix4.equalsEpsilon(local.modelMatrix,M.matrix(C,pose),1e-7));
 }finally{f.manager.dispose();}
});
