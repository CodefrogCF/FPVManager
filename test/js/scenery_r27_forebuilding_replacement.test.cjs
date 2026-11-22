'use strict';
const {test}=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const Collision=require('../../web/scenery_collision.js');
const catalog=require('../../web/assets/scenery/catalog.json');
const report=require('../../tool/scenery/r28_1/restoration_report.json');
const raw=fs.readFileSync(path.join(__dirname,'../../web/assets/scenery/local_reference.fpc'));
const collider=Collision.parse(raw.buffer.slice(raw.byteOffset,raw.byteOffset+raw.byteLength));
const scene=catalog.sceneries.find(s=>s.id==='de-bb-ruedersdorf-chemical-plant');
const radius=.08/scene.alignment.scale;
const sweep=(a,b)=>Collision.sweep(collider,a,b,radius);

const r29=require('../../tool/scenery/r29/refinement_R29_report.json');
test('R29: actual original RAWscan roof restored; no synthetic low roof',()=>{
  assert.equal(report.revision,'R28.1');
  assert.ok(report.removed_synthetic_triangles>2500);
  assert.equal(r29.revision,'R29');
  assert.ok(r29.restored_original_triangles>25000,
    'Missing original source geometry was not restored');
  assert.equal(r29.original_material_0_retained,true);
  assert.ok(sweep([-3.50,2.45,-.50],[-3.50,2.45,-1.50]),
    'Full original RAWscan building roof must collide');
  assert.equal(sweep([-3.50,2.45,-1.49],[-3.50,2.45,-1.15]),null,
    'Invented low green roof must not return');
  assert.ok(sweep([-3.665,3.49,-1.84],[-3.665,3.10,-1.84]),
    'Original RAWscan wall/structure must be retained');
});

test('R29: the removed artificial exterior staircase remains absent',()=>{
  assert.equal(sweep([-3.24,3.43,-1.95],[-3.24,3.43,-1.20]),null,
    'Invented outdoor staircase reappeared');
  assert.ok(sweep([-4.18,1.67,-1.84],[-4.18,1.95,-1.84]),
    'Restored real outer wall should collide');
});

test('R28.1: neighboring silos, dive opening and north-east hall landing remain',()=>{
  assert.ok(sweep([-2.19,2.66,-1.38],[-2.19,2.66,-.45]));
  assert.equal(sweep([1.41,3.85,-.58],[1.41,3.85,-.35]),null);
  assert.equal(sweep([-4.881,-.79,-.15],[-4.881,-.79,-.04]),null);
});
