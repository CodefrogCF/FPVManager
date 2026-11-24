const {test}=require('node:test'),assert=require('node:assert/strict');
const {create}=require('../../web/features/signal/live_radio.js');
function setup(options={}){
    let now=0,calls=0,levels=[],resolve=null,fail=false,defer=false,availability=true;const events=[],layers=[],stations=[],nodes=new Map(),sampleSizes=[];
    const doc={getElementById:id=>{if(!nodes.has(id))nodes.set(id,{dataset:{},listeners:{},addEventListener(k,v){this.listeners[k]=v;}});return nodes.get(id);}};
    const C={Cartographic:{fromDegrees:(longitude,latitude)=>({latitude,longitude})},sampleTerrainMostDetailed:async(provider,positions)=>{
        calls++;sampleSizes.push(positions.length);levels.push('most-detailed');if(defer)await new Promise(r=>resolve=r);return positions.map(p=>({...p,height:fail?NaN:1000}));
    }};
    const layer={set:c=>layers.push(c),clear:()=>layers.push(null),setStation:c=>stations.push(c),dispose:()=>layers.push('disposed')};
    const api=create({C,viewer:{},terrain:{sample:(fn)=>fn(availability?{availability:{}}:{})},ready:()=>true,emit:(type,p)=>events.push({type,...p}),doc,layer,clock:()=>now,wallClock:()=>100000+now,...options});
    return {api,events,layers,stations,nodes,sampleSizes,clock:n=>now=n,get calls(){return calls;},levels,get resolve(){return resolve;},set defer(v){defer=v;},set fail(v){fail=v;},set availability(v){availability=v;}};
}
const command={positions:[{latitude:46.7,longitude:8.4},{latitude:46.701,longitude:8.4}]};

