'use strict';
const fs=require('node:fs'),path=require('node:path'),test=require('node:test'),assert=require('node:assert/strict');
const M=require('../../web/scenery_manager.js'),C=require('../../web/scenery_collision.js'),R=require('../../web/regional_3d.js'),A=require('../../web/scenery_alignment.js');
const raw=fs.readFileSync(path.resolve(__dirname,'../../web/assets/scenery/local_reference.fpc'));
const mesh=C.parse(raw.buffer.slice(raw.byteOffset,raw.byteOffset+raw.byteLength));
const catalog=require('../../web/assets/scenery/catalog.json'),item=M.validate(catalog)[0],certs=item.terrainCertificates,radius=.25/item.alignment.scale;
const wait=()=>new Promise(r=>setTimeout(r,10));
const autoCatalog=structuredClone(catalog);autoCatalog.sceneries[0].heightAlignmentMode='terrain';delete autoCatalog.sceneries[0].heightCalibration;
const expectedHeight=60,frame=C.transform(M.terrainAligned(item,expectedHeight));
function sampleFor(c,p){const l=frame.local({...p,height:expectedHeight});const z=M.groundLocal(mesh,c,l);return Number.isFinite(z)?expectedHeight+(z-l[2])*frame.scale:NaN;}
function dummy(){
 class Matrix4{};Matrix4.fromRotationTranslation=x=>x;Matrix4.multiply=(a,b)=>({a,b});
 const Cesium={Cartesian3:{fromDegrees:(...v)=>v},Transforms:{eastNorthUpToFixedFrame:x=>x},Matrix3:{fromRotationZ:x=>x},Matrix4,Math:{toRadians:v=>v*Math.PI/180},Color:class{},Credit:class{}};
 const viewer={scene:{primitives:{add(){},remove(){}},preUpdate:{addEventListener:()=>()=>{}},requestRender(){}}};return {Cesium,viewer};
}
async function until(m,predicate){for(let i=0;i<200;i++){m.tick(true);if(predicate(m.snapshot()[0]))return;await wait();}assert.fail('Timed out waiting for scenery state');}
test('R8 certified terrain regions share the exact asset hash, final alignment, opt-in default',async()=>{
 assert.equal(certs.length,15);assert.equal(await M.verifyTerrainAsset(mesh,certs[0]),true);assert.ok(mesh.triangleCount>900000);assert.equal(item.clipTerrain,false);assert.equal(item.alignment.scale,16.023268178233355);assert.equal(item.alignment.rotationDeg,99.7993823133657);assert.deepEqual(item.terrainRegions.slice(0,item.terrainCertificates.length),certs.map(c=>c.polygon));assert.deepEqual(item.terrainRegions[item.terrainCertificates.length],M.normalizeTerrainCertificate(item.terrainUnderlay.certificate,item.alignment).polygon);
 const bad=structuredClone(catalog);bad.sceneries[0].terrainCertificates[1].collisionSha256='0'.repeat(64);assert.throws(()=>M.validate(bad));
 const bad2=structuredClone(catalog);bad2.sceneries[0].terrainCertificates[1].seamToleranceM=10;assert.throws(()=>M.validate(bad2));
});
for(const [i,c] of certs.entries())test(`R8 region ${i+1}: 121 ground queries and 121 swept-sphere vertical landing checks`,()=>{
 const [x0,y0,x1,y1]=c.localBounds;for(let x=0;x<=10;x++)for(let y=0;y<=10;y++){
  const p=[x0+(x1-x0)*x/10,y0+(y1-y0)*y/10,0];assert.ok(Number.isFinite(M.groundLocal(mesh,c,p)),`no mesh at ${p}`);assert.ok(C.sweep(mesh,[p[0],p[1],c.localGroundRange[1]+.05],[p[0],p[1],c.localGroundRange[0]-.05],radius));
 }
});
test('R8 continuous union interval coverage across overlapping insets and refusal across gaps/exterior',()=>{
 const a={localBounds:[0,0,2,2]},b={localBounds:[1.8,0,4,2]},separate={localBounds:[2.2,0,4,2]};
 assert.ok(M.segmentCovered([.5,1,0],[3,1,0],[a,b],16));assert.ok(M.segmentCovered([3,1,0],[.5,1,0],[a,b],16));assert.equal(M.segmentCovered([.5,1,0],[3,1,0],[a,separate],16),false);assert.equal(M.segmentCovered([-.1,1,0],[3,1,0],[a,b],16),false);
 assert.ok(M.segmentCovered([1,1,0],[1,1,2],[a],16));assert.equal(M.segmentCovered([0,1,0],[0,1,2],[a],16),false);
});
test('R8 actual-mesh seam evaluation: matching synthetic samples pass, 1m offset and missing samples fail',()=>{
 let count=0;for(const c of certs){const points=M.seamPoints(c,item.alignment);count+=points.length;const heights=points.map(p=>sampleFor(c,p));assert.ok(heights.every(Number.isFinite));const approved=M.evaluateSeam(mesh,frame,c,points,heights);assert.equal(approved.approved,true);assert.ok(approved.maxErrorM<.01);assert.equal(M.evaluateSeam(mesh,frame,c,points,heights.map(y=>y+1)).approved,false);assert.equal(M.evaluateSeam(mesh,frame,c,points,[]).approved,false);}
 assert.ok(count<2048);console.log('R8 seam sample count',count);
});
test('R8 live seam gate admits compatible patches only, rejects moved alignment, provider change, late response and unload',async()=>{
 const {Cesium,viewer}=dummy();let key={},delta=0,pending=false,resolve=null;const c=certs[0];
 const m=M.create(Cesium,viewer,{fetchCatalog:async()=>autoCatalog,position:()=>({...item.alignment,height:100}),modelFactory:async()=>({ready:true}),collisionFactory:async()=>mesh,terrainKey:()=>key,sampleGround:async()=>expectedHeight,
 sampleSeamGround:points=>{const values=points.map(p=>sampleFor(c,p)+delta);if(!pending)return Promise.resolve(values);return new Promise(r=>{resolve=()=>r(values);});}});
 try{await m.initialize();await until(m,s=>s.collisionReady);const edit={alignment:item.alignment,heightOffsetM:0,terrainRegions:[c.polygon],buildingRegions:item.buildingRegions,clipTerrain:true,replaceBuildings:true};
  m.setEdit(item.id,edit);assert.equal(m.activeRegions('terrain').length,0);await until(m,s=>s.terrainSeamState==='checked');assert.equal(m.snapshot()[0].terrainReplacementApproved,1);assert.deepEqual(m.activeRegions('terrain',true),[c.polygon]);assert.deepEqual(m.activeRegions('terrain'),[c.polygon]);
  delta=1;key={};m.tick(true);assert.equal(m.activeRegions('terrain',true).length,0);await until(m,s=>s.terrainSeamState==='checked');assert.equal(m.snapshot()[0].terrainReplacementApproved,0);
  key={};delta=0;pending=true;m.tick(true);await until(m,()=>!!resolve);m.setEdit(item.id,{...edit,heightOffsetM:.5});resolve();await wait();m.tick(true);assert.equal(m.activeRegions('terrain',true).length,0);assert.equal(m.activeRegions('terrain').length,0);
  pending=false;m.setEdit(item.id,edit);await until(m,s=>s.terrainReplacementReady);m.setEnabled(item.id,false);assert.equal(m.activeRegions('terrain').length,0);
 }finally{m.dispose();}
});
test('R8 seam data unavailable: no terrain mask in map or flight',async()=>{
 const {Cesium,viewer}=dummy();const key={};const m=M.create(Cesium,viewer,{fetchCatalog:async()=>autoCatalog,position:()=>({...item.alignment,height:100}),modelFactory:async()=>({ready:true}),collisionFactory:async()=>mesh,terrainKey:()=>key,sampleGround:async()=>expectedHeight,sampleSeamGround:async()=>{throw Error('network');}});
 try{await m.initialize();await until(m,s=>s.collisionReady);m.setEdit(item.id,{...item,clipTerrain:true});await until(m,s=>s.terrainSeamState==='unavailable');assert.equal(m.activeRegions('terrain').length,0);assert.equal(m.activeRegions('terrain',true).length,0);}finally{m.dispose();}
});
test('R8 failed clipping collection replacement removes the old hole, foreign clipping preserved',()=>{
 let fail=false;let regions=[certs[0].polygon];const globe={clippingPolygons:undefined},viewer={scene:{globe,primitives:{add(){},remove(){}},preUpdate:{addEventListener:()=>()=>{}},requestRender(){}}};const Cesium={Cartesian3:{fromDegrees:(...p)=>p},ClippingPolygon:class{constructor(o){Object.assign(this,o);}},ClippingPolygonCollection:class{static isSupported(){return true;}constructor(o){if(fail)throw Error('simulated allocation failure');Object.assign(this,o);}}};
 const r=R.create(Cesium,viewer,{enabled:true,terrainReady:()=>true,position:()=>({...item.alignment,height:100}),terrainRegions:()=>regions});
 try{r.tick(true);assert.ok(r.terrainMaskActive(regions[0]));fail=true;regions=[certs[1].polygon];r.tick(true);assert.equal(globe.clippingPolygons,undefined);assert.equal(r.terrainMaskActive(certs[0].polygon),false);const foreign={};globe.clippingPolygons=foreign;r.tick(true);assert.equal(globe.clippingPolygons,foreign);}finally{r.dispose();}
});
