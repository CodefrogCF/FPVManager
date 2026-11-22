'use strict';
const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs=require('node:fs');
const crypto=require('node:crypto');
const path=require('node:path');
const Collision=require('../../web/scenery_collision.js');
const catalog=require('../../web/assets/scenery/catalog.json');
const file=fs.readFileSync(path.resolve(__dirname,'../../web/assets/scenery/local_reference.fpc'));
const mesh=Collision.parse(file.buffer.slice(file.byteOffset,file.byteOffset+file.byteLength));
const scene=catalog.sceneries.find(s=>s.id==='de-bb-ruedersdorf-chemical-plant');
const r=0.11/scene.alignment.scale;
const check=(a,b)=>Collision.sweep(mesh,a,b,r);

test('R25: north-west utility entrance and window are physically open',()=>{
  assert.equal(check([-4.18,5.70,-1.85],[-4.18,5.82,-1.85]),null);
  assert.equal(check([-4.40,5.70,-1.52],[-4.40,5.81,-1.52]),null);
  assert.ok(check([-4.36,5.70,-1.85],[-4.36,5.82,-1.85]));
});
test('R25: northwest roof hatch is open and neighbouring roof blocks dives',()=>{
  assert.equal(check([-4.22,5.94,-1.37],[-4.22,5.94,-1.13]),null);
  assert.ok(check([-4.40,5.94,-1.37],[-4.40,5.94,-1.13]));
});
test('R25: east production block has real doorway and solid facade',()=>{
  assert.equal(check([4.24,1.87,-1.79],[4.46,1.87,-1.79]),null);
  assert.ok(check([4.24,1.60,-1.79],[4.46,1.60,-1.79]));
});
test('R25: newly generated collider matches certified scene',()=>{
  const digest=crypto.createHash('sha256').update(file).digest('hex');
  assert.equal(scene.terrainCertificate.collisionSha256,digest);
  assert.ok(scene.terrainCertificates.every(c=>c.collisionSha256===digest));
  assert.equal(scene.terrainCertificates.length,16);
});
