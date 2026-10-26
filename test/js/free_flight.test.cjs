const test=require('node:test');
const assert=require('node:assert/strict');
const {createSimulator,parameters,distance,rateCommand}=require('../../web/free_flight.js');
const spawn={latitude:46.7,longitude:8.4};
function setup(options={}){
    let ready=true,ground=1000;
    const poses=[],restored=[],states=[];
    const model=createSimulator({sampleHeight:async()=>1000,renderedHeight:()=>ground,
        captureCamera:()=>({heading:0,id:'orbital'}),restoreCamera:p=>restored.push(p),
        applyPose:p=>poses.push(p),isTerrainReady:()=>ready,onState:s=>states.push(s),...options});
    return {model,poses,restored,states,ready:v=>ready=v,ground:v=>ground=v};
}
async function start(page,config={}){await page.model.start({...spawn,...config},new AbortController().signal);}
function advance(model,seconds=1,fps=60){for(let i=0;i<seconds*fps;i++)model.tick(1/fps);}
function input(model,frame={}){model.flightInput({throttle:0,yaw:0,pitch:0,roll:0,...frame});}
const dot=(a,b)=>a.north*b.north+a.east*b.east+a.up*b.up;

test('HUD launch height is independent of local terrain; layout changes preserve flight state and survive reset',async()=>{
    let ground=1000;
    const p=setup({renderedHeight:()=>ground});
    await start(p,{flightMode:'gps',agl:20});
    assert.equal(p.model.status().heightAboveHome,20);
    assert.deepEqual(p.model.status().home,spawn);
    ground=1005;advance(p.model,.2);
    assert.equal(p.model.status().agl,15);assert.equal(p.model.status().heightAboveHome,20);
    const before=p.model.status();p.model.hudStyle('betaflight');
    const after=p.model.status();assert.equal(after.hudStyle,'betaflight');
    for(const key of ['height','agl','heightAboveHome','speed','heading'])assert.equal(after[key],before[key]);
    assert.deepEqual(after.position,before.position);assert.deepEqual(after.attitude,before.attitude);
    ground=900;p.model.vertical(-1);advance(p.model,8);
    assert.ok(p.model.status().heightAboveHome<0);assert.ok(p.model.status().agl>0);
    await p.model.reset();assert.equal(p.model.status().hudStyle,'betaflight');
    assert.equal(p.model.status().heightAboveHome,20);assert.equal(p.model.status().distance,0);
    assert.throws(()=>p.model.hudStyle('unknown'));assert.throws(()=>parameters({hudStyle:'unknown'}));
});

test('graphics changes do not affect flight state and survive reset; invalid profiles are rejected',async()=>{
    const profiles=[],p=setup({applyGraphics:value=>profiles.push(value)}),reference=setup();
    await start(p,{flightMode:'acro',agl:500});await start(reference,{flightMode:'acro',agl:500});
    for(const profile of ['quality','performance','balanced']){
        const before=p.model.status();p.model.graphicsProfile(profile);
        assert.equal(p.model.status().height,before.height);assert.deepEqual(p.model.status().attitude,before.attitude);
        for(const page of [p,reference]){input(page.model,{throttle:.6,pitch:.2,roll:.1});advance(page.model,.5);}
        assert.equal(p.model.status().height,reference.model.status().height);
        assert.deepEqual(p.model.status().position,reference.model.status().position);
    }
    await p.model.reset();assert.equal(p.model.status().graphicsProfile,'balanced');
    assert.equal(profiles.at(-1),'balanced');assert.equal(p.model.active,true);assert.equal(p.model.flightMode,'acro');
    assert.throws(()=>p.model.graphicsProfile('unknown'));assert.throws(()=>parameters({graphicsProfile:'unknown'}));
});
test('vertical flight samples the same floor once per frame and horizontal sweeps remain at most 0.5 m apart',async()=>{
    const probes=[];
    const p=setup({renderedHeight:point=>{probes.push({...point});return 1000;}});
    await start(p,{flightMode:'acro',agl:500});p.model.tick(1/60);assert.equal(probes.length,1);
    probes.length=0;input(p.model,{throttle:1,pitch:1});advance(p.model,2);
    assert.ok(probes.length>120);
    // A fresh frame starts with another probe of its current position. All
    // consecutive probes, including the intermediate sweep points, stay close.
    for(let i=1;i<probes.length;i++)assert.ok(distance(probes[i-1],probes[i])<=.5001);
});

