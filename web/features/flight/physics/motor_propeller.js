// Lightweight, assumption-based multirotor propulsion model (SI units).
// NOT an ESC phase-current model and NOT calibrated manufacturer data.
(function(root,factory){
    const api=factory();
    if(typeof module==='object'&&module.exports)module.exports=api;
    else root.FPVMotorPropeller=api;
})(typeof globalThis!=='undefined'?globalThis:this,function(){
    'use strict';
    const rho=1.225,g=9.80665,inch=.0254;
    const clamp=(x,min,max)=>Math.max(min,Math.min(max,x));
    const within=(v,min,max)=>Number.isFinite(v)&&v>=min&&v<=max;
    function bladeCount(description){
        // propellerCount in the database is the number of propellers, NOT blades.
        const match=String(description??'').match(/(?:^|[^\d])\d+(?:[.,]\d+)?\s*[x×]\s*\d+(?:[.,]\d+)?\s*[x×]\s*(\d+)(?:\D|$)/i);
        return match&&within(Number(match[1]),2,8)?Number(match[1]):null;
    }
    function curvePoints(value){
        if(!Array.isArray(value)||value.length<2||value.length>64)return null;
        let last=-1;
        const points=[];
        for(const p of value){
            const t=p?.throttle,thrust=p?.thrustNewtonsPerMotor,power=p?.powerWattsPerMotor;
            if(!within(t,0,1)||t<=last||!within(thrust,0,500)||!within(power,0,10000))return null;
            points.push({throttle:t,thrustNewtonsPerMotor:thrust,powerWattsPerMotor:power,
                rpm:within(p.rpm,0,120000)?p.rpm:null});last=t;
        }
        return points[0].throttle===0&&points.at(-1).throttle===1?points:null;
    }
    function normalize(value){
        if(!value||typeof value!=='object')return null;
        const motorKv=value.motorKv,motors=value.motorCount,diameter=value.propellerDiameterInches,
            pitch=value.propellerPitchInches,mass=value.takeoffWeightGrams,
            voltage=value.referenceVoltageVolts;
        if(!within(motorKv,100,6000)||!Number.isInteger(motors)||motors<1||motors>32||
            !within(diameter,1,30)||!within(pitch,.1,30)||!within(mass,50,50000)||
            !within(voltage,2,100))return null;
        const blades=within(value.bladeCount,2,8)?value.bladeCount:bladeCount(value.propellerDescription)??3;
        const rpmEfficiency=within(value.rpmEfficiency,.3,.98)?value.rpmEfficiency:.70;
        const propellerEfficiency=within(value.propellerEfficiency,.3,.95)?value.propellerEfficiency:.72;
        const motorTimeConstant=within(value.motorTimeConstantSeconds,0,.5)?value.motorTimeConstantSeconds:.055;
        const curve=value.manufacturerCurve===undefined||value.manufacturerCurve===null?null:curvePoints(value.manufacturerCurve);
        const invalidCurve=value.manufacturerCurve!=null&&!curve;
        if(invalidCurve)return null; // Never silently use an invalid manufacturer claim.
        for(const [key,min,max] of [['bladeCount',2,8],['rpmEfficiency',.3,.98],
            ['propellerEfficiency',.3,.95],['motorTimeConstantSeconds',0,.5]]){
            if(value[key]!=null&&!within(value[key],min,max))return null;
        }
        const maxPowerWatts=within(value.maxPowerWatts,1,50000)?value.maxPowerWatts:null;
        const escAmps=within(value.escContinuousCurrentAmpsPerChannel,.1,1000)?value.escContinuousCurrentAmpsPerChannel:null;
        const motorAmps=within(value.motorContinuousCurrentAmpsPerMotor,.1,1000)?value.motorContinuousCurrentAmpsPerMotor:null;
        return {motorKv,motorCount:motors,diameterMeters:diameter*inch,pitchRatio:pitch/diameter,
            bladeCount:blades,massKg:mass/1000,referenceVoltageVolts:voltage,
            rpmEfficiency,propellerEfficiency,motorTimeConstant,
            manufacturerCurve:curve,maxPowerWatts,escAmps,motorAmps,
            source:curve?'manufacturer-curve-unverified':'generic-propeller-coefficients',
            bladeCountEstimated:value.bladeCount==null&&bladeCount(value.propellerDescription)==null};
    }
    function lerpCurve(curve,command){
        for(let i=1;i<curve.length;i++)if(command<=curve[i].throttle){
            const a=curve[i-1],b=curve[i],t=(command-a.throttle)/(b.throttle-a.throttle);
            const mix=k=>a[k]+(b[k]-a[k])*t;
            return {thrustNewtonsPerMotor:mix('thrustNewtonsPerMotor'),powerWattsPerMotor:mix('powerWattsPerMotor'),
                rpm:a.rpm===null||b.rpm===null?null:mix('rpm')};
        }
        return {...curve.at(-1)};
    }
    function output(p,command,voltage,externalPowerLimit=null){
        const fraction=clamp(command,0,1),v=within(voltage,1,100)?voltage:p.referenceVoltageVolts;
        let rpm,thrust,power;
        if(p.manufacturerCurve){
            const sample=lerpCurve(p.manufacturerCurve,fraction);
            // Manufacturer curve is taken at reference voltage; an approximate
            // scaling is used at other voltages until issue #136 couples the pack.
            const ratio=clamp(v/p.referenceVoltageVolts,.25,1.3);
            rpm=sample.rpm===null?p.motorKv*v*p.rpmEfficiency*fraction:sample.rpm*ratio;
            thrust=sample.thrustNewtonsPerMotor*ratio*ratio;
            power=sample.powerWattsPerMotor*ratio**3;
        }else{
            rpm=p.motorKv*v*p.rpmEfficiency*fraction;
            const n=rpm/60,D=p.diameterMeters;
            // Bounded generic static propeller coefficients. These are NOT
            // measured coefficients for any particular motor/propeller pair.
            const ct=clamp(.072*(p.bladeCount/3)**.23*(p.pitchRatio/.5)**.18,.035,.14);
            const cp=clamp(.039*(p.bladeCount/3)**.32*(p.pitchRatio/.5)**.35,.018,.085);
            thrust=ct*rho*n*n*D**4;
            power=cp*rho*n**3*D**5/p.propellerEfficiency;
        }
        const unrestrictedPower=power*p.motorCount;
        const limits=[
            {value:p.maxPowerWatts,source:'drone-max-power'},
            {value:p.escAmps===null?null:p.escAmps*p.motorCount*v,source:'esc-dc-input-proxy'},
            {value:p.motorAmps===null?null:p.motorAmps*p.motorCount*v,source:'motor-dc-input-proxy'},
            {value:within(externalPowerLimit,0,100000)?externalPowerLimit:null,source:'battery-dc-current-cap'},
            // Generic assumptions must not create unbounded physical forces.
            // Explicit measured curves/power limits are not replaced by made-up
            // manufacturer ratings; this is a numerical envelope only.
            {value:p.manufacturerCurve?null:Math.min(50000,p.massKg*4000),source:'generic-simulation-envelope'}
        ].filter(item=>Number.isFinite(item.value));
        const activeLimit=limits.length?limits.reduce((a,b)=>a.value<=b.value?a:b):null;
        const limit=activeLimit?.value??null;
        const ratio=limit!==null&&unrestrictedPower>limit&&unrestrictedPower>0?limit/unrestrictedPower:1;
        // P ∝ RPM³ and T ∝ RPM² (static approximation).
        rpm*=Math.cbrt(ratio);thrust*=ratio**(2/3);power*=ratio;
        // Further bound extreme user input, including unrealistic large props
        // at very high KV, so terrain sweeps never see unbounded acceleration.
        const maxThrust=12*p.massKg*g;
        if(thrust*p.motorCount>maxThrust){
            const r=maxThrust/(thrust*p.motorCount);
            rpm*=Math.sqrt(r);thrust*=r;power*=r**1.5;
        }
        const activeLimitSources=ratio<1?limits.filter(item=>
            Math.abs(item.value-limit)<=Math.max(1e-6,limit*1e-8)).map(item=>item.source):[];
        return {rpm,thrustNewtonsPerMotor:thrust,powerWattsPerMotor:power,
            totalThrustNewtons:thrust*p.motorCount,propulsionPowerWatts:power*p.motorCount,
            estimatedCurrentAmps:power*p.motorCount/v,
            limited:ratio<1||thrust*p.motorCount>=maxThrust-1e-7,
            limitSource:ratio<1?activeLimit.source:thrust*p.motorCount>=maxThrust-1e-7?'numerical-thrust-envelope':null,
            activeLimitSources,
            source:p.source,estimated:true};
    }
    function create(profile){
        const p=normalize(profile);
        if(!p)return null;
        let command=0,last=output(p,0,p.referenceVoltageVolts);
        function reset(initial=0){command=clamp(initial,0,1);last=output(p,command,p.referenceVoltageVolts);return last;}
        function advanceCommand(target,dt){
            if(!within(dt,0,1)||!Number.isFinite(target))throw Error('Invalid propulsion integration step');
            const tau=p.motorTimeConstant;
            command=clamp(target,0,1)+(command-clamp(target,0,1))*(tau>0?Math.exp(-dt/tau):0);
            return command;
        }
        function evaluate(voltage,powerLimit=null){
            last=output(p,command,voltage,powerLimit);
            return last;
        }
        function tick(target,dt,voltage){
            advanceCommand(target,dt);
            return evaluate(voltage);
        }
        function hoverCommand(voltage=p.referenceVoltageVolts){
            const required=p.massKg*g;
            if(output(p,1,voltage).totalThrustNewtons<required)return 1;
            let lo=0,hi=1;
            for(let i=0;i<28;i++){
                const mid=(lo+hi)*.5;
                if(output(p,mid,voltage).totalThrustNewtons<required)lo=mid;else hi=mid;
            }
            return (lo+hi)/2;
        }
        return {configuration:p,reset,tick,advanceCommand,evaluate,hoverCommand,
            get state(){return {...last,command,hoverCommand:hoverCommand(),massKg:p.massKg,
                maximumThrustToWeight:output(p,1,p.referenceVoltageVolts).totalThrustNewtons/(p.massKg*g)};}};
    }
    return {normalize,bladeCount,curvePoints,output,create};
});
