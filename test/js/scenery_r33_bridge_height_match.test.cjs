'use strict';
const test=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const B=require('../../web/scenery_bridge_calibration.js');
const M=require('../../web/scenery_manager.js');
const A=require('../../web/scenery_alignment.js');
const catalog=require('../../web/assets/scenery/catalog.json');

const point=(height,lon=13.78985,lat=52.48412)=>({height,longitude:lon,latitude:lat});

test('R33.1: matching scan and rendered ground heights produce zero offset',()=>{
  assert.deepEqual(B.compare(point(82),point(82),0),{deltaM:0,proposedOffsetM:0,horizontalM:0,warning:null});
});
test('R33.1: ground picks yield a signed additive offset rather than hardcoded geoid',()=>{
  assert.deepEqual(B.compare(point(108.3),point(81.8),-2),{
    deltaM:-26.5,proposedOffsetM:-28.5,horizontalM:0,warning:null});
  assert.equal(B.compare(point(71),point(81.5),5).proposedOffsetM,15.5);
});
test('R33: reject invalid depth, inappropriate separation and implausible offsets',()=>{
  assert.throws(()=>B.compare(point(NaN),point(81)),/valid 3D/);
  assert.throws(()=>B.compare(point(10,0,0),point(10,180,0)),/12 m auseinander/);
  assert.throws(()=>B.compare(point(170),point(81)),/überschreitet/);
  assert.throws(()=>B.compare(point(82),point(82),60.1),/überschreitet/);
  assert.ok(B.compare(point(82),point(82,13.78994)).warning);
});
test('R33: BKG-specific edit is validated, persists separately from ordinary offset',()=>{
  const item=M.validate(catalog)[0];
  assert.equal(item.bkgHeightOffsetM,-16.90);
  const edit=A.normalizeEdit({...item,bkgHeightOffsetM:-27.5,heightOffsetM:.25},item.alignment);
  assert.equal(edit.bkgHeightOffsetM,-27.5);
  assert.equal(edit.heightOffsetM,.25);
  assert.throws(()=>A.normalizeEdit({...item,bkgHeightOffsetM:-61},item.alignment),/BKG/);
  assert.throws(()=>A.normalizeEdit({...item,bkgHeightOffsetM:'-20'},item.alignment),/BKG/);
});

test('R33: BKG-only height nudge follows a provider switch, preview hiding is reversible',async()=>{
  class Matrix4{};Matrix4.fromRotationTranslation=x=>x;Matrix4.multiply=(a,b)=>({a,b});
  const C={Cartesian3:{fromDegrees:(...v)=>v},Transforms:{eastNorthUpToFixedFrame:x=>x},
    Matrix3:{fromRotationZ:x=>x},Matrix4,Math:{toRadians:x=>x*Math.PI/180},Color:class{},Credit:class{}};
  const model={ready:true,show:true,destroy(){}};
  const viewer={scene:{primitives:{add(){},remove(){}},preUpdate:{addEventListener:()=>()=>{}},requestRender(){}},
    cesiumWidget:{creditDisplay:{addStaticCredit(){},removeStaticCredit(){}}}};
  let regional=false,provider={id:'normal'};
  const manager=M.create(C,viewer,{fetchCatalog:async()=>catalog,
    modelFactory:async()=>model,collisionFactory:async()=>{throw Error('unused');},
    position:()=>({...catalog.sceneries[0].alignment,height:100}),
    terrainKey:()=>provider,regionalHeightMode:()=>regional,sampleGround:async()=>78});
  const flush=()=>new Promise(r=>setImmediate(r));
  try{
    await manager.initialize();await flush();manager.tick(true);await flush();
    const normal=manager.snapshot()[0];
    assert.equal(normal.heightState,'adjusted');
    assert.equal(normal.bkgHeightOffsetM,-16.90);
    const edit={...normal,bkgHeightOffsetM:-24};
    manager.setEdit(normal.id,edit);
    assert.equal(manager.snapshot()[0].bkgHeightOffsetM,-24);
    assert.equal(manager.snapshot()[0].effectiveAlignment.ellipsoidHeightM,normal.effectiveAlignment.ellipsoidHeightM);
    regional=true;provider={id:'bkg'};manager.tick(true);await flush();
    assert.equal(manager.snapshot()[0].heightState,'adjusted');
    assert.ok(Math.abs(manager.snapshot()[0].effectiveAlignment.ellipsoidHeightM-(normal.effectiveAlignment.ellipsoidHeightM-24))<1e-8);
    manager.setPreviewHidden(normal.id,true);
    assert.equal(model.show,false);
    manager.setPreviewHidden(normal.id,false);
    assert.equal(model.show,true);
    assert.deepEqual(manager.previewModels(normal.id),[model]);
    regional=false;provider={id:'normal-2'};manager.tick(true);await flush();
    assert.equal(manager.snapshot()[0].effectiveAlignment.ellipsoidHeightM,normal.effectiveAlignment.ellipsoidHeightM);
  }finally{manager.dispose();}
});

