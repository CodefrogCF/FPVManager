(function (root, factory) {
    const api = factory();
    if (typeof module === "object" && module.exports) module.exports = api;
    else root.FPVRouteEditor = api;
})(typeof globalThis !== "undefined" ? globalThis : this, function () {
    "use strict";
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
            ids.add(point.id);
        }
        for (const id of [command.selectedId, command.moveId]) {
            if (id != null && !ids.has(id)) throw new Error("Invalid selected waypoint");
        }
    }
    function createEditor(Cesium, viewer, emit, host = window, sampleHeights = async points =>
        points.map(point => viewer.scene.globe.getHeight(Cesium.Cartographic.fromDegrees(point.longitude, point.latitude)) ?? 0)) {
        let state = null, source = null, drag = null;
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
            return entity instanceof Cesium.Entity && source?.entities.contains(entity) && entity.properties?.waypointId?.getValue();
        }
        function action(action, id, position) {
            if (!state?.enabled || !state.interactive) return;
            emit("route-map-action", { editorId: state.editorId, revision: state.revision,
                action, ...(id ? { id } : {}), ...(position || {}) });
        }
        function set(command) {
            validate(command);
            if (state?.editorId === command.editorId && state.revision >= command.revision) return {};
            release();
            const replacement = new Cesium.CustomDataSource("Route draft");
            command.waypoints.forEach((point, index) => replacement.entities.add({
                id: `route-waypoint-${point.id}`,
                position: Cesium.Cartesian3.fromDegrees(point.longitude, point.latitude),
                properties: { waypointId: point.id },
                point: { pixelSize: point.id === command.selectedId ? 16 : 12,
                    color: point.id === command.selectedId ? Cesium.Color.YELLOW : Cesium.Color.CYAN,
                    outlineColor: Cesium.Color.BLACK, outlineWidth: 2,
                    heightReference: Cesium.HeightReference.CLAMP_TO_GROUND,
                    disableDepthTestDistance: Number.POSITIVE_INFINITY },
                label: { text: String(index + 1), font: "bold 16px sans-serif",
                    pixelOffset: new Cesium.Cartesian2(0, -24),
                    fillColor: Cesium.Color.WHITE, outlineColor: Cesium.Color.BLACK,
                    outlineWidth: 3, style: Cesium.LabelStyle.FILL_AND_OUTLINE,
                    heightReference: Cesium.HeightReference.CLAMP_TO_GROUND,
                    disableDepthTestDistance: Number.POSITIVE_INFINITY }
            }));
            if (command.waypoints.length > 1) replacement.entities.add({
                id: "route-line",
                polyline: { positions: command.waypoints.map(p => Cesium.Cartesian3.fromDegrees(p.longitude, p.latitude)),
                    width: 4, material: Cesium.Color.CYAN, clampToGround: true }
            });
            replacement.show = command.enabled;
            viewer.dataSources.add(replacement);
            if (source) viewer.dataSources.remove(source, true);
            source = replacement; state = structuredClone(command);
            return {};
        }
        function click(pixel) {
            if (!state?.enabled) return false;
            if (!state.interactive) return true;
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
            if (!state?.enabled || !state.interactive) return;
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
            source.entities.getById(`route-waypoint-${drag.id}`).position =
                Cesium.Cartesian3.fromDegrees(point.longitude, point.latitude);
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
                if (!source?.entities.values.length || !state?.waypoints.length) return;
                const framedState = state;
                const heights = await sampleHeights(framedState.waypoints, signal);
                signal.throwIfAborted();
                if (state !== framedState) return;
                if (!Array.isArray(heights) || heights.length !== state.waypoints.length || heights.some(h => !Number.isFinite(h))) {
                    throw new Error("Route terrain heights unavailable");
                }
                const positions = state.waypoints.map((point,index) =>
                    Cesium.Cartesian3.fromDegrees(point.longitude, point.latitude, heights[index]));
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
                if (source) viewer.dataSources.remove(source, true);
            }
        };
    }
    return { createEditor, validate };
});
