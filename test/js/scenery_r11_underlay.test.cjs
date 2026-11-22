'use strict';
const {test}=require('node:test'),assert=require('node:assert/strict');
const fs=require('node:fs'),path=require('node:path');
const M=require('../../web/scenery_manager.js');
const Coll=require('../../web/scenery_collision.js');
const catalog=require('../../web/assets/scenery/catalog.json');
const base=path.resolve(__dirname,'../../web/assets/scenery');
const meshFor=(file)=>{const b=fs.readFileSync(path.join(base,file));return Coll.parse(b.buffer.slice(b.byteOffset,b.byteOffset+b.byteLength));};
const tick=()=>new Promise(r=>setImmediate(r));
function fixture(){
 let p={...catalog.sceneries[0].alignment,height:100};const models=[];
 class Matrix4{};Matrix4.fromRotationTranslation=x=>x;Matrix4.multiply=(a,b)=>({a,b});
 const C={Cartesian3:{fromDegrees:(...v)=>v},Transforms:{eastNorthUpToFixedFrame:x=>x},Matrix3:{fromRotationZ:x=>x},Matrix4,Math:{toRadians:v=>v*Math.PI/180},Color:class{constructor(...v){this.values=v;}},Credit:class{constructor(...v){this.values=v;}}};
 const viewer={scene:{primitives:{add:x=>models.push(x),remove:x=>{const i=models.indexOf(x);if(i>=0)models.splice(i,1);x.destroy?.();}},preUpdate:{addEventListener:()=>()=>{}},requestRender(){}},cesiumWidget:{creditDisplay:{addStaticCredit(){},removeStaticCredit(){}}}};
 return {C,viewer,models,position:()=>p,canLoad:()=>true,now:()=>Date.now(),setPosition:x=>{p=x;}};
}
const sleep=ms=>new Promise(r=>setTimeout(r,ms));
async function until(predicate,n=250){for(let i=0;i<n;i++){if(predicate())return;await sleep(10);}throw Error('Timeout waiting for scenery async state');}

// Keep one authentic collider for each dataset. A real FPC parse validates
// all BVH bounds, leaf ranges, triangle indices, and binary bounds.
const scan=meshFor('local_reference.fpc');const dem=meshFor('ruedersdorf_r11_ground.fpc');
const overlay=catalog.sceneries[0].terrainUnderlay.certificate;
const overlaypoly=JSON.stringify(M.normalizeTerrainCertificate(overlay,catalog.sceneries[0].alignment).polygon);

test('R11 calibrated underlay is independent of the original R8 collision geometry',()=>{
 assert.ok(scan.triangleCount>900000);assert.equal(dem.triangleCount,153928);
 assert.notEqual(overlay.collisionSha256,catalog.sceneries[0].terrainCertificate.collisionSha256);
 assert.equal(catalog.sceneries[0].clipTerrain,false,'Experiment remains opt-in');
 assert.equal(catalog.sceneries[0].terrainRegions.length,17);
 assert.equal(JSON.stringify(catalog.sceneries[0].terrainRegions.at(-1)),overlaypoly);
 assert.equal(M.validate(catalog)[0].terrainUnderlay.certificate.source,'underlay');
 const fail=structuredClone(catalog);fail.sceneries[0].terrainUnderlay.asset='../bad.glb';assert.throws(()=>M.validate(fail));
 const fail2=structuredClone(catalog);fail2.sceneries[0].terrainUnderlay.certificate.collisionSha256='00'.repeat(32);assert.doesNotThrow(()=>M.validate(fail2));
});

test('R11 DGM ground coverage is continuous inside the certified model-local rectangular perimeter',()=>{
 const c=overlay,b=c.localBounds;const z=c.localGroundRange;
 for(let j=0;j<=10;j++)for(let i=0;i<=10;i++){
  const x=b[0]+(.04+(i/10)*.92)*(b[2]-b[0]),y=b[1]+(.04+(j/10)*.92)*(b[3]-b[1]);
  const got=M.groundLocal(dem,c,[x,y,-2]);
  assert.ok(Number.isFinite(got)&&got>z[0]&&got<z[1],`missing ground ${i} ${j}`);
 }
});

