'use strict';
const fs=require('node:fs'),path=require('node:path'),test=require('node:test'),assert=require('node:assert/strict');
const C=require('../../web/features/scenery/scenery_collision.js'),M=require('../../web/features/scenery/scenery_manager.js');
const raw=fs.readFileSync(path.resolve(__dirname,'../../web/assets/scenery/local_reference.fpc'));
const mesh=C.parse(raw.buffer.slice(raw.byteOffset,raw.byteOffset+raw.byteLength));
const item=M.validate(require('../../web/assets/scenery/catalog.json'))[0],cert=item.terrainCertificate,R=.25/item.alignment.scale;
test('R7 FPC exact hash and catalog configuration',async()=>{assert.equal(await M.verifyTerrainAsset(mesh,cert),true);assert.equal(await M.verifyTerrainAsset(mesh,{...cert,collisionSha256:'0'.repeat(64)}),false);assert.equal(item.clipTerrain,false);assert.deepEqual(item.terrainRegions.slice(0,item.terrainCertificates.length),item.terrainCertificates.map(c=>c.polygon));assert.deepEqual(item.terrainRegions[item.terrainCertificates.length],M.normalizeTerrainCertificate(item.terrainUnderlay.certificate,item.alignment).polygon);});
test('R7 ground coverage sampled on 21x21 grid, each vertical sweep lands on physical surface',()=>{
  const [x0,y0,x1,y1]=cert.localBounds;
  for(let i=0;i<=20;i++)for(let j=0;j<=20;j++){
    const x=x0+(x1-x0)*i/20,y=y0+(y1-y0)*j/20;
    const z=M.groundLocal(mesh,cert,[x,y,0]);assert.ok(Number.isFinite(z),`${x},${y} uncovered`);assert.ok(C.sweep(mesh,[x,y,cert.localGroundRange[1]+.05],[x,y,cert.localGroundRange[0]-.05],R));
  }
});
test('R7 margin deliberately excludes edges of certified terrain',()=>{const [x0,y0,x1,y1]=cert.localBounds;const p=[(x0+x1)/2,(y0+y1)/2,-2];assert.ok(M.insideGroundPatch(p,cert,item.alignment.scale));for(const q of [[x0,p[1],p[2]],[x1,p[1],p[2]],[p[0],y0,p[2]],[p[0],y1,p[2]],[x0-.1,p[1],p[2]]])assert.equal(M.insideGroundPatch(q,cert,item.alignment.scale),false);});
test('R7 runtime replacement is opt-in, asset verified, bounded and invalidated by edit or unload',async()=>{
 const A=require('../../web/features/scenery/scenery_alignment.js'),fixture=require('../../web/assets/scenery/catalog.json'),key={};
 class Matrix4{};Matrix4.fromRotationTranslation=x=>x;Matrix4.multiply=(a,b)=>({a,b});
 const Cesium={Cartesian3:{fromDegrees:(...v)=>v},Transforms:{eastNorthUpToFixedFrame:x=>x},Matrix3:{fromRotationZ:x=>x},Matrix4,Math:{toRadians:v=>v*Math.PI/180},Color:class{},Credit:class{}};
 const viewer={scene:{primitives:{add(){},remove(){}},preUpdate:{addEventListener:()=>()=>{}},requestRender(){}}};
 const autoFixture=structuredClone(fixture);autoFixture.sceneries[0].heightAlignmentMode='terrain';delete autoFixture.sceneries[0].heightCalibration;
 const scene=M.create(Cesium,viewer,{fetchCatalog:async()=>autoFixture,position:()=>({...item.alignment,height:60}),modelFactory:async()=>({ready:true}),collisionFactory:async()=>mesh,terrainKey:()=>key,sampleGround:async()=>60,sampleSeamGround:async points=>{const frame=C.transform(M.terrainAligned(item,60));return points.map(p=>{const l=frame.local({...p,height:60}),z=M.groundLocal(mesh,cert,l);return 60+(z-l[2])*frame.scale;});}});
 const sleep=()=>new Promise(r=>setTimeout(r,10));
 try{
  await scene.initialize();await sleep();scene.tick(true);await sleep();scene.tick(true);
  assert.equal(scene.activeRegions('terrain',true).length,0);
  const id=item.id;const edit={alignment:item.alignment,heightOffsetM:0,terrainRegions:[cert.polygon],buildingRegions:item.buildingRegions,clipTerrain:true,replaceBuildings:true};scene.setEdit(id,edit);
  for(let i=0;i<100&&!scene.snapshot()[0].terrainReplacementReady;i++){await sleep();scene.tick(true);}
  assert.equal(scene.snapshot()[0].terrainReplacementReady,true);assert.deepEqual(scene.activeRegions('terrain',true),[cert.polygon]);
  const pos=(x,y,height)=>{const a=item.alignment,theta=-a.rotationDeg*Math.PI/180;return {...A.offset(a,a.scale*(Math.cos(theta)*x-Math.sin(theta)*y),a.scale*(Math.sin(theta)*x+Math.cos(theta)*y)),height};};
  const [x0,y0,x1,y1]=cert.localBounds,a=pos((x0+x1)/2,(y0+y1)/2,61),b=pos(x1-.12,(y0+y1)/2,61),outside=pos(x1+.2,(y0+y1)/2,61);
  assert.ok(Number.isFinite(scene.replacementHeight(a,()=>true)));assert.equal(scene.replacementHeight(a,()=>false),undefined);assert.equal(scene.replacementPassage(a,b,()=>true),true);assert.equal(scene.replacementPassage(a,b,()=>false),false);assert.equal(scene.replacementPassage(a,outside,()=>true),false);
  scene.setEdit(id,{...edit,heightOffsetM:.25});assert.equal(scene.activeRegions('terrain',true).length,0);assert.equal(scene.replacementHeight(a,()=>true),undefined);
  scene.setEdit(id,edit);for(let i=0;i<100&&!scene.snapshot()[0].terrainReplacementReady;i++){await sleep();scene.tick(true);}assert.equal(scene.activeRegions('terrain',true).length,1);scene.setEnabled(id,false);assert.equal(scene.activeRegions('terrain',true).length,0);
 }finally{scene.dispose();}
});
test('R7 regional mask queried only when the owned collection is installed, restored on invalidation',async()=>{
 const R=require('../../web/features/terrain/regional_3d.js');let busy=false,verified=false,online=true,ready=true;
 const globe={clippingPolygons:undefined},viewer={scene:{globe,primitives:{add(){},remove(){}},preUpdate:{addEventListener:()=>()=>{}},requestRender(){}}};
 const Cesium={Cartesian3:{fromDegrees:(...p)=>p},ClippingPolygon:class{constructor(o){Object.assign(this,o);}},ClippingPolygonCollection:class{static isSupported(){return true;}constructor(o){Object.assign(this,o);}}};
 const r=R.create(Cesium,viewer,{enabled:true,online:()=>online,terrainReady:()=>ready,navigationBusy:()=>busy,position:()=>({...item.alignment,height:100}),terrainRegions:()=>[],flightTerrainRegions:()=>verified?[cert.polygon]:[]});
 try{r.tick(true);assert.equal(r.terrainMaskActive(cert.polygon),false);busy=true;verified=true;r.tick(true);assert.ok(r.terrainMaskActive(cert.polygon));assert.equal(r.terrainMaskActive([]),false);ready=false;assert.equal(r.terrainMaskActive(cert.polygon),false);r.tick(true);assert.equal(globe.clippingPolygons,undefined);ready=true;r.tick(true);assert.ok(r.terrainMaskActive(cert.polygon));const foreign={};globe.clippingPolygons=foreign;assert.equal(r.terrainMaskActive(cert.polygon),false);r.tick(true);assert.equal(globe.clippingPolygons,foreign);online=false;assert.equal(r.terrainMaskActive(cert.polygon),false);}finally{r.dispose();}
});
