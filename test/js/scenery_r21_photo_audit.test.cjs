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

// R30 deliberately retires the synthetic eastern production floors and roof.
// The R25 shell must not remain as a floating frame over the real scan.
test('R30 east production block: obsolete upper decks and fictitious roof are absent',()=>{
  for(const y of [1.31,1.67,2.03]){
    assert.equal(ray(5.16,y,-1.29,-1.43),null,
      `Obsolete east upper deck blocks the restored scan at y=${y}`);
    assert.equal(ray(4.885,y,-1.29,-1.43),null,
      `Obsolete east roof passage still contains a full-span floor at y=${y}`);
  }
  assert.equal(ray(4.93,1.95,-.66,-.95),null,
    'R25 synthetic east-block roof still covers the actual scan');
});

test('R27 resized east-north platform and central/south-eastern silo distinction preserved',()=>{
  assert.equal(ray(-4.881,-.79,.12,-.38),null,'Resized east-north platform hole obstructed');
  assert.ok(ray(-4.945,-.79,.12,-.34),'Resized east-north platform ring disappeared');
  assert.equal(ray(-2.79,-2.43,.12,-.38),null,'Obsolete western landing reappeared');
  assert.equal(ray(1.41,3.87,-.31,-.54),null,'Central four-silo stairwell was capped');
  assert.ok(ray(4.79,-2.202,-.04,-.34),'South-eastern six-silo roof must stay closed');
});

test('R21 catalog certificate hashes and geographic rotation remain aligned',()=>{
  const sha=crypto.createHash('sha256').update(raw).digest('hex');
  assert.equal(scene.terrainCertificate.collisionSha256,sha);
  assert.ok(scene.terrainCertificates.length===15 && scene.terrainCertificates.every(c=>c.collisionSha256===sha));
  assert.equal(scene.alignment.rotationDeg,99.7993823133657);
  assert.equal(scene.alignment.scale,16.023268178233355);
  assert.equal(scene.surveyVerified,false);
  // Progressive scan replacement must not fail on an obsolete triangle budget.
  assert.ok(mesh.triangleCount>0);
  assert.equal(mesh.triangleCount,raw.readUInt32LE(8));
});
