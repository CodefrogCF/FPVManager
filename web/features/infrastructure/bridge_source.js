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
    const afterFrame=signal=>new Promise(resolve=>{
        // Offscreen picks can synchronously wait for the GPU. Let a visible
        // frame finish before each one rather than chaining zero-delay tasks.
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
    function createPickBudget({now=()=>globalThis.performance?.now?.()??Date.now(),mobile=false,
        active=()=>true,hasGeometry=()=>true,frameMs=()=>16.7}={}){
        let next=0,average=0;
        return {record(cost){
            if(!active()||!hasGeometry()){next=0;return;}
            average=average?average*.75+cost*.25:cost;
            // Bound recovery to avoid starvation. More expensive picks and
            // slow frames leave more time for ordinary visible rendering.
            const recovery=Math.min(120,Math.max(0,average*(mobile?2:1)-8,
                Math.min(60,Math.max(0,frameMs()-16.7))));
            next=now()+recovery;
        },async wait(signal){
            signal?.throwIfAborted?.();if(!active()||!hasGeometry())return 0;
            const start=now(),delay=Math.min(120,Math.max(0,next-start));
            if(delay>0)await new Promise(resolve=>{
                const finish=()=>{clearTimeout(timer);signal?.removeEventListener('abort',finish);resolve();};
                const timer=setTimeout(finish,delay);signal?.addEventListener('abort',finish,{once:true});if(signal?.aborted)finish();
            });
            signal?.throwIfAborted?.();return Math.max(0,now()-start);
        }};
    }
    function create(C,viewer,{getDeckTileset,fetcher=(...args)=>fetch(...args),cachedOnly=false,
        isOnline=()=>globalThis.navigator?.onLine!==false,now=()=>Date.now(),
        yieldBatch=afterFrame,isNavigationActive=()=>false,mobile=false,incremental=false,prefetchRoads=incremental,lookahead=()=>[],sessionReuse=false,pickBudget=null}={}){
        const scene=viewer.scene;let disposed=false,cache=null,nativeCache=null,pending=null,controller=null,retryAt=-Infinity;
        // Positive classifications are tied to the current source tileset, not
        // its camera-dependent selected LOD. Never persist to disk.
        const probeCache=new Map(),negativeCache=new Map(),PROBE_LIMIT=4096,PROBE_TTL=120000;
        let probeSource=null,metrics=null,epoch=0,firstProfilePublished=false;
        // Session-local source-axis index. Positions are independent of the
        // camera and native tile LOD. Only contiguous same-ID hits form spans.
        const axes=new Map(),AXIS_LIMIT=96,POINT_LIMIT=4096,VALID_MS=600000,RECHECK_MS=120000;
        const roadAreas=[],invalidatedIndex=new Set();
        let prefetchController=null;
        function resetIndex(){axes.clear();invalidatedIndex.clear();prefetchController?.abort();prefetchController=null;}
        function axisKey(route){return JSON.stringify([route.id,route.coordinates]);}
        function markInvalid(id){invalidatedIndex.add(id);while(invalidatedIndex.size>POINT_LIMIT)invalidatedIndex.delete(invalidatedIndex.values().next().value);}
        function spanKey(route,along,point){return `${route.id}:${along.toFixed(3)}:${point.longitude}:${point.latitude}`;}
        function priority(point,center,ahead){return Math.min(distance(point,center),...ahead.map(p=>distance(point,p)+40));}
        function pruneIndex(center){
            if(axes.size>AXIS_LIMIT){
                const distant=[...axes].map(([key,a])=>({key,gap:a.tools.nearest(center).gap})).sort((a,b)=>b.gap-a.gap);
                for(const a of distant.slice(0,axes.size-AXIS_LIMIT))axes.delete(a.key);
            }
            const count=[...axes.values()].reduce((n,a)=>n+a.points.size,0);
            if(count>POINT_LIMIT){
                const entries=[...axes.values()].flatMap(a=>[...a.points].map(([k,v])=>({a,k,v})));
                entries.sort((a,b)=>a.v.at-b.v.at);
                for(const {a,k} of entries.slice(0,count-POINT_LIMIT))a.points.delete(k);
            }
        }
        function invalidate(){probeCache.clear();negativeCache.clear();nativeCache=null;probeSource=null;firstProfilePublished=false;resetIndex();epoch++;controller?.abort();pending=null;}
        function setDiagnosticsEnabled(value){if(value)metrics??={nativePicks:0,nativePickMs:0,nativeHits:0,nativeMisses:0,nativeDeferred:0,nativeCooldownFrames:0,nativeProfileHits:0,nativeIndexedHits:0,nativeNegativeHits:0,nativeUnknownHits:0,nativeIndexedMisses:0,nativeIndexedDeferred:0,nativeHeightRejected:0,nativeRechecks:0,nativeSections:0,nativeSessionHits:0,nativeSessionCommitted:0,nativeClassifiedRoadHits:0,nativeAdaptiveWaitMs:0,nativeEarlyProfiles:0,nativeEdgeDeferred:0};else metrics=null;}
        function diagnostics(){return metrics?{...metrics,nativeCacheEntries:probeCache.size,nativeRoadCacheEntries:negativeCache.size,nativeIndexedAxes:axes.size,nativeIndexedPoints:[...axes.values()].reduce((n,a)=>n+a.points.size,0)}:null;}
        function exclusions(selected){
            const result=[],collection=scene.primitives;
            for(let i=0;i<(collection?.length||0);i++){
                const primitive=collection.get?collection.get(i):collection[i];
                if(primitive&&primitive!==selected)result.push(primitive);
            }
            return result;
        }
        function pick(point,selected,excluded,classify=false){
            if(disposed||getDeckTileset?.()!==selected||selected?.show===false)return null;
            try{
                const lon=point.longitude*DEG,lat=point.latitude*DEG;
                const ray=new C.Ray(C.Cartesian3.fromDegrees(point.longitude,point.latitude,6000),
                    new C.Cartesian3(-Math.cos(lat)*Math.cos(lon),-Math.cos(lat)*Math.sin(lon),-Math.sin(lat)));
                const hit=scene.pickFromRay(ray,excluded,.7),feature=hit?.object;
                if(!feature?.getProperty||(feature.tileset??feature.content?.tileset)!==selected)return null;
                const code=feature.getProperty('KUNSTBAUTE')??feature.getProperty('kunstbaute');
                if(!BRIDGE_CODES.has(Number(code)))return classify&&code!=null&&code!==''&&finite(Number(code))?{nonBridge:true}:null;
                const position=hit.position&&C.Cartographic.fromCartesian(hit.position);
                if(!finite(position?.height)||position.height< -500||position.height>5500)return null;
                const uuid=feature.getProperty('UUID'),objectId=feature.getProperty('OBJECTID');
                return {...point,height:position.height,nativeId:String(uuid??objectId??''),
                    name:String(feature.getProperty('NAME')||'Bridge').slice(0,120),code:Number(code)};
            }catch(_){return null;}
        }
        async function roads(center,signal){
            signal?.throwIfAborted?.();
            if(prefetchRoads){
                const found=roadAreas.find(a=>distance(center,a.center)<250&&now()-a.time<300000);
                if(found)return found.routes;
            }
            if(cache&&distance(center,cache.center)<250&&now()-cache.time<300000)return cache.routes;
            if(cachedOnly||!isOnline())return [];
            if(now()<retryAt)return cache&&distance(center,cache.center)<250?cache.routes:[];
            const generation=epoch,timeout=new AbortController(),cancel=()=>timeout.abort();
            signal?.addEventListener('abort',cancel,{once:true});
            const timer=setTimeout(()=>timeout.abort(),8000);
            try{
                const response=await fetcher(urlFor(center),{signal:timeout.signal,credentials:'omit'});
                const routes=parseIdentify(await limitedJson(response,signal));signal?.throwIfAborted?.();
                if(disposed||generation!==epoch)return [];
                cache={center:{...center},time:now(),routes};
                if(prefetchRoads){roadAreas.push(cache);if(roadAreas.length>8)roadAreas.shift();}
                retryAt=-Infinity;return routes;
            }catch(error){
                if(!signal?.aborted)retryAt=now()+30000;
                throw error;
            }finally{clearTimeout(timer);signal?.removeEventListener('abort',cancel);}
        }
        async function runIndexed(center,signal,selected){
            const generation=epoch,flight=isNavigationActive();
            const ahead=(lookahead()||[]).filter(p=>valid(p)&&distance(p,center)<=RADIUS).slice(0,3);
            const ensure=()=>{signal?.throwIfAborted?.();if(disposed||epoch!==generation||getDeckTileset?.()!==selected||selected.show===false)throw Error('Bridge source changed');};
            // Keep source-axis geometry across overlapping search windows; a
            // changed axis with the same ID invalidates its old observations.
            let routes=[];
            try{routes=await roads(center,signal);}catch(err){ensure();if(!axes.size)throw err;}
            ensure();
            for(const route of routes){
                const key=axisKey(route);
                if(axes.has(key))continue;
                for(const [old,a] of axes)if(a.route.id===route.id){
                    for(const [along,record] of a.points)if(record.value)markInvalid(`${spanKey(a.route,along,record.value)}:1`);
                    axes.delete(old);
                }
                const tools=lineTools(route.coordinates);
                if(tools.total>=24&&tools.total<=20000)axes.set(key,{route,tools,points:new Map()});
            }
            pruneIndex(center);
            const jobs=[],invalidatedSections=invalidatedIndex;
            for(const a of axes.values()){
                const near=a.tools.nearest(center);
                if(near.gap>RADIUS+100)continue;
                const lower=Math.max(0,near.along-1400),upper=Math.min(a.tools.total,near.along+1400);
                const grid=[...new Set([...(lower===0?[0]:[]),...Array.from({length:Math.max(0,Math.floor(upper/24)-Math.ceil(lower/24)+1)},(_,i)=>(Math.ceil(lower/24)+i)*24),...(upper===a.tools.total?[upper]:[])])].sort((a,b)=>a-b);
                for(const along of grid){
                    const point=a.tools.at(along);if(distance(point,center)>RADIUS+100)continue;
                    const old=a.points.get(along),age=old?now()-old.at:Infinity;
                    // Failed/unloaded picks are retryable, never valid heights.
                    // Successful source observations get sparse revalidation.
                    const retry=old?.suspect?2000:old?.value?RECHECK_MS:old?.nonBridge?60000:old?.attempted?Math.min(48000,6000*2**Math.min(3,old.attempted)):0;
                    if(old&&age<retry){if(metrics){if(old.value)metrics.nativeIndexedHits++;
                        else if(old.nonBridge)metrics.nativeNegativeHits++;else metrics.nativeUnknownHits++;}continue;}
                    const attempted=old?.attempted??0;
                    const neighbour=[along-24,along+24].some(k=>a.points.get(k)?.value);
                    jobs.push({a,along,point,old,rank:priority(point,center,ahead)+(old?.value?2000:attempted?800:0)-(neighbour?350:0)+(!neighbour&&Math.round(along/24)%2?200:0),attempted});
                }
            }
            jobs.sort((a,b)=>a.rank-b.rank);
            // Bounded new work per pass. No extra waits after each pick: the
            // next pass continues with unattempted positions rather than
            // starting over. Reserve part of the budget for stale positives.
            const budget=flight?(mobile?32:48):96;
            const rechecks=jobs.filter(j=>j.old?.value||j.old?.suspect).slice(0,Math.max(1,Math.floor(budget/8)));
            const queue=[...rechecks,...jobs.filter(j=>!rechecks.includes(j))];
            const limit=Math.min(queue.length,budget);
            if(metrics)metrics.nativeIndexedDeferred+=Math.max(0,jobs.length-limit);
            if(limit)await yieldBatch(signal);ensure();
            for(let picked=0;picked<limit;picked++){
                const j=queue.shift();
                ensure();const d=metrics,start=now();if(d){d.nativePicks++;d.nativeMisses++;d.nativeIndexedMisses++;if(j.old?.value)d.nativeRechecks++;}
                const observation=pick(j.point,selected,exclusions(selected),true),result=observation?.nonBridge?null:observation;
                if(d)d.nativePickMs+=Math.max(0,now()-start);
                const previous=j.old?.value??j.old?.reference,instant=now();
                let value=result?.nativeId?result:null,observedAt=instant,suspect=!result?j.old?.suspect??null:null;
                if(previous&&value&&previous.nativeId===value.nativeId&&Math.abs(value.height-previous.height)>.75){
                    // A new elevation needs independent agreement. Do not
                    // extend the old observation's validity on a mismatch.
                    if(j.old.suspect&&instant-j.old.at<=RECHECK_MS&&Math.abs(j.old.suspect.height-value.height)<=.25&&j.old.suspect.nativeId===value.nativeId){
                        suspect=null;
                    }else{suspect=value;value=null;if(d)d.nativeHeightRejected++;}
                }
                if(!value&&!result&&j.old?.value&&previous&&instant-(j.old.observedAt??j.old.at)<VALID_MS){
                    // A missing tile is not contradictory evidence.
                    value=previous;observedAt=j.old.observedAt??j.old.at;
                }
                // A conflicting source ID is not a valid continuation of
                // the old span; only new same-ID neighbours can form a span.
                if(previous&&result&&(!value||previous.nativeId!==value.nativeId)){
                    for(const from of [j.along-24,j.along])if(from>=0)
                        markInvalid(`${spanKey(j.a.route,from,j.a.tools.at(from))}:1`);
                }
                j.a.points.set(j.along,{value,at:instant,observedAt,attempted:j.attempted+1,suspect,
                    reference:suspect?previous:null,nonBridge:observation?.nonBridge===true});
                // A positive anchor immediately promotes its unmeasured neighbours,
                // so sparse initial searches can yield a usable section within
                // the same bounded pass instead of waiting for another scan.
                if(value){
                    const neighbours=queue.filter(q=>q.a===j.a&&Math.abs(Math.abs(q.along-j.along)-24)<.01);
                    for(const q of neighbours.reverse()){queue.splice(queue.indexOf(q),1);queue.unshift(q);}
                }
                await yieldBatch(signal);ensure();
            }
            pruneIndex(center);
            const bridges=[];
            for(const a of axes.values()){
                const ordered=[...a.points].sort((x,y)=>x[0]-y[0]),outliers=new Set();
                for(let i=1;i<ordered.length-1;i++){
                    const [a0,l]=ordered[i-1],[a1,m]=ordered[i],[a2,r]=ordered[i+1];
                    if(Math.abs(a1-a0-24)>.01||Math.abs(a2-a1-24)>.01||!l.value||!m.value||!r.value||
                        l.value.nativeId!==m.value.nativeId||r.value.nativeId!==m.value.nativeId||
                        [l,m,r].some(v=>now()-v.observedAt>=VALID_MS))continue;
                    if(m.value.height>(l.value.height+r.value.height)/2+1.5){
                        outliers.add(a1);if(metrics)metrics.nativeHeightRejected++;
                        // Recheck this measurement ahead of normal stale points.
                        m.reference=m.value;m.suspect=m.value;m.value=null;m.at=now()-2000;
                        markInvalid(`${spanKey(a.route,a0,l.value)}:1`);
                        markInvalid(`${spanKey(a.route,a1,a.tools.at(a1))}:1`);
                    }
                }
                for(let i=1;i<ordered.length;i++){
                    const [from,l]=ordered[i-1],[to,r]=ordered[i];
                    const left=l.value,right=r.value,span=to-from;
                    if((l.suspect||r.suspect||(left&&now()-l.observedAt>=VALID_MS)||(right&&now()-r.observedAt>=VALID_MS))&&Math.abs(span-24)<.01)markInvalid(`${spanKey(a.route,from,a.tools.at(from))}:1`);
                    if(outliers.has(from)||outliers.has(to)||!left||!right||left.nativeId!==right.nativeId||span<23.99||span>24.01||
                        now()-l.observedAt>=VALID_MS||now()-r.observedAt>=VALID_MS||
                        Math.min(distance(left,center),distance(right,center))>RADIUS+100)continue;
                    // No interpolation across discontinuous decks or steep
                    // mismatched features. A coherent grade is still not a
                    // surveyed underside measurement.
                    if(Math.abs(left.height-right.height)>span*.35+.5){if(metrics)metrics.nativeHeightRejected++;
                        markInvalid(`${spanKey(a.route,from,left)}:1`);continue;}
                    bridges.push({id:spanKey(a.route,from,left),sourceId:left.nativeId,source:SOURCE,
                        name:left.name,coordinates:[left,right].map(({longitude,latitude,height})=>({longitude,latitude,height})),
                        mappedOnly:false,profileMethod:'loaded-native-road',nativeClass:left.code,stableSection:true});
                }
            }
            bridges.sort((a,b)=>priority(a.coordinates[0],center,ahead)-priority(b.coordinates[0],center,ahead));
            if(metrics){metrics.nativeSections=bridges.length;if(!limit&&bridges.length)metrics.nativeProfileHits++;}
            const result={bridges:bridges.slice(0,128),piers:[],invalidatedSections:[...invalidatedSections]};
            invalidatedSections.clear();return result;
        }
        async function run(center,signal){
            const selected=getDeckTileset?.();
            if(disposed||!valid(center)||!selected||selected.show===false||!scene.pickFromRay||!C.Ray)
                return {bridges:[],piers:[]};
            if(probeSource!==selected){probeCache.clear();negativeCache.clear();nativeCache=null;axes.clear();invalidatedIndex.clear();probeSource=selected;firstProfilePublished=false;}
            if(incremental)return runIndexed(center,signal,selected);
            const generation=epoch,flight=isNavigationActive();
            if(nativeCache?.selected===selected&&distance(center,nativeCache.center)<80&&
                now()-nativeCache.time<(nativeCache.result.bridges.length&&!nativeCache.result.partial?30000:2000)){
                if(metrics)metrics.nativeProfileHits++;return nativeCache.result;
            }
            const routes=await roads(center,signal),bridges=[];
            const initial=sessionReuse&&flight&&!firstProfilePublished;
            const ahead=sessionReuse?(lookahead()||[]).filter(p=>valid(p)&&distance(p,center)<=RADIUS).slice(0,3):[];
            // A caller may start discovery from preUpdate. Cesium ray picking
            // renders an offscreen pass and must run after that frame unwinds.
            await yieldBatch(signal);signal?.throwIfAborted?.();
            const candidates=routes.map(route=>{const tools=lineTools(route.coordinates);const near=tools.nearest(center);return {route,tools,near,priority:Math.min(near.gap,...ahead.map(p=>tools.nearest(p).gap+40))};})
                .filter(p=>p.near.gap<=RADIUS+100&&p.tools.total>=24&&p.tools.total<=20000)
                .sort((a,b)=>a.priority-b.priority).slice(0,32);
            let probes=0,visits=0;
            const budget=sessionReuse&&flight&&nativeCache?.result.bridges.length?(mobile?48:64):96;
            const exhausted=()=>probes>=budget||visits>=192;
            const probe=async (point,routeId)=>{
                signal?.throwIfAborted?.();
                if(exhausted())return null;visits++;if(!sessionReuse)probes++;
                if(generation!==epoch||getDeckTileset?.()!==selected)throw Error('Bridge source changed');
                const key=JSON.stringify([routeId,point.longitude,point.latitude]),hit=probeCache.get(key);
                if((flight||sessionReuse)&&hit?.value&&(hit.committed||now()-hit.at<PROBE_TTL)){
                    probeCache.delete(key);probeCache.set(key,hit);
                    if(metrics){metrics.nativeHits++;if(hit.committed)metrics.nativeSessionHits++;}
                    return hit.value;
                }
                const negative=negativeCache.get(key);
                if(sessionReuse&&negative!==undefined&&now()-negative<15000){if(metrics)metrics.nativeClassifiedRoadHits++;return null;}
                if(sessionReuse)probes++;
                const d=metrics;
                if(pickBudget){const waited=await pickBudget.wait(signal);if(d)d.nativeAdaptiveWaitMs+=waited;}
                signal?.throwIfAborted?.();
                if(generation!==epoch||getDeckTileset?.()!==selected)throw Error('Bridge source changed');
                const start=now();if(d){d.nativePicks++;d.nativeMisses++;}
                const observation=pick(point,selected,exclusions(selected),sessionReuse);
                if(sessionReuse&&observation?.nonBridge){negativeCache.delete(key);negativeCache.set(key,now());
                    while(negativeCache.size>PROBE_LIMIT)negativeCache.delete(negativeCache.keys().next().value);}
                const measured=observation?.nonBridge?null:observation;
                const result=measured?{...measured,observedAt:now()}:null;
                const cost=Math.max(0,now()-start);if(d)d.nativePickMs+=cost;pickBudget?.record(cost);
                // Missing geometry may become resident on the very next frame.
                // Only source-identified positive observations are reusable.
                if(result?.nativeId){
                    probeCache.set(key,{value:result,at:now()});
                    while(probeCache.size>PROBE_LIMIT)probeCache.delete(probeCache.keys().next().value);
                }
                await yieldBatch(signal);
                // One ray per visible frame is the original working budget.
                // Additional fixed waits starve classification on a moving camera.
                signal?.throwIfAborted?.();return result;
            };
            for(const {route,tools,near} of candidates){
                if(disposed||getDeckTileset?.()!==selected||exhausted())break;
                let anchor=null,anchorAlong=null;const anchorPositions=new Set();
                // Prefer a committed anchor close to the aircraft before issuing
                // additional GPU queries. Distant cached bridges must not hide
                // unexamined nearby roads.
                if(sessionReuse)for(const offset of [0,-24,24,-48,48]){
                    const along=Math.round(near.along/24)*24+offset;
                    if(along<0||along>tools.total)continue;
                    const p=tools.at(along),entry=probeCache.get(JSON.stringify([route.id,p.longitude,p.latitude]));
                    if(entry?.committed&&distance(p,center)<=RADIUS+100){anchor=entry.value;anchorAlong=along;if(metrics)metrics.nativeSessionHits++;break;}
                }
                for(const offset of [0,-48,48,-120,120]){
                    if(anchor)break;
                    if(exhausted())break;
                    const along=Math.max(0,Math.min(tools.total,(sessionReuse?Math.round(near.along/24)*24:near.along)+offset));
                    if(anchorPositions.has(along))continue;anchorPositions.add(along);
                    const point=tools.at(along);
                    if(distance(point,center)>RADIUS+100)continue;
                    anchor=await probe(point,route.id);if(anchor){anchorAlong=along;break;}
                }
                if(!anchor&&sessionReuse){
                    const start=Math.max(0,Math.ceil((near.along-1400)/24)),end=Math.min(Math.floor(tools.total/24),Math.floor((near.along+1400)/24));
                    const known=[];
                    for(let k=start;k<=end;k++){
                        const p=tools.at(k*24),entry=probeCache.get(JSON.stringify([route.id,p.longitude,p.latitude]));
                        if(entry?.committed&&distance(p,center)<=RADIUS+100)known.push({along:k*24,entry});
                    }
                    known.sort((a,b)=>Math.abs(a.along-near.along)-Math.abs(b.along-near.along));
                    if(known.length){anchorAlong=known[0].along;anchor=known[0].entry.value;if(metrics)metrics.nativeSessionHits++;}
                }
                if(!anchor)continue;
                // Only matching, contiguous native bridge features form a
                // profile. Crossing roads cannot inherit a bridge's height.
                const lower=Math.max(0,near.along-1400),upper=Math.min(tools.total,near.along+1400);
                // Stable positions along each source axis enable reuse across
                // overlapping search windows; include true end points when covered.
                const positions=[...new Set([...(lower===0?[0]:[]),
                    ...Array.from({length:Math.max(0,Math.floor(upper/24)-Math.ceil(lower/24)+1)},(_,i)=>(Math.ceil(lower/24)+i)*24),
                    ...(upper===tools.total?[upper]:[]),anchorAlong])].sort((a,b)=>a-b);
                // Spend the bounded ray budget around the confirmed bridge,
                // not at the distant start of a potentially long road axis.
                // Afterwards split at every missing/unprobed grid position.
                const hits=new Map([[anchorAlong,anchor]]);
                // Reconstruct known sections from committed stations even if
                // the current frame budget cannot reach their previous edges.
                if(sessionReuse)for(const along of positions){
                    const point=tools.at(along);if(distance(point,center)>RADIUS+100)continue;
                    const entry=probeCache.get(JSON.stringify([route.id,point.longitude,point.latitude]));
                    if(entry?.committed&&entry.value.nativeId===anchor.nativeId){hits.set(along,entry.value);if(metrics)metrics.nativeSessionHits++;}
                }
                // An initial preview needs only a local contiguous span. Follow-up
                // scans use the full budget so this does not permanently limit coverage.
                const misses=[0,0];
                for(const along of positions.slice().sort((a,b)=>Math.abs(a-anchorAlong)-Math.abs(b-anchorAlong))){
                    if(exhausted())break;
                    if(hits.has(along))continue;
                    const side=along<anchorAlong?0:1;
                    if(initial&&(Math.abs(along-anchorAlong)>144||misses[side]>=2)){
                        if(metrics)metrics.nativeEdgeDeferred++;continue;
                    }
                    const point=tools.at(along);
                    if(distance(point,center)>RADIUS+100)continue;
                    const hit=await probe(point,route.id);
                    if(hit&&(!anchor.nativeId||hit.nativeId===anchor.nativeId)){hits.set(along,hit);misses[side]=0;}else misses[side]++;
                }
                const chunks=[];let chunk=[];
                const flush=()=>{if(chunk.length>=2&&distance(chunk[0],chunk.at(-1))>=(sessionReuse?23.9:24))chunks.push(chunk);chunk=[];};
                const rejected=new Set();
                for(let i=1;i<positions.length-1;i++){
                    const a=positions[i-1],b=positions[i],c=positions[i+1],l=hits.get(a),m=hits.get(b),r=hits.get(c);
                    if(!l||!m||!r||!m.nativeId||l.nativeId!==m.nativeId||r.nativeId!==m.nativeId||c-a<1)continue;
                    if(m.height>l.height+(r.height-l.height)*(b-a)/(c-a)+1.5){rejected.add(b);if(metrics)metrics.nativeHeightRejected++;}
                }
                for(const along of positions){
                    const hit=hits.get(along);
                    if(!hit||rejected.has(along)){flush();continue;}
                    const previous=chunk.at(-1);
                    if(previous&&Math.abs(previous.height-hit.height)>distance(previous,hit)*.35+.5){
                        flush();if(metrics)metrics.nativeHeightRejected++;
                    }
                    chunk.push({...hit,along});
                }
                flush();
                for(const [part,coordinates] of chunks.entries()){
                    // Anchor pier stations to the full official road axis, not
                    // the current (camera/LOD dependent) detected chunk length.
                    const first=coordinates[0].along,last=coordinates.at(-1).along,nativeStations=[];
                    const heightAt=along=>{
                        let i=0;while(i<coordinates.length-2&&coordinates[i+1].along<along)i++;
                        const a=coordinates[i],b=coordinates[i+1],t=(along-a.along)/(b.along-a.along||1);
                        return {...tools.at(along),height:a.height+(b.height-a.height)*t,
                            observedAt:Math.min(a.observedAt,b.observedAt),
                            ...(sessionReuse&&anchor.nativeId?{nativeProbeEvidence:[a,b].map(q=>({key:JSON.stringify([route.id,q.longitude,q.latitude]),height:q.height,observedAt:q.observedAt}))}:{})};
                    };
                    for(let k=Math.max(0,Math.ceil((first+1-12)/24));12+24*k<=last-1;k++){
                        const along=12+24*k,point=heightAt(along);
                        nativeStations.push({...point,station:k,probes:[heightAt(Math.max(first,along-4)),point,heightAt(Math.min(last,along+4))]});
                    }
                    bridges.push({id:`${route.id}:${part}`,sourceId:anchor.nativeId||route.sourceId,source:SOURCE,
                        name:anchor.name,coordinates:coordinates.map(({longitude,latitude,height})=>({longitude,latitude,height})),
                        mappedOnly:false,profileMethod:'loaded-native-road',nativeClass:anchor.code,nativeIdentified:!!anchor.nativeId,stableSection:sessionReuse,nativeStationKey:route.id,nativeStations});
                }
                if(bridges.length>=16||(initial&&bridges.some(b=>b.nativeStations?.length)))break;
            }
            signal?.throwIfAborted?.();
            const result={bridges:!disposed&&getDeckTileset?.()===selected&&selected.show!==false?bridges.slice(0,16):[],piers:[]};
            if(initial&&generation===epoch&&result.bridges.some(b=>b.nativeStations?.length)){
                result.partial=true;firstProfilePublished=true;if(metrics)metrics.nativeEarlyProfiles++;
            }
            if(!disposed&&generation===epoch&&getDeckTileset?.()===selected)nativeCache={center:{...center},selected,time:now(),result};
            return result;
        }
        // Promote sampled points only once a source-identified station also
        // passed the terrain/deck clearance check in bridge_supports.
        function commitValidated(candidate){
            if(!sessionReuse||disposed||!candidate?.nativeIdentified||!candidate.sourceId||probeSource!==getDeckTileset?.())return;
            const evidence=candidate.nativeProbeEvidence;
            if(!Array.isArray(evidence)||evidence.length!==2)return;
            const entries=evidence.map(e=>probeCache.get(e.key));
            if(entries.some((entry,i)=>!entry||entry.value.nativeId!==candidate.sourceId||
                entry.value.height!==evidence[i].height||entry.value.observedAt!==evidence[i].observedAt))return;
            for(const entry of entries)if(!entry.committed){entry.committed=true;if(metrics)metrics.nativeSessionCommitted++;}
        }
        // Optional route preparation streams only official road axes. GPU
        // heights are sampled later from resident native geometry; no camera
        // teleport or persistent storage, and the flight start never waits.
        async function prepareRoute(points,signal){
            if(!prefetchRoads||disposed||cachedOnly||!isOnline()||!Array.isArray(points))return;
            prefetchController?.abort();const active=new AbortController();prefetchController=active;
            const cancel=()=>active.abort();signal?.addEventListener('abort',cancel,{once:true});if(signal?.aborted)cancel();
            try{
                const centers=[];const origin=points.find(valid);for(const p of points){
                    if(!valid(p)||!origin||distance(p,origin)<350)continue;
                    if(!centers.length||distance(p,centers.at(-1))>=350)centers.push(p);
                    if(centers.length>=3)break;
                }
                for(const center of centers){active.signal.throwIfAborted();await roads(center,active.signal);}
            }catch(_){/* optional visual preparation never blocks replay */}
            finally{signal?.removeEventListener('abort',cancel);if(prefetchController===active)prefetchController=null;}
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
        return {discover,prepareRoute,commitValidated,invalidate,setDiagnosticsEnabled,diagnostics,dispose(){disposed=true;invalidate();cache=null;roadAreas.length=0;metrics=null;}};
    }
    return {create,createPickBudget,parseIdentify,urlFor,BRIDGE_CODES};
});
