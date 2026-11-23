(function(root,factory){
    const api=factory();
    if(typeof module==='object'&&module.exports)module.exports=api;
    else root.FPVSignalHud=api;
})(typeof globalThis!=='undefined'?globalThis:this,function(){
    'use strict';
    const clamp=(x,a=0,b=1)=>Math.max(a,Math.min(b,x));
    const defaults=Object.freeze({djiWarning:true,betaflightBars:true,analogNoise:false,
        terrainIllustration:false,weakThreshold:.55,criticalThreshold:.25,lostThreshold:.08,analogIntensity:.65});
    function settings(value={}){
        if(!value||typeof value!=='object'||Array.isArray(value))throw Error('Invalid signal HUD settings');
        const s={...defaults,...value};
        for(const key of ['djiWarning','betaflightBars','analogNoise','terrainIllustration'])
            if(typeof s[key]!=='boolean')throw Error(`Invalid signal HUD ${key}`);
        for(const key of ['weakThreshold','criticalThreshold','lostThreshold','analogIntensity'])
            if(!Number.isFinite(s[key])||s[key]<0||s[key]>1)throw Error(`Invalid signal HUD ${key}`);
        if(!(s.lostThreshold<s.criticalThreshold&&s.criticalThreshold<s.weakThreshold))
            throw Error('Signal HUD thresholds must be ordered');
        return s;
    }
    function modeled(link){
        // An explicit model must provide its own provenance. No string such as
        // 'clear' or 'obstructed' can be interpreted as an RF measurement.
        if(!link||typeof link!=='object'||!Number.isFinite(link.quality)||link.quality<0||link.quality>1||
            !['rfModel','estimatedModel','terrainIllustration'].includes(link.source))return null;
        return {quality:link.quality,source:link.source};
    }
    function links(assessment,opts){
        const rc=modeled(assessment?.controlLink),video=modeled(assessment?.videoLink);
        if(video||!opts.terrainIllustration||assessment?.source!=='sampledTerrain'||
            assessment.confidence!=='approximate')return {rc,video};
        // Visualization-only proxy, intentionally NOT a radio link model.
        // It must never be used by a failsafe or interpreted as real LQ/RSSI.
        const geometry={clear:.94,fresnelIntrusion:.48,obstructed:.13};
        const quality=geometry[assessment.visibility];
        return {rc,video:Number.isFinite(quality)?{quality,source:'terrainIllustration'}:null};
    }
    function level(quality,opts,previous='unknown'){
        if(!Number.isFinite(quality))return 'unknown';
        // Small hysteresis while exiting warning states prevents flicker.
        const hysteresis=.035;
        const limit=(name,bound)=>bound+(previous===name?hysteresis:0);
        if(quality<=limit('lost',opts.lostThreshold))return 'lost';
        if(quality<=limit('critical',opts.criticalThreshold))return 'critical';
        if(quality<=limit('weak',opts.weakThreshold))return 'weak';
        return 'good';
    }
    function evaluate(assessment,configuration,previous='unknown'){
        const opts=settings(configuration),link=links(assessment,opts);
        const videoLevel=level(link.video?.quality,opts,previous);
        return {rc:link.rc,video:link.video,videoLevel,
            videoBars:link.video?(videoLevel==='lost'?0:clamp(Math.ceil(link.video.quality*5),0,5)):null,
            rcBars:link.rc?clamp(Math.ceil(link.rc.quality*5),0,5):null,
            warning:['weak','critical','lost'].includes(videoLevel)?videoLevel:null,
            noise:link.video&&opts.analogNoise
                ?clamp((.06+.94*Math.pow(1-link.video.quality,.8))*opts.analogIntensity):0};
    }
    function create(doc,{translate=source=>source,now=()=>typeof performance!=='undefined'?performance.now():Date.now()}={}){
        const edge=doc.getElementById('hud-signal-edge'),bars=doc.getElementById('hud-signal-bars'),
            video=doc.getElementById('hud-signal-video'),rc=doc.getElementById('hud-signal-rc'),
            videoLabel=doc.getElementById('hud-signal-video-label'),
            noise=doc.getElementById('hud-analog-noise');
        let previous='unknown',smoothed=null,lastAt=null,frame=0;
        let lastVideoAt=null,lastAnalogNoise=0;
        const transientVideoGapMs=1100; // aesthetic hold, never RC or measured RF state
        function reset(){previous='unknown';smoothed=null;lastAt=null;frame=0;
            lastVideoAt=null;lastAnalogNoise=0;
            edge.hidden=bars.hidden=noise.hidden=true;
            noise.style.opacity='0';}
        function update(state,assessment){
            const cfg=settings(state.signalHud??{}),style=state.hudStyle==='betaflight'?'betaflight':'goggles';
            const target=links(assessment,cfg);
            const stamp=now();
            if(target.video){
                const elapsed=lastAt===null?0:clamp((stamp-lastAt)/1000,0,1);
                // Time-based first-order smoothing, with immediate first sample.
                const alpha=1-Math.exp(-elapsed/0.55);
                smoothed=smoothed===null?target.video.quality:smoothed+(target.video.quality-smoothed)*alpha;
                lastVideoAt=stamp;
            }else if(lastVideoAt===null||stamp-lastVideoAt>transientVideoGapMs){
                smoothed=null;
            }
            lastAt=stamp;
            const output=evaluate({...assessment,videoLink:target.video},cfg,previous);
            // Preserve the smoothed value, including for terrain illustration.
            const effective=target.video?evaluate({videoLink:{...target.video,quality:smoothed}},cfg,previous):output;
            previous=effective.videoLevel;
            // The DJI-inspired lower-edge warning is an independent HUD option,
            // not exclusive to the goggles layout. Betaflight bars remain separate.
            edge.hidden=!(cfg.djiWarning&&effective.warning);
            if(!edge.hidden){edge.dataset.level=effective.warning;
                edge.style.opacity=String(effective.warning==='weak'?clamp((cfg.weakThreshold-smoothed)/Math.max(.01,cfg.weakThreshold-cfg.criticalThreshold)*.65+.25,.25,.88):.85);
                edge.title='SIM · Estimated video indication; not measured RF signal';}
            bars.hidden=!(style==='betaflight'&&cfg.betaflightBars);
            if(!bars.hidden){
                video.dataset.bars=String(effective.videoBars??0);
                video.dataset.level=effective.videoLevel;
                video.dataset.known=String(!!target.video);
                video.dataset.source=target.video?.source??'unknown';
                rc.dataset.bars=String(output.rcBars??0);
                rc.dataset.known=String(!!target.rc);
                const label=target.video?.source==='terrainIllustration'?'SIM TERRAIN':'SIM VIDEO';
                videoLabel.textContent=translate(label);
                video.setAttribute('aria-label',`${label}: ${effective.videoLevel}`);
                rc.setAttribute('aria-label',`SIM RC: ${output.rc?'estimated '+level(output.rc.quality,cfg):'unknown'}`);
                const simulatedMetrics=(link)=>link&&Number.isFinite(link.linkMarginDb)&&Number.isFinite(link.estimatedMaxRangeM)
                    ? `SIM estimated reserve ${link.linkMarginDb.toFixed(1)} dB; theoretical free-space range ${(link.estimatedMaxRangeM/1000).toFixed(1)} km (assumptions, not measured)`
                    : 'Simulated quality only; no calibrated range available';
                rc.title=simulatedMetrics(assessment?.controlLink)+
                    (assessment?.controlLink?.detail==='sampledObstructionOnly'?' · LIMITED terrain coverage; sampled blockage only':'');
                video.title=target.video?.source==='terrainIllustration'
                    ?'Terrain-risk illustration only: not an RF signal prediction'
                    :simulatedMetrics(assessment?.videoLink)+
                        (assessment?.videoLink?.detail==='sampledObstructionOnly'?' · LIMITED terrain coverage; sampled blockage only':'');
            }
            // Short missing RF/terrain updates must not switch the *visual*
            // analog interference off and on. Only the effect remembers the
            // previous estimate: RC/video bars remain unknown, and no failsafe
            // decisions use the holdover. After 1.1 s, release it entirely.
            if(target.video)lastAnalogNoise=effective.noise;
            const transientGap=!target.video&&lastVideoAt!==null&&
                stamp-lastVideoAt>=0&&stamp-lastVideoAt<=transientVideoGapMs;
            const visualNoise=target.video?effective.noise:transientGap?lastAnalogNoise:0;
            noise.hidden=!(style==='betaflight'&&cfg.analogNoise&&(target.video||transientGap));
            if(!noise.hidden){
                // No canvas readback or texture allocation; effect runs only
                // at the bounded HUD update cadence (~10 Hz).
                noise.dataset.level=target.video?effective.videoLevel:'unknown';
                noise.dataset.holdover=String(transientGap);
                // Brief extra flicker during uncertainty, then resume the
                // ordinary smooth noise without a flash to zero.
                const dropout=target.video&&((effective.videoLevel==='lost'&&cfg.analogIntensity>.3&&frame%7<3)||
                    (effective.videoLevel==='critical'&&effective.noise>.58&&frame%25===0));
                const flutter=transientGap&&frame%9===0;
                noise.dataset.dropout=String(!!dropout);
                noise.style.opacity=String(dropout ? .96 : flutter?clamp(visualNoise*1.18,0,.96):visualNoise);
                noise.style.backgroundPosition=`${(frame*29)%113}px ${(frame*41)%107}px`;
                noise.style.setProperty?.('--tear-position',`${(frame*23)%89+5}%`);
                noise.style.setProperty?.('--tear-strength',String(clamp(visualNoise*2)));
                frame++;
            }else noise.style.opacity='0';
            return effective;
        }
        reset();
        return {update,reset};
    }
    return {defaults,settings,modeled,links,level,evaluate,create};
});
