const test = require('node:test');
const assert = require('node:assert/strict');
const T = require('../../web/scene_environment.js').FPVTunnelInfrastructure;
const tick = () => new Promise(r => setImmediate(r));
const road = (n, coords = [[8.3,46.9],[8.3001,46.9001]]) => ({
    type:'Feature',featureId:String(n),geometry:{type:'LineString',coordinates:coords},
    properties:{KUNSTBAUTE:n===1?1000:1100,STRASSENNAME:`Tunnel ${n}`},
});
function fixture({respond=()=>({results:[]}), time=()=>2000, getHeight=()=>500, automaticFixture=false, onRoutes=()=>{}, osmFallback=false, requestTimeoutMs=7000, fetcherOverride=null}={}){
    const events=[], requested=[], drawn=[], positions=[], listeners=new Set(), autoTimers=new Map();
    let nextAutoTimer=0;let cameraLongitude=8.3, cameraLatitude=46.9;
    const moveListeners=new Set();
    const camera={position:{x:1},positionCartographic:{height:500},heading:.3,pitch:-.4,roll:0,
        setView:p=>positions.push(p)};
    if(automaticFixture){
        camera.moveEnd={addEventListener:fn=>{moveListeners.add(fn);return ()=>moveListeners.delete(fn)}};
        camera.getPickRay=()=>({cameraCenter:true});
    }
    const C={
        CustomDataSource:class{constructor(name){this.name=name;this.entities={items:[],add:i=>this.entities.items.push(i)};}},
        Cartesian3:{fromDegreesArray:a=>a,fromDegrees:(lon,lat,h)=>({lon,lat,h}),clone:p=>({...p})},
        Cartographic:{fromDegrees:(lon,lat)=>({lon,lat}),fromCartesian:()=>({longitude:cameraLongitude,latitude:cameraLatitude})},
        Cartesian2:class{constructor(x,y){this.x=x;this.y=y}},Math:{toDegrees:value=>value},
        Color:{ORANGE:'orange'},PolylineDashMaterialProperty:class{constructor(o){this.options=o}},
    };
    const viewer={camera,canvas:{clientWidth:800,clientHeight:600},dataSources:{add:d=>drawn.push(d),remove:d=>{const i=drawn.indexOf(d);if(i>=0)drawn.splice(i,1);}},
        scene:{globe:{getHeight,pick:()=>({x:1})},requestRender(){},preRender:{addEventListener(cb){listeners.add(cb);return()=>listeners.delete(cb)}}}};
    const fetcher=async(url,options)=>{
        requested.push({url,options});
        if(fetcherOverride)return await fetcherOverride(url,options);
        const reply=respond(new URL(url).searchParams.get('layers'),url);
        return {ok:true,status:200,headers:{get:()=>null},
            text:async()=>JSON.stringify(reply)};
    };
    const module=T.create(C,viewer,(type,data)=>events.push({type,...data}),{fetcher,onRoutes,now:time,isTerrainReady:()=>true,requestTimeoutMs,
        setTimer:automaticFixture?(fn)=>{const id=++nextAutoTimer;autoTimers.set(id,fn);return id;}:setTimeout,
        clearTimer:automaticFixture?(id)=>autoTimers.delete(id):clearTimeout,osmFallback});
    return {module,C,viewer,events,requested,drawn,positions,listeners,autoTimers,moveListeners,
        moveCenter(lon,lat){cameraLongitude=lon;cameraLatitude=lat},
        runAutoTimer(){const tasks=[...autoTimers.values()];autoTimers.clear();tasks.forEach(fn=>fn())}};
}
test('official object codes and line features preserve provenance without inventing tunnel portals or heights',()=>{
    assert.equal(T.category(1000),'tunnel');assert.equal(T.category('Tunnel'),'tunnel');
    assert.equal(T.category(1100),'underpass');assert.equal(T.category(1200),'underpass');
    assert.equal(T.category(200),null);assert.equal(T.category(1000,'railway'),null);
    assert.equal(T.category('Tunnel','railway'),'tunnel');
    assert.throws(()=>T.bounds(8,46.8,5000));assert.throws(()=>T.bounds(17,46.8));
    const b=T.bounds(8.3,46.9,600), url=T.urlFor(b,'road');
    assert.match(url,/swisstlm3d-strassen/);assert.match(url,/geometryFormat=geojson/);
    assert.equal(new URL(url).searchParams.get('sr'),'4326');
    assert.throws(()=>T.urlFor(b,'guess'));
    const feature=T.parseIdentify({results:[road(1),road(2),road(3)]},'road');
    assert.equal(feature.routes.length,3);assert.equal(feature.routes[0].kind,'tunnel');
    assert.equal(feature.routes[1].kind,'underpass');
    assert.equal(feature.routes[0].heightReference,'unavailable');
    assert.equal(feature.routes[0].endpointsVerified,false);
    assert.equal(feature.routes[0].source,T.LAYERS.road);
});
test('unknown, invalid and incomplete geometry is not converted into fake 3D infrastructure',()=>{
    const invalid=road(1,[[3000000,1200000],[3000001,1200001]]);
    const good=road(2);
    const unknown=road(1);unknown.properties.KUNSTBAUTE=999998;
    const outcome=T.parseIdentify({results:[invalid,good,unknown]});
    assert.equal(outcome.routes.length,1);assert.equal(outcome.incomplete,true);
    assert.throws(()=>T.parseIdentify({results:new Array(201).fill(good)}));
    assert.equal(T.parseIdentify({results:[{featureId:1,properties:{KUNSTBAUTE:1000},geometry:null}]}).incomplete,true);
});
test('manual bounded search builds labelled schematic lines, focuses endpoints, and cleans resources',async()=>{
    const f=fixture({respond:layer=>({results:layer.includes('strassen')?[road(1),road(2)]:[]})});
    f.module.set({routesVisible:true,explorationAllowed:true});
    const result=await f.module.scan({longitude:8.3,latitude:46.9});
    assert.equal(result.count,2);assert.equal(f.requested.length,2);
    assert.equal(result.routes[0].source,T.LAYERS.road);
    assert.equal(f.drawn.length,1);
    assert.equal(f.drawn[0].entities.items.length,6);
    assert.match(f.drawn[0].entities.items[1].name,/NOT verified portal/);
    assert.equal(f.drawn[0].entities.items[0].polyline.clampToGround,true);
    assert.match(f.drawn[0].entities.items[0].description,/Schematic surface/);
    assert.equal(f.module.pick({id:`fpv-tunnel-${result.routes[0].id}`}),true);
    assert.equal(f.events.at(-1).portalsVerified,false);
    f.module.focus({routeId:result.routes[0].id});
    assert.equal(f.positions.at(-1).destination.h,506);
    const state=f.module.explore({routeId:result.routes[0].id});
    assert.equal(state.mode,'schematic-surface');assert.equal(f.listeners.size,1);
    f.module.stop();assert.equal(f.listeners.size,0);
    assert.equal(f.positions.at(-1).destination.x,1,'restores original camera');
    f.module.set({routesVisible:false,explorationAllowed:false});
    assert.equal(f.drawn.length,0);assert.equal(f.module.status().count,0);
    f.module.dispose();
});
test('no support for tunneled flying with absent terrain, failed services, or disabled user consent',async()=>{
    const f=fixture({respond:()=>({results:[road(1)]}),getHeight:()=>undefined});
    await assert.rejects(f.module.scan({longitude:8.3,latitude:46.9}),/Enable tunnel/);
    f.module.set({routesVisible:true,explorationAllowed:false});
    const result=await f.module.scan({longitude:8.3,latitude:46.9});
    assert.throws(()=>f.module.explore({routeId:result.routes[0].id}),/Enable/);
    f.module.set({routesVisible:true,explorationAllowed:true});
    assert.throws(()=>f.module.focus({routeId:result.routes[0].id}),/Terrain elevation missing/);
    assert.throws(()=>f.module.explore({routeId:result.routes[0].id}),/Terrain elevation missing/);
    assert.equal(f.listeners.size,0);f.module.dispose();
});
test('stale responses are discarded and disposal aborts fetches',async()=>{
    let signal=null,resolve;
    const C={CustomDataSource:class{},Cartesian3:{},Cartographic:{}};
    const camera={};
    const viewer={camera,scene:{requestRender(){}},dataSources:{remove(){}}};
    const m=T.create(C,viewer,()=>{},{now:()=>2000,fetcher:(_url,{signal:s})=>{
        signal=s;return new Promise(r=>resolve=r);
    }});
    m.set({routesVisible:true,explorationAllowed:false});
    const pending=m.scan({longitude:8.3,latitude:46.9});
    await tick();assert.equal(signal.aborted,false);
    m.dispose();assert.equal(signal.aborted,true);
    resolve({ok:true,status:200,headers:{get:()=>null},text:async()=>JSON.stringify({results:[road(1)]})});
    await assert.rejects(pending);
});
test('official service failure and incomplete coverage never create false no-tunnel claims',async()=>{
    const f=fixture({respond:layer=>({results:layer.includes('strassen')?new Array(200).fill(0).map((_,i)=>road(i+100)):[]})});
    f.module.set({routesVisible:true,explorationAllowed:false});
    const result=await f.module.scan({longitude:8.3,latitude:46.9});
    assert.equal(result.incomplete,true);assert.ok(result.count<=160);
    f.module.dispose();
});

