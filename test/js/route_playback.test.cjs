const test = require('node:test');
const assert = require('node:assert/strict');
const {prepare, evaluate, create, distance} = require('../../web/flight_recording.js').routePlayback;
const {createSimulator} = require('../../web/free_flight.js');
const signal = () => new AbortController().signal;
const a = {latitude:46.7, longitude:8.4, heightMode:'agl', heightMeters:30};
const b = {latitude:46.7002, longitude:8.4002, heightMode:'agl', heightMeters:40};
const base = (points=[a,b],more={}) => ({points,defaultSpeedMetersPerSecond:10,defaultAglMeters:20,
    settings:{flightMode:'gps',cameraFovDegrees:110},...more});

function mock(){
    const poses=[],events=[];
    const simulator={active:false,async start(){this.active=true;},stop(){this.active=false;},
        playbackPose(p){assert.equal(this.active,true);poses.push(p);},
        playbackEnd(){poses.push({released:true});}};
    const playback=create({simulator,sampleGround:async points=>points.map(()=>1000),
        renderedGround:()=>1000,emit:(type,state)=>events.push({type,state})});
    return {simulator,playback,poses,events};
}

test('planned trajectory resolves AGL from terrain and preserves explicit leg speed',async()=>{
    let calls=0;
    const result=await prepare(base([a,{...b,speedMetersPerSecond:4}, {...b,latitude:46.7004}]),
        async points=>{calls++;return points.map(()=>1000);},signal());
    assert.equal(calls,1);
    assert.deepEqual(result.points.map(p=>p.height),[1030,1040,1040]);
    assert.equal(result.recorded,false);
    assert.equal(result.assumedSpeed,true);
    assert.ok(result.duration>3);
    const middle=evaluate(result,result.points[1].seconds);
    assert.ok(Math.abs(middle.height-1040)<1e-9);
    assert.ok(middle.progress>0&&middle.progress<1);
});

test('recorded timing, absolute heights and speed are unchanged by replay preparation',async()=>{
    const values=[{seconds:3,absoluteElevationMeters:1100,groundSpeedMetersPerSecond:2},
        {seconds:4.25,absoluteElevationMeters:1110,groundSpeedMetersPerSecond:18}];
    const result=await prepare(base([a,b],{recorded:values}),async()=>{throw Error('Unneeded terrain read');},signal());
    assert.deepEqual(result.points.map(p=>p.seconds),[0,1.25]);
    assert.deepEqual(result.points.map(p=>p.height),[1100,1110]);
    assert.deepEqual(result.points.map(p=>p.speed),[2,18]);
    assert.equal(evaluate(result,.625).speed,10);
    assert.equal(result.recorded,true);
});

test('missing recorded AGL does not become fabricated height',async()=>{
    const result=await prepare(base([a,b],{recorded:[
        {seconds:0,absoluteElevationMeters:1050},
        {seconds:1,absoluteElevationMeters:1060,terrainElevationMeters:1020},
    ]}),async()=>[],signal());
    assert.equal(result.points[0].ground,null);
    assert.equal(evaluate(result,.5).ground,null);
    assert.equal(result.points[1].ground,1020);
});

test('partial terrain coverage fails closed; terrain requests are batched at 64 points',async()=>{
    const points=Array.from({length:130},(_,i)=>({...a,latitude:a.latitude+i*.00001}));
    const lengths=[];
    const request=base(points);
    const result=await prepare(request,async items=>{lengths.push(items.length);return items.map(()=>1000);},signal());
    assert.deepEqual(lengths,[64,64,2]);
    assert.equal(result.points.length,130);
    await assert.rejects(()=>prepare(request,async items=>items.map(()=>null),signal()),/Terrain heights unavailable/);
    await assert.rejects(()=>prepare(base(Array.from({length:1001},()=>a)),async()=>[],signal()),/Replay needs/);
});

test('trajectory validation rejects unsupported coordinates, heights and malformed recorded samples',async()=>{
    const bad=[
        base([a,{...b,latitude:91}]),
        base([a,{...b,heightMode:'absolute',heightMeters:NaN}]),
        base([a,b],{recorded:[{seconds:0,absoluteElevationMeters:1000},{seconds:0,absoluteElevationMeters:1001}]}),
        base([a,b],{defaultSpeedMetersPerSecond:0}),
    ];
    for(const request of bad)await assert.rejects(()=>prepare(request,async()=>[1000,1000],signal()));
});

