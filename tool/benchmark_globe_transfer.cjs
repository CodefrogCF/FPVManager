#!/usr/bin/env node
'use strict';
// Reproducible, synthetic protocol benchmark. This is NOT a device benchmark.
const { performance } = require('node:perf_hooks');
const { gzipSync } = require('node:zlib');
const { createBridge } = require('../web/globe_bridge.js');

function stamp(task) {
    const started = performance.now();
    const value = task();
    return { value, ms: +(performance.now() - started).toFixed(2) };
}
async function run() {
    const features = Array.from({ length: 18000 }, (_, i) => ({
        type: 'Feature',
        geometry: { type: 'Polygon', coordinates: [[[8.1 + i / 100000, 47.0],
            [8.11 + i / 100000, 47.0], [8.11 + i / 100000, 47.01],
            [8.1 + i / 100000, 47.0]]] },
        properties: { id: `uas-${i}`, source: 'Swiss UAS synthetic example',
            name: `Representative airspace #${i}`, lowerLimit: 0,
            category: 'FLIGHT_RESTRICTION', attribution: 'Synthetic; not authoritative' }
    }));
    const command = { version: 1, sessionId: 'bench', requestId: '1',
        type: 'set-uas-zones', visible: true,
        geojson: { type: 'FeatureCollection', features },
        sourceAttribution: 'Synthetic benchmark — not official airspace data' };
    const json = stamp(() => JSON.stringify(command));
    const compressed = stamp(() => gzipSync(Buffer.from(json.value, 'utf8')).toString('base64'));
    const frameLimit = 96 * 1024;
    const plainFrames = Math.ceil(json.value.length / frameLimit) + 2;
    const gzipFrames = Math.ceil(compressed.value.length / frameLimit) + 2;
    const events = [];
    let received;
    let parsed;
    const bridge = createBridge({ sessionId: 'bench', send: raw => events.push(JSON.parse(raw)),
        execute: async value => { received = value; return {}; },
        onTransferParsed: value => { parsed = value; } });
    const frame = (type, extra) => bridge.receive(JSON.stringify({
        version: 1, sessionId: 'bench', requestId: '1', type, ...extra }));
    const transferStart = performance.now();
    frame('transfer-start', {commandType: 'set-uas-zones', encoding: 'gzip-base64',
        length: compressed.value.length, originalLength: json.value.length,
        originalBytes: Buffer.byteLength(json.value, 'utf8') });
    for (let i = 0, pos = 0; pos < compressed.value.length; i++, pos += frameLimit) {
        frame('transfer-chunk', {index: i, data: compressed.value.slice(pos, pos + frameLimit)});
    }
    frame('transfer-complete');
    for (let count = 0; !events.length && count < 200; count++) {
        await new Promise(resolve => setTimeout(resolve, 10));
    }
    const elapsed = +(performance.now() - transferStart).toFixed(2);
    bridge.dispose();
    if (!received || events.at(-1)?.ok !== true ||
        received.geojson.features.length !== features.length) {
        throw new Error('Benchmark transfer failed data integrity check');
    }
    const summary = {
        environment: `Node ${process.version} (synthetic; no real WebView)`,
        features: features.length,
        jsonCharacters: json.value.length,
        gzipBase64Characters: compressed.value.length,
        predictedNativeFrameCalls: { json: plainFrames, gzipBase64: gzipFrames,
            reductionPct: +((1 - gzipFrames / plainFrames) * 100).toFixed(1) },
        encodeJsonMs: json.ms, gzipEncodeUtf8Base64Ms: compressed.ms,
        bridgeDecodeAndParseMs: elapsed,
        browserLikeDecodeMs: parsed?.decodeMs,
        jsonParseMs: parsed?.parseMs,
        cesiumImportMs: 'not measured (requires live Cesium viewer)',
        platformTransportMs: 'not measured (requires actual Flutter/WebView)',
    };
    console.log(JSON.stringify(summary, null, 2));
}
run().catch(error => { console.error(error); process.exitCode = 1; });
