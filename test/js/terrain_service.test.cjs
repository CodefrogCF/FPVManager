const test = require('node:test');
const assert = require('node:assert/strict');
const { createTerrainManager } = require('../../web/terrain_service.js');
const tick = () => new Promise(resolve => setImmediate(resolve));
function deferred() { let resolve, reject; const promise = new Promise((a, b) => { resolve = a; reject = b; }); return { promise, resolve, reject }; }
function provider() {
    const listeners = new Set();
    return { requestTileGeometry: async () => ({}), errorEvent: {
        addEventListener: listener => { listeners.add(listener); return () => listeners.delete(listener); },
        fail: () => { const error = { retry: true }; for (const listener of [...listeners]) listener(error); return error; },
        get listenerCount() { return listeners.size; }
    } };
}
function peer(options = {}) {
    const applied = [], statuses = [];
    const manager = createTerrainManager({ createProvider: async () => provider(),
        createFallback: () => ({ flat: true }), applyProvider: value => applied.push(value),
        onStatus: value => statuses.push(value), ...options });
    return { manager, applied, statuses };
}

test('initialization and probe failures retain a usable flat map; retry can recover', async () => {
    let attempts = 0, probeFails = true;
    const { manager, applied } = peer({ createProvider: async () => {
        if (++attempts === 1) throw new Error('Metadata unavailable');
        return provider();
    }, probe: async () => { if (probeFails) throw new Error('Root tile missing'); } });
    try {
        assert.equal((await manager.retry()).state, 'unavailable');
        assert.equal((await manager.retry()).state, 'unavailable');
        assert.equal(applied.at(-1).flat, true);
        probeFails = false;
        assert.equal((await manager.retry()).state, 'ready');
        assert.equal(manager.provider.errorEvent.listenerCount, 1);
        assert.equal(attempts, 3);
    } finally { manager.dispose(); }
});

test('missing tile event switches to flat, stops automatic retry and invalidates a pending height', async () => {
    const { manager } = peer();
    try {
        await manager.retry();
        const old = manager.provider, height = deferred();
        const query = manager.sample(() => height.promise, new AbortController().signal);
        const rejected = assert.rejects(query, /cancelled/);
        const error = old.errorEvent.fail();
        await rejected;
        assert.equal(error.retry, false);
        assert.deepEqual(manager.status(), { state: 'unavailable', reason: 'tileFailed' });
        assert.equal(manager.provider.flat, true);
        assert.equal(old.errorEvent.listenerCount, 0);
        await manager.retry();
        height.resolve(1200); await tick();
        old.errorEvent.fail();
        assert.equal(manager.status().state, 'ready');
    } finally { manager.dispose(); }
});

test('simultaneous retries share one bounded attempt and ignore its late timeout result', async () => {
    const first = deferred(); let attempts = 0;
    const { manager } = peer({ initializationTimeoutMs: 20,
        createProvider: () => ++attempts === 1 ? first.promise : Promise.resolve(provider()) });
    try {
        const one = manager.retry(), two = manager.retry();
        assert.equal(one, two);
        assert.equal((await one).state, 'unavailable');
        await manager.retry(); const current = manager.provider;
        const obsolete = provider(); first.resolve(obsolete); await tick();
        assert.equal(manager.provider, current);
        assert.equal(obsolete.errorEvent.listenerCount, 0);
        assert.equal(attempts, 2);
    } finally { manager.dispose(); }
});

test('offline transition invalidates initialization; online is a hint and requires an explicit retry', async () => {
    let offline = null, attempts = 0;
    const pending = deferred();
    const { manager } = peer({ offlineReason: () => offline,
        createProvider: () => ++attempts === 1 ? pending.promise : Promise.resolve(provider()) });
    try {
        const connecting = manager.retry(); await tick();
        offline = 'networkOffline'; manager.networkChanged(); await connecting;
        assert.equal(manager.status().state, 'offline');
        pending.resolve(provider()); await tick();
        await manager.retry(); assert.equal(attempts, 1);
        offline = null; manager.networkChanged();
        assert.deepEqual(manager.status(), { state: 'unavailable', reason: 'networkRestored' });
        assert.equal(attempts, 1);
        await manager.retry(); assert.equal(manager.status().state, 'ready');
    } finally { manager.dispose(); }
});