test('default sampling timers preserve browser Window receiver semantics',async()=>{
    const nativeSet=globalThis.setTimeout,nativeClear=globalThis.clearTimeout;
    let started=0,cleared=0,api;
    globalThis.setTimeout=function(fn,ms){'use strict';
        if(this!==undefined&&this!==globalThis)throw TypeError('Illegal invocation');
        started++;return Reflect.apply(nativeSet,globalThis,arguments);
    };
    globalThis.clearTimeout=function(id){'use strict';
        if(this!==undefined&&this!==globalThis)throw TypeError('Illegal invocation');
        cleared++;return Reflect.apply(nativeClear,globalThis,arguments);
    };
    try{
        const p=setup();api=p.api;
        const result=await api.sample(command,new AbortController().signal);
        assert.deepEqual(result.heights,[1000,1000]);
        assert.equal(p.calls,1,'a host timer must not fail before terrain sampling');
        assert.ok(started>0);assert.ok(cleared>0);
        assert.equal(api.diagnostics().activeRequests,0);
    }finally{
        globalThis.setTimeout=nativeSet;globalThis.clearTimeout=nativeClear;
        api?.dispose();
    }
});
test('live pose bridge is opt-in and bounded; controls expose settings without sharing per-frame telemetry',()=>{
    const p=setup(),state={active:true,paused:false,flightId:1,position:{latitude:46.7,longitude:8.4},height:1100,home:{latitude:46.7,longitude:8.3}};
    p.api.observe(state);assert.equal(p.events.length,0);p.api.monitor({enabled:true,revision:1});
    for(let i=0;i<120;i++){p.clock(i*1000/60);p.api.observe(state);}
    assert.equal(p.events.length,3);p.api.observe({...state,active:false},true);assert.equal(p.events.at(-1).active,false);
    p.nodes.get('hud-live-radio').listeners.click();assert.equal(p.events.at(-1).type,'flight-radio-settings-request');
    p.nodes.get('flight-radio-enabled').checked=false;p.nodes.get('flight-radio-enabled').listeners.change();assert.equal(p.events.at(-1).enabled,false);
    p.api.monitor({enabled:false,revision:3});assert.equal(p.nodes.get('hud-live-radio').hidden,true);
    assert.throws(()=>p.api.monitor({enabled:'yes',revision:3}));
});
test('highest-available terrain samples are cached exactly, expire and are invalidated with terrain',async()=>{
    const p=setup(),signal=new AbortController().signal;
    assert.deepEqual((await p.api.sample(command,signal)).heights,[1000,1000]);assert.deepEqual(p.levels,['most-detailed']);
    await p.api.sample(command,signal);assert.equal(p.calls,1);
    p.clock(30000);await p.api.sample(command,signal);assert.equal(p.calls,2);
    p.api.terrainChanged();await p.api.sample(command,signal);assert.equal(p.calls,3);
    p.fail=true;p.api.terrainChanged();await assert.rejects(p.api.sample(command,signal),/Incomplete/);
    p.fail=false;await p.api.sample(command,signal);assert.equal(p.calls,5);
    await assert.rejects(p.api.sample({positions:Array(257).fill(command.positions[0])},signal));
    await assert.rejects(p.api.sample({positions:[{latitude:91,longitude:0}]},signal));
});
test('missing detailed-terrain availability cannot be presented as clear terrain',async()=>{
    const p=setup(),signal=new AbortController().signal;
    p.availability=false;
    await assert.rejects(p.api.sample(command,signal),/Detailed live terrain unavailable/);
    assert.equal(p.calls,0,'no fixed-level fallback that could miss a ridge');
    p.availability=true;
    const result=await p.api.sample(command,signal);
    assert.deepEqual(result.heights,[1000,1000]);
    assert.equal(result.samplingMethod,'most-detailed-available');
});
test('overlapping queries are bounded, late terrain and cancelled responses never populate the cache',async()=>{
    const p=setup();p.defer=true;const abort=new AbortController(),pending=p.api.sample(command,abort.signal);
    await assert.rejects(p.api.sample(command,new AbortController().signal),/already running/);assert.equal(p.calls,1);
    p.api.terrainChanged();p.resolve();await assert.rejects(pending,/changed/);
    p.defer=false;await p.api.sample(command,new AbortController().signal);assert.equal(p.calls,2);
    p.api.terrainChanged();p.defer=true;const cancelled=p.api.sample(command,abort.signal);abort.abort();p.resolve();await assert.rejects(cancelled);
    p.defer=false;await p.api.sample(command,new AbortController().signal);assert.equal(p.calls,4);
    p.api.dispose();await assert.rejects(p.api.sample(command,new AbortController().signal));
});
test('terrain provider change releases obsolete query slot before its promise settles',async()=>{
    const p=setup(),signal=new AbortController().signal;
    p.defer=true;
    const stale=p.api.sample(command,signal);
    const finishStale=p.resolve;
    p.api.terrainChanged();
    p.defer=false;
    const fresh=await p.api.sample(command,signal);
    assert.deepEqual(fresh.heights,[1000,1000]);
    assert.equal(p.calls,2,'do not block the new terrain behind obsolete requests');
    finishStale();
    await assert.rejects(stale,/changed/);
    await p.api.sample(command,signal);
    assert.equal(p.calls,2,'late old results must not clear the new cache');
    p.api.dispose();
});
test('old results cannot restore a clear status after settings, terrain changes or disabling',()=>{
    const p=setup();p.api.monitor({enabled:true,revision:1});
    p.api.observe({active:true,paused:false,flightId:1});
    const result={revision:2,flightId:1,expiresAtMs:105000,state:'noSampledObstruction',rays:[{state:'noSampledObstruction'}],message:'Sampled'};
    p.api.set(result);assert.equal(p.nodes.get('hud-live-radio').dataset.state,'noSampledObstruction');
    p.clock(6000);p.api.observe({active:true,paused:false,flightId:1});assert.equal(p.nodes.get('hud-live-radio').dataset.state,'unknown');
    p.api.set({...result,expiresAtMs:111000});
    p.api.terrainChanged();const n=p.layers.length;p.api.set(result);assert.equal(p.layers.length,n);assert.equal(p.nodes.get('hud-live-radio').dataset.state,'unknown');
    p.api.observe({active:true,paused:false,flightId:2});p.api.set({...result,revision:3,expiresAtMs:111000});assert.equal(p.nodes.get('hud-live-radio').dataset.state,'unknown');
    p.api.monitor({enabled:false,revision:4});p.api.set({...result,revision:5});assert.equal(p.nodes.get('hud-live-radio').hidden,true);
    p.api.monitor({enabled:true,revision:6});assert.throws(()=>p.api.set({revision:6,flightId:2,state:'noSampledObstruction',rays:[]}));
    p.api.dispose();assert.equal(p.layers.at(-1),'disposed');
});
test('terrain cache has a bounded capacity',async()=>{
    const p=setup(),signal=new AbortController().signal;
    for(let batch=0;batch<17;batch++)await p.api.sample({positions:Array.from({length:256},(_,i)=>({latitude:46.7,longitude:8+(batch*256+i)*.000001}))},signal);
    assert.equal(p.calls,17);await p.api.sample({positions:[{latitude:46.7,longitude:8}]},signal);assert.equal(p.calls,18);
});

