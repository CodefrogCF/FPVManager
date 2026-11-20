// Advanced simulation-only collision impulse model. Swept intersection and
// surface verification belong to the caller; this module cannot prove that
// unloaded tiles or unsurveyed meshes are safe.
(function(root,factory){
    const api=factory();
    if(typeof module==='object'&&module.exports)module.exports=api;
    else root.FPVCollisionResponse=api;
})(typeof globalThis!=='undefined'?globalThis:this,function(){
    'use strict';
    const clamp=(v,min,max)=>Math.max(min,Math.min(max,v));
    const axes=['north','east','up'];
    function configuration(value={}){
        const cfg={mode:value.mode??'slide',restitution:value.restitution??.12,
            friction:value.friction??.28,hardStopNormalSpeedMs:value.hardStopNormalSpeedMs??22,
            minimumReboundSpeedMs:value.minimumReboundSpeedMs??1,
            terrainProbeMeters:value.terrainProbeMeters??.6};
        if(!['slide','rebound','hard-stop'].includes(cfg.mode))throw Error('Invalid collision response mode');
        for(const [key,min,max] of [['restitution',0,.75],['friction',0,1],
            ['hardStopNormalSpeedMs',1,150],['minimumReboundSpeedMs',0,10],['terrainProbeMeters',.2,3]])
            if(!Number.isFinite(cfg[key])||cfg[key]<min||cfg[key]>max)throw Error(`Invalid collision ${key}`);
        return cfg;
    }
    function unitNormal(value){
        if(!value||!axes.every(k=>Number.isFinite(value[k])))return null;
        const length=Math.hypot(value.north,value.east,value.up);
        if(length<1e-8)return null;
        return {north:value.north/length,east:value.east/length,up:value.up/length};
    }
    function resolve(incoming,contactNormal,config){
        const cfg=configuration(config),normal=unitNormal(contactNormal);
        if(!incoming||!axes.every(k=>Number.isFinite(incoming[k])))
            return {velocity:{north:0,east:0,up:0},mode:'hard-stop',reason:'invalid velocity',normal:null};
        const zero={north:0,east:0,up:0};
        if(cfg.mode==='hard-stop'||!normal)return {velocity:zero,mode:'hard-stop',
            reason:normal?'configured':'surface normal unavailable',normal};
        const vn=axes.reduce((sum,k)=>sum+incoming[k]*normal[k],0);
        // Already separating: do not apply a new impulse to a receding contact.
        if(vn>=0)return {velocity:{...incoming},mode:'separating',normal,normalSpeedMs:0};
        const impact=-vn;
        if(impact>=cfg.hardStopNormalSpeedMs)
            return {velocity:zero,mode:'hard-stop',reason:'severe normal impact',normal,normalSpeedMs:impact};
        const tangent={};for(const k of axes)tangent[k]=incoming[k]-vn*normal[k];
        const tangentialSpeed=Math.hypot(tangent.north,tangent.east,tangent.up);
        const restitution=cfg.mode==='rebound'&&impact>=cfg.minimumReboundSpeedMs?cfg.restitution:0;
        // Coulomb-inspired impulse: friction consumes kinetic energy; it must
        // not produce transverse acceleration or grow the impact speed.
        const tangentScale=tangentialSpeed>1e-12?
            clamp(1-cfg.friction*(1+restitution)*impact/tangentialSpeed,0,1):0;
        const result={};for(const k of axes)
            result[k]=tangent[k]*tangentScale+restitution*impact*normal[k];
        return {velocity:result,mode:restitution>0?'rebound':'slide',normal,
            normalSpeedMs:impact,tangentialSpeedMs:tangentialSpeed,restitution};
    }
    // Derived only from FINITE, rendered terrain samples around the contact.
    // No default flat normal: missing tiles or abrupt tile seams are unknown.
    function terrainNormal(point,readHeight,move,probeMeters=.6){
        if(typeof readHeight!=='function'||typeof move!=='function'||!point)return null;
        const offsets=[move(point,probeMeters,0),move(point,-probeMeters,0),
            move(point,0,probeMeters),move(point,0,-probeMeters)];
        const heights=offsets.map(p=>readHeight({...p,height:point.height}));
        if(!heights.every(Number.isFinite))return null;
        const gradientNorth=(heights[0]-heights[1])/(2*probeMeters);
        const gradientEast=(heights[2]-heights[3])/(2*probeMeters);
        // Avoid attempting a well-defined contact normal at a discontinuity
        // or a very steep vertical mesh not representable by a height field.
        if(Math.hypot(gradientNorth,gradientEast)>8)return null;
        return unitNormal({north:-gradientNorth,east:-gradientEast,up:1});
    }
    return {configuration,unitNormal,resolve,terrainNormal};
});
