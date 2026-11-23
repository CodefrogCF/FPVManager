const test=require('node:test');
const assert=require('node:assert/strict');
const signal=require('../../web/features/flight/hud/signal_hud.js');
const flight=require('../../web/features/flight/free_flight.js');
const {create:makeHud}=require('../../web/features/flight/hud/flight_hud.js');
const defaultState={hudStyle:'goggles',flightId:1,mode:'angle',position:{latitude:46.8,longitude:8.3},
    signalHud:{djiWarning:true,betaflightBars:true,analogNoise:true,terrainIllustration:true,
        weakThreshold:.55,criticalThreshold:.25,lostThreshold:.08,analogIntensity:.8}};
function nodes(){
    const map=new Map(),doc={getElementById(id){
        if(!map.has(id))map.set(id,{style:{},dataset:{},hidden:true,textContent:'',
            setAttribute(k,v){this[k]=v;}});
        return map.get(id);
    }};
    return {map,doc,get:id=>doc.getElementById(id)};
}
const geometry=visibility=>({visibility,source:'sampledTerrain',confidence:'approximate',controlLink:'unknown',videoLink:'unknown'});
const explicit=(quality,source='estimatedModel')=>({visibility:'unknown',source:'unavailable',confidence:'unavailable',
    controlLink:{quality:.9,source},videoLink:{quality,source}});

test('preferences validate ordered thresholds and retain defaults',()=>{
    assert.equal(signal.settings({}).analogIntensity,.65);
    assert.throws(()=>signal.settings({analogIntensity:1.1}),/Invalid/);
    assert.throws(()=>signal.settings({terrainIllustration:'yes'}),/Invalid/);
    assert.throws(()=>signal.settings({criticalThreshold:.7,weakThreshold:.5}),/ordered/);
    assert.throws(()=>flight.parameters({signalHud:{weakThreshold:.1,criticalThreshold:.2}}),/ordered/);
    assert.equal(flight.parameters({}).signalHud.terrainIllustration,false);
});

test('geometric visibility never produces RC quality or a loss event',()=>{
    for(const state of ['clear','fresnelIntrusion','obstructed','unknown']){
        const output=signal.evaluate(geometry(state),defaultState.signalHud);
        assert.equal(output.rc,null);
        assert.equal(output.rcBars,null);
        if(state==='unknown')assert.equal(output.video,null);
        else assert.equal(output.video.source,'terrainIllustration');
    }
    assert.equal(signal.evaluate(geometry('obstructed'),{...defaultState.signalHud,terrainIllustration:false}).video,null);
    const missing=signal.evaluate({source:'sampledTerrain',visibility:'obstructed',confidence:'unavailable'},defaultState.signalHud);
    assert.equal(missing.video,null);
});

test('modelled RC and video links stay independent and thresholds classify correctly',()=>{
    const opts=defaultState.signalHud;
    assert.equal(signal.evaluate(explicit(.7),opts).warning,null);
    assert.equal(signal.evaluate(explicit(.5),opts).warning,'weak');
    assert.equal(signal.evaluate(explicit(.2),opts).warning,'critical');
    assert.equal(signal.evaluate(explicit(.04),opts).warning,'lost');
    assert.equal(signal.evaluate(explicit(.54),opts,'weak').videoLevel,'weak');
    assert.equal(signal.evaluate(explicit(.57),opts,'weak').videoLevel,'weak');
    assert.equal(signal.evaluate(explicit(.6),opts,'weak').videoLevel,'good');
    assert.equal(signal.evaluate(explicit(.5),opts).rcBars,5);
    assert.equal(signal.evaluate(explicit(.5),opts).videoBars,3);
    assert.equal(signal.modeled({quality:1,source:'measured'}),null);
    assert.equal(signal.modeled({quality:NaN,source:'rfModel'}),null);
    assert.equal(signal.evaluate(explicit(.5),opts).video.source,'estimatedModel');
});

test('DJI bottom edge is optional and changes orange/red by severity',()=>{
    const n=nodes(),view=signal.create(n.doc,{now:()=>0});
    view.update(defaultState,geometry('clear'));
    assert.equal(n.get('hud-signal-edge').hidden,true);
    view.update(defaultState,geometry('fresnelIntrusion'));
    // Constant clock leaves the smoothed sample unchanged until time advances.
    const simulated=signal.create(n.doc,{now:(()=>{let now=0;return ()=>now+=3000;})()});
    simulated.update(defaultState,geometry('fresnelIntrusion'));
    assert.equal(n.get('hud-signal-edge').hidden,false);
    assert.equal(n.get('hud-signal-edge').dataset.level,'weak');
    simulated.update(defaultState,geometry('obstructed'));
    assert.equal(n.get('hud-signal-edge').dataset.level,'critical');
    simulated.update({...defaultState,signalHud:{...defaultState.signalHud,djiWarning:false}},geometry('obstructed'));
    assert.equal(n.get('hud-signal-edge').hidden,true);
});

