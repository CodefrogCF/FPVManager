'use strict';
const test=require('node:test');
const assert=require('node:assert/strict');
const guidance=require('../../web/autonomous_flight_control.js');
const aero=require('../../web/body_axis_aerodynamics.js');
const {createSimulator,distance,parameters}=require('../../web/free_flight.js');
const {configuration:rotationConfig,initialState,stepTargetRates}=require('../../web/rotational_dynamics.js');
const home={latitude:46.7,longitude:8.4};
const pack={chemistry:'LiPo',cellCount:6,capacityMah:4500,nominalVoltageVolts:22.2,
    chargePercent:100,hoverPowerWatts:180,cruisePowerWatts:250,cruiseSpeedMetersPerSecond:15,
    takeoffWeightGrams:1320,maxPowerWatts:2200,continuousDischargeC:120,resistanceOhmsPerCell:.008};
const drone={motorKv:1750,motorCount:4,propellerDiameterInches:7,propellerPitchInches:3.5,
    takeoffWeightGrams:1320,referenceVoltageVolts:22.2,maxPowerWatts:2200};
const rc=q=>({controlLink:{quality:q,source:'estimatedModel'}});
const near=(a,b,tol=1e-7)=>assert.ok(Math.abs(a-b)<tol,`expected ${a} near ${b}`);
async function flight(config={},options={}){
    const poses=[],checks=[],model=createSimulator({sampleHeight:async()=>1000,renderedHeight:()=>1000,
        isTerrainReady:()=>true,captureCamera:()=>({heading:0}),restoreCamera:()=>{},
        onState:()=>{},applyPose:pose=>poses.push(pose),
        modeledCollision:(from,to)=>{checks.push({from,to});return false;},...options});
    await model.start({...home,agl:60,flightMode:'gps',physicsModel:'advanced',physicsStepHz:120,...config},
        new AbortController().signal);
    return {model,poses,checks};
}
function run(model,seconds,fps=60,observe=()=>{}){
    for(let i=0;i<Math.round(seconds*fps);i++){
        model.tick(1/fps);observe(model.status());
    }
    return model.status();
}
test('guidance creates separate target commands without directly modifying position or velocity',()=>{
    const config=parameters({physicsModel:'advanced',flightMode:'gps'}),state={north:0,east:0,up:0};
    const attitude={w:1,x:0,y:0,z:0},wind={north:0,east:0,up:0};
    const forward=guidance.manualTargets(1,0,0,0,config);
    assert.deepEqual(forward,{north:config.maxSpeed,east:0,up:0,heading:0});
    const roll=guidance.manualTargets(0,1,0,0,config);
    assert.equal(roll.north,0);assert.equal(roll.east,config.maxSpeed);
    const command=guidance.command(state,forward,attitude,wind,config,config.aerodynamics,aero,20,0.5);
    assert.ok(command.targetTiltRadians>0&&command.targetTiltRadians<=Math.PI/4);
    assert.ok(command.rates.y<0,'forward acceleration requires nose-down pitch');
    assert.ok(command.thrustAcceleration<=20);
    assert.deepEqual(state,{north:0,east:0,up:0});
    const side=guidance.command(state,roll,attitude,wind,config,config.aerodynamics,aero,20,.5);
    assert.ok(side.rates.x>0,'lateral acceleration requires bank');
    assert.ok(Math.abs(side.rates.y)<1e-8);
    const descending=guidance.command(state,{...forward,north:0,up:-5},attitude,wind,
        config,config.aerodynamics,aero,6,0);
    assert.ok(descending.thrustAcceleration<=6,'weak motors cannot request hover thrust');
    assert.ok(descending.targetTiltRadians<=Math.PI/4);
});
test('autonomous attitude torque obeys exactly the same inertia/torque/acceleration limits as manual Acro',()=>{
    const c=rotationConfig({pitchInertiaKgM2:.1,pitchTorqueNm:.05,motorResponseTimeConstantSeconds:.07});
    const command={x:0,y:5,z:0};
    const one=stepTargetRates(initialState(),initialState(),command,.5,1/120,c);
    assert.equal(one.rates.x,0);assert.equal(one.rates.z,0);
    assert.ok(one.angularAcceleration.y<=c.pitchAccelerationLimitDegs2*Math.PI/180);
    assert.ok(one.torques.y<=c.pitchTorqueNm*.5);
    assert.ok(one.rates.y<5,'target rate is not assigned instantaneously');
    assert.throws(()=>stepTargetRates(initialState(),initialState(),{x:NaN,y:0,z:0},1,1/120,c));
});
test('advanced GPS requires physical tilt and thrust, not immediate speed or heading assignment',async()=>{
    const {model:m}=await flight({maxSpeed:18});
    m.stick(1,0);const initial=m.status();
    m.tick(1/120);const first=m.status();
    assert.ok(first.horizontalSpeed<.1);
    assert.ok(first.flightControl?.targetTiltRadians>0);
    assert.ok(first.flightControl?.requestedThrustAcceleration>0);
    assert.ok(Math.abs(first.pitch)>0&&Math.abs(first.pitch)<.1);
    const moving=run(m,4);assert.ok(moving.horizontalSpeed>5&&moving.horizontalSpeed<=20);
    const heading=moving.heading;
    m.look(300,0);near(m.status().heading,heading,1e-12);
    run(m,.5);assert.ok(Math.abs(m.status().heading-heading)>.02);
    m.stick(0,0);const speed=m.status().horizontalSpeed;
    run(m,4);assert.ok(m.status().horizontalSpeed<speed,'stick release brakes through tilt');
});
test('advanced GPS crosswind is corrected only within propulsion envelope',async()=>{
    const mild=await flight({maxSpeed:15},{sampleWind:()=>({enabled:true,available:true,north:0,east:7,up:0})});
    run(mild.model,7);assert.ok(mild.model.status().distance<3,'hover counteracts ordinary crosswind');
    const strong=await flight({maxSpeed:15,acroThrustToWeight:1.2},
        {sampleWind:()=>({enabled:true,available:true,north:0,east:60,up:0})});
    run(strong.model,6);assert.ok(strong.model.status().distance>10,'a very strong gust exceeds control authority');
    assert.ok(Number.isFinite(strong.model.status().height));
});
test('GPS Rescue keeps all states and controlled landing while respecting geometry collision sweep',async()=>{
    const {model:m,checks}=await flight({agl:10,maxSpeed:12,climbSpeed:5,acceleration:9,deceleration:7,
        failsafe:{enabled:true,mode:'gpsRescue',activationDelaySeconds:.2,recoveryDelaySeconds:.3,
            rescueAltitudeMeters:5,returnSpeedMetersPerSecond:7}});
    m.stick(1,0);run(m,4);const away=m.status().distance;
    assert.ok(away>20);
    m.stick(0,0);m.linkAssessment(rc(0));
    const phases=new Set(),lastDistance={};
    for(let i=0;i<35*60;i++){
        m.tick(1/60);
        const s=m.status();phases.add(s.failsafe.phase);lastDistance[s.failsafe.phase]=s.distance;
        if(s.failsafe.phase==='landed')break;
    }
    for(const phase of ['rescueHold','climb','turn','return','landing','landed'])
        assert.ok(phases.has(phase),`GPS phase ${phase} missing`);
    assert.ok(m.status().distance<4&&m.status().height>=1000.5&&m.status().height<1000.8);
    assert.equal(m.status().thrustAcceleration,0,'landed advanced aircraft disarms simulated propulsion');
    assert.ok(checks.length>1000,'all movement uses the existing model and terrain collision sweep');
    assert.equal(m.status().flightControl?.phase,'landed');
});
test('hardware-aware advanced GPS Rescue uses coupled electrical power and motor torque',async()=>{
    const {model:m}=await flight({agl:10,propulsionProfile:drone,batteryProfile:pack,showBatteryVoltage:true,
        failsafe:{enabled:true,mode:'gpsRescue',activationDelaySeconds:.1,rescueAltitudeMeters:5,
            returnSpeedMetersPerSecond:6}});
    m.stick(1,0);run(m,3);m.stick(0,0);m.linkAssessment(rc(0));
    const phases=new Set();
    for(let i=0;i<45*60;i++){
        m.tick(1/60);phases.add(m.status().failsafe.phase);
        if(m.status().failsafe.phase==='landed')break;
    }
    assert.ok(phases.has('climb')&&phases.has('return')&&phases.has('landed'));
    const s=m.status();
    assert.equal(s.battery.electricalCoupling,'estimated-battery-motor-dc');
    assert.ok(s.battery.consumedWh>0);
    assert.ok(s.flightControl.deliveredThrustAcceleration<=s.flightControl.maximumThrustAcceleration+.2);
});
test('insufficient battery cannot climb, and restricted battery current cannot bypass thrust limits',async()=>{
    const low=await flight({agl:200,propulsionProfile:drone,batteryProfile:{...pack,chargePercent:0},
        failsafe:{enabled:true,mode:'gpsRescue',activationDelaySeconds:.1,rescueAltitudeMeters:5}});
    low.model.linkAssessment(rc(0));run(low.model,.4);
    assert.equal(low.model.status().failsafe.phase,'unavailable');
    const height=low.model.status().height;
    run(low.model,1);
    assert.ok(low.model.status().height<height-1);
    assert.ok(low.model.status().flightControl.deliveredThrustAcceleration<1e-6);
    const weak=await flight({agl:200,propulsionProfile:drone,
        batteryProfile:{...pack,continuousDischargeC:.1},
        failsafe:{enabled:true,mode:'hold',activationDelaySeconds:.1}});
    weak.model.linkAssessment(rc(0));run(weak.model,1);
    assert.equal(weak.model.status().failsafe.phase,'hold');
    assert.ok(weak.model.status().flightControl.maximumThrustAcceleration<9.80665);
    assert.ok(weak.model.status().height<1199);
});
test('manual takeover is gated by stable modeled RC and non-throttle command in Advanced GPS, Acro and Angle',async()=>{
    for(const flightMode of ['gps','acro','angle']){
        const {model:m}=await flight({flightMode,agl:150,
            failsafe:{enabled:true,mode:'gpsRescue',activationDelaySeconds:.1,recoveryDelaySeconds:.2,rescueAltitudeMeters:5}});
        m.linkAssessment(rc(0));run(m,.3);assert.ok(m.status().failsafe.active);
        m.flightInput({throttle:1,yaw:1,pitch:0,roll:0});assert.ok(m.status().failsafe.active);
        m.linkAssessment(rc(.9));run(m,.3);assert.equal(m.status().failsafe.recoveryReady,true);
        m.flightInput({throttle:1,yaw:0,pitch:0,roll:0});assert.ok(m.status().failsafe.active);
        m.flightInput({throttle:0,yaw:1,pitch:0,roll:0});assert.equal(m.status().failsafe.phase,'normal');
    }
});
test('advanced GPS and rescue are deterministic across 30, 60 and 120 render FPS',async()=>{
    const states=[];
    for(const fps of [30,60,120]){
        const {model:m}=await flight({maxSpeed:14,failsafe:{enabled:true,mode:'gpsRescue',
            activationDelaySeconds:.2,rescueAltitudeMeters:5}});
        m.stick(1,0);run(m,3,fps);m.stick(0,0);m.linkAssessment(rc(0));run(m,8,fps);
        states.push(m.status());
    }
    for(const s of states.slice(1)){
        near(s.position.latitude,states[0].position.latitude,1e-10);
        near(s.position.longitude,states[0].position.longitude,1e-10);
        near(s.height,states[0].height,1e-7);
        near(s.heading,states[0].heading,1e-8);
        assert.equal(s.failsafe.phase,states[0].failsafe.phase);
    }
});
test('advanced autonomous motion cannot bypass existing modeled collision barriers',async()=>{
    let blocked=0;
    const {model:m}=await flight({agl:100,flightMode:'gps'},
        {modeledCollision:()=>{blocked++;return 'model';}});
    m.stick(1,0);run(m,1);
    assert.ok(blocked>0);
    assert.ok(m.status().distance<.01);
    assert.ok(m.status().reason.includes('3D surface contact'));
    m.stick(0,0);
    m.linkAssessment(rc(0));
});
test('legacy assisted and legacy rescue remain on the historical direct velocity model',async()=>{
    const {model:legacy}=await flight({physicsModel:'legacy',flightMode:'gps'});
    const {model:advanced}=await flight({physicsModel:'advanced',flightMode:'gps'});
    legacy.stick(1,0);advanced.stick(1,0);
    legacy.tick(1/60);advanced.tick(1/60);
    assert.equal(legacy.status().flightControl,null);
    assert.ok(advanced.status().flightControl?.targetTiltRadians>0);
    assert.ok(Math.abs(legacy.status().pitch)<1e-12);
    assert.ok(Math.abs(advanced.status().pitch)>0);
});
