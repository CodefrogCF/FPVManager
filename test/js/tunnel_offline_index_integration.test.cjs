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
