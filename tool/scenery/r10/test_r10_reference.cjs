'use strict';
const test=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),crypto=require('node:crypto');
const C=require('../../../web/scenery_collision.js');
const report=require('./height_calibration.json');
const r9=require('../r9/report.json');
const raw=fs.readFileSync(__dirname+'/dgm_ellipsoid_reference.fpc');
const mesh=C.parse(raw.buffer.slice(raw.byteOffset,raw.byteOffset+raw.byteLength));
const sha=b=>crypto.createHash('sha256').update(b).digest('hex');
test('GCG reference exact hash and FPC geometry shape',()=>{
  assert.equal(sha(raw),report.reference_fpc_sha256);
  assert.equal(mesh.triangleCount,156156);
  assert.equal(mesh.vertices.length/3,78638);
});
test('121 vertical swept-sphere collisions across calibrated terrain grid',()=>{
  const [x0,y0,x1,y1]=r9.reference_extent_local;
  for(let i=0;i<=10;i++)for(let j=0;j<=10;j++){
    const x=x0+.03+(x1-x0-.06)*i/10,y=y0+.03+(y1-y0-.06)*j/10;
    const hit=C.sweep(mesh,[x,y,0],[x,y,-4],.25/r9.alignment.scale);
    assert.ok(hit,`missing ground at ${x}, ${y}`);
    assert.ok(hit.fraction>.4&&hit.fraction<.7);
  }
});
test('R8 production collider and terrain masks remain unchanged',()=>{
  const catalog=require('../../../web/assets/scenery/catalog.json').sceneries[0];
  assert.equal(catalog.terrainCertificate.collisionSha256,report.sources.r8_collision_sha256);
  assert.equal(catalog.clipTerrain,false);
  assert.equal(catalog.assets.length,1);
  assert.equal(catalog.assets[0].path,'local_reference.glb');
});
test('ellipsoid height, modeled root height and checks remain consistent',()=>{
  const a=report.anchor;
  assert.ok(Math.abs(a.terrain_ellipsoid_m-a.dgm_nhn_m-a.gcg2016_anomaly_m)<1e-8);
  assert.ok(Math.abs(a.model_root_ellipsoid_m-(a.terrain_ellipsoid_m-a.model_reference_local_up*r9.alignment.scale))<1e-8);
  assert.equal(report.seams.filter(v=>v.within_0_5m).length,7);
  assert.equal(report.seam_sample_count,536);
  assert.ok(report.grid_local.geoid_anomaly_variation_m<.03);
});
