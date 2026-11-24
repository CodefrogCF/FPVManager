#!/usr/bin/env node
'use strict';
// Offline adapter/cache fixture. IO latency is prescribed, not measured network performance.
const fs=require('node:fs'),path=require('node:path'),{performance}=require('node:perf_hooks');
const {createHash}=require('node:crypto');
const root=path.resolve(__dirname,'..');
const options=Object.fromEntries(process.argv.slice(2).map(arg=>{
    const m=/^--(baseline|out)=(.+)$/.exec(arg);
    if(!m)throw Error('Usage: node tool/benchmark_live_rf_reliability.cjs [--baseline=repo] [--out=report.json]');
    return [m[1],path.resolve(root,m[2])];
}));
const CNative=require(path.join(root,'web/cesium/index.cjs'));
const quantile=(values,p)=>values.length?[...values].sort((a,b)=>a-b)[Math.ceil(values.length*p)-1]:null;
const bytes=value=>Buffer.byteLength(JSON.stringify(value),'utf8');
class Clock {
    constructor(){this.now=0;this.next=1;this.tasks=new Map();}
    setTimeout=(fn,ms)=>{const id=this.next++;this.tasks.set(id,{at:this.now+ms,fn});return id;};
    clearTimeout=id=>this.tasks.delete(id);
    delay(ms){return new Promise(resolve=>this.setTimeout(resolve,ms));}
    async flush(){for(let i=0;i<80;i++)await Promise.resolve();}
    async run(promise){
        let finished=false,result,failure;
        promise.then(value=>{finished=true;result=value;},error=>{finished=true;failure=error;});
        for(let turns=0;!finished&&turns<10000;turns++){
            await this.flush();this.observeMemory?.();if(finished)break;
            const entry=[...this.tasks].sort((a,b)=>a[1].at-b[1].at||a[0]-b[0])[0];
            if(!entry)throw Error('Fixture stalled without a bounded timeout');
            this.now=Math.max(this.now,entry[1].at);this.tasks.delete(entry[0]);entry[1].fn();
        }
        if(!finished)throw Error('Fixture exceeded deterministic event budget');
        if(failure)throw failure;return result;
    }
    async bounded(work,signal){
        let timer,onAbort;
        const stop=new Promise((_,reject)=>{
            timer=this.setTimeout(()=>{const error=Error('Terrain request timed out');error.name='TerrainTimeoutError';reject(error);},12000);
            onAbort=()=>reject(signal.reason??Error('Terrain operation cancelled'));
            signal?.addEventListener('abort',onAbort,{once:true});if(signal?.aborted)onAbort();
        });
        try{return await Promise.race([Promise.resolve().then(work),stop]);}
        finally{this.clearTimeout(timer);signal?.removeEventListener('abort',onAbort);}
    }
}
function profile(distance,frame,rapid){
    const pilot={latitude:46.7,longitude:8.3},cos=Math.cos(pilot.latitude*Math.PI/180);
    const target={latitude:pilot.latitude+(rapid?Math.sin(frame*.8)*.0008:0),
        longitude:pilot.longitude+distance/(111195*cos)};
    // First-pass inputs equivalent in size to the existing near-field policy.
    const count=Math.min(256,Math.ceil(distance/5)+1);
    return Array.from({length:count},(_,i)=>({
        latitude:pilot.latitude+(target.latitude-pilot.latitude)*i/(count-1),
        longitude:pilot.longitude+(target.longitude-pilot.longitude)*i/(count-1)}));
}
function fixture(api,distance,{stuck=false,missing=false}={}){
    const clock=new Clock(),nodes=new Map(),level=17,scheme=new CNative.GeographicTilingScheme();
    const ridge=8.3+distance*.55/(111195*Math.cos(46.7*Math.PI/180));
    let tileRequests=0,interpolations=0,bulkCalls=0,logicalBatches=0,failCurrent=false;
    const provider={availability:{computeMaximumLevelAtPosition:()=>level},tilingScheme:scheme,
        requestTileGeometry(x,y,l){
            if(l!==level)throw Error('Requested terrain detail changed');
            tileRequests++;
            if(stuck&&tileRequests===1)return new Promise(()=>{});
            return clock.delay(80).then(()=>({interpolateHeight(_rectangle,lon,lat){
                interpolations++;
                if(failCurrent)return undefined;
                const degrees=lon*180/Math.PI;
                return 1000+800*Math.exp(-(((degrees-ridge)/.0015)**2))+25*Math.sin(lat*10000);
            }}));
        }};
    const C={Cartographic:CNative.Cartographic,sampleTerrainMostDetailed:async(_provider,points)=>{
        bulkCalls++;await clock.delay(80);
        return points.map(point=>({...point,height:failCurrent?undefined:1000+800*Math.exp(-(((point.longitude*180/Math.PI-ridge)/.0015)**2))}));
    }};
    const doc={getElementById(id){if(!nodes.has(id))nodes.set(id,{dataset:{},addEventListener(){}});return nodes.get(id);}};
    const instance=api.create({C,viewer:{},terrain:{provider,sample:(work,signal)=>{
        logicalBatches++;failCurrent=missing&&logicalBatches%7===0;
        return clock.bounded(()=>work(provider),signal);
    }},ready:()=>true,emit(){},layer:{clear(){},set(){},dispose(){}},doc,
        clock:()=>clock.now,wallClock:()=>100000+clock.now,
        sampleTimeoutMs:12000,timers:{setTimeout:clock.setTimeout,clearTimeout:clock.clearTimeout}});
    return {clock,instance,get metrics(){return {tileRequests,interpolations,bulkCalls,logicalBatches};}};
}
async function scenario(api,distance,motion,mode='healthy'){
    const gcAvailable=typeof global.gc==='function';
    if(gcAvailable)global.gc();
    const processHeap={beforeBytes:process.memoryUsage().heapUsed,sampledPeakBytes:0,endBytes:null,
        explicitGcBeforeAndAfter:gcAvailable};
    processHeap.sampledPeakBytes=processHeap.beforeBytes;
    const recordHeap=()=>{processHeap.sampledPeakBytes=Math.max(processHeap.sampledPeakBytes,process.memoryUsage().heapUsed);};
    const f=fixture(api,distance,{stuck:mode==='stuck-first-tile',missing:mode==='missing'});
    f.clock.observeMemory=recordHeap;recordHeap();
    const latencies=[],cpuTimes=[],failures=[],heightsHash=createHash('sha256');let successes=0,commandBytes=0,replyBytes=0,maxUnavailableMs=0,unavailableSince=null,firstAttemptLatency=null;
    const attempts=mode==='stuck-first-tile'?5:30;
    try{
        for(let frame=0;frame<attempts;frame++){
            f.clock.now=Math.max(f.clock.now,frame*2000);
            const command={positions:profile(distance,frame,motion==='rapid')};
            commandBytes+=bytes({type:'query-live-radio-terrain',...command});
            recordHeap();
            const started=f.clock.now,cpu=performance.now();
            try{
                const result=await f.clock.run(f.instance.sample(command,new AbortController().signal));
                if(result.heights.length!==command.positions.length||result.heights.some(h=>!Number.isFinite(h)))
                    throw Error('Fixture received an invalid successful profile');
                successes++;replyBytes+=bytes(result);latencies.push(f.clock.now-started);
                heightsHash.update(JSON.stringify(result.heights));
                if(unavailableSince!==null){maxUnavailableMs=Math.max(maxUnavailableMs,f.clock.now-unavailableSince);unavailableSince=null;}
            }catch(error){
                failures.push(String(error.message));replyBytes+=bytes({error:error.message});
                if(unavailableSince===null)unavailableSince=started;
            }
            cpuTimes.push(performance.now()-cpu);
            recordHeap();
            if(frame===0)firstAttemptLatency=f.clock.now-started;
        }
        if(unavailableSince!==null)maxUnavailableMs=Math.max(maxUnavailableMs,f.clock.now-unavailableSince);
        return {distanceM:distance,motion,mode,attempts,successes,samplingSuccessRate:successes/attempts,
            failedSamplingFrequency:failures.length/attempts,maxSamplingUnavailableIntervalMs:maxUnavailableMs,
            prescribedIoLatencyMs:{p50:quantile(latencies,.5),p95:quantile(latencies,.95),coldFirstAttempt:firstAttemptLatency,max:latencies.length?Math.max(...latencies):null},
            nodeFixtureCpuMs:{p50:quantile(cpuTimes,.5),p95:quantile(cpuTimes,.95)},
            processHeap,
            ...f.metrics,serializedPayloadBytes:{commands:commandBytes,replies:replyBytes},
            sampledHeightsSha256:heightsHash.digest('hex'),
            diagnostics:typeof f.instance.diagnostics==='function'?f.instance.diagnostics():null,
            errors:[...new Set(failures)]};
    }finally{
        f.instance.dispose();await f.clock.flush();recordHeap();
        if(gcAvailable)global.gc();
        processHeap.endBytes=process.memoryUsage().heapUsed;recordHeap();
    }
}
async function run(repo){
    const api=require(path.join(repo,'web/features/signal/live_radio.js')),scenarios=[];
    for(const distance of [1000,3000,6000])for(const motion of ['stationary','rapid'])
        scenarios.push(await scenario(api,distance,motion));
    scenarios.push(await scenario(api,3000,'rapid','missing'));
    scenarios.push(await scenario(api,3000,'rapid','stuck-first-tile'));
    return {scenarios};
}
(async()=>{
    const before=options.baseline?await run(options.baseline):null,after=await run(root);
    const comparisons=before?before.scenarios.map((original,index)=>({distanceM:original.distanceM,motion:original.motion,mode:original.mode,
        successfulHeightStreamsMatch:original.successes===after.scenarios[index].successes?original.sampledHeightsSha256===after.scenarios[index].sampledHeightsSha256:null})):null;
    if(comparisons?.some(item=>item.successfulHeightStreamsMatch===false))throw Error('Sampling fixture height output changed');
    const report={schemaVersion:1,kind:'synthetic',nodeVersion:process.version,recordedAtUtc:new Date().toISOString(),
        scope:'Live JS terrain sampling adapter/cache. Bundled Cesium coordinate/tiling math; analytic mock terrain interpolation and deterministic IO clock.',
        fixture:{attemptIntervalMs:2000,healthyAttempts:30,terrainLevel:17,tileIoLatencyMs:80,
            terrain:'1000–1825 m analytic ridge crossing each path; finite detailed heights',
            rapidMotion:'sinusoidal lateral endpoint movement, about70 m/s peak',
            missing:'all interpolation unavailable on every seventh uncached batch',
            stuck:'first tile never settles; all later requests healthy; existing12s terrain-manager bound modeled'},
        processHeapMeasurement:{source:'process.memoryUsage().heapUsed',explicitGcSupported:typeof global.gc==='function',
            sampling:'Before fixture; after fixture creation, virtual event turns and requests; after disposal/microtask draining. End measured after explicit GC when available.',
            limitation:'Sampled peak, not continuous peak. Includes fixture/promises, analytic tiles, reports and retained module allocations. Sequential process retention and GC noise prevent device-memory or improvement claims.'},
        unmeasured:['real network/device/GPU latency','end-to-end Flutter calculation latency','HUD UNKNOWN duration','application/device heap and GPU memory','bridge framing/transport time','RF/failsafe transitions'],
        ...(before?{before,comparisons}:{}),after};
    const output=JSON.stringify(report,null,2)+'\n';
    if(options.out){fs.mkdirSync(path.dirname(options.out),{recursive:true});fs.writeFileSync(options.out,output);}
    process.stdout.write(output);
})().catch(error=>{process.stderr.write(error.stack+'\n');process.exitCode=1;});
