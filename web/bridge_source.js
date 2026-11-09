/* Bridge discovery from the official road axis and the actual loaded 3D model.
 * The axis has no elevation or bridge classification. Both are established by
 * picking the selected swissTLM3D tileset, never by a road's name or colour. */
(function(root,factory){
    const api=factory();
    if(typeof module==='object'&&module.exports)module.exports=api;
    else root.FPVBridgeSource=api;
})(typeof globalThis!=='undefined'?globalThis:this,function(){
    'use strict';
    const DEG=Math.PI/180,R=6378137,RADIUS=600,MAX_BYTES=2*1024*1024;
    const ENDPOINT='https://api3.geo.admin.ch/rest/services/api/MapServer/identify';
    const SOURCE='ch.swisstopo.swisstlm3d.3d';
    // swissTLM3D object catalogue, TLM_STRASSE_KUNSTBAUTE_CD:
    // bridge, bridge with gallery, covered bridge, bridge with steps, footbridge.
    const BRIDGE_CODES=new Set([200,300,400,450,600]);
    const finite=Number.isFinite;
    const valid=p=>p&&finite(p.longitude)&&finite(p.latitude)&&p.longitude>=5.8&&p.longitude<=10.7&&
        p.latitude>=45.6&&p.latitude<=47.9;
    const distance=(a,b)=>Math.hypot((a.longitude-b.longitude)*DEG*R*Math.cos((a.latitude+b.latitude)*DEG/2),
        (a.latitude-b.latitude)*DEG*R);
    function urlFor(center){
        if(!valid(center))throw Error('Invalid Swiss bridge search position');
        const dy=RADIUS/(R*DEG),dx=dy/Math.cos(center.latitude*DEG);
        const box=[center.longitude-dx,center.latitude-dy,center.longitude+dx,center.latitude+dy].join(',');
        return `${ENDPOINT}?${new URLSearchParams({limit:'200',geometryType:'esriGeometryEnvelope',geometry:box,
            mapExtent:box,imageDisplay:'512,512,96',tolerance:'0',sr:'4326',geometryFormat:'geojson',
            returnGeometry:'true',layers:'all:ch.swisstopo.swisstlm3d-strassen'})}`;
    }
    function parseIdentify(document){
        if(!document||!Array.isArray(document.results)||document.results.length>200)
            throw Error('Invalid official bridge road response');
        const routes=[];let vertices=0;
        for(const [index,feature] of document.results.entries()){
            const geometry=feature?.geometry;
            const lines=geometry?.type==='LineString'?[geometry.coordinates]:
                geometry?.type==='MultiLineString'?geometry.coordinates:[];
            if(!Array.isArray(lines))continue;
            for(const [part,line] of lines.slice(0,16).entries()){
                if(!Array.isArray(line)||line.length<2||line.length>512||vertices+line.length>8192)continue;
                const coordinates=line.map(p=>({longitude:p?.[0],latitude:p?.[1]}));
                if(!coordinates.every(valid))continue;
                vertices+=line.length;
                routes.push({id:`swisstopo-native:${feature.featureId??feature.id??index}:${part}`,
                    sourceId:String(feature.featureId??feature.id??index),coordinates});
            }
        }
        return routes;
    }
    function lineTools(line){
        const cumulative=[0];
        for(let i=1;i<line.length;i++)cumulative.push(cumulative.at(-1)+distance(line[i-1],line[i]));
        const total=cumulative.at(-1);
        const at=along=>{
            let i=0;while(i<line.length-2&&cumulative[i+1]<along)i++;
            const t=Math.max(0,Math.min(1,(along-cumulative[i])/(cumulative[i+1]-cumulative[i]||1)));
            return {longitude:line[i].longitude+(line[i+1].longitude-line[i].longitude)*t,
                latitude:line[i].latitude+(line[i+1].latitude-line[i].latitude)*t};
        };
        const nearest=center=>{
            let best={gap:Infinity,along:0};
            for(let i=1;i<line.length;i++){
                const a=line[i-1],b=line[i],scale=R*DEG*Math.cos(center.latitude*DEG);
                const dx=(b.longitude-a.longitude)*scale,dy=(b.latitude-a.latitude)*R*DEG,
                    px=(center.longitude-a.longitude)*scale,py=(center.latitude-a.latitude)*R*DEG,
                    t=Math.max(0,Math.min(1,(px*dx+py*dy)/(dx*dx+dy*dy||1))),gap=Math.hypot(px-t*dx,py-t*dy);
                if(gap<best.gap)best={gap,along:cumulative[i-1]+t*(cumulative[i]-cumulative[i-1])};
            }
            return best;
        };
        return {total,at,nearest};
    }
    async function limitedJson(response,signal){
        if(!response?.ok)throw Error(`Official bridge roads unavailable (${response?.status||'network'})`);
        if(Number(response.headers?.get?.('content-length')||0)>MAX_BYTES)throw Error('Official bridge response exceeds budget');
        if(response.body?.getReader){
            const reader=response.body.getReader(),decoder=new TextDecoder();let body='',bytes=0;
            try{
                for(;;){
                    const part=await reader.read();signal?.throwIfAborted?.();
                    if(part.done)break;
                    bytes+=part.value.byteLength;
                    if(bytes>MAX_BYTES){await reader.cancel();throw Error('Official bridge response exceeds budget');}
                    body+=decoder.decode(part.value,{stream:true});
                }
                return JSON.parse(body+decoder.decode());
            }finally{reader.releaseLock?.();}
        }
        if(response.text){const body=await response.text();if(body.length>MAX_BYTES)throw Error('Official bridge response exceeds budget');
            return JSON.parse(body);}
        const document=await response.json();
        if(JSON.stringify(document).length>MAX_BYTES)throw Error('Official bridge response exceeds budget');
        return document;
    }
    function create(C,viewer,{getDeckTileset,fetcher=(...args)=>fetch(...args),cachedOnly=false,
        isOnline=()=>globalThis.navigator?.onLine!==false,now=()=>Date.now(),
        yieldBatch=()=>new Promise(resolve=>setTimeout(resolve,0))}={}){
        const scene=viewer.scene;let disposed=false,cache=null,nativeCache=null,pending=null,controller=null,retryAt=-Infinity;
        function exclusions(selected){
            const result=[],collection=scene.primitives;
            for(let i=0;i<(collection?.length||0);i++){
                const primitive=collection.get?collection.get(i):collection[i];
                if(primitive&&primitive!==selected)result.push(primitive);
            }
            return result;
        }
        function pick(point,selected,excluded){
            if(disposed||getDeckTileset?.()!==selected||selected?.show===false)return null;
            try{
                const lon=point.longitude*DEG,lat=point.latitude*DEG;
                const ray=new C.Ray(C.Cartesian3.fromDegrees(point.longitude,point.latitude,6000),
                    new C.Cartesian3(-Math.cos(lat)*Math.cos(lon),-Math.cos(lat)*Math.sin(lon),-Math.sin(lat)));
                const hit=scene.pickFromRay(ray,excluded,.7),feature=hit?.object;
                if(!feature?.getProperty||feature.tileset&&feature.tileset!==selected)return null;
                const code=feature.getProperty('KUNSTBAUTE')??feature.getProperty('kunstbaute');
                if(!BRIDGE_CODES.has(Number(code)))return null;
                const position=hit.position&&C.Cartographic.fromCartesian(hit.position);
                if(!finite(position?.height)||position.height< -500||position.height>5500)return null;
                const uuid=feature.getProperty('UUID'),objectId=feature.getProperty('OBJECTID');
                return {...point,height:position.height,nativeId:String(uuid??objectId??''),
                    name:String(feature.getProperty('NAME')||'Bridge').slice(0,120),code:Number(code)};
            }catch(_){return null;}
        }
        async function roads(center,signal){
            if(cache&&distance(center,cache.center)<250&&now()-cache.time<300000)return cache.routes;
            if(cachedOnly||!isOnline())return [];
            if(now()<retryAt)return cache&&distance(center,cache.center)<250?cache.routes:[];
            const timeout=new AbortController(),cancel=()=>timeout.abort();
            signal?.addEventListener('abort',cancel,{once:true});
            const timer=setTimeout(()=>timeout.abort(),8000);
            try{
                const response=await fetcher(urlFor(center),{signal:timeout.signal,credentials:'omit'});
                const routes=parseIdentify(await limitedJson(response,signal));signal?.throwIfAborted?.();
                if(disposed)return [];
                cache={center:{...center},time:now(),routes};retryAt=-Infinity;return routes;
            }catch(error){
                if(!signal?.aborted)retryAt=now()+30000;
                throw error;
            }finally{clearTimeout(timer);signal?.removeEventListener('abort',cancel);}
        }
        async function run(center,signal){
            const selected=getDeckTileset?.();
            if(disposed||!valid(center)||!selected||selected.show===false||!scene.pickFromRay||!C.Ray)
                return {bridges:[],piers:[]};
            if(nativeCache?.selected===selected&&distance(center,nativeCache.center)<80&&
                now()-nativeCache.time<(nativeCache.result.bridges.length?30000:2000))return nativeCache.result;
            const routes=await roads(center,signal),excluded=exclusions(selected),bridges=[];
            // A caller may start discovery from preUpdate. Cesium ray picking
            // renders an offscreen pass and must run after that frame unwinds.
            await yieldBatch();signal?.throwIfAborted?.();
            const candidates=routes.map(route=>{const tools=lineTools(route.coordinates);return {route,tools,near:tools.nearest(center)};})
                .filter(p=>p.near.gap<=RADIUS+100&&p.tools.total>=24&&p.tools.total<=20000)
                .sort((a,b)=>a.near.gap-b.near.gap).slice(0,32);
            let probes=0;
            const probe=async point=>{
                signal?.throwIfAborted?.();
                if(++probes>96)return null;
                const result=pick(point,selected,excluded);
                if(probes%4===0)await yieldBatch();
                signal?.throwIfAborted?.();
                return result;
            };
            for(const {route,tools,near} of candidates){
                if(disposed||getDeckTileset?.()!==selected||probes>=96)break;
                let anchor=null;
                for(const offset of [0,-48,48,-120,120]){
                    if(probes>=96)break;
                    const point=tools.at(Math.max(0,Math.min(tools.total,near.along+offset)));
                    if(distance(point,center)>RADIUS+100)continue;
                    anchor=await probe(point);if(anchor)break;
                }
                if(!anchor)continue;
                // Only matching, contiguous native bridge features form a
                // profile. Crossing roads cannot inherit a bridge's height.
                const lower=Math.max(0,near.along-1400),upper=Math.min(tools.total,near.along+1400);
                const steps=Math.ceil((upper-lower)/24),chunks=[];let chunk=[];
                const flush=()=>{if(chunk.length>=2&&distance(chunk[0],chunk.at(-1))>=24)chunks.push(chunk);chunk=[];};
                for(let i=0;i<=steps&&probes<96;i++){
                    const point=tools.at(lower+(upper-lower)*i/steps);
                    if(distance(point,center)>RADIUS+100){flush();continue;}
                    const hit=await probe(point);
                    if(!hit||anchor.nativeId&&hit.nativeId!==anchor.nativeId){flush();continue;}
                    chunk.push(hit);
                }
                flush();
                for(const [part,coordinates] of chunks.entries())bridges.push({
                    id:`${route.id}:${part}`,sourceId:anchor.nativeId||route.sourceId,source:SOURCE,
                    name:anchor.name,coordinates:coordinates.map(({longitude,latitude,height})=>({longitude,latitude,height})),
                    mappedOnly:false,profileMethod:'loaded-native-road',nativeClass:anchor.code});
                if(bridges.length>=16)break;
            }
            signal?.throwIfAborted?.();
            const result={bridges:!disposed&&getDeckTileset?.()===selected&&selected.show!==false?bridges.slice(0,16):[],piers:[]};
            if(!disposed)nativeCache={center:{...center},selected,time:now(),result};
            return result;
        }
        function discover(center,signal){
            if(disposed||!valid(center))return Promise.resolve({bridges:[],piers:[]});
            if(pending&&distance(center,pending.center)<120&&!pending.signal.aborted)return pending.promise;
            controller?.abort();controller=new AbortController();
            const current=controller,cancel=()=>current.abort();
            signal?.addEventListener('abort',cancel,{once:true});if(signal?.aborted)current.abort();
            const operation=run(center,current.signal).finally(()=>{
                signal?.removeEventListener('abort',cancel);if(pending?.promise===operation)pending=null;
            });
            pending={center:{...center},signal:current.signal,promise:operation};return operation;
        }
        return {discover,dispose(){disposed=true;controller?.abort();pending=null;cache=null;nativeCache=null;}};
    }
    return {create,parseIdentify,urlFor,BRIDGE_CODES};
});
