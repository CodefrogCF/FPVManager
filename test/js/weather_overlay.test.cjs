const test = require('node:test');
const assert = require('node:assert/strict');
require('../../web/weather_overlay.js');
const weather = globalThis.FPVWeatherOverlay;

test('Weather sample colors are based on displayed source values', () => {
  assert.deepEqual(weather.rgb('wind', 2), [50, 161, 114]);
  assert.deepEqual(weather.rgb('wind', 13), [205, 64, 65]);
  assert.notDeepEqual(weather.rgb('precipitation', 4), weather.rgb('wind', 4));
});
test('Weather overlay validation rejects invalid coordinates and metadata', () => {
  const valid = {kind:'wind', timestampUtc:'2026-10-23T12:00:00Z', source:'Open-Meteo',gridSpacingMeters:1000,
    cells:[{west:8,south:46,east:8.1,north:46.1,value:4}]};
  assert.doesNotThrow(() => weather.validate(valid));
  assert.throws(() => weather.validate({...valid,cells:[{...valid.cells[0],value:-1}]}));
  assert.throws(() => weather.validate({...valid,kind:'airspace'}));
});
test('Weather layer is added and cleared without modifying other layers', async () => {
  const inserted = [], deleted = [];
  const layer = {show:true,entities: {values:[],removeAll(){this.values=[]},add(entity){this.values.push(entity)}}};
  const viewer = {dataSources:{ async add(s) { inserted.push(s); return s; },remove(s){deleted.push(s)}},scene:{requestRender(){}}};
  const Cesium = {CustomDataSource: class { constructor(){ this.entities=layer.entities; this.show=true; } },
    Color:{fromBytes:(...args)=>args},Cartesian3:{fromDegreesArray:(a)=>a},
    ClassificationType:{TERRAIN:1},HeightReference:{CLAMP_TO_GROUND:1}};
  const overlay = weather.create(Cesium,()=>viewer);
  await overlay.replace({kind:'wind',timestampUtc:'2026-10-23T12:00:00Z',source:'Open-Meteo',gridSpacingMeters:1000,
    cells:[{west:8,south:46,east:8.1,north:46.1,value:4}]});
  assert.equal(layer.entities.values.length,1);
  overlay.clear();
  assert.equal(layer.entities.values.length,0);
  assert.equal(inserted.length,1);
  assert.equal(deleted.length,0);
});

function deferredRenderer() {
  let finish;
  const attached = [], removed = [];
  const ready = new Promise(resolve => { finish = resolve; });
  const Cesium = {CustomDataSource: class {
    constructor() { this.show = true; this.entities = {values:[], removeAll(){this.values=[];},add(entity){this.values.push(entity);}}; }
  },Color:{fromBytes:(...a)=>a},Cartesian3:{fromDegreesArray:a=>a},
    ClassificationType:{TERRAIN:1},HeightReference:{CLAMP_TO_GROUND:1}};
  const viewer = {dataSources:{async add(source){await ready;attached.push(source);return source;},
    remove(source){removed.push(source);const i=attached.indexOf(source);if(i>=0)attached.splice(i,1);}},scene:{requestRender(){}}};
  const overlay = weather.create(Cesium,()=>viewer);
  const command = {kind:'wind',timestampUtc:'2026-10-23T12:00:00Z',source:'Open-Meteo',gridSpacingMeters:1000,
    cells:[{west:8,south:46,east:8.1,north:46.1,value:4}]};
  return {overlay, command, attached, removed, finish};
}

test('clear and disposal invalidate a weather layer whose renderer attachment is still pending', async () => {
  for (const action of ['clear','dispose']) {
    const r = deferredRenderer();
    const pending = r.overlay.replace(r.command);
    r.overlay[action]();
    r.finish();
    assert.equal((await pending).superseded,true);
    assert.equal(r.overlay.current,null);
    if (action === 'clear') {
      assert.equal(r.attached.length,1);
      assert.equal(r.attached[0].show,false);
      assert.equal(r.attached[0].entities.values.length,0);
    } else {
      assert.equal(r.attached.length,0);
    }
  }
});

test('the newest weather overlay wins when multiple replacements await the same renderer attachment', async () => {
  const r = deferredRenderer();
  const first = r.overlay.replace(r.command);
  const latest = {...r.command, timestampUtc:'2026-10-23T13:00:00Z', cells:[{...r.command.cells[0],value:9}]};
  const second = r.overlay.replace(latest);
  r.finish();
  assert.equal((await first).superseded,true);
  await second;
  assert.equal(r.attached.length,1);
  assert.equal(r.attached[0].entities.values[0].properties.sampledValue,9);
  assert.equal(r.overlay.current.timestampUtc,latest.timestampUtc);
});
