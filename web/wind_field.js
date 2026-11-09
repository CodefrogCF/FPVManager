(function(root,factory){
    const api=factory(typeof module==='object'&&module.exports?require('./map_providers.js'):root.FPVMapProviders);
    if(typeof module==='object'&&module.exports)module.exports=api;else root.FPVWindField=api;
})(typeof globalThis!=='undefined'?globalThis:this,function(Credits){
    'use strict';
    const creditApi=Credits??{retainStaticCredit:(d,c)=>d?.addStaticCredit(c),releaseStaticCredit:(d,c)=>d?.removeStaticCredit(c),
        weatherCredits:C=>[new C.Credit('<a href="https://open-meteo.com/">Open-Meteo</a> · CC BY 4.0 · interpolated wind',true)]};
    const rad=Math.PI/180,R=6378137,eccentricitySquared=6.6943799901413165e-3,zero=Object.freeze({north:0,east:0,up:0});
    const vector=l=>({north:-l.speedMs*Math.cos(l.fromDegrees*rad),east:-l.speedMs*Math.sin(l.fromDegrees*rad)});
    function field(raw){
        if(!raw||!['current','forecast'].includes(raw.mode)||typeof raw.source!=='string'||raw.source.length>200||
            ![raw.centerLatitude,raw.centerLongitude,raw.radiusMeters].every(Number.isFinite)||Math.abs(raw.centerLatitude)>85||Math.abs(raw.centerLongitude)>179.8||
            ![1500,5000].includes(raw.radiusMeters)||!Array.isArray(raw.nodes)||raw.nodes.length!==9)throw Error('Invalid wind field');
        for(const name of ['validAtUtc','retrievedUtc','expiresUtc'])if(typeof raw[name]!=='string'||!raw[name].endsWith('Z')||!Number.isFinite(Date.parse(raw[name])))throw Error('Invalid wind timestamp');
        if(Date.parse(raw.expiresUtc)<=Date.parse(raw.retrievedUtc))throw Error('Invalid wind expiry');
        const dy=raw.radiusMeters/111320,dx=raw.radiusMeters/(111320*Math.cos(raw.centerLatitude*rad));
        const nodes=raw.nodes.map((node,i)=>{
            if(!node||![node.latitude,node.longitude].every(Number.isFinite)||Math.abs(node.latitude)>85||Math.abs(node.longitude)>180||!Array.isArray(node.levels)||node.levels.length>4||
                Math.abs(node.latitude-(raw.centerLatitude+(Math.floor(i/3)-1)*dy))>1e-6||Math.abs(node.longitude-(raw.centerLongitude+(i%3-1)*dx))>1e-6)throw Error('Invalid wind grid node');
            let last=-1;
            return {latitude:node.latitude,longitude:node.longitude,levels:node.levels.map(l=>{
                if(!l||![l.agl,l.speedMs,l.fromDegrees].every(Number.isFinite)||![10,80,120,180].includes(l.agl)||l.agl<=last||l.speedMs<0||l.speedMs>100||l.fromDegrees<0||l.fromDegrees>=360)throw Error('Invalid wind level');
                last=l.agl;return {...vector(l),agl:l.agl};
            })};
        });
        if(nodes.every(n=>!n.levels.length))throw Error('Empty wind field');
        return {...raw,nodes,dy,dx,west:raw.centerLongitude-dx,east:raw.centerLongitude+dx,
            south:raw.centerLatitude-dy,north:raw.centerLatitude+dy,expires:Date.parse(raw.expiresUtc)};
    }
    function levelAt(levels,agl){
        if(!levels.length)return null;
        const first=levels[0],last=levels[levels.length-1];
        if(agl<=first.agl)return {...first,extrapolated:agl<first.agl};
        if(agl>=last.agl)return {...last,extrapolated:agl>last.agl};
        for(let i=1;i<levels.length;i++)if(agl<=levels[i].agl){
            const a=levels[i-1],b=levels[i],f=(agl-a.agl)/(b.agl-a.agl);
            return {north:a.north+(b.north-a.north)*f,east:a.east+(b.east-a.east)*f,extrapolated:false};
        }
    }
    function sample(data,latitude,longitude,agl){
        if(!data||![latitude,longitude,agl].every(Number.isFinite))return null;
        let x=(longitude-data.west)/data.dx,y=(latitude-data.south)/data.dy;
        if(x< -1e-8||x>2+1e-8||y< -1e-8||y>2+1e-8)return null;
        x=Math.max(0,Math.min(2,x));y=Math.max(0,Math.min(2,y));
        const col=Math.min(1,Math.floor(x)),row=Math.min(1,Math.floor(y)),fx=x-col,fy=y-row;
        let north=0,east=0,extrapolated=false;
        for(const [dx,dy,weight] of [[0,0,(1-fx)*(1-fy)],[1,0,fx*(1-fy)],[0,1,(1-fx)*fy],[1,1,fx*fy]]){
            if(weight<1e-10)continue;
            const value=levelAt(data.nodes[(row+dy)*3+col+dx].levels,agl);if(!value)return null;
            north+=value.north*weight;east+=value.east*weight;extrapolated||=value.extrapolated;
        }
        return {north,east,up:0,speedMs:Math.hypot(north,east),extrapolated};
    }
    const density={quality:7,balanced:5,performance:3};
    function create(C,viewer,send=()=>{},{now=()=>Date.now(),elapsed=()=>performance.now(),doc=typeof document==='undefined'?null:document,isTerrainReady=()=>true}={}){
        const collection=new C.PolylineCollection();viewer.scene.primitives.add(collection);collection.show=false;
        const palette=['#61dea5','#ffe080','#ffab66','#ff797b'];
        const terrain=new Map(),location=new C.Cartographic();
        const sourceCredits=creditApi.weatherCredits(C);
        const credits=viewer.cesiumWidget?.creditDisplay;let credited=false;
        let data=null,visible=false,affectFlight=false,disposed=false,dirty=true,terrainMissing=false,entries=[],navigation=null,anchor=null,profile='balanced',lastDraw=-Infinity,lastTerrain=0,status=null;
        let windowBounds=null,groundGrid=null,lastMotion=null;
        let uiData,uiVisible,uiForce,uiNav,uiFresh;
        function fresh(){return data&&now()<data.expires;}
        function publish(){
            const state=!data?'unavailable':!fresh()?'expired':visible&&(!isTerrainReady()||terrainMissing)?'terrainPending':'ready';
            if(state===status)return;status=state;send('wind-layer-status',{state});
        }
        function controls(){
            const valid=!!fresh(),nav=!!navigation;
            if(uiData===data&&uiVisible===visible&&uiForce===affectFlight&&uiNav===nav&&uiFresh===valid)return;
            uiData=data;uiVisible=visible;uiForce=affectFlight;uiNav=nav;uiFresh=valid;
            const needed=!!(fresh()&&(visible||affectFlight&&navigation));
            if(needed!==credited){credited=needed;for(const credit of sourceCredits)
                if(needed)creditApi.retainStaticCredit(credits,credit);else creditApi.releaseStaticCredit(credits,credit);}
            const status=doc?.getElementById('flight-wind-status'),force=doc?.getElementById('flight-wind-force'),arrows=doc?.getElementById('flight-wind-arrows');
            if(force)force.checked=affectFlight;if(arrows)arrows.checked=visible;
            const time=data?new Date(data.validAtUtc).toLocaleString(undefined,{dateStyle:'short',timeStyle:'short'}):'';
            const message=data?`${data.mode==='current'?'Aktueller Modellwind':'Windprognose'} · ${time}${fresh()?'':' · abgelaufen'}`:'Keine Winddaten geladen';
            if(status&&status.textContent!==message)status.textContent=message;
            const legend=doc?.getElementById('wind-legend');
            if(legend){legend.hidden=!visible||nav;const text=`${message} · Pfeile folgen der Strömung. Wind in m/s: grün <3, gelb 3–7, orange 7–12, rot ≥12. Open-Meteo, keine lokale Messung.`;
                if(legend.textContent!==text)legend.textContent=text;}
        }
        function ground(lat,lon){
            if(!isTerrainReady())return undefined;
            const key=`${lat.toFixed(6)},${lon.toFixed(6)}`;if(terrain.has(key))return terrain.get(key);
            C.Cartographic.fromDegrees(lon,lat,0,location);const value=viewer.scene.globe.getHeight(location);
            if(Number.isFinite(value)){if(terrain.size>=256)terrain.delete(terrain.keys().next().value);terrain.set(key,value);}return value;
        }
        function inside(p,b){return p.latitude>=b.south&&p.latitude<=b.north&&p.longitude>=b.west&&p.longitude<=b.east;}
        function remove(entry){collection.remove(entry.line);collection.remove(entry.back);}
        function rebuild(){
            dirty=false;terrainMissing=false;if(!data||!visible||!fresh())return;
            const count=density[profile],radius=navigation?Math.min(250,data.radiusMeters):data.radiusMeters;
            const center=navigation??{latitude:data.centerLatitude,longitude:data.centerLongitude};
            anchor={latitude:center.latitude,longitude:center.longitude,agl:navigation?.agl};
            const latStep=radius/111320,lonStep=radius/(111320*Math.cos(center.latitude*rad));
            windowBounds={south:Math.max(data.south,center.latitude-latStep),north:Math.min(data.north,center.latitude+latStep),
                west:Math.max(data.west,center.longitude-lonStep),east:Math.min(data.east,center.longitude+lonStep)};
            if(windowBounds.south>=windowBounds.north||windowBounds.west>=windowBounds.east){for(const e of entries)remove(e);entries=[];groundGrid=null;return;}
            const heights=navigation?(profile==='performance'?[Math.max(5,navigation.agl-20),navigation.agl+20]:[Math.max(5,navigation.agl-25),navigation.agl,navigation.agl+25]):
                profile==='quality'?[10,80,120,180]:profile==='performance'?[10,80]:[10,80,180];
            groundGrid={count,bounds:windowBounds,values:[]};
            for(let y=0;y<count;y++)for(let x=0;x<count;x++){
                const latitude=windowBounds.south+(windowBounds.north-windowBounds.south)*y/(count-1);
                const longitude=windowBounds.west+(windowBounds.east-windowBounds.west)*x/(count-1);
                const value=ground(latitude,longitude);groundGrid.values.push(value);if(!Number.isFinite(value))terrainMissing=true;
            }
            const maximum=count*count*heights.length,keep=[];
            const minHeight=Math.min(...heights)-10,maxHeight=Math.max(...heights)+10;
            for(const e of entries){
                const inHeight=navigation?e.agl>=minHeight&&e.agl<=maxHeight:heights.some(h=>Math.abs(e.agl-h)<.01);
                if(keep.length<maximum&&inside(e,windowBounds)&&inHeight)keep.push(e);else remove(e);
            }
            entries=keep;
            const spacing=2*radius/count,length=Math.max(10,Math.min(48,spacing*.24));
            for(let i=entries.length;i<maximum;i++){
                const agl=heights[i%heights.length],cell=Math.floor(i/heights.length),y=Math.floor(cell/count),x=cell%count;
                const latitude=windowBounds.south+(windowBounds.north-windowBounds.south)*(y+.5)/count;
                const longitude=windowBounds.west+(windowBounds.east-windowBounds.west)*(x+.5)/count;
                const paths=Array.from({length:2},()=>[new C.Cartesian3(),new C.Cartesian3()]);
                const tint=C.Color.fromCssColorString(palette[0]).withAlpha(0),backTint=C.Color.fromCssColorString('#101820').withAlpha(0);
                const material=C.Material.fromType('PolylineArrow',{color:tint}),background=C.Material.fromType('PolylineArrow',{color:backTint});
                const back=collection.add({positions:paths[0],width:7,material:background,show:false});
                const line=collection.add({positions:paths[0],width:4,material,show:false});
                entries.push({latitude,longitude,agl,length,paths,line,back,material,background,tint,backTint,band:-1,slot:0});
            }
            if(lastMotion===null)lastMotion=elapsed();
        }
        function groundAt(latitude,longitude){
            if(!groundGrid)return undefined;
            const {count,bounds:b,values}=groundGrid;
            const x=Math.max(0,Math.min(count-1,(longitude-b.west)/(b.east-b.west)*(count-1)));
            const y=Math.max(0,Math.min(count-1,(latitude-b.south)/(b.north-b.south)*(count-1)));
            const col=Math.min(count-2,Math.floor(x)),row=Math.min(count-2,Math.floor(y)),fx=x-col,fy=y-row;
            const a=values[row*count+col],c=values[(row+1)*count+col],d=values[(row+1)*count+col+1],e=values[row*count+col+1];
            return [a,c,d,e].every(Number.isFinite)?a*(1-fx)*(1-fy)+e*fx*(1-fy)+c*(1-fx)*fy+d*fx*fy:undefined;
        }
        const removeTerrain=viewer.scene.globe.tileLoadProgressEvent.addEventListener(pending=>{
            if(pending===0&&elapsed()-lastTerrain>500){lastTerrain=elapsed();terrain.clear();dirty=true;}
        });
        const removeUpdate=viewer.scene.preUpdate.addEventListener(()=>{
            if(disposed)return;
            if(navigation&&(!anchor||Math.abs(navigation.latitude-anchor.latitude)>30/111320||Math.abs(navigation.longitude-anchor.longitude)>30/111320||Math.abs(navigation.agl-anchor.agl)>10))dirty=true;
            if(dirty)rebuild();publish();controls();
            const shouldShow=!!(visible&&fresh()&&entries.length&&isTerrainReady());
            if(collection.show!==shouldShow)collection.show=shouldShow;
            const clock=elapsed();if(!collection.show){lastMotion=null;return;}if(clock-lastDraw<50)return;lastDraw=clock;
            const dt=lastMotion===null?0:Math.max(0,(clock-lastMotion)/1000);lastMotion=clock;
            for(const e of entries){
                const wind=sample(data,e.latitude,e.longitude,e.agl);
                if(!wind||wind.speedMs<.05){e.line.show=e.back.show=false;continue;}
                const altitude=(groundAt(e.latitude,e.longitude)??0)+e.agl,sin=Math.sin(e.latitude*rad);
                const denominator=Math.sqrt(1-eccentricitySquared*sin*sin);
                const northRadius=R*(1-eccentricitySquared)/(denominator**3)+altitude;
                const eastRadius=(R/denominator+altitude)*Math.max(.01,Math.cos(e.latitude*rad));
                e.latitude+=wind.north*dt/northRadius/rad;e.longitude+=wind.east*dt/eastRadius/rad;
                const b=windowBounds;
                // Recycle only at the displayed boundary, across the full field.
                if(!inside(e,b)){
                    const wrap=(v,lo,hi)=>lo+((v-lo)%(hi-lo)+(hi-lo))%(hi-lo);
                    e.latitude=wrap(e.latitude,b.south,b.north);e.longitude=wrap(e.longitude,b.west,b.east);
                }
                const unitN=wind.north/wind.speedMs,unitE=wind.east/wind.speedMs;
                const base=groundAt(e.latitude,e.longitude);
                const edge=Math.min((e.latitude-b.south)*R*rad,(b.north-e.latitude)*R*rad,
                    (e.longitude-b.west)*R*rad*Math.cos(e.latitude*rad),(b.east-e.longitude)*R*rad*Math.cos(e.latitude*rad));
                const alpha=Math.max(0,Math.min(1,edge/Math.max(30,e.length*2)));
                const band=wind.speedMs<3?0:wind.speedMs<7?1:wind.speedMs<12?2:3;
                if(band!==e.band){e.band=band;e.tint=C.Color.fromCssColorString(palette[band]).withAlpha(1);e.material.uniforms.color=e.tint;}
                e.tint.alpha=.92*alpha;e.background.uniforms.color.alpha=.65*alpha;
                const paths=e.paths[e.slot^=1];
                const lat=e.latitude+unitN*e.length/northRadius/rad,lon=e.longitude+unitE*e.length/eastRadius/rad;
                e.line.show=e.back.show=Number.isFinite(base)&&inside({latitude:lat,longitude:lon},b);
                for(let i=0;i<2;i++){
                    paths[i]=C.Cartesian3.fromDegrees(i?lon:e.longitude,i?lat:e.latitude,(base??0)+e.agl,undefined,paths[i]);
                }
                e.back.positions=paths;e.line.positions=paths;
            }
            viewer.scene.requestRender();
        });
        function flagsFromUi(){
            visible=!!doc.getElementById('flight-wind-arrows').checked;affectFlight=!!doc.getElementById('flight-wind-force').checked;dirty=true;
            send('wind-flags-changed',{visible,affectFlight});controls();
        }
        const force=doc?.getElementById('flight-wind-force'),arrows=doc?.getElementById('flight-wind-arrows'),button=doc?.getElementById('wind-flight');
        force?.addEventListener('change',flagsFromUi);arrows?.addEventListener('change',flagsFromUi);
        const requestSettings=()=>send('wind-settings-request',{});button?.addEventListener('click',requestSettings);
        return {
            set(command){
                if(disposed)return {};
                if(typeof command.visible!=='boolean'||typeof command.affectFlight!=='boolean')throw Error('Invalid wind controls');
                const next=command.field==null?null:field(command.field);
                data=next;visible=command.visible;affectFlight=command.affectFlight;dirty=true;controls();viewer.scene.requestRender();return {};
            },
            sample(point){
                if(!affectFlight)return null;
                const value=fresh()?sample(data,point.latitude,point.longitude,point.agl):null;
                return value?{...value,enabled:true,available:true}:{...zero,enabled:true,available:false,reason:!data?'unavailable':!fresh()?'expired':'outside'};
            },
            navigation(point){const next=point&&[point.latitude,point.longitude,point.agl].every(Number.isFinite)?point:null;
                if(!next&&navigation||next&&!navigation)dirty=true;navigation=next;},
            terrainChanged(){terrain.clear();dirty=true;},
            performance(value){if(!Object.hasOwn(density,value))throw Error('Invalid wind graphics profile');
                if(profile!==value){profile=value;dirty=true;}},
            dispose(){if(disposed)return;disposed=true;removeTerrain();removeUpdate();force?.removeEventListener('change',flagsFromUi);arrows?.removeEventListener('change',flagsFromUi);button?.removeEventListener('click',requestSettings);
                terrain.clear();entries=[];if(credited)for(const credit of sourceCredits)creditApi.releaseStaticCredit(credits,credit);viewer.scene.primitives.remove(collection);const legend=doc?.getElementById('wind-legend');if(legend)legend.hidden=true;}
        };
    }
    return {field,sample,create};
});
