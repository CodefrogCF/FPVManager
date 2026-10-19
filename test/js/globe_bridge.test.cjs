const test = require('node:test');
const assert = require('node:assert/strict');
const { createBridge } = require('../../web/globe_bridge.js');
const tick = () => new Promise(resolve => setImmediate(resolve));

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
