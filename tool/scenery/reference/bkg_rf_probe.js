/* Developer-only comparison; never grants runtime RF authorization. */
(function(root,factory){const api=factory();if(typeof module==='object'&&module.exports)module.exports=api;else root.FPVBkgRfProbe=api;})(typeof globalThis!=='undefined'?globalThis:this,function(){
    'use strict';
    function validate(input){
        if(!input||typeof input.source!=='string'||!input.source.trim()||!Array.isArray(input.controls)||input.controls.length<3||input.controls.length>64)
            throw Error('Provide a documented independent source and 3–64 controls');
        const seen=new Set();
        for(const p of input.controls){
            if(!p||![p.longitude,p.latitude,p.dhhn2016M,p.ellipsoidM].every(Number.isFinite)||p.longitude<5||p.longitude>16||p.latitude<47||p.latitude>56||p.ellipsoidM-p.dhhn2016M<=10||p.ellipsoidM-p.dhhn2016M>=100)
                throw Error('Invalid or non-German reference control');
            const key=`${p.longitude},${p.latitude}`;
            if(seen.has(key))throw Error('Duplicate reference coordinate');seen.add(key);
        }
        return input.controls;
    }
    function compare(input,heights){
        const controls=validate(input);
        if(!Array.isArray(heights)||heights.length!==controls.length||!heights.every(Number.isFinite))throw Error('Incomplete terrain sample');
        const points=controls.map((p,i)=>({...p,meshM:heights[i],ellipsoidResidualM:heights[i]-p.ellipsoidM,normalResidualM:heights[i]-p.dhhn2016M}));
        const stats=key=>({rmsM:Math.sqrt(points.reduce((s,p)=>s+p[key]**2,0)/points.length),maxAbsM:Math.max(...points.map(p=>Math.abs(p[key])))});
        const ellipsoid=stats('ellipsoidResidualM'),normal=stats('normalResidualM');
        // Diagnostic hypothesis only. A close local match is not evidence of
        // nationwide coverage, source consistency, or a surveyed height datum.
        const close=a=>a.rmsM<=2&&a.maxAbsM<=3;
        const hypothesis=close(ellipsoid)&&normal.rmsM>=10?'matches-ellipsoid-locally':close(normal)&&ellipsoid.rmsM>=10?'matches-normal-locally':'inconclusive';
        return {source:input.source,points,ellipsoid,normal,hypothesis,rfAuthorized:false};
    }
    async function run(input,{C,regional,cacheModule,clock=()=>performance.now(),timeoutMs=30000}){
        const controls=validate(input);
        if(controls.some(p=>!regional.inCountry(p.longitude,p.latitude)))throw Error('Control outside approximate Germany provider region');
        const timed=async fn=>{const t=clock();let timer;try{return {value:await Promise.race([Promise.resolve().then(fn),new Promise((_,reject)=>{timer=setTimeout(()=>reject(Error('Probe timed out; reload before retry')),timeoutMs);})]),ms:clock()-t};}finally{clearTimeout(timer);}};
        const {value:provider,ms:providerMs}=await timed(()=>regional.terrain(C));
        if(!provider.availability)throw Error('Provider has no detailed tile availability');
        const cache=cacheModule.create({C});const abort=new AbortController();
        const positions=()=>controls.map(p=>C.Cartographic.fromDegrees(p.longitude,p.latitude));
        try{
            cache.setStation(controls[0]);
            const cold=await timed(()=>cache.sample(provider,positions(),abort.signal));
            const coldCache=cache.diagnostics();
            const warm=await timed(()=>cache.sample(provider,positions(),abort.signal));
            const warmCache=cache.diagnostics();
            const native=await timed(()=>C.sampleTerrainMostDetailed(provider,positions(),true));
            const vals=batch=>{if(!Array.isArray(batch)||batch.length!==controls.length||batch.some(p=>!Number.isFinite(p?.height)))throw Error('Incomplete detailed sample');return batch.map(p=>p.height);};
            const a=vals(cold.value),b=vals(warm.value),c=vals(native.value);
            return {...compare(input,c),providerUrl:regional.terrainUrl,levels:positions().map(p=>provider.availability.computeMaximumLevelAtPosition(p)),providerMs,coldMs:cold.ms,warmMs:warm.ms,nativeMs:native.ms,coldCache,warmCache,coldVsNativeMaxM:Math.max(...a.map((h,i)=>Math.abs(h-c[i]))),warmVsNativeMaxM:Math.max(...b.map((h,i)=>Math.abs(h-c[i])))};
        }finally{abort.abort();cache.reset();}
    }
    return {validate,compare,run};
});
