'use strict';
const {test}=require('node:test'),assert=require('node:assert/strict');
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const Collision=require('../../web/scenery_collision.js');
const catalog=require('../../web/assets/scenery/catalog.json');
const raw=fs.readFileSync(path.join(__dirname,'../../web/assets/scenery/local_reference.fpc'));
const mesh=Collision.parse(raw.buffer.slice(raw.byteOffset,raw.byteOffset+raw.byteLength));
const scene=catalog.sceneries.find(s=>s.id==='de-bb-ruedersdorf-chemical-plant');
const r=.16/scene.alignment.scale;
function ray(x,y,z0,z1){return Collision.sweep(mesh,[x,y,z0],[x,y,z1],r);}

test('R22 northern stepped annex has collidable internal support but open middle',()=>{
  assert.ok(Collision.sweep(mesh,[-5.50,2.635,-1.83],[-5.615,2.635,-1.83],r),'New inner pier should collide');
  assert.equal(ray(-5.33,2.65,-1.72,-1.90),null,'Annex interior should stay flyable');
});
test('R22 east courtyard has discontinuous gallery and free center',()=>{
  assert.ok(ray(-1.205,4.78,-1.60,-1.80),'Missing narrow ledge');
  assert.equal(ray(-.55,4.78,-1.56,-1.82),null,'No solid mezzanine should close courtyard hall');
});
test('R22 small service annex has pillars without central bulkhead',()=>{
  assert.ok(ray(2.170,.142,-1.69,-1.90),'Small building post missing');
  assert.equal(ray(2.350,.26,-1.69,-1.90),null,'Unobserved corridor wall was created');
});
test('R22 core R20/R21 dive openings and six-silo closed roof are unchanged',()=>{
  assert.equal(ray(-4.881,-.79,.12,-.38),null,'Hall exterior platform gap blocked');
  assert.equal(ray(1.41,3.87,-.31,-.54),null,'Central four-silo roof dive blocked');
  assert.ok(ray(4.79,-2.202,-.04,-.34),'South-eastern six-silo roof falsely opened');
  assert.equal(ray(4.93,1.95,-.99,-1.115),null,'R21 eastern stair hatch blocked');
});
test('R22 certificate and geographic alignment are correct',()=>{
  const sha=crypto.createHash('sha256').update(raw).digest('hex');
  assert.equal(scene.terrainCertificate.collisionSha256,sha);
  assert.equal(scene.terrainCertificates.length,15);
  assert.ok(scene.terrainCertificates.every(c=>c.collisionSha256===sha));
  assert.equal(scene.alignment.rotationDeg,99.7993823133657);
  assert.equal(scene.alignment.scale,16.023268178233355);
  assert.equal(scene.surveyVerified,false);
});