test('FPV camera tilt looks up relative to the body and never changes flight physics',async()=>{
    for(const flightMode of ['angle','acro']){
        const level=setup(),tilted=setup();
        await start(level,{flightMode,agl:500});await start(tilted,{flightMode,agl:500,cameraTiltDegrees:35});
        assert.ok(Math.abs(tilted.poses.at(-1).direction.up-Math.sin(35*Math.PI/180))<1e-12);
        for(const p of [level,tilted]){input(p.model,{throttle:.7,pitch:.4,roll:.8,yaw:.2});advance(p.model,1);}
        assert.deepEqual(tilted.model.status().attitude,level.model.status().attitude);
        assert.deepEqual(tilted.model.status().position,level.model.status().position);
        assert.equal(tilted.model.status().height,level.model.status().height);
        const before=tilted.model.status();tilted.model.cameraTilt(60);const after=tilted.model.status();
        assert.equal(after.speed,before.speed);assert.equal(after.height,before.height);assert.deepEqual(after.attitude,before.attitude);
        for(const pose of tilted.poses){assert.ok(Math.abs(dot(pose.direction,pose.up))<1e-10);assert.ok(Math.abs(dot(pose.up,pose.up)-1)<1e-10);}
        await tilted.model.reset();assert.equal(tilted.model.status().cameraTiltDegrees,60);
        for(const bad of [-1,81,NaN,Infinity,'30'])assert.throws(()=>tilted.model.cameraTilt(bad));
    }
    assert.throws(()=>parameters({cameraTiltDegrees:81}));
    const gps=setup();await start(gps,{flightMode:'gps',cameraTiltDegrees:60});assert.equal(gps.poses.at(-1).direction,undefined);
});
test('Mode 2 throttle, yaw and pitch/roll control thrust and attitude rather than direct translation',async()=>{
    const p=setup();await start(p,{agl:25,maxSpeed:20,climbSpeed:4});
    assert.equal(p.poses.at(-1).height,1025);advance(p.model);assert.equal(p.model.status().height,1025);
    input(p.model,{yaw:1});advance(p.model);assert.ok(p.model.status().heading>1);
    assert.ok(distance(spawn,p.model.status().position)<.001,'Yaw alone must not strafe');
    input(p.model,{throttle:1});advance(p.model);assert.ok(p.model.status().height>1025);
    assert.ok(distance(spawn,p.model.status().position)<.001,'Throttle alone must not fly forward');
    input(p.model,{throttle:1,pitch:1,roll:.5});advance(p.model);
    assert.ok(p.model.status().pitch<-.7&&p.model.status().roll>.3);
    assert.ok(distance(spawn,p.model.status().position)>1);
    const pose=p.poses.at(-1);assert.ok(Math.abs(dot(pose.direction,pose.up))<1e-10);
    assert.ok(pose.direction.up<0&&pose.up.east!==0);
    p.model.stop();assert.equal(p.restored.at(-1).id,'orbital');assert.equal(p.model.status().active,false);
});
test('Angle self-level, gravity, inertia, drag, speed limits and frame time are bounded',async()=>{
    const a=setup(),b=setup();await start(a,{agl:500});await start(b,{agl:500});
    input(a.model,{pitch:1,throttle:.5});input(b.model,{pitch:1,throttle:.5});advance(a.model,5,60);advance(b.model,5,120);
    assert.ok(distance(a.model.status().position,b.model.status().position)<.002);
    assert.ok(Math.abs(a.model.status().height-b.model.status().height)<.002);
    const speed=a.model.status().horizontalSpeed;input(a.model);advance(a.model,3);
    assert.ok(a.model.status().horizontalSpeed>0&&a.model.status().horizontalSpeed<speed);
    assert.ok(Math.abs(a.model.status().pitch)<.001,'Angle mode must self-level');
    const falling=setup();await start(falling,{agl:500});input(falling.model,{pitch:1});advance(falling.model,2);
    assert.ok(falling.model.status().height<1499,'Tilt at hover throttle loses altitude');
    const c=setup();await start(c,{agl:500});input(c.model,{pitch:1,roll:1,throttle:1});advance(c.model,10);
    assert.ok(c.model.status().horizontalSpeed<=15.000001);
    const before=c.model.status().position;c.model.tick(100);
    assert.ok(distance(before,c.model.status().position)<=1.51);
    c.model.tick(NaN);assert.ok(Number.isFinite(c.model.status().height));
});
test('Acro retains attitude on release, crosses inverted flight and has continuous orthonormal camera axes',async()=>{
    const p=setup();await start(p,{flightMode:'acro',agl:500});input(p.model,{roll:1});advance(p.model,1.1);
    assert.ok(p.poses.at(-1).up.up<-.9,'Acro must pass through inverted roll');
    input(p.model);advance(p.model,1.5);const released={...p.model.status().attitude};advance(p.model,1);
    const later=p.model.status().attitude;
    assert.ok(Math.abs(released.w*later.w+released.x*later.x+released.y*later.y+released.z*later.z)>.99999,'Release must hold attitude, not level');
    input(p.model,{pitch:1,yaw:.5,roll:.2});advance(p.model,5);
    for(const pose of p.poses){
        assert.ok(Object.values(pose.direction).every(Number.isFinite));
        assert.ok(Math.abs(dot(pose.direction,pose.up))<1e-10);
        assert.ok(Math.abs(dot(pose.direction,pose.direction)-1)<1e-10);
        assert.ok(Math.abs(dot(pose.up,pose.up)-1)<1e-10);
    }
});
async function inverted(config={}){
    const p=setup();await start(p,{flightMode:'acro',agl:1000,acroMotorTimeConstant:0,...config});
    input(p.model,{throttle:-1,roll:1});advance(p.model,1,240);
    input(p.model,{throttle:-1});advance(p.model,1.5,240);
    assert.ok(p.poses.at(-1).up.up<-.999999);
    return p;
}
test('Acro spawns, resets and releases at zero throttle with no initial motor thrust',async()=>{
    const p=setup();await start(p,{flightMode:'acro',agl:500});
    assert.equal(p.model.status().throttle,0);assert.equal(p.model.status().thrustAcceleration,0);
    advance(p.model,.5);assert.ok(p.model.status().height<1500&&p.model.status().verticalSpeed<0);
    input(p.model,{throttle:1});advance(p.model,.5);assert.equal(p.model.status().throttle,1);
    input(p.model);advance(p.model,1);
    assert.equal(p.poses.at(-1).throttle,0);assert.ok(p.model.status().thrustAcceleration<.001);
    await p.model.reset();assert.equal(p.model.status().throttle,0);assert.equal(p.model.status().thrustAcceleration,0);
    assert.equal(p.model.status().height,1500);
});

