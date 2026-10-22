const test = require('node:test');
const assert = require('node:assert/strict');
const {WMS,createWms,createVectors} = require('../../web/obstacle_layers.js');

function setup({image = () => Promise.resolve({}), yieldBatch,
    terrainReady = () => true, groundHeight = () => undefined} = {}) {
    const layers = [],sources = [],events = [],providers = [];
    let entityId = 0;
    const C = {
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
        scene:{globe:{getHeight:groundHeight},requestRender() {}}};
    const wms = createWms(C,viewer,(type,payload) => events.push({type,...payload}),{timeoutMs:20});
    const vectors = createVectors(C,viewer,{yieldBatch,isTerrainReady:terrainReady});
    return {C,viewer,layers,sources,events,providers,wms,vectors};
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
    assert.equal(p.wms.status().state,'failed');assert.equal(p.layers.length,0);
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
    assert.equal(point.position.isConstant,false);
    assert.equal(stem.polyline.positions.isConstant,false);
    assert.equal(point.show.getValue(),true);
    assert.deepEqual(point.position.getValue(),[8.1,46.2,579.25]);
    assert.equal(stem.polyline.show.getValue(),true);
    assert.deepEqual(stem.polyline.positions.getValue(),[[8.1,46.2,529.25],[8.1,46.2,579.25]]);
    assert.equal(stem.polyline.positions.getValue()[1][2]-stem.polyline.positions.getValue()[0][2],50);
    assert.equal(point.point.heightReference,'none');
    // Terrain LOD/refinement adjusts BOTH endpoints by the same delta.
    ground=531.75;
    assert.deepEqual(point.position.getValue(),[8.1,46.2,581.75]);
    assert.deepEqual(stem.polyline.positions.getValue(),[[8.1,46.2,531.75],[8.1,46.2,581.75]]);
    assert.equal(stem.polyline.positions.getValue()[1][2]-stem.polyline.positions.getValue()[0][2],50);
    // Source geometry for elevated cables is untouched.
    assert.deepEqual(cable.polyline.positions,[[8,46,550],[8.01,46.01,560]]);
    assert.equal(cable.polyline.clampToGround,false);
    assert.deepEqual(p.vectors.pick(stem),{id:'crane',revision:1});
    assert.deepEqual(p.vectors.pick(point),{id:'crane',revision:1});
    ready=false;
    assert.equal(point.show.getValue(),false);
    assert.equal(stem.polyline.show.getValue(),false);
    ready=true;
    for (const invalidHeight of [undefined,NaN,Infinity,-2000]) {
        ground=invalidHeight;
        assert.equal(point.show.getValue(),false);
        assert.equal(stem.polyline.show.getValue(),false);
    }
    ground=530;
    assert.equal(point.show.getValue(),true);
    assert.deepEqual(point.position.getValue(),[8.1,46.2,580]);
    assert.deepEqual(stem.polyline.positions.getValue(),[[8.1,46.2,530],[8.1,46.2,580]]);
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
    assert.deepEqual(point.position.getValue(),[8,46,452.5]);
    assert.deepEqual(stem.polyline.positions.getValue(),[[8,46,402.5],[8,46,452.5]]);
    assert.equal(p.sources[0].entities.values.length,2);
    p.vectors.dispose();
});
