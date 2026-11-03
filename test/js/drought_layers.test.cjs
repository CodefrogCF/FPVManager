const test = require('node:test');
const assert = require('node:assert/strict');
const { create, validate, definitions, droughtWarning } = require('../../web/situational_layers.js');

function fixture() {
  const wms = [], destroyed = [], events = [], imagery = [];
  let tile;
  const C = {
    UrlTemplateImageryProvider: class {
      constructor(options) {
        Object.assign(this, options);
        this.errorEvent = { addEventListener: listener => {
          this.fail = listener;
          return () => { this.fail = null; };
        }};
        tile = this;
      }
      requestImage() { return Promise.resolve({tile: true}); }
    },
    WebMercatorTilingScheme: class {},
    Rectangle: {fromDegrees: (...v) => v},
    Credit: class { constructor(html, onScreen) { this.html = html; this.onScreen = onScreen; } },
    ImageryLayer: class { constructor(provider, opts) {this.provider = provider; Object.assign(this, opts);} }
  };
  const viewer = {
    imageryLayers: {
      add: layer => { imagery.push(layer); },
      remove: layer => { const index = imagery.indexOf(layer); if (index >= 0) imagery.splice(index,1); }
    },
    dataSources: {remove: ()=>{}},
    camera: { moveEnd: {addEventListener: ()=>()=>{}}, computeViewRectangle: ()=>null },
    scene: {globe:{ellipsoid:{}}, requestRender:()=>{}}
  };
  const intervals = new Set();
  const factory = (C, viewer, callback, config) => {
    const mock = {config, set: command => {
      mock.command = command;
      callback('', {state: command.visible ? 'ready' : 'off'});
    }, dispose:()=> destroyed.push(config)};
    wms.push(mock);
    return mock;
  };
  const manager = create(C, viewer, (name,payload)=>events.push({name, payload}), factory,
    {timers: {setInterval: f=>{intervals.add(f);return f;}, clearInterval:f=>intervals.delete(f)}});
  return {manager, wms, destroyed, imagery, events, intervals, get tile(){return tile;}};
}

test('only the documented drought product IDs and CDI time steps are accepted', () => {
  assert.equal(definitions['drought-index'].layer,'ch.bafu.trockenheitsindex');
  assert.equal(definitions['vegetation-vhi'].layer,'ch.swisstopo.swisseo_vhi_v100');
  assert.equal(definitions['vegetation-vhi-all'].layer,'ch.swisstopo.swisseo_vhi_v100_vegetation');
  assert.equal(droughtWarning.layer, 'ch.bafu.trockenheitswarnkarte');
  for (const id of ['drought-warning','drought-index','vegetation-vhi','vegetation-vhi-all'])
    validate({id, visible:true, opacity:.5});
  for (const step of [0,1,2,3,4])
    validate({id:'drought-index',visible:true,opacity:.5,timeStep:step});
  for (const step of [-1,5,'2',2.5])
    assert.throws(()=>validate({id:'drought-index',visible:true,opacity:.5,timeStep:step}));
  assert.throws(()=>validate({id:'vegetation-vhi',visible:true,opacity:.5,timeStep:2}));
});

test('CDI published WMS time steps replace imagery without changing warning or vegetation',async()=>{
  const p=fixture();
  await p.manager.set({id:'drought-index',visible:true,opacity:.4,timeStep:1});
  await p.manager.set({id:'vegetation-vhi',visible:true,opacity:.3});
  assert.equal(p.wms[0].config.definition.parameters.time,'1');
  assert.equal(p.wms[0].config.definition.maximumLevel,11);
  assert.equal(p.wms[1].config.definition.layer,'ch.swisstopo.swisseo_vhi_v100');
  await p.manager.set({id:'drought-index',visible:true,opacity:.4,timeStep:3});
  assert.equal(p.wms[2].config.definition.parameters.time,'3');
  assert.equal(p.destroyed.length,1);
  await p.manager.set({id:'drought-index',visible:true,opacity:.7,timeStep:3});
  assert.equal(p.wms.length,3,'opacity change must not allocate another provider');
  p.manager.dispose();
  assert.equal(p.destroyed.length,3);
  assert.equal(p.intervals.size,0);
});

test('published WMTS warning tile remains independent; retry, errors and disposal free resources',async()=>{
  const p=fixture();
  await p.manager.set({id:'drought-warning',visible:true,opacity:.35});
  assert.equal(p.imagery.length,1);
  assert.match(p.tile.url,/ch\.bafu\.trockenheitswarnkarte/);
  assert.equal(p.tile.maximumLevel,11);
  assert.match(p.tile.credit.html,/BAFU/);
  await p.tile.requestImage(1,2,3);
  assert.equal(p.events.at(-1).payload.state,'ready');
  await p.manager.set({id:'drought-warning',visible:true,opacity:.65});
  assert.equal(p.imagery.length,1);
  assert.equal(p.imagery[0].alpha,.65);
  p.tile.fail();
  assert.equal(p.events.at(-1).payload.state,'failed');
  await p.manager.set({id:'drought-warning',visible:true,opacity:.65,retry:true});
  assert.equal(p.imagery.length,1);
  await p.manager.set({id:'drought-warning',visible:false,opacity:.65});
  assert.equal(p.imagery.length,0);
  p.manager.dispose();
  assert.equal(p.intervals.size,0);
});

test('actual WMS factory passes official CDI time parameter and zoom cap to Cesium', () => {
  const {createWms} = require('../../web/obstacle_layers.js');
  const C = {
    WebMercatorTilingScheme: class {positionToTileXY() {return {x:4,y:5};}},
    WebMapServiceImageryProvider: class {
      constructor(config) { Object.assign(this,config); this.errorEvent = {addEventListener:()=>()=>{}}; }
      requestImage(){return Promise.resolve({});}
    },
    Rectangle:{fromDegrees:(...v)=>v}, Cartographic:{fromDegrees:()=>({})},
    Credit:class {constructor(html,onScreen){this.html=html;this.onScreen=onScreen;}},
    ImageryLayer:class {constructor(provider, opts){this.imageryProvider=provider;Object.assign(this,opts);}}
  };
  const layers=[];
  const viewer={imageryLayers:{add:l=>layers.push(l),remove:l=>{
    const i=layers.indexOf(l);if(i>=0)layers.splice(i,1);
  }}};
  const wms=createWms(C,viewer,()=>{}, {definition:{url:'https://wms.geo.admin.ch/',
    layer:'ch.bafu.trockenheitsindex',bounds:[5.8,45.7,10.7,47.9],
    parameters:{time:'2'}, maximumLevel:11}});
  wms.set({visible:true,opacity:.5});
  assert.equal(layers.length,1);
  assert.equal(layers[0].imageryProvider.parameters.time,'2');
  assert.equal(layers[0].imageryProvider.maximumLevel,11);
  wms.dispose();
  assert.equal(layers.length,0);
});
