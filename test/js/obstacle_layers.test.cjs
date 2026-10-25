const test = require('node:test');
const assert = require('node:assert/strict');
const {WMS,createWms,createVectors,createHazards} = require('../../web/obstacle_layers.js');
const {Request,RequestState} = require('../../web/cesium/index.cjs');

function setup({image = () => Promise.resolve({}), yieldBatch,
    terrainReady = () => true, groundHeight = () => undefined} = {}) {
    const layers = [],sources = [],events = [],providers = [];
    let clock = 0, heightCalls = 0;
    const event = () => {const listeners = new Set(); return {
        addEventListener(fn){listeners.add(fn);return ()=>listeners.delete(fn);},
        fire(){for(const fn of listeners)fn();},get size(){return listeners.size;}
    };};
    const preRender=event(),tiles=event(),camera=event();
    let entityId = 0;
    const C = {
        RequestState,
        WebMercatorTilingScheme:class { positionToTileXY() { return {x:133,y:90}; } },
        WebMapServiceImageryProvider:class { constructor(options) {
            Object.assign(this,options); providers.push(this);
            this.errorEvent = {addEventListener:fn => {this.onError=fn; return () => {this.onError=null;};}};
        } requestImage(...args) { return image(...args); } },
        ImageryLayer:class {constructor(provider,options) {Object.assign(this,options);this.imageryProvider=provider;}},
        Credit:class {constructor(html,onScreen) {Object.assign(this,{html,onScreen});}},
        Rectangle:{fromDegrees:(...bounds) => bounds},Cartographic:{fromDegrees:(lon,lat) => ({lon,lat})},
        CustomDataSource:class {constructor(name) {this.name=name;const values=[];
            this.entities={values,add:options => {const entity={id:`e${++entityId}`,...options};values.push(entity);return entity;}};}},
        Cartesian3:{fromDegrees:(lon,lat,height) => [lon,lat,height]},
        CallbackProperty:class {constructor(callback,isConstant) {
            this.getValue=callback;this.isConstant=isConstant;
        }},
        Color:{fromCssColorString:s => s,BLACK:'black'},HeightReference:{NONE:'none',CLAMP_TO_GROUND:'ground'},ArcType:{NONE:'straight'}
    };
    const viewer = {imageryLayers:{add:l => layers.push(l),remove:l => {const i=layers.indexOf(l);if(i>=0)layers.splice(i,1);}},
        dataSources:{add:async s => sources.push(s),remove:s => {const i=sources.indexOf(s);if(i>=0)sources.splice(i,1);}},
        camera:{changed:camera,moveEnd:event()},
        scene:{preRender,globe:{tileLoadProgressEvent:tiles,getHeight:p=>{heightCalls++;return groundHeight(p);}},requestRender() {}}};
    const wms = createWms(C,viewer,(type,payload) => events.push({type,...payload}),{timeoutMs:20});
    const vectors = createVectors(C,viewer,{yieldBatch,isTerrainReady:terrainReady,now:()=>clock});
    return {C,viewer,layers,sources,events,providers,wms,vectors,preRender,tiles,camera,
        get heightCalls(){return heightCalls;},frame(ms=16){clock+=ms;preRender.fire();},
        refine(){tiles.fire();clock+=201;preRender.fire();}};
}
const tick = () => new Promise(r => setImmediate(r));
const line = {id:'source-id',category:'powerLines',parts:[{kind:'LineString',elevated:true,
    coordinates:[[8,46,550],[8.01,46.01,560]]}]};

