const test = require('node:test');
const assert = require('node:assert/strict');
const {attach, sourceResource} = require('../../web/vegetation_models.js');

const source = 'https://3d.geo.admin.ch/ch.swisstopo.vegetation.3d/v1/20250728/';
const assetBase = 'http://127.0.0.1:9000/assets/vegetation/';
const tile = {_header: {boundingVolume: {region: [.12, .8, .14, .82, 900, 1000]}}};

function fixture({uri = '../../Tree-2.glb', failLocal = false} = {}) {
    class Resource {
        constructor({url}) { this.url = url; }
        clone() { return new Resource({url: this.url}); }
        getDerivedResource({url}) { return new Resource({url: new URL(url, this.url).href}); }
    }
    const requests = [];
    const original = async (tileset, tile, resource, buffer, offset) => {
        const model = resource.clone().getDerivedResource({url: uri}).url;
        requests.push({tileset, tile, resource, buffer, offset, model});
        if (failLocal && model.startsWith(assetBase)) throw Error('Local model failed');
        return model;
    };
    const C = {Resource, Cesium3DTileContentFactory: {i3dm: original}, RequestState: {CANCELLED: 4}};
    const resource = new Resource({url: source + '10/927/210.i3dm?compositeIndex=1'});
    const buffer = new ArrayBuffer(4096);
    const read = (owner, node = tile) => C.Cesium3DTileContentFactory.i3dm(owner, node, resource, buffer, 256);
    return {C, requests, read, resource, buffer, original};
}

test('an official instanced batch picks a stable local variant and preserves the source instances and offset', async () => {
    const {C, requests, read, resource, buffer} = fixture();
    const forest = {}, other = {};
    const release = attach(C, forest, {assetBase, sample(longitude, latitude) {
        assert.ok(Math.abs(longitude - .13 * 180 / Math.PI) < 1e-10);
        assert.ok(Math.abs(latitude - .81 * 180 / Math.PI) < 1e-10);
        return 0;
    }});
    const model = await read(forest);
    assert.match(model, /\/tree-conifer-[123]\.glb$/);
    assert.equal(await read(forest), model);
    assert.equal(await read(other), source + 'Tree-2.glb');
    assert.equal(requests[0].buffer, buffer);
    assert.equal(requests[0].offset, 256);
    assert.equal(requests[0].tile, tile);
    assert.equal(resource.clone().getDerivedResource({url: '../../Tree-2.glb'}).url, source + 'Tree-2.glb');
    release();
    assert.equal(await read(forest), source + 'Tree-2.glb');
});

test('the Laubholz probability selects broadleaf and a missing raster still varies the models', async () => {
    const {C, read} = fixture();
    const deciduous = {}, unknown = {};
    const releaseDeciduous = attach(C, deciduous, {assetBase, sample: () => 1});
    const releaseUnknown = attach(C, unknown, {assetBase});
    assert.match(await read(deciduous), /\/tree-broadleaf-[123]\.glb$/);
    releaseDeciduous();
    assert.match(await read(unknown), /\/tree-(broadleaf|conifer)-[123]\.glb$/);
    releaseUnknown();
});

test('future or foreign model URIs keep the original loader and skip composition sampling', async () => {
    for (const uri of ['../../Tree-4.glb', 'https://other.example/20250728/Tree-2.glb']) {
        const {C, read, resource} = fixture({uri});
        const owner = {};
        let samples = 0;
        attach(C, owner, {assetBase, sample: () => { samples++; return 1; }});
        assert.equal(await read(owner), new URL(uri, resource.url).href);
        assert.equal(samples, 0);
    }
});

test('missing local GLB retries the official model only for a live tile and releases the factory hook', async () => {
    const {C, requests, read, original} = fixture({failLocal: true});
    const owner = {};
    const release = attach(C, owner, {assetBase});
    assert.equal(await read(owner), source + 'Tree-2.glb');
    assert.equal(requests.length, 2);
    await assert.rejects(read(owner, {...tile, _request: {state: C.RequestState.CANCELLED}}), /Local model failed/);
    assert.equal(requests.length, 3);
    release();
    assert.equal(C.Cesium3DTileContentFactory.i3dm, original);
});

test('the official vegetation index restores bare i3dm paths from its published revision', async () => {
    const url = new URL('../tileset.json', source).href;
    class Resource {
        constructor({url}) { this.url = url; }
        clone() { return new Resource({url: this.url}); }
        getDerivedResource() { return this.clone(); }
        async fetchJson() {
            return {root: {children: [
                {content: {uri: '20250728/tileset24.json'}},
                {content: {uri: '10/244/834.i3dm'}},
                {content: {url: '10/244/835.i3dm'}},
                {content: {uri: '20250728/10/245/835.i3dm'}},
                {content: {uri: 'models/test.glb'}},
            ]}};
        }
    }
    const index = sourceResource({Resource}, url).getDerivedResource().getDerivedResource();
    const json = await index.fetchJson();
    assert.deepEqual(json.root.children.map(({content}) => content.uri ?? content.url), [
        '20250728/tileset24.json', '20250728/10/244/834.i3dm', '20250728/10/244/835.i3dm',
        '20250728/10/245/835.i3dm', 'models/test.glb',
    ]);
    assert.equal(sourceResource({Resource}, 'https://other.example/tileset.json'), 'https://other.example/tileset.json');
});
