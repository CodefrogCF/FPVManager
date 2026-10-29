(function(root,factory){
    const api=factory();
    if(typeof module==='object'&&module.exports)module.exports=api;
    else root.FPVSceneEnvironment=api;
})(typeof globalThis!=='undefined'?globalThis:this,function(){
    'use strict';
    const sources=Object.freeze({
        buildings:'https://3d.geo.admin.ch/ch.swisstopo.swissbuildings3d.3d/v1/tileset.json',
        vegetation:'https://3d.geo.admin.ch/ch.swisstopo.vegetation.3d/v1/tileset.json'
    });
    const budgets=Object.freeze({quality:[12,24,48,24,8],balanced:[24,40,32,16,4],performance:[40,64,24,12,2]});
    function time(value){
        if(value==null)return null;
        if(typeof value!=='string'||!/^\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d(?:\.\d{1,6})?Z$/.test(value))throw Error('Expected UTC scene time');
        const date=new Date(value);
        if(!Number.isFinite(date.getTime())||date.getUTCFullYear()<1900||date.getUTCFullYear()>2100||
            date.toISOString().slice(0,19)!==value.slice(0,19))throw Error('Scene date must be within 1900–2100');
        return date.toISOString();
    }
    function create(C,viewer,send=()=>{},{urls=sources,timeoutMs=15000,setTimer=setTimeout,clearTimer=clearTimeout}={}){
        const scene=viewer.scene,clock=viewer.clock,overrides=new Map();
        const original={time:C.JulianDate.clone(clock.currentTime),step:clock.clockStep,animate:clock.shouldAnimate,
            light:scene.light,lighting:scene.globe.enableLighting,atmosphere:scene.globe.dynamicAtmosphereLightingFromSun,
            lightingIn:scene.globe.lightingFadeInDistance,lightingOut:scene.globe.lightingFadeOutDistance,
            nightIn:scene.globe.nightFadeInDistance,nightOut:scene.globe.nightFadeOutDistance,
            ambient:scene.globe.vertexShadowDarkness};
        const credit=new C.Credit('3D buildings / vegetation · © swisstopo',true);
        const creditDisplay=viewer.cesiumWidget?.creditDisplay;
        const layers=Object.fromEntries(Object.keys(sources).map(key=>[key,{requested:false,tileset:null,pending:null,revision:0,
            phase:'hidden',failed:false,removers:[],lastStatus:null,timer:null}]));
        let disposed=false,lighting=false,profile='balanced',credited=false,appliedTime=null;
        function publish(key){
            if(disposed)return;
            const l=layers[key],state=!l.requested?'hidden':l.phase;
            if(l.lastStatus===state)return;l.lastStatus=state;
            send('scene-layer-status',{layer:key,state});
        }
        function credits(){
            const needed=Object.values(layers).some(l=>l.requested);
            if(needed===credited)return;credited=needed;
            if(needed)creditDisplay?.addStaticCredit(credit);else creditDisplay?.removeStaticCredit(credit);
        }
        function options(key){
            const b=budgets[profile],trees=key==='vegetation',mb=1024*1024;
            return {show:false,maximumScreenSpaceError:b[trees?1:0],cacheBytes:b[trees?3:2]*mb,
                maximumCacheOverflowBytes:b[4]*mb,shadows:C.ShadowMode.DISABLED,
                preloadWhenHidden:false,preloadFlightDestinations:false,loadSiblings:false,
                cullRequestsWhileMoving:true,foveatedScreenSpaceError:true,showCreditsOnScreen:true};
        }
        function visibility(key){
            const l=layers[key];if(!l.tileset)return;
            const height=viewer.camera.positionCartographic.height;
            l.tileset.show=l.requested&&height<(key==='vegetation'?12000:25000);
        }
        function release(l){
            clearTimer(l.timer);l.timer=null;
            l.revision++;for(const remove of l.removers)remove();l.removers=[];
            if(l.tileset){scene.primitives.remove(l.tileset);l.tileset=null;}
        }
        function load(key){
            const l=layers[key];if(disposed||l.pending||l.tileset||!l.requested)return;
            const revision=++l.revision;l.phase='loading';l.failed=false;publish(key);
            const current=()=>!disposed&&revision===l.revision;
            let timedOut=false;
            const timer=l.timer=setTimer(()=>{
                if(!current())return;timedOut=true;l.revision++;l.pending=null;l.phase='failed';publish(key);
            },timeoutMs);
            l.pending=Promise.resolve().then(()=>C.Cesium3DTileset.fromUrl(urls[key],options(key))).then(tileset=>{
                if(!current()||timedOut){if(!tileset.isDestroyed())tileset.destroy();return;}
                Object.assign(tileset,options(key));l.tileset=tileset;scene.primitives.add(tileset);visibility(key);
                l.phase='ready';publish(key);
                l.removers.push(tileset.tileFailed.addEventListener(()=>{if(!current())return;l.failed=true;l.phase='partial';publish(key);}));
                l.removers.push(tileset.loadProgress.addEventListener((pending,processing)=>{
                    if(!current()||l.failed)return;l.phase=pending+processing>0?'loading':'ready';publish(key);
                }));
                scene.requestRender();
            }).catch(()=>{if(current()){l.phase='failed';publish(key);}}).finally(()=>{
                clearTimer(timer);if(current())l.pending=null;
            });
        }
        function applyTime(){
            const selected=overrides.get('flight')??overrides.get('route');
            const enabled=!!selected||lighting,utc=selected?.timeUtc??null;
            const identity=enabled?(utc??'now'):'daylight';if(identity===appliedTime)return;appliedTime=identity;
            scene.globe.enableLighting=enabled;
            // Cesium's planet-scale defaults otherwise illuminate close terrain
            // fully, even on the night side. Keep physical lighting near ground.
            scene.globe.lightingFadeOutDistance=enabled?0:original.lightingOut;
            scene.globe.lightingFadeInDistance=enabled?1:original.lightingIn;
            scene.globe.nightFadeOutDistance=enabled?0:original.nightOut;
            scene.globe.nightFadeInDistance=enabled?1:original.nightIn;
            scene.globe.vertexShadowDarkness=enabled ? .06 : original.ambient;
            scene.globe.dynamicAtmosphereLightingFromSun=enabled||original.atmosphere;
            scene.light=enabled?new C.SunLight():original.light;
            if(enabled){
                if(utc){clock.shouldAnimate=false;clock.currentTime=C.JulianDate.fromIso8601(utc);}
                else clock.clockStep=C.ClockStep.SYSTEM_CLOCK;
            }else{
                clock.currentTime=C.JulianDate.clone(original.time);clock.clockStep=original.step;clock.shouldAnimate=original.animate;
                scene.globe.enableLighting=original.lighting;
            }
            scene.skyAtmosphere?.setDynamicLighting?.(enabled,enabled);
            scene.requestRender();
        }
        const removeUpdate=scene.preUpdate.addEventListener(()=>{for(const key of Object.keys(layers))visibility(key);});
        return {
            set(command){
                if(disposed)return {};
                for(const key of ['buildings','vegetation','lighting'])if(typeof command[key]!=='boolean')throw Error('Invalid scene preference');
                lighting=command.lighting;applyTime();
                for(const key of Object.keys(layers)){
                    const l=layers[key];l.requested=command[key];
                    if(command.retry===key){release(l);l.pending=null;}
                    if(l.requested&&!l.tileset&&!l.pending&&(l.phase!=='failed'||command.retry===key))load(key);
                    visibility(key);publish(key);
                }
                credits();scene.requestRender();return {};
            },
            setTime({scope,enabled,timeUtc=null}){
                if(disposed)return {};
                if(!['route','flight'].includes(scope)||typeof enabled!=='boolean')throw Error('Invalid scene time scope');
                const parsed=time(timeUtc);
                if(enabled)overrides.set(scope,{timeUtc:parsed});else overrides.delete(scope);
                applyTime();return {};
            },
            performance(value='balanced'){
                if(!Object.hasOwn(budgets,value))throw Error('Unknown scene graphics profile');profile=value;
                for(const key of Object.keys(layers))if(layers[key].tileset)Object.assign(layers[key].tileset,options(key));
                for(const key of Object.keys(layers))visibility(key);
            },
            dispose(){
                if(disposed)return;disposed=true;removeUpdate();
                for(const l of Object.values(layers))release(l);
                if(credited)creditDisplay?.removeStaticCredit(credit);
            }
        };
    }
    function bindTimeControls(doc,changed){
        const mode=doc.getElementById('flight-time-mode'),value=doc.getElementById('flight-time-value');
        const fixed=doc.getElementById('flight-time-fixed'),error=doc.getElementById('flight-time-error');
        const localValue=date=>`${date.getFullYear()}-${String(date.getMonth()+1).padStart(2,'0')}-${String(date.getDate()).padStart(2,'0')}T${String(date.getHours()).padStart(2,'0')}:${String(date.getMinutes()).padStart(2,'0')}`;
        function update(next){
            mode.value=next.enabled?(next.timeUtc?'fixed':'now'):'map';fixed.hidden=mode.value!=='fixed';
            if(next.timeUtc)value.value=localValue(new Date(next.timeUtc));error.textContent='';
        }
        function change(){
            try{
                fixed.hidden=mode.value!=='fixed';
                if(mode.value==='fixed'&&!value.value)value.value=localValue(new Date());
                const date=mode.value==='fixed'?new Date(value.value):null;
                if(date&&localValue(date)!==value.value)throw Error('Ungültige oder nicht existierende lokale Uhrzeit.');
                const next={enabled:mode.value!=='map',timeUtc:date?time(date.toISOString()):null};
                changed(next);update(next);
            }catch(e){error.textContent=e.message;}
        }
        mode.addEventListener('change',change);value.addEventListener('change',change);
        update({enabled:false});return {update};
    }
    return {sources,budgets,time,create,bindTimeControls};
});
