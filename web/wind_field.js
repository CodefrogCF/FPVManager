(function(root,factory){
    const api=factory();
    if(typeof module==='object'&&module.exports)module.exports=api;else root.FPVWindField=api;
})(typeof globalThis!=='undefined'?globalThis:this,function(){
    'use strict';
    const rad=Math.PI/180,R=6378137,zero=Object.freeze({north:0,east:0,up:0});
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
        const materials=['#32a172','#f8c449','#ed842d','#cd4041'].map(color=>C.Material.fromType('PolylineArrow',{color:C.Color.fromCssColorString(color).withAlpha(.85)}));
        const terrain=new Map(),location=new C.Cartographic(),local=new C.Cartesian3();
        const credit=new C.Credit('<a href="https://open-meteo.com/" target="_blank" rel="noopener">Open-Meteo</a> · CC BY 4.0 · interpolated wind',true);
        const credits=viewer.cesiumWidget?.creditDisplay;let credited=false;
        let data=null,visible=false,affectFlight=false,disposed=false,dirty=true,terrainMissing=false,entries=[],navigation=null,anchor=null,profile='balanced',lastDraw=-Infinity,lastTerrain=0,status=null;
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
            if(needed!==credited){credited=needed;if(needed)credits?.addStaticCredit(credit);else credits?.removeStaticCredit(credit);}
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
        function rebuild(){
            dirty=false;terrainMissing=false;collection.removeAll();entries=[];if(!data||!visible||!fresh())return;
            const count=density[profile],radius=navigation?Math.min(250,data.radiusMeters):data.radiusMeters;
            const center=navigation??{latitude:data.centerLatitude,longitude:data.centerLongitude};
            anchor={latitude:center.latitude,longitude:center.longitude,agl:navigation?.agl};
            const latStep=radius/111320,lonStep=radius/(111320*Math.cos(center.latitude*rad));
            const heights=navigation?(profile==='performance'?[Math.max(5,navigation.agl-20),navigation.agl+20]:[Math.max(5,navigation.agl-25),navigation.agl,navigation.agl+25]):
                profile==='quality'?[10,80,120,180]:profile==='performance'?[10,80]:[10,80,180];
            const spacing=2*radius/(count-1),span=Math.min(120,spacing*.65),length=Math.max(8,Math.min(60,spacing*.25));
            for(let y=0;y<count;y++)for(let x=0;x<count;x++){
                const latitude=center.latitude+(2*y/(count-1)-1)*latStep,longitude=center.longitude+(2*x/(count-1)-1)*lonStep;
                const base=ground(latitude,longitude);if(!Number.isFinite(base)){terrainMissing=true;continue;}
                for(const agl of heights){
                    const wind=sample(data,latitude,longitude,agl);if(!wind||wind.speedMs<.05)continue;
                    const position=C.Cartesian3.fromDegrees(longitude,latitude,base+agl),transform=C.Transforms.eastNorthUpToFixedFrame(position);
                    const paths=Array.from({length:2},()=>[new C.Cartesian3(),new C.Cartesian3()]);
                    const band=wind.speedMs<3?0:wind.speedMs<7?1:wind.speedMs<12?2:3;
                    const line=collection.add({positions:paths[0],width:4,material:materials[band],show:false});
                    entries.push({latitude,longitude,transform,wind,span,length,paths,line,slot:0,offset:entries.length*.618});
                }
            }
        }
        const removeTerrain=viewer.scene.globe.tileLoadProgressEvent.addEventListener(pending=>{
            if(pending===0&&elapsed()-lastTerrain>500){lastTerrain=elapsed();terrain.clear();dirty=true;}
        });
        const removeUpdate=viewer.scene.preUpdate.addEventListener(()=>{
            if(disposed)return;
            if(navigation&&(!anchor||Math.abs(navigation.latitude-anchor.latitude)>30/111320||Math.abs(navigation.longitude-anchor.longitude)>30/111320||Math.abs(navigation.agl-anchor.agl)>10))dirty=true;
            if(dirty)rebuild();publish();controls();collection.show=!!(visible&&fresh()&&entries.length&&isTerrainReady());
            const clock=elapsed();if(!collection.show||clock-lastDraw<50)return;lastDraw=clock;
            for(const e of entries){
                const unitN=e.wind.north/e.wind.speedMs,unitE=e.wind.east/e.wind.speedMs;
                const travel=((clock/1000*e.wind.speedMs+e.offset*e.span)%e.span)-e.span/2;
                const paths=e.paths[e.slot^=1];
                const lat=e.latitude+(unitN*(travel+e.length))/R/rad,lon=e.longitude+(unitE*(travel+e.length))/(R*Math.cos(e.latitude*rad))/rad;
                e.line.show=lat>=data.south&&lat<=data.north&&lon>=data.west&&lon<=data.east;
                for(let i=0;i<2;i++){
                    const distance=travel+(i?e.length:0);local.x=unitE*distance;local.y=unitN*distance;local.z=0;
                    C.Matrix4.multiplyByPoint(e.transform,local,paths[i]);
                }
                e.line.positions=paths;
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
            performance(value){if(!Object.hasOwn(density,value))throw Error('Invalid wind graphics profile');profile=value;dirty=true;},
            dispose(){if(disposed)return;disposed=true;removeTerrain();removeUpdate();force?.removeEventListener('change',flagsFromUi);arrows?.removeEventListener('change',flagsFromUi);button?.removeEventListener('click',requestSettings);
                terrain.clear();entries=[];if(credited)credits?.removeStaticCredit(credit);viewer.scene.primitives.remove(collection);const legend=doc?.getElementById('wind-legend');if(legend)legend.hidden=true;}
        };
    }
    return {field,sample,create};
});
