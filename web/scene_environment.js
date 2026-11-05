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
                send('infrastructure-selected',{kind:'structure',source:'ch.swisstopo.swisstlm3d.3d',
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
        isTerrainReady = () => true} = {}) {
        let disposed = false, visible = false, allowed = false, items = [], active = null, opacity = .85;
        let requestController = null, revision = 0, lastRequestAt = -Infinity;
        let dataSource = null, removeFrame = null, pending = false;
        const scene = viewer.scene, camera = viewer.camera;
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
        function set({routesVisible, explorationAllowed, opacity:nextOpacity = opacity} = {}) {
            if (typeof routesVisible !== 'boolean' || typeof explorationAllowed !== 'boolean')
                throw Error('Invalid tunnel settings');
            if(!Number.isFinite(nextOpacity)||nextOpacity<.2||nextOpacity>1)throw Error('Invalid tunnel opacity');
            if (disposed) return {};
            if (!routesVisible || !explorationAllowed) stop();
            if (!routesVisible) clear();
            visible = routesVisible; allowed = explorationAllowed; opacity = nextOpacity;
            draw();return {visible, explorationAllowed:allowed, count:items.length};
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
                source:route.source,sourceId:route.sourceId,portalsVerified:false,heightReference:'unavailable'});
            return true;
        }
        return {set,scan,focus,explore,stop,pick,
            dispose(){if(disposed)return;clear();disposed=true;},
            status(){return {visible,allowed,pending,count:items.length,exploring:!!active};}};
    }
    return {ENDPOINT,LAYERS,BOUNDS,category,bounds,urlFor,parseIdentify,create};
});
