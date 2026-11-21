(function(root,factory){const api=factory(typeof module==='object'&&module.exports?require('./rf_estimation.js'):root.FPVRfEstimation);if(typeof module==='object'&&module.exports)module.exports=api;else root.FPVLiveRadio=api;})(typeof globalThis!=='undefined'?globalThis:this,function(rfEstimation){
    function create({C,viewer,terrain,ready,emit,layer,doc,language,onAssessmentChange=()=>{},clock=()=>performance.now(),wallClock=()=>Date.now()}){
        const cache=new Map();let epoch=0,busy=null,enabled=false,showPath=true,showMarker=true,useSpawn=true,last=-Infinity,lastMode=null,flightId=-1,active=false,paused=false,revision=0,disposed=false,expiry=null,resultAt=-Infinity;
        const badge=doc.getElementById('hud-live-radio'),toggle=doc.getElementById('flight-radio-enabled'),details=doc.getElementById('flight-radio-status');
        const names={unknown:'LOS: ?',obstructed:'LOS: obstruction',fresnelIntrusion:'LOS: Fresnel',noSampledObstruction:'LOS: sampled'};
        const translate=source=>language?.translate(source)??source;
        let detailMessage='Aus',rfSettings=rfEstimation.configuration();
        let stationKey='';
        function drawStation(position){
            const key=position?`${position.latitude},${position.longitude}`:'';
            if(key===stationKey)return;
            layer.setStation?.(position);
            stationKey=key;
        }
        // Only explicitly identified link models can supply UI quality. Terrain
        // visibility remains geometric and cannot assert a video/RC loss.
        const validModeledLink=value=>value==='unknown'||(
            value&&typeof value==='object'&&Number.isFinite(value.quality)&&value.quality>=0&&value.quality<=1&&
            ['rfModel','estimatedModel'].includes(value.source));
        const unknownAssessment=Object.freeze({visibility:'unknown',source:'unavailable',confidence:'unavailable',controlLink:'unknown',videoLink:'unknown'});
        let currentAssessment=unknownAssessment,trainingRc=null;
        function assessment(){return trainingRc===null?currentAssessment:Object.freeze({...currentAssessment,
            controlLink:Object.freeze({quality:trainingRc,source:'estimatedModel',detail:'manualTraining'})});}
        function setTrainingRc(value){
            if(value!==null&&(!Number.isFinite(value)||value<0||value>1))throw Error('Invalid training RC quality');
            trainingRc=value;onAssessmentChange();
        }
        function updateLabels(){
            badge.textContent=translate(names[badge.dataset.state]??names.unknown);
            badge.title=translate('Periodic geometric preview, not measured radio quality. Open details for sampling time and coverage.');
            details.textContent=translate(detailMessage);
        }
        const removeLanguage=language?.onChange(updateLabels);
        function unknown(){clearTimeout(expiry);expiry=null;resultAt=-Infinity;currentAssessment=unknownAssessment;layer.clear();badge.dataset.state='unknown';detailMessage='Unknown / awaiting a terrain profile';updateLabels();onAssessmentChange();}
        function monitor(c){
            if(disposed)throw Error('Live radio disposed');
            if(typeof c.enabled!=='boolean'||!Number.isInteger(c.revision)||c.revision<0)throw Error('Invalid live radio monitor');
            if(c.revision<revision)return {};
            if(c.showSignalPath!==undefined&&typeof c.showSignalPath!=='boolean'||
                c.showGroundStationMarker!==undefined&&typeof c.showGroundStationMarker!=='boolean'||
                c.useSpawn!==undefined&&typeof c.useSpawn!=='boolean')throw Error('Invalid live radio visibility settings');
            enabled=c.enabled;showPath=c.showSignalPath!==false;showMarker=c.showGroundStationMarker!==false;useSpawn=c.useSpawn!==false;
            if(c.rfProfiles!==undefined)rfSettings=rfEstimation.configuration(c.rfProfiles);
            revision=c.revision;last=-Infinity;lastMode=null;toggle.checked=enabled;badge.hidden=!enabled;
            unknown();drawStation(null);return {};
        }
        function observe(s){
            if(!enabled||disposed)return;
            if(enabled&&clock()-resultAt>=5000&&resultAt!==-Infinity)unknown();
            const mode=`${!!s.active}/${!!s.paused}/${s.flightId}`;
            const speed=Number.isFinite(s.speed)?Math.max(0,s.speed):0;
            const interval=speed>=30?200:speed>=12?400:750;
            if(mode===lastMode&&clock()-last<interval)return;
            if(lastMode!==null&&mode!==lastMode){unknown();if(useSpawn&&s.flightId!==flightId)drawStation(null);}
            last=clock();lastMode=mode;flightId=s.flightId;active=!!s.active;paused=!!s.paused;
            emit('flight-radio-position',{active:!!s.active,paused:!!s.paused,flightId:s.flightId,
                latitude:s.position?.latitude,longitude:s.position?.longitude,height:s.height,speed,homeLatitude:s.home?.latitude,homeLongitude:s.home?.longitude});
        }
        async function sample(c,signal){
            if(disposed||!Array.isArray(c.positions)||!c.positions.length||c.positions.length>256||!ready())throw Error('Live terrain unavailable');
            const token=epoch,now=clock(),keys=c.positions.map(p=>{
                if(!Number.isFinite(p.latitude)||Math.abs(p.latitude)>90||!Number.isFinite(p.longitude)||Math.abs(p.longitude)>180)throw Error('Invalid live terrain position');
                return `${p.latitude},${p.longitude}`;
            });
            const missing=[];for(let i=0;i<keys.length;i++){const e=cache.get(keys[i]);if(!e||now-e.at>=30000)missing.push(i);}
            if(missing.length){
                if(busy)throw Error('Live terrain query already running');
                const positions=missing.map(i=>C.Cartographic.fromDegrees(c.positions[i].longitude,c.positions[i].latitude));
                // Never certify a clear mountain link from a fixed low LOD.
                // When the provider cannot supply its best available terrain,
                // surface coverage is unknown rather than assumed clear.
                const work=terrain.sample(provider=>{
                    if(typeof C.sampleTerrainMostDetailed!=='function'||!provider?.availability)
                        throw Error('Detailed live terrain unavailable');
                    return C.sampleTerrainMostDetailed(provider,positions,true);
                },signal);busy=work;
                let result;
                try{result=await work;}finally{if(busy===work)busy=null;}
                signal.throwIfAborted();if(epoch!==token||!ready())throw Error('Live terrain changed');
                if(result.length!==missing.length||result.some(p=>!Number.isFinite(p.height)||Math.abs(p.height)>100000))throw Error('Incomplete live terrain');
                for(let j=0;j<missing.length;j++){
                    const key=keys[missing[j]];cache.delete(key);cache.set(key,{height:result[j].height,at:clock()});
                    while(cache.size>4096)cache.delete(cache.keys().next().value);
                }
            }
            signal.throwIfAborted();if(epoch!==token||!ready())throw Error('Live terrain changed');
            return {heights:keys.map(k=>cache.get(k).height),samplingMethod:'most-detailed-available',heightReference:'wgs84Ellipsoid'};
        }
        function set(c){
            if(disposed||!Number.isInteger(c.revision)||c.revision<revision||!enabled)return {};
            if(!Object.hasOwn(names,c.state))throw Error('Invalid live radio result');
            if(c.state!=='unknown'&&(!active||paused||c.flightId!==flightId)){unknown();return {};}
            if(!Array.isArray(c.rays)||c.rays.length>1||!c.rays.length&&c.state!=='unknown'||c.rays.some(r=>r.state!==c.state))throw Error('Inconsistent live radio result');
            if(c.state!=='unknown'&&(!Number.isFinite(c.expiresAtMs)||c.expiresAtMs<=wallClock()||c.expiresAtMs>wallClock()+10000)){revision=c.revision;unknown();return {};}
            if(c.assessment!==undefined){
                const a=c.assessment;
                if(!a||!['unknown','clear','fresnelIntrusion','obstructed'].includes(a.visibility)||
                    !['unavailable','sampledTerrain'].includes(a.source)||
                    !['unavailable','limited','approximate'].includes(a.confidence)||
                    !validModeledLink(a.controlLink)||!validModeledLink(a.videoLink)||
                    (a.confidence==='limited'&&(a.controlLink!=='unknown'||a.videoLink!=='unknown'))||
                    (a.visibility!=='unknown'&&a.visibility!==({noSampledObstruction:'clear'}[c.state]??c.state)))
                    throw Error('Inconsistent live link assessment');
                currentAssessment=Object.freeze({...a,
                    controlLink:a.controlLink==='unknown'?'unknown':Object.freeze({...a.controlLink}),
                    videoLink:a.videoLink==='unknown'?'unknown':Object.freeze({...a.videoLink})});
            }else currentAssessment=unknownAssessment;
            // The radio approximation is explicitly separate from geometric LOS.
            // Preserve explicit link readings, including externally supplied profiles.
            const estimated=rfEstimation.assess(currentAssessment,c.pilot,c.rays?.[0],rfSettings);
            if(estimated.controlLink!=='unknown'||estimated.videoLink!=='unknown'){
                currentAssessment=Object.freeze({...currentAssessment,
                    controlLink:currentAssessment.controlLink==='unknown'?estimated.controlLink:currentAssessment.controlLink,
                    videoLink:currentAssessment.videoLink==='unknown'?estimated.videoLink:currentAssessment.videoLink});
            }
            // A successful, flight-matched profile can restore the station even
            // if its earlier standalone marker command arrived out of order.
            if(c.pilot&&Number.isFinite(c.pilot.latitude)&&Number.isFinite(c.pilot.longitude))
                drawStation(showMarker?{latitude:c.pilot.latitude,longitude:c.pilot.longitude}:null);
            if(showPath&&!(currentAssessment.confidence==='limited'&&
                c.state==='noSampledObstruction'))layer.set({...c,showPilot:false,showTargetMarkers:false});
            else layer.clear();
            revision=c.revision;
            badge.dataset.state=(currentAssessment.confidence==='limited'&&
                c.state==='noSampledObstruction')?'unknown':c.state;
            clearTimeout(expiry);resultAt=c.state==='unknown'?-Infinity:clock();
            if(c.state!=='unknown'){const token=revision;expiry=setTimeout(()=>{if(!disposed&&revision===token)unknown();},Math.min(5000,c.expiresAtMs-wallClock()));}
            detailMessage=String(c.message??'Unknown').slice(0,160);
            if(c.sampling&&typeof c.sampling==='object'&&Number.isFinite(c.sampling.maximumGapMeters)){
                const diag=c.sampling;
                detailMessage+=` · ${String(diag.tier??'adaptive').slice(0,30)} (${Number(diag.samples)||0} pts, max gap ${diag.maximumGapMeters.toFixed(0)} m${diag.limited?', LIMITED':''})`;
            }
            // Display only the mathematical free-space prediction when terrain
            // is missing or under-resolved. Never promote it to controlLink or
            // videoLink, which would incorrectly allow a simulated failsafe.
            const sampledBlocked=currentAssessment.confidence==='limited'&&
                currentAssessment.visibility==='obstructed'&&
                currentAssessment.controlLink?.detail==='sampledObstructionOnly';
            if(sampledBlocked){
                detailMessage+=' · SIM sampled obstruction: RF loss estimated despite LIMITED overall terrain coverage (not measured)';
            }
            if((c.state==='unknown'||currentAssessment.confidence==='limited')&&Number.isFinite(c.distanceMeters)){
                const preview=rfEstimation.freeSpacePreview(c.distanceMeters,rfSettings);
                if(preview)detailMessage+=` · SIM free-space ONLY Video ${preview.video.estimatedMarginDb.toFixed(1)} dB / RC ${preview.control.estimatedMarginDb.toFixed(1)} dB (no terrain loss included)`;
            }

            if(currentAssessment.videoLink!=='unknown'||currentAssessment.controlLink!=='unknown'){
                const brief=(name,link)=>!link||link==='unknown'||!Number.isFinite(link.linkMarginDb)||!Number.isFinite(link.estimatedMaxRangeM)
                    ?'':`${name}: ${link.linkMarginDb.toFixed(1)} dB reserve; free-space ≈${(link.estimatedMaxRangeM/1000).toFixed(1)} km`;
                const parts=[brief('Video',currentAssessment.videoLink),brief('RC',currentAssessment.controlLink)].filter(Boolean);
                if(parts.length)detailMessage+=` · SIM ${parts.join(' | ')}`;
            }
            updateLabels();onAssessmentChange();return {};
        }
        function station(c){
            if(disposed||!enabled||!Number.isInteger(c.revision)||c.revision<revision)return {};
            if(c.position!==null&&(!c.position||!Number.isFinite(c.position.latitude)||Math.abs(c.position.latitude)>90||
                !Number.isFinite(c.position.longitude)||Math.abs(c.position.longitude)>180))throw Error('Invalid ground station position');
            drawStation(showMarker?c.position:null);
            return {};
        }
        const settings=()=>emit('flight-radio-settings-request');
        badge.addEventListener('click',settings);doc.getElementById('configure-flight-radio').addEventListener('click',settings);
        toggle.addEventListener('change',()=>emit('flight-radio-toggle',{enabled:toggle.checked}));
        return {monitor,observe,sample,set,station,assessment,setTrainingRc,terrainChanged(){if(disposed)return;++epoch;++revision;cache.clear();unknown();drawStation(null);},dispose(){disposed=true;++epoch;enabled=false;clearTimeout(expiry);cache.clear();removeLanguage?.();layer.dispose();}};
    }
    return {create};
});
