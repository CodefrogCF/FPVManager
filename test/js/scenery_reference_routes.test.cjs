'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const V = require('../../tool/scenery/reference/validate.cjs');
const fixture = require('../../tool/scenery/reference/ruedersdorf.json');
const Collision = require('../../web/features/scenery/scenery_collision.js');
const Playback = require('../../web/features/flight/flight_recording.js').routePlayback;
const Failsafe = require('../../web/features/signal/simulated_failsafe.js');
const state = V.load(fixture);
const height = state.site.alignment.ellipsoidHeightM;
const result = V.validate(fixture, state, height);

test('reference routes match the pinned physical mesh, current pose and generated GeoJSON fixture', () => {
    const expected = JSON.parse(fs.readFileSync(path.join(__dirname,'../fixtures/scenery/reference_ruedersdorf_routes.geojson'),'utf8'));
    // Independent Cesium/platform arithmetic can vary by a few last digits.
    assert.equal(result.routes.features.length,9);
    assert.equal(result.report.checks.reduce((n,x)=>n+x.segments,0),21);
    assert.equal(result.report.blockedProbes.length,3);
    for(let i=0;i<expected.features.length;i++){
        const a=result.routes.features[i], b=expected.features[i];
        assert.equal(a.properties.name,b.properties.name);
        assert.equal(a.geometry.coordinates.length,b.geometry.coordinates.length);
        a.geometry.coordinates.forEach((p,j)=>p.forEach((v,k)=>assert.ok(Math.abs(v-b.geometry.coordinates[j][k])<1e-5)));
        assert.deepEqual(a.properties.fpvmanager.waypoints.map(p=>p.airspeedMetersPerSecond),b.properties.fpvmanager.waypoints.map(p=>p.airspeedMetersPerSecond));
    }
    assert.equal(state.site.clipTerrain,false);
    assert.equal(state.site.surveyVerified,false);
});

test('changed source hash, alignment and intersecting reference paths fail instead of exporting', () => {
    assert.throws(()=>V.load({...fixture,assetSha256:{...fixture.assetSha256,'local_reference.fpc':'0'.repeat(64)}}),/Stale reference asset/);
    assert.throws(()=>V.load({...fixture,alignment:{...fixture.alignment,scale:2}}),/Stale alignment/);
    assert.throws(()=>V.validate({...fixture,routes:[{id:'negative',speedMps:1,points:fixture.blockedProbes[0].points}]},state,height),/intersects main mesh/);
    assert.throws(()=>V.geographicTransform(state.site,NaN),/effective root/);
});

test('exported absolute routes use the existing playback preparation and remain clear along its evaluated trajectory',async()=>{
    const frame=Collision.transform(state.site.alignment),radius=fixture.clearanceRadiusM/frame.scale;
    for(const feature of result.routes.features){
        const points=feature.geometry.coordinates.map(([longitude,latitude,heightMeters],i)=>({longitude,latitude,heightMeters,heightMode:'absolute',speedMetersPerSecond:feature.properties.fpvmanager.waypoints[i].airspeedMetersPerSecond}));
        const trajectory=await Playback.prepare({points,defaultSpeedMetersPerSecond:10,defaultAglMeters:20},()=>{throw Error('Absolute preparation must not query terrain');});
        assert.equal(trajectory.assumedHeight,false);assert.equal(trajectory.assumedSpeed,false);
        let previous=null;
        // Include all exact waypoint times, and evaluate at <=0.1 s intervals.
        const times=new Set(trajectory.points.map(p=>p.seconds));
        for(let t=0;t<trajectory.duration;t+=.1)times.add(t);
        for(const t of [...times].sort((a,b)=>a-b)){
            const p=frame.local(Playback.evaluate(trajectory,t));
            assert.equal(Collision.sweep(state.mesh,previous??p,p,radius),null,`${feature.properties.name} playback at ${t}`);
            previous=p;
        }
    }
});

test('reference wall shadow weakens default video and the deliberate training RC profile can trigger and recover a generic failsafe',()=>{
    const samples=result.report.checks.find(c=>c.id==='rf-recovery').rf;
    assert.ok(samples[2].videoMarginDb<samples[1].videoMarginDb);
    assert.ok(samples[2].videoQuality<=samples[1].videoQuality);
    assert.equal(samples[2].control.lossDb,17);
    assert.equal(samples[2].video.lossDb,29);
    assert.equal(samples[2].controlQuality,1,'default RC need not fail at short distance');
    const machine=Failsafe.create({enabled:true,mode:'hold',autoRecover:true,activationDelaySeconds:.6,recoveryDelaySeconds:.6});
    function step(sample){let s;for(let i=0;i<60;i++)s=machine.step(1/60,{controlLink:{quality:sample.trainingControlQuality,source:'rfModel'},videoLink:{quality:sample.videoQuality,source:'rfModel'}});return s;}
    assert.equal(step(samples[0]).phase,'normal');
    assert.equal(step(samples[2]).phase,'hold');
    assert.equal(step(samples[4]).phase,'normal');
    const rescue=Failsafe.create({enabled:true,mode:'gpsRescue',activationDelaySeconds:.1});
    const context={position:{latitude:52.48,longitude:13.79},home:{latitude:52.48,longitude:13.79},height:100,homeHeight:95,distanceToHome:5};
    let phase;for(let i=0;i<12;i++)phase=rescue.step(1/60,{controlLink:{quality:samples[2].trainingControlQuality,source:'rfModel'}},context).phase;
    assert.equal(phase,'rescueHold');
});

test('a different effective root height is reprojected without changing local clearance',()=>{
    const newHeight=height-16.9;
    const shifted=V.validate(fixture,state,newHeight);
    const before=result.spawns[2].position,after=shifted.spawns[2].position;
    assert.ok(Math.abs(after[2]-before[2]+16.9)<.002);
    assert.deepEqual(shifted.report.checks.map(c=>c.meshClear),result.report.checks.map(c=>c.meshClear));
});

test('both generic physics models stop a zero-throttle descent at the actual closed silo roof',async()=>{
    const {createSimulator}=require('../../web/features/flight/free_flight.js');
    const geo=V.geographicTransform(state.site,height), frame=Collision.transform(state.site.alignment);
    const [longitude,latitude,spawnHeight]=geo([4.79,-2.202,-.04]);
    const floor=spawnHeight-25; // deliberately synthetic terrain below the test roof
    for(const physicsModel of ['advanced','legacy']){
        let contacts=0;
        const sim=createSimulator({sampleHeight:async()=>floor,renderedHeight:()=>floor,captureCamera:()=>({heading:0}),restoreCamera(){},applyPose(){},isTerrainReady:()=>true,onState(){},modeledCollision:(a,b)=>{
            const hit=Collision.contact(state.mesh,frame,a,b,fixture.clearanceRadiusM);if(hit)contacts++;return hit;
        }});
        try{
            await sim.start({longitude,latitude,agl:25,flightMode:'acro',physicsModel},new AbortController().signal);
            sim.flightInput({throttle:0});for(let i=0;i<180;i++)sim.tick(1/60);
            assert.ok(contacts>0,`${physicsModel}: no physical roof contact`);
            assert.ok(sim.status().height>geo([4.79,-2.202,-.34])[2],`${physicsModel}: passed through roof`);
        }finally{sim.stop();}
    }
});
