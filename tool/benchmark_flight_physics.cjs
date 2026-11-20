// CPU-only physics scheduling baseline; not a Cesium, Android or GPU benchmark.
'use strict';
const {performance}=require('node:perf_hooks');
const {createSimulator}=require('../web/free_flight.js');
const spawn={latitude:46.7,longitude:8.4};
const seconds=30;
async function bench(mode,fps){
    const sim=createSimulator({sampleHeight:async()=>1000,renderedHeight:()=>1000,
        captureCamera:()=>({heading:0}),restoreCamera:()=>{},applyPose:()=>{},
        isTerrainReady:()=>true,onState:()=>{}});
    await sim.start({...spawn,agl:1000,flightMode:'acro',physicsModel:mode,physicsStepHz:120},new AbortController().signal);
    sim.flightInput({throttle:.6,pitch:.25,roll:.1,yaw:.1});
    const before=performance.now();
    for(let i=0;i<seconds*fps;i++)sim.tick(1/fps);
    const elapsed=performance.now()-before,s=sim.status();
    console.log(`${mode.padEnd(8)} ${String(fps).padStart(3)} fps: ${elapsed.toFixed(1)} ms CPU / ${seconds}s simulated, `+
        `${s.physicsDiagnostics.simulatedSeconds.toFixed(3)}s physics, ${s.physicsDiagnostics.droppedSeconds.toFixed(4)}s dropped, `+
        `${s.distance.toFixed(1)}m distance`);
    sim.stop();
}
(async()=>{for(const mode of ['legacy','advanced'])for(const fps of [30,60,120])await bench(mode,fps);})()
    .catch(e=>{console.error(e);process.exitCode=1;});
