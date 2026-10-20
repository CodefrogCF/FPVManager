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
        onStatus, offlineReason = () => null, probe = async () => {},
        initializationTimeoutMs = 8000, sampleTimeoutMs = 12000, tileTimeoutMs = 12000 }) {
        let provider = createFallback();
        let state = "loading", reason = null, disposed = false;
        let generation = new AbortController(), removeErrorListener = null, pending = null;

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
        }
        function fallback(nextState, nextReason) {
            invalidate();
            provider = createFallback();
            applyProvider(provider);
            publish(nextState, nextReason);
        }
        function providerFailed(failedProvider) {
            if (!disposed && provider === failedProvider) {
                fallback("unavailable", "tileFailed");
            }
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
                    const response = requestTile(...args);
                    if (response === undefined) return undefined;
                    return bounded(() => response, tileTimeoutMs, []).catch(error => {
                        if (error.name === "TerrainTimeoutError") {
                            // Cesium 1.145 marks requests cancelled before its
                            // scheduler aborts their I/O. Preserve that cancellation
                            // path rather than turning a camera-move cancellation
                            // into a provider outage.
                            if (args[3]?.cancelled) return response;
                            providerFailed(next);
                            args[3]?.cancel?.();
                        }
                        throw error;
                    });
                };
                await probe(next, attemptGeneration.signal);
                return next;
            }, initializationTimeoutMs, [attemptGeneration.signal, ...(commandSignal ? [commandSignal] : [])]).then(next => {
                if (!current()) return status();
                provider = next;
                removeErrorListener = next.errorEvent.addEventListener(error => {
                    // No unbounded automatic retries of a missing/failed tile.
                    error.retry = false;
                    providerFailed(next);
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
                const result = await bounded(() => work(sampledProvider), sampleTimeoutMs,
                    [sampledGeneration.signal, commandSignal]);
                commandSignal.throwIfAborted();
                if (disposed || generation !== sampledGeneration || state !== "ready") {
                    throw new Error("Terrain changed during the request");
                }
                return result;
            } catch (error) {
                commandSignal.throwIfAborted();
                if (!disposed && generation === sampledGeneration) providerFailed(sampledProvider);
                throw error;
            }
        }
        function dispose() {
            if (disposed) return;
            disposed = true;
            invalidate();
        }
        return { retry, networkChanged, sample, dispose, status,
            get provider() { return provider; } };
    }
    return { createTerrainManager };
});
