'use strict';
const test=require('node:test'),assert=require('node:assert/strict');
const B=require('../../web/features/infrastructure/bridge_supports.js');
const ORIGIN={longitude:8.4,latitude:46.8};
const point=x=>({lon:ORIGIN.longitude+x/(111319.49*Math.cos(ORIGIN.latitude*Math.PI/180)),lat:ORIGIN.latitude});
const way=(id=1,tags={bridge:'yes',highway:'primary'})=>({type:'way',id,tags,geometry:[point(-72),point(72)]});
class Event{constructor(){this.listeners=new Set();}addEventListener(f){this.listeners.add(f);return()=>this.listeners.delete(f);}
    fire(){for(const f of this.listeners)f();}}
function fixture(options={}){
    class Value{constructor(o){Object.assign(this,o);}}
    const primitives=[],fetches=[],samples=[],excluded=[],preUpdate=new Event();
    const C={CylinderGeometry:Value,GeometryInstance:Value,Primitive:Value,PerInstanceColorAppearance:Value,
        Cartesian3:{fromDegrees:(longitude,latitude,height)=>({longitude,latitude,height})},
        Cartographic:{fromDegrees:(longitude,latitude)=>({longitude,latitude})},
        Transforms:{eastNorthUpToFixedFrame:position=>({position})},
        Color:{fromBytes:(...v)=>v},ColorGeometryInstanceAttribute:{fromColor:color=>({color})},ShadowMode:{DISABLED:0}};
    const collection={get length(){return primitives.length;},get:i=>primitives[i],
        add:p=>{primitives.push(p);return p;},remove:p=>{const i=primitives.indexOf(p);if(i>=0)primitives.splice(i,1);}};
    let clock=10000,terrainReady=true,deck=532.6;
    const viewer={camera:{positionCartographic:{longitude:ORIGIN.longitude*Math.PI/180,
        latitude:ORIGIN.latitude*Math.PI/180,height:700}},scene:{preUpdate,primitives:collection,globe:{},
        sampleHeight:(p,omit)=>{excluded.push(omit.slice());return typeof deck==='function'?deck(p):deck;},requestRender(){}}};
    const manager=B.create(C,viewer,{now:()=>clock,ready:()=>terrainReady,
        yieldBatch:async()=>{},
        fetcher:async(url,args)=>{fetches.push({url,args});return {ok:true,json:async()=>({elements:[way()]})};},
        sampleTerrain:async(points,signal)=>{samples.push({points,signal});return points.map(()=>500);},...options});
    return {C,viewer,manager,primitives,fetches,samples,excluded,preUpdate,
        setClock:v=>clock=v,setReady:v=>terrainReady=v,setDeck:v=>deck=v};
}

test('only explicit bridge roads/railways qualify; suspension, arches and ordinary roads stay untouched',()=>{
    const document={elements:[way(1),way(2,{railway:'rail',bridge:'viaduct'}),way(3,{highway:'primary'}),
        way(4,{highway:'primary',bridge:'no'}),way(5,{highway:'primary',bridge:'yes','bridge:structure':'suspension'}),
        way(6,{highway:'primary',bridge:'yes','bridge:structure':'arch'}),way(7,{highway:'primary',bridge:'yes','bridge:structure':'cable-stayed'}),
        way(1)]};
    assert.deepEqual(B.parseBridges(document).map(x=>x.id),['osm-bridge:1','osm-bridge:2']);
    assert.throws(()=>B.parseBridges({}),/Invalid/);
});

test('station spacing follows bends and leaves both abutments free under a bounded budget',()=>{
    const bridges=B.parseBridges({elements:[way()]});
    const stations=B.stations(bridges,ORIGIN,3);
    assert.equal(stations.length,3);
    assert.ok(stations.every(p=>p.longitude>point(-72).lon&&p.longitude<point(72).lon));
    assert.ok(stations.every(p=>p.probes.length===3));
});

test('automatic piers connect sampled terrain to the loaded deck in one batch',async()=>{
    const p=fixture();p.manager.setEnabled(true);
    try{
        const result=await p.manager.refresh(ORIGIN);
        assert.equal(result.count,5);
        assert.equal(p.primitives.length,1);
        const primitive=p.primitives[0];assert.equal(primitive.geometryInstances.length,5);
        for(let i=0;i<result.supports.length;i++){
            const support=result.supports[i],instance=primitive.geometryInstances[i];
            assert.ok(Math.abs(support.bottom-499.7)<1e-8);
            assert.ok(Math.abs(support.top-532.5)<1e-8);
            assert.ok(Math.abs(instance.geometry.length-(532.5-499.7))<1e-8);
            assert.ok(Math.abs(instance.modelMatrix.position.height-(support.top+support.bottom)/2)<1e-8);
        }
        assert.ok(p.fetches[0].url.includes('bridge'));
        assert.equal(p.samples[0].points.length,5);
    }finally{p.manager.dispose();}
    assert.equal(p.primitives.length,0);assert.equal(p.preUpdate.listeners.size,0);
});

test('deck samples exclude own supports and every nonstructures scene primitive',async()=>{
    const source={},roof={};let p;
    p=fixture({getDeckTileset:()=>source});p.primitives.push(source,roof);p.manager.setEnabled(true);
    try{
        await p.manager.refresh(ORIGIN);const oldSupport=p.primitives.at(-1);
        p.setClock(13000);await p.manager.refresh(ORIGIN);
        assert.ok(p.excluded.at(-1).includes(roof));
        assert.ok(p.excluded.at(-1).includes(oldSupport));
        assert.equal(p.excluded.at(-1).includes(source),false);
        assert.equal(p.primitives.length,3);
    }finally{p.manager.dispose();}
    assert.deepEqual(p.primitives,[source,roof]);
});

test('missing terrain/deck, inconsistent deck or implausible clearance never fabricates a pier',async()=>{
    for(const [ground,deck] of [[null,532.6],[500,undefined],[500,501],[500,700],
        [500,p=>p.longitude<ORIGIN.longitude?530:550]]){
        const p=fixture({sampleTerrain:async points=>points.map(()=>ground)});p.setDeck(deck);p.manager.setEnabled(true);
        try{await p.manager.refresh(ORIGIN);
            if(typeof deck==='function')assert.ok(p.manager.status().count<5,'crossing level discontinuity is rejected');
            else assert.equal(p.manager.status().count,0);
        }finally{p.manager.dispose();}
    }
});

test('cached source geometry resamples newly loaded decks without another query',async()=>{
    const p=fixture();p.setDeck(undefined);p.manager.setEnabled(true);
    try{
        await p.manager.refresh(ORIGIN);assert.equal(p.manager.status().count,0);
        p.setDeck(532.6);p.setClock(13000);await p.manager.refresh(ORIGIN);
        assert.equal(p.manager.status().count,5);assert.equal(p.fetches.length,1);
    }finally{p.manager.dispose();}
});