test('diagnostic mode performs no provider I/O, including repeated retries', async () => {
    let attempts = 0;
    const { manager } = peer({ offlineReason: () => 'diagnosticOffline',
        createProvider: () => { attempts++; return provider(); } });
    try {
        await manager.retry(); await manager.retry();
        assert.equal(attempts, 0);
        await assert.rejects(manager.sample(() => 1, new AbortController().signal), /unavailable/);
    } finally { manager.dispose(); }
});

test('height failures and stalls are bounded and cannot silently return a flat height', async () => {
    const { manager } = peer({ sampleTimeoutMs: 20 });
    try {
        await manager.retry();
        await assert.rejects(manager.sample(() => Promise.reject(new Error('HTTP 404')),
            new AbortController().signal), /404/);
        assert.equal(manager.status().state, 'unavailable');
        await manager.retry();
        await assert.rejects(manager.sample(() => new Promise(() => {}),
            new AbortController().signal), /timed out/);
        assert.equal(manager.status().state, 'unavailable');
    } finally { manager.dispose(); }
});

test('rendered tile stalls time out without height sampling; scheduling deferral remains undefined', async () => {
    const next = provider(); let deferred = true, cancelled = false;
    next.requestTileGeometry = () => deferred ? undefined : new Promise(() => {});
    const { manager } = peer({ createProvider: async () => next, tileTimeoutMs: 20 });
    try {
        await manager.retry();
        assert.equal(manager.provider.requestTileGeometry(0,0,0), undefined);
        assert.equal(manager.status().state, 'ready');
        deferred = false;
        await assert.rejects(manager.provider.requestTileGeometry(0,0,0,
            { cancel: () => { cancelled = true; } }), /timed out/);
        assert.equal(manager.status().state, 'unavailable');
        assert.equal(cancelled, true);
    } finally { manager.dispose(); }
});

test('cancelling a height query leaves healthy terrain intact', async () => {
    const { manager } = peer();
    try {
        await manager.retry();
        const abort = new AbortController(), height = deferred();
        const query = manager.sample(() => height.promise, abort.signal);
        const rejected = assert.rejects(query, /abort/i);
        abort.abort(); await rejected;
        height.resolve(42); await tick();
        assert.equal(manager.status().state, 'ready');
        assert.equal(await manager.sample(async () => 1234, new AbortController().signal), 1234);
    } finally { manager.dispose(); }
});

test('a renderer-cancelled tile is not converted into a timeout outage', async () => {
    const next = provider(), response = deferred();
    next.requestTileGeometry = () => response.promise;
    const { manager } = peer({ createProvider: async () => next, tileTimeoutMs: 20 });
    try {
        await manager.retry();
        const tile = manager.provider.requestTileGeometry(0,0,0,{cancelled:true});
        await new Promise(resolve => setTimeout(resolve, 35));
        assert.equal(manager.status().state, 'ready');
        response.resolve({}); await tile;
        assert.equal(manager.status().state, 'ready');
    } finally { manager.dispose(); }
});

test('cancelled retry and disposal reject late provider changes and detach listeners', async () => {
    const first = deferred(); let calls = 0;
    const { manager, statuses } = peer({ createProvider: () => ++calls === 1 ? first.promise : Promise.resolve(provider()) });
    const abort = new AbortController();
    const pending = manager.retry(abort.signal); await tick(); abort.abort(); await pending;
    assert.equal(manager.status().state, 'unavailable');
    first.resolve(provider()); await tick();
    await manager.retry(); const current = manager.provider;
    const count = statuses.length;
    manager.dispose();
    assert.equal(current.errorEvent.listenerCount, 0);
    current.errorEvent.fail(); manager.networkChanged();
    assert.equal(statuses.length, count);
    await assert.rejects(manager.retry(), /disposed/);
});
