const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const { createBridge } = require('../../web/globe_bridge.js');
const FPVTerrain = require('../../web/terrain_service.js');
const FPVMapProviders = require('../../web/map_providers.js');
const FPVObstacles = require('../../web/obstacle_layers.js');
const source = fs.readFileSync(require.resolve('../../web/globe.js'), 'utf8');
const FPVUasZoneStyles = require('../../web/uas_zone_styles.js');
require('../../web/weather_overlay.js');
const FPVWeatherOverlay = globalThis.FPVWeatherOverlay;

// Exercise the renderer's provider setup without network I/O or WebGL. The
// visible credits themselves are checked with the actual browser smoke harness.
async function renderer({ offline = false, terrainFails = false, configuration, groundView = false, floating = false } = {}) {
    const imagery = [], terrain = [], events = [], sources = [];
    let geojsonLoads = 0;
    const colors = value => ({ value, withAlpha: a => ({value, alpha:a}) });
    const info = {addEventListener() {}};
    const window = {
        FPVMapProviderConfig: configuration,
        location: { search: floating ? '?chrome=floating' : offline ? '?offline=1' : '', origin: 'http://localhost' },
        addEventListener() {},
        FPVBridge: { postMessage: raw => events.push(JSON.parse(raw)) }
    };
    window.parent = window;
    const context = vm.createContext({
        window, navigator: { onLine: true }, URLSearchParams, AbortController, FPVTerrain, FPVMapProviders, FPVObstacles,
        document: { getElementById: () => info, documentElement: {classList: new Set()} },
        console: { error() {}, log() {} }, setTimeout, clearTimeout,
        FPVGlobeBridge: { createBridge },
        FPVGroundNavigation: { createWalker: () => ({ stop() {}, tick() {}, status: () => ({active: groundView}) }), bindControls() {} },
        FPVFreeFlight: {createSimulator:()=>({stop(){},tick(){},status:()=>({active:false})})},
        FPVFlightRendering: {create:()=>({})},
        FPVSceneEnvironment: {create:()=>({set(){},setTime(){},performance(){},dispose(){}}),bindTimeControls:()=>({update(){}})},
        FPVWindField: {create:()=>({set(){},sample(){return null;},navigation(){},performance(){},terrainChanged(){},dispose(){}})},
        FPVGlobePositions: {create:()=>({location(){},destination(){},dispose(){}})},
        FPVFlightHud: {create:()=>({update(){},device(){}})},
        FPVFlightRecording: {create:()=>({observe(){},bind(){},control(){}})},
        FPVLiveRadio: {create:()=>({observe(){},terrainChanged(){},dispose(){}})},
        FPVControllerInput: {bindPanel:()=>({update(){}})},
        FPVRoadNavigation: {create:()=>({set(){},dispose(){}})},
        FPVMapCompass: {create:()=>({dispose(){}})},
        FPVNavigationControls: {bindControls:()=>Object.assign(()=>{},{tick(){},reset(){},setVisible(){},sync(){}})},
        FPVSignalAnalysis: require('../../web/signal_analysis.js'),
        FPVSituationalLayers: {create:()=>({set(){},pick(){return null;},dispose(){}})},
        FPVRouteEditor: {
            createEditor: () => ({ click: () => false, terrainChanged() {} }),
            createOverlays: () => ({ terrainChanged() {}, dispose() {} })
        },
        performance: { now: () => 42 }, FPVUasZoneStyles, FPVWeatherOverlay,
        Cesium: {
            Color: {RED:colors('red'), fromCssColorString:colors},
            GeoJsonDataSource: { async load(data, options) {
                geojsonLoads++;
                const values = data.features.map((feature, i) => ({
                    id:'zone-'+i, polygon:{},
                    properties:{type:{getValue:() => feature.properties.type},
                        restriction:{getValue:() => feature.properties.restriction},
                        identifier:feature.properties.identifier},
                }));
                return {entities:{values, suspendEvents() {}, resumeEvents() {}},
                    show:true, credit:options.credit};
            } },
            Credit: class { constructor(html, showOnScreen) { Object.assign(this, { html, showOnScreen }); } },
            GridImageryProvider: class {},
            UrlTemplateImageryProvider: class { constructor(options) { Object.assign(this, options); imagery.push(this); } },
            WebMercatorTilingScheme: class {},
            Ellipsoid: { WGS84: {} },
            EllipsoidTerrainProvider: class {},
            CesiumTerrainProvider: { async fromUrl(url, options) {
                terrain.push({ url, ...options });
                if (terrainFails) throw new Error('Fixture: terrain unavailable');
                return { credit: options.credit, // No metadata-derived credit.
                    errorEvent: { addEventListener: () => () => {} },
                    requestTileGeometry: async () => ({}) };
            } },
            ImageryLayer: class { constructor(provider) { this.imageryProvider = provider; } },
            Viewer: class { constructor(_id, options) {
                let current = options.baseLayer;
                this.imageryLayers = { get: () => current, add: layer => { current = layer; }, remove() {} };
                const listeners = new Set();
                this.scene = { globe: {}, renderError: { addEventListener() {} },
                    preRender: { addEventListener() {} },
                    postRender:{addEventListener(f) {listeners.add(f);return () => listeners.delete(f);}},
                    requestRender:() => setImmediate(() => {for(const f of [...listeners]) f();}) };
                this.dataSources = {
                    contains:d=>sources.includes(d), indexOf:d=>sources.indexOf(d),
                    add: async d=> {sources.push(d);return d;},
                    remove: d=> {const index=sources.indexOf(d); if(index>=0)sources.splice(index,1);},
                    raiseToTop:d=> {const index=sources.indexOf(d);if(index>=0) {sources.splice(index,1);sources.push(d);}}
                };
                this.clock = {currentTime:0};
                this.camera = { setView() {}, moveEnd:{addEventListener() {}}, computeViewRectangle() {},
                    positionCartographic:{longitude:.15,latitude:.82} };
                this.screenSpaceEventHandler = { setInputAction() {} };
            } },
            Cartesian3: { fromDegrees() {} }, Math: { toRadians() {}, toDegrees:r => r*180/Math.PI },
            Rectangle:class { constructor(west,south,east,north) {Object.assign(this,{west,south,east,north});} },
            ScreenSpaceEventType: { LEFT_CLICK: 1 }
        }
    });
    vm.runInContext(source, context, { filename: 'globe.js' });
    await new Promise(resolve => setImmediate(resolve));
    assert.equal(events.some(e => e.type === 'globe-error'), false, info.textContent);
    assert.equal(events.some(e => e.type === 'globe-ready'), true);
    return { imagery, terrain, context, events, sources, info, get globe(){return vm.runInContext('activeViewer.scene.globe',context);}, get geojsonLoads() {return geojsonLoads;} };
}