test('visibility is idempotent, opacity rebuilds only supports and disable cancels late terrain',async()=>{
    const p=fixture();p.manager.setEnabled(true);await p.manager.refresh(ORIGIN);
    const first=p.primitives[0];
    for(let i=0;i<100;i++)p.manager.setEnabled(true);
    assert.equal(p.primitives[0],first);assert.equal(p.fetches.length,1);
    p.manager.setOpacity(.5);assert.notEqual(p.primitives[0],first);
    assert.equal(p.primitives[0].appearance.translucent,true);
    p.manager.setEnabled(false);assert.equal(p.manager.status().count,0);p.manager.dispose();
    let finish;const q=fixture({sampleTerrain:()=>new Promise(resolve=>finish=resolve)});
    q.manager.setEnabled(true);const pending=q.manager.refresh(ORIGIN);
    await new Promise(resolve=>setImmediate(resolve));q.manager.setEnabled(false);finish([500,500,500,500,500]);
    await pending;assert.equal(q.primitives.length,0);q.manager.dispose();
});

test('offline and cached-only mode do not send bridge requests',async()=>{
    for(const options of [{cachedOnly:true},{isOnline:()=>false}]){
        const p=fixture(options);p.manager.setEnabled(true);await p.manager.refresh(ORIGIN);
        assert.equal(p.fetches.length,0);assert.equal(p.primitives.length,0);p.manager.dispose();
    }
});

test('terrain failure removes existing supports and camera updates remain throttled',async()=>{
    const p=fixture();p.manager.setEnabled(true);await p.manager.refresh(ORIGIN);
    for(let i=0;i<100;i++)p.preUpdate.fire();assert.equal(p.samples.length,1);
    p.setReady(false);p.preUpdate.fire();assert.equal(p.manager.status().count,0);
    assert.equal(p.primitives.length,0);p.manager.dispose();
});

test('two-second bridge refreshes follow the aircraft without horizon picks, while map inspection retains its visible target',async()=>{
    let navigating=true,picks=0,rays=0;const centers=[];
    const p=fixture({cachedOnly:true,isNavigationActive:()=>navigating,
        discoverBridges:async center=>{centers.push({...center});return {bridges:[],piers:[]};}});
    p.C.Cartesian2=class{constructor(x,y){Object.assign(this,{x,y});}};
    const target={longitude:8.45*Math.PI/180,latitude:46.85*Math.PI/180};
    p.C.Cartographic.fromCartesian=()=>target;
    p.viewer.scene.canvas={clientWidth:800,clientHeight:600};
    p.viewer.camera.getPickRay=()=>{rays++;return {};};
    p.viewer.scene.globe.pick=()=>{picks++;return {};};
    p.manager.setEnabled(true);
    try{
        for(let i=0;i<6;i++){
            const latitude=ORIGIN.latitude+i*40/111320;
            p.viewer.camera.positionCartographic.latitude=latitude*Math.PI/180;
            p.setClock(10000+i*2100);await p.manager.refresh();
            assert.ok(Math.abs(centers.at(-1).latitude-latitude)<1e-10);
        }
        assert.equal(rays,0);assert.equal(picks,0);
        p.viewer.camera.positionCartographic.latitude=NaN;
        const count=centers.length;await p.manager.refresh();assert.equal(centers.length,count);
        assert.equal(rays,0,'Missing navigation coordinates must not trigger a horizon ray');
        navigating=false;await p.manager.refresh();
        assert.equal(rays,1);assert.equal(picks,1);
        assert.ok(Math.abs(centers.at(-1).latitude-46.85)<1e-10);
    }finally{p.manager.dispose();}
});

test('overlapping refreshes share their request and a failed primary uses the bounded backup',async()=>{
    let requests=0,release;
    const p=fixture({fetcher:async()=>{requests++;if(requests===1)throw Error('primary unavailable');
        await new Promise(resolve=>release=resolve);return {ok:true,json:async()=>({elements:[way()]})};}});
    p.manager.setEnabled(true);const a=p.manager.refresh(ORIGIN),b=p.manager.refresh(ORIGIN);
    assert.equal(a,b);await new Promise(resolve=>setImmediate(resolve));release();
    await a;assert.equal(requests,2);assert.equal(p.manager.status().count,5);p.manager.dispose();
});

test('terrain interruption clears the pending slot and recovery starts a new request',async()=>{
    let release,requests=0;
    const p=fixture({sampleTerrain:async points=>{requests++;if(requests===1)await new Promise(resolve=>release=resolve);
        return points.map(()=>500);}});
    p.manager.setEnabled(true);const first=p.manager.refresh(ORIGIN);
    await new Promise(resolve=>setImmediate(resolve));
    p.setReady(false);await p.manager.refresh(ORIGIN);
    assert.equal(p.manager.status().pending,false);
    p.setReady(true);const second=p.manager.refresh(ORIGIN);assert.notEqual(second,first);
    await second;release();await first;
    assert.equal(p.manager.status().count,5);assert.equal(requests,2);p.manager.dispose();
});

test('an oversized streaming bridge response is cancelled before the remainder downloads',async()=>{
    let cancelled=0,reads=0;
    const p=fixture({fetcher:async()=>({ok:true,body:{getReader:()=>({
        read:async()=>{reads++;return {done:false,value:new Uint8Array(2*1024*1024+1)};},
        cancel:async()=>{cancelled++;},releaseLock(){}})}})});
    p.manager.setEnabled(true);await p.manager.refresh(ORIGIN);
    assert.equal(cancelled,2,'both bounded services reject the oversized response');
    assert.equal(reads,2);assert.equal(p.manager.status().count,0);
    assert.match(p.manager.status().error,/budget/);p.manager.dispose();
});

test('supports carry their own OSM credit only while visible',async()=>{
    const p=fixture(),credits=new Set();
    p.manager.dispose();p.C.Credit=class{constructor(html){this.html=html;}};
    p.viewer.cesiumWidget={creditDisplay:{addStaticCredit:c=>credits.add(c),removeStaticCredit:c=>credits.delete(c)}};
    const manager=B.create(p.C,p.viewer,{fetcher:async()=>({ok:true,json:async()=>({elements:[way()]})}),
        sampleTerrain:async points=>points.map(()=>500)});
    manager.setEnabled(true);await manager.refresh(ORIGIN);
    assert.equal(credits.size,1);assert.match([...credits][0].html,/OpenStreetMap/);
    manager.setEnabled(false);assert.equal(credits.size,0);manager.dispose();
});

test('a reduced graphics budget applies even to an in-flight higher-quality sample',async()=>{
    let release;
    const bridges=Array.from({length:5},(_,i)=>({...way(i+1),geometry:[point(-600),point(600)].map(p=>
        ({lon:p.lon,lat:p.lat+i*.0001}))}));
    const p=fixture({fetcher:async()=>({ok:true,json:async()=>({elements:bridges})}),
        sampleTerrain:async points=>{await new Promise(resolve=>release=resolve);return points.map(()=>500);}});
    p.manager.performance('quality');p.manager.setEnabled(true);const pending=p.manager.refresh(ORIGIN);
    await new Promise(resolve=>setImmediate(resolve));p.manager.performance('compatibility');release();await pending;
    assert.equal(p.manager.status().count,24);p.manager.dispose();
});