test('R11 opt-in underlay stays hidden before clipping; passes matching live terrain seam and unloads safely',async()=>{
 const f=fixture();let provider={name:'regional'};let maskActive=false;let perturb=0;const alignment=M.terrainAligned(catalog.sceneries[0],79.8206323739);
 const frame=Coll.transform(alignment);
 const sampleSeamGround=async(points)=>points.map(q=>{
  const seed=79.8206323739;const p=frame.local({...q,height:seed});
  const z=M.groundLocal(dem,overlay,p);
  if(!Number.isFinite(z))throw Error('Offline test seam unavailable');
  return seed+(z-p[2])*frame.scale+perturb;
 });
 const mgr=M.create(f.C,f.viewer,{position:f.position,terrainKey:()=>provider,terrainStable:()=>true,
  fetchCatalog:async()=>catalog,modelFactory:async(url)=>({source:url,show:true,ready:true,destroy(){this.destroyed=true;}}),
  collisionFactory:async(url)=>url.endsWith('ruedersdorf_r11_ground.fpc')?dem:scan,
  sampleGround:async()=>79.8206323739,sampleSeamGround,terrainMaskActive:poly=>maskActive&&JSON.stringify(poly)===overlaypoly,
  setTimer:(fn,ms)=>setTimeout(fn,ms),clearTimer:clearTimeout});
 try{
  await mgr.initialize();await until(()=>mgr.snapshot()[0].collisionState==='ready');mgr.tick(true);
  assert.equal(mgr.snapshot()[0].groundUnderlayState??'idle','idle');assert.equal(f.models.length,1);
  const e=mgr.snapshot()[0];mgr.setEdit(e.id,{alignment:e.alignment,heightOffsetM:0,buildingRegions:e.buildingRegions,terrainRegions:e.terrainRegions,replaceBuildings:true,clipTerrain:true});
  await until(()=>mgr.snapshot()[0].groundUnderlayState==='ready');
  await until(()=>{mgr.tick(true);return mgr.snapshot()[0].terrainSeamState==='checked'});
  assert.equal(mgr.snapshot()[0].terrainReplacementApproved,1,'Large perimeter replaces small certified fallback patches');
  const model=f.models.find(x=>x.source.endsWith('ruedersdorf_r11_ground.glb'));
  assert.ok(model,'Underlay glTF must be attached');
  assert.equal(model.show,false,'No clipping: no rendered duplicate ground');
  maskActive=true;mgr.tick(true);assert.equal(model.show,true);
  assert.equal(mgr.snapshot()[0].groundUnderlayVisible,true);
  const center={longitude:alignment.longitude,latitude:alignment.latitude};
  const h=(await sampleSeamGround([center]))[0];
  assert.ok(Math.abs(mgr.replacementHeight({...center,height:h+1},poly=>JSON.stringify(poly)===overlaypoly)-(h))<.2);
  // The outer 1-m DEM collar is outside the original photogrammetric site.
  // Its vertical contact must exist only when the actual owned terrain mask
  // is active, not while the independent DGM is hidden.
  const A=require('../../web/scenery_alignment.js');const angle=-alignment.rotationDeg*Math.PI/180;
  const spot=A.offset(alignment,alignment.scale*8.73*Math.cos(angle),alignment.scale*8.73*Math.sin(angle));
  const ground=(await sampleSeamGround([spot]))[0];
  const from={...spot,height:ground+3},to={...spot,height:ground-3};
  assert.ok(mgr.collision(from,to),'Masked DGM underlay must have an actual physical contact');
  maskActive=false;mgr.tick(true);assert.equal(model.show,false);
  assert.equal(mgr.collision(from,to),false,'No hidden DGM collider when clipping is absent');
  // A failed provider seam has to undo the full-site mask; the old certified
  // R8 small patches may still be assessed separately.
  provider={name:'changed'};perturb=1.0;mgr.tick(true);await until(()=>{mgr.tick(true);return mgr.snapshot()[0].terrainSeamState==='checked'});
  assert.equal(mgr.activeRegions('terrain').some(p=>JSON.stringify(p)===overlaypoly),false);
  assert.equal(model.show,false);
  mgr.setEnabled(e.id,false);mgr.tick(true);
  assert.equal(mgr.snapshot()[0].groundUnderlayState,'idle');assert.equal(f.models.length,0);
 }finally{mgr.dispose();}
});