test('station selection, visibility flags and LOS rays are independent',()=>{
    const p=setup();
    p.api.monitor({enabled:true,revision:1,useSpawn:false,showGroundStationMarker:true,showSignalPath:false});
    p.api.station({revision:1,position:{latitude:47.0,longitude:8.0}});
    assert.equal(p.stations.at(-1).latitude,47);
    p.api.observe({active:true,paused:false,flightId:1});
    p.api.set({revision:2,flightId:1,expiresAtMs:105000,state:'obstructed',rays:[{state:'obstructed'}],message:'Terrain obstruction'});
    assert.equal(p.layers.at(-1),null,'hide sight line, not the assessment status');
    assert.equal(p.nodes.get('hud-live-radio').dataset.state,'obstructed');
    assert.equal(p.stations.at(-1).longitude,8,'station survives unknown/ray clearing');
    p.api.station({revision:1,position:{latitude:47,longitude:8.5}});
    assert.equal(p.stations.at(-1).longitude,8,'reject older station updates');
    p.api.monitor({enabled:true,revision:3,useSpawn:false,showGroundStationMarker:false,showSignalPath:true});
    p.api.station({revision:3,position:{latitude:47,longitude:8.5}});
    assert.equal(p.stations.at(-1),null,'visibility controls station independently');
    p.api.monitor({enabled:false,revision:4});
    assert.equal(p.stations.at(-1),null);
    assert.throws(()=>p.api.monitor({enabled:true,revision:5,showSignalPath:5}));
    p.api.monitor({enabled:true,revision:5});
    assert.throws(()=>p.api.station({revision:5,position:{latitude:91,longitude:8}}),/Invalid/);
    p.api.dispose();
});

test('link assessment is immutable, expires, and cannot equate geometric loss with RC loss',()=>{
    const p=setup();p.api.monitor({enabled:true,revision:1});
    p.api.observe({active:true,paused:false,flightId:1});
    const assessment={visibility:'obstructed',source:'sampledTerrain',confidence:'approximate',controlLink:'unknown',videoLink:'unknown',sampleCount:22};
    const record={revision:2,flightId:1,expiresAtMs:105000,state:'obstructed',rays:[{state:'obstructed'}],assessment};
    p.api.set(record);
    assert.equal(p.api.assessment().visibility,'obstructed');
    assert.equal(p.api.assessment().controlLink,'unknown');
    assert.equal(Object.isFrozen(p.api.assessment()),true);
    assert.throws(()=>p.api.set({...record,revision:3,assessment:{...assessment,controlLink:'lost'}}),/Inconsistent/);
    p.clock(6000);p.api.observe({active:true,paused:false,flightId:1});
    assert.equal(p.api.assessment().visibility,'unknown');
    p.api.dispose();
});

test('explicit modelled RC/video readings are accepted independently, while terrain-only values stay unknown',()=>{
    const p=setup();p.api.monitor({enabled:true,revision:1});
    p.api.observe({active:true,paused:false,flightId:1});
    const assessment={visibility:'clear',source:'sampledTerrain',confidence:'approximate',
        controlLink:{quality:.9,source:'estimatedModel'},videoLink:{quality:.23,source:'rfModel'}};
    const command={revision:2,flightId:1,expiresAtMs:105000,state:'noSampledObstruction',
        rays:[{state:'noSampledObstruction'}],assessment};
    p.api.set(command);
    assert.equal(p.api.assessment().controlLink.quality,.9);
    assert.equal(p.api.assessment().videoLink.quality,.23);
    assert.throws(()=>p.api.set({...command,revision:3,assessment:{...assessment,controlLink:{quality:1.5,source:'rfModel'}}}),/Inconsistent/);
    assert.throws(()=>p.api.set({...command,revision:3,assessment:{...assessment,videoLink:{quality:0,source:'measured'}}}),/Inconsistent/);
    p.clock(6000);p.api.observe({active:true,paused:false,flightId:1});
    assert.equal(p.api.assessment().videoLink,'unknown');
    p.api.dispose();
});

