'use strict';
const test=require('node:test'),assert=require('node:assert/strict');
const rotation=require('../../web/rotational_dynamics.js');
const {createSimulator,parameters}=require('../../web/free_flight.js');
const rad=Math.PI/180,gEstimate=9.80665;
const equal=(a,b,eps=1e-9)=>assert.ok(Math.abs(a-b)<=eps,`${a} != ${b}`);
const zero=()=>({x:0,y:0,z:0});
const max={x:720,y:720,z:600};
const input=(roll=0,pitch=0,yaw=0)=>({x:roll,y:pitch,z:yaw});
const config=(overrides={})=>rotation.configuration(overrides);
function stepFor(time,sticks,opts={},power=.8,oldRates=zero(),oldTorque=zero()){
    const settings=config(opts);
    let rates={...oldRates},torques={...oldTorque},last;
    for(let i=0;i<Math.round(time*240);i++){
        last=rotation.step(rates,torques,sticks,max,.2,power,1/240,settings);
        rates=last.rates;torques=last.torques;
    }
    return {rates,torques,last};
}
test('rotational defaults, constraints and input validation fail safely',()=>{
    const defaults=config();assert.equal(defaults.rateProfile,'betaflight');
    assert.ok(Object.isFrozen(defaults));
    for(const value of [null,false,[],4])assert.throws(()=>config(value));
    for(const value of ['acro','Betaflight',0])assert.throws(()=>config({rateProfile:value}));
    for(const field of ['rollInertiaKgM2','pitchInertiaKgM2','yawInertiaKgM2','rollTorqueNm','pitchTorqueNm','yawTorqueNm']){
        for(const value of [0,-1,NaN,Infinity,'1'])assert.throws(()=>config({[field]:value}));
    }
    for(const field of ['rollAccelerationLimitDegs2','controllerGainPerSecond'])assert.throws(()=>config({[field]:0}));
    assert.throws(()=>config({superRate:1}));
    assert.throws(()=>config({motorResponseTimeConstantSeconds:-1}));
    assert.throws(()=>rotation.step(zero(),zero(),input(),max,0,1,1,defaults));
    assert.throws(()=>rotation.step(zero(),zero(),input(),max,0,NaN,1/120,defaults));
});
test('stick-to-rate profiles retain legacy full-stick maxima and center behavior',()=>{
    const linear=config({rateProfile:'linear'}),legacy=config({rateProfile:'legacyExpo'}),bf=config();
    for(const profile of [linear,legacy,bf]){
        equal(rotation.targetRate(1,720,.6,profile),720*rad);
        equal(rotation.targetRate(-1,720,.6,profile),-720*rad);
        equal(rotation.targetRate(0,720,.6,profile),0);
    }
    equal(rotation.targetRate(.5,720,.6,linear),360*rad);
    equal(rotation.targetRate(.5,720,.6,legacy),720*rad*(.5*(.4+.6*.25)));
    assert.ok(Math.abs(rotation.targetRate(.5,720,0,bf))<360*rad);
    assert.ok(Math.abs(rotation.targetRate(.5,720,.6,bf))<Math.abs(rotation.targetRate(.5,720,.6,legacy)));
    for(const stick of [-1,-.2,0,.2,1]){
        equal(rotation.targetRate(stick,700,.2,bf),-rotation.targetRate(-stick,700,.2,bf));
    }
});
test('inertia and torque limits bound angular acceleration; independent axes behave separately',()=>{
    const low=stepFor(.1,input(1),{rollInertiaKgM2:.01,motorResponseTimeConstantSeconds:0});
    const heavy=stepFor(.1,input(1),{rollInertiaKgM2:.1,motorResponseTimeConstantSeconds:0});
    assert.ok(low.rates.x>heavy.rates.x*2,`inertia low ${low.rates.x}, heavy ${heavy.rates.x}`);
    assert.equal(low.rates.y,0);assert.equal(low.rates.z,0);
    const weak=stepFor(.2,input(1),{rollTorqueNm:.07,motorResponseTimeConstantSeconds:0});
    const strong=stepFor(.2,input(1),{rollTorqueNm:2,motorResponseTimeConstantSeconds:0});
    assert.ok(strong.rates.x>weak.rates.x*2);
    const capped=config({rollAccelerationLimitDegs2:300,motorResponseTimeConstantSeconds:0});
    const output=rotation.step(zero(),zero(),input(1),max,0,1,1/120,capped);
    assert.ok(output.angularAcceleration.x<=300*rad+1e-12);
    equal(output.rates.x,output.angularAcceleration.x/120);
    const yaw=stepFor(.1,input(0,0,1));
    assert.equal(yaw.rates.x,0);assert.equal(yaw.rates.y,0);assert.ok(yaw.rates.z>0);
});
test('rapid stick reversals must brake before reversing; motor lag prevents instantaneous torque reversal',()=>{
    const initial=stepFor(.22,input(1));
    assert.ok(initial.rates.x>0&&initial.torques.x>=0);
    const c=config();
    const next=rotation.step(initial.rates,initial.torques,input(-1),max,.2,.8,1/240,c);
    assert.ok(next.rates.x>0,'one fixed step cannot reverse angular velocity');
    assert.ok(next.rates.x-initial.rates.x <= c.rollAccelerationLimitDegs2*rad/240+1e-10,'angular acceleration is physically bounded during actuator lag');
    const braking=stepFor(.07,input(-1),{},.8,initial.rates,initial.torques);
    assert.ok(braking.rates.x<initial.rates.x,'braking begins once the motor torque changes');
    assert.ok(next.torques.x> -c.rollTorqueNm*.8,'actuator torque cannot jump to max reverse');
    const reverse=stepFor(.9,input(-1),{},.8,initial.rates,initial.torques);
    assert.ok(reverse.rates.x<0,'control reverses after physical braking');
    for(const axis of ['x','y','z'])assert.ok(Number.isFinite(reverse.rates[axis]));
});
test('stick release brakes powered axes but does not auto-level or invent torque without power',()=>{
    const spin=stepFor(.16,input(1,.25,-.4));
    const braking=stepFor(.7,input(),{},.8,spin.rates,spin.torques);
    assert.ok(Math.abs(braking.rates.x)<Math.abs(spin.rates.x)*.05);
    assert.ok(Math.abs(braking.rates.y)<Math.abs(spin.rates.y)*.05);
    assert.ok(Math.abs(braking.rates.z)<Math.abs(spin.rates.z)*.05);
    const stopped=rotation.step(spin.rates,spin.torques,input(-1),max,.2,0,1/120,config());
    for(const axis of ['x','y','z'])equal(stopped.torques[axis],0);
    assert.ok(stopped.rates.x>0,'without power there is only passive angular damping');
});
test('severe high-rate rotation remains finite and respects per-axis limits',()=>{
    const c=config({motorResponseTimeConstantSeconds:0,superRate:.95});
    let rates=zero(),torques=zero();
    for(let i=0;i<120*50;i++){
        const stick=i%83<41?1:-1;
        const result=rotation.step(rates,torques,input(stick,-stick,stick),
            {x:1500,y:1500,z:1500},1,1,1/120,c);
        rates=result.rates;torques=result.torques;
        for(const axis of ['x','y','z']){
            assert.ok(Number.isFinite(rates[axis]));
            assert.ok(Number.isFinite(torques[axis]));
            assert.ok(Math.abs(rates[axis])<1600*rad);
            assert.ok(Math.abs(result.angularAcceleration[axis])<=
                c[axis==='x'?'rollAccelerationLimitDegs2':axis==='y'?'pitchAccelerationLimitDegs2':'yawAccelerationLimitDegs2']*rad+1e-8);
        }
    }
});
function simulator(){
    const model=createSimulator({
        sampleHeight:async()=>1000,renderedHeight:()=>1000,isTerrainReady:()=>true,
        captureCamera:()=>({heading:0}),restoreCamera:()=>{},applyPose:()=>{},onState:()=>{},
    });
    return model;
}
async function launch(settings={}){
    const model=simulator();
    await model.start({latitude:46.7,longitude:8.4,agl:1000,flightMode:'acro',physicsModel:'advanced',...settings},new AbortController().signal);
    return model;
}
function advance(model,seconds,fps=60){for(let i=0;i<Math.round(seconds*fps);i++)model.tick(1/fps);}
function control(model,frame={}){model.flightInput({throttle:.6,pitch:0,roll:0,yaw:0,...frame});}
function norm(q){return Math.hypot(q.w,q.x,q.y,q.z);}
function qSimilarity(a,b){return Math.abs(a.w*b.w+a.x*b.x+a.y*b.y+a.z*b.z);}
test('advanced Acro uses bounded rates in full rolls, flips, yaw spins and stick release',async()=>{
    for(const axis of ['roll','pitch','yaw']){
        const model=await launch({acroRollRate:800,acroPitchRate:800,acroYawRate:800});
        control(model,{[axis]:1});advance(model,.6);
        const status=model.status();
        assert.ok(Math.abs(status.angularVelocity[axis==='roll'?'x':axis==='pitch'?'y':'z'])>1);
        equal(norm(status.attitude),1,1e-10);
        control(model);advance(model,.8);
        const atRest=model.status();
        assert.ok(Math.hypot(...Object.values(atRest.angularVelocity))<.05);
        const attitude=atRest.attitude;
        advance(model,.7);
        assert.ok(qSimilarity(attitude,model.status().attitude)>.9999,'released Acro holds orientation');
    }
});
test('advanced Acro controls reflect torque and inertia, rather than teleporting to rate target',async()=>{
    const light=await launch({acroRollRate:1000,rotation:{rollInertiaKgM2:.005}});
    const heavy=await launch({acroRollRate:1000,rotation:{rollInertiaKgM2:.2}});
    for(const model of [light,heavy]){control(model,{roll:1});advance(model,.11);}
    assert.ok(light.status().angularVelocity.x>heavy.status().angularVelocity.x*2);
    assert.ok(heavy.status().angularVelocity.x<1000*rad*.5);
    assert.ok(Math.abs(heavy.status().attitude.x)<Math.abs(light.status().attitude.x));
    const zero=await launch();control(zero,{throttle:0,roll:1});advance(zero,.3);
    assert.ok(zero.status().angularVelocity.x>0,'Air Mode retains rate authority at zero pilot throttle');
    assert.ok(zero.status().controlTorque.x>0,'Low-throttle control is not silently disabled');
    assert.ok(zero.status().thrustAcceleration<gEstimate,'Air Mode must not hover at zero gas');
});
test('rotation is frame-rate invariant and quaternions remain normalized under rapid reversals',async()=>{
    const runs=[];
    for(const fps of [30,60,120]){
        const model=await launch({physicsStepHz:120,acroRollRate:1200,acroPitchRate:1100,acroYawRate:900});
        for(let segment=0;segment<12;segment++){
            control(model,{roll:segment%2?-.9:.9,pitch:segment%3?-.8:.8,yaw:segment%2?.7:-.7});
            advance(model,.2,fps);
            equal(norm(model.status().attitude),1,1e-9);
        }
        runs.push(model.status());
    }
    for(const r of runs.slice(1)){
        assert.ok(qSimilarity(r.attitude,runs[0].attitude)>.999999999);
        for(const axis of ['x','y','z'])equal(r.angularVelocity[axis],runs[0].angularVelocity[axis],1e-8);
    }
});
test('rotation controller is advanced-only; legacy rate behavior is preserved',async()=>{
    const ordinary=simulator();
    await ordinary.start({latitude:46.7,longitude:8.4,agl:1000,flightMode:'acro',physicsModel:'legacy',rotation:{rollInertiaKgM2:.0001}},new AbortController().signal);
    control(ordinary,{throttle:0,roll:1});advance(ordinary,.1);
    assert.ok(ordinary.status().angularVelocity.x>0,'legacy has its original unpowered stick response');
    assert.equal(ordinary.status().controlTorque,null);
    assert.equal(parameters({}).rotation.rateProfile,'betaflight');
    assert.throws(()=>parameters({rotation:{rateProfile:'unknown'}}));
});
test('motor and battery limits affect torque authority for the 7-inch reference quad',async()=>{
    const propulsionProfile={motorKv:1750,motorCount:4,propellerDiameterInches:7,
        propellerPitchInches:3.5,propellerDescription:'HQProp 7x3.5x3V1S',
        takeoffWeightGrams:1320,referenceVoltageVolts:22.2,maxPowerWatts:2200};
    const batteryProfile={chemistry:'LiPo',cellCount:6,capacityMah:4500,
        nominalVoltageVolts:22.2,chargePercent:100,hoverPowerWatts:180,
        cruisePowerWatts:250,cruiseSpeedMetersPerSecond:15,takeoffWeightGrams:1320,
        motorCount:4,maxPowerWatts:2200,continuousDischargeC:120,resistanceOhmsPerCell:.008};
    const normal=await launch({propulsionProfile,batteryProfile,acroRollRate:720});
    const empty=await launch({propulsionProfile,batteryProfile:{...batteryProfile,chargePercent:0},acroRollRate:720});
    for(const model of [normal,empty]){
        control(model,{throttle:1,roll:1});advance(model,.25);
    }
    assert.ok(normal.status().propulsion.totalThrustNewtons>0);
    assert.ok(Math.abs(normal.status().angularVelocity.x)>1);
    equal(empty.status().propulsion.totalThrustNewtons,0);
    equal(empty.status().angularVelocity.x,0);
    equal(empty.status().controlTorque.x,0);
});
