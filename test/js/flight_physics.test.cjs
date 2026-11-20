'use strict';
const test=require('node:test'),assert=require('node:assert/strict');
const {createRuntime,configuration,models,hzOptions}=require('../../web/flight_physics.js');
const {createSimulator,parameters,distance}=require('../../web/free_flight.js');
const spawn={latitude:46.7,longitude:8.4};
function fixture(config={}){
    const poses=[];
    const model=createSimulator({sampleHeight:async()=>1000,renderedHeight:()=>1000,
        captureCamera:()=>({heading:0}),restoreCamera:()=>{},applyPose:p=>poses.push(p),
        isTerrainReady:()=>true,onState:()=>{}});
    return {model,poses,start:()=>model.start({...spawn,agl:500,...config},new AbortController().signal)};
}
function fly(sim,fps,duration){for(let i=0;i<fps*duration;i++)sim.tick(1/fps);return sim.status();}

test('physics architecture has explicit selectable model and deterministic frequency validation',()=>{
    assert.deepEqual(models,['legacy','advanced']);assert.deepEqual(hzOptions,[60,120,240]);
    assert.deepEqual(configuration({}),{mode:'legacy',hz:120});
    assert.equal(parameters({}).physicsModel,'legacy');
    assert.equal(parameters({physicsModel:'advanced',physicsStepHz:240}).physicsStepHz,240);
    for(const invalid of ['invalid','advanced '])assert.throws(()=>parameters({physicsModel:invalid}));
    for(const invalid of [0,75,Infinity,'120'])assert.throws(()=>parameters({physicsStepHz:invalid}));
});

test('advanced movement and battery state remain independent of 30, 60 and 120 Hz rendered frames',async()=>{
    const states=[];
    for(const fps of [30,60,120]){
        const s=fixture({physicsModel:'advanced',physicsStepHz:120,flightMode:'acro',acroMotorTimeConstant:.04});
        await s.start();s.model.flightInput({throttle:.6,pitch:.25,roll:.1,yaw:.15});
        states.push(fly(s.model,fps,3));
        assert.equal(states.at(-1).physicsModel,'advanced');
        assert.equal(states.at(-1).physicsDiagnostics.stepHz,120);
        assert.equal(states.at(-1).physicsDiagnostics.droppedSeconds,0);
        assert.ok(Math.abs(states.at(-1).physicsDiagnostics.simulatedSeconds-3)<1e-8);
    }
    for(const state of states.slice(1)){
        assert.ok(Math.abs(state.height-states[0].height)<1e-7);
        assert.ok(distance(state.position,states[0].position)<1e-5);
        assert.ok(Math.abs(state.speed-states[0].speed)<1e-7);
        for(const axis of ['w','x','y','z'])assert.ok(Math.abs(state.attitude[axis]-states[0].attitude[axis])<1e-9);
    }
});

test('advanced runtime integrates stalled frames with bounded catch-up and explicit dropped-time diagnostics',()=>{
    let t=0,renders=0;const runtime=createRuntime({mode:'advanced',hz:120,
        integrate:dt=>{t+=dt;},snapshot:()=>({t}),present:()=>{renders++;}});
    runtime.advance(.15);
    assert.ok(Math.abs(t-.15)<1e-8);assert.equal(runtime.diagnostics().droppedSeconds,0);
    runtime.advance(2);
    assert.equal(runtime.diagnostics().lastSubsteps,24);
    assert.ok(runtime.diagnostics().queuedSeconds>0);
    assert.ok(runtime.diagnostics().droppedSeconds>=1.49);
    assert.equal(renders,2,'one camera presentation per rendered frame');
    const delayed=runtime.diagnostics();
    runtime.reset();assert.equal(runtime.diagnostics().droppedSeconds,0);
    assert.equal(runtime.diagnostics().simulatedSeconds,0);
    assert.ok(delayed.simulatedSeconds>0);
});