test('automatic RF estimation exposes independent simulated links, supports CE custom profiles and never treats missing terrain as loss',()=>{
    const p=setup();p.api.monitor({enabled:true,revision:1,rfProfiles:{video:{eirpDbm:14},control:{eirpDbm:14}}});
    p.api.observe({active:true,paused:false,flightId:1});
    const assessment={visibility:'clear',source:'sampledTerrain',confidence:'approximate',controlLink:'unknown',videoLink:'unknown',
        minimumClearanceMeters:20,minimumFresnelMarginMeters:10};
    const sample={revision:2,flightId:1,expiresAtMs:105000,state:'noSampledObstruction',
        pilot:{latitude:47,longitude:8,height:1200},
        rays:[{state:'noSampledObstruction',latitude:47,longitude:8.01,height:1200,ground:1000}],assessment};
    p.api.set(sample);
    assert.equal(p.api.assessment().controlLink.source,'rfModel');
    assert.equal(p.api.assessment().videoLink.source,'rfModel');
    assert.ok(p.api.assessment().controlLink.quality>=p.api.assessment().videoLink.quality);
    p.api.setTrainingRc(0);assert.equal(p.api.assessment().controlLink.quality,0);
    assert.ok(p.api.assessment().videoLink.quality>=0);
    p.api.setTrainingRc(null);
    p.api.set({...sample,revision:3,state:'unknown',rays:[],assessment:{visibility:'unknown',source:'unavailable',confidence:'unavailable',controlLink:'unknown',videoLink:'unknown'}});
    assert.equal(p.api.assessment().controlLink,'unknown');
});

test('fast flight uses bounded faster pose updates and reports modeled speed',()=>{
    const p=setup();p.api.monitor({enabled:true,revision:1});
    const state={active:true,paused:false,flightId:1,position:{latitude:47,longitude:8},
        home:{latitude:47,longitude:8},height:1100,speed:60};
    p.api.observe(state);assert.equal(p.events.length,1);assert.equal(p.events[0].speed,60);
    p.clock(190);p.api.observe(state);assert.equal(p.events.length,1);
    p.clock(230);p.api.observe(state);assert.equal(p.events.length,2);
    p.clock(400);p.api.observe(state);assert.equal(p.events.length,2);
    p.api.dispose();
});

test('live radio details show model-derived range separately from geometry, never invented data',()=>{
    const p=setup();p.api.monitor({enabled:true,revision:1});
    p.api.observe({active:true,paused:false,flightId:10});
    const sample={revision:2,flightId:10,expiresAtMs:105000,state:'noSampledObstruction',
        pilot:{latitude:47,longitude:8,height:1100},rays:[{state:'noSampledObstruction',latitude:47,longitude:8.01,height:1200}],
        assessment:{visibility:'clear',source:'sampledTerrain',confidence:'approximate',controlLink:'unknown',videoLink:'unknown'}};
    p.api.set(sample);
    const details=p.nodes.get('flight-radio-status').textContent;
    assert.match(details,/SIM Video: .* dB reserve; free-space .* km/);
    assert.match(details,/RC: .* dB reserve; free-space .* km/);
    p.api.set({...sample,revision:3,state:'unknown',rays:[],assessment:{visibility:'unknown',source:'unavailable',confidence:'unavailable',controlLink:'unknown',videoLink:'unknown'}});
    assert.doesNotMatch(p.nodes.get('flight-radio-status').textContent,/free-space/);
    p.api.dispose();
});

