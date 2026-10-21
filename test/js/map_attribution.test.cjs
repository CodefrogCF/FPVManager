const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const { createBridge } = require('../../web/globe_bridge.js');
const FPVTerrain = require('../../web/terrain_service.js');
const FPVMapProviders = require('../../web/map_providers.js');
const source = fs.readFileSync(require.resolve('../../web/globe.js'), 'utf8');

// Exercise the renderer's provider setup without network I/O or WebGL. The
// visible credits themselves are checked with the actual browser smoke harness.
async function renderer({ offline = false, terrainFails = false, configuration } = {}) {
    const imagery = [], terrain = [], events = [];
    const info = {};
    const window = {
        FPVMapProviderConfig: configuration,
        location: { search: offline ? '?offline=1' : '', origin: 'http://localhost' },
        addEventListener() {},
        FPVBridge: { postMessage: raw => events.push(JSON.parse(raw)) }
    };
    window.parent = window;
    const context = vm.createContext({
        window, navigator: { onLine: true }, URLSearchParams, AbortController, FPVTerrain, FPVMapProviders,
        document: { getElementById: () => info },
        console: { error() {} }, setTimeout, clearTimeout,
        FPVGlobeBridge: { createBridge },
        FPVGroundNavigation: { createWalker: () => ({ stop() {}, tick() {}, status: () => ({active: false}) }), bindControls() {} },
        FPVRouteEditor: {
            createEditor: () => ({ click: () => false, terrainChanged() {} }),
            createOverlays: () => ({ terrainChanged() {}, dispose() {} })
        },
        performance: { now: () => 0 },
        Cesium: {
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
                this.scene = { globe: {}, renderError: { addEventListener() {} }, preRender: { addEventListener() {} } };
                this.camera = { setView() {} };
                this.screenSpaceEventHandler = { setInputAction() {} };
            } },
            Cartesian3: { fromDegrees() {} }, Math: { toRadians() {} },
            ScreenSpaceEventType: { LEFT_CLICK: 1 }
        }
    });
    vm.runInContext(source, context, { filename: 'globe.js' });
    await new Promise(resolve => setImmediate(resolve));
    assert.equal(events.some(e => e.type === 'globe-error'), false, info.textContent);
    assert.equal(events.some(e => e.type === 'globe-ready'), true);
    return { imagery, terrain, context, events };
}

function assertSatelliteCredit(provider) {
    for (const name of ['swisstopo', 'CNES', 'Spot Image', 'NPOC',
        'Includes material © (2016-2018) Planet. All rights reserved']) {
        assert.ok(provider.credit.html.includes(name), `Missing attribution: ${name}`);
    }
    assert.equal(provider.credit.showOnScreen, true);
}

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