test('failed queries back off after panning beyond an earlier successful cache',async()=>{
    let requests=0;
    const p=fixture({fetcher:async()=>{requests++;if(requests>1)throw Error('rate limited');
        return {ok:true,json:async()=>({elements:[way()]})};}});
    p.manager.setEnabled(true);await p.manager.refresh(ORIGIN);
    const moved={longitude:ORIGIN.longitude+.01,latitude:ORIGIN.latitude};
    p.setClock(13000);await p.manager.refresh(moved);assert.equal(requests,3);
    p.setClock(17000);await p.manager.refresh(moved);assert.equal(requests,3,'stale cache cannot bypass retry delay');
    p.setClock(45000);await p.manager.refresh(moved);assert.equal(requests,5);p.manager.dispose();
});

test('an unrelated OSINT bridge cannot suppress bridge discovery in the current view',async()=>{
    const p=fixture();
    try{
        p.manager.setSourceFeatures([{id:'distant',sourceType:'BRIDGE',parts:[{kind:'LineString',
            elevated:true,coordinates:[[10.2,47.5,520],[10.202,47.5,520]]}]}],
        {sourceId:'aviation',source:'BAZL',elevationReference:'WGS84_ELLIPSOID'});
        await p.manager.refresh(ORIGIN);
        assert.equal(p.fetches.length,0);
        p.manager.setEnabled(true);await p.manager.refresh(ORIGIN);
        assert.equal(p.fetches.length,1);
        assert.equal(p.manager.status().count,5);
    }finally{p.manager.dispose();}
});

test('confirmed native bridge profiles produce supports without waiting for Overpass',async()=>{
    let discoveries=0,disposed=0;
    const coordinates=way().geometry.map(p=>({longitude:p.lon,latitude:p.lat,height:532.6}));
    const p=fixture({cachedOnly:true,discoverBridges:async()=>{discoveries++;return {bridges:[{
        id:'swisstopo:45029',sourceId:'45029',source:'swisstopo 3D',coordinates,
        profileMethod:'loaded-native-road'}],piers:[]};},disposeDiscovery:()=>disposed++});
    p.setDeck(undefined);p.manager.setEnabled(true);
    try{
        const state=await p.manager.refresh(ORIGIN);
        assert.equal(discoveries,1);assert.equal(state.count,5);assert.equal(p.fetches.length,0);
        assert.equal(p.excluded.length,0,'confirmed native heights do not trigger redundant resident deck GPU picks');
        assert.ok(state.supports.every(p=>p.source==='swisstopo 3D'&&p.heightMethod==='loaded-native-deck'));
    }finally{p.manager.dispose();}
    assert.equal(disposed,1);
});

test('quality deck verification permits at most one resident GPU pick per yielded frame',async()=>{
    const bridges=Array.from({length:5},(_,i)=>({...way(i+1),geometry:[point(-600),point(600)].map(p=>
        ({lon:p.lon,lat:p.lat+i*.0001}))}));
    let frame=0;const picks=new Map();
    const p=fixture({yieldBatch:async()=>{frame++;},
        fetcher:async()=>({ok:true,json:async()=>({elements:bridges})})});
    p.viewer.scene.sampleHeight=()=>{picks.set(frame,(picks.get(frame)||0)+1);return 532.6;};
    p.manager.performance('quality');p.manager.setEnabled(true);
    try{
        const state=await p.manager.refresh(ORIGIN);
        assert.equal(state.count,128);assert.equal([...picks.values()].reduce((a,b)=>a+b,0),384);
        assert.equal(Math.max(...picks.values()),1,'384 quality probes cannot run as one synchronous GPU burst');
        assert.equal(picks.has(0),false,'the first offscreen pick also waits for the visible frame');
    }finally{p.manager.dispose();}
});

test('unchanged refreshed supports retain their primitive and changed geometry still rebuilds',async()=>{
    const p=fixture();p.manager.setEnabled(true);
    try{
        await p.manager.refresh(ORIGIN);const first=p.primitives[0];
        p.setClock(13000);await p.manager.refresh(ORIGIN);
        assert.equal(p.primitives[0],first,'a cached bridge refresh need not rebuild and upload all pier geometry');
        p.setDeck(533.6);p.setClock(16000);await p.manager.refresh(ORIGIN);
        assert.notEqual(p.primitives[0],first);assert.equal(p.primitives.length,1);
        assert.ok(p.manager.status().supports.every(s=>s.top===533.5));
    }finally{p.manager.dispose();}
});

test('disabling supports between deferred GPU probes cancels the remaining burst',async()=>{
    let frames=0,p;
    p=fixture({yieldBatch:async()=>{if(++frames===3)p.manager.setEnabled(false);}});
    p.manager.setEnabled(true);
    try{
        await p.manager.refresh(ORIGIN);
        assert.equal(p.excluded.length,2);assert.equal(p.primitives.length,0);
        assert.equal(p.manager.status().pending,false);
    }finally{p.manager.dispose();}
});

test('hiding structures discards a late native discovery result',async()=>{
    let release;
    const p=fixture({discoverBridges:()=>new Promise(resolve=>release=resolve)});
    p.manager.setEnabled(true);const pending=p.manager.refresh(ORIGIN);
    p.manager.setEnabled(false);release({bridges:B.parseBridges({elements:[way()]}),piers:[]});
    await pending;
    assert.equal(p.primitives.length,0);assert.equal(p.fetches.length,0);p.manager.dispose();
});

test('exact ground samples are reused, expire and invalidate on terrain change without caching deck picks',async()=>{
    let provider={};const p=fixture({terrainIdentity:()=>provider});
    p.manager.setDiagnosticsEnabled(true);p.manager.setEnabled(true);
    try{
        await p.manager.refresh(ORIGIN);const initial=p.samples.length,picks=p.excluded.length;
        assert.equal(initial,1);assert.ok(picks>0);
        p.setClock(13000);await p.manager.refresh(ORIGIN);
        assert.equal(p.samples.length,initial);assert.ok(p.excluded.length>picks);
        assert.equal(p.manager.diagnostics().groundHits,5);
        provider={};p.setClock(16000);await p.manager.refresh(ORIGIN);
        assert.equal(p.samples.length,initial+1);
        p.setClock(137000);await p.manager.refresh(ORIGIN);
        assert.equal(p.samples.length,initial+2);
        p.manager.setDiagnosticsEnabled(false);assert.equal(p.manager.diagnostics(),null);
    }finally{p.manager.dispose();}
});

