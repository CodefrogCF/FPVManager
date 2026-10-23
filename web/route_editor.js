(function (root, factory) {
    const api = factory();
    if (typeof module === "object" && module.exports) module.exports = api;
    else root.FPVRouteEditor = api;
})(typeof globalThis !== "undefined" ? globalThis : this, function () {
    "use strict";
    const previewAgl = 30;
    function altitude(point, ground) {
        if (point.height?.reference === "aboveGroundLevel") return ground + point.height.meters;
        if (point.height?.reference === "wgs84Ellipsoid") return point.height.meters;
        return ground + previewAgl;
    }
    function isPreview(point) {
        return !["aboveGroundLevel", "wgs84Ellipsoid"].includes(point.height?.reference);
    }
    function createLayer(Cesium, viewer, sampleHeights, isTerrainReady = () => true, onError = () => {}) {
        let source = null, revision = 0, request = null, records = [], cache = new Map();
        const key = p => `${p.latitude}|${p.longitude}`;
        async function heights(points, signal) {
            const missing = points.filter(p => !cache.has(key(p)));
            if (missing.length) {
                const sampled = await sampleHeights(missing, signal);
                signal.throwIfAborted();
                if (!Array.isArray(sampled) || sampled.length !== missing.length || sampled.some(h => !Number.isFinite(h))) {
                    throw new Error("Route terrain heights unavailable");
                }
                if (cache.size > 20000) cache.clear();
                missing.forEach((point, index) => cache.set(key(point), sampled[index]));
            }
            return points.map(p => cache.get(key(p)));
        }
        function remove() {
            if (source) viewer.dataSources.remove(source, true);
            source = null;
        }
        async function set(next, signal = new AbortController().signal) {
            records = structuredClone(next);
            const token = ++revision;
            request?.abort();
            const operation = request = new AbortController();
            const cancel = () => operation.abort();
            signal.addEventListener("abort", cancel, {once:true});
            try {
                signal.throwIfAborted();
                if (!isTerrainReady() || !next.some(route => route.waypoints.length)) { remove(); return {}; }
                const points = next.flatMap(route => route.waypoints);
                const sampled = await heights(points, operation.signal);
                signal.throwIfAborted(); operation.signal.throwIfAborted();
                if (token !== revision || !isTerrainReady()) return {};
                const replacement = new Cesium.CustomDataSource(next[0]?.draft ? "Route draft" : "Saved flight routes");
                let offset = 0;
                for (const route of next) {
                    const colors = [Cesium.Color.CYAN, Cesium.Color.ORANGE, Cesium.Color.LIME, Cesium.Color.CORNFLOWERBLUE];
                    const color = colors[(route.id || 0) % colors.length];
                    const positions = route.waypoints.map((point,index) =>
                        Cesium.Cartesian3.fromDegrees(point.longitude, point.latitude, altitude(point, sampled[offset + index])));
                    route.waypoints.forEach((point, index) => {
                        const id = route.draft ? `route-waypoint-${point.id}` : `saved-route-${route.id}-waypoint-${point.id}`;
                        replacement.entities.add({id, name: route.name,
                            position: positions[index], properties: {waypointId: point.id},
                            point: {pixelSize: point.id === route.selectedId ? 16 : 12,
                                color: point.id === route.selectedId ? Cesium.Color.YELLOW : color,
                                outlineColor: Cesium.Color.BLACK, outlineWidth: 2},
                            label: {text: `${index + 1}${isPreview(point) ? "*" : ""}`, font: "bold 16px sans-serif", pixelOffset: new Cesium.Cartesian2(0,-24),
                                fillColor: Cesium.Color.WHITE, outlineColor: Cesium.Color.BLACK,
                                outlineWidth: 3, style: Cesium.LabelStyle.FILL_AND_OUTLINE}
                        });
                        replacement.entities.add({id: `${id}-height`, polyline: {
                            positions: [Cesium.Cartesian3.fromDegrees(point.longitude, point.latitude, sampled[offset + index]), positions[index]],
                            width: 1, material: color?.withAlpha?.(0.35) ?? color, clampToGround: false, arcType: Cesium.ArcType?.NONE
                        }});
                    });
                    if (positions.length > 1) replacement.entities.add({id: `route-line-${route.id || 'draft'}`,
                        polyline: {positions, width: 4, material: color, clampToGround: false}});
                    route.waypoints.forEach((point, index) => {
                        if (point.critical && index < positions.length - 1) replacement.entities.add({
                            id: `route-warning-${route.id || 'draft'}-${index}`,
                            polyline: {positions: positions.slice(index, index + 2), width: 7,
                                material: Cesium.Color.RED, clampToGround: false}
                        });
                    });
                    offset += route.waypoints.length;
                }
                viewer.dataSources.add(replacement);
                remove(); source = replacement;
                return {};
            } catch (error) {
                if (token !== revision) return {};
                if (operation.signal.aborted) { remove(); return {}; }
                remove(); throw error;
            } finally { signal.removeEventListener("abort", cancel); }
        }
        return {set, heights, get source() {return source;},
            async frame(id, signal) {
                const current = revision;
                const points = records.filter(route => id == null || route.id === id).flatMap(route => route.waypoints);
                if (!points.length) return;
                if (!isTerrainReady()) throw new Error("Detailed terrain is required for the route preview");
                const sampled = await heights(points, signal);
                signal.throwIfAborted();
                if (current !== revision || !isTerrainReady()) return;
                const sphere = Cesium.BoundingSphere.fromPoints(points.map((point,index) =>
                    Cesium.Cartesian3.fromDegrees(point.longitude, point.latitude, altitude(point, sampled[index]))));
                viewer.camera.flyToBoundingSphere(sphere, {duration:1,
                    offset:new Cesium.HeadingPitchRange(0, -Math.PI / 4, Math.max(300, sphere.radius * 3))});
            },
            terrainChanged() {
                ++revision; request?.abort(); cache.clear(); remove();
                if (isTerrainReady()) return set(records).catch(onError);
            },
            dispose() {++revision; request?.abort(); records = []; cache.clear(); remove();}
        };
    }
    function validate(command) {
        if (typeof command.editorId !== "string" || !command.editorId || command.editorId.length > 120 ||
            !Number.isSafeInteger(command.revision) || command.revision < 1 ||
            typeof command.enabled !== "boolean" || typeof command.interactive !== "boolean" ||
            !Array.isArray(command.waypoints) || command.waypoints.length > 1000) throw new Error("Invalid route editor state");
        const ids = new Set();
        for (const point of command.waypoints) {
            if (!Number.isSafeInteger(point.id) || point.id <= 0 || ids.has(point.id) ||
                !Number.isFinite(point.latitude) || Math.abs(point.latitude) > 90 ||
                !Number.isFinite(point.longitude) || Math.abs(point.longitude) > 180) throw new Error("Invalid route waypoint");
            if (point.height != null && (!Number.isFinite(point.height.meters) || Math.abs(point.height.meters) > 100000 ||
                !["aboveGroundLevel", "wgs84Ellipsoid", "besselEllipsoid", "ln02", "lhn95", "unverified"].includes(point.height.reference) ||
                (point.height.reference === "aboveGroundLevel" && point.height.meters < 0))) throw new Error("Invalid waypoint height");
            ids.add(point.id);
        }
        for (const id of [command.selectedId, command.moveId]) {
            if (id != null && !ids.has(id)) throw new Error("Invalid selected waypoint");
        }
    }
    function createEditor(Cesium, viewer, emit, host = window, sampleHeights = async points =>
        points.map(point => viewer.scene.globe.getHeight(Cesium.Cartographic.fromDegrees(point.longitude, point.latitude))),
        isTerrainReady = () => true) {
        let state = null, drag = null, building = false;
        const layer = createLayer(Cesium, viewer, sampleHeights, isTerrainReady,
            () => emit("route-preview-error", {message:"Unable to rebuild the route preview. Retry map sync."}));
        const controls = viewer.scene.screenSpaceCameraController;
        const handler = new Cesium.ScreenSpaceEventHandler(viewer.canvas);
        function release() {
            if (drag) controls.enableInputs = drag.inputs;
            drag = null;
        }
        function pointAt(pixel) {
            const ray = viewer.camera.getPickRay(pixel);
            const position = ray && viewer.scene.globe.pick(ray, viewer.scene);
            if (!position) return null;
            const point = Cesium.Cartographic.fromCartesian(position);
            return { latitude: Cesium.Math.toDegrees(point.latitude), longitude: Cesium.Math.toDegrees(point.longitude) };
        }
        function idAt(pixel) {
            const picked = viewer.scene.pick(pixel);
            const entity = picked?.id;
            return entity instanceof Cesium.Entity && layer.source?.entities.contains(entity) && entity.properties?.waypointId?.getValue();
        }
        function action(action, id, position) {
            if (!state?.enabled || !state.interactive || building) return;
            emit("route-map-action", { editorId: state.editorId, revision: state.revision,
                action, ...(id ? { id } : {}), ...(position || {}) });
        }
        async function set(command, signal) {
            validate(command);
            if (state?.editorId === command.editorId && state.revision >= command.revision) return {};
            release();
            const current = state = structuredClone(command);
            building = true;
            try {
                return await layer.set(command.enabled ? [{...command, draft:true}] : [], signal);
            } finally { if (state === current) building = false; }
        }
        function click(pixel) {
            if (!state?.enabled) return false;
            if (!state.interactive || building) return true;
            if (drag?.moved) return true;
            const id = idAt(pixel);
            if (id) action("select", id);
            else {
                const position = pointAt(pixel);
                if (position) action(state.moveId ? "move" : "add", state.moveId, position);
            }
            viewer.canvas.focus();
            return true;
        }
        handler.setInputAction(event => {
            if (!state?.enabled || !state.interactive || building) return;
            const id = idAt(event.position);
            if (!id) return;
            drag = { id, inputs: controls.enableInputs, start: event.position, moved: false };
            controls.enableInputs = false;
        }, Cesium.ScreenSpaceEventType.LEFT_DOWN);
        handler.setInputAction(event => {
            if (!drag || !state?.interactive) return;
            if (Cesium.Cartesian2.distance(drag.start, event.endPosition) < 5) return;
            const point = pointAt(event.endPosition);
            if (!point) return;
            drag.moved = true; drag.point = point;
            const height = viewer.scene.globe.getHeight(Cesium.Cartographic.fromDegrees(point.longitude, point.latitude));
            const entity = layer.source?.entities.getById(`route-waypoint-${drag.id}`);
            if (entity && Number.isFinite(height)) entity.position =
                Cesium.Cartesian3.fromDegrees(point.longitude, point.latitude, altitude(state.waypoints.find(p => p.id === drag.id) ?? {}, height));
        }, Cesium.ScreenSpaceEventType.MOUSE_MOVE);
        // LEFT_UP arrives before LEFT_CLICK; suppress the click generated by a drag.
        let suppressClick = false;
        handler.setInputAction(() => {
            if (drag?.moved && drag.point) {
                action("move", drag.id, drag.point); suppressClick = true;
                setTimeout(() => { suppressClick = false; }, 0);
            }
            release();
        }, Cesium.ScreenSpaceEventType.LEFT_UP);
        handler.setInputAction(event => {
            const id = idAt(event.position);
            if (id) action("delete", id);
        }, Cesium.ScreenSpaceEventType.RIGHT_CLICK);
        const key = event => {
            if (state?.enabled && state.interactive && event.key === "Delete" && state.selectedId) {
                event.preventDefault(); action("delete", state.selectedId);
            }
        };
        const menu = event => { if (state?.enabled) event.preventDefault(); };
        viewer.canvas.addEventListener("keydown", key);
        viewer.canvas.addEventListener("contextmenu", menu);
        viewer.canvas.addEventListener("pointercancel", release);
        viewer.canvas.addEventListener("blur", release);
        host.addEventListener("blur", release);
        return { set, click(pixel) { if (suppressClick) { suppressClick = false; return true; } return click(pixel); },
            async frame(signal = new AbortController().signal) {
                if (!state?.waypoints.length) return;
                const framedState = state;
                const heights = await layer.heights(framedState.waypoints, signal);
                signal.throwIfAborted();
                if (state !== framedState) return;
                if (!Array.isArray(heights) || heights.length !== state.waypoints.length || heights.some(h => !Number.isFinite(h))) {
                    throw new Error("Route terrain heights unavailable");
                }
                const positions = state.waypoints.map((point,index) =>
                    Cesium.Cartesian3.fromDegrees(point.longitude, point.latitude, altitude(point, heights[index])));
                const sphere = Cesium.BoundingSphere.fromPoints(positions);
                viewer.camera.flyToBoundingSphere(sphere, { duration: 1,
                    offset: new Cesium.HeadingPitchRange(0, -Math.PI / 4, Math.max(300, sphere.radius * 3)) });
            },
            dispose() {
                release(); handler.destroy();
                viewer.canvas.removeEventListener("keydown", key);
                viewer.canvas.removeEventListener("contextmenu", menu);
                viewer.canvas.removeEventListener("pointercancel", release);
                viewer.canvas.removeEventListener("blur", release);
                host.removeEventListener("blur", release);
                layer.dispose();
            }
            ,terrainChanged() {release(); layer.terrainChanged();}
        };
    }
    function createOverlays(Cesium, viewer, sampleHeights, isTerrainReady, onError) {
        const layer = createLayer(Cesium, viewer, sampleHeights, isTerrainReady, onError);
        let revision = 0;
        return {
            async set(command, signal) {
                if (!Number.isSafeInteger(command.revision) || command.revision < 1 ||
                    !Array.isArray(command.routes) || command.routes.length > 20) throw new Error("Invalid saved route state");
                const ids = new Set();
                for (const route of command.routes) {
                    if (!Number.isSafeInteger(route.id) || route.id < 1 || ids.has(route.id) ||
                        typeof route.name !== "string" || route.name.length > 120) throw new Error("Invalid saved route");
                    ids.add(route.id);
                    validate({editorId:String(route.id), revision:1, enabled:true, interactive:false, waypoints:route.waypoints});
                }
                if (command.revision <= revision) return {};
                revision = command.revision;
                return layer.set(command.routes, signal);
            },
            terrainChanged: layer.terrainChanged,
            frame(id, signal) {
                if (!Number.isSafeInteger(id) || id < 1) throw new Error("Invalid route ID");
                return layer.frame(id, signal);
            },
            dispose: layer.dispose
        };
    }
    async function sampleProfile(command, sampler, signal) {
        const points = command.positions;
        if (!Array.isArray(points) || !points.length || points.length > 256 || points.some(p =>
            !Number.isFinite(p.latitude) || Math.abs(p.latitude) > 90 ||
            !Number.isFinite(p.longitude) || Math.abs(p.longitude) > 180)) throw new Error("Invalid terrain profile batch");
        signal.throwIfAborted();
        const sampled = await sampler(points, signal);
        signal.throwIfAborted();
        if (!Array.isArray(sampled.heights) || sampled.heights.length !== points.length ||
            sampled.heights.some(h => !Number.isFinite(h) || Math.abs(h) > 100000)) throw new Error("Incomplete terrain profile");
        return {...sampled, heightReference: "wgs84Ellipsoid"};
    }
    return { createEditor, createOverlays, validate, previewAgl, sampleProfile };
});
