(function(root,factory){const api=factory();if(typeof module==='object'&&module.exports)module.exports=api;else root.FPVLiveRadio=api;})(typeof globalThis!=='undefined'?globalThis:this,function(){
    function create({C,viewer,terrain,ready,emit,layer,doc,language,clock=()=>performance.now(),wallClock=()=>Date.now()}){
        const cache=new Map();let epoch=0,busy=null,enabled=false,last=-Infinity,lastMode=null,flightId=-1,active=false,paused=false,revision=0,disposed=false,expiry=null,resultAt=-Infinity;
        const badge=doc.getElementById('hud-live-radio'),toggle=doc.getElementById('flight-radio-enabled'),details=doc.getElementById('flight-radio-status');
        const names={unknown:'LOS: ?',obstructed:'LOS: obstruction',fresnelIntrusion:'LOS: Fresnel',noSampledObstruction:'LOS: sampled'};
        const translate=source=>language?.translate(source)??source;
        let detailMessage='Aus';
        function updateLabels(){
            badge.textContent=translate(names[badge.dataset.state]??names.unknown);
            badge.title=translate('Periodic geometric preview, not measured radio quality. Open details for sampling time and coverage.');
            details.textContent=translate(detailMessage);
        }
        const removeLanguage=language?.onChange(updateLabels);
        function unknown(){clearTimeout(expiry);expiry=null;resultAt=-Infinity;layer.clear();badge.dataset.state='unknown';detailMessage='Unknown / awaiting a terrain profile';updateLabels();}
        function monitor(c){
            if(disposed)throw Error('Live radio disposed');
            if(typeof c.enabled!=='boolean'||!Number.isInteger(c.revision)||c.revision<0)throw Error('Invalid live radio monitor');
            if(c.revision<revision)return {};
            enabled=c.enabled;revision=c.revision;last=-Infinity;lastMode=null;toggle.checked=enabled;badge.hidden=!enabled;unknown();return {};
        }
        function observe(s){
            if(!enabled||disposed)return;
            if(enabled&&clock()-resultAt>=5000&&resultAt!==-Infinity)unknown();
            const mode=`${!!s.active}/${!!s.paused}/${s.flightId}`;
            if(mode===lastMode&&clock()-last<1000)return;
            if(lastMode!==null&&mode!==lastMode)unknown();
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
            layer.set(c);revision=c.revision;badge.dataset.state=c.state;
            clearTimeout(expiry);resultAt=c.state==='unknown'?-Infinity:clock();
            if(c.state!=='unknown'){const token=revision;expiry=setTimeout(()=>{if(!disposed&&revision===token)unknown();},Math.min(5000,c.expiresAtMs-wallClock()));}
            detailMessage=String(c.message??'Unknown').slice(0,160);updateLabels();return {};
        }
        const settings=()=>emit('flight-radio-settings-request');
        badge.addEventListener('click',settings);doc.getElementById('configure-flight-radio').addEventListener('click',settings);
        toggle.addEventListener('change',()=>emit('flight-radio-toggle',{enabled:toggle.checked}));
        return {monitor,observe,sample,set,terrainChanged(){if(disposed)return;++epoch;++revision;cache.clear();unknown();},dispose(){disposed=true;++epoch;enabled=false;clearTimeout(expiry);cache.clear();removeLanguage?.();layer.dispose();}};
    }
    return {create};
});
