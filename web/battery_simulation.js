// FPVManager Issue #123: local, deterministic ESTIMATES, never real battery telemetry.
// Level-flight power interpolation and climb work mirror route_energy.dart.
(function(root,factory){
    const api=factory();
    if(typeof module==='object'&&module.exports)module.exports=api;
    else root.FPVBatterySimulation=api;
})(typeof globalThis!=='undefined'?globalThis:this,function(){
    'use strict';
    const clamp=(v,a,b)=>Math.max(a,Math.min(b,v));
    const number=(v,min,max)=>Number.isFinite(v)&&v>=min&&v<=max;
    const CHEMISTRY={lipo:{nominal:3.7,empty:3.3,full:4.2},lihv:{nominal:3.8,empty:3.3,full:4.35},liion:{nominal:3.6,empty:3.0,full:4.2}};
    function chemistry(name){const value=String(name??'').toLowerCase().replace(/[^a-z]/g,'');
        return value==='lipo'?CHEMISTRY.lipo:value==='lihv'?CHEMISTRY.lihv:
            ['liion','lion','lithiumion'].includes(value)?CHEMISTRY.liion:null;}
    function normalize(p){
        if(!p||typeof p!=='object'||!chemistry(p.chemistry)||!Number.isInteger(p.cellCount)||p.cellCount<1||p.cellCount>16||
            !number(p.capacityMah,1,100000)||!number(p.chargePercent,0,100)||
            !number(p.hoverPowerWatts,.01,100000)||!number(p.cruisePowerWatts,.01,100000)||
            !number(p.cruiseSpeedMetersPerSecond,.1,150))return null;
        const cell=chemistry(p.chemistry),nominal=number(p.nominalVoltageVolts,p.cellCount*2.5,p.cellCount*4.3)
            ?p.nominalVoltageVolts:p.cellCount*cell.nominal;
        const capacityWh=number(p.energyWh,0.01,100000)?p.energyWh:nominal*p.capacityMah/1000;
        if(!number(capacityWh,.01,100000))return null;
        const maxSpeed=number(p.maxSpeedMetersPerSecond,p.cruiseSpeedMetersPerSecond+0.01,150)
            ?p.maxSpeedMetersPerSecond:null;
        const maxPower=maxSpeed!=null&&number(p.maxPowerWatts,p.cruisePowerWatts,100000)
            ?p.maxPowerWatts:null;
        return {...p,cell,nominal,capacityWh,maxSpeed,maxPower,
            massKg:number(p.takeoffWeightGrams,1,50000)?p.takeoffWeightGrams/1000:null};
    }
    // Non-linear, illustrative open-circuit voltage. The endpoints do not
    // assert any battery has a safe flight reserve at zero modelled energy.
    const curve=[[0,0],[.1,.22],[.2,.34],[.4,.54],[.6,.66],[.8,.8],[.9,.9],[1,1]];
    function openCircuitCellVoltage(soc,cell){
        const s=clamp(soc,0,1);
        for(let i=1;i<curve.length;i++)if(s<=curve[i][0]){
            const [a,x]=curve[i-1],[b,y]=curve[i];
            return cell.empty+(cell.full-cell.empty)*(x+(y-x)*(s-a)/(b-a));
        }
        return cell.full;
    }
    function levelPower(p,speed){
        const v=clamp(Number.isFinite(speed)?speed:0,0,150),c=p.cruiseSpeedMetersPerSecond;
        if(p.maxSpeed!=null&&p.maxPower!=null&&v>c){
            const ratio=clamp((v-c)/(p.maxSpeed-c),0,1);
            return {watts:p.cruisePowerWatts+(p.maxPower-p.cruisePowerWatts)*ratio,extrapolated:v>p.maxSpeed};
        }
        if(v<=c)return {watts:p.hoverPowerWatts+(p.cruisePowerWatts-p.hoverPowerWatts)*v/c,extrapolated:false};
        // Above the known curve, use a bounded, explicit assumption rather
        // than pretending the cruise figure is a high-speed measurement.
        return {watts:p.cruisePowerWatts*(1+.5*clamp((v-c)/c,0,4)),extrapolated:true};
    }
    function create(profile,options={}){
        const p=normalize(profile);if(!p)return null;
        const resistance=number(options.resistanceOhmsPerCell,0,.1)?options.resistanceOhmsPerCell:0;
        let consumedWh=0,estimatedPowerWatts=0,extrapolated=false;
        function snapshot(thresholds={}){
            const soc=clamp(p.chargePercent/100-consumedWh/p.capacityWh,0,1);
            const openCell=openCircuitCellVoltage(soc,p.cell);
            const openPack=openCell*p.cellCount;
            const current=estimatedPowerWatts/Math.max(openPack,1);
            const cellVoltage=clamp(openCell-current*resistance,p.cell.empty-.3,p.cell.full);
            const low=number(thresholds.lowVoltagePerCell,3,4.3)?thresholds.lowVoltagePerCell:3.5;
            const critical=number(thresholds.criticalVoltagePerCell,2.8,4.2)?thresholds.criticalVoltagePerCell:3.3;
            return {estimated:true,available:true,packVoltageVolts:cellVoltage*p.cellCount,
                cellVoltageVolts:cellVoltage,cellCount:p.cellCount,remainingPercent:soc*100,
                consumedWh,estimatedPowerWatts,extrapolated,
                level:cellVoltage<=critical?'critical':cellVoltage<=low?'low':'normal',
                source:'estimated',sagApplied:resistance>0};
        }
        function tick(dt,airSpeed,verticalSpeed){
            if(!number(dt,0,.5)||dt===0)return snapshot();
            const base=levelPower(p,airSpeed);
            extrapolated=extrapolated||base.extrapolated;
            const climb=p.massKg==null?0:p.massKg*9.80665*Math.max(0,Number.isFinite(verticalSpeed)?verticalSpeed:0)/.65;
            // No downhill regenerative credit. Extra 10% allowance follows
            // the opt-in conservative route telemetry estimate.
            estimatedPowerWatts=clamp(base.watts*1.1+climb,0,100000);
            consumedWh=Math.min(p.capacityWh*p.chargePercent/100,consumedWh+estimatedPowerWatts*dt/3600);
            return snapshot();
        }
        return {tick,snapshot,get consumedWh(){return consumedWh;}};
    }
    return {create,normalize,levelPower,openCircuitCellVoltage};
});
