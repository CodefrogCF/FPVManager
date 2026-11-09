(function (root, factory) {
    if (typeof module === 'object' && module.exports) module.exports = factory(require('./obstacle_models.js'),require('./map_providers.js'));
    else root.FPVObstacles = factory(root.FPVObstacleModels,root.FPVMapProviders);
})(typeof globalThis !== 'undefined' ? globalThis : this, function (Models,Credits) {
    'use strict';
    const creditApi=Credits??{retainStaticCredit:(d,c)=>d?.addStaticCredit(c),releaseStaticCredit:(d,c)=>d?.removeStaticCredit(c)};
    const WMS = Object.freeze({url: 'https://wms.geo.admin.ch/',
        layer: 'ch.bazl.luftfahrthindernis', bounds: [3.329595,44.074747,14.278255,49.200438],
        legend: 'https://api3.geo.admin.ch/static/images/legends/ch.bazl.luftfahrthindernis_de.png'});

    function createWms(C, viewer, emit, {timeoutMs = 12000, timers = globalThis,
        definition = WMS, statusEvent = 'obstacle-wms-status', label = 'Obstacle',
        attribution = 'BAZL / FOCA · geo.admin.ch'} = {}) {
        let layer = null, removeError = null, revision = 0, disposed = false;
        let visible = false, opacity = 0.8, state = 'off', error = null;
        const pending = new Set();
        const failedTiles = new Set(), retries = new Map();
        let otherFailure = false;
        const keyFor = (x,y,level) => `${level}/${x}/${y}`;
        const cancelled = request => request?.cancelled === true ||
            (C.RequestState?.CANCELLED !== undefined && request?.state === C.RequestState.CANCELLED);
        function status() { return {visible, opacity, state, error}; }
        function publish() { if (!disposed) emit(statusEvent, status()); }
        function clear() {
            removeError?.(); removeError = null;
            for (const cancel of [...pending]) cancel();
            if (layer) viewer.imageryLayers.remove(layer, true);
            layer = null;
            failedTiles.clear(); retries.clear(); otherFailure = false;
        }
        function fail(generation, key = null) {
            if (disposed || generation !== revision || !visible) return;
            if (key !== null && (failedTiles.has(key) || failedTiles.size < 256)) failedTiles.add(key);
            else otherFailure = true;
            // One missing tile must never discard all previously loaded imagery.
            // Bound bookkeeping even if an unavailable service is panned widely.
            if (state !== 'failed') {
                state = 'failed'; error = `Some ${label.toLowerCase()} tiles are unavailable or timed out. Loaded tiles remain visible. Retry in Map layers.`;
                publish();
            }
        }
        function bounded(promise, request) {
            return new Promise((resolve, reject) => {
                let done = false;
                const finish = (fn, value) => {
                    if (done) return; done = true;
                    timers.clearTimeout(timer); pending.delete(cancel); fn(value);
                };
                const cancel = () => {
                    request?.cancel?.();
                    finish(reject, new Error('Imagery request cancelled'));
                };
                const timer = timers.setTimeout(() => {
                    finish(reject, new Error('Imagery tile timeout'));
                    // Abort the transport without converting a genuine timeout
                    // into Cesium's automatically rescheduled camera cancellation.
                    try { request?.cancelFunction?.(); } catch (_) { /* Already settled. */ }
                }, timeoutMs);
                pending.add(cancel);
                Promise.resolve(promise).then(value => finish(resolve, value), reason => finish(reject, reason));
            });
        }
        function set(command) {
            if (disposed) throw new Error('Obstacle imagery disposed');
            if (typeof command.visible !== 'boolean' || !Number.isFinite(command.opacity) ||
                command.opacity < 0 || command.opacity > 1) throw new Error('Invalid obstacle imagery settings');
            visible = command.visible; opacity = command.opacity;
            if (!visible) { revision++; clear(); state = 'off'; error = null; publish(); return; }
            if (layer && !command.retry) { layer.alpha = opacity; publish(); return; }
            const generation = ++revision;
            clear(); state = 'loading'; error = null; publish();
            try {
                const scheme = new C.WebMercatorTilingScheme();
                const provider = new C.WebMapServiceImageryProvider({url: definition.url, layers: definition.layer,
                    parameters: {service:'WMS', version:'1.3.0', transparent:true, format:'image/png', styles:'default',...definition.parameters},
                    crs:'EPSG:3857', tilingScheme:scheme, rectangle:C.Rectangle.fromDegrees(...definition.bounds),
                    enablePickFeatures:false, maximumLevel:definition.maximumLevel??19,
                    credit:new C.Credit(attribution, !(definition===WMS&&attribution==='BAZL / FOCA · geo.admin.ch'))});
                const requestImage = provider.requestImage.bind(provider);
                provider.requestImage = (x,y,level,request) => {
                    if (disposed || generation !== revision) return undefined;
                    const key = keyFor(x,y,level);
                    let result;
                    try { result = requestImage(x,y,level,request); }
                    catch (e) { if (!cancelled(request)) fail(generation,key); return Promise.reject(e); }
                    if (result === undefined) return undefined; // Cesium request throttling.
                    return bounded(result,request).then(image => {
                        if (!disposed && generation === revision && visible && !cancelled(request)) {
                            failedTiles.delete(key); retries.delete(key);
                            if (!failedTiles.size && !otherFailure && state !== 'ready') {
                                state = 'ready'; error = null; publish();
                            }
                        }
                        return image;
                    }, e => {
                        // Camera movement routinely cancels scheduled Cesium
                        // requests. It must not turn a healthy layer off.
                        if (!cancelled(request)) fail(generation,key);
                        throw e;
                    });
                };
                removeError = provider.errorEvent.addEventListener(e => {
                    e.retry = false;
                    if (disposed || generation !== revision || !visible) return;
                    const key = [e.x,e.y,e.level].every(Number.isInteger) ? keyFor(e.x,e.y,e.level) : null;
                    fail(generation,key);
                    const count = retries.get(key) ?? 0;
                    if (key !== null && count < 2 && (retries.has(key) || retries.size < 256)) {
                        retries.set(key,count+1); e.retry = true;
                    }
                });
                layer = new C.ImageryLayer(provider, {alpha:opacity});
                viewer.imageryLayers.add(layer);
                // A Swiss probe prevents an apparently healthy layer when only
                // out-of-coverage tiles have been requested by the current view.
                const tile = scheme.positionToTileXY(C.Cartographic.fromDegrees(8.5,46.8), 8);
                const probe = provider.requestImage(tile.x,tile.y,8);
                // The wrapper reports genuine probe errors and ignores camera
                // cancellation. Do not reclassify its rejection as a layer loss.
                // An undefined result is scheduler backpressure, not a failure.
                if (probe !== undefined) Promise.resolve(probe).catch(() => {});
            } catch (_) { fail(generation); }
        }
        return {set, status, dispose() { if (disposed) return; disposed = true; revision++; clear(); }};
    }

    function createVectors(C, viewer, {yieldBatch = () => new Promise(r => setTimeout(r,0)),
        isTerrainReady = () => true, now = () => performance.now(), terrainBatchSize = 128,
        onFeatures = () => {}} = {}) {
        let source = null, sourceReady = null, revision = -1, disposed = false;
        let records = new Map(), hasLoadedModels = false;
        const heightCache = new Map(), pendingRecords = new Set();
        let terrainProvider = viewer.terrainProvider, heightGeneration = 0;
        const models = Models.create(C,viewer);
        if (!Number.isInteger(terrainBatchSize) || terrainBatchSize < 1 || terrainBatchSize > 512) throw new Error('Invalid terrain batch size');
        let terrain = null, terrainEpoch = 0;
        let selection = new Map();
        const credit = new C.Credit('<a href="https://www.bazl.admin.ch/de/luftfahrthindernisdaten-schweiz" target="_blank" rel="noopener">BAZL / Skyguide · Luftfahrthindernisse</a>', false);
        let credited = false;
        function setCredit(visible) {
            const display = viewer.cesiumWidget?.creditDisplay;
            if (visible && !credited) { creditApi.retainStaticCredit(display,credit); credited = true; }
            if (!visible && credited) { creditApi.releaseStaticCredit(display,credit); credited = false; }
        }
        const colors = {powerLines:'#ff6b50', cableways:'#f6c445', masts:'#55d5ff', other:'#dc9aff', unknown:'#eeeeee'};
        function remove(s) { if (s) viewer.dataSources.remove(s, true); }
        // One sample per distinct support location, independent of the number
        // of attached cables/graphics. Publish a complete scan atomically so
        // cable attachments and mast tops always use the same height snapshot.
        function terrainBindings(entities) {
            const locations = new Map(), bindings = new Set();
            let scan = null, scannedEpoch = -1, scannedAt = -Infinity;
            function watch(coordinates, apply, force = false) {
                const points = coordinates.map(([lon,lat]) => {
                    const key = `${lon},${lat}`;
                    if (!locations.has(key)) locations.set(key, {
                        key, location:C.Cartographic.fromDegrees(lon,lat), height:heightCache.get(key), generation:heightGeneration, bindings:new Set()
                    });
                    return locations.get(key);
                });
                const binding = {points,apply,force};
                bindings.add(binding);
                for (const point of points) point.bindings.add(binding);
            }
            function begin() { scan = {points:[...locations.values()], index:0, epoch:terrainEpoch}; }
            function batch() {
                const end = Math.min(scan.index + terrainBatchSize, scan.points.length), ready = isTerrainReady();
                for (; scan.index < end; scan.index++) {
                    const point = scan.points[scan.index];
                    if (point.generation !== heightGeneration) { point.height=undefined; point.generation=heightGeneration; }
                    const height = ready ? viewer.scene.globe.getHeight(point.location) : undefined;
                    point.next = !ready ? null : Number.isFinite(height) && height >= -1500 && height <= 16000
                        ? height : point.height ?? heightCache.get(point.key) ?? null;
                }
                return scan.index === scan.points.length;
            }
            function commit() {
                const changed = new Set();
                const ready = isTerrainReady();
                for (const point of scan.points) {
                    if (!ready || point.generation !== heightGeneration) {
                        point.next = null; point.generation=heightGeneration;
                    }
                    if (point.next != null) {
                        heightCache.delete(point.key); heightCache.set(point.key,point.next);
                        if (heightCache.size > 40000) heightCache.delete(heightCache.keys().next().value);
                    }
                    if (point.height !== point.next) {
                        point.height = point.next;
                        for (const binding of point.bindings) changed.add(binding);
                    }
                }
                for (const binding of bindings) if (binding.force) changed.add(binding);
                entities.suspendEvents?.();
                try { for (const binding of changed) { binding.apply(binding.points); binding.force=false; } }
                finally { entities.resumeEvents?.(); }
                scannedEpoch = scan.epoch; scannedAt = now(); scan = null;
                if (changed.size) viewer.scene.requestRender?.();
            }
            return {
                watch,
                async prime(current) {
                    begin();
                    while (!batch()) { await yieldBatch(); if (!current()) return; }
                    // Reconciliation publishes heights and entities together.
                },
                commit,
                update() {
                    if (!locations.size) return;
                    if (!scan) {
                        if (scannedEpoch === terrainEpoch || now() - scannedAt < 200) return;
                        begin();
                    }
                    if (batch()) commit();
                },
                hide() {
                    scan = null;
                    for (const point of locations.values()) point.height = null;
                    for (const binding of bindings) binding.apply(binding.points);
                },
                dispose() { locations.clear(); bindings.clear(); scan = null; }
            };
        }
        function terrainChanged() {
            terrainEpoch++;
            if (!isTerrainReady() || viewer.terrainProvider !== terrainProvider) {
                terrainProvider = viewer.terrainProvider;
                heightGeneration++;
                heightCache.clear(); terrain?.hide();
            }
        }
        const listeners = [
            (viewer.scene.preUpdate ?? viewer.scene.preRender)?.addEventListener(() => terrain?.update()),
            viewer.scene.globe.tileLoadProgressEvent?.addEventListener(terrainChanged),
            viewer.camera?.changed?.addEventListener(terrainChanged),
            viewer.camera?.moveEnd?.addEventListener(terrainChanged)
        ];
        // The source provides two distinct vertical values for point obstacles:
        // an absolute LN02 top elevation and a height above local ground (AGL).
        // Cesium renders a separate terrain mesh, which may differ from the
        // source's elevation datum and from the geometry's survey terrain.
        // To DRAW an exact AGL-height stem, compute BOTH endpoints from the same
        // rendered terrain sample. Never keep the original absolute top while
        // moving only the bottom: doing so changes the displayed object height.
        // Original source elevations remain in Flutter's obstacle attributes.
        function pointAboveTerrain(coordinate, agl, color, next, heights, models, sourceType) {
            const [lon,lat,sourceElevation] = coordinate;
            const sourceTop = Number.isFinite(sourceElevation) ? sourceElevation : 0;
            const fallbackTop = C.Cartesian3.fromDegrees(lon,lat,sourceTop);
            const marker = next.entities.add({position:fallbackTop, show:false,
                point:{pixelSize:7,color,outlineColor:C.Color.BLACK,outlineWidth:1,heightReference:C.HeightReference.NONE}});
            const stem = next.entities.add({polyline:{positions:[fallbackTop,fallbackTop],show:false,width:2,material:color,arcType:C.ArcType.NONE}});
            const model = models?.add(sourceType,agl,fallbackTop,next,marker,stem);
            heights.watch([coordinate], ([point]) => {
                const ground = point.height, visible = ground != null && ground + agl <= 16000;
                marker.show = visible; stem.polyline.show = visible;
                if (model) model.show = visible;
                if (!visible) return;
                const top = C.Cartesian3.fromDegrees(lon,lat,ground + agl);
                marker.position = top;
                const base = C.Cartesian3.fromDegrees(lon,lat,ground);
                stem.polyline.positions = [base,top];
                if (model) model.position = base;
            });
            return [marker,stem,...(model ? [model] : [])];
        }
        function validate(command) {
            if (!Number.isSafeInteger(command.revision) || !Array.isArray(command.features) ||
                command.features.length > 1200 ||
                (command.useModels != null && typeof command.useModels !== 'boolean')) throw new Error('Invalid obstacle batch');
            let vertices = 0, parts = 0;
            const ids = new Set();
            for (const f of command.features) {
                if (typeof f.id !== 'string' || f.id.length > 160 || ids.has(f.id) ||
                    !Object.hasOwn(colors,f.category) || !Array.isArray(f.parts) ||
                    (f.sourceType != null && (typeof f.sourceType !== 'string' || f.sourceType.length > 80))) throw new Error('Invalid obstacle feature');
                ids.add(f.id);
                for (const p of f.parts) {
                    parts++;
                    if (!['Point','LineString','PolygonOuter','PolygonHole'].includes(p.kind) ||
                        !Array.isArray(p.coordinates) || p.coordinates.length < (p.kind === 'Point' ? 1 : 2) ||
                        p.kind === 'Point' && p.coordinates.length !== 1 || typeof p.elevated !== 'boolean') {
                        throw new Error('Invalid obstacle geometry');
                    }
                    for (const a of p.coordinates) {
                        if (!Array.isArray(a) || a.length !== 3 || !Number.isFinite(a[0]) || !Number.isFinite(a[1]) ||
                            Math.abs(a[0]) > 180 || Math.abs(a[1]) > 90 ||
                            (p.elevated && (!Number.isFinite(a[2]) || a[2] < -1500 || a[2] > 16000))) {
                            throw new Error('Invalid obstacle position');
                        }
                        vertices++;
                    }
                    if (p.heightAgl != null && (p.kind !== 'Point' ||
                        !Number.isFinite(p.heightAgl) || p.heightAgl <= 0 || p.heightAgl >= 1500)) {
                        throw new Error('Invalid obstacle AGL');
                    }
                }
            }
            if (parts > 4000 || vertices > 40000) throw new Error('Obstacle rendering limit exceeded');
        }
        function supportIndex(features) {
            const grid = new Map(), cell = (x,y) => `${Math.floor(x*10000)},${Math.floor(y*10000)}`;
            for (const f of features) {
                // The full BAZL KMZ also classifies support points as
                // TRANSMISSION_LINE / cableways, not only as POLE.
                if (!['masts','powerLines','cableways'].includes(f.category) || f.parts.length !== 1) continue;
                const p=f.parts[0];
                if (p.kind!=='Point' || !p.elevated || p.heightAgl==null) continue;
                const [lon,lat,top]=p.coordinates[0],key=cell(lon,lat);
                if (!grid.has(key)) grid.set(key,[]);
                grid.get(key).push({lon,lat,top,agl:p.heightAgl});
            }
            return coordinate => {
                const [lon,lat,top]=coordinate, candidates=[];
                for(let x=-1;x<=1;x++)for(let y=-1;y<=1;y++) {
                    for(const p of grid.get(`${Math.floor(lon*10000)+x},${Math.floor(lat*10000)+y}`)??[]) {
                        const dx=(p.lon-lon)*111195*Math.cos(lat*Math.PI/180),dy=(p.lat-lat)*111195;
                        // Same horizontal support and compatible original top;
                        // never attach to an unrelated nearby/crossing object.
                        if(Math.hypot(dx,dy)<=2 && Math.abs(p.top-top)<=5)candidates.push(p);
                    }
                }
                return candidates.length===1?candidates[0]:null;
            };
        }
        function anchoredCable(p, findSupport, color, next, heights) {
            const anchors=p.coordinates.map((a,index)=>({index,support:findSupport(a)})).filter(a=>a.support);
            if(!anchors.length)return null;
            const source=p.coordinates.map(a=>C.Cartesian3.fromDegrees(...a));
            const lengths=[0];
            for(let i=1;i<p.coordinates.length;i++){
                const a=p.coordinates[i-1],b=p.coordinates[i];
                lengths.push(lengths[i-1]+Math.hypot((a[0]-b[0])*Math.cos(a[1]*Math.PI/180),a[1]-b[1]));
            }
            // Resolve interpolation weights once; terrain refinements only
            // change the vertical offsets, not the source cable topology.
            let right = 0;
            const weights = p.coordinates.map((_a,i) => {
                while (right < anchors.length && anchors[right].index < i) right++;
                if (anchors[right]?.index === i) return {left:right,right,t:0};
                const left = right - 1;
                if (left < 0 || right === anchors.length) return null;
                const length = lengths[anchors[right].index] - lengths[anchors[left].index];
                return {left,right,t:length > 0 ? (lengths[i]-lengths[anchors[left].index])/length : 0};
            });
            const entity = next.entities.add({name:'Approximate cable display anchored to published support tops',polyline:{
                positions:source,show:false,width:3,material:color,arcType:C.ArcType.NONE}});
            heights.watch(anchors.map(a => [a.support.lon,a.support.lat]), points => {
                // Absolute source geometry remains valid even when an offscreen
                // support has never had a rendered terrain sample. Adjust only
                // known anchors; never invent terrain or a cable elevation.
                entity.polyline.show = true;
                const deltas = anchors.map((a,i) => points[i].height == null ? 0
                    : points[i].height + a.support.agl - p.coordinates[a.index][2]);
                entity.polyline.positions = p.coordinates.map((a,i) => {
                    const w = weights[i];
                    return w ? C.Cartesian3.fromDegrees(a[0],a[1],a[2]+deltas[w.left]*(1-w.t)+deltas[w.right]*w.t) : source[i];
                });
            });
            return entity;
        }
        function forget(record) {
            for (const entity of record.entities) models.remove(entity);
        }
        async function replace(command, signal) {
            validate(command);
            if (disposed || command.revision <= revision) return;
            revision = command.revision;
            // Keep the data source AND unchanged entity identities. Cesium's
            // ModelVisualizer otherwise destroys and reloads every GLB.
            if (!source) {
                source = new C.CustomDataSource('Swiss aviation obstacles');
                source.show = true;
                const added = source;
                sourceReady = Promise.resolve(viewer.dataSources.add(added)).then(() => {
                    if (disposed) remove(added);
                });
            }
            const next = new C.CustomDataSource('Staged obstacle entities');
            const heights = terrainBindings(source.entities), nextRecords = new Map(), created = [];
            const ids = new Map();
            const current = () => !disposed && revision === command.revision && !signal?.aborted;
            let committed = false;
            try {
                await sourceReady;
                if (!current()) return;
                const findSupport=supportIndex(command.features);
                let index = 0;
                for (const f of command.features) {
                    if (!current()) return;
                    if(f.supportOnly)continue;
                    // Cable anchoring is part of its signature: changing a
                    // published support must invalidate only affected cables.
                    const anchors = f.parts.map(p => p.kind === 'LineString' && p.elevated
                        ? p.coordinates.map(a => findSupport(a)) : null);
                    const signature = JSON.stringify([f,Boolean(command.useModels && f.parts.length === 1 && f.parts[0].kind === 'Point'),anchors]);
                    const old = records.get(f.id);
                    if (old?.signature === signature) {
                        nextRecords.set(f.id,old);
                        for (const binding of old.bindings) heights.watch(...binding);
                        for (const entity of old.entities) ids.set(entity.id,{id:f.id,revision:command.revision});
                        if (++index % 80 === 0) await yieldBatch();
                        continue;
                    }
                    const record = {signature,entities:[],bindings:[]};
                    created.push(record); pendingRecords.add(record); nextRecords.set(f.id,record);
                    const bindings = {watch(coordinates,apply) {
                        record.bindings.push([coordinates,apply]); heights.watch(coordinates,apply,true);
                    }};
                    const remember = entity => { record.entities.push(entity); ids.set(entity.id,{id:f.id,revision:command.revision}); };
                    const color = C.Color.fromCssColorString(colors[f.category]);
                    // Swiss obstacle KML can include an extra Point merely to
                    // label a line/polygon. It is not a separate 3D obstacle.
                    const hasLineOrArea = f.parts.some(p => p.kind !== 'Point');
                    for (const p of f.parts) {
                        if (p.kind === 'Point' && hasLineOrArea) continue;
                        if(p.kind==='LineString' && p.elevated && ['powerLines','cableways'].includes(f.category)){
                            const anchored=anchoredCable(p,findSupport,color,next,bindings);
                            if(anchored){remember(anchored);continue;}
                        }
                        const colorPoint = p.kind === 'Point' && p.heightAgl != null;
                        if (colorPoint) {
                            const entities = pointAboveTerrain(p.coordinates[0],p.heightAgl,color,next,bindings,
                                command.useModels && f.parts.length === 1 ? models : null,f.sourceType);
                            for (const entity of entities) remember(entity);
                            continue;
                        }
                        const points = p.coordinates.map(a => C.Cartesian3.fromDegrees(a[0],a[1],p.elevated ? a[2] : 0));
                        // Unknown AGL for a genuine point: preserve absolute
                        // source top without pretending to know its local height.
                        // For unknown line altitudes, retain a projected marker.
                        const entity = next.entities.add(p.kind === 'Point' || !p.elevated ? {
                            position:points[0], point:{pixelSize:p.elevated ? 7 : 5, color,
                                outlineColor:C.Color.BLACK, outlineWidth:1,
                                heightReference:p.elevated ? C.HeightReference.NONE : C.HeightReference.CLAMP_TO_GROUND}
                        } : {polyline:{positions:points, width:p.elevated ? 3 : 2, material:color,
                            clampToGround:!p.elevated, arcType:p.elevated ? C.ArcType.NONE : C.ArcType.GEODESIC}});
                        remember(entity);
                    }
                    if (++index % 80 === 0) await yieldBatch();
                }
                if (!current()) return;
                await heights.prime(current);
                if (!current()) return;
                source.entities.suspendEvents?.();
                try {
                    heights.commit();
                    for (const [id,old] of records) if (nextRecords.get(id) !== old) {
                        forget(old);
                        for (const entity of old.entities) source.entities.remove(entity);
                    }
                    for (const record of created) for (const entity of record.entities) {
                        next.entities.remove(entity); source.entities.add(entity);
                    }
                    terrain?.dispose(); terrain = heights;
                    records = nextRecords; selection = ids;
                    hasLoadedModels = [...records.values()].some(record => record.entities.some(entity => !!entity.model));
                    committed = true;
                } finally { source.entities.resumeEvents?.(); }
                setCredit(command.features.length > 0);
                // Consumers see only the atomically committed source batch,
                // never cancelled or superseded staging data.
                onFeatures(command.features);
                viewer.scene.requestRender?.();
            } finally {
                for (const record of created) {
                    pendingRecords.delete(record);
                    if (!committed) forget(record);
                }
                if (!committed) heights.dispose();
            }
        }
        return {replace, terrainChanged, hasVisibleModels:()=>!disposed && !!source?.show && hasLoadedModels, pick(entity) { return source?.show && entity ? selection.get(entity.id) : undefined; },
            dispose() { disposed = true; revision++; for (const stop of listeners) stop?.();
                terrain?.dispose(); terrain = null;
                for (const record of pendingRecords) forget(record);
                pendingRecords.clear(); records.clear(); models.dispose(); heightCache.clear();
                onFeatures([]);
                remove(source); source = null; selection.clear(); setCredit(false); }};
    }
    function createHazards(C, viewer, {yieldBatch = () => new Promise(r => setTimeout(r,0))} = {}) {
        let source = null, staged = null, revision = -1, disposed = false, selection = new Map();
        const credit = new C.Credit('Schutzgebiete · BAZL / Skyguide · geo.admin.ch',false);
        let credited=false;
        function setCredit(visible) {
            const display=viewer.cesiumWidget?.creditDisplay;
            if(visible&&!credited){creditApi.retainStaticCredit(display,credit);credited=true;}
            if(!visible&&credited){creditApi.releaseStaticCredit(display,credit);credited=false;}
        }
        const remove = s => { if (s) viewer.dataSources.remove(s,true); };
        async function replace(command, signal) {
            if (!Number.isSafeInteger(command.revision) || !Number.isFinite(command.bufferMeters) ||
                command.bufferMeters < 0 || command.bufferMeters > 1000 ||
                !Array.isArray(command.features) || command.features.length > 1200) throw new Error('Invalid advisory areas');
            let vertices = 0, parts = 0;
            for (const f of command.features) {
                if (typeof f.id !== 'string' || f.id.length > 160 || !Array.isArray(f.parts)) throw new Error('Invalid advisory feature');
                for (const p of f.parts) {
                    if (!Array.isArray(p.coordinates)) throw new Error('Invalid advisory geometry');
                    parts++;
                    for (const a of p.coordinates) {
                        vertices++;
                        if (!Array.isArray(a) || !Number.isFinite(a[0]) || !Number.isFinite(a[1]) ||
                            Math.abs(a[0]) > 180 || Math.abs(a[1]) > 90) throw new Error('Invalid advisory coordinate');
                    }
                }
            }
            if (vertices > 40000 || parts > 4000) throw new Error('Advisory rendering limit exceeded');
            if (disposed || command.revision <= revision) return;
            revision = command.revision; remove(staged);
            const next = staged = new C.CustomDataSource('Advisory obstacle areas');
            const ids = new Map(), current = () => !disposed && revision === command.revision && !signal?.aborted;
            try {
                await viewer.dataSources.add(next); next.show = false;
                const color = C.Color.fromCssColorString('#00bcd4').withAlpha(0.22);
                if (command.bufferMeters > 0) for (let i=0;i<command.features.length;i++) {
                    if (!current()) return;
                    const f = command.features[i], hasLine = f.parts.some(p => p.kind !== 'Point');
                    if(f.supportOnly)continue;
                    for (const p of f.parts) {
                        if (p.kind === 'Point' && hasLine || !['Point','LineString'].includes(p.kind)) continue;
                        const positions = p.coordinates.map(a => C.Cartesian3.fromDegrees(a[0],a[1]));
                        if (!positions.length || p.kind === 'LineString' && positions.length < 2) continue;
                        const entity = next.entities.add({name:'Advisory horizontal obstacle buffer',
                            ...(p.kind === 'Point' ? {position:positions[0],ellipse:{
                                semiMajorAxis:command.bufferMeters,semiMinorAxis:command.bufferMeters,
                                material:color,heightReference:C.HeightReference.CLAMP_TO_GROUND
                            }} : {corridor:{positions,width:2*command.bufferMeters,
                                cornerType:C.CornerType.ROUNDED,material:color,
                                heightReference:C.HeightReference.CLAMP_TO_GROUND}})});
                        ids.set(entity.id,{id:f.id,revision:command.revision,layer:'hazard'});
                    }
                    if (i % 80 === 79) await yieldBatch();
                }
                if (!current()) return;
                remove(source); source=next; staged=null; selection=ids; next.show=true;
                setCredit(ids.size>0);
                viewer.scene.requestRender?.();
            } finally { if (source !== next) { remove(next); if (staged===next) staged=null; } }
        }
        return {replace,pick(entity) { return source?.show && entity ? selection.get(entity.id) : undefined; },
            dispose() { disposed=true; revision++; remove(source);remove(staged);source=staged=null;selection.clear();setCredit(false); }};
    }
    return {WMS, createWms, createVectors, createHazards};
});
