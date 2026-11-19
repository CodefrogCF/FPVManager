// FPVManager Issue #129 – deterministic, simulation-only RC failsafe state machine.
// Geometric LOS and visualization-only video estimates MUST NOT drive this model.
(function(root,factory){const api=factory();if(typeof module==='object'&&module.exports)module.exports=api;else root.FPVSimulatedFailsafe=api;})(typeof globalThis!=='undefined'?globalThis:this,function(){
    'use strict';
    const defaults=Object.freeze({enabled:false,mode:'hold',lossThreshold:.08,recoveryThreshold:.35,
        activationDelaySeconds:1.5,recoveryDelaySeconds:2,rescueAltitudeMeters:50,
        returnSpeedMetersPerSecond:8,climbSpeedMetersPerSecond:3,autoRecover:true});
    function configuration(value={}){
        if(!value||typeof value!=='object'||Array.isArray(value))throw Error('Invalid simulated failsafe configuration');
        const s={...defaults,...value};
        if(typeof s.enabled!=='boolean'||typeof s.autoRecover!=='boolean'||!['hold','descend','gpsRescue'].includes(s.mode))
            throw Error('Invalid simulated failsafe mode');
        for(const [key,lo,hi] of [['lossThreshold',0,.5],['recoveryThreshold',.05,1],
            ['activationDelaySeconds',.1,30],['recoveryDelaySeconds',.1,30],
            ['rescueAltitudeMeters',5,500],['returnSpeedMetersPerSecond',.5,50],
            ['climbSpeedMetersPerSecond',.2,15]])
            if(!Number.isFinite(s[key])||s[key]<lo||s[key]>hi)throw Error(`Invalid simulated failsafe ${key}`);
        if(s.recoveryThreshold<=s.lossThreshold+.05)throw Error('Failsafe recovery threshold needs hysteresis');
        return s;
    }
    function rcQuality(assessment){
        const link=assessment?.controlLink;
        // Only an explicit radio model or the opt-in manual training signal
        // can cause a simulated RC loss. Unknown and terrainIllustration never can.
        if(!link||typeof link!=='object'||!Number.isFinite(link.quality)||link.quality<0||link.quality>1||
            !['rfModel','estimatedModel'].includes(link.source))return null;
        return link.quality;
    }
    function create(settings=defaults){
        let cfg=configuration(settings),phase='normal',lossTime=0,recoveryTime=0,reason=null,quality=null;
        function reset(){phase='normal';lossTime=0;recoveryTime=0;reason=null;quality=null;}
        function setConfiguration(value){cfg=configuration(value);reset();}
        function status(){return {enabled:cfg.enabled,mode:cfg.mode,phase,reason,rcQuality:quality,
            active:!['normal','pending'].includes(phase),recoveryReady:phase==='awaitingManual',
            recovering:recoveryTime>0&&!['normal','pending','awaitingManual'].includes(phase)};}
        function takeControl(context){
            if(cfg.mode!=='gpsRescue')return cfg.mode;
            if(!context?.position||!context?.home||![context.height,context.homeHeight].every(Number.isFinite)){
                phase='unavailable';reason='navigation';return 'hold';
            }
            if(context.batteryInsufficient===true){phase='unavailable';reason='battery';return 'hold';}
            phase='climb';reason=null;return 'gpsRescue';
        }
        function step(dt,assessment,context={}){
            if(!cfg.enabled||context.playback){reset();return status();}
            const seconds=Number.isFinite(dt)?Math.max(0,Math.min(dt,.1)):0;
            quality=rcQuality(assessment);
            if(phase==='normal'||phase==='pending'){
                // An unknown link cannot arm a failsafe, even behind terrain.
                if(quality===null||quality>cfg.lossThreshold){phase='normal';lossTime=0;}
                else {lossTime+=seconds;phase=lossTime>=cfg.activationDelaySeconds?'active':'pending';
                    if(phase==='active'){phase=cfg.mode;takeControl(context);}}
                return status();
            }
            if(quality!==null&&quality>=cfg.recoveryThreshold){
                recoveryTime+=seconds;
                if(recoveryTime>=cfg.recoveryDelaySeconds){
                    if(cfg.autoRecover){reset();quality=rcQuality(assessment);return status();}
                    phase='awaitingManual';reason='manualRecovery';
                }
            }else recoveryTime=0;
            if(phase==='awaitingManual')return status();
            if(phase==='climb'||phase==='return'||phase==='arrived'){
                if(!context.position||!context.home||![context.height,context.homeHeight].every(Number.isFinite)){
                    phase='unavailable';reason='navigation';
                }else if(context.batteryInsufficient===true){phase='unavailable';reason='battery';}
                else {
                    const altitude=context.homeHeight+cfg.rescueAltitudeMeters;
                    const delta=altitude-context.height;
                    if(phase==='climb'&&delta<=1)phase='return';
                    if(phase==='return'&&Number.isFinite(context.distanceToHome)&&context.distanceToHome<3)phase='arrived';
                }
            }
            return status();
        }
        function recover(){if(phase!=='awaitingManual')return false;reset();return true;}
        return {step,reset,recover,status,setConfiguration,get settings(){return {...cfg};}};
    }
    return {defaults,configuration,rcQuality,create};
});
