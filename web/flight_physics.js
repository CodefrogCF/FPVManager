// Shared flight-physics runtime. The legacy adapter preserves the historical
// render-frame integration; the advanced adapter uses bounded fixed substeps.
// Neither adapter owns Cesium, the HUD, stored aircraft profiles or RF states.
(function(root,factory){
    const api=factory();
    if(typeof module==='object'&&module.exports)module.exports=api;
    else root.FPVFlightPhysics=api;
})(typeof globalThis!=='undefined'?globalThis:this,function(){
    'use strict';
    const models=Object.freeze(['legacy','advanced']);
    const hzOptions=Object.freeze([60,120,240]);
    function configuration(value={}){
        const mode=value.mode??'legacy',hz=value.hz??120;
        if(!models.includes(mode))throw Error('Unknown flight physics model');
        if(!hzOptions.includes(hz))throw Error('Unsupported physics step frequency');
        return {mode,hz};
    }
    // A snapshot always carries world (north/east/up) velocity in m/s, body
    // angular velocity in rad/s, a unit quaternion and propulsion acceleration
    // in m/s². Positions use WGS84 latitude/longitude in degrees and height in
    // metres; neither implementation may reinterpret these shared units.
    function interpolateState(previous,current,alpha){
        if(!previous?.position||!current?.position)return current;
        const t=Math.max(0,Math.min(1,alpha)),lerp=(a,b)=>a+(b-a)*t;
        // Shortest WGS84 longitude arc, including anti-meridian crossings.
        const longitudeDelta=((current.position.longitude-previous.position.longitude+540)%360)-180;
        const longitude=((previous.position.longitude+t*longitudeDelta+540)%360)-180;
        const a=previous.attitude,b=current.attitude;
        const sign=a.w*b.w+a.x*b.x+a.y*b.y+a.z*b.z<0?-1:1;
        const mix={w:lerp(a.w,sign*b.w),x:lerp(a.x,sign*b.x),
            y:lerp(a.y,sign*b.y),z:lerp(a.z,sign*b.z)};
        const length=Math.hypot(mix.w,mix.x,mix.y,mix.z);
        const headingDelta=Math.atan2(Math.sin(current.heading-previous.heading),Math.cos(current.heading-previous.heading));
        const wrap=angle=>((angle%(2*Math.PI))+2*Math.PI)%(2*Math.PI);
        return {position:{latitude:lerp(previous.position.latitude,current.position.latitude),longitude},
            height:lerp(previous.height,current.height),heading:wrap(previous.heading+t*headingDelta),
            pitch:lerp(previous.pitch,current.pitch),roll:lerp(previous.roll,current.roll),
            attitude:{w:mix.w/length,x:mix.x/length,y:mix.y/length,z:mix.z/length}};
    }
    function createRuntime(options){
        const config=configuration(options);
        if(typeof options.integrate!=='function'||typeof options.snapshot!=='function'||typeof options.present!=='function')
            throw Error('Physics runtime requires integration, state and presentation adapters');
        const step=1/config.hz,maxSteps=options.maxSteps??24,maxBacklog=options.maxBacklogSeconds??.5;
        if(!Number.isInteger(maxSteps)||maxSteps<1||maxSteps>96||!Number.isFinite(maxBacklog)||maxBacklog<step*maxSteps||maxBacklog>2)
            throw Error('Invalid physics resource budget');
        let queued=0,dropped=0,simulated=0,steps=0,lastFrameSeconds=1/60,previous=null,current=null;
        function reset(){queued=0;dropped=0;simulated=0;steps=0;lastFrameSeconds=1/60;previous=null;current=null;}
        function discardBacklog(){queued=0;previous=null;current=null;}
        function diagnostics(){return {model:config.mode,stepHz:config.mode==='advanced'?config.hz:null,
            simulatedSeconds:simulated,queuedSeconds:queued,droppedSeconds:dropped,
            lastSubsteps:steps,interpolationAlpha:config.mode==='advanced'?Math.max(0,Math.min(1,queued/step)):1};}
        function advance(frameSeconds){
            if(!Number.isFinite(frameSeconds)||frameSeconds<=0)return diagnostics();
            if(config.mode==='legacy'){
                // Keep the existing frame-stall behaviour unchanged in legacy.
                const dt=frameSeconds>.075?Math.min(lastFrameSeconds,1/30):frameSeconds;
                if(frameSeconds<=.075)lastFrameSeconds=frameSeconds;
                options.integrate(dt);
                if(options.isActive&&!options.isActive()){reset();return diagnostics();}
                simulated+=dt;steps=1;
                return diagnostics();
            }
            const requested=queued+frameSeconds;
            queued=Math.min(maxBacklog,requested);
            dropped+=Math.max(0,requested-maxBacklog);
            steps=0;
            while(queued+1e-10>=step&&steps<maxSteps){
                previous=options.snapshot();
                options.integrate(step);
                if(options.isActive&&!options.isActive()){reset();break;}
                current=options.snapshot();
                queued=Math.max(0,queued-step);
                simulated+=step;steps++;
            }
            if(!options.isActive||options.isActive())options.present(previous,current,Math.max(0,Math.min(1,queued/step)));
            return diagnostics();
        }
        return {advance,reset,discardBacklog,diagnostics,configuration:config};
    }
    return {models,hzOptions,configuration,interpolateState,createRuntime};
});
