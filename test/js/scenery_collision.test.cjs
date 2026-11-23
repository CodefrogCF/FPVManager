'use strict';
const test=require('node:test'),assert=require('node:assert/strict');
const C=require('../../web/features/scenery/scenery_collision.js');
// Two disjoint wall panels, with a 2 m opening between them at y=[-1,1].
function fixture(){
 const v=[0,-4,-3,0,-1,-3,0,-1,3,0,-4,3,0,1,-3,0,4,-3,0,4,3,0,1,3];
 const t=[0,1,2,0,2,3,4,5,6,4,6,7];
 const bounds=[0,-4,-3,0,4,3,0,-4,-3,0,-1,3,0,1,-3,0,4,3];const children=[1,2,-1,2,-3,2];
 const b=new ArrayBuffer(16+4*(v.length+t.length+bounds.length+children.length));
 new Uint32Array(b,0,4).set([0x31435046,8,4,3]);let off=16;
 for(const [type,values] of [[Float32Array,v],[Uint32Array,t],[Float32Array,bounds],[Int32Array,children]]){new type(b,off,values.length).set(values);off+=4*values.length;}
 return b;
}
test('thin walls detect high speed sweeps from both sides with first hit and face normal',()=>{
 const m=C.parse(fixture());
 for(const sign of [-1,1]){
  const hit=C.sweep(m,[sign*20,-2,1],[-sign*20,-2,1],.25);assert.ok(hit);assert.ok(Math.abs(hit.fraction-19.75/40)<.0001);assert.deepEqual(hit.normal.map(x=>x||0),[sign,0,0]);
 }
});
test('gaps stay open, but swept rotor radius clips edges and coplanar grazing is detected',()=>{
 const m=C.parse(fixture());assert.equal(C.sweep(m,[-20,0,0],[20,0,0],.25),null);
 assert.ok(C.sweep(m,[-20,.9,0],[20,.9,0],.25));assert.ok(C.sweep(m,[.2,-6,0],[.2,6,0],.25));
 assert.equal(C.sweep(m,[.3,-6,0],[.3,6,0],.25),null);
 assert.ok(C.sweep(m,[0,-2,0],[0,-2,0],.25));
});
test('invalid asset header, index, bounds, leaf range or recursive structure are rejected',()=>{
 for(const corrupt of [b=>new Uint32Array(b)[0]=0,b=>new Uint32Array(b,16+96,1)[0]=999,b=>new Float32Array(b,16+96+48,1)[0]=1,b=>new Int32Array(b,b.byteLength-4,1)[0]=1,b=>new Int32Array(b,b.byteLength-24,1)[0]=0]){const b=fixture();corrupt(b);assert.throws(()=>C.parse(b));}
});
test('WGS84 transform shares anchor, altitude and clockwise heading with renderer',()=>{
 const a={longitude:13.789853720999993,latitude:52.48411904363446,ellipsoidHeightM:85,rotationDeg:90,scale:16};const f=C.transform(a);
 assert.ok(Math.hypot(...f.local({...a,height:85}))<1e-9);
 assert.ok(Math.abs(f.local({...a,height:101})[2]-1)<1e-9);
 const n=f.normal([1,0,0]);assert.ok(Math.abs(n.east)<1e-12&&Math.abs(n.north+1)<1e-12);
 assert.ok(f.local({...a,latitude:a.latitude+.0001,height:85})[0]<-.69);
});
test('contact adapter scales rotor sweep and reports normals to advanced physics',()=>{
 const m=C.parse(fixture());const frame={scale:2,local:p=>p.xyz,normal:n=>n?{east:n[0],north:n[1],up:n[2]}:null};
 const hit=C.contact(m,frame,{xyz:[-10,2,0]},{xyz:[10,2,0]});assert.equal(hit.kind,'scenery');assert.ok(hit.normal.east<-.99);assert.ok(Math.abs(hit.fraction-9.875/20)<.0001);
 assert.equal(C.contact(m,frame,{xyz:[-10,0,0]},{xyz:[10,0,0]}),false);
});

test('both flight physics modes use the scan sweep instead of crossing a thin roof',async()=>{
 const {createSimulator}=require('../../web/features/flight/free_flight.js');const m=C.parse(fixture());
 // Reorient the synthetic wall to a horizontal roof at 150 m, with spawn above a panel.
 const anchor={latitude:52.484119,longitude:13.789854};
 const frame={scale:1,local:p=>[p.height-150,-2+(p.longitude-anchor.longitude)*68000,1+(p.latitude-anchor.latitude)*111260],normal:n=>n?{up:n[0],east:n[1],north:n[2]}:null};
 for(const physicsModel of ['advanced','legacy']){
  let hits=0;const model=createSimulator({sampleHeight:async()=>100,renderedHeight:()=>100,captureCamera:()=>({heading:0}),restoreCamera:()=>{},applyPose:()=>{},isTerrainReady:()=>true,onState:()=>{},modeledCollision:(a,b)=>{const hit=C.contact(m,frame,a,b);if(hit)hits++;return hit;}});
  await model.start({...anchor,agl:60,flightMode:'acro',physicsModel},new AbortController().signal);
  try{model.flightInput({throttle:0});for(let i=0;i<600;i++){model.tick(1/120);assert.ok(model.status().height>=150.249,'must not penetrate the roof');}assert.ok(hits>0,physicsModel+' should contact roof');}finally{model.stop();}
 }
});
