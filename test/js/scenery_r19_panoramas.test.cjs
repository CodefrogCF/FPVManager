'use strict';
// R19 approximate architectural details from panorama set: real collider.
const {test}=require('node:test'),assert=require('node:assert/strict');
const fs=require('node:fs'),path=require('node:path');
const Collision=require('../../web/scenery_collision.js');
const catalog=require('../../web/assets/scenery/catalog.json');
const file=path.resolve(__dirname,'../../web/assets/scenery/local_reference.fpc');
const data=fs.readFileSync(file);
const mesh=Collision.parse(data.buffer.slice(data.byteOffset,data.byteOffset+data.byteLength));
const site=catalog.sceneries.find(e=>e.id==='de-bb-ruedersdorf-chemical-plant');
const radius=0.19/site.alignment.scale;

test('R19: all four new east production tank walls have collision faces',()=>{
 for(const y of [1.31,1.67,2.03,2.39]){
  const hit=Collision.sweep(mesh,[4.52,y,-1.56],[4.78,y,-1.56],radius);
  assert.ok(hit,`Missing vessel at y=${y}`);
 }
});

test('R19: synthetic intermediate floors no longer span the east-vessel access aisle',()=>{
 for(const y of [1.31,1.67,2.03,2.39]){
  const hit=Collision.sweep(mesh,[5.16,y,-1.52],[5.16,y,-1.73],radius);
  assert.equal(hit,null,`Obsolete slab still crosses aisle y=${y}`);
 }
});

test('R19: exposed stairs and side gallery have physical geometry',()=>{
 assert.ok(Collision.sweep(mesh,[-3.63,2.90,-1.20],[-3.63,2.90,-1.95],radius));
 assert.ok(Collision.sweep(mesh,[-3.36,2.96,-1.20],[-3.36,2.96,-1.95],radius));
});
