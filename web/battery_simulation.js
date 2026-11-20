// FPVManager simulated estimates; never real battery telemetry.
// Chemistry source of truth: assets/battery/chemistries.json (generated for JS + Dart).
// Level-flight interpolation and climb work mirror route_energy.dart.
(function(root,factory){
    const node=typeof module==='object'&&module.exports;
    const api=factory(node?require('./battery_chemistries.generated.js'):root.FPVBatteryChemistries);
    if(node)module.exports=api;
    else root.FPVBatterySimulation=api;
})(typeof globalThis!=='undefined'?globalThis:this,function(catalog){
    'use strict';
    const clamp=(v,a,b)=>Math.max(a,Math.min(b,v));
    const number=(v,min,max)=>Number.isFinite(v)&&v>=min&&v<=max;
    function chemistry(name){
        const token=String(name??'').toLowerCase().replace(/[^a-z0-9]/g,'');
        return Object.values(catalog||{}).find(c=>c.id.toLowerCase()===token||
            c.aliases.some(a=>a.toLowerCase().replace(/[^a-z0-9]/g,'')===token))||null;
    }
    function normalize(p){
        if(!p||typeof p!=='object'||!chemistry(p.chemistry)||!Number.isInteger(p.cellCount)||p.cellCount<1||p.cellCount>16||
            !number(p.capacityMah,1,100000)||!number(p.chargePercent,0,100)||
            !number(p.hoverPowerWatts,.01,100000)||!number(p.cruisePowerWatts,.01,100000)||
            !number(p.cruiseSpeedMetersPerSecond,.1,150))return null;
        const cell=chemistry(p.chemistry),nominal=number(p.nominalVoltageVolts,p.cellCount*.8,p.cellCount*5)
            ?p.nominalVoltageVolts:p.cellCount*cell.nominalVolts;
        const capacityWh=number(p.energyWh,.01,100000)?p.energyWh:nominal*p.capacityMah/1000;
        if(!number(capacityWh,.01,100000))return null;
        const maxSpeed=number(p.maxSpeedMetersPerSecond,p.cruiseSpeedMetersPerSecond+.01,150)
            ?p.maxSpeedMetersPerSecond:null;
        const maxPower=maxSpeed!==null&&number(p.maxPowerWatts,p.cruisePowerWatts,100000)
            ?p.maxPowerWatts:null;
        const dischargeC=number(p.continuousDischargeC,.01,1000)?p.continuousDischargeC:cell.referenceContinuousC;
        const resistance=number(p.resistanceOhmsPerCell,.000001,.5)?p.resistanceOhmsPerCell:
            cell.resistanceOhmsAt1Ah/Math.max(.001,p.capacityMah/1000);
        const burstC=number(p.burstDischargeC,.01,1000)?p.burstDischargeC:null;
        const burstSeconds=number(p.burstDurationSeconds,.01,3600)?p.burstDurationSeconds:null;
        const validBurst=burstC!==null&&burstSeconds!==null&&burstC>=dischargeC;
        const specificResistance=number(p.resistanceOhmsPerCell,.000001,.5);
        const driveCount=Number.isInteger(p.motorCount)&&p.motorCount>=1&&p.motorCount<=32?p.motorCount:null;
        const escLimit=number(p.escContinuousCurrentAmpsPerChannel,.001,1000)?p.escContinuousCurrentAmpsPerChannel:null;
        const motorLimit=number(p.motorContinuousCurrentAmpsPerMotor,.001,1000)?p.motorContinuousCurrentAmpsPerMotor:null;
        return {...p,cell,nominal,capacityWh,maxSpeed,maxPower,dischargeC,resistance,
            driveCount,escLimit,motorLimit,
            specificResistance,burstC:validBurst?burstC:null,
            burstSeconds:validBurst?burstSeconds:null,
            massKg:number(p.takeoffWeightGrams,1,50000)?p.takeoffWeightGrams/1000:null};
    }
    function openCircuitCellVoltage(soc,cell){
        const s=clamp(soc,0,1),points=cell.curve;
        for(let i=1;i<points.length;i++)if(s<=points[i][0]){
            const [a,x]=points[i-1],[b,y]=points[i];
            return x+(y-x)*(s-a)/(b-a);
        }
        return points[points.length-1][1];
    }
    function levelPower(p,speed){
        const v=clamp(Number.isFinite(speed)?speed:0,0,150),c=p.cruiseSpeedMetersPerSecond;
        if(p.maxSpeed!==null&&p.maxPower!==null&&v>c){
            const ratio=clamp((v-c)/(p.maxSpeed-c),0,1);
            return {watts:p.cruisePowerWatts+(p.maxPower-p.cruisePowerWatts)*ratio,extrapolated:v>p.maxSpeed};
        }
        if(v<=c)return {watts:p.hoverPowerWatts+(p.cruisePowerWatts-p.hoverPowerWatts)*v/c,extrapolated:false};
        return {watts:p.cruisePowerWatts*(1+.5*clamp((v-c)/c,0,4)),extrapolated:true};
    }
    // A live Acro/Angle flight has a motor-thrust estimate. Horizontal motion
    // alone cannot consume propulsive power: a drone in a zero-throttle dive
    // can retain substantial airspeed while its propellers are nearly idle.
    // Level-power interpolation remains the proxy for GPS flight and replay,
    // where actual motor thrust is not reconstructed from recorded positions.
    function poweredFlightPower(p,horizontalAirSpeed,thrustToWeight){
        const level=levelPower(p,horizontalAirSpeed);
        if(!Number.isFinite(thrustToWeight)||thrustToWeight<0||thrustToWeight>12)
            return {watts:level.watts,extrapolated:level.extrapolated};
        const idleWatts=clamp(p.hoverPowerWatts*.08,10,25);
        // Hover calibration: exactly hoverPowerWatts at one g and zero speed.
        // Forward flight adds a bounded share of the configured speed load;
        // actual thrust, not falling airspeed, gates propulsive consumption.
        const forwardCost=Math.max(0,level.watts-p.hoverPowerWatts)*.65;
        const propulsiveWatts=(p.hoverPowerWatts+forwardCost-idleWatts)*
            Math.pow(thrustToWeight,1.5);
        return {watts:clamp(idleWatts+propulsiveWatts,idleWatts,
            p.maxPower??100000),extrapolated:level.extrapolated};
    }
    function estimateLoad(p,soc,power,resistance,secondsAboveContinuous=0){
        const openCell=openCircuitCellVoltage(soc,p.cell);
        const openPack=openCell*p.cellCount;
        const packResistance=resistance*p.cellCount;
        const discriminant=openPack*openPack-4*packResistance*power;
        const current=power===0?0:packResistance===0?power/openPack:
            discriminant<=0?openPack/(2*packResistance):2*power/(openPack+Math.sqrt(discriminant));
        const lower=p.cell.curve[0][1]-.3;
        const continuousLimit=p.dischargeC*p.capacityMah/1000;
        const burstLimit=p.burstC===null?null:p.burstC*p.capacityMah/1000;
        const burstAvailable=burstLimit!==null&&p.burstSeconds!==null&&
            secondsAboveContinuous<=p.burstSeconds&&current<=burstLimit;
        return {currentAmps:current,packVoltageVolts:Math.max(p.cellCount*lower,openPack-current*packResistance),
            currentLimitAmps:continuousLimit,burstLimitAmps:burstLimit,
            burstRemainingSeconds:p.burstSeconds===null?null:Math.max(0,p.burstSeconds-secondsAboveContinuous),
            exceedsReferenceCurrent:(current>continuousLimit&&!burstAvailable)||discriminant<0,
            powerDeliveryUncertain:discriminant<0};
    }
    function create(profile,options={}){
        const p=normalize(profile);if(!p)return null;
        // An explicit positive override retains the existing HUD resistance setting;
        // 0 (the old default) now selects chemistry-based approximate resistance.
        // A battery-specific value takes precedence over the legacy HUD-level override.
        const resistance=p.specificResistance?p.resistance:
            number(options.resistanceOhmsPerCell,.000001,.1)?options.resistanceOhmsPerCell:p.resistance;
        let consumedWh=0,consumedAh=0,estimatedPowerWatts=0,extrapolated=false;
        let secondsAboveContinuous=0;
        function currentSoc(){return clamp(p.chargePercent/100-consumedAh/(p.capacityMah/1000),0,1);}
        function snapshot(thresholds={}){
            const soc=currentSoc();
            const load=estimateLoad(p,soc,estimatedPowerWatts,resistance,secondsAboveContinuous);
            const low=number(thresholds.lowVoltagePerCell,.5,4.5)?thresholds.lowVoltagePerCell:p.cell.lowVolts;
            const critical=number(thresholds.criticalVoltagePerCell,.5,4.5)?thresholds.criticalVoltagePerCell:p.cell.criticalVolts;
            const cellVoltage=load.packVoltageVolts/p.cellCount;
            // Independent, per-channel/per-motor limits. This is only a
            // DC equal-share proxy: PWM motor phase current is not modeled.
            const perUnit=p.driveCount===null?null:load.currentAmps/p.driveCount;
            return {estimated:true,available:true,packVoltageVolts:load.packVoltageVolts,
                cellVoltageVolts:cellVoltage,cellCount:p.cellCount,remainingPercent:soc*100,
                remainingEnergyWh:Math.max(0,Math.min(p.capacityWh*soc,
                    p.capacityWh*p.chargePercent/100-consumedWh)),
                consumedAh,consumedWh,estimatedPowerWatts,extrapolated,
                currentAmps:load.currentAmps,currentLimitAmps:load.currentLimitAmps,
                estimatedInputCurrentPerMotorAmps:perUnit,
                escContinuousCurrentAmpsPerChannel:p.escLimit,
                motorContinuousCurrentAmpsPerMotor:p.motorLimit,
                escPossiblyOverloaded:perUnit===null||p.escLimit===null?null:perUnit>p.escLimit,
                motorPossiblyOverloaded:perUnit===null||p.motorLimit===null?null:perUnit>p.motorLimit,
                propulsionCurrentSource:'estimated-equal-share-dc-input', 
                burstLimitAmps:load.burstLimitAmps,
                burstRemainingSeconds:load.burstRemainingSeconds,
                currentLimitEstimated:!number(p.continuousDischargeC,.01,1000),
                exceedsReferenceCurrent:load.exceedsReferenceCurrent,
                powerDeliveryUncertain:load.powerDeliveryUncertain,
                chemistry:p.cell.id,thresholdSource:number(thresholds.lowVoltagePerCell,.5,4.5)?'custom':'chemistry',
                level:cellVoltage<=critical?'critical':cellVoltage<=low?'low':'normal',
                source:'estimated',sagApplied:resistance>0};
        }
        function tick(dt,horizontalAirSpeed,verticalSpeed,flightLoad=null){
            if(!number(dt,0,.5)||dt===0)return snapshot();
            const thrustG=flightLoad&&Number.isFinite(flightLoad.thrustToWeight)
                ?flightLoad.thrustToWeight:null;
            const base=poweredFlightPower(p,horizontalAirSpeed,thrustG);
            extrapolated=extrapolated||base.extrapolated;
            // Thrust already includes the cost of climbing in manual flight.
            // GPS/replay do not expose thrust; use a separate climb-work proxy.
            const climb=thrustG===null&&p.massKg!==null
                ?p.massKg*9.80665*Math.max(0,Number.isFinite(verticalSpeed)?verticalSpeed:0)/.65:0;
            estimatedPowerWatts=clamp(base.watts+climb,0,100000);
            const load=estimateLoad(p,currentSoc(),estimatedPowerWatts,resistance,secondsAboveContinuous);
            // Conservative continuous accumulation: once the burst allowance is exhausted,
            // it is not automatically reset by a short idle interval.
            if(load.currentAmps>load.currentLimitAmps)secondsAboveContinuous+=dt;
            // Coulomb count from modeled terminal voltage, not nominal voltage.
            // This changes endurance with chemistry/load; severe overload is flagged,
            // not claimed to be a physically sustainable drone power output.
            consumedWh=Math.min(p.capacityWh*p.chargePercent/100,consumedWh+estimatedPowerWatts*dt/3600);
            consumedAh=Math.min(p.capacityMah*p.chargePercent/1000,
                consumedAh+load.currentAmps*dt/3600);
            return snapshot();
        }
        return {tick,snapshot,get consumedWh(){return consumedWh;}};
    }
    return {create,normalize,chemistry,levelPower,poweredFlightPower,openCircuitCellVoltage,estimateLoad};
});