test('invalid ground values are not cached',async()=>{
    let batches=0;const q=fixture({sampleTerrain:async points=>{batches++;return points.map(()=>batches===1?NaN:500);}});
    q.manager.setEnabled(true);
    try{await q.manager.refresh(ORIGIN);assert.equal(q.manager.status().count,0);
        q.setClock(13000);await q.manager.refresh(ORIGIN);assert.equal(batches,2);assert.equal(q.manager.status().count,5);
    }finally{q.manager.dispose();}
});


function deckFixture(options={}){
    const tile={contentReady:true,content:{},boundingSphere:{center:{x:ORIGIN.longitude*100000,y:ORIGIN.latitude*100000,z:530},radius:1000}};
    const tileset={show:true,_selectedTiles:[tile]};
    const p=fixture({getDeckTileset:()=>tileset,...options});
    p.C.Cartesian3.fromDegrees=(longitude,latitude,height)=>({longitude,latitude,height,x:longitude*100000,y:latitude*100000,z:height});
    p.manager.setDiagnosticsEnabled(true);p.manager.setEnabled(true);
    return {...p,tile,tileset};
}
test('deck cache uses coherent groups and the identity of locally selected tile content',async()=>{
    let terrain={};const p=deckFixture({terrainIdentity:()=>terrain});
    try{
        await p.manager.refresh(ORIGIN);assert.equal(p.manager.diagnostics().deckCacheEntries,5);const initial=p.excluded.length;assert.equal(initial,15);
        p.tileset._selectedTiles.push({contentReady:true,content:{},boundingSphere:{center:{x:0,y:0,z:0},radius:1}});
        p.setClock(13000);await p.manager.refresh(ORIGIN);assert.equal(p.excluded.length,initial);assert.equal(p.manager.diagnostics().deckHits,5);
        // Same tile, different content: re-sample, do not keep previous height.
        p.tile.content={};p.setDeck(534);p.setClock(16000);await p.manager.refresh(ORIGIN);
        assert.equal(p.excluded.length,initial*2);assert.ok(p.manager.status().supports.every(s=>s.top===533.9));
        terrain={};p.setClock(19000);await p.manager.refresh(ORIGIN);assert.equal(p.excluded.length,initial*3);
        p.manager.invalidateDeckCache();p.setClock(22000);await p.manager.refresh(ORIGIN);assert.equal(p.excluded.length,initial*4);
        p.setClock(53000);await p.manager.refresh(ORIGIN);assert.equal(p.excluded.length,initial*5);
        p.tileset._selectedTiles=[];p.setClock(56000);await p.manager.refresh(ORIGIN);assert.equal(p.excluded.length,initial*6);assert.equal(p.manager.diagnostics().deckCacheEntries,0);
    }finally{p.manager.dispose();}
});
test('missing, incoherent or implausible deck data is never cached',async()=>{
    for(const height of [undefined,501,700,p=>p.longitude>ORIGIN.longitude?540:500]){
        const p=deckFixture();p.setDeck(height);
        try{await p.manager.refresh(ORIGIN);
            if(typeof height!=='function')assert.equal(p.manager.diagnostics().deckCacheEntries,0);
            else assert.ok(p.manager.diagnostics().deckCacheEntries<5);
        }finally{p.manager.dispose();}
    }
});
test('benchmark suppresses synthetic supports and restores preference; expensive navigation picks yield an extra frame',async()=>{
    let frame=0,clock=10000;const p=deckFixture({now:()=>clock,isNavigationActive:()=>true,yieldBatch:async()=>{frame++;}});
    const frames=[];p.viewer.scene.sampleHeight=()=>{frames.push(frame);clock+=10;return 532.6;};
    try{
        await p.manager.refresh(ORIGIN);assert.equal(p.manager.status().count,5);assert.equal(frames.length,15);
        assert.ok(frames.slice(1).every((v,i)=>v-frames[i]>=2));assert.equal(p.manager.diagnostics().deckCooldownFrames,15);
        p.manager.setBenchmarkSuppressed(true);assert.equal(p.manager.status().count,0);assert.equal(p.manager.diagnostics().benchmarkSuppressed,true);
        await p.manager.refresh(ORIGIN);assert.equal(frames.length,15);
        p.manager.setBenchmarkSuppressed(false);await p.manager.refresh(ORIGIN);assert.equal(p.manager.status().count,5);
        assert.equal(p.manager.diagnostics().benchmarkSuppressed,false);
    }finally{p.manager.dispose();}
});


test('replacing the source tileset during asynchronous deck sampling cannot publish stale heights',async()=>{
    let selected={show:true},frames=0;
    const p=fixture({getDeckTileset:()=>selected,yieldBatch:async()=>{if(++frames===2)selected={show:true};}});
    p.manager.setEnabled(true);
    try{await p.manager.refresh(ORIGIN);assert.equal(p.manager.status().count,0);assert.equal(p.excluded.length,1);}
    finally{p.manager.dispose();}
});

test('visual flight cache survives LOD churn only for coherent source-scoped samples; terrain and explicit changes invalidate',async()=>{
    let terrain={};const p=deckFixture({reuseFlightDeck:true,isNavigationActive:()=>true,terrainIdentity:()=>terrain});
    try{
        await p.manager.refresh(ORIGIN);assert.equal(p.excluded.length,15);
        p.tileset._selectedTiles=[];p.setClock(20000);await p.manager.refresh(ORIGIN);
        assert.equal(p.excluded.length,15);assert.equal(p.manager.diagnostics().deckPersistentHits,5);
        p.manager.invalidateDeckCache();p.setClock(30000);await p.manager.refresh(ORIGIN);
        assert.equal(p.excluded.length,30);assert.equal(p.manager.diagnostics().deckCacheEntries,0);
        p.setClock(40000);await p.manager.refresh(ORIGIN);
        assert.equal(p.excluded.length,45);assert.equal(p.manager.diagnostics().deckCacheEntries,5);
        p.setClock(50000);await p.manager.refresh(ORIGIN);assert.equal(p.excluded.length,45);
        terrain={};p.setClock(60000);await p.manager.refresh(ORIGIN);assert.equal(p.excluded.length,60);
        assert.equal(p.manager.diagnostics().deckCacheEntries,0);
    }finally{p.manager.dispose();}
});

test('mobile flight throttles rapid refreshes but retries failed resident probes after tiles load',async()=>{
    const p=deckFixture({reuseFlightDeck:true,mobile:true,isNavigationActive:()=>true});
    p.tileset._selectedTiles=[];p.setDeck(undefined);
    try{
        await p.manager.refresh(ORIGIN);assert.equal(p.excluded.length,15);assert.equal(p.manager.status().count,0);
        p.setClock(11000);await p.manager.refresh(ORIGIN);assert.equal(p.excluded.length,15);
        p.setDeck(532.6);p.setClock(12200);await p.manager.refresh(ORIGIN);
        assert.equal(p.excluded.length,30);assert.equal(p.manager.status().count,5);
        assert.equal(p.manager.diagnostics().deckRetryDeferred,0);
    }finally{p.manager.dispose();}
});

