const test=require('node:test'),assert=require('node:assert/strict');
const F=require('../../web/features/signal/simulated_failsafe.js');
const {createSimulator}=require('../../web/features/flight/free_flight.js');
const home={latitude:46.7,longitude:8.4};
const context={position:home,home,height:1020,homeHeight:1000,distanceToHome:40};
function observation(quality,{id=1,ageMs=0,state=quality===null?'unknown':'valid',errorCategory=null}={}){
    return {visibility:quality===null?'unknown':quality<.2?'obstructed':'clear',
        controlLink:quality===null?'unknown':{quality,source:'rfModel'},videoLink:'unknown',
        observation:{id,quality:state,ageMs,freshnessMs:F.maximumObservationAgeMs,errorCategory}};
}
function step(machine,value,seconds,ctx=context){
    let result=machine.status();for(let i=0;i<Math.round(seconds*100);i++)result=machine.step(.01,value,ctx);return result;
}

test('clear, blocked, pending/error, blocked preserves only confirmed loss time',()=>{
    const machine=F.create({enabled:true,activationDelaySeconds:1});
    step(machine,observation(.9),.2);
    assert.equal(step(machine,observation(0,{id:2}),.6).phase,'pending');
    const before=machine.status().lossTimeSeconds;
    for(const state of ['pending','unknown','error']){
        const status=step(machine,observation(null,{state,errorCategory:'TERRAIN_UNAVAILABLE'}),.2);
        assert.equal(status.phase,'pending');assert.equal(status.rcQuality,null);
        assert.equal(status.lossTimeSeconds,before,'missing terrain never asserts loss or reception');
        assert.equal(status.observationQuality,state);
    }
    assert.equal(step(machine,observation(0,{id:3}),.41).phase,'hold');
});

test('unknown does not restore RC and stable recovery must use valid fresh model evidence',()=>{
    const machine=F.create({enabled:true,mode:'hold',activationDelaySeconds:.2,recoveryDelaySeconds:.4,autoRecover:true});
    assert.equal(step(machine,observation(0),.3).phase,'hold');
    assert.equal(step(machine,observation(null,{state:'pending'}),1).phase,'hold');
    assert.equal(machine.recover(),false);
    assert.equal(step(machine,observation(.9,{id:2}),.2).phase,'hold');
    step(machine,observation(null,{state:'error'}),.1);
    assert.equal(step(machine,observation(.9,{id:3}),.2).phase,'hold','a gap cannot qualify stable recovery');
    assert.equal(step(machine,observation(.9,{id:3}),.21).phase,'normal');
});

test('prolonged uncertainty holds without inventing RC loss or launching GPS Rescue',()=>{
    const machine=F.create({enabled:true,mode:'gpsRescue',activationDelaySeconds:10,recoveryDelaySeconds:.3});
    step(machine,observation(0),.4);const confirmed=machine.status().lossTimeSeconds;
    const uncertain=step(machine,observation(null,{state:'error'}),12);
    assert.equal(uncertain.phase,'uncertain');assert.equal(uncertain.active,true);
    assert.equal(uncertain.reason,'observationUnavailable');assert.equal(uncertain.rcQuality,null);
    assert.equal(uncertain.lossTimeSeconds,confirmed);assert.equal(uncertain.targetAltitudeMeters,null);
    assert.equal(machine.recover(),false);
    step(machine,observation(.9,{id:2}),.2);assert.equal(machine.recover(),false);
    step(machine,observation(.9,{id:2}),.11);assert.equal(machine.status().recoveryReady,true);
    assert.equal(machine.recover(),true);assert.equal(machine.status().phase,'normal');
});

test('a frozen or repeatedly wrapped result ages out and cannot count loss indefinitely',()=>{
    const machine=F.create({enabled:true,mode:'gpsRescue',activationDelaySeconds:10});
    for(let i=0;i<1200;i++)machine.step(.01,observation(0,{id:7,ageMs:0}),context);
    const status=machine.status();assert.equal(status.phase,'uncertain');assert.equal(status.rcQuality,null);
    assert.equal(status.observationQuality,'stale');assert.ok(status.lossTimeSeconds<=5);
    const before=status.lossTimeSeconds;
    step(machine,observation(null,{state:'stale',ageMs:12000}),10);
    assert.equal(machine.status().lossTimeSeconds,before);
    assert.equal(step(machine,observation(0,{id:8}),.4).phase,'pending','a fresh position may resume confirmed timing');
});

