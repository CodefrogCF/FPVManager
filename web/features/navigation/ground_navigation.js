(function (root, factory) {
    const controls = typeof module === "object" && module.exports
        ? require("./navigation_controls.js") : root.FPVNavigationControls;
    const api = factory(controls);
    if (typeof module === "object" && module.exports) module.exports = api;
    else root.FPVGroundNavigation = api;
})(typeof globalThis !== "undefined" ? globalThis : this, function (controls) {
    "use strict";
    const radians = Math.PI / 180;
    const clamp = (value, min, max) => Math.max(min, Math.min(max, value));
    // Cesium retains previously seen tiles in this cache. Preloading siblings
    // also covers adjacent terrain beyond the camera's current field of view.
    const groundTileCacheSize = 512;

    function createTerrainCache(globe) {
        let previous;
        return {
            start() {
                if (previous) return;
                const { tileCacheSize, preloadAncestors, preloadSiblings } = globe;
                previous = { tileCacheSize, preloadAncestors, preloadSiblings };
                globe.tileCacheSize = Math.max(tileCacheSize, groundTileCacheSize);
                globe.preloadAncestors = true;
                globe.preloadSiblings = true;
            },
            stop() {
                if (!previous) return;
                Object.assign(globe, previous);
                previous = undefined;
            }
        };
    }

    function validPosition(point) {
        return point && Number.isFinite(point.latitude) && Number.isFinite(point.longitude) &&
            Math.abs(point.latitude) < 89.9 && Math.abs(point.longitude) <= 180;
    }

    // Small walking steps on WGS84. Normalise diagonal speed and dateline wrap.
    function step(position, heading, forward, right, seconds) {
        const magnitude = Math.max(1, Math.hypot(forward, right));
        const distance = 3 * clamp(seconds, 0, 0.1) / magnitude;
        const north = (Math.cos(heading) * forward - Math.sin(heading) * right) * distance;
        const east = (Math.sin(heading) * forward + Math.cos(heading) * right) * distance;
        const latitude = position.latitude + north / 6378137 / radians;
        const longitude = ((position.longitude + east /
            (6378137 * Math.cos(position.latitude * radians)) / radians + 540) % 360) - 180;
        return { latitude, longitude };
    }

    function createWalker({ sampleHeight, renderedHeight, captureCamera, applyPose,
        restoreCamera, isTerrainReady, onState, terrainCache }) {
        let active = false, pending = false, operation = 0, abort = null, saved = null;
        let position = null, heading = 0, pitch = 0, height = null, lastPose = null;
        let stickForward = 0, stickRight = 0;
        const keys = new Set();
        const status = () => ({ active, pending, position: position && { ...position }, heading, pitch, height });
        function updatePose(force = false) {
            const eye = height + 2;
            if (!force && lastPose?.latitude === position.latitude && lastPose.longitude === position.longitude &&
                lastPose.height === eye && lastPose.heading === heading && lastPose.pitch === pitch) return;
            lastPose = { ...position, height: eye, heading, pitch };
            applyPose(lastPose);
        }
        function stop(reason = null) {
            const wasRunning = active || pending;
            operation++;
            abort?.abort(); abort = null;
            keys.clear();
            stickForward = stickRight = 0;
            active = pending = false;
            lastPose = null;
            if (saved) {
                terrainCache?.stop();
                restoreCamera(saved);
            }
            saved = null;
            if (wasRunning) onState({ active, pending, reason });
        }
        async function start(point, signal) {
            if (!validPosition(point)) throw new Error("Invalid ground-view position (polar regions unsupported)");
            if (!isTerrainReady()) throw new Error("Detailed terrain is required for ground view");
            stop();
            const token = ++operation;
            const request = abort = new AbortController();
            const cancel = () => { if (token === operation) stop(); };
            signal.addEventListener("abort", cancel, { once: true });
            pending = true;
            onState({ active: false, pending: true, reason: null });
            try {
                signal.throwIfAborted();
                const sampled = await sampleHeight(point, request.signal);
                signal.throwIfAborted(); request.signal.throwIfAborted();
                if (token !== operation || !isTerrainReady()) throw new Error("Ground view cancelled");
                if (!Number.isFinite(sampled)) throw new Error("No terrain height at the spawn point");
                saved = captureCamera();
                terrainCache?.start();
                position = { latitude: point.latitude, longitude: point.longitude };
                heading = saved.heading || 0; pitch = 0; height = sampled;
                active = true; pending = false;
                updatePose();
                onState({ active: true, pending: false, reason: null });
                return {};
            } catch (error) {
                if (token !== operation) return { cancelled: true };
                if (token === operation) stop("Unable to enter ground view");
                throw error;
            } finally {
                signal.removeEventListener("abort", cancel);
            }
        }
        function tick(seconds) {
            if (!active) return;
            if (!isTerrainReady()) { stop("Terrain unavailable; returned to globe view"); return; }
            const forward = Number(keys.has("ArrowUp") || keys.has("w")) - Number(keys.has("ArrowDown") || keys.has("s")) + stickForward;
            const right = Number(keys.has("ArrowRight") || keys.has("d")) - Number(keys.has("ArrowLeft") || keys.has("a")) + stickRight;
            const next = forward || right ? step(position, heading, forward, right, seconds) : position;
            if (!validPosition(next)) return;
            const ground = renderedHeight(next);
            // Never walk into unloaded terrain or invent an ellipsoid-ground height.
            if (Number.isFinite(ground)) { position = next; height = ground; }
            updatePose();
        }
        function look(dx, dy) {
            if (!active || !Number.isFinite(dx) || !Number.isFinite(dy)) return;
            heading = ((heading + dx * 0.004) % (2 * Math.PI) + 2 * Math.PI) % (2 * Math.PI);
            pitch = clamp(pitch - dy * 0.004, -85 * radians, 85 * radians);
        }
        return { start, stop, tick, look, status,
            get active() { return active; },
            refreshPose() { if (active) updatePose(true); },
            key(key, down) { if (down && active) keys.add(key); else keys.delete(key); },
            stick(forward, right) {
                if (!active || !Number.isFinite(forward) || !Number.isFinite(right)) return;
                const length = Math.max(1, Math.hypot(forward, right));
                stickForward = forward / length; stickRight = right / length;
            },
            clearKeys() { keys.clear(); stickForward = stickRight = 0; } };
    }

    return { createWalker, createTerrainCache, bindControls: controls.bindControls, step };
});
