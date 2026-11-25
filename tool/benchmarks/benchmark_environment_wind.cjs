#!/usr/bin/env node
'use strict';
// Synthetic, repeatable long-range environmental sampling benchmark (Node).
// Device GPU/terrain/WebView performance must also be tested on Android/Windows.
const {performance}=require('node:perf_hooks');
const environment=require('../../web/features/weather/environmental_wind.js');
const {field,sample}=require('../../web/features/weather/wind_field.js');
const rad=Math.PI/180,lat=46.7,lon=8.4,radiusMeters=5000;
const dy=radiusMeters/111320,dx=radiusMeters/(111320*Math.cos(lat*rad));
const model=field({mode:'current',source:'synthetic benchmark',
    validAtUtc:'2026-11-20T12:00:00Z',retrievedUtc:'2026-11-20T12:00:00Z',expiresUtc:'2026-11-20T12:30:00Z',
    centerLatitude:lat,centerLongitude:lon,radiusMeters,
    nodes:Array.from({length:9},(_,i)=>({latitude:lat+(Math.floor(i/3)-1)*dy,
        longitude:lon+(i%3-1)*dx,levels:[10,80,120,180].map(agl=>({agl,speedMs:11+(i%3),fromDegrees:275}))}))});
function measure(name,settings){
    let queries=0;
    const provider=environment.createProvider({sampleLocal:sample,terrainHeight:(latitude,longitude)=>{
        queries++;return 1200+latitude*350+longitude*100;
    }});
    provider.configure(model,settings);
    const count=100000,start=performance.now();let sum=0;
    for(let i=0;i<count;i++){
        const progress=(i%25000)/25000;
        const v=provider.sample({latitude:lat+progress*.9,longitude:lon+progress*.7,
            agl:35+i%350,timeSeconds:i/120});
        sum+=v.north+v.east+v.up;
    }
    const ms=performance.now()-start;
    console.log(`${name}: ${count} samples over ~100 km, ${ms.toFixed(1)} ms, `+
        `${(count/ms*1000).toFixed(0)} samples/s, terrain queries=${queries}, `+
        `cache=${provider.stats().terrainCacheEntries}/${provider.stats().maximumTerrainCache}; checksum=${sum.toFixed(3)}`);
}
measure('regional + gusts',{gustSpeedMs:4,turbulenceIntensity:.5});
measure('regional + terrain',{gustSpeedMs:4,turbulenceIntensity:.5,ridgeLift:true,leeTurbulence:true});
