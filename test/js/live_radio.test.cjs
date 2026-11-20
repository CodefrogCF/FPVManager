const {test}=require('node:test'),assert=require('node:assert/strict');
const {create}=require('../../web/live_radio.js');
function setup(){
    let now=0,calls=0,levels=[],resolve=null,fail=false,defer=false;const events=[],layers=[],stations=[],nodes=new Map();
    const doc={getElementById:id=>{if(!nodes.has(id))nodes.set(id,{dataset:{},listeners:{},addEventListener(k,v){this.listeners[k]=v;}});return nodes.get(id);}};
    const C={Cartographic:{fromDegrees:(longitude,latitude)=>({latitude,longitude})},sampleTerrain:async(provider,level,positions)=>{
        calls++;levels.push(level);if(defer)await new Promise(r=>resolve=r);return positions.map(p=>({...p,height:fail?NaN:1000}));
    }};
    const layer={set:c=>layers.push(c),clear:()=>layers.push(null),setStation:c=>stations.push(c),dispose:()=>layers.push('disposed')};
    const api=create({C,viewer:{},terrain:{sample:(fn)=>fn({})},ready:()=>true,emit:(type,p)=>events.push({type,...p}),doc,layer,clock:()=>now,wallClock:()=>100000+now});
    return {api,events,layers,stations,nodes,clock:n=>now=n,get calls(){return calls;},levels,get resolve(){return resolve;},set defer(v){defer=v;},set fail(v){fail=v;}};
}
const command={positions:[{latitude:46.7,longitude:8.4},{latitude:46.701,longitude:8.4}]};
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
test('fixed-level terrain samples are cached exactly, expire and are invalidated with terrain',async()=>{
    const p=setup(),signal=new AbortController().signal;
    assert.deepEqual((await p.api.sample(command,signal)).heights,[1000,1000]);assert.deepEqual(p.levels,[12]);
    await p.api.sample(command,signal);assert.equal(p.calls,1);
    p.clock(30000);await p.api.sample(command,signal);assert.equal(p.calls,2);
    p.api.terrainChanged();await p.api.sample(command,signal);assert.equal(p.calls,3);
    p.fail=true;p.api.terrainChanged();await assert.rejects(p.api.sample(command,signal),/Incomplete/);
    p.fail=false;await p.api.sample(command,signal);assert.equal(p.calls,5);
    await assert.rejects(p.api.sample({positions:Array(257).fill(command.positions[0])},signal));
    await assert.rejects(p.api.sample({positions:[{latitude:91,longitude:0}]},signal));
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
    const failsafe=require('../../web/simulated_failsafe.js');
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
