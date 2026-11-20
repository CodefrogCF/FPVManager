// Optional, bounded aerodynamic heuristics for powered multirotor flight.
// NOT CFD, measured propeller data, or a prediction of vortex-ring state.
(function(root,factory){
    const api=factory();
    if(typeof module==='object'&&module.exports)module.exports=api;
    else root.FPVDescentAerodynamics=api;
})(typeof globalThis!=='undefined'?globalThis:this,function(){
    'use strict';
    const rho=1.225,g=9.80665;
    const clamp=(v,a,b)=>Math.max(a,Math.min(b,v));
    const smooth=(a,b,x)=>{const t=clamp((x-a)/(b-a),0,1);return t*t*(3-2*t);};
    function configuration(raw={}){
        if(!raw||typeof raw!=='object'||Array.isArray(raw))throw Error('Invalid descent aerodynamics');
        const cfg={groundEffectEnabled:raw.groundEffectEnabled??false,
            propwashEnabled:raw.propwashEnabled??false,
            vortexRingEnabled:raw.vortexRingEnabled??false,
            groundEffectIntensity:raw.groundEffectIntensity??1,
            propwashIntensity:raw.propwashIntensity??1,
            vortexRingIntensity:raw.vortexRingIntensity??1,
            rotorDiameterMeters:raw.rotorDiameterMeters??.1778}; // assumed 7-inch unless hardware supplies diameter
        for(const key of ['groundEffectEnabled','propwashEnabled','vortexRingEnabled'])
            if(typeof cfg[key]!=='boolean')throw Error(`Invalid ${key}`);
        for(const key of ['groundEffectIntensity','propwashIntensity','vortexRingIntensity'])
            if(!Number.isFinite(cfg[key])||cfg[key]<0||cfg[key]>2)throw Error(`Invalid ${key}`);
        if(!Number.isFinite(cfg.rotorDiameterMeters)||cfg.rotorDiameterMeters<.0254||cfg.rotorDiameterMeters>.762)
            throw Error('Invalid rotor diameter');
        return Object.freeze(cfg);
    }
    function rotate(q,v){
        const tx=2*(q.y*v.z-q.z*v.y),ty=2*(q.z*v.x-q.x*v.z),tz=2*(q.x*v.y-q.y*v.x);
        return {x:v.x+q.w*tx+q.y*tz-q.z*ty,
            y:v.y+q.w*ty+q.z*tx-q.x*tz,z:v.z+q.w*tz+q.x*ty-q.y*tx};
    }
    const dot=(a,b)=>a.x*b.x+a.y*b.y+a.z*b.z;
    function evaluate({thrustAcceleration, motorCommand=0, orientation,
        airVelocity, clearanceMeters=null, rotorDiameterMeters=null,
        motorCount=4, aircraftMassKg=1.3, timeSeconds=0},cfg){
        if(!Number.isFinite(thrustAcceleration)||thrustAcceleration<0||thrustAcceleration>200||
            !Number.isFinite(motorCommand)||motorCommand<0||motorCommand>1||
            !orientation||!['w','x','y','z'].every(k=>Number.isFinite(orientation[k]))||
            !airVelocity||!['north','east','up'].every(k=>Number.isFinite(airVelocity[k]))||
            !Number.isFinite(timeSeconds)||!Number.isInteger(motorCount)||motorCount<1||motorCount>32||
            !Number.isFinite(aircraftMassKg)||aircraftMassKg<=0||aircraftMassKg>50)
            throw Error('Invalid descent aerodynamics input');
        const diameter=rotorDiameterMeters??cfg.rotorDiameterMeters;
        if(!Number.isFinite(diameter)||diameter<.0254||diameter>.762)throw Error('Invalid rotor diameter');
        const axial=rotate(orientation,{x:0,y:0,z:-1});
        // Rotated body-up normal in north/east/up. Only a nearly upright
        // rotor disc receives appreciable lift from horizontal terrain.
        const upward=clamp(-axial.z,0,1);
        const effectiveMotor=thrustAcceleration>1e-8&&motorCommand>1e-4;
        const powered=effectiveMotor?clamp(thrustAcceleration/g,0,1):0;
        let groundBoost=0,propwashLoss=0,vortexLoss=0;
        const clearanceKnown=Number.isFinite(clearanceMeters)&&clearanceMeters>=0;
        if(cfg.groundEffectEnabled&&powered>0&&clearanceKnown){
            // Smooth fade at four rotor diameters, no estimated altitude used.
            // Upper bound: +25% of free-air motor thrust, only near terrain.
            const proximity=clamp(1-clearanceMeters/(4*diameter),0,1);
            groundBoost=clamp(.25*cfg.groundEffectIntensity*proximity*proximity*powered*upward*upward,0,.3);
        }
        let side={north:0,east:0,up:0};
        if((cfg.propwashEnabled||cfg.vortexRingEnabled)&&powered>.15){
            const v={x:airVelocity.north,y:airVelocity.east,z:-airVelocity.up};
            const along=dot(v,axial); // descent into the powered prop disc is negative along thrust
            const descend=Math.max(0,-along);
            const lateral=Math.sqrt(Math.max(0,dot(v,v)-along*along));
            // Induced velocity estimated from total T/(2*rho*A).
            // Use hardware mass when available; otherwise assume 1.3 kg.
            // This is NOT a real vortex-ring prediction.
            const diskArea=Math.PI*(diameter/2)**2*motorCount;
            const induced=clamp(Math.sqrt(Math.max(.001,thrustAcceleration*aircraftMassKg)/(2*rho*diskArea)),1,20);
            const descentWindow=smooth(.22*induced,.7*induced,descend)*
                (1-smooth(1.6*induced,2.5*induced,descend));
            const forwardRelief=1-smooth(.4*induced,1.8*induced,lateral);
            const exposure=descentWindow*forwardRelief*powered;
            if(cfg.propwashEnabled)propwashLoss=clamp(.09*cfg.propwashIntensity*exposure,0,.18);
            if(cfg.vortexRingEnabled)vortexLoss=clamp(.20*cfg.vortexRingIntensity*exposure,0,.4);
            // Bounded lateral buffeting, from motor power (never from gravity).
            // Deterministic in simulation time, no random calls or frame-time input.
            if(cfg.propwashEnabled&&exposure>0){
                const r=rotate(orientation,{x:0,y:1,z:0});
                const f=rotate(orientation,{x:1,y:0,z:0});
                const strength=Math.min(.12*thrustAcceleration,.75)*cfg.propwashIntensity*exposure;
                const a=strength*.6*Math.sin(timeSeconds*14.7+1.1),
                    b=strength*.4*Math.sin(timeSeconds*9.3+2.7);
                side={north:a*r.x+b*f.x,east:a*r.y+b*f.y,up:-a*r.z-b*f.z};
            }
        }
        // Hard upper/lower bound applies even when several features are enabled.
        const multiplier=clamp(1+groundBoost-propwashLoss-vortexLoss,.5,1.3);
        return {effectiveThrustAcceleration:thrustAcceleration*multiplier,
            disturbance:side,groundBoost,propwashLoss,vortexLoss,
            clearanceKnown,groundEffectApplied:groundBoost>0,
            estimated:true};
    }
    return {configuration,evaluate};
});
