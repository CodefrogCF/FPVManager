'use strict';
// R19 panoramas were superseded by R24/R25: four speculative vessel meshes
// were removed and replaced with accessible rooms, side platforms and stairs.
// Keep the suite name for CI continuity but assert the current scene contract.
const {test}=require('node:test'), assert=require('node:assert/strict');
const fs=require('node:fs'), path=require('node:path');
const Collision=require('../../web/scenery_collision.js');
const catalog=require('../../web/assets/scenery/catalog.json');
const file=path.resolve(__dirname,'../../web/assets/scenery/local_reference.fpc');
const data=fs.readFileSync(file);
const mesh=Collision.parse(data.buffer.slice(data.byteOffset,data.byteOffset+data.byteLength));
const site=catalog.sceneries.find(e=>e.id==='de-bb-ruedersdorf-chemical-plant');
const radius=0.19/site.alignment.scale;
const check=(a,b)=>Collision.sweep(mesh,a,b,radius);

test('R25/R27: former east vessel bays remain physically open instead of containing four cylinders',()=>{
 for(const y of [1.31,1.67,2.03,2.39]){
  assert.equal(check([4.71,y,-1.56],[4.86,y,-1.56]),null,
   `An obsolete vessel wall still blocks the interior at y=${y}`);
 }
});

test('R25/R27: side platforms are solid while the central multi-storey aisle remains open',()=>{
 for(const y of [1.31,1.67,2.03]){
  assert.ok(check([5.16,y,-1.51],[5.16,y,-1.76]),
   `Eastern side platform missing at y=${y}`);
  assert.equal(check([4.885,y,-1.51],[4.885,y,-1.76]),null,
   `An obsolete full-width slab blocks the central aisle at y=${y}`);
 }
});

test('R19: exposed stairs and side gallery have physical geometry',()=>{
 assert.ok(check([-3.63,2.90,-1.20],[-3.63,2.90,-1.95]));
 assert.ok(check([-3.36,2.96,-1.20],[-3.36,2.96,-1.95]));
});
