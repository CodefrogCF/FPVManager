'use strict';
// Real asset test. Run after applying R2: node --test tool/scenery/test_ruedersdorf_r2.cjs
const fs=require('node:fs'),path=require('node:path'),test=require('node:test'),assert=require('node:assert/strict');
const C=require(process.env.FPV_COLLISION_RUNTIME||'../../web/features/scenery/scenery_collision.js');
const file=process.env.FPV_R2_FPC||path.resolve(__dirname,'../../web/assets/scenery/local_reference.fpc');
const b=fs.readFileSync(file),m=C.parse(b.buffer.slice(b.byteOffset,b.byteOffset+b.byteLength));
const R=.25/16.023268178233355;
const cases=[
['chimney horizontal entry',[-.80,1.958,-1.70],[-.367,1.958,-1.70],false],
['chimney ascent through open rim',[-.367,1.958,-1.70],[-.367,1.958,.7],false],
['chimney dive from open rim',[-.367,1.958,.7],[-.367,1.958,-1.70],false],
['chimney exit through lower opening',[-.367,1.958,-1.70],[-.80,1.958,-1.70],false],
// R4: user confirmed a second lower opening. Restore R2 expectation on rollback.
['chimney opposite entry (R4)',[.0,1.958,-1.70],[-.367,1.958,-1.70],false],
['chimney wall above opening',[-.80,1.958,-.5],[-.367,1.958,-.5],true],
['chimney bottom slab',[-.367,1.958,-1.7],[-.367,1.958,-2.2],true],
['long hall entrance',[-3.886,-.55,-1.81],[-3.886,-1.42,-1.81],false],
// R5: photo-confirmed central column at the height transition; use the adjacent aisle.
['long hall aisle alongside central pillar',[-4.9,-1.90,-1.25],[3.1,-1.90,-1.25],false],
['long hall window',[-4.397,-.55,-.98],[-4.397,-1.25,-.98],false],
['long hall side pier',[-5.035+.25536*3,-.55,-1.65],[-5.035+.25536*3,-1.15,-1.65],true],
['long hall roof',[-3.2,-1.59,.3],[-3.2,-1.59,-.7],true],
['long hall floor',[-3.2,-1.59,-1.4],[-3.2,-1.59,-2.1],true],
['vaulted hall entrance',[-1.591,-4.6,-1.81],[-1.591,-5.3,-1.81],false],
['vaulted hall exterior scanned obstacle',[-1.591,-4.5,-1.81],[-1.591,-4.6,-1.81],true],
['vaulted hall skylight',[-2.527,-5.94,.1],[-2.527,-5.94,-1.1],false],
['vaulted hall aisle',[-3.05,-5.9,-1.25],[.2,-5.9,-1.25],false],
['vaulted hall roof',[-1.7,-5.9,.1],[-1.7,-5.9,-1.4],true],
['silo frame gap',[1.46,3.35,-1.9],[1.46,4.40,-1.9],false],
['silo frame pillar',[1.27,3.35,-1.9],[1.27,3.85,-1.9],true],
['silo roof platform',[1.4,3.82,-.25],[1.4,3.82,-.7],true],
// R6: original scan shows an enclosed production block with floor levels, not an open atrium.
['east production block reconstructed intermediate slab',[4.885,2.03,-1.86],[4.885,2.03,-.80],true],
['open factory perimeter floor',[4.55,2.0,-1.4],[4.55,2.0,-1.8],true],
];
for(const [name,a,z,hit] of cases)test(name,()=>{const h=C.sweep(m,a,z,R);assert.equal(!!h,hit,h?`unexpected contact at ${h.fraction}: ${a.map((x,i)=>x+(z[i]-x)*h.fraction).join(',')}`:'expected obstacle not found');});
