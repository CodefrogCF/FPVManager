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
        restoreCamera, isTerrainReady, onState }) {
        let active = false, pending = false, operation = 0, abort = null, saved = null;
        let position = null, heading = 0, pitch = 0, height = null;
        let stickForward = 0, stickRight = 0;
        const keys = new Set();
        const status = () => ({ active, pending, position: position && { ...position }, heading, pitch, height });
        function stop(reason = null) {
            const wasRunning = active || pending;
            operation++;
            abort?.abort(); abort = null;
            keys.clear();
            stickForward = stickRight = 0;
            active = pending = false;
            if (saved) restoreCamera(saved);
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
                position = { latitude: point.latitude, longitude: point.longitude };
                heading = saved.heading || 0; pitch = 0; height = sampled;
                active = true; pending = false;
                applyPose({ ...position, height: height + 2, heading, pitch });
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
            const next = step(position, heading, forward, right, seconds);
            if (!validPosition(next)) return;
            const ground = renderedHeight(next);
            // Never walk into unloaded terrain or invent an ellipsoid-ground height.
            if (Number.isFinite(ground)) { position = next; height = ground; }
            applyPose({ ...position, height: height + 2, heading, pitch });
        }
        function look(dx, dy) {
            if (!active || !Number.isFinite(dx) || !Number.isFinite(dy)) return;
            heading = ((heading + dx * 0.004) % (2 * Math.PI) + 2 * Math.PI) % (2 * Math.PI);
            pitch = clamp(pitch - dy * 0.004, -85 * radians, 85 * radians);
        }
        return { start, stop, tick, look, status,
            key(key, down) { if (down && active) keys.add(key); else keys.delete(key); },
            stick(forward, right) {
                if (!active || !Number.isFinite(forward) || !Number.isFinite(right)) return;
                const length = Math.max(1, Math.hypot(forward, right));
                stickForward = forward / length; stickRight = right / length;
            },
            clearKeys() { keys.clear(); stickForward = stickRight = 0; } };
    }

    return { createWalker, bindControls: controls.bindControls, step };
});
