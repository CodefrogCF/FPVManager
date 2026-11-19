const test=require('node:test');
const assert=require('node:assert/strict');
const F=require('../../web/simulated_failsafe.js');
const {createSimulator,distance}=require('../../web/free_flight.js');
const spawn={latitude:46.70,longitude:8.40};
const rc=q=>({visibility:'obstructed',source:'sampledTerrain',confidence:'approximate',
    controlLink:q===null?'unknown':{quality:q,source:'estimatedModel',detail:'manualTraining'},
    videoLink:{quality:0,source:'estimatedModel'}});
const context={position:spawn,home:spawn,height:1020,homeHeight:1000,distanceToHome:40};
function steps(machine,quality,seconds,ctx=context){let s;for(let i=0;i<Math.round(seconds*60);i++)s=machine.step(1/60,rc(quality),ctx);return s;}
function flight(){const points=[],events=[];const model=createSimulator({sampleHeight:async()=>1000,
    renderedHeight:()=>1000,isTerrainReady:()=>true,captureCamera:()=>({heading:0}),restoreCamera:()=>{},
    applyPose:s=>points.push(s),onState:s=>events.push(s)});return {model,points,events};}
async function start(m,overrides={}){await m.start({...spawn,flightMode:'gps',agl:60,...overrides},new AbortController().signal);}
function run(m,seconds){for(let i=0;i<seconds*60;i++)m.tick(1/60);}
test('failsafe is opt-in and rejects invalid config and implicit LOS/video signals',()=>{
    assert.equal(F.configuration({}).enabled,false);
    assert.equal(F.rcQuality({visibility:'obstructed',controlLink:'unknown',videoLink:{quality:0,source:'rfModel'}}),null);
    assert.equal(F.rcQuality({controlLink:{quality:0,source:'terrainIllustration'}}),null);
    assert.equal(F.rcQuality(rc(0)),0);
    for(const settings of [{mode:'invalid'},{lossThreshold:1},{recoveryThreshold:.08},{activationDelaySeconds:-1},
        {rescueAltitudeMeters:900},{autoRecover:'yes'}])assert.throws(()=>F.configuration(settings));
    const machine=F.create();assert.equal(steps(machine,0,5).phase,'normal');
});
test('short glitches and unknown terrain cannot trigger; sustained modeled RC loss can',()=>{
    const machine=F.create({enabled:true,mode:'hold',activationDelaySeconds:1,recoveryDelaySeconds:1});
    assert.equal(steps(machine,0,.6).phase,'pending');
    assert.equal(steps(machine,null,2).phase,'normal');
    assert.equal(steps(machine,0,1.2).phase,'hold');
    assert.equal(steps(machine,null,2).phase,'hold','unknown is not proof of reconnection');
    assert.equal(steps(machine,.45,.5).phase,'hold');
    assert.equal(machine.status().recovering,true);
    assert.equal(steps(machine,.45,.7).phase,'normal');
});
test('manual recovery needs stable RC quality and an explicit resume',()=>{
    const machine=F.create({enabled:true,mode:'descend',activationDelaySeconds:.2,recoveryDelaySeconds:.3,autoRecover:false});
    assert.equal(steps(machine,0,.4).phase,'descend');
    assert.equal(machine.recover(),false);
    assert.equal(steps(machine,.6,.4).phase,'awaitingManual');
    assert.equal(machine.recover(),true);assert.equal(machine.status().phase,'normal');
});
test('GPS rescue checks navigation and known insufficient energy before entering return',()=>{
    const settings={enabled:true,mode:'gpsRescue',activationDelaySeconds:.1,recoveryDelaySeconds:1};
    const noNav=F.create(settings);
    assert.equal(steps(noNav,0,.2,{position:null,home:null,height:10,homeHeight:null}).phase,'unavailable');
    const drained=F.create(settings);
    assert.equal(steps(drained,0,.2,{...context,batteryInsufficient:true}).reason,'battery');
    const available=F.create(settings);
    assert.equal(steps(available,0,.2).phase,'climb');
    assert.equal(available.step(1/60,rc(0),{...context,height:1055}).phase,'return');
    assert.equal(available.step(1/60,rc(0),{...context,height:1055,distanceToHome:2}).phase,'arrived');
});
test('video-only loss leaves simulated manual flight and RC state unchanged',async()=>{
    const {model}=flight();await start(model,{failsafe:{enabled:true,mode:'hold',activationDelaySeconds:.2}});
    model.linkAssessment({controlLink:'unknown',videoLink:{quality:0,source:'estimatedModel'}});
    model.stick(1,0);run(model,2);
    assert.equal(model.status().failsafe.phase,'normal');
    assert.ok(distance(spawn,model.status().position)>0.2);
});
test('GPS rescue returns smoothly using normal terrain probes, recovers and resets',async()=>{
    const page=flight(),m=page.model;await start(m,{maxSpeed:12,failsafe:{enabled:true,mode:'gpsRescue',
        activationDelaySeconds:.3,recoveryDelaySeconds:.3,rescueAltitudeMeters:50,
        returnSpeedMetersPerSecond:6,climbSpeedMetersPerSecond:2}});
    m.stick(1,0);run(m,5);const away=m.status().distance;assert.ok(away>5);
    m.linkAssessment(rc(0));run(m,.6);assert.equal(m.status().failsafe.phase,'return');
    // Even at high control rates the normal collision/terrain sweep protects movement.
    const startPos=m.status().position;
    m.stick(-1,0);run(m,1);
    assert.equal(m.status().failsafe.phase,'return');
    assert.ok(m.status().distance<away+12,'bounded inertial response while rescuing');
    assert.ok(distance(startPos,m.status().position)<12,'no teleport');
    m.linkAssessment(rc(.9));run(m,.6);assert.equal(m.status().failsafe.phase,'normal');
    m.linkAssessment(rc(0));run(m,.5);assert.ok(m.status().failsafe.active);
    await m.reset();assert.equal(m.status().failsafe.phase,'normal');
    m.stop();assert.equal(m.status().failsafe.phase,'normal');
});
test('settings and rescue simulation remain independent of video-HUD settings',async()=>{
    const {model:m}=flight();await start(m,{failsafe:{enabled:true,mode:'descend',activationDelaySeconds:.2}});
    m.signalHudSettings({terrainIllustration:true});
    m.linkAssessment({source:'sampledTerrain',visibility:'obstructed',controlLink:'unknown',videoLink:'unknown'});
    run(m,1);assert.equal(m.status().failsafe.phase,'normal');
    m.linkAssessment(rc(0));run(m,.5);assert.equal(m.status().failsafe.phase,'descend');
    m.failsafeSettings({enabled:false});assert.equal(m.status().failsafe.phase,'normal');
});
test('pausing freezes activation time and starting a new flight resets the lost-link state',async()=>{
    const {model:m}=flight();await start(m,{failsafe:{enabled:true,mode:'hold',activationDelaySeconds:.4}});
    m.linkAssessment(rc(0));run(m,.2);assert.equal(m.status().failsafe.phase,'pending');
    m.pause(true);run(m,2);assert.equal(m.status().failsafe.phase,'pending');
    m.pause(false);run(m,.3);assert.equal(m.status().failsafe.phase,'hold');
    await m.reset();assert.equal(m.status().failsafe.phase,'normal');
});
test('route playback explicitly resets and bypasses failsafe',async()=>{
    const {model:m}=flight();await start(m,{failsafe:{enabled:true,mode:'hold',activationDelaySeconds:.1}});
    m.linkAssessment(rc(0));run(m,.3);assert.equal(m.status().failsafe.phase,'hold');
    m.playbackPose({latitude:46.7001,longitude:8.4001,height:1060,heading:0,pitch:0,speed:5,seconds:0});
    assert.equal(m.status().failsafe.phase,'normal');
    assert.equal(m.status().playback,true);
    run(m,3);assert.equal(m.status().failsafe.phase,'normal');
    m.playbackEnd();assert.equal(m.status().failsafe.phase,'normal');
});