test('automatic 3D tunnel discovery scans only nearby Swiss terrain after camera idle', async()=>{
    let timestamp=30000;
    const p=fixture({automaticFixture:true,time:()=>timestamp,
        respond:layer=>({results:layer.includes('strassen')?[road(1)]:[]})});
    assert.equal(p.module.status().visible,false);
    p.module.setAutomatic(true);
    assert.equal(p.module.status().automatic,true);
    assert.equal(p.autoTimers.size,1,'deferred camera-idle discovery');
    p.runAutoTimer();await tick();await tick();
    assert.equal(p.requested.length,2,'one bounded request per road/railway layer');
    assert.equal(p.drawn.length,0,'automatic discovery does not force the separate line overlay on');
    assert.equal(p.events.at(-1).type,'tunnel-auto-status');
    assert.equal(p.events.at(-1).state,'ready');
    assert.equal(p.events.at(-1).count,1);
    assert.equal(p.module.status().count,1,'the discovered axis remains available for 3D meshes');
    assert.equal(p.module.status().visible,true);
    // No requery when merely panning a few metres within the same area.
    timestamp+=25000;
    p.viewer.camera.moveEnd.addEventListener(()=>{})(); // registration lifecycle
    for(const notify of p.moveListeners)notify();
    p.runAutoTimer();await tick();
    assert.equal(p.requested.length,2);
    p.moveCenter(8.34,46.91);
    for(const notify of p.moveListeners)notify();
    p.runAutoTimer();await tick();await tick();
    assert.equal(p.requested.length,4,'new nearby area triggers bounded refresh');
    p.module.setAutomatic(false);
    assert.equal(p.module.status().visible,false);
    assert.equal(p.drawn.length,0);
    p.module.dispose();assert.equal(p.moveListeners.size,0);
});

