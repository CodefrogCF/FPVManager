const test=require('node:test');
const assert=require('node:assert/strict');
const index=require('../../web/tunnel_offline_index.js');
const T=require('../../web/scene_environment.js').FPVTunnelInfrastructure;
const generated={schemaVersion:1,generated:true,tileDegrees:.25,
    source:'OpenStreetMap (Geofabrik Switzerland extract)',snapshotDateUtc:'2026-11-06T00:00:00Z',
    routes:[
        [123,0,'tunnel','road','Alpine tunnel',[[8.1,46.6],[8.35,46.6]]],
        [124,0,'underpass','railway','Covered railway',[[8.3,46.61],[8.32,46.61]]]],
    tiles:{'9:4':[0],'10:4':[0,1]},
};
const response=document=>({ok:true,headers:{get:()=>null},text:async()=>JSON.stringify(document)});

test('local tunnel index validates provenance and rejects unbuilt placeholder',()=>{
    assert.equal(index.verify(generated),generated);
    assert.throws(()=>index.verify({schemaVersion:1,generated:false}),/not generated/);
    assert.throws(()=>index.verify({...generated,routes:[[123,0,'tunnel','road','Bad',[[90,0],[8.1,46.6]]]]}),/Invalid coordinates/);
});

test('viewport query finds long tunnel intersecting region despite endpoints outside',async()=>{
    let requests=0;
    const local=index.create({fetcher:async()=>{requests++;return response(generated);}});
    const region=[8.26,46.58,8.28,46.62];
    const result=await local.query(region);
    assert.equal(result.routes.length,1);
    assert.equal(result.routes[0].id,'osm:123:0');
    assert.equal(result.routes[0].source,generated.source);
    assert.equal(result.routes[0].endpointsVerified,false);
    assert.equal(result.incomplete,false);
    await local.query(region);
    assert.equal(requests,1,'once loaded, the index stays in local memory');
});

test('empty area is a valid completed offline query, not a network failure',async()=>{
    const local=index.create({fetcher:async()=>response(generated)});
    assert.deepEqual((await local.query([6.2,46.0,6.21,46.01])).routes,[]);
});

test('index rejects malformed tile references before allowing discovery',async()=>{
    const local=index.create({fetcher:async()=>response({...generated,tiles:{'9:4':[200]}})});
    await assert.rejects(()=>local.query([8.1,46.6,8.11,46.61]),/Invalid tile lookup/);
});
