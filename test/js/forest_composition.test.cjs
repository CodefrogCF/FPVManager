const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');
const {create, parse} = require('../../web/forest_composition.js');

const filename = 'assets/vegetation/forest_composition.bin';
const asset = fs.readFileSync(path.join(__dirname, '../../web', filename));

test('the bundled Swiss overview samples the correct leaf-type probability and NoData', () => {
    const sample = parse(asset);
    assert.equal(sample(9.89, 46.85), .04);
    assert.equal(sample(7.04, 47.44), .66);
    assert.equal(sample(8.4, 46.7), undefined);
    assert.equal(sample(10.7, 47.9), undefined);
    assert.equal(sample(NaN, 47), undefined);
});

test('truncated or incompatible forest data cannot be used as an overview', () => {
    assert.throws(() => parse(asset.subarray(0, asset.length - 1)), /dimensions/);
    assert.throws(() => parse(new Uint8Array(32)), /header/);
});

test('the forest overview loads lazily once from the packaged asset', async () => {
    let calls = 0;
    const forest = create({
        fetcher: async url => {
            calls++;
            assert.equal(url, filename);
            return {ok: true, arrayBuffer: async () => Uint8Array.from(asset).buffer};
        }
    });
    assert.equal(forest.sample(9.89, 46.85), undefined);
    assert.equal(calls, 0);
    const firstLoad = forest.load();
    assert.equal(forest.load(), firstLoad);
    assert.equal(await firstLoad, true);
    assert.equal(forest.sample(9.89, 46.85), .04);
    assert.equal(forest.sample(7.04, 47.44), .66);
    assert.equal(calls, 1);
});

test('missing or corrupt local forest data falls back without repeated reads', async () => {
    for (const response of [{ok: false}, {ok: true, arrayBuffer: async () => new ArrayBuffer(10)}]) {
        let calls = 0;
        const forest = create({fetcher: async () => {calls++; return response;}});
        assert.equal(await forest.load(), false);
        assert.equal(await forest.load(), false);
        assert.equal(forest.sample(9.89, 46.85), undefined);
        assert.equal(calls, 1);
    }
});