test('limited extended-range terrain keeps both links unknown while displaying free-space diagnostics',()=>{
    const p=setup();p.api.monitor({enabled:true,revision:1});
    p.api.observe({active:true,paused:false,flightId:1});
    const limited={visibility:'clear',source:'sampledTerrain',confidence:'limited',controlLink:'unknown',videoLink:'unknown',
        sampleCount:160,maximumSampleGapMeters:520,samplingTier:'extendedRange'};
    p.api.set({revision:2,flightId:1,expiresAtMs:105000,state:'noSampledObstruction',
        distanceMeters:48000,
        sampling:{tier:'extendedRange',samples:160,coarseSamples:96,refinedSamples:64,queries:2,maximumGapMeters:520,limited:true},
        pilot:{latitude:47,longitude:8,height:950},
        rays:[{latitude:47.4,longitude:8,height:1200,ground:500,state:'noSampledObstruction'}],
        assessment:limited});
    assert.equal(p.api.assessment().controlLink,'unknown');
    assert.equal(p.api.assessment().videoLink,'unknown');
    assert.throws(()=>p.api.set({revision:3,flightId:1,expiresAtMs:105000,
        state:'noSampledObstruction',rays:[{state:'noSampledObstruction'}],
        assessment:{...limited,controlLink:{quality:1,source:'rfModel'}}}),/Inconsistent/);
    assert.equal(p.nodes.get('hud-live-radio').dataset.state,'unknown');
    assert.match(p.nodes.get('flight-radio-status').textContent,/LIMITED/);
    assert.match(p.nodes.get('flight-radio-status').textContent,/SIM free-space ONLY/);
    p.api.set({revision:3,state:'unknown',distanceMeters:60000,rays:[]});
    assert.equal(p.api.assessment().controlLink,'unknown');
    assert.match(p.nodes.get('flight-radio-status').textContent,/free-space ONLY/);
    p.api.dispose();
});


test('11 km sampled blockage in sparse terrain supplies visibly qualified RF estimates and opt-in RC failsafe',()=>{
    const failsafe=require('../../web/features/signal/simulated_failsafe.js');
    const p=setup();p.api.monitor({enabled:true,revision:1});
    p.api.observe({active:true,paused:false,flightId:18});
    p.api.set({revision:2,flightId:18,expiresAtMs:105000,state:'obstructed',
        distanceMeters:11389,
        sampling:{tier:'mediumRange',samples:160,coarseSamples:96,refinedSamples:64,
            queries:2,maximumGapMeters:420,limited:true},
        pilot:{latitude:47,longitude:8,height:1000},
        rays:[{latitude:47,longitude:8.15,height:1150,ground:1200,state:'obstructed'}],
        assessment:{visibility:'obstructed',source:'sampledTerrain',confidence:'limited',
            sampleCount:160,minimumClearanceMeters:-40,minimumFresnelMarginMeters:-70,
            controlLink:'unknown',videoLink:'unknown'}});
    const assessed=p.api.assessment();
    assert.equal(assessed.confidence,'limited');
    assert.equal(assessed.controlLink.source,'rfModel');
    assert.equal(assessed.videoLink.source,'rfModel');
    assert.equal(assessed.controlLink.detail,'sampledObstructionOnly');
    assert.match(p.nodes.get('flight-radio-status').textContent,/sampled obstruction/);
    assert.match(p.nodes.get('flight-radio-status').textContent,/LIMITED/);
    assert.equal(p.nodes.get('hud-live-radio').dataset.state,'obstructed');
    // An explicitly enabled model-based RC failsafe, not the geometric label,
    // may consume the quality estimate after its normal activation delay.
    const machine=failsafe.create({enabled:true,mode:'hold',activationDelaySeconds:.6});
    for(let i=0;i<9;i++)machine.step(.1,assessed);
    assert.equal(machine.status().phase,'hold');
    const off=failsafe.create({enabled:false});
    for(let i=0;i<9;i++)off.step(.1,assessed);
    assert.equal(off.status().phase,'normal');
    p.clock(6000);p.api.observe({active:true,paused:false,flightId:18});
    assert.equal(p.api.assessment().controlLink,'unknown');
});

