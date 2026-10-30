(function(root,factory){const api=factory();if(typeof module==='object'&&module.exports)module.exports=api;else root.FPVMapLabels=api;
})(typeof globalThis!=='undefined'?globalThis:this,function(){
    'use strict';
    const sources={place:'ch.swisstopo.swissnames3d',street:'ch.swisstopo.amtliches-strassenverzeichnis'};
    const valid=(lat,lon)=>Number.isFinite(lat)&&Number.isFinite(lon)&&Math.abs(lat)<=90&&Math.abs(lon)<=180;
    function normalize(raw,kind,bounds){
        if(!raw||!Array.isArray(raw.results)||raw.results.length>650)throw Error('Invalid label response');
        const records=new Map();
        for(const f of raw.results){
            if(f?.layerBodId!==sources[kind]||!f.properties)continue;
            const p=f.properties,text=kind==='street'?p.stn_label:p.name;
            if(typeof text!=='string'||!text.trim()||text.length>160||/[\u0000-\u001f<>]/.test(text))continue;
            if(kind==='place'&&p.objektklasse!=='TLM_SIEDLUNGSNAME')continue;
            if(kind==='street'&&p.str_status&&p.str_status!=='bestehend')continue;
            let lon,lat;
            if(f.geometry?.type==='Point'&&Array.isArray(f.geometry.coordinates))[lon,lat]=f.geometry.coordinates;
            else if(Array.isArray(f.bbox)&&f.bbox.length===4&&f.bbox.every(Number.isFinite)){
                lon=(f.bbox[0]+f.bbox[2])/2;lat=(f.bbox[1]+f.bbox[3])/2;
            }
            if(!valid(lat,lon)||lon<bounds.west||lon>bounds.east||lat<bounds.south||lat>bounds.north)continue;
            const id=f.featureId??f.id;if(!['string','number'].includes(typeof id)||String(id).length>100)continue;
            records.set(kind+':'+id,{id:kind+':'+id,text:text.trim(),latitude:lat,longitude:lon,kind,
                priority:kind==='street'?2:/^(Ort|Stadt|Dorf)$/i.test(p.objektart??'')?0:1});
            if(records.size>=256)break;
        }
        return {records:[...records.values()],limited:raw.results.length>=200};
    }
    function url(kind,b){
        const params=new URLSearchParams({layers:'all:'+sources[kind],geometry:[b.west,b.south,b.east,b.north].join(','),
            geometryType:'esriGeometryEnvelope',sr:'4326',tolerance:'0',returnGeometry:'true',geometryFormat:'geojson',limit:'100',lang:'de'});
        // No mapExtent/imageDisplay: that source's scale-dependent geometry can
        // otherwise omit names. Only the small requested envelope is queried.
        return 'https://api3.geo.admin.ch/rest/services/ech/MapServer/identify?'+params;
    }
    function create(C,viewer,emit=()=>{},{fetcher=globalThis.fetch,online=()=>globalThis.navigator?.onLine!==false,
        cachedOnly=false,timers=globalThis,now=()=>Date.now(),cacheEntries=24}={}){
        const scene=viewer.scene,canvas=viewer.canvas,collection=new C.LabelCollection({scene});scene.primitives.add(collection);collection.show=false;
        const cache=new Map(),heights=new Map(),pool=[],position=new C.Cartographic();
        const credit=new C.Credit('Orts-/Straßennamen · © swisstopo · swissNAMES3D / amtliches Strassenverzeichnis',true);
        const credits=viewer.cesiumWidget?.creditDisplay;
        let requested=false,disposed=false,credited=false,controller=null,revision=0,timer=null,records=[],dirty=false,lastKey=null,lastDraw=0,state='off',retryAt=0;
        function publish(next){if(state===next)return;state=next;emit('labels-layer-status',{state});}
        function permitted(){return !cachedOnly&&online();}
        function stop(){revision++;controller?.abort();controller=null;timers.clearTimeout(timer);timer=null;}
        function creditState(){const show=requested&&permitted();if(show===credited)return;credited=show;if(show)credits?.addStaticCredit(credit);else credits?.removeStaticCredit(credit);}
        function viewport(){
            let center=viewer.camera.positionCartographic;
            try{const ray=viewer.camera.getPickRay?.(new C.Cartesian2((canvas.clientWidth||800)/2,(canvas.clientHeight||600)/2));
                const picked=ray&&scene.globe.pick?.(ray,scene);if(picked)center=C.Cartographic.fromCartesian(picked);}catch(_){/* Use the camera footprint when looking at sky. */}
            if(!center)return null;
            const latitude=C.Math.toDegrees(center.latitude),longitude=C.Math.toDegrees(center.longitude);
            if(!valid(latitude,longitude)||latitude<45.5||latitude>48.5||longitude<5.5||longitude>11)return null;
            const ground=scene.globe.getHeight(center),height=Math.max(100,viewer.camera.positionCartographic.height-(Number.isFinite(ground)?ground:0));
            if(height>350000)return {zoomIn:true};
            const radius=Math.max(650,Math.min(45000,height*.8)),dy=radius/111320,dx=dy/Math.cos(latitude*Math.PI/180);
            const lat=Math.round(latitude/dy)*dy,lon=Math.round(longitude/dx)*dx;
            return {west:Math.max(5.5,lon-dx*1.5),east:Math.min(11,lon+dx*1.5),south:Math.max(45.5,lat-dy*1.5),north:Math.min(48.5,lat+dy*1.5),
                streets:height<12000,key:[Math.round(latitude/dy),Math.round(longitude/dx),Math.round(Math.log2(radius)),height<12000].join(':')};
        }
        async function json(address,signal){
            const response=await fetcher(address,{signal,credentials:'omit',redirect:'error',referrerPolicy:'no-referrer'});
            if(!response.ok)throw Error('Label source unavailable');
            const max=4*1024*1024,declared=Number(response.headers?.get?.('content-length')||0);
            if(declared>max)throw Error('Label response too large');
            const chunks=[];let length=0;const reader=response.body?.getReader?.();
            if(!reader)throw Error('Streaming label response required');
            try{for(;;){const {value,done}=await reader.read();if(done)break;length+=value.byteLength;if(length>max)throw Error('Label response too large');chunks.push(value);}}
            catch(error){try{await reader.cancel();}catch(_){}throw error;}finally{reader.releaseLock();}
            const bytes=new Uint8Array(length);let offset=0;for(const chunk of chunks){bytes.set(chunk,offset);offset+=chunk.length;}
            return JSON.parse(new TextDecoder('utf-8',{fatal:true}).decode(bytes));
        }
        async function load(force=false){
            if(disposed||!requested)return;
            creditState();
            if(!permitted()){stop();collection.show=false;publish('offline');return;}
            const bounds=viewport();if(!bounds||bounds.zoomIn){stop();collection.show=false;publish(bounds?'zoomIn':'outside');return;}
            collection.show=true;
            const hit=cache.get(bounds.key);
            if(!force&&hit&&now()-hit.time<15*60*1000){cache.delete(bounds.key);cache.set(bounds.key,hit);records=hit.records;dirty=true;publish(hit.partial?'partial':'ready');scene.requestRender();return;}
            if(!force&&(controller&&lastKey===bounds.key||lastKey===bounds.key&&now()<retryAt))return;
            stop();const current=++revision;lastKey=bounds.key;controller=new AbortController();const requestController=controller,signal=controller.signal;
            const timeout=timers.setTimeout(()=>requestController.abort(),12000);publish('loading');
            try{
                const kinds=bounds.streets?['place','street']:['place'];
                const results=await Promise.allSettled(kinds.map(async kind=>normalize(await json(url(kind,bounds),signal),kind,bounds)));
                if(disposed||current!==revision||!requested||!permitted())return;
                const successful=results.filter(r=>r.status==='fulfilled');if(!successful.length)throw Error('No label data');
                const next=successful.flatMap(r=>r.value.records).sort((a,b)=>a.priority-b.priority||a.id.localeCompare(b.id));
                const partial=successful.length!==kinds.length||successful.some(r=>r.value.limited);
                const value={records:next.slice(0,400),partial,time:now()};cache.delete(bounds.key);cache.set(bounds.key,value);
                while(cache.size>cacheEntries)cache.delete(cache.keys().next().value);
                records=value.records;dirty=true;retryAt=0;publish(partial?'partial':'ready');scene.requestRender();
            }catch(_){if(!disposed&&current===revision&&requested){retryAt=now()+30000;publish('failed');}}
            finally{timers.clearTimeout(timeout);if(current===revision)controller=null;}
        }
        function schedule(){dirty=true;if(timer===null&&requested)timer=timers.setTimeout(()=>{timer=null;void load();},500);}
        function draw(){
            if(!requested||!collection.show||!dirty||now()-lastDraw<100)return;dirty=false;lastDraw=now();
            const occupied=[],names=new Set();let count=0;
            for(const record of records){
                if(count>=80)break;
                const key=record.latitude+','+record.longitude;
                let ground=heights.get(key);if(ground===undefined){C.Cartographic.fromDegrees(record.longitude,record.latitude,0,position);ground=scene.globe.getHeight(position);if(Number.isFinite(ground)){if(heights.size>=512)heights.delete(heights.keys().next().value);heights.set(key,ground);}}
                const p=C.Cartesian3.fromDegrees(record.longitude,record.latitude,Number.isFinite(ground)?ground+5:0);
                const point=C.SceneTransforms.worldToWindowCoordinates(scene,p);
                if(!point||point.x<12||point.x>canvas.clientWidth-12||point.y<16||point.y>canvas.clientHeight-48||names.has(record.text))continue;
                const size=record.kind==='street'?14:record.priority===0?17:15,width=Math.min(250,record.text.length*size*.6)+14;
                const box={left:point.x-width/2,right:point.x+width/2,top:point.y-size,bottom:point.y+size};
                if(occupied.some(b=>box.left<b.right&&box.right>b.left&&box.top<b.bottom&&box.bottom>b.top))continue;
                occupied.push(box);names.add(record.text);
                const label=pool[count]??(pool[count]=collection.add({text:'',show:false,heightReference:C.HeightReference.RELATIVE_TO_GROUND,
                    style:C.LabelStyle.FILL_AND_OUTLINE,outlineColor:C.Color.BLACK,outlineWidth:2,disableDepthTestDistance:0,
                    showBackground:true,backgroundColor:C.Color.BLACK.withAlpha(.65),backgroundPadding:new C.Cartesian2(4,3)}));
                // A small visual offset keeps glyphs clear of surface depth
                // fighting; it is not an object elevation or source height.
                label.text=record.text;label.position=C.Cartesian3.fromDegrees(record.longitude,record.latitude,5);label.font=`600 ${size}px sans-serif`;
                label.fillColor=C.Color.fromCssColorString(record.kind==='street'?'#ffffff':'#e4f2c6');label.show=true;count++;
            }
            for(let i=count;i<pool.length;i++)pool[i].show=false;
        }
        const removeChanged=viewer.camera.changed.addEventListener(schedule),removeRender=scene.preRender.addEventListener(draw);
        const removeTerrain=scene.globe.tileLoadProgressEvent.addEventListener(pending=>{if(pending===0){heights.clear();dirty=true;}});
        return {set(command){if(typeof command.visible!=='boolean')throw Error('Invalid label visibility');requested=command.visible;
            if(!requested){stop();collection.show=false;publish('off');creditState();return {};}
            void load(command.retry===true);return {};},networkChanged(){if(requested)void load(true);},
            dispose(){if(disposed)return;disposed=true;stop();removeChanged();removeRender();removeTerrain();cache.clear();heights.clear();if(credited)credits?.removeStaticCredit(credit);scene.primitives.remove(collection);}};
    }
    return {create,normalize,url,sources};
});
