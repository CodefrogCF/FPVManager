(function(root,factory){const api=factory(typeof module==='object'&&module.exports?require('./rf_estimation.js'):root.FPVRfEstimation,typeof module==='object'&&module.exports?require('./live_terrain_tile_cache.js'):root.FPVLiveTerrainTileCache);if(typeof module==='object'&&module.exports)module.exports=api;else root.FPVLiveRadio=api;})(typeof globalThis!=='undefined'?globalThis:this,function(rfEstimation,terrainTiles){
    // Raw Window timers throw "Illegal invocation" when called as facade methods.
    function create({C,viewer,terrain,ready,emit,layer,doc,language,onAssessmentChange=()=>{},clock=()=>performance.now(),wallClock=()=>Date.now(),
        sampleTimeoutMs=12000,timers={setTimeout:(fn,ms)=>setTimeout(fn,ms),clearTimeout:id=>clearTimeout(id)}}){
        const cache=new Map(),tileCache=terrainTiles.create({C,clock,tileTimeoutMs:sampleTimeoutMs,timers}),latencies=[];
        let sequence=0,completed=0,failures=0,lastError=null,lastSample=null,lastSampleId=0,sampledProvider=null;
        let lastValidAt=-Infinity,observationId=null,observationQuality='unknown',observationError=null,observationReason=null;
        let diagnosticsEnabled=false,remoteDiagnostics={},lastDistance=null,latestAnalysisGeneration=-1;
        let epoch=0,busy=null,enabled=false,showPath=true,showMarker=true,useSpawn=true,last=-Infinity,lastMode=null,flightId=-1,active=false,paused=false,revision=0,disposed=false,expiry=null,resultAt=-Infinity;
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
        function assessment(){
            const ageMs=lastValidAt===-Infinity?null:Math.max(0,clock()-lastValidAt);
            const observation=Object.freeze({id:observationId,enabled,
                quality:observationQuality==='valid'&&ageMs>=5000?'stale':observationQuality,
                ageMs,freshnessMs:5000,errorCategory:observationError,reason:observationReason});
            return Object.freeze(trainingRc===null?{...currentAssessment,observation}:{...currentAssessment,
                observation:Object.freeze({id:'manualTraining',enabled:true,quality:'valid',ageMs:0,freshnessMs:5000,errorCategory:null,reason:null,manual:true}),
                controlLink:Object.freeze({quality:trainingRc,source:'estimatedModel',detail:'manualTraining'})});
        }
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
        function unknown(quality='unknown',errorCategory=null,reset=false){clearTimeout(expiry);expiry=null;resultAt=-Infinity;
            observationQuality=quality;observationError=errorCategory;observationReason=null;if(reset){lastValidAt=-Infinity;observationId=null;}currentAssessment=unknownAssessment;layer.clear();badge.dataset.state='unknown';detailMessage='Unknown / awaiting a terrain profile';updateLabels();onAssessmentChange();}
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
            unknown('unknown',null,true);drawStation(null);return {};
        }
        function observe(s){
            if(!enabled||disposed)return;
            if(enabled&&clock()-resultAt>=5000&&resultAt!==-Infinity)unknown('stale','STALE');
            const mode=`${!!s.active}/${!!s.paused}/${s.flightId}`;
            const speed=Number.isFinite(s.speed)?Math.max(0,s.speed):0;
            const interval=speed>=30?200:speed>=12?400:750;
            if(mode===lastMode&&clock()-last<interval)return;
            if(lastMode!==null&&mode!==lastMode){unknown('unknown',null,true);if(useSpawn&&s.flightId!==flightId)drawStation(null);}
            last=clock();lastMode=mode;flightId=s.flightId;active=!!s.active;paused=!!s.paused;
            emit('flight-radio-position',{active:!!s.active,paused:!!s.paused,flightId:s.flightId,
                latitude:s.position?.latitude,longitude:s.position?.longitude,height:s.height,speed,homeLatitude:s.home?.latitude,homeLongitude:s.home?.longitude});
        }
        function error(category,message){const value=Error(`${category}: ${message}`);value.category=category;return value;}
        function failureCategory(value){
            if(value?.category)return value.category;
            if(value?.name==='TerrainTimeoutError'||value?.name==='TimeoutError'||/timed out/i.test(value?.message??''))return 'TIMEOUT';
            if(value?.name==='AbortError'||/cancelled|changed/i.test(value?.message??''))return 'SUPERSEDED';
            if(/unavailable|Incomplete/i.test(value?.message??''))return 'TERRAIN_UNAVAILABLE';
            return 'SAMPLING_ERROR';
        }
        function diagnostics(){
            const sorted=[...latencies].sort((a,b)=>a-b),percentile=p=>sorted.length?sorted[Math.ceil(sorted.length*p)-1]:null;
            const observation=assessment().observation;
            const p50=remoteDiagnostics.p50Ms??remoteDiagnostics.latencyP50Ms??percentile(.5);
            const p95=remoteDiagnostics.p95Ms??remoteDiagnostics.latencyP95Ms??percentile(.95);
            return {...lastSample,...tileCache.diagnostics(),...remoteDiagnostics,enabled:diagnosticsEnabled,
                observationQuality:observation.quality,quality:observation.quality,los:badge.dataset.state??'unknown',
                ageMs:observation.ageMs,lastValidAgeMs:observation.ageMs,distanceMeters:lastDistance??remoteDiagnostics.distanceMeters??null,
                generation:remoteDiagnostics.generation??lastSample?.generation??epoch,
                active:remoteDiagnostics.active??(busy?1:0),queued:remoteDiagnostics.queued??0,
                activeRequests:busy?1:0,queuedRequests:0,completedRequests:completed,
                consecutiveFailures:failures,failures:remoteDiagnostics.failures??failures,
                error:remoteDiagnostics.error??lastError,errorCategory:lastError,lastErrorCategory:lastError,
                p50Ms:p50,p95Ms:p95,latencyP50Ms:p50,latencyP95Ms:p95,
                latencyWindowSamples:latencies.length,cacheEntries:cache.size};
        }
        function setDiagnostics(c){
            if(typeof c.enabled!=='boolean')throw Error('Invalid live radio diagnostics setting');
            diagnosticsEnabled=c.enabled;recordRemoteDiagnostics(c.diagnostics);return {};
        }
        function recordRemoteDiagnostics(value){
            if(!value||typeof value!=='object'||Array.isArray(value))return;
            remoteDiagnostics=Object.fromEntries(Object.entries(value).slice(0,64).filter(([key,v])=>
                key.length<=80&&(v===null||typeof v==='boolean'||typeof v==='string'&&v.length<=200||typeof v==='number'&&Number.isFinite(v))));
        }
        function resetSampling(){
            ++epoch;const previous=busy;busy=null;
            previous?.controller.abort(error('SUPERSEDED','Live terrain changed'));
            cache.clear();tileCache.reset();sampledProvider=null;
        }
        async function sample(c,signal){
            if(disposed||!ready())throw error('TERRAIN_UNAVAILABLE','Live terrain unavailable');
            // Match the existing shared radio geometry's 4096-point bound.
            // A fast-flight profile may fuse coarse and gap-refinement points
            // into one bridge command; cached-tile I/O still has four workers.
            if(!Array.isArray(c.positions)||!c.positions.length||c.positions.length>4096)
                throw error('INVALID_RESULT','Invalid live terrain sample batch');
            signal?.throwIfAborted();
            if(c.generation!==undefined){
                if(!Number.isSafeInteger(c.generation)||c.generation<0)throw error('INVALID_RESULT','Invalid live analysis generation');
                if(c.generation<latestAnalysisGeneration)throw error('SUPERSEDED','Obsolete live analysis generation');
                latestAnalysisGeneration=c.generation;
            }
            if(sampledProvider&&terrain.provider&&sampledProvider!==terrain.provider)resetSampling();
            if(terrain.provider)sampledProvider=terrain.provider;
            if(busy&&c.generation!==undefined&&busy.analysisGeneration!==c.generation){
                const previous=busy;busy=null;
                previous.controller.abort(error('SUPERSEDED','Live analysis generation changed'));
            }
            const token=epoch,started=clock(),id=++sequence,keys=c.positions.map(p=>{
                if(!Number.isFinite(p.latitude)||Math.abs(p.latitude)>90||!Number.isFinite(p.longitude)||Math.abs(p.longitude)>180)
                    throw error('INVALID_RESULT','Invalid live terrain position');
                return `${p.latitude},${p.longitude}`;
            });
            const unique=new Map();for(let i=0;i<keys.length;i++)if(!unique.has(keys[i]))unique.set(keys[i],i);
            const values=new Map(),missing=[];
            for(const [key,i] of unique){const entry=cache.get(key);
                const availability=sampledProvider?.availability;
                const sameDetail=!entry||entry.level===null||typeof availability?.computeMaximumLevelAtPosition!=='function'||
                    availability.computeMaximumLevelAtPosition(entry.position)===entry.level;
                if(entry&&sameDetail&&started-entry.at<30000){values.set(key,entry.height);cache.delete(key);cache.set(key,entry);}
                else{if(entry)cache.delete(key);missing.push(i);}
            }
            const stats={requestId:c.analysisRequestId??c.requestId??id,generation:c.generation??token,
                startMs:started,completionMs:null,durationMs:null,samples:keys.length,sampleCount:keys.length,
                validSamples:values.size,missingSamples:missing.length,sampledSamples:missing.length,
                cacheHits:unique.size-missing.length,provider:terrain.provider?.constructor?.name??'unknown'};
            let work=null;
            try{
                if(missing.length){
                    if(busy)throw error('PENDING','Live terrain query already running');
                    work={epoch:token,analysisGeneration:c.generation,controller:new AbortController(),timer:null};busy=work;
                    const onAbort=()=>work.controller.abort(error('SUPERSEDED','Live terrain request cancelled'));
                    signal?.addEventListener('abort',onAbort,{once:true});if(signal?.aborted)onAbort();
                    const positions=missing.map(i=>C.Cartographic.fromDegrees(c.positions[i].longitude,c.positions[i].latitude));
                    let stop;
                    const bounded=new Promise((_,reject)=>{
                        stop=()=>reject(work.controller.signal.reason??error('SUPERSEDED','Live terrain cancelled'));
                        work.controller.signal.addEventListener('abort',stop,{once:true});
                        work.timer=timers.setTimeout(()=>work.controller.abort(error('TIMEOUT','Live terrain sampling timed out')),sampleTimeoutMs);
                        if(work.controller.signal.aborted)stop();
                    });
                    let result,providerUsed=null;
                    try{
                        work.controller.signal.throwIfAborted();
                        const operation=terrain.sample(provider=>{
                            providerUsed=provider;
                            stats.provider=provider?.constructor?.name??'unknown';
                            return tileCache.sample(provider,positions,work.controller.signal);
                        },work.controller.signal);
                        result=await Promise.race([bounded,operation]);
                    }finally{
                        timers.clearTimeout(work.timer);signal?.removeEventListener('abort',onAbort);
                        work.controller.signal.removeEventListener('abort',stop);if(busy===work)busy=null;
                    }
                    work.controller.signal.throwIfAborted();signal?.throwIfAborted();
                    if(epoch!==token||disposed||!ready())throw error('SUPERSEDED','Live terrain changed');
                    stats.validSamples=values.size+(Array.isArray(result)?result.filter(p=>Number.isFinite(p?.height)&&Math.abs(p.height)<=100000).length:0);
                    stats.missingSamples=unique.size-stats.validSamples;
                    if(!Array.isArray(result)||result.length!==missing.length||stats.missingSamples)
                        throw error('TERRAIN_UNAVAILABLE','Incomplete live terrain');
                    sampledProvider=providerUsed??sampledProvider;
                    for(let j=0;j<missing.length;j++){
                        const key=keys[missing[j]],height=result[j].height;values.set(key,height);
                        const availability=providerUsed?.availability;
                        const level=typeof availability?.computeMaximumLevelAtPosition==='function'
                            ?availability.computeMaximumLevelAtPosition(positions[j]):null;
                        cache.delete(key);cache.set(key,{height,at:clock(),position:positions[j],level});
                        while(cache.size>4096)cache.delete(cache.keys().next().value);
                    }
                }
                signal?.throwIfAborted();
                if(epoch!==token||disposed||!ready())throw error('SUPERSEDED','Live terrain changed');
                stats.validSamples=keys.length;stats.missingSamples=0;completed++;failures=0;lastError=null;
                return {heights:keys.map(key=>values.get(key)),samplingMethod:'most-detailed-available',heightReference:'wgs84Ellipsoid',
                    diagnostics:{...tileCache.diagnostics(),...stats,completionMs:clock(),durationMs:clock()-started,active:0,queued:0,errorCategory:null}};
            }catch(value){
                const kind=failureCategory(value);stats.errorCategory=kind;
                if(epoch===token&&id>=lastSampleId){failures++;lastError=kind;}
                throw value?.category?value:error(kind,value?.message??String(value));
            }finally{
                if(epoch===token&&id>=lastSampleId){
                    lastSampleId=id;stats.completionMs=clock();stats.durationMs=stats.completionMs-started;lastSample=stats;
                    latencies.push(stats.durationMs);if(latencies.length>128)latencies.shift();
                }
            }
        }
        function set(c){
            if(disposed||!Number.isInteger(c.revision)||c.revision<revision||!enabled)return {};
            if(!Object.hasOwn(names,c.state))throw Error('Invalid live radio result');
            recordRemoteDiagnostics(c.diagnostics);
            if(Number.isFinite(c.distanceMeters))lastDistance=c.distanceMeters;
            if(c.state!=='unknown'&&(!active||paused||c.flightId!==flightId)){unknown('unknown','SUPERSEDED',true);return {};}
            if(!Array.isArray(c.rays)||c.rays.length>1||!c.rays.length&&c.state!=='unknown'||c.rays.some(r=>r.state!==c.state))throw Error('Inconsistent live radio result');
            if(c.state!=='unknown'&&(!Number.isFinite(c.expiresAtMs)||c.expiresAtMs<=wallClock()||c.expiresAtMs>wallClock()+10000)){revision=c.revision;unknown('stale','STALE');return {};}
            const insufficientClear=c.state==='noSampledObstruction'&&c.assessment?.confidence==='limited';
            const quality=c.observation?.quality??c.quality??(c.state==='unknown'||insufficientClear?'unknown':'valid');
            if(!['valid','pending','stale','unknown','error'].includes(quality))throw Error('Invalid live observation quality');
            const suppliedAge=c.observation?.ageMs??0;
            if(suppliedAge!==null&&(!Number.isFinite(suppliedAge)||suppliedAge<0))throw Error('Invalid live observation age');
            // The expiry crosses the bridge with the result. Account for its
            // transit delay as well as Dart's capture-to-send calculation age.
            const inputAge=c.state==='unknown'?suppliedAge:Math.max(suppliedAge??0,5000-(c.expiresAtMs-wallClock()));
            if(c.state!=='unknown'&&inputAge>=5000){revision=c.revision;unknown('stale','STALE');return {};}
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
            observationQuality=quality;observationError=c.observation?.errorCategory??c.errorCategory??null;
            observationReason=typeof c.observation?.reason==='string'?c.observation.reason.slice(0,160):null;
            if(c.state!=='unknown'&&quality==='valid'){lastValidAt=clock()-(inputAge??0);observationId=c.observation?.id??c.revision;}
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
            clearTimeout(expiry);resultAt=c.state==='unknown'?-Infinity:clock()-(inputAge??0);
            if(c.state!=='unknown'){const token=revision;expiry=setTimeout(()=>{if(!disposed&&revision===token)unknown('stale','STALE');},Math.min(5000-(inputAge??0),c.expiresAtMs-wallClock()));}
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
        return {monitor,observe,sample,set,station,assessment,setTrainingRc,diagnostics,setDiagnostics,get diagnosticsEnabled(){return diagnosticsEnabled;},terrainChanged(){if(disposed)return;resetSampling();++revision;unknown('unknown','SUPERSEDED',true);drawStation(null);},dispose(){disposed=true;resetSampling();enabled=false;clearTimeout(expiry);removeLanguage?.();layer.dispose();}};
    }
    return {create};
});
