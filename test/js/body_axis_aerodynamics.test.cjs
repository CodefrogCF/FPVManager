'use strict';
const test=require('node:test'),assert=require('node:assert/strict');
const aero=require('../../web/features/flight/physics/body_axis_aerodynamics.js');
const {createSimulator,distance}=require('../../web/features/flight/free_flight.js');
const zero={north:0,east:0,up:0},identity={w:1,x:0,y:0,z:0};
const dt=1/120;
const speed=v=>Math.hypot(v.north,v.east,v.up);
const energy=v=>speed(v)**2;
function evolve(initial,q=identity,settings={},power=.5,seconds=3,wind=zero){
    const c=aero.configuration(settings);
    let v={...initial},distance={north:0,east:0,up:0};
    for(let i=0;i<Math.round(seconds/dt);i++){
        const result=aero.integrate(v,wind,q,zero,dt,power,c);
        v=result.velocity;
        for(const axis of ['north','east','up'])distance[axis]+=result.travel[axis];
    }
    return {v,distance};
}
function near(a,b,epsilon=1e-9){assert.ok(Math.abs(a-b)<epsilon,`${a} should match ${b}`);}

test('directional coefficients reject invalid, nonfinite and unknown inputs without mutating presets',()=>{
    const a=aero.configuration();
    assert.equal(a.preset,'conservative');
    assert.equal(a.forward,.35);assert.equal(a.vertical,1);
    assert.equal(aero.configuration({preset:'streamlined'}).forward,.2);
    assert.equal(aero.configuration({preset:'highDrag'}).vertical,1.3);
    assert.equal(aero.configuration({preset:'custom',forward:.03,backward:.7}).forward,.03);
    assert.ok(Object.isFrozen(a));
    for(const bad of [null,[],false])assert.throws(()=>aero.configuration(bad));
    for(const preset of ['sport','Conservative',1])assert.throws(()=>aero.configuration({preset}));
    for(const bad of [-1,Infinity,NaN,'1'])assert.throws(()=>aero.configuration({preset:'custom',forward:bad}));
    for(const bad of [-1,0,5.01])assert.throws(()=>aero.configuration({preset:'custom',vertical:bad}));
    for(const bad of [0,121,Infinity])assert.throws(()=>aero.configuration({},bad));
    assert.throws(()=>aero.configuration({propellerDragEnabled:'true'}));
    assert.throws(()=>aero.integrate(zero,zero,identity,zero,1.5,.5,a));
    assert.throws(()=>aero.integrate(zero,zero,identity,zero,dt,-.1,a));
});

test('body-axis drag distinguishes forward, reverse, lateral and vertical trajectories',()=>{
    const f=evolve({north:40,east:0,up:0});
    const b=evolve({north:-40,east:0,up:0});
    const s=evolve({north:0,east:40,up:0});
    const z=evolve({north:0,east:0,up:-40});
    assert.ok(speed(f.v)>speed(b.v));
    assert.ok(speed(b.v)>speed(s.v));
    assert.ok(speed(s.v)>speed(z.v));
    assert.ok(f.distance.north>Math.abs(b.distance.north));
    assert.ok(Math.abs(f.v.east)<1e-12&&Math.abs(f.v.up)<1e-12);
    assert.ok(b.v.north<0,'backward momentum never flips sign');
    assert.ok(s.v.east>0,'lateral drift never becomes propulsive');
    assert.ok(z.v.up<0,'vertical descent never creates thrust');
});

test('attitude rotates drag frame; yaw rotation preserves equivalent physical trajectory',()=>{
    const a=evolve({north:35,east:0,up:0});
    const half=Math.SQRT1_2,q={w:half,x:0,y:0,z:half};
    const b=evolve({north:0,east:35,up:0},q);
    near(a.v.north,b.v.east);near(a.distance.north,b.distance.east);
    near(b.v.north,0);near(b.distance.north,0);
    // Changing orientation by 90° mid-flight immediately changes the drag
    // coefficient applied to the same existing world-space momentum.
    let v={north:45,east:0,up:0};
    const before=aero.integrate(v,zero,identity,zero,dt,1,aero.configuration());
    const after=aero.integrate(v,zero,q,zero,dt,1,aero.configuration());
    assert.ok(before.velocity.north>after.velocity.north);
});