test('WMS uses capabilities-verified transparent EPSG:3857 parameters and separate imagery layer',async () => {
    const p=setup(); const base={base:true};p.layers.push(base);
    p.wms.set({visible:true,opacity:.65}); await tick();
    assert.equal(p.wms.status().state,'ready'); assert.equal(p.layers.length,2);
    const provider=p.providers[0];assert.equal(provider.url,WMS.url);assert.equal(provider.layers,WMS.layer);
    assert.equal(provider.crs,'EPSG:3857');assert.equal(provider.parameters.version,'1.3.0');
    assert.equal(provider.parameters.transparent,true);assert.equal(provider.parameters.styles,'default');
    assert.deepEqual(provider.rectangle,WMS.bounds);assert.equal(provider.enablePickFeatures,false);
    assert.ok(provider.credit.html.includes('BAZL'));assert.equal(provider.credit.onScreen,true);
    // Changing the base layer leaves the obstacle layer present and unchanged.
    p.viewer.imageryLayers.remove(base);p.viewer.imageryLayers.add({base:'topographic'});
    p.wms.set({visible:true,opacity:.2});assert.equal(p.providers.length,1);assert.equal(p.layers[0].alpha,.2);
    p.wms.set({visible:false,opacity:.2});assert.equal(p.layers.length,1);assert.equal(p.wms.status().state,'off');
    p.wms.dispose();
});
test('tile/network failure remains local and explicit retry recovers',async () => {
    let fail=true; const p=setup({image:() => fail ? Promise.reject(new Error('offline')) : Promise.resolve({})});
    p.wms.set({visible:true,opacity:1});await tick();
    assert.equal(p.wms.status().state,'failed');assert.equal(p.layers.length,1);
    assert.equal(p.events.every(e => e.type==='obstacle-wms-status'),true);
    fail=false;p.wms.set({visible:true,opacity:.7,retry:true});await tick();
    assert.equal(p.wms.status().state,'ready');assert.equal(p.layers.length,1);p.wms.dispose();
});
test('tile timeout, disabling and disposal invalidate late completions',async () => {
    let resolve;const p=setup({image:() => new Promise(r => resolve=r)});
    p.wms.set({visible:true,opacity:1});await new Promise(r => setTimeout(r,35));
    assert.equal(p.wms.status().state,'failed');resolve({});await tick();
    assert.equal(p.wms.status().state,'failed');
    p.wms.set({visible:true,opacity:1,retry:true});p.wms.set({visible:false,opacity:1});resolve({});await tick();
    assert.equal(p.wms.status().state,'off');assert.equal(p.layers.length,0);
    p.wms.set({visible:true,opacity:1});p.wms.dispose();const count=p.events.length;resolve({});await tick();
    assert.equal(p.layers.length,0);assert.equal(p.events.length,count);
});
test('renderer recreation accepts requested WMS state without accumulating layers',async () => {
    const old=setup();old.wms.set({visible:true,opacity:.4});old.wms.dispose();
    const next=setup();next.wms.set({visible:true,opacity:.4});await tick();
    assert.equal(old.layers.length,0);assert.equal(next.layers.length,1);assert.equal(next.layers[0].alpha,.4);next.wms.dispose();
});
test('camera-cancelled tile requests do not mark healthy WMS imagery unavailable',async () => {
    let stall=false;
    const p=setup({image:() => stall ? new Promise(() => {}) : Promise.resolve({})});
    p.wms.set({visible:true,opacity:.8});await tick();stall=true;
    const request={cancelled:true};
    await assert.rejects(p.providers[0].requestImage(1,2,3,request),/timeout/);
    assert.equal(p.wms.status().state,'ready');assert.equal(p.layers.length,1);p.wms.dispose();
});

test('scheduler cancellation without the explicit cancelled flag retains the same WMS layer',async () => {
    let rejectTile=false;
    const p=setup({image:()=>rejectTile ? Promise.reject(new Error('Request cancelled')) : Promise.resolve({})});
    p.wms.set({visible:true,opacity:.8});await tick();
    const layer=p.layers[0],request=new Request();
    // Cesium's scheduler also cancels requests directly by changing state.
    request.state=RequestState.CANCELLED;
    assert.equal(request.cancelled,false);
    rejectTile=true;
    await assert.rejects(p.providers[0].requestImage(1,2,3,request));
    assert.equal(p.wms.status().state,'ready');
    assert.equal(p.layers[0],layer);assert.equal(p.providers.length,1);
    p.wms.dispose();
});

test('scheduler backpressure defers tiles without failing or replacing the layer',async () => {
    let throttled=true;
    const p=setup({image:()=>throttled ? undefined : Promise.resolve({})});
    p.wms.set({visible:true,opacity:.8});await tick();
    const layer=p.layers[0],provider=p.providers[0];
    assert.equal(p.wms.status().state,'loading');
    assert.equal(provider.requestImage(1,2,3,new Request()),undefined);
    throttled=false;await provider.requestImage(1,2,3,new Request());
    assert.equal(p.wms.status().state,'ready');assert.equal(p.layers[0],layer);
    p.wms.dispose();
});