test('disabling tunnel centerline overlay removes all lines while keeping automatic 3D discovery alive',async()=>{
    const f=fixture({respond:layer=>({results:layer.includes('strassen')?[road(1)]:[]})});
    f.module.set({routesVisible:true,explorationAllowed:false});
    f.module.setAutomatic(true);
    await f.module.scan({longitude:8.3,latitude:46.9});
    assert.equal(f.drawn.length,1);
    assert.equal(f.drawn[0].entities.items.length,3);
    const count=f.module.status().count,fetches=f.requested.length;

    f.module.set({routesVisible:false,explorationAllowed:false});
    assert.equal(f.drawn.length,0,'disabling the centerlines removes their Cesium data source');
    assert.equal(f.module.status().automatic,true,'3D discovery remains enabled');
    assert.equal(f.module.status().count,count,'3D mesh source routes are retained');
    assert.equal(f.module.snapshot().routes.length,count);

    await f.module.scan({longitude:8.3,latitude:46.9});
    assert.equal(f.drawn.length,0,'cached scan cannot resurrect a hidden centerline overlay');
    assert.equal(f.requested.length,fetches,'cached routes are reused');

    f.module.set({routesVisible:true,explorationAllowed:false});
    assert.equal(f.drawn.length,1,'line overlay reuses existing routes when reenabled');
    assert.equal(f.requested.length,fetches);
    f.module.set({routesVisible:false,explorationAllowed:false});
    assert.equal(f.drawn.length,0);
    f.module.setAutomatic(false);
    assert.equal(f.module.status().visible,false);
    f.module.dispose();
});

