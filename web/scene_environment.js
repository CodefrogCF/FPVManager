(function(root,factory){
    const api=factory();
    if(typeof module==='object'&&module.exports)module.exports=api;
    else root.FPVSceneEnvironment=api;
})(typeof globalThis!=='undefined'?globalThis:this,function(){
    'use strict';
    const sources=Object.freeze({
        buildings:'https://3d.geo.admin.ch/ch.swisstopo.swissbuildings3d.3d/v1/tileset.json',
        vegetation:'https://3d.geo.admin.ch/ch.swisstopo.vegetation.3d/v1/tileset.json',
        structures:'https://3d.geo.admin.ch/ch.swisstopo.swisstlm3d.3d/v1/tileset.json'
    });
    const budgets=Object.freeze({quality:[12,24,48,24,8],balanced:[24,40,32,16,4],performance:[40,64,24,12,2],navigation:[32,56,24,12,2]});
    function time(value){
        if(value==null)return null;
        if(typeof value!=='string'||!/^\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d(?:\.\d{1,6})?Z$/.test(value))throw Error('Expected UTC scene time');
        const date=new Date(value);
        if(!Number.isFinite(date.getTime())||date.getUTCFullYear()<1900||date.getUTCFullYear()>2100||
            date.toISOString().slice(0,19)!==value.slice(0,19))throw Error('Scene date must be within 1900–2100');
        return date.toISOString();
    }
    function create(C,viewer,send=()=>{},{urls=sources,timeoutMs=15000,setTimer=setTimeout,clearTimer=clearTimeout,
        cachedOnly=false,isOnline=()=>globalThis.navigator?.onLine!==false}={}){
        const scene=viewer.scene,clock=viewer.clock,overrides=new Map();
        const original={time:C.JulianDate.clone(clock.currentTime),step:clock.clockStep,animate:clock.shouldAnimate,
            light:scene.light,lighting:scene.globe.enableLighting,atmosphere:scene.globe.dynamicAtmosphereLightingFromSun,
            lightingIn:scene.globe.lightingFadeInDistance,lightingOut:scene.globe.lightingFadeOutDistance,
            nightIn:scene.globe.nightFadeInDistance,nightOut:scene.globe.nightFadeOutDistance,
            ambient:scene.globe.vertexShadowDarkness};
        const credit=new C.Credit('3D buildings / vegetation / infrastructure · © swisstopo',true);
        const creditDisplay=viewer.cesiumWidget?.creditDisplay;
        const layers=Object.fromEntries(Object.keys(sources).map(key=>[key,{requested:false,tileset:null,pending:null,revision:0,
            phase:'hidden',failed:false,removers:[],lastStatus:null,timer:null}]));
        let disposed=false,lighting=false,profile='balanced',credited=false,appliedTime=null,structuresOpacity=1;
        let navigating=false;
        const mapLayers={buildings:false,vegetation:false,structures:false},navigationLayers={buildings:null,vegetation:null};
        function publish(key){
            if(disposed)return;
            const l=layers[key],state=!l.requested?'hidden':l.phase;
            if(l.lastStatus===state || (l.lastStatus===null&&state==='hidden'))return;l.lastStatus=state;
            send('scene-layer-status',{layer:key,state});
        }
        function credits(){
            const needed=Object.values(layers).some(l=>l.requested);
            if(needed===credited)return;credited=needed;
            if(needed)creditDisplay?.addStaticCredit(credit);else creditDisplay?.removeStaticCredit(credit);
        }
        function options(key){
            const b=budgets[navigating?'navigation':profile],trees=key==='vegetation',structures=key==='structures',mb=1024*1024;
            return {show:false,maximumScreenSpaceError:structures?Math.max(24,b[0]):b[trees?1:0],cacheBytes:(structures?Math.min(16,b[2]):b[trees?3:2])*mb,
                maximumCacheOverflowBytes:b[4]*mb,shadows:C.ShadowMode.DISABLED,
                preloadWhenHidden:false,preloadFlightDestinations:false,loadSiblings:false,
                cullRequestsWhileMoving:true,foveatedScreenSpaceError:true,showCreditsOnScreen:true};
        }
        function applyStructureStyle(){
            const tileset=layers.structures.tileset;
            if(!tileset||!C.Cesium3DTileStyle)return;
            tileset.style=structuresOpacity>=1 ? undefined :
                new C.Cesium3DTileStyle({color:`color('white', ${structuresOpacity})`});
        }
        function visibility(key){
            const l=layers[key];if(!l.tileset)return;
            const height=viewer.camera.positionCartographic.height;
            l.tileset.show=l.requested&&height<(key==='vegetation'?12000:25000);
        }
        function release(l){
            clearTimer(l.timer);l.timer=null;
            l.revision++;for(const remove of l.removers)remove();l.removers=[];
            if(l.tileset){scene.primitives.remove(l.tileset);l.tileset=null;}
        }
        function load(key){
            const l=layers[key];if(disposed||l.pending||l.tileset||!l.requested)return;
            if(cachedOnly||!isOnline()){l.phase='offline';publish(key);return;}
            const revision=++l.revision;l.phase='loading';l.failed=false;publish(key);
            const current=()=>!disposed&&revision===l.revision;
            let timedOut=false;
            const timer=l.timer=setTimer(()=>{
                if(!current())return;timedOut=true;l.revision++;l.pending=null;l.phase='failed';publish(key);
            },timeoutMs);
            l.pending=Promise.resolve().then(()=>C.Cesium3DTileset.fromUrl(urls[key]??sources[key],options(key))).then(tileset=>{
                if(!current()||timedOut){if(!tileset.isDestroyed())tileset.destroy();return;}
                Object.assign(tileset,options(key));l.tileset=tileset;scene.primitives.add(tileset);if(key==='structures')applyStructureStyle();visibility(key);
                l.phase=isOnline()?'ready':'offline';publish(key);
                l.removers.push(tileset.tileFailed.addEventListener(()=>{if(!current())return;l.failed=true;l.phase=isOnline()?'partial':'offline';publish(key);}));
                l.removers.push(tileset.loadProgress.addEventListener((pending,processing)=>{
                    if(!current()||l.failed)return;l.phase=isOnline()?(pending+processing>0?'loading':'ready'):'offline';publish(key);
                }));
                scene.requestRender();
            }).catch(()=>{if(current()){l.phase='failed';publish(key);}}).finally(()=>{
                clearTimer(timer);if(current())l.pending=null;
            });
        }
        function applyTime(){
            const selected=overrides.get('flight')??overrides.get('route');
            const enabled=!!selected||lighting,utc=selected?.timeUtc??null;
            const identity=enabled?(utc??'now'):'daylight';if(identity===appliedTime)return;appliedTime=identity;
            scene.globe.enableLighting=enabled;
            // Cesium's planet-scale defaults otherwise illuminate close terrain
            // fully, even on the night side. Keep physical lighting near ground.
            scene.globe.lightingFadeOutDistance=enabled?0:original.lightingOut;
            scene.globe.lightingFadeInDistance=enabled?1:original.lightingIn;
            scene.globe.nightFadeOutDistance=enabled?0:original.nightOut;
            scene.globe.nightFadeInDistance=enabled?1:original.nightIn;
            scene.globe.vertexShadowDarkness=enabled ? .06 : original.ambient;
            scene.globe.dynamicAtmosphereLightingFromSun=enabled||original.atmosphere;
            scene.light=enabled?new C.SunLight():original.light;
            if(enabled){
                if(utc){clock.shouldAnimate=false;clock.currentTime=C.JulianDate.fromIso8601(utc);}
                else clock.clockStep=C.ClockStep.SYSTEM_CLOCK;
            }else{
                clock.currentTime=C.JulianDate.clone(original.time);clock.clockStep=original.step;clock.shouldAnimate=original.animate;
                scene.globe.enableLighting=original.lighting;
            }
            scene.skyAtmosphere?.setDynamicLighting?.(enabled,enabled);
            scene.requestRender();
        }
        function applyLayers(retry){
            for(const key of Object.keys(layers)){
                const l=layers[key];l.requested=navigating?(navigationLayers[key]??mapLayers[key]):mapLayers[key];
                if(retry===key || (key==='structures'&&!l.requested&&(l.tileset||l.pending))){
                    release(l);l.pending=null;if(!l.requested)l.phase='hidden';
                }
                if(l.tileset)Object.assign(l.tileset,options(key));
                if(l.requested&&!l.tileset&&!l.pending&&(l.phase!=='failed'||retry===key))load(key);
                visibility(key);publish(key);
            }
            credits();scene.requestRender();
        }
        const removeUpdate=scene.preUpdate.addEventListener(()=>{for(const key of Object.keys(layers))visibility(key);});
        return {
            hasVisibleModels(){return Object.values(layers).some(l=>l.tileset?.show===true);},
            set(command){
                if(disposed)return {};
                for(const key of ['buildings','vegetation','lighting'])if(typeof command[key]!=='boolean')throw Error('Invalid scene preference');
                if(command.structures!==undefined&&typeof command.structures!=='boolean')throw Error('Invalid structures preference');
                if(command.structuresOpacity!==undefined&&(!Number.isFinite(command.structuresOpacity)||command.structuresOpacity<.2||command.structuresOpacity>1))throw Error('Invalid structures opacity');
                if(command.structuresOpacity!==undefined){structuresOpacity=command.structuresOpacity;applyStructureStyle();}
                if(command.retry!==undefined&&command.retry!==null&&!Object.hasOwn(layers,command.retry))throw Error('Invalid scene layer retry');
                lighting=command.lighting;applyTime();
                for(const key of Object.keys(layers))mapLayers[key]=key==='structures'?(command.structures??mapLayers.structures):command[key];
                applyLayers(command.retry);return {};
            },
            navigation(command){
                if(disposed)return {};
                for(const key of ['buildings','vegetation'])if(command[key]!==undefined&&command[key]!==null&&typeof command[key]!=='boolean')throw Error('Invalid navigation scene preference');
                if(command.active!==undefined&&typeof command.active!=='boolean')throw Error('Invalid navigation scene state');
                if(command.active!==undefined)navigating=command.active;
                Object.assign(navigationLayers,{buildings:command.buildings,vegetation:command.vegetation});
                applyLayers();return {};
            },
            navigationActive(active){
                if(disposed||navigating===active)return;
                navigating=active;applyLayers();
            },
            pick(feature){
                const structures=layers.structures;
                if(disposed||!structures?.requested||!structures.tileset||
                    !feature||feature.content?.tileset!==structures.tileset)return false;
                const rawIds=typeof feature.getPropertyIds==='function'?feature.getPropertyIds():[];
                const ids=Array.isArray(rawIds)?rawIds:[];
                const props={};
                for(const key of ids.slice(0,16)){
                    if(typeof key!=='string'||key.length>60)continue;
                    const value=feature.getProperty(key);
                    if(['string','number','boolean'].includes(typeof value))
                        props[key]=String(value).slice(0,160);
                }
                send('infrastructure-selected',{kind:'structure',datasetSource:'ch.swisstopo.swisstlm3d.3d',
                    attributes:props,mode:'official-3d-tiles',heightReference:'source-geometry'});
                return true;
            },
            networkChanged(){
                if(disposed)return;
                for(const key of Object.keys(layers)){
                    const l=layers[key];if(!l.requested)continue;
                    if(cachedOnly||!isOnline()){l.phase='offline';publish(key);}
                    else if(l.phase==='offline'){
                        if(l.tileset){l.phase=l.failed?'partial':'ready';publish(key);}
                        else load(key);
                    }
                }
            },
            setTime({scope,enabled,timeUtc=null}){
                if(disposed)return {};
                if(!['route','flight'].includes(scope)||typeof enabled!=='boolean')throw Error('Invalid scene time scope');
                const parsed=time(timeUtc);
                if(enabled)overrides.set(scope,{timeUtc:parsed});else overrides.delete(scope);
                applyTime();return {};
            },
            performance(value='balanced'){
                if(!Object.hasOwn(budgets,value))throw Error('Unknown scene graphics profile');profile=value;
                for(const key of Object.keys(layers))if(layers[key].tileset)Object.assign(layers[key].tileset,options(key));
                for(const key of Object.keys(layers))visibility(key);
            },
            dispose(){
                if(disposed)return;disposed=true;removeUpdate();
                for(const l of Object.values(layers))release(l);
                if(credited)creditDisplay?.removeStaticCredit(credit);
            }
        };
    }
    function bindTimeControls(doc,changed){
        const mode=doc.getElementById('flight-time-mode'),value=doc.getElementById('flight-time-value');
        const fixed=doc.getElementById('flight-time-fixed'),error=doc.getElementById('flight-time-error');
        const localValue=date=>`${date.getFullYear()}-${String(date.getMonth()+1).padStart(2,'0')}-${String(date.getDate()).padStart(2,'0')}T${String(date.getHours()).padStart(2,'0')}:${String(date.getMinutes()).padStart(2,'0')}`;
        function update(next){
            mode.value=next.enabled?(next.timeUtc?'fixed':'now'):'map';fixed.hidden=mode.value!=='fixed';
            if(next.timeUtc)value.value=localValue(new Date(next.timeUtc));error.textContent='';
        }
        function change(){
            try{
                fixed.hidden=mode.value!=='fixed';
                if(mode.value==='fixed'&&!value.value)value.value=localValue(new Date());
                const date=mode.value==='fixed'?new Date(value.value):null;
                if(date&&localValue(date)!==value.value)throw Error('Ungültige oder nicht existierende lokale Uhrzeit.');
                const next={enabled:mode.value!=='map',timeUtc:date?time(date.toISOString()):null};
                changed(next);update(next);
            }catch(e){error.textContent=e.message;}
        }
        mode.addEventListener('change',change);value.addEventListener('change',change);
        update({enabled:false});return {update};
    }
    return {sources,budgets,time,create,bindTimeControls};
});


