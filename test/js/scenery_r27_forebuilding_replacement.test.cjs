'use strict';
const {test}=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const Collision=require('../../web/scenery_collision.js');
const catalog=require('../../web/assets/scenery/catalog.json');
const raw=fs.readFileSync(path.join(__dirname,'../../web/assets/scenery/local_reference.fpc'));
const collider=Collision.parse(raw.buffer.slice(raw.byteOffset,raw.byteOffset+raw.byteLength));
const scene=catalog.sceneries.find(s=>s.id==='de-bb-ruedersdorf-chemical-plant');
const radius=.08/scene.alignment.scale;
const sweep=(a,b)=>Collision.sweep(collider,a,b,radius);

test('R27 forebuilding: rebuilt facades have true doors, windows and masonry collisions',()=>{
  assert.equal(sweep([-4.03,3.49,-1.84],[-4.03,3.11,-1.84]),null);
  assert.equal(sweep([-3.77,3.49,-1.84],[-3.77,3.11,-1.84]),null);
  assert.ok(sweep([-3.665,3.49,-1.84],[-3.665,3.10,-1.84]));
  assert.equal(sweep([-3.869,3.49,-1.617],[-3.869,3.10,-1.617]),null);
  assert.equal(sweep([-4.03,1.67,-1.84],[-4.03,1.95,-1.84]),null);
  assert.ok(sweep([-4.18,1.67,-1.84],[-4.18,1.95,-1.84]));
});

test('R27 forebuilding: open undercroft, roof and broken external stair are physically consistent',()=>{
  assert.equal(sweep([-3.46,3.48,-1.79],[-3.46,3.08,-1.79]),null);
  assert.ok(sweep([-3.5,2.45,-1.49],[-3.5,2.45,-1.15]));
  assert.ok(sweep([-3.24,3.43,-1.95],[-3.24,3.43,-1.20]));
  assert.equal(sweep([-3.24,3.58,-1.70],[-3.24,3.58,-1.23]),null);
});

test('R27 courtyard: silo bodies, roof-dive and old exterior hall landing unaffected',()=>{
  assert.ok(sweep([-2.19,2.66,-1.38],[-2.19,2.66,-.45]));
  assert.equal(sweep([1.41,3.85,-.58],[1.41,3.85,-.35]),null);
  assert.equal(sweep([-4.876,-.726,-.15],[-4.876,-.726,-.04]),null);
});
