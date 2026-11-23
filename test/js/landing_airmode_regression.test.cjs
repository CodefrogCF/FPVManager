'use strict';
const test=require('node:test'),assert=require('node:assert/strict');
const {createSimulator}=require('../../web/features/flight/free_flight.js');
const collision=require('../../web/features/flight/physics/collision_response.js');
const rotation=require('../../web/features/flight/physics/rotational_dynamics.js');
const origin={latitude:46.7,longitude:8.4};
function create(environment={}){
    return createSimulator({sampleHeight:async()=>1000,renderedHeight:()=>1000,
        isTerrainReady:()=>true,captureCamera:()=>({heading:0}),restoreCamera:()=>{},
        applyPose:()=>{},onState:()=>{},...environment});
}
async function start(options={},environment={}){
    const model=create(environment);
    await model.start({...origin,agl:100,flightMode:'acro',physicsModel:'advanced',...options},
        new AbortController().signal);
    return model;
}
function input(model,frame={}){model.flightInput({throttle:0,roll:0,pitch:0,yaw:0,...frame});}
function tick(model,time,frequency=120){for(let i=0;i<Math.round(time*frequency);i++)model.tick(1/frequency);}

test('verified gentle touchdown settles instead of continuously sliding',async()=>{
    const model=await start({agl:1},{sampleWind:()=>({available:true,north:2,east:0,up:0})});
    input(model,{throttle:.45});tick(model,1);
    const contact=model.status();
    assert.equal(contact.lastCollision?.mode,'rest');
    assert.equal(contact.speed,0);
    assert.ok(contact.height>=1000.5&&contact.height<1000.51);
    const position={...contact.position};
    input(model,{throttle:0});tick(model,4);
    assert.equal(model.status().lastCollision?.mode,'rest');
    assert.deepEqual(model.status().position,position,'wind must not create ice-like drift while resting');
    assert.equal(model.status().speed,0);
    assert.ok(Math.abs(model.status().height-contact.height)<1e-9);
});

test('terrain resting contact releases as soon as real thrust permits takeoff',async()=>{
    const model=await start({agl:1});
    input(model,{throttle:.45});tick(model,1);
    assert.equal(model.status().lastCollision?.mode,'rest');
    input(model,{throttle:1});tick(model,.7);
    assert.ok(model.status().height>1001);
    assert.ok(model.status().verticalSpeed>0);
    assert.notEqual(model.status().lastCollision?.mode,'rest');
});

test('low-speed contact does not latch on unknown terrain, vertical walls, or high-speed grazes',()=>{
    const config={mode:'slide',friction:.28};
    assert.equal(collision.resolve({north:.2,east:0,up:-1.2},{north:0,east:0,up:1},config,{allowRest:true}).mode,'rest');
    assert.equal(collision.resolve({north:.2,east:0,up:-1.2},null,config).mode,'hard-stop');
    assert.equal(collision.resolve({north:.2,east:0,up:-1.2},{north:0,east:0,up:1},config).mode,'slide',
        'models with a plausible normal are not automatically settled as surveyed terrain');
    assert.equal(collision.resolve({north:.2,east:0,up:-1.2},{north:-1,east:0,up:0},config).mode,'slide');
    assert.equal(collision.resolve({north:6,east:0,up:-1.2},{north:0,east:0,up:1},config).mode,'slide');
    assert.equal(collision.resolve({north:0,east:0,up:-4},{north:0,east:0,up:1},config).mode,'slide');
    assert.equal(collision.resolve({north:.2,east:0,up:-1.2},{north:0,east:0,up:1},{mode:'slide',friction:0}).mode,'slide');
    assert.equal(collision.resolve({north:.2,east:0,up:-1.2},{north:0,east:0,up:1},{mode:'rebound',restitution:.5}).mode,'rebound');
});

