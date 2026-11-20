#!/usr/bin/env node
'use strict';
// CPU-only deterministic workload. Not a Cesium tile download or Android GPU benchmark.
const {performance}=require('node:perf_hooks');
const {createSimulator,distance}=require('../web/free_flight.js');
const start={latitude:46.7,longitude:8.4};
const checkpoints=[5900,6100,10000,14400,20000,30000,49900];
const times=[],results=[];
let terrainQueries=0,known=0,missing=0;
const sim=createSimulator({
    sampleHeight:async()=>1000,
    renderedHeight:point=>{
        terrainQueries++;
        const d=distance(start,point);
        // Simulate missing rendered Cesium tiles near reported failure distances.
        if(d>=8200&&d<=14400 || d>=30000){missing++;return undefined;}
        known++;return 1000;
    },
    captureCamera:()=>({heading:0}),restoreCamera:()=>{},applyPose:()=>{},
    isTerrainReady:()=>true,onState:()=>{}
});
(async()=>{
    await sim.start({...start,flightMode:'gps',agl:500,maxSpeed:28,acceleration:10},new AbortController().signal);
    sim.stick(1,0);
    let index=0,steps=0;
    while(index<checkpoints.length&&steps<70000){
        const t=performance.now();sim.tick(1/30);times.push(performance.now()-t);steps++;
        const state=sim.status();
        if(state.distance>=checkpoints[index]){
            results.push({checkpointKm:checkpoints[index]/1000,actualDistanceKm:+(state.distance/1000).toFixed(2),
                speedKmh:+(state.horizontalSpeed*3.6).toFixed(1),terrainCoverage:state.terrainVerification.state,
                unverifiedMeters:+state.terrainVerification.unverifiedDistanceMeters.toFixed(0),
                reason:state.reason});index++;
        }
    }
    times.sort((a,b)=>a-b);
    const sum=times.reduce((a,b)=>a+b,0);
    console.log(JSON.stringify({note:'CPU-only simulator benchmark. No real terrain download, rendering, device FPS or RF validation.',
        simulationSteps:steps,elapsedSimulationSeconds:+(steps/30).toFixed(1),
        cpuMillisecondsPerStep:{mean:+(sum/times.length).toFixed(4),p95:+times[Math.floor(times.length*.95)].toFixed(4),
            max:+times.at(-1).toFixed(4)},terrainQueries,known,missing,checkpoints:results},null,2));
    if(index!==checkpoints.length||results.some(r=>r.speedKmh<100))process.exitCode=1;
})().catch(error=>{console.error(error);process.exitCode=1;});