test('Acro centre and lower stick half produce identical zero-thrust falls',async()=>{
    const results=[];
    for(const throttle of [0,-.5,-1]){
        const p=setup();await start(p,{flightMode:'acro',agl:500});
        input(p.model,{throttle});advance(p.model,1);
        assert.equal(p.model.status().throttle,0);assert.equal(p.model.status().thrustAcceleration,0);
        assert.ok(p.model.status().height<1496);results.push(p.model.status());
    }
    for(const result of results.slice(1)){
        assert.equal(result.height,results[0].height);assert.equal(result.verticalSpeed,results[0].verticalSpeed);
    }
});

test('Acro upper half controls motor command and HUD from zero to full, retaining the physical hover point',async()=>{
    const results=[];
    for(const throttle of [.25,.5,1]){
        const p=setup();await start(p,{flightMode:'acro',agl:500,acroMotorTimeConstant:0});
        input(p.model,{throttle});advance(p.model,1);
        assert.equal(p.model.status().throttle,throttle);assert.equal(p.poses.at(-1).throttle,throttle);
        results.push(p.model.status());
    }
    assert.ok(results[0].height<1500);assert.equal(results[1].height,1500);assert.ok(results[2].height>1500);
});

test('Acro inverted full throttle adds downward thrust and is faster than a zero-throttle fall',async()=>{
    const coast=await inverted(),full=await inverted();
    const before=full.model.status().height;
    input(coast.model,{throttle:-1});input(full.model,{throttle:1});
    advance(coast.model,1,240);advance(full.model,1,240);
    assert.ok(full.model.status().height<coast.model.status().height-10);
    assert.ok(full.model.status().verticalSpeed<coast.model.status().verticalSpeed-15);
    assert.ok(before-full.model.status().height>25);
    assert.ok(full.model.status().horizontalSpeed<1e-5,'Inverted thrust must not accelerate along camera forward');
});
test('Acro throttle cut follows analytic gravity/drag free fall instead of the assisted descent-speed limit',async()=>{
    const p=setup(),terminal=120,seconds=2,gravity=9.80665;
    await start(p,{flightMode:'acro',agl:500,maxSpeed:.5,climbSpeed:.2,acroMotorTimeConstant:0,acroTerminalVelocity:terminal});
    const height=p.model.status().height;input(p.model);advance(p.model,seconds,240);
    const expectedSpeed=-terminal*Math.tanh(gravity*seconds/terminal);
    const expectedDrop=terminal*terminal/gravity*Math.log(Math.cosh(gravity*seconds/terminal));
    assert.ok(Math.abs(p.model.status().verticalSpeed-expectedSpeed)<.001);
    assert.ok(Math.abs(height-p.model.status().height-expectedDrop)<.001);
    assert.ok(p.model.status().verticalSpeed<-19);
});
test('Acro gravity at zero collective is independent of attitude, with rate control still available',async()=>{
    const level=setup(),tumbling=setup();
    for(const p of [level,tumbling])await start(p,{flightMode:'acro',agl:500,acroMotorTimeConstant:0});
    input(level.model,{throttle:-1});input(tumbling.model,{throttle:-1,pitch:1,roll:.3,yaw:.7});
    advance(level.model,3);advance(tumbling.model,3);
    assert.ok(Math.abs(level.model.status().height-tumbling.model.status().height)<1e-9);
    assert.ok(Math.abs(level.model.status().verticalSpeed-tumbling.model.status().verticalSpeed)<1e-9);
    assert.equal(tumbling.model.status().thrustAcceleration,0);
    assert.notDeepEqual(tumbling.model.status().attitude,level.model.status().attitude);
});
test('Acro ninety-degree bank directs collective sideways while gravity stays down',async()=>{
    async function banked(){const p=setup();await start(p,{flightMode:'acro',agl:500,acroMotorTimeConstant:0});
        input(p.model,{throttle:-1,roll:1});advance(p.model,.5,240);input(p.model,{throttle:-1});advance(p.model,2,240);return p;}
    const full=await banked(),coast=await banked();
    input(full.model,{throttle:1});advance(full.model,.1,240);advance(coast.model,.1,240);
    assert.ok(full.model.status().position.longitude>coast.model.status().position.longitude);
    assert.ok(full.model.status().horizontalSpeed>3);
    assert.ok(Math.abs(full.model.status().verticalSpeed-coast.model.status().verticalSpeed)<.02);
});
test('Acro orientation changes do not redirect existing world momentum or apply GPS braking',async()=>{
    const straight=setup(),turning=setup();
    for(const p of [straight,turning]){
        await start(p,{flightMode:'acro',agl:500,maxSpeed:.5,climbSpeed:.2,acroMotorTimeConstant:0});
        input(p.model,{throttle:1,pitch:.5});advance(p.model,.75);
        assert.ok(p.model.status().horizontalSpeed>3,'Assisted maximum speed must not clamp Acro');
    }
    input(straight.model,{throttle:-1});input(turning.model,{throttle:-1,yaw:1});
    advance(straight.model,1.5);advance(turning.model,1.5);
    assert.ok(distance(straight.model.status().position,turning.model.status().position)<1e-6);
    assert.ok(Math.abs(straight.model.status().height-turning.model.status().height)<1e-8);
    assert.ok(turning.model.status().horizontalSpeed>2);
});
test('Acro thrust curve and motor response have bounded nonnegative spool-up and spool-down',async()=>{
    const slow=setup(),instant=setup();
    await start(slow,{flightMode:'acro',acroMotorTimeConstant:.1});await start(instant,{flightMode:'acro',acroMotorTimeConstant:0});
    input(slow.model,{throttle:1});input(instant.model,{throttle:1});advance(slow.model,.1);advance(instant.model,.1);
    assert.ok(slow.model.status().thrustAcceleration>9.80665&&slow.model.status().thrustAcceleration<4*9.80665);
    assert.ok(slow.model.status().verticalSpeed<instant.model.status().verticalSpeed);
    input(slow.model,{throttle:-1});advance(slow.model,1);
    assert.ok(slow.model.status().thrustAcceleration>=0&&slow.model.status().thrustAcceleration<.01);
    const linear=setup();await start(linear,{flightMode:'acro',acroThrustCurve:0,acroMotorTimeConstant:0});
    input(linear.model,{throttle:.25});advance(linear.model,1);
    assert.ok(Math.abs(linear.model.status().verticalSpeed)<1e-10,'25% of linear 4:1 thrust balances weight');
});
test('Acro free fall approaches aerodynamic terminal velocity smoothly, including after high-speed terrain contact',async()=>{
    const p=setup();await start(p,{flightMode:'acro',agl:1000,acroMotorTimeConstant:0});input(p.model,{throttle:-1});advance(p.model,20);
    assert.ok(Math.abs(p.model.status().verticalSpeed+22.5)<.01);
    const dive=await inverted({acroThrustToWeight:12,acroTerminalVelocity:120});input(dive.model,{throttle:1});advance(dive.model,20);
    assert.ok(dive.model.status().height>=1000.5&&dive.model.status().height<1001);
    assert.equal(dive.model.status().speed,0);
});

