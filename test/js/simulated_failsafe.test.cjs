const test=require('node:test');
const assert=require('node:assert/strict');
const F=require('../../web/features/signal/simulated_failsafe.js');
const {createSimulator,distance}=require('../../web/features/flight/free_flight.js');
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
    const machine=F.create({enabled:true,mode:'hold',activationDelaySeconds:1,recoveryDelaySeconds:1,autoRecover:true});
    assert.equal(steps(machine,0,.6).phase,'pending');
    assert.equal(steps(machine,null,2).phase,'pending','unknown pauses rather than resets confirmed loss time');
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
    assert.equal(steps(machine,.6,.4).phase,'descend');assert.equal(machine.status().recoveryReady,true);
    assert.equal(machine.recover(),true);assert.equal(machine.status().phase,'normal');
});
test('GPS rescue checks navigation and known insufficient energy before entering return',()=>{
    const settings={enabled:true,mode:'gpsRescue',activationDelaySeconds:.1,recoveryDelaySeconds:1};
    const noNav=F.create(settings);
    assert.equal(steps(noNav,0,.2,{position:null,home:null,height:10,homeHeight:null}).phase,'unavailable');
    const drained=F.create(settings);
    assert.equal(steps(drained,0,.2,{...context,batteryInsufficient:true}).reason,'battery');
    const available=F.create(settings);
    assert.equal(steps(available,0,.2).phase,'rescueHold');
    assert.equal(steps(available,0,.6).phase,'climb');
    assert.equal(available.status().targetAltitudeMeters,1120);
    assert.equal(available.step(1/60,rc(0),{...context,height:1120}).phase,'turn');
    assert.equal(available.step(1/60,rc(0),{...context,height:1120,headingErrorRadians:0}).phase,'return');
    assert.equal(available.step(1/60,rc(0),{...context,height:1120,distanceToHome:2}).phase,'landing');
    assert.equal(available.step(1/60,rc(0),{...context,height:1000.5,distanceToHome:1}).phase,'landed');
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
        activationDelaySeconds:.3,recoveryDelaySeconds:.3,rescueAltitudeMeters:5,
        returnSpeedMetersPerSecond:6,climbSpeedMetersPerSecond:2}});
    m.stick(1,0);run(m,5);const away=m.status().distance;assert.ok(away>5);
    m.linkAssessment(rc(0));run(m,.6);assert.ok(['rescueHold','climb'].includes(m.status().failsafe.phase));
    run(m,6);assert.equal(m.status().failsafe.phase,'return');
    // Even at high control rates the normal collision/terrain sweep protects movement.
    const startPos=m.status().position;
    m.stick(-1,0);run(m,1);
    assert.equal(m.status().failsafe.phase,'return');
    assert.ok(m.status().distance<away+20,'bounded acceleration and braking while rescuing');
    assert.ok(distance(startPos,m.status().position)<12,'no teleport');
    m.linkAssessment(rc(.9));run(m,.6);assert.equal(m.status().failsafe.phase,'return');
    m.flightInput({throttle:-1,yaw:0,pitch:0,roll:0});
    assert.equal(m.status().failsafe.phase,'return','idle throttle cannot cancel rescue');
    m.flightInput({throttle:0,yaw:.6,pitch:0,roll:0});
    assert.equal(m.status().failsafe.phase,'normal','deliberate stick input takes control');
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

test('default RF estimates can drive optional RC failsafe but a video-only model cannot',()=>{
    const rf=require('../../web/features/signal/rf_estimation.js');
    const ground={latitude:47,longitude:8},far={latitude:47,longitude:8.05};
    const terrain={visibility:'obstructed',source:'sampledTerrain',confidence:'approximate',
        minimumClearanceMeters:-100,minimumFresnelMarginMeters:-100};
    const modeled=rf.assess(terrain,ground,far);
    assert.equal(modeled.controlLink.source,'rfModel');
    const machine=F.create({enabled:true,mode:'hold',activationDelaySeconds:.2});
    for(let i=0;i<5;i++)machine.step(.1,modeled,context);
    assert.equal(machine.status().phase,'hold');
    const videoOnly=F.create({enabled:true,mode:'hold',activationDelaySeconds:.2});
    for(let i=0;i<5;i++)videoOnly.step(.1,{controlLink:'unknown',videoLink:modeled.videoLink},context);
    assert.equal(videoOnly.status().phase,'normal');
});

