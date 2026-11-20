'use strict';
const {test}=require('node:test'),assert=require('node:assert/strict');
const air=require('../../web/descent_aerodynamics.js');
const {createSimulator,distance}=require('../../web/free_flight.js');
const q={w:1,x:0,y:0,z:0},base={north:0,east:0,up:0};
const near=(a,b,e=1e-8)=>assert.ok(Math.abs(a-b)<e,`${a} != ${b}`);
function sample({thrustAcceleration=9.80665,motorCommand=.5,orientation=q,
    clearanceMeters=.12,airVelocity=base,rotorDiameterMeters=.1778,
    motorCount=4,timeSeconds=2.2}={},settings={}){
    return air.evaluate({thrustAcceleration,motorCommand,orientation,clearanceMeters,
        airVelocity,rotorDiameterMeters,motorCount,timeSeconds},air.configuration(settings));
}
test('independent effect switches default off and validate strict bounds',()=>{
    assert.deepEqual(Object.keys(air.configuration()).slice(0,3),
        ['groundEffectEnabled','propwashEnabled','vortexRingEnabled']);
    assert.equal(sample().effectiveThrustAcceleration,9.80665);
    assert.equal(sample().groundBoost,0);
    for(const invalid of [null,[],1,'x'])assert.throws(()=>air.configuration(invalid));
    for(const key of ['groundEffectEnabled','propwashEnabled','vortexRingEnabled'])
        assert.throws(()=>air.configuration({[key]:1}));
    for(const key of ['groundEffectIntensity','propwashIntensity','vortexRingIntensity']){
        for(const value of [-1,Infinity,3,'1'])assert.throws(()=>air.configuration({[key]:value}));
    }
    for(const v of [0,-1,.9,NaN])assert.throws(()=>air.configuration({rotorDiameterMeters:v}));
});
test('ground effect requires verified terrain proximity, powered thrust and upright rotor',()=>{
    const c={groundEffectEnabled:true};
    const ground=sample({},c);
    assert.ok(ground.groundBoost>0);
    assert.ok(ground.effectiveThrustAcceleration>9.80665);
    assert.ok(ground.effectiveThrustAcceleration<=9.80665*1.3);
    for(const clearanceMeters of [null,NaN,-.1,Infinity,4*.1778,12]){
        assert.equal(sample({clearanceMeters},c).groundBoost,0);
    }
    for(const motorCommand of [0,0.00001])assert.equal(sample({motorCommand},c).groundBoost,0);
    assert.equal(sample({thrustAcceleration:0},c).groundBoost,0);
    assert.equal(sample({orientation:{w:0,x:1,y:0,z:0}},c).groundBoost,0);
    assert.ok(sample({clearanceMeters:.08},c).groundBoost>ground.groundBoost);
    assert.ok(sample({rotorDiameterMeters:.3},c).groundBoost>ground.groundBoost);
});
test('ground effect responds to available thrust and intensity and remains bounded',()=>{
    const c={groundEffectEnabled:true};
    const lo=sample({thrustAcceleration:4},c);
    const hi=sample({thrustAcceleration:12},c);
    assert.ok(lo.groundBoost<hi.groundBoost);
    assert.equal(sample({},{...c,groundEffectIntensity:0}).groundBoost,0);
    const extreme=sample({clearanceMeters:0,thrustAcceleration:100,motorCommand:1},
        {...c,groundEffectIntensity:2});
    assert.ok(extreme.effectiveThrustAcceleration<=130);
    assert.ok(extreme.groundBoost<=.3);
});
test('powered low-airspeed descent causes bounded propwash and vortex-like thrust loss',()=>{
    const c={propwashEnabled:true,vortexRingEnabled:true};
    const descent=sample({airVelocity:{north:0,east:0,up:-6},clearanceMeters:null},c);
    assert.ok(descent.propwashLoss>0);
    assert.ok(descent.vortexLoss>0);
    assert.ok(descent.effectiveThrustAcceleration<9.80665);
    assert.ok(descent.effectiveThrustAcceleration>=9.80665*.5);
    const drift=Math.hypot(...Object.values(descent.disturbance));
    assert.ok(drift<2);
    assert.deepEqual(descent,sample({airVelocity:{north:0,east:0,up:-6},clearanceMeters:null},c));
    assert.equal(sample({airVelocity:base},c).propwashLoss,0);
    assert.equal(sample({airVelocity:{north:40,east:0,up:-6}},c).propwashLoss,0);
    assert.equal(sample({airVelocity:{north:0,east:0,up:-65}},c).propwashLoss,0);
});
test('propwash and vortex-ring-like losses are independently switchable',()=>{
    const v={airVelocity:{north:0,east:0,up:-6}};
    const p=sample(v,{propwashEnabled:true});
    const r=sample(v,{vortexRingEnabled:true});
    assert.ok(p.propwashLoss>0&&p.vortexLoss===0);
    assert.ok(r.vortexLoss>0&&r.propwashLoss===0);
    assert.deepEqual(r.disturbance,base);
    assert.equal(sample(v,{propwashEnabled:true,propwashIntensity:0}).propwashLoss,0);
    assert.equal(sample(v,{vortexRingEnabled:true,vortexRingIntensity:0}).vortexLoss,0);
});
test('ballistic zero-throttle descent does not gain thrust, loss, or buffeting',()=>{
    const c={groundEffectEnabled:true,propwashEnabled:true,vortexRingEnabled:true};
    for(const speed of [0,6,25,90]){
        const zero=sample({motorCommand:0,thrustAcceleration:0,
            airVelocity:{north:0,east:0,up:-speed}},c);
        assert.equal(zero.effectiveThrustAcceleration,0);
        assert.equal(zero.groundBoost+zero.propwashLoss+zero.vortexLoss,0);
        assert.deepEqual(zero.disturbance,base);
    }
});
test('strong wind changes relative airflow in descent but cannot create motor thrust',()=>{
    const c={propwashEnabled:true};
    const sink=sample({airVelocity:{north:0,east:0,up:-6}},c);
    const wind=sample({airVelocity:{north:35,east:0,up:-6}},c);
    assert.ok(sink.propwashLoss>wind.propwashLoss);
    assert.equal(sample({airVelocity:{north:0,east:0,up:-6},thrustAcceleration:0},c)
        .effectiveThrustAcceleration,0);
});
test('perturbations remain finite and bounded at extreme speeds, tilt and rotor sizes',()=>{
    const c=air.configuration({groundEffectEnabled:true,propwashEnabled:true,vortexRingEnabled:true,
        groundEffectIntensity:2,propwashIntensity:2,vortexRingIntensity:2});
    for(const speed of [0,5,10,50,300,1500])for(const tilt of [q,
        {w:Math.SQRT1_2,x:0,y:Math.SQRT1_2,z:0},{w:0,x:1,y:0,z:0}]){
        const e=air.evaluate({orientation:tilt,motorCommand:1,airVelocity:{north:1,east:0,up:-speed},
            thrustAcceleration:80,clearanceMeters:.02,rotorDiameterMeters:.762,
            motorCount:32,timeSeconds:1000},c);
        assert.ok(Number.isFinite(e.effectiveThrustAcceleration));
        assert.ok(e.effectiveThrustAcceleration>=40&&e.effectiveThrustAcceleration<=104);
        assert.ok(Object.values(e.disturbance).every(Number.isFinite));
    }
});
const spawn={latitude:46.7,longitude:8.4};
async function flight({terrain=1000,...override}={}){
    const sim=createSimulator({sampleHeight:async()=>1000,renderedHeight:()=>terrain,
        captureCamera:()=>({heading:0}),restoreCamera:()=>{},applyPose:()=>{},
        isTerrainReady:()=>true,onState:()=>{}});
    await sim.start({...spawn,physicsModel:'advanced',flightMode:'acro',agl:100,
        ...override},new AbortController().signal);
    return sim;
}
function tick(sim,seconds,fps=60){for(let i=0;i<seconds*fps;i++)sim.tick(1/fps);}
test('advanced powered descent engages propwash while low-throttle free fall remains ballistic',async()=>{
    const options={descentAerodynamics:{propwashEnabled:true,vortexRingEnabled:true}};
    const powered=await flight(options),free=await flight(options);
    powered.flightInput({throttle:.34,pitch:0,roll:0,yaw:0});
    free.flightInput({throttle:0,pitch:0,roll:0,yaw:0});
    let largest=0;
    for(let i=0;i<240;i++){
        powered.tick(1/60);free.tick(1/60);
        const d=powered.status().descentEffects;
        largest=Math.max(largest,d?.propwashLoss??0);
        assert.equal(free.status().thrustAcceleration,0);
        assert.equal(free.status().descentEffects?.propwashLoss??0,0);
    }
    assert.ok(largest>.001,`powered propwash maximum: ${largest}`);
    assert.ok(powered.status().verticalSpeed<0&&free.status().verticalSpeed<0);
});
test('missing terrain never invents a ground-effect enhancement',async()=>{
    const model=await flight({terrain:NaN,agl:1,
        descentAerodynamics:{groundEffectEnabled:true}});
    model.flightInput({throttle:.5,pitch:0,roll:0,yaw:0});tick(model,1);
    assert.equal(model.status().descentEffects.groundBoost,0);
    assert.equal(model.status().descentEffects.clearanceKnown,false);
    assert.equal(model.status().terrainVerification.state,'unavailable');
});
test('verified near-ground advanced flight gets bounded ground effect; legacy is unchanged',async()=>{
    const settings={groundEffectEnabled:true,groundEffectIntensity:2,rotorDiameterMeters:.3};
    const advanced=await flight({agl:1,descentAerodynamics:settings});
    const legacyA=await flight({agl:1,physicsModel:'legacy',descentAerodynamics:settings});
    const legacyB=await flight({agl:1,physicsModel:'legacy'});
    for(const sim of [advanced,legacyA,legacyB])sim.flightInput({throttle:.48,pitch:0,roll:0,yaw:0});
    let seen=false;
    for(let i=0;i<90;i++){
        for(const sim of [advanced,legacyA,legacyB])sim.tick(1/60);
        if(advanced.status().descentEffects?.groundBoost>0)seen=true;
    }
    assert.ok(seen,'near-ground motor thrust should be enhanced in advanced mode');
    near(legacyA.status().height,legacyB.status().height);
    near(legacyA.status().verticalSpeed,legacyB.status().verticalSpeed);
});
test('fixed physics timestep makes activated propwash deterministic across render frame rates',async()=>{
    const results=[];
    for(const fps of [30,60,120]){
        const sim=await flight({descentAerodynamics:{propwashEnabled:true,vortexRingEnabled:true}});
        sim.flightInput({throttle:.35,pitch:0,roll:0,yaw:0});tick(sim,3,fps);
        results.push(sim.status());
    }
    for(const other of results.slice(1)){
        near(other.height,results[0].height,1e-6);
        near(other.verticalSpeed,results[0].verticalSpeed,1e-6);
        assert.ok(distance(other.position,results[0].position)<1e-5);
    }
});
test('angle and GPS use the same optional ground-effect model as Acro',async()=>{
    const results=[];
    for(const mode of ['acro','angle','gps']){
        const sim=await flight({agl:1,flightMode:mode,
            descentAerodynamics:{groundEffectEnabled:true,rotorDiameterMeters:.3}});
        if(mode==='acro')sim.flightInput({throttle:.5,pitch:0,roll:0,yaw:0});
        if(mode==='angle')sim.flightInput({throttle:0,pitch:0,roll:0,yaw:0});
        let max=0;
        for(let i=0;i<90;i++){
            sim.tick(1/60);
            max=Math.max(max,sim.status().descentEffects?.groundBoost??0);
        }
        results.push(max);
    }
    for(const boost of results)assert.ok(boost>0,`Ground effect in all advanced modes: ${results}`);
});
test('7-inch hardware rotor diameter overrides fallback and motor spin-down remains bounded',async()=>{
    const options={agl:1,flightMode:'angle',
        propulsionProfile:{motorKv:1750,motorCount:4,propellerDiameterInches:7,
            propellerPitchInches:3.5,takeoffWeightGrams:1320,referenceVoltageVolts:22.2,
            maxPowerWatts:2200},descentAerodynamics:{groundEffectEnabled:true,
            propwashEnabled:true,vortexRingEnabled:true,rotorDiameterMeters:.0254}};
    const sim=await flight(options);
    sim.flightInput({throttle:-.4,pitch:0,roll:0,yaw:0});
    let seen=false;
    for(let i=0;i<300;i++){
        sim.tick(1/120);
        const s=sim.status();
        assert.ok(Number.isFinite(s.thrustAcceleration));
        if(s.descentEffects?.groundBoost>0)seen=true;
    }
    assert.ok(seen,'hardware rotor diameter should enable near-terrain effect');
});
test('GPS Rescue keeps physical landing and motor disarm with all descent effects enabled',async()=>{
    const sim=await flight({flightMode:'gps',agl:10,maxSpeed:12,climbSpeed:5,
        acceleration:9,deceleration:7,
        descentAerodynamics:{groundEffectEnabled:true,propwashEnabled:true,
            vortexRingEnabled:true},
        failsafe:{enabled:true,mode:'gpsRescue',activationDelaySeconds:.2,
            recoveryDelaySeconds:.3,rescueAltitudeMeters:5,
            returnSpeedMetersPerSecond:7}});
    sim.stick(1,0);tick(sim,4);
    assert.ok(sim.status().distance>20);
    sim.stick(0,0);
    sim.linkAssessment({controlLink:{quality:0,source:'estimatedModel'}});
    const phases=new Set();
    for(let i=0;i<45*60;i++){
        sim.tick(1/60);
        phases.add(sim.status().failsafe.phase);
        if(sim.status().failsafe.phase==='landed')break;
    }
    for(const phase of ['rescueHold','climb','turn','return','landing','landed'])
        assert.ok(phases.has(phase),`Missing rescue phase: ${phase}`);
    assert.ok(sim.status().distance<4);
    assert.equal(sim.status().thrustAcceleration,0);
    assert.equal(sim.status().descentEffects,null);
});
