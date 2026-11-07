const test = require('node:test');
const assert = require('node:assert/strict');
const Local = require('../../web/tunnel_offline_index.js');
const T = require('../../web/scene_environment.js').FPVTunnelInfrastructure;

function environment({indexDocument,online=false}={}) {
    const sent=[],requests=[],routes=[];
    const C={
        CustomDataSource:class {
            constructor(){this.entities={add(){}};}
        },
        Cartesian3:{fromDegreesArray:p=>p,fromDegrees:(...p)=>p,clone:p=>p},
        Cartographic:{fromDegrees:(...p)=>p},
        Math:{toDegrees:p=>p},
        Color:{ORANGE:'orange'},
        PolylineDashMaterialProperty:class{},
    };
    const viewer={camera:{setView(){},position:{},heading:0,pitch:0,roll:0},
        dataSources:{add(){},remove(){}},scene:{globe:{getHeight:()=>500},requestRender(){}}};
    const catalog=Local.create({fetcher:async()=>({ok:true,headers:{get:()=>null},
        text:async()=>JSON.stringify(indexDocument)})});
    const module=T.create(C,viewer,(name,data)=>sent.push({name,data}),{
        offlineIndex:catalog, isOnline:()=>online,
        fetcher:async url=>{requests.push(url);throw Error('Unexpected remote request');},
        onRoutes:found=>routes.push(found),now:()=>10000,
        setTimer:()=>1,clearTimer:()=>{},
    });
    return {module,requests,routes,sent};
}
const document={schemaVersion:1,generated:true,tileDegrees:.25,
    source:'OpenStreetMap (Geofabrik Switzerland extract)',
    snapshotDateUtc:'2026-11-06T00:00:00Z',
    routes:[[123,0,'tunnel','road','Tunnel example',[[8.2,46.6],[8.201,46.6]]]],
    tiles:{'9:4':[0]}};

test('fully offline app discovers bundled Swiss tunnel and sends no Overpass/GeoAdmin requests',async()=>{
    const f=environment({indexDocument:document});
    f.module.setAutomatic(true);
    const data=await f.module.scan({longitude:8.2,latitude:46.6});
    assert.equal(data.count,1);
    assert.equal(data.localIndex,true);
    assert.deepEqual(data.failedLayers,[]);
    assert.deepEqual(data.sourceLayers,[document.source]);
    assert.equal(f.requests.length,0);
    assert.equal(f.routes.at(-1)[0].id,'osm:123:0');
    assert.equal(f.sent.find(e=>e.name==='tunnel-routes-loaded').data.routes[0].coordinates,undefined);
    f.module.dispose();
});

test('a valid bundled catalogue with no nearby tunnel does not query live services',async()=>{
    const f=environment({indexDocument:document,online:true});
    f.module.setAutomatic(true);
    const data=await f.module.scan({longitude:6.9,latitude:46.2});
    assert.equal(data.count,0);
    assert.equal(data.incomplete,false);
    assert.equal(f.requests.length,0);
    f.module.dispose();
});

test('offline app rejects an ungenerated index explicitly instead of returning misleading zero tunnels',async()=>{
    const f=environment({indexDocument:{schemaVersion:1,generated:false}});
    f.module.setAutomatic(true);
    await assert.rejects(()=>f.module.scan({longitude:8.2,latitude:46.6}),/Offline tunnel catalogue unavailable/);
    assert.equal(f.requests.length,0);
    f.module.dispose();
});

test('bundled index returns more than 48 valid centerlines within the visible area',async()=>{
    const routes=Array.from({length:90},(_,i)=>[100000+i,0,'tunnel','road',`Tunnel ${i}`,
        [[8.2+i*.000001,46.6],[8.201+i*.000001,46.6]]]);
    const full={...document,routes,tiles:{'9:4':routes.map((_,i)=>i)}};
    const f=environment({indexDocument:full});
    f.module.setAutomatic(true);
    const data=await f.module.scan({longitude:8.2,latitude:46.6});
    assert.equal(data.count,90);
    assert.equal(f.routes.at(-1).length,90);
    assert.equal(f.requests.length,0);
    f.module.dispose();
});


