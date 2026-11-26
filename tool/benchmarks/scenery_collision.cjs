#!/usr/bin/env node
// Synthetic CPU microbenchmark, not a mobile/GPU frame-rate guarantee.
'use strict';
const fs=require('node:fs'),path=require('node:path'),os=require('node:os'),{performance}=require('node:perf_hooks');
const Collision=require('../../web/features/scenery/scenery_collision.js');
const data=fs.readFileSync(path.join(__dirname,'../../test/fixtures/scenery/collision_grid.fpc'));
const mesh=Collision.parse(data.buffer.slice(data.byteOffset,data.byteOffset+data.length));
// Reference traversal disables acceleration while retaining identical triangles
// and the same narrow-phase sweep. This is not an importable FPC leaf layout.
const reference={...mesh,bounds:mesh.bounds.subarray(0,6),children:new Int32Array([-1,mesh.triangleCount])};
const paths=Array.from({length:100},(_,i)=>[[-5,.5+(17*i)%69,.5+(31*i)%69],[5,.5+(17*i)%69,.5+(31*i)%69]]);
function measure(model){const times=[],stats={};for(const [a,b]of paths){const start=performance.now();const hit=Collision.sweep(model,a,b,.25,'double',stats);if(!hit)throw Error('Expected synthetic wall hit');times.push(performance.now()-start);}times.sort((a,b)=>a-b);return {p50Ms:times[49],p95Ms:times[94],nodes:stats.nodes,triangleTests:stats.triangles};}
for(const [a,b]of paths.slice(0,5)){Collision.sweep(mesh,a,b,.25);Collision.sweep(reference,a,b,.25);}
console.log(JSON.stringify({scope:'Synthetic CPU sweep microbenchmark',node:process.version,platform:process.platform,cpu:os.cpus()[0]?.model,meshBytes:mesh.byteLength,triangles:mesh.triangleCount,nodes:mesh.nodeCount,rays:paths.length,unaccelerated:measure(reference),bvh:measure(mesh)},null,2));
