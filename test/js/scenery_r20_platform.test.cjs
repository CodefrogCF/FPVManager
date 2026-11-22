'use strict';
const {test}=require('node:test'),assert=require('node:assert/strict');
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const Collision=require('../../web/scenery_collision.js');
const catalog=require('../../web/assets/scenery/catalog.json');
const p=path.resolve(__dirname,'../../web/assets/scenery/local_reference.fpc');
const b=fs.readFileSync(p);
const mesh=Collision.parse(b.buffer.slice(b.byteOffset,b.byteOffset+b.byteLength));
const site=catalog.sceneries.find(s=>s.id==='de-bb-ruedersdorf-chemical-plant');
const radius=.19/site.alignment.scale;
const sweep=(x,y,z0,z1)=>Collision.sweep(mesh,[x,y,z0],[x,y,z1],radius);

test('R20 georeference: -X points north and +Y points east at site heading',()=>{
 const angle=site.alignment.rotationDeg*Math.PI/180;
 const c=Math.cos(angle),s=Math.sin(angle);
 // ENU location of platform center relative to building center (-3.275,-1.592).
 const dx=-4.86-(-3.275),dy=-.72-(-1.592);
 const east=c*dx+s*dy,north=-s*dx+c*dy;
 assert.ok(east>0.5 && north>1.1,{east,north});
 // North end itself at x=-5.06, east facade at y=-.88.
 assert.ok(-4.86 < -4.60 && -.72 > -.88);
});

test('R20 full free center, both opposite solid rim strips, no old west platform',()=>{
 for(const [x,y] of [[-4.860,-.720],[-4.835,-.735],[-4.90,-.77]]){
   assert.equal(sweep(x,y,.18,-.31),null,`Platform hole blocked at ${x}/${y}`);
 }
 for(const [x,y] of [[-4.994,-.72],[-4.724,-.72],[-4.86,-.575],[-4.86,-.868]]){
   assert.ok(sweep(x,y,.18,-.31),`Expected load-bearing platform ring at ${x}/${y}`);
 }
 assert.equal(sweep(-2.790,-2.430,.18,-.31),null,'R16 west platform survived');
});

test('R20 keep central 4-silo roof open and SE 6-silo headhouse closed',()=>{
 assert.equal(sweep(1.41,3.87,-.31,-.54),null);
 assert.ok(sweep(4.79,-2.202,-.04,-.34));
});

test('R20 catalog certificates refer to the new collider, not R19',()=>{
 const digest=crypto.createHash('sha256').update(b).digest('hex');
 assert.equal(site.terrainCertificate.collisionSha256,digest);
 assert.equal(site.terrainCertificates.length,16);
 assert.ok(site.terrainCertificates.every(c=>c.collisionSha256===digest));
 assert.equal(site.alignment.rotationDeg,99.7993823133657);
 assert.ok(mesh.triangleCount>949000 && mesh.triangleCount<1000000);
});