test('drag always dissipates air-relative kinetic energy, including in moving wind',()=>{
    const q={w:.8660254037844386,x:.28867513459481287,y:.28867513459481287,z:.28867513459481287};
    const wind={north:12,east:-5,up:3};
    const initial={north:62,east:-25,up:-45};
    const relative=v=>({north:v.north-wind.north,east:v.east-wind.east,up:v.up-wind.up});
    const r=aero.integrate(initial,wind,q,zero,.05,0,aero.configuration());
    assert.ok(energy(relative(r.velocity))<energy(relative(initial)));
    for(const axis of ['north','east','up'])assert.ok(Number.isFinite(r.travel[axis]));
    const stopped=aero.integrate(wind,wind,q,zero,dt,0,aero.configuration());
    assert.deepEqual(stopped.velocity,wind);
});

test('propeller drag acts only at low/zero motor power on body vertical flow',()=>{
    const falling={north:0,east:0,up:-30};
    const off=aero.configuration({propellerDragEnabled:false});
    const on=aero.configuration({propellerDragEnabled:true});
    const unpowered=aero.integrate(falling,zero,identity,zero,.1,0,on);
    const powered=aero.integrate(falling,zero,identity,zero,.1,1,on);
    const disabled=aero.integrate(falling,zero,identity,zero,.1,0,off);
    assert.ok(unpowered.velocity.up>powered.velocity.up);
    near(powered.velocity.up,disabled.velocity.up);
    assert.equal(unpowered.velocity.north,0);assert.equal(unpowered.velocity.east,0);
    const forward={north:30,east:0,up:0};
    near(aero.integrate(forward,zero,identity,zero,.1,0,on).velocity.north,
        aero.integrate(forward,zero,identity,zero,.1,0,off).velocity.north);
});

test('zero-throttle vertical free fall remains finite, momentum-preserving and converges to terminal speed',()=>{
    const c=aero.configuration({propellerDragEnabled:false},22.5),gravity={north:0,east:0,up:-9.80665};
    let v={...zero};
    for(let i=0;i<120*18;i++){
        v=aero.integrate(v,zero,identity,gravity,dt,0,c).velocity;
        assert.ok(Number.isFinite(v.up)&&v.up<=0);
    }
    assert.ok(Math.abs(v.up+22.5)<.01,`terminal free-fall speed: ${v.up}`);
    // An almost horizontal attitude presents the lateral or forward body face
    // to vertical airflow; do not apply level-flight forward drag by default.
    const half=Math.SQRT1_2,q={w:half,x:0,y:half,z:0};
    const vertical=evolve({north:0,east:0,up:-30},identity,{},.5);
    const turned=evolve({north:0,east:0,up:-30},q,{},.5);
    assert.ok(speed(turned.v)>speed(vertical.v));
});

test('extreme airspeed and abrupt attitude changes stay finite without reversing momentum',()=>{
    let velocity={north:1800,east:-1200,up:800};
    const rotations=[identity,{w:0,x:1,y:0,z:0},{w:Math.SQRT1_2,x:0,y:0,z:Math.SQRT1_2},
        {w:.5,x:.5,y:.5,z:.5}];
    const config=aero.configuration({preset:'highDrag'});
    for(let i=0;i<300;i++){
        const old=energy(velocity);
        const result=aero.integrate(velocity,zero,rotations[i%4],zero,dt,0,config);
        velocity=result.velocity;
        assert.ok(Number.isFinite(energy(velocity)));
        assert.ok(energy(velocity)<=old+1e-8,'drag may never inject energy');
    }
});

