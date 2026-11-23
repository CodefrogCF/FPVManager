'use strict';
// Current Ruedersdorf physical-scene contracts. This deliberately checks the
// active scene, not old reconstruction stages, incremental reports or names.
const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const C = require('../../web/scenery_collision.js');
const catalog = require('../../web/assets/scenery/catalog.json');
const site = catalog.sceneries.find(s => s.id === 'de-bb-ruedersdorf-chemical-plant');
if (!site) throw Error('Ruedersdorf scene is absent');
const base = path.join(__dirname, '../../web/assets/scenery');
const bytes = fs.readFileSync(path.join(base, 'local_reference.fpc'));
const mesh = C.parse(bytes.buffer.slice(bytes.byteOffset, bytes.byteOffset + bytes.byteLength));
const radius = .11 / site.alignment.scale;
const hit = (a, b, r = radius) => C.sweep(mesh, a, b, r);
const vertical = (x, y, top, bottom, r = radius) => hit([x,y,top], [x,y,bottom], r);

test('scene uses a single validated collision asset and matching terrain certificates', () => {
  const sha = crypto.createHash('sha256').update(bytes).digest('hex');
  assert.ok(mesh.triangleCount > 900000, 'Unexpectedly small physical scene');
  assert.equal(mesh.triangleCount, bytes.readUInt32LE(8));
  assert.equal(site.terrainCertificate.collisionSha256, sha);
  assert.ok(site.terrainCertificates.length > 0);
  assert.ok(site.terrainCertificates.every(c => c.collisionSha256 === sha));
  assert.notEqual(site.terrainUnderlay.certificate.collisionSha256, sha);
  assert.equal(site.clipTerrain, false);
  assert.equal(site.surveyVerified, false);
});

test('north RAWscan building has a real roof and walls, without the fabricated lower roof', () => {
  assert.ok(vertical(-3.50, 2.45, -.50, -1.50));
  assert.equal(vertical(-3.50, 2.45, -1.49, -1.15), null);
  assert.ok(hit([-4.18,1.67,-1.84],[-4.18,1.95,-1.84]));
});

test('southern reconstructed production building has exterior walls and open entrances', () => {
  assert.equal(hit([4.24,1.87,-1.79],[4.46,1.87,-1.79]), null);
  assert.ok(hit([4.24,1.60,-1.79],[4.46,1.60,-1.79]));
  for (const y of [1.31, 1.67, 2.03]) {
    assert.ok(vertical(5.16,y,-1.51,-1.76), `South gallery missing near ${y}`);
    assert.equal(vertical(4.885,y,-1.51,-1.76), null, `South centre blocked near ${y}`);
  }
});

test('southern upper decks retain real roof and clear skylight apertures', () => {
  for (const y of [1.31,1.67,2.03]) {
    assert.ok(vertical(5.16,y,-1.29,-1.43));
    assert.equal(vertical(4.885,y,-1.29,-1.43),null);
  }
  assert.ok(vertical(4.93,1.95,-.66,-.95));
  assert.equal(vertical(4.59,1.66,-.66,-.95),null);
  assert.equal(vertical(5.17,2.20,-.66,-.95),null);
});

test('long hall has side galleries and an actual fly-through in the middle', () => {
  assert.ok(vertical(-4.78,-2.13,-1.12,-1.41));
  assert.ok(vertical(-4.78,-1.08,-1.12,-1.41));
  assert.equal(vertical(-4.65,-1.60,-1.12,-1.41),null);
  assert.equal(vertical(-4.684,-2.135,-1.12,-1.41),null);
});

test('east-north platform remains a traversable opening with a solid four-sided rim', () => {
  const r = .19 / site.alignment.scale;
  for (const [x,y] of [[-4.881,-.79],[-4.890,-.797],[-4.870,-.772]]) {
    assert.equal(vertical(x,y,.18,-.31,r),null);
  }
  for (const [x,y] of [[-4.945,-.79],[-4.820,-.79],[-4.881,-.85],[-4.881,-.716]]) {
    assert.ok(vertical(x,y,.18,-.31,r));
  }
  assert.equal(vertical(-2.790,-2.430,.18,-.31,r),null);
});

test('four-silo dive is open while the separate six-silo roof remains closed', () => {
  assert.equal(vertical(1.41,3.87,-.31,-.54),null);
  assert.ok(vertical(4.79,-2.202,-.04,-.34));
  assert.ok(vertical(4.79,-2.252,-.50,-1.90));
});

test('northwest utility has an open entrance and roof hatch but physical surrounding walls', () => {
  assert.equal(hit([-4.18,5.70,-1.85],[-4.18,5.82,-1.85]),null);
  assert.ok(hit([-4.36,5.70,-1.85],[-4.36,5.82,-1.85]));
  assert.equal(vertical(-4.22,5.94,-1.37,-1.13),null);
  assert.ok(vertical(-4.40,5.94,-1.37,-1.13));
});

test('west-silo exterior stairs remain solid for swept collision', () => {
  const r = .25 / site.alignment.scale;
  for (const deg of [-35,-65,-90,-115,-145]) {
    const t = Math.abs(deg+35)/110, z=-1.985+.435*t, a=deg*Math.PI/180;
    const x=-2.1134+.47*Math.cos(a), y=2.1267+.47*Math.sin(a);
    assert.ok(hit([x,y,z+.105],[x,y,z-.11],r),`Missing stair near ${deg} degrees`);
  }
});

test('obsolete vessel geometry and fictional scan courtyard stairs stay absent', () => {
  const r = .19 / site.alignment.scale;
  for (const y of [1.31,1.67,2.03,2.39]) {
    assert.equal(hit([4.71,y,-1.56],[4.86,y,-1.56],r),null);
  }
  assert.equal(vertical(-3.63,2.90,-1.20,-1.95,r),null);
  assert.equal(vertical(-3.36,2.96,-1.20,-1.95,r),null);
});