/* Issue #111: official swissTLM3D centerline discovery, schematic display only.
 * No tunnel volumes, portal dimensions or collision clearance are inferred. */
(function (root, factory) {
    const api = factory();
    if (typeof module === 'object' && module.exports) module.exports.FPVTunnelInfrastructure = api;
    else root.FPVTunnelInfrastructure = api;
})(typeof globalThis !== 'undefined' ? globalThis : this, function () {
    'use strict';
    const ENDPOINT = 'https://api3.geo.admin.ch/rest/services/ech/MapServer/identify';
    const LAYERS = Object.freeze({
        road: 'ch.swisstopo.swisstlm3d-strassen',
        railway: 'ch.swisstopo.swisstlm3d-eisenbahnnetz'
    });
    const MAX_FEATURES = 48, MAX_VERTICES = 4096, MAX_RESPONSE = 1024 * 1024;
    const BOUNDS = Object.freeze({west: 5.8, east: 10.7, south: 45.6, north: 47.9});
    const label = value => String(value ?? '').trim().slice(0, 120);
    function category(value, transport = 'road') {
        const code = Number(value);
        if (transport === 'road') {
            if (code === 1000) return 'tunnel';
            if (code === 1100 || code === 1200) return 'underpass';
        }
        // Codes differ in the railway catalogue; accept only explicit names.
        const normalized = label(value).toLowerCase().normalize('NFD').replace(/[\u0300-\u036f]/g, '');
        if (/^tunnel(?:\b|_)/.test(normalized)) return 'tunnel';
        if (/^unterf(?:u|ue)hrung/.test(normalized) || /^underpass/.test(normalized)) return 'underpass';
        return null;
    }
    function bounds(lon, lat, radius = 600) {
        if (![lon, lat, radius].every(Number.isFinite) || radius < 150 || radius > 1500 ||
            lon < BOUNDS.west || lon > BOUNDS.east || lat < BOUNDS.south || lat > BOUNDS.north)
            throw Error('Choose a supported Swiss map position and a search radius of 150–1500 m.');
        const dx = radius / (111320 * Math.max(.5, Math.cos(lat * Math.PI / 180)));
        const dy = radius / 111320;
        return [lon - dx, lat - dy, lon + dx, lat + dy];
    }
    function urlFor(box, transport) {
        if (!LAYERS[transport]) throw Error('Unsupported swissTLM3D transport layer');
        const p = new URLSearchParams({
            geometryType: 'esriGeometryEnvelope', geometry: box.join(','),
            mapExtent: box.join(','), imageDisplay: '512,512,96',
            tolerance: '0', sr: '4326', geometryFormat: 'geojson',
            returnGeometry: 'true', layers: `all:${LAYERS[transport]}`,
        });
        return `${ENDPOINT}?${p}`;
    }
    function vertices(geometry) {
        if (!geometry || typeof geometry !== 'object') return [];
        const chains = geometry.type === 'LineString' ? [geometry.coordinates] :
            geometry.type === 'MultiLineString' ? geometry.coordinates : [];
        if (!Array.isArray(chains) || chains.length > 32) return [];
        return chains.flatMap(chain => {
            if (!Array.isArray(chain) || chain.length > MAX_VERTICES) return [];
            const parsed = chain.map(point => Array.isArray(point) && point.length >= 2 &&
                Number.isFinite(point[0]) && Number.isFinite(point[1]) &&
                point[0] >= BOUNDS.west && point[0] <= BOUNDS.east &&
                point[1] >= BOUNDS.south && point[1] <= BOUNDS.north ?
                [point[0], point[1]] : null);
            return parsed.every(Boolean) && parsed.length >= 2 ? [parsed] : [];
        });
    }
    function parseIdentify(json, transport = 'road') {
        if (!json || !Array.isArray(json.results) || json.results.length > 200)
            throw Error('Swiss feature response invalid or truncated.');
        const result = [], seen = new Set();
        let vertexCount = 0, incomplete = json.results.length >= 200;
        for (const feature of json.results) {
            if (result.length >= MAX_FEATURES) { incomplete = true; break; }
            const properties = feature?.properties ?? feature?.attributes ?? {};
            if (!properties || typeof properties !== 'object') continue;
            const kind = category(properties.KUNSTBAUTE ?? properties.kunstbaute ??
                properties.Kunstbaute ?? properties.kunstbaute_lookup, transport);
            if (!kind) continue;
            const routes = vertices(feature.geometry);
            if (!routes.length) { incomplete = true; continue; }
            const rawId = label(feature.featureId ?? feature.id);
            if (!rawId) { incomplete = true; continue; }
            for (let part = 0; part < routes.length; part++) {
                const coordinates = routes[part];
                if (vertexCount + coordinates.length > MAX_VERTICES) { incomplete = true; break; }
                const id = `${transport}:${rawId}:${part}`;
                if (seen.has(id)) continue;
                seen.add(id); vertexCount += coordinates.length;
                result.push({id, name: label(properties.STRASSENNAME ?? properties.NAME ??
                    properties.name ?? properties.label) || `${transport === 'road' ? 'Road' : 'Railway'} ${kind}`,
                    kind, transport, coordinates,
                    // Identified centerline end is NOT an independently surveyed tunnel portal.
                    endpointsVerified: false, heightReference: 'unavailable',
                    source: LAYERS[transport], sourceId: rawId});
            }
        }
        return {routes: result, incomplete};
    }
    async function limitedJson(response, signal) {
        if (!response?.ok) throw Error(`Official swissTLM3D request failed (${response?.status ?? 'network'}).`);
        if (Number(response.headers?.get?.('content-length') ?? 0) > MAX_RESPONSE)
            throw Error('Official feature response exceeds memory budget.');
        if (response.body?.getReader) {
            const reader = response.body.getReader(); let total = 0;
            const chunks = [];
            try {
                for (;;) {
                    if (signal?.aborted) throw Error('Infrastructure request cancelled');
                    const {done, value} = await reader.read();
                    if (done) break;
                    total += value.length;
                    if (total > MAX_RESPONSE) throw Error('Official feature response exceeds memory budget.');
                    chunks.push(value);
                }
            } finally { reader.releaseLock(); }
            const bytes = new Uint8Array(total); let pos = 0;
            for (const chunk of chunks) { bytes.set(chunk, pos); pos += chunk.length; }
            return JSON.parse(new TextDecoder().decode(bytes));
        }
        const text = await response.text();
        if (text.length > MAX_RESPONSE) throw Error('Official feature response exceeds memory budget.');
        return JSON.parse(text);
    }
    function create(C, viewer, emit = () => {}, {fetcher = (...args) => fetch(...args),
        now = () => performance.now(), isOnline = () => globalThis.navigator?.onLine !== false,
        isTerrainReady = () => true, setTimer = setTimeout, clearTimer = clearTimeout} = {}) {
        let disposed = false, visible = false, manualVisible = false, automatic = false, allowed = false, items = [], active = null, opacity = .85;
        let requestController = null, revision = 0, lastRequestAt = -Infinity;
        let dataSource = null, removeFrame = null, pending = false;
        let autoTimer = null, lastAutoAt = -Infinity, lastAutoCenter = null;
        let autoState = 'hidden', autoCount = 0, autoIncomplete = true;
        const scene = viewer.scene, camera = viewer.camera;
        const AUTO_INTERVAL = 20000, AUTO_RADIUS = 900, AUTO_CAMERA_LIMIT = 8000;
        const cancelAutoTimer = () => { if (autoTimer !== null) { clearTimer(autoTimer); autoTimer = null; } };
        const removeMoveEnd = camera.moveEnd?.addEventListener?.(() => scheduleAutomaticScan());
        function clearData() {
            if (dataSource) { viewer.dataSources.remove(dataSource, true); dataSource = null; }
            scene.requestRender?.();
        }
        function draw() {
            clearData();
            if (!visible || !items.length) return;
            const source = dataSource = new C.CustomDataSource('FPVManager swissTLM3D tunnel centerlines (schematic surface trace)');
            for (const route of items) {
                source.entities.add({ id:`fpv-tunnel-${route.id}`, name:route.name,
                    description:`Schematic surface projection only. ${route.source} / ${route.sourceId}. No tunnel interior or verified portals.`,
                    polyline:{ positions:C.Cartesian3.fromDegreesArray(route.coordinates.flat()),
                        clampToGround:true, width:3,
                        material:new C.PolylineDashMaterialProperty({color:C.Color.ORANGE?.withAlpha?.(opacity) ?? C.Color.ORANGE}),
                    },
                });
                // Schematic centerline endpoints: do NOT assert these are portals.
                for(const [index,coordinate] of [route.coordinates[0],route.coordinates.at(-1)].entries()){
                    source.entities.add({id:`fpv-tunnel-end-${route.id}:${index}`,
                        name:`Centerline ${index?'end':'start'} (NOT verified portal)`,
                        description:`Unverified endpoint of ${route.source} / ${route.sourceId}. No clearance data.`,
                        position:C.Cartesian3.fromDegrees(coordinate[0],coordinate[1]),
                        point:{pixelSize:6,color:C.Color.ORANGE?.withAlpha?.(opacity) ?? C.Color.ORANGE,
                            heightReference:C.HeightReference?.CLAMP_TO_GROUND}});
                }
            }
            viewer.dataSources.add(source);
            scene.requestRender?.();
        }
        function stop(restore = true, message = null) {
            if (!active) return;
            const previous = active;
            active = null;
            removeFrame?.(); removeFrame = null;
            if (restore && !disposed) camera.setView({destination:previous.position,
                orientation:previous.orientation});
            emit('infrastructure-exploration-status', {active:false, message});
            scene.requestRender?.();
        }
        function clear() { revision++;requestController?.abort();requestController = null;pending = false;stop();items = [];clearData(); }
        // The official service publishes axes, NOT surveyed tubes or portals.
        // Discover nearby schematic routes only when the 3D structures layer is enabled.
        // A viewport scan is bounded, deferred until camera idle, and rate-limited.
        function automaticCenter() {
            if (!automatic || disposed || !isOnline() || !camera.getPickRay ||
                !C.Cartesian2 || !C.Cartographic?.fromCartesian || !C.Math?.toDegrees ||
                !viewer.canvas || camera.positionCartographic?.height > AUTO_CAMERA_LIMIT) return null;
            const canvas = viewer.canvas;
            if (!canvas.clientWidth || !canvas.clientHeight) return null;
            if (C.SceneMode && scene.mode !== C.SceneMode.SCENE3D) return null;
            const target = new C.Cartesian2(canvas.clientWidth / 2, canvas.clientHeight / 2);
            const ray = camera.getPickRay(target);
            // Ellipsoid fallback only chooses a search region; it does NOT
            // manufacture a tunnel portal, elevation or clearance.
            const hit = (ray && scene.globe.pick?.(ray, scene)) ?? camera.pickEllipsoid?.(target);
            if (!hit) return null;
            const center = C.Cartographic.fromCartesian(hit);
            const longitude = C.Math.toDegrees(center.longitude), latitude = C.Math.toDegrees(center.latitude);
            try { bounds(longitude, latitude, AUTO_RADIUS); } catch (_) { return null; }
            return {longitude, latitude};
        }
        function publishAutomatic(state, count = autoCount, incomplete = autoIncomplete) {
            if (state === autoState && count === autoCount && incomplete === autoIncomplete) return;
            autoState = state; autoCount = count; autoIncomplete = incomplete;
            emit('tunnel-auto-status', {state, count, incomplete});
        }
        function scheduleAutomaticScan() {
            cancelAutoTimer();
            if (!automatic || disposed) return;
            autoTimer = setTimer(() => {
                autoTimer = null;
                const center = automaticCenter(), stamp = now();
                if (!center) {publishAutomatic(isOnline()?'outside':'offline');return;}
                if (pending || stamp - lastAutoAt < AUTO_INTERVAL) return;
                if (lastAutoCenter && Math.hypot(
                    (center.longitude - lastAutoCenter.longitude) * 75000,
                    (center.latitude - lastAutoCenter.latitude) * 111000) < 350) return;
                lastAutoAt = stamp;
                publishAutomatic('loading');
                scan({...center, radiusMeters:AUTO_RADIUS}).then(result => {
                    if (!automatic || disposed) return;
                    lastAutoCenter = center;
                    publishAutomatic(result.incomplete?'partial':'ready',result.count,result.incomplete);
                }).catch(() => {
                    // Keep existing routes on transient failure, never claim
                    // that a failed source query proves no tunnels exist.
                    if (automatic && !disposed) publishAutomatic(isOnline()?'failed':'offline');
                });
            }, 650);
        }
        function updateVisibility() {
            const next = manualVisible || automatic;
            if (!next) { if (visible) clear(); visible = false; }
            else if (!visible) { visible = true; draw(); }
        }
        function setAutomatic(enabled) {
            if (typeof enabled !== 'boolean') throw Error('Invalid automatic tunnel setting');
            if (disposed || enabled === automatic) return {automatic, visible};
            automatic = enabled; if (!automatic) {cancelAutoTimer();publishAutomatic('hidden',0,true);}
            updateVisibility();
            if (automatic) {publishAutomatic('waiting',0,true);scheduleAutomaticScan();}
            return {automatic, visible};
        }
        function set({routesVisible, explorationAllowed, opacity:nextOpacity = opacity} = {}) {
            if (typeof routesVisible !== 'boolean' || typeof explorationAllowed !== 'boolean')
                throw Error('Invalid tunnel settings');
            if(!Number.isFinite(nextOpacity)||nextOpacity<.2||nextOpacity>1)throw Error('Invalid tunnel opacity');
            if (disposed) return {};
            if (!routesVisible || !explorationAllowed) stop();
            manualVisible = routesVisible; allowed = explorationAllowed; opacity = nextOpacity;
            updateVisibility();
            draw();return {visible, automatic, explorationAllowed:allowed, count:items.length};
        }
        async function scan({longitude,latitude,radiusMeters = 600} = {},signal) {
            if (disposed || !visible) throw Error('Enable tunnel routes first.');
            if (!isOnline()) throw Error('Official tunnel data requires a connection; no offline routes are cached.');
            const box = bounds(longitude, latitude, radiusMeters);
            if (pending) throw Error('Tunnel request already running.');
            if (now() - lastRequestAt < 1500) throw Error('Please wait before requesting another area.');
            lastRequestAt = now(); pending = true;
            stop();
            const token = ++revision;
            requestController?.abort();
            const local = new AbortController(); requestController = local;
            const abort = () => local.abort();signal?.addEventListener('abort',abort,{once:true});
            const timeout = setTimeout(() => local.abort(), 12000);
            try {
                const routes = [], sources = [], failed = [];
                let incomplete = false;
                for (const transport of Object.keys(LAYERS)) {
                    if (local.signal.aborted) throw Error('Tunnel request cancelled.');
                    try {
                        const response = await fetcher(urlFor(box, transport), {signal: local.signal});
                        const decoded = parseIdentify(await limitedJson(response,local.signal),transport);
                        routes.push(...decoded.routes); sources.push(LAYERS[transport]);
                        incomplete ||= decoded.incomplete;
                    } catch (error) {
                        if (local.signal.aborted) throw error;
                        failed.push(`${transport}: ${String(error.message || error).slice(0,100)}`);
                    }
                }
                if (token !== revision || disposed || local.signal.aborted) throw Error('Tunnel request superseded.');
                if (!sources.length) throw Error('No supported official tunnel feature service responded.');
                incomplete ||= failed.length > 0 || routes.length > MAX_FEATURES;
                items = routes.slice(0,MAX_FEATURES);draw();
                const data = {count:items.length, incomplete, queriedAtUtc:new Date().toISOString(),
                    sourceLayers:sources, failedLayers:failed, bbox:box,
                    routes:items.map(({coordinates,...details})=>({...details, vertexCount:coordinates.length}))};
                emit('infrastructure-scan-status',{count:items.length,incomplete});
                return data;
            } finally {
                clearTimeout(timeout);signal?.removeEventListener('abort',abort);
                if (token === revision){pending = false;requestController = null;}
            }
        }
        function routeById(routeId) {
            if (typeof routeId !== 'string' || routeId.length > 150) throw Error('Invalid route selection');
            const found = items.find(r => r.id === routeId);
            if (!found || !visible) throw Error('Selected tunnel route is not available in the current area.');
            return found;
        }
        function groundAt(lon,lat) {
            if (!isTerrainReady()) throw Error('Detailed terrain is unavailable for schematic exploration.');
            const height = scene.globe.getHeight(C.Cartographic.fromDegrees(lon,lat));
            if (!Number.isFinite(height)) throw Error('Terrain elevation missing at the selected route.');
            return height;
        }
        function viewPoint(position, next) {
            const lon = position[0], lat = position[1];
            const terrain = groundAt(lon,lat);
            const heading = Math.atan2((next[0]-lon)*Math.cos(lat*Math.PI/180),next[1]-lat);
            camera.setView({destination:C.Cartesian3.fromDegrees(lon,lat,terrain+6),
                orientation:{heading,pitch:0,roll:0}});
            scene.requestRender?.();
        }
        function focus({routeId, end = false}={}) {
            if (typeof end !== 'boolean') throw Error('Invalid endpoint');
            const route = routeById(routeId);
            stop();
            const position = end?route.coordinates.at(-1):route.coordinates[0];
            const target = end?route.coordinates.at(-2):route.coordinates[1];
            viewPoint(position,target);
            return {routeId:route.id, mode:'schematic-surface', portalVerified:false};
        }
        function explore({routeId} = {}) {
            if (!allowed) throw Error('Enable schematic tunnel exploration first.');
            const route = routeById(routeId);
            if (route.coordinates.length < 2 || route.coordinates.length > 512) throw Error('Unsupported route geometry.');
            stop();
            // Verify a terrain solution BEFORE switching camera modes.
            for (const point of [route.coordinates[0],route.coordinates.at(-1)]) groundAt(...point);
            const position = C.Cartesian3.clone(camera.position);
            const orientation = {heading:camera.heading,pitch:camera.pitch,roll:camera.roll};
            active = {position,orientation,start:now(),points:route.coordinates};
            emit('infrastructure-exploration-status',{active:true,
                message:'Schematic SURFACE trace only – NOT a traversable tunnel or surveyed portal.'});
            function update() {
                if (disposed || !active) return;
                const p=active,progress=Math.min(1,(now()-p.start)/15000),offset=progress*(p.points.length-1);
                const i=Math.min(p.points.length-2,Math.floor(offset)),t=offset-i;
                const a=p.points[i],b=p.points[i+1];
                const current=[a[0]+(b[0]-a[0])*t,a[1]+(b[1]-a[1])*t];
                try {viewPoint(current,b);}catch(err){stop(true,err.message);return;}
                if(progress>=1)stop();
            }
            removeFrame = scene.preRender.addEventListener(update);
            update();
            return {active:true,mode:'schematic-surface',durationSeconds:15};
        }
        function pick(entity) {
            if (!entity || typeof entity.id !== 'string' || !entity.id.startsWith('fpv-tunnel-')) return false;
            const route=items.find(r=>`fpv-tunnel-${r.id}`===entity.id);
            if(!route)return false;
            emit('infrastructure-selected',{id:route.id,name:route.name,kind:route.kind,transport:route.transport,
                datasetSource:route.source,sourceId:route.sourceId,portalsVerified:false,heightReference:'unavailable'});
            return true;
        }
        return {set,setAutomatic,scan,focus,explore,stop,pick,
            geometry(routeId){const r=routeById(routeId);return {id:r.id,source:r.source,sourceId:r.sourceId,
                coordinates:r.coordinates.map(pair=>[...pair])};},
            dispose(){if(disposed)return;cancelAutoTimer();removeMoveEnd?.();clear();disposed=true;},
            status(){return {visible,automatic,autoState,allowed,pending,count:items.length,exploring:!!active};}};
    }
    return {ENDPOINT,LAYERS,BOUNDS,category,bounds,urlFor,parseIdentify,create};
});
/* Issue #112: bounded, explicitly SIMULATION-ONLY tunnel geometry. This is not
 * a surveyed tunnel, a clearance certificate, or permission to enter a site.
 * Kept in scene_environment.js to use the existing registered Flutter asset. */
