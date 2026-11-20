(function(root,factory){
    const api=factory();
    if(typeof module==='object'&&module.exports)module.exports=api;
    else root.FPVEnvironmentalWind=api;
})(typeof globalThis!=='undefined'?globalThis:this,function(){
    'use strict';
    // Simulation-only environmental wind. Local model data is authoritative in
    // its footprint; extrapolation, gusts and orographic effects are estimates.
    const rad=Math.PI/180,metersPerDegree=111320,zero={north:0,east:0,up:0};
    const clamp=(v,lo,hi)=>Math.max(lo,Math.min(hi,v));
    const smooth=t=>{t=clamp(t,0,1);return t*t*(3-2*t);};
    const defaults=Object.freeze({regionalTransitionMeters:3000,regionalVariation:.12,
        altitudeShearExponent:.12,veerDegreesPerKm:2,gustSpeedMs:0,
        turbulenceIntensity:0,ridgeLift:false,leeTurbulence:false,
        fallbackSpeedMs:0,fallbackFromDegrees:270,terrainProbeMeters:140,seed:17});
    function configuration(raw={}){
        if(!raw||typeof raw!=='object'||Array.isArray(raw))throw Error('Invalid environmental wind settings');
        for(const key of Object.keys(raw))
            if(!Object.hasOwn(defaults,key))throw Error(`Unknown wind ${key}`);
        const next={...defaults,...raw};
        const bounds={regionalTransitionMeters:[100,20000],regionalVariation:[0,.5],
            altitudeShearExponent:[0,.5],veerDegreesPerKm:[-15,15],gustSpeedMs:[0,25],
            turbulenceIntensity:[0,1],fallbackSpeedMs:[0,40],fallbackFromDegrees:[0,360],
            terrainProbeMeters:[50,500],seed:[0,1000000]};
        for(const [key,[lo,hi]] of Object.entries(bounds))
            if(!Number.isFinite(next[key])||next[key]<lo||next[key]>hi)throw Error(`Invalid wind ${key}`);
        for(const key of ['ridgeLift','leeTurbulence'])
            if(typeof next[key]!=='boolean')throw Error(`Invalid wind ${key}`);
        return next;
    }
    function fromDegrees(speed,from){return {north:-speed*Math.cos(from*rad),east:-speed*Math.sin(from*rad),up:0};}
    const finiteVector=v=>v&&['north','east'].every(k=>Number.isFinite(v[k]))&&Math.hypot(v.north,v.east)<=100;
    // A bounded sample interface. No network, randomness, frame time or terrain
    // loading is performed by the provider. Time is simulated elapsed seconds.
    function createProvider({sampleLocal,terrainHeight=()=>undefined,maxTerrainCache=128}={}){
        if(typeof sampleLocal!=='function'||typeof terrainHeight!=='function')throw Error('Missing wind providers');
        let data=null,settings=configuration(),terrainCache=new Map(),terrainCalls=0;
        const cap=clamp(Math.trunc(maxTerrainCache)||128,8,256);
        function configure(field,raw={}){settings=configuration(raw);data=field??null;terrainCache.clear();terrainCalls=0;}
        function terrain(latitude,longitude){
            const latitudeBin=Math.round(latitude*metersPerDegree/60);
            const longitudeBin=Math.round(longitude*metersPerDegree*Math.max(.1,Math.cos(latitude*rad))/60);
            const key=`${latitudeBin}:${longitudeBin}`;
            if(terrainCache.has(key))return terrainCache.get(key);
            const value=terrainHeight(latitude,longitude);terrainCalls++;
            const result=Number.isFinite(value)?value:null;
            if(terrainCache.size>=cap)terrainCache.delete(terrainCache.keys().next().value);
            terrainCache.set(key,result);return result;
        }
        function localAt(latitude,longitude,agl){return data?sampleLocal(data,latitude,longitude,agl):null;}
        function sample(point){
            if(!point||!Number.isFinite(point.latitude)||!Number.isFinite(point.longitude)||
                Math.abs(point.latitude)>85||Math.abs(point.longitude)>180)return null;
            const agl=Number.isFinite(point.agl)?clamp(point.agl,0,50000):80;
            const time=Number.isFinite(point.timeSeconds)?point.timeSeconds:0;
            const local=data?localAt(point.latitude,point.longitude,agl):null;
            let outside=Infinity,edge=local,anchor=null;
            if(data){
                const lat=clamp(point.latitude,data.south,data.north);
                const lon=clamp(point.longitude,data.west,data.east);
                const north=(point.latitude-lat)*metersPerDegree;
                const east=(point.longitude-lon)*metersPerDegree*Math.max(.1,Math.cos(point.latitude*rad));
                outside=Math.hypot(north,east);
                if(!local)edge=localAt(lat,lon,agl);
                anchor=localAt(data.centerLatitude,data.centerLongitude,agl);
                if(!anchor){
                    // Sparse grids can have missing levels: prefer any usable
                    // node rather than fabricating a calm pocket.
                    for(const node of data.nodes){
                        if(node.levels.length){anchor=localAt(node.latitude,node.longitude,agl);if(anchor)break;}
                    }
                }
            }
            const fallback=fromDegrees(settings.fallbackSpeedMs,settings.fallbackFromDegrees);
            const base=finiteVector(anchor)?anchor:fallback;
            // Regional continuation is not a remote weather forecast: it uses
            // the nearest valid local level (or explicitly configured fallback).
            const verticalReference=data?180:80;
            const shear=clamp(Math.pow(Math.max(10,agl)/verticalReference,settings.altitudeShearExponent),.5,2);
            const angle=clamp((agl-verticalReference)/1000,-1,20)*settings.veerDegreesPerKm*rad;
            const cos=Math.cos(angle),sin=Math.sin(angle),n=base.north*shear,e=base.east*shear;
            const kmN=(point.latitude-(data?.centerLatitude??0))*metersPerDegree/1000;
            const kmE=(point.longitude-(data?.centerLongitude??0))*metersPerDegree*Math.max(.1,Math.cos(point.latitude*rad))/1000;
            const variation=1+settings.regionalVariation*(.65*Math.sin(kmN/17+settings.seed*.013)+.35*Math.sin(kmE/23-settings.seed*.011));
            const region={north:(n*cos-e*sin)*variation,east:(n*sin+e*cos)*variation,up:0};
            const weight=data?smooth(outside/settings.regionalTransitionMeters):1;
            const localVector=finiteVector(edge)?edge:region;
            let north=localVector.north*(1-weight)+region.north*weight;
            let east=localVector.east*(1-weight)+region.east*weight;
            let up=0;
            // Continuous deterministic functions of world position and simulated
            // time: never Math.random(), Date.now(), or rendering frame count.
            const phase=settings.seed*.061+kmN*.009+kmE*.013;
            const gust=Math.sin(time*.65+phase)*.7+Math.sin(time*1.43+phase*.53)*.3;
            const speed=Math.hypot(north,east);
            if(speed>1e-6&&settings.gustSpeedMs){
                const magnitude=settings.gustSpeedMs*gust;
                north+=north/speed*magnitude-east/speed*magnitude*.2;
                east+=east/speed*magnitude+north/speed*magnitude*.2;
            }
            if(settings.turbulenceIntensity){
                const t=settings.turbulenceIntensity;
                north+=t*2.5*Math.sin(time*2.31+kmE*.2+phase);
                east+=t*2.5*Math.sin(time*1.91+kmN*.23-phase*1.3);
                up+=t*1.2*Math.sin(time*1.73+phase*.81);
            }
            let terrainAvailable=false;
            if((settings.ridgeLift||settings.leeTurbulence)&&Number.isFinite(point.agl)&&point.agl<500&&speed>.5){
                const len=Math.hypot(north,east);
                if(len>.1){
                    const d=settings.terrainProbeMeters;
                    const dn=north/len*d/metersPerDegree;
                    const de=east/len*d/(metersPerDegree*Math.max(.1,Math.cos(point.latitude*rad)));
                    const center=terrain(point.latitude,point.longitude);
                    const incoming=terrain(point.latitude-dn,point.longitude-de);
                    const outgoing=terrain(point.latitude+dn,point.longitude+de);
                    if([center,incoming,outgoing].every(Number.isFinite)){
                        terrainAvailable=true;
                        const exposure=smooth((500-point.agl)/450);
                        if(settings.ridgeLift){
                            const rise=clamp((center-incoming)/d,0,.7);
                            up+=clamp(len*rise*.55*exposure,0,8);
                        }
                        if(settings.leeTurbulence){
                            const fall=clamp((center-outgoing)/d,0,.7);
                            up-=clamp(len*fall*.32*exposure,0,5);
                            // Lee-side roughness is spatially and temporally
                            // correlated, not a per-frame random impulse.
                            const wake=fall*settings.turbulenceIntensity*3*exposure;
                            north+=wake*Math.sin(time*3.1+phase*3);
                            east+=wake*Math.cos(time*2.7-phase*2);
                        }
                    }
                }
            }
            // The caller already validates finite wind vectors. Clamp here as
            // an additional safety boundary even for extreme user presets.
            const magnitude=Math.hypot(north,east,up);
            if(magnitude>90){const scale=90/magnitude;north*=scale;east*=scale;up*=scale;}
            const source=local&&outside<1e-6?'local':data?'regional-estimate':'fallback';
            return {north,east,up,speedMs:Math.hypot(north,east,up),enabled:true,available:true,
                source,approximate:source!=='local'||!!local?.extrapolated||!!(settings.gustSpeedMs||settings.turbulenceIntensity||settings.ridgeLift||settings.leeTurbulence),
                extrapolated:source!=='local'||!!local?.extrapolated,
                terrainEstimated:terrainAvailable,altitudeEstimated:!Number.isFinite(point.agl),
                fallbackCalm:!data&&settings.fallbackSpeedMs===0};
        }
        return {configure,sample,stats:()=>({terrainCacheEntries:terrainCache.size,terrainCalls,maximumTerrainCache:cap}),
            settings:()=>({...settings})};
    }
    return {configuration,createProvider,defaults};
});
