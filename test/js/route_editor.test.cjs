const test = require('node:test');
const assert = require('node:assert/strict');
const { createEditor, createOverlays } = require('../../web/route_editor.js');
const { sampleProfile } = require('../../web/route_editor.js');

function setup({sampleHeights} = {}) {
    const actions = {}, emitted = [], sources = [], flights = [];
    class Entity { constructor(options) {
        Object.assign(this, options);
        if (options.properties) this.properties = {waypointId: {getValue: () => options.properties.waypointId}};
    } }
    class CustomDataSource { constructor() {
        const values = [];
        this.entities = {values, add: o => {const e = new Entity(o); values.push(e); return e;},
            contains: e => values.includes(e), getById: id => values.find(e => e.id === id)};
    } }
    const controls = {enableInputs: true};
    const canvas = {addEventListener() {}, removeEventListener() {}, focus() {}};
    let picked = null;
    const viewer = {canvas, camera: {getPickRay: p => p,
        flyToBoundingSphere: (sphere,options) => flights.push({sphere,options})},
        scene: {screenSpaceCameraController: controls, pick: () => ({id: picked}),
            globe: {pick: ray => ({latitude: ray.y / 100, longitude: ray.x / 100}), getHeight: () => 1000}},
        flyTo: async (source,options) => {flights.push({source,options}); return true;},
        dataSources: {add: s => sources.push(s), remove: s => sources.splice(sources.indexOf(s), 1)}};
    const Cesium = {Entity, CustomDataSource, ScreenSpaceEventHandler: class {
        setInputAction(fn, type) {actions[type] = fn;} destroy() {}
    }, ScreenSpaceEventType: {LEFT_DOWN: 'down', LEFT_UP: 'up', MOUSE_MOVE: 'move', RIGHT_CLICK: 'right'},
        Cartographic: {fromCartesian: p => p, fromDegrees: (longitude,latitude) => ({longitude,latitude})}, Math: {toDegrees: n => n},
        BoundingSphere: {fromPoints: positions => ({radius:0,positions})},
        HeadingPitchRange: class {constructor(heading,pitch,range) {Object.assign(this,{heading,pitch,range});}},
        Cartesian3: {fromDegrees: (longitude, latitude, height) => ({longitude, latitude, height})},
        Cartesian2: class {static distance(a,b) {return Math.hypot(a.x-b.x,a.y-b.y);}},
        Color: {}, HeightReference: {}, LabelStyle: {}};
    const editor = createEditor(Cesium, viewer, (type, event) => emitted.push({type,...event}), {addEventListener() {}, removeEventListener() {}}, sampleHeights);
    return {editor, Cesium, viewer, actions, emitted, controls, sources, flights, pick(index) {picked = index == null ? null : sources.at(-1).entities.values[index];}};
}
const state = {editorId:'test', revision:1, enabled:true, interactive:true, selectedId:1, moveId:null,
    waypoints:[{id:1, latitude:46, longitude:8}]};

test('terrain profile batches are bounded, reject missing elevations and honour cancellation', async () => {
    const command = {positions:[{latitude:46,longitude:8}]};
    const sampler = async () => ({heights:[1200], samplingMethod:'most-detailed'});
    assert.equal((await sampleProfile(command,sampler,new AbortController().signal)).heightReference,'wgs84Ellipsoid');
    await assert.rejects(sampleProfile({positions:Array(257).fill(command.positions[0])},sampler,new AbortController().signal));
    await assert.rejects(sampleProfile(command,async()=>({heights:[NaN]}),new AbortController().signal));
    let release;
    const abort = new AbortController();
    const pending = sampleProfile(command,()=>new Promise(resolve=>{release=resolve;}),abort.signal);
    abort.abort(); release({heights:[1200]}); await assert.rejects(pending);
});

test('critical segments get a separate red map highlight', async () => {
    const page = setup();
    await page.editor.set({...state,waypoints:[{...state.waypoints[0],critical:true},{id:2,latitude:46.01,longitude:8.01}]});
    const warning = page.sources[0].entities.values.find(e=>e.id.startsWith('route-warning'));
    assert.equal(warning.polyline.width,7);
    assert.equal(warning.polyline.positions.length,2);
    page.editor.dispose();
});

test('map add/select/move/delete events carry the current draft identity and revision', async () => {
    const page = setup(); await page.editor.set(state);
    page.editor.click({x:800,y:4600});
    assert.equal(page.emitted.at(-1).action, 'add');
    page.pick(0); page.editor.click({x:800,y:4600});
    assert.equal(page.emitted.at(-1).action, 'select');
    page.actions.down({position:{x:800,y:4600}});
    assert.equal(page.controls.enableInputs, false);
    page.actions.move({endPosition:{x:810,y:4610}}); page.actions.up();
    assert.equal(page.controls.enableInputs, true);
    assert.deepEqual(page.emitted.at(-1), {type:'route-map-action', editorId:'test', revision:1, action:'move', id:1, latitude:46.1, longitude:8.1});
    page.actions.right({position:{x:810,y:4610}});
    assert.equal(page.emitted.at(-1).action, 'delete');
    page.editor.dispose();
    assert.equal(page.sources.length, 0);
});