test('renderer live RF reuses decoded highest-LOD terrain on new flight-ray coordinates and flushes it on terrain change',async()=>{
    const {create:make}=require('../../web/features/signal/live_radio.js');
    let geometryCalls=0,fallBackCalls=0;
    const P={availability:{computeMaximumLevelAtPosition:()=>15},
        tilingScheme:{positionToTileXY:()=>({x:3,y:7}),tileXYToRectangle:()=>({west:8,east:9,south:46,north:47})},
        requestTileGeometry(){geometryCalls++;return Promise.resolve({interpolateHeight:(_r,lon,lat)=>lon*5+lat});}};
    const C={Cartographic:{fromDegrees:(longitude,latitude)=>({longitude,latitude})},
        sampleTerrainMostDetailed:async(_,positions)=>{fallBackCalls++;return positions.map(p=>({...p,height:999}));}};
    const nodes=new Map();
    const api=make({C,viewer:{},terrain:{sample:fn=>fn(P)},ready:()=>true,emit:()=>{},
        layer:{clear(){},setStation(){},dispose(){}},doc:{getElementById(id){
            if(!nodes.has(id))nodes.set(id,{dataset:{},addEventListener(){}});
            return nodes.get(id);}},clock:()=>0,wallClock:()=>100000});
    const signal=new AbortController().signal;
    const a=await api.sample({positions:[{latitude:46.2,longitude:8.1},{latitude:46.4,longitude:8.3}]},signal);
    const b=await api.sample({positions:[{latitude:46.6,longitude:8.7}]},signal);
    assert.equal(geometryCalls,1);
    assert.equal(fallBackCalls,0);
    assert.deepEqual(a.heights,[86.7,87.9]);
    assert.deepEqual(b.heights,[90.1]);
    api.terrainChanged();
    await api.sample({positions:[{latitude:46.8,longitude:8.8}]},signal);
    assert.equal(geometryCalls,2,'terrain changes invalidate decoded tile geometry');
    api.dispose();
});
function deterministicTimers(){
    let now=0,id=0;const pending=new Map();
    return {clock:()=>now,setTimeout(fn,ms){const key=++id;pending.set(key,{at:now+ms,fn});return key;},
        clearTimeout(key){pending.delete(key);},advance(ms){now+=ms;
            for(;;){const next=[...pending].filter(([,v])=>v.at<=now).sort((a,b)=>a[1].at-b[1].at)[0];
                if(!next)break;pending.delete(next[0]);next[1].fn();}},get size(){return pending.size;}};
}
const flushMicrotasks=async()=>{for(let i=0;i<24;i++)await Promise.resolve();};

test('high-latency sampling completes with monotonic request diagnostics before its finite deadline',async()=>{
    const timers=deterministicTimers(),p=setup({timers,clock:timers.clock,sampleTimeoutMs:100});
    p.defer=true;const pending=p.api.sample({...command,generation:4,analysisRequestId:12},new AbortController().signal);
    assert.equal(p.api.diagnostics().active,1);timers.advance(90);await flushMicrotasks();
    assert.equal(p.api.diagnostics().active,1);
    p.resolve();const result=await pending;
    assert.deepEqual(result.heights,[1000,1000]);assert.equal(result.diagnostics.requestId,12);
    assert.equal(result.diagnostics.generation,4);assert.equal(result.diagnostics.durationMs,90);
    assert.equal(result.diagnostics.validSamples,2);assert.equal(result.diagnostics.missingSamples,0);
    assert.equal(p.api.diagnostics().latencyP50Ms,90);assert.equal(p.api.diagnostics().latencyP95Ms,90);
    assert.equal(timers.size,0);p.api.dispose();
});

test('a sampler ignoring cancellation cannot keep the timeout slot busy or overwrite fresh cache',async()=>{
    const timers=deterministicTimers(),p=setup({timers,clock:timers.clock,sampleTimeoutMs:100});
    p.defer=true;const pending=p.api.sample({...command,generation:1},new AbortController().signal),finishOld=p.resolve;
    timers.advance(100);await assert.rejects(pending,error=>error.category==='TIMEOUT');
    assert.equal(p.api.diagnostics().active,0);assert.equal(p.api.diagnostics().consecutiveFailures,1);
    p.defer=false;const recovered=await p.api.sample({...command,generation:1},new AbortController().signal);
    assert.deepEqual(recovered.heights,[1000,1000]);assert.equal(p.api.diagnostics().consecutiveFailures,0);
    p.fail=true;finishOld();await flushMicrotasks();p.fail=false;
    assert.deepEqual((await p.api.sample(command,new AbortController().signal)).heights,[1000,1000]);
    assert.equal(p.calls,2);assert.equal(timers.size,0);p.api.dispose();
});

test('analysis generation supersedes an obsolete query while identical-generation overlap stays bounded',async()=>{
    const p=setup();p.defer=true;
    const obsolete=p.api.sample({...command,generation:1,analysisRequestId:11},new AbortController().signal),finish=p.resolve;
    const rejected=assert.rejects(obsolete,error=>error.category==='SUPERSEDED');
    await assert.rejects(p.api.sample({...command,generation:1},new AbortController().signal),error=>error.category==='PENDING');
    p.defer=false;
    const fresh=await p.api.sample({...command,generation:2,analysisRequestId:13},new AbortController().signal);
    await rejected;assert.deepEqual(fresh.heights,[1000,1000]);
    finish();await flushMicrotasks();assert.equal(p.api.diagnostics().requestId,13);
    assert.equal(p.api.diagnostics().errorCategory,null);p.api.dispose();
});

