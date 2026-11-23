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
    function create(viewer,{now=()=>performance.now(),capacity=240,resources=()=>({}),
        isContinuous=()=>false,isForeground=()=>globalThis.document?.visibilityState!=='hidden'}={}){
        if(!Number.isSafeInteger(capacity)||capacity<16||capacity>MAX_SAMPLES)throw Error('Invalid frame sample limit');
        const scene=viewer.scene;
        const render=new Float64Array(capacity),interval=new Float64Array(capacity),physics=new Float64Array(capacity);
        let running=false,disposed=false,removePre=null,removePost=null;
        let physicsCount=0,physicsTotalMs=0,physicsMaxMs=0;
        let renderCount=0,intervalCount=0,allFrames=0,lastFrame=null,frameStart=null;
        const record=(buffer,count,value)=>{buffer[count%capacity]=value;};
        const samples=(buffer,count)=>Array.from(buffer.slice(0,Math.min(capacity,count)));
        function reset(){
            renderCount=0;intervalCount=0;allFrames=0;lastFrame=null;frameStart=null;
            physicsCount=0;physicsTotalMs=0;physicsMaxMs=0;
        }
        function pre(){
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
            if(frameStart===null)return;
            const elapsed=now()-frameStart;frameStart=null;
            if(Number.isFinite(elapsed)&&elapsed>=0&&elapsed<60000){
                record(render,renderCount++,elapsed);allFrames++;
            }
        }
        function stop(){
            if(!running)return;
            running=false;removePre?.();removePost?.();removePre=removePost=null;frameStart=null;
        }
        function start(){
            if(disposed)throw Error('Scene timing is disposed');
            if(running)return;
            reset();running=true;
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
            const resource=resources(),physicsMs=samples(physics,physicsCount);
            return {running,frames:allFrames,renderSamples:renderMs.length,intervalSamples:intervalMs.length,
                physicsStep:{count:physicsCount,samples:physicsMs.length,totalMs:physicsTotalMs,
                    p50Ms:percentile(physicsMs,.5),p95Ms:percentile(physicsMs,.95),maxMs:physicsMaxMs},
                cpuRenderMs:{p50:percentile(renderMs,.5),p95:percentile(renderMs,.95),max:percentile(renderMs,1)},
                framePacingMs:{p50:percentile(intervalMs,.5),p95:percentile(intervalMs,.95),max:percentile(intervalMs,1)},
                over33Ms:intervalMs.filter(ms=>ms>33.34).length,
                over100Ms:intervalMs.filter(ms=>ms>100).length,
                // Cesium's tileset estimate does not include terrain or full GPU allocations.
                tilesets:{resident:resource.resident??0,visible:resource.visible??0,pending:resource.pending??0,
                    estimatedBytes:resource.estimatedTilesetBytes??0},
                caveat:'CPU render callbacks and frame intervals; not GPU time, full GPU memory or idle FPS.'};
        }
        return {start,stop,snapshot,measurePhysicsStep,dispose(){if(disposed)return;stop();disposed=true;reset();}};
    }
    return {create,percentile};
});
