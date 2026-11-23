'use strict';
const assert = require('node:assert/strict');
const {test} = require('node:test');
const {readFileSync} = require('node:fs');
const {join} = require('node:path');
const A = require('../../web/features/scenery/scenery_alignment.js');
const Preview = require('../../web/features/scenery/scenery_reference_preview.js');

const root = join(__dirname,'../..');
function fakeCesium() {
  class Matrix4 {}
  Matrix4.fromRotationTranslation = rotation => ({rotation});
  Matrix4.multiply = (a,b) => ({a,b});
  return {
    Cartesian3:{fromDegrees:(lon,lat,height) => ({lon,lat,height})},
    Transforms:{eastNorthUpToFixedFrame:point => ({point})},
    Matrix3:{fromRotationZ:angle => ({angle})}, Matrix4,
    Math:{toRadians:deg=>deg*Math.PI/180},
    Color:class {constructor(red,green,blue,alpha){Object.assign(this,{red,green,blue,alpha});}}
  };
}

test('normalize validates all numeric fields and version',()=>{
  assert.deepEqual(A.normalize(A.DEFAULT), A.DEFAULT);
  for (const candidate of [
    {longitude:'13.789'}, {latitude:120}, {ellipsoidHeightM:Infinity},
    {scale:0}, {rotationDeg:-900}, {opacity:-0.5}, {schemaVersion:2}
  ]) assert.throws(()=>A.normalize({...A.DEFAULT,...candidate}),/Invalid|Unsupported/);
  assert.throws(()=>A.normalize(null),/Invalid/);
});

test('model matrix applies rotation about ENU local up and preserves geodetic anchor',()=>{
  const C = fakeCesium();
  const cfg = {...A.DEFAULT,longitude:13.8,latitude:52.4,ellipsoidHeightM:91,rotationDeg:90};
  const matrix = A.modelMatrix(C,cfg);
  assert.deepEqual(matrix.a.point,{lon:13.8,lat:52.4,height:91});
  assert.ok(Math.abs(matrix.b.rotation.angle+Math.PI/2)<1e-12);
  const model={};
  A.apply(C,model,{...cfg,opacity:.3,scale:12});
  assert.equal(model.scale,12);
  assert.equal(model.color.alpha,.3);
});

test('one meter nudge moves approximate east/north and respects altitude',()=>{
  const original = A.DEFAULT;
  const next = A.nudge(original,1,1);
  const dy=(next.latitude-original.latitude)*111320;
  const dx=(next.longitude-original.longitude)*111320*Math.cos(original.latitude*Math.PI/180);
  assert.ok(Math.abs(dy-1)<.001);
  assert.ok(Math.abs(dx-1)<.001);
  assert.equal(next.ellipsoidHeightM,original.ellipsoidHeightM);
});

test('export includes local licensing and explicitly unverified positioning',()=>{
  const json=A.exportDocument(A.DEFAULT);
  assert.equal(json.heightDatum,'WGS84 ellipsoid');
  assert.equal(json.surveyVerified,false);
  assert.equal(json.physicalCollisionsEnabled,false);
  assert.equal(json.license,'CC BY-NC');
  assert.deepEqual(A.normalize(json),A.normalize(A.DEFAULT));
});

test('preview is opt-in, adds local model only and disposes it',async()=>{
  const C=fakeCesium();
  C.Model={fromGltfAsync:async()=>{throw Error('unused')}};
  const primitives=[];const messages=[];let destination;
  const model={destroy(){this.destroyed=true;}};
  const viewer={scene:{primitives:{add(x){primitives.push(x);},remove(x){primitives.splice(primitives.indexOf(x),1);}},requestRender(){}},
    camera:{flyTo(v){destination=v.destination;}}};
  const preview=Preview.create(C,viewer,{fetchConfig:async url=>{assert.equal(url,'./assets/scenery/reference_alignment.json');return A.exportDocument(A.DEFAULT);},
    modelFactory:async cfg=>{assert.equal(cfg.scale,10);return model;},onStatus:msg=>messages.push(msg.state)});
  assert.equal(primitives.length,0);
  assert.equal(await preview.load(),model);
  assert.equal(primitives.length,1);
  assert.equal(model.scale,10);
  assert.deepEqual(destination,{lon:A.DEFAULT.longitude,lat:A.DEFAULT.latitude,height:550});
  assert.deepEqual(messages,['loaded']);
  preview.dispose();assert.equal(primitives.length,0);
});

test('missing local reference asset fails safely without affecting renderer',async()=>{
  const C=fakeCesium(); const messages=[];
  const viewer={scene:{primitives:{add(){throw Error('should not add');}}}};
  const preview=Preview.create(C,viewer,{fetchConfig:async()=>{throw Error('404 locally');},onStatus:v=>messages.push(v)});
  assert.equal(await preview.load(),null);
  assert.equal(messages[0].state,'error');
});