test('Betaflight bars and analog interference are independently optional',()=>{
    const n=nodes(),clock=(()=>{let stamp=0;return ()=>stamp+=1000;})();
    const view=signal.create(n.doc,{now:clock}),s={...defaultState,hudStyle:'betaflight'};
    view.update(s,geometry('clear'));
    assert.equal(n.get('hud-signal-bars').hidden,false);
    assert.equal(n.get('hud-signal-video').dataset.bars,'5');
    assert.equal(n.get('hud-signal-rc').dataset.known,'false');
    assert.equal(n.get('hud-analog-noise').hidden,false);
    const before=Number(n.get('hud-analog-noise').style.opacity);
    for(let i=0;i<5;i++)view.update(s,geometry('obstructed'));
    assert.ok(Number(n.get('hud-analog-noise').style.opacity)>before);
    assert.equal(n.get('hud-signal-video').dataset.source,'terrainIllustration');
    view.update({...s,signalHud:{...s.signalHud,analogNoise:false}},geometry('obstructed'));
    assert.equal(n.get('hud-analog-noise').hidden,true);
    assert.equal(n.get('hud-signal-bars').hidden,false);
    view.update({...s,signalHud:{...s.signalHud,betaflightBars:false}},geometry('obstructed'));
    assert.equal(n.get('hud-signal-bars').hidden,true);
});

test('analog noise bridges subsecond RF gaps but RF indicators remain unknown',()=>{
    let stamp=1000;
    const n=nodes(),view=signal.create(n.doc,{now:()=>stamp}),state={...defaultState,hudStyle:'betaflight'};
    view.update(state,geometry('obstructed'));
    stamp+=100;view.update(state,geometry('obstructed')); // First frame may intentionally simulate a dropout.
    const initial=Number(n.get('hud-analog-noise').style.opacity);
    stamp+=500;view.update(state,geometry('unknown'));
    assert.equal(n.get('hud-analog-noise').hidden,false);
    assert.equal(n.get('hud-analog-noise').dataset.holdover,'true');
    assert.ok(Number(n.get('hud-analog-noise').style.opacity)>=initial);
    assert.equal(n.get('hud-signal-video').dataset.known,'false','visual holdover is NOT an RF estimate');
    assert.equal(n.get('hud-signal-rc').dataset.known,'false');
    stamp+=350;view.update(state,geometry('unknown'));
    assert.equal(n.get('hud-analog-noise').hidden,false);
    stamp+=100;view.update(state,geometry('obstructed'));
    assert.equal(n.get('hud-analog-noise').hidden,false,'returning telemetry is continuous');
    assert.equal(n.get('hud-analog-noise').dataset.holdover,'false');
    stamp+=1300;view.update(state,geometry('unknown'));
    assert.equal(n.get('hud-analog-noise').hidden,true,'no indefinitely stale interference');
    view.update(defaultState,geometry('unknown'));
    assert.equal(n.get('hud-signal-edge').hidden,true,'unknown is not a video warning');
});

test('analog holdover resets between flights and never starts without an RF estimate',()=>{
    let stamp=0;const n=nodes(),view=signal.create(n.doc,{now:()=>stamp});
    const state={...defaultState,hudStyle:'betaflight'};
    view.update(state,geometry('unknown'));assert.equal(n.get('hud-analog-noise').hidden,true);
    view.update(state,geometry('fresnelIntrusion'));
    stamp+=300;view.update(state,geometry('unknown'));assert.equal(n.get('hud-analog-noise').hidden,false);
    view.reset();view.update(state,geometry('unknown'));
    assert.equal(n.get('hud-analog-noise').hidden,true);
});

test('flight HUD resets smoothing when the flight id changes',()=>{
    const n=nodes(),hud=makeHud(n.doc),state={...defaultState,verticalSpeed:0};
    hud.update(state,0,geometry('obstructed'));
    assert.equal(n.get('hud-signal-edge').dataset.level,'critical');
    hud.update({...state,flightId:2},0,geometry('clear'));
    assert.equal(n.get('hud-signal-edge').hidden,true);
    hud.update({...state,hudStyle:'betaflight',flightId:2},0,geometry('obstructed'));
    assert.equal(n.get('hud-signal-bars').hidden,false);
});

test('critical video quality produces stronger analog interference without changing RC state',()=>{
    const cfg={...defaultState.signalHud,analogNoise:true,analogIntensity:1};
    const quality=(v)=>signal.evaluate(explicit(v),cfg);
    assert.ok(quality(.98).noise<quality(.45).noise);
    assert.ok(quality(.45).noise<quality(.12).noise);
    assert.ok(quality(.12).noise<quality(.01).noise);
    assert.equal(quality(.01).rc.quality,.9);
});


test('DJI-style lower warning edge is independently available in Betaflight OSD',()=>{
    const n=nodes(),view=signal.create(n.doc,{now:()=>Date.now()});
    const osd={...defaultState,hudStyle:'betaflight',signalHud:{...defaultState.signalHud,terrainIllustration:false}};
    view.update(osd,explicit(.15));
    assert.equal(n.get('hud-signal-edge').hidden,false,'weak/lost video has a lower edge even in Betaflight');
    assert.equal(n.get('hud-signal-edge').dataset.level,'critical');
    assert.equal(n.get('hud-signal-bars').hidden,false,'independent RC/video OSD meters remain available');
    view.update({...osd,signalHud:{...osd.signalHud,betaflightBars:false}},explicit(.15));
    assert.equal(n.get('hud-signal-edge').hidden,false,'disabling OSD bars must not disable the lower warning');
    view.update({...osd,signalHud:{...osd.signalHud,djiWarning:false}},explicit(.15));
    assert.equal(n.get('hud-signal-edge').hidden,true);
    view.update(osd,geometry('obstructed'));
    assert.equal(n.get('hud-signal-edge').hidden,true,
        'terrain-only obstruction must not fabricate a video-quality warning');
    const css=require('node:fs').readFileSync(require('node:path').join(__dirname,'../../web/features/flight/hud/flight_hud.css'),'utf8');
    assert.match(css,/#hud-signal-edge\s*\{[^}]*z-index:2/,
        'bottom warning must render above analog interference overlay');
});
