    const rendererLanguage = FPVRendererLanguage.create(document);
    const translate = rendererLanguage.translate;

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
    const meteoswissRadar = typeof FPVMeteoRadar !== "undefined"
        ? FPVMeteoRadar.create(Cesium, () => activeViewer)
        : { replace: async () => { throw Error("MeteoSwiss radar decoder unavailable"); }, clear: () => ({}), dispose() {} };
    const datedImagery = typeof FPVDatedImagery !== "undefined"
        ? FPVDatedImagery.create(Cesium, () => activeViewer,
            (type,payload) => sendToFlutter(type,payload))
        : { replace: async () => { throw Error("Dated imagery renderer unavailable"); },
            clear: () => ({}), dispose() {} };
    const bridge = FPVGlobeBridge.createBridge({
        send: postToFlutter,
        execute: executeCommand,
        onTransferParsed: measurement => {
            if (measurement.commandType === 'set-uas-zones' ||
                measurement.commandType === 'replace-uas-zones') {
                sendToFlutter('uas-bridge-decode-metrics', measurement);
            }
        }
    });
    bridge.emit("renderer-loading");
    function sendToFlutter(type, payload = {}) { bridge.emit(type, payload); }
    window.addEventListener("pagehide", event => {
        if (!event.persisted) { mapCompass?.dispose(); roadNavigation?.dispose(); }
        stopNavigation();
        if (!event.persisted) liveRadio?.dispose();
        if (!event.persisted) { situationalLayers?.dispose(); obstacleWms?.dispose(); obstacleVectors?.dispose(); hazardAreas?.dispose(); disposeGroundControls?.(); routeEditor?.dispose(); routeOverlays?.dispose(); signalAnalysis?.dispose(); weatherOverlay.dispose(); meteoswissRadar.dispose(); datedImagery.dispose(); terrainManager?.dispose(); bridge.dispose(); }
        if (!event.persisted) scenePerformance?.dispose();
        if (!event.persisted) sceneEnvironment?.dispose(); tunnels?.dispose(); tunnelVolumes?.dispose(); infrastructureClearance?.dispose(); modelCollisions?.dispose();
        if (!event.persisted) windLayer?.dispose();
        if (!event.persisted) globePositions?.dispose();
        if (!event.persisted) spotGrounding?.dispose();
        if (!event.persisted) mapLabels?.dispose();
        if (!event.persisted) { localSceneryPreview?.dispose(); sceneryManager?.dispose(); regional3D?.dispose(); }
        if (!event.persisted) mapCredits?.dispose();
    });
    let rendererReady = false;
    let obstacleWms = null, obstacleVectors = null, hazardAreas = null, bridgeSupports = null, obstacleViewportTracker = null, obstacleViewportKey = null;
    let situationalLayers = null, roadNavigation = null, mapCompass = null;
    let terrainManager = null;
    let flyer = null, routePlayback = null, flightRecording = null, liveRadio = null, scenePerformance = null, sceneEnvironment = null, tunnels = null, tunnelVolumes = null, infrastructureClearance = null, modelCollisions = null, windLayer = null, globePositions = null, applyFlightTime = null, requestedFlightTime = null;
    let schematicTunnelsEnabled = false, structuresForTunnelScan = false;
    let mapLabels = null, mapCredits = null, localSceneryPreview = null, sceneryManager = null, regional3D = null;
    let regionalTerrain = false, regionalTerrainChanging = false, regionalBuildingsRequested = false, regionalTerrainRevision = 0;
    let sceneryCatalogReady = Promise.resolve();
    let bridgeHeightMatch={phase:"idle"};
    let touchControlsVisible=true;
    function setTouchControls(visible){
        if(typeof visible!=='boolean')throw Error('Invalid touch visibility');
        touchControlsVisible=visible;disposeGroundControls?.setVisible(visible);
        const toggle=document.getElementById('flight-show-touch');if(toggle)toggle.checked=visible;
        activeViewer?.scene.requestRender();
    }
    let walker = null, routeEditor = null, routeOverlays = null, signalAnalysis = null, disposeGroundControls = null;
    let uasImportRevision = 0;
    const offline = new URLSearchParams(window.location.search).get("offline") === "1";
    const regional3DTest = new URLSearchParams(window.location.search).get("regional3DTest") === "1";
    let regional3DEnabled=regional3DTest; // explicit build-time test opt-in only
    const floatingChrome = new URLSearchParams(window.location.search).get('chrome') === 'floating';
    if (floatingChrome) document.documentElement.classList.add('floating-map-chrome');
    let currentMapStyle = "satellite";
    let mapProviders = FPVMapProviders.createAdapters(Cesium, window.FPVMapProviderConfig);
    const terrainAvailable = () => terrainManager?.status().state === "ready";
    const offlineReason = () => offline ? "diagnosticOffline" :
        navigator.onLine === false && !window.FPVMapProviderConfig?.cacheRoot ? "networkOffline" : null;
    window.addEventListener("offline", () => {
        terrainManager?.networkChanged();mapLabels?.networkChanged();sceneEnvironment?.networkChanged();regional3D?.tick(true);
        if (activeViewer) refreshRegionalImagery(currentMapStyle);
    });
    window.addEventListener("online", () => {
        terrainManager?.networkChanged();mapLabels?.networkChanged();sceneEnvironment?.networkChanged();regional3D?.tick(true);
        if (activeViewer) refreshRegionalImagery(currentMapStyle);
    });

    let activeViewer = null;
    let activeBaseLayer = null;
    let activeRegionalLayers = [];
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

    function stopNavigation(reason = null, {preserveTunnel = false} = {}) {
        if(typeof FPVCaptureMode!=='undefined')FPVCaptureMode.set(document,false);
        tunnels?.stop();routePlayback?.interrupt(reason);walker?.stop(reason);flyer?.stop(reason);
        if(!preserveTunnel)tunnelVolumes?.stop();
    }
    function navigationActive() { return flyer?.active || walker?.status().active; }
    function simulationSpawn(command) {
        if (command.latitude != null || command.longitude != null) return {latitude:command.latitude,longitude:command.longitude};
        const canvas=activeViewer.canvas;
        const ray=activeViewer.camera.getPickRay(new Cesium.Cartesian2(canvas.clientWidth/2,canvas.clientHeight/2));
        const target=ray && activeViewer.scene.globe.pick(ray,activeViewer.scene);
        if(!target)throw new Error('Point the camera at terrain or select a map point before spawning');
        const position=Cesium.Cartographic.fromCartesian(target);
        return {latitude:Cesium.Math.toDegrees(position.latitude),longitude:Cesium.Math.toDegrees(position.longitude)};
    }

    function resetCamera() {
        stopNavigation();
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

        stopNavigation();
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

    function refreshRegionalImagery(style) {
        // WMS imagery only. No fake elevation/terrain availability is asserted.
        // Place directly above the base imagery, below user-selected overlays.
        const regional = mapProviders.regionalImagery?.(style, Boolean(offlineReason())) ?? [];
        const added=[];
        try {
            for (const provider of regional) {
                const layer=new Cesium.ImageryLayer(provider);
                activeViewer.imageryLayers.add(layer,1+added.length);
                added.push(layer);
            }
        } catch(error) {
            for (const layer of added) activeViewer.imageryLayers.remove(layer,true);
            throw error;
        }
        for (const layer of activeRegionalLayers) activeViewer.imageryLayers.remove(layer,true);
        activeRegionalLayers=added;
    }

    function setMapStyle(style) {
        const provider = createMapProvider(style);
        const newLayer = new Cesium.ImageryLayer(provider);

        activeViewer.imageryLayers.add(newLayer, 0);
        try { refreshRegionalImagery(style); }
        catch (error) {
            activeViewer.imageryLayers.remove(newLayer,true);
            throw error;
        }

        if (activeBaseLayer) {
            activeViewer.imageryLayers.remove(
                activeBaseLayer,
                true
            );
        }

        activeBaseLayer = newLayer;
        currentMapStyle = style;
        // A finer terrain LOD also retains the associated, labelled imagery
        // one level longer when zooming out. Keep flight rendering independent.
        if (!navigationActive()) activeViewer.scene.globe.maximumScreenSpaceError =
            style === 'topographic' ? 1 : 2;
        activeViewer.scene.requestRender();

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

    async function queryTerrainElevation(command, signal, allowUnverified = false) {
        const { latitude, longitude } = command;
        if(regionalTerrain&&!allowUnverified)throw Error("BKG beta terrain vertical datum has not been verified for geographic elevation queries");
        if (!Number.isFinite(latitude) || !Number.isFinite(longitude) ||
            latitude < -90 || latitude > 90 || longitude < -180 || longitude > 180) {
            throw new Error("Invalid terrain coordinates");
        }
        const position = Cesium.Cartographic.fromDegrees(longitude, latitude);
        if(!mapProviders.containsTerrainPoint(longitude,latitude))throw new Error('Terrain is outside the prepared offline region');
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
            heightReference: regionalTerrain ? "unverified" : "wgs84Ellipsoid",
            samplingMethod: detailed ? "most-detailed" : "level-12" };
    }

    let spotsDataSource = null;
    let spotGrounding = null;
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
            spotGrounding = FPVGlobePositions.createSpotGrounding(Cesium, activeViewer.scene);

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

                let entity = entities.getById(id);

                if (!entity) {
                    entity = entities.add({
                        id,
                        name: spot.name,
                        position: new Cesium.ConstantPositionProperty(),
                        show: false,
                        point: {
                            pixelSize: 13,
                            color: Cesium.Color.CYAN,
                            outlineColor: Cesium.Color.BLACK,
                            outlineWidth: 2
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
                            distanceDisplayCondition:
                                new Cesium.DistanceDisplayCondition(
                                    0,
                                    15000
                                )
                        }
                    });
                } else {
                    entity.name = spot.name;
                    entity.label.text = spot.name;
                }
                spotGrounding.set(entity, spot.longitude, spot.latitude);
            }

            for (const entity of [...entities.values]) {
                if (!expectedIds.has(entity.id)) {
                    entities.removeById(entity.id);
                    spotGrounding.remove(entity.id);
                }
            }
        } finally {
            entities.resumeEvents();
        }

        lastSpotRevision = revision;
    }

    function bridgeMatchStatus(){
        // Local operator measurements only: no automatic geodetic certification.
        return {...bridgeHeightMatch};
    }
    function resetBridgeHeightMatch(){
        if(bridgeHeightMatch.id){try{sceneryManager?.setPreviewHidden(bridgeHeightMatch.id,false);}catch(_){}}
        bridgeHeightMatch={phase:'idle'};
        activeViewer?.scene?.requestRender?.();
    }
    function bridgeMatchPick(pixel){
        if(!bridgeHeightMatch||!['scan','target'].includes(bridgeHeightMatch.phase))return false;
        const scene=activeViewer.scene,id=bridgeHeightMatch.id;
        try{
            if(!scene.pickPositionSupported)throw Error('Depth picking is not supported on this device');
            if(!regionalTerrain||regionalTerrainChanging)throw Error('BKG terrain is no longer active');
            const picked=scene.pick(pixel);
            if(bridgeHeightMatch.phase==='scan'){
                if(!sceneryManager?.previewModels(id).includes(picked?.primitive))
                    throw Error('Bitte einen sichtbaren Bodenbereich des Originalscans antippen (nicht die Karte)');
                const xyz=scene.pickPosition(pixel);
                const c=xyz&&Cesium.Cartographic.fromCartesian(xyz);
                if(!c||!Number.isFinite(c.height))throw Error('Keine gültige Tiefeninformation für den Scan-Boden vorhanden');
                bridgeHeightMatch={...bridgeHeightMatch,phase:'target',source:{
                    longitude:Cesium.Math.toDegrees(c.longitude),latitude:Cesium.Math.toDegrees(c.latitude),height:c.height}};
                sceneryManager.setPreviewHidden(id,true);
                info.textContent='Bodenabgleich: Jetzt die gleiche Stelle auf dem Kartengelände antippen (Scan ausgeblendet)';info.hidden=false;
                scene.requestRender?.();
                return true;
            }
            // Only compare a scanned ground point to real Cesium terrain,
            // not the roof of a BKG LoD2 building (different ground level).
            const tiles=regional3D?.visualOnlyModels()??[];
            const lod2=tiles.some(t=>t===picked?.primitive||t===picked?.tileset||t===picked?.content?.tileset||t===picked?.primitive?.tileset);
            if(lod2||picked&&picked.primitive!==scene.globe)
                throw Error('Bitte nur die freie Geländeoberfläche wählen, kein LoD2-Gebäude oder anderes Objekt');
            const ray=activeViewer.camera.getPickRay(pixel);
            const xyz=ray&&scene.globe.pick(ray,scene);
            const c=xyz&&Cesium.Cartographic.fromCartesian(xyz);
            if(!c||!Number.isFinite(c.height))throw Error('Kein Gelände-Höhenschnitt unter dem gewählten Punkt vorhanden');
            const target={longitude:Cesium.Math.toDegrees(c.longitude),latitude:Cesium.Math.toDegrees(c.latitude),height:c.height};
            const current=sceneryManager.snapshot().find(x=>x.id===id);
            if(!current||current.heightState!=='adjusted')throw Error('Scenery terrain calibration is no longer ready');
            if(typeof globalThis.FPVSceneryBridgeCalibration?.compare!=='function')
                throw Error('Bodenabgleich-Modul fehlt im Android-Asset-Bundle; App mit aktualisierter pubspec.yaml neu bauen');
            const result=globalThis.FPVSceneryBridgeCalibration.compare(bridgeHeightMatch.source,target,current.bkgHeightOffsetM??0);
            bridgeHeightMatch={phase:'proposal',id,source:bridgeHeightMatch.source,target,
                surface:'terrain',...result};
            sceneryManager.setPreviewHidden(id,false);
            info.textContent=`Bodenabgleich: ${result.deltaM>=0?'+':''}${result.deltaM.toFixed(2)} m · BKG-Versatz ${result.proposedOffsetM.toFixed(2)} m · im Menü prüfen/übernehmen`;
            info.hidden=false;
            scene.requestRender?.();
        }catch(error){
            bridgeHeightMatch={...bridgeHeightMatch,error:String(error?.message??error)};
            info.textContent=bridgeHeightMatch.error;info.hidden=false;
            activeViewer.scene.requestRender?.();
        }
        return true;
    }

    async function executeCommand(command, signal) {
        signal.throwIfAborted();
        if (!activeViewer) throw new Error("Globe is not initialized");
        switch (command.type) {
            case 'scenery-catalog': await sceneryCatalogReady; if(!sceneryManager)throw Error('Scenery unavailable');return {catalog:sceneryManager.bundledCatalog()};
            case 'replace-scenery-catalog':
                if(navigationActive()||flyer?.pending||walker?.status().pending||routePlayback?.loaded)throw Error('Stop navigation before changing scenery');
                await sceneryCatalogReady;if(!sceneryManager)throw Error('Scenery unavailable');
                resetBridgeHeightMatch();
                {const sceneries=sceneryManager.replaceCatalog(command.catalog);regional3D?.tick(true);return {sceneries};}
            case 'scenery-status': await sceneryCatalogReady; return {sceneries:sceneryManager?.snapshot()??[],regionalTerrain,regionalTerrainChanging,bridgeHeightMatch:bridgeMatchStatus(),replacement:regional3D?.replacementStatus()??null};
            case 'begin-scenery-bridge-height-match': {
                await sceneryCatalogReady;
                if(navigationActive()||flyer?.pending||walker?.status().pending||routePlayback?.loaded)
                    throw Error('Stop navigation before ground height matching');
                if(!regionalTerrain||regionalTerrainChanging)throw Error('Enable BKG 3D Beta terrain first');
                if(!activeViewer.scene.pickPositionSupported)throw Error('3D depth picking unavailable');
                if(typeof globalThis.FPVSceneryBridgeCalibration?.compare!=='function')
                    throw Error('Bodenabgleich-Modul fehlt im App-Bundle; pubspec.yaml prüfen und APK neu erstellen');
                const item=sceneryManager?.snapshot().find(x=>x.id===command.id);
                if(!item||item.heightState!=='adjusted'||!item.enabled||!sceneryManager.previewModels(command.id).length)
                    throw Error('Local scan must be loaded and terrain-calibrated');
                resetBridgeHeightMatch();
                bridgeHeightMatch={phase:'scan',id:command.id};
                info.textContent='Bodenabgleich: Geeignete ebene Bodenfläche möglichst mittig im Originalscan antippen';info.hidden=false;
                return {sceneries:sceneryManager.snapshot(),bridgeHeightMatch:bridgeMatchStatus()};
            }
            case 'cancel-scenery-bridge-height-match': {
                resetBridgeHeightMatch();
                return {sceneries:sceneryManager?.snapshot()??[],bridgeHeightMatch:bridgeMatchStatus()};
            }
            case 'restore-scenery-preferences': await sceneryCatalogReady; sceneryManager?.restorePreferences(command.preferences); return {};
            case 'set-scenery-enabled': if(navigationActive()||flyer?.pending||walker?.status().pending||routePlayback?.loaded)throw Error('Stop navigation before changing scenery'); await sceneryCatalogReady; if(!sceneryManager)throw Error('Scenery unavailable');return {sceneries:sceneryManager.setEnabled(command.id,command.enabled)};
            case 'set-scenery-edit': await sceneryCatalogReady; if(!sceneryManager)throw Error('Scenery unavailable');
                if(navigationActive()||flyer?.pending||walker?.status().pending||routePlayback?.loaded)throw Error('Stop navigation before editing scenery');
                {resetBridgeHeightMatch();const sceneries=sceneryManager.setEdit(command.id,command.edit);regional3D?.tick(true);return {sceneries,bridgeHeightMatch:bridgeMatchStatus(),replacement:regional3D?.replacementStatus()??null};}
            case 'restore-scenery-edits': await sceneryCatalogReady; sceneryManager?.restoreEdits(command.edits);regional3D?.tick(true);return {};
            case 'retry-scenery': if(navigationActive()||flyer?.pending||walker?.status().pending||routePlayback?.loaded)throw Error('Stop navigation before reloading scenery'); await sceneryCatalogReady; if(!sceneryManager)throw Error('Scenery unavailable');return {sceneries:sceneryManager.retry(command.id)};
            case 'tunnel-runtime-diagnostics': {
                // Explicit local snapshot: never broadcast tunnel identities,
                // flight positions, or rejection reasons as automatic telemetry.
                return tunnelVolumes?.diagnostics()??{active:false,count:0};
            }
            case 'flight-physics-diagnostics': {
                // On-demand only; do not stream per-frame state over the bridge.
                const state=flyer?.status();
                return {active:state?.active??false,
                    ...(state?.physicsDiagnostics??{model:'advanced',stepHz:null,
                        simulatedSeconds:0,queuedSeconds:0,droppedSeconds:0,
                        lastSubsteps:0,interpolationAlpha:1})};
            }
            case 'scene-performance': {
                // Explicit developer diagnostics only; does not update UI or
                // send per-frame events over the Flutter bridge.
                if(command.action==='start')scenePerformance.start();
                else if(command.action==='stop')scenePerformance.stop();
                else if(command.action!=='snapshot')throw Error('Invalid scene diagnostics action');
                return scenePerformance.snapshot();
            }
            case 'set-capture-mode': {
                if(typeof command.enabled!=='boolean')throw Error('Invalid capture mode');
                if(command.enabled && !flyer?.active)throw Error('Capture mode requires active simulation');
                return FPVCaptureMode.set(document,command.enabled);
            }
            case "set-language": rendererLanguage.setLanguage(command.language); return {};
            case "set-road-navigation": return roadNavigation.set(command);
            case "set-rendering-paused": {
                if(typeof command.paused!=='boolean')throw new Error('Invalid render loop state');
                if(command.paused)stopNavigation();
                activeViewer.useDefaultRenderLoop=!command.paused;
                if(!command.paused)activeViewer.scene.requestRender();
                return {};
            }
            case "set-situational-overlay": return situationalLayers.set(command);
            case "set-weather-overlay": return weatherOverlay.replace(command);
            case "set-meteoswiss-radar": return meteoswissRadar.replace(command, signal);
            case "clear-meteoswiss-radar": return meteoswissRadar.clear();
            case "set-dated-imagery": return datedImagery.replace(command, signal);
            case "clear-dated-imagery": return datedImagery.clear();
            case 'set-touch-controls': setTouchControls(command.visible); return {};
            case 'set-device-location': return globePositions.location(command);
            case 'set-map-labels': return mapLabels.set(command);
            case 'set-search-destination': stopNavigation(); return globePositions.destination(command);
            case 'set-wind-field': return windLayer.set(command);
            case 'query-wind-center': {
                const flying=flyer?.active?flyer.status().position:null;
                if(flying)return flying;
                const scene=activeViewer.scene,canvas=activeViewer.canvas;
                const ray=activeViewer.camera.getPickRay(new Cesium.Cartesian2(canvas.clientWidth/2,canvas.clientHeight/2));
                const hit=ray&&scene.globe.pick(ray,scene);
                const point=hit?Cesium.Cartographic.fromCartesian(hit):activeViewer.camera.positionCartographic;
                return {latitude:Cesium.Math.toDegrees(point.latitude),longitude:Cesium.Math.toDegrees(point.longitude)};
            }
            case "clear-weather-overlay": return weatherOverlay.clear(command.kind);
            case "set-obstacle-wms": obstacleWms.set(command); return {};
            case "set-obstacle-vectors": await obstacleVectors.replace(command,signal); return {};
            case "set-hazard-areas": await hazardAreas.replace(command,signal); return {};
            case "enter-ground-view": if(regionalTerrainChanging)throw Error("Regional terrain is changing; retry after loading"); flyer?.stop(); return walker.start(command, signal);
            case "enter-simulation": {
                if(regionalTerrainChanging)throw Error("Regional terrain is changing; retry after loading");
                if(routePlayback?.loaded)routePlayback.interrupt();
                if(flyer.active)return flyer.reconfigure(command,signal);
                const point = simulationSpawn(command);
                // Preserve a local collision mesh when the user explicitly
                // enables model contacts in ordinary FPV simulation.
                const preserveTunnel=tunnelVolumes?.status()?.collisionEnabled===true &&
                    !tunnelVolumes?.flight;
                stopNavigation(null,{preserveTunnel});
                const preview=command.sceneTime??{enabled:false};
                if(typeof preview.enabled!=='boolean')throw Error('Invalid flight lighting preview');
                FPVSceneEnvironment.time(preview.timeUtc);
                requestedFlightTime=preview;
                try{return await flyer.start({...command,...point},signal);}
                finally{if(requestedFlightTime===preview)requestedFlightTime=null;}
            }
            case "exit-simulation": stopNavigation(); return {};
            case "reset-simulation": return routePlayback?.loaded
                ? routePlayback.control({action:'restart'}) : flyer.reset(signal);
            case 'start-route-playback': {
                if(regionalTerrainChanging)throw Error('Regional terrain is changing; retry after loading');
                if(infrastructureClearance?.hasUnverifiedTunnel() || (tunnelVolumes?.model && tunnelVolumes.model.clearanceVerified!==true))
                    throw Error('Remove the unverified simulation tunnel before route playback; no safe tunnel clearance is established.');
                stopNavigation();
                const preview=command.settings?.sceneTime??{enabled:false};
                if(typeof preview.enabled!=='boolean')throw Error('Invalid replay lighting preview');
                FPVSceneEnvironment.time(preview.timeUtc);
                requestedFlightTime=preview;
                try{return await routePlayback.start(command,signal);}
                finally{if(requestedFlightTime===preview)requestedFlightTime=null;}
            }
            case 'route-playback-control': return routePlayback.control(command);
            case 'flight-recording-control': return flightRecording.control(command);
            case 'set-flight-radio-monitor': return liveRadio.monitor(command);
            case 'query-live-radio-terrain': if(regionalTerrain)throw Error('TERRAIN_UNAVAILABLE: BKG beta terrain height datum is not validated for RF planning');return liveRadio.sample(command,signal);
            case 'set-live-radio-result': return liveRadio.set(command);
            case 'set-live-radio-diagnostics': return liveRadio.setDiagnostics(command);
            case 'set-live-radio-ground-station': return liveRadio.station(command);
            case "navigation-input": disposeGroundControls?.native(command); return {};
            case 'set-bkg-3d-test': {
                if(typeof command.enabled!=='boolean')throw Error('BKG test toggle must be boolean');
                if(command.enabled&&(offline||offlineReason()||navigator.onLine===false||
                    window.FPVMapProviderConfig?.prepared||window.FPVMapProviderConfig?.preparedUnavailable||
                    window.FPVMapProviderConfig?.terrain||new URLSearchParams(window.location.search).get('cachedMaps')==='1')){
                    throw Error('BKG 3D test streaming requires the online, non-cached globe');
                }
                regional3DEnabled=command.enabled;
                regional3D?.tick(true);
                return {enabled:regional3DEnabled,active:regional3D?.region()===true};
            }
            case 'set-scene-environment': {
                const result=sceneEnvironment.set(command);
                regionalBuildingsRequested=command.buildings;regional3D?.tick(true);
                // The fully enabled 3D infrastructure layer also discovers
                // schematic tunnel centerlines near the viewed terrain.
                structuresForTunnelScan = command.structures===true;
                tunnels?.setAutomatic(structuresForTunnelScan || schematicTunnelsEnabled);
                if(command.modelCollisions!==undefined){
                    modelCollisions?.setEnabled(command.modelCollisions);
                    tunnelVolumes?.setCollisionEnabled(command.modelCollisions);
                    infrastructureClearance?.setCollisionEnabled(command.modelCollisions);
                }
                return result;
            }
            case 'set-tunnel-infrastructure': {
                if(typeof command.autoModels!=='boolean')throw Error('Schematic tunnel option missing');
                const previouslyEnabled=schematicTunnelsEnabled;
                schematicTunnelsEnabled=command.autoModels;
                tunnelVolumes?.setAutomaticEnabled(schematicTunnelsEnabled);
                const cached=(!previouslyEnabled&&schematicTunnelsEnabled) ? tunnels?.snapshot?.() : null;
                // Reuse existing official/OSM axes when the 3D switch is turned
                // on after the structure layer has already scanned the area.
                if(cached?.routes?.length)void tunnelVolumes?.setAutomaticRoutes(cached.routes,cached.center).catch(()=>{});
                tunnels?.setAutomatic(structuresForTunnelScan || schematicTunnelsEnabled,
                    !!(cached && !cached.routes.length));
                if(command.routesVisible===false&&!schematicTunnelsEnabled){
                    tunnelVolumes?.stop();infrastructureClearance?.forgetTunnel();
                }
                return tunnels.set(command);
            }
            case 'scan-tunnel-infrastructure': {
                tunnelVolumes?.stop();
                // Explicit one-shot viewport query: never scan every camera movement.
                const canvas = activeViewer.canvas;
                const ray = activeViewer.camera.getPickRay(new Cesium.Cartesian2(
                    canvas.clientWidth / 2, canvas.clientHeight / 2));
                const hit = ray && activeViewer.scene.globe.pick(ray, activeViewer.scene);
                if (!hit) throw Error('Point the center of the map at Swiss terrain before searching for tunnel axes.');
                const center = Cesium.Cartographic.fromCartesian(hit);
                return tunnels.scan({longitude: Cesium.Math.toDegrees(center.longitude),
                    latitude: Cesium.Math.toDegrees(center.latitude),
                    radiusMeters: command.radiusMeters ?? 600}, signal);
            }
            case 'focus-tunnel-route': stopNavigation(); return tunnels.focus(command);
            case 'explore-tunnel-route': stopNavigation(); return tunnels.explore(command);
            case 'exit-tunnel-exploration': tunnels.stop(); return {};
            case 'prepare-tunnel-model': {
                if(!tunnels||!tunnelVolumes)throw Error('3D tunnel renderer unavailable.');
                stopNavigation();
                const source=tunnels.geometry(command.routeId);
                const result = await tunnelVolumes.prepare(source,{widthMeters:command.widthMeters??6,
                    heightMeters:command.heightMeters??5,profile:command.profile??'vaulted'},signal);
                infrastructureClearance?.retainTunnel(tunnelVolumes.model);
                return result;
            }
            case 'import-tunnel-model': {
                if(!tunnelVolumes)throw Error('Tunnel renderer unavailable.');
                // Keep a previously displayed mesh until the new source is
                // validated. importModel() owns validated replacement.
                stopNavigation(null,{preserveTunnel:true});
                if(JSON.stringify(command.document??{}).length>2097152)
                    throw Error('Tunnel geometry exceeds the 2 MiB transfer limit.');
                const result = tunnelVolumes.importModel(command.document);
                infrastructureClearance?.retainTunnel(tunnelVolumes.model);
                return result;
            }
            case 'remove-tunnel-model': stopNavigation(); infrastructureClearance?.forgetTunnel(); return {};
            case 'enter-tunnel-flight': {
                if(!tunnelVolumes?.model)throw Error('Import or create a tunnel model first.');
                if(!terrainAvailable())throw Error('Detailed terrain is required for virtual tunnel flight.');
                if(!['gps','angle','acro'].includes(command.flightMode))throw Error('Invalid virtual flight mode.');
                tunnels?.stop();routePlayback?.interrupt();walker?.stop();flyer?.stop();
                const spawn=tunnelVolumes.firstPose();
                try{
                    const flightPreferences=flyer.status();
                    await flyer.start({latitude:spawn.latitude,longitude:spawn.longitude,
                        agl:1,flightMode:command.flightMode,maxSpeed:5,climbSpeed:3,
                        acceleration:3,deceleration:4,
                        cameraFovDegrees:flightPreferences.cameraFovDegrees,
                        cameraTiltDegrees:flightPreferences.cameraTiltDegrees,
                        hudStyle:flightPreferences.hudStyle,graphicsProfile:flightPreferences.graphicsProfile,
                        physicsModel:flightPreferences.physicsModel,physicsStepHz:flightPreferences.physicsStepHz,
                        showCoordinates:flightPreferences.showCoordinates},signal);
                    signal.throwIfAborted();
                    tunnelVolumes.activate();
                    flyer.enterTunnel(spawn);
                    return {active:true,quality:tunnelVolumes.model.quality};
                }catch(error){flyer?.stop('Tunnel flight stopped');tunnelVolumes.stop();throw error;}
            }
            case 'import-infrastructure-clearance': {
                if (!infrastructureClearance) throw Error('Infrastructure analysis unavailable.');
                if (JSON.stringify(command.document ?? {}).length > 65536)
                    throw Error('Infrastructure geometry file exceeds 64 KiB.');
                return infrastructureClearance.replace(command.document);
            }
            case 'query-infrastructure-clearance': {
                if (!infrastructureClearance) throw Error('Infrastructure analysis unavailable.');
                signal?.throwIfAborted?.();
                const report = await infrastructureClearance.assessRoute(command, signal);
                signal?.throwIfAborted?.();
                return report;
            }
            case 'set-infrastructure-clearance-layer':
                return infrastructureClearance?.setVisible(command.visible, command.clearReport) ?? {};
            case 'set-navigation-environment': return sceneEnvironment.navigation(command);
            case 'set-scene-time': return sceneEnvironment.setTime(command);
            case "exit-ground-view": stopNavigation(); return {};
            case "set-route-editor": stopNavigation(); return routeEditor.set(command, signal);
            case "set-signal-analysis": return signalAnalysis.set(command);
            case "set-visible-routes": return routeOverlays.set(command, signal);
            case "frame-visible-routes": stopNavigation(); await routeOverlays.frame(command.routeId, signal); return {};
            case "frame-route": stopNavigation(); await routeEditor.frame(signal); return {};
            case "reset-camera": resetCamera(); return {};
            case "reload-renderer": setTimeout(() => window.location.reload(), 0); return {};
            case "retry-terrain": {
                await terrainManager.retry(signal);
                signal.throwIfAborted();
                // Refresh failed imagery requests too, preserving the selected style.
                if (terrainAvailable()) setMapStyle(currentMapStyle);
                regional3D?.retry();
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
                if(regionalTerrain)throw Error("BKG beta terrain is not validated for route elevation profiles");
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
                    stopNavigation();
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
            stopNavigation();
            if (rendererReady) {
                terrainManager.networkChanged();
                sendToFlutter("globe-ready", { terrainAvailable: terrainAvailable(),
                    transport: { gzipBase64: typeof FPVGlobeBridge.supportsGzipBase64 === "function" &&
                        FPVGlobeBridge.supportsGzipBase64(), transferCredits: true } });
                sendToFlutter("terrain-status", terrainManager.status());
                sendToFlutter('terrain-resource-warning',{active:terrainManager.hasWarning});
                publishObstacleViewport(true);
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
        await window.FPVPreparedOfflineReady;
        mapProviders=FPVMapProviders.createAdapters(Cesium,window.FPVMapProviderConfig);
        const info = document.getElementById("info");
        let selectedPointInfo = null;
        const pointLabel = () => regionalTerrain ? "BKG 3D-Beta · experimental terrain; vertical datum not verified" : selectedPointInfo[2] === undefined
            ? translate('Lat: {0} | Lon: {1} | Flat map — terrain height unavailable', ...selectedPointInfo)
            : translate('Lat: {0} | Lon: {1} | Height: {2} m (WGS84 ellipsoid, rendered terrain)', ...selectedPointInfo);

        const imageryProvider = createMapProvider("satellite");

        function terrainInfo(status) {
            info.hidden = !!flyer?.active || (floatingChrome && status.state === 'ready' && !selectedPointInfo && !walker?.active);
            info.textContent = status.state === "ready"
                ? regionalTerrain ? "BKG 3D-Beta · test only; vertical datum not verified" : selectedPointInfo ? pointLabel() : translate("FPVManager | 3D terrain loaded")
                : status.state === "loading"
                    ? translate("Connecting to 3D terrain | Flat map shown")
                    : translate("3D terrain unavailable | Flat map shown — terrain heights disabled");
        }
        terrainManager = FPVTerrain.createTerrainManager({
            createProvider: () => regionalTerrain ? FPVRegional3D.terrain(Cesium) : mapProviders.terrain(),
            createFallback: () => new Cesium.EllipsoidTerrainProvider(),
            applyProvider: provider => {
                if (activeViewer) activeViewer.terrainProvider = provider;
            },
            offlineReason,
            onWarning: active => {
                if (rendererReady) sendToFlutter('terrain-resource-warning',{active});
            },
            // Validate every global root, including the eastern root covering
            // Switzerland. Prepared regional packages use their packaged root.
            probe: (provider, signal) => {
                const root=regionalTerrain?provider.tilingScheme.positionToTileXY(Cesium.Cartographic.fromDegrees(10.4515,51.1657),0):null;
                return FPVTerrain.probeRootTiles(provider,signal,root?[[root.x,root.y,0]]:window.FPVMapProviderConfig?.prepared?[mapProviders.terrainProbe]:undefined);
            },
            onStatus: status => {
                if (status.state !== "ready") selectedPointInfo = null;
                if (status.state !== "ready") stopNavigation("Terrain unavailable; returned to globe view");
                routeEditor?.terrainChanged();
                routeOverlays?.terrainChanged();
                signalAnalysis?.clear();
                liveRadio?.terrainChanged();
                obstacleVectors?.terrainChanged();
                windLayer?.terrainChanged();
                activeViewer?.scene?.requestRender?.();
                terrainInfo(status);
                if (rendererReady) sendToFlutter("terrain-status", status);
                if (status.state === "ready") publishObstacleViewport();
            }
        });
        await terrainManager.initialize();

        FPVMapProviders.prepareCredits?.(Cesium,{usesIon:window.FPVMapProviderConfig?.usesIon===true});
        const viewer = new Cesium.Viewer("globe", {
            creditViewport: document.body,
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

        mapCredits=FPVMapProviders.configureCredits?.(Cesium,viewer)??null;
        viewer.scene.globe.depthTestAgainstTerrain = true;
        if(window.FPVMapProviderConfig?.prepared){
            const height=viewer.scene.globe.getHeight.bind(viewer.scene.globe);
            viewer.scene.globe.getHeight=point=>mapProviders.containsTerrainPoint(point.longitude*180/Math.PI,point.latitude*180/Math.PI)?height(point):undefined;
        }
        const flightRenderer = FPVFlightRendering.create(Cesium,viewer,{onProfile:value=>{sceneEnvironment?.performance(value);windLayer?.performance(value);
            tunnelVolumes?.setPerformanceProfile?.(value);},
            terrainPassage:(from,to)=>tunnelVolumes?.segmentInside(from,to)===true||
                tunnelVolumes?.artificialBoundaryNear(from)===true||
                tunnelVolumes?.artificialBoundaryNear(to)===true||
                sceneryManager?.replacementPassage(from,to,poly=>regional3D?.terrainMaskActive(poly)===true)===true});
        roadNavigation = FPVRoadNavigation.create(Cesium,viewer,
            follow=>sendToFlutter('road-navigation-follow',{follow}),
            {isTerrainReady:terrainAvailable,onActive:active=>{sceneEnvironment?.navigationActive(active);mapLabels?.navigation(active);}});
        mapCompass = FPVMapCompass.create(Cesium,viewer,document.getElementById('map-compass'),
            {navigation:roadNavigation,isEnabled:()=>!navigationActive(),language:rendererLanguage});
        activeViewer = viewer;
        const sampleSceneTerrain=async(points,signal)=>{
            const positions=points.map(p=>Cesium.Cartographic.fromDegrees(p.longitude,p.latitude));
            const heights=await terrainManager.sample(provider=>provider.availability
                ?Cesium.sampleTerrainMostDetailed(provider,positions,true)
                :Cesium.sampleTerrain(provider,12,positions,true),signal);
            return heights.map(p=>p.height);
        };
        const bridgeSource=typeof FPVBridgeSource!=='undefined'?FPVBridgeSource.create(Cesium,viewer,{
            cachedOnly:offline||new URLSearchParams(window.location.search).get('cachedMaps')==='1',
            getDeckTileset:()=>sceneEnvironment?.structuresTileset?.()}):null;
        bridgeSupports=typeof FPVBridgeSupports!=='undefined'
            ?FPVBridgeSupports.create(Cesium,viewer,{sampleTerrain:sampleSceneTerrain,
                ready:terrainAvailable,cachedOnly:offline||new URLSearchParams(window.location.search).get('cachedMaps')==='1',
                isNavigationActive:navigationActive,
                getDeckTileset:()=>sceneEnvironment?.structuresTileset?.(),
                discoverBridges:bridgeSource?.discover,disposeDiscovery:()=>bridgeSource?.dispose()})
            :null;
        sceneEnvironment = FPVSceneEnvironment.create(Cesium,viewer,sendToFlutter,{urls:window.FPVSceneSources,
            forestComposition:globalThis.FPVForestComposition?.create(),
            cachedOnly:offline||new URLSearchParams(window.location.search).get('cachedMaps')==='1',bridgeSupports,
            getTunnelApertures:()=>tunnelVolumes?.apertureSpecs?.()||[],
            getTunnelApertureRevision:()=>tunnelVolumes?.apertureRevision?.()??0});
        scenePerformance = FPVScenePerformance.create(viewer,{
            isContinuous:()=>flyer?.active===true&&!flyer.status().paused,
            resources:()=>sceneEnvironment?.resourceStats()??{}
        });
        tunnels = typeof FPVTunnelInfrastructure !== 'undefined'
            ? FPVTunnelInfrastructure.create(Cesium,viewer,sendToFlutter,{
                isTerrainReady:terrainAvailable,
                isSimulating:()=>flyer?.active===true,
                onRoutes:(routes,center)=>{
                    if(schematicTunnelsEnabled)void tunnelVolumes?.setAutomaticRoutes(routes,center).catch(()=>{});
                }})
            : null;
        tunnelVolumes = typeof FPVTunnelFlythrough !== 'undefined'
            ? FPVTunnelFlythrough.create(Cesium,viewer,sendToFlutter,{
                ready:terrainAvailable,
                isSimulating:()=>flyer?.active===true,
                sampleTerrain:sampleSceneTerrain,
                getDeckTileset:()=>sceneEnvironment?.structuresTileset?.()
            }) : null;
        windLayer = FPVWindField.create(Cesium,viewer,sendToFlutter,{isTerrainReady:terrainAvailable,language:rendererLanguage});
        globePositions = FPVGlobePositions.create(Cesium,viewer,sendToFlutter,{isTerrainReady:terrainAvailable,isNavigationActive:navigationActive});
        mapLabels = FPVMapLabels.create(Cesium,viewer,sendToFlutter,{cachedOnly:offline||new URLSearchParams(window.location.search).get('cachedMaps')==='1'});
        situationalLayers = FPVSituationalLayers.create(Cesium,viewer,sendToFlutter,FPVObstacles.createWms);
        obstacleWms = FPVObstacles.createWms(Cesium,viewer,sendToFlutter);
        hazardAreas = FPVObstacles.createHazards(Cesium,viewer);
        obstacleVectors = FPVObstacles.createVectors(Cesium,viewer,
            {isTerrainReady:terrainAvailable,onFeatures:features=>bridgeSupports?.setSourceFeatures(features,{
                sourceId:'aviation-obstacles',visible:true,elevationReference:'WGS84_ELLIPSOID',
                source:'BAZL aviation obstacles'})});
        obstacleViewportTracker = FPVObstacles.createViewportTracker(viewer);
        obstacleViewportKey = null;
        viewer.camera.moveEnd.addEventListener(publishObstacleViewport);
        // Zooming back can finish before local terrain arrives. Re-evaluate
        // as tiles arrive even when the camera no longer moves. The publisher
        // coalesces identical regions; unrelated pending tiles need not finish.
        viewer.scene.globe.tileLoadProgressEvent?.addEventListener(() => {
            publishObstacleViewport();
        });
        modelCollisions = typeof FPVSceneModelCollision !== 'undefined'
            ? FPVSceneModelCollision.create(Cesium,viewer,
                {hasVisibleModels:()=>flyer?.active===true&&(
                    sceneEnvironment?.hasVisibleModels?.()===true ||
                    obstacleVectors?.hasVisibleModels?.()===true),
                    extraVisualOnly:()=>[...(sceneryManager?.visualOnlyModels()??[]),...(regional3D?.visualOnlyModels()??[])]}) : null;
        infrastructureClearance = typeof FPVInfrastructureClearance !== 'undefined'
            ? FPVInfrastructureClearance.create(Cesium, viewer, () => tunnelVolumes?.model ?? null)
            : null;
        const groundPanel = document.getElementById("ground-controls");
        const flightButtons=document.getElementById('flight-buttons'),hud=document.getElementById('navigation-hud');
        const flightHud=FPVFlightHud.create(document,rendererLanguage,
            {diagnosticsEnabled:()=>liveRadio.diagnosticsEnabled,
                diagnostics:()=>liveRadio.diagnostics()}),device=document.getElementById('navigation-device');
        liveRadio=FPVLiveRadio.create({C:Cesium,viewer,terrain:terrainManager,ready:terrainAvailable,emit:sendToFlutter,doc:document,language:rendererLanguage,
            onAssessmentChange:()=>{if(flyer?.active){flyer.linkAssessment(liveRadio.assessment());
                flightHud.update(flyer.status(),viewer.camera.heading,liveRadio.assessment());}},
            layer:FPVSignalAnalysis.createLayer(Cesium,viewer,{name:'Simulated radio link'})});
        flightRecording=FPVFlightRecording.create({emit:sendToFlutter,getState:()=>flyer.status()});
        flightRecording.bind(document,rendererLanguage);
        const settingsButton=document.getElementById('settings-flight'),settingsPanel=document.getElementById('flight-options');
        const hudSelect=document.getElementById('flight-hud-style');
        const batteryToggle=document.getElementById('flight-battery-enabled'),
            batteryCellToggle=document.getElementById('flight-battery-cell'),
            batteryAutoThresholds=document.getElementById('flight-battery-auto-thresholds'),
            batteryLow=document.getElementById('flight-battery-low'),
            batteryCritical=document.getElementById('flight-battery-critical'),
            batteryError=document.getElementById('flight-battery-error');
        const signalInputs={djiWarning:'flight-signal-dji',betaflightBars:'flight-signal-bars',
            analogNoise:'flight-signal-analog',terrainIllustration:'flight-signal-terrain',
            analogIntensity:'flight-signal-intensity',weakThreshold:'flight-signal-weak',
            criticalThreshold:'flight-signal-critical',lostThreshold:'flight-signal-lost'};
        const signalElements=Object.fromEntries(Object.entries(signalInputs).map(([key,id])=>[key,document.getElementById(id)]));
        const signalError=document.getElementById('flight-signal-error');
        function syncSignalOptions(value){
            for(const [key,node] of Object.entries(signalElements))
                if(node.type==='checkbox')node.checked=value[key]===true;
                else node.value=String(key==='analogIntensity'?Math.round(value[key]*100):value[key]);
        }
        function updateSignalOptions(){
            const values={};
            for(const [key,node] of Object.entries(signalElements))
                values[key]=node.type==='checkbox'?node.checked:Number(node.value)/(key==='analogIntensity'?100:1);
            try{FPVSignalHud.settings(values);signalError.textContent='';flyer.signalHudSettings(values);}
            catch(error){signalError.textContent=translate(error.message);}
        }
        for(const input of Object.values(signalElements))input.addEventListener('change',updateSignalOptions);
        const failsafeFields={enabled:'flight-failsafe-enabled',mode:'flight-failsafe-mode',
            lossThreshold:'flight-failsafe-loss',recoveryThreshold:'flight-failsafe-recovery',
            activationDelaySeconds:'flight-failsafe-delay',recoveryDelaySeconds:'flight-failsafe-recovery-delay',
            rescueAltitudeMeters:'flight-failsafe-altitude',returnSpeedMetersPerSecond:'flight-failsafe-speed',
            climbSpeedMetersPerSecond:'flight-failsafe-climb',autoRecover:'flight-failsafe-auto'};
        const failsafeElements=Object.fromEntries(Object.entries(failsafeFields).map(([key,id])=>[key,document.getElementById(id)]));
        const failsafeError=document.getElementById('flight-failsafe-error'),
            failsafeResume=document.getElementById('flight-failsafe-resume'),
            failsafeTraining=document.getElementById('flight-failsafe-training'),
            failsafeTrainingQuality=document.getElementById('flight-failsafe-training-quality'),
            failsafeTrainingValue=document.getElementById('flight-failsafe-training-value');
        function syncFailsafeOptions(value){for(const [key,node] of Object.entries(failsafeElements))
            if(node.type==='checkbox')node.checked=value[key]===true;else node.value=String(value[key]);}
        function updateFailsafeOptions(){const values={};for(const [key,node] of Object.entries(failsafeElements))
            values[key]=node.type==='checkbox'?node.checked:node.tagName==='SELECT'?node.value:Number(node.value);
            try{FPVSimulatedFailsafe.configuration(values);failsafeError.textContent='';flyer.failsafeSettings(values);}
            catch(error){failsafeError.textContent=translate(error.message);}}
        for(const node of Object.values(failsafeElements))node.addEventListener('change',updateFailsafeOptions);
        function trainingSignal(){const quality=Number(failsafeTrainingQuality.value)/100;
            failsafeTrainingValue.textContent=`${Math.round(quality*100)} %`;
            liveRadio.setTrainingRc(failsafeTraining.checked?quality:null);}
        failsafeTraining.addEventListener('change',trainingSignal);
        failsafeTrainingQuality.addEventListener('input',trainingSignal);
        failsafeResume.addEventListener('click',()=>flyer.resumeAfterFailsafe());
        const coordinateToggle=document.getElementById('flight-show-coordinates');
        const cameraButton=document.getElementById('camera-flight'),cameraPanel=document.getElementById('flight-camera');
        const cameraSlider=document.getElementById('flight-camera-angle'),cameraValue=document.getElementById('flight-camera-value');
        const cameraFovSlider=document.getElementById('flight-camera-fov'),cameraFovValue=document.getElementById('flight-camera-fov-value');
        const cameraTiltRow=document.getElementById('flight-camera-tilt-row');
        const graphicsSelect=document.getElementById('flight-graphics-profile');
        const controllerPanel=FPVControllerInput.bindPanel(document,value=>flyer.controllerSettings(value),rendererLanguage);
        let flightTimeSettings={enabled:false,timeUtc:null};
        const timeControls=FPVSceneEnvironment.bindTimeControls(document,value=>applyFlightTime(value));
        applyFlightTime=(value=flightTimeSettings)=>{
            sceneEnvironment.setTime({scope:'flight',...value});flightTimeSettings=value;timeControls.update(value);
            sendToFlutter('scene-time-state',value);
        };
        let deviceMessage='', lastHud=0,lastReason=null;
        const lastModes={ground:false,flight:false};
        const cameraAdapter={
            isTerrainReady: terrainAvailable,
            sampleHeight: async (point, signal) => (await queryTerrainElevation(point, signal, true)).heightMeters,
            renderedHeight: point=>tunnelVolumes?.floorAt(point)??flightRenderer.renderedHeight(point),
            onSurfaceDiscontinuity: ({position,previousGround,nextGround,height})=>
                // At artificial segment limits the terrain probe can jump to
                // mountain height BEFORE the next 1.8-km mesh is committed.
                // Do not treat that height as the flight floor, regardless of
                // whether previousGround already holds the same stale value.
                Number.isFinite(nextGround)&&height<nextGround+.5&&
                tunnelVolumes?.artificialBoundaryNear(position)===true,
            sampleWind: point=>windLayer.sample(point),
            applyGraphics: flightRenderer.applyGraphics,
            prepareGraphics:async signal=>{
                applyFlightTime(requestedFlightTime??undefined);
                signal.throwIfAborted();
                sceneEnvironment.prepareGraphics();
                await flightRenderer.prepareGraphics(signal,({completed,total})=>{
                    if(signal.aborted||!flyer.status().pending)return;
                    info.hidden=false;
                    info.textContent=total
                        ?translate('Preparing flight… {0}%',Math.round(100*completed/total))
                        :translate('Preparing flight…');
                }, sceneEnvironment.prepareVegetationShaders);
            },
            captureCamera: () => {
                viewer.camera.cancelFlight();
                const saved = { destination: Cesium.Cartesian3.clone(viewer.camera.positionWC),
                    direction: Cesium.Cartesian3.clone(viewer.camera.directionWC),
                    up: Cesium.Cartesian3.clone(viewer.camera.upWC), heading: viewer.camera.heading,
                    near: viewer.camera.frustum.near, fov:viewer.camera.frustum.fov, inputs: viewer.scene.screenSpaceCameraController.enableInputs,
                    collision: viewer.scene.screenSpaceCameraController.enableCollisionDetection,
                    graphics:flightRenderer.captureGraphics(), mapStyle:currentMapStyle };
                viewer.scene.screenSpaceCameraController.enableInputs = false;
                viewer.scene.screenSpaceCameraController.enableCollisionDetection = false;
                viewer.camera.frustum.near = 0.1;
                return saved;
            },
            restoreCamera: saved => {
                viewer.scene.screenSpaceCameraController.enableInputs = saved.inputs;
                viewer.scene.screenSpaceCameraController.enableCollisionDetection = saved.collision;
                viewer.camera.frustum.near = saved.near;
                viewer.camera.frustum.fov = saved.fov;
                flightRenderer.restoreGraphics(saved.graphics);
                if (saved.mapStyle !== currentMapStyle) {
                    viewer.scene.globe.maximumScreenSpaceError = currentMapStyle === 'topographic' ? 1 : 2;
                }
                viewer.camera.setView({destination:saved.destination,orientation:{direction:saved.direction,up:saved.up}});
            }
        };
        function applyCamera(point){
            flightRenderer.applyPose(point);
            windLayer.navigation(flyer?.active?point:null);
        }
        function modeState(mode,state){
            if(mode==='flight')flightRecording.observe(state);
            if(mode==='flight')liveRadio.observe(state,true);
            const entering=state.active&&!lastModes[mode];lastModes[mode]=state.active;
            if(mode==='flight'){
                if(!state.active&&!state.pending&&routePlayback?.active)routePlayback.interrupt('Flight simulator stopped');
                if(!state.active&&!state.pending&&tunnelVolumes?.flight)tunnelVolumes.stop();
                if(entering)applyFlightTime(requestedFlightTime??undefined);
                else if(!state.active)sceneEnvironment.setTime({scope:'flight',enabled:false});
                if(!state.active){windLayer.navigation(null);
                    failsafeTraining.checked=false;liveRadio.setTrainingRc(null);}
            }
            groundPanel.hidden=!state.active||!touchControlsVisible; flightButtons.hidden=state.mode!=='gps'||!state.active||!touchControlsVisible;
            groundPanel.setAttribute?.('data-mode',state.mode==='gps'?'gps':mode);
            const flying=mode==='flight'&&state.active;
            hud.hidden=!flying; info.hidden=flying;
            if(!flying){settingsPanel.hidden=true;settingsButton.setAttribute('aria-expanded','false');}
            else {hudSelect.value=state.hudStyle;coordinateToggle.checked=state.showCoordinates===true;
                syncSignalOptions(state.signalHud);syncFailsafeOptions(state.failsafeSettings);
                failsafeResume.disabled=state.failsafe?.recoveryReady!==true;
                batteryToggle.checked=state.showBatteryVoltage===true;
                batteryCellToggle.checked=state.showBatteryCellVoltage===true;
                batteryAutoThresholds.checked=state.batteryUseChemistryThresholds===true;
                batteryLow.value=String(state.lowBatteryCellVoltage);
                batteryCritical.value=String(state.criticalBatteryCellVoltage);
                flightHud.update(state,viewer.camera.heading,liveRadio.assessment());controllerPanel.update(state.controller);}
            const fpv=mode==='flight'&&state.active;
            cameraButton.hidden=!fpv;
            if(!fpv){cameraPanel.hidden=true;cameraButton.setAttribute?.('aria-expanded','false');}
            if(fpv){
                cameraTiltRow.hidden=state.mode==='gps';
                cameraSlider.value=String(state.cameraTiltDegrees);cameraValue.textContent=`${state.cameraTiltDegrees}°`;
                cameraFovSlider.value=String(state.cameraFovDegrees);cameraFovValue.textContent=`${state.cameraFovDegrees}°`;
            }
            if(mode==='flight'&&state.graphicsProfile)graphicsSelect.value=state.graphicsProfile;
            if(!state.active){disposeGroundControls?.reset();terrainInfo(terrainManager.status());}
            if(entering)viewer.canvas.focus();
            disposeGroundControls?.sync();
            sendToFlutter(mode==='flight'?'simulation-state':'ground-view-state',{
                active:state.active,pending:state.pending,reason:state.active?null:state.reason??null,
                ...(mode==='flight'?{cameraTiltDegrees:state.cameraTiltDegrees,cameraFovDegrees:state.cameraFovDegrees,graphicsProfile:state.graphicsProfile,hudStyle:state.hudStyle,showCoordinates:state.showCoordinates,
                showBatteryVoltage:state.showBatteryVoltage,showBatteryCellVoltage:state.showBatteryCellVoltage,
                physicsModel:state.physicsModel,physicsStepHz:state.physicsStepHz,physicsDiagnostics:state.physicsDiagnostics,
                lowBatteryCellVoltage:state.lowBatteryCellVoltage,criticalBatteryCellVoltage:state.criticalBatteryCellVoltage,
                signalHud:state.signalHud,failsafe:state.failsafeSettings,
                controller:state.controller}:{})});
        }
        walker=FPVGroundNavigation.createWalker({...cameraAdapter,
            terrainCache:FPVGroundNavigation.createTerrainCache(viewer.scene.globe),
            applyPose:point=>{
                applyCamera(point);
                info.hidden=false;
                info.textContent=`${point.latitude.toFixed(6)}, ${point.longitude.toFixed(6)} | `+
                    translate('Ground: {0} m WGS84 | Eye: ≈ 2 m AGL | Look: {1}°',
                        (point.height-2).toFixed(1),(point.pitch*180/Math.PI).toFixed(0))+
                    (deviceMessage?` | ${translate(deviceMessage)}`:'');
            },onState:state=>modeState('ground',state)});
        flyer=FPVFreeFlight.createSimulator({...cameraAdapter,
            renderedHeight:point=>tunnelVolumes?.floorAt(point)??sceneryManager?.replacementHeight(point,poly=>regional3D?.terrainMaskActive(poly)===true)??flightRenderer.renderedHeight(point),
            measurePhysicsStep:(integrate,dt)=>scenePerformance.measurePhysicsStep(integrate,dt),
            modeledCollision:(from,to)=>tunnelVolumes?.intersects(from,to)===true ? 'tunnel' :
                // A surface-height approximation must not fill the interior of
                // an explicitly modeled synthetic tube. Its geometric walls,
                // floor and ceiling are still tested by intersects() above.
                tunnelVolumes?.segmentInside(from,to)===true ? false :
                infrastructureClearance?.collision(from,to)===true ? 'bridge' :
                (!tunnelVolumes?.flight && modelCollisions?.collision(from,to)) || sceneryManager?.collision(from,to) || false,
            terrainCollision:flightRenderer.terrainCollision,
            applyPose:point=>{
                applyCamera(point);
                // Prefetch the next source-aligned window before a long tunnel
                // reaches its artificial mesh boundary. No live Overpass calls.
                const target=tunnelVolumes?.flightCoverageTarget(point);
                if(target)void tunnels?.prefetchFlight(target).catch(()=>{});
                flightRecording.observe(point);
                liveRadio.observe(point);flyer.linkAssessment(liveRadio.assessment());
                failsafeResume.disabled=point.failsafe?.recoveryReady!==true;
                const now=performance.now();if(now-lastHud<100&&point.reason===lastReason)return;lastHud=now;lastReason=point.reason;
                flightHud.update(point,viewer.camera.heading,liveRadio.assessment());
            },onState:state=>modeState('flight',state)});
        const playbackPanel=document.getElementById('route-playback');
        const playbackInfo=document.getElementById('route-playback-info');
        const playbackPause=document.getElementById('route-playback-pause');
        const playbackSpeed=document.getElementById('route-playback-speed');
        const playbackProgress=document.getElementById('route-playback-progress');
        const formatTime=value=>`${Math.floor(value/60)}:${String(Math.floor(value%60)).padStart(2,'0')}`;
        const playbackDisplay=state=>{
            playbackPanel.hidden=!state.loading&&!state.active&&state.phase!=='finished'&&state.phase!=='stopped';
            playbackPause.disabled=!state.active;
            playbackPause.textContent=translate(state.phase==='paused'?'Resume':'Pause');
            playbackProgress.value=state.progress;
            playbackSpeed.value=String(state.speed);
            playbackInfo.textContent=state.loading?translate('Preparing route & terrain…'):
                `${state.recorded?'Recorded':'Planned'} replay · ${state.phase} · ${formatTime(state.seconds)} / ${formatTime(state.duration)}`+
                (state.assumedHeight?' · assumed AGL':'')+(state.assumedSpeed?(state.recorded?' · speed derived where missing':' · fallback speed'):'');
        };
        routePlayback=FPVRoutePlayback.create({simulator:flyer,
            sampleGround:(points,signal)=>sampleRouteHeights(points,signal),
            renderedGround:flightRenderer.renderedHeight,
            emit:sendToFlutter,display:playbackDisplay});
        const replayCommand=command=>{try{routePlayback.control(command);}catch(error){playbackInfo.textContent=error.message;}};
        playbackPause.addEventListener('click',()=>replayCommand({action:routePlayback.status().phase==='paused'?'resume':'pause'}));
        document.getElementById('route-playback-stop').addEventListener('click',()=>replayCommand({action:'stop'}));
        document.getElementById('route-playback-restart').addEventListener('click',()=>replayCommand({action:'restart'}));
        playbackSpeed.addEventListener('change',()=>replayCommand({action:'speed',speed:Number(playbackSpeed.value)}));
        playbackDisplay(routePlayback.status());
        const playbackBlocking=()=>routePlayback?.active===true;
        const currentAgent=()=>flyer.active?flyer:walker;
        const navigation={status:()=>({active:!!navigationActive(),mode:flyer.active?flyer.flightMode:'ground',controller:flyer.controller}),stop:stopNavigation,
            key:(...args)=>{if(!playbackBlocking())currentAgent().key(...args);},
            stick:(...args)=>{if(!playbackBlocking())currentAgent().stick(...args);},
            look:(...args)=>{if(!playbackBlocking())currentAgent().look(...args);},
            flightInput:frame=>{if(!playbackBlocking())flyer.flightInput(frame);},
            vertical:v=>{if(flyer.active&&!playbackBlocking())flyer.vertical(v);},
            pause:value=>{if(playbackBlocking())replayCommand({action:value?'pause':'resume'});else flyer.pause(value);},
            clearKeys:()=>{walker.clearKeys();flyer.clearKeys();},
            reset:()=>{if(routePlayback?.loaded)replayCommand({action:'restart'});
                else if(flyer.active)flyer.reset().catch(()=>{});}};
        const controllerInterruptions=[];
        disposeGroundControls=FPVNavigationControls.bindControls(navigation,viewer.canvas,groundPanel,window,document,{
            onFocus:focused=>sendToFlutter('navigation-focus',{focused}),
            onInterruption:message=>{
                if(controllerInterruptions.at(-1)!==message)controllerInterruptions.push(message);
                if(controllerInterruptions.length>3)controllerInterruptions.shift();
                document.getElementById('controller-last-interruption').textContent=translate(
                    'Recent interruptions: {0}',controllerInterruptions.map(translateMessage=>translate(translateMessage)).join(' · '));
            },
            onDevice:message=>{deviceMessage=message;device.textContent=translate(message);flightHud.device(message);walker.refreshPose();}});
        rendererLanguage.onChange(()=>{
            if(walker.active)walker.refreshPose();
            else if(!flyer?.pending)terrainInfo(terrainManager.status());
            device.textContent=translate(deviceMessage);
            const playback=routePlayback?.status();
            if(playback)playbackDisplay(playback);
        });
        disposeGroundControls.setVisible(touchControlsVisible);
        document.getElementById('flight-show-touch').addEventListener('change',event=>{
            setTouchControls(event.target.checked);sendToFlutter('touch-controls-changed',{visible:touchControlsVisible});
        });
        document.getElementById('reset-flight').addEventListener('click',()=>{
            if(routePlayback?.loaded)replayCommand({action:'restart'});else flyer.reset().catch(()=>{});
        });
        document.getElementById('exit-flight').addEventListener('click',()=>stopNavigation());
        settingsButton.addEventListener('click',()=>{
            settingsPanel.hidden=!settingsPanel.hidden;
            settingsButton.setAttribute('aria-expanded',String(!settingsPanel.hidden));
            if(settingsPanel.hidden)viewer.canvas.focus();
        });
        hudSelect.addEventListener('change',()=>flyer.hudStyle(hudSelect.value));
        coordinateToggle.addEventListener('change',()=>flyer.showCoordinates(coordinateToggle.checked));
        const updateBatteryHud=()=>{
            const low=Number(batteryLow.value),critical=Number(batteryCritical.value);
            if(!Number.isFinite(low)||!Number.isFinite(critical)||critical<.5||critical>4.4||low<.6||low>4.5||low<=critical){
                batteryError.textContent=translate('Warnspannung muss höher als kritische Zellspannung sein.');return;
            }
            batteryError.textContent='';
            flyer.batteryHud({enabled:batteryToggle.checked,showCell:batteryCellToggle.checked,low,critical,
                useChemistryThresholds:batteryAutoThresholds.checked});
        };
        for(const item of [batteryToggle,batteryCellToggle,batteryAutoThresholds,batteryLow,batteryCritical])item.addEventListener('change',updateBatteryHud);
        cameraButton.addEventListener('click',()=>{
            cameraPanel.hidden=!cameraPanel.hidden;cameraButton.setAttribute('aria-expanded',String(!cameraPanel.hidden));
        });
        cameraSlider.addEventListener('input',()=>flyer.cameraTilt(Number(cameraSlider.value)));
        cameraFovSlider.addEventListener('input',()=>flyer.cameraFov(Number(cameraFovSlider.value)));
        graphicsSelect.addEventListener('change',()=>flyer.graphicsProfile(graphicsSelect.value));
        let lastWalkTime=performance.now();
        // Move before Cesium's controllers and camera-motion/underground
        // detection, so those observe the pose rendered by this frame too.
        viewer.scene.preUpdate.addEventListener(()=>{
            const now=performance.now(),seconds=(now-lastWalkTime)/1000;lastWalkTime=now;
            disposeGroundControls.tick(seconds);walker.tick(seconds);
            if(routePlayback?.active)routePlayback.tick(seconds);else flyer.tick(seconds);
        });
        const sampleRouteHeights = async (points, signal) => {
            if (!terrainAvailable()) throw new Error("Detailed terrain is required for the route preview");
            const positions = points.map(point => Cesium.Cartographic.fromDegrees(point.longitude, point.latitude));
            const sampled = await terrainManager.sample(provider => provider.availability
                ? Cesium.sampleTerrainMostDetailed(provider, positions, true)
                : Cesium.sampleTerrain(provider, 12, positions, true), signal);
            return sampled.map(point => point.height);
        };
        routeEditor = FPVRouteEditor.createEditor(Cesium, viewer, sendToFlutter, window, sampleRouteHeights, terrainAvailable,
            value=>sceneEnvironment.setTime({scope:'route',...value}));
        signalAnalysis = FPVSignalAnalysis.createLayer(Cesium, viewer);
        routeOverlays = FPVRouteEditor.createOverlays(Cesium, viewer, sampleRouteHeights, terrainAvailable,
            () => sendToFlutter("route-preview-error", {message:"Unable to rebuild saved routes. Retry the route preview in Map layers."}));
        viewer.scene.renderError.addEventListener((_scene, error) => {
            stopNavigation("Renderer unavailable; returned to globe view");
            sendToFlutter("globe-error", { message: String(error.message || error) });
        });
        activeBaseLayer = viewer.imageryLayers.get(0);
        refreshRegionalImagery(currentMapStyle);

        // Local catalog integrates with the normal globe; never moves the camera.
        if(typeof FPVSceneryManager!=='undefined') sceneryManager = FPVSceneryManager.create(Cesium,viewer,{
            debugWireframe:new URLSearchParams(window.location.search).get('sceneryCollisionDebug')==='1',
            sampleSeamGround:sampleSceneTerrain,
            terrainMaskActive:polygon=>regional3D?.terrainMaskActive(polygon)===true,
            terrainStable:()=>!regionalTerrainChanging,
            regionalHeightMode:()=>regionalTerrain,
            // R32: preserve the independent 34.25-m flat-ellipsoid Workbench
            // preview, but calibrate the actual Rüdersdorf model to the active
            // rendered terrain. A 34.25-m model ROOT places original ground at
            // only 1.79 m ellipsoidal height, beneath the actual DGM5 surface.
            // Provider identity invalidates samples on switch; missing terrain
            // never gets interpreted as sea level in BKG mode.
            terrainKey:()=>!regionalTerrainChanging&&terrainManager.status().state==='ready'?terrainManager.provider:null,
            sampleGround:async (alignment,item)=>{
                // Calibration points sampled from the original ground scan,
                // rather than an arbitrary single courtyard cell (which may
                // be a roof, steep edge or a missing BKG terrain patch).
                // XYZ: model-local coordinates, before georeferenced scale.
                const scanGround=[
                    [-3.8,0,-2.0069],[-2,0.2,-2.0362],[-4.6,0.5,-1.9719],
                    [-3,-3.5,-2.0566],[0,-3.5,-2.0853],[1.2,1.1,-2.038],
                    [2.1,2.1,-2.0392],[-5.4,-3.2,-2.0677]
                ];
                const angle=-alignment.rotationDeg*Math.PI/180,cos=Math.cos(angle),sin=Math.sin(angle);
                const positions=scanGround.map(([x,y])=>{
                    const coord=FPVSceneryAlignment.offset(alignment,
                        alignment.scale*(cos*x-sin*y),alignment.scale*(sin*x+cos*y));
                    return Cesium.Cartographic.fromDegrees(coord.longitude,coord.latitude);
                });
                // Prefer actual rendered Globe triangles, never BKG's raw
                // height samples when its vertical datum remains unverified.
                // A tile not yet resident is NOT evidence of zero elevation.
                const displayed=FPVSceneryManager.pickRenderedGroundHeights(Cesium,viewer,positions);
                let heights;
                if(regionalTerrain){
                    // A not-yet-loaded globe tile can return the ellipsoid
                    // surface (~0 m) instead of the DGM5 ground (~41 m normal
                    // height, or ~80 m ellipsoidal at this site). Do not use
                    // such fallback hits to sink the complete factory below
                    // the map. The range is deliberately broad and applies
                    // only to this bounded Rüdersdorf calibration.
                    const valid=displayed.map(h=>Number.isFinite(h)&&h>=20&&h<=150?h:NaN);
                    if(valid.filter(Number.isFinite).length<5)
                        throw Error('BKG ground calibration pending: fewer than five plausible rendered DGM5 intersections');
                    heights=valid;
                }else{
                    const sampled=await terrainManager.sample(provider=>provider.availability
                        ?Cesium.sampleTerrainMostDetailed(provider,positions,true)
                        :Cesium.sampleTerrain(provider,12,positions,true));
                    // For normal providers, require broad on-screen coverage
                    // before preferring rendered tiles over detailed samples.
                    heights=displayed.filter(Number.isFinite).length>=6
                        ?displayed:sampled.map(p=>p?.height);
                }
                return FPVSceneryManager.fitGroundReference(scanGround,heights,
                    item.groundReferenceLocalUp,alignment.scale);
            },onStatus:value=>{
            console.info('[scenery]',value.id,value.state,value.message??'');
            sendToFlutter('scenery-preview-status',value);
        }});
        if(sceneryManager) sceneryCatalogReady=sceneryManager.initialize().catch(error=>console.warn('[scenery-catalog]',error));
        const preparedMaps=window.FPVMapProviderConfig?.prepared||window.FPVMapProviderConfig?.preparedUnavailable;
        if(typeof FPVRegional3D!=='undefined') regional3D=FPVRegional3D.create(Cesium,viewer,{
            enabled:()=>regional3DEnabled&&!offline&&!preparedMaps&&!window.FPVMapProviderConfig?.terrain&&new URLSearchParams(window.location.search).get('cachedMaps')!=='1',
            online:()=>navigator.onLine!==false,
            navigationBusy:()=>Boolean(navigationActive()||flyer?.pending||walker?.status().pending||routePlayback?.loaded),
            buildingsRequested:()=>regionalBuildingsRequested,
            buildingRegions:()=>sceneryManager?.activeRegions('buildings')??[],
            flightBuildingRegions:()=>sceneryManager?.activeRegions('buildings',true)??[],
            terrainRegions:()=>sceneryManager?.activeRegions('terrain')??[],
            flightTerrainRegions:()=>flyer&&(flyer.status().active||flyer.status().pending)?sceneryManager?.activeRegions('terrain',true)??[]:[],
            terrainReady:()=>regionalTerrain&&!regionalTerrainChanging&&terrainManager.status().state==='ready',
            onStatus:value=>console.info('[BKG LoD2 beta]',value),
            onRegionChange:active=>{
                if(!active&&bridgeHeightMatch.phase!=='idle')resetBridgeHeightMatch();
                regionalTerrain=active;regionalTerrainChanging=true;
                const revision=++regionalTerrainRevision;
                void terrainManager.switchProvider().finally(()=>{if(regionalTerrainRevision===revision)regionalTerrainChanging=false;});
            }
        });

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
                if(bridgeMatchPick(event.position))return;
                const picked = viewer.scene.pick(event.position);

                const entity = picked?.id instanceof Cesium.Entity
                    ? picked.id
                    : picked?.primitive?.id;

                if (sceneEnvironment?.pick?.(picked)) return;
                const obstacle = obstacleVectors.pick(entity) || hazardAreas.pick(entity);
                if (obstacle) {
                    selectedPointInfo = null; terrainInfo(terrainManager.status());
                    sendToFlutter('obstacle-selected',obstacle); return;
                }
                sendToFlutter('obstacle-cleared');
                if (navigationActive() || routeEditor.click(event.position)) return;
                if (tunnels?.pick(entity)) return;
                if (situationalLayers.pick(entity)) return;

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

                selectedPointInfo = [latitude.toFixed(6), longitude.toFixed(6)];
                if (terrainAvailable()) selectedPointInfo.push(altitude.toFixed(1));
                info.textContent = pointLabel();
                info.hidden=false;

                sendToFlutter("point-selected", {
                    latitude: latitude,
                    longitude: longitude,
                    altitude: altitude,
                    heightReference: terrainAvailable() && !regionalTerrain ? "wgs84Ellipsoid" : "unverified"
                });
            },
            Cesium.ScreenSpaceEventType.LEFT_CLICK
        );
    }

    function publishObstacleViewport(force = false) {
        if (!rendererReady || !activeViewer) return;
        const bounds = obstacleViewportTracker?.(navigationActive());
        if (bounds) {
            const key = JSON.stringify(bounds);
            if (force || key !== obstacleViewportKey) {
                sendToFlutter('obstacle-viewport',bounds);
                obstacleViewportKey = key;
            }
        }
    }

    initializeGlobe().catch((error) => {
        console.error(error);

        document.getElementById("info").textContent =
            "Failed to initialize 3D globe: " + error.message;

        sendToFlutter("globe-error", {
            message: error.message
        });
    });
