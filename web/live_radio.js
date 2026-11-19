(function(root,factory){const api=factory();if(typeof module==='object'&&module.exports)module.exports=api;else root.FPVLiveRadio=api;})(typeof globalThis!=='undefined'?globalThis:this,function(){
    function create({C,viewer,terrain,ready,emit,layer,doc,language,onAssessmentChange=()=>{},clock=()=>performance.now(),wallClock=()=>Date.now()}){
        const cache=new Map();let epoch=0,busy=null,enabled=false,showPath=true,showMarker=true,useSpawn=true,last=-Infinity,lastMode=null,flightId=-1,active=false,paused=false,revision=0,disposed=false,expiry=null,resultAt=-Infinity;
        const badge=doc.getElementById('hud-live-radio'),toggle=doc.getElementById('flight-radio-enabled'),details=doc.getElementById('flight-radio-status');
        const names={unknown:'LOS: ?',obstructed:'LOS: obstruction',fresnelIntrusion:'LOS: Fresnel',noSampledObstruction:'LOS: sampled'};
        const translate=source=>language?.translate(source)??source;
        let detailMessage='Aus';
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
            revision=c.revision;last=-Infinity;lastMode=null;toggle.checked=enabled;badge.hidden=!enabled;
            unknown();drawStation(null);return {};
        }
        function observe(s){
            if(!enabled||disposed)return;
            if(enabled&&clock()-resultAt>=5000&&resultAt!==-Infinity)unknown();
            const mode=`${!!s.active}/${!!s.paused}/${s.flightId}`;
            if(mode===lastMode&&clock()-last<1000)return;
            if(lastMode!==null&&mode!==lastMode){unknown();if(useSpawn&&s.flightId!==flightId)drawStation(null);}
            last=clock();lastMode=mode;flightId=s.flightId;active=!!s.active;paused=!!s.paused;
            emit('flight-radio-position',{active:!!s.active,paused:!!s.paused,flightId:s.flightId,
                latitude:s.position?.latitude,longitude:s.position?.longitude,height:s.height,homeLatitude:s.home?.latitude,homeLongitude:s.home?.longitude});
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
                const work=terrain.sample(provider=>C.sampleTerrain(provider,12,positions,true),signal);busy=work;
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
            return {heights:keys.map(k=>cache.get(k).height),samplingMethod:'level-12',heightReference:'wgs84Ellipsoid'};
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
                    !['unavailable','approximate'].includes(a.confidence)||
                    !validModeledLink(a.controlLink)||!validModeledLink(a.videoLink)||
                    (a.visibility!=='unknown'&&a.visibility!==({noSampledObstruction:'clear'}[c.state]??c.state)))
                    throw Error('Inconsistent live link assessment');
                currentAssessment=Object.freeze({...a,
                    controlLink:a.controlLink==='unknown'?'unknown':Object.freeze({...a.controlLink}),
                    videoLink:a.videoLink==='unknown'?'unknown':Object.freeze({...a.videoLink})});
            }else currentAssessment=unknownAssessment;
            // A successful, flight-matched profile can restore the station even
            // if its earlier standalone marker command arrived out of order.
            if(c.pilot&&Number.isFinite(c.pilot.latitude)&&Number.isFinite(c.pilot.longitude))
                drawStation(showMarker?{latitude:c.pilot.latitude,longitude:c.pilot.longitude}:null);
            if(showPath)layer.set({...c,showPilot:false});else layer.clear();
            revision=c.revision;badge.dataset.state=c.state;
            clearTimeout(expiry);resultAt=c.state==='unknown'?-Infinity:clock();
            if(c.state!=='unknown'){const token=revision;expiry=setTimeout(()=>{if(!disposed&&revision===token)unknown();},Math.min(5000,c.expiresAtMs-wallClock()));}
            detailMessage=String(c.message??'Unknown').slice(0,160);updateLabels();onAssessmentChange();return {};
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
