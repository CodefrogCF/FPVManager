// Direction-dependent quadratic aerodynamic damping for the optional advanced
// flight model. World axes are north/east/up; body axes are forward/right/down.
// The coefficients are CALIBRATION PRESETS, not measured CdA or propeller data.
(function(root,factory){
    const api=factory();
    if(typeof module==='object'&&module.exports)module.exports=api;
    else root.FPVBodyAxisAerodynamics=api;
})(typeof globalThis!=='undefined'?globalThis:this,function(){
    'use strict';
    const gravity=9.80665;
    // Multipliers of g / (reference vertical terminal speed)^2. Vertical=1
    // corresponds to the previously configured free-fall terminal velocity
    // for an upright aircraft with propeller drag disabled.
    const presets=Object.freeze({
        conservative:Object.freeze({forward:.35,backward:.55,lateral:.7,vertical:1,propeller:.12}),
        streamlined:Object.freeze({forward:.2,backward:.4,lateral:.5,vertical:.85,propeller:.08}),
        highDrag:Object.freeze({forward:.6,backward:.85,lateral:1,vertical:1.3,propeller:.2})
    });
    const clamp=(x,low,high)=>Math.max(low,Math.min(high,x));
    const coefficients=['forward','backward','lateral','vertical','propeller'];
    function configuration(settings={},terminalVelocity=22.5){
        if(!settings||typeof settings!=='object'||Array.isArray(settings))throw Error('Invalid aerodynamics settings');
        if(!Number.isFinite(terminalVelocity)||terminalVelocity<5||terminalVelocity>120)
            throw Error('Invalid aerodynamic reference terminal speed');
        const preset=settings.preset??'conservative';
        if(preset!=='custom'&&!Object.hasOwn(presets,preset))throw Error('Unknown aerodynamics preset');
        const defaults=presets[preset]??presets.conservative;
        const result={preset,terminalVelocity,propellerDragEnabled:settings.propellerDragEnabled??true};
        if(typeof result.propellerDragEnabled!=='boolean')throw Error('Invalid propeller drag toggle');
        for(const key of coefficients){
            const value=preset==='custom'?(settings[key]??defaults[key]):defaults[key];
            if(!Number.isFinite(value)||value<(key==='vertical'?.1:0)||value>5)
                throw Error(`Invalid aerodynamics ${key} coefficient`);
            result[key]=value;
        }
        return Object.freeze(result);
    }
    function inverse(q){return {w:q.w,x:-q.x,y:-q.y,z:-q.z};}
    function rotate(q,v){
        // Quaternion rotation via cross products, without allocating quaternion
        // products each substep. A unit quaternion is supplied by the flight model.
        const tx=2*(q.y*v.z-q.z*v.y),ty=2*(q.z*v.x-q.x*v.z),tz=2*(q.x*v.y-q.y*v.x);
        return {x:v.x+q.w*tx+q.y*tz-q.z*ty,
            y:v.y+q.w*ty+q.z*tx-q.x*tz,
            z:v.z+q.w*tz+q.x*ty-q.y*tx};
    }
    function bodyAirVelocity(velocity,wind,attitude){
        return rotate(inverse(attitude),{x:velocity.north-wind.north,
            y:velocity.east-wind.east,z:wind.up-velocity.up});
    }
    function dragCoefficients(config,bodyVelocity,motorCommand){
        // Reverse airflow meets a different projected cross-section. At low
        // motor demand, an optional disc/autorotation surrogate adds BODY-Z
        // resistance only; it never generates lift or motor thrust.
        const lowPower=config.propellerDragEnabled?
            1-clamp(motorCommand/.35,0,1):0;
        const scale=gravity/(config.terminalVelocity*config.terminalVelocity);
        return {x:scale*(bodyVelocity.x>=0?config.forward:config.backward),
            y:scale*config.lateral,z:scale*(config.vertical+config.propeller*lowPower)};
    }
    function integrate(velocity,wind,attitude,acceleration,seconds,motorCommand,config){
        if(!Number.isFinite(seconds)||seconds<=0||seconds>1||
            !Number.isFinite(motorCommand)||motorCommand<0||motorCommand>1)
            throw Error('Invalid aerodynamic simulation step');
        // Strang split: half external acceleration, exact per-axis quadratic
        // damping and displacement in the current body frame, then half kick.
        // dv_i/dt = -k_i v_i |v_i| has the closed-form velocity solution
        // v_i(t)=v_i(0)/(1+k_i |v_i(0)| t). No Euler overshoot is possible.
        const middle={north:velocity.north+acceleration.north*seconds/2,
            east:velocity.east+acceleration.east*seconds/2,
            up:velocity.up+acceleration.up*seconds/2};
        const body=bodyAirVelocity(middle,wind,attitude);
        const k=dragCoefficients(config,body,motorCommand),after={},travelBody={};
        for(const axis of ['x','y','z']){
            const v=body[axis],loss=k[axis]*Math.abs(v)*seconds;
            after[axis]=v/(1+loss);
            // Integrate the exact drag-only displacement; log1p is accurate
            // even near zero and preserves the velocity's direction.
            travelBody[axis]=v*seconds*(loss>1e-10?Math.log1p(loss)/loss:1);
        }
        const airVelocity=rotate(attitude,after),airTravel=rotate(attitude,travelBody);
        return {velocity:{north:wind.north+airVelocity.x+acceleration.north*seconds/2,
            east:wind.east+airVelocity.y+acceleration.east*seconds/2,
            up:wind.up-airVelocity.z+acceleration.up*seconds/2},
        travel:{north:wind.north*seconds+airTravel.x,
            east:wind.east*seconds+airTravel.y,
            up:wind.up*seconds-airTravel.z}};
    }
    return {presets,configuration,bodyAirVelocity,dragCoefficients,integrate};
});
