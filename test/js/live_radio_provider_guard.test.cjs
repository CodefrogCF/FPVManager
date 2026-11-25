'use strict';
const test = require('node:test'), assert = require('node:assert/strict');
const fs = require('node:fs'), path = require('node:path'), vm = require('node:vm');
const {createBridge} = require('../../web/core/globe_bridge.js');

// Exercise the actual trusted command clause without booting the WebGL globe.
// The JSON transport must preserve a provider restriction as unavailable data,
// instead of disguising it as a sampling/programming failure.
const globe = fs.readFileSync(path.join(__dirname, '../../web/globe.js'), 'utf8');
const clause = globe.match(/case 'query-live-radio-terrain': ([^\r\n]+)/);
assert.ok(clause, 'Live terrain query command must exist');

test('unverified BKG terrain remains unavailable through the JSON bridge and never samples RF heights', async () => {
    for (const regionalTerrain of [true, false]) {
        let samples = 0;
        const events = [], heights = [500, 501];
        const liveRadio = {sample: async command => {samples++; assert.equal(command.generation, 7);return {heights};}};
        const execute = vm.runInNewContext(`(command,signal)=>{${clause[1]}}`, {regionalTerrain, liveRadio, Error});
        const bridge = createBridge({sessionId: 'provider-guard', execute,
            send: raw => events.push(JSON.parse(raw))});
        try {
            bridge.receive(JSON.stringify({type: 'query-live-radio-terrain', version: 1,
                sessionId: 'provider-guard', requestId: '36', generation: 7, analysisRequestId: 12,
                positions: [{latitude: 52.46, longitude: 13.78}, {latitude: 52.461, longitude: 13.781}]}));
            await new Promise(resolve => setImmediate(resolve));
            const result = events.find(event => event.type === 'command-result');
            assert.ok(result);assert.equal(result.requestId, '36');
            if (regionalTerrain) {
                assert.equal(result.ok, false);assert.equal(samples, 0);
                assert.match(result.error, /^TERRAIN_UNAVAILABLE:.*height datum/);
                assert.equal(result.result, undefined);
            } else {
                assert.equal(result.ok, true);assert.equal(samples, 1);
                assert.deepEqual(result.result.heights, heights);
            }
        } finally {bridge.dispose();}
    }
});