test('Air Mode brakes a low-throttle roll when right stick centres, and accepts reversals',async()=>{
    const model=await start();
    input(model,{throttle:.7,roll:1});tick(model,.25);
    const active=model.status().angularVelocity.x;
    assert.ok(active>2);
    input(model,{throttle:0,roll:0});tick(model,.5);
    assert.ok(Math.abs(model.status().angularVelocity.x)<.05,'centred stick should stop active roll at zero throttle');
    input(model,{throttle:0,roll:-1});tick(model,.3);
    assert.ok(model.status().angularVelocity.x<-.4,'reverse stick should change rotation without adding pilot throttle');
    assert.ok(model.status().thrustAcceleration<9.80665,'low-throttle correction must not levitate');
});

test('Air Mode rotation still consumes a small real motor command and remains optional',async()=>{
    assert.equal(rotation.configuration().airModeEnabled,true);
    assert.throws(()=>rotation.configuration({airModeIdleCommand:.5}));
    assert.throws(()=>rotation.configuration({airModeEnabled:'yes'}));
    const on=await start(),off=await start({rotation:{airModeEnabled:false}});
    for(const model of [on,off]){input(model,{throttle:0,roll:1});tick(model,.25);}
    assert.ok(on.status().angularVelocity.x>0);
    assert.ok(on.status().thrustAcceleration>0);
    assert.ok(off.status().angularVelocity.x===0);
    assert.equal(off.status().thrustAcceleration,0);
    input(on,{throttle:0});tick(on,1);
    assert.ok(Math.abs(on.status().angularVelocity.x)<.04);
    assert.ok(on.status().thrustAcceleration<.001,'after rate settles the idle correction ends');
});

test('Air Mode with a fully exhausted battery cannot invent rotation or thrust',async()=>{
    const propulsionProfile={motorKv:1750,motorCount:4,propellerDiameterInches:7,
        propellerPitchInches:3.5,takeoffWeightGrams:1320,referenceVoltageVolts:22.2};
    const batteryProfile={chemistry:'LiPo',cellCount:6,capacityMah:4500,
        nominalVoltageVolts:22.2,chargePercent:0,hoverPowerWatts:180,
        cruisePowerWatts:250,cruiseSpeedMetersPerSecond:15,takeoffWeightGrams:1320,
        motorCount:4,maxPowerWatts:2200,continuousDischargeC:120,resistanceOhmsPerCell:.008};
    const model=await start({propulsionProfile,batteryProfile});
    input(model,{throttle:0,roll:1});tick(model,.5);
    assert.equal(model.status().angularVelocity.x,0);
    assert.equal(model.status().thrustAcceleration,0);
    assert.equal(model.status().controlTorque.x,0);
});

test('landing latch and Air Mode remain frame-rate deterministic',async()=>{
    const results=[];
    for(const fps of [30,60,120]){
        const model=await start({agl:1,physicsStepHz:120});
        input(model,{throttle:.45});tick(model,1,fps);
        assert.equal(model.status().lastCollision?.mode,'rest');
        input(model,{throttle:0});tick(model,2,fps);
        results.push(model.status());
    }
    for(const state of results.slice(1)){
        assert.deepEqual(state.position,results[0].position);
        assert.equal(state.height,results[0].height);
        assert.equal(state.speed,0);
    }
});


test('Air Mode braking uses the actual motor/battery path on the 7-inch reference craft',async()=>{
    const propulsionProfile={motorKv:1750,motorCount:4,propellerDiameterInches:7,
        propellerPitchInches:3.5,takeoffWeightGrams:1320,referenceVoltageVolts:22.2};
    const batteryProfile={chemistry:'LiPo',cellCount:6,capacityMah:4500,
        nominalVoltageVolts:22.2,chargePercent:100,hoverPowerWatts:180,
        cruisePowerWatts:250,cruiseSpeedMetersPerSecond:15,takeoffWeightGrams:1320,
        motorCount:4,maxPowerWatts:2200,continuousDischargeC:120,resistanceOhmsPerCell:.008};
    const model=await start({propulsionProfile,batteryProfile});
    input(model,{throttle:.65,roll:1});tick(model,.2);
    const rotation=model.status().angularVelocity.x;
    assert.ok(rotation>1);
    input(model,{throttle:0,roll:0});tick(model,.2);
    assert.ok(Math.abs(model.status().angularVelocity.x)<rotation*.5);
    assert.ok(model.status().propulsion.propulsionPowerWatts>0,
        'corrective torque must correspond to accounted motor power');
    tick(model,.7);
    assert.ok(Math.abs(model.status().angularVelocity.x)<.02);
    assert.ok(model.status().propulsion.propulsionPowerWatts<.1);
});