test('GPS rescue approaches commanded speed while far from home, then brakes continuously',async()=>{
    const {model:m}=flight();await start(m,{maxSpeed:22,acceleration:9,deceleration:6,
        failsafe:{enabled:true,mode:'gpsRescue',activationDelaySeconds:.1,returnSpeedMetersPerSecond:14,rescueAltitudeMeters:5}});
    m.stick(1,0);run(m,26);assert.ok(m.status().distance>200);
    m.linkAssessment(rc(0));run(m,.25);assert.ok(m.status().failsafe.active);
    run(m,7);assert.equal(m.status().failsafe.phase,'return');
    run(m,7);assert.ok(m.status().horizontalSpeed>12.5,'feasible 14 m/s target after bounded reversal');
    const before=m.status().distance;assert.ok(before>100,'speed test is still far from home');
    run(m,18);assert.ok(m.status().distance<before-100,'return closes the distance without teleporting');
});

test('simulated shallow obstruction degrades modeled RC without using video quality',()=>{
    const rf=require('../../web/features/signal/rf_estimation.js');
    const a={latitude:47,longitude:8},b={latitude:47,longitude:8.02};
    const blocked={source:'sampledTerrain',confidence:'approximate',visibility:'obstructed',
        minimumClearanceMeters:-60,minimumFresnelMarginMeters:-60};
    const clear={...blocked,visibility:'clear'};
    const occluded=rf.assess(blocked,a,b),visible=rf.assess(clear,a,b);
    assert.ok(occluded.controlLink.quality<visible.controlLink.quality);
    const machine=F.create({enabled:true,mode:'hold',activationDelaySeconds:.2});
    steps(machine,0,.3);
    assert.equal(machine.status().phase,'hold');
});

test('full GPS Rescue sequence holds, climbs, turns, returns and completes a modeled landing',async()=>{
    const {model:m}=flight();await start(m,{agl:10,maxSpeed:12,climbSpeed:5,acceleration:9,deceleration:7,
        failsafe:{enabled:true,mode:'gpsRescue',activationDelaySeconds:.2,recoveryDelaySeconds:.3,
            rescueAltitudeMeters:5,returnSpeedMetersPerSecond:7}});
    m.stick(1,0);run(m,4);const away=m.status().distance;
    assert.ok(away>20);
    m.linkAssessment(rc(0));run(m,.3);assert.equal(m.status().failsafe.phase,'rescueHold');
    const seen=new Set();for(let i=0;i<30;i++){
        run(m,1);seen.add(m.status().failsafe.phase);
        if(m.status().failsafe.phase==='landed')break;
    }
    for(const phase of ['climb','turn','return','landing','landed'])
        assert.ok(seen.has(phase),`missing rescue phase ${phase}`);
    assert.ok(m.status().distance<4);
    assert.ok(m.status().height>=1000.5&&m.status().height<=1000.8);
});

test('controller can reclaim only after stable RF recovery and deliberate non-throttle input',async()=>{
    const {model:m}=flight();await start(m,{failsafe:{enabled:true,mode:'gpsRescue',
        activationDelaySeconds:.1,recoveryDelaySeconds:.2,rescueAltitudeMeters:5}});
    m.stick(1,0);run(m,3);m.linkAssessment(rc(0));run(m,.3);
    assert.ok(m.status().failsafe.active);
    m.flightInput({throttle:0,yaw:.9,pitch:0,roll:0});
    assert.ok(m.status().failsafe.active,'no takeover on lost RC');
    m.linkAssessment(rc(.8));run(m,.3);
    assert.ok(m.status().failsafe.recoveryReady);
    m.flightInput({throttle:-1,yaw:0,pitch:0,roll:0});
    assert.ok(m.status().failsafe.active,'throttle alone does not imply pilot intent');
    m.flightInput({throttle:-1,yaw:0,pitch:.7,roll:0});
    assert.equal(m.status().failsafe.phase,'normal');
});

