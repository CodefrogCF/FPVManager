(function (root, factory) {
    const api = factory();
    if (typeof module === "object" && module.exports) module.exports = api;
    else root.FPVTerrain = api;
})(typeof globalThis !== "undefined" ? globalThis : this, function () {
    "use strict";

    // Timed-out third-party I/O may finish later, but cannot change the viewer.
    async function bounded(work, timeoutMs, signals) {
        let timer;
        const cleanups = [];
        try {
            return await Promise.race([
                Promise.resolve().then(() => {
                    for (const signal of signals) signal.throwIfAborted();
                    return work();
                }),
                new Promise((_, reject) => {
                    timer = setTimeout(() => {
                        const error = new Error("Terrain request timed out");
                        error.name = "TerrainTimeoutError";
                        reject(error);
                    }, timeoutMs);
                    for (const signal of signals) {
                        const abort = () => reject(new Error("Terrain operation cancelled"));
                        if (signal.aborted) abort();
                        else {
                            signal.addEventListener("abort", abort, { once: true });
                            cleanups.push(() => signal.removeEventListener("abort", abort));
                        }
                    }
                })
            ]);
        } finally {
            clearTimeout(timer);
            for (const cleanup of cleanups) cleanup();
        }
    }

    async function probeRootTiles(provider, signal, tiles) {
        const scheme = provider.tilingScheme;
        tiles ??= Array.from({ length: scheme.getNumberOfYTilesAtLevel(0) }, (_, y) =>
            Array.from({ length: scheme.getNumberOfXTilesAtLevel(0) }, (_, x) => [x, y, 0])).flat();
        await Promise.all(tiles.map(async coordinates => {
            let request;
            while (request === undefined) {
                signal.throwIfAborted();
                request = provider.requestTileGeometry(...coordinates);
                if (request === undefined) await new Promise(resolve => setTimeout(resolve, 50));
            }
            const tile = await request;
            signal.throwIfAborted();
            if (!tile) throw new Error("Terrain probe returned no tile");
        }));
    }

    function createTerrainManager({ createProvider, createFallback, applyProvider,
        onStatus, onWarning = () => {}, offlineReason = () => null, probe = async () => {},
        initializationTimeoutMs = 8000, sampleTimeoutMs = 12000, tileTimeoutMs = 12000,
        startupRetryDelaysMs = [750, 2000] }) {
        let provider = createFallback();
        let state = "loading", reason = null, disposed = false;
        let generation = new AbortController(), removeErrorListener = null, pending = null;
        let startupEpoch = 0, startupTimer = null;
        const failedTiles = new Set(), retries = new Map();
        let warning = false;
        function warn(key) {
            if (failedTiles.size < 128) failedTiles.add(key);
            if (!warning) { warning = true; onWarning(true); }
        }
        function recovered(key) {
            failedTiles.delete(key); retries.delete(key);
            if (warning && !failedTiles.size) { warning = false; onWarning(false); }
        }

        const status = () => ({ state, reason });
        function publish(nextState, nextReason = null) {
            if (state === nextState && reason === nextReason) return;
            state = nextState;
            reason = nextReason;
            onStatus(status());
        }
        function invalidate() {
            generation.abort();
            generation = new AbortController();
            removeErrorListener?.();
            removeErrorListener = null;
            pending = null;
            failedTiles.clear(); retries.clear();
            if (warning) { warning = false; if (!disposed) onWarning(false); }
        }
        function fallback(nextState, nextReason) {
            invalidate();
            provider = createFallback();
            applyProvider(provider);
            publish(nextState, nextReason);
        }
        function networkChanged() {
            if (disposed) return;
            const offline = offlineReason();
            if (offline) {
                stopStartupRecovery();
                if (state !== "offline" || reason !== offline) fallback("offline", offline);
            } else if (state === "offline") {
                publish("unavailable", "networkRestored");
            }
        }
        function connect(commandSignal) {
            if (disposed) return Promise.reject(new Error("Terrain manager disposed"));
            if (pending) return pending;
            const offline = offlineReason();
            if (offline) {
                networkChanged();
                return Promise.resolve(status());
            }
            fallback("loading", null);
            const attemptGeneration = generation;
            const current = () => !disposed && generation === attemptGeneration;
            const attempt = bounded(async () => {
                const next = await createProvider();
                attemptGeneration.signal.throwIfAborted();
                // Cesium's request scheduling may defer with undefined. Preserve
                // that contract, but bound real requests even without a height query.
                const requestTile = next.requestTileGeometry.bind(next);
                // Keep the few essential root tiles validated by the startup
                // probe. Requesting them again can fail after a successful probe;
                // Cesium cannot upsample a failed root, leaving only the sky.
                const rootTiles = new Map();
                next.requestTileGeometry = (...args) => {
                    const key = `${args[2]}/${args[0]}/${args[1]}`;
                    if (rootTiles.has(key)) return Promise.resolve(rootTiles.get(key));
                    const response = requestTile(...args);
                    if (response === undefined) return undefined;
                    const cancel = () => {
                        try { args[3]?.cancelFunction?.(); } catch (_) { /* Already settled. */ }
                    };
                    attemptGeneration.signal.addEventListener("abort", cancel, { once: true });
                    if (attemptGeneration.signal.aborted) cancel();
                    return bounded(() => response, tileTimeoutMs, [attemptGeneration.signal]).then(tile => {
                        if (current() && tile) {
                            if (args[2] === 0) rootTiles.set(key, tile);
                            recovered(key);
                        }
                        return tile;
                    }).catch(error => {
                        if (!args[3]?.cancelled && current()) warn(key);
                        if (error.name === "TerrainTimeoutError") {
                            // Cesium 1.145 marks requests cancelled before its
                            // scheduler aborts their I/O. Preserve that cancellation
                            // path rather than turning a camera-move cancellation
                            // into a provider outage.
                            if (args[3]?.cancelled) return response;
                            cancel();
                        }
                        throw error;
                    }).finally(() => attemptGeneration.signal.removeEventListener("abort", cancel));
                };
                await probe(next, attemptGeneration.signal);
                return next;
            }, initializationTimeoutMs, [attemptGeneration.signal, ...(commandSignal ? [commandSignal] : [])]).then(next => {
                if (!current()) return status();
                provider = next;
                removeErrorListener = next.errorEvent.addEventListener(error => {
                    if (!current()) { error.retry = false; return; }
                    const key = [error.x,error.y,error.level].every(Number.isInteger)
                        ? `${error.level}/${error.x}/${error.y}` : 'unknown';
                    warn(key);
                    const count = retries.get(key) ?? 0;
                    error.retry = key !== 'unknown' && count < 2 && retries.size < 128;
                    if (error.retry) retries.set(key,count+1);
                });
                applyProvider(next);
                if (current()) publish("ready");
                return status();
            }).catch(() => {
                if (current()) fallback("unavailable", "connectionFailed");
                return status();
            }).finally(() => {
                if (pending === attempt) pending = null;
            });
            pending = attempt;
            return attempt;
        }
        function stopStartupRecovery() {
            startupEpoch++;
            clearTimeout(startupTimer);
            startupTimer = null;
        }
        function retry(commandSignal) {
            stopStartupRecovery();
            return connect(commandSignal);
        }
        function initialize() {
            stopStartupRecovery();
            const epoch = startupEpoch;
            let retries = 0;
            const attempt = () => connect().then(result => {
                if (!disposed && epoch === startupEpoch && !offlineReason() &&
                    result.state === "unavailable" && retries < startupRetryDelaysMs.length) {
                    startupTimer = setTimeout(() => {
                        startupTimer = null;
                        if (!disposed && epoch === startupEpoch && !offlineReason()) void attempt();
                    }, startupRetryDelaysMs[retries++]);
                }
                return result;
            });
            // Do not delay the usable fallback while retrying a transient startup
            // failure. Manual retry, offline mode and disposal cancel this budget.
            return attempt();
        }
        async function sample(work, commandSignal) {
            if (disposed || state !== "ready") throw new Error("Detailed terrain data unavailable");
            const sampledProvider = provider, sampledGeneration = generation;
            try {
                // Background scans have no command signal; provider changes
                // still cancel them through the mandatory generation signal.
                const result = await bounded(() => work(sampledProvider), sampleTimeoutMs,
                    [sampledGeneration.signal, ...(commandSignal ? [commandSignal] : [])]);
                commandSignal?.throwIfAborted();
                if (disposed || generation !== sampledGeneration || state !== "ready") {
                    throw new Error("Terrain changed during the request");
                }
                return result;
            } catch (error) {
                commandSignal?.throwIfAborted();
                // A missing profile tile or a timed-out height query does not
                // invalidate already rendered terrain in the rest of the view.
                throw error;
            }
        }
        function dispose() {
            if (disposed) return;
            disposed = true;
            stopStartupRecovery();
            invalidate();
        }
        return { initialize, retry, networkChanged, sample, dispose, status,
            get hasWarning() { return warning; },
            get provider() { return provider; } };
    }
    return { createTerrainManager, probeRootTiles };
});
