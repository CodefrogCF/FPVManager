// FPVManager – simulation-only, approximate RF link budgets and ideal free-space range.
// EU/FCC simulation scenarios. DJI ideal free-air range is used ONLY as an
// illustrative model calibration; thresholds are not measured sensitivities.
// Receiver thresholds, fade margins and additional terrain attenuation are
// user-configurable ASSUMPTIONS, not measured RF performance or guaranteed range.
(function(root,factory){const api=factory();if(typeof module==='object'&&module.exports)module.exports=api;else root.FPVRfEstimation=api;})(typeof globalThis!=='undefined'?globalThis:this,function(){
    'use strict';
    const presets=Object.freeze({
        video:Object.freeze({
            eu:Object.freeze({frequencyMhz:5800,eirpDbm:13.9,receiverThresholdDbm:-124,fadeMarginDb:12}),
            fcc:Object.freeze({frequencyMhz:5800,eirpDbm:32.9,receiverThresholdDbm:-110.3,fadeMarginDb:12})}),
        control:Object.freeze({
            eu:Object.freeze({frequencyMhz:868,eirpDbm:14,receiverThresholdDbm:-120,fadeMarginDb:10}),
            // Illustrative 250 mW, not a manufacturer-supported limit for every TX.
            fcc:Object.freeze({frequencyMhz:915,eirpDbm:24,receiverThresholdDbm:-120,fadeMarginDb:10})})});
    const defaults=Object.freeze({enabled:true,videoScenario:'eu',controlScenario:'eu',
        video:presets.video.eu,control:presets.control.eu});
    const clamp=(x,a=0,b=1)=>Math.max(a,Math.min(b,x));
    const round=(v,digits=1)=>Number(v.toFixed(digits));
    function configuration(options={}){
        if(!options||typeof options!=='object'||Array.isArray(options))throw Error('Invalid RF profile settings');
        const cfg={enabled:options.enabled??defaults.enabled};
        for(const type of ['video','control']){
            const region=options[`${type}Scenario`]??defaults[`${type}Scenario`];
            if(!['eu','fcc','custom'].includes(region))throw Error(`Invalid RF ${type} regulatory scenario`);
            cfg[`${type}Scenario`]=region;
        }
        if(typeof cfg.enabled!=='boolean')throw Error('Invalid RF simulation state');
        for(const type of ['video','control']){
            const override=options[type]??{};
            if(!override||typeof override!=='object'||Array.isArray(override))throw Error('Invalid RF profile');
            const profile={...(presets[type][cfg[`${type}Scenario`]]??defaults[type]),...override};
            for(const [key,min,max] of [['frequencyMhz',100,8000],['eirpDbm',-30,50],
                ['receiverThresholdDbm',-150,-40],['fadeMarginDb',0,50]])
                if(!Number.isFinite(profile[key])||profile[key]<min||profile[key]>max)throw Error(`Invalid RF ${type} ${key}`);
            cfg[type]=profile;
        }
        return cfg;
    }
    function distanceMeters(a,b){
        if(!a||!b||![a.latitude,a.longitude,b.latitude,b.longitude].every(Number.isFinite)||
            Math.abs(a.latitude)>90||Math.abs(b.latitude)>90||Math.abs(a.longitude)>180||Math.abs(b.longitude)>180)return null;
        const rad=Math.PI/180,dl=(b.latitude-a.latitude)*rad,dn=(b.longitude-a.longitude)*rad;
        const h=Math.sin(dl/2)**2+Math.cos(a.latitude*rad)*Math.cos(b.latitude*rad)*Math.sin(dn/2)**2;
        const surface=12756274*Math.asin(Math.sqrt(clamp(h)));
        // When both ellipsoidal heights are available, use approximate slant
        // distance rather than ground-projected distance. No earth curvature or
        // atmosphere model is implied for the maximum-range calculation.
        return Number.isFinite(a.height)&&Number.isFinite(b.height)
            ? Math.hypot(surface,b.height-a.height):surface;
    }
    function freeSpaceLossDb(distance,frequencyMhz){
        if(!Number.isFinite(distance)||distance<=0||!Number.isFinite(frequencyMhz)||frequencyMhz<=0)return null;
        return 32.44+20*Math.log10(distance/1000)+20*Math.log10(frequencyMhz);
    }
    function theoreticalRangeMeters(profile,extraLossDb=0){
        if(!profile||!Number.isFinite(extraLossDb)||extraLossDb<0)throw Error('Invalid RF extra loss');
        // 0 dB modelled margin, including the configured fade reserve. This
        // is free-space only; radio horizon, noise, multipath and dynamic
        // modulation modes are NOT modelled.
        const checked=configuration({video:profile}).video;
        const permittedLoss=checked.eirpDbm-checked.receiverThresholdDbm-checked.fadeMarginDb-extraLossDb;
        return 1000*Math.pow(10,(permittedLoss-32.44-20*Math.log10(checked.frequencyMhz))/20);
    }
    function excessTerrainLossDb(visibility,minimumClearance,minimumFresnelMargin){
        // Heuristic, not calibrated diffraction or real material attenuation.
        const intrusion=Math.max(0,Number.isFinite(minimumFresnelMargin)?-minimumFresnelMargin:0);
        const blocking=Math.max(0,Number.isFinite(minimumClearance)?-minimumClearance:0);
        // Obstructed terrain is treated as a high-risk *scenario* (not a proven
        // outage). Deep ridge blockage must degrade the modeled RC link as well.
        return visibility==='obstructed'?(38+Math.min(55,blocking*.9)):
            visibility==='fresnelIntrusion'?(6+Math.min(20,intrusion*.45)):0;
    }
    function one(profile,distance,visibility,minimumClearance,minimumFresnelMargin){
        const freeSpaceDb=freeSpaceLossDb(distance,profile.frequencyMhz);
        const terrainLossDb=excessTerrainLossDb(visibility,minimumClearance,minimumFresnelMargin);
        const estimatedRxPowerDbm=profile.eirpDbm-freeSpaceDb-terrainLossDb;
        const linkMarginDb=estimatedRxPowerDbm-profile.receiverThresholdDbm-profile.fadeMarginDb;
        const theoreticalMaxRangeM=theoreticalRangeMeters(profile);
        const terrainScenarioRangeM=theoreticalRangeMeters(profile,terrainLossDb);
        // Smooth illustrative score. Not measured RSSI, SNR, LQ or probability.
        const quality=clamp((linkMarginDb+6)/30);
        return Object.freeze({quality,source:'rfModel',detail:'approximateLinkBudget',estimated:true,
            confidence:'assumptionBased',distanceMeters:round(distance),
            freeSpaceLossDb:round(freeSpaceDb),estimatedTerrainLossDb:round(terrainLossDb),
            estimatedRxPowerDbm:round(estimatedRxPowerDbm),
            linkMarginDb:round(linkMarginDb),marginDb:round(linkMarginDb),
            estimatedMaxRangeM:round(theoreticalMaxRangeM),
            estimatedTerrainScenarioRangeM:round(terrainScenarioRangeM),
            rangeFraction:round(distance/theoreticalMaxRangeM,3)});
    }
    // Pure free-space diagnostics: intentionally has NO quality field. A
    // predicted budget without sampled terrain must never drive RC failsafe.
    function freeSpacePreview(distance,settings=defaults){
        if(!Number.isFinite(distance)||distance<1||distance>250000)return null;
        const cfg=configuration(settings);
        if(!cfg.enabled)return null;
        const make=profile=>{
            const loss=freeSpaceLossDb(distance,profile.frequencyMhz);
            return Object.freeze({distanceMeters:round(distance),freeSpaceLossDb:round(loss),
                estimatedMarginDb:round(profile.eirpDbm-loss-profile.receiverThresholdDbm-profile.fadeMarginDb),
                estimatedMaxRangeM:round(theoreticalRangeMeters(profile)),
                confidence:'freeSpaceOnly'});
        };
        return Object.freeze({video:make(cfg.video),control:make(cfg.control)});
    }
    function assess(geometry,from,to,settings=defaults){
        const cfg=configuration(settings),dist=distanceMeters(from,to);
        // Unavailable geometry is NOT assumed clear. The separately exposed
        // theoreticalRangeMeters() remains available without a terrain sample.
        if(!cfg.enabled||geometry?.source!=='sampledTerrain'||geometry?.confidence!=='approximate'||
            !['clear','fresnelIntrusion','obstructed'].includes(geometry.visibility)||
            !Number.isFinite(dist)||dist<1||dist>250000)return {controlLink:'unknown',videoLink:'unknown'};
        return {controlLink:one(cfg.control,dist,geometry.visibility,geometry.minimumClearanceMeters,geometry.minimumFresnelMarginMeters),
            videoLink:one(cfg.video,dist,geometry.visibility,geometry.minimumClearanceMeters,geometry.minimumFresnelMarginMeters)};
    }
    return {defaults,presets,configuration,distanceMeters,freeSpaceLossDb,theoreticalRangeMeters,excessTerrainLossDb,freeSpacePreview,assess};
});