test('invalid replacement leaves the route intact; saving and stale revisions reject interaction', async () => {
    const page = setup(); await page.editor.set(state);
    await assert.rejects(page.editor.set({...state, revision:2, waypoints:[{id:1,latitude:NaN,longitude:8}]}));
    assert.equal(page.sources.length, 1);
    await page.editor.set({...state,revision:2,interactive:false});
    await page.editor.set({...state,revision:1});
    page.editor.click({x:800,y:4600});
    assert.equal(page.emitted.length, 0);
    page.editor.dispose();
});

test('framing an isolated waypoint keeps an editing distance instead of zooming into the ground', async () => {
    const page = setup(); await page.editor.set(state); await page.editor.frame();
    assert.equal(page.flights.length,1);
    assert.equal(page.flights[0].options.offset.range,300);
    assert.equal(page.flights[0].sphere.positions[0].height,1030);
    assert.ok(page.flights[0].options.offset.pitch < 0);
    page.editor.dispose();
});

test('framing cannot override newer drafts or aborted requests', async () => {
    const page = setup();
    await page.editor.set(state);
    const framing = page.editor.frame();
    await page.editor.set({...state,revision:2,waypoints:[],selectedId:null}); await framing;
    assert.equal(page.flights.length,0);
    await page.editor.set({...state,revision:3});
    const abort = new AbortController();
    const cancelled = page.editor.frame(abort.signal); abort.abort();
    await assert.rejects(cancelled); assert.equal(page.flights.length,0);
    page.editor.dispose();
});

test('unspecified heights use an explicitly marked 30 m AGL preview', async () => {
    const page = setup({sampleHeights: async points => points.map((_,i) => 1000 + i * 100)});
    await page.editor.set({...state,waypoints:[...state.waypoints,{id:2,latitude:46.01,longitude:8.01}]});
    const entities = page.sources[0].entities.values;
    assert.equal(entities.find(e => e.id==='route-waypoint-1').position.height,1030);
    assert.equal(entities.find(e => e.id==='route-waypoint-2').position.height,1130);
    assert.equal(entities.find(e => e.id==='route-waypoint-1').label.text,'1*');
    const line = entities.find(e => e.id.startsWith('route-line'));
    assert.equal(line.polyline.clampToGround,false);
    assert.deepEqual(line.polyline.positions.map(p=>p.height),[1030,1130]);
    assert.equal(entities.find(e => e.id==='route-waypoint-1-height').polyline.positions[0].height,1000);
    page.editor.dispose();
});

test('configured AGL and ellipsoid heights drive points, lines and framing; incompatible datums stay previews', async () => {
    const page = setup({sampleHeights: async points => points.map(() => 1000)});
    await page.editor.set({...state,waypoints:[
        {id:1,latitude:46,longitude:8,height:{meters:70,reference:'aboveGroundLevel'}},
        {id:2,latitude:46.01,longitude:8.01,height:{meters:1200,reference:'wgs84Ellipsoid'}},
        {id:3,latitude:46.02,longitude:8.02,height:{meters:700,reference:'ln02'}}]});
    const entities = page.sources[0].entities.values;
    assert.deepEqual([1,2,3].map(i=>entities.find(e=>e.id===`route-waypoint-${i}`).position.height),[1070,1200,1030]);
    assert.equal(entities.find(e=>e.id==='route-waypoint-1').label.text,'1');
    assert.equal(entities.find(e=>e.id==='route-waypoint-3').label.text,'3*');
    await page.editor.frame();
    assert.deepEqual(page.flights[0].sphere.positions.map(p=>p.height),[1070,1200,1030]);
    await assert.rejects(page.editor.set({...state,revision:2,waypoints:[
        {id:1,latitude:46,longitude:8,height:{meters:-1,reference:'aboveGroundLevel'}}]}));
    page.editor.dispose();
});

test('late terrain results cannot restore deselected or disposed route geometry', async () => {
    let release;
    const page = setup({sampleHeights: () => new Promise(resolve => {release=resolve;})});
    const pending = page.editor.set(state);
    await page.editor.set({...state,revision:2,waypoints:[],selectedId:null});
    release([1000]); await pending;
    assert.equal(page.sources.length,0);
    const next = page.editor.set({...state,revision:3});
    page.editor.dispose(); release([1000]); await next;
    assert.equal(page.sources.length,0);
});

test('saved route overlays stay independent, frame above terrain and hide/rebuild across terrain loss', async () => {
    const page = setup(); let terrain = true;
    const overlays = createOverlays(page.Cesium,page.viewer,async points => points.map(()=>1200),()=>terrain);
    const command = {revision:1,routes:[{id:5,name:'Saved route',waypoints:state.waypoints}]};
    await overlays.set(command);
    assert.equal(page.sources[0].entities.values[0].position.height,1230);
    await overlays.frame(5,new AbortController().signal);
    assert.equal(page.flights[0].sphere.positions[0].height,1230);
    assert.equal(page.controls.enableInputs,true,'display-only overlay must not lock walking/camera');
    terrain = false; await overlays.terrainChanged(); assert.equal(page.sources.length,0);
    terrain = true; await overlays.terrainChanged(); assert.equal(page.sources.length,1);
    await overlays.set({revision:2,routes:[]}); assert.equal(page.sources.length,0);
    await overlays.set(command); assert.equal(page.sources.length,0,'stale selection cannot reappear');
    await assert.rejects(overlays.set({revision:3,routes:[{id:5,name:'Bad',waypoints:[{id:1,latitude:NaN,longitude:0}]}]}));
    overlays.dispose(); page.editor.dispose();
});
