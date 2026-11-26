'use strict';
// Developer-only reference flight validation; no site-specific runtime code.
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const root = path.resolve(__dirname, '../../..');
const assetRoot = path.join(root, 'web/assets/scenery');
const Collision = require(path.join(root, 'web/features/scenery/scenery_collision.js'));
const Alignment = require(path.join(root, 'web/features/scenery/scenery_alignment.js'));
const RF = require(path.join(root, 'web/features/signal/rf_estimation.js'));
const sha = bytes => crypto.createHash('sha256').update(bytes).digest('hex');
function load(fixture) {
    const catalog = JSON.parse(fs.readFileSync(path.join(assetRoot, 'catalog.json'), 'utf8'));
    const site = catalog.sceneries.find(s => s.id === fixture.sceneryId);
    assert.ok(site && site.physicalCollisionsEnabled, 'Missing physical reference scenery');
    assert.equal(fixture.schemaVersion, 1);
    for (const [key, value] of Object.entries(fixture.alignment)) assert.equal(site.alignment[key], value, `Stale alignment: ${key}`);
    for (const [name, expected] of Object.entries(fixture.assetSha256)) {
        assert.match(name, /^[\w-]+\.(glb|fpc)$/);
        assert.equal(sha(fs.readFileSync(path.join(assetRoot, name))), expected, `Stale reference asset: ${name}`);
    }
    const bytes = fs.readFileSync(path.join(assetRoot, site.collisionAsset));
    const mesh = Collision.parse(bytes.buffer.slice(bytes.byteOffset, bytes.byteOffset + bytes.byteLength));
    const material = Collision.normalizeRf(fixture.rfProfile);
    assert.deepEqual(Collision.normalizeRf(site.rfMaterials?.[site.collisionAsset]), material);
    return {site, mesh, material};
}
function cesium() {
    const scope = {console,setTimeout,clearTimeout,URL,TextDecoder,TextEncoder,atob,btoa,TransformStream,ReadableStream,WritableStream,AbortController,Blob};
    scope.global = scope;
    return vm.runInNewContext(fs.readFileSync(path.join(root,'web/cesium/Cesium.js'),'utf8')+';Cesium',scope);
}
function geographicTransform(site, height) {
    assert.ok(Number.isFinite(height) && Math.abs(height-site.alignment.ellipsoidHeightM)<1000, 'Supply the verified effective root ellipsoid height in metres');
    const C = cesium(), a = {...site.alignment,ellipsoidHeightM:height};
    const matrix = Alignment.modelMatrix(C,a), inverse = Collision.transform(a);
    return point => {
        const position = C.Matrix4.multiplyByPoint(matrix, new C.Cartesian3(...point.map(v=>v*a.scale)),new C.Cartesian3());
        const p = C.Cartographic.fromCartesian(position);
        const geo = [C.Math.toDegrees(p.longitude),C.Math.toDegrees(p.latitude),p.height];
        const back = inverse.local({longitude:geo[0],latitude:geo[1],height:geo[2]});
        assert.ok(Math.hypot(...back.map((x,i)=>x-point[i]))*a.scale < 0.002,`Geographic round trip: ${JSON.stringify({point,back,geo})}`);
        return geo;
    };
}
function validate(fixture, state, height) {
    const {site,mesh,material} = state, scale=site.alignment.scale;
    const radius=fixture.clearanceRadiusM/scale, geo=geographicTransform(site,height);
    const features=[], spawns=[], checks=[];
    assert.ok(radius>0 && radius*scale<=2);
    for (const route of fixture.routes) {
        assert.ok(route.points.length>=2 && route.points.length<=1000 && route.speedMps>0 && route.speedMps<=200);
        const local=route.points;
        for (let i=0;i<local.length;i++) {
            assert.ok(local[i].length===3 && local[i].every(Number.isFinite));
            assert.equal(Collision.sweep(mesh,local[i],local[i],radius),null,`${route.id} waypoint ${i} intersects main mesh`);
            if(i) assert.equal(Collision.sweep(mesh,local[i-1],local[i],radius),null,`${route.id} segment ${i} intersects main mesh`);
        }
        const coordinates=local.map(geo);
        // Also test the geographic-coordinate interpolation chord in model coordinates
        // at short intervals (not a claim about curved playback trajectories).
        const frame=Collision.transform({...site.alignment,ellipsoidHeightM:height});
        for(let i=1;i<coordinates.length;i++) {
            const a=coordinates[i-1],b=coordinates[i], n=Math.max(1,Math.ceil(Math.hypot(...local[i].map((x,j)=>x-local[i-1][j]))*scale/10));
            let previous=local[i-1];
            for(let j=1;j<=n;j++) {
                const t=j/n, p=a.map((x,k)=>x+(b[k]-x)*t),next=frame.local({longitude:p[0],latitude:p[1],height:p[2]});
                assert.equal(Collision.sweep(mesh,previous,next,radius),null,`${route.id} interpolated segment ${i}/${j}`);previous=next;
            }
        }
        const feature={type:'Feature',properties:{name:route.name,fpvmanager:{version:1,waypoints:coordinates.map(p=>({height:{meters:p[2],reference:'wgs84Ellipsoid'},airspeedMetersPerSecond:route.speedMps}))}},geometry:{type:'LineString',coordinates}};
        features.push(feature);
        spawns.push({route:route.id,position:coordinates[0],meshClearanceRadiusM:fixture.clearanceRadiusM,scope:'main mesh only; verify rendered terrain and spawn behavior manually'});
        const result={id:route.id,segments:local.length-1,meshClear:true};
        if(route.station){
            assert.equal(Collision.sweep(mesh,route.station,route.station,radius),null,'station intersects main mesh');
            const station=geo(route.station), from={longitude:station[0],latitude:station[1],height:station[2]};
            result.rf=local.map((p,i)=>{
                const links={};
                for(const [name,frequency] of [['control',868],['video',5800]]) {
                    const trace=Collision.rfTrace(mesh,route.station,p,scale,frequency,.6,{nodes:8192,triangles:4096});
                    assert.ok(trace.complete,`${route.id} incomplete ${name} ${i}`);
                    assert.equal(trace.hits.length>0,route.expectedDirectHits[i],`${route.id} ${name} ${i}`);
                    const lossDb=Math.min(160,trace.hits.reduce((n,h)=>n+Collision.rfLoss(material,frequency,h.cosine),0)+(trace.fresnel&&!trace.hits.length?4:0));
                    links[name]={lossDb,complete:true,crossings:trace.hits.length,fresnel:trace.fresnel};
                }
                const g=coordinates[i],to={longitude:g[0],latitude:g[1],height:g[2]}, terrain={source:'sampledTerrain',confidence:'approximate',visibility:'clear',minimumClearanceMeters:10,minimumFresnelMarginMeters:10};
                const modeled=RF.assess(terrain,from,to,{...RF.defaults,control:{...RF.defaults.control,frequencyMhz:868},video:{...RF.defaults.video,frequencyMhz:5800}},links);
                const clear=RF.assess(terrain,from,to,{...RF.defaults,control:{...RF.defaults.control,frequencyMhz:868},video:{...RF.defaults.video,frequencyMhz:5800}});
                for(const key of ['controlLink','videoLink']) {
                    assert.ok(modeled[key].estimated);
                    if(route.expectedDirectHits[i]) assert.ok(modeled[key].linkMarginDb<clear[key].linkMarginDb);
                }
                // Deliberately weakened receiver profile for simulator training only.
                // Default short-range Crossfire may retain full quality behind this wall.
                const training=RF.assess(terrain,from,to,{...RF.defaults,controlScenario:'custom',control:{...RF.defaults.control,receiverThresholdDbm:-60}},links);
                assert.ok(route.expectedDirectHits[i]?training.controlLink.quality<.2:training.controlLink.quality>.5,'Training loss/recovery must be distinguishable');
                return {...links,controlQuality:modeled.controlLink.quality,videoQuality:modeled.videoLink.quality,trainingControlQuality:training.controlLink.quality};
            });
            result.station=station;
        }
        checks.push(result);
    }
    for(const probe of fixture.blockedProbes) assert.ok(Collision.sweep(mesh,...probe.points,radius),`${probe.id} unexpectedly clear`);
    return {routes:{type:'FeatureCollection',features},spawns,report:{schemaVersion:1,sceneryId:site.id,revision:fixture.revision,effectiveRootHeightM:height,meshTriangles:mesh.triangleCount,scope:'CPU main-mesh checks only; RF assumes clear synthetic terrain; no device, rendering, playback or survey verification',checks,blockedProbes:fixture.blockedProbes.map(p=>p.id)}};
}
function main(args) {
    const [fixturePath,mode,...rest]=args;
    if(!fixturePath||!['--check','--export'].includes(mode)|| (mode==='--check'&&rest.length)||(mode==='--export'&&rest.length!==2)) throw Error('Usage: node tool/scenery/reference/validate.cjs <fixture.json> --check | --export <effective-root-ellipsoid-m> <new-output-directory>');
    const fixture=JSON.parse(fs.readFileSync(fixturePath,'utf8')), state=load(fixture);
    const height=mode==='--check'?state.site.alignment.ellipsoidHeightM:Number(rest[0]);
    const result=validate(fixture,state,height);
    if(mode==='--export') {
        assert.ok(rest[0].trim(),'Explicit effective root height required');
        fs.mkdirSync(rest[1]); // never overwrite existing user files
        for(const [name,value] of [['routes.geojson',result.routes],['spawn-candidates.json',result.spawns],['validation.json',result.report]]) fs.writeFileSync(path.join(rest[1],name),JSON.stringify(value,null,2)+'\n',{flag:'wx'});
    }
    console.log(JSON.stringify(result.report,null,2));
}
if(require.main===module) main(process.argv.slice(2));
module.exports={load,validate,geographicTransform};