(function(root,factory){
    const api=factory();
    if(typeof module==='object'&&module.exports) module.exports.FPVTunnelFlythrough=api;
    else root.FPVTunnelFlythrough=api;
})(typeof globalThis!=='undefined'?globalThis:this,function(){
    'use strict';
    const R=6378137,DEG=Math.PI/180,MAX_SECTIONS=96,MAX_LENGTH=2200;
    const finite=Number.isFinite;
    const PROFILES=Object.freeze(['rectangular','vaulted']);
    const xy=(point,origin)=>({x:(point.longitude-origin.longitude)*DEG*R*Math.cos(origin.latitude*DEG),
        y:(point.latitude-origin.latitude)*DEG*R});
    function length(a,b){const p=xy(b,a);return Math.hypot(p.x,p.y);}
    function validateSections(sections){
        if(!Array.isArray(sections)||sections.length<2||sections.length>MAX_SECTIONS)
            throw Error('Tunnel model requires 2–96 cross sections.');
        let distance=0;
        return sections.map((s,i)=>{
            if(!s||![s.longitude,s.latitude,s.floorMetersWgs84,s.widthMeters,s.heightMeters].every(finite)
                ||s.longitude<5.8||s.longitude>10.7||s.latitude<45.6||s.latitude>47.9
                ||s.floorMetersWgs84 < -500||s.floorMetersWgs84>9000
                ||s.widthMeters<3||s.widthMeters>15||s.heightMeters<3||s.heightMeters>12)
                throw Error('Invalid tunnel cross section, bounds or elevation reference.');
            if(i){const step=length(sections[i-1],s);if(step<.5||step>200)throw Error('Unusable tunnel segment length.');
                distance+=step;if(distance>MAX_LENGTH)throw Error('Tunnel exceeds bounded length.');}
            return {longitude:s.longitude,latitude:s.latitude,floorMetersWgs84:s.floorMetersWgs84,
                widthMeters:s.widthMeters,heightMeters:s.heightMeters};
        });
    }
    function procedural(route,groundHeights,{widthMeters=6,heightMeters=5,profile='rectangular'}={}){
        if(!PROFILES.includes(profile))throw Error('Unsupported tunnel cross-section profile.');
        if(!route||!Array.isArray(route.coordinates)||route.coordinates.length<2||
            route.coordinates.length>MAX_SECTIONS||!Array.isArray(groundHeights)||
            route.coordinates.length!==groundHeights.length)throw Error('Unsupported tunnel centerline or terrain profile.');
        if(![widthMeters,heightMeters].every(finite)||widthMeters<3||widthMeters>15||heightMeters<3||heightMeters>12)
            throw Error('Simulation dimensions must be within 3–15 m width and 3–12 m height.');
        const pts=route.coordinates.map((p,i)=>{
            if(!Array.isArray(p)||p.length<2||![p[0],p[1],groundHeights[i]].every(finite))
                throw Error('Terrain data missing – no simulated tunnel created.');
            return {longitude:p[0],latitude:p[1],terrain:groundHeights[i]};
        });
        const distances=[0];for(let i=1;i<pts.length;i++)distances.push(distances[i-1]+length(pts[i-1],pts[i]));
        const total=distances.at(-1);
        const sections=validateSections(pts.map((p,i)=>({longitude:p.longitude,latitude:p.latitude,
            // Smooth approach to the simulated underground segment. The endpoints
            // are synthetic and NOT verified real-world portal elevations.
            floorMetersWgs84:p.terrain+.6-heightMeters*.75*Math.min(1,distances[i]/12,(total-distances[i])/12),
            widthMeters,heightMeters})));
        return {version:1,identity:String(route.id||'local').slice(0,150),quality:'simulation-only',
            source:String(route.source||'').slice(0,160),sourceId:String(route.sourceId||'').slice(0,160),
            elevationReference:'WGS84_ELLIPSOID',portalsVerified:false,clearanceVerified:false,
            label:'SYNTHETIC TUNNEL · SIMULATION ONLY',profile,sections};
    }
    // Externally supplied cross-section files are unverified until their
    // provenance has been checked independently. They cannot enable automatic
    // replay or assert that published clearance is established.
    function importSections(document){
        if(!document||document.version!==1||document.elevationReference!=='WGS84_ELLIPSOID'
            ||typeof document.source!=='string'||!document.source.trim()
            ||document.source.length>256)throw Error('Explicit WGS84 elevation and source required.');
        if(document.profile!==undefined&&!PROFILES.includes(document.profile))
            throw Error('Unsupported tunnel cross-section profile.');
        return {version:1,identity:String(document.identity||'imported').slice(0,150),
            source:document.source,sourceId:String(document.sourceId||'').slice(0,160),
            quality:'external-unverified',elevationReference:'WGS84_ELLIPSOID',
            portalsVerified:false,clearanceVerified:false,
            label:'EXTERNAL GEOMETRY · CLEARANCE NOT VERIFIED',profile:document.profile??'rectangular',
            sections:validateSections(document.sections)};
    }
    /* Version 2 is an explicit, local, georeferenced triangle mesh interchange.
     * It does NOT parse arbitrary glTF/IFC, infer a datum, or certify accuracy.
     * WGS84 longitude/latitude/degrees + ellipsoid metres (EPSG:4979) only.
     * Separate render/collider meshes allow a conservative collision proxy. */
    const MAX_MESH_VERTICES=8192,MAX_MESH_TRIANGLES=12000;
    function validateTriMesh(raw,name){
        if(!raw||!Array.isArray(raw.vertices)||raw.vertices.length<3||
            raw.vertices.length>MAX_MESH_VERTICES||!Array.isArray(raw.triangles)||
            raw.triangles.length<1||raw.triangles.length>MAX_MESH_TRIANGLES)
            throw Error(`${name}: bounded vertices and triangles required.`);
        const vertices=raw.vertices.map(v=>{
            if(!Array.isArray(v)||v.length!==3||!v.every(finite)||
                v[0]<5.8||v[0]>10.7||v[1]<45.6||v[1]>47.9||v[2]<-500||v[2]>9000)
                throw Error(`${name}: EPSG:4979 [longitude, latitude, ellipsoid height] required.`);
            return v.slice();
        });
        const origin=vertices[0];
        for(const v of vertices){
            if(length({longitude:origin[0],latitude:origin[1]},
                {longitude:v[0],latitude:v[1]})>20000||Math.abs(v[2]-origin[2])>3000)
                throw Error(`${name}: vertex outside supported 20 km / 3 km local extent.`);
        }
        const xyz=vertices.map(v=>ecef(...v));
        const triangles=raw.triangles.map(t=>{
            if(!Array.isArray(t)||t.length!==3||t.some(i=>!Number.isInteger(i)||i<0||i>=vertices.length)||
                new Set(t).size!==3)throw Error(`${name}: invalid triangle index.`);
            const ab=sub(xyz[t[1]],xyz[t[0]]),ac=sub(xyz[t[2]],xyz[t[0]]);
            if(norm2(cross(ab,ac))<1e-12)throw Error(`${name}: degenerate triangle.`);
            return t.slice();
        });
        return {vertices,triangles};
    }
    function validateClips(value,origin,name){
        if(value===undefined)return [];
        if(!Array.isArray(value)||value.length>8)throw Error(`${name}: at most eight clipping polygons.`);
        return value.map(poly=>{
            if(!Array.isArray(poly)||poly.length<3||poly.length>24)throw Error(`${name}: polygon has invalid size.`);
            const vertices=poly.map(p=>{
                if(!Array.isArray(p)||p.length!==2||!p.every(finite)||p[0]<5.8||p[0]>10.7||
                    p[1]<45.6||p[1]>47.9||
                    length({longitude:origin[0],latitude:origin[1]},
                        {longitude:p[0],latitude:p[1]})>20000)
                    throw Error(`${name}: invalid WGS84 polygon vertex.`);
                return p.slice();
            });
            let twiceArea=0;for(let i=0;i<vertices.length;i++){
                const a=xy({longitude:vertices[i][0],latitude:vertices[i][1]},
                    {longitude:origin[0],latitude:origin[1]});
                const b=xy({longitude:vertices[(i+1)%vertices.length][0],
                    latitude:vertices[(i+1)%vertices.length][1]},
                    {longitude:origin[0],latitude:origin[1]});
                twiceArea+=a.x*b.y-b.x*a.y;
            }
            if(Math.abs(twiceArea)<1)throw Error(`${name}: degenerate clipping polygon.`);
            return vertices;
        });
    }
    function importGeoreferencedMesh(doc){
        if(!doc||doc.version!==2||doc.format!=='fpvmanager-georeferenced-trimesh'||
            doc.coordinateReference!=='EPSG:4979'||doc.elevationReference!=='WGS84_ELLIPSOID'||
            typeof doc.source!=='string'||!doc.source.trim()||doc.source.length>256)
            throw Error('Version 2 requires explicit EPSG:4979, ellipsoid height and source.');
        const visualMesh=validateTriMesh(doc.visualMesh,'Visual mesh');
        const collisionGeometry=validateTriMesh(doc.collisionMesh,'Collision mesh');
        // Collision proxies may be simpler but must occupy the same local area.
        const first=visualMesh.vertices[0];
        if(collisionGeometry.vertices.some(v=>length({longitude:first[0],latitude:first[1]},
            {longitude:v[0],latitude:v[1]})>20000||Math.abs(v[2]-first[2])>3000))
            throw Error('Collision mesh is not colocated with the visual model.');
        const clipping=doc.terrainClipPolygons;
        if(clipping!==undefined&&(!clipping||typeof clipping!=='object'||Array.isArray(clipping)))
            throw Error('Invalid terrain clipping document.');
        const previewClips=validateClips(clipping?.preview,first,'Preview terrain clipping');
        const flightClips=validateClips(clipping?.flight,first,'Flight terrain clipping');
        let entryPose=null;
        if(doc.entryPose!==undefined){
            const pose=doc.entryPose;
            if(!pose||![pose.longitude,pose.latitude,pose.height,pose.headingRadians].every(finite)||
                Math.abs(pose.headingRadians)>2*Math.PI||
                length({longitude:first[0],latitude:first[1]},pose)>20000||
                pose.height<-500||pose.height>9000)
                throw Error('Invalid explicit entry pose (EPSG:4979/metres/radians).');
            entryPose={longitude:pose.longitude,latitude:pose.latitude,
                height:pose.height,heading:pose.headingRadians,ground:pose.height};
        }
        let sections=null;
        if(doc.flightProfile!==undefined){
            if(!doc.flightProfile||doc.flightProfile.profile!=='rectangular'&&
                doc.flightProfile.profile!=='vaulted')throw Error('Invalid explicit flight profile.');
            sections=validateSections(doc.flightProfile.sections);
        }
        const canFly=!!entryPose&&!!sections&&flightClips.length>0;
        const imported={version:2,kind:'georeferenced-trimesh',
            identity:String(doc.identity||'local-mesh').slice(0,150),
            source:doc.source,sourceId:String(doc.sourceId||'').slice(0,160),
            quality:'external-mesh-unverified',label:'GEOREFERENCED MESH · SOURCE NOT VERIFIED',
            elevationReference:'WGS84_ELLIPSOID',coordinateReference:'EPSG:4979',
            portalsVerified:false,clearanceVerified:false,
            visualMesh,collisionGeometry,previewClips,flightClips,entryPose,sections,
            profile:doc.flightProfile?.profile??null,canFly};
        if(canFly){
            if(!inside(imported,entryPose,.25)||collision(imported,entryPose,entryPose,.25))
                throw Error('Flight entry pose intersects a wall or is outside the explicit tunnel profile.');
            entryPose.ground=closest(imported,entryPose).floor;
        }
        return imported;
    }
    function closest(model,point){
        if(!model?.sections||!point||![point.latitude,point.longitude,point.height].every(finite))return null;
        const s=model.sections,origin=s[0],p=xy(point,origin);
        let nearest=null;
        for(let i=0;i<s.length-1;i++){
            const a=xy(s[i],origin),b=xy(s[i+1],origin),dx=b.x-a.x,dy=b.y-a.y,den=dx*dx+dy*dy;
            const raw=((p.x-a.x)*dx+(p.y-a.y)*dy)/den,t=Math.max(0,Math.min(1,raw));
            const lateral=((p.x-a.x)*dy-(p.y-a.y)*dx)/Math.sqrt(den);
            const dist=Math.hypot(p.x-a.x-t*dx,p.y-a.y-t*dy);
            if(nearest&&nearest.distance<=dist)continue;
            const interp=(key)=>s[i][key]+(s[i+1][key]-s[i][key])*t;
            nearest={distance:dist,lateral,segment:i,t,raw,
                floor:interp('floorMetersWgs84'),height:interp('heightMeters'),width:interp('widthMeters'),
                heading:Math.atan2(dx,dy)};
        }
        return nearest;
    }
    function inside(model,point,radius=.25){
        if(!finite(radius)||radius<0||radius>1)return false;
        const p=closest(model,point);if(!p)return false;
        const half=p.width/2;
        const roof=model.profile==='vaulted'
            ? p.height-Math.min(p.height*.45,half)+Math.min(p.height*.45,half)*
                Math.sqrt(Math.max(0,1-Math.pow(p.lateral/half,2)))
            : p.height;
        return p.distance<=half-radius && point.height>=p.floor+radius &&
            point.height<=p.floor+roof-radius &&
            !(p.segment===0&&p.raw<0) &&
            !(p.segment===model.sections.length-2&&p.raw>1);
    }
    function rings(model){
        const sections=model.sections;
        const vaulted=model.profile==='vaulted';
        return sections.map((s,i)=>{
            const prev=sections[Math.max(0,i-1)],next=sections[Math.min(sections.length-1,i+1)];
            const v=xy(next,prev),d=Math.hypot(v.x,v.y);
            if(d<1e-9)throw Error('Degenerate tunnel cross-section tangent.');
            const east=-v.y/d,north=v.x/d;
            const lonOffset=m=>m/(R*DEG*Math.cos(s.latitude*DEG)),latOffset=m=>m/(R*DEG);
            const point=(lateral,up)=>[s.longitude+lonOffset(east*lateral),
                s.latitude+latOffset(north*lateral),s.floorMetersWgs84+up];
            const half=s.widthMeters/2;
            if(!vaulted)return [point(-half,0),point(half,0),point(half,s.heightMeters),point(-half,s.heightMeters)];
            // Interior vaulted profile: flat floor, vertical sidewalls and a
            // tessellated elliptical arch. The roof is part of the actual
            // collision mesh, not a loose bounding box or inferred clearance.
            const rise=Math.min(s.heightMeters*.45,half),spring=s.heightMeters-rise;
            const ring=[point(-half,0),point(half,0),point(half,spring)];
            for(let j=1;j<=8;j++){
                const theta=Math.PI*j/8;
                ring.push(point(half*Math.cos(theta),spring+rise*Math.sin(theta)));
            }
            return ring;
        });
    }
    function geometry(C,model){
        if(model.kind==='georeferenced-trimesh'){
            const coords=[];
            for(const p of model.visualMesh.vertices){
                const xyz=C.Cartesian3.fromDegrees(p[0],p[1],p[2]);
                coords.push(xyz.x,xyz.y,xyz.z);
            }
            const indices=model.visualMesh.triangles.flat();
            return new C.Geometry({attributes:{position:new C.GeometryAttribute({
                componentDatatype:C.ComponentDatatype.DOUBLE,componentsPerAttribute:3,
                values:new Float64Array(coords)})},indices:new Uint16Array(indices),
                primitiveType:C.PrimitiveType.TRIANGLES,
                boundingSphere:C.BoundingSphere.fromVertices(coords)});
        }
        const ring=rings(model),coords=[],indices=[];
        const put=p=>{const xyz=C.Cartesian3.fromDegrees(p[0],p[1],p[2]);
            coords.push(xyz.x,xyz.y,xyz.z);return coords.length/3-1;};
        // Open at both ends: no invisible blocking face across either portal.
        // Double-sided rendering matches the collision triangles exactly.
        for(let face=0;face<ring[0].length;face++)for(let i=0;i<ring.length-1;i++){
            const a=put(ring[i][face]),b=put(ring[i][(face+1)%ring[i].length]),
                c=put(ring[i+1][(face+1)%ring[i+1].length]),d=put(ring[i+1][face]);
            indices.push(a,b,c,a,c,d);
        }
        if(coords.length/3>8000)throw Error('Tunnel mesh vertex budget exceeded.');
        return new C.Geometry({attributes:{position:new C.GeometryAttribute({componentDatatype:C.ComponentDatatype.DOUBLE,
            componentsPerAttribute:3,values:new Float64Array(coords)})},
            indices:coords.length/3<65536?new Uint16Array(indices):new Uint32Array(indices),
            primitiveType:C.PrimitiveType.TRIANGLES,boundingSphere:C.BoundingSphere.fromVertices(coords)});
    }
    // Collision and rendering consume the SAME rings. Every segment carries
    // an axis-aligned broad-phase box and explicit collision triangles.
    const collisionCache=new WeakMap();
    function ecef(lon,lat,h){
        const phi=lat*DEG,lambda=lon*DEG,sp=Math.sin(phi),cp=Math.cos(phi);
        const n=R/Math.sqrt(1-(1/298.257223563)*(2-1/298.257223563)*sp*sp);
        return [(n+h)*cp*Math.cos(lambda),(n+h)*cp*Math.sin(lambda),
            (n*(1-(1/298.257223563)*(2-1/298.257223563))+h)*sp];
    }
    const sub=(a,b)=>[a[0]-b[0],a[1]-b[1],a[2]-b[2]];
    const add=(a,b)=>[a[0]+b[0],a[1]+b[1],a[2]+b[2]];
    const scale=(a,t)=>[a[0]*t,a[1]*t,a[2]*t];
    const dot=(a,b)=>a[0]*b[0]+a[1]*b[1]+a[2]*b[2];
    const cross=(a,b)=>[a[1]*b[2]-a[2]*b[1],a[2]*b[0]-a[0]*b[2],a[0]*b[1]-a[1]*b[0]];
    const norm2=a=>dot(a,a);
    const clamp01=t=>Math.max(0,Math.min(1,t));
    function pointTriangleDistance2(p,a,b,c){
        // Christer Ericson, Real-Time Collision Detection, closest-point regions.
        const ab=sub(b,a),ac=sub(c,a),ap=sub(p,a),d1=dot(ab,ap),d2=dot(ac,ap);
        if(d1<=0&&d2<=0)return norm2(ap);
        const bp=sub(p,b),d3=dot(ab,bp),d4=dot(ac,bp);
        if(d3>=0&&d4<=d3)return norm2(bp);
        const vc=d1*d4-d3*d2;
        if(vc<=0&&d1>=0&&d3<=0){const v=d1/(d1-d3);return norm2(sub(p,add(a,scale(ab,v))));}
        const cp=sub(p,c),d5=dot(ab,cp),d6=dot(ac,cp);
        if(d6>=0&&d5<=d6)return norm2(cp);
        const vb=d5*d2-d1*d6;
        if(vb<=0&&d2>=0&&d6<=0){const w=d2/(d2-d6);return norm2(sub(p,add(a,scale(ac,w))));}
        const va=d3*d6-d5*d4;
        if(va<=0&&(d4-d3)>=0&&(d5-d6)>=0){const w=(d4-d3)/((d4-d3)+(d5-d6));
            return norm2(sub(p,add(b,scale(sub(c,b),w))));}
        const denominator=va+vb+vc;
        if(Math.abs(denominator)<1e-16)return Math.min(norm2(ap),norm2(bp),norm2(cp));
        const v=vb/denominator,w=vc/denominator;
        return norm2(sub(p,add(a,add(scale(ab,v),scale(ac,w)))));
    }
    function segmentSegmentDistance2(p1,q1,p2,q2){
        const d1=sub(q1,p1),d2=sub(q2,p2),r=sub(p1,p2),a=norm2(d1),e=norm2(d2);
        const f=dot(d2,r);let s=0,t=0;
        if(a<=1e-14&&e<=1e-14)return norm2(r);
        if(a<=1e-14)t=clamp01(f/e);
        else {const c=dot(d1,r);
            if(e<=1e-14)s=clamp01(-c/a);
            else {const b=dot(d1,d2),denom=a*e-b*b;
                if(Math.abs(denom)>1e-14)s=clamp01((b*f-c*e)/denom);
                t=(b*s+f)/e;
                if(t<0){t=0;s=clamp01(-c/a);}
                else if(t>1){t=1;s=clamp01((b-c)/a);}
            }
        }
        return norm2(sub(add(p1,scale(d1,s)),add(p2,scale(d2,t))));
    }
    function segmentHitsTriangle(p,q,a,b,c){
        const dir=sub(q,p),edge1=sub(b,a),edge2=sub(c,a),h=cross(dir,edge2);
        const det=dot(edge1,h);
        if(Math.abs(det)<1e-12)return false;
        const inv=1/det,s=sub(p,a),u=dot(s,h)*inv;
        if(u < -1e-9||u>1+1e-9)return false;
        const v=dot(dir,cross(s,edge1))*inv;
        if(v < -1e-9||u+v>1+1e-9)return false;
        const t=dot(edge2,cross(s,edge1))*inv;
        return t>=-1e-9&&t<=1+1e-9;
    }
    function sweptSphereHitsTriangle(p,q,tri,r2){
        const [a,b,c]=tri;
        if(segmentHitsTriangle(p,q,a,b,c))return true;
        if(pointTriangleDistance2(p,a,b,c)<=r2||pointTriangleDistance2(q,a,b,c)<=r2)return true;
        return segmentSegmentDistance2(p,q,a,b)<=r2||
            segmentSegmentDistance2(p,q,b,c)<=r2||segmentSegmentDistance2(p,q,c,a)<=r2;
    }
    function collisionMesh(model){
        let mesh=collisionCache.get(model);
        if(mesh)return mesh;
        if(model.kind==='georeferenced-trimesh'){
            const {vertices,triangles}=model.collisionGeometry;
            const origin=ecef(...vertices[0]);
            const local=vertices.map(v=>sub(ecef(...v),origin));
            const layers=[];
            // Triangle AABBs are grouped to keep collision work bounded.
            for(let i=0;i<triangles.length;i+=64){
                const batch=triangles.slice(i,i+64).map(indices=>indices.map(j=>local[j]));
                const all=batch.flat();
                const min=[0,1,2].map(k=>Math.min(...all.map(p=>p[k])));
                const max=[0,1,2].map(k=>Math.max(...all.map(p=>p[k])));
                layers.push({min,max,triangles:batch});
            }
            const min=[0,1,2].map(k=>Math.min(...layers.map(l=>l.min[k])));
            const max=[0,1,2].map(k=>Math.max(...layers.map(l=>l.max[k])));
            mesh={origin,layers,min,max,triangleCount:triangles.length};
            collisionCache.set(model,mesh);return mesh;
        }
        const vertices=rings(model).map(r=>r.map(p=>ecef(p[0],p[1],p[2])));
        const origin=ecef(model.sections[0].longitude,model.sections[0].latitude,
            model.sections[0].floorMetersWgs84);
        const layers=[];
        for(let i=0;i<vertices.length-1;i++){
            const a=vertices[i].map(p=>sub(p,origin)),b=vertices[i+1].map(p=>sub(p,origin));
            const all=a.concat(b),min=[0,1,2].map(k=>Math.min(...all.map(p=>p[k]))),
                max=[0,1,2].map(k=>Math.max(...all.map(p=>p[k]))),triangles=[];
            for(let j=0;j<a.length;j++){
                const k=(j+1)%a.length;
                triangles.push([a[j],a[k],b[k]],[a[j],b[k],b[j]]);
            }
            layers.push({min,max,triangles});
        }
        const min=[0,1,2].map(k=>Math.min(...layers.map(l=>l.min[k])));
        const max=[0,1,2].map(k=>Math.max(...layers.map(l=>l.max[k])));
        mesh={origin,layers,min,max,triangleCount:layers.reduce((n,l)=>n+l.triangles.length,0)};
        collisionCache.set(model,mesh);
        return mesh;
    }
    function collision(model,a,b,radius=.25){
        if(!model||!a||!b||!finite(radius)||radius<0||radius>1||
            ![a.longitude,a.latitude,a.height,b.longitude,b.latitude,b.height].every(finite))return false;
        const dist=Math.hypot(length(a,b),b.height-a.height);
        const mesh=collisionMesh(model),p=sub(ecef(a.longitude,a.latitude,a.height),mesh.origin),
            q=sub(ecef(b.longitude,b.latitude,b.height),mesh.origin),r2=radius*radius+1e-10;
        // A long jump is blocked only if its swept AABB approaches THIS model;
        // unrelated models must not stop replay elsewhere on the globe.
        if([0,1,2].some(k=>Math.max(p[k],q[k])+radius<mesh.min[k] ||
            Math.min(p[k],q[k])-radius>mesh.max[k]))return false;
        if(dist>100)return true;
        for(const layer of mesh.layers){
            if([0,1,2].some(k=>Math.max(p[k],q[k])+radius<layer.min[k] ||
                Math.min(p[k],q[k])-radius>layer.max[k]))continue;
            if(layer.triangles.some(t=>sweptSphereHitsTriangle(p,q,t,r2)))return true;
        }
        return false;
    }
    function create(C,viewer,emit=()=>{}, {sampleTerrain=async()=>[],ready=()=>true}={}){
        let model=null,primitive=null,clipping=null,oldClipping=null,flight=false,collisionEnabled=false,revision=0,disposed=false,pending=false;
        const scene=viewer.scene;
        function publish(error=null){emit('tunnel-model-state',{ready:!!model,flight,pending,
            quality:model?.quality??null,label:model?.label??null,source:model?.source??null,
            canFly:model?model.kind!=='georeferenced-trimesh'||model.canFly:false,
            visualTriangles:model?.visualMesh?.triangles.length??null,
            collisionTriangles:model?.collisionGeometry?.triangles.length??null,error});}
        function stop(){
            ++revision;flight=false;pending=false;model=null;
            if(primitive){scene.primitives.remove(primitive);primitive=null;}
            if(clipping){scene.globe.clippingPolygons=oldClipping;clipping=null;oldClipping=null;}
            scene.requestRender?.();publish();
        }
        // Idle display cuts only small *synthetic* portal approaches, not an
        // entire artificial trench through the mountain. During an explicit
        // simulated fly-through, clip the full synthetic corridor to allow
        // interior rendering below the loaded terrain surface.
        function cutFor(next, full){
            if(next.kind==='georeferenced-trimesh'){
                const polygons=full?next.flightClips:next.previewClips;
                if(!polygons.length)return null;
                return new C.ClippingPolygonCollection({polygons:polygons.map(points=>
                    new C.ClippingPolygon({positions:points.map(p=>C.Cartesian3.fromDegrees(p[0],p[1],0))}))});
            }
            const sections=rings(next),left=sections.map(p=>p[0]),right=sections.map(p=>p[1]);
            const polygon=positions=>new C.ClippingPolygon({positions:positions.map(p=>
                C.Cartesian3.fromDegrees(...p))});
            if(full)return new C.ClippingPolygonCollection({polygons:[polygon([...left,...right.slice().reverse()])]});
            const approach=(a,b)=>{
                const lengthMeters=length(next.sections[a],next.sections[b]);
                const t=Math.min(1,12/lengthMeters);
                const mid=(x,y)=>x.map((value,index)=>value+(y[index]-value)*t);
                return polygon([left[a],right[a],mid(right[a],right[b]),mid(left[a],left[b])]);
            };
            const last=sections.length-1;
            return new C.ClippingPolygonCollection({polygons:[approach(0,1),approach(last,last-1)]});
        }
        function show(next){
            if(disposed)throw Error('Tunnel renderer is disposed.');
            const needsClipping=next.kind!=='georeferenced-trimesh'||next.previewClips.length>0;
            if(needsClipping&&(!C.ClippingPolygonCollection?.isSupported?.(scene)||!C.ClippingPolygon||
                !('clippingPolygons' in scene.globe)))
                throw Error('WebGL2 terrain clipping is not supported on this device.');
            if(needsClipping&&scene.globe.clippingPolygons?.length>0)
                throw Error('Another terrain clipping layer owns the globe.');
            const cut=needsClipping?cutFor(next,false):null;
            const geom=geometry(C,next);
            const instance=new C.GeometryInstance({geometry:geom,attributes:{color:C.ColorGeometryInstanceAttribute.fromColor(
                C.Color.fromBytes(75,120,133,255))}});
            const mesh=new C.Primitive({geometryInstances:instance,appearance:new C.PerInstanceColorAppearance({flat:true,
                translucent:false,closed:false}),asynchronous:false,allowPicking:false});
            const previous=scene.globe.clippingPolygons;
            try {if(cut)scene.globe.clippingPolygons=cut;scene.primitives.add(mesh);}
            catch(err){if(cut)scene.globe.clippingPolygons=previous;throw err;}
            oldClipping=cut?previous:null;clipping=cut;primitive=mesh;model=next;flight=false;
            scene.requestRender?.();publish();return {ready:true,quality:model.quality,modelLabel:model.label,
                sections:model.sections?.length??0,visualTriangles:model.visualMesh?.triangles.length??null,
                collisionTriangles:model.collisionGeometry?.triangles.length??null,
                canFly:model.kind!=='georeferenced-trimesh'||model.canFly,
                portalsVerified:false,clearanceVerified:false};
        }
        async function prepare(route,settings={},signal){
            if(disposed)throw Error('Tunnel renderer disposed.');
            stop();const token=revision;pending=true;publish();
            try {
                if(!ready())throw Error('Detailed terrain is unavailable.');
                if(!route?.coordinates)throw Error('Select an available tunnel axis first.');
                const points=route.coordinates.map(p=>({longitude:p[0],latitude:p[1]}));
                if(points.length>MAX_SECTIONS)throw Error('Route too detailed for a bounded model.');
                signal?.throwIfAborted?.();
                const heights=await sampleTerrain(points,signal);
                signal?.throwIfAborted?.();
                if(token!==revision||disposed)throw Error('Tunnel preparation superseded.');
                const next=procedural(route,heights,settings);
                return show(next);
            } catch(err){if(token===revision){pending=false;publish(String(err.message||err));}throw err;}
            finally{if(token===revision){pending=false;publish();}}
        }
        function importModel(doc){
            const next=doc?.version===2?importGeoreferencedMesh(doc):importSections(doc);
            stop();return show(next);
        }
        function firstPose(){
            if(!model)throw Error('Prepare a supported model before flying.');
            if(model.kind==='georeferenced-trimesh'){
                if(!model.canFly)throw Error('Mesh flight needs an explicit pose, floor profile and terrain clipping.');
                return {...model.entryPose};
            }
            const a=model.sections[0],b=model.sections[1],ahead=xy(b,a);
            return {latitude:a.latitude,longitude:a.longitude,height:a.floorMetersWgs84+model.sections[0].heightMeters*.5,
                heading:Math.atan2(ahead.x,ahead.y),pitch:0,ground:a.floorMetersWgs84};
        }
        function activate(){
            if(!model)throw Error('Tunnel model missing.');
            if(model.kind==='georeferenced-trimesh'&&!model.canFly)
                throw Error('Mesh flight needs an explicit pose, floor profile and terrain clipping.');
            if(model.kind!=='georeferenced-trimesh'&&!clipping)
                throw Error('Tunnel terrain clipping unavailable.');
            if(!C.ClippingPolygonCollection?.isSupported?.(scene)||!C.ClippingPolygon)
                throw Error('Terrain clipping unavailable for tunnel flight.');
            if(!clipping&&scene.globe.clippingPolygons?.length>0)
                throw Error('Another terrain clipping layer owns the globe.');
            // The source explicitly supplies clipping geometry for external meshes.
            const next=cutFor(model,true);
            if(!next)throw Error('Explicit tunnel flight clipping is missing.');
            if(!clipping)oldClipping=scene.globe.clippingPolygons;
            scene.globe.clippingPolygons=next;
            clipping=next;flight=true;scene.requestRender?.();publish();
        }
        function floorAt(point){if(!flight||!model||!model.sections)return null;
            const near=closest(model,{...point,height:point.height??0});
            if(!near||near.distance>near.width/2+.5)return null;return near.floor;}
        function setCollisionEnabled(value){
            if(typeof value!=='boolean')throw Error('Invalid tunnel mesh collision preference');
            collisionEnabled=!disposed&&value;return {enabled:collisionEnabled};
        }
        function intersects(a,b){return (flight||collisionEnabled)&&model?collision(model,a,b):false;}
        return {prepare,importModel,firstPose,activate,floorAt,intersects,setCollisionEnabled,
            get flight(){return flight;},get model(){return model;},stop,
            dispose(){if(disposed)return;stop();disposed=true;},status(){return {ready:!!model,flight,pending,
                collisionEnabled,quality:model?.quality??null};}};
    }
    return {procedural,importSections,importGeoreferencedMesh,validateSections,validateTriMesh,
        closest,inside,collision,collisionMesh,rings,geometry,create,MAX_SECTIONS,MAX_LENGTH,
        MAX_MESH_VERTICES,MAX_MESH_TRIANGLES};
});

