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

    function createTerrainManager({ createProvider, createFallback, applyProvider,
        onStatus, onWarning = () => {}, offlineReason = () => null, probe = async () => {},
        initializationTimeoutMs = 8000, sampleTimeoutMs = 12000, tileTimeoutMs = 12000 }) {
        let provider = createFallback();
        let state = "loading", reason = null, disposed = false;
        let generation = new AbortController(), removeErrorListener = null, pending = null;
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
                if (state !== "offline" || reason !== offline) fallback("offline", offline);
            } else if (state === "offline") {
                publish("unavailable", "networkRestored");
            }
        }
        function retry(commandSignal) {
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
                next.requestTileGeometry = (...args) => {
                    const key = `${args[2]}/${args[0]}/${args[1]}`;
                    const response = requestTile(...args);
                    if (response === undefined) return undefined;
                    const cancel = () => {
                        try { args[3]?.cancelFunction?.(); } catch (_) { /* Already settled. */ }
                    };
                    attemptGeneration.signal.addEventListener("abort", cancel, { once: true });
                    if (attemptGeneration.signal.aborted) cancel();
                    return bounded(() => response, tileTimeoutMs, [attemptGeneration.signal]).then(tile => {
                        if (current()) recovered(key);
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
            invalidate();
        }
        return { retry, networkChanged, sample, dispose, status,
            get hasWarning() { return warning; },
            get provider() { return provider; } };
    }
    return { createTerrainManager };
});