test('confirmed RC recovery remains available during a long GPS return despite marginal and short unknown profiles',async()=>{
    const {model:m}=flight();
    await start(m,{maxSpeed:20,acceleration:9,deceleration:6,
        failsafe:{enabled:true,mode:'gpsRescue',activationDelaySeconds:.3,recoveryDelaySeconds:.6,
            rescueAltitudeMeters:5,returnSpeedMetersPerSecond:8,climbSpeedMetersPerSecond:5}});
    m.stick(1,0);run(m,22);
    assert.ok(m.status().distance>100,'drone must be far enough away to test mid-return takeover');
    m.linkAssessment(rc(0));run(m,.4);run(m,7);
    assert.equal(m.status().failsafe.phase,'return');
    const away=m.status().distance;
    m.linkAssessment(rc(.85));run(m,.7);
    assert.equal(m.status().failsafe.recoveryReady,true);
    // The previous implementation revoked takeover every time a terrain
    // profile returned a value below the recovery threshold (but above loss).
    m.linkAssessment(rc(.30));run(m,6);
    assert.equal(m.status().failsafe.phase,'return');
    assert.ok(m.status().distance<away-10,'the aircraft is still returning');
    assert.equal(m.status().failsafe.recoveryReady,true,'hysteresis retains a confirmed RC link');
    // A short gap while the next terrain profile is loading is NOT a new loss.
    m.linkAssessment(rc(null));run(m,1.5);
    assert.equal(m.status().failsafe.recoveryReady,true);
    assert.ok(m.status().distance>15,'control must be reclaimable well before arriving home');
    m.stick(.9,0);
    assert.equal(m.status().failsafe.phase,'normal','pilot touch stick takes over mid-return');
    assert.equal(m.status().failsafe.active,false);
    m.stop();
});

test('a sustained second RC loss or prolonged unknown profile revokes GPS takeover until another stable reconnection',()=>{
    const machine=F.create({enabled:true,mode:'gpsRescue',activationDelaySeconds:.3,recoveryDelaySeconds:.6});
    assert.equal(steps(machine,0,.4).phase,'rescueHold');
    steps(machine,.8,.7);assert.equal(machine.status().recoveryReady,true);
    steps(machine,0,.2);assert.equal(machine.status().recoveryReady,true,'brief RC dip is filtered');
    steps(machine,0,.2);assert.equal(machine.status().recoveryReady,false,'confirmed second loss revokes takeover');
    assert.equal(machine.recover(),false);
    steps(machine,.8,.3);assert.equal(machine.status().recoveryReady,false,'must requalify after a second loss');
    steps(machine,.8,.4);assert.equal(machine.status().recoveryReady,true);
    steps(machine,null,2);assert.equal(machine.status().recoveryReady,true);
    steps(machine,null,3.1);assert.equal(machine.status().recoveryReady,false,'indefinitely missing RF does not imply a usable RC link');
    assert.equal(machine.recover(),false);
    steps(machine,.8,.7);assert.equal(machine.status().recoveryReady,true);
    assert.equal(machine.recover(),true);
});

test('RC takeover accepts deliberate FPV controller input while returning and rejects throttle-only input',async()=>{
    const {model:m}=flight();
    await start(m,{flightMode:'angle',maxSpeed:20,acceleration:8,deceleration:5,
        failsafe:{enabled:true,mode:'gpsRescue',activationDelaySeconds:.1,recoveryDelaySeconds:.3,
            rescueAltitudeMeters:5,returnSpeedMetersPerSecond:8}});
    m.linkAssessment(rc(0));run(m,.2);run(m,6);
    // Autonomous rescue must continue while video or throttle input changes.
    assert.ok(m.status().failsafe.active);
    m.linkAssessment(rc(.9));run(m,.4);
    m.linkAssessment(rc(.33));run(m,2);
    assert.ok(m.status().failsafe.recoveryReady);
    m.flightInput({throttle:1,yaw:0,pitch:0,roll:0});
    assert.ok(m.status().failsafe.active,'throttle alone is not deliberate takeover');
    m.flightInput({throttle:0,yaw:.8,pitch:0,roll:0});
    assert.equal(m.status().failsafe.phase,'normal');
});