test('frozen measurement retains warmed geometry without new picks; compute-only creates no primitive and normal mode restores',async()=>{
    const p=deckFixture();try{
        await p.manager.refresh(ORIGIN);assert.equal(p.manager.status().count,5);
        p.manager.setBenchmarkMode(1);await p.manager.refresh(ORIGIN);
        const original=p.primitives[0],count=p.excluded.length;
        p.manager.beginBenchmarkMeasurement();p.manager.setDiagnosticsEnabled(false);p.manager.setDiagnosticsEnabled(true);
        p.setClock(30000);await p.manager.refresh(ORIGIN);p.preUpdate.fire();
        assert.equal(p.primitives[0],original);assert.equal(p.excluded.length,count);
        assert.equal(p.manager.diagnostics().frozen,true);assert.equal(p.manager.diagnostics().visibleSupports,5);
        p.manager.setBenchmarkMode(2);await p.manager.refresh(ORIGIN);
        assert.equal(p.primitives.length,0);assert.equal(p.manager.diagnostics().computedSupports,5);
        assert.equal(p.manager.diagnostics().geometryBuilds,0);
        p.manager.setBenchmarkMode(0);await p.manager.refresh(ORIGIN);
        assert.equal(p.primitives.length,1);assert.equal(p.manager.diagnostics().visibleSupports,5);
    }finally{p.manager.dispose();}
});

test('mobile most-detailed fallback can finish every nearby pier within its deadline',async()=>{
    const p=deckFixture({reuseFlightDeck:true,mobile:true,isNavigationActive:()=>true});
    p.tileset._selectedTiles=[];p.setDeck(undefined);const attempts=[];
    p.viewer.scene.sampleHeightMostDetailed=async points=>{attempts.push(points[1].longitude);return points;};
    try{
        await p.manager.refresh(ORIGIN);assert.equal(attempts.length,5);
        assert.equal(p.manager.diagnostics().detailedDeferred,0);
        assert.equal(new Set(attempts).size,5);assert.equal(p.manager.status().count,0);
    }finally{p.manager.dispose();}
});

test('slow flight refresh publishes validated piers before completing the batch and survives movement within the search area',async()=>{
    let frames=0,release,block=false;
    const p=deckFixture({reuseFlightDeck:true,isNavigationActive:()=>true,
        yieldBatch:async()=>{if(++frames===4&&block)await new Promise(resolve=>release=resolve);}});
    try{
        block=true;
        const first=p.manager.refresh(ORIGIN);
        await new Promise(resolve=>setImmediate(resolve));
        assert.ok(release,'sampling has reached a later candidate');
        assert.ok(p.manager.status().count>0,'first validated group already visible');
        assert.ok(p.manager.status().pending);
        const moved={...ORIGIN,latitude:ORIGIN.latitude+400/111320};
        p.setClock(21000);
        assert.equal(p.manager.refresh(moved),first,'motion within the source area must not starve pending work');
        release();await first;
        assert.equal(p.manager.status().count,5);
        assert.ok(p.manager.diagnostics().progressPublishes>0);
    }finally{release?.();p.manager.dispose();}
});

test('invalidated deck sampling stops before spending the rest of the GPU budget',async()=>{
    let frames=0,release;
    const p=deckFixture({reuseFlightDeck:true,isNavigationActive:()=>true,
        yieldBatch:async()=>{if(++frames===2)await new Promise(resolve=>release=resolve);}});
    try{
        const operation=p.manager.refresh(ORIGIN);
        await new Promise(resolve=>setImmediate(resolve));
        assert.ok(release);p.manager.invalidateDeckCache();release();await operation;
        assert.equal(p.manager.status().count,0);
        assert.equal(p.excluded.length,1);
        assert.equal(p.manager.diagnostics().refreshInvalidated,1);
        p.setClock(11000);await p.manager.refresh(ORIGIN);
        assert.equal(p.manager.status().count,5);
    }finally{release?.();p.manager.dispose();}
});


test('previously validated visual piers survive missing resident deck observations without renewing their age',async()=>{
    const p=deckFixture({reuseFlightDeck:true,isNavigationActive:()=>true});
    p.tileset._selectedTiles=[];
    try{await p.manager.refresh(ORIGIN);assert.equal(p.manager.status().count,5);const primitive=p.primitives[0];
        p.setDeck(undefined);p.setClock(20000);await p.manager.refresh(ORIGIN);
        assert.equal(p.manager.status().count,5);assert.equal(p.primitives[0],primitive);
        assert.equal(p.manager.diagnostics().retainedSupports,5);
        p.setClock(140001);await p.manager.refresh(ORIGIN);assert.equal(p.manager.status().count,0);
    }finally{p.manager.dispose();}
});

test('contradictory finite deck data and source invalidation cannot retain old piers',async()=>{
    const p=deckFixture({reuseFlightDeck:true,isNavigationActive:()=>true});
    p.tileset._selectedTiles=[];
    try{await p.manager.refresh(ORIGIN);assert.equal(p.manager.status().count,5);
        p.setDeck(700);p.setClock(20000);await p.manager.refresh(ORIGIN);assert.equal(p.manager.status().count,0);
        p.setDeck(532.6);p.setClock(23000);await p.manager.refresh(ORIGIN);assert.equal(p.manager.status().count,5);
        p.manager.invalidateDeckCache();p.setDeck(undefined);p.setClock(24000);await p.manager.refresh(ORIGIN);assert.equal(p.manager.status().count,0);
    }finally{p.manager.dispose();}
});

test('a transient empty native discovery keeps validated piers in range but not after a source replacement',async()=>{
    let selected={show:true},available=true;
    const coordinates=way().geometry.map(p=>({longitude:p.lon,latitude:p.lat,height:532.6}));
    const p=fixture({cachedOnly:true,reuseFlightDeck:true,isNavigationActive:()=>true,getDeckTileset:()=>selected,
        discoverBridges:async()=>({bridges:available?[{id:'native:1',sourceId:'native:1',source:'swisstopo',coordinates,profileMethod:'loaded-native-road'}]:[],piers:[]})});
    p.manager.setEnabled(true);p.manager.setDiagnosticsEnabled(true);
    try{await p.manager.refresh(ORIGIN);assert.equal(p.manager.status().count,5);
        available=false;p.setClock(20000);await p.manager.refresh(ORIGIN);assert.equal(p.manager.status().count,5);
        selected={show:true};p.setClock(21000);await p.manager.refresh(ORIGIN);assert.equal(p.manager.status().count,0);
    }finally{p.manager.dispose();}
});