test('duplicate coordinates are sampled once, missing data stays explicit and latency retention is bounded',async()=>{
    const p=setup(),signal=new AbortController().signal;
    const repeated={positions:[command.positions[0],command.positions[0],command.positions[1],command.positions[1]]};
    const result=await p.api.sample(repeated,signal);
    assert.deepEqual(result.heights,[1000,1000,1000,1000]);assert.deepEqual(p.sampleSizes,[2]);
    p.api.terrainChanged();p.fail=true;
    for(let i=0;i<140;i++)await assert.rejects(p.api.sample(command,signal),error=>error.category==='TERRAIN_UNAVAILABLE');
    assert.equal(p.api.diagnostics().consecutiveFailures,140);assert.equal(p.api.diagnostics().missingSamples,2);
    assert.equal(p.api.diagnostics().validSamples,0);assert.equal(p.api.diagnostics().latencyWindowSamples,128);
    assert.equal(p.api.diagnostics().cacheEntries,0);p.fail=false;
    await p.api.sample(command,signal);assert.equal(p.api.diagnostics().consecutiveFailures,0);p.api.dispose();
});

test('observation metadata ages from capture, stays uncertain through pending gaps, and manual training is explicit',()=>{
    const p=setup();p.api.monitor({enabled:true,revision:1});p.api.observe({active:true,paused:false,flightId:1});
    const valid={revision:2,flightId:1,expiresAtMs:104000,state:'obstructed',rays:[{state:'obstructed'}],
        observation:{quality:'valid',ageMs:1000},assessment:{visibility:'obstructed',source:'sampledTerrain',confidence:'approximate',
            controlLink:{quality:.01,source:'rfModel'},videoLink:'unknown'}};
    p.api.set(valid);const first=p.api.assessment();
    assert.equal(first.observation.ageMs,1000);assert.equal(first.observation.id,2);assert.equal(first.observation.enabled,true);
    p.clock(1000);assert.equal(p.api.assessment().observation.ageMs,2000);
    p.api.set({revision:3,state:'unknown',rays:[],observation:{quality:'pending',ageMs:2000},errorCategory:'PENDING'});
    const gap=p.api.assessment();assert.equal(gap.controlLink,'unknown');assert.equal(gap.observation.quality,'pending');
    assert.equal(gap.observation.ageMs,2000);assert.equal(gap.observation.id,2);assert.equal(gap.observation.errorCategory,'PENDING');
    p.clock(5000);assert.equal(p.api.assessment().observation.ageMs,6000);
    p.api.set({...valid,revision:4,expiresAtMs:110000,observation:{quality:'valid',ageMs:5001}});
    assert.equal(p.api.assessment().observation.quality,'stale');assert.equal(p.api.assessment().controlLink,'unknown');
    p.api.setTrainingRc(0);assert.equal(p.api.assessment().observation.manual,true);
    assert.equal(p.api.assessment().observation.quality,'valid');assert.equal(p.api.assessment().observation.ageMs,0);
    p.api.setTrainingRc(null);p.api.monitor({enabled:false,revision:5});assert.equal(p.api.assessment().observation.enabled,false);
    p.api.dispose();
});

test('invalid link input cannot freshen the last valid observation',()=>{
    const p=setup();p.api.monitor({enabled:true,revision:1});p.api.observe({active:true,paused:false,flightId:1});
    const command={revision:2,flightId:1,expiresAtMs:105000,state:'obstructed',rays:[{state:'obstructed'}],
        assessment:{visibility:'obstructed',source:'sampledTerrain',confidence:'approximate',controlLink:'unknown',videoLink:'unknown'}};
    p.api.set(command);p.clock(3000);
    assert.throws(()=>p.api.set({...command,revision:3,assessment:{...command.assessment,controlLink:{quality:9,source:'rfModel'}}}),/Inconsistent/);
    assert.equal(p.api.assessment().observation.ageMs,3000);assert.equal(p.api.assessment().observation.id,2);p.api.dispose();
});

test('late older-generation query cannot cancel a newer in-flight profile',async()=>{
    const p=setup();p.defer=true;
    const fresh=p.api.sample({...command,generation:8},new AbortController().signal);
    await assert.rejects(p.api.sample({...command,generation:7},new AbortController().signal),error=>error.category==='SUPERSEDED');
    assert.equal(p.api.diagnostics().active,1);assert.equal(p.calls,1);
    p.resolve();assert.deepEqual((await fresh).heights,[1000,1000]);p.api.dispose();
});

