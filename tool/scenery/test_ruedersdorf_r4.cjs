'use strict';
// R4 retained chimney and roof paths; R4 hall fittings superseded by R5 tests.
// R4 static collision paths, in the model's local coordinates. No terrain or LoD2.
const fs=require('node:fs'),path=require('node:path'),test=require('node:test'),assert=require('node:assert/strict');
const C=require(process.env.FPV_COLLISION_RUNTIME||'../../web/scenery_collision.js');
const b=fs.readFileSync(process.env.FPV_R4_FPC||path.resolve(__dirname,'../../web/assets/scenery/local_reference.fpc'));
const m=C.parse(b.buffer.slice(b.byteOffset,b.byteOffset+b.byteLength)),R=.25/16.023268178233355;
const cases=[['straight through both portals A to B',[-.8,1.958,-1.70],[0,1.958,-1.70],false],['straight through both portals B to A',[0,1.958,-1.70],[-.8,1.958,-1.70],false],['second entry',[0,1.958,-1.70],[-.367,1.958,-1.70],false],['second exit',[-.367,1.958,-1.70],[0,1.958,-1.70],false],['second wall above opening',[0,1.958,-.5],[-.367,1.958,-.5],true],['side wall',[-.367,2.30,-1.70],[-.367,1.958,-1.70],true],['jamb B',[0,2.035,-1.70],[-.367,2.035,-1.70],true],['jamb A',[-.8,2.035,-1.70],[-.367,2.035,-1.70],true],['new roof opening',[-2.60,-1.59,.2],[-2.60,-1.59,-.32],false],['roof next to opening',[-2.72,-1.59,.2],[-2.72,-1.59,-.32],true]];
for(const [name,a,z,hit] of cases)test(name,()=>assert.equal(!!C.sweep(m,a,z,R),hit));