test('standard Acro level-flight speed settles near 160 km/h; explicit legacy drag remains configurable',async()=>{
    for(const [terminal,expected] of [[undefined,159.407],[35,247.967]]){
        const p=setup();await start(p,{flightMode:'acro',agl:1000,
            ...(terminal===undefined?{}:{acroTerminalVelocity:terminal})});
        // Rotate to the full-throttle level-flight attitude without introducing
        // a test-only attitude setter: 4*cos(tilt)=1 balances weight.
        const duration=Math.acos(1/4)/Math.PI,steps=Math.floor(duration*240);
        input(p.model,{pitch:1});
        for(let i=0;i<steps;i++)p.model.tick(1/240);
        p.model.tick(duration-steps/240);
        input(p.model);advance(p.model,2,240);
        input(p.model,{throttle:1});advance(p.model,30,240);
        assert.ok(Math.abs(p.model.status().horizontalSpeed*3.6-expected)<.02);
        assert.ok(Math.abs(p.model.status().verticalSpeed)<.001);
    }
});

test('rate curves keep full stick and neutral exact, remain symmetric and soften the centre',()=>{
    for(const expo of [0,.3,1]){
        assert.equal(rateCommand(0,600,expo),0);
        assert.equal(rateCommand(1,600,expo),600);
        assert.equal(rateCommand(-1,600,expo),-600);
        let previous=-600;
        for(let i=-100;i<=100;i++){
            const value=rateCommand(i/100,600,expo);
            assert.ok(value>=previous&&Math.abs(value)<=600);
            assert.equal(value,-rateCommand(-i/100,600,expo));previous=value;
        }
    }
    assert.equal(rateCommand(.5,600,0),300);
    assert.equal(rateCommand(.5,600,1),75);
});

