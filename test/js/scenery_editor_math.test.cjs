'use strict';
const test=require('node:test'),assert=require('node:assert/strict'),C=require('../../web/cesium/index.cjs');
const M=require('../../web/features/scenery/scenery_editor_math.js'),T=require('../../web/features/scenery/scenery_tileset_provider.js');
const pose={longitude:13.8,latitude:52.4,ellipsoidHeightM:100,rotationDeg:38,pitchDeg:15,rollDeg:9,scale:1.7,opacity:1};
const near=(a,b,t=1e-6)=>assert.ok(Math.abs(a-b)<t,`${a} != ${b}`);
const sources=[[0,0,0],[20,0,0],[0,20,0],[5,0,15]];
function pairs(a=pose){return sources.map(([x,y,z])=>{const g=M.geographic(C,M.point(C,a,{x,y,z}));return {source:{x,y,z},target:{longitude:g.longitude,latitude:g.latitude,heightM:g.ellipsoidHeightM}};});}
test('numeric, graphical ENU moves and model coordinates share pinned Cesium matrices',()=>{
 const p=M.translate(C,pose,23,-17,8),o=M.xyz(C,pose),enu=M.frame(C,pose),expected=C.Matrix4.multiplyByPoint(enu,new C.Cartesian3(23,-17,8),new C.Cartesian3());assert.ok(C.Cartesian3.distance(M.xyz(C,p),expected)<1e-7);
 const s={x:3,y:4,z:5},roundtrip=M.local(C,pose,M.point(C,pose,s));for(const key of ['x','y','z'])near(roundtrip[key],s[key]);assert.equal(p.scale,pose.scale);assert.ok(C.Cartesian3.distance(o,expected)>20);
});
test('3D control points recover translation, heading, pitch, roll and uniform scale',()=>{
 const result=M.fit(C,{...pose,rotationDeg:0,pitchDeg:0,rollDeg:0,scale:1},pairs());for(const key of ['longitude','latitude','ellipsoidHeightM','rotationDeg','pitchDeg','rollDeg','scale'])near(result.alignment[key],pose[key]);assert.ok(result.rmsM<1e-7);assert.ok(result.maxM<1e-7);assert.equal(result.residualsM.length,4);
});
test('inconsistent control points report nonzero individual residuals and RMS',()=>{const p=pairs();p[3].target.heightM+=3;const result=M.fit(C,pose,p);assert.ok(result.rmsM>.2);near(result.rmsM,Math.sqrt(result.residualsM.reduce((n,v)=>n+v*v,0)/4));assert.ok(result.maxM>=result.rmsM);});
test('residual diagnostics measure the current placement after manual changes',()=>{const p=pairs();assert.ok(M.residuals(C,pose,p).rmsM<1e-7);const r=M.residuals(C,M.translate(C,pose,0,0,3),p);near(r.rmsM,3,.001);assert.equal(r.residualsM.length,4);});
test('planar noncollinear controls work; coincident and collinear controls fail',()=>{const planar=pairs().slice(0,3);assert.ok(M.fit(C,pose,planar).maxM<1e-7);for(const p of [Array(3).fill(planar[0]),[0,1,2].map(i=>({...planar[0],source:{x:i,y:0,z:0}}))])assert.throws(()=>M.fit(C,pose,p),/collinear/);});
test('control-point solver rejects missing heights, extreme or distant data',()=>{for(const mutate of [p=>delete p[0].target.heightM,p=>p[0].source.x=Infinity,p=>p[0].target.longitude=150,p=>p.length=2]){const p=pairs();mutate(p);assert.throws(()=>M.fit(C,pose,p));}});
test('control points remain stable across the antimeridian and at high latitude',()=>{for(const a of [{...pose,longitude:179.9999},{...pose,latitude:85}]){const result=M.fit(C,{...a,scale:1},pairs(a));near(result.alignment.scale,a.scale);assert.ok(result.rmsM<1e-6);}});
test('undo/redo is bounded, immutable and discards obsolete future edits',()=>{const h=M.history({x:0},3);for(let x=1;x<6;x++)h.set({x});assert.equal(h.undo().x,4);assert.equal(h.undo().x,3);assert.equal(h.undo().x,2);assert.equal(h.undo().x,2);assert.equal(h.redo().x,3);const v=h.value;v.x=9;assert.equal(h.value.x,3);h.set({x:7});assert.equal(h.canRedo,false);});
test('remote editor placement preserves source georeferencing and relative asset corrections',()=>{
 const pivot={longitude:13.8,latitude:52.4,heightM:100},base={eastM:10,northM:20,upM:3,headingDeg:15,pitchDeg:2,rollDeg:1,scale:1.1};
 const doc={anchor:pivot,assets:[{id:'a',provider:'remote-tiles',tileset:{correction:base}},{id:'b',provider:'remote-tiles',tileset:{correction:{...base,eastM:40}}}]};
 const state=M.initial(C,doc,pose),corrections=M.remoteCorrections(C,doc,state);for(const [k,v]of Object.entries(base))near(corrections[0].correction[k],v);
 const moved=M.translate(C,{...state,rotationDeg:40,scale:2},8,3,1),next=M.remoteCorrections(C,doc,moved),p={...pivot,ellipsoidHeightM:pivot.heightM};
 const deltas=doc.assets.map((asset,i)=>C.Matrix4.multiply(T.correctionMatrix(C,p,next[i].correction),C.Matrix4.inverse(T.correctionMatrix(C,p,asset.tileset.correction),new C.Matrix4()),new C.Matrix4()));assert.ok(C.Matrix4.equalsEpsilon(deltas[0],deltas[1],1e-6));
 near(C.Cartesian3.distance(C.Matrix4.multiplyByPoint(T.correctionMatrix(C,p,next[0].correction),M.xyz(C,p),new C.Cartesian3()),M.xyz(C,moved)),0,1e-6);
});
