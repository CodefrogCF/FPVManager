const test=require('node:test'),assert=require('node:assert/strict');
const Wind=require('../../web/environmental_wind.js');
const {field,sample}=require('../../web/wind_field.js');
const {createSimulator,distance}=require('../../web/free_flight.js');
const rad=Math.PI/180;
function snapshot(){
    const latitude=46.7,longitude=8.4,radiusMeters=1500;
    const dy=radiusMeters/111320,dx=radiusMeters/(111320*Math.cos(latitude*rad));
    return field({mode:'current',source:'Open-Meteo',validAtUtc:'2026-11-20T20:00:00Z',
        retrievedUtc:'2026-11-20T20:00:00Z',expiresUtc:'2026-11-20T20:30:00Z',
        centerLatitude:latitude,centerLongitude:longitude,radiusMeters,
        nodes:Array.from({length:9},(_,i)=>({latitude:latitude+(Math.floor(i/3)-1)*dy,
            longitude:longitude+(i%3-1)*dx,levels:[10,80,120,180].map(agl=>({agl,
                speedMs:7+Math.floor(i/3)*2+(i%3)*.7+agl/100,
                fromDegrees:260+Math.floor(i/3)*7}))}))});
}
const point=(latitude,longitude,agl=80,timeSeconds=0)=>({latitude,longitude,agl,timeSeconds});
const provider=(terrainHeight)=>Wind.createProvider({sampleLocal:sample,...(terrainHeight?{terrainHeight}:{})});
const norm=v=>Math.hypot(v.north,v.east,v.up);
const difference=(a,b)=>Math.hypot(a.north-b.north,a.east-b.east,a.up-b.up);

test('environment interface validates physically bounded presets and never accepts non-finite inputs',()=>{
    for(const value of [{gustSpeedMs:Infinity},{turbulenceIntensity:-.01},{ridgeLift:1},
        {fallbackFromDegrees:361},{regionalTransitionMeters:0},{seed:NaN},{terrainProbeMeters:2000}])
        assert.throws(()=>Wind.configuration(value));
    assert.equal(provider().sample(point(120,8)),null);
    assert.equal(provider().sample(point(NaN,8)),null);
    assert.deepEqual(Wind.configuration().gustSpeedMs,0);
});

test('local bilinear model values stay authoritative when synthetic effects are off',()=>{
    const f=snapshot(),p=provider();p.configure(f);
    for(const latitude of [f.south,f.centerLatitude-.25*f.dy,f.centerLatitude,f.north])
        for(const longitude of [f.west,f.centerLongitude+.25*f.dx,f.east])
            for(const agl of [10,45,80,120,180]){
                const actual=p.sample(point(latitude,longitude,agl));
                const expected=sample(f,latitude,longitude,agl);
                assert.ok(difference(actual,expected)<1e-8);
                assert.equal(actual.source,'local');
            }
});

test('all four edges and corners blend continuously without sudden dead calm',()=>{
    const f=snapshot(),p=provider();p.configure(f);
    const edges=[
        [f.centerLatitude,f.east,0,1],
        [f.centerLatitude,f.west,0,-1],
        [f.north,f.centerLongitude,1,0],
        [f.south,f.centerLongitude,-1,0],
        [f.north,f.east,1,1],
    ];
    for(const [lat,lon,n,e] of edges){
        const previous=p.sample(point(lat-n/111320,lon-e/(111320*Math.cos(lat*rad))));
        const boundary=p.sample(point(lat,lon));
        const after=p.sample(point(lat+n/111320,lon+e/(111320*Math.cos(lat*rad))));
        assert.ok(difference(previous,boundary)<.1);
        assert.ok(difference(after,boundary)<.1);
        assert.ok(norm(after)>3);
        assert.equal(after.source,'regional-estimate');
    }
});

