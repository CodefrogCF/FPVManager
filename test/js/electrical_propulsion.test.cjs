'use strict';
const test=require('node:test'),assert=require('node:assert/strict');
const {create:makeMotor}=require('../../web/features/flight/physics/motor_propeller.js');
const {create:makeBattery}=require('../../web/features/flight/physics/battery_simulation.js');
const solver=require('../../web/features/flight/physics/electrical_propulsion.js');
const {createSimulator}=require('../../web/features/flight/free_flight.js');
const motorProfile={motorKv:1750,motorCount:4,propellerDiameterInches:7,
    propellerPitchInches:3.5,propellerDescription:'HQProp 7x3.5x3V1S',
    takeoffWeightGrams:1320,referenceVoltageVolts:22.2,maxPowerWatts:2200};
const batteryProfile={chemistry:'LiPo',cellCount:6,capacityMah:4500,
    nominalVoltageVolts:22.2,chargePercent:100,hoverPowerWatts:180,
    cruisePowerWatts:250,cruiseSpeedMetersPerSecond:15,
    takeoffWeightGrams:1320,motorCount:4,maxPowerWatts:2200,
    continuousDischargeC:120,resistanceOhmsPerCell:.008};
const near=(a,b,delta=1e-5)=>assert.ok(Math.abs(a-b)<=delta,`${a} ~= ${b} (delta ${delta})`);
function coupled({battery={},motor={},target=1,seconds=2}={}){
    const drive=makeMotor({...motorProfile,...motor});
    const pack=makeBattery({...batteryProfile,...battery});
    let result;
    for(let i=0;i<Math.round(seconds*120);i++){
        result=solver.step(drive,pack,target,1/120);
        pack.tick(1/120,0,0,{propulsionPowerWatts:result.propulsion.propulsionPowerWatts,
            electricalResult:result.electrical,thrustToWeight:result.propulsion.totalThrustNewtons/(1.32*9.80665)});
    }
    return {result,snapshot:pack.snapshot(),drive,pack};
}
test('loaded terminal voltage, motor thrust and charge are coupled, not previous-frame proxies',()=>{
    const charged=coupled(),low=coupled({battery:{chargePercent:12}});
    assert.ok(charged.result.propulsion.totalThrustNewtons>low.result.propulsion.totalThrustNewtons);
    assert.ok(charged.result.propulsion.rpm>low.result.propulsion.rpm);
    assert.ok(charged.snapshot.packVoltageVolts<charged.pack.electricalState().openCircuitPackVoltageVolts);
    near(charged.result.propulsion.loadedPackVoltageVolts,charged.snapshot.packVoltageVolts);
    near(charged.snapshot.currentAmps,charged.result.electrical.currentAmps);
    assert.ok(charged.snapshot.consumedWh>0&&charged.snapshot.consumedAh>0);
    assert.equal(charged.snapshot.electricalCoupling,'estimated-battery-motor-dc');
});
test('constrained discharge rating limits motor power without ignoring auxiliary load',()=>{
    const restricted=coupled({battery:{continuousDischargeC:5}}),unrestricted=coupled();
    assert.ok(restricted.result.propulsion.totalThrustNewtons<unrestricted.result.propulsion.totalThrustNewtons);
    assert.equal(restricted.snapshot.batteryCurrentLimited,true);
    assert.equal(restricted.snapshot.batteryLimitSource,'battery-discharge-current');
    assert.ok(restricted.snapshot.currentAmps<=22.5+1e-5);
    assert.ok(restricted.result.propulsion.propulsionPowerWatts+14.4 <=
        restricted.snapshot.packVoltageVolts*22.5+.1);
});
test('high resistance under load reduces voltage and available thrust',()=>{
    const lowResistance=coupled({battery:{resistanceOhmsPerCell:.003}});
    const highResistance=coupled({battery:{resistanceOhmsPerCell:.04}});
    assert.ok(highResistance.snapshot.packVoltageVolts<lowResistance.snapshot.packVoltageVolts);
    assert.ok(highResistance.result.propulsion.totalThrustNewtons<lowResistance.result.propulsion.totalThrustNewtons);
});
test('separate ESC and motor current limits are reported as constrained DC approximations',()=>{
    const esc=coupled({motor:{escContinuousCurrentAmpsPerChannel:6}});
    const motor=coupled({motor:{motorContinuousCurrentAmpsPerMotor:6}});
    assert.equal(esc.snapshot.escCurrentLimited,true);
    assert.equal(esc.snapshot.motorCurrentLimited,false);
    assert.equal(motor.snapshot.motorCurrentLimited,true);
    assert.equal(motor.snapshot.escCurrentLimited,false);
    assert.equal(esc.result.propulsion.limitSource,'esc-dc-input-proxy');
    assert.equal(motor.result.propulsion.limitSource,'motor-dc-input-proxy');
});
test('equal ESC and motor caps are both independently identified',()=>{
    const both=coupled({motor:{escContinuousCurrentAmpsPerChannel:6,
        motorContinuousCurrentAmpsPerMotor:6}});
    assert.equal(both.snapshot.escCurrentLimited,true);
    assert.equal(both.snapshot.motorCurrentLimited,true);
    assert.ok(both.result.propulsion.activeLimitSources.includes('esc-dc-input-proxy'));
    assert.ok(both.result.propulsion.activeLimitSources.includes('motor-dc-input-proxy'));
});
test('zero throttle does not consume hover or propulsion power; auxiliary counted once',()=>{
    const zero=coupled({target:0,seconds:5});
    near(zero.result.propulsion.propulsionPowerWatts,0);
    near(zero.snapshot.estimatedPowerWatts,14.4,.0001);
    assert.ok(zero.snapshot.consumedWh<.025);
    near(zero.snapshot.currentAmps,zero.snapshot.estimatedPowerWatts/zero.snapshot.packVoltageVolts,1e-4);
});
test('depleted battery cannot produce thrust; missing pack preserves motor-only estimation',()=>{
    const empty=coupled({battery:{chargePercent:0}});
    near(empty.result.propulsion.totalThrustNewtons,0);
    assert.equal(empty.snapshot.batteryCurrentLimited,true);
    assert.equal(empty.snapshot.remainingEnergyWh,0);
    const standalone=makeMotor(motorProfile);
    assert.ok(standalone.tick(1,.1).totalThrustNewtons>0);
});
test('battery peak C window expires without instant reset after brief idle',()=>{
    const pack=makeBattery({...batteryProfile,continuousDischargeC:3,burstDischargeC:60,burstDurationSeconds:.2});
    const motor=makeMotor(motorProfile);
    let burstPower=0;
    for(let i=0;i<40;i++){
        const out=solver.step(motor,pack,1,1/120);
        if(i===10)burstPower=out.propulsion.propulsionPowerWatts;
        pack.tick(1/120,0,0,{propulsionPowerWatts:out.propulsion.propulsionPowerWatts,electricalResult:out.electrical});
    }
    const after=solver.step(motor,pack,1,1/120);
    assert.ok(after.propulsion.propulsionPowerWatts<burstPower);
    assert.equal(pack.electricalState().burstAllowed,false);
});
async function flight(fps,options={}){
    const sim=createSimulator({sampleHeight:async()=>1000,renderedHeight:()=>1000,
        isTerrainReady:()=>true,captureCamera:()=>({heading:0}),restoreCamera:()=>{},
        applyPose:()=>{},onState:()=>{}});
    await sim.start({latitude:46.7,longitude:8.4,agl:500,physicsModel:options.physicsModel||'advanced',
        flightMode:'acro',propulsionProfile:motorProfile,batteryProfile:{...batteryProfile,chargePercent:options.soc??100},
        showBatteryVoltage:true},new AbortController().signal);
    sim.flightInput({throttle:.6,pitch:0,roll:0,yaw:0});
    for(let i=0;i<fps*2;i++)sim.tick(1/fps);
    return sim.status();
}
test('full/near-empty pack flight and energy are deterministic across render rates',async()=>{
    for(const soc of [100,8]){
        const a=await flight(30,{soc}),b=await flight(60,{soc}),c=await flight(120,{soc});
        for(const s of [b,c]){
            near(s.height,a.height,1e-6);
            near(s.propulsion.rpm,a.propulsion.rpm,1e-5);
            near(s.battery.consumedWh,a.battery.consumedWh,1e-6);
            near(s.battery.packVoltageVolts,a.battery.packVoltageVolts,1e-5);
        }
        assert.equal(a.propulsion.coupled,true);
    }
    const fresh=await flight(60),low=await flight(60,{soc:8});
    assert.ok(fresh.propulsion.totalThrustNewtons>low.propulsion.totalThrustNewtons);
    const legacy=await flight(60,{physicsModel:'legacy'});
    assert.equal(legacy.propulsion,null);
});
