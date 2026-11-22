'use strict';
// R21, panorama-driven geometry: physical mesh clearance / no invisible caps.
const {test}=require('node:test'),assert=require('node:assert/strict');
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const Collision=require('../../web/scenery_collision.js');
const catalog=require('../../web/assets/scenery/catalog.json');
const raw=fs.readFileSync(path.join(__dirname,'../../web/assets/scenery/local_reference.fpc'));
const mesh=Collision.parse(raw.buffer.slice(raw.byteOffset,raw.byteOffset+raw.byteLength));
const scene=catalog.sceneries.find(x=>x.id==='de-bb-ruedersdorf-chemical-plant');
const r=.19/scene.alignment.scale;
function ray(x,y,z0,z1){return Collision.sweep(mesh,[x,y,z0],[x,y,z1],r);}

test('R21 long hall retained galleries collide on BOTH sides, central dive aisle open',()=>{
  assert.ok(ray(-4.78,-2.13,-1.12,-1.41),'Missing west-side elevated slab');
  assert.ok(ray(-4.78,-1.08,-1.12,-1.41),'Missing east-side elevated slab');
  assert.equal(ray(-4.65,-1.60,-1.12,-1.41),null,'False mezzanine bridge across central atrium');
});

test('R21 broken upper floor has real hole, not merely a dark top texture',()=>{
  assert.equal(ray(-4.684,-2.135,-1.12,-1.41),null,'Damaged panel is still collidable');
  assert.ok(ray(-4.78,-2.135,-1.12,-1.41),'Intact panel beside hole should collide');
});

test('R21 east upper room: OLD solid roof is removed, smaller stairwell hatch physically open',()=>{
  assert.equal(ray(4.93,1.95,-.99,-1.115),null,'R6 roof or hidden slab still seals upper hatch');
  assert.ok(ray(4.71,1.95,-.99,-1.115),'Upper hatch must have collidable floor around perimeter');
  assert.ok(ray(4.93,1.55,-.99,-1.115),'Upper landing outside the real hatch should be solid');
});

test('R21 east upper room has an ACTUAL vaulted roof above the hatch',()=>{
  assert.ok(ray(4.93,1.95,-.66,-.95),'Roof must protect formerly open east building from above');
});

test('R21 R20 north-east platform and central/south-eastern silo distinction preserved',()=>{
  assert.equal(ray(-4.86,-.72,.12,-.38),null,'East-north platform hole obstructed');
  assert.ok(ray(-4.995,-.72,.12,-.34),'East-north platform ring disappeared');
  assert.equal(ray(-2.79,-2.43,.12,-.38),null,'Obsolete western landing reappeared');
  assert.equal(ray(1.41,3.87,-.31,-.54),null,'Central four-silo stairwell was capped');
  assert.ok(ray(4.79,-2.202,-.04,-.34),'South-eastern six-silo roof must stay closed');
});

test('R21 catalog certificate hashes and geographic rotation remain aligned',()=>{
  const sha=crypto.createHash('sha256').update(raw).digest('hex');
  assert.equal(scene.terrainCertificate.collisionSha256,sha);
  assert.ok(scene.terrainCertificates.length===16 && scene.terrainCertificates.every(c=>c.collisionSha256===sha));
  assert.equal(scene.alignment.rotationDeg,99.7993823133657);
  assert.equal(scene.alignment.scale,16.023268178233355);
  assert.equal(scene.surveyVerified,false);
  assert.ok(mesh.triangleCount>953000 && mesh.triangleCount<975000,mesh.triangleCount);
});
