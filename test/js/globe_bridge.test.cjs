const test = require('node:test');
const assert = require('node:assert/strict');
const { createBridge } = require('../../web/globe_bridge.js');
const tick = () => new Promise(resolve => setImmediate(resolve));
const { gzipSync } = require('node:zlib');

function peer(execute = async () => ({}), overrides = {}) {
    const events = [];
    const bridge = createBridge({ sessionId: 'page', execute,
        send: raw => events.push(JSON.parse(raw)),
        limits: { frame: 2048, command: 4096, transfers: 2, pending: 4,
            idleMs: 100, commandMs: 200, ...overrides } });
    const send = (id, type, data = {}) => bridge.receive(JSON.stringify({
        version: 1, sessionId: 'page', requestId: String(id), type, ...data }));
    return { bridge, events, send };
}

test('correlates concurrent success/error responses and rejects duplicate execution', async () => {
    const pending = new Map();
    let calls = 0;
    const p = peer(command => { calls++; return new Promise((resolve, reject) =>
        pending.set(command.requestId, { resolve, reject })); });
    try {
        p.send(1, 'first'); p.send(2, 'second'); p.send(1, 'first');
        pending.get('2').resolve({ value: 2 }); await tick();
        pending.get('1').reject(new Error('Failed')); await tick();
        assert.equal(calls, 2);
        assert.deepEqual(p.events.map(e => [e.requestId, e.commandType, e.ok]),
            [['2', 'second', true], ['1', 'first', false]]);
        assert.equal(p.events[0].version, 1);
        assert.equal(p.events[0].sessionId, 'page');
        assert.ok(p.events[1].eventSequence > p.events[0].eventSequence);
        p.send(2, 'second'); await tick(); assert.equal(calls, 2);
    } finally { p.bridge.dispose(); }
});

test('validates envelopes and never executes malformed or wrong-session commands', async () => {
    let calls = 0;
    const p = peer(async () => { calls++; });
    try {
        for (const value of ['{', '[]', 'x'.repeat(2049)]) p.bridge.receive(value);
        p.send(1, 'test', { version: 2 }); p.send(2, 'test', { sessionId: 'old' });
        p.send(3, 'test', { requestId: {} }); p.send(4, 'test', { type: 7 });
        await tick(); assert.equal(calls, 0); assert.equal(p.events.length, 0);
    } finally { p.bridge.dispose(); }
});

test('assembles indexed transfers and rejects missing/out-of-order data', async () => {
    const commands = [];
    const p = peer(async command => { commands.push(command); });
    try {
        const raw = JSON.stringify({ version: 1, sessionId: 'page', requestId: '1',
            type: 'data', value: 'é🐸'.repeat(50) });
        p.send(1, 'transfer-start', { commandType: 'data', length: raw.length });
        p.send(1, 'transfer-chunk', { index: 0, data: raw.slice(0, 100) });
        p.send(1, 'transfer-chunk', { index: 1, data: raw.slice(100) });
        p.send(1, 'transfer-complete'); await tick();
        assert.equal(commands[0].value, 'é🐸'.repeat(50));
        assert.equal(p.events.at(-1).ok, true);

        p.send(2, 'transfer-start', { commandType: 'data', length: 20 });
        p.send(2, 'transfer-chunk', { index: 1, data: 'bad' });
        p.send(2, 'transfer-complete'); await tick();
        assert.equal(commands.length, 1);
        assert.equal(p.events.at(-1).ok, false);
        assert.equal(p.events.at(-1).commandType, 'data');
    } finally { p.bridge.dispose(); }
});

test('bounds total transfer buffers and frees them on cancel and failure', async () => {
    const p = peer();
    try {
        p.send(1, 'transfer-start', { commandType: 'data', length: 3000 });
        p.send(2, 'transfer-start', { commandType: 'data', length: 3000 });
        assert.equal(p.events.at(-1).ok, false);
        p.send(1, 'cancel-command');
        p.send(3, 'transfer-start', { commandType: 'data', length: 3000 });
        p.send(3, 'transfer-complete');
        assert.match(p.events.at(-1).error, /Incomplete/);
        p.send(4, 'transfer-start', { commandType: 'data', length: 4097 });
        assert.match(p.events.at(-1).error, /limit/);
    } finally { p.bridge.dispose(); }
});

