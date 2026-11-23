// Experimental local terrain-height comparison: choose equivalent ground
// surfaces at nearly the same geographic location in the live Cesium scene.
// This is a visual calibration, not a terrain survey.
(function(root,factory){const api=factory();if(typeof module==='object'&&module.exports)module.exports=api;else root.FPVSceneryBridgeCalibration=api;})(typeof globalThis!=='undefined'?globalThis:this,function(){
    'use strict';
    const MAX_HORIZONTAL_M=12;
    const MAX_CORRECTION_M=60;
    function compare(source,target,existingOffsetM=0){
        const keys=['longitude','latitude','height'];
        if(!source||!target||!keys.every(k=>Number.isFinite(source[k])&&Number.isFinite(target[k]))||
            !Number.isFinite(existingOffsetM))throw Error('Missing valid 3D surface position');
        if(Math.abs(source.latitude)>90||Math.abs(target.latitude)>90||Math.abs(source.longitude)>180||Math.abs(target.longitude)>180)
            throw Error('Invalid surface coordinates');
        const rad=Math.PI/180,lat=(source.latitude+target.latitude)/2*rad;
        const east=(target.longitude-source.longitude)*111320*Math.cos(lat);
        const north=(target.latitude-source.latitude)*111320;
        const horizontalM=Math.hypot(east,north);
        if(horizontalM>MAX_HORIZONTAL_M)throw Error('Bodenpunkte liegen mehr als 12 m auseinander; dieselbe Stelle im Scan und auf der Karte wählen');
        const deltaM=target.height-source.height;
        const proposedOffsetM=existingOffsetM+deltaM;
        if(Math.abs(deltaM)>MAX_CORRECTION_M||Math.abs(proposedOffsetM)>MAX_CORRECTION_M)
            throw Error('Höhenkorrektur überschreitet ±60 m; bitte die beiden Bodenpunkte prüfen');
        return {deltaM:Math.round(deltaM*100)/100,
            proposedOffsetM:Math.round(proposedOffsetM*100)/100,
            horizontalM:Math.round(horizontalM*10)/10,
            warning:horizontalM>3?'Die Bodenpunkte liegen mehr als 3 m auseinander; ein Geländegefälle kann den Vergleich verfälschen':null};
    }
    return {compare,MAX_HORIZONTAL_M,MAX_CORRECTION_M};
});
