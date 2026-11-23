'use strict';
const test=require('node:test'),assert=require('node:assert/strict');
const motor=require('../../web/features/flight/physics/motor_propeller.js');
const {createSimulator}=require('../../web/features/flight/free_flight.js');
const reference={motorKv:1750,motorCount:4,propellerDiameterInches:7,
    propellerPitchInches:3.5,propellerDescription:'HQProp 7x3.5x3V1S',
    takeoffWeightGrams:1320,referenceVoltageVolts:22.2,maxPowerWatts:2200,
    escContinuousCurrentAmpsPerChannel:60};
const near=(a,b,limit=1e-8)=>assert.ok(Math.abs(a-b)<limit,`${a} should be within ${limit} of ${b}`);
function flight(profile,other={}){
    const sim=createSimulator({sampleHeight:async()=>1000,renderedHeight:()=>1000,
        isTerrainReady:()=>true,captureCamera:()=>({heading:0}),restoreCamera:()=>{},
        applyPose:()=>{},onState:()=>{}});
    return {sim,start:()=>sim.start({latitude:46.7,longitude:8.4,agl:500,
        physicsModel:'advanced',flightMode:'acro',propulsionProfile:profile,...other},new AbortController().signal)};
}
function tick(sim,seconds){for(let i=0;i<Math.round(seconds*120);i++)sim.tick(1/120);}
test('profile interprets propeller description blade count, never propellerCount as blades',()=>{
    assert.equal(motor.bladeCount('HQProp 7x3.5x3V1S'),3);
    assert.equal(motor.bladeCount('7×3.5×2'),2);
    const p=motor.normalize({...reference,propellerCount:4});
    assert.equal(p.motorCount,4);assert.equal(p.bladeCount,3);
    assert.equal(motor.normalize({...reference,motorKv:null}),null);
    assert.equal(motor.normalize({...reference,manufacturerCurve:[{throttle:1,thrustNewtonsPerMotor:20,powerWattsPerMotor:500}]}),null);
});
test('model predicts thrust from propeller, motor KV, voltage, mass and RPM',()=>{
    const a=motor.create(reference),b=motor.create({...reference,propellerDiameterInches:5});
    a.reset(.65);b.reset(.65);
    assert.ok(a.state.totalThrustNewtons>b.state.totalThrustNewtons);
    assert.ok(a.state.propulsionPowerWatts>b.state.propulsionPowerWatts);
    assert.ok(a.state.rpm>0);assert.ok(a.state.estimatedCurrentAmps>0);
    assert.ok(a.state.maximumThrustToWeight>1);
    const lowerVoltage=motor.output(a.configuration,.65,18);
    const fullVoltage=motor.output(a.configuration,.65,22.2);
    assert.ok(lowerVoltage.totalThrustNewtons<fullVoltage.totalThrustNewtons);
    assert.ok(lowerVoltage.propulsionPowerWatts<fullVoltage.propulsionPowerWatts);
});
test('manufacturer curve overrides assumptions and respects configured power limits',()=>{
    const manufacturerCurve=[{throttle:0,thrustNewtonsPerMotor:0,powerWattsPerMotor:0},
        {throttle:.5,thrustNewtonsPerMotor:4,powerWattsPerMotor:100},
        {throttle:1,thrustNewtonsPerMotor:20,powerWattsPerMotor:900}];
    const a=motor.create({...reference,maxPowerWatts:1500,manufacturerCurve});
    a.reset(.5);
    near(a.state.totalThrustNewtons,16);near(a.state.propulsionPowerWatts,400);
    a.reset(1);assert.ok(a.state.propulsionPowerWatts<=1500+1e-6);
    assert.equal(a.state.limited,true);
    assert.equal(a.state.source,'manufacturer-curve-unverified');
});
test('motor inertia, reset, hover command and zero throttle are deterministic',()=>{
    const a=motor.create(reference),b=motor.create(reference);
    const hover=a.hoverCommand();assert.ok(hover>0&&hover<1);
    near(motor.output(a.configuration,hover,22.2).totalThrustNewtons,1.32*9.80665,1e-6);
    a.tick(1,1/120);assert.ok(a.state.command<.2);
    a.reset(0);b.reset(0);
    for(let i=0;i<120;i++){a.tick(.6,1/120);b.tick(.6,1/120);}
    assert.deepEqual(a.state,b.state);
    a.tick(0,1/120);assert.ok(a.state.command>0,'motors spin down over time');
    a.reset(0);near(a.state.propulsionPowerWatts,0);near(a.state.totalThrustNewtons,0);
});
test('advanced free fall draws low auxiliary power; hardware power is reflected in battery usage',async()=>{
    const battery={chemistry:'LiPo',batteryId:1,cellCount:6,capacityMah:4500,
        nominalVoltageVolts:22.2,chargePercent:100,hoverPowerWatts:180,
        cruisePowerWatts:250,cruiseSpeedMetersPerSecond:15,
        takeoffWeightGrams:1320,motorCount:4,maxPowerWatts:2200};
    const falling=flight(reference,{batteryProfile:battery,showBatteryVoltage:true});
    await falling.start();tick(falling.sim,2);
    const down=falling.sim.status();
    assert.ok(down.verticalSpeed<0);
    assert.equal(down.propulsion.source,'generic-propeller-coefficients');
    near(down.propulsion.propulsionPowerWatts,0,1e-6);
    assert.ok(down.battery.estimatedPowerWatts<35);
    const powered=flight(reference,{batteryProfile:battery,showBatteryVoltage:true});
    await powered.start();powered.sim.flightInput({throttle:.65,pitch:0,roll:0,yaw:0});tick(powered.sim,2);
    assert.ok(powered.sim.status().battery.consumedWh>down.battery.consumedWh*5);
    assert.ok(powered.sim.status().propulsion.rpm>0);
});
test('advanced manual flight uses different hardware and legacy ignores the hardware model',async()=>{
    const full=flight(reference),small=flight({...reference,propellerDiameterInches:5}),
        legacy=flight(reference,{physicsModel:'legacy'});
    for(const v of [full,small,legacy]){
        await v.start();v.sim.flightInput({throttle:.65,pitch:0,roll:0,yaw:0});tick(v.sim,1);
    }
    assert.ok(full.sim.status().height>small.sim.status().height);
    assert.equal(legacy.sim.status().propulsion,null);
});
test('missing hardware uses explicit generic fallback rather than invented motor curves',async()=>{
    const sim=flight({motorKv:1750});await sim.start();
    sim.sim.flightInput({throttle:.6,pitch:0,roll:0,yaw:0});tick(sim.sim,.5);
    assert.equal(sim.sim.status().propulsion,null);
    assert.ok(sim.sim.status().thrustAcceleration>0);
});

