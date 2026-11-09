'use strict';
const test=require('node:test'),assert=require('node:assert/strict');
const B=require('../../web/bridge_supports.js');
const center={longitude:8.6,latitude:46.7};
const at=x=>[center.longitude+x/(111319.49*Math.cos(center.latitude*Math.PI/180)),center.latitude,532.6];
const profile={id:'bazl-bridge',sourceType:'BRIDGE',parts:[{kind:'LineString',elevated:true,coordinates:[at(-72),at(72)]}]};
const sourceOptions={sourceId:'aviation-obstacles',source:'BAZL aviation obstacles',elevationReference:'WGS84_ELLIPSOID'};
function fixture(options={}){
    class Value{constructor(value){Object.assign(this,value);}}
    const primitives=[],listeners=new Set(),requests=[];
    const C={CylinderGeometry:Value,GeometryInstance:Value,Primitive:Value,PerInstanceColorAppearance:Value,
        Cartesian3:{fromDegrees:(longitude,latitude,height)=>({longitude,latitude,height})},
        Cartographic:{fromDegrees:(longitude,latitude)=>({longitude,latitude})},
        Transforms:{eastNorthUpToFixedFrame:position=>({position})},
        Color:{fromBytes:(...v)=>v},ColorGeometryInstanceAttribute:{fromColor:color=>({color})},ShadowMode:{DISABLED:0}};
    const viewer={camera:{positionCartographic:{longitude:center.longitude*Math.PI/180,latitude:center.latitude*Math.PI/180,height:700}},
        scene:{globe:{},primitives:{get length(){return primitives.length;},get:i=>primitives[i],
            add:p=>{primitives.push(p);return p;},remove:p=>{const i=primitives.indexOf(p);if(i>=0)primitives.splice(i,1);}},
            preUpdate:{addEventListener:f=>{listeners.add(f);return()=>listeners.delete(f);}},requestRender(){}}};
    const manager=B.create(C,viewer,{cachedOnly:true,getDeckTileset:()=>null,
        yieldBatch:async()=>{},
        fetcher:async(...args)=>{requests.push(args);throw Error('Unexpected request');},
        sampleTerrain:async points=>points.map(()=>500),...options});
    return {manager,viewer,primitives,requests};
}
test('cached BAZL bridge profile produces piers without a structures mesh or network',async()=>{
    const f=fixture();
    try{
        f.manager.setSourceFeatures([profile],sourceOptions);
        const state=await f.manager.refresh(center);
        assert.equal(state.count,5);assert.equal(state.sourceCount,1);
        assert.equal(f.requests.length,0);
        assert.ok(state.supports.every(p=>p.bottom===499.7&&Math.abs(p.top-532.5)<1e-8));
        assert.ok(state.supports.every(p=>p.heightMethod==='source-profile-estimate'));
        f.manager.setEnabled(false);assert.equal(f.manager.status().count,5,'source visibility controls its own piers');
        f.manager.setSourceFeatures([],{...sourceOptions,visible:false});
        assert.equal(f.manager.status().count,0);assert.equal(f.primitives.length,0);
    }finally{f.manager.dispose();}
});
test('BAZL bridge after more than 512 other obstacles is still available; unclassified or unknown datum heights are excluded',()=>{
    const others=Array.from({length:700},(_,i)=>({...profile,id:`cable-${i}`,sourceType:'TRANSMISSION_LINE'}));
    assert.equal(B.parseSourceFeatures([...others,profile],sourceOptions).bridges.length,1);
    assert.equal(B.parseSourceFeatures([profile],{sourceId:'unknown'}).bridges.length,0);
    assert.equal(B.parseSourceFeatures([{...profile,supportOnly:true}],sourceOptions).bridges.length,0);
});
test('native elevated bridge outlines preserve their longitudinal source height profile',()=>{
    const a=at(-72),b=at(72),lat=0.00004;
    const polygon={...profile,parts:[{kind:'PolygonOuter',elevated:true,coordinates:[
        [a[0],a[1]-lat,531],[b[0],b[1]-lat,534],[b[0],b[1]+lat,534],[a[0],a[1]+lat,531],[a[0],a[1]-lat,531]]}]};
    const data=B.parseSourceFeatures([polygon],sourceOptions);
    assert.equal(data.bridges.length,1);
    const height=data.bridges[0].coordinates.map(p=>p.height).sort((a,b)=>a-b);
    assert.ok(Math.abs(height[0]-531)<1e-8&&Math.abs(height[1]-534)<1e-8);
});
test('mapped bridge:support positions take precedence over guessed spacing and exclude marine piers',()=>{
    const p=at(17),data=B.parseBridgeData({elements:[
        {type:'way',id:1,tags:{bridge:'yes',highway:'primary'},geometry:[at(-72),at(72)].map(a=>({lon:a[0],lat:a[1]}))},
        {type:'node',id:2,tags:{'bridge:support':'pier'},lon:p[0],lat:p[1]},
        {type:'node',id:3,tags:{man_made:'pier'},lon:center.longitude,lat:center.latitude}]});
    const stations=B.stations(data.bridges,center,96,data.piers);
    assert.equal(data.piers.length,1);assert.equal(stations.length,1);
    assert.equal(stations[0].longitude,p[0]);assert.equal(stations[0].mapped,true);
});
test('mapped heights can render a standalone pier without guessing an absolute height datum',async()=>{
    const f=fixture();
    try{
        f.manager.setSourceFeatures([{type:'Feature',id:'pier',properties:{'bridge:support':'pier',height:'20 m'},
            geometry:{type:'Point',coordinates:at(0).slice(0,2)}}],{sourceId:'mapped',source:'OpenStreetMap'});
        const state=await f.manager.refresh(center);
        assert.equal(state.count,1);assert.equal(state.mappedCount,1);
        assert.equal(state.supports[0].heightMethod,'mapped-height-estimate');
        assert.equal(state.supports[0].top,519.9);
    }finally{f.manager.dispose();}
});
test('OSM query requests canonical mapped supports and refines cached source deck samples',async()=>{
    const f=fixture({cachedOnly:false,getDeckTileset:()=>({}),fetcher:async url=>{
        f.requests.push(String(url));return {ok:true,json:async()=>({elements:[
            {type:'way',id:1,tags:{bridge:'yes',highway:'primary'},geometry:[at(-72),at(72)].map(a=>({lon:a[0],lat:a[1]}))},
            {type:'node',id:2,tags:{'bridge:support':'pier'},lon:at(17)[0],lat:center.latitude}]})};}});
    f.viewer.scene.sampleHeight=()=>532.6;
    try{
        f.manager.setEnabled(true);await f.manager.refresh(center);
        assert.match(decodeURIComponent(f.requests[0]),/bridge:support/);
        assert.equal(f.manager.status().mappedCount,1);assert.equal(f.manager.status().count,1);
    }finally{f.manager.dispose();}
});
test('missing resident bridge tiles can be resolved by bounded most-detailed sampling',async()=>{
    const f=fixture({cachedOnly:false,getDeckTileset:()=>({}),fetcher:async()=>({ok:true,json:async()=>({elements:[
        {type:'way',id:1,tags:{bridge:'yes',highway:'primary'},geometry:[at(-72),at(72)].map(a=>({lon:a[0],lat:a[1]}))}]})})});
    f.viewer.scene.sampleHeight=()=>undefined;let calls=0;
    f.viewer.scene.sampleHeightMostDetailed=async positions=>{calls++;assert.equal(positions.length,3);
        return positions.map(p=>({...p,height:532.6}));};
    try{f.manager.setEnabled(true);await f.manager.refresh(center);
        assert.equal(calls,5,'most-detailed work is bounded to one pier per request');assert.equal(f.manager.status().count,5);
    }finally{f.manager.dispose();}
});

test('hiding an OSINT bridge while its terrain loads cannot install late pillars',async()=>{
    let finish;
    const f=fixture({sampleTerrain:points=>new Promise(resolve=>{finish=()=>resolve(points.map(()=>500));})});
    try{
        f.manager.setSourceFeatures([profile],sourceOptions);
        const pending=f.manager.refresh(center);await new Promise(resolve=>setImmediate(resolve));
        assert.equal(typeof finish,'function');
        f.manager.setSourceFeatures([],{...sourceOptions,visible:false});
        finish();await pending;
        assert.equal(f.manager.status().sourceCount,0);assert.equal(f.manager.status().count,0);
        assert.equal(f.primitives.length,0);
    }finally{f.manager.dispose();}
});