/* Issue #113: infrastructure-aware advisory geometry checks.
 * swisstopo 3D Tiles are rendered independently; their presence does not
 * expose surveyed collision meshes or prove that every bridge is assessed.
 * External cross-section input is NEVER promoted to verified status merely
 * because its metadata claims to be surveyed. */
(function (root, factory) {
    const tunnel = typeof module === 'object' && module.exports
        ? module.exports.FPVTunnelFlythrough : root.FPVTunnelFlythrough;
    const api = factory(tunnel);
    if (typeof module === 'object' && module.exports) module.exports.FPVInfrastructureClearance = api;
    else root.FPVInfrastructureClearance = api;
})(typeof globalThis !== 'undefined' ? globalThis : this, function (tunnel) {
    'use strict';
    const R = 6378137, DEG = Math.PI / 180;
    const MAX_SURFACES = 48, MAX_SECTIONS = 24, MAX_ROUTE = 512, MAX_PROBES = 1024;
    const finite = Number.isFinite;
    const clamp = (value, low, high) => Math.max(low, Math.min(high, value));
    function distance(a, b) {
        const lat = (a.latitude + b.latitude) / 2 * DEG;
        return Math.hypot((b.longitude - a.longitude) * DEG * R * Math.cos(lat),
            (b.latitude - a.latitude) * DEG * R);
    }
    function local(point, origin) {
        return {x: (point.longitude - origin.longitude) * DEG * R * Math.cos(origin.latitude * DEG),
            y: (point.latitude - origin.latitude) * DEG * R};
    }
    function validateDocument(document) {
        if (!document || document.version !== 1 || document.elevationReference !== 'WGS84_ELLIPSOID' ||
            typeof document.source !== 'string' || !document.source.trim() || document.source.length > 240 ||
            !Array.isArray(document.surfaces) || document.surfaces.length > MAX_SURFACES)
            throw Error('A bounded source and WGS84-ellipsoid infrastructure document are required.');
        const seen = new Set(), quality = ['surveyed', 'derived', 'approximate', 'unknown'];
        const surfaces = document.surfaces.map((raw, index) => {
            if (!raw || !['deck', 'support'].includes(raw.kind) || typeof raw.id !== 'string' ||
                !/^[a-zA-Z0-9_:.\-]{1,80}$/.test(raw.id) || seen.has(raw.id))
                throw Error('Invalid or duplicated infrastructure surface ID.');
            seen.add(raw.id);
            if (!finite(raw.bottomMetersWgs84) || !finite(raw.topMetersWgs84) ||
                raw.topMetersWgs84 <= raw.bottomMetersWgs84 ||
                raw.bottomMetersWgs84 < -500 || raw.topMetersWgs84 > 9000)
                throw Error('Surface heights must be explicit WGS84-ellipsoid meters.');
            const points = raw.kind === 'deck' ? raw.centerline : [raw.center];
            if (!Array.isArray(points) || points.length < (raw.kind === 'deck' ? 2 : 1) ||
                points.length > MAX_SECTIONS || !points.every(p => p && finite(p.longitude) && finite(p.latitude) &&
                p.longitude >= 5.8 && p.longitude <= 10.7 && p.latitude >= 45.6 && p.latitude <= 47.9))
                throw Error('Invalid Swiss geographic geometry.');
            const width = raw.kind === 'deck' ? raw.widthMeters : raw.radiusMeters * 2;
            if (!finite(width) || width < .2 || width > 80 ||
                (raw.kind === 'deck' && points.some((p, i) => i > 0 &&
                    (distance(points[i - 1], p) < .5 || distance(points[i - 1], p) > 200))))
                throw Error('Surface dimensions or geometry exceed budget.');
            return Object.freeze({id: raw.id, kind: raw.kind,
                name: typeof raw.name === 'string' ? raw.name.slice(0, 100) : `Surface ${index + 1}`,
                bottomMetersWgs84: raw.bottomMetersWgs84, topMetersWgs84: raw.topMetersWgs84,
                widthMeters: width, centerline: points.map(p => ({longitude: p.longitude, latitude: p.latitude})),
                // A local import cannot independently certify surveyed accuracy.
                quality: 'external-unverified', claimedQuality: quality.includes(raw.quality) ? raw.quality : 'unknown',
                source: document.source.slice(0, 240), sourceId: String(raw.sourceId ?? raw.id).slice(0, 100)});
        });
        return Object.freeze({source: document.source, quality: 'external-unverified', surfaces});
    }
    function corridor(point, surface) {
        let best = Infinity;
        const line = surface.centerline;
        for (let i = 1; i < line.length; i++) {
            const origin = line[i - 1], a = {x: 0, y: 0}, b = local(line[i], origin), p = local(point, origin);
            const len2 = b.x * b.x + b.y * b.y;
            const t = len2 > 0 ? clamp((p.x * b.x + p.y * b.y) / len2, 0, 1) : 0;
            best = Math.min(best, Math.hypot(p.x - (a.x + b.x * t), p.y - (a.y + b.y * t)));
        }
        if (surface.kind === 'support') best = distance(point, line[0]);
        return best;
    }
    function surfaceClearance(point, surface, radius) {
        if (!point || !finite(point.height)) return null;
        const horizontal = Math.max(0, corridor(point, surface) - surface.widthMeters / 2);
        const vertical = point.height < surface.bottomMetersWgs84 ? surface.bottomMetersWgs84 - point.height :
            point.height > surface.topMetersWgs84 ? point.height - surface.topMetersWgs84 : 0;
        const outside = Math.hypot(horizontal, vertical);
        // If the drone centre is inside the represented volume, negative
        // clearance is an overlap. Otherwise subtract its bounding radius.
        return horizontal === 0 && vertical === 0 ? -radius : outside - radius;
    }
    function tunnelClearance(point, model, radius) {
        if (!model?.sections || !tunnel || !finite(point.height)) return null;
        const near = tunnel.closest(model, point);
        if (!near) return null;
        // Only report contact/near-contact within the displayed model's
        // footprint, not an imaginary nationwide tunnel obstacle.
        if (near.distance > near.width / 2 + 2 + radius ||
            point.height < near.floor - 2 - radius ||
            point.height > near.floor + near.height + 2 + radius) return null;
        const wall = near.width / 2 - near.distance;
        const floor = point.height - near.floor;
        const ceiling = near.floor + near.height - point.height;
        const clearance = Math.min(wall, floor, ceiling) - radius;
        return clearance;
    }
    function analyse(input, surfaces = [], model = null, {radiusMeters = .25} = {}) {
        if (!input || !Array.isArray(input.samples) || input.samples.length < 2 ||
            input.samples.length > MAX_ROUTE || !finite(radiusMeters) || radiusMeters < .05 || radiusMeters > 2 ||
            input.samples.some(p => !p || !finite(p.latitude) || !finite(p.longitude) ||
                Math.abs(p.latitude) > 90 || Math.abs(p.longitude) > 180 ||
                (p.height !== null && p.height !== undefined && !finite(p.height)) ||
                !Number.isInteger(p.segment) || p.segment < 0 || p.segment > 1000))
            throw Error('Invalid or unbounded route clearance samples.');
        if (!Array.isArray(surfaces) || surfaces.length > MAX_SURFACES)
            throw Error('Unbounded infrastructure geometry.');
        const hits = new Map();
        let used = 0, unknown = 0, clipped = Boolean(input.truncated), assessed = 0;
        const samples = input.samples;
        outer: for (let i = 0; i < samples.length - 1; i++) {
            const a = samples[i], b = samples[i + 1], horizontal = distance(a, b);
            const count = Math.max(1, Math.ceil(horizontal / 2));
            for (let step = 0; step < count; step++) {
                if (++used > MAX_PROBES) {clipped = true; break outer;}
                const t = step / count;
                const point = {longitude: a.longitude + (b.longitude - a.longitude) * t,
                    latitude: a.latitude + (b.latitude - a.latitude) * t,
                    height: a.height == null || b.height == null ? null : a.height + (b.height - a.height) * t};
                if (point.height === null) {unknown++; continue;}
                for (const surface of surfaces) {
                    const clearance = surfaceClearance(point, surface, radiusMeters);
                    assessed++;
                    if (clearance > 2) continue;
                    const key = `${a.segment}:${surface.id}`;
                    const earlier = hits.get(key);
                    if (!earlier || clearance < earlier.clearanceMeters) hits.set(key, {
                        segment: a.segment, kind: surface.kind, id: surface.id, name: surface.name,
                        source: surface.source, sourceId: surface.sourceId, quality: surface.quality,
                        claimedQuality: surface.claimedQuality,
                        clearanceMeters: clearance, status: clearance <= 0 ? 'model-contact' : 'near-model'});
                }
                const tunnelMargin = tunnelClearance(point, model, radiusMeters);
                if (tunnelMargin !== null && tunnelMargin <= 2) {
                    assessed++;
                    const key = `${a.segment}:tunnel`;
                    const earlier = hits.get(key);
                    if (!earlier || tunnelMargin < earlier.clearanceMeters) hits.set(key, {
                        segment: a.segment, kind: 'tunnel', id: String(model.identity || 'tunnel'),
                        name: 'Modeled tunnel interior', source: String(model.source || 'local'),
                        sourceId: String(model.sourceId || ''), quality: model.quality || 'unknown',
                        claimedQuality: 'unknown', clearanceMeters: tunnelMargin,
                        status: tunnelMargin <= 0 ? 'model-contact' : 'near-model'});
                }
            }
        }
        if (used < MAX_PROBES) {
            const last = samples.at(-1);
            if (last.height == null) unknown++;
        }
        const findings = [...hits.values()].sort((a, b) => a.segment - b.segment || a.clearanceMeters - b.clearanceMeters);
        if (findings.length > 80) clipped = true;
        return {findings: findings.slice(0, 80), checkedSamples: Math.min(used, MAX_PROBES),
            unknownHeightSamples: unknown, modelCount: surfaces.length + (model ? 1 : 0),
            incomplete: true, processingLimited: clipped, // Published 3D Tiles are NOT fully surveyed for collisions.
            coverage: surfaces.length || model ? 'local-models-only' : 'unassessed',
            message: 'No nationwide or complete bridge underside coverage; 3D Tiles visualisation does not establish obstacle clearance.',
            assessedComparisons: assessed};
    }
    function create(C, viewer, getTunnelModel = () => null) {
        let surfaces = [], source = null, visual = null, visible = false, report = null, route = null, disposed = false;
        let retainedTunnel = null;
        const scene = viewer.scene;
        function clearVisual() {
            if (visual) {visual.forEach(v => viewer.entities.remove(v));visual = null;}
            scene.requestRender?.();
        }
        function render() {
            clearVisual();
            if (!visible || !report || !route || !C || !viewer.entities) return;
            visual = [];
            const escape = value => String(value).replace(/[&<>"']/g, c => ({
                '&':'&amp;', '<':'&lt;', '>':'&gt;', '"':'&quot;', "'":'&#39;'
            }[c]));
            for (const hit of report.findings.slice(0, 80)) {
                const i = route.findIndex(p => p.segment === hit.segment);
                if (i < 0 || !route[i] || !route[i + 1]) continue;
                const a = route[i], b = route[i + 1];
                if (a.height == null || b.height == null) continue;
                visual.push(viewer.entities.add({name: `Infrastructure advisory: ${hit.name}`,
                    description: `${escape(hit.status)}; ${escape(hit.quality)}. NOT proof of clearance. Source: ${escape(hit.source)} / ${escape(hit.sourceId)}`,
                    polyline: {positions: C.Cartesian3.fromDegreesArrayHeights([
                        a.longitude, a.latitude, a.height, b.longitude, b.latitude, b.height]),
                        width: 5, material: hit.clearanceMeters <= 0 ? C.Color.RED : C.Color.ORANGE}}));
            }
            scene.requestRender?.();
        }
        function replace(document) {
            if (disposed) throw Error('Infrastructure renderer disposed.');
            const next = validateDocument(document);
            surfaces = next.surfaces;source = next.source;report = null;route = null;clearVisual();
            return {count: surfaces.length, quality: next.quality, source};
        }
        function assess(input) {
            if (disposed) throw Error('Infrastructure renderer disposed.');
            route = input.samples;
            report = analyse(input, surfaces, getTunnelModel() ?? retainedTunnel, {radiusMeters: input.radiusMeters});
            render();return report;
        }
        function setVisible(value) {
            if (typeof value !== 'boolean') throw Error('Expected infrastructure clearance visibility');
            if (disposed) return {};
            visible = value;render();return {visible};
        }
        let collisionEnabled = false;
        function setCollisionEnabled(value) {
            if (typeof value !== 'boolean') throw Error('Invalid infrastructure collision preference');
            collisionEnabled = !disposed && value;
            return {enabled:collisionEnabled};
        }
        function collision(a, b, radius = .25) {
            if (disposed || !(visible || collisionEnabled) || !surfaces.length || !a || !b) return false;
            const probes = Math.min(32, Math.max(1, Math.ceil(distance(a, b) / .25)));
            for (let i = 0; i <= probes; i++) {
                const t = i / probes, point = {latitude: a.latitude + (b.latitude - a.latitude) * t,
                    longitude: a.longitude + (b.longitude - a.longitude) * t,
                    height: a.height + (b.height - a.height) * t};
                if (surfaces.some(s => surfaceClearance(point, s, radius) <= 0)) return true;
            }
            return false;
        }
        function retainTunnel(model) {
            if (disposed) throw Error('Renderer disposed.');
            if (!model || (!Array.isArray(model.sections) &&
                    model.kind !== 'georeferenced-trimesh') ||
                (model.sections?.length??0)>96 || !model.quality ||
                model.clearanceVerified === true) {
                throw Error('Unsupported or independently unverified tunnel geometry.');
            }
            // Retain for route *analysis* after the route editor releases its
            // clipping mesh. Does not enable physical fly-through or terrain clipping.
            retainedTunnel = model;
            report = route = null;clearVisual();
        }
        function forgetTunnel() {retainedTunnel = null; report = route = null;clearVisual();}
        return {replace, assess, setVisible, setCollisionEnabled, collision, retainTunnel, forgetTunnel,
            hasUnverifiedTunnel: () => !!(getTunnelModel() ?? retainedTunnel),
            status: () => ({surfaceCount: surfaces.length, source, visible, hasReport: !!report,
                retainedTunnel: !!retainedTunnel}),
            dispose() {if (disposed) return;clearVisual();surfaces = [];retainedTunnel = null;
                report = route = null;disposed = true;}};
    }
    return {validateDocument, surfaceClearance, tunnelClearance, analyse, create,
        MAX_SURFACES, MAX_ROUTE, MAX_PROBES};
});