test('floating map chrome hides redundant ready text but retains terrain outage information', async () => {
    const ready=await renderer({floating:true});
    assert.equal(ready.info.hidden,true);
    const failed=await renderer({floating:true,terrainFails:true});
    assert.equal(failed.info.hidden,false);
    assert.match(failed.info.textContent,/3D terrain unavailable/);
});

function assertSatelliteCredit(provider) {
    for (const name of ['swisstopo', 'CNES', 'Spot Image', 'NPOC',
        'Includes material © (2016-2018) Planet. All rights reserved']) {
        assert.ok(provider.credit.html.includes(name), `Missing attribution: ${name}`);
    }
    assert.equal(provider.credit.showOnScreen, true);
}

test('ground camera uses a local obstacle viewport independent of the ellipsoid horizon',async () => {
    const page=await renderer({groundView:true});
    const viewport=page.events.find(e => e.type==='obstacle-viewport');
    assert.ok(viewport);assert.ok(viewport.east-viewport.west < .1);
    assert.ok(viewport.north-viewport.south < .1);
});

test('zone inspection preserves source values and marks every display limit within the frame budget', async () => {
    const page = await renderer();
    const raw = { name:'Source provided zone name', restriction:'FUTURE_CODE', lowerLimit:0, active:false, unset:null,
        nested:{source:'value'}, html:'<b>source text</b>', message:'x'.repeat(9000) };
    const details = page.context.uasSelectionDetails(raw);
    assert.equal(details.attributes.lowerLimit, '0');
    assert.equal(details.attributes.active, 'false');
    assert.equal(details.attributes.unset, 'null');
    assert.equal(details.attributes.nested, '{"source":"value"}');
    assert.equal(details.attributes.html, '<b>source text</b>');
    assert.equal(details.attributes.restriction, 'FUTURE_CODE');
    assert.equal(details.name, 'Source provided zone name');
    assert.equal(details.attributes.message.length, 8000);
    assert.equal(details.truncatedAttributes.includes('message'), true);
    assert.equal(details.omittedAttributeCount, 0);
    const large = Object.fromEntries(Array.from({length:200}, (_,i) => ['\\"'.repeat(50)+i, '\\"'.repeat(5000)]));
    large.restriction = 'REQ_AUTHORISATION';
    large.lowerLimit = 0;
    const limited = page.context.uasSelectionDetails(large);
    assert.equal(limited.attributes.restriction, 'REQ_AUTHORISATION');
    assert.equal(limited.attributes.lowerLimit, '0');
    assert.ok(limited.omittedAttributeCount > 0);
    assert.equal(Object.keys(limited.attributes).length + limited.omittedAttributeCount, Object.keys(large).length);
    assert.ok(JSON.stringify(limited).length < 128*1024 - 3000);
    assert.equal(Object.hasOwn(page.context.uasSelectionDetails({name:'   '}), 'name'), false);
    const named = page.context.uasSelectionDetails({name:'n'.repeat(200)});
    assert.equal(named.name.length, 160);
    assert.equal(named.attributes.name.length, 200);
});

test('startup and style changes retain complete visible source credits', async () => {
    const page = await renderer();
    assertSatelliteCredit(page.imagery[0]);
    for (const style of ['topographic', 'relief', 'satellite']) {
        page.context.setMapStyle(style);
        const provider = page.imagery.at(-1);
        assert.equal(provider.credit.showOnScreen, true);
        if (style === 'satellite') assertSatelliteCredit(provider);
        else {
            assert.equal(provider.credit.html, '© swisstopo');
            assert.equal(provider.credit.html.includes('Planet'), false);
        }
    }
    assert.throws(() => page.context.setMapStyle('unknown'), /Unknown map style/);
});

