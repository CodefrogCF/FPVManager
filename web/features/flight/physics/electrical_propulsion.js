// Deterministic, approximate DC battery-to-propulsion coupling for Advanced FPV flight.
// NOT measured battery telemetry, motor phase current, or a battery-protection device.
(function(root,factory){
    const api=factory();
    if(typeof module==='object'&&module.exports)module.exports=api;
    else root.FPVElectricalPropulsion=api;
})(typeof globalThis!=='undefined'?globalThis:this,function(){
    'use strict';
    const clamp=(v,min,max)=>Math.max(min,Math.min(max,v));
    function step(drive,battery,target,dt){
        if(!drive||!battery||typeof battery.electricalState!=='function')
            throw Error('A propulsion model and chemistry-aware battery are required');
        // Advance inertia ONCE per physical step. Evaluation at several voltages
        // must never advance the motor, battery or clock several times.
        const commandedFraction=drive.advanceCommand(target,dt);
        const cell=battery.electricalState();
        const ocv=cell.openCircuitPackVoltageVolts;
        const R=cell.resistanceOhms;
        const auxiliary=cell.auxiliaryPowerWatts;
        const cutoff=cell.minimumCellVoltageVolts*cell.cellCount;
        // A depleted battery cannot deliver a new motor-current budget.
        const ratingLimit=cell.available?cell.dischargeCurrentLimitAmps:0;
        const voltageLimit=R>0?Math.max(0,(ocv-cutoff)/R):ocv>cutoff?Number.MAX_SAFE_INTEGER:0;
        const limitCurrent=Math.max(0,Math.min(ratingLimit,voltageLimit));
        const limitSource=!cell.available?'battery-depleted':voltageLimit<ratingLimit?
            'battery-low-voltage':'battery-discharge-current';
        const evaluate=v=>{
            // Auxiliary power is reserved BEFORE providing DC input power to ESCs.
            const availableForMotors=Math.max(0,limitCurrent*v-auxiliary);
            const prop=drive.evaluate(v,availableForMotors);
            const demand=prop.propulsionPowerWatts+auxiliary;
            const current=clamp(demand/Math.max(.01,v),0,limitCurrent);
            return {prop,current,demand};
        };
        let volts=ocv,iterations=0,converged=false;
        for(let i=0;i<16;i++){
            const load=evaluate(volts);
            const next=clamp(ocv-load.current*R,Math.min(cutoff,ocv),ocv);
            iterations=i+1;
            if(Math.abs(next-volts)<.00001){volts=next;converged=true;break;}
            // Direct fixed-point update converges rapidly for the usual
            // motor P(V) curve. The hard iteration bound prevents stalls.
            volts=next;
        }
        // Always calculate the propulsion state from the *same* terminal
        // voltage used by the committed battery consumption, not the OCV.
        const final=evaluate(volts);
        const terminal=clamp(ocv-final.current*R,Math.min(cutoff,ocv),ocv);
        if(!converged&&Math.abs(terminal-volts)<.0001)converged=true;
        // Reevaluate once to keep the motor output close to the terminal
        // voltage after the final fixed-point iteration.
        volts=terminal;
        const result=evaluate(volts);
        const actualPower=Math.min(result.demand,result.current*volts);
        const availableAuxiliary=Math.min(auxiliary,actualPower);
        const motorCurrent=Math.min(result.current,Math.max(0,result.prop.propulsionPowerWatts/Math.max(.01,volts)));
        const batteryLimited=result.prop.limitSource==='battery-dc-current-cap' ||
            (!cell.available&&commandedFraction>0) ||
            (limitCurrent===0&&commandedFraction>0);
        const electrical={electricalCoupling:'estimated-battery-motor-dc',
            estimated:true,packVoltageVolts:volts,currentAmps:result.current,
            totalPowerWatts:actualPower,estimatedMotorDcInputCurrentAmps:motorCurrent,
            auxiliaryCurrentAmps:availableAuxiliary/Math.max(.01,volts),
            currentLimitAmps:cell.continuousCurrentLimitAmps,
            burstLimitAmps:cell.burstCurrentLimitAmps,
            burstRemainingSeconds:cell.burstRemainingSeconds,
            exceedsReferenceCurrent:result.current>cell.continuousCurrentLimitAmps+1e-6&&!cell.burstAllowed,
            batteryCurrentLimited:batteryLimited,batteryLimitSource:batteryLimited?limitSource:null,
            escCurrentLimited:result.prop.activeLimitSources.includes('esc-dc-input-proxy'),
            motorCurrentLimited:result.prop.activeLimitSources.includes('motor-dc-input-proxy'),
            propulsionPowerLimited:result.prop.limited,
            propulsionLimitSource:result.prop.limitSource,
            powerDeliveryUncertain:!converged || cell.dischargeRatingSource==='chemistry-estimate',
            iterationCount:iterations,converged};
        return {propulsion:{...result.prop,loadedPackVoltageVolts:volts,
                estimatedCurrentAmps:motorCurrent,batteryCurrentLimited:batteryLimited,
                batteryLimitSource:batteryLimited?limitSource:null,
                coupled:true},electrical};
    }
    return {step};
});
