function postToFlutter(message) {
        if (window.FPVBridge?.postMessage) window.FPVBridge.postMessage(message);
        if (window.parent !== window) {
            window.parent.postMessage(message, window.location.origin);
        }
    }
    // Keep source values as plain text, with explicit bounds below the bridge's
    // event-frame limit. Key restriction/height fields precede optional content.
    function uasSelectionDetails(raw) {
        const priority = ['identifier', 'name', 'type', 'reason', 'restriction',
            'restrictionConditions', 'message', 'uomDimensions', 'lowerLimit',
            'lowerVerticalReference', 'upperLimit', 'upperVerticalReference',
            'permanent', 'startDateTime', 'endDateTime', 'startTime', 'endTime',
            'authorityName', 'service', 'siteURL', 'email', 'phone'];
        const keys = Object.keys(raw);
        const ordered = [...priority.filter(key => Object.hasOwn(raw, key)),
            ...keys.filter(key => !priority.includes(key))];
        const attributes = Object.create(null), truncatedAttributes = [];
        let size = 0;
        for (const key of ordered) {
            if (Object.keys(attributes).length >= 128) break;
            if (key.length > 120) continue;
            let value, limited = false;
            try {
                value = typeof raw[key] === 'object' ? JSON.stringify(raw[key]) : String(raw[key]);
            } catch { value = '[Unsupported value]'; limited = true; }
            if (typeof value !== 'string') { value = '[Unsupported value]'; limited = true; }
            if (value.length > 8000) { value = value.slice(0, 8000); limited = true; }
            const cost = JSON.stringify([key, value]).length +
                (limited ? JSON.stringify(key).length + 1 : 0);
            if (size + cost > 80 * 1024) continue;
            attributes[key] = value; size += cost;
            if (limited) truncatedAttributes.push(key);
        }
        const sourceName = typeof raw.name === 'string' ? raw.name.trim() : '';
        return {...(sourceName ? {name:sourceName.slice(0,160)} : {}),
            attributes, omittedAttributeCount: keys.length - Object.keys(attributes).length, truncatedAttributes};
    }
    const weatherOverlay = FPVWeatherOverlay.create(Cesium, () => activeViewer);
    const bridge = FPVGlobeBridge.createBridge({ send: postToFlutter, execute: executeCommand });
    bridge.emit("renderer-loading");
    function sendToFlutter(type, payload = {}) { bridge.emit(type, payload); }
    window.addEventListener("pagehide", event => {
        walker?.stop();
        if (!event.persisted) { obstacleWms?.dispose(); obstacleVectors?.dispose(); hazardAreas?.dispose(); disposeGroundControls?.(); routeEditor?.dispose(); routeOverlays?.dispose(); weatherOverlay.dispose(); terrainManager?.dispose(); bridge.dispose(); }
    });
    let rendererReady = false;
    let obstacleWms = null, obstacleVectors = null, hazardAreas = null;
    let terrainManager = null;
    let walker = null, routeEditor = null, routeOverlays = null, disposeGroundControls = null;
    let uasImportRevision = 0;
    const offline = new URLSearchParams(window.location.search).get("offline") === "1";
    let currentMapStyle = "satellite";
    const mapProviders = FPVMapProviders.createAdapters(Cesium, window.FPVMapProviderConfig);
    const terrainAvailable = () => terrainManager?.status().state === "ready";
    const offlineReason = () => offline ? "diagnosticOffline" :
        navigator.onLine === false ? "networkOffline" : null;
    window.addEventListener("offline", () => terrainManager?.networkChanged());
    window.addEventListener("online", () => terrainManager?.networkChanged());

    let activeViewer = null;
    let activeBaseLayer = null;
    let spotsRequestedVisible = true;
    let overlayOrder = ["uasZones", "savedSpots"];

    function applyOverlayOrder() {
        const sources = { uasZones: uasDataSource, savedSpots: spotsDataSource };
        for (const key of overlayOrder) {
            const source = sources[key];
            if (source && activeViewer.dataSources.contains(source)) {
                activeViewer.dataSources.raiseToTop(source);
            }
        }
    }

    function setOverlayOrder(order) {
        if (!Array.isArray(order) || order.length !== 2 ||
            new Set(order).size !== 2 ||
            order.some(key => key !== "uasZones" && key !== "savedSpots")) {
            throw new Error("Invalid overlay order");
        }
        overlayOrder = [...order];
        applyOverlayOrder();
    }

    function layerState() {
        const sources = { uasZones: uasDataSource, savedSpots: spotsDataSource };
        return {
            overlayOrder: Object.keys(sources)
                .filter(key => sources[key] && activeViewer.dataSources.contains(sources[key]))
                .sort((a, b) => activeViewer.dataSources.indexOf(sources[a]) -
                    activeViewer.dataSources.indexOf(sources[b])),
            spotsVisible: spotsRequestedVisible
        };
    }

    function setSpotsVisible(visible) {
        if (typeof visible !== "boolean") throw new Error("Invalid spots visibility");
        spotsRequestedVisible = visible;
        if (spotsDataSource) spotsDataSource.show = visible;
        if (!visible) sendToFlutter("spot-cleared");
    }

    let uasDataSource = null;
    let uasRequestedVisible = false;
    let uasFillOpacity = 0.20;
    let uasDownloadedAtUtc = null;
    let uasFeatureCount = null;
    let uasRenderMetrics = null;
    let cancelUasFrameMeasurement = null;

    // Only records observed renderer work; does not imply current NOTAMs or
    // adequate spatial coverage. A stale import must not replace later metrics.
    function publishUasImportMetrics(revision, featureCount, loadMs, attachMs) {
        if (revision !== uasImportRevision) return;
        const metrics = { featureCount,
            loadMs: Math.round(loadMs * 100) / 100,
            attachMs: Math.round(attachMs * 100) / 100,
            firstFrameMs: null };
        uasRenderMetrics = metrics;
        sendToFlutter('uas-render-metrics', metrics);
        const scene = activeViewer?.scene;
        // First real Cesium postRender following data-source attachment.
        // Never block acknowledgement, interaction or page disposal.
        if (!scene?.postRender?.addEventListener || !scene?.requestRender) return;
        if (cancelUasFrameMeasurement) cancelUasFrameMeasurement();
        let done = false;
        const start = performance.now();
        let unsubscribe = null;
        const handler = () => {
            if (done) return;
            done = true;
            unsubscribe?.();
            cancelUasFrameMeasurement = null;
            if (revision !== uasImportRevision) return;
            metrics.firstFrameMs = Math.round((performance.now() - start) * 100) / 100;
            uasRenderMetrics = metrics;
            sendToFlutter('uas-render-metrics', metrics);
        };
        unsubscribe = scene.postRender.addEventListener(handler);
        cancelUasFrameMeasurement = () => { done = true; unsubscribe?.(); };
        scene.requestRender();
    }

    function createMapProvider(style) {
        return mapProviders.imagery(style, Boolean(offlineReason()));
    }

    function resetCamera() {
        walker?.stop();
        activeViewer.camera.flyTo({
            destination: Cesium.Cartesian3.fromDegrees(
                8.4,
                46.7,
                180000
            ),
            orientation: {
                heading: 0,
                pitch: Cesium.Math.toRadians(-55),
                roll: 0
            },
            duration: 1.5
        });
    }

    function flyToCoordinates(command) {
        const latitude = Number(command.latitude);
        const longitude = Number(command.longitude);
        const altitude = Number(command.altitude);

        if (
            !Number.isFinite(latitude) ||
            !Number.isFinite(longitude) ||
            !Number.isFinite(altitude) ||
            Math.abs(latitude) > 90 ||
            Math.abs(longitude) > 180 ||
            altitude <= 0
        ) {
            throw new Error("Invalid camera coordinates");
        }

        walker?.stop();
        activeViewer.camera.flyTo({
            destination: Cesium.Cartesian3.fromDegrees(
                longitude,
                latitude,
                altitude
            ),
            orientation: {
                heading: 0,
                pitch: Cesium.Math.toRadians(-60),
                roll: 0
            },
            duration: 1.5
        });
    }

    function setMapStyle(style) {
        const provider = createMapProvider(style);
        const newLayer = new Cesium.ImageryLayer(provider);

        activeViewer.imageryLayers.add(newLayer, 0);

        if (activeBaseLayer) {
            activeViewer.imageryLayers.remove(
                activeBaseLayer,
                true
            );
        }

        activeBaseLayer = newLayer;
        currentMapStyle = style;

        sendToFlutter("map-style-changed", {
            style
        });
    }

    function sendUasStatus({
        visible,
        loading = false,
        error = null
    }) {
        sendToFlutter("uas-zones-status", {
            visible,
            loading,
            error,
            fillOpacity: uasFillOpacity,
            downloadedAtUtc: uasDownloadedAtUtc,
            featureCount: uasFeatureCount
        });
    }

    function setUasFillOpacity(opacity) {
        if (
            typeof opacity !== "number" ||
            !Number.isFinite(opacity) ||
            opacity < 0 ||
            opacity > 1
        ) {
            throw new Error("Invalid UAS fill opacity");
        }

        uasFillOpacity = opacity;

        if (!uasDataSource) {
            return;
        }

        const entities = uasDataSource.entities;
        entities.suspendEvents();
        try {
            // Draw source types separately, including overlapping entities.
            // Unknown codes remain grey and never imply flight clearance.
            FPVUasZoneStyles.applyToDataSource(
                uasDataSource, Cesium, uasFillOpacity,
                activeViewer?.clock?.currentTime
            );
        } finally {
            entities.resumeEvents();
        }
    }

    async function setUasZonesVisible(
        visible,
        geojson = null,
        downloadedAtUtc = null,
        replace = false,
        signal,
        sourceAttribution = 'Airspace data'
    ) {
        const revision = ++uasImportRevision;
        if (cancelUasFrameMeasurement) {
            cancelUasFrameMeasurement();
            cancelUasFrameMeasurement = null;
        }
        uasRequestedVisible = visible;

        // Hide without deleting the currently loaded data.
        if (!visible && !replace) {
            if (uasDataSource) {
                uasDataSource.show = false;
            }

            sendToFlutter("uas-zone-cleared");

            sendUasStatus({
                visible: false
            });

            return;
        }

        // Reuse the existing Cesium data source.
        if (uasDataSource && !replace) {
            uasDataSource.show = visible;

            sendUasStatus({
                visible
            });

            return;
        }

        if (
            !geojson ||
            geojson.type !== "FeatureCollection" ||
            !Array.isArray(geojson.features)
        ) {
            sendUasStatus({
                visible: uasDataSource?.show === true,
                error: "Invalid or missing UAS GeoJSON"
            });

            throw new Error("Invalid or missing UAS GeoJSON");
        }

        sendUasStatus({
            visible: uasDataSource?.show === true,
            loading: true
        });

        try {
            const loadStarted = performance.now();
            const replacement =
                await Cesium.GeoJsonDataSource.load(
                    geojson,
                    {
                        clampToGround: true,

                        stroke:
                            Cesium.Color.RED.withAlpha(0.85),

                        fill:
                            Cesium.Color.RED.withAlpha(
                                uasFillOpacity
                            ),

                        strokeWidth: 2,

                        credit: new Cesium.Credit(FPVMapProviders.escapeCredit(sourceAttribution))
                    }
                );

            const loadMs = performance.now() - loadStarted;
            signal.throwIfAborted();
            if (revision !== uasImportRevision) throw new Error("UAS import superseded");
            const attachStarted = performance.now();
            await activeViewer.dataSources.add(replacement);
            const attachMs = performance.now() - attachStarted;
            if (signal.aborted || revision !== uasImportRevision) {
                activeViewer.dataSources.remove(replacement, true);
                throw new Error("UAS import superseded");
            }

            const previous = uasDataSource;

            uasDataSource = replacement;
            uasDataSource.show = uasRequestedVisible;
            applyOverlayOrder();

            if (previous) {
                activeViewer.dataSources.remove(
                    previous,
                    true
                );
            }

            uasDownloadedAtUtc = downloadedAtUtc;
            uasFeatureCount = geojson.features.length;

            setUasFillOpacity(uasFillOpacity);
            publishUasImportMetrics(revision, geojson.features.length, loadMs, attachMs);

            sendToFlutter("uas-zone-cleared");

            sendUasStatus({
                visible: uasDataSource.show
            });

            console.log(
                "[FPVManager] UAS dataset imported:",
                uasFeatureCount,
                "features"
            );
        } catch (error) {
            if (signal.aborted || revision !== uasImportRevision) throw error;
            console.error(
                "[FPVManager] UAS import failed:",
                error
            );

            sendUasStatus({
                visible: uasDataSource?.show === true,
                error: String(error.message || error)
            });
            throw error;
        }
    }

    async function queryTerrainElevation(command, signal) {
        const { latitude, longitude } = command;
        if (!Number.isFinite(latitude) || !Number.isFinite(longitude) ||
            latitude < -90 || latitude > 90 || longitude < -180 || longitude > 180) {
            throw new Error("Invalid terrain coordinates");
        }
        const position = Cesium.Cartographic.fromDegrees(longitude, latitude);
        let detailed;
        const sampled = await terrainManager.sample(terrainProvider => {
            detailed = Boolean(terrainProvider.availability);
            return detailed
                ? Cesium.sampleTerrainMostDetailed(terrainProvider, [position], true)
                : Cesium.sampleTerrain(terrainProvider, 12, [position], true);
        }, signal);
        signal.throwIfAborted();
        const height = sampled[0]?.height;
        if (!Number.isFinite(height)) throw new Error("No terrain elevation available at these coordinates");
        return { latitude, longitude, heightMeters: height,
            heightReference: "wgs84Ellipsoid",
            samplingMethod: detailed ? "most-detailed" : "level-12" };
    }

    let spotsDataSource = null;
    let lastSpotRevision = -1;

    async function setSpotMarkers(command, signal) {
        if (!activeViewer) {
            throw new Error("Globe is not ready");
        }

        const spots = command.spots;
        const revision = command.revision;

        if (
            !Array.isArray(spots) ||
            spots.length > 10000 ||
            !Number.isSafeInteger(revision) ||
            revision < 0
        ) {
            throw new Error("Invalid spot marker data");
        }

        if (revision < lastSpotRevision) {
            return;
        }

        // Validate the entire incoming dataset before
        // changing the displayed entities.
        const incoming = new Set();

        for (const spot of spots) {
            if (
                !Number.isSafeInteger(spot.id) ||
                spot.id <= 0 ||
                typeof spot.name !== "string" ||
                !Number.isFinite(spot.latitude) ||
                !Number.isFinite(spot.longitude) ||
                spot.latitude < -90 ||
                spot.latitude > 90 ||
                spot.longitude < -180 ||
                spot.longitude > 180 ||
                incoming.has(spot.id)
            ) {
                throw new Error("Invalid spot feature");
            }

            incoming.add(spot.id);
        }

        if (!spotsDataSource) {
            spotsDataSource = new Cesium.CustomDataSource(
                "FPVManager Saved Spots"
            );

            await activeViewer.dataSources.add(
                spotsDataSource
            );
            applyOverlayOrder();
        }

        signal.throwIfAborted();
        if (revision < lastSpotRevision) return;

        spotsDataSource.show = spotsRequestedVisible;

        const entities = spotsDataSource.entities;

        entities.suspendEvents();

        try {
            const expectedIds = new Set();

            for (const spot of spots) {
                const id = `fpv-spot-${spot.id}`;

                expectedIds.add(id);

                const position =
                    Cesium.Cartesian3.fromDegrees(
                        spot.longitude,
                        spot.latitude,
                        0
                    );

                let entity = entities.getById(id);

                if (!entity) {
                    entity = entities.add({
                        id,
                        name: spot.name,
                        position,
                        point: {
                            pixelSize: 13,
                            color: Cesium.Color.CYAN,
                            outlineColor: Cesium.Color.BLACK,
                            outlineWidth: 2,
                            heightReference:
                                Cesium.HeightReference.CLAMP_TO_GROUND
                        },
                        label: {
                            text: spot.name,
                            font: "12px sans-serif",
                            fillColor: Cesium.Color.WHITE,
                            outlineColor: Cesium.Color.BLACK,
                            outlineWidth: 3,
                            style:
                                Cesium.LabelStyle.FILL_AND_OUTLINE,
                            pixelOffset:
                                new Cesium.Cartesian2(0, -25),
                            heightReference:
                                Cesium.HeightReference.CLAMP_TO_GROUND,
                            distanceDisplayCondition:
                                new Cesium.DistanceDisplayCondition(
                                    0,
                                    15000
                                )
                        }
                    });
                } else {
                    entity.name = spot.name;
                    entity.position = position;
                    entity.label.text = spot.name;
                }
            }

            for (const entity of [...entities.values]) {
                if (!expectedIds.has(entity.id)) {
                    entities.removeById(entity.id);
                }
            }
        } finally {
            entities.resumeEvents();
        }

        lastSpotRevision = revision;
    }

    async function executeCommand(command, signal) {
        signal.throwIfAborted();
        if (!activeViewer) throw new Error("Globe is not initialized");
        switch (command.type) {
            case "set-weather-overlay": return weatherOverlay.replace(command);
            case "clear-weather-overlay": return weatherOverlay.clear();
            case "set-obstacle-wms": obstacleWms.set(command); return {};
            case "set-obstacle-vectors": await obstacleVectors.replace(command,signal); return {};
            case "set-hazard-areas": await hazardAreas.replace(command,signal); return {};
            case "enter-ground-view": return walker.start(command, signal);
            case "exit-ground-view": walker.stop(); return {};
            case "set-route-editor": walker.stop(); return routeEditor.set(command, signal);
            case "set-visible-routes": return routeOverlays.set(command, signal);
            case "frame-visible-routes": walker.stop(); await routeOverlays.frame(command.routeId, signal); return {};
            case "frame-route": walker.stop(); await routeEditor.frame(signal); return {};
            case "reset-camera": resetCamera(); return {};
            case "reload-renderer": setTimeout(() => window.location.reload(), 0); return {};
            case "retry-terrain": {
                await terrainManager.retry(signal);
                signal.throwIfAborted();
                // Refresh failed imagery requests too, preserving the selected style.
                if (terrainAvailable()) setMapStyle(currentMapStyle);
                return terrainManager.status();
            }
            case "fly-to": flyToCoordinates(command); return {};
            case "set-map-style": setMapStyle(command.style); return {};
            case "set-uas-zones":
            case "replace-uas-zones":
                if (typeof command.visible !== "boolean") throw new Error("Invalid visibility");
                await setUasZonesVisible(command.visible, command.geojson ?? null,
                    command.downloadedAtUtc ?? null, command.type === "replace-uas-zones", signal,
                    command.sourceAttribution ?? 'Airspace data');
                return layerState();
            case "set-uas-opacity":
                setUasFillOpacity(command.opacity);
                sendUasStatus({ visible: uasDataSource?.show === true });
                return {};
            case "query-route-terrain": return FPVRouteEditor.sampleProfile(command, async points => {
                let detailed;
                const positions = points.map(p => Cesium.Cartographic.fromDegrees(p.longitude, p.latitude));
                const sampled = await terrainManager.sample(provider => {
                    detailed = Boolean(provider.availability);
                    return detailed ? Cesium.sampleTerrainMostDetailed(provider, positions, true)
                        : Cesium.sampleTerrain(provider, 12, positions, true);
                }, signal);
                return {heights: sampled.map(p => p.height), samplingMethod: detailed ? "most-detailed" : "level-12"};
            }, signal);
            case "query-terrain-elevation": return queryTerrainElevation(command, signal);
            case "set-spot-markers": await setSpotMarkers(command, signal); return layerState();
            case "set-spots-visible": setSpotsVisible(command.visible); return layerState();
            case "set-overlay-order": setOverlayOrder(command.order); return layerState();
                case "focus-spot": {
                    walker?.stop();
                    const latitude = command.latitude;
                    const longitude = command.longitude;
                    const terrainHeight = command.terrainHeightMeters;
                    const range = command.rangeMeters;

                    if (
                        !Number.isFinite(latitude) ||
                        !Number.isFinite(longitude) ||
                        !Number.isFinite(terrainHeight) ||
                        !Number.isFinite(range) ||
                        latitude < -90 ||
                        latitude > 90 ||
                        longitude < -180 ||
                        longitude > 180 ||
                        range < 50 ||
                        range > 10000
                    ) {
                        throw new Error("Invalid spot focus parameters");
                    }

                    const target = Cesium.Cartesian3.fromDegrees(
                        longitude,
                        latitude,
                        terrainHeight
                    );

                    const boundingSphere = new Cesium.BoundingSphere(
                        target,
                        1
                    );

                    activeViewer.camera.flyToBoundingSphere(
                        boundingSphere,
                        {
                            duration: 2.5,
                            offset: new Cesium.HeadingPitchRange(
                                Cesium.Math.toRadians(0),
                                Cesium.Math.toRadians(-55),
                                range
                            )
                        }
                    );

                    return {};
                }

            default: throw new Error(`Unsupported command: ${command.type}`);
        }
    }

    window.FPVManager = {
        receive: bridge.receive,
        hello: () => {
            walker?.stop();
            if (rendererReady) {
                terrainManager.networkChanged();
                sendToFlutter("globe-ready", { terrainAvailable: terrainAvailable() });
                sendToFlutter("terrain-status", terrainManager.status());
                publishObstacleViewport();
            }
        }
    };
    window.addEventListener("message", event => {
        if (window.parent === window || event.source !== window.parent ||
            event.origin !== window.location.origin) return;
        if (event.data === "fpvmanager-hello") window.FPVManager.hello();
        else bridge.receive(event.data);
    });

    async function initializeGlobe() {
        const info = document.getElementById("info");
        let selectedPointInfo = null;

        const imageryProvider = createMapProvider("satellite");

        function terrainInfo(status) {
            info.textContent = status.state === "ready"
                ? selectedPointInfo ?? "FPVManager | 3D terrain loaded"
                : status.state === "loading"
                    ? "Connecting to 3D terrain | Flat map shown"
                    : "3D terrain unavailable | Flat map shown — terrain heights disabled";
        }
        terrainManager = FPVTerrain.createTerrainManager({
            createProvider: () => mapProviders.terrain(),
            createFallback: () => new Cesium.EllipsoidTerrainProvider(),
            applyProvider: provider => {
                if (activeViewer) activeViewer.terrainProvider = provider;
            },
            offlineReason,
            probe: async (provider, signal) => {
                // Metadata alone does not establish that terrain tiles can be read.
                let request;
                while (request === undefined) {
                    signal.throwIfAborted();
                    request = provider.requestTileGeometry(0, 0, 0);
                    if (request === undefined) await new Promise(resolve => setTimeout(resolve, 50));
                }
                const tile = await request;
                signal.throwIfAborted();
                if (!tile) throw new Error("Terrain probe returned no tile");
            },
            onStatus: status => {
                if (status.state !== "ready") selectedPointInfo = null;
                if (status.state !== "ready") walker?.stop("Terrain unavailable; returned to globe view");
                routeEditor?.terrainChanged();
                routeOverlays?.terrainChanged();
                // Dynamic obstacle stems follow the actual rendered terrain;
                // invalidate the frame on provider transitions as well.
                activeViewer?.scene?.requestRender?.();
                terrainInfo(status);
                if (rendererReady) sendToFlutter("terrain-status", status);
            }
        });
        await terrainManager.retry();

        const viewer = new Cesium.Viewer("globe", {
            baseLayerPicker: false,
            baseLayer: new Cesium.ImageryLayer(imageryProvider),
            terrainProvider: terrainManager.provider,
            animation: false,
            timeline: false,
            geocoder: false,
            homeButton: false,
            fullscreenButton: false,
            sceneModePicker: false,
            navigationHelpButton: false,
            infoBox: false,
            selectionIndicator: false
        });

        viewer.scene.globe.depthTestAgainstTerrain = true;
        activeViewer = viewer;
        obstacleWms = FPVObstacles.createWms(Cesium,viewer,sendToFlutter);
        hazardAreas = FPVObstacles.createHazards(Cesium,viewer);
        obstacleVectors = FPVObstacles.createVectors(Cesium,viewer,
            {isTerrainReady:terrainAvailable});
        viewer.camera.moveEnd.addEventListener(publishObstacleViewport);
        const groundPanel = document.getElementById("ground-controls");
        walker = FPVGroundNavigation.createWalker({
            isTerrainReady: terrainAvailable,
            sampleHeight: async (point, signal) => (await queryTerrainElevation(point, signal)).heightMeters,
            renderedHeight: point => viewer.scene.globe.getHeight(Cesium.Cartographic.fromDegrees(point.longitude, point.latitude)),
            captureCamera: () => {
                viewer.camera.cancelFlight();
                const saved = { destination: Cesium.Cartesian3.clone(viewer.camera.positionWC),
                    direction: Cesium.Cartesian3.clone(viewer.camera.directionWC),
                    up: Cesium.Cartesian3.clone(viewer.camera.upWC), heading: viewer.camera.heading,
                    near: viewer.camera.frustum.near, inputs: viewer.scene.screenSpaceCameraController.enableInputs,
                    collision: viewer.scene.screenSpaceCameraController.enableCollisionDetection };
                viewer.scene.screenSpaceCameraController.enableInputs = false;
                viewer.scene.screenSpaceCameraController.enableCollisionDetection = false;
                viewer.camera.frustum.near = 0.1;
                return saved;
            },
            applyPose: point => {
                viewer.camera.setView({ destination: Cesium.Cartesian3.fromDegrees(point.longitude, point.latitude, point.height),
                    orientation: { heading: point.heading, pitch: point.pitch, roll: 0 } });
                info.textContent = `${point.latitude.toFixed(6)}, ${point.longitude.toFixed(6)} | ` +
                    `Ground: ${(point.height - 2).toFixed(1)} m WGS84 | Eye: ≈ 2 m AGL | ` +
                    `Look: ${(point.pitch * 180 / Math.PI).toFixed(0)}°`;
            },
            restoreCamera: saved => {
                viewer.scene.screenSpaceCameraController.enableInputs = saved.inputs;
                viewer.scene.screenSpaceCameraController.enableCollisionDetection = saved.collision;
                viewer.camera.frustum.near = saved.near;
                viewer.camera.setView({ destination: saved.destination, orientation: { direction: saved.direction, up: saved.up } });
            },
            onState: state => {
                groundPanel.hidden = !state.active;
                if (!state.active) {
                    disposeGroundControls?.reset();
                    groundPanel.querySelector("[data-stick-thumb]").style.transform = "translate(0px, 0px)";
                    terrainInfo(terrainManager.status());
                }
                if (state.active) viewer.canvas.focus();
                sendToFlutter("ground-view-state", state);
            }
        });
        disposeGroundControls = FPVGroundNavigation.bindControls(walker, viewer.canvas, groundPanel);
        let lastWalkTime = performance.now();
        viewer.scene.preRender.addEventListener(() => {
            const now = performance.now();
            walker.tick((now - lastWalkTime) / 1000); lastWalkTime = now;
        });
        const sampleRouteHeights = async (points, signal) => {
            if (!terrainAvailable()) throw new Error("Detailed terrain is required for the route preview");
            const positions = points.map(point => Cesium.Cartographic.fromDegrees(point.longitude, point.latitude));
            const sampled = await terrainManager.sample(provider => provider.availability
                ? Cesium.sampleTerrainMostDetailed(provider, positions, true)
                : Cesium.sampleTerrain(provider, 12, positions, true), signal);
            return sampled.map(point => point.height);
        };
        routeEditor = FPVRouteEditor.createEditor(Cesium, viewer, sendToFlutter, window, sampleRouteHeights, terrainAvailable);
        routeOverlays = FPVRouteEditor.createOverlays(Cesium, viewer, sampleRouteHeights, terrainAvailable,
            () => sendToFlutter("route-preview-error", {message:"Unable to rebuild saved routes. Retry the route preview in Map layers."}));
        viewer.scene.renderError.addEventListener((_scene, error) => {
            walker?.stop("Renderer unavailable; returned to globe view");
            sendToFlutter("globe-error", { message: String(error.message || error) });
        });
        activeBaseLayer = viewer.imageryLayers.get(0);

        // Initial camera position: Swiss Alps
        viewer.camera.setView({
            destination: Cesium.Cartesian3.fromDegrees(
                8.4,
                46.7,
                180000
            ),
            orientation: {
            heading: 0,
            pitch: Cesium.Math.toRadians(-55),
            roll: 0
            }
        });

        terrainInfo(terrainManager.status());

        rendererReady = true;
        window.FPVManager.hello();


        // Display coordinates and elevation on click.
        viewer.screenSpaceEventHandler.setInputAction(
            function (event) {
                const picked = viewer.scene.pick(event.position);

                const entity = picked?.id instanceof Cesium.Entity
                    ? picked.id
                    : picked?.primitive?.id;

                const obstacle = obstacleVectors.pick(entity) || hazardAreas.pick(entity);
                if (obstacle) {
                    selectedPointInfo = null; terrainInfo(terrainManager.status());
                    sendToFlutter('obstacle-selected',obstacle); return;
                }
                sendToFlutter('obstacle-cleared');
                if (walker.status().active || routeEditor.click(event.position)) return;

                const isUasZone =
                    uasDataSource !== null &&
                    uasDataSource.show &&
                    entity instanceof Cesium.Entity &&
                    uasDataSource.entities.contains(entity);

                const isSavedSpot =
                    spotsDataSource !== null &&
                    spotsDataSource.show &&
                    entity instanceof Cesium.Entity &&
                    spotsDataSource.entities.contains(entity);

                if (isSavedSpot) {
                    selectedPointInfo = null; terrainInfo(terrainManager.status());
                    const spotId = Number(
                        entity.id.replace("fpv-spot-", "")
                    );

                    sendToFlutter("uas-zone-cleared");

                    sendToFlutter("spot-selected", {
                        id: spotId
                    });

                    return;
                }

                // Any non-spot click dismisses the spot selection.
                sendToFlutter("spot-cleared");

                if (isUasZone) {
                    selectedPointInfo = null; terrainInfo(terrainManager.status());
                    const ray = viewer.camera.getPickRay(event.position);
                    const position = ray && viewer.scene.globe.pick(ray, viewer.scene);
                    const coordinates = position && Cesium.Cartographic.fromCartesian(position);
                    const rawAttributes =
                        entity.properties?.getValue(
                            viewer.clock.currentTime
                        ) ?? {};

                    sendToFlutter("uas-zone-selected", {
                        id: String(entity.id).slice(0, 160),
                        name: String(
                            entity.name || "UAS Geographical Zone"
                        ).slice(0, 160),
                        ...(coordinates ? {
                            latitude: Cesium.Math.toDegrees(coordinates.latitude),
                            longitude: Cesium.Math.toDegrees(coordinates.longitude)
                        } : {}),
                        ...uasSelectionDetails(rawAttributes)
                    });

                    return;
                }

                sendToFlutter("uas-zone-cleared");

                const ray =
                    viewer.camera.getPickRay(event.position);

                if (!ray) return;

                const position =
                    viewer.scene.globe.pick(ray, viewer.scene);

                if (!position) return;

                const coordinates =
                    Cesium.Cartographic.fromCartesian(position);

                const longitude = Cesium.Math.toDegrees(
                    coordinates.longitude
                );

                const latitude = Cesium.Math.toDegrees(
                    coordinates.latitude
                );

                const altitude = coordinates.height;

                selectedPointInfo = info.textContent =
                    `Lat: ${latitude.toFixed(6)} | ` +
                    `Lon: ${longitude.toFixed(6)} | ` +
                    (terrainAvailable()
                        ? `Height: ${altitude.toFixed(1)} m (WGS84 ellipsoid, rendered terrain)`
                        : "Flat map — terrain height unavailable");

                sendToFlutter("point-selected", {
                    latitude: latitude,
                    longitude: longitude,
                    altitude: altitude,
                    heightReference: terrainAvailable() ? "wgs84Ellipsoid" : "unverified"
                });
            },
            Cesium.ScreenSpaceEventType.LEFT_CLICK
        );
    }

    function publishObstacleViewport() {
        if (!rendererReady || !activeViewer) return;
        const camera = activeViewer.camera;
        let rect;
        if (walker?.status().active) {
            const p = camera.positionCartographic;
            // The ellipsoid horizon below mountain terrain can otherwise look
            // like a country-wide viewport from a two-metre ground camera.
            rect = new Cesium.Rectangle(p.longitude-0.0005,p.latitude-0.0005,p.longitude+0.0005,p.latitude+0.0005);
        } else rect = camera.computeViewRectangle(activeViewer.scene.globe.ellipsoid);
        if (rect) sendToFlutter('obstacle-viewport',{
            west:Cesium.Math.toDegrees(rect.west),south:Cesium.Math.toDegrees(rect.south),
            east:Cesium.Math.toDegrees(rect.east),north:Cesium.Math.toDegrees(rect.north)});
    }

    initializeGlobe().catch((error) => {
        console.error(error);

        document.getElementById("info").textContent =
            "Failed to initialize 3D globe: " + error.message;

        sendToFlutter("globe-error", {
            message: error.message
        });
    });
