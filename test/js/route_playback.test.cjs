const test = require('node:test');
const assert = require('node:assert/strict');
const {prepare, evaluate, create, distance} = require('../../web/features/flight/flight_recording.js').routePlayback;
const {createSimulator} = require('../../web/features/flight/free_flight.js');
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

test('scenery lookahead is bounded, rate-aware and inactive during pause/stop',async()=>{
 const m=mock();assert.deepEqual(m.playback.sceneryLookahead(),[]);
 await m.playback.start(base([a,{...b,latitude:a.latitude+.01}]),signal());
 const slow=m.playback.sceneryLookahead();assert.equal(slow.length,3);assert.ok(slow[0].latitude>a.latitude);assert.ok(slow[2].latitude>slow[0].latitude);
 m.playback.control({action:'speed',speed:4});assert.ok(m.playback.sceneryLookahead()[0].latitude>slow[0].latitude);
 m.playback.control({action:'pause'});assert.deepEqual(m.playback.sceneryLookahead(),[]);
 m.playback.control({action:'stop'});assert.deepEqual(m.playback.sceneryLookahead(),[]);
});

test('benchmark freezes AGL, truncates to a fixed prefix and reuses poses across warmup and measured passes',async()=>{
    let ground=1000,calls=0;const poses=[],events=[];
    const sim={active:false,async start(){this.active=true;},stop(){this.active=false;},
        playbackPose(p){poses.push(p);return true;},playbackEnd(){}};
    const replay=create({simulator:sim,sampleGround:async p=>{calls++;return p.map(()=>ground);},
        renderedGround:()=>{throw Error('Benchmark must not depend on rendered LOD heights');},emit:(_,s)=>events.push(s)});
    const route=base([a,{...b,latitude:46.705},{...b,latitude:46.71,longitude:8.42}],{benchmarkLimitSeconds:35});
    const prepared=await replay.prepareBenchmark(route,signal());
    assert.equal(prepared.duration,35);assert.ok(prepared.sourceDuration>35);
    const initialCalls=calls;ground=1050;
    await replay.start({...route,benchmark:true},signal());
    assert.throws(()=>replay.control({action:'speed',speed:2}),/Invalid replay speed/);
    const fly=()=>{const start=poses.length;for(let i=0;i<400&&replay.active;i++)replay.tick(.1);assert.equal(replay.status().phase,'finished');return poses.slice(start);};
    const first=fly();replay.control({action:'restart'});const second=fly();
    assert.deepEqual(second,first);assert.equal(calls,initialCalls);
    assert.equal(first.at(-1).seconds,35);assert.ok(first.at(-1).latitude<46.71);
    assert.equal(first.at(-1).aglTarget,null);
    replay.interrupt();replay.clearBenchmark();
    await assert.rejects(()=>replay.start({...route,benchmark:true},signal()),/not prepared/);
});

test('benchmark preparation is abortable and cannot publish a late trajectory',async()=>{
    let release;const replay=create({simulator:{stop(){}},sampleGround:()=>new Promise(resolve=>{release=resolve;})});
    const route=base([a,{...b,latitude:46.705}],{benchmarkLimitSeconds:60});
    const pending=replay.prepareBenchmark(route,signal());
    replay.control({action:'stop'});release([1000,1000]);
    await assert.rejects(pending,/abort/i);
    await assert.rejects(()=>replay.start({...route,benchmark:true},signal()),/not prepared/);
});