test('individual failed tiles retain loaded imagery, retry at most twice and recover in place',async () => {
    let fail=false;
    const p=setup({image:(x)=>fail && x===1 ? Promise.reject(new Error('temporary failure')) : Promise.resolve({})});
    p.wms.set({visible:true,opacity:.8});await tick();
    const provider=p.providers[0],layer=p.layers[0],request=new Request();
    let cancelled=0;request.cancel=()=>cancelled++;
    fail=true;
    await assert.rejects(provider.requestImage(1,2,3,request));
    assert.equal(p.layers[0],layer);assert.equal(p.wms.status().state,'failed');
    assert.equal(cancelled,0,'A network failure must not become an automatically rescheduled cancellation');
    await provider.requestImage(2,2,3,new Request());
    assert.equal(p.wms.status().state,'failed','A different successful tile must not conceal a missing tile');
    for(const retry of [true,true,false]){
        const error={x:1,y:2,level:3};provider.onError(error);assert.equal(error.retry,retry);
    }
    fail=false;await provider.requestImage(1,2,3,new Request());
    assert.equal(p.wms.status().state,'ready');assert.equal(p.wms.status().error,null);
    assert.equal(p.layers[0],layer);assert.equal(p.providers.length,1);
    p.wms.dispose();
});

test('tile timeout aborts its transport while retaining imagery and bounded retry semantics',async () => {
    let stall=false;
    const p=setup({image:()=>stall ? new Promise(()=>{}) : Promise.resolve({})});
    p.wms.set({visible:true,opacity:.8});await tick();
    const layer=p.layers[0],request=new Request();let aborted=0;
    request.cancelFunction=()=>aborted++;
    stall=true;
    await assert.rejects(p.providers[0].requestImage(1,2,3,request),/timeout/);
    assert.equal(aborted,1);assert.equal(request.cancelled,false);
    assert.equal(p.wms.status().state,'failed');assert.equal(p.layers[0],layer);
    p.wms.set({visible:false,opacity:.8});assert.equal(p.layers.length,0);
    assert.equal(p.wms.status().state,'off');p.wms.dispose();
});
test('vector geometry retains actual converted heights; unknown heights remain ground-projected',async () => {
    const p=setup();
    await p.vectors.replace({revision:1,features:[line,{id:'unknown',category:'unknown',parts:[{
        kind:'LineString',elevated:false,coordinates:[[8.4,46.7,null],[8.5,46.8,null]]}]}]});
    assert.equal(p.sources.length,1);
    const [cable,unknown]=p.sources[0].entities.values;
    assert.deepEqual(cable.polyline.positions,[[8,46,550],[8.01,46.01,560]]);
    assert.equal(cable.polyline.clampToGround,false);assert.equal(cable.polyline.arcType,'straight');
    assert.equal(unknown.point.heightReference,'ground');assert.equal(unknown.position[2],0);
    assert.deepEqual(p.vectors.pick(cable),{id:'source-id',revision:1});
    await p.vectors.replace({revision:2,features:[]});assert.equal(p.vectors.pick(cable),undefined);p.vectors.dispose();assert.equal(p.sources.length,0);
});
test('invalid replacement, obsolete revisions and cancellation preserve the committed dataset',async () => {
    const p=setup();await p.vectors.replace({revision:1,features:[line]});const first=p.sources[0];
    await assert.rejects(p.vectors.replace({revision:2,features:[{...line,parts:[{kind:'LineString',elevated:true,coordinates:[[8,46,null],[8,46,600]]}]}]}));
    assert.equal(p.sources[0],first);
    await p.vectors.replace({revision:0,features:[]});assert.equal(p.sources[0],first);
    const abort=new AbortController();abort.abort();await p.vectors.replace({revision:3,features:[]},abort.signal);
    assert.equal(p.sources.length,1);assert.equal(p.sources[0],first);p.vectors.dispose();
});
test('bounded batches can be superseded and disposed without leaking staging entities',async () => {
    let release;const p=setup({yieldBatch:() => new Promise(r => release=r)});
    await p.vectors.replace({revision:1,features:[line]});
    const batch=Array.from({length:81},(_,i) => ({...line,id:`feature-${i}`}));
    const pending=p.vectors.replace({revision:2,features:batch});await tick();
    await p.vectors.replace({revision:3,features:[{...line,id:'new'}]});release();await pending;
    assert.equal(p.sources.length,1);assert.equal(p.vectors.pick(p.sources[0].entities.values[0]).id,'new');
    const pending2=p.vectors.replace({revision:4,features:batch});await tick();p.vectors.dispose();release();await pending2;
    assert.equal(p.sources.length,0);
    await assert.rejects(setup().vectors.replace({revision:1,features:Array(1201).fill(line)}));
});

