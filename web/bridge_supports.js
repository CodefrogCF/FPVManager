/* Bounded synthetic supports for explicitly mapped bridge decks. The source
 * deck stays untouched; pier spacing is illustrative, not surveyed engineering. */
(function(root,factory){
    const api=factory(typeof module==='object'&&module.exports?require('./map_providers.js'):root.FPVMapProviders);
    if(typeof module==='object'&&module.exports)module.exports=api;
    else root.FPVBridgeSupports=api;
})(typeof globalThis!=='undefined'?globalThis:this,function(Credits){
    'use strict';
    const creditApi=Credits??{retainStaticCredit:(d,c)=>d?.addStaticCredit(c),releaseStaticCredit:(d,c)=>d?.removeStaticCredit(c)};
    const R=6378137,DEG=Math.PI/180,RADIUS=600,MAX_BYTES=2*1024*1024;
    const ENDPOINTS=['https://overpass.private.coffee/api/interpreter','https://overpass-api.de/api/interpreter'];
    const BUDGETS={quality:128,balanced:96,performance:48,compatibility:24,navigation:64};
    const afterFrame=signal=>new Promise(resolve=>{
        let frame=null,timer=null;
        const finish=()=>{if(frame!==null)globalThis.cancelAnimationFrame?.(frame);clearTimeout(timer);
            signal?.removeEventListener('abort',finish);resolve();};
        if(signal?.aborted){finish();return;}
        const defer=()=>{frame=null;timer=setTimeout(finish,0);};
        signal?.addEventListener('abort',finish,{once:true});
        if(typeof globalThis.requestAnimationFrame==='function')frame=globalThis.requestAnimationFrame(defer);
        else defer();
    });
    const finite=Number.isFinite;
    const distance=(a,b)=>Math.hypot((a.longitude-b.longitude)*DEG*R*Math.cos((a.latitude+b.latitude)*DEG/2),
        (a.latitude-b.latitude)*DEG*R);
    const valid=p=>p&&[p.longitude,p.latitude].every(finite)&&p.longitude>=5.8&&p.longitude<=10.7&&
        p.latitude>=45.6&&p.latitude<=47.9;
    const supportKind=tags=>/^(?:pier|lift_pier|pivot_pier|pylon)$/.test(String(tags?.['bridge:support']||''))||
        tags?.man_made==='bridge_pier';
    const metres=value=>{
        if(finite(value))return value;
        const match=typeof value==='string'&&value.trim().match(/^(\d+(?:\.\d+)?)\s*(?:m)?$/);
        return match?Number(match[1]):null;
    };
    const suppliedHeight=(properties,coordinate)=>{
        if(finite(properties?.deckMetersWgs84))return properties.deckMetersWgs84;
        if(['WGS84_ELLIPSOID','EPSG:4979'].includes(properties?.elevationReference||properties?.heightReference||
            properties?.coordinateReference)&&finite(coordinate?.[2]))return coordinate[2];
        return null;
    };
    function mappedPier(id,coordinates,tags={},properties={}){
        if(!coordinates.length||!coordinates.every(valid))return null;
        const ring=coordinates.length>2&&distance(coordinates[0],coordinates.at(-1))<.1?
            coordinates.slice(0,-1):coordinates;
        const center={longitude:ring.reduce((sum,p)=>sum+p.longitude,0)/ring.length,
            latitude:ring.reduce((sum,p)=>sum+p.latitude,0)/ring.length};
        const radius=Math.max(.4,Math.min(6,Math.max(...ring.map(p=>distance(center,p)))||
            metres(tags.diameter)/2||.8));
        const height=metres(tags.height??properties.heightMeters);
        return {...center,id:String(id),radius,mapped:true,source:properties.source||'OpenStreetMap',
            topMetersWgs84:suppliedHeight(properties),
            heightMeters:finite(height)&&height>=2.5&&height<=150?height:null};
    }
    function parseBridgeData(document){
        if(!document||!Array.isArray(document.elements))throw Error('Invalid bridge response');
        const bridges=[],piers=[],seen=new Set();let vertices=0;
        for(const element of document.elements.slice(0,512)){
            if(!element||!Number.isSafeInteger(element.id)||!element.tags)continue;
            const tags=element.tags,key=`${element.type}/${element.id}`;
            if(seen.has(key))continue;seen.add(key);
            const geometry=element.type==='node'?[element]:element.geometry;
            if(!Array.isArray(geometry)||geometry.length<1||geometry.length>256)continue;
            const coordinates=geometry.map(p=>({longitude:p?.lon,latitude:p?.lat}));
            if(!coordinates.every(valid)||(vertices+=coordinates.length)>8192)continue;
            if(supportKind(tags)){
                const pier=mappedPier(`osm-support:${key}`,coordinates,tags);
                if(pier&&piers.length<192)piers.push(pier);
                continue;
            }
            if(element.type!=='way'||(!tags.highway&&!tags.railway)||!tags.bridge||
                /^(?:no|false|0)$/i.test(tags.bridge)||coordinates.length<2||bridges.length>=48)continue;
            bridges.push({id:`osm-bridge:${element.id}`,coordinates,
                name:String(tags.name||'Bridge').slice(0,120),source:'OpenStreetMap',sourceId:`way/${element.id}`,
                mappedOnly:/suspension|cable.?stayed|arch|hanging/i.test(`${tags.bridge} ${tags['bridge:structure']||''}`)});
        }
        return {bridges,piers};
    }
    function parseSourceFeatures(input,{sourceId='osint',elevationReference,source=sourceId}={}){
        const features=Array.isArray(input)?input:input?.type==='FeatureCollection'?input.features:[];
        const bridges=[],piers=[];
        if(!Array.isArray(features))return {bridges,piers};
        for(const [index,feature] of features.slice(0,1200).entries()){
            const properties={elevationReference,...(feature?.properties||{}),...(feature?.tags||{})},tags=properties.tags||properties;
            if(feature?.sourceType==='BRIDGE'&&feature.supportOnly!==true&&Array.isArray(feature.parts)){
                for(const [part,piece] of feature.parts.slice(0,16).entries()){
                    if(bridges.length>=48)break;
                    if(!['LineString','PolygonOuter'].includes(piece.kind)||piece.elevated!==true||!Array.isArray(piece.coordinates)||
                        piece.coordinates.length<2||piece.coordinates.length>512)continue;
                    let coordinates=piece.coordinates.map(p=>({longitude:p?.[0],latitude:p?.[1],
                        height:suppliedHeight(properties,p)}));
                    if(!coordinates.every(p=>valid(p)&&finite(p.height)))continue;
                    if(piece.kind==='PolygonOuter'){
                        if(distance(coordinates[0],coordinates.at(-1))<.1)coordinates=coordinates.slice(0,-1);
                        const n=coordinates.length;if(n<3)continue;
                        const lon=coordinates.reduce((sum,p)=>sum+p.longitude,0)/n,
                            lat=coordinates.reduce((sum,p)=>sum+p.latitude,0)/n,
                            scale=R*DEG*Math.cos(lat*DEG);
                        const points=coordinates.map(p=>({x:(p.longitude-lon)*scale,
                            y:(p.latitude-lat)*R*DEG,height:p.height}));
                        const xx=points.reduce((sum,p)=>sum+p.x*p.x,0),yy=points.reduce((sum,p)=>sum+p.y*p.y,0),
                            cross=points.reduce((sum,p)=>sum+p.x*p.y,0),angle=.5*Math.atan2(2*cross,xx-yy);
                        const projected=points.map(p=>({...p,d:p.x*Math.cos(angle)+p.y*Math.sin(angle)}));
                        const meanH=points.reduce((sum,p)=>sum+p.height,0)/n,
                            denominator=projected.reduce((sum,p)=>sum+p.d*p.d,0),
                            grade=denominator?projected.reduce((sum,p)=>sum+p.d*(p.height-meanH),0)/denominator:0;
                        if(Math.abs(grade)>.5)continue;
                        coordinates=[Math.min(...projected.map(p=>p.d)),Math.max(...projected.map(p=>p.d))].map(d=>({
                            longitude:lon+d*Math.cos(angle)/scale,latitude:lat+d*Math.sin(angle)/(R*DEG),height:meanH+grade*d}));
                    }
                    bridges.push({id:`${sourceId}:${feature.id??index}:${part}`,source,
                        sourceId:String(feature.id??index),coordinates,mappedOnly:false,
                        profileMethod:'aviation-obstacle-profile',name:String(feature.name||'Bridge').slice(0,120)});
                }
                continue;
            }
            const geometry=feature?.geometry;
            if(!geometry)continue;
            const id=`${sourceId}:${feature.id??index}`;
            const asPoint=p=>({longitude:p?.[0],latitude:p?.[1]});
            if(supportKind(tags)){
                const raw=geometry.type==='Point'?[geometry.coordinates]:geometry.type==='Polygon'?
                    geometry.coordinates?.[0]:geometry.type==='LineString'?geometry.coordinates:[];
                if(!Array.isArray(raw)||raw.length>256)continue;
                const pier=mappedPier(id,raw.map(asPoint),tags,{...properties,source,
                    deckMetersWgs84:suppliedHeight(properties,raw[0])});
                if(pier)piers.push(pier);
                continue;
            }
            if(!tags.bridge||/^(?:no|false|0)$/i.test(tags.bridge))continue;
            const lines=geometry.type==='LineString'?[geometry.coordinates]:
                geometry.type==='MultiLineString'?geometry.coordinates:[];
            if(!Array.isArray(lines))continue;
            for(const [part,line] of lines.slice(0,16).entries()){
                if(!Array.isArray(line)||line.length<2||line.length>256)continue;
                const coordinates=line.map(p=>({...asPoint(p),height:suppliedHeight(properties,p)}));
                if(!coordinates.every(valid))continue;
                bridges.push({id:`${id}:${part}`,source,sourceId:id,coordinates,
                    name:String(feature.name||tags.name||'Bridge').slice(0,120),
                    mappedOnly:/suspension|cable.?stayed|arch|hanging/i.test(`${tags.bridge} ${tags['bridge:structure']||''}`)});
            }
        }
        return {bridges:bridges.slice(0,48),piers:piers.slice(0,192)};
    }
    function parseBridges(document){
        return parseBridgeData(document).bridges.filter(bridge=>!bridge.mappedOnly);
    }
    function stations(bridges,center,budget=96,piers=[]){
        const result=[],matched=new Set();
        for(const bridge of bridges){
            const line=bridge.coordinates,cumulative=[0];
            for(let i=1;i<line.length;i++)cumulative.push(cumulative.at(-1)+distance(line[i-1],line[i]));
            const total=cumulative.at(-1);
            if(total<24||total>20000)continue;
            const at=d=>{
                let i=0;while(i<cumulative.length-2&&cumulative[i+1]<d)i++;
                const t=(d-cumulative[i])/(cumulative[i+1]-cumulative[i]||1);
                return {longitude:line[i].longitude+(line[i+1].longitude-line[i].longitude)*t,
                    latitude:line[i].latitude+(line[i+1].latitude-line[i].latitude)*t,
                    height:finite(line[i].height)&&finite(line[i+1].height)?
                        line[i].height+(line[i+1].height-line[i].height)*t:null};
            };
            const nearest=p=>{
                let best=null;
                for(let i=1;i<line.length;i++){
                    const a=line[i-1],b=line[i],scale=R*DEG*Math.cos(p.latitude*DEG),
                        dx=(b.longitude-a.longitude)*scale,dy=(b.latitude-a.latitude)*R*DEG,
                        px=(p.longitude-a.longitude)*scale,py=(p.latitude-a.latitude)*R*DEG,
                        t=Math.max(0,Math.min(1,(px*dx+py*dy)/(dx*dx+dy*dy||1))),
                        gap=Math.hypot(px-dx*t,py-dy*t);
                    if(!best||gap<best.gap)best={gap,along:cumulative[i-1]+(cumulative[i]-cumulative[i-1])*t};
                }
                return best;
            };
            const mapped=piers.map(pier=>({pier,near:nearest(pier)})).filter(({pier,near})=>
                !matched.has(pier.id)&&near&&near.gap<=12&&near.along>1&&near.along<total-1);
            if(mapped.length){
                for(const {pier,near} of mapped){
                    if(center&&distance(pier,center)>RADIUS+100)continue;
                    const profile=at(near.along);
                    result.push({...pier,positionSource:pier.source,sourceId:bridge.sourceId,source:bridge.source,
                        deckMetersWgs84:finite(pier.topMetersWgs84)?pier.topMetersWgs84:profile.height,
                        profileMethod:bridge.profileMethod,
                        probes:[at(Math.max(0,near.along-4)),{...pier,height:profile.height},at(Math.min(total,near.along+4))]});
                    matched.add(pier.id);if(result.length>=budget)return result;
                }
                continue;
            }
            if(bridge.mappedOnly)continue;
            const spans=Math.max(2,Math.ceil(total/28));
            for(let i=1;i<spans;i++){
                const along=total*i/spans,p=at(along);
                if(center&&distance(p,center)>RADIUS+100)continue;
                if(result.some(q=>distance(p,q)<2))continue;
                result.push({...p,id:`${bridge.id}:${i}`,sourceId:bridge.sourceId,
                    source:bridge.source,mapped:false,deckMetersWgs84:p.height,profileMethod:bridge.profileMethod,
                    probes:[at(along-4),p,at(along+4)]});
                if(result.length>=budget)return result;
            }
        }
        for(const pier of piers){
            if(matched.has(pier.id)||(!finite(pier.topMetersWgs84)&&!finite(pier.heightMeters))||
                (center&&distance(pier,center)>RADIUS+100))continue;
            result.push({...pier,sourceId:pier.id,deckMetersWgs84:pier.topMetersWgs84,probes:[pier,pier,pier]});
            if(result.length>=budget)break;
        }
        return result;
    }
    function create(C,viewer,{sampleTerrain=async()=>[],ready=()=>true,cachedOnly=false,
        isOnline=()=>globalThis.navigator?.onLine!==false,getDeckTileset=null,discoverBridges=null,disposeDiscovery=()=>{},
        fetcher=(...args)=>fetch(...args),now=()=>Date.now(),yieldBatch=afterFrame}={}){
        const scene=viewer.scene;
        let enabled=false,structuresEnabled=false,disposed=false,profile='balanced',opacity=1,revision=0,controller=null;
        const sourceSets=new Map();
        let primitive=null,supports=[],cache=null,pending=null,pendingCenter=null,lastCenter=null,lastRefreshAt=-Infinity;
        let lastFrameAt=-Infinity,error=null,retryAt=-Infinity,credited=false;
        let sourceQuery=null,drawSignature=null;
        const creditDisplay=viewer.cesiumWidget?.creditDisplay;
        const sourceCredits=C.Credit?{
            osm:new C.Credit('<a href="https://www.openstreetmap.org/copyright" target="_blank" rel="noopener">© OpenStreetMap</a>',true),
            aviation:new C.Credit('<a href="https://www.bazl.admin.ch/de/luftfahrthindernisdaten-schweiz" target="_blank" rel="noopener">BAZL / Skyguide · Luftfahrthindernisse</a>',false),
            native:new C.Credit('© swisstopo',false)
        }:{};
        const activeCredits=new Set();
        function credits(show){
            const needed=new Set();
            if(show)for(const support of supports){
                if(/OpenStreetMap/.test(support.source||'')||/OpenStreetMap/.test(support.positionSource||''))needed.add('osm');
                if(/BAZL|aviation/i.test(support.source||''))needed.add('aviation');
                if(/swisstopo/i.test(support.source||''))needed.add('native');
            }
            for(const key of activeCredits)if(!needed.has(key)){
                creditApi.releaseStaticCredit(creditDisplay,sourceCredits[key]);activeCredits.delete(key);
            }
            for(const key of needed)if(sourceCredits[key]&&!activeCredits.has(key)){
                creditApi.retainStaticCredit(creditDisplay,sourceCredits[key]);activeCredits.add(key);
            }
        }
        const status=()=>({enabled:enabled&&!disposed,count:supports.length,pending:!!pending,
            sourceCount:sourceSets.size,mappedCount:supports.filter(p=>p.mapped).length,
            quality:'simulation-only',error,supports:supports.map(p=>({...p}))});
        function clear(){
            if(primitive){scene.primitives.remove(primitive);primitive=null;}
            supports=[];drawSignature=null;credits(false);scene.requestRender?.();
        }
        function focus(){
            const canvas=scene.canvas||viewer.canvas,camera=viewer.camera;
            try{
                if(canvas&&C.Cartesian2&&C.Cartographic?.fromCartesian){
                    const pixel=new C.Cartesian2((canvas.clientWidth||canvas.width)/2,(canvas.clientHeight||canvas.height)/2);
                    const ray=camera?.getPickRay?.(pixel),hit=ray&&scene.globe.pick?.(ray,scene);
                    const position=hit&&C.Cartographic.fromCartesian(hit);
                    if(position){const p={longitude:position.longitude/DEG,latitude:position.latitude/DEG};if(valid(p))return p;}
                }
            }catch(_){/* use camera coordinate when a visible ground pick is unavailable */}
            const p=camera?.positionCartographic;
            const result=p&&{longitude:p.longitude/DEG,latitude:p.latitude/DEG};
            return valid(result)?result:null;
        }
        async function fetchRoutes(center,signal){
            if(cache&&distance(center,cache.center)<250&&now()-cache.time<300000)return cache.data;
            if(cachedOnly||!isOnline())return {bridges:[],piers:[]};
            const dy=RADIUS/(R*DEG),dx=dy/Math.cos(center.latitude*DEG);
            const box=[center.latitude-dy,center.longitude-dx,center.latitude+dy,center.longitude+dx].join(',');
            const query=`[out:json][timeout:8][maxsize:2097152];(way["highway"]["bridge"](${box});`+
                `way["railway"]["bridge"](${box});`+
                `nwr["bridge:support"~"^(pier|lift_pier|pivot_pier|pylon)$"](${box});`+
                `nwr["man_made"="bridge_pier"](${box}););out geom;`;
            let failure;
            for(const endpoint of ENDPOINTS){
                signal.throwIfAborted?.();
                const timeout=new AbortController(),cancel=()=>timeout.abort();
                signal.addEventListener('abort',cancel,{once:true});
                const timer=setTimeout(()=>timeout.abort(),10000);
                try{
                    const response=await fetcher(`${endpoint}?data=${encodeURIComponent(query)}`,{signal:timeout.signal,credentials:'omit'});
                    if(!response?.ok)throw Error(`Bridge data unavailable (${response?.status||'network'})`);
                    if(Number(response.headers?.get?.('content-length')||0)>MAX_BYTES)throw Error('Bridge response exceeds budget');
                    let document;
                    if(response.body?.getReader){
                        const reader=response.body.getReader(),decoder=new TextDecoder();
                        let body='',bytes=0;
                        try{
                            for(;;){
                                const part=await reader.read();signal.throwIfAborted?.();
                                if(part.done)break;
                                bytes+=part.value.byteLength;
                                if(bytes>MAX_BYTES){await reader.cancel();throw Error('Bridge response exceeds budget');}
                                body+=decoder.decode(part.value,{stream:true});
                            }
                            body+=decoder.decode();document=JSON.parse(body);
                        }finally{reader.releaseLock?.();}
                    }else if(typeof response.text==='function'){
                        const body=await response.text();
                        if(body.length>MAX_BYTES)throw Error('Bridge response exceeds budget');
                        document=JSON.parse(body);
                    }else{
                        document=await response.json();
                        if(JSON.stringify(document).length>MAX_BYTES)throw Error('Bridge response exceeds budget');
                    }
                    signal.throwIfAborted?.();
                    const data=parseBridgeData(document);
                    cache={center:{...center},time:now(),data};retryAt=-Infinity;return data;
                }catch(err){failure=err;if(signal.aborted)throw err;}
                finally{clearTimeout(timer);signal.removeEventListener('abort',cancel);}
            }
            throw failure||Error('Bridge data unavailable');
        }
        function exclusions(){
            const selected=getDeckTileset?.(),excluded=[],collection=scene.primitives;
            if(selected){
                for(let i=0;i<(collection?.length||0);i++){
                    const p=typeof collection.get==='function'?collection.get(i):collection[i];
                    if(p&&p!==selected)excluded.push(p);
                }
            }
            if(primitive&&!excluded.includes(primitive))excluded.push(primitive);
            return excluded;
        }
        function draw(next){
            if(!next.length){clear();return;}
            const signature=JSON.stringify([opacity,next.map(p=>[p.id,p.longitude,p.latitude,p.bottom,p.top,p.radius])]);
            if(primitive&&signature===drawSignature){supports=next;credits(true);return;}
            if(!C.CylinderGeometry||!C.GeometryInstance||!C.Primitive||!C.Transforms?.eastNorthUpToFixedFrame||
                !C.PerInstanceColorAppearance||!C.ColorGeometryInstanceAttribute)return;
            const color=C.Color.fromBytes(137,139,133,Math.round(opacity*255));
            const instances=next.map(p=>new C.GeometryInstance({id:p.id,
                geometry:new C.CylinderGeometry({length:p.top-p.bottom,topRadius:p.radius,bottomRadius:p.radius,
                    slices:12,vertexFormat:C.PerInstanceColorAppearance.VERTEX_FORMAT}),
                modelMatrix:C.Transforms.eastNorthUpToFixedFrame(C.Cartesian3.fromDegrees(p.longitude,p.latitude,(p.top+p.bottom)/2)),
                attributes:{color:C.ColorGeometryInstanceAttribute.fromColor(color)}}));
            const nextPrimitive=new C.Primitive({geometryInstances:instances,asynchronous:false,
                appearance:new C.PerInstanceColorAppearance({closed:true,translucent:opacity<1}),
                shadows:C.ShadowMode?.DISABLED});
            scene.primitives.add(nextPrimitive);
            if(primitive)scene.primitives.remove(primitive);
            primitive=nextPrimitive;supports=next;drawSignature=signature;credits(true);scene.requestRender?.();
        }
        async function deckSamples(candidates,excluded,signal){
            const groups=candidates.map(()=>[]);
            for(let i=0;i<candidates.length;i++){
                const p=candidates[i];
                // Discovery has already classified and sampled these heights
                // against the selected native tileset. Re-picking every pier's
                // three neighbours would repeat up to 384 GPU passes in quality.
                if(p.profileMethod==='loaded-native-road'&&finite(p.deckMetersWgs84))continue;
                for(const q of p.probes){
                    if(!scene.sampleHeight){groups[i].push(null);continue;}
                    await yieldBatch(signal);signal.throwIfAborted?.();
                    if(disposed||!enabled||!ready())return groups;
                    try{groups[i].push(scene.sampleHeight(C.Cartographic.fromDegrees(q.longitude,q.latitude),excluded,.7));}
                    catch(_){groups[i].push(null);}
                }
            }
            const missing=[];
            for(let i=0;i<candidates.length;i++)if(!finite(candidates[i].deckMetersWgs84)&&
                !finite(candidates[i].heightMeters)&&groups[i].some(value=>!finite(value)))missing.push(i);
            if(missing.length&&scene.sampleHeightMostDetailed&&(!getDeckTileset||getDeckTileset())){
                // Cesium's most-detailed sampler also performs picking. Keep
                // each request to one pier instead of a scene-wide GPU burst.
                const deadline=Date.now()+8000;
                for(const i of missing){
                    await yieldBatch(signal);signal.throwIfAborted?.();
                    if(disposed||!enabled||!ready()||Date.now()>=deadline)break;
                    let timer,abort;
                    try{
                        const positions=candidates[i].probes.map(q=>C.Cartographic.fromDegrees(q.longitude,q.latitude));
                        const sampled=await Promise.race([
                            scene.sampleHeightMostDetailed(positions,excluded,.7),
                            new Promise((_,reject)=>{
                                timer=setTimeout(()=>reject(Error('Bridge deck sampling timed out')),Math.max(1,deadline-Date.now()));
                                abort=()=>reject(Error('Bridge deck sampling cancelled'));
                                signal.addEventListener('abort',abort,{once:true});
                            })
                        ]);
                        for(let k=0;k<3;k++)if(finite(sampled?.[k]?.height))groups[i][k]=sampled[k].height;
                    }catch(_){/* explicit source profiles still remain usable */}
                    finally{clearTimeout(timer);if(abort)signal.removeEventListener('abort',abort);}
                }
            }
            return groups;
        }
        function refineMappedPositions(center,signal){
            if(sourceQuery||cachedOnly||!isOnline()||now()<retryAt||
                (cache&&distance(center,cache.center)<250&&now()-cache.time<300000))return;
            sourceQuery=fetchRoutes(center,signal).then(()=>{
                if(!disposed&&enabled&&!signal.aborted){lastRefreshAt=-Infinity;void refresh(lastCenter||center);}
            }).catch(()=>{if(!signal.aborted)retryAt=now()+30000;}).finally(()=>{sourceQuery=null;});
        }
        function refresh(center=focus()){
            if(disposed||!enabled)return Promise.resolve(status());
            if(!ready()){++revision;controller?.abort();pending=null;pendingCenter=null;clear();return Promise.resolve(status());}
            if(!valid(center))return Promise.resolve(status());
            if(pending&&pendingCenter&&distance(center,pendingCenter)<120)return pending;
            if(supports.length&&lastCenter&&distance(center,lastCenter)<80&&now()-lastRefreshAt<1500)
                return Promise.resolve(status());
            const token=++revision;controller?.abort();controller=new AbortController();
            const signal=controller.signal;pendingCenter={...center};lastRefreshAt=now();lastCenter={...center};
            const operation=(async()=>{
                try{
                    const local={bridges:[],piers:[]};
                    for(const data of sourceSets.values()){
                        local.bridges.push(...data.bridges);local.piers.push(...data.piers);
                    }
                    let native={bridges:[],piers:[]},remote={bridges:[],piers:[]};
                    if(structuresEnabled&&discoverBridges&&(!getDeckTileset||getDeckTileset())){
                        try{native=await discoverBridges(center,signal)||native;}
                        catch(err){if(signal.aborted)throw err;}
                    }
                    signal.throwIfAborted?.();
                    if(token!==revision||disposed||!enabled)return status();
                    const available=stations([...native.bridges,...local.bridges],center,BUDGETS[profile],
                        [...native.piers,...local.piers]);
                    // Local OSINT profiles work offline and are never held up
                    // by an optional public-service request or its backoff.
                    // A source entry elsewhere in Switzerland must not prevent
                    // discovery of bridges in the current camera area.
                    if(!available.length&&structuresEnabled&&
                        (!getDeckTileset||getDeckTileset())&&now()>=retryAt){
                        remote=await fetchRoutes(center,signal);
                    }else if(cache&&distance(center,cache.center)<250)remote=cache.data;
                    if(token!==revision||disposed||!enabled)return status();
                    const candidates=stations([...native.bridges,...local.bridges,...remote.bridges],center,BUDGETS[profile],
                        [...native.piers,...local.piers,...remote.piers]);
                    if(!candidates.length){clear();return status();}
                    const ground=await sampleTerrain(candidates.map(p=>({longitude:p.longitude,latitude:p.latitude})),signal);
                    signal.throwIfAborted?.();
                    if(token!==revision||disposed||!enabled)return status();
                    if(!ready()){clear();return status();}
                    const excluded=exclusions();
                    // A missing production tileset cannot justify sampling
                    // arbitrary building roofs for an OSINT source profile.
                    const canProbe=!getDeckTileset||!!getDeckTileset();
                    const sampled=canProbe?await deckSamples(candidates,excluded,signal):candidates.map(()=>[]);
                    const next=[];
                    for(let i=0;i<candidates.length;i++){
                        const p=candidates[i],base=ground?.[i],heights=sampled[i];
                        if(!finite(base)||base< -500||base>9000)continue;
                        const coherent=heights.length===3&&heights.every(finite)&&Math.max(...heights)-Math.min(...heights)<=2.8;
                        let deck=coherent&&heights[1]-base>=2.5?heights[1]:null;
                        let heightMethod='loaded-deck';
                        if(!finite(deck)&&finite(p.deckMetersWgs84)){
                            deck=p.deckMetersWgs84;heightMethod=p.profileMethod==='loaded-native-road'?
                                'loaded-native-deck':'source-profile-estimate';
                        }
                        if(!finite(deck)&&finite(p.heightMeters)){
                            deck=base+p.heightMeters;heightMethod='mapped-height-estimate';
                        }
                        const gap=deck-base;
                        if(!finite(deck)||gap<2.5||gap>150)continue;
                        next.push({id:p.id,sourceId:p.sourceId,source:p.source||'OpenStreetMap',
                            positionSource:p.positionSource||p.source||'OpenStreetMap',mapped:!!p.mapped,heightMethod,
                            longitude:p.longitude,latitude:p.latitude,bottom:base-.3,top:deck-.1,
                            radius:p.radius||(gap>45?1:.7),quality:'simulation-only'});
                    }
                    if(token!==revision||disposed||!enabled)return status();
                    if(!ready()){clear();return status();}
                    draw(next.slice(0,BUDGETS[profile]));error=null;
                    if(native.bridges.length||local.bridges.length||local.piers.length)refineMappedPositions(center,signal);
                    return status();
                }catch(err){
                    if(token===revision&&!signal.aborted){error=String(err?.message||err).slice(0,160);
                        retryAt=now()+30000;if(!ready())clear();}
                    return status();
                }finally{if(token===revision){pending=null;pendingCenter=null;}}
            })();
            pending=operation;return operation;
        }
        const removeFrame=scene.preUpdate?.addEventListener?.(()=>{
            if(disposed||!enabled)return;
            if(!ready()){if(supports.length||pending){++revision;controller?.abort();pending=null;clear();}return;}
            if(now()-lastFrameAt<2000)return;lastFrameAt=now();
            const center=focus();
            if(center&&(!lastCenter||distance(center,lastCenter)>120||!supports.length||now()-lastRefreshAt>15000))void refresh(center);
        });
        function updateEnabled(){
            enabled=structuresEnabled||sourceSets.size>0;
            if(!enabled){++revision;controller?.abort();pending=null;pendingCenter=null;clear();}
        }
        function setEnabled(value){
            if(typeof value!=='boolean')throw Error('Invalid bridge support preference');
            if(disposed||structuresEnabled===value)return {enabled:enabled&&!disposed,count:supports.length,pending:!!pending};
            structuresEnabled=value;updateEnabled();return status();
        }
        function setSourceFeatures(features,{sourceId='osint',visible=true,...options}={}){
            if(disposed)return status();
            const data=visible?parseSourceFeatures(features,{...options,sourceId}):{bridges:[],piers:[]};
            const signature=JSON.stringify(data),previous=sourceSets.get(sourceId);
            if(previous&&JSON.stringify(previous)===signature)return status();
            if(data.bridges.length||data.piers.length)sourceSets.set(sourceId,data);
            else sourceSets.delete(sourceId);
            ++revision;controller?.abort();pending=null;pendingCenter=null;retryAt=-Infinity;lastRefreshAt=-Infinity;
            clear();updateEnabled();
            if(enabled)void refresh();
            return status();
        }
        function performance(value='balanced'){
            if(!Object.hasOwn(BUDGETS,value))throw Error('Unknown bridge graphics profile');
            if(profile===value||disposed)return;profile=value;lastRefreshAt=-Infinity;
            if(supports.length>BUDGETS[profile])draw(supports.slice(0,BUDGETS[profile]));
            if(enabled)void refresh();
        }
        function setOpacity(value){
            if(!finite(value)||value<.2||value>1)throw Error('Invalid bridge support opacity');
            if(opacity===value||disposed)return;opacity=value;if(supports.length)draw(supports);
        }
        return {setEnabled,setSourceFeatures,refresh,performance,setOpacity,status,
            dispose(){if(disposed)return;disposed=true;enabled=false;++revision;controller?.abort();pending=null;
                removeFrame?.();clear();cache=null;sourceSets.clear();disposeDiscovery();}};
    }
    return {create,parseBridges,parseBridgeData,parseSourceFeatures,stations,BUDGETS};
});