test('diagnostics are opt-in and retain bounded remote fields without changing live results',()=>{
    const p=setup();assert.equal(p.api.diagnosticsEnabled,false);
    p.api.setDiagnostics({enabled:true});assert.equal(p.api.diagnosticsEnabled,true);
    p.api.monitor({enabled:true,revision:1});p.api.observe({active:true,paused:false,flightId:1});
    p.api.set({revision:2,state:'unknown',rays:[],diagnostics:{movementMeters:20,latencyP50Ms:100,
        dangerousNested:{unbounded:true},badNumber:Infinity},distanceMeters:3000});
    const diagnostic=p.api.diagnostics();assert.equal(diagnostic.enabled,true);assert.equal(diagnostic.movementMeters,20);
    assert.equal(diagnostic.dangerousNested,undefined);assert.equal(diagnostic.badNumber,undefined);
    assert.equal(diagnostic.distanceMeters,3000);assert.equal(diagnostic.observationQuality,'unknown');
    p.api.setDiagnostics({enabled:false});assert.equal(p.api.diagnosticsEnabled,false);p.api.dispose();
});

test('bridge transit cannot freshen the terrain capture age',()=>{
    const p=setup();p.api.monitor({enabled:true,revision:1});p.api.observe({active:true,paused:false,flightId:1});
    p.clock(2000);
    p.api.set({revision:2,flightId:1,expiresAtMs:105000,state:'noSampledObstruction',
        rays:[{state:'noSampledObstruction'}],observation:{quality:'valid',ageMs:300}});
    assert.equal(p.api.assessment().observation.ageMs,2000,'the expired part of the original five-second budget includes transport');
    p.api.dispose();
});

test('exact-position cache rechecks finer terrain availability before reusing old heights',async()=>{
    let highest=7,requests=0;
    const provider={availability:{computeMaximumLevelAtPosition:()=>highest},
        tilingScheme:{positionToTileXY:()=>({x:0,y:0}),tileXYToRectangle:()=>({})},
        requestTileGeometry:async(_x,_y,level)=>{requests++;return {interpolateHeight:()=>level*100};}};
    const p=setup({terrain:{provider,sample:fn=>fn(provider)}}),signal=new AbortController().signal;
    assert.deepEqual((await p.api.sample(command,signal)).heights,[700,700]);assert.equal(requests,1);
    highest=8;
    assert.deepEqual((await p.api.sample(command,signal)).heights,[800,800]);assert.equal(requests,2,
        'a newly available finer mountain tile must replace memoized coordinates');p.api.dispose();
});

test('repeated insufficient clear profiles never refresh the last valid observation age or identity',()=>{
    const p=setup();p.api.monitor({enabled:true,revision:1});p.api.observe({active:true,paused:false,flightId:1});
    const clear={state:'noSampledObstruction',flightId:1,rays:[{state:'noSampledObstruction'}],
        assessment:{visibility:'clear',source:'sampledTerrain',confidence:'approximate',
            controlLink:{quality:.9,source:'rfModel'},videoLink:'unknown'}};
    p.api.set({...clear,revision:2,expiresAtMs:105000});
    const limited={...clear,assessment:{...clear.assessment,confidence:'limited',controlLink:'unknown'}};
    p.clock(1000);p.api.set({...limited,revision:3,expiresAtMs:106000,observation:{quality:'unknown',ageMs:0}});
    assert.equal(p.api.assessment().observation.quality,'unknown');
    assert.equal(p.api.assessment().observation.ageMs,1000);assert.equal(p.api.assessment().observation.id,2);
    p.clock(2000);p.api.set({...limited,revision:4,expiresAtMs:107000});
    assert.equal(p.api.assessment().observation.quality,'unknown','legacy limited-clear commands default to insufficient data');
    assert.equal(p.api.assessment().controlLink,'unknown');
    assert.equal(p.api.assessment().observation.ageMs,2000);assert.equal(p.api.assessment().observation.id,2);
    p.clock(6000);p.api.observe({active:true,paused:false,flightId:1});
    assert.equal(p.api.assessment().observation.ageMs,6000);assert.equal(p.api.assessment().observation.id,2);
    assert.equal(p.api.diagnostics().lastValidAgeMs,6000);p.api.dispose();
});