test('regional continuation changes smoothly over 150 km without leaving a calm band',()=>{
    const f=snapshot(),p=provider();p.configure(f,{regionalVariation:.3});
    const measurements=[];
    for(let km=0;km<=150;km+=.5){
        const w=p.sample(point(46.7+km/111.32,8.4,80));
        assert.equal(w.available,true);
        assert.ok(norm(w)>2);
        measurements.push(w);
    }
    assert.ok(difference(measurements[4],measurements.at(-1))>.1,'Large-scale flow should vary');
    for(let i=1;i<measurements.length;i++)assert.ok(difference(measurements[i-1],measurements[i])<.85,
        `Wind discontinuity at regional sample ${i}`);
});

test('regional vertical shear and veering remain smooth and report unknown AGL honestly',()=>{
    const f=snapshot(),p=provider();p.configure(f,{altitudeShearExponent:.3,veerDegreesPerKm:8});
    const latitude=46.7+25/111.32,longitude=8.4;
    const low=p.sample(point(latitude,longitude,80));
    const high=p.sample(point(latitude,longitude,2000));
    assert.ok(norm(high)>norm(low));
    assert.ok(difference(low,high)>1);
    for(let h=20;h<=2000;h+=20)assert.ok(difference(p.sample(point(latitude,longitude,h)),p.sample(point(latitude,longitude,h+1)))<.2);
    const estimated=p.sample(point(latitude,longitude,NaN));
    assert.equal(estimated.altitudeEstimated,true);assert.ok(Number.isFinite(norm(estimated)));
});

test('gusts and turbulence are repeatable for arbitrary sample order and continuous in time',()=>{
    const f=snapshot(),settings={gustSpeedMs:6,turbulenceIntensity:.75,seed:42};
    const a=provider(),b=provider();a.configure(f,settings);b.configure(f,settings);
    for(const time of [0,5,2,60,5,120]){
        const v=a.sample(point(46.7,8.4,120,time));
        assert.deepEqual(v,b.sample(point(46.7,8.4,120,time)));
        assert.ok(difference(v,a.sample(point(46.7,8.4,120,time+.001)))<.1);
    }
    assert.ok(difference(a.sample(point(46.7,8.4,120,1)),a.sample(point(46.7,8.4,120,8)))>1);
});

test('optional ridge updraft and lee downdraft use local height slope, never fabricate terrain',()=>{
    const f=snapshot(),s={ridgeLift:true,leeTurbulence:true,turbulenceIntensity:.3,terrainProbeMeters:140};
    // Flow points primarily east; the eastward ridge grows until the crest.
    const slope=provider((lat,lon)=>1000+(lon-8.4)*111320*Math.cos(lat*rad)*.23);
    slope.configure(f,s);
    const uphill=slope.sample(point(46.7,8.4,50,0));
    assert.ok(uphill.up>0,'Windward slope must yield positive vertical lift');
    assert.equal(uphill.terrainEstimated,true);
    const lee=provider((lat,lon)=>1000-(lon-8.4)*111320*Math.cos(lat*rad)*.23);
    lee.configure(f,s);
    const down=lee.sample(point(46.7,8.4,50,0));
    assert.ok(down.up<uphill.up);
    const missing=provider(()=>undefined);missing.configure(f,s);
    const noData=missing.sample(point(46.7,8.4,50));
    assert.equal(noData.terrainEstimated,false);
    assert.ok(Number.isFinite(norm(noData)));
    assert.equal(missing.stats().terrainCacheEntries,3);
});

test('terrain query cache is bounded while crossing multiple regions; disabling effects avoids probes',()=>{
    let calls=0;const f=snapshot(),p=provider(()=>{calls++;return 1500;});
    p.configure(f,{ridgeLift:true,leeTurbulence:true});
    for(let k=0;k<6000;k++){
        const w=p.sample(point(46.7+k/200000,8.4+k/100000,75,k/120));
        assert.ok(Number.isFinite(norm(w)));
    }
    assert.ok(p.stats().terrainCacheEntries<=128);assert.ok(calls<18000);
    p.configure(f,{ridgeLift:false,leeTurbulence:false});
    const before=calls;for(let k=0;k<500;k++)p.sample(point(46.7+k/100000,8.4,80,k/60));
    assert.equal(calls,before);
});