test('ground-only resident samples use a complete detailed observation instead of losing bridge piers',async()=>{
    const p=deckFixture({reuseFlightDeck:true,isNavigationActive:()=>true,mobile:true});
    p.tileset._selectedTiles=[];p.setDeck(500);
    p.viewer.scene.sampleHeightMostDetailed=async points=>points.map(q=>({...q,height:532.6}));
    try{await p.manager.refresh(ORIGIN);assert.equal(p.manager.status().count,5);
        assert.ok(p.manager.status().supports.every(s=>s.top===532.5));
        assert.equal(p.manager.diagnostics().deckGroundOnly,5);
        assert.equal(p.manager.diagnostics().detailedResolved,5);
        // Ground-only hits after LOD eviction don't erase validated geometry.
        delete p.viewer.scene.sampleHeightMostDetailed;p.setClock(20000);await p.manager.refresh(ORIGIN);
        assert.equal(p.manager.status().count,5);
        assert.equal(p.manager.diagnostics().retainedSupports,5);
    }finally{p.manager.dispose();}
});

test('an incomplete detailed sample cannot be mixed with a separate resident observation',async()=>{
    const p=deckFixture({reuseFlightDeck:true,isNavigationActive:()=>true});
    p.tileset._selectedTiles=[];let index=0;p.setDeck(()=>++index%3===2?undefined:532.6);
    p.viewer.scene.sampleHeightMostDetailed=async points=>points.map((q,i)=>({...q,height:i===1?532.6:undefined}));
    try{await p.manager.refresh(ORIGIN);assert.equal(p.manager.status().count,0);
        assert.equal(p.manager.diagnostics().detailedResolved,0);
    }finally{p.manager.dispose();}
});

test('portal-only invalidation does not abort native source discovery',async()=>{
    let invalidations=0;const p=deckFixture({invalidateDiscovery:()=>invalidations++});
    try{await p.manager.refresh(ORIGIN);const previous=invalidations;
        p.manager.invalidateDeckCache(false);assert.equal(invalidations,previous);
        p.manager.invalidateDeckCache();assert.equal(invalidations,previous+1);
    }finally{p.manager.dispose();}
});

test('partial native discovery retains a different validated bridge, but not outside the search area',async()=>{
    const selected={show:true};let includeBoth=true;
    const profile=(id,dy)=>({id,sourceId:id,source:'swisstopo',profileMethod:'loaded-native-road',
        coordinates:way().geometry.map(p=>({longitude:p.lon,latitude:p.lat+dy/111320,height:532.6}))});
    const one=profile('native:1',0),two=profile('native:2',150);
    const p=fixture({cachedOnly:true,reuseFlightDeck:true,isNavigationActive:()=>true,getDeckTileset:()=>selected,
        discoverBridges:async()=>({bridges:includeBoth?[one,two]:[one],piers:[]})});
    p.manager.setEnabled(true);p.manager.setDiagnosticsEnabled(true);
    try{await p.manager.refresh(ORIGIN);assert.equal(p.manager.status().count,10);
        includeBoth=false;p.setClock(20000);await p.manager.refresh(ORIGIN);assert.equal(p.manager.status().count,10);
        assert.equal(p.manager.diagnostics().retainedSupports,5);
        p.setClock(30000);await p.manager.refresh({...ORIGIN,latitude:ORIGIN.latitude-900/111320});
        assert.equal(p.manager.status().count,0);
    }finally{p.manager.dispose();}
});

test('two independent detailed deck observations enable mobile reuse despite resident ground-only hits',async()=>{
    const p=deckFixture({reuseFlightDeck:true,mobile:true,isNavigationActive:()=>true});
    p.tileset._selectedTiles=[];p.setDeck(500);let detailed=0;
    p.viewer.scene.sampleHeightMostDetailed=async points=>{detailed++;return points.map(q=>({...q,height:532.6}));};
    try{
        await p.manager.refresh(ORIGIN);assert.equal(p.manager.status().count,5);assert.equal(detailed,5);
        p.setClock(20000);await p.manager.refresh(ORIGIN);assert.equal(detailed,10);
        assert.equal(p.manager.diagnostics().deckConfirmedEntries,5);
        p.setClock(30000);await p.manager.refresh(ORIGIN);assert.equal(detailed,10);
        assert.equal(p.manager.diagnostics().deckStableHits,5);
    }finally{p.manager.dispose();}
});

test('a source profile cannot be overwritten by a coherent but much higher sampled surface',async()=>{
    const selected={show:true};const p=fixture({cachedOnly:true,getDeckTileset:()=>selected});
    p.setDeck(545);p.manager.setSourceFeatures([{type:'Feature',id:'ref',geometry:{type:'LineString',coordinates:way().geometry.map(q=>[q.lon,q.lat,532.6])},properties:{bridge:'yes',highway:'primary',elevationReference:'EPSG:4979'}}]);
    try{await p.manager.refresh(ORIGIN);assert.ok(p.manager.status().count>0);
        assert.ok(p.manager.status().supports.every(s=>Math.abs(s.top-532.5)<1e-6));}
    finally{p.manager.dispose();}
});

test('invalidated native section removes old supports even if all new observations temporarily disappear',async()=>{
    const selected={show:true};let invalid=false;
    const profile={id:'native-section',sourceId:'uuid',source:'swisstopo',profileMethod:'loaded-native-road',
        coordinates:[point(-12.1),point(12.1)].map(q=>({longitude:q.lon,latitude:q.lat,height:532.6})),stableSection:true};
    const p=fixture({cachedOnly:true,reuseFlightDeck:true,isNavigationActive:()=>true,getDeckTileset:()=>selected,
        discoverBridges:async()=>invalid?{bridges:[],piers:[],invalidatedSections:['native-section:1']}:{bridges:[profile],piers:[]}});
    p.manager.setEnabled(true);
    try{await p.manager.refresh(ORIGIN);assert.equal(p.manager.status().count,1);invalid=true;p.setClock(20000);
        await p.manager.refresh(ORIGIN);assert.equal(p.manager.status().count,0);}
    finally{p.manager.dispose();}
});

test('LOD-only budget changes preserve independently confirmed deck heights but source changes do not',async()=>{
    let invalidations=0;const p=deckFixture({reuseFlightDeck:true,isNavigationActive:()=>true,invalidateDiscovery:()=>invalidations++});
    p.tileset._selectedTiles=[];
    try{
        await p.manager.refresh(ORIGIN);p.setClock(20000);await p.manager.refresh(ORIGIN);
        assert.equal(p.manager.diagnostics().deckConfirmedEntries,5);const before=p.excluded.length,prior=invalidations;
        p.manager.invalidateLod();p.setClock(30000);await p.manager.refresh(ORIGIN);
        assert.equal(p.excluded.length,before);assert.equal(invalidations,prior);
        assert.equal(p.manager.diagnostics().deckStableHits,5);
        p.manager.invalidateDeckCache();p.setClock(40000);await p.manager.refresh(ORIGIN);
        assert.equal(p.excluded.length,before+15);assert.equal(invalidations,prior+1);
    }finally{p.manager.dispose();}
});

