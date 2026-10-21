const test = require('node:test');
const assert = require('node:assert/strict');
const { createEditor } = require('../../web/route_editor.js');

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
    return {editor, actions, emitted, controls, sources, flights, pick(index) {picked = index == null ? null : sources.at(-1).entities.values[index];}};
}
const state = {editorId:'test', revision:1, enabled:true, interactive:true, selectedId:1, moveId:null,
    waypoints:[{id:1, latitude:46, longitude:8}]};

test('map add/select/move/delete events carry the current draft identity and revision', () => {
    const page = setup(); page.editor.set(state);
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

test('invalid replacement leaves the route intact; saving and stale revisions reject interaction', () => {
    const page = setup(); page.editor.set(state);
    assert.throws(() => page.editor.set({...state, revision:2, waypoints:[{id:1,latitude:NaN,longitude:8}]}));
    assert.equal(page.sources.length, 1);
    page.editor.set({...state,revision:2,interactive:false});
    page.editor.set({...state,revision:1});
    page.editor.click({x:800,y:4600});
    assert.equal(page.emitted.length, 0);
    page.editor.dispose();
});

test('framing an isolated waypoint keeps an editing distance instead of zooming into the ground', async () => {
    const page = setup(); page.editor.set(state); await page.editor.frame();
    assert.equal(page.flights.length,1);
    assert.equal(page.flights[0].options.offset.range,300);
    assert.equal(page.flights[0].sphere.positions[0].height,1000);
    assert.ok(page.flights[0].options.offset.pitch < 0);
    page.editor.dispose();
});

test('late framing samples cannot override newer drafts or aborted requests', async () => {
    let release;
    const page = setup({sampleHeights: () => new Promise(resolve => {release=resolve;})});
    page.editor.set(state);
    const framing = page.editor.frame();
    page.editor.set({...state,revision:2,waypoints:[],selectedId:null}); release([1000]); await framing;
    assert.equal(page.flights.length,0);
    page.editor.set({...state,revision:3});
    const abort = new AbortController();
    const cancelled = page.editor.frame(abort.signal); abort.abort(); release([1000]);
    await assert.rejects(cancelled); assert.equal(page.flights.length,0);
    page.editor.dispose();
});