/* Opt-in, conservative scene-surface collision for the FPV SIMULATOR only.
 * Cesium sampleHeight is the highest currently rendered surface, not a 3D
 * collision mesh. Hidden/unloaded tiles and bridge undersides are UNKNOWN.
 * Never use these results as physical flight clearance. */
(function(root,factory){
    const api=factory();
    if(typeof module==='object'&&module.exports)module.exports.FPVSceneModelCollision=api;
    else root.FPVSceneModelCollision=api;
})(typeof globalThis!=='undefined'?globalThis:this,function(){
    'use strict';
    function create(C,viewer,{hasVisibleModels=()=>false}={}){
        const scene=viewer.scene;
        let enabled=false,disposed=false;
        function setEnabled(value){
            if(typeof value!=='boolean')throw Error('Invalid 3D collision preference');
            if(!disposed)enabled=value;
            return {enabled};
        }
        function collision(from,to,radius=.25){
            if(disposed||!enabled||!hasVisibleModels()||!scene.sampleHeightSupported||
                typeof scene.sampleHeight!=='function'||typeof scene.globe?.getHeight!=='function'||
                !C.Cartographic?.fromDegrees||!Number.isFinite(radius)||radius<0||radius>1 ||
                !from||!to||![from.latitude,from.longitude,from.height,to.latitude,to.longitude,to.height].every(Number.isFinite))return false;
            if(C.SceneMode&&scene.mode!==C.SceneMode.SCENE3D)return false;
            const distance=Math.hypot((to.longitude-from.longitude)*75000,
                (to.latitude-from.latitude)*111000,to.height-from.height);
            // Work strictly with the loaded scene and at most five bounded
            // samples per simulation frame. No implicit extra 3D tile fetching.
            if(distance>15)return false;
            const probes=Math.min(4,Math.max(1,Math.ceil(distance)));
            try {
                for(let i=0;i<=probes;i++){
                    const t=i/probes, point=C.Cartographic.fromDegrees(
                        from.longitude+(to.longitude-from.longitude)*t,
                        from.latitude+(to.latitude-from.latitude)*t);
                    const top=scene.sampleHeight(point,undefined,.5);
                    const ground=scene.globe.getHeight(point);
                    const elevation=from.height+(to.height-from.height)*t;
                    // Suppress bare terrain hits and elevations significantly
                    // below the model surface: scene height cannot distinguish
                    // a bridge underside from open air underneath the deck.
                    if(Number.isFinite(top)&&Number.isFinite(ground)&&top-ground>2&&
                        Math.abs(elevation-top)<=Math.max(radius, .35))return 'model';
                }
            }catch(_){return false;} // Device without usable depth texture.
            return false;
        }
        return {setEnabled,collision,dispose(){enabled=false;disposed=true;},status(){return {enabled};}};
    }
    return {create};
});