test('advanced hardware flight and energy are deterministic at 30/60/120 render FPS',async()=>{
    const battery={chemistry:'LiPo',batteryId:1,cellCount:6,capacityMah:4500,
        nominalVoltageVolts:22.2,chargePercent:100,hoverPowerWatts:180,
        cruisePowerWatts:250,cruiseSpeedMetersPerSecond:15,
        takeoffWeightGrams:1320,motorCount:4,maxPowerWatts:2200};
    const snapshots=[];
    for(const fps of [30,60,120]){
        const f=flight(reference,{batteryProfile:battery,showBatteryVoltage:true});
        await f.start();f.sim.flightInput({throttle:.48,pitch:.05,roll:.03,yaw:0});
        for(let i=0;i<fps*3;i++)f.sim.tick(1/fps);
        snapshots.push(f.sim.status());
    }
    for(const state of snapshots.slice(1)){
        near(state.height,snapshots[0].height,1e-7);
        near(state.battery.consumedWh,snapshots[0].battery.consumedWh,1e-6);
        near(state.propulsion.rpm,snapshots[0].propulsion.rpm,1e-5);
    }
});
test('advanced Angle mode starts near hover and respects zero/minimum throttle',async()=>{
    const f=flight(reference,{flightMode:'angle',climbSpeed:25});
    await f.start();tick(f.sim,1.5);
    const hovered=f.sim.status();
    assert.ok(Math.abs(hovered.verticalSpeed)<1,'centered Angle throttle estimates hover');
    f.sim.flightInput({throttle:-1,pitch:0,roll:0,yaw:0});tick(f.sim,1);
    assert.ok(f.sim.status().verticalSpeed<-1,'minimum Angle throttle permits descent');
});
test('explicit motor/ESC electrical limits can reduce available thrust independent of mass',()=>{
    const unrestricted=motor.output(motor.normalize(reference),1,22.2);
    const restricted=motor.output(motor.normalize({...reference,maxPowerWatts:null,
        escContinuousCurrentAmpsPerChannel:15}),1,22.2);
    assert.ok(restricted.limited);
    assert.ok(restricted.totalThrustNewtons<unrestricted.totalThrustNewtons);
    assert.ok(restricted.estimatedCurrentAmps<15*4+.01);
});
