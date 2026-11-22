'use strict';
const {test}=require('node:test'),assert=require('node:assert/strict');
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const Collision=require('../../web/scenery_collision.js');
const catalog=require('../../web/assets/scenery/catalog.json');
const p=path.resolve(__dirname,'../../web/assets/scenery/local_reference.fpc');
const data=fs.readFileSync(p);
const mesh=Collision.parse(data.buffer.slice(data.byteOffset,data.byteOffset+data.byteLength));
const s=catalog.sceneries.find(e=>e.id==='de-bb-ruedersdorf-chemical-plant');
const radius=0.25/s.alignment.scale;

test('R15: open six-silo roof permits a centered downward dive without any hidden floor',()=>{
 const from=[4.79,-2.202,-.025],to=[4.79,-2.202,-1.96];
 assert.equal(Collision.sweep(mesh,from,to,radius),null,'Roof or staircase blocks central 25cm-radius dive');
});
test('R15: closed roof outside stair well and stepped lower flights still collide',()=>{
 assert.ok(Collision.sweep(mesh,[4.15,-2.20,-.19],[4.15,-2.20,-.30],radius),'Top gallery roof outside opening must remain solid');
 assert.ok(Collision.sweep(mesh,[4.79,-2.252,-.50],[4.79,-2.252,-1.90],radius),'Stair flights must collide');
});
test('R15: regenerated collider matches all certified R8 terrain patches and preserves R11 DGM underlay',()=>{
 assert.equal(mesh.triangleCount,940208);
 const sha=crypto.createHash('sha256').update(data).digest('hex');
 assert.equal(s.terrainCertificate.collisionSha256,sha);
 assert.equal(s.terrainCertificates.length,16);
 assert.ok(s.terrainCertificates.every(c=>c.collisionSha256===sha));
 assert.notEqual(s.terrainUnderlay.certificate.collisionSha256,sha);
});
