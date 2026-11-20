// Deterministic, simulation-only RC failsafe and Betaflight-inspired GPS Rescue.
// Geometric LOS and video-only effects never trigger a control loss.
(function(root,factory){const api=factory();if(typeof module==='object'&&module.exports)module.exports=api;else root.FPVSimulatedFailsafe=api;})(typeof globalThis!=='undefined'?globalThis:this,function(){
    'use strict';
    const defaults=Object.freeze({enabled:false,mode:'hold',lossThreshold:.20,recoveryThreshold:.45,
        activationDelaySeconds:.6,recoveryDelaySeconds:.6,rescueAltitudeMeters:100,
        returnSpeedMetersPerSecond:8,climbSpeedMetersPerSecond:5,autoRecover:false});
    const clamp=(v,a,b)=>Math.max(a,Math.min(b,v));
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
        if(!link||typeof link!=='object'||!Number.isFinite(link.quality)||link.quality<0||link.quality>1||
            !['rfModel','estimatedModel'].includes(link.source))return null;
        return link.quality;
    }
    function create(settings=defaults){
        let cfg=configuration(settings),phase='normal',lossTime=0,recoveryTime=0,phaseTime=0;
        let reason=null,quality=null,targetAltitude=null;
        // A confirmed RC restoration stays usable through marginal link quality
        // and short missing terrain results. Do not require the pilot to catch
        // a single frame immediately after the reconnection timer completes.
        // A sustained new loss or stale/unknown RC evidence revokes takeover.
        let recoveryArmed=false,reLossTime=0,unknownRecoveryTime=0;
        const maximumUnknownRecoverySeconds=5;
        function reset(){phase='normal';lossTime=0;recoveryTime=0;phaseTime=0;reason=null;quality=null;targetAltitude=null;
            recoveryArmed=false;reLossTime=0;unknownRecoveryTime=0;}
        function setConfiguration(value){cfg=configuration(value);reset();}
        function setPhase(next){if(next!==phase){phase=next;phaseTime=0;}}
        function status(){return {enabled:cfg.enabled,mode:cfg.mode,phase,reason,rcQuality:quality,
            active:!['normal','pending'].includes(phase),recoveryReady:recoveryArmed&&!['normal','pending','landed'].includes(phase),
            recovering:recoveryTime>0&&!recoveryArmed&&!['normal','pending','landed'].includes(phase),
            targetAltitudeMeters:targetAltitude};}
        function takeControl(context){
            if(cfg.mode!=='gpsRescue'){setPhase(cfg.mode);return;}
            if(!context?.position||!context?.home||![context.height,context.homeHeight].every(Number.isFinite)){
                setPhase('unavailable');reason='navigation';return;
            }
            if(context.batteryInsufficient===true){setPhase('unavailable');reason='battery';return;}
            // Betaflight-inspired CURRENT altitude + configured initial climb,
            // never a descent to a lower height above the home point.
            targetAltitude=Math.max(context.height,context.homeHeight)+cfg.rescueAltitudeMeters;
            setPhase('rescueHold');reason=null;
        }
        function step(dt,assessment,context={}){
            if(!cfg.enabled||context.playback){reset();return status();}
            const seconds=Number.isFinite(dt)?clamp(dt,0,.1):0;
            quality=rcQuality(assessment);
            if(phase==='normal'||phase==='pending'){
                if(quality===null||quality>cfg.lossThreshold){setPhase('normal');lossTime=0;}
                else {lossTime+=seconds;setPhase('pending');
                    if(lossTime>=cfg.activationDelaySeconds)takeControl(context);}
                return status();
            }
            phaseTime+=seconds;
            // RF profiles are refreshed asynchronously. Short samples between
            // the two hysteresis thresholds, or a briefly unavailable terrain
            // profile, must not erase a *confirmed* RC reconnection. Conversely,
            // unknown RF is never evidence of a new reconnection and cannot
            // authorize takeover indefinitely.
            if(quality!==null&&quality>=cfg.recoveryThreshold){
                reLossTime=0;unknownRecoveryTime=0;
                if(!recoveryArmed){
                    recoveryTime=Math.min(cfg.recoveryDelaySeconds,recoveryTime+seconds);
                    if(recoveryTime>=cfg.recoveryDelaySeconds)recoveryArmed=true;
                }
                // GPS Rescue requires a deliberate pilot command even once
                // the model reports a stable RC connection.
                if(cfg.mode!=='gpsRescue'&&cfg.autoRecover&&recoveryArmed){
                    reset();return status();
                }
            }else if(quality!==null&&quality<=cfg.lossThreshold){
                unknownRecoveryTime=0;
                reLossTime+=seconds;
                if(!recoveryArmed)recoveryTime=0;
                if(reLossTime>=cfg.activationDelaySeconds){
                    recoveryArmed=false;recoveryTime=0;
                }
            }else if(quality===null){
                reLossTime=0;
                if(!recoveryArmed)recoveryTime=0;
                else if((unknownRecoveryTime+=seconds)>=maximumUnknownRecoverySeconds){
                    recoveryArmed=false;recoveryTime=0;
                }
            }else{
                // Between loss/recovery thresholds: connected-state hysteresis.
                reLossTime=0;unknownRecoveryTime=0;
                if(!recoveryArmed)recoveryTime=0;
            }
            if(phase==='landed')return status();
            if(['rescueHold','climb','turn','return','landing'].includes(phase)){
                if(!context.position||!context.home||![context.height,context.homeHeight].every(Number.isFinite)){
                    setPhase('unavailable');reason='navigation';
                }else if(context.batteryInsufficient===true){
                    setPhase('unavailable');reason='battery';
                }else if(phase==='rescueHold'&&phaseTime>=.5){
                    setPhase('climb');
                }else if(phase==='climb'&&context.height>=targetAltitude-1){
                    setPhase('turn');
                }else if(phase==='turn'&&Number.isFinite(context.headingErrorRadians)&&
                    Math.abs(context.headingErrorRadians)<=.05){
                    setPhase('return');
                }else if(phase==='return'&&Number.isFinite(context.distanceToHome)&&context.distanceToHome<=3){
                    setPhase('landing');
                }else if(phase==='landing'&&Number.isFinite(context.distanceToHome)&&context.distanceToHome<=4&&
                    context.height<=context.homeHeight+.7){
                    setPhase('landed');reason='simulatedLanding';
                }
            }
            return status();
        }
        function recover(){if(!status().recoveryReady)return false;reset();return true;}
        return {step,reset,recover,status,setConfiguration,get settings(){return {...cfg};}};
    }
    return {defaults,configuration,rcQuality,create};
});
