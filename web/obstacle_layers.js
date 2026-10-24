(function (root, factory) {
    if (typeof module === 'object' && module.exports) module.exports = factory();
    else root.FPVObstacles = factory();
})(typeof globalThis !== 'undefined' ? globalThis : this, function () {
    'use strict';
    const WMS = Object.freeze({url: 'https://wms.geo.admin.ch/',
        layer: 'ch.bazl.luftfahrthindernis', bounds: [3.329595,44.074747,14.278255,49.200438],
        legend: 'https://api3.geo.admin.ch/static/images/legends/ch.bazl.luftfahrthindernis_de.png'});

    function createWms(C, viewer, emit, {timeoutMs = 12000, timers = globalThis,
        definition = WMS, statusEvent = 'obstacle-wms-status', label = 'Obstacle',
        attribution = 'BAZL / FOCA · geo.admin.ch'} = {}) {
        let layer = null, removeError = null, revision = 0, disposed = false;
        let visible = false, opacity = 0.8, state = 'off', error = null;
        const pending = new Set();
        function status() { return {visible, opacity, state, error}; }
        function publish() { if (!disposed) emit(statusEvent, status()); }
        function clear() {
            removeError?.(); removeError = null;
            for (const cancel of [...pending]) cancel();
            if (layer) viewer.imageryLayers.remove(layer, true);
            layer = null;
        }
        function fail(generation) {
            if (disposed || generation !== revision || !visible) return;
            state = 'failed'; error = `${label} tiles unavailable or timed out. Retry in Map layers.`;
            // Invalidates outstanding requests so late completions cannot report ready.
            revision++; clear(); publish();
        }
        function bounded(request) {
            return new Promise((resolve, reject) => {
                let done = false;
                const finish = (fn, value) => {
                    if (done) return; done = true;
                    timers.clearTimeout(timer); pending.delete(cancel); fn(value);
                };
                const cancel = () => finish(reject, new Error('Obstacle request cancelled'));
                const timer = timers.setTimeout(() => {
                    finish(reject, new Error('Obstacle tile timeout'));
                }, timeoutMs);
                pending.add(cancel);
                Promise.resolve(request).then(value => finish(resolve, value), reason => finish(reject, reason));
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
                    parameters: {service:'WMS', version:'1.3.0', transparent:true, format:'image/png', styles:'default'},
                    crs:'EPSG:3857', tilingScheme:scheme, rectangle:C.Rectangle.fromDegrees(...definition.bounds),
                    enablePickFeatures:false, maximumLevel:19,
                    credit:new C.Credit(attribution, true)});
                const requestImage = provider.requestImage.bind(provider);
                provider.requestImage = (x,y,level,request) => {
                    if (disposed || generation !== revision) return undefined;
                    let result;
                    try { result = requestImage(x,y,level,request); }
                    catch (e) { fail(generation); return Promise.reject(e); }
                    if (result === undefined) return undefined; // Cesium request throttling.
                    return bounded(result).then(image => {
                        if (generation === revision && visible && state !== 'ready') {
                            state = 'ready'; publish();
                        }
                        return image;
                    }, e => {
                        // Camera movement routinely cancels scheduled Cesium
                        // requests. It must not turn a healthy layer off.
                        if (!request?.cancelled) { fail(generation); request?.cancel?.(); }
                        throw e;
                    });
                };
                removeError = provider.errorEvent.addEventListener(e => { e.retry = false; fail(generation); });
                layer = new C.ImageryLayer(provider, {alpha:opacity});
                viewer.imageryLayers.add(layer);
                // A Swiss probe prevents an apparently healthy layer when only
                // out-of-coverage tiles have been requested by the current view.
                const tile = scheme.positionToTileXY(C.Cartographic.fromDegrees(8.5,46.8), 8);
                const probe = provider.requestImage(tile.x,tile.y,8);
                if (probe === undefined) fail(generation);
                else Promise.resolve(probe).catch(() => fail(generation));
            } catch (_) { fail(generation); }
        }
        return {set, status, dispose() { if (disposed) return; disposed = true; revision++; clear(); }};
    }

    function createVectors(C, viewer, {yieldBatch = () => new Promise(r => setTimeout(r,0)),
        isTerrainReady = () => true} = {}) {
        let source = null, staged = null, revision = -1, disposed = false;
        let selection = new Map();
        const credit = new C.Credit('BAZL / FOCA · Skyguide · geo.admin.ch · CHGeo2004 © swisstopo', true);
        let credited = false;
        function setCredit(visible) {
            const display = viewer.cesiumWidget?.creditDisplay;
            if (visible && !credited) { display?.addStaticCredit(credit); credited = true; }
            if (!visible && credited) { display?.removeStaticCredit(credit); credited = false; }
        }
        const colors = {powerLines:'#ff6b50', cableways:'#f6c445', masts:'#55d5ff', other:'#dc9aff', unknown:'#eeeeee'};
        function remove(s) { if (s) viewer.dataSources.remove(s, true); }
        // The source provides two distinct vertical values for point obstacles:
        // an absolute LN02 top elevation and a height above local ground (AGL).
        // Cesium renders a separate terrain mesh, which may differ from the
        // source's elevation datum and from the geometry's survey terrain.
        // To DRAW an exact AGL-height stem, compute BOTH endpoints from the same
        // rendered terrain sample. Never keep the original absolute top while
        // moving only the bottom: doing so changes the displayed object height.
        // Original source elevations remain in Flutter's obstacle attributes.
        function pointAboveTerrain(coordinate, agl, color) {
            const [lon,lat,sourceElevation] = coordinate;
            const sourceTop = Number.isFinite(sourceElevation) ? sourceElevation : 0;
            const location = C.Cartographic.fromDegrees(lon,lat);
            const fallbackTop = C.Cartesian3.fromDegrees(lon,lat,sourceTop);
            const hiddenPositions = [fallbackTop,fallbackTop];
            let previousGround, cachedTop, cachedStem;
            function sample() {
                if (!isTerrainReady()) return null;
                const ground = viewer.scene?.globe?.getHeight?.(location);
                // A missing/non-finite tile height is not the ellipsoid zero;
                // never invent a ground position or a guaranteed obstacle top.
                if (!Number.isFinite(ground) || ground < -1500 ||
                    ground + agl > 16000) return null;
                if (ground !== previousGround) {
                    cachedTop = C.Cartesian3.fromDegrees(lon,lat,ground + agl);
                    cachedStem = [C.Cartesian3.fromDegrees(lon,lat,ground),cachedTop];
                    previousGround = ground;
                }
                return {top:cachedTop,stem:cachedStem};
            }
            const show = new C.CallbackProperty(() => sample() !== null, false);
            return {
                marker:{position:new C.CallbackProperty(() => sample()?.top ?? fallbackTop,false),
                    show,point:{pixelSize:7,color,outlineColor:C.Color.BLACK,outlineWidth:1,
                        heightReference:C.HeightReference.NONE}},
                stem:{polyline:{positions:new C.CallbackProperty(() => sample()?.stem ?? hiddenPositions,false),
                    show,width:2,material:color,arcType:C.ArcType.NONE}}
            };
        }
        function validate(command) {
            if (!Number.isSafeInteger(command.revision) || !Array.isArray(command.features) ||
                command.features.length > 1200) throw new Error('Invalid obstacle batch');
            let vertices = 0, parts = 0;
            const ids = new Set();
            for (const f of command.features) {
                if (typeof f.id !== 'string' || f.id.length > 160 || ids.has(f.id) ||
                    !Object.hasOwn(colors,f.category) || !Array.isArray(f.parts)) throw new Error('Invalid obstacle feature');
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
        function anchoredCable(p, findSupport, color) {
            const anchors=p.coordinates.map((a,index)=>({index,support:findSupport(a)})).filter(a=>a.support);
            if(!anchors.length)return null;
            const source=p.coordinates.map(a=>C.Cartesian3.fromDegrees(...a));
            const lengths=[0];
            for(let i=1;i<p.coordinates.length;i++){
                const a=p.coordinates[i-1],b=p.coordinates[i];
                lengths.push(lengths[i-1]+Math.hypot((a[0]-b[0])*Math.cos(a[1]*Math.PI/180),a[1]-b[1]));
            }
            let previous='',cached=source;
            function sample(){
                if(!isTerrainReady())return null;
                const grounds=anchors.map(a=>viewer.scene?.globe?.getHeight?.(C.Cartographic.fromDegrees(a.support.lon,a.support.lat)));
                if(grounds.some(g=>!Number.isFinite(g)||g < -1500 || g > 16000))return null;
                const key=grounds.join(',');
                if(key!==previous){
                    const deltas=anchors.map((a,i)=>grounds[i]+a.support.agl-p.coordinates[a.index][2]);
                    cached=p.coordinates.map((a,i)=>{
                        const exact=anchors.findIndex(v=>v.index===i);
                        if(exact>=0)return C.Cartesian3.fromDegrees(a[0],a[1],a[2]+deltas[exact]);
                        const right=anchors.findIndex(v=>v.index>i),left=right-1;
                        if(left<0||right<0)return source[i];
                        const length=lengths[anchors[right].index]-lengths[anchors[left].index];
                        const t=length>0?(lengths[i]-lengths[anchors[left].index])/length:0;
                        return C.Cartesian3.fromDegrees(a[0],a[1],a[2]+deltas[left]*(1-t)+deltas[right]*t);
                    });previous=key;
                }
                return cached;
            }
            return {name:'Approximate cable display anchored to published support tops',polyline:{
                positions:new C.CallbackProperty(()=>sample()??source,false),
                show:new C.CallbackProperty(()=>sample()!==null,false),width:3,material:color,arcType:C.ArcType.NONE}};
        }
        async function replace(command, signal) {
            validate(command);
            if (disposed || command.revision <= revision) return;
            revision = command.revision;
            remove(staged); staged = null;
            const next = new C.CustomDataSource('Swiss aviation obstacles');
            staged = next;
            const ids = new Map();
            const current = () => !disposed && revision === command.revision && !signal?.aborted;
            try {
                await viewer.dataSources.add(next);
                next.show = false;
                const findSupport=supportIndex(command.features);
                let index = 0;
                for (const f of command.features) {
                    if (!current()) return;
                    if(f.supportOnly)continue;
                    const color = C.Color.fromCssColorString(colors[f.category]);
                    // Swiss obstacle KML can include an extra Point merely to
                    // label a line/polygon. It is not a separate 3D obstacle.
                    const hasLineOrArea = f.parts.some(p => p.kind !== 'Point');
                    for (const p of f.parts) {
                        if (p.kind === 'Point' && hasLineOrArea) continue;
                        if(p.kind==='LineString' && p.elevated && ['powerLines','cableways'].includes(f.category)){
                            const anchored=anchoredCable(p,findSupport,color);
                            if(anchored){const entity=next.entities.add(anchored);
                                ids.set(entity.id,{id:f.id,revision:command.revision});continue;}
                        }
                        const colorPoint = p.kind === 'Point' && p.heightAgl != null;
                        if (colorPoint) {
                            const objects = pointAboveTerrain(p.coordinates[0],p.heightAgl,color);
                            const marker = next.entities.add(objects.marker);
                            const stem = next.entities.add(objects.stem);
                            ids.set(marker.id,{id:f.id,revision:command.revision});
                            ids.set(stem.id,{id:f.id,revision:command.revision});
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
                        ids.set(entity.id, {id:f.id, revision:command.revision});
                    }
                    if (++index % 80 === 0) await yieldBatch();
                }
                if (!current()) return;
                remove(source); source = next; selection = ids; next.show = true; staged = null;
                setCredit(command.features.length > 0);
                viewer.scene.requestRender?.();
            } finally {
                if (source !== next) { remove(next); if (staged === next) staged = null; }
            }
        }
        return {replace, pick(entity) { return source?.show && entity ? selection.get(entity.id) : undefined; },
            dispose() { disposed = true; revision++; remove(source); remove(staged); source = staged = null; selection.clear(); setCredit(false); }};
    }
    function createHazards(C, viewer, {yieldBatch = () => new Promise(r => setTimeout(r,0))} = {}) {
        let source = null, staged = null, revision = -1, disposed = false, selection = new Map();
        const credit = new C.Credit('Advisory areas from BAZL / FOCA · Skyguide · geo.admin.ch',true);
        let credited=false;
        function setCredit(visible) {
            const display=viewer.cesiumWidget?.creditDisplay;
            if(visible&&!credited){display?.addStaticCredit(credit);credited=true;}
            if(!visible&&credited){display?.removeStaticCredit(credit);credited=false;}
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
