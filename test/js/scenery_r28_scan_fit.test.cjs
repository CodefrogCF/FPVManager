'use strict';
const {test}=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const M=require('../../web/scenery_manager.js');
const catalog=require('../../web/assets/scenery/catalog.json');
const Collision=require('../../web/scenery_collision.js');
const raw=fs.readFileSync(path.join(__dirname,'../../web/assets/scenery/local_reference.fpc'));
const collider=Collision.parse(raw.buffer.slice(raw.byteOffset,raw.byteOffset+raw.byteLength));

// Ground model XYZ comes from the original scan, not camera-estimated building height.
const controls=[[-3.8,0,-2.0069],[-2,0.2,-2.0362],[-4.6,0.5,-1.9719],[-3,-3.5,-2.0566],[0,-3.5,-2.0853]];
test('R28 ground-reference fit uses scan ground elevations and ignores one wrong tile',()=>{
  const localGround=-2.02575,scale=16.023268178233355,anchor=64;
  const heights=controls.map(c=>anchor+(c[2]-localGround)*scale);
  heights[0]+=35; // building/bridge or outdated terrain tile
  assert.ok(Math.abs(M.fitGroundReference(controls,heights,localGround,scale)-anchor)<1e-5);
  assert.throws(()=>M.fitGroundReference(controls,[NaN,NaN,30,NaN,50],localGround,scale),/Insufficient/);
});

test('R28.1 original scan fallback supersedes the unsupported green roof enlargement',()=>{
  const restore=require('../../tool/scenery/r28_1/restoration_report.json');
  assert.equal(restore.revision,'R28.1');
  assert.equal(restore.scanned_original_textures_preserved,true);
  assert.equal(restore.detailed_replacement_added,false);
  assert.ok(restore.removed_synthetic_triangles>2500);
  const obj=catalog.sceneries.find(s=>s.id==='de-bb-ruedersdorf-chemical-plant');
  const radius=.08/obj.alignment.scale;
  assert.equal(Collision.sweep(collider,[-3.493,2.486,-1.49],[-3.493,2.486,-1.15],radius),null,
    'R28 fabricated roof must no longer be collidable');
});