test('incomplete transfers expire and cannot be completed afterwards', async () => {
    let calls = 0;
    const p = peer(async () => { calls++; }, { idleMs: 10 });
    try {
        p.send(1, 'transfer-start', { commandType: 'data', length: 100 });
        await new Promise(resolve => setTimeout(resolve, 30));
        assert.match(p.events.at(-1).error, /timed out/);
        p.send(1, 'transfer-complete'); await tick(); assert.equal(calls, 0);
    } finally { p.bridge.dispose(); }
});

test('cancel/dispose abort async work and suppress its late result', async () => {
    let resolve, signal;
    const p = peer((_, value) => { signal = value; return new Promise(r => { resolve = r; }); });
    p.send(1, 'async'); p.send(1, 'cancel-command');
    assert.equal(signal.aborted, true);
    resolve({ stale: true }); await tick(); assert.equal(p.events.length, 0);
    p.bridge.dispose(); p.send(2, 'async'); await tick(); assert.equal(p.events.length, 0);
});

test('limits active requests and times out stalled renderer work', async () => {
    const p = peer(() => new Promise(() => {}), { pending: 1, commandMs: 10 });
    try {
        p.send(1, 'hang'); p.send(2, 'extra');
        assert.equal(p.events.at(-1).ok, false);
        await new Promise(resolve => setTimeout(resolve, 30));
        assert.match(p.events.at(-1).error, /timed out/);
    } finally { p.bridge.dispose(); }
});

test('large UAS transfers report local JSON parse metrics without changing the command', async () => {
    let measurement = null, received = null;
    const bridge = createBridge({
        sessionId: 'page',
        send: () => {},
        execute: async data => { received = data; },
        onTransferParsed: data => { measurement = data; }
    });
    try {
        const raw = JSON.stringify({version:1,sessionId:'page',requestId:'1',
            type:'set-uas-zones', visible:true, geojson:{type:'FeatureCollection',
                features:[{type:'Feature',geometry:{type:'Point',coordinates:[8.1,47.1]},
                    properties:{note:'\"\\'.repeat(1000)}}]}});
        const send = (type, data) => bridge.receive(JSON.stringify({
            version:1,sessionId:'page',requestId:'1',type,...data}));
        send('transfer-start', {commandType:'set-uas-zones',length:raw.length});
        for (let index = 0, start = 0; start < raw.length; index++, start += 512)
            send('transfer-chunk', {index, data:raw.slice(start,start+512)});
        send('transfer-complete', {});
        await tick();
        assert.equal(received.geojson.features[0].properties.note, '\"\\'.repeat(1000));
        assert.equal(measurement.commandType, 'set-uas-zones');
        assert.equal(measurement.characters, raw.length);
        assert.ok(measurement.chunkCount > 1);
        assert.ok(Number.isFinite(measurement.parseMs));
    } finally { bridge.dispose(); }
});

test('broken transfer never reports successful parse timing', async () => {
    const measurements = [];
    const bridge = createBridge({sessionId:'page',send:()=>{},execute:async()=>{},
        onTransferParsed: value => measurements.push(value)});
    try {
        for (const [type, data] of [
            ['transfer-start',{commandType:'set-uas-zones',length:5}],
            ['transfer-chunk',{index:0,data:'abcde'}],
            ['transfer-complete',{}]
        ]) bridge.receive(JSON.stringify({version:1,sessionId:'page',requestId:'1',type,...data}));
        await tick();
        assert.equal(measurements.length,0);
    } finally { bridge.dispose(); }
});

