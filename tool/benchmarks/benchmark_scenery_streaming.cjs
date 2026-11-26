#!/usr/bin/env node
// Synthetic CPU/lifecycle benchmark with real manager and Cesium math, mocked GPU/network.
'use strict';
const {performance}=require('node:perf_hooks'),os=require('node:os');
const C=require('../../web/cesium/index.cjs'),M=require('../../web/features/scenery/scenery_manager.js');
const {createRuntime}=require('../../web/features/flight/physics/flight_physics.js');
const cycles=Number(process.argv[2]??200),preset=process.argv[3]??'balanced';
if(!Number.isInteger(cycles)||cycles<1||cycles>10000)throw Error('Cycles must be 1..10000');
const policy=M.streamingOptions({preset}),MiB=1024*1024;
const point={longitude:8.4,latitude:46.7,height:100},outside={...point,latitude:46.75};
const scene={id:'benchmark',name:'Benchmark',author:'Synthetic',license:'CC0',heightDatum:'WGS84 ellipsoid',enabled:true,
 alignment:{...point,ellipsoidHeightM:100,scale:1,rotationDeg:0,opacity:1},heightAlignmentMode:'fixed',physicalCollisionsEnabled:true,
 collisionAsset:'benchmark.fpc',assets:[{kind:'glb',path:'benchmark.glb'}],loadRadiusM:1000,unloadRadiusM:1500};
const flush=()=>new Promise(r=>setImmediate(r));
const quantile=(values,p)=>values.slice().sort((a,b)=>a-b)[Math.ceil((values.length-1)*p)];
async function run(){
 let camera=outside,clock=0,created=0,destroyed=0,colliderLoads=0,steps=0;
 const models=new Set(),credits=new Set(),durations=[],stepDurations=[],heapSamples=[];
 const viewer={scene:{preUpdate:new C.Event(),requestRender(){},primitives:{add:m=>models.add(m),remove:m=>{if(!models.delete(m))throw Error('Unexpected model removal');m.destroy();}}},cesiumWidget:{creditDisplay:{addStaticCredit:c=>credits.add(c),removeStaticCredit:c=>credits.delete(c)}}};
 const manager=M.create(C,viewer,{fetchCatalog:async()=>({schemaVersion:1,sceneries:[scene]}),position:()=>camera,now:()=>clock,streaming:policy,diagnosticsEnabled:()=>true,
  modelFactory:async()=>{created++;return {ready:true,show:true,statistics:{geometryByteLength:8*MiB,texturesByteLength:16*MiB,trianglesLength:100000},destroy(){destroyed++;}};},
  collisionFactory:async()=>{colliderLoads++;return {triangleCount:10000,byteLength:2*MiB};}});
 const runtime=createRuntime({mode:'advanced',hz:120,integrate:()=>{const start=performance.now();steps++;stepDurations[(steps-1)%240]=performance.now()-start;},snapshot:()=>({}),present(){}});
 const tick=()=>{clock+=500;manager.tick(true);};
 const memory=()=>{global.gc?.();return process.memoryUsage().heapUsed;};
 let before,after,peakModels=0,peakCollisionBytes=0;const start=performance.now();
 try{
  await manager.initialize();before=memory();
  for(let i=0;i<cycles;i++){
   const t=performance.now();camera=point;tick();await flush();tick();await flush();tick();
   const active=manager.performanceSnapshot();peakModels=Math.max(peakModels,active.residentModels);peakCollisionBytes=Math.max(peakCollisionBytes,active.collisionBytes);
   if(active.residentModels!==1||active.activeCollisionTriangles!==10000)throw Error('Scene did not activate');
   for(let j=0;j<60;j++)runtime.advance(1/60);
   camera=outside;tick();const unloaded=manager.performanceSnapshot();
   if(models.size||credits.size||unloaded.collisionBytes||unloaded.localAdmissionBytes)throw Error('Resource retained after unload');
   durations.push(performance.now()-t);
   if((i+1)%Math.max(1,Math.floor(cycles/4))===0)heapSamples.push({cycle:i+1,bytes:memory()});
  }
  after=memory();if(created!==destroyed||colliderLoads!==cycles||steps!==cycles*120)throw Error('Lifecycle or fixed timestep mismatch');
  const d=manager.performanceSnapshot();
  console.log(JSON.stringify({scope:'Synthetic lifecycle CPU benchmark; mocked asset/GPU/physics workload, no network or real device',node:process.version,cpu:os.cpus()[0]?.model,preset,cycles,elapsedMs:+(performance.now()-start).toFixed(2),cycleMs:{p50:quantile(durations,.5),p95:quantile(durations,.95)},created,destroyed,colliderLoads,peakModels,peakCollisionBytes,remainingModels:models.size,remainingCredits:credits.size,remainingCollisionBytes:d.collisionBytes,historySamples:d.loadSamples.length,physics:runtime.diagnostics(),syntheticStepP95Ms:quantile(stepDurations,.95),heapBeforeBytes:before,heapAfterBytes:after,heapSamples,explicitGc:typeof global.gc==='function'},null,2));
 }finally{manager.dispose();}
}
run().catch(e=>{console.error(e);process.exitCode=1;});