test('independent body rates reach configured roll, pitch and yaw speeds and survive reset',async()=>{
    const config={flightMode:'acro',agl:500,acroRollRate:600,acroPitchRate:420,acroYawRate:250,acroRateExpo:.4};
    for(const [axis,rate] of [['roll',600],['pitch',420],['yaw',250]]){
        const p=setup();await start(p,config);input(p.model,{[axis]:1});advance(p.model,1.5,240);
        const before=p.model.status().attitude;advance(p.model,.025,240);
        const after=p.model.status().attitude;
        const dot=before.w*after.w+before.x*after.x+before.y*after.y+before.z*after.z;
        const measured=2*Math.acos(Math.min(1,Math.abs(dot)))*180/Math.PI/.025;
        assert.ok(Math.abs(measured-rate)<.02,`${axis}: ${measured} vs ${rate}`);
        await p.model.reset();input(p.model,{[axis]:1});advance(p.model,1.5,240);
        const reset=p.model.status().attitude;
        assert.ok(Math.abs(before.w*reset.w+before.x*reset.x+before.y*reset.y+before.z*reset.z)>.999999);
    }
});

test('custom rates retain frame-rate independence and Angle/GPS controls ignore Acro rates',async()=>{
    const result=[];
    for(const fps of [30,60,120,240]){
        const p=setup();await start(p,{flightMode:'acro',agl:500,acroRollRate:1500,acroPitchRate:850,acroYawRate:700,acroRateExpo:.6});
        input(p.model,{roll:.3,pitch:.2,yaw:.4,throttle:.5});advance(p.model,2,fps);result.push(p.model.status());
    }
    for(const current of result.slice(1)){
        assert.ok(distance(current.position,result[0].position)<.001);
        assert.ok(Math.abs(current.height-result[0].height)<.001);
    }
    for(const flightMode of ['angle','gps']){
        const baseline=setup(),custom=setup();await start(baseline,{flightMode,agl:500});
        await start(custom,{flightMode,agl:500,acroRollRate:1500,acroPitchRate:850,acroYawRate:700,acroRateExpo:.6});
        for(const p of [baseline,custom]){input(p.model,{roll:.5,pitch:.2,yaw:.3});advance(p.model,1);}
        assert.deepEqual(custom.model.status().attitude,baseline.model.status().attitude);
        assert.deepEqual(custom.model.status().position,baseline.model.status().position);
    }
});
test('Acro attitude, motors and trajectory agree at 30, 60, 120 and 240 FPS',async()=>{
    const results=[];
    for(const fps of [30,60,120,240]){
        const p=setup();await start(p,{flightMode:'acro',agl:500});input(p.model,{throttle:.3,pitch:.2,roll:.1,yaw:.3});advance(p.model,3,fps);results.push(p.model.status());
    }
    for(const current of results.slice(1)){
        assert.ok(distance(results[0].position,current.position)<.001);
        assert.ok(Math.abs(results[0].height-current.height)<.001);
        assert.ok(Math.abs(results[0].verticalSpeed-current.verticalSpeed)<1e-8);
    }
});
test('GPS keeps assisted translation, look, hover and automatic braking',async()=>{
    const p=setup();await start(p,{flightMode:'gps'});p.model.stick(1,0);advance(p.model,4);
    assert.ok(p.model.status().position.latitude>spawn.latitude);assert.equal(p.model.status().height,1020);
    const speed=p.model.status().speed;p.model.stick(0,0);advance(p.model,1);
    assert.ok(p.model.status().speed>0&&p.model.status().speed<speed);
    p.model.look(100,-100);assert.ok(p.model.status().heading>0&&p.model.status().pitch>0);
    assert.equal(p.poses.at(-1).direction,undefined);
});
test('keyboard uses gas E/Q, yaw A/D, pitch W/S and roll arrows',async()=>{
    const p=setup();await start(p);p.model.key('d',true);advance(p.model,.5);p.model.key('d',false);
    assert.ok(distance(spawn,p.model.status().position)<.001);
    p.model.key('e',true);advance(p.model);assert.ok(p.model.status().height>1020);
    p.model.key('w',true);p.model.key('ArrowRight',true);advance(p.model);
    assert.ok(p.model.status().roll>0&&p.model.status().pitch<0);
});
test('terrain sweeps stop at raised terrain and missing tiles do not allow blind movement',async()=>{
    const p=setup({renderedHeight:position=>position.latitude>spawn.latitude+1/111320?1100:1000});
    await start(p,{maxSpeed:100,acceleration:50});input(p.model,{pitch:1,throttle:1});advance(p.model,2);
    assert.ok(distance(spawn,p.model.status().position)<1.5);assert.equal(p.model.status().speed,0);
    assert.match(p.model.status().reason,/Terrain contact/);
    const unknown=setup();await start(unknown);input(unknown.model,{pitch:1});unknown.ground(undefined);advance(unknown.model);
    assert.deepEqual(unknown.model.status().position,spawn);assert.equal(unknown.model.status().agl,null);
    unknown.ground(1000);advance(unknown.model);assert.ok(unknown.model.status().position.latitude>spawn.latitude);
    const ray=setup({terrainCollision:()=>true});await start(ray);input(ray.model,{pitch:1});advance(ray.model);
    assert.deepEqual(ray.model.status().position,spawn);assert.match(ray.model.status().reason,/Terrain contact/);
});
test('descent and refined terrain never put any mode below the surface, including while paused',async()=>{
    for(const mode of ['gps','angle','acro']){
        const p=setup();await start(p,{agl:1,flightMode:mode});p.model.vertical(-1);advance(p.model,10);
        assert.ok(p.model.status().height>=1000.5);
        p.model.pause(true);p.ground(1050);p.model.tick(.1);assert.equal(p.model.status().height,1050.5);
        const before=p.model.status().position;advance(p.model);assert.deepEqual(p.model.status().position,before);
        p.model.pause(false);p.model.tick(.1);assert.equal(p.model.status().speed,0);
    }
});
test('mode changes and reset respawn level without losing the original orbital camera',async()=>{
    const p=setup();await start(p,{agl:40});input(p.model,{pitch:1,roll:1});advance(p.model);
    await p.model.reconfigure({flightMode:'acro',agl:30},new AbortController().signal);
    assert.deepEqual(p.model.status().position,spawn);assert.equal(p.model.status().height,1030);
    assert.equal(p.model.status().mode,'acro');assert.equal(p.model.status().roll,0);
    input(p.model,{roll:1});advance(p.model);await p.model.reset();
    assert.equal(p.model.status().mode,'acro');assert.equal(p.model.status().speed,0);assert.equal(p.model.status().roll,0);
    p.model.stop();assert.ok(p.restored.every(r=>r.id==='orbital'));
});
test('exit, abort and terrain loss invalidate pending spawn without late camera changes',async()=>{
    let resolve;const p=setup({sampleHeight:()=>new Promise(r=>resolve=r)});
    const pending=p.model.start(spawn,new AbortController().signal);p.model.stop();resolve(2000);
    assert.deepEqual(await pending,{cancelled:true});assert.equal(p.poses.length,0);
    const next=setup();await start(next);next.ready(false);next.model.tick(.1);
    assert.equal(next.model.status().active,false);assert.equal(next.restored.length,1);
    const aborted=new AbortController();aborted.abort();await assert.rejects(next.model.start(spawn,aborted.signal));
});
test('invalid modes, parameters and coordinates are rejected before changing camera',async()=>{
    for(const command of [{flightMode:'unknown'},{agl:NaN},{agl:-1},{maxSpeed:101},{climbSpeed:0},{acceleration:0},{deceleration:Infinity},
        {acroThrustToWeight:1},{acroThrustCurve:1.1},{acroMotorTimeConstant:-1},{acroTerminalVelocity:Infinity},
        ...['acroRollRate','acroPitchRate','acroYawRate'].flatMap(key=>[9,1501,NaN,Infinity,'600'].map(value=>({[key]:value}))),
        ...[-.01,1.01,NaN,Infinity].map(acroRateExpo=>({acroRateExpo}))])assert.throws(()=>parameters(command));
    const p=setup();await assert.rejects(p.model.start({latitude:90,longitude:0},new AbortController().signal));
    assert.equal(p.poses.length,0);
});