test('infrastructure selection retains dataset provenance without overriding the bridge source', () => {
    const p = peer();
    try {
        p.bridge.emit('infrastructure-selected', {
            kind: 'tunnel', id: 'road:tunnel:0',
            datasetSource: 'ch.swisstopo.swisstlm3d-strassen'
        });
        assert.equal(p.events.length, 1);
        assert.equal(p.events[0].source, 'fpvmanager-globe');
        assert.equal(p.events[0].datasetSource, 'ch.swisstopo.swisstlm3d-strassen');
        assert.equal(p.events[0].type, 'infrastructure-selected');
    } finally { p.bridge.dispose(); }
});

function sendGzip(bridge, requestId, type, command, overrides = {}) {
    const raw = JSON.stringify({ version: 1, sessionId: 'page',
        requestId: String(requestId), type, ...command });
    const compressed = gzipSync(Buffer.from(raw, 'utf8')).toString('base64');
    const start = { encoding: 'gzip-base64', commandType: type,
        length: compressed.length, originalLength: raw.length,
        originalBytes: Buffer.byteLength(raw, 'utf8'), ...overrides };
    const send = (kind, extra = {}) => bridge.receive(JSON.stringify({
        version: 1, sessionId: 'page', requestId: String(requestId), type: kind, ...extra }));
    send('transfer-start', start);
    for (let index = 0, offset = 0; offset < compressed.length; index++, offset += 1024) {
        send('transfer-chunk', { index, data: compressed.slice(offset, offset + 1024) });
    }
    send('transfer-complete');
    return { raw, compressed };
}
const settle = async (predicate, milliseconds = 2000) => {
    for (let i = 0; i < milliseconds / 5; i++) {
        if (predicate()) return;
        await new Promise(resolve => setTimeout(resolve, 5));
    }
    assert.fail('Timed out waiting for renderer acknowledgement');
};

test('gzip UAS transfer preserves geometry, attributes and attribution without proxy', async () => {
    let received = null, metric = null;
    const events = [];
    const bridge = createBridge({ sessionId: 'page',
        send: raw => events.push(JSON.parse(raw)),
        execute: async command => { received = command; return { accepted: true }; },
        onTransferParsed: data => { metric = data; } });
    try {
        const features = Array.from({ length: 8000 }, (_, i) => ({ type: 'Feature',
            geometry: { type: 'Point', coordinates: [8.34 + i * 0.00001, 47.1] },
            properties: { name: 'Zürich / 🎮 ' + i, lowerLimit: 0,
                source: 'Swiss UAS dataset', note: '\\"\n\t'.repeat(4) } }));
        const command = { visible: true, geojson: { type: 'FeatureCollection', features },
            sourceAttribution: 'FOCA, Switzerland ©', downloadedAtUtc: '2026-11-05T12:00:00Z' };
        const { raw, compressed } = sendGzip(bridge, 1, 'set-uas-zones', command);
        await settle(() => events.some(event => event.type === 'command-result'));
        assert.deepEqual(received.geojson, command.geojson);
        assert.equal(received.sourceAttribution, command.sourceAttribution);
        assert.equal(received.downloadedAtUtc, command.downloadedAtUtc);
        assert.equal(metric.transport, 'gzip-base64');
        assert.ok(Number.isFinite(metric.parseMs) && Number.isFinite(metric.decodeMs));
        assert.ok(compressed.length * 3 < raw.length, 'compression must reduce bridge bytes');
        assert.equal(events.at(-1).ok, true);
    } finally { bridge.dispose(); }
});