test('expired confirmed flight heights cannot jump upward on a single coherent observation',async()=>{
    const p=deckFixture({reuseFlightDeck:true,isNavigationActive:()=>true});p.tileset._selectedTiles=[];
    try{
        await p.manager.refresh(ORIGIN);p.setClock(20000);await p.manager.refresh(ORIGIN);
        assert.equal(p.manager.diagnostics().deckConfirmedEntries,5);
        p.setDeck(550);p.setClock(330000);await p.manager.refresh(ORIGIN);
        assert.ok(p.manager.status().supports.every(x=>x.top<540));
        assert.equal(p.manager.diagnostics().deckHeightRejected,5);
        p.setDeck(532.6);p.setClock(340000);await p.manager.refresh(ORIGIN);
        assert.equal(p.manager.status().count,5);assert.ok(p.manager.status().supports.every(x=>Math.abs(x.top-532.5)<1e-6));
    }finally{p.manager.dispose();}
});

test('partially rediscovered sections of the SAME native bridge do not delete validated neighbouring piers',async()=>{
    const selected={show:true};let mode=0;
    const span=(id,x)=>({id,sourceId:'same-uuid',source:'swisstopo',profileMethod:'loaded-native-road',stableSection:true,
        coordinates:[point(x-12.1),point(x+12.1)].map(q=>({longitude:q.lon,latitude:q.lat,height:532.6}))});
    const a=span('a',-48),b=span('b',48),c=span('c',100);
    const p=fixture({cachedOnly:true,reuseFlightDeck:true,isNavigationActive:()=>true,getDeckTileset:()=>selected,
        discoverBridges:async()=>mode===0?{bridges:[a,b],piers:[]}:mode===1?{bridges:[a,c],piers:[]}:
            {bridges:[a,c],piers:[],invalidatedSections:['b:1']}});
    p.manager.setEnabled(true);p.manager.setDiagnosticsEnabled(true);
    try{
        await p.manager.refresh(ORIGIN);assert.equal(p.manager.status().count,2);
        mode=1;p.setClock(20000);await p.manager.refresh(ORIGIN);
        assert.deepEqual(p.manager.status().supports.map(p=>p.id).sort(),['a:1','b:1','c:1']);
        assert.equal(p.manager.diagnostics().supportRetainedSameSource,1);
        assert.equal(p.manager.diagnostics().supportRemovedDuringDraw,0);
        mode=2;p.setClock(30000);await p.manager.refresh(ORIGIN);
        assert.deepEqual(p.manager.status().supports.map(p=>p.id).sort(),['a:1','c:1']);
        assert.equal(p.manager.diagnostics().supportRemovedDuringDraw,1);
    }finally{p.manager.dispose();}
});

test('legacy native station identifiers do not alias disjoint chunks when scan bounds shift',()=>{
    const span=(x)=>({id:'same-route:0',sourceId:'uuid',nativeStationKey:'road-1',source:'swisstopo',profileMethod:'loaded-native-road',
        coordinates:[point(x-36),point(x+36)].map(q=>({longitude:q.lon,latitude:q.lat,height:532.6}))});
    const a=B.stations([span(-100)],ORIGIN),b=B.stations([span(100)],ORIGIN);
    assert.ok(a.length&&b.length);assert.ok(a.every(p=>!b.some(q=>q.id===p.id)));
    assert.deepEqual(B.stations([span(-100)],ORIGIN).map(p=>p.id),a.map(p=>p.id));
});

test('rotating the map camera at a fixed position does not change the ground search anchor',async()=>{
    const centers=[];const p=fixture({cachedOnly:true,reuseFlightDeck:true,
        discoverBridges:async center=>{centers.push({...center});return {bridges:[],piers:[]};}});
    let target=ORIGIN,rays=0;
    p.C.Cartesian2=class{};p.viewer.scene.canvas={width:800,height:600};
    p.viewer.camera.getPickRay=()=>{rays++;return {};};p.viewer.scene.globe.pick=()=>({});
    p.C.Cartographic.fromCartesian=()=>({longitude:target.longitude*Math.PI/180,latitude:target.latitude*Math.PI/180});
    p.manager.setEnabled(true);
    try{
        await p.manager.refresh();target={longitude:8.45,latitude:46.85};p.setClock(30000);await p.manager.refresh();
        assert.equal(rays,1);assert.equal(centers.length,2);assert.deepEqual(centers[0],centers[1]);
        p.viewer.camera.positionCartographic.longitude=8.45*Math.PI/180;p.setClock(50000);await p.manager.refresh();
        assert.equal(rays,2);assert.ok(Math.abs(centers.at(-1).longitude-8.45)<1e-9);
    }finally{p.manager.dispose();}
});

test('portal visibility changes and empty auxiliary viewport updates preserve native world-space geometry',async()=>{
    const selected={show:true};let available=true,invalidations=0;
    const profile={id:'native',sourceId:'uuid',source:'swisstopo',profileMethod:'loaded-native-road',
        coordinates:way().geometry.map(q=>({longitude:q.lon,latitude:q.lat,height:532.6}))};
    const p=fixture({cachedOnly:true,reuseFlightDeck:true,isNavigationActive:()=>true,getDeckTileset:()=>selected,
        invalidateDiscovery:()=>invalidations++,discoverBridges:async()=>({bridges:available?[profile]:[],piers:[]})});
    p.manager.setEnabled(true);p.manager.setDiagnosticsEnabled(true);
    try{
        await p.manager.refresh(ORIGIN);const first=p.primitives[0],before=p.manager.status().supports,prior=invalidations;
        assert.equal(before.length,5);available=false;
        for(let i=0;i<25;i++){
            p.manager.invalidateVisualPicking();p.manager.setSourceFeatures([],{sourceId:'aviation-obstacles'});
        }
        p.setClock(20000);await p.manager.refresh(ORIGIN);
        assert.equal(invalidations,prior);assert.equal(p.primitives[0],first);assert.deepEqual(p.manager.status().supports,before);
        assert.equal(p.manager.diagnostics().deckVisualInvalidations,25);
        const feature={type:'Feature',id:'other',geometry:{type:'LineString',coordinates:way().geometry.map(q=>[q.lon,q.lat+.002,540])},
            properties:{bridge:'yes',highway:'primary',elevationReference:'EPSG:4979'}};
        p.manager.setSourceFeatures([feature],{sourceId:'aviation-obstacles'});await p.manager.refresh(ORIGIN);
        assert.equal(p.manager.status().count,10);
        p.manager.setSourceFeatures([],{sourceId:'aviation-obstacles'});await p.manager.refresh(ORIGIN);
        assert.deepEqual(p.manager.status().supports,before);assert.equal(invalidations,prior);
    }finally{p.manager.dispose();}
});

