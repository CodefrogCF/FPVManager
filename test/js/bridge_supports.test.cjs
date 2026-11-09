'use strict';
const test=require('node:test'),assert=require('node:assert/strict');
const B=require('../../web/bridge_supports.js');
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