// For point obstacles the Skyguide/BAZL schema applies maxHeightAGL at
// the same horizontal coordinate. Both endpoints MUST derive from the same
// terrain sample or a 50-m mast will not be rendered as 50 metres tall.
test('isolated Point: a 50 m crane is EXACTLY 50 m above the rendered terrain, not the unrelated AMSL top',async () => {
    let ground=529.25, ready=true;
    const p=setup({groundHeight:position => {
        assert.deepEqual(position,{lon:8.1,lat:46.2});
        return ground;
    },terrainReady:() => ready});
    await p.vectors.replace({revision:1,features:[
        {id:'crane',category:'masts',parts:[{kind:'Point',elevated:true,
            coordinates:[[8.1,46.2,690.5]],heightAgl:50}]},
        line
    ]});
    const [point,stem,cable]=p.sources[0].entities.values;
    assert.equal(point.position instanceof p.C.CallbackProperty,false);
    assert.equal(stem.polyline.positions instanceof p.C.CallbackProperty,false);
    assert.equal(point.show,true);
    assert.deepEqual(point.position,[8.1,46.2,579.25]);
    assert.equal(stem.polyline.show,true);
    assert.deepEqual(stem.polyline.positions,[[8.1,46.2,529.25],[8.1,46.2,579.25]]);
    assert.equal(stem.polyline.positions[1][2]-stem.polyline.positions[0][2],50);
    assert.equal(point.point.heightReference,'none');
    // Terrain LOD/refinement adjusts BOTH endpoints by the same delta.
    ground=531.75;
    p.refine();
    assert.deepEqual(point.position,[8.1,46.2,581.75]);
    assert.deepEqual(stem.polyline.positions,[[8.1,46.2,531.75],[8.1,46.2,581.75]]);
    assert.equal(stem.polyline.positions[1][2]-stem.polyline.positions[0][2],50);
    // Source geometry for elevated cables is untouched.
    assert.deepEqual(cable.polyline.positions,[[8,46,550],[8.01,46.01,560]]);
    assert.equal(cable.polyline.clampToGround,false);
    assert.deepEqual(p.vectors.pick(stem),{id:'crane',revision:1});
    assert.deepEqual(p.vectors.pick(point),{id:'crane',revision:1});
    ready=false;
    p.vectors.terrainChanged();
    assert.equal(point.show,false);
    assert.equal(stem.polyline.show,false);
    ready=true;
    for (const invalidHeight of [undefined,NaN,Infinity,-2000]) {
        ground=invalidHeight;
        p.refine();
        assert.equal(point.show,false);
        assert.equal(stem.polyline.show,false);
    }
    ground=530;
    p.refine();
    assert.equal(point.show,true);
    assert.deepEqual(point.position,[8.1,46.2,580]);
    assert.deepEqual(stem.polyline.positions,[[8.1,46.2,530],[8.1,46.2,580]]);
    p.vectors.dispose();
});

test('point without trusted AGL retains source absolute top without a fabricated stem',async () => {
    const p=setup({groundHeight:()=>532});
    await p.vectors.replace({revision:1,features:[{id:'unknown-agl',category:'other',parts:[
        {kind:'Point',elevated:true,coordinates:[[8.1,46.2,740]]}]}]});
    const [point]=p.sources[0].entities.values;
    assert.deepEqual(point.position,[8.1,46.2,740]);
    assert.equal(p.sources[0].entities.values.length,1);
    p.vectors.dispose();
});

test('extra KML label Point on line is not a free-floating obstacle marker',async () => {
    const p=setup();
    await p.vectors.replace({revision:2,features:[{id:'cable-and-label',category:'cableways',parts:[
        {kind:'LineString',elevated:true,coordinates:[[8.1,46.2,600],[8.2,46.3,610]]},
        {kind:'Point',elevated:true,coordinates:[[8.1,46.2,790]]}]}]});
    const [cable]=p.sources[0].entities.values;
    assert.equal(p.sources[0].entities.values.length,1);
    assert.deepEqual(cable.polyline.positions,[[8.1,46.2,600],[8.2,46.3,610]]);
    assert.deepEqual(p.vectors.pick(cable),{id:'cable-and-label',revision:2});
    p.vectors.dispose();
});