test('fallback assumptions are explicit when no local weather is available',()=>{
    const p=provider();p.configure(null,{fallbackSpeedMs:8,fallbackFromDegrees:90});
    const w=p.sample(point(46.7,8.4,80));
    assert.ok(Math.abs(w.east+8)<1.5);assert.equal(w.source,'fallback');
    p.configure(null,{fallbackSpeedMs:0,regionalVariation:0});
    assert.equal(p.sample(point(46.7,8.4)).fallbackCalm,true);
});

test('long-range deterministic sampling benchmark stays bounded without network or cache growth',()=>{
    const p=provider(),f=snapshot();p.configure(f,{regionalVariation:.35,gustSpeedMs:3,turbulenceIntensity:.5});
    const start=performance.now();let total=0;
    for(let i=0;i<30000;i++){
        const v=p.sample(point(46.7+(i%2000)/111320*50,8.4+(i%1300)/111320*20,10+(i%800),i/120));
        total+=v.north;
    }
    const duration=performance.now()-start;
    assert.ok(Number.isFinite(total));assert.equal(p.stats().terrainCacheEntries,0);
    assert.ok(duration<3000,`30k environmental samples took ${duration.toFixed(1)} ms`);
});

test('advanced flight measures airspeed against sampled environmental wind, not ground speed',async()=>{
    const f=snapshot(),p=provider();p.configure(f,{regionalVariation:.2,gustSpeedMs:2,seed:21});
    const start={latitude:46.7,longitude:8.4};
    const model=createSimulator({sampleHeight:async()=>1000,renderedHeight:()=>1000,
        captureCamera:()=>({heading:0}),restoreCamera:()=>{},applyPose:()=>{},
        isTerrainReady:()=>true,onState:()=>{},sampleWind:point=>p.sample(point)});
    await model.start({...start,flightMode:'acro',physicsModel:'advanced',agl:500},new AbortController().signal);
    const input={throttle:0,yaw:0,pitch:0,roll:0};model.flightInput(input);
    for(let i=0;i<240;i++)model.tick(1/60);
    const state=model.status();
    assert.ok(distance(start,state.position)>0);
    assert.ok(Math.abs(state.airspeedMetersPerSecond-state.speed)>.1);
    assert.equal(state.wind.available,true);
    assert.ok(state.speed<100&&Number.isFinite(state.height));
});

test('environmental wind leads to identical advanced flight trajectories at 30/60/120 render FPS',async()=>{
    const f=snapshot(),trajectories=[];
    for(const fps of [30,60,120]){
        const p=provider();p.configure(f,{gustSpeedMs:5,turbulenceIntensity:.4,regionalVariation:.25,
            ridgeLift:false,seed:123});
        const model=createSimulator({sampleHeight:async()=>1000,renderedHeight:()=>1000,
            captureCamera:()=>({heading:0}),restoreCamera:()=>{},applyPose:()=>{},
            isTerrainReady:()=>true,onState:()=>{},sampleWind:point=>p.sample(point)});
        await model.start({latitude:46.7,longitude:8.4,flightMode:'acro',physicsModel:'advanced',
            physicsStepHz:120,agl:500},new AbortController().signal);
        model.flightInput({throttle:.5,yaw:.05,pitch:.1,roll:.03});
        for(let step=0;step<fps*3;step++)model.tick(1/fps);
        const result=model.status();
        trajectories.push([result.position.latitude,result.position.longitude,result.height,result.speed,
            result.airspeedMetersPerSecond,result.wind.north,result.wind.east,result.wind.up]);
    }
    for(const v of trajectories)for(let i=0;i<v.length;i++)
        assert.ok(Math.abs(v[i]-trajectories[0][i])<1e-5,
            `Render-rate dependence in flight component ${i}`);
});