test('stale clear RF cannot arm recovery and fresh evidence requalifies GPS takeover',()=>{
    const machine=F.create({enabled:true,mode:'gpsRescue',activationDelaySeconds:.1,recoveryDelaySeconds:.3});
    step(machine,observation(0),.2);
    step(machine,observation(.9,{id:2,ageMs:4900}),.5);
    assert.equal(machine.status().recoveryReady,false);assert.equal(machine.recover(),false);
    step(machine,observation(.9,{id:3}),.31);assert.equal(machine.status().recoveryReady,true);
    step(machine,observation(null,{state:'pending'}),5.1);
    assert.equal(machine.status().recoveryReady,false);assert.equal(machine.recover(),false);
    step(machine,observation(.9,{id:4}),.31);assert.equal(machine.recover(),true);
});

test('explicit invalid, missing and superseded observation qualities never provide RC evidence',()=>{
    for(const state of ['pending','stale','unknown','error'])assert.equal(F.rcQuality(observation(.9,{state})),null);
    for(const ageMs of [NaN,Infinity,-1,5000,5001])assert.equal(F.rcQuality(observation(.9,{ageMs})),null);
    assert.equal(F.rcQuality(observation(.9,{ageMs:1})),.9);
    assert.equal(F.rcQuality({visibility:'obstructed',controlLink:'unknown'}),null);
});

test('disabled monitoring does not engage uncertainty hold before any RF observation',()=>{
    const machine=F.create({enabled:true,mode:'gpsRescue'});
    assert.equal(step(machine,{controlLink:'unknown',observation:{enabled:false,quality:'unknown',ageMs:null}},20).phase,'normal');
    assert.equal(step(machine,null,20).phase,'normal');
    assert.equal(machine.status().active,false);
});

for(const physicsModel of ['advanced','legacy'])test(`${physicsModel} GPS Rescue survives terrain gaps and requires fresh RC takeover`,async()=>{
    const model=createSimulator({sampleHeight:async()=>1000,renderedHeight:()=>1000,isTerrainReady:()=>true,
        captureCamera:()=>({heading:0}),restoreCamera:()=>{},applyPose:()=>{},onState:()=>{}});
    await model.start({...home,agl:60,physicsModel,flightMode:'gps',failsafe:{enabled:true,mode:'gpsRescue',
        activationDelaySeconds:.2,recoveryDelaySeconds:.3,rescueAltitudeMeters:5}},new AbortController().signal);
    function run(seconds){for(let i=0;i<Math.round(seconds*60);i++)model.tick(1/60);}
    model.linkAssessment(observation(0));run(.3);assert.equal(model.status().failsafe.active,true);
    model.linkAssessment(observation(null,{state:'error'}));run(6);
    const status=model.status();assert.equal(status.physicsModel,physicsModel);assert.equal(status.failsafe.recoveryReady,false);
    assert.ok(['climb','turn','return','landing','landed'].includes(status.failsafe.phase));
    assert.ok(Number.isFinite(status.height));assert.ok(Number.isFinite(status.position.latitude));
    model.linkAssessment(observation(.9,{id:2}));run(.4);
    assert.equal(model.status().failsafe.recoveryReady,true);
    model.linkAssessment(observation(0,{id:3}));
    assert.equal(model.resumeAfterFailsafe(),false,'new low RF evidence blocks takeover before the next physics step');
    model.pause(true);model.linkAssessment(observation(null,{state:'stale',ageMs:5100}));
    assert.equal(model.resumeAfterFailsafe(),false,'paused simulation cannot use expired takeover evidence');
    model.pause(false);model.linkAssessment(observation(.9,{id:4}));run(.4);
    assert.equal(model.resumeAfterFailsafe(),true);
    assert.equal(model.status().failsafe.phase,'normal');model.stop();
});