test('untrusted AGL cannot be sent to nonpoint parts or as NaN, negative, or huge',async () => {
    for (const part of [
        {kind:'LineString',elevated:true,coordinates:[[8,46,500],[8.1,46,510]],heightAgl:50},
        ...[NaN,Infinity,-1,0,2000].map(heightAgl =>
            ({kind:'Point',elevated:true,coordinates:[[8,46,500]],heightAgl}))
    ]) {
        const p=setup();
        await assert.rejects(p.vectors.replace({revision:1,features:[
            {id:'malformed',category:'masts',parts:[part]}]}),/Invalid obstacle AGL/);
    }
});

test('isolated point with AGL remains accurately drawable even if the absolute datum is unavailable',async () => {
    const p=setup({groundHeight:()=>402.5});
    await p.vectors.replace({revision:1,features:[{id:'height-only',category:'masts',parts:[
        {kind:'Point',elevated:false,coordinates:[[8,46,null]],heightAgl:50}]}]});
    const [point,stem]=p.sources[0].entities.values;
    assert.deepEqual(point.position,[8,46,452.5]);
    assert.deepEqual(stem.polyline.positions,[[8,46,402.5],[8,46,452.5]]);
    assert.equal(p.sources[0].entities.values.length,2);
    p.vectors.dispose();
});

test('cable attachment vertices follow the same terrain and AGL as published mast tops', async () => {
    let ground=600;
    const p=setup({groundHeight:()=>ground});
    const mast=(id,lon,lat,top,agl,supportOnly=false)=>({id,category:'masts',supportOnly,
        parts:[{kind:'Point',elevated:true,coordinates:[[lon,lat,top]],heightAgl:agl}]});
    const cable={id:'cable',category:'powerLines',parts:[{kind:'LineString',elevated:true,
        coordinates:[[8.1,46.2,740],[8.15,46.25,750],[8.2,46.3,760]]}]};
    await p.vectors.replace({revision:1,features:[cable,mast('a',8.1,46.2,740,50),mast('b',8.2,46.3,760,70)]});
    const [line,marker]=p.sources[0].entities.values;
    let positions=line.polyline.positions;
    assert.equal(positions[0][2],marker.position[2]);
    assert.equal(positions[0][2],650);assert.equal(positions[1][2],660);assert.equal(positions[2][2],670);
    ground=620;p.refine();positions=line.polyline.positions;
    assert.equal(positions[0][2],670);assert.equal(marker.position[2],670);
    assert.equal(positions[2][2],690);
    ground=undefined;p.refine();assert.equal(line.polyline.show,false);
    assert.equal(marker.show,false);
    assert.deepEqual(p.vectors.pick(line),{id:'cable',revision:1});
    // Support-only records keep the line anchored when mast markers are hidden.
    ground=600;
    await p.vectors.replace({revision:2,features:[cable,mast('a',8.1,46.2,740,50,true),mast('b',8.2,46.3,760,70,true)]});
    assert.equal(p.sources[0].entities.values.length,1);
    assert.equal(p.sources[0].entities.values[0].polyline.positions[0][2],650);
    p.vectors.dispose();
});

test('unrelated or ambiguous masts cannot replace cable source heights',async()=>{
    const p=setup({groundHeight:()=>600});
    const mast={id:'mast',category:'masts',parts:[{kind:'Point',elevated:true,coordinates:[[8,46,900]],heightAgl:50}]};
    await p.vectors.replace({revision:1,features:[line,mast]});
    assert.deepEqual(p.sources[0].entities.values[0].polyline.positions,line.parts[0].coordinates);
    const matching={...mast,parts:[{...mast.parts[0],coordinates:[[8,46,550]]}]};
    await p.vectors.replace({revision:2,features:[line,matching,{...matching,id:'another'}]});
    assert.deepEqual(p.sources[0].entities.values[0].polyline.positions,line.parts[0].coordinates);
    p.vectors.dispose();
});

function hazards(options={}) {
    const p=setup();
    const C={...p.C,CornerType:{ROUNDED:'rounded'},Color:{fromCssColorString:color=>({withAlpha:alpha=>({color,alpha})})}};
    return {...p,hazards:createHazards(C,p.viewer,options)};
}

