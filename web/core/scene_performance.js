/* Opt-in, bounded scene timing. No telemetry/network traffic. */
(function(root,factory){
    const api=factory();
    if(typeof module==='object'&&module.exports)module.exports=api;
    else root.FPVScenePerformance=api;
})(typeof globalThis!=='undefined'?globalThis:this,function(){
    'use strict';
    const MAX_SAMPLES=600;
    function percentile(values,p){
        if(!values.length)return null;
        const sorted=values.slice().sort((a,b)=>a-b);
        return Math.round(sorted[Math.ceil((sorted.length-1)*p)]*100)/100;
    }
    // Optional WebGL2 timer query. Never wait on the GPU; skip frames when the
    // driver is busy or another consumer owns the TIME_ELAPSED query target.
    function gpuTimer(gl,onSample){
        let ext=null,active=null,pending=[];
        try{ext=gl?.getExtension?.('EXT_disjoint_timer_query_webgl2')??null;}catch(_){}
        const supported=!!(ext&&gl.createQuery&&gl.getQuery&&gl.getQueryParameter);
        function release(query){try{gl.deleteQuery(query);}catch(_){}}
        function clear(){
            if(active){try{if(gl.getQuery(ext.TIME_ELAPSED_EXT,gl.CURRENT_QUERY)===active)gl.endQuery(ext.TIME_ELAPSED_EXT);}catch(_){}release(active);active=null;}
            for(const query of pending)release(query);pending=[];
        }
        function pre(){
            if(!supported)return;
            try{
                if(gl.isContextLost?.()||gl.getParameter(ext.GPU_DISJOINT_EXT)){clear();return;}
                if(active)clear(); // A failed render may have omitted postRender.
                // Poll only availability, never a blocking result on an unfinished query.
                while(pending.length&&gl.getQueryParameter(pending[0],gl.QUERY_RESULT_AVAILABLE)){
                    const query=pending.shift();let ns;try{ns=gl.getQueryParameter(query,gl.QUERY_RESULT);}finally{release(query);}
                    if(Number.isFinite(ns)&&ns>=0)onSample(ns/1e6);
                }
                if(active||pending.length>=8||gl.getQuery(ext.TIME_ELAPSED_EXT,gl.CURRENT_QUERY))return;
                active=gl.createQuery();if(active)gl.beginQuery(ext.TIME_ELAPSED_EXT,active);
            }catch(_){clear();}
        }
        function post(){
            if(!active)return;
            try{if(gl.getQuery(ext.TIME_ELAPSED_EXT,gl.CURRENT_QUERY)===active){gl.endQuery(ext.TIME_ELAPSED_EXT);pending.push(active);}else release(active);active=null;}
            catch(_){clear();}
        }
        return {supported,pre,post,clear};
    }
    function rendererInfo(gl){
        let vendor=null,renderer=null,webglVersion=null,unmasked=false;
        try{
            const debug=gl?.getExtension?.('WEBGL_debug_renderer_info');
            const read=key=>key==null?null:gl?.getParameter?.(key)??null;
            vendor=read(debug?.UNMASKED_VENDOR_WEBGL)??read(gl?.VENDOR);
            renderer=read(debug?.UNMASKED_RENDERER_WEBGL)??read(gl?.RENDERER);
            unmasked=!!debug&&!!renderer;
            webglVersion=read(gl?.VERSION);
        }catch(_){}
        const ua=globalThis.navigator?.userAgent??'';
        // UA identifies the Chromium engine, not necessarily the WebView2 runtime.
        const engine=ua.match(/(?:Chrome|Chromium)\/([\d.]+)/)?.[1]??null;
        return {vendor,renderer,unmasked,webglVersion,chromiumVersion:engine};
    }
    function create(viewer,{now=()=>performance.now(),capacity=240,resources=()=>({}),
        isContinuous=()=>false,isForeground=()=>globalThis.document?.visibilityState!=='hidden',gpuContext=()=>viewer.scene.context?._gl,
        Observer=globalThis.PerformanceObserver,
        requestFrame=globalThis.requestAnimationFrame?.bind(globalThis),cancelFrame=globalThis.cancelAnimationFrame?.bind(globalThis)}={}){
        if(!Number.isSafeInteger(capacity)||capacity<16||capacity>MAX_SAMPLES)throw Error('Invalid frame sample limit');
        const scene=viewer.scene;
        const render=new Float64Array(capacity),interval=new Float64Array(capacity),physics=new Float64Array(capacity),gpu=new Float64Array(capacity);
        const update=new Float64Array(capacity),sceneCpu=new Float64Array(capacity),raf=new Float64Array(capacity);
        let gpuTimingEnabled=true;
        let running=false,disposed=false,removePre=null,removePost=null,removeUpdate=null,removeUpdated=null,gpuSampler=null,gpuCount=0;
        let updateCount=0,sceneCount=0,rafCount=0,updateStart=null,sceneStart=null,lastRaf=null,rafHandle=null,rafGeneration=0,info=null;
        let longObserver=null,longSupported=false,longCount=0,longTotal=0,longMax=0,longStarted=0;
        let pendingTerrain=null,terrainSince=null,terrainLastMs=null,terrainPeak=0,terrainBatches=0;
        let physicsCount=0,physicsTotalMs=0,physicsMaxMs=0;
        let renderCount=0,intervalCount=0,allFrames=0,lastFrame=null,frameStart=null;
        const record=(buffer,count,value)=>{buffer[count%capacity]=value;};
        const samples=(buffer,count)=>Array.from(buffer.slice(0,Math.min(capacity,count)));
        function reset(){
            renderCount=0;intervalCount=0;allFrames=0;lastFrame=null;frameStart=null;
            physicsCount=0;physicsTotalMs=0;physicsMaxMs=0;gpuCount=0;
            updateCount=sceneCount=rafCount=0;updateStart=sceneStart=lastRaf=null;
            pendingTerrain=terrainSince=terrainLastMs=null;terrainPeak=terrainBatches=0;
            longSupported=false;longCount=longTotal=longMax=0;
        }
        function beforeUpdate(){sceneStart=updateStart=now();}
        function afterUpdate(){
            if(updateStart===null)return;
            const elapsed=now()-updateStart;updateStart=null;
            if(Number.isFinite(elapsed)&&elapsed>=0&&elapsed<60000)record(update,updateCount++,elapsed);
        }
        function watchRaf(generation){
            if(!requestFrame||!running||generation!==rafGeneration)return;
            rafHandle=requestFrame(timestamp=>{
                if(!running||generation!==rafGeneration)return;
                rafHandle=null;
                if(isForeground()&&Number.isFinite(timestamp)){
                    const gap=lastRaf===null?null:timestamp-lastRaf;
                    if(gap!==null&&gap>=1&&gap<=250)record(raf,rafCount++,gap);
                    lastRaf=timestamp;
                }else lastRaf=null;
                watchRaf(generation);
            });
        }
        function recordTerrainProgress(pending){
            if(!running||!Number.isFinite(pending)||pending<0)return;
            pendingTerrain=pending;terrainPeak=Math.max(terrainPeak,pending);
            if(pending>0&&terrainSince===null)terrainSince=now();
            if(pending===0&&terrainSince!==null){terrainLastMs=Math.max(0,now()-terrainSince);terrainSince=null;terrainBatches++;}
        }
        function pre(){
            gpuSampler?.pre();
            frameStart=now();
            if(!Number.isFinite(frameStart))frameStart=null;
            if(frameStart===null)return;
            if(lastFrame!==null&&isForeground()){
                const gap=frameStart-lastFrame;
                // Request-render / background / paused periods must not be
                // mistaken for dropped frames during continuously rendered motion.
                if(gap>=1&&(gap<=250||(isContinuous()&&gap<60000))){record(interval,intervalCount++,gap);}
            }
            lastFrame=isForeground()?frameStart:null;
        }
        function post(){
            gpuSampler?.post();
            if(frameStart===null)return;
            const elapsed=now()-frameStart;frameStart=null;
            if(Number.isFinite(elapsed)&&elapsed>=0&&elapsed<60000){
                record(render,renderCount++,elapsed);allFrames++;
                if(sceneStart!==null){const total=now()-sceneStart;if(Number.isFinite(total)&&total>=0&&total<60000)record(sceneCpu,sceneCount++,total);}
                sceneStart=null;
            }
        }
        function recordLongTasks(entries){
            for(const entry of entries){
                if(!Number.isFinite(entry.startTime)||entry.startTime<longStarted||!Number.isFinite(entry.duration)||entry.duration<50)continue;
                longCount++;longTotal+=entry.duration;longMax=Math.max(longMax,entry.duration);
            }
        }
        function stop(){
            if(!running)return;
            running=false;if(longObserver){recordLongTasks(longObserver.takeRecords?.()??[]);longObserver.disconnect();longObserver=null;}removePre?.();removePost?.();removeUpdate?.();removeUpdated?.();
            removePre=removePost=removeUpdate=removeUpdated=null;frameStart=updateStart=sceneStart=null;gpuSampler?.clear();
            rafGeneration++;if(rafHandle!==null)cancelFrame?.(rafHandle);rafHandle=null;lastRaf=null;
        }
        function start({gpuTiming=true}={}){
            if(disposed)throw Error('Scene timing is disposed');
            if(running)return;
            if(typeof gpuTiming!=='boolean')throw Error('Invalid GPU timing option');
            gpuTimingEnabled=gpuTiming;reset();running=true;longStarted=now();
            if(Observer?.supportedEntryTypes?.includes('longtask'))try{
                const observer=new Observer(list=>{if(running&&longObserver===observer)recordLongTasks(list.getEntries());});
                observer.observe({type:'longtask',buffered:false});longObserver=observer;longSupported=true;
            }catch(_){longObserver=null;}
            const gl=gpuContext();info=rendererInfo(gl);
            gpuSampler=gpuTimingEnabled?gpuTimer(gl,ms=>record(gpu,gpuCount++,ms)):null;
            removeUpdate=scene.preUpdate?.addEventListener(beforeUpdate);
            removeUpdated=scene.postUpdate?.addEventListener(afterUpdate);
            removePre=scene.preRender.addEventListener(pre);
            removePost=scene.postRender.addEventListener(post);
            watchRaf(++rafGeneration);
        }
        function measurePhysicsStep(integrate,dt){
            if(!running)return integrate(dt);
            const started=now();
            try{return integrate(dt);}finally{
                const elapsed=now()-started;
                if(Number.isFinite(elapsed)&&elapsed>=0){record(physics,physicsCount++,elapsed);physicsTotalMs+=elapsed;physicsMaxMs=Math.max(physicsMaxMs,elapsed);}
            }
        }
        function snapshot(){
            if(longObserver)recordLongTasks(longObserver.takeRecords?.()??[]);
            const renderMs=samples(render,renderCount),intervalMs=samples(interval,intervalCount);
            const resource=resources(),physicsMs=samples(physics,physicsCount),gpuMs=samples(gpu,gpuCount);
            const totalIntervalMs=intervalMs.reduce((sum,ms)=>sum+ms,0);
            const updateMs=samples(update,updateCount),sceneMs=samples(sceneCpu,sceneCount),rafMs=samples(raf,rafCount);
            const rafFast=percentile(rafMs,.1),rafMedian=percentile(rafMs,.5);
            const stats=values=>({p50:percentile(values,.5),p95:percentile(values,.95),max:percentile(values,1),samples:values.length});
            const canvas=scene.canvas??viewer.canvas;
            const gl=running?gpuContext():null;
            if(running&&resource.pendingTerrainTiles!==pendingTerrain)recordTerrainProgress(resource.pendingTerrainTiles);
            const finite=v=>Number.isFinite(v)?v:null;
            return {running,frames:allFrames,frameAgeMs:lastFrame===null?null:Math.max(0,now()-lastFrame),continuous:isContinuous(),renderFps:totalIntervalMs>0?1000*intervalMs.length/totalIntervalMs:null,renderSamples:renderMs.length,intervalSamples:intervalMs.length,
                renderer:info,canvas:{width:finite(canvas?.width),height:finite(canvas?.height),cssWidth:finite(canvas?.clientWidth),cssHeight:finite(canvas?.clientHeight),bufferWidth:finite(gl?.drawingBufferWidth),bufferHeight:finite(gl?.drawingBufferHeight),devicePixelRatio:finite(globalThis.devicePixelRatio),resolutionScale:finite(viewer.resolutionScale)},
                animationCadence:{samples:rafMs.length,fastHz:rafFast>0?1000/rafFast:null,medianHz:rafMedian>0?1000/rafMedian:null,p95Ms:percentile(rafMs,.95)},
                cpuUpdateMs:stats(updateMs),cpuSceneMs:stats(sceneMs),
                mainThreadLongTasks:{supported:longSupported,count:longCount,totalMs:longTotal,maxMs:longMax},
                sceneTileLoading:resource.sceneTileLoading??null,bridgeSupports:resource.bridgeSupports??null,bridgeCommands:resource.bridgeCommands??null,
                // Command list is an observed Cesium list, not actual GPU draw calls.
                sceneCommands:{count:finite(scene.frameState?.commandList?.length)},
                terrainProvider:resource.terrainProvider??null,terrainRequests:resource.terrainRequests??null,layerStats:resource.layerStats??null,terrainStreaming:{pending:pendingTerrain,peak:terrainPeak,activeMs:terrainSince===null?null:Math.max(0,now()-terrainSince),lastBatchMs:terrainLastMs,batches:terrainBatches},
                physicsStep:{count:physicsCount,samples:physicsMs.length,totalMs:physicsTotalMs,
                    p50Ms:percentile(physicsMs,.5),p95Ms:percentile(physicsMs,.95),maxMs:physicsMaxMs},
                cpuRenderMs:{p50:percentile(renderMs,.5),p95:percentile(renderMs,.95),max:percentile(renderMs,1)},
                gpuRenderMs:{enabled:gpuTimingEnabled,supported:gpuSampler?.supported??false,samples:gpuMs.length,p50:percentile(gpuMs,.5),p95:percentile(gpuMs,.95),max:percentile(gpuMs,1)},
                pendingTerrainTiles:resource.pendingTerrainTiles??null,scenery:resource.scenery??null,flightPhysics:resource.flightPhysics??null,
                framePacingMs:{p50:percentile(intervalMs,.5),p95:percentile(intervalMs,.95),max:percentile(intervalMs,1)},
                over33Ms:intervalMs.filter(ms=>ms>33.34).length,
                over100Ms:intervalMs.filter(ms=>ms>100).length,
                // Cesium's tileset estimate does not include terrain or full GPU allocations.
                tilesets:{resident:resource.resident??0,visible:resource.visible??0,pending:resource.pending??0,
                    estimatedBytes:resource.estimatedTilesetBytes??0},
                caveat:'CPU callback timing is not GPU time; scene timing covers observed Cesium callbacks only, rAF cadence is not physical display refresh, terrain busy time is wall time not processing time; GPU samples require WebGL2 timer-query support. Frame pacing is not idle FPS. Memory is not full GPU allocation.'};
        }
        return {start,stop,snapshot,measurePhysicsStep,recordTerrainProgress,get running(){return running;},dispose(){if(disposed)return;stop();disposed=true;reset();}};
    }
    return {create,percentile,gpuTimer};
});
