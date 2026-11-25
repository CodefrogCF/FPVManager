#!/usr/bin/env node
'use strict';
// Isolated CPU-only electrical/propulsion benchmark; not a device FPS result.
const {performance}=require('node:perf_hooks');
const {create:makeBattery}=require('../../web/features/flight/physics/battery_simulation.js');
const {create:makeMotor}=require('../../web/features/flight/physics/motor_propeller.js');
const solver=require('../../web/features/flight/physics/electrical_propulsion.js');
const drone={motorKv:1750,motorCount:4,propellerDiameterInches:7,propellerPitchInches:3.5,
    propellerDescription:'HQProp 7x3.5x3V1S',takeoffWeightGrams:1320,referenceVoltageVolts:22.2,
    maxPowerWatts:2200,escContinuousCurrentAmpsPerChannel:60};
const battery={chemistry:'LiPo',cellCount:6,capacityMah:4500,nominalVoltageVolts:22.2,
    chargePercent:100,continuousDischargeC:120,hoverPowerWatts:180,cruisePowerWatts:250,
    cruiseSpeedMetersPerSecond:15,takeoffWeightGrams:1320,motorCount:4,maxPowerWatts:2200};
const frames=60000,drive=makeMotor(drone),pack=makeBattery(battery);
let watts=0,thrust=0,iterations=0;
const started=performance.now();
for(let i=0;i<frames;i++){
    const target=.35+.3*(.5+.5*Math.sin(i*.004));
    const solved=solver.step(drive,pack,target,1/120);
    pack.tick(1/120,0,0,{propulsionPowerWatts:solved.propulsion.propulsionPowerWatts,
        electricalResult:solved.electrical});
    watts+=solved.electrical.totalPowerWatts;
    thrust+=solved.propulsion.totalThrustNewtons;
    iterations+=solved.electrical.iterationCount;
}
const elapsed=performance.now()-started;
console.log(JSON.stringify({scenario:'CPU-only coupled 7-inch 6S Advanced Acro propulsion',frames,
    milliseconds:+elapsed.toFixed(2),microsecondsPerStep:+(elapsed*1000/frames).toFixed(3),
    meanIterations:+(iterations/frames).toFixed(2),meanPowerWatts:+(watts/frames).toFixed(2),
    meanThrustNewtons:+(thrust/frames).toFixed(2),
    note:'No Cesium, GPU, Flutter, terrain or physical drone calibration'},null,2));