test('manual tunnel layer remains visible after automatic infrastructure is disabled',()=>{
    const p=fixture({automaticFixture:true});
    p.module.set({routesVisible:true,explorationAllowed:false});
    p.module.setAutomatic(true);
    p.module.setAutomatic(false);
    assert.equal(p.module.status().visible,true);
    p.module.set({routesVisible:false,explorationAllowed:false});
    assert.equal(p.module.status().visible,false);
    p.module.dispose();
});

test('automatic search never invents data when terrain, camera or network is unavailable',()=>{
    const p=fixture({automaticFixture:true});
    p.viewer.camera.positionCartographic.height=12000;
    p.module.setAutomatic(true);p.runAutoTimer();
    assert.equal(p.requested.length,0);
    p.module.setAutomatic(false);
    assert.equal(p.autoTimers.size,0);
    p.module.dispose();
});


test('automatic official route scan publishes selectable provenance without requesting a user JSON file',async()=>{
    const updated=[];
    const f=fixture({respond:layer=>({results:layer.includes('strassen')?[road(1)]:[]}),
        onRoutes:(routes,center)=>updated.push({routes,center})});
    f.module.setAutomatic(true);
    const found=await f.module.scan({longitude:8.3,latitude:46.9});
    assert.equal(found.count,1);
    assert.equal(updated.length,1);
    assert.equal(updated[0].routes[0].source,T.LAYERS.road);
    const metadata=f.events.find(event=>event.type==='tunnel-routes-loaded');
    assert.equal(metadata.routes[0].source,T.LAYERS.road);
    assert.equal(metadata.routes[0].coordinates,undefined,'bridge event includes only bounded metadata');
    f.module.dispose();
});

test('empty official scan falls back to explicitly tagged OSM tunnel, without inventing portals',async()=>{
    const osmWay={type:'way',id:22189455,tags:{highway:'primary',tunnel:'yes',name:'OSM demo tunnel'},
        geometry:[{lon:8.3,lat:46.9},{lon:8.3002,lat:46.9001}]};
    const f=fixture({osmFallback:true,respond:layer=>layer?{results:[]}:{elements:[osmWay]}});
    f.module.setAutomatic(true);
    const result=await f.module.scan({longitude:8.3,latitude:46.9});
    assert.equal(result.count,1);
    assert.equal(f.requested.length,3,'two official requests, one bounded fallback');
    assert.equal(result.routes[0].source,'OpenStreetMap (Overpass fallback)');
    assert.equal(result.routes[0].endpointsVerified,false);
    assert.equal(result.routes[0].heightReference,'unavailable');
    const query=new URL(f.requested[2].url);
    assert.equal(query.origin,'https://overpass.private.coffee');
    assert.match(query.searchParams.get('data'),/tunnel/);
    f.module.dispose();
});
test('fallback ignores untagged streets, rejects malformed geometry and preserves OSM provenance',()=>{
    const elements=[
        {type:'way',id:1,tags:{highway:'residential'},geometry:[{lon:8.3,lat:46.9},{lon:8.301,lat:46.9}]},
        {type:'way',id:2,tags:{highway:'residential',covered:'yes'},geometry:[{lon:8.3,lat:46.9},{lon:8.301,lat:46.9}]},
        {type:'way',id:3,tags:{highway:'residential',tunnel:'yes'},geometry:[{lon:8.3,lat:46.9},{lon:40,lat:46.9}]},
    ];
    const parsed=T.parseOsm({elements});
    assert.equal(parsed.routes.length,1);assert.equal(parsed.incomplete,true);
    assert.equal(parsed.routes[0].kind,'underpass');
    assert.equal(parsed.routes[0].sourceId,'way/2');
    assert.throws(()=>T.parseOsm({results:[]}));
});