test('R33.1: tap workflow uses local scanned ground and bare terrain, confirmation is explicit',()=>{
  const js=fs.readFileSync('web/globe.js','utf8');
  const html=fs.readFileSync('web/globe.html','utf8');
  const manager=fs.readFileSync('web/scenery_manager.js','utf8');
  const ui=fs.readFileSync('lib/features/globe/scenery_layers_section.dart','utf8');
  const controller=fs.readFileSync('lib/features/globe/globe_controller.dart','utf8');
  assert.match(html,/scenery_bridge_calibration\.js/);
  assert.ok(html.indexOf('scenery_bridge_calibration.js')<html.indexOf('globe.js'));
  assert.match(manager,/allowPicking:url\.endsWith\("local_reference\.glb"\)/);
  assert.match(js,/sceneryManager\.setPreviewHidden\(id,true\)/);
  assert.match(js,/FPVSceneryBridgeCalibration\.compare/);
  assert.match(js,/case 'begin-scenery-bridge-height-match'/);
  assert.match(js,/case 'cancel-scenery-bridge-height-match'/);
  assert.match(js,/if\(bridgeMatchPick\(event\.position\)\)return;/);
  assert.match(ui,/Bodenhöhe übernehmen/);
  assert.match(ui,/proposedOffsetM/);
  assert.match(controller,/beginSceneryBridgeHeightMatch/);
  assert.match(controller,/saveSceneryEdit/);
});

test('R33.1: calibration module is bundled for Android, not just loaded in HTML',()=>{
  const yaml=fs.readFileSync('pubspec.yaml','utf8');
  const html=fs.readFileSync('web/globe.html','utf8');
  assert.match(yaml,/^\s+- web\/scenery_bridge_calibration\.js\s*$/m);
  assert.match(html,/<script src="scenery_bridge_calibration\.js"><\/script>/);
  assert.ok(html.indexOf('scenery_bridge_calibration.js')<html.indexOf('globe.js'));
  const js=fs.readFileSync('web/globe.js','utf8');
  assert.match(js,/globalThis\.FPVSceneryBridgeCalibration\?\.compare/);
});

test('R33.1: do not compare a scanned floor with distant or elevated LoD2 roofs',()=>{
  assert.throws(()=>B.compare(point(83),point(84,13.79035)),/12 m auseinander/);
  assert.deepEqual(B.compare(point(92.5),point(84),-1).proposedOffsetM,-9.5);
  const js=fs.readFileSync('web/globe.js','utf8');
  assert.match(js,/const xyz=ray&&scene\.globe\.pick\(ray,scene\)/);
  assert.match(js,/if\(lod2\|\|picked&&picked\.primitive!==scene\.globe\)/);
  const ui=fs.readFileSync('lib/features/globe/scenery_layers_section.dart','utf8');
  assert.match(ui,/Bodenfläche möglichst mittig im Originalscan/);
});

test('R33.1: calibration helper registers in a plain browser without CommonJS globals',()=>{
  const vm=require('node:vm');
  const context={};
  vm.runInNewContext(fs.readFileSync('web/scenery_bridge_calibration.js','utf8'),context);
  assert.equal(typeof context.FPVSceneryBridgeCalibration?.compare,'function');
  assert.equal(context.FPVSceneryBridgeCalibration.MAX_HORIZONTAL_M,12);
});
