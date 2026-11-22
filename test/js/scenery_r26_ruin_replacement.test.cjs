'use strict';
const {test}=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const Collision=require('../../web/scenery_collision.js');
const catalog=require('../../web/assets/scenery/catalog.json');
const bin=fs.readFileSync(path.resolve(__dirname,'../../web/assets/scenery/local_reference.fpc'));
const collider=Collision.parse(bin.buffer.slice(bin.byteOffset,bin.byteOffset+bin.byteLength));
const scene=catalog.sceneries.find(s=>s.id==='de-bb-ruedersdorf-chemical-plant');
const radius=0.11/scene.alignment.scale;
const check=(a,b)=>Collision.sweep(collider,a,b,radius);

test('R26: newly rebuilt southwest annex has physical front and rear entrances',()=>{
  assert.equal(check([2.90,-5.01,-1.82],[2.90,-4.89,-1.82]),null);
  assert.equal(check([3.65,-5.01,-1.82],[3.65,-4.89,-1.82]),null);
  assert.equal(check([2.83,-4.64,-1.82],[2.83,-4.54,-1.82]),null);
});

test('R26: removed scan shell does not block windows, but new wall fields collide',()=>{
  assert.equal(check([3.20,-5.01,-1.56],[3.20,-4.89,-1.56]),null);
  assert.ok(check([3.29,-5.01,-1.75],[3.29,-4.89,-1.75]));
  assert.ok(check([2.62,-5.01,-1.82],[2.62,-4.89,-1.82]));
});

test('R26: partially destroyed roof and elevated decks allow and block dives correctly',()=>{
  assert.equal(check([3.17,-4.75,-1.45],[3.17,-4.75,-1.24]),null);
  assert.ok(check([2.62,-4.75,-1.45],[2.62,-4.75,-1.24]));
  assert.ok(check([2.72,-4.67,-1.73],[2.72,-4.67,-1.60]));
  assert.equal(check([3.27,-4.77,-1.73],[3.27,-4.77,-1.60]),null);
});