test('automatic tunnel snapshot can reuse scanned axes without an additional request',async()=>{
    const f=fixture({respond:layer=>({results:layer.includes('strassen')?[road(1)]:[]})});
    f.module.setAutomatic(true);
    await f.module.scan({longitude:8.3,latitude:46.9});
    const snapshot=f.module.snapshot();
    assert.equal(snapshot.routes.length,1);
    assert.equal(snapshot.routes[0].coordinates.length,2);
    snapshot.routes[0].coordinates[0][0]=99;
    assert.equal(f.module.snapshot().routes[0].coordinates[0][0],8.3,
        'snapshot is an independent, immutable-in-practice copy');
    assert.equal(f.requested.length,2,'turning on 3D can reuse this snapshot without another fetch');
    f.module.dispose();
});


test('automatic viewport discovery queries explicitly tagged tunnel ways before unfiltered official roads',async()=>{
    let time=60000;
    const way={type:'way',id:731,tags:{highway:'secondary',tunnel:'yes',name:'Tunnel in view'},
        geometry:[{lon:8.3001,lat:46.9001},{lon:8.3005,lat:46.9005}]};
    const f=fixture({automaticFixture:true,osmFallback:true,time:()=>time,
        respond:layer=>layer?{results:[]}:{elements:[way]}});
    f.viewer.camera.computeViewRectangle=()=>({west:8.296,south:46.898,east:8.305,north:46.903});
    f.module.setAutomatic(true);f.runAutoTimer();await tick();await tick();
    assert.equal(f.requested.length,1,'no unfiltered official identify call needed for tagged OSM data');
    assert.equal(new URL(f.requested[0].url).origin,'https://overpass.private.coffee');
    const query=new URL(f.requested[0].url).searchParams.get('data');
    assert.match(query,/46.898,8.296,46.903,8.305/,'viewport rectangle, not arbitrary center radius');
    assert.equal(f.module.status().count,1);
    assert.equal(f.events.at(-1).state,'ready');
    time+=20000;
    const cached=await f.module.scan({longitude:8.3,latitude:46.9,preferTagged:true,
        viewportBox:[8.296,46.898,8.305,46.903]});
    assert.equal(cached.fromCache,true);
    assert.equal(f.requested.length,1,'same viewport served from local memory');
    f.module.dispose();
});

test('automatic tunnel discovery tries backup Overpass instance after primary failure',async()=>{
    const way={type:'way',id:732,tags:{railway:'rail',tunnel:'yes'},
        geometry:[{lon:8.31,lat:46.91},{lon:8.311,lat:46.911}]};
    const f=fixture({osmFallback:true,respond:(layer,url)=>{
        if(url.startsWith(T.OSM_ENDPOINT))throw Error('HTTP 503');
        return layer?{results:[]}:{elements:[way]};
    }});
    f.module.setAutomatic(true);
    const response=await f.module.scan({longitude:8.31,latitude:46.91,preferTagged:true});
    assert.equal(response.count,1);
    assert.equal(f.requested.length,2);
    assert.equal(new URL(f.requested[1].url).origin,'https://overpass-api.de');
    assert.equal(response.routes[0].transport,'railway');
    f.module.dispose();
});