test('interpolation across antimeridian is short and heading remains finite',async()=>{
    const request=base([{latitude:0,longitude:179.9,heightMode:'absolute',heightMeters:2000},
        {latitude:0,longitude:-179.9,heightMode:'absolute',heightMeters:2020}],
        {recorded:[{seconds:0,absoluteElevationMeters:2000},{seconds:10,absoluteElevationMeters:2020}]});
    const path=await prepare(request,async()=>[],signal());
    const midpoint=evaluate(path,5);
    assert.ok(Math.abs(Math.abs(midpoint.longitude)-180)<.0001);
    assert.ok(Number.isFinite(midpoint.heading)&&Number.isFinite(midpoint.pitch));
    assert.ok(distance(path.points[0],path.points[1])<30000);
});

test('pause/resume/speed/stop/restart keep manual simulator controllable',async()=>{
    const m=mock();
    await m.playback.start(base(),signal());
    assert.equal(m.playback.status().phase,'playing');
    m.playback.tick(.5);
    const t=m.playback.status().seconds;
    m.playback.control({action:'pause'});m.playback.tick(1);
    assert.equal(m.playback.status().seconds,t);
    m.playback.control({action:'speed',speed:4});
    m.playback.control({action:'resume'});m.playback.tick(.1);
    assert.ok(m.playback.status().seconds>t+.39);
    m.playback.control({action:'stop'});
    assert.equal(m.playback.active,false);
    assert.equal(m.simulator.active,true);
    assert.ok(m.poses.at(-1).released);
    m.playback.control({action:'restart'});
    assert.equal(m.playback.status().seconds,0);
    assert.equal(m.playback.active,true);
    assert.throws(()=>m.playback.control({action:'speed',speed:999}),/Invalid replay speed/);
});

test('renderer interruption prevents stale route async completion from restarting flight',async()=>{
    let resolve;
    const m=mock();
    const pending=prepare(base(),()=>new Promise(r=>resolve=r),signal());
    resolve([1000,1000]);await pending;
    const replay=create({simulator:m.simulator,sampleGround:()=>new Promise(r=>resolve=r)});
    const waiting=replay.start(base(),signal());
    replay.interrupt('Renderer reloaded');
    resolve([1000,1000]);
    await assert.rejects(waiting,/cancelled/);
    assert.equal(replay.status().phase,'idle');
    assert.equal(m.simulator.active,false);
});

test('virtual playback input locks do not alter ordinary free-flight controls after release',async()=>{
    const poses=[];
    const simulator=createSimulator({sampleHeight:async()=>1000,renderedHeight:()=>1000,
        terrainCollision:()=>false,captureCamera:()=>({heading:0}),restoreCamera:()=>{},
        applyPose:p=>poses.push(p),isTerrainReady:()=>true,onState:()=>{}});
    await simulator.start({...base().settings,latitude:46.7,longitude:8.4,agl:40},signal());
    simulator.playbackPose({latitude:46.7001,longitude:8.4001,height:1040,heading:.4,pitch:0,speed:8});
    const locked=simulator.status().position;
    simulator.key('w',true);simulator.tick(.1);
    assert.deepEqual(simulator.status().position,locked);
    simulator.playbackEnd();simulator.key('w',true);simulator.tick(.1);
    assert.notDeepEqual(simulator.status().position,locked);
});

test('AGL replay follows currently rendered terrain and pauses explicitly on missing tiles',async()=>{
    const frames=[];let terrain=1000;
    const simulator={active:true,async start(){},stop(){},playbackPose:frame=>frames.push(frame),playbackEnd(){}};
    const replay=create({simulator,sampleGround:async points=>points.map(()=>1000),renderedGround:()=>terrain});
    await replay.start(base(),signal());
    terrain=1035;replay.tick(.1);
    assert.ok(frames.at(-1).height>1065);
    terrain=undefined;const before=frames.length;replay.tick(.1);
    assert.equal(replay.status().phase,'paused');
    assert.equal(frames.length,before);
    assert.match(replay.status().reason,/terrain tiles unavailable/i);
    terrain=1000;replay.control({action:'resume'});replay.tick(.1);
    assert.equal(replay.status().phase,'playing');
});

test('stop while preparing cancels late terrain data rather than launching simulation',async()=>{
    let complete;const m=mock();
    const replay=create({simulator:m.simulator,sampleGround:()=>new Promise(r=>complete=r)});
    const pending=replay.start(base(),signal());
    replay.control({action:'stop'});
    complete([1000,1000]);
    await assert.rejects(pending,/cancelled/);
    assert.equal(replay.status().phase,'idle');
    assert.equal(m.simulator.active,false);
});
