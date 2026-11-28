/* Bounded synthetic supports for explicitly mapped bridge decks. The source
 * deck stays untouched; pier spacing is illustrative, not surveyed engineering. */
(function(root,factory){
    const api=factory(typeof module==='object'&&module.exports?require('../map/map_providers.js'):root.FPVMapProviders);
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
    // Structural tags are authoritative; names only qualify when they explicitly
    // name the bridge type. A generic footbridge or a road name is insufficient.
    function mappedOnlyBridge(value){
        const tags=value?.tags||value||{};
        const structure=`${tags.bridge||''} ${tags['bridge:structure']||''} ${tags.bridgeType||''} ${tags.structure||''}`;
        const name=String(value?.name||tags.name||'').normalize('NFKC');
        return value?.mappedOnly===true||
            /(?:^|[\s;,])(?:suspension|cable[-_ ]?stayed|arch|hanging|suspended)(?=$|[\s;,])/i.test(structure)||
            /\b(?:suspension|hanging|suspended|rope)[ -]+(?:foot[ -]?)?bridge\b|\b(?:Hängebrücke|Haengebruecke)\b|\b(?:pont|passerelle)\s+suspendu[e]?\b|\bponte\s+sospeso\b/i.test(name);
    }
    // An unclassified native/aviation deck can overlap a classified OSM span.
    // Exclude guesses only along that span, not on a road crossing underneath it.
    function onMappedOnlySpan(point,before,after,bridges){
        const scale=R*DEG*Math.cos(point.latitude*DEG),dy=R*DEG,
            vx=(after.longitude-before.longitude)*scale,vy=(after.latitude-before.latitude)*dy;
        for(const bridge of bridges){
            const line=bridge.coordinates;
            for(let i=1;i<line.length;i++){
                const a=line[i-1],b=line[i],dx=(b.longitude-a.longitude)*scale,by=(b.latitude-a.latitude)*dy,
                    length2=dx*dx+by*by;
                if(!length2)continue;
                const px=(point.longitude-a.longitude)*scale,py=(point.latitude-a.latitude)*dy,
                    t=(px*dx+py*by)/length2;
                if(t<0||t>1||Math.hypot(px-t*dx,py-t*by)>12)continue;
                const alignment=Math.abs(vx*dx+vy*by)/Math.sqrt((vx*vx+vy*vy)*length2);
                if(alignment>=.9)return true;
            }
        }
        return false;
    }
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
                mappedOnly:mappedOnlyBridge(tags)});
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
                        sourceId:String(feature.id??index),coordinates,
                        mappedOnly:mappedOnlyBridge({...properties,...tags,name:feature.name||tags.name}),
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
                    mappedOnly:mappedOnlyBridge(tags)});
            }
        }
        return {bridges:bridges.slice(0,48).map(p=>({...p,sourceSetId:sourceId})),
            piers:piers.slice(0,192).map(p=>({...p,sourceSetId:sourceId}))};
    }
    function parseBridges(document){
        return parseBridgeData(document).bridges.filter(bridge=>!bridge.mappedOnly);
    }
    function stations(bridges,center,budget=96,piers=[]){
        const result=[],matched=new Set(),mappedOnly=bridges.filter(mappedOnlyBridge);
        for(const bridge of bridges){
            const line=bridge.coordinates,cumulative=[0];
            for(let i=1;i<line.length;i++)cumulative.push(cumulative.at(-1)+distance(line[i-1],line[i]));
            const total=cumulative.at(-1);
            if(total<(bridge.stableSection?23.9:24)||total>20000)continue;
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
                        profileMethod:bridge.profileMethod,sourceSetId:bridge.sourceSetId,sourceFeatureId:bridge.id,
                        positionSourceSetId:pier.sourceSetId,positionFeatureId:pier.id,
                        probes:[at(Math.max(0,near.along-4)),{...pier,height:profile.height},at(Math.min(total,near.along+4))]});
                    matched.add(pier.id);if(result.length>=budget)return result;
                }
                continue;
            }
            if(mappedOnlyBridge(bridge))continue;
            if(Array.isArray(bridge.nativeStations)){
                for(const p of bridge.nativeStations){
                    if(center&&distance(p,center)>RADIUS+100)continue;
                    if(onMappedOnlySpan(p,p.probes[0],p.probes[2],mappedOnly)||result.some(q=>distance(p,q)<2))continue;
                    result.push({...p,id:JSON.stringify(['native-axis-pier',bridge.nativeStationKey,bridge.sourceId,p.station,p.longitude.toFixed(7),p.latitude.toFixed(7)]),
                        sourceId:bridge.sourceId,source:bridge.source,mapped:false,deckMetersWgs84:p.height,profileMethod:bridge.profileMethod,nativeIdentified:bridge.nativeIdentified===true});
                    if(result.length>=budget)return result;
                }
                continue;
            }
            const spans=Math.max(2,Math.ceil(total/28));
            for(let i=1;i<spans;i++){
                const along=total*i/spans,p=at(along);
                if(onMappedOnlySpan(p,at(Math.max(0,along-4)),at(Math.min(total,along+4)),mappedOnly))continue;
                if(center&&distance(p,center)>RADIUS+100)continue;
                if(result.some(q=>distance(p,q)<2))continue;
                result.push({...p,id:bridge.nativeStationKey?JSON.stringify(['native-pier',bridge.nativeStationKey,bridge.sourceId,p.longitude.toFixed(6),p.latitude.toFixed(6)]):`${bridge.id}:${i}`,sourceId:bridge.sourceId,
                    source:bridge.source,mapped:false,deckMetersWgs84:p.height,profileMethod:bridge.profileMethod,sourceSetId:bridge.sourceSetId,sourceFeatureId:bridge.id,
                    probes:[at(along-4),p,at(along+4)]});
                if(result.length>=budget)return result;
            }
        }
        for(const pier of piers){
            if(matched.has(pier.id)||(!finite(pier.topMetersWgs84)&&!finite(pier.heightMeters))||
                (center&&distance(pier,center)>RADIUS+100))continue;
            result.push({...pier,sourceId:pier.id,sourceFeatureId:pier.id,deckMetersWgs84:pier.topMetersWgs84,probes:[pier,pier,pier]});
            if(result.length>=budget)break;
        }
        return result;
    }
    function create(C,viewer,{sampleTerrain=async()=>[],ready=()=>true,cachedOnly=false,
        isOnline=()=>globalThis.navigator?.onLine!==false,isNavigationActive=()=>false,
        getDeckTileset=null,discoverBridges=null,disposeDiscovery=()=>{},
        fetcher=(...args)=>fetch(...args),now=()=>Date.now(),yieldBatch=afterFrame,terrainIdentity=()=>null,
        mobile=false,reuseFlightDeck=false,sessionReuse=false,pickBudget=null,commitNative=()=>{},lookahead=()=>[],invalidateDiscovery=()=>{},discoveryDiagnostics=()=>null,setDiscoveryDiagnostics=()=>{}}={}){
        const scene=viewer.scene;
        let enabled=false,structuresEnabled=false,benchmarkSuppressed=false,disposed=false,profile='balanced',opacity=1,revision=0,controller=null;
        const sourceSets=new Map();
        // Exact coordinates only: no quantization/interpolation and no reuse
        // across terrain providers. In-memory, bounded, successful samples only.
        const groundCache=new Map(),GROUND_LIMIT=2048,GROUND_TTL=120000;
        let groundIdentity=terrainIdentity(),metrics=null;
        // Cache only coherent three-probe groups against the actual selected
        // native geometry. Never reuse a provisional/missing height or a
        // most-detailed result that may differ from the visible LOD.
        const deckCache=new Map(),observations=new Map(),detailedAttempts=new Map(),validatedSupports=new Map(),DECK_LIMIT=512,DECK_TTL=30000,FLIGHT_DECK_TTL=120000;
        const geometryIds=new WeakMap();let nextGeometryId=0,deckEpoch=0,visualEpoch=0,deckTileset=null;
        function geometryId(object){
            if(!object||typeof object!=='object')return null;
            if(!geometryIds.has(object))geometryIds.set(object,++nextGeometryId);
            return geometryIds.get(object);
        }
        function invalidateDeckCache(notify=true){confirmedDecks.clear();deckCache.clear();observations.clear();detailedAttempts.clear();validatedSupports.clear();deckEpoch++;lastRefreshAt=-Infinity;if(notify)invalidateDiscovery();}
        // Portal uniforms/masks alter the visual pick pass, not the real
        // bridge source. Invalidate only LOD-bound observations, not confirmed
        // heights, world-space instances or in-progress native discovery.
        function invalidateVisualPicking(){
            if(disposed)return;
            visualEpoch++;
            for(const [key,entry] of deckCache)if(!entry.confirmed)deckCache.delete(key);
            if(metrics)metrics.deckVisualInvalidations++;
        }
        // A graphics budget changes selected LOD, not the source identity.
        // Abort only the unfinished sampling batch; keep source-scoped native
        // observations and independently confirmed decks. Actual source/terrain
        // changes still go through full invalidation.
        function invalidateLod(){
            if(disposed)return;
            deckCache.clear();observations.clear();detailedAttempts.clear();deckEpoch++;
            if(getDeckTileset?.()===deckTileset&&ready())supportEpoch=deckEpoch;
            ++revision;controller?.abort();pending=null;pendingCenter=null;lastRefreshAt=-Infinity;
            if(metrics)metrics.deckLodInvalidations++;
        }
        function deckSignature(candidate,base){
            const tileset=getDeckTileset?.();
            if(tileset!==deckTileset){deckTileset=tileset;invalidateDeckCache(false);}
            // Cesium 3D Tiles does not expose the selected tile array publicly.
            // Fail closed on unsupported versions, incomplete bounds or empty
            // selections. No general scene/terrain picks are ever cached.
            if(!tileset||tileset.show!==true||!Array.isArray(tileset._selectedTiles)||!finite(base))return null;
            const rays=candidate.probes.map(q=>{
                const a=C.Cartesian3.fromDegrees(q.longitude,q.latitude,base),b=C.Cartesian3.fromDegrees(q.longitude,q.latitude,base+1);
                const dx=b.x-a.x,dy=b.y-a.y,dz=b.z-a.z,length=Math.hypot(dx,dy,dz);
                return {a,dx:dx/length,dy:dy/length,dz:dz/length,length};
            });
            if(rays.some(r=>!finite(r.length)||r.length<.5))return null;
            const relevant=[];
            for(const tile of tileset._selectedTiles){
                const sphere=tile?.boundingSphere,c=sphere?.center,r=sphere?.radius;
                if(!c||![c.x,c.y,c.z,r].every(finite)||r<0)return null;
                // A vertical pick can hit any height. Test perpendicular
                // distance to the entire vertical ray, not a height band.
                const near=rays.some(({a,dx,dy,dz})=>{
                    const x=c.x-a.x,y=c.y-a.y,z=c.z-a.z,t=x*dx+y*dy+z*dz;
                    return Math.hypot(x-t*dx,y-t*dy,z-t*dz)<=r+5;
                });
                if(!near)continue;
                const tileId=geometryId(tile),contentId=geometryId(tile.content);
                if(tile.contentReady!==true||!tileId||!contentId)return null;
                relevant.push(`${tileId}:${contentId}`);
            }
            return relevant.length?`${deckEpoch}/${visualEpoch}/${relevant.sort().join(',')}`:null;
        }
        const deckKey=(p,base)=>JSON.stringify([p.id,p.source,p.sourceId,p.deckMetersWgs84??null,p.heightMeters??null,base,p.probes.map(q=>[q.longitude,q.latitude])]);
        const flightDeckKey=p=>JSON.stringify([p.id,p.source,p.sourceId,p.deckMetersWgs84??null,p.heightMeters??null,p.probes.map(q=>[q.longitude,q.latitude])]);
        const confirmedDecks=new Map(),CONFIRMED_TTL=sessionReuse?Infinity:300000;
        const sessionNative=record=>sessionReuse&&record?.candidate.nativeIdentified===true&&record.candidate.profileMethod==='loaded-native-road'&&finite(record.candidate.observedAt);
        const usableRecord=record=>record&&(now()-record.at<FLIGHT_DECK_TTL||sessionNative(record));
        const retainedPool=()=>sessionReuse?[...supports,...[...validatedSupports.values()].filter(sessionNative).map(r=>r.support).filter(p=>!supports.some(q=>q.id===p.id))]:supports;
        function storeObservation(key,entry){observations.delete(key);observations.set(key,entry);while(observations.size>DECK_LIMIT)observations.delete(observations.keys().next().value);}
        function storeConfirmed(key,entry){confirmedDecks.delete(key);confirmedDecks.set(key,entry);
            while(confirmedDecks.size>DECK_LIMIT)confirmedDecks.delete(confirmedDecks.keys().next().value);}
        function plausibleDeck(p,heights,base){return coherentDeck(heights,base)&&
            (!finite(p.deckMetersWgs84)||Math.abs(heights[1]-p.deckMetersWgs84)<=.75)&&
            heights[1]<=((heights[0]+heights[2])/2)+.75;}

        function coherentDeck(heights,base){return finite(base)&&base>=-500&&base<=9000&&heights.length===3&&
            heights.every(finite)&&Math.max(...heights)-Math.min(...heights)<=2.8&&heights[1]-base>=2.5&&heights[1]-base<=150;}

        function syncGroundIdentity(){
            const identity=terrainIdentity();if(identity!==groundIdentity){groundIdentity=identity;groundCache.clear();invalidateDeckCache();lastRefreshAt=-Infinity;clear(false,'terrain-provider');}
            return identity;
        }
        async function sampleGround(candidates,signal){
            const identity=syncGroundIdentity(),instant=now(),missing=new Map(),result=[];
            for(const [i,p] of candidates.entries()){
                const key=`${p.longitude},${p.latitude}`,hit=groundCache.get(key);
                if(hit&&(instant-hit.at<GROUND_TTL||(sessionReuse&&p.nativeIdentified===true&&p.profileMethod==='loaded-native-road'))){
                    result[i]=hit.height;groundCache.delete(key);groundCache.set(key,hit);
                    if(metrics)metrics.groundHits++;
                }else{
                    groundCache.delete(key);if(metrics)metrics.groundMisses++;
                    if(!missing.has(key))missing.set(key,{point:{longitude:p.longitude,latitude:p.latitude},indices:[]});
                    missing.get(key).indices.push(i);
                }
            }
            if(missing.size){
                const started=now(),d=metrics;if(d){d.groundBatches++;d.groundPoints+=missing.size;}
                let values;try{values=await sampleTerrain([...missing.values()].map(x=>x.point),signal);}
                finally{if(d)d.groundWallMs+=Math.max(0,now()-started);}
                signal.throwIfAborted?.();
                if(syncGroundIdentity()!==identity||!ready())throw Error('Bridge terrain changed during sampling');
                let j=0;for(const [key,entry] of missing){
                    const height=values?.[j++];for(const index of entry.indices)result[index]=height;
                    if(finite(height)&&height>=-500&&height<=9000)groundCache.set(key,{height,at:now()});
                }
                while(groundCache.size>GROUND_LIMIT)groundCache.delete(groundCache.keys().next().value);
            }
            return result;
        }
        let supportEpoch=-1,primitive=null,supports=[],cache=null,pending=null,pendingCenter=null,lastCenter=null,lastRefreshAt=-Infinity;
        let lastFrameAt=-Infinity,error=null,retryAt=-Infinity,credited=false;
        let mapFocus=null;
        let sourceQuery=null,drawSignature=null,benchmarkMode=0,frozen=false,detailedActive=0,freezeContaminated=false;
        // 0 normal, 1 freeze after warmup, 2 compute without drawing.
        const hidden=()=>benchmarkMode===2;
        const creditDisplay=viewer.cesiumWidget?.creditDisplay;
        const sourceCredits=C.Credit?{
            osm:new C.Credit('<a href="https://www.openstreetmap.org/copyright" target="_blank" rel="noopener">© OpenStreetMap contributors · ODbL 1.0</a>',true),
            aviation:new C.Credit('<a href="https://www.bazl.admin.ch/de/luftfahrthindernisdaten-schweiz" target="_blank" rel="noopener">BAZL / Skyguide · Luftfahrthindernisse</a>',false),
            native:new C.Credit('© swisstopo',false)
        }:{};
        const activeCredits=new Set();
        function credits(show){
            const needed=new Set();
            if(show&&!hidden())for(const support of supports){
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
        const audit=[];
        const idHash=value=>{let hash=2166136261;for(let i=0;i<value.length;i++)hash=Math.imul(hash^value.charCodeAt(i),16777619);return (hash>>>0).toString(16).padStart(8,'0');};
        function auditEvent(id,reason){if(!metrics)return;audit.push(`${idHash(id)}:${reason}`);if(audit.length>6)audit.shift();}
        function clear(preserve=false,reason='reset'){
            if(metrics&&supports.length){metrics.supportCleared+=supports.length;metrics.lastRemovalReason=reason;for(const p of supports)auditEvent(p.id,reason);}
            if(primitive){scene.primitives.remove(primitive);primitive=null;}
            supports=[];if(!preserve)validatedSupports.clear();drawSignature=null;credits(false);scene.requestRender?.();
        }
        function focus(){
            const canvas=scene.canvas||viewer.canvas,camera=viewer.camera;
            // During flight the useful search area is around the aircraft.
            // A centre-of-screen ray can reach a distant mountainside and
            // initialize terrain pickers at every two-second refresh.
            const position=camera?.positionCartographic;
            const cameraPoint=position&&{longitude:position.longitude/DEG,latitude:position.latitude/DEG,height:position.height};
            if(isNavigationActive()){mapFocus=null;return valid(cameraPoint)?cameraPoint:null;}
            // Map orbit/heading changes must not move the search anchor. A
            // true pan/zoom may select a new area; use the original ground ray
            // only after actual camera translation or altitude change.
            if(mapFocus&&valid(cameraPoint)&&distance(cameraPoint,mapFocus.camera)<30&&
                Math.abs(cameraPoint.height-mapFocus.camera.height)<Math.max(20,Math.abs(mapFocus.camera.height)*.02))return mapFocus.target;
            try{
                if(canvas&&C.Cartesian2&&C.Cartographic?.fromCartesian){
                    const pixel=new C.Cartesian2((canvas.clientWidth||canvas.width)/2,(canvas.clientHeight||canvas.height)/2);
                    const ray=camera?.getPickRay?.(pixel),hit=ray&&scene.globe.pick?.(ray,scene);
                    const position=hit&&C.Cartographic.fromCartesian(hit);
                    if(position){const p={longitude:position.longitude/DEG,latitude:position.latitude/DEG};if(valid(p)){
                        if(valid(cameraPoint)&&finite(cameraPoint.height))mapFocus={camera:cameraPoint,target:p};return p;
                    }}
                }
            }catch(_){/* use camera coordinate when a visible ground pick is unavailable */}
            const p=camera?.positionCartographic;
            const result=p&&{longitude:p.longitude/DEG,latitude:p.latitude/DEG};
            return valid(result)?result:null;
        }
        // Hysteresis for already admitted supports only. New geometry still
        // enters within the 700 m discovery area. Retain visible distant piers
        // up to a hard cap, never grow the active geometry budget.
        function retainInArea(p,center){
            const gap=distance(p,center);
            if(gap<=RADIUS+100)return true;
            if(!sessionReuse||!supports.some(q=>q.id===p.id))return false;
            if(gap<=900)return true;
            if(gap>1200)return false;
            try{
                const camera=viewer.camera,frustum=camera.frustum;
                const volume=frustum?.computeCullingVolume?.(camera.positionWC,camera.directionWC,camera.upWC);
                if(!volume||!C.BoundingSphere||C.Intersect?.OUTSIDE===undefined)return false;
                const mid=C.Cartesian3.fromDegrees(p.longitude,p.latitude,(p.top+p.bottom)/2);
                const sphere=new C.BoundingSphere(mid,(p.top-p.bottom)/2+p.radius);
                return volume.computeVisibility(sphere)!==C.Intersect.OUTSIDE;
            }catch(_){return false;}
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
        function draw(next,reason='refresh'){
            supportEpoch=deckEpoch;
            if(metrics){const ids=new Map(next.map(p=>[p.id,p]));
                for(const old of supports){const p=ids.get(old.id);
                    if(!p){metrics.supportRemovedDuringDraw++;
                        const why=reason==='refresh-admission'||reason==='refresh'?
                            (lastCenter&&!retainInArea(old,lastCenter)?'outside-area':
                             next.some(q=>distance(q,old)<(q.sourceId===old.sourceId&&!sessionReuse?8:2))?'near-replacement':
                             next.length>=BUDGETS[profile]?'render-budget':'refresh-omitted'):reason;
                        metrics.lastRemovalReason=why;auditEvent(old.id,why);continue;}
                    if(old.longitude!==p.longitude||old.latitude!==p.latitude){metrics.supportPositionChanged++;auditEvent(p.id,'position');}
                    if(Math.abs(old.top-p.top)>.01||Math.abs(old.bottom-p.bottom)>.01){metrics.supportHeightChanged++;auditEvent(p.id,'height');}
                    if(old.radius!==p.radius){metrics.supportRadiusChanged++;auditEvent(p.id,'radius');}
                }
                const oldIds=new Set(supports.map(p=>p.id));metrics.supportAdded+=next.filter(p=>!oldIds.has(p.id)).length;
            }
            if(!next.length){clear(sessionReuse,reason);return;}
            if(hidden()){
                if(primitive){scene.primitives.remove(primitive);primitive=null;}
                supports=next;drawSignature=null;credits(false);scene.requestRender?.();return;
            }
            const signature=JSON.stringify([opacity,next.map(p=>[p.id,p.longitude,p.latitude,p.bottom,p.top,p.radius]).sort((a,b)=>a[0].localeCompare(b[0]))]);
            if(primitive&&signature===drawSignature){supports=next;credits(true);return;}
            if(!C.CylinderGeometry||!C.GeometryInstance||!C.Primitive||!C.Transforms?.eastNorthUpToFixedFrame||
                !C.PerInstanceColorAppearance||!C.ColorGeometryInstanceAttribute)return;
            const started=now(),d=metrics;
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
            if(d){d.geometryBuilds++;d.geometryBuildMs+=Math.max(0,now()-started);}
        }
        async function deckSamples(candidates,ground,excluded,signal,onProgress=()=>{}){
            const groups=candidates.map(()=>[]),reused=new Map(),suspectIndices=new Set(),selected=getDeckTileset?.();
            let verificationBudget=2;
            const flight=reuseFlightDeck&&isNavigationActive()&&!!selected;
            // Sync the identity before consulting the long-lived visual cache.
            if(selected!==deckTileset){deckTileset=selected;invalidateDeckCache(false);}
            const generation=deckEpoch;
            const publish=(i)=>{
                if(reuseFlightDeck&&!signal.aborted&&generation===deckEpoch&&getDeckTileset?.()===selected)onProgress(i,groups[i]);
            };
            for(let i=0;i<candidates.length;i++){
                signal.throwIfAborted?.();
                if(generation!==deckEpoch)throw Error('Bridge deck changed during sampling');
                const p=candidates[i];
                // Discovery has already classified and sampled these heights
                // against the selected native tileset. Re-picking every pier's
                // three neighbours would repeat up to 384 GPU passes in quality.
                if(p.profileMethod==='loaded-native-road'&&finite(p.deckMetersWgs84)){publish(i);continue;}
                if(!finite(ground[i])||ground[i]< -500||ground[i]>9000){if(metrics)metrics.deckInvalidGround++;continue;}
                const key=deckKey(p,ground[i]),stableKey=flightDeckKey(p),hit=deckCache.get(key);
                const confirmed=confirmedDecks.get(stableKey);
                if(flight&&confirmed&&now()-confirmed.at<CONFIRMED_TTL&&Math.abs(confirmed.base-ground[i])<=.25&&plausibleDeck(p,confirmed.heights,ground[i])){
                    groups[i]=confirmed.heights.slice();storeConfirmed(stableKey,confirmed);
                    if(metrics){metrics.deckHits++;metrics.deckPersistentHits++;metrics.deckStableHits++;}publish(i);continue;
                }
                if(flight&&confirmed&&metrics){if(Math.abs(confirmed.base-ground[i])>.25)metrics.deckBaseChanged++;else metrics.deckExpired++;}
                const previousObservation=observations.get(stableKey);
                const verifyAgain=sessionReuse&&flight&&!confirmed&&verificationBudget>0&&hit?.confirmed&&
                    previousObservation&&previousObservation.revision!==revision&&now()-previousObservation.at>=15000&&
                    now()-previousObservation.at<FLIGHT_DECK_TTL&&Math.abs(previousObservation.base-ground[i])<=.25;
                if(verifyAgain){verificationBudget--;if(metrics)metrics.deckIndependentRechecks++;}
                if(!verifyAgain&&flight&&hit?.confirmed&&now()-hit.at<FLIGHT_DECK_TTL&&plausibleDeck(p,hit.heights,ground[i])){
                    groups[i]=hit.heights.slice();deckCache.delete(key);deckCache.set(key,hit);
                    if(metrics){metrics.deckHits++;metrics.deckPersistentHits++;}publish(i);continue;
                }
                const signature=deckSignature(p,ground[i]);
                if(!verifyAgain&&signature&&hit?.signature===signature&&now()-hit.at<DECK_TTL){
                    groups[i]=hit.heights.slice();deckCache.delete(key);deckCache.set(key,hit);
                    if(metrics)metrics.deckHits++;reused.set(i,signature);continue;
                }
                deckCache.delete(key);if(metrics){metrics.deckMisses++;if(!signature)metrics.deckUnidentified++;}
                let stable=!!signature;
                for(const q of p.probes){
                    if(!scene.sampleHeight){groups[i].push(null);continue;}
                    await yieldBatch(signal);signal.throwIfAborted?.();
                    if(disposed||!enabled||!ready())return groups;
                    if(generation!==deckEpoch||(getDeckTileset&&getDeckTileset()!==selected))throw Error('Bridge deck changed during sampling');
                    if(stable&&deckSignature(p,ground[i])!==signature)stable=false;
                    const d=metrics;if(pickBudget){const waited=await pickBudget.wait(signal);if(d)d.deckAdaptiveWaitMs+=waited;}
                    signal.throwIfAborted?.();if(generation!==deckEpoch||(getDeckTileset&&getDeckTileset()!==selected))throw Error('Bridge deck changed during sampling');
                    if(disposed||!enabled||!ready())return groups;
                    if(stable&&deckSignature(p,ground[i])!==signature)stable=false;
                    const started=now();if(d)d.deckPicks++;
                    try{groups[i].push(scene.sampleHeight(C.Cartographic.fromDegrees(q.longitude,q.latitude),getDeckTileset?exclusions():excluded,.7));}
                    catch(_){groups[i].push(null);}
                    const cost=Math.max(0,now()-started);if(d)d.deckPickMs+=cost;pickBudget?.record(cost);
                    // At most one synchronous pick per frame (already the
                    // existing limit). Expensive picks get an extra frame of
                    // recovery rather than saturating every animation frame.
                    if(!pickBudget&&cost>=8&&isNavigationActive()){
                        if(d)d.deckCooldownFrames++;
                        await yieldBatch(signal);signal.throwIfAborted?.();
                    }
                }
                let coherent=plausibleDeck(p,groups[i],ground[i]);
                // On revalidation, a sudden upward jump must be corroborated
                // by a separate pass. A coherent but wrong upper surface is
                // not enough to replace previously known deck geometry.
                const earlier=observations.get(stableKey);
                if(flight&&coherent&&confirmed&&groups[i][1]>confirmed.heights[1]+.75&&
                    !(earlier&&earlier.revision!==revision&&now()-earlier.at<FLIGHT_DECK_TTL&&Math.abs(earlier.base-ground[i])<=.25&&
                        earlier.heights.every((h,k)=>Math.abs(h-groups[i][k])<=.25))){
                    storeObservation(stableKey,{heights:groups[i].slice(),base:ground[i],at:now(),revision});
                    groups[i]=[];coherent=false;suspectIndices.add(i);if(metrics)metrics.deckHeightRejected++;continue;
                }
                if(!coherent&&groups[i].length===3&&groups[i].every(finite)&&metrics)metrics.deckHeightRejected++;
                if(!coherent&&metrics)metrics.deckIncoherent++;
                if(generation===deckEpoch&&coherent){
                    const verified=stable&&deckSignature(p,ground[i])===signature;
                    const previous=observations.get(stableKey);
                    // If Cesium does not expose stable selected bounds (common
                    // on mobile), require two independent coherent resident
                    // observations agreeing within 25 cm before reuse.
                    const repeated=flight&&previous&&previous.revision!==revision&&now()-previous.at<FLIGHT_DECK_TTL&&Math.abs(previous.base-ground[i])<=.25&&
                        previous.heights.every((height,j)=>Math.abs(height-groups[i][j])<=.25);
                    if(verified||repeated){
                        deckCache.set(key,{signature:verified?signature:null,confirmed:true,heights:groups[i].slice(),at:now()});
                        while(deckCache.size>DECK_LIMIT)deckCache.delete(deckCache.keys().next().value);
                        // Only independent agreement qualifies for longer
                        // source-scoped reuse; a single selected LOD is not proof.
                        if(repeated)storeConfirmed(stableKey,{heights:groups[i].slice(),base:ground[i],at:now(),revision});
                    }
                    if(flight)storeObservation(stableKey,{heights:groups[i].slice(),base:ground[i],at:now(),revision});
                }else if(!flight)observations.delete(stableKey);
                // A resident miss must not discard a previous successful
                // detailed observation. That would prevent confirmation on
                // devices whose resident LOD is consistently too coarse.
                if(coherent||finite(p.deckMetersWgs84)||finite(p.heightMeters))publish(i);
            }
            const missing=[];
            for(let i=0;i<candidates.length;i++){
                const p=candidates[i],base=ground[i];
                if(!suspectIndices.has(i)&&finite(base)&&base>=-500&&base<=9000&&!finite(p.deckMetersWgs84)&&
                    !finite(p.heightMeters)&&!plausibleDeck(p,groups[i],base)){
                    // A resident pick can return the terrain instead of the
                    // unloaded bridge. Finite values alone do not validate a deck.
                    if(metrics&&groups[i].length===3&&groups[i].every(h=>finite(h)&&Math.abs(h-base)<2.5))metrics.deckGroundOnly++;
                    missing.push(i);
                }
            }
            if(missing.length&&scene.sampleHeightMostDetailed&&(!getDeckTileset||getDeckTileset())){
                // Cesium's most-detailed sampler also performs picking. Keep
                // each request to one pier instead of a scene-wide GPU burst.
                const deadline=Date.now()+8000;
                // Retain the wall-clock deadline and single-flight guard, but
                // don't impose a two-pier limit which can starve entire bridges.
                if(flight)missing.sort((a,b)=>(detailedAttempts.get(deckKey(candidates[a],ground[a]))??-Infinity)-
                    (detailedAttempts.get(deckKey(candidates[b],ground[b]))??-Infinity)||0);
                const detailed=missing;
                for(const [index,i] of detailed.entries()){
                    await yieldBatch(signal);signal.throwIfAborted?.();
                    if(disposed||!enabled||!ready()||Date.now()>=deadline){if(metrics)metrics.detailedDeferred+=detailed.length-index;break;}
                    // Promise.race cannot cancel Cesium's underlying picker.
                    // Do not start another request while it is still working.
                    if(detailedActive){if(metrics)metrics.detailedDeferred+=detailed.length-index;break;}
                    if(generation!==deckEpoch||(getDeckTileset&&getDeckTileset()!==selected))throw Error('Bridge deck changed during sampling');
                    let timer,abort;
                    const started=now(),d=metrics;if(d)d.detailedRequests++;
                    const key=deckKey(candidates[i],ground[i]);detailedAttempts.delete(key);detailedAttempts.set(key,started);
                    while(detailedAttempts.size>DECK_LIMIT)detailedAttempts.delete(detailedAttempts.keys().next().value);
                    try{
                        const positions=candidates[i].probes.map(q=>C.Cartographic.fromDegrees(q.longitude,q.latitude));
                        const underlying=scene.sampleHeightMostDetailed(positions,getDeckTileset?exclusions():excluded,.7);
                        detailedActive++;
                        const tracked=Promise.resolve(underlying).finally(()=>{detailedActive--;});
                        const sampled=await Promise.race([
                            tracked,
                            new Promise((_,reject)=>{
                                timer=setTimeout(()=>reject(Error('Bridge deck sampling timed out')),Math.max(1,deadline-Date.now()));
                                abort=()=>reject(Error('Bridge deck sampling cancelled'));
                                signal.addEventListener('abort',abort,{once:true});
                            })
                        ]);
                        signal.throwIfAborted?.();
                        if(generation!==deckEpoch||(getDeckTileset&&getDeckTileset()!==selected))throw Error('Bridge deck changed during sampling');
                        const heights=Array.from({length:3},(_,k)=>sampled?.[k]?.height);
                        // Do not merge heights from two different sampling passes.
                        if(plausibleDeck(candidates[i],heights,ground[i])){
                            const p=candidates[i],stableKey=flightDeckKey(p),previous=confirmedDecks.get(stableKey),earlier=observations.get(stableKey);
                            if(flight&&previous&&heights[1]>previous.heights[1]+.75&&
                                !(earlier&&earlier.revision!==revision&&now()-earlier.at<FLIGHT_DECK_TTL&&Math.abs(earlier.base-ground[i])<=.25&&earlier.heights.every((h,k)=>Math.abs(h-heights[k])<=.25))){
                                storeObservation(stableKey,{heights:heights.slice(),base:ground[i],at:now(),revision});if(d)d.deckHeightRejected++;continue;
                            }
                            if(flight){
                                if(earlier&&earlier.revision!==revision&&now()-earlier.at<FLIGHT_DECK_TTL&&
                                    Math.abs(earlier.base-ground[i])<=.25&&earlier.heights.every((h,k)=>Math.abs(h-heights[k])<=.25)){
                                    storeConfirmed(stableKey,{heights:heights.slice(),base:ground[i],at:now(),revision});
                                    if(d)d.deckDetailedConfirmed++;
                                }
                                storeObservation(stableKey,{heights:heights.slice(),base:ground[i],at:now(),revision});
                            }
                            groups[i]=heights;if(d)d.detailedResolved++;publish(i);
                        }
                    }catch(_){/* explicit source profiles still remain usable */}
                    finally{if(d)d.detailedWallMs+=Math.max(0,now()-started);clearTimeout(timer);if(abort)signal.removeEventListener('abort',abort);}
                }
            }
            if(generation!==deckEpoch||(getDeckTileset&&getDeckTileset()!==selected))throw Error('Bridge deck changed during sampling');
            // Other candidates can take several frames to resolve. Never
            // publish a cache hit whose selected geometry changed meanwhile.
            for(const [i,signature] of reused){
                if(deckSignature(candidates[i],ground[i])!==signature){groups[i]=[];if(metrics)metrics.deckStaleHits++;}
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
            if(!ready()){groundCache.clear();invalidateDeckCache();++revision;controller?.abort();pending=null;pendingCenter=null;clear(false,'terrain-not-ready');return Promise.resolve(status());}
            if(!valid(center))return Promise.resolve(status());
            syncGroundIdentity();if(frozen)return Promise.resolve(status());
            // Detect source replacement before waiting for discovery/terrain.
            const currentTileset=getDeckTileset?.();
            if(currentTileset!==deckTileset){deckTileset=currentTileset;invalidateDeckCache(false);
                ++revision;controller?.abort();pending=null;pendingCenter=null;
                if(supports.length)clear(false,'tileset-replacement');}
            const flight=isNavigationActive()&&reuseFlightDeck;
            const elapsed=now()-lastRefreshAt,moved=lastCenter?distance(center,lastCenter):Infinity;
            // Tile load-progress events can fire several times per second.
            // Throttle them even when discovery has not found a bridge yet.
            // A slow GPU probe batch must be allowed to make progress while
            // the aircraft moves through the same discovery area. Abort only
            // when the old search area is genuinely behind the aircraft.
            if(pending&&pendingCenter&&distance(center,pendingCenter)<(flight?700:120))return pending;
            if(lastCenter&&moved<(flight?350:80)&&elapsed<(flight&&supports.length?8000:1500)&&
                (flight||supports.length)){
                if(metrics)metrics.refreshDeferred++;return Promise.resolve(status());
            }
            if(metrics)metrics.refreshes++;
            const previousCenter=lastCenter;
            // Aim the candidate ordering a short distance along recent
            // movement, not the tilted FPV camera's viewing direction.
            const movedMeters=previousCenter?distance(previousCenter,center):0;
            const lead=flight&&movedMeters>1?Math.min(1,120/movedMeters):0;
            const ahead=lead?{longitude:center.longitude+(center.longitude-previousCenter.longitude)*lead,
                latitude:center.latitude+(center.latitude-previousCenter.latitude)*lead}:center;
            const routeAhead=(lookahead()||[]).filter(p=>valid(p)&&distance(p,center)<=RADIUS).slice(0,3);
            const priority=p=>Math.min(distance(p,center),distance(p,ahead)+40,...routeAhead.map(q=>distance(p,q)+40));
            const token=++revision;controller?.abort();controller=new AbortController();
            const signal=controller.signal;pendingCenter={...center};lastRefreshAt=now();lastCenter={...center};
            let samplingEpoch=null;
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
                    const invalidatedSections=new Set(native.invalidatedSections||[]);
                    for(const id of invalidatedSections)validatedSupports.delete(id);
                    if(invalidatedSections.size)draw(supports.filter(p=>!invalidatedSections.has(p.id)),'source-contradiction');
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
                    // Keep the existing admission budget but resolve nearby
                    // supports first; retain the previous primitive until done.
                    candidates.sort((a,b)=>priority(a)-priority(b));
                    const mappedOnly=[...local.bridges,...remote.bridges].filter(mappedOnlyBridge);
                    if(!candidates.length){
                        // An empty native scan is not evidence that a previously
                        // validated deck vanished. Do not retain across a source
                        // change, an explicit mapped-only exclusion or outside
                        // the local search area. Age never renews on a miss.
                        const selectedNow=getDeckTileset?.();
                        const retained=reuseFlightDeck&&supportEpoch===deckEpoch&&selectedNow===deckTileset?
                            retainedPool().filter(p=>{const record=validatedSupports.get(p.id);return usableRecord(record)&&retainInArea(p,center)&&
                                !(!p.mapped&&onMappedOnlySpan(p,record.candidate.probes[0],record.candidate.probes[2],mappedOnly));}):[];
                        if(retained.length){if(metrics)metrics.retainedSupports+=retained.length;draw(retained.sort((a,b)=>priority(a)-priority(b)).slice(0,BUDGETS[profile]),'refresh-admission');}
                        else draw([],'outside-search-area');
                        if(metrics)metrics.refreshCompleted++;return status();
                    }
                    const ground=await sampleGround(candidates,signal);
                    signal.throwIfAborted?.();
                    if(token!==revision||disposed||!enabled)return status();
                    if(!ready()){clear(false,'terrain-not-ready');return status();}
                    const excluded=exclusions();
                    // A missing production tileset cannot justify sampling
                    // arbitrary building roofs for an OSINT source profile.
                    const canProbe=!getDeckTileset||!!getDeckTileset();
                    const selected=getDeckTileset?.();
                    if(selected!==deckTileset){deckTileset=selected;invalidateDeckCache(false);}
                    const progressEpoch=deckEpoch;samplingEpoch=progressEpoch;
                    const makeSupport=(i,heights)=>{
                        const p=candidates[i],base=ground?.[i];
                        if(!finite(base)||base< -500||base>9000)return null;
                        const coherent=plausibleDeck(p,heights,base);
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
                        if(!finite(deck)||gap<2.5||gap>150)return null;
                        let support={id:p.id,sourceId:p.sourceId,source:p.source||'OpenStreetMap',
                            sourceSetId:p.sourceSetId,sourceFeatureId:p.sourceFeatureId,
                            positionSourceSetId:p.positionSourceSetId,positionFeatureId:p.positionFeatureId,
                            positionSource:p.positionSource||p.source||'OpenStreetMap',mapped:!!p.mapped,heightMethod,
                            longitude:p.longitude,latitude:p.latitude,bottom:base-.3,top:deck-.1,
                            radius:p.radius||(gap>45?1:.7),quality:'simulation-only'};
                        // Record only newly validated source-backed geometry.
                        if(reuseFlightDeck){const cached=confirmedDecks.get(flightDeckKey(p))??deckCache.get(deckKey(p,base));
                            const at=cached&&coherentDeck(heights,base)&&cached.heights.every((h,k)=>h===heights[k])?cached.at:now();
                            const previous=validatedSupports.get(p.id),old=previous?.support;
                            // Native heights are sampled from different resident
                            // LODs. A cache replay isn't a new observation. Keep
                            // the actual world transform until a change is
                            // independently corroborated at the same station.
                            let record={candidate:p,base,at,support},acceptedNativeObservation=true;
                            if(p.profileMethod==='loaded-native-road'&&finite(p.observedAt)){
                                record.at=p.observedAt;
                                if(old&&previous.candidate.sourceId===p.sourceId&&old.longitude===p.longitude&&old.latitude===p.latitude){
                                    const delta=Math.max(Math.abs(old.top-support.top),Math.abs(old.bottom-support.bottom));
                                    if(delta<=.25){support=old;record={...record,support,at:Math.max(previous.at,p.observedAt)};}
                                    else {
                                        const proposal=previous.proposal;
                                        const confirmed=proposal&&p.observedAt>proposal.observedAt&&
                                            Math.abs(proposal.support.top-support.top)<=.25&&Math.abs(proposal.support.bottom-support.bottom)<=.25;
                                        if(!confirmed){
                                            record={...previous,proposal:p.observedAt>(proposal?.observedAt??previous.at)?{support,observedAt:p.observedAt}:proposal};
                                            support=old;acceptedNativeObservation=false;if(metrics)metrics.supportHeightHeld++;
                                        }
                                    }
                                }
                            }
                            if(sessionReuse&&acceptedNativeObservation&&p.nativeIdentified===true&&p.profileMethod==='loaded-native-road')commitNative(p);
                            validatedSupports.delete(p.id);validatedSupports.set(p.id,record);
                            while(validatedSupports.size>DECK_LIMIT)validatedSupports.delete(validatedSupports.keys().next().value);}
                        return support;
                    };
                    // Do not wait for every station (potentially hundreds of
                    // GPU passes) to finish before publishing the first pier.
                    // Keep previously validated candidates until this batch is
                    // complete, but never carry them across source/terrain changes.
                    const partial=new Map(),candidateKeys=new Map(candidates.map(p=>[p.id,p]));
                    // The candidate list is a bounded observation, not an authoritative
                    // inventory. A partially rediscovered source must not delete
                    // its unobserved piers. Only a validated replacement can do so.
                    const samePosition=(a,b)=>a.id===b.id&&a.sourceId===b.sourceId&&
                        a.longitude===b.longitude&&a.latitude===b.latitude;
                    const mergeRetained=(fresh,retained)=>{
                        const ids=new Set(fresh.map(p=>p.id));
                        return [...fresh,...retained.filter(old=>!ids.has(old.id)&&!fresh.some(p=>
                            distance(p,old)<(p.sourceId===old.sourceId&&!sessionReuse?8:2)&&(!old.mapped||p.mapped)&&
                            Math.abs(p.top-old.top)<=2.8))];
                    };
                    // A bounded scan can miss one of several nearby bridges.
                    // Retain nearby validated piers even if another portion of
                    // their source was rediscovered. Mapped-only spans remain authoritative.
                    const unobserved=supportEpoch===progressEpoch?retainedPool().filter(p=>{
                        const record=validatedSupports.get(p.id);
                        return usableRecord(record)&&retainInArea(p,center)&&
                            !samePosition(candidateKeys.get(p.id)||{},p)&&
                            !(!p.mapped&&onMappedOnlySpan(p,record.candidate.probes[0],record.candidate.probes[2],mappedOnly));
                    }):[];
                    const previous=supportEpoch===progressEpoch?retainedPool().filter(p=>{
                        const candidate=candidateKeys.get(p.id);
                        const record=validatedSupports.get(p.id);
                        return candidate&&usableRecord(record)&&
                            candidate.longitude===p.longitude&&candidate.latitude===p.latitude&&
                            candidate.sourceId===p.sourceId&&retainInArea(p,center);
                    }):[];
                    let lastPublish=-Infinity,dirty=false;
                    const canPublish=()=>reuseFlightDeck&&token===revision&&!signal.aborted&&!disposed&&enabled&&!frozen&&ready()&&
                        progressEpoch===deckEpoch&&getDeckTileset?.()===selected;
                    const flushProgress=(force=false)=>{
                        if(!canPublish()||!dirty||(!force&&now()-lastPublish<250))return;
                        const merged=mergeRetained([...partial.values()],[...unobserved,...previous]);
                        draw(merged.sort((a,b)=>priority(a)-priority(b)).slice(0,BUDGETS[profile]));
                        lastPublish=now();dirty=false;if(metrics)metrics.progressPublishes++;
                    };
                    const publish=(i,heights)=>{
                        if(!canPublish())return;
                        const support=makeSupport(i,heights);if(!support)return;
                        partial.set(support.id,support);dirty=true;if(candidates[i].profileMethod!=='loaded-native-road')flushProgress();
                    };
                    // Source-identified native heights need no additional GPU picks.
                    if(reuseFlightDeck){
                        for(let i=0;i<candidates.length;i++){
                            if(candidates[i].profileMethod==='loaded-native-road'&&finite(candidates[i].deckMetersWgs84))publish(i,[]);
                        }
                        flushProgress(true);
                    }
                    const sampled=canProbe?await deckSamples(candidates,ground,excluded,signal,publish):candidates.map(()=>[]);
                    if(token!==revision||signal.aborted||disposed||!enabled)return status();
                    if(!ready()){clear(false,'terrain-not-ready');return status();}
                    if(progressEpoch!==deckEpoch||getDeckTileset?.()!==selected)return status();
                    const next=candidates.map((candidate,i)=>{
                        const heights=sampled[i],support=makeSupport(i,heights);if(support)return support;
                        const old=previous.find(p=>p.id===candidate.id),record=validatedSupports.get(candidate.id);
                        // Reuse a previously validated visual pier only when
                        // the same candidate is temporarily unobservable.
                        // Finite contradictory data still removes it immediately.
                        if(!old||!usableRecord(record))return null;
                        if(finite(ground[i])&&Math.abs(ground[i]-record.base)>.25){validatedSupports.delete(candidate.id);return null;}
                        if(!finite(ground[i])){if(metrics)metrics.retainedSupports++;return old;}
                        // Ground-only hits with no identifiable loaded deck are
                        // also a visibility miss, not a new measured deck height.
                        const unloaded=heights.length>0&&heights.every(h=>!finite(h)||Math.abs(h-ground[i])<2.5);
                        if(!unloaded&&((heights.length===3&&heights.every(finite))||
                            heights.some(h=>finite(h)&&Math.abs(h-(old.top+.1))>2.8))){validatedSupports.delete(candidate.id);return null;}
                        if(metrics)metrics.retainedSupports++;return old;
                    }).filter(Boolean);
                    const combined=mergeRetained(next,unobserved).sort((a,b)=>priority(a)-priority(b)).slice(0,BUDGETS[profile]);
                    if(metrics){const retained=combined.filter(p=>unobserved.includes(p));metrics.retainedSupports+=retained.length;
                        metrics.supportRetainedSameSource+=retained.filter(p=>candidates.some(c=>c.sourceId===p.sourceId)).length;}
                    draw(combined,'refresh-admission');error=null;if(metrics)metrics.refreshCompleted++;
                    // A first local preview is not a complete scan. Permit a
                    // prompt follow-up once that geometry has been admitted.
                    if(native.partial&&combined.length)lastRefreshAt=now()-30000;
                    if(native.bridges.length||local.bridges.length||local.piers.length)refineMappedPositions(center,signal);
                    return status();
                }catch(err){
                    if(token===revision&&!signal.aborted){
                        if(samplingEpoch!==null&&samplingEpoch!==deckEpoch){
                            if(metrics)metrics.refreshInvalidated++;lastRefreshAt=-Infinity;
                        }else{error=String(err?.message||err).slice(0,160);retryAt=now()+30000;}
                        if(!ready())clear(false,'terrain-not-ready');
                    }
                    return status();
                }finally{if(token===revision){pending=null;pendingCenter=null;}}
            })();
            pending=operation;return operation;
        }
        const removeFrame=scene.preUpdate?.addEventListener?.(()=>{
            if(disposed||!enabled)return;
            if(!ready()){groundCache.clear();invalidateDeckCache();if(supports.length||pending){++revision;controller?.abort();pending=null;clear(false,'terrain-not-ready');}return;}
            if(now()-lastFrameAt<2000)return;lastFrameAt=now();
            const center=focus();
            if(frozen)return;
            const flight=isNavigationActive()&&reuseFlightDeck,elapsed=now()-lastRefreshAt;
            if(center&&(!lastCenter||distance(center,lastCenter)>(flight?250:120)||
                (!supports.length&&elapsed>2000)||elapsed>(flight?30000:15000)))void refresh(center);
        });
        function updateEnabled(){
            enabled=!benchmarkSuppressed&&(structuresEnabled||sourceSets.size>0);
            if(!enabled){++revision;controller?.abort();pending=null;pendingCenter=null;clear(false,'disabled');}
        }
        function setEnabled(value){
            if(typeof value!=='boolean')throw Error('Invalid bridge support preference');
            if(disposed||structuresEnabled===value)return {enabled:enabled&&!disposed,count:supports.length,pending:!!pending};
            structuresEnabled=value;invalidateDeckCache();if(!value)deckTileset=null;updateEnabled();return status();
        }
        function setBenchmarkSuppressed(value){
            if(typeof value!=='boolean')throw Error('Invalid benchmark support preference');
            if(disposed||benchmarkSuppressed===value)return;
            benchmarkSuppressed=value;invalidateDeckCache();updateEnabled();
            lastRefreshAt=-Infinity;
            if(enabled)void refresh();
        }
        function setSourceFeatures(features,{sourceId='osint',visible=true,...options}={}){
            if(disposed)return status();
            const data=visible?parseSourceFeatures(features,{...options,sourceId}):{bridges:[],piers:[]};
            const signature=JSON.stringify(data),previous=sourceSets.get(sourceId);
            if(previous?JSON.stringify(previous)===signature:!data.bridges.length&&!data.piers.length)return status();
            const unchanged=new Set(),nextFeatures=new Map([...data.bridges,...data.piers].map(p=>[p.id,JSON.stringify(p)]));
            for(const p of [...(previous?.bridges||[]),...(previous?.piers||[])])if(nextFeatures.get(p.id)===JSON.stringify(p))unchanged.add(p.id);
            if(data.bridges.length||data.piers.length)sourceSets.set(sourceId,data);
            else sourceSets.delete(sourceId);
            ++revision;controller?.abort();pending=null;pendingCenter=null;retryAt=-Infinity;lastRefreshAt=-Infinity;
            // This is a viewport-scoped auxiliary source, not a replacement
            // of the native Structures tileset. Preserve unrelated piers.
            const affected=p=>(p.sourceSetId===sourceId&&!unchanged.has(p.sourceFeatureId))||
                (p.positionSourceSetId===sourceId&&!unchanged.has(p.positionFeatureId));
            for(const [id,record] of validatedSupports)if(affected(record.candidate))validatedSupports.delete(id);
            const kept=supports.filter(p=>!affected(p));
            if(kept.length!==supports.length)draw(kept,'source-update');
            updateEnabled();
            if(enabled)void refresh();
            return status();
        }
        function performance(value='balanced'){
            if(!Object.hasOwn(BUDGETS,value))throw Error('Unknown bridge graphics profile');
            if(profile===value||disposed)return;profile=value;lastRefreshAt=-Infinity;
            if(supports.length>BUDGETS[profile])draw(supports.slice(0,BUDGETS[profile]),'profile-budget');
            if(enabled)void refresh();
        }
        function setOpacity(value){
            if(!finite(value)||value<.2||value>1)throw Error('Invalid bridge support opacity');
            if(opacity===value||disposed)return;opacity=value;if(supports.length)draw(supports);
        }
        function setBenchmarkMode(value=0){
            if(![0,1,2].includes(value))throw Error('Invalid benchmark support mode');
            if(benchmarkMode===value&&!frozen)return;
            frozen=false;freezeContaminated=false;benchmarkMode=value;++revision;controller?.abort();pending=null;pendingCenter=null;
            clear(false,'benchmark-mode');lastRefreshAt=-Infinity;if(enabled)void refresh();
        }
        function beginBenchmarkMeasurement(){
            if(benchmarkMode!==1)return;
            freezeContaminated=detailedActive>0;frozen=true;++revision;controller?.abort();pending=null;pendingCenter=null;
        }
        return {hasGeometry:()=>supports.length>0,setEnabled,setBenchmarkSuppressed,setBenchmarkMode,beginBenchmarkMeasurement,invalidateDeckCache,invalidateVisualPicking,invalidateLod,setSourceFeatures,refresh,performance,setOpacity,status,
            setDiagnosticsEnabled(value){if(value)metrics??={groundHits:0,groundMisses:0,groundBatches:0,groundPoints:0,groundWallMs:0,deckPicks:0,deckPickMs:0,deckHits:0,deckMisses:0,deckStaleHits:0,deckCooldownFrames:0,deckPersistentHits:0,deckStableHits:0,deckLodInvalidations:0,deckVisualInvalidations:0,supportHeightHeld:0,deckDetailedConfirmed:0,deckBaseChanged:0,deckExpired:0,deckHeightRejected:0,deckUnidentified:0,deckIncoherent:0,deckInvalidGround:0,deckGroundOnly:0,deckRetryDeferred:0,detailedRequests:0,detailedResolved:0,detailedWallMs:0,detailedDeferred:0,geometryBuilds:0,geometryBuildMs:0,refreshes:0,refreshDeferred:0,refreshCompleted:0,refreshInvalidated:0,progressPublishes:0,retainedSupports:0,supportRemovedDuringDraw:0,supportRetainedSameSource:0,supportAdded:0,supportCleared:0,supportPositionChanged:0,supportHeightChanged:0,supportRadiusChanged:0,lastRemovalReason:null,deckAdaptiveWaitMs:0,deckIndependentRechecks:0};else {metrics=null;audit.length=0;}setDiscoveryDiagnostics(value);},
            diagnostics(){let fingerprint=2166136261;if(metrics)for(const p of [...supports].sort((a,b)=>a.id.localeCompare(b.id))){
                const value=JSON.stringify([p.id,p.longitude,p.latitude,p.top,p.bottom,p.radius]);
                for(let i=0;i<value.length;i++)fingerprint=Math.imul(fingerprint^value.charCodeAt(i),16777619);
            }return metrics?{...metrics,supportTransformHash:(fingerprint>>>0).toString(16).padStart(8,'0'),sessionSupportEntries:validatedSupports.size,supportAudit:audit.join(";").slice(-200),groundCacheEntries:groundCache.size,deckCacheEntries:deckCache.size,deckConfirmedEntries:confirmedDecks.size,deckObservations:observations.size,benchmarkSuppressed,benchmarkMode,frozen,freezeContaminated,detailedActive,visibleSupports:primitive&&!hidden()?supports.length:0,computedSupports:supports.length,...discoveryDiagnostics()}:null;},
            dispose(){if(disposed)return;disposed=true;enabled=false;++revision;controller?.abort();pending=null;
                removeFrame?.();clear();cache=null;groundCache.clear();invalidateDeckCache();deckTileset=null;metrics=null;sourceSets.clear();disposeDiscovery();}};
    }
    return {create,parseBridges,parseBridgeData,parseSourceFeatures,stations,BUDGETS};
});
