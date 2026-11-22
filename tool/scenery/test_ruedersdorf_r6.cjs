'use strict';
const fs=require('node:fs'),path=require('node:path'),test=require('node:test'),assert=require('node:assert/strict');
const C=require(process.env.FPV_COLLISION_RUNTIME||'../../web/scenery_collision.js');
const b=fs.readFileSync(process.env.FPV_R6_FPC||path.resolve(__dirname,'../../web/assets/scenery/local_reference.fpc'));
const m=C.parse(b.buffer.slice(b.byteOffset,b.byteOffset+b.byteLength)),R=.25/16.023268178233355;
const cases=[
['gangway flight between rails',[3.46,-1.578,-.397],[4.21,-1.578,-.397],false],
['gangway reverse flight',[4.21,-1.578,-.397],[3.46,-1.578,-.397],false],
['gangway deck',[3.62,-1.578,-.34],[3.62,-1.578,-.52],true],
['gangway railing',[3.62,-1.58,-.413],[3.62,-1.70,-.413],true],
['gangway stair',[3.25,-1.578,-.35],[3.25,-1.578,-.70],true],
['east block lower opening',[4.05,1.24,-1.83],[4.65,1.24,-1.83],false],
['east block wall',[4.05,1.43,-1.52],[4.64,1.43,-1.52],true],
['west block entrance',[-3.03,1.51,-1.88],[-3.03,2.05,-1.88],false],
['west block solid wall',[-4.16,1.53,-1.3],[-4.16,2.05,-1.3],true],
['west block open shaft',[-3.5,2.45,-1.85],[-3.5,2.45,-.86],false],
['six silo gallery floor',[4.21,-1.1,-.32],[4.21,-1.1,-.55],true],
['six silo gallery passage',[4.21,-1.0,-.35],[4.21,-.20,-.35],false],
['six silo tower slab',[4.2,-2.21,-1.91],[4.2,-2.21,-1.70],true],
['vault gable solid',[.8,-5.94,-.6],[.3,-5.94,-.6],true],
['four silo solid wall',[.0147,3.25,-1.3],[.0147,3.8762,-1.3],true]
];
for(const [name,a,z,hit] of cases)test(name,()=>assert.equal(!!C.sweep(m,a,z,R),hit));
