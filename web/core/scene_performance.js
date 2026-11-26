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
    function create(viewer,{now=()=>performance.now(),capacity=240,resources=()=>({}),
        isContinuous=()=>false,isForeground=()=>globalThis.document?.visibilityState!=='hidden',gpuContext=()=>viewer.scene.context?._gl}={}){
        if(!Number.isSafeInteger(capacity)||capacity<16||capacity>MAX_SAMPLES)throw Error('Invalid frame sample limit');
        const scene=viewer.scene;
        const render=new Float64Array(capacity),interval=new Float64Array(capacity),physics=new Float64Array(capacity),gpu=new Float64Array(capacity);
        let running=false,disposed=false,removePre=null,removePost=null,gpuSampler=null,gpuCount=0;
        let physicsCount=0,physicsTotalMs=0,physicsMaxMs=0;
        let renderCount=0,intervalCount=0,allFrames=0,lastFrame=null,frameStart=null;
        const record=(buffer,count,value)=>{buffer[count%capacity]=value;};
        const samples=(buffer,count)=>Array.from(buffer.slice(0,Math.min(capacity,count)));
        function reset(){
            renderCount=0;intervalCount=0;allFrames=0;lastFrame=null;frameStart=null;
            physicsCount=0;physicsTotalMs=0;physicsMaxMs=0;gpuCount=0;
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
            }
        }
        function stop(){
            if(!running)return;
            running=false;removePre?.();removePost?.();removePre=removePost=null;frameStart=null;gpuSampler?.clear();
        }
        function start(){
            if(disposed)throw Error('Scene timing is disposed');
            if(running)return;
            reset();running=true;
            gpuSampler=gpuTimer(gpuContext(),ms=>record(gpu,gpuCount++,ms));
            removePre=scene.preRender.addEventListener(pre);
            removePost=scene.postRender.addEventListener(post);
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
            const renderMs=samples(render,renderCount),intervalMs=samples(interval,intervalCount);
            const resource=resources(),physicsMs=samples(physics,physicsCount),gpuMs=samples(gpu,gpuCount);
            return {running,frames:allFrames,renderSamples:renderMs.length,intervalSamples:intervalMs.length,
                physicsStep:{count:physicsCount,samples:physicsMs.length,totalMs:physicsTotalMs,
                    p50Ms:percentile(physicsMs,.5),p95Ms:percentile(physicsMs,.95),maxMs:physicsMaxMs},
                cpuRenderMs:{p50:percentile(renderMs,.5),p95:percentile(renderMs,.95),max:percentile(renderMs,1)},
                gpuRenderMs:{supported:gpuSampler?.supported??false,samples:gpuMs.length,p50:percentile(gpuMs,.5),p95:percentile(gpuMs,.95),max:percentile(gpuMs,1)},
                scenery:resource.scenery??null,flightPhysics:resource.flightPhysics??null,
                framePacingMs:{p50:percentile(intervalMs,.5),p95:percentile(intervalMs,.95),max:percentile(intervalMs,1)},
                over33Ms:intervalMs.filter(ms=>ms>33.34).length,
                over100Ms:intervalMs.filter(ms=>ms>100).length,
                // Cesium's tileset estimate does not include terrain or full GPU allocations.
                tilesets:{resident:resource.resident??0,visible:resource.visible??0,pending:resource.pending??0,
                    estimatedBytes:resource.estimatedTilesetBytes??0},
                caveat:'CPU callback timing is not GPU time; GPU samples require WebGL2 timer-query support. Frame pacing is not idle FPS. Memory is not full GPU allocation.'};
        }
        return {start,stop,snapshot,measurePhysicsStep,get running(){return running;},dispose(){if(disposed)return;stop();disposed=true;reset();}};
    }
    return {create,percentile,gpuTimer};
});
