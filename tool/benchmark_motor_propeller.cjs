#!/usr/bin/env node
'use strict';
// CPU-only deterministic microbenchmark. NOT a Cesium/Flutter/device FPS result.
const {performance}=require('node:perf_hooks');
const {create}=require('../web/motor_propeller.js');
const profile={motorKv:1750,motorCount:4,propellerDiameterInches:7,
    propellerPitchInches:3.5,propellerDescription:'HQProp 7x3.5x3V1S',
    takeoffWeightGrams:1320,referenceVoltageVolts:22.2,maxPowerWatts:2200,
    escContinuousCurrentAmpsPerChannel:60};
const model=create(profile);if(!model)throw Error('Reference aircraft unavailable');
const frames=120000;
let watts=0,newtons=0;
const start=performance.now();
for(let i=0;i<frames;i++){
    const level=.35+.3*(.5+.5*Math.sin(i*.004));
    const result=model.tick(level,1/120,22.2);
    watts+=result.propulsionPowerWatts;
    newtons+=result.totalThrustNewtons;
}
const elapsed=performance.now()-start;
console.log(JSON.stringify({scenario:'CPU-only motor/propeller 7-inch profile',frames,
    milliseconds:Math.round(elapsed*1000)/1000,
    microsecondsPerStep:Math.round(elapsed*1000/frames*1000)/1000,
    meanPowerWatts:Math.round(watts/frames),
    meanThrustNewtons:Math.round(newtons/frames),
    note:'No terrain, Cesium, Flutter, GPU or battery coupling benchmarked'},null,2));
