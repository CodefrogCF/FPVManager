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

// R27 replaces the obsolete R23 production upper-deck system with the
// actual low courtyard forebuilding. The old service-hatch assertions no
// longer apply; check the new roof and genuine open circulation instead.
test('R27 courtyard replacement: low roof is solid and forebuilding is accessible',()=>{
  assert.ok(Collision.sweep(mesh,[-3.50,2.45,-1.49],[-3.50,2.45,-1.15],radius),
    'Low roof must remain solid');
  assert.equal(Collision.sweep(mesh,[-4.03,3.49,-1.84],[-4.03,3.11,-1.84],radius),null,
    'Front entrance must be physically open');
  assert.equal(Collision.sweep(mesh,[-3.46,3.48,-1.79],[-3.46,3.08,-1.79],radius),null,
    'Undercroft must remain open');
});
test('R27 courtyard replacement: open rear entrance, solid neighboring masonry',()=>{
  assert.equal(Collision.sweep(mesh,[-4.03,1.67,-1.84],[-4.03,1.95,-1.84],radius),null);
  assert.ok(Collision.sweep(mesh,[-4.18,1.67,-1.84],[-4.18,1.95,-1.84],radius));
});
test('R23 north utility aisle remains open after courtyard replacement',()=>{
  assert.equal(vertical(-4.00,5.95,-1.36,-1.78),null,'North utility building aisle filled');
});
test('R23 retains platform dive, central silo dive and southeast closed roof',()=>{
  assert.equal(vertical(-4.86,-.72,.12,-.38),null);
  assert.equal(vertical(1.41,3.87,-.31,-.54),null);
  assert.ok(vertical(4.79,-2.202,-.04,-.34));
  assert.equal(vertical(4.93,1.95,-.99,-1.115),null);
});
test('R23 catalog certificates match collision asset',()=>{
  const sha = crypto.createHash('sha256').update(raw).digest('hex');
  assert.equal(scene.terrainCertificate.collisionSha256,sha);
  assert.ok(scene.terrainCertificates.every(x=>x.collisionSha256===sha));
  assert.equal(scene.terrainCertificates.length,16);
  assert.equal(scene.alignment.rotationDeg,99.7993823133657);
  assert.equal(scene.surveyVerified,false);
});
