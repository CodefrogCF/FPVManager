// Optional advanced Acro attitude model. Body x=forward (roll), y=right
// (pitch), z=down (yaw). Angular rates are rad/s; torques are N*m and
// diagonal moments of inertia are kg*m². No Betaflight PID emulation.
(function(root,factory){
    const api=factory();
    if(typeof module==='object'&&module.exports)module.exports=api;
    else root.FPVRotationalDynamics=api;
})(typeof globalThis!=='undefined'?globalThis:this,function(){
    'use strict';
    const rad=Math.PI/180;
    const axes=['x','y','z'];
    const clamp=(n,lo,hi)=>Math.max(lo,Math.min(hi,n));
    const defaults=Object.freeze({rateProfile:'betaflight',superRate:.55,
        rollInertiaKgM2:.018,pitchInertiaKgM2:.021,yawInertiaKgM2:.03,
        rollTorqueNm:1,pitchTorqueNm:1,yawTorqueNm:.45,
        rollAccelerationLimitDegs2:4000,pitchAccelerationLimitDegs2:4000,yawAccelerationLimitDegs2:2200,
        controllerGainPerSecond:16,motorResponseTimeConstantSeconds:.035,
        passiveDampingPerSecond:.15});
    const fields=[
        ['superRate',0,.95],
        ['rollInertiaKgM2',.0001,5],['pitchInertiaKgM2',.0001,5],['yawInertiaKgM2',.0001,5],
        ['rollTorqueNm',.0001,20],['pitchTorqueNm',.0001,20],['yawTorqueNm',.0001,20],
        ['rollAccelerationLimitDegs2',10,20000],['pitchAccelerationLimitDegs2',10,20000],['yawAccelerationLimitDegs2',10,20000],
        ['controllerGainPerSecond',.1,100],['motorResponseTimeConstantSeconds',0,.5],['passiveDampingPerSecond',0,5]
    ];
    function configuration(value={}){
        if(!value||typeof value!=='object'||Array.isArray(value))throw Error('Invalid rotational dynamics configuration');
        const result={...defaults,...value};
        if(!['betaflight','legacyExpo','linear'].includes(result.rateProfile))throw Error('Unknown Acro rate profile');
        for(const [name,min,max] of fields){
            const v=result[name];
            if(typeof v!=='number'||!Number.isFinite(v)||v<min||v>max)throw Error(`Invalid rotational dynamics ${name}`);
        }
        return Object.freeze(Object.fromEntries(Object.keys(defaults).map(k=>[k,result[k]])));
    }
    function targetRate(stick,maximumDegreesPerSecond,expo,config){
        if(!Number.isFinite(stick)||Math.abs(stick)>1||!Number.isFinite(maximumDegreesPerSecond)||maximumDegreesPerSecond<0||!Number.isFinite(expo)||expo<0||expo>1)
            throw Error('Invalid rotational rate input');
        const shaped=config.rateProfile==='linear'?stick:stick*((1-expo)+expo*stick*stick);
        // Betaflight-inspired Super Rate shape normalized to preserve the
        // existing user-specified FULL stick max rates in degrees/s.
        const multiplier=config.rateProfile==='betaflight'?
            (1-config.superRate)/(1-config.superRate*Math.abs(shaped)):1;
        return shaped*multiplier*maximumDegreesPerSecond*rad;
    }
    const initialState=()=>({x:0,y:0,z:0});
    function step(rates,torques,sticks,maxRatesDegreesPerSecond,expo,authority,seconds,config){
        const targets={};
        for(const axis of axes)targets[axis]=targetRate(sticks[axis],maxRatesDegreesPerSecond[axis],expo,config);
        return stepTargetRates(rates,torques,targets,authority,seconds,config);
    }
    // Shared actuator/torque path: both stick-derived Acro rates and GPS
    // attitude-controller target rates obey the same motor/inertia constraints.
    function stepTargetRates(rates,torques,targetRates,authority,seconds,config){
        if(!Number.isFinite(seconds)||seconds<=0||seconds>.05||!Number.isFinite(authority)||authority<0||authority>1)
            throw Error('Invalid rotational integration step');
        const inertia=[config.rollInertiaKgM2,config.pitchInertiaKgM2,config.yawInertiaKgM2];
        const limits=[config.rollTorqueNm,config.pitchTorqueNm,config.yawTorqueNm];
        const accel=[config.rollAccelerationLimitDegs2,config.pitchAccelerationLimitDegs2,config.yawAccelerationLimitDegs2];
        const result={rates:{},torques:{},averageRates:{},angularAcceleration:{},targets:{}};
        for(let i=0;i<3;i++){
            const axis=axes[i],previous=rates[axis],oldTorque=torques[axis];
            if(!Number.isFinite(previous)||!Number.isFinite(oldTorque))throw Error('Invalid rotational state');
            const target=targetRates[axis];
            if(!Number.isFinite(target)||Math.abs(target)>100)throw Error('Invalid commanded angular rate');
            const maximum=limits[i]*authority;
            const requested=clamp(inertia[i]*(target-previous)*config.controllerGainPerSecond,-maximum,maximum);
            const tau=config.motorResponseTimeConstantSeconds;
            const smooth=tau===0?0:Math.exp(-seconds/tau);
            // Torque actuator lags command; a falling supply cap is enforced
            // immediately so power cut cannot leave fictitious motor torque.
            const torque=clamp(requested+(oldTorque-requested)*smooth,-maximum,maximum);
            const acceleration=clamp(torque/inertia[i]-config.passiveDampingPerSecond*previous,
                -accel[i]*rad,accel[i]*rad);
            const next=previous+acceleration*seconds;
            result.rates[axis]=next;
            result.torques[axis]=torque;
            result.averageRates[axis]=(previous+next)*.5;
            result.angularAcceleration[axis]=acceleration;
            result.targets[axis]=target;
        }
        return result;
    }
    return {configuration,initialState,targetRate,step,stepTargetRates};
});
