'use strict';
const {test} = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const Collision = require('../../web/scenery_collision.js');
const catalog = require('../../web/assets/scenery/catalog.json');
const raw = fs.readFileSync(path.join(__dirname,'../../web/assets/scenery/local_reference.fpc'));
const mesh = Collision.parse(raw.buffer.slice(raw.byteOffset, raw.byteOffset + raw.byteLength));
const scene = catalog.sceneries.find(s => s.id === 'de-bb-ruedersdorf-chemical-plant');
const radius = .16 / scene.alignment.scale;  // 16 cm world radius
function vertical(x,y,z0=-1.125,z1=-1.22) {
  return Collision.sweep(mesh,[x,y,z0],[x,y,z1],radius);
}

// R29 restores the ACTUAL 2022 RAWscan building from the original archive.
// The old R28.1 assumptions about an empty site are no longer valid.
test('R29 courtyard: original scanned roof and walls collide, invented low roof does not',()=>{
  assert.ok(Collision.sweep(mesh,[-3.50,2.45,-.50],[-3.50,2.45,-1.50],radius),
    'Restored original photogrammetric roof is missing');
  assert.equal(Collision.sweep(mesh,[-3.50,2.45,-1.49],[-3.50,2.45,-1.15],radius),null,
    'Former fabricated low roof reappeared');
  assert.ok(Collision.sweep(mesh,[-4.18,1.67,-1.84],[-4.18,1.95,-1.84],radius),
    'Restored original wall section is missing');
});
test('R23 north utility aisle remains open after courtyard replacement',()=>{
  assert.equal(vertical(-4.00,5.95,-1.36,-1.78),null,'North utility building aisle filled');
});
test('R23 retains platform dive, central silo dive and southeast closed roof',()=>{
  assert.equal(vertical(-4.881,-.79,.12,-.38),null);
  assert.equal(vertical(1.41,3.87,-.31,-.54),null);
  assert.ok(vertical(4.79,-2.202,-.04,-.34));
  assert.equal(vertical(4.93,1.95,-.99,-1.115),null);
});
test('R23 catalog certificates match collision asset',()=>{
  const sha = crypto.createHash('sha256').update(raw).digest('hex');
  assert.equal(scene.terrainCertificate.collisionSha256,sha);
  assert.ok(scene.terrainCertificates.every(x=>x.collisionSha256===sha));
  assert.equal(scene.terrainCertificates.length,15);
  assert.equal(scene.alignment.rotationDeg,99.7993823133657);
  assert.equal(scene.surveyVerified,false);
});
