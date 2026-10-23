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
