'use strict';
// R19 speculative east vessels were superseded by the R25 southern production
// building. R30 accidentally removed that building when repairing a separate
// original-scan footprint in the north; R34 restores it without recreating the
// old vessel cylinders or altering the photographed northern original scan.
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

test('R34: restored southern production side platforms retain a clear central aisle',()=>{
 for(const y of [1.31,1.67,2.03]){
  assert.ok(check([5.16,y,-1.51],[5.16,y,-1.76]),
    `Southern building east-side gallery still missing at y=${y}`);
  assert.equal(check([4.885,y,-1.51],[4.885,y,-1.76]),null,
    `Restored building must retain a clear center at y=${y}`);
 }
});

test('R28.1: original-scan courtyard no longer contains the fictional R19 stair flights',()=>{
 assert.equal(check([-3.63,2.90,-1.20],[-3.63,2.90,-1.95]),null);
 assert.equal(check([-3.36,2.96,-1.20],[-3.36,2.96,-1.95]),null);
 // The separate northern vaulted hall and its galleries stay intact.
 assert.ok(check([-2.94,-6.53,-1.20],[-2.94,-6.53,-1.95]));
});