test('gzip transfers are bounded and corrupt payloads cannot execute', async () => {
    let calls = 0;
    const events = [];
    const bridge = createBridge({ sessionId: 'page',
        send: raw => events.push(JSON.parse(raw)), execute: async () => { calls++; },
        limits: { frame: 2048, command: 4096, transfers: 2, pending: 4,
            idleMs: 1000, commandMs: 1000 } });
    try {
        const raw = JSON.stringify({ version: 1, sessionId: 'page', requestId: '1',
            type: 'set-uas-zones', data: 'a'.repeat(100) });
        const data = gzipSync(raw).toString('base64');
        const send = (id, type, value = {}) => bridge.receive(JSON.stringify({
            version: 1, sessionId: 'page', requestId: String(id), type, ...value }));
        send(1, 'transfer-start', { encoding: 'gzip-base64', commandType: 'set-uas-zones',
            length: data.length, originalLength: raw.length,
            originalBytes: 4097 });
        assert.equal(events.at(-1).ok, false);
        send(2, 'transfer-start', { encoding: 'gzip-base64', commandType: 'set-uas-zones',
            length: data.length, originalLength: raw.length,
            originalBytes: Buffer.byteLength(raw) - 1 });
        send(2, 'transfer-chunk', { index: 0, data });
        send(2, 'transfer-complete');
        await settle(() => events.length >= 2);
        assert.equal(events.at(-1).ok, false);
        assert.match(events.at(-1).error, /size|length/i);
        assert.equal(calls, 0);
        send(3, 'transfer-start', { encoding: 'gzip-base64', commandType: 'set-map-style',
            length: data.length, originalLength: raw.length, originalBytes: Buffer.byteLength(raw) });
        assert.equal(events.at(-1).ok, false);
    } finally { bridge.dispose(); }
});

test('cancellation or disposal during asynchronous gzip decoding never executes stale data', async () => {
    let calls = 0;
    const events = [];
    const bridge = createBridge({ sessionId: 'page',
        send: raw => events.push(JSON.parse(raw)), execute: async () => { calls++; } });
    const send = (id, type) => bridge.receive(JSON.stringify({
        version: 1, sessionId: 'page', requestId: String(id), type }));
    try {
        sendGzip(bridge, 1, 'set-uas-zones', { data: 'a'.repeat(300000) });
        send(1, 'cancel-command');
        await new Promise(resolve => setTimeout(resolve, 70));
        assert.equal(calls, 0);
        assert.equal(events.length, 0, 'cancel must suppress obsolete acknowledgements');
        sendGzip(bridge, 2, 'set-uas-zones', { data: 'a'.repeat(300000) });
        bridge.dispose();
        await new Promise(resolve => setTimeout(resolve, 70));
        assert.equal(calls, 0);
    } finally { bridge.dispose(); }
});

test('the existing JSON transport remains supported with no compression APIs', async () => {
    const events = [], data = [];
    const bridge = createBridge({ sessionId:'page', send:raw=>events.push(JSON.parse(raw)),
        execute:async value=>{ data.push(value); } });
    try {
        const raw = JSON.stringify({ version:1, sessionId:'page', requestId:'1',
            type:'set-uas-zones', geojson:{type:'FeatureCollection',features:[]} });
        for (const [type, payload] of [
            ['transfer-start', { commandType:'set-uas-zones', length:raw.length }],
            ['transfer-chunk', {index:0,data:raw}],
            ['transfer-complete',{}]
        ]) bridge.receive(JSON.stringify({version:1,sessionId:'page',requestId:'1',type,...payload}));
        await tick();
        assert.equal(data[0].geojson.type, 'FeatureCollection');
        assert.equal(events.at(-1).ok, true);
    } finally { bridge.dispose(); }
});

test('negotiated transfer credits enforce an eight-chunk sender window', async () => {
    const events = [];
    const bridge = createBridge({ sessionId:'page',
        send:raw=>events.push(JSON.parse(raw)), execute:async()=>{} });
    try {
        const raw = JSON.stringify({version:1,sessionId:'page',requestId:'1',
            type:'set-uas-zones', data:'a'.repeat(10000)});
        const send = (type,data={})=>bridge.receive(JSON.stringify({
            version:1,sessionId:'page',requestId:'1',type,...data}));
        send('transfer-start',{commandType:'set-uas-zones',length:raw.length,
            flowControl:true});
        for(let index=0,off=0;off<raw.length;index++,off+=700) {
            send('transfer-chunk',{index,data:raw.slice(off,off+700)});
        }
        assert.deepEqual(events.filter(event=>event.type==='transfer-credit')
            .map(event=>event.nextIndex), [16]);
        send('transfer-complete');
        await tick();
        assert.equal(events.at(-1).ok,true);
    } finally {bridge.dispose();}
});