test('flying corridor prefetch reads bundled index without changing the separate centerline overlay',async()=>{
    const f=environment({indexDocument:document});
    f.module.setAutomatic(true);
    const loaded=await f.module.prefetchFlight({longitude:8.2005,latitude:46.6});
    assert.equal(loaded,true);
    assert.equal(f.requests.length,0,'prefetch must never contact Overpass/GeoAdmin');
    assert.equal(f.routes.at(-1)[0].id,'osm:123:0');
    assert.equal(f.module.status().count,0,'flight prefetch is not a manual line-overlay scan');
    assert.equal(await f.module.prefetchFlight({longitude:8.2005,latitude:46.6}),false,
        'same spatial cell is briefly throttled');
    f.module.dispose();
});

test('bundled index carries optional connected-road portal geometry without exposing it as surveyed heights',async()=>{
    const near=[[8.19995,46.6],[8.1999,46.6],[8.19985,46.6],[8.1998,46.6],[8.19975,46.6]];
    const full={...document,routes:[[123,0,'tunnel','road','Tunnel example',
        [[8.2,46.6],[8.201,46.6]],[near,null]]]};
    const catalog=Local.create({fetcher:async()=>({ok:true,headers:{get:()=>null},
        text:async()=>JSON.stringify(full)})});
    const found=await catalog.query([8.199,46.599,8.202,46.601]);
    assert.deepEqual(found.routes[0].roadApproaches,[near,null]);
    assert.equal(found.routes[0].endpointsVerified,false);
    assert.throws(()=>Local.verify({...full,routes:[[123,0,'tunnel','road','X',
        [[8.2,46.6],[8.201,46.6]],[[[8.2,46.6]],null]]]}),
        /Invalid connected-road approach/);
});

test('offline index preserves connected bridge approach provenance without inventing a deck height',async()=>{
    const near=[[8.19995,46.6],[8.1999,46.6],[8.19985,46.6],[8.1998,46.6],[8.19975,46.6]];
    const full={...document,routes:[[123,0,'tunnel','road','Bridge-connected portal',
        [[8.2,46.6],[8.201,46.6]],[near,null],['bridge',null]]]};
    const catalog=Local.create({fetcher:async()=>({ok:true,headers:{get:()=>null},
        text:async()=>JSON.stringify(full)})});
    const found=await catalog.query([8.199,46.599,8.202,46.601]);
    assert.deepEqual(found.routes[0].roadApproachKinds,['bridge',null]);
    assert.deepEqual(found.routes[0].roadApproaches,[near,null]);
    assert.equal(found.routes[0].heightReference,'unavailable');
    assert.throws(()=>Local.verify({...full,routes:[[123,0,'tunnel','road','X',
        [[8.2,46.6],[8.201,46.6]],[near,null],['unknown',null]]]}),
        /approach metadata/);
});


test('legacy index silently excludes fabricated tubes beneath free bridges',async()=>{
    const fakeId=1_000_000_000_001;
    const full={...document,routes:[
        [fakeId,0,'underpass','road','Possible underpass (OSM bridge crossing)',
            [[8.2,46.6],[8.201,46.6]]],
        [124,0,'underpass','road','Covered road (OSM tagged)',
            [[8.2,46.6],[8.201,46.6]]],
        [125,0,'tunnel','road','Real mapped tunnel',[[8.2,46.6],[8.201,46.6]]]],
        tiles:{'9:4':[0,1,2]}};
    const catalog=Local.create({fetcher:async()=>({ok:true,headers:{get:()=>null},
        text:async()=>JSON.stringify(full)})});
    const found=await catalog.query([8.199,46.599,8.202,46.601]);
    assert.deepEqual(new Set(found.routes.map(r=>r.id)),
        new Set(['osm:124:0','osm:125:0']));
});