test('advisory radial areas and metric corridors remain independently selectable',async()=>{
    const p=hazards();
    const point={id:'p',category:'masts',parts:[{kind:'Point',coordinates:[[8,46,null]]}]};
    await p.vectors.replace({revision:1,features:[line]});
    await p.hazards.replace({revision:1,bufferMeters:30,features:[line,point]});
    assert.equal(p.sources.length,2);
    const [corridor,radial]=p.sources[1].entities.values;
    assert.equal(corridor.corridor.width,60);assert.equal(corridor.corridor.cornerType,'rounded');
    assert.equal(radial.ellipse.semiMajorAxis,30);assert.equal(radial.ellipse.heightReference,'ground');
    assert.equal(radial.ellipse.material.alpha,.22);
    assert.deepEqual(p.hazards.pick(corridor),{id:'source-id',revision:1,layer:'hazard'});
    await p.hazards.replace({revision:2,bufferMeters:0,features:[line,point]});
    assert.equal(p.sources[1].entities.values.length,0);assert.equal(p.sources[0].entities.values.length,1);
    assert.equal(p.hazards.pick(corridor),undefined);
    p.hazards.dispose();p.vectors.dispose();assert.equal(p.sources.length,0);
});

test('advisory areas reject invalid buffers and discard obsolete batches',async()=>{
    let release;
    const p=hazards({yieldBatch:()=>new Promise(r=>release=r)});
    for(const bufferMeters of [-1,NaN,Infinity,1001])await assert.rejects(p.hazards.replace({revision:1,bufferMeters,features:[]}));
    await p.hazards.replace({revision:1,bufferMeters:10,features:[line]});
    const pending=p.hazards.replace({revision:2,bufferMeters:20,features:Array.from({length:81},(_,i)=>({...line,id:`f${i}`}))});
    await tick();await p.hazards.replace({revision:3,bufferMeters:40,features:[line]});release();await pending;
    assert.equal(p.sources.length,1);assert.equal(p.sources[0].entities.values[0].corridor.width,80);
    const aborted=new AbortController();aborted.abort();
    await p.hazards.replace({revision:4,bufferMeters:20,features:[]},aborted.signal);
    assert.equal(p.sources.length,1);p.hazards.dispose();assert.equal(p.sources.length,0);
});

test('isolated TRANSMISSION_LINE support points also anchor published cable geometry',async()=>{
    const p=setup({groundHeight:()=>600});
    const support={id:'published-support',category:'powerLines',parts:[{
        kind:'Point',elevated:true,coordinates:[[8,46,550]],heightAgl:35}]};
    await p.vectors.replace({revision:1,features:[line,support]});
    const [cable,marker]=p.sources[0].entities.values;
    assert.equal(cable.polyline.positions[0][2],635);
    assert.equal(cable.polyline.positions[0][2],marker.position[2]);
    p.vectors.dispose();
});

test('100 cables share two terrain samples; stable frames never resample or replace geometry',async()=>{
    const p=setup({groundHeight:()=>600});
    const supports=[8,8.01].map((lon,i)=>({id:'support-'+i,category:'masts',parts:[{
        kind:'Point',elevated:true,coordinates:[[lon,46+i*.01,550+i*10]],heightAgl:50}]}));
    await p.vectors.replace({revision:1,features:[...Array.from({length:100},(_,i)=>({...line,id:'cable-'+i})),...supports]});
    assert.equal(p.heightCalls,2);
    const cable=p.sources[0].entities.values[0],positions=cable.polyline.positions;
    for(let i=0;i<600;i++)p.frame();
    assert.equal(p.heightCalls,2);assert.equal(cable.polyline.positions,positions);
    p.refine();assert.equal(p.heightCalls,4);assert.equal(cable.polyline.positions,positions,'Identical refined heights do not recreate static geometry');
    p.vectors.dispose();assert.equal(p.preRender.size,0);assert.equal(p.tiles.size,0);assert.equal(p.camera.size,0);
    p.refine();assert.equal(p.heightCalls,4);
});

test('terrain refinement is sampled in bounded batches and publishes one consistent height snapshot',async()=>{
    let ground=600;
    const p=setup({groundHeight:()=>ground});
    await p.vectors.replace({revision:1,features:Array.from({length:130},(_,i)=>({id:'mast-'+i,category:'masts',parts:[{
        kind:'Point',elevated:true,coordinates:[[8+i*.001,46,700]],heightAgl:50}]}))});
    const first=p.sources[0].entities.values[0];assert.equal(first.position[2],650);assert.equal(p.heightCalls,130);
    ground=620;p.refine();assert.equal(p.heightCalls,258);assert.equal(first.position[2],650);
    p.frame();assert.equal(p.heightCalls,260);assert.equal(first.position[2],670);
    p.vectors.dispose();
});