test('existing rest latch releases on missing terrain instead of inventing a solid floor',async()=>{
    let available=true;
    const model=await start({agl:1},{renderedHeight:()=>available?1000:NaN});
    input(model,{throttle:.45});tick(model,1);
    assert.equal(model.status().lastCollision?.mode,'rest');
    available=false;input(model,{throttle:0});tick(model,.4);
    assert.equal(model.status().terrainVerification.state,'unavailable');
    assert.notEqual(model.status().lastCollision?.mode,'rest');
    assert.ok(model.status().height<1000.5,'missing terrain must not hold the aircraft aloft');
});

test('Legacy mode does not enable Air Mode or new terrain rest latch',async()=>{
    const model=await start({physicsModel:'legacy',agl:1});
    input(model,{throttle:.45});tick(model,2);
    assert.equal(model.status().controlTorque,null);
    assert.notEqual(model.status().lastCollision?.mode,'rest');
});

test('assisted steep-slope touchdown settles a short vertical drop but not fast grazing motion',()=>{
    const angle=65*Math.PI/180;
    const slopeNormal={north:-Math.sin(angle),east:0,up:Math.cos(angle)};
    const impact={north:0,east:0,up:-Math.sqrt(2*9.80665*.8)};
    const aided=collision.resolve(impact,slopeNormal,{mode:'slide',friction:.28,assistedLanding:true},{allowRest:true});
    assert.equal(aided.mode,'rest');
    assert.equal(aided.assisted,true);
    assert.deepEqual(aided.velocity,{north:0,east:0,up:0});
    assert.equal(collision.resolve(impact,slopeNormal,{mode:'slide',friction:.28,assistedLanding:false},{allowRest:true}).mode,'slide');
    assert.equal(collision.resolve({...impact,north:8},slopeNormal,{mode:'slide',friction:.28},{allowRest:true}).mode,'slide');
    const verySteep={north:-Math.sin(82*Math.PI/180),east:0,up:Math.cos(82*Math.PI/180)};
    assert.equal(collision.resolve(impact,verySteep,{mode:'slide',friction:.28},{allowRest:true}).mode,'slide');
    assert.equal(collision.resolve(impact,null,{mode:'slide',friction:.28},{allowRest:true}).mode,'hard-stop');
});

test('assisted landing holds a real 65-degree terrain profile instead of sliding downhill',async()=>{
    const rad=Math.PI/180,radius=6378137;
    const slopeHeight=p=>1000+Math.tan(65*rad)*(p.latitude-origin.latitude)*rad*radius;
    const trajectories=[];
    for(const assistedLanding of [true,false]){
        const model=await start({agl:1,collisionResponse:{mode:'slide',assistedLanding}},
            {renderedHeight:slopeHeight});
        input(model);tick(model,2);
        trajectories.push(model.status());
    }
    const [assisted,physical]=trajectories;
    assert.equal(assisted.lastCollision?.mode,'rest');
    assert.equal(assisted.speed,0);
    assert.equal(assisted.position.latitude,origin.latitude);
    assert.ok(Math.abs(assisted.height-1000.501)<.01);
    assert.equal(physical.lastCollision?.mode,'slide');
    assert.ok(physical.speed>5,'without explicit landing assistance, the rock slope remains slippery');
    assert.ok(physical.position.latitude<origin.latitude,'downslope travel stays possible when assistance is off');
});
