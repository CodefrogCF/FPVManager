'use strict';
const { test }=require('node:test');
const assert=require('node:assert/strict');
const crypto=require('node:crypto');
const fs=require('node:fs');
const path=require('node:path');
const C=require('../../web/scenery_collision.js');
const catalog=require('../../web/assets/scenery/catalog.json');
const file=path.resolve(__dirname,'../../web/assets/scenery/local_reference.fpc');
const raw=fs.readFileSync(file);
const mesh=C.parse(raw.buffer.slice(raw.byteOffset,raw.byteOffset+raw.byteLength));
const item=catalog.sceneries[0];
const r=.25/item.alignment.scale;

test('R13: new FPC and all terrain certificates use identical SHA-256',()=>{
 const hash=crypto.createHash('sha256').update(raw).digest('hex');
 assert.ok(mesh.triangleCount>900000);
 assert.equal(item.terrainCertificate.collisionSha256,hash);
 assert.equal(item.terrainCertificates.length,15);
 assert.ok(item.terrainCertificates.every(c=>c.collisionSha256===hash));
 assert.equal(item.terrainUnderlay.certificate.collisionSha256===hash,false);
 assert.equal(item.alignment.scale,16.023268178233355);
 assert.equal(item.alignment.rotationDeg,99.7993823133657);
 assert.equal(item.clipTerrain,false);
});

test('R13: west-silo exposed stair treads have physical swept sphere contacts',()=>{
 for(const deg of [-35,-65,-90,-115,-145]){
  const t=Math.abs(deg+35)/110;
  const z=-1.985+.435*t;
  const a=deg*Math.PI/180;
  const x=-2.1134+.47*Math.cos(a),y=2.1267+.47*Math.sin(a);
  const from=[x,y,z+.105],to=[x,y,z-.11];
  const hit=C.sweep(mesh,from,to,r);
  assert.ok(hit,`No stair contact for azimuth ${deg}`);
  assert.ok(hit.fraction>=0&&hit.fraction<1);
 }
});