test('terrain has an explicit visible credit even without metadata attribution', async () => {
    const page = await renderer();
    assert.equal(page.terrain.length, 1);
    assert.equal(page.terrain[0].credit.html, '© swisstopo');
    assert.equal(page.terrain[0].credit.showOnScreen, true);
});

test('terrain failure preserves imagery attribution on the flat fallback', async () => {
    const page = await renderer({ terrainFails: true });
    assertSatelliteCredit(page.imagery[0]);
    assert.equal(page.events.find(e => e.type === 'globe-ready').terrainAvailable, false);
});

test('offline diagnostic grid does not claim external imagery or terrain', async () => {
    const page = await renderer({ offline: true });
    page.context.setMapStyle('relief');
    assert.equal(page.imagery.length, 0);
    assert.equal(page.terrain.length, 0);
    assert.equal(page.events.find(e => e.type === 'globe-ready').terrainAvailable, false);
});

test('replacing imagery and terrain adapters needs no renderer or map UI edits', async () => {
    const customSource = {id:'fixture.source', name:'Fixture source', publisher:'Fixture publisher',
        attribution:'Fixture <source> & contributors', metadataUri:'https://example.invalid/metadata',
        licenseName:null, licenseUri:null, validity:null};
    const page = await renderer({configuration: {
        imagery: {satellite: {source:customSource, url:'https://example.invalid/{z}/{x}/{y}.png', maximumLevel:10}},
        terrain: {source:customSource, url:'https://example.invalid/terrain/'}
    }});
    assert.equal(page.imagery[0].url, 'https://example.invalid/{z}/{x}/{y}.png');
    assert.equal(page.imagery[0].maximumLevel, 10);
    assert.equal(page.imagery[0].credit.html, 'Fixture &lt;source&gt; &amp; contributors');
    assert.equal(page.terrain[0].url, 'https://example.invalid/terrain/');
    assert.equal(page.terrain[0].credit.html, page.imagery[0].credit.html);
    assert.throws(() => page.context.setMapStyle('toString'), /Unknown map style/);
});


test('renderer applies source classification, preserves overlaps, and measures rendering', async () => {
    const page = await renderer();
    const geojson = {type:'FeatureCollection',features:[
        {type:'Feature',geometry:{type:'Polygon',coordinates:[]},properties:{type:'COMMON',restriction:'REQ_AUTHORISATION.MTOM_ALL',identifier:'p'}},
        {type:'Feature',geometry:{type:'Polygon',coordinates:[]},properties:{type:'COMMON',restriction:'REQ_AUTHORISATION.CTR',identifier:'c'}},
        {type:'Feature',geometry:{type:'Polygon',coordinates:[]},properties:{type:'COMMON',restriction:'UNRECOGNISED',identifier:'u'}},
    ]};
    const signal = new AbortController().signal;
    await page.context.setUasZonesVisible(true, geojson, '2026-10-22T09:00:00Z', false, signal,'© FOCA / BAZL');
    assert.equal(page.geojsonLoads,1);
    assert.equal(page.sources.length,1);
    const items = page.sources[0].entities.values;
    assert.deepEqual(items.map(e=>e.polygon.material.value),['#ef6c00','#7b1fa2','#757575']);
    assert.deepEqual(items.map(e=>e.properties.identifier),['p','c','u']);
    assert.equal(page.sources[0].credit.html,'© FOCA / BAZL');
    assert.equal(page.events.some(e=>e.type==='uas-render-metrics'),true);
    await new Promise(resolve=>setImmediate(resolve));
    const measured = page.events.filter(e=>e.type==='uas-render-metrics').at(-1);
    assert.equal(measured.featureCount,3);
    assert.equal(typeof measured.loadMs,'number');
    assert.equal(typeof measured.attachMs,'number');
    assert.equal(typeof measured.firstFrameMs,'number');
    page.context.setUasFillOpacity(.4);
    assert.equal(items[0].polygon.material.alpha,.4);
    assert.equal(items[1].polygon.material.value,'#7b1fa2');
    await page.context.setUasZonesVisible(false,null,null,false,signal);
    assert.equal(page.sources[0].show,false);
    await page.context.setUasZonesVisible(true,null,null,false,signal);
    assert.equal(page.geojsonLoads,1,'visibility changes must not trigger import');
    assert.equal(page.sources[0].show,true);
});

 test('topographic detail retains finer labelled imagery and restores default for other styles',async()=>{
    const p=await renderer();
    p.context.setMapStyle('topographic');assert.equal(p.globe.maximumScreenSpaceError,1);
    p.context.setMapStyle('satellite');assert.equal(p.globe.maximumScreenSpaceError,2);
    const flight=await renderer({groundView:true});
    flight.globe.maximumScreenSpaceError=3;
    flight.context.setMapStyle('topographic');assert.equal(flight.globe.maximumScreenSpaceError,3);
 });