test('HTML workbench uses the real regional map providers and scenery catalog',()=>{
  const workbench=readFileSync(join(root,'tool/scenery/cesium_georeference_workbench.html'),'utf8');
  const source=readFileSync(join(root,'tool/scenery/cesium_georeference_workbench.js'),'utf8');
  const globe=readFileSync(join(root,'web/globe.js'),'utf8');
  const html=readFileSync(join(root,'web/globe.html'),'utf8');
  const pubspec=readFileSync(join(root,'pubspec.yaml'),'utf8');
  assert.match(workbench,/map_providers\.js/);
  assert.match(source,/regionalImagery\(style\)/);
  assert.match(source,/\bEllipsoidTerrainProvider\b/);
  assert.match(source,/\bModel\.fromGltfAsync\b/);
  assert.match(source,/exportDocument\(config\)/);
  assert.match(globe,/FPVSceneryManager\.create/);
  assert.match(html,/scenery_manager\.js/);
  assert.match(pubspec,/web\/assets\/scenery\//);
  assert.match(html,/scenery_alignment\.js/);
  assert.match(pubspec,/web\/features\/scenery\/scenery_alignment\.js/);
  assert.match(pubspec,/web\/features\/scenery\/scenery_reference_preview\.js/);
});

test('control point fit recovers clockwise rotation, scale and anchor with metre residuals',()=>{
 const base=A.normalize({...A.DEFAULT,scale:16.01,rotationDeg:99.5});
 const theta=-102*Math.PI/180,scale=16.2,tx=4,ty=-3;
 const pairs=[[-5,-4],[6,-3],[4,7],[-6,5]].map(([x,y])=>({source:{x,y},target:A.offset(base,tx+scale*(Math.cos(theta)*x-Math.sin(theta)*y),ty+scale*(Math.sin(theta)*x+Math.cos(theta)*y))}));
 const fit=A.fitControlPoints(base,pairs);
 assert.ok(Math.abs(fit.alignment.rotationDeg-102)<1e-6);
 assert.ok(Math.abs(fit.alignment.scale-scale)<1e-6);
 assert.ok(Math.abs(A.localPoint(base,fit.alignment).x-tx)<1e-6);
 assert.ok(Math.abs(A.localPoint(base,fit.alignment).y-ty)<1e-6);
 assert.ok(fit.rmsM<1e-6);assert.equal(fit.residualsM.length,4);
 assert.equal(fit.alignment.ellipsoidHeightM,base.ellipsoidHeightM);
});
test('control points require noncollinear correspondences; misfit reported rather than hidden',()=>{
 const base=A.DEFAULT;
 const p=[[-5,-5],[5,-5],[5,5],[-5,5]].map(([x,y],i)=>({source:{x,y},target:A.offset(base,x*10+(i===3?5:0),y*10)}));
 assert.ok(A.fitControlPoints(base,p).rmsM>1);
 assert.throws(()=>A.fitControlPoints(base,p.slice(0,2)),/3–64/);
 assert.throws(()=>A.fitControlPoints(base,[0,1,2].map(x=>({source:{x,y:x},target:A.offset(base,x,x)}))),/collinear/);
});
test('replacement polygons are bounded, non self-intersecting and independently opt-in',()=>{
 const base=A.DEFAULT;
 const polygon=[[0,0],[100,0],[100,100],[0,100]].map(([x,y])=>{const p=A.offset(base,x,y);return [p.longitude,p.latitude];});
 assert.equal(A.normalizeEdit({alignment:base,buildingRegions:[polygon]},base).replaceBuildings,false);
 assert.equal(A.normalizeEdit({alignment:base,buildingRegions:[polygon],replaceBuildings:true},base).buildingRegions.length,1);
 assert.throws(()=>A.normalizeRegions([[polygon[0],polygon[2],polygon[1],polygon[3]]],base),/Self-intersecting/);
 assert.throws(()=>A.normalizeRegions([[[0,0],[1,0],[1,1]]],base),/1 km/);
 assert.throws(()=>A.normalizeEdit({alignment:base,heightOffsetM:21},base),/Height/);
 assert.throws(()=>A.normalizeEdit({alignment:base,clipTerrain:'true'},base),/switch/);
});

test('scan-derived local footprint rotates clockwise with alignment and remains geographically bounded',()=>{
 const base=A.normalize({...A.DEFAULT,rotationDeg:90,scale:10});
 const poly=A.projectFootprint([[0,0],[1,0],[1,1],[0,1]],base);
 const points=poly.map(([longitude,latitude])=>A.localPoint(base,{longitude,latitude}));
 assert.ok(points.some(p=>Math.abs(p.x)<1e-7&&Math.abs(p.y+10)<1e-7));
 assert.ok(points.some(p=>Math.abs(p.x-10)<1e-7&&Math.abs(p.y+10)<1e-7));
 const catalog=require('../../web/assets/scenery/catalog.json');
 const item=catalog.sceneries[0];
 assert.ok(A.projectFootprint(item.draftBuildingFootprintLocal,item.alignment).length>=3);
 assert.equal(item.replaceBuildings,true);assert.equal(item.clipTerrain,false);
});
