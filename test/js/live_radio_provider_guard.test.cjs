'use strict';
const test = require('node:test'), assert = require('node:assert/strict');
const fs = require('node:fs'), path = require('node:path'), vm = require('node:vm');
const {createBridge} = require('../../web/core/globe_bridge.js');
const {create,verifier} = require('../../web/features/terrain/bkg_rf_height.js');
const globe = fs.readFileSync(path.join(__dirname, '../../web/globe.js'), 'utf8');
const helpers = globe.slice(globe.indexOf('    function rfOffsets('), globe.indexOf('    let sceneryCatalogReady'));
const clause = globe.match(/case 'query-live-radio-terrain': ([^\r\n]+)/);
assert.ok(clause);
const point = {longitude:13.79,latitude:52.484};
const fixture={schema:1,datum:'DHHN2016',provider:'https://sgx.geodatenzentrum.de/gdz_basemapde_3d_gelaende/dgm5_4326_mesh/',west:13.775,south:52.481,stepLon:.025,stepLat:.01,cols:2,rows:2,values:[38.9,38.8,38.9,38.8],controls:Array.from({length:8},(_,i)=>({longitude:13.78+i*.001,latitude:52.484,dhhn2016M:40}))};

test('local grid interpolates and converts each endpoint independently, fails closed outside coverage',()=>{
    const a=create(fixture), z=a.offset(point);
    assert.ok(a.available);assert.ok(Math.abs(z-38.84)<1e-8);
    const ray={...point,height:100,ground:80};
    const result=a.point(ray,1);assert.ok(Math.abs(result.height-138.84)<1e-8);
    assert.ok(Math.abs(a.point(result,-1).ground-80)<1e-8);
    assert.equal(ray.height,100);
    assert.equal(a.offset({longitude:13.79,latitude:52.47909}),null);
    assert.throws(()=>a.offsets([point,{longitude:13.405,latitude:52.52}]),/outside experimental/);
    assert.equal(create(null).available,false);assert.equal(create({...fixture,values:[1,2,3,4]}).available,false);
});

test('actual JSON bridge blocks missing and out-of-region BKG heights, converts prepared local terrain, leaves Swiss heights unchanged',async()=>{
    for(const [regionalTerrain,grid,positions,expected] of [
        [true,null,[point],null],[true,fixture,[{longitude:13.4,latitude:52.52}],null],
        [true,fixture,[point],[538.84]],[false,null,[point],[500]]]){
        let samples=0;const events=[];
        const liveRadio={sample:async command=>{samples++;assert.equal(command.generation,7);return {heights:[500],heightReference:'wgs84Ellipsoid'};}};
        const adapter=create(grid),provider={availability:true};
        const context={regionalTerrain,regionalTerrainRevision:0,regionalTerrainChanging:false,bkgRfHeight:adapter,bkgRfVerifier:verifier(adapter),liveRadio,Error,
            terrainManager:{provider,sample:fn=>fn(provider)},Cesium:{Cartographic:{fromDegrees:()=>({})},sampleTerrainMostDetailed:async(_p,points)=>points.map(()=>({height:40}))}};
        const execute=vm.runInNewContext(`${helpers}\n(command,signal)=>{${clause[1]}}`,context);
        const bridge=createBridge({sessionId:'provider-guard',execute,send:raw=>events.push(JSON.parse(raw))});
        try{
            bridge.receive(JSON.stringify({type:'query-live-radio-terrain',version:1,sessionId:'provider-guard',requestId:'36',generation:7,analysisRequestId:12,positions}));
            await new Promise(resolve=>setImmediate(resolve));
            const result=events.find(e=>e.type==='command-result');assert.ok(result);
            assert.equal(result.ok,expected!==null);
            assert.equal(samples,expected===null?0:1);
            if(expected)assert.ok(Math.abs(result.result.heights[0]-expected[0])<1e-8);
            else assert.match(result.error,/^TERRAIN_UNAVAILABLE:/);
        }finally{bridge.dispose();}
    }
});

test('provider revision change rejects in-flight profile; telemetry and scenery overlay share the conversion',async()=>{
    const emissions=[];let resolve;
    const adapter=create(fixture),provider={availability:true};
    const context={regionalTerrain:true,regionalTerrainRevision:0,regionalTerrainChanging:false,bkgRfHeight:adapter,bkgRfVerifier:verifier(adapter),liveRadio:{sample:()=>new Promise(r=>{resolve=r;})},sendToFlutter:(...a)=>emissions.push(a),Error,
        terrainManager:{provider,sample:fn=>fn(provider)},Cesium:{Cartographic:{fromDegrees:()=>({})},sampleTerrainMostDetailed:async(_p,points)=>points.map(()=>({height:40}))}};
    const api=vm.runInNewContext(`${helpers}\n({queryLiveRadioTerrain,emitRadioPosition,rfSceneCommand})`,context);
    const pending=api.queryLiveRadioTerrain({positions:[point]});await new Promise(r=>setImmediate(r));context.regionalTerrainRevision++;
    resolve({heights:[500]});await assert.rejects(pending,/regional terrain changed/);
    api.emitRadioPosition('flight-radio-position',{...point,active:true,paused:false,height:100});
    assert.ok(Math.abs(emissions[0][1].height-138.84)<1e-8);
    api.emitRadioPosition('flight-radio-position',{longitude:13.4,latitude:52.52,active:true,paused:false,height:100});
    assert.equal(emissions[1][1].height,null);assert.equal(emissions[1][1].rfHeightUnavailable,true);
    const command={pilot:{...point,height:138.84},rays:[{...point,height:138.84,ground:118.84}]};
    const converted=api.rfSceneCommand(command);assert.ok(Math.abs(converted.pilot.height-100)<1e-8);assert.ok(Math.abs(converted.rays[0].ground-80)<1e-8);
});

test('reference checks are shared, reject datum shifts, and retry only after cooldown or provider replacement',async()=>{
    let now=0,calls=0;const a=create(fixture),v=verifier(a,()=>now),p={};
    const good=async controls=>{calls++;return controls.map(c=>c.dhhn2016M);};
    await Promise.all([v.ensure(p,good),v.ensure(p,good)]);await v.ensure(p,good);assert.equal(calls,1);assert.equal(v.verified(p),true);
    const next={};const wrong=async controls=>{calls++;return controls.map(c=>c.dhhn2016M+39);};
    await assert.rejects(v.ensure(next,wrong),/height mismatch/);assert.equal(v.verified(next),false);
    await assert.rejects(v.ensure(next,good),/pending retry/);assert.equal(calls,2);now=10000;await v.ensure(next,good);assert.equal(calls,3);
});
