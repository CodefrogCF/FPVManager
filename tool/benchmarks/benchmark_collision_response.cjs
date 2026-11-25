#!/usr/bin/env node
// Synthetic CPU-only benchmark: does not include Cesium tile GPU picking,
// streamed model loads, Android WebView or Windows WebView2 costs.
const {performance}=require('node:perf_hooks');
const collision=require('../../web/features/flight/physics/collision_response.js');
const {createSimulator}=require('../../web/features/flight/free_flight.js');
const loops=100000;
let checksum=0;
function timed(label,callback){
    const start=performance.now();
    for(let i=0;i<loops;i++)checksum+=callback(i);
    return {label,samples:loops,milliseconds:Number((performance.now()-start).toFixed(2))};
}
const response=timed('normal/tangent collision resolution',i=>{
    const incoming={north:20+(i%19),east:-2-(i%3),up:-5-(i%7)};
    const normal={north:0,east:0,up:1};
    return collision.resolve(incoming,normal,{mode:'rebound',restitution:.12,friction:.28}).velocity.north;
});
const point={latitude:46.7,longitude:8.4,height:1010};
const move=(p,n,e)=>({latitude:p.latitude+n/111320,longitude:p.longitude+e/76000});
const gradients=timed('rendered terrain normal approximation',i=>{
    const n=collision.terrainNormal(point,p=>1000+(p.latitude-point.latitude)*111320*.2,move);
    return n?.north??0;
});
const output={benchmark:'Issue #142 synthetic collision CPU microbenchmark',
    limitations:'No Cesium, GPU, tile streaming, or platform performance measurement',
    results:[response,gradients],checksum:Number(checksum.toFixed(4))};
console.log(JSON.stringify(output,null,2));

// A bounded long-range simulation with a synthetic known-normal wall: measure
// the entire fixed-step collision pipeline (not real Cesium GPU picking).
(async()=>{
    const spawn={latitude:46.7,longitude:8.4},radius=6378137,rad=Math.PI/180;
    const east=p=>(p.longitude-spawn.longitude)*rad*radius*Math.cos(spawn.latitude*rad);
    let sweeps=0,wallContacts=0;
    const sim=createSimulator({sampleHeight:async()=>1000,renderedHeight:()=>1000,
        isTerrainReady:()=>true,applyPose:()=>{},onState:()=>{},
        captureCamera:()=>({heading:0}),restoreCamera:()=>{},
        sampleWind:()=>({available:true,north:30,east:26,up:0}),
        terrainCollision:()=>{sweeps++;return false;},
        modeledCollision:(a,b)=>{
            sweeps++;
            if(east(a)<200&&east(b)>=200){wallContacts++;
                return {kind:'bridge',normal:{north:0,east:-1,up:0},
                    fraction:(200-east(a))/(east(b)-east(a))};}
            return false;
        }});
    await sim.start({...spawn,agl:500,physicsModel:'advanced',flightMode:'acro',
        collisionResponse:{mode:'slide',friction:.15}},new AbortController().signal);
    sim.flightInput({throttle:.5});
    const start=performance.now(),steps=12000;
    for(let i=0;i<steps;i++)sim.tick(1/120);
    const ms=performance.now()-start,state=sim.status();
    console.log(JSON.stringify({benchmark:'Fast FPV flight collision pipeline (synthetic)',
        physicsSeconds:steps/120,steps,sweeps,wallContacts,
        elapsedMilliseconds:Number(ms.toFixed(2)),
        metresTravelledFromSpawn:Number((state.distance).toFixed(1)),
        horizontalSpeedMs:Number(state.horizontalSpeed.toFixed(2)),
        limitations:'No Cesium/GPU, streamed terrain or Android/Windows hardware'},null,2));
})().catch(error=>{console.error(error);process.exitCode=1;});