test('native station transform remains fixed until a genuinely new observation corroborates a height change',async()=>{
    const selected={show:true};let height=532.6,observedAt=10000;
    const profile=()=>{const q={...ORIGIN,height,observedAt,station:4};return {id:'chunk',sourceId:'uuid',source:'swisstopo',nativeStationKey:'road',
        profileMethod:'loaded-native-road',coordinates:way().geometry.map(p=>({longitude:p.lon,latitude:p.lat,height})),
        nativeStations:[{...q,probes:[q,q,q]}]};};
    const p=fixture({cachedOnly:true,reuseFlightDeck:true,isNavigationActive:()=>true,getDeckTileset:()=>selected,
        discoverBridges:async()=>({bridges:[profile()],piers:[]})});
    p.manager.setEnabled(true);p.manager.setDiagnosticsEnabled(true);
    try{
        await p.manager.refresh(ORIGIN);const first=p.primitives[0],before=p.manager.status().supports;
        assert.equal(before.length,1);height=539;observedAt=20000;p.setClock(20000);await p.manager.refresh(ORIGIN);
        assert.equal(p.primitives[0],first);assert.deepEqual(p.manager.status().supports,before);
        p.setClock(30000);await p.manager.refresh(ORIGIN);assert.equal(p.primitives[0],first,'same cached observation cannot confirm a correction');
        observedAt=40000;p.setClock(40000);await p.manager.refresh(ORIGIN);
        assert.notEqual(p.primitives[0],first);assert.ok(Math.abs(p.manager.status().supports[0].top-538.9)<1e-9);
        height=539.1;observedAt=50000;p.setClock(50000);const corrected=p.primitives[0];await p.manager.refresh(ORIGIN);
        assert.equal(p.primitives[0],corrected,'sub-decimetre LOD drift must not rebuild the geometry');
    }finally{p.manager.dispose();}
});

test('V7 retains identified native stations beyond old TTL and re-admits them after leaving the area',async()=>{
    const selected={show:true};let present=true,commits=0;const q={...ORIGIN,height:532.6,observedAt:10000,station:4};
    const profile={id:'chunk',sourceId:'uuid',source:'swisstopo',nativeStationKey:'road',nativeIdentified:true,
        profileMethod:'loaded-native-road',coordinates:way().geometry.map(p=>({longitude:p.lon,latitude:p.lat,height:q.height})),
        nativeStations:[{...q,probes:[q,q,q]}]};
    const p=fixture({cachedOnly:true,reuseFlightDeck:true,sessionReuse:true,commitNative:()=>commits++,isNavigationActive:()=>true,getDeckTileset:()=>selected,
        discoverBridges:async()=>({bridges:present?[profile]:[],piers:[]})});
    p.manager.setEnabled(true);p.manager.setDiagnosticsEnabled(true);
    try{
        await p.manager.refresh(ORIGIN);const initial=p.manager.status().supports,hash=p.manager.diagnostics().supportTransformHash;
        assert.equal(initial.length,1);assert.ok(commits>0);present=false;p.setClock(900000);await p.manager.refresh(ORIGIN);
        assert.deepEqual(p.manager.status().supports,initial);assert.equal(p.manager.diagnostics().supportTransformHash,hash);
        p.setClock(920000);await p.manager.refresh({...ORIGIN,longitude:ORIGIN.longitude+.03});assert.equal(p.manager.status().count,0);
        p.setClock(940000);await p.manager.refresh(ORIGIN);assert.deepEqual(p.manager.status().supports,initial);
        p.manager.invalidateDeckCache();p.setClock(960000);await p.manager.refresh(ORIGIN);assert.equal(p.manager.status().count,0);
    }finally{p.manager.dispose();}
});


test('session retention uses a bounded hysteresis and a frustum-aware outer limit for existing piers',async()=>{
    const selected={show:true};let present=true,visible=true;
    const q={...ORIGIN,height:532.6,observedAt:10000,station:4};
    const profile={id:'chunk',sourceId:'uuid',source:'swisstopo',nativeStationKey:'road',nativeIdentified:true,
        profileMethod:'loaded-native-road',coordinates:way().geometry.map(p=>({longitude:p.lon,latitude:p.lat,height:q.height})),
        nativeStations:[{...q,probes:[q,q,q]}]};
    const p=fixture({cachedOnly:true,reuseFlightDeck:true,sessionReuse:true,isNavigationActive:()=>true,getDeckTileset:()=>selected,
        discoverBridges:async()=>({bridges:present?[profile]:[],piers:[]})});
    p.C.BoundingSphere=class {constructor(center,radius){Object.assign(this,{center,radius});}};
    p.C.Intersect={OUTSIDE:-1};p.viewer.camera.frustum={computeCullingVolume:()=>({computeVisibility:()=>visible?1:-1})};
    p.manager.setEnabled(true);p.manager.setDiagnosticsEnabled(true);
    const center=meters=>({...ORIGIN,longitude:point(meters).lon});
    try{
        await p.manager.refresh(ORIGIN);const initial=p.manager.status().supports;assert.equal(initial.length,1);
        present=false;visible=false;p.setClock(20000);await p.manager.refresh(center(800));
        assert.deepEqual(p.manager.status().supports,initial,'hysteresis prevents flickering at the discovery boundary');
        visible=true;p.setClock(30000);await p.manager.refresh(center(1000));
        assert.deepEqual(p.manager.status().supports,initial,'in-frustum support retained outside the hysteresis radius');
        p.setClock(40000);await p.manager.refresh(center(1300));assert.equal(p.manager.status().count,0);
        p.setClock(50000);await p.manager.refresh(center(1000));assert.equal(p.manager.status().count,0,'outer ring never admits inactive geometry');
        p.setClock(60000);await p.manager.refresh(ORIGIN);assert.deepEqual(p.manager.status().supports,initial);
        visible=false;p.setClock(70000);await p.manager.refresh(center(1000));assert.equal(p.manager.status().count,0);
    }finally{p.manager.dispose();}
});

test('short signature hits receive a bounded independent deck recheck and can become session confirmations',async()=>{
    const p=deckFixture({reuseFlightDeck:true,sessionReuse:true,isNavigationActive:()=>true});
    try{
        await p.manager.refresh(ORIGIN);const initial=p.excluded.length;assert.equal(initial,15);
        assert.equal(p.manager.diagnostics().deckConfirmedEntries,0);
        p.setClock(30000);await p.manager.refresh(ORIGIN);
        assert.equal(p.manager.diagnostics().deckIndependentRechecks,2);
        assert.equal(p.excluded.length,initial+6);assert.equal(p.manager.diagnostics().deckConfirmedEntries,2);
        p.setClock(40000);await p.manager.refresh(ORIGIN);
        assert.equal(p.manager.diagnostics().deckConfirmedEntries,4);
        p.setClock(50000);await p.manager.refresh(ORIGIN);assert.equal(p.manager.diagnostics().deckConfirmedEntries,5);
        const before=p.excluded.length;p.setClock(900000);await p.manager.refresh(ORIGIN);
        assert.equal(p.excluded.length,before,'independent confirmations survive the old TTL');
        p.manager.invalidateDeckCache();p.setClock(920000);await p.manager.refresh(ORIGIN);
        assert.equal(p.manager.diagnostics().deckConfirmedEntries,0);assert.equal(p.excluded.length,before+15);
    }finally{p.manager.dispose();}
});
