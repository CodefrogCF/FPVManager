'use strict';
// Repository-local mesh only; no external assets or real RF claims.
const fs=require('node:fs'),path=require('node:path'),{performance}=require('node:perf_hooks');
const collision=require('../../web/features/scenery/scenery_collision.js');
const root=path.join(__dirname,'../../web/assets/scenery');
const catalog=JSON.parse(fs.readFileSync(path.join(root,'catalog.json'),'utf8')).sceneries[0];
const data=fs.readFileSync(path.join(root,catalog.collisionAsset));
const mesh=collision.parse(data.buffer.slice(data.byteOffset,data.byteOffset+data.byteLength));
const scale=catalog.alignment.scale;
const scenarios={aboveRoof:[[-12,0,5],[12,0,5]],acrossSite:[[-12,4.5,-2],[12,4.5,-2]],vertical:[ [0,0,-5],[0,0,5]],longApproach:[[-100,3,1],[8,3,1]]};
const n=Number(process.argv[2]??200);if(!Number.isInteger(n)||n<1||n>10000)throw Error('Invalid sample count');
const result=[];
for(const [scenario,[a,b]] of Object.entries(scenarios))for(const frequency of [868,5800]){
 const run=()=>{const start=performance.now(),budget={nodes:8192,triangles:4096,deadline:start+6};const trace=collision.rfTrace(mesh,a,b,scale,frequency,.6,budget);return {ms:performance.now()-start,complete:trace.complete,hits:trace.hits.length,nodes:8192-budget.nodes,triangles:4096-budget.triangles};};
 for(let i=0;i<20;i++)run();const samples=Array.from({length:n},run),sorted=samples.map(x=>x.ms).sort((a,b)=>a-b),percentile=p=>+sorted[Math.min(n-1,Math.floor(n*p))].toFixed(3);
 result.push({scenario,frequencyMhz:frequency,iterations:n,complete:samples.filter(x=>x.complete).length,p50Ms:percentile(.5),p95Ms:percentile(.95),p99Ms:percentile(.99),maxNodes:Math.max(...samples.map(x=>x.nodes)),maxTriangles:Math.max(...samples.map(x=>x.triangles)),maxCrossings:Math.max(...samples.map(x=>x.hits))});
}
console.log(JSON.stringify({scope:'Node CPU-only; local FPC BVH, no renderer/terrain/bridge/GPU',runtime:process.version,platform:process.platform,meshTriangles:mesh.triangleCount,meshNodes:mesh.nodeCount,scale,samples:result},null,2));
