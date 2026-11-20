#!/usr/bin/env node
'use strict';
// Synthetic CPU only. Does not establish Android/WebView2 frame performance.
const {performance}=require('node:perf_hooks');
const aerodynamic=require('../web/descent_aerodynamics.js');
const base={thrustAcceleration:9.80665,motorCommand:.55,
    orientation:{w:1,x:0,y:0,z:0},rotorDiameterMeters:.1778,
    motorCount:4,aircraftMassKg:1.32};
function run(label,settings){
    const cfg=aerodynamic.configuration(settings),N=100000;
    const start=performance.now();let checksum=0;
    for(let i=0;i<N;i++){
        const e=aerodynamic.evaluate({...base,timeSeconds:i/120,
            clearanceMeters:.35+(i%30)*.01,
            airVelocity:{north:(i%10)*.4,east:0,up:-5-(i%15)*.25}},cfg);
        checksum+=e.effectiveThrustAcceleration+e.disturbance.east;
    }
    const elapsed=performance.now()-start;
    console.log(`${label}: ${N} samples, ${elapsed.toFixed(1)} ms, `+
        `${Math.round(N/elapsed*1000)} samples/s, checksum=${checksum.toFixed(4)}`);
}
run('disabled',{});
run('all effects enabled',{groundEffectEnabled:true,propwashEnabled:true,
    vortexRingEnabled:true});
