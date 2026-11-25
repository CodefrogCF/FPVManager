'use strict';
const {test}=require('node:test');
const assert=require('node:assert/strict');
const M=require('../../web/features/scenery/scenery_manager.js');
const A=require('../../web/features/scenery/scenery_alignment.js');
const Collision=require('../../web/features/scenery/scenery_collision.js');
const bundle=require('../../web/assets/scenery/catalog.json');
const flush=()=>new Promise(resolve=>setImmediate(resolve));
function scene(id='synthetic-site'){
  const item=structuredClone(bundle.sceneries[0]);
  Object.assign(item,{id,name:id,alignment:{...A.DEFAULT,longitude:13.8,latitude:52.4,ellipsoidHeightM:100,scale:1,opacity:1},
    assets:[{kind:'glb',path:'synthetic.glb'}],collisionAsset:'floor.fpc',heightAlignmentMode:'fixed',requireGroundCalibration:false,
    replaceBuildings:false,clipTerrain:false,terrainRegions:[],buildingRegions:[],heightOffsetM:0,bkgHeightOffsetM:0});
  for(const key of ['heightCalibration','terrainCertificate','terrainCertificates','terrainUnderlay'])delete item[key];
  return item;
}
function catalog(...sceneries){return {schemaVersion:1,sceneries,unavailable:[]};}
function fixture(options={}){
  const primitives=new Set(),credits=new Set();let loads=0;
  class Matrix4{};Matrix4.fromRotationTranslation=x=>x;Matrix4.multiply=(a,b)=>({a,b});
  const C={Cartesian3:{fromDegrees:(...v)=>v},Transforms:{eastNorthUpToFixedFrame:x=>x},
    Matrix3:{fromRotationZ:x=>x,fromRowMajorArray:x=>x},Matrix4,Math:{toRadians:v=>v*Math.PI/180},
    Color:class{},Credit:class{}};
  const viewer={scene:{primitives:{add:x=>primitives.add(x),remove:x=>{primitives.delete(x);x.destroy?.();}},
    preUpdate:{addEventListener:()=>()=>{}},requestRender(){}},cesiumWidget:{creditDisplay:{addStaticCredit:x=>credits.add(x),removeStaticCredit:x=>credits.delete(x)}}};
  const manager=M.create(C,viewer,{fetchCatalog:async()=>catalog(),position:()=>({longitude:13.8,latitude:52.4,height:100}),
    modelFactory:async()=>{loads++;return {ready:true,destroy(){this.destroyed=true;}};},
    collisionFactory:async()=>floor(0),...options});
  return {manager,primitives,credits,loads:()=>loads};
}
function floor(z){
  const vertices=[-100,-100,z,100,-100,z,100,100,z,-100,100,z],indices=[0,1,2,0,2,3];
  const b=new ArrayBuffer(16+vertices.length*4+indices.length*4+32),h=new DataView(b);
  [0x31435046,4,2,1].forEach((v,i)=>h.setUint32(i*4,v,true));
  new Float32Array(b,16,12).set(vertices);new Uint32Array(b,64,6).set(indices);
  new Float32Array(b,88,6).set([-100,-100,z,100,100,z]);new Int32Array(b,112,2).set([-1,2]);
  return Collision.parse(b);
}
test('bundled catalog bootstrap is isolated from runtime edits and intentional removals',async()=>{
  const original=catalog(scene('bundled'));
  const f=fixture({fetchCatalog:async()=>original}),m=f.manager;
  try{
    assert.throws(()=>m.bundledCatalog(),/unavailable/);
    await m.initialize();const data=m.bundledCatalog();data.sceneries[0].name='Modified externally';
    assert.equal(m.bundledCatalog().sceneries[0].name,'bundled');
    m.replaceCatalog(catalog());assert.deepEqual(m.snapshot(),[]);
    assert.equal(m.bundledCatalog().sceneries[0].id,'bundled');
  }finally{m.dispose();}
});
test('catalog CRUD retains unchanged model identity, independently enables peers and releases deleted scenes',async()=>{
  const f=fixture(),m=f.manager;
  try{
    await m.initialize();m.replaceCatalog(catalog(scene()));await flush();m.tick(true);await flush();
    assert.equal(m.snapshot()[0].state,'ready');const model=[...f.primitives][0];
    m.replaceCatalog(catalog(scene()));assert.equal(f.loads(),1);assert.equal([...f.primitives][0],model);
    const other=scene('other');other.enabled=false;m.replaceCatalog(catalog(scene(),other));
    assert.equal(m.snapshot().find(x=>x.id==='other').enabled,false);assert.equal(f.loads(),1);
    const disabled=scene();disabled.enabled=false;m.replaceCatalog(catalog(disabled,other));assert.equal(f.primitives.size,0);
    m.replaceCatalog(catalog(scene(),other));await flush();m.tick(true);assert.equal(f.loads(),2);
    m.replaceCatalog(catalog());assert.equal(f.primitives.size,0);assert.equal(f.credits.size,0);assert.deepEqual(m.snapshot(),[]);
  }finally{m.dispose();}
});
test('native persistence handover with explicit defaults does not load the bundled model twice',async()=>{
  const initial=catalog(scene());
  const f=fixture({fetchCatalog:async()=>initial}),m=f.manager;
  try{
    await m.initialize();await flush();m.tick(true);const model=[...f.primitives][0];
    const item=scene();item.alignment={...item.alignment,pitchDeg:0,rollDeg:0};
    item.collisionAssets=[item.collisionAsset];item.attribution=`${item.author} · ${item.license}`;
    m.replaceCatalog(catalog(item));await flush();m.tick(true);
    assert.equal(f.loads(),1);assert.equal([...f.primitives][0],model);
    item.author='Updated author';m.replaceCatalog(catalog(item));await flush();m.tick(true);
    assert.equal(f.loads(),2,'changed provenance refreshes the rendered credit');
  }finally{m.dispose();}
});
test('unavailable providers and invalid optional scenes cannot block a valid scene',async()=>{
  const f=fixture(),m=f.manager;
  try{
    const invalid=scene('broken');invalid.alignment.scale=0;
    const input=catalog(scene(),invalid);input.unavailable=[{id:'future',name:'Future',enabled:true,message:'Provider unavailable'}];
    m.replaceCatalog(input);await flush();m.tick(true);
    assert.equal(m.snapshot().find(x=>x.id==='synthetic-site').state,'ready');
    assert.equal(m.snapshot().find(x=>x.id==='broken').state,'error');
    assert.equal(m.snapshot().find(x=>x.id==='future').state,'unavailable');assert.equal(f.loads(),1);
    assert.throws(()=>m.replaceCatalog({...catalog(scene()),unavailable:[{id:'synthetic-site'}]}),/duplicate/);
    assert.equal(m.snapshot().length,3,'invalid whole-catalog update must be atomic');
  }finally{m.dispose();}
});
test('late initial catalog and late model loads cannot restore removed scenes',async()=>{
  let resolveCatalog,resolveModel;
  const f=fixture({fetchCatalog:()=>new Promise(r=>resolveCatalog=r),modelFactory:()=>new Promise(r=>resolveModel=r)}),m=f.manager;
  const init=m.initialize();m.replaceCatalog(catalog(scene()));await flush();m.replaceCatalog(catalog());
  const late={ready:true,destroy(){this.destroyed=true;}};resolveModel(late);resolveCatalog(catalog(scene('old')));
  await init;await flush();assert.equal(late.destroyed,true);assert.deepEqual(m.snapshot(),[]);assert.equal(f.primitives.size,0);m.dispose();
});
test('multiple independent collision assets select the earliest sweep contact',async()=>{
  const f=fixture({collisionFactory:async path=>floor(path.endsWith('upper.fpc')?10:0)}),m=f.manager;
  try{
    const item=scene();item.collisionAssets=['floor.fpc','upper.fpc'];
    m.replaceCatalog(catalog(item));await flush();m.tick(true);await flush();
    assert.equal(m.snapshot()[0].collisionReady,true);
    const hit=m.collision({longitude:13.8,latitude:52.4,height:130},{longitude:13.8,latitude:52.4,height:70});
    assert.ok(hit&&hit.fraction<.34&&hit.fraction>.3,'upper floor is hit before the primary lower floor');
  }finally{m.dispose();}
});
test('failure of a secondary collider never activates a partially loaded collider set',async()=>{
  const f=fixture({collisionFactory:async path=>{if(path.endsWith('missing.fpc'))throw Error('Missing collider');return floor(0);}}),m=f.manager;
  try{
    const item=scene();item.collisionAssets=['floor.fpc','missing.fpc'];
    m.replaceCatalog(catalog(item));await flush();m.tick(true);await flush();
    assert.equal(m.snapshot()[0].collisionState,'error');assert.equal(m.snapshot()[0].collisionReady,false);
    assert.equal(m.collision({longitude:13.8,latitude:52.4,height:130},{longitude:13.8,latitude:52.4,height:70}),false);
  }finally{m.dispose();}
});
test('heading pitch and roll share a rigid visual/collision frame with correct axis signs',()=>{
  const base={...A.DEFAULT,longitude:0,latitude:0,ellipsoidHeightM:0,scale:1};
  const rolled=Collision.transform({...base,rollDeg:90});
  const n=rolled.normal([0,1,0]);assert.ok(Math.abs(n.east)<1e-12&&Math.abs(n.north)<1e-12&&Math.abs(n.up-1)<1e-12);
  const pitched=Collision.transform({...base,pitchDeg:90});assert.ok(pitched.normal([1,0,0]).up>.999999);
  const rotated={...base,rotationDeg:73,pitchDeg:24,rollDeg:-31};
  const r=A.rotationMatrix(rotated),frame=Collision.transform(rotated),normal=frame.normal([0,0,1]);
  assert.deepEqual([normal.east,normal.north,normal.up],[r[2],r[5],r[8]]);
  assert.ok(Math.abs(Math.hypot(normal.east,normal.north,normal.up)-1)<1e-12);
  const local=frame.local({longitude:0,latitude:0,height:10});
  assert.ok(Math.abs(Math.hypot(...local)-10)<1e-8);
  assert.throws(()=>A.normalize({...base,pitchDeg:91}),/Invalid/);
});
test('visual and CPU rotations match the pinned Cesium HPR implementation',()=>{
  const fs=require('node:fs'),vm=require('node:vm');
  const scope={console,setTimeout,clearTimeout,URL,TextDecoder,TextEncoder,atob,btoa,
    TransformStream,ReadableStream,WritableStream,AbortController,Blob};scope.global=scope;
  const C=vm.runInNewContext(fs.readFileSync(require.resolve('../../web/cesium/Cesium.js'),'utf8')+';Cesium',scope);
  for(const [heading,pitch,roll] of [[0,0,0],[73,24,-31],[90,0,0],[0,90,0],[0,0,90],[-123,-45,160]]){
    const cfg={...A.DEFAULT,rotationDeg:heading,pitchDeg:pitch,rollDeg:roll};
    const actual=C.Matrix3.fromHeadingPitchRoll(new C.HeadingPitchRoll(...[heading,pitch,roll].map(C.Math.toRadians)));
    const rotation=C.Matrix3.fromRowMajorArray(A.rotationMatrix(cfg));
    assert.ok(C.Matrix3.equalsEpsilon(actual,rotation,1e-14));
    const matrix=A.modelMatrix(C,cfg);
    const enu=C.Transforms.eastNorthUpToFixedFrame(C.Cartesian3.fromDegrees(cfg.longitude,cfg.latitude,cfg.ellipsoidHeightM));
    const expected=C.Matrix4.multiply(enu,C.Matrix4.fromRotationTranslation(actual),new C.Matrix4());
    assert.ok(C.Matrix4.equalsEpsilon(matrix,expected,1e-12));
  }
});