test('empty tagged and official responses do not claim a complete tunnel inventory',async()=>{
    const f=fixture({osmFallback:true,respond:layer=>layer?{results:[]}:{elements:[]}});
    f.module.setAutomatic(true);
    const response=await f.module.scan({longitude:8.3,latitude:46.9,preferTagged:true});
    assert.equal(response.count,0);assert.equal(response.incomplete,true);
    assert.equal(f.requested.length,3,'one tagged query then road and rail identify fallbacks');
    f.module.dispose();
});


test('timeout on primary Overpass endpoint does not abort backup search',async()=>{
    const way={type:'way',id:800,tags:{highway:'primary',tunnel:'yes'},
        geometry:[{lon:8.59,lat:46.64},{lon:8.5902,lat:46.6402}]};
    let primaryAborted=false;
    const f=fixture({osmFallback:true,requestTimeoutMs:20,fetcherOverride:(url,{signal})=>{
        if(url.startsWith(T.OSM_ENDPOINT))return new Promise((_resolve,reject)=>{
            signal.addEventListener('abort',()=>{
                primaryAborted=true;
                reject(new DOMException('signal is aborted without reason','AbortError'));
            },{once:true});
        });
        return Promise.resolve({ok:true,status:200,headers:{get:()=>null},
            text:async()=>JSON.stringify({elements:[way]})});
    }});
    f.module.setAutomatic(true);
    const result=await f.module.scan({longitude:8.59,latitude:46.64,preferTagged:true});
    assert.equal(primaryAborted,true);
    assert.equal(result.count,1);
    assert.equal(f.requested.length,2,'a timed-out primary does not block the backup');
    assert.equal(f.requested[1].options.signal.aborted,false);
    assert.equal(result.incomplete,true,'partial source failure must be reported');
    assert.match(result.failedLayers[0],/Timeout after 20 ms/);
    f.module.dispose();
});

test('exhausted source timeouts report failure rather than a false zero-tunnel result',async()=>{
    const f=fixture({osmFallback:true,requestTimeoutMs:10,fetcherOverride:(_url,{signal})=>
        new Promise((_resolve,reject)=>{
            signal.addEventListener('abort',()=>reject(new DOMException('signal is aborted without reason','AbortError')),{once:true});
        })});
    f.module.setAutomatic(true);
    await assert.rejects(f.module.scan({longitude:8.59,latitude:46.64,preferTagged:true}),
        /Tunnel sources unavailable:.*Timeout after 10 ms/);
    assert.equal(f.requested.length,4,'both Overpass and both official layers attempted');
    assert.equal(f.module.status().count,0);
    f.module.dispose();
});

test('camera movement while a tunnel request is pending schedules the next viewport',async()=>{
    let resolveFirst,first=true,timestamp=60000;
    const way={type:'way',id:901,tags:{highway:'residential',tunnel:'yes'},
        geometry:[{lon:8.3,lat:46.9},{lon:8.301,lat:46.901}]};
    const reply=()=>({ok:true,status:200,headers:{get:()=>null},
        text:async()=>JSON.stringify({elements:[way]})});
    const f=fixture({automaticFixture:true,osmFallback:true,time:()=>timestamp,
        fetcherOverride:()=>{
            if(first){first=false;return new Promise(resolve=>{resolveFirst=resolve;});}
            return Promise.resolve(reply());
        }});
    f.module.setAutomatic(true);f.runAutoTimer();await tick();
    assert.equal(f.requested.length,1);
    f.moveCenter(8.34,46.91);
    for(const notify of f.moveListeners)notify();
    f.runAutoTimer();await tick();
    assert.equal(f.requested.length,1,'no overlapping viewport fetch');
    resolveFirst(reply());await tick();await tick();
    assert.equal(f.autoTimers.size,1,'the newer viewport remains scheduled');
    timestamp+=1600;f.runAutoTimer();await tick();await tick();
    assert.equal(f.requested.length,2,'fetches follow the latest camera location');
    f.module.dispose();
});