test('real simulator benchmark reuses verified spawn across variants without another terrain request',async()=>{
    let singleReads=0,routeReads=0;
    const states=[];
    const sim=createSimulator({sampleHeight:async()=>{singleReads++;throw Error('Terrain request timed out');},
        renderedHeight:()=>1000,terrainCollision:()=>false,captureCamera:()=>({heading:0}),restoreCamera:()=>{},
        applyPose:()=>{},isTerrainReady:()=>true,onState:s=>states.push(s)});
    const replay=create({simulator:sim,sampleGround:async points=>{routeReads++;return points.map(()=>1000);}});
    const route=base([a,{...b,latitude:46.705}],{benchmarkLimitSeconds:35});
    await replay.prepareBenchmark(route,signal());
    const initialReads=routeReads;
    for(let variant=0;variant<6;variant++){
        await replay.start({...route,benchmark:true},signal());
        assert.equal(sim.active,true);
        assert.equal(sim.status().height,1030);
        assert.equal(sim.status().heightAboveHome,30);
        assert.equal(replay.status().phase,'playing');
        replay.interrupt();sim.stop();
    }
    assert.equal(singleReads,0);assert.equal(routeReads,initialReads);
    // Ordinary replay and a bridge-supplied field cannot bypass terrain sampling.
    replay.clearBenchmark();
    await assert.rejects(replay.start({...route,settings:{...route.settings,benchmarkGround:1000}},signal()),/Terrain request timed out/);
    assert.equal(singleReads,1);assert.equal(sim.active,false);
    assert.equal(states.at(-1).reason,'Unable to start simulated flight');
});

test('real simulator benchmark reports a safe start stage and restores the camera after graphics failure',async()=>{
    const states=[],restored=[];
    const sim=createSimulator({sampleHeight:async()=>{throw Error('Unexpected terrain read');},
        renderedHeight:()=>1000,terrainCollision:()=>false,captureCamera:()=>({heading:0}),restoreCamera:s=>restored.push(s),
        applyPose:()=>{},isTerrainReady:()=>true,onState:s=>states.push(s),
        prepareGraphics:async()=>{throw Error('private-provider-url');}});
    const replay=create({simulator:sim,sampleGround:async points=>points.map(()=>1000)});
    const route=base([a,{...b,latitude:46.705}],{benchmarkLimitSeconds:35});
    await replay.prepareBenchmark(route,signal());
    await assert.rejects(replay.start({...route,benchmark:true},signal()),e=>{
        assert.equal(e.message,'Benchmark flight start failed: graphics');
        assert.equal(e.cause.message,'private-provider-url');return true;
    });
    assert.equal(sim.active,false);assert.equal(sim.status().pending,false);
    assert.equal(restored.length,1);
    assert.equal(states.at(-1).reason,'Benchmark flight start failed: graphics');
    assert.equal(replay.status().reason,'Benchmark flight start failed: graphics');
});

test('benchmark cannot reuse a verified sample after the simulator loses terrain readiness',async()=>{
    let ready=true;
    const sim=createSimulator({sampleHeight:async()=>1000,renderedHeight:()=>1000,
        terrainCollision:()=>false,captureCamera:()=>({heading:0}),restoreCamera:()=>{},
        applyPose:()=>{},isTerrainReady:()=>ready,onState:()=>{}});
    const replay=create({simulator:sim,sampleGround:async points=>points.map(()=>1000)});
    const route=base([a,{...b,latitude:46.705}],{benchmarkLimitSeconds:35});
    await replay.prepareBenchmark(route,signal());ready=false;
    await assert.rejects(replay.start({...route,benchmark:true},signal()),/Detailed terrain is required/);
    assert.equal(sim.active,false);
});

test('benchmark distinguishes camera capture from graphics profile application failures',async()=>{
    for(const failureStage of ['camera','graphics']){
        let restored=0;
        const fail=()=>{throw Error('private-provider-url');};
        const sim=createSimulator({sampleHeight:async()=>1000,renderedHeight:()=>1000,
            terrainCollision:()=>false,captureCamera:failureStage==='camera'?fail:()=>({heading:0}),
            restoreCamera:()=>restored++,applyGraphics:failureStage==='graphics'?fail:()=>{},
            applyPose:()=>{},isTerrainReady:()=>true,onState:()=>{}});
        const replay=create({simulator:sim,sampleGround:async points=>points.map(()=>1000)});
        const route=base([a,{...b,latitude:46.705}],{benchmarkLimitSeconds:35});
        await replay.prepareBenchmark(route,signal());
        await assert.rejects(replay.start({...route,benchmark:true},signal()),error=>{
            assert.equal(error.message,`Benchmark flight start failed: ${failureStage}`);
            assert.equal(error.cause.message,'private-provider-url');return true;
        });
        assert.equal(sim.active,false);assert.equal(sim.status().pending,false);
        assert.equal(restored,failureStage==='graphics'?1:0);
    }
});
