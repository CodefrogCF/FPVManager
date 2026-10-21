(function (root, factory) {
    const api = factory();
    if (typeof module === "object" && module.exports) module.exports = api;
    else root.FPVGroundNavigation = api;
})(typeof globalThis !== "undefined" ? globalThis : this, function () {
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
        const keys = new Set();
        const status = () => ({ active, pending, position: position && { ...position }, heading, pitch, height });
        function stop(reason = null) {
            const wasRunning = active || pending;
            operation++;
            abort?.abort(); abort = null;
            keys.clear();
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
            const forward = Number(keys.has("ArrowUp")) - Number(keys.has("ArrowDown"));
            const right = Number(keys.has("ArrowRight")) - Number(keys.has("ArrowLeft"));
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
            clearKeys() { keys.clear(); } };
    }

    function bindControls(walker, canvas, panel, host = window, doc = document) {
        const cleanups = [];
        let drag = null;
        function listen(target, event, handler, options) {
            target.addEventListener(event, handler, options);
            cleanups.push(() => target.removeEventListener(event, handler, options));
        }
        canvas.tabIndex = 0;
        listen(canvas, "keydown", event => {
            if (!walker.status().active) return;
            if (event.key.startsWith("Arrow")) { event.preventDefault(); walker.key(event.key, true); }
            if (event.key === "Escape") { event.preventDefault(); walker.stop(); }
        });
        listen(canvas, "keyup", event => {
            if (event.key.startsWith("Arrow") && walker.status().active) event.preventDefault();
            walker.key(event.key, false);
        });
        listen(canvas, "blur", () => { walker.clearKeys(); drag = null; });
        listen(host, "blur", () => { walker.clearKeys(); drag = null; });
        listen(doc, "visibilitychange", () => { if (doc.hidden) walker.stop("Ground view paused"); });
        listen(host, "pagehide", () => walker.stop());
        listen(canvas, "pointerdown", event => {
            if (!walker.status().active || event.button !== 0) return;
            canvas.focus(); canvas.setPointerCapture(event.pointerId);
            drag = { id: event.pointerId, x: event.clientX, y: event.clientY };
        });
        listen(canvas, "pointermove", event => {
            if (!drag || drag.id !== event.pointerId) return;
            walker.look(event.clientX - drag.x, event.clientY - drag.y);
            drag.x = event.clientX; drag.y = event.clientY;
        });
        for (const event of ["pointerup", "pointercancel", "lostpointercapture"]) {
            listen(canvas, event, () => { drag = null; });
        }
        for (const button of panel.querySelectorAll("[data-walk]")) {
            const key = button.dataset.walk;
            listen(button, "pointerdown", event => {
                event.preventDefault(); button.setPointerCapture(event.pointerId);
                walker.key(key, true);
            });
            for (const event of ["pointerup", "pointercancel", "lostpointercapture"]) {
                listen(button, event, () => walker.key(key, false));
            }
        }
        listen(panel.querySelector("[data-exit]"), "click", () => walker.stop());
        return () => { walker.stop(); for (const cleanup of cleanups) cleanup(); };
    }
    return { createWalker, bindControls, step };
});