const spawn={latitude:46.7,longitude:8.4};
async function flight(command){
    const model=createSimulator({sampleHeight:async()=>1000,renderedHeight:()=>1000,
        captureCamera:()=>({heading:0}),restoreCamera:()=>{},applyPose:()=>{},
        isTerrainReady:()=>true,onState:()=>{}});
    await model.start({...spawn,flightMode:'acro',agl:950,physicsModel:'advanced',...command},new AbortController().signal);
    return model;
}
function tick(sim,seconds,fps=60){for(let i=0;i<seconds*fps;i++)sim.tick(1/fps);}

test('advanced Acro zero throttle produces no propulsion, and preset changes the dive',async()=>{
    const slow=await flight({aerodynamics:{preset:'highDrag'}});
    const fast=await flight({aerodynamics:{preset:'streamlined'}});
    for(const sim of [slow,fast]){
        sim.flightInput({throttle:0,pitch:0,roll:0,yaw:0});tick(sim,8);
        const state=sim.status();
        assert.equal(state.thrustAcceleration,0);
        assert.ok(state.verticalSpeed<0);
    }
    assert.ok(fast.status().verticalSpeed<slow.status().verticalSpeed);
    assert.ok(fast.status().height<slow.status().height);
});

test('advanced Angle uses body-axis drag but legacy retains unchanged isotropic response',async()=>{
    const mk=async (mode,preset)=>flight({flightMode:'angle',physicsModel:mode,aerodynamics:{preset}});
    const advancedLow=await mk('advanced','streamlined'),advancedHigh=await mk('advanced','highDrag');
    const legacyLow=await mk('legacy','streamlined'),legacyHigh=await mk('legacy','highDrag');
    for(const sim of [advancedLow,advancedHigh,legacyLow,legacyHigh]){
        sim.flightInput({throttle:-1,pitch:0,roll:0,yaw:0});tick(sim,5);
    }
    assert.ok(advancedLow.status().verticalSpeed<advancedHigh.status().verticalSpeed);
    near(legacyLow.status().verticalSpeed,legacyHigh.status().verticalSpeed,1e-8);
    near(legacyLow.status().height,legacyHigh.status().height,1e-8);
});

test('advanced directional aerodynamics is reproducible at 30/60/120 Hz rendering',async()=>{
    const results=[];
    for(const fps of [30,60,120]){
        const model=await flight({physicsStepHz:120,aerodynamics:{preset:'custom',forward:.3,
            backward:.6,lateral:.8,vertical:1.15,propeller:.15}});
        model.flightInput({throttle:.5,pitch:.3,roll:.2,yaw:.3});tick(model,3,fps);
        results.push(model.status());
    }
    for(const r of results.slice(1)){
        near(r.height,results[0].height,1e-7);
        assert.ok(distance(r.position,results[0].position)<1e-5);
        near(r.speed,results[0].speed,1e-7);
    }
});


test('7-inch hardware coupled battery/free fall retains near-zero motor load and passive drag',async()=>{
    const model=await flight({propulsionProfile:{motorKv:1750,motorCount:4,
        propellerDiameterInches:7,propellerPitchInches:3.5,takeoffWeightGrams:1320,
        referenceVoltageVolts:22.2,maxPowerWatts:2200},
    batteryProfile:{chemistry:'LiPo',cellCount:6,capacityMah:4500,
        nominalVoltageVolts:22.2,chargePercent:100,hoverPowerWatts:180,
        cruisePowerWatts:250,cruiseSpeedMetersPerSecond:15,
        takeoffWeightGrams:1320,motorCount:4,maxPowerWatts:2200,
        continuousDischargeC:120,resistanceOhmsPerCell:.008},
    showBatteryVoltage:true});
    model.flightInput({throttle:0,pitch:0,roll:0,yaw:0});tick(model,4);
    const state=model.status();
    assert.ok(state.verticalSpeed<-10);
    assert.ok(state.propulsion.coupled);
    assert.ok(state.propulsion.totalThrustNewtons<1e-9);
    assert.ok(state.battery.estimatedPowerWatts<30,'auxiliary draw only, not powered cruise');
    assert.ok(state.battery.consumedWh>0&&state.battery.consumedWh<.05);
    assert.ok(Number.isFinite(state.battery.packVoltageVolts));
});