test('advanced presentation interpolates pose without changing the actual physics state',async()=>{
    const p=fixture({physicsModel:'advanced',physicsStepHz:120,flightMode:'gps',maxSpeed:20});
    await p.start();p.model.stick(1,0);
    p.model.tick(1/120);const physical=p.model.status();
    p.model.tick(1/240); // no additional simulation step, only interpolated camera
    assert.deepEqual(p.model.status().position,physical.position);
    assert.equal(p.model.status().height,physical.height);
    assert.equal(p.model.status().physicsDiagnostics.lastSubsteps,0);
    const shown=p.poses.at(-1);
    assert.ok(Number.isFinite(shown.latitude));
    assert.ok(shown.latitude<=physical.position.latitude+1e-11);
});

test('advanced reset and legacy fallback preserve mode and clean simulation-clock state',async()=>{
    for(const mode of ['legacy','advanced']){
        const p=fixture({physicsModel:mode,flightMode:'gps'});await p.start();
        p.model.stick(.7,.2);fly(p.model,60,2);
        assert.equal(p.model.status().physicsModel,mode);
        await p.model.reset();assert.equal(p.model.status().physicsModel,mode);
        assert.equal(p.model.status().physicsDiagnostics.simulatedSeconds,0);
        assert.equal(p.model.status().distance,0);
    }
});

test('legacy retains its original frame delay limit while advanced reports catch-up explicitly',async()=>{
    const legacy=fixture({physicsModel:'legacy',flightMode:'gps'});
    const advanced=fixture({physicsModel:'advanced',flightMode:'gps'});
    await legacy.start();await advanced.start();
    legacy.model.tick(.5);advanced.model.tick(.5);
    assert.ok(legacy.model.status().physicsDiagnostics.simulatedSeconds<=1/30+1e-9);
    assert.ok(advanced.model.status().physicsDiagnostics.simulatedSeconds>.19);
    assert.equal(advanced.model.status().physicsDiagnostics.droppedSeconds,0);
});

test('advanced physics and energy use the same processed simulation time across frame rates',async()=>{
    const profile={batteryId:1,chemistry:'LiPo',cellCount:6,capacityMah:4500,
        nominalVoltageVolts:22.2,chargePercent:100,hoverPowerWatts:180,
        cruisePowerWatts:290,cruiseSpeedMetersPerSecond:17,maxPowerWatts:1100,
        maxSpeedMetersPerSecond:45,takeoffWeightGrams:1320};
    const results=[];
    for(const fps of [30,60,120]){
        const p=fixture({physicsModel:'advanced',physicsStepHz:120,flightMode:'acro',
            showBatteryVoltage:true,batteryProfile:profile});
        await p.start();p.model.flightInput({throttle:.55,pitch:.2,roll:.1,yaw:0});
        results.push(fly(p.model,fps,4));
    }
    for(const result of results.slice(1)){
        assert.ok(Math.abs(result.battery.consumedWh-results[0].battery.consumedWh)<1e-7);
        assert.ok(Math.abs(result.battery.remainingPercent-results[0].battery.remainingPercent)<1e-7);
    }
});

test('stopping during physics substeps clears clock without presenting an invalid frame',()=>{
    let running=true,presented=0,integrations=0;
    const runtime=createRuntime({mode:'advanced',hz:120,isActive:()=>running,
        integrate:()=>{integrations++;running=false;},
        snapshot:()=>({velocity:0}),present:()=>{presented++;}});
    runtime.advance(1/30);
    assert.equal(integrations,1);
    assert.equal(presented,0);
    assert.equal(runtime.diagnostics().queuedSeconds,0);
    assert.equal(runtime.diagnostics().simulatedSeconds,0);
});

test('render-state interpolation follows shortest rotation and longitude across the date line',()=>{
    const {interpolateState}=require('../../web/flight_physics.js');
    const prev={position:{latitude:1,longitude:179.9},height:20,heading:Math.PI*2-.1,
        pitch:0,roll:0,attitude:{w:1,x:0,y:0,z:0}};
    const next={position:{latitude:1,longitude:-179.9},height:30,heading:.1,
        pitch:.1,roll:0,attitude:{w:-1,x:0,y:0,z:0}};
    const center=interpolateState(prev,next,.5);
    assert.ok(Math.abs(Math.abs(center.position.longitude)-180)<1e-7);
    assert.ok(center.heading<1e-7||Math.abs(center.heading-2*Math.PI)<1e-7);
    assert.ok(Math.abs(center.attitude.w-1)<1e-10);
    assert.equal(center.height,25);
});
