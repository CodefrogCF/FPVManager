// Generic scenery catalog with optional static CPU collision assets.
(function(root,factory){
    const api=factory(typeof module==='object'&&module.exports?require('./scenery_alignment.js'):root.FPVSceneryAlignment,
        typeof module==='object'&&module.exports?require('./scenery_collision.js'):root.FPVSceneryCollision,
        typeof module==='object'&&module.exports?require('./scenery_tileset_provider.js'):root.FPVSceneryTilesets);
    if(typeof module==='object'&&module.exports)module.exports=api;else root.FPVSceneryManager=api;
})(typeof globalThis!=='undefined'?globalThis:this,function(A,Collision,Tilesets){
    'use strict';
    const ROOT='assets/scenery/';
    const catalogUrl='./'+ROOT+'catalog.json';
    const storageKey='fpvmanager.scenery.enabled.v1';
    function validate(input){
        if(!input||input.schemaVersion!==1||!Array.isArray(input.sceneries)||input.sceneries.length>64)throw Error('Invalid scenery catalog');
        const ids=new Set();
        return input.sceneries.map(item=>{
            if(!item||typeof item.id!=='string'||!/^[a-z0-9_-]{1,80}$/.test(item.id)||ids.has(item.id))throw Error('Invalid or duplicate scenery ID');
            ids.add(item.id);
            for(const k of ['name','author','license'])if(typeof item[k]!=='string'||!item[k].trim()||item[k].length>2048)throw Error('Invalid scenery '+k);
            if(item.sourceUrl!=null){const source=new URL(item.sourceUrl);if(source.protocol!=='https:'||source.username||source.password)throw Error('Invalid scenery source URL');}
            if(item.enabled!==undefined&&typeof item.enabled!=='boolean')throw Error('Invalid enabled setting');
            if(!item.alignment||!['longitude','latitude','ellipsoidHeightM','scale','rotationDeg','opacity'].every(k=>Object.hasOwn(item.alignment,k)))throw Error('Explicit alignment required');
            const alignment=A.normalize(item.alignment);
            if(item.heightDatum!=='WGS84 ellipsoid'||typeof item.physicalCollisionsEnabled!=='boolean')throw Error('Unsupported scenery height/collision configuration');
            if(item.physicalCollisionsEnabled&&(!item.collisionAsset||!/^([a-zA-Z0-9_-]+\/)*[a-zA-Z0-9_-]+\.fpc$/.test(item.collisionAsset)))throw Error('Invalid collision asset');
            if(!item.physicalCollisionsEnabled&&item.collisionAsset!==undefined)throw Error('Unexpected collision asset');
            if(item.collisionAssets!==undefined&&(!item.physicalCollisionsEnabled||!Array.isArray(item.collisionAssets)||
                !item.collisionAssets.length||item.collisionAssets.length>16||item.collisionAssets[0]!==item.collisionAsset||
                new Set(item.collisionAssets).size!==item.collisionAssets.length||
                item.collisionAssets.some(p=>typeof p!=='string'||!/^([a-zA-Z0-9_-]+\/)*[a-zA-Z0-9_-]+\.fpc$/.test(p))))throw Error('Invalid collision assets');
            if(!Array.isArray(item.assets)||!item.assets.length||item.assets.length>16)throw Error('Invalid scenery assets');
            const assets=item.assets.map(asset=>{
                if(asset?.kind==='3d-tiles')return {kind:'3d-tiles',url:Tilesets.safeUrl(asset.url),options:Tilesets.normalizeOptions(asset.options)};
                // Self-contained GLB only. No paths outside the dedicated asset root.
                if(!asset||asset.kind!=='glb'||typeof asset.path!=='string'||!/^([a-zA-Z0-9_-]+\/)*[a-zA-Z0-9_-]+\.glb$/.test(asset.path))throw Error('Invalid scenery asset');
                if(asset.managed===true){
                    if(!/^managed\/[a-f0-9]{64}\.glb$/.test(asset.path)||!['cache','server'].includes(asset.backend)||
                        !Number.isSafeInteger(asset.estimatedBytes)||asset.estimatedBytes<1||asset.estimatedBytes>128*1024*1024)throw Error('Invalid managed model');
                    if(asset.backend==='cache'&&(typeof asset.cacheRoot!=='string'||asset.cacheRoot.length>2048))throw Error('Invalid scenery cache root');
                    return {kind:'glb',path:asset.path,managed:true,backend:asset.backend,cacheRoot:asset.cacheRoot,estimatedBytes:asset.estimatedBytes};
                }
                if(asset.path.startsWith('managed/'))throw Error('Managed models require storage metadata');
                return {kind:'glb',path:asset.path};
            });
            const loadRadiusM=item.loadRadiusM??2500,unloadRadiusM=item.unloadRadiusM??4000;
            if(!Number.isFinite(loadRadiusM)||!Number.isFinite(unloadRadiusM)||loadRadiusM<100||unloadRadiusM<=loadRadiusM||unloadRadiusM>30000)throw Error('Invalid scenery activation radii');
            const heightAlignmentMode=item.heightAlignmentMode??'terrain';
            if(heightAlignmentMode!=='terrain'&&heightAlignmentMode!=='fixed')
                throw Error('Unsupported scenery height alignment mode');
            if(item.requireGroundCalibration!==undefined&&typeof item.requireGroundCalibration!=='boolean')
                throw Error('Invalid scenery terrain calibration requirement');
            if(item.requireGroundCalibration&&heightAlignmentMode!=='terrain')
                throw Error('Ground calibration requires provider-driven alignment');
            if(item.heightCalibration!==undefined){
                const c=item.heightCalibration;
                if(!c||typeof c!=='object'||Array.isArray(c)||
                    !['manual-workbench','terrain-provider-rendered-ground'].includes(c.method)||
                    typeof c.reference!=='string'||c.reference.length>256||c.surveyVerified!==false||
                    !/^[A-Za-z0-9_-]{1,32}$/.test(c.revision??''))
                    throw Error('Invalid scenery height calibration metadata');
                if(c.method==='manual-workbench'&&heightAlignmentMode!=='fixed')
                    throw Error('Manual calibration requires fixed alignment');
                if(c.method==='terrain-provider-rendered-ground'){
                    if(heightAlignmentMode!=='terrain'||!item.requireGroundCalibration||
                        !Number.isFinite(c.referenceGroundHeightM)||!Number.isFinite(c.referenceRootHeightM)||
                        !Number.isFinite(c.groundReferenceLocalUp)||
                        Math.abs(c.referenceRootHeightM-(c.referenceGroundHeightM-c.groundReferenceLocalUp*alignment.scale))>.01||
                        Math.abs(c.referenceRootHeightM-alignment.ellipsoidHeightM)>.01)
                        throw Error('Inconsistent terrain-ground reference and model root');
                }
            }
            const groundReferenceLocalUp=item.groundReferenceLocalUp;
            if(groundReferenceLocalUp!==undefined&&(!Number.isFinite(groundReferenceLocalUp)||Math.abs(groundReferenceLocalUp)>10000))throw Error('Invalid scenery ground reference');
            const buildingRegions=item.buildingRegions??(item.draftBuildingFootprintLocal?[A.projectFootprint(item.draftBuildingFootprintLocal,alignment)]:[]);
            const terrainCertificate=normalizeTerrainCertificate(item.terrainCertificate,alignment);
            const rawCertificates=item.terrainCertificates??(terrainCertificate?[item.terrainCertificate]:[]);
            if(!Array.isArray(rawCertificates)||rawCertificates.length>16)throw Error('Invalid terrain certificate list');
            const terrainCertificates=rawCertificates.map(c=>normalizeTerrainCertificate(c,alignment));
            const u=item.terrainUnderlay;
            if(u&&(typeof u!=='object'||!/^([a-zA-Z0-9_-]+\/)*[a-zA-Z0-9_-]+\.glb$/.test(u.asset)||
                !/^([a-zA-Z0-9_-]+\/)*[a-zA-Z0-9_-]+\.fpc$/.test(u.collisionAsset)||
                !u.certificate))throw Error('Invalid optional DGM underlay');
            const terrainUnderlay=u?{...u,certificate:{...normalizeTerrainCertificate(u.certificate,alignment),source:'underlay'}}:null;
            if(terrainUnderlay&&(!terrainCertificate||terrainUnderlay.certificate.collisionSha256===terrainCertificate.collisionSha256||
                !Array.isArray(item.terrainRegions)||!item.terrainRegions.some(p=>JSON.stringify(p)===JSON.stringify(terrainUnderlay.certificate.polygon))))
                throw Error('Mismatched DGM underlay coverage or asset');
            if(terrainCertificates.some(c=>!c||!terrainCertificate||c.collisionSha256!==terrainCertificate.collisionSha256)||
                (terrainCertificate&&JSON.stringify(terrainCertificates[0])!==JSON.stringify(terrainCertificate))||new Set(terrainCertificates.map(c=>JSON.stringify(c.polygon))).size!==terrainCertificates.length)throw Error('Mismatched terrain certificate list');
            return {...item,...A.normalizeEdit({...item,alignment,buildingRegions},alignment),heightAlignmentMode,terrainCertificate,terrainCertificates,terrainUnderlay,assets,loadRadiusM,unloadRadiusM,enabled:item.enabled!==false};
        });
    }
    // Certified ground patch is an offline geometry coverage proof, not an altitude survey.
    function normalizeTerrainCertificate(c,alignment){
        if(c===undefined)return null;
        if(!c||!Array.isArray(c.localBounds)||c.localBounds.length!==4||!c.localBounds.every(Number.isFinite)||
            !Array.isArray(c.localGroundRange)||c.localGroundRange.length!==2||!c.localGroundRange.every(Number.isFinite)||
            !/^[0-9a-f]{64}$/.test(c.collisionSha256)||!Number.isFinite(c.coverageMarginLocal)||c.coverageMarginLocal<.02)throw Error('Invalid terrain coverage certificate');
        if(c.seamToleranceM!==undefined&&(!Number.isFinite(c.seamToleranceM)||c.seamToleranceM<.05||c.seamToleranceM>.5))throw Error('Invalid terrain seam tolerance');
        const [x0,y0,x1,y1]=c.localBounds,[z0,z1]=c.localGroundRange;
        if(x1-x0<.1||y1-y0<.1||z1<=z0||Math.max(...c.localBounds.map(Math.abs),Math.abs(z0),Math.abs(z1))>100)throw Error('Invalid terrain coverage bounds');
        return {...c,polygon:A.projectFootprint([[x0,y0],[x1,y0],[x1,y1],[x0,y1]],alignment)};
    }
    function insideGroundPatch(p,c,scale){
        const [x0,y0,x1,y1]=c.localBounds,margin=Math.max(.035,.55/scale);
        return p[0]>x0+margin&&p[0]<x1-margin&&p[1]>y0+margin&&p[1]<y1-margin;
    }
    function groundLocal(mesh,c,p){
        const [lo,hi]=c.localGroundRange,epsilon=1e-5;
        const hit=Collision.sweep(mesh,[p[0],p[1],hi+epsilon],[p[0],p[1],lo-epsilon],epsilon);
        return hit?hi+epsilon-(hi-lo+2*epsilon)*hit.fraction-epsilon:undefined;
    }
    function patchInterval(a,b,c,scale){
        const [x0,y0,x1,y1]=c.localBounds,margin=Math.max(.035,.55/scale)+1e-9;
        const low=[x0+margin,y0+margin],high=[x1-margin,y1-margin];let start=0,end=1;
        for(let i=0;i<2;i++){
            if(low[i]>=high[i])return null;
            const delta=b[i]-a[i];
            if(Math.abs(delta)<1e-12){if(a[i]<low[i]||a[i]>high[i])return null;continue;}
            const t0=(low[i]-a[i])/delta,t1=(high[i]-a[i])/delta;
            start=Math.max(start,Math.min(t0,t1));end=Math.min(end,Math.max(t0,t1));if(start>end)return null;
        }
        return [start,end];
    }
    function segmentCovered(a,b,patches,scale){
        const intervals=patches.map(c=>patchInterval(a,b,c,scale)).filter(Boolean).sort((x,y)=>x[0]-y[0]);let end=0;
        for(const interval of intervals){if(interval[0]>end+1e-10)return false;end=Math.max(end,interval[1]);if(end>=1-1e-10)return true;}
        return false;
    }
    function seamPoints(c,alignment,maxStepM=3){
        const [x0,y0,x1,y1]=c.localBounds,coords=[[x0,y0],[x1,y0],[x1,y1],[x0,y1]],result=[];
        const angle=-alignment.rotationDeg*Math.PI/180,cos=Math.cos(angle),sin=Math.sin(angle);
        for(let i=0;i<4;i++){
            const a=coords[i],b=coords[(i+1)%4],n=Math.max(1,Math.ceil(Math.hypot(b[0]-a[0],b[1]-a[1])*alignment.scale/maxStepM));
            if(n>512||result.length+n>2048)return [];
            for(let j=0;j<n;j++){
                const x=a[0]+(b[0]-a[0])*j/n,y=a[1]+(b[1]-a[1])*j/n;
                result.push(A.offset(alignment,alignment.scale*(cos*x-sin*y),alignment.scale*(sin*x+cos*y)));
            }
        }
        return result;
    }
    function evaluateSeam(mesh,frame,cert,points,heights){
        if(!Array.isArray(heights)||heights.length!==points.length)return {approved:false,maxErrorM:null,samples:0};
        let max=0;
        for(let i=0;i<points.length;i++){
            if(!Number.isFinite(heights[i]))return {approved:false,maxErrorM:null,samples:i};
            const local=frame.local({...points[i],height:heights[i]}),z=groundLocal(mesh,cert,local);
            if(!Number.isFinite(z))return {approved:false,maxErrorM:null,samples:i};
            max=Math.max(max,Math.abs(z-local[2])*frame.scale);
        }
        return {approved:max<=cert.seamToleranceM,maxErrorM:max,samples:points.length};
    }
    async function verifyTerrainAsset(mesh,certificate){
        if(!certificate||!globalThis.crypto?.subtle||!mesh.vertices?.buffer)return false;
        try{const hash=await globalThis.crypto.subtle.digest('SHA-256',mesh.vertices.buffer);return Array.from(new Uint8Array(hash),x=>x.toString(16).padStart(2,'0')).join('')===certificate.collisionSha256;}catch(_){return false;}
    }
    function distanceM(a,b){
        const rad=Math.PI/180,dlat=(b.latitude-a.latitude)*rad,dlon=(b.longitude-a.longitude)*rad;
        const h=Math.sin(dlat/2)**2+Math.cos(a.latitude*rad)*Math.cos(b.latitude*rad)*Math.sin(dlon/2)**2;
        return 6371008.8*2*Math.asin(Math.sqrt(Math.min(1,h)));
    }
    // Use the terrain triangles actually rendered by Cesium for BKG beta
    // calibration. Cesium sampleTerrain() may report a different level of
    // detail or an unverified vertical datum; never silently mix the two.
    // Picking is restricted to the Globe (not the local scenery or LoD2).
    function pickRenderedGroundHeights(C,viewer,positions){
        if(!Array.isArray(positions))throw Error('Invalid scenery ground positions');
        const result=[];
        const globe=viewer?.scene?.globe;
        for(const point of positions){
            let height=NaN;
            if(globe?.pick&&C?.Cartesian3?.fromRadians&&C?.Cartesian3?.negate&&
                C?.Ellipsoid?.WGS84?.geodeticSurfaceNormal&&C?.Ray&&C?.Cartographic?.fromCartesian&&
                Number.isFinite(point?.longitude)&&Number.isFinite(point?.latitude)){
                try{
                    const origin=C.Cartesian3.fromRadians(point.longitude,point.latitude,10000,C.Ellipsoid.WGS84);
                    const normal=C.Ellipsoid.WGS84.geodeticSurfaceNormal(origin,new C.Cartesian3());
                    const direction=C.Cartesian3.negate(normal,new C.Cartesian3());
                    const hit=globe.pick(new C.Ray(origin,direction),viewer.scene);
                    if(hit){
                        const cart=C.Cartographic.fromCartesian(hit,C.Ellipsoid.WGS84);
                        if(Number.isFinite(cart?.height))height=cart.height;
                    }
                }catch(_){/* Missing resident terrain is not an elevation. */}
            }
            result.push(height);
        }
        return result;
    }
    async function sampleAnchorGround(C,viewer,alignment,{regional=false,sample}={}){
        const point=C.Cartographic.fromDegrees(alignment.longitude,alignment.latitude);
        let height;
        if(regional){
            // Relative placement follows the *displayed* surface, without
            // pretending a raw provider height has a verified absolute datum.
            const globe=viewer.scene.globe;
            if(globe.tilesLoaded===false||!Number.isFinite(globe.getHeight?.(point)))throw Error('Local terrain is not resident at the model anchor');
            height=pickRenderedGroundHeights(C,viewer,[point])[0];
        }else height=(await sample([point]))?.[0]?.height;
        if(!Number.isFinite(height))throw Error('Terrain is unavailable at the model anchor');
        return height;
    }
    // Estimate the active-renderer ground height at the catalog reference from
    // multiple scan-surveyed ground points. Ignore invalid tiles and outliers;
    // a single anomalous terrain sample must never lift the entire plant.
    // Input ground controls are local model coordinates (unscaled, Z up).
    function fitGroundReference(controls,heights,referenceLocalUp,scale){
        if(!Array.isArray(controls)||!Array.isArray(heights)||controls.length!==heights.length||
            !Number.isFinite(referenceLocalUp)||!Number.isFinite(scale)||scale<=0)throw Error('Invalid scenery ground controls');
        const values=[];
        for(let i=0;i<controls.length;i++){
            const z=controls[i]?.[2],h=heights[i];
            if(Number.isFinite(z)&&Number.isFinite(h))values.push(h+(referenceLocalUp-z)*scale);
        }
        if(values.length<3)throw Error('Insufficient reliable scenery terrain samples');
        values.sort((a,b)=>a-b);
        const median=a=>a.length%2?a[(a.length-1)/2]:(a[a.length/2-1]+a[a.length/2])/2;
        const pivot=median(values),inliers=values.filter(v=>Math.abs(v-pivot)<=6);
        if(inliers.length<3)throw Error('Inconsistent scenery terrain samples');
        return median(inliers);
    }
    // A reference point on the model ground near its horizontal anchor, in
    // unscaled local up units, not the lowest vertex or bounding-sphere bottom.
    function terrainAligned(item,height){
        if(!Number.isFinite(height)||!Number.isFinite(item.groundReferenceLocalUp))throw Error('Invalid terrain alignment sample');
        return A.normalize({...item.alignment,ellipsoidHeightM:height-item.groundReferenceLocalUp*item.alignment.scale+(item.heightOffsetM??0)});
    }
    async function managedModelUrl(asset,{baseUrl=globalThis.location?.href,cacheStorage=globalThis.caches,crypto=globalThis.crypto,urls=globalThis.URL}={}){
        if(asset.backend==='server')return {url:'./'+ROOT+asset.path,release(){}};
        const base=new URL(baseUrl),root=new URL(asset.cacheRoot);
        if(root.origin!==base.origin||root.search||root.hash||!root.pathname.endsWith('/scenery-local/v1/'))throw Error('Invalid scenery cache origin');
        const key=asset.path.split('/').at(-1);
        if(!/^[a-f0-9]{64}\.glb$/.test(key))throw Error('Invalid scenery cache key');
        if(!cacheStorage||!crypto?.subtle)throw Error('Local scenery requires secure browser storage');
        const cache=await cacheStorage.open('fpvmanager-scenery-v1:'+root.href);
        // Cache-only lookup: an evicted local model must never turn into a
        // network request to the app host or to an original asset provider.
        const response=await cache.match(root.href+key);
        if(!response||!response.ok)throw Error('Local scenery file is unavailable. Reimport the model on this device.');
        const reader=response.body?.getReader();if(!reader)throw Error('Empty local scenery file');
        const chunks=[];let total=0;
        try{for(;;){const {value,done}=await reader.read();if(done)break;total+=value.byteLength;
            if(total>64*1024*1024)throw Error('Local scenery exceeds 64 MiB');chunks.push(value);}}
        catch(error){await reader.cancel().catch(()=>{});throw error;}finally{reader.releaseLock();}
        const bytes=new Uint8Array(total);let offset=0;for(const chunk of chunks){bytes.set(chunk,offset);offset+=chunk.length;}
        const hash=Array.from(new Uint8Array(await crypto.subtle.digest('SHA-256',bytes)),x=>x.toString(16).padStart(2,'0')).join('');
        if(hash+'.glb'!==key)throw Error('Local scenery checksum mismatch. Reimport the model.');
        const url=urls.createObjectURL(new Blob([bytes],{type:'model/gltf-binary'}));let released=false;
        return {url,release(){if(!released){released=true;urls.revokeObjectURL(url);}}};
    }
    function create(C,viewer,{fetchCatalog=()=>fetch(catalogUrl,{cache:'no-store'}).then(r=>{if(!r.ok)throw Error('Scenery catalog HTTP '+r.status);return r.json();}),
        debugWireframe=false,
        managedUrl=managedModelUrl,
        tilesetFactory=(url,options,signal)=>Tilesets.load(C,url,options,{signal}),
        probeTileset=(url,options)=>Tilesets.probe(C,url,options),
        canStreamRemote=()=>globalThis.navigator?.onLine!==false,flightPosition=()=>null,maxActiveTilesets=4,
        modelFactory=(url,config,credit)=>C.Model.fromGltfAsync({url,modelMatrix:A.modelMatrix(C,config),scale:config.scale,allowPicking:true,enableCollision:false,enableDebugWireframe:debugWireframe,debugWireframe,credit,showCreditsOnScreen:true}),
        collisionFactory=(url,signal)=>Collision.load(url,signal),
        position=()=>{const x=viewer.camera.positionCartographic;return {latitude:C.Math.toDegrees(x.latitude),longitude:C.Math.toDegrees(x.longitude),height:x.height};},
        onStatus=()=>{},storage,now=()=>Date.now(),setTimer=setTimeout,clearTimer=clearTimeout,timeoutMs=60000,canLoad=()=>true,terrainKey=()=>null,terrainStable=()=>true,sampleGround=async()=>NaN,sampleSeamGround=null,terrainMaskActive=()=>false,regionalHeightMode=()=>false}={}){
        let unavailableEntries=[],initialCatalog=null;
        let disposed=false,entries=new Map(),lastTick=-Infinity,catalogRevision=0,tileReadyRetryTimer=null,probeAbort=null;
        const display=viewer.cesiumWidget?.creditDisplay;
        try{storage??=globalThis.localStorage;}catch(_){}
        let prefs={};try{const parsed=JSON.parse(storage?.getItem(storageKey)||'{}');if(parsed&&typeof parsed==='object'&&!Array.isArray(parsed))prefs=parsed;}catch(_){}
        function publish(e,state,message=null,category=null){e.state=state;e.message=message;e.errorCategory=category;onStatus({id:e.item.id,state,message,category,visualOnly:!collisionReady(e)});}
        const modelReleases=new WeakMap();
        const remoteAssets=new WeakMap();
        const hasRemote=e=>e.item.assets.some(a=>a.kind==='3d-tiles');
        function applyVisual(model,config){
            const remote=remoteAssets.get(model);
            if(remote){Tilesets.applyCorrection(C,model,remote.pivot,remote.asset.options.correction,remote.original);
                model.style=config.opacity<1?new C.Cesium3DTileStyle({color:`color('white', ${config.opacity})`}):remote.style;}
            else A.apply(C,model,config);
        }
        function rebalanceRemoteCache(){
            const models=Array.from(entries.values()).flatMap(e=>e.models.filter(m=>remoteAssets.has(m)));
            for(const model of models){model.cacheBytes=Math.floor(128*1024*1024/models.length);model.maximumCacheOverflowBytes=0;}
        }
        function remoteStatus(e){
            const models=e.models.filter(m=>remoteAssets.has(m));
            return {remote:hasRemote(e),errorCategory:e.errorCategory??null,streamingState:e.streamingState??null,tileFailures:e.tileFailures??0,tileError:e.tileError??null,
                tileErrorCategory:e.tileErrorCategory??null,remoteBytes:models.reduce((n,m)=>n+(m.totalMemoryUsageInBytes??0),0)};
        }
        function remoteDistance(e,asset,point){
            const model=e.models.find(m=>remoteAssets.get(m)?.asset===asset),sphere=model?.boundingSphere;
            if(sphere&&[sphere.center?.x,sphere.center?.y,sphere.center?.z,sphere.radius].every(Number.isFinite)){
                return Math.max(0,C.Cartesian3.distance(C.Cartesian3.fromDegrees(point.longitude,point.latitude,point.height),sphere.center)-sphere.radius);
            }
            return Tilesets.distance(C,point,asset.options.boundingSphere,e.item.alignment,asset.options.correction);
        }
        async function inspectTileset(url,cachePolicy,signal){
            if(disposed||!canStreamRemote())throw Error('External tilesets require an online globe.');
            probeAbort?.abort();const abort=new AbortController();probeAbort=abort;
            const cancel=()=>abort.abort();signal?.addEventListener?.('abort',cancel,{once:true});if(signal?.aborted)cancel();
            try{return await probeTileset(url,{cachePolicy,signal:abort.signal});}
            catch(error){const detail=Tilesets.describe(error);throw Error(`${detail.category}: ${detail.message}`);}
            finally{signal?.removeEventListener?.('abort',cancel);if(probeAbort===abort)probeAbort=null;}
        }
        function disposeModel(model,added){try{if(added)viewer.scene.primitives.remove(model);else if(!model.isDestroyed?.())model.destroy?.();}finally{modelReleases.get(model)?.();modelReleases.delete(model);}}
        function effectiveOffset(e){return (e.item.heightOffsetM??0)+(regionalHeightMode()?(e.item.bkgHeightOffsetM??0):0);}
        function aligned(e,height){return terrainAligned({...e.item,heightOffsetM:effectiveOffset(e)},height);}
        function original(e){
            const a=A.normalize({...e.item.alignment,ellipsoidHeightM:e.item.alignment.ellipsoidHeightM+effectiveOffset(e)}),remote=e.item.assets.find(x=>x.kind==='3d-tiles');
            return remote&&(e.item.physicalCollisionsEnabled||e.item.assets.some(x=>x.kind==='glb'))
                ?A.transformed(C,a,Tilesets.correctionMatrix(C,e.item.alignment,remote.options.correction)):a;
        }
        function releaseUnderlay(e){
            clearSeams(e);e.groundRevision=(e.groundRevision??0)+1;e.groundAbort?.abort();e.groundAbort=null;
            if(e.groundModel){disposeModel(e.groundModel,true);e.groundModel=null;}
            e.groundCollider=null;e.groundVerified=false;e.groundState='idle';e.groundError=null;
        }
        function remove(e){e.remoteAbort?.abort();e.remoteAbort=null;for(const release of e.pendingResources??[])release();e.pendingResources?.clear();clearTimer(e.heightSampleTimer);e.heightSampleTimer=null;clearTimer(e.heightRetryTimer);e.heightRetryTimer=null;releaseUnderlay(e);e.revision++;e.collisionAbort?.abort();clearTimer(e.collisionTimer);e.collisionTimer=null;e.collisionAbort=null;e.collider=null;e.colliders=[];e.terrainAssetVerified=false;e.collisionFrame=null;e.collisionAlignment=null;e.collisionState='idle';e.collisionError=null;e.lastHit=null;e.previewHidden=false;e.heightRevision=(e.heightRevision??0)+1;e.heightKey=null;e.heightPending=false;e.heightState=null;e.heightError=null;e.heightRetryAt=0;e.effectiveAlignment=original(e);e.groundHeightM=null;clearTimer(e.timer);e.timer=null;for(const model of e.models)disposeModel(model,true);e.models=[];rebalanceRemoteCache();e.ready=false;if(e.credit){display?.removeStaticCredit(e.credit);e.credit=null;}}
        function escape(v){return String(v).replaceAll('&','&amp;').replaceAll('<','&lt;').replaceAll('>','&gt;').replaceAll('"','&quot;');}
        // An estimated DGM1 absolute fallback is not visual evidence that the
        // active BKG/other terrain is aligned. Hide scenery until actual
        // terrain-surface measurements have been applied, rather than rendering
        // its roofs under the terrain (or floating above it) during loading.
        function syncCalibrationVisibility(e){
            if(!e.item.requireGroundCalibration)return;
            const visible=!e.previewHidden&&e.heightState==='adjusted'&&e.heightKey!=null&&e.heightKey===terrainKey();
            for(const model of e.models){
                if(model.show!==visible){model.show=visible;viewer.scene.requestRender?.();}
            }
        }
        // Regional DGM5 can have a ready terrain provider before Cesium has
        // rendered any tiles at the scenery location. A failed first pick must
        // recover automatically even when no further camera/scene events occur.
        function scheduleHeightRetry(e){
            clearTimer(e.heightRetryTimer);e.heightRetryTimer=null;
            if(disposed||!e.enabled||!canLoad()||e.state==='idle'||e.heightKey==null)return;
            const delay=Math.max(0,(e.heightRetryAt??0)-now());
            e.heightRetryTimer=setTimer(()=>{
                e.heightRetryTimer=null;
                if(!disposed&&e.enabled&&e.state!=='idle')tick(true);
            },delay);
        }
        function updateHeight(e){
            if(e.item.heightAlignmentMode==='fixed'){
                // Manual workbench alignment is an explicit vertical placement.
                // Do not silently override it after a provider switch / delayed
                // sample, and do not apply an unverified BKG geoid subtraction.
                if(e.heightState!=='fixed'){
                    e.heightRevision=(e.heightRevision??0)+1;
                    e.heightState='fixed';e.heightKey=null;
                    e.heightPending=false;e.heightRetryAt=0;e.groundHeightM=null;
                    e.effectiveAlignment=original(e);
                    for(const model of e.models)applyVisual(model,e.effectiveAlignment);
                    if(e.groundModel)A.apply(C,e.groundModel,e.effectiveAlignment);
                    viewer.scene.requestRender?.();
                }
                return;
            }
            if(!Number.isFinite(e.item.groundReferenceLocalUp))return;
            const key=terrainKey()??null;
            if(e.heightKey!==key){
                clearTimer(e.heightSampleTimer);e.heightSampleTimer=null;
                clearSeams(e);clearTimer(e.heightRetryTimer);e.heightRetryTimer=null;
                e.heightRevision=(e.heightRevision??0)+1;e.heightKey=key;e.heightPending=false;e.heightRetryAt=0;
                e.heightState=key===null?'original':'pending';e.heightError=null;e.groundHeightM=null;e.effectiveAlignment=original(e);
                for(const model of e.models)applyVisual(model,e.effectiveAlignment);if(e.groundModel)A.apply(C,e.groundModel,e.effectiveAlignment);
                viewer.scene.requestRender?.();
            }
            syncCalibrationVisibility(e);
            if(key===null||e.heightPending||e.heightState==='adjusted'||now()<(e.heightRetryAt??0))return;
            const rev=e.revision,hrev=e.heightRevision;
            const current=()=>!disposed&&e.revision===rev&&e.heightRevision===hrev&&terrainKey()===key;
            e.heightPending=true;e.heightState='pending';
            e.heightSampleTimer=setTimer(()=>{if(current()){remove(e);publish(e,'error','Terrain alignment timed out. Retry when local terrain is available.');}},timeoutMs);
            Promise.resolve().then(()=>sampleGround(e.item.alignment,e.item)).then(height=>{
                if(!current())return;
                const cfg=aligned(e,height);
                for(const model of e.models)applyVisual(model,cfg);if(e.groundModel)A.apply(C,e.groundModel,cfg);
                e.effectiveAlignment=cfg;e.groundHeightM=height;e.heightState='adjusted';e.heightError=null;
                clearTimer(e.heightRetryTimer);e.heightRetryTimer=null;
                syncCalibrationVisibility(e);
                viewer.scene.requestRender?.();
            }).catch(error=>{if(current()){
                e.heightState='unavailable';e.heightRetryAt=now()+(regionalHeightMode()?2500:10000);
                e.heightError=String(error?.message??error);
                syncCalibrationVisibility(e);scheduleHeightRetry(e);
            }})
              .finally(()=>{if(current()){clearTimer(e.heightSampleTimer);e.heightSampleTimer=null;e.heightPending=false;}});
        }
        function heightReady(e){
            if(e.item.requireGroundCalibration)return e.heightState==='adjusted'&&e.heightKey!=null&&e.heightKey===terrainKey();
            return e.item.heightAlignmentMode==='fixed'||terrainKey()==null||!Number.isFinite(e.item.groundReferenceLocalUp)||(e.heightState==='adjusted'&&e.heightKey===terrainKey());
        }
        function collisionReady(e){return !!(e.ready&&e.enabled&&e.collider&&e.item.physicalCollisionsEnabled&&e.item.alignment.opacity>=.99&&terrainStable()&&heightReady(e));}
        function loadCollider(e,rev){
            if(!e.item.physicalCollisionsEnabled)return;
            const abort=new AbortController();e.collisionAbort=abort;e.collisionState='loading';
            e.collisionTimer=setTimer(()=>{if(e.revision===rev&&!abort.signal.aborted){abort.abort();e.collider=null;e.collisionState='error';e.collisionError='Collision asset load timed out';e.collisionTimer=null;}},timeoutMs);
            const current=()=>!disposed&&e.revision===rev&&!abort.signal.aborted;
            Promise.resolve().then(async()=>{
                const meshes=[];
                for(const path of e.item.collisionAssets??[e.item.collisionAsset]){
                    if(!current())return null;
                    meshes.push(await collisionFactory('./'+ROOT+path,abort.signal));
                }
                return meshes;
            }).then(meshes=>{
                if(!meshes||!current())return;
                e.colliders=meshes;const mesh=meshes[0];
                if(!current())return;clearTimer(e.collisionTimer);e.collisionTimer=null;e.collider=mesh;e.collisionState='ready';e.collisionError=null;viewer.scene.requestRender?.();
                if(e.base.terrainCertificate)void verifyTerrainAsset(mesh,e.base.terrainCertificate).then(ok=>{if(current()&&e.collider===mesh){e.terrainAssetVerified=ok;viewer.scene.requestRender?.();}});
            }).catch(error=>{if(current()){clearTimer(e.collisionTimer);e.collisionTimer=null;e.collider=null;e.collisionState='error';e.collisionError=String(error?.message||error);}});
        }
        function wantsUnderlay(e){
            return !!(terrainKey()!=null&&terrainStable()&&e.base.terrainUnderlay&&e.item.clipTerrain&&e.item.terrainRegions.some(p=>
                JSON.stringify(p)===JSON.stringify(e.base.terrainUnderlay.certificate.polygon)));
        }
        function loadUnderlay(e,rev){
            if(!wantsUnderlay(e)||e.groundState&&e.groundState!=='idle')return;
            const underlay=e.base.terrainUnderlay,abort=new AbortController(),groundRev=(e.groundRevision??0)+1;
            e.groundRevision=groundRev;e.groundAbort=abort;e.groundState='loading';
            const current=()=>!disposed&&!abort.signal.aborted&&e.revision===rev&&e.groundRevision===groundRev&&wantsUnderlay(e);
            const credit=new C.Credit('© GeoBasis-DE/LGB (dl-de/by-2-0) · GCG2016 © BKG (CC BY 4.0) · DGM1 experimental underlay',true);
            (async()=>{
                let model=null;
                try{
                    const results=await Promise.all([
                        modelFactory('./'+ROOT+underlay.asset,e.effectiveAlignment??e.item.alignment,credit),
                        collisionFactory('./'+ROOT+underlay.collisionAsset,abort.signal)]);
                    model=results[0];const mesh=results[1];
                    if(!current()){disposeModel(model,false);return;}
                    applyVisual(model,e.effectiveAlignment??e.item.alignment);model.show=false;
                    viewer.scene.primitives.add(model);e.groundModel=model;model=null;
                    e.groundCollider=mesh;
                    const verified=await verifyTerrainAsset(mesh,underlay.certificate);
                    if(!current())return;
                    e.groundVerified=verified;e.groundState=verified?'ready':'error';
                    if(!verified)e.groundError='DGM1 collider hash mismatch or unavailable crypto';
                    clearSeams(e);viewer.scene.requestRender?.();
                }catch(error){if(model)disposeModel(model,false);if(current()){e.groundState='error';e.groundError=String(error?.message??error);}}
            })();
        }
        // A terrain model is never drawn before a *real* Cesium terrain clipping
        // polygon is active and the provider seam has passed. No visual/physical
        // ground geometry on unsupported devices or incomplete network loads.
        function syncUnderlay(e){
            if(!e.groundModel)return;
            const visible=e.groundVerified&&e.groundModel.ready===true&&verifiedPatches(e).some(c=>
                c.source==='underlay'&&terrainMaskActive(c.polygon));
            if(e.groundModel.show!==!!visible){e.groundModel.show=!!visible;viewer.scene.requestRender?.();}
        }
        function groundMesh(e,c){return c.source==='underlay'?e.groundCollider:e.collider;}
        async function load(e){
            const rev=++e.revision;e.effectiveAlignment=original(e);publish(e,'loading');
            e.remoteAbort=new AbortController();e.tileFailures=0;e.tileError=null;e.tileErrorCategory=null;e.streamingState=hasRemote(e)?'loading':null;
            const current=()=>!disposed&&e.revision===rev;
            e.timer=setTimer(()=>{if(current()){remove(e);publish(e,'error','Scenery load timed out');}},timeoutMs);
            try{
                const remoteCount=e.item.assets.filter(a=>a.kind==='3d-tiles').length;
                const occupiedRemote=Array.from(entries.values()).filter(x=>x!==e&&['loading','ready'].includes(x.state)).reduce((n,x)=>n+x.item.assets.filter(a=>a.kind==='3d-tiles').length,0);
                if(remoteCount+occupiedRemote>maxActiveTilesets){remove(e);publish(e,'unavailable','External scenery capacity reached. Disable another nearby provider.','RESOURCE_LIMIT');return;}
                const required=e.item.assets.reduce((n,a)=>n+(a.managed?a.estimatedBytes:0),0);
                const occupied=Array.from(entries.values()).filter(x=>x!==e&&['loading','ready'].includes(x.state)).reduce((n,x)=>n+x.item.assets.reduce((n,a)=>n+(a.managed?a.estimatedBytes:0),0),0);
                if(required+occupied>128*1024*1024)throw Error('Active local scenery exceeds the 128 MiB decoded resource budget. Disable another local model.');
                // Sequential loads cap concurrent GPU uploads; cancelled models cannot be attached later.
                for(const [assetIndex,asset] of e.item.assets.entries()){
                    const title=e.item.sourceUrl?`<a href="${escape(e.item.sourceUrl)}" target="_blank" rel="noopener">${escape(e.item.name)}</a>`:escape(e.item.name);
                    const credit=new C.Credit(`${escape(e.item.author)} · ${title} · ${escape(e.item.license)} · ${escape(e.item.attribution??'')} · georeferenced placement; experimental simulation only`,true);
                    if(asset.kind==='3d-tiles'){
                        const model=await tilesetFactory(asset.url,asset.options,e.remoteAbort.signal);
                        if(!current()){disposeModel(model,false);return;}
                        const stops=[];remoteAssets.set(model,{asset:e.item.assets[assetIndex],index:assetIndex,pivot:e.preview?.item.alignment??e.item.alignment,original:C.Matrix4.clone(model.modelMatrix??C.Matrix4.IDENTITY),style:model.style});
                        modelReleases.set(model,()=>{for(const stop of stops)stop?.();});
                        try{
                            applyVisual(model,e.item.alignment);
                            const fail=error=>{if(current()){
                                const detail=Tilesets.describe(error);e.tileFailures=Math.min(1000000,(e.tileFailures??0)+1);e.tileError=detail.message;e.tileErrorCategory=detail.category;e.streamingState='degraded';viewer.scene.requestRender?.();
                                if(e.lastTileNotice===undefined||now()-e.lastTileNotice>=1000){e.lastTileNotice=now();onStatus({id:e.item.id,state:e.state,message:detail.message,category:detail.category,visualOnly:!collisionReady(e)});}
                            }};
                            stops.push(model.tileFailed?.addEventListener(fail));
                            stops.push(model.tileLoad?.addEventListener(()=>{if(current()){e.streamingState='streaming';e.tileError=null;e.tileErrorCategory=null;}}));
                            stops.push(model.allTilesLoaded?.addEventListener(()=>{if(current()&&e.streamingState!=='degraded')e.streamingState='ready';}));
                            viewer.scene.primitives.add(model);e.models.push(model);rebalanceRemoteCache();
                            if(!e.credit){e.credit=credit;display?.addStaticCredit(credit);}
                        }catch(error){disposeModel(model,false);throw error;}
                        continue;
                    }
                    const acquired=asset.managed?await managedUrl(asset):{url:'./'+ROOT+asset.path,release(){}};
                    let released=false;
                    const resource={url:acquired.url,release(){if(!released){released=true;acquired.release();}}};
                    if(!current()){resource.release();return;}
                    e.pendingResources??=new Set();e.pendingResources.add(resource.release);
                    let model;
                    try{model=await modelFactory(resource.url,e.item.alignment,credit);}catch(error){e.pendingResources.delete(resource.release);resource.release();throw error;}
                    e.pendingResources.delete(resource.release);
                    let offError;
                    modelReleases.set(model,()=>{offError?.();resource.release();});
                    offError=model.errorEvent?.addEventListener(error=>{
                        if(current()){remove(e);publish(e,'error',String(error?.message||error));}
                    });
                    if(!current()){disposeModel(model,false);return;}
                    try{
                        applyVisual(model,e.effectiveAlignment??e.item.alignment);
                        model.show=!e.item.requireGroundCalibration;
                        // Height fitting can finish before the GLB upload.
                        // Newly attached models must inherit the fitted state.
                        if(debugWireframe)model.debugWireframe=true;
                        viewer.scene.primitives.add(model);e.models.push(model);
                        syncCalibrationVisibility(e);
                        if(!e.credit){e.credit=credit;display?.addStaticCredit(credit);}
                    }catch(error){disposeModel(model,false);throw error;}
                }
                if(current())loadCollider(e,rev);
                viewer.scene.requestRender?.();
            }catch(error){if(current()){remove(e);const detail=hasRemote(e)?Tilesets.describe(error):null;publish(e,'error',detail?.message??String(error?.message||error),detail?.category??null);}}
        }
        function tick(force=false){
            if(disposed)return;
            const t=now();if(!force&&t-lastTick<500)return;lastTick=t;
            const p=position();if(!p||![p.latitude,p.longitude,p.height].every(Number.isFinite))return;
            const airborne=flightPosition();const positions=[p,...(airborne&&[airborne.latitude,airborne.longitude,airborne.height].every(Number.isFinite)?[airborne]:[])];
            for(const e of entries.values()){
                const d=Math.min(...positions.map(point=>Math.min(...e.item.assets.map(asset=>asset.kind==='3d-tiles'
                    ?remoteDistance(e,asset,point)
                    :Math.hypot(distanceM(e.item.alignment,point),Math.max(0,point.height-e.item.alignment.ellipsoidHeightM))))));
                if(!e.enabled||!canLoad()||!e.preview&&d>e.item.unloadRadiusM){if(e.state!=='idle'){remove(e);publish(e,'idle');}continue;}
                if(hasRemote(e)&&!canStreamRemote()){
                    if(e.state!=='unavailable'||e.errorCategory!=='OFFLINE'){remove(e);publish(e,'unavailable','External tilesets require an online globe; no offline provider cache is created.','OFFLINE');}continue;
                }
                if(e.state==='unavailable'&&e.errorCategory==='OFFLINE')publish(e,'idle');
                if(e.state==='unavailable'&&e.errorCategory==='RESOURCE_LIMIT'){
                    const count=Array.from(entries.values()).filter(x=>x!==e&&['loading','ready'].includes(x.state)).reduce((n,x)=>n+x.item.assets.filter(a=>a.kind==='3d-tiles').length,0);
                    if(count+e.item.assets.filter(a=>a.kind==='3d-tiles').length<=maxActiveTilesets)publish(e,'idle');
                }
                if(e.state==='idle'&&(e.preview||d<=e.item.loadRadiusM)&&!Array.from(entries.values()).some(x=>x.state==='loading'&&hasRemote(x)===hasRemote(e)))void load(e);
                if(!e.preview&&(e.state==='loading'||e.state==='ready'))updateHeight(e);
                if(e.state==='ready'&&wantsUnderlay(e))loadUnderlay(e,e.revision);
                else if(e.groundState&&e.groundState!=='idle'&&!wantsUnderlay(e))releaseUnderlay(e);
                syncUnderlay(e);
                if(e.state==='loading'&&e.models.length===e.item.assets.length&&e.models.every(m=>remoteAssets.has(m)||m.ready===true)){
                    clearTimer(e.timer);e.timer=null;e.ready=true;publish(e,'ready');
                }
                updateSeams(e);
            }
        }
        async function initialize(){
            const rev=++catalogRevision;const catalog=validate(await fetchCatalog());
            if(disposed||rev!==catalogRevision)return;
            initialCatalog={schemaVersion:1,sceneries:catalog};
            for(const e of entries.values())remove(e);
            entries=new Map(catalog.map(item=>[item.id,{item,base:item,enabled:Object.hasOwn(prefs,item.id)&&typeof prefs[item.id]==='boolean'?prefs[item.id]:item.enabled,models:[],revision:0,state:'idle',ready:false}]));tick(true);
        }
        // Apply a complete persisted catalog atomically. Unchanged scenes keep
        // model/collider identity. Unknown providers or bad optional definitions
        // cannot prevent another scene from loading.
        function bundledCatalog(){
            if(!initialCatalog)throw Error('Bundled scenery catalog unavailable');
            return JSON.parse(JSON.stringify(initialCatalog));
        }
        function configurationKey(item){
            // Native manifests make defaults explicit. They must not upload the
            // same bundled GLB twice during the initial persistence handover.
            const value={...item,attribution:item.attribution??`${item.author} · ${item.license}`,
                alignment:{...item.alignment,pitchDeg:item.alignment.pitchDeg??0,rollDeg:item.alignment.rollDeg??0},
                collisionAssets:item.physicalCollisionsEnabled?(item.collisionAssets??[item.collisionAsset]):[]};
            const stable=v=>Array.isArray(v)?v.map(stable):v&&typeof v==='object'?
                Object.fromEntries(Object.keys(v).filter(k=>v[k]!==undefined).sort().map(k=>[k,stable(v[k])])):v;
            return JSON.stringify(stable(value));
        }
        function replaceCatalog(input){
            if(disposed)throw Error('Scenery manager disposed');
            if(!input||input.schemaVersion!==1||!Array.isArray(input.sceneries)||
                !Array.isArray(input.unavailable)||input.sceneries.length+input.unavailable.length>64)
                throw Error('Invalid scenery catalog');
            const ids=new Set(),catalog=[],failures=[];
            for(const item of [...input.sceneries,...input.unavailable]){
                if(!item||typeof item.id!=='string'||!/^[a-z0-9_-]{1,80}$/.test(item.id)||ids.has(item.id))throw Error('Invalid or duplicate scenery ID');
                ids.add(item.id);
            }
            for(const item of input.sceneries){
                try{catalog.push(validate({schemaVersion:1,sceneries:[item]})[0]);}
                catch(error){failures.push({id:item.id,name:typeof item.name==='string'?item.name.slice(0,120):item.id,
                    enabled:item.enabled===true,state:'error',message:String(error.message).slice(0,512),visualOnly:true});}
            }
            for(const item of input.unavailable){
                if(typeof item.name!=='string'||item.name.length>120||typeof item.enabled!=='boolean'||typeof item.message!=='string'||item.message.length>512)
                    throw Error('Invalid unavailable scenery');
                failures.push({...item,state:'unavailable',visualOnly:true});
            }
            const next=new Map();
            for(const item of catalog){
                const previous=entries.get(item.id);
                if(previous&&configurationKey(previous.item)===configurationKey(item)){
                    previous.enabled=item.enabled;next.set(item.id,previous);
                }else next.set(item.id,{item,base:item,enabled:item.enabled,models:[],revision:0,state:'idle',ready:false});
            }
            catalogRevision++;
            for(const [id,e] of entries)if(next.get(id)!==e)remove(e);
            entries=next;unavailableEntries=failures;tick(true);viewer.scene.requestRender?.();return snapshot();
        }
        function setEnabled(id,value){const e=entries.get(id);if(!e||typeof value!=='boolean')throw Error('Invalid scenery preference');e.enabled=value;prefs={...prefs,[id]:value};try{storage?.setItem(storageKey,JSON.stringify(prefs));}catch(_){}tick(true);return snapshot();}
        function restorePreferences(values){if(!values||typeof values!=='object'||Array.isArray(values))throw Error('Invalid scenery preferences');for(const e of entries.values())if(Object.hasOwn(values,e.item.id)&&typeof values[e.item.id]==='boolean')setEnabled(e.item.id,values[e.item.id]);}
        function retry(id){const e=entries.get(id);if(!e)throw Error('Unknown scenery');remove(e);publish(e,'idle');tick(true);return snapshot();}
        function setEdit(id,value){
            const e=entries.get(id);if(!e)throw Error('Unknown scenery');
            const next=value===null?A.normalizeEdit(e.base,e.base.alignment):A.normalizeEdit(value,e.item.alignment);
            // Preserve verified readiness and avoid a second full GLB upload.
            const moved=next.alignment.longitude!==e.item.alignment.longitude||next.alignment.latitude!==e.item.alignment.latitude;
            clearSeams(e);e.item={...e.item,...next};
            if(moved){e.heightRevision=(e.heightRevision??0)+1;e.heightKey=null;e.heightPending=false;e.heightState='original';e.heightRetryAt=0;e.groundHeightM=null;}
            e.effectiveAlignment=e.item.heightAlignmentMode==='fixed'
                ?original(e)
                :e.heightState==='adjusted'&&e.heightKey===terrainKey()&&Number.isFinite(e.groundHeightM)?aligned(e,e.groundHeightM):original(e);
            for(const model of e.models)applyVisual(model,e.effectiveAlignment);if(e.groundModel)A.apply(C,e.groundModel,e.effectiveAlignment);
            syncCalibrationVisibility(e);
            tick(true);viewer.scene.requestRender?.();return snapshot();
        }
        function restoreEdits(values){
            if(!values||typeof values!=='object'||Array.isArray(values))throw Error('Invalid scenery edits');
            for(const e of entries.values())if(Object.hasOwn(values,e.item.id)){
                try{
                    let value=values[e.item.id];
                    // Source-declared migration: only upgrade an unchanged legacy base anchor.
                    // Keep intentionally edited coordinates, scale and offsets.
                    const a=value?.alignment,b=e.base.alignment;
                    if(a&&Array.isArray(e.base.legacyAlignmentHeightsM)&&e.base.legacyAlignmentHeightsM.includes(a.ellipsoidHeightM)&&
                        ['longitude','latitude','scale','rotationDeg'].every(k=>a[k]===b[k]))
                        value={...value,alignment:{...a,ellipsoidHeightM:b.ellipsoidHeightM}};
                    setEdit(e.item.id,value);
                }catch(error){console.warn('[scenery edit]',e.item.id,error);}
            }
        }
        function candidatePatches(e){
            // The certificate belongs to the exact unedited placement and FPC.
            if(!e.base.terrainCertificate||!e.terrainAssetVerified||!collisionReady(e)||!e.item.clipTerrain||terrainKey()==null||!['adjusted','fixed'].includes(e.heightState)||
                e.item.heightOffsetM!==0||(regionalHeightMode()&&e.item.bkgHeightOffsetM!==0)||JSON.stringify(e.item.alignment)!==JSON.stringify(e.base.alignment))return [];
            const requested=new Set(e.item.terrainRegions.map(p=>JSON.stringify(p)));
            const standard=e.base.terrainCertificates.filter(c=>requested.has(JSON.stringify(c.polygon)));
            const overlay=e.base.terrainUnderlay?.certificate;
            return overlay&&e.groundVerified&&e.groundCollider&&e.groundModel?.ready===true&&
                requested.has(JSON.stringify(overlay.polygon))?[overlay,...standard]:standard;
        }
        function clearSeams(e){if(e.seamCheck){e.seamCheck.abort.abort();clearTimer(e.seamCheck.timer);e.seamCheck=null;}}
        function updateSeams(e){
            const candidates=candidatePatches(e).filter(c=>c.seamToleranceM!==undefined);
            if(!candidates.length){clearSeams(e);return;}
            if(e.seamCheck&&e.seamCheck.item===e.item&&e.seamCheck.key===terrainKey()&&e.seamCheck.collider===e.collider&&e.seamCheck.groundCollider===e.groundCollider&&e.seamCheck.alignment===e.effectiveAlignment)return;
            clearSeams(e);
            const check={item:e.item,key:terrainKey(),collider:e.collider,groundCollider:e.groundCollider,alignment:e.effectiveAlignment,abort:new AbortController(),timer:null,results:new Map(),state:'pending'};
            e.seamCheck=check;
            const current=()=>!disposed&&e.seamCheck===check&&!check.abort.signal.aborted&&check.key===terrainKey()&&check.collider===e.collider&&check.groundCollider===e.groundCollider&&check.alignment===e.effectiveAlignment&&check.item===e.item;
            if(typeof sampleSeamGround!=='function'){check.state='unavailable';return;}
            const work=candidates.map(c=>({c,points:seamPoints(c,e.effectiveAlignment)}));
            const points=work.flatMap(w=>w.points);if(work.some(w=>!w.points.length)||points.length>2048){check.state='unavailable';return;}
            const logFailure=()=>{if(current()){check.state='unavailable';check.results.clear();check.abort.abort();viewer.scene.requestRender?.();}};
            check.timer=setTimer(logFailure,timeoutMs);
            // Provider samples are request-scoped and never persisted (BKG beta).
            (async()=>{
                const values=[];
                try{
                    for(let i=0;i<points.length;i+=128){if(!current())return;const batch=points.slice(i,i+128),result=await sampleSeamGround(batch,check.abort.signal);if(!Array.isArray(result)||result.length!==batch.length)throw Error('Incomplete terrain seam sample');values.push(...result);}
                    if(!current())return;
                    let i=0;const frame=frameFor(e);
                    for(const w of work){const result=evaluateSeam(groundMesh(e,w.c),frame,w.c,w.points,values.slice(i,i+w.points.length));i+=w.points.length;check.results.set(JSON.stringify(w.c.polygon),result);}
                    check.state='checked';viewer.scene.requestRender?.();
                }catch(_){logFailure();}finally{clearTimer(check.timer);check.timer=null;}
            })();
        }
        function verifiedPatches(e){
            const candidates=candidatePatches(e),check=e.seamCheck;
            const approved=candidates.filter(c=>c.seamToleranceM===undefined||!!(check&&check.state==='checked'&&!check.abort.signal.aborted&&check.item===e.item&&check.key===terrainKey()&&check.collider===e.collider&&check.groundCollider===e.groundCollider&&check.alignment===e.effectiveAlignment&&check.results.get(JSON.stringify(c.polygon))?.approved));
            // The large underlay replaces, rather than stacks over, the smaller
            // R8 cutouts. If its live seam fails, certified small patches survive.
            const large=approved.find(c=>c.source==='underlay');return large?[large]:approved;
        }
        function frameFor(e){if(e.collisionAlignment!==e.effectiveAlignment){e.collisionAlignment=e.effectiveAlignment;e.collisionFrame=Collision.transform(e.effectiveAlignment);}return e.collisionFrame;}
        function activeRegions(kind,forFlight=false){
            if(kind==='terrain')return Array.from(entries.values()).flatMap(e=>{
                if(e.base.terrainCertificate)return verifiedPatches(e).map(c=>c.polygon);
                return !forFlight&&e.ready&&e.enabled&&e.state==='ready'&&e.item.alignment.opacity>=.99&&heightReady(e)&&e.item.clipTerrain?e.item.terrainRegions:[];
            });
            return Array.from(entries.values()).filter(e=>e.ready&&e.enabled&&e.state==='ready'&&e.item.alignment.opacity>=.99&&heightReady(e)&&(!forFlight||collisionReady(e))&&e.item.replaceBuildings).flatMap(e=>e.item.buildingRegions);
        }
        function replacementHeight(point,maskActive){
            for(const e of entries.values()){
                const patches=verifiedPatches(e);if(!patches.length)continue;
                const f=frameFor(e),p=f.local(point);
                for(const c of patches){if(!maskActive(c.polygon)||!insideGroundPatch(p,c,f.scale))continue;
                    const z=groundLocal(groundMesh(e,c),c,p);if(Number.isFinite(z))return point.height+(z-p[2])*f.scale;}
            }
            return undefined;
        }
        function replacementPassage(from,to,maskActive){
            for(const e of entries.values()){
                const patches=verifiedPatches(e).filter(c=>maskActive(c.polygon));if(!patches.length)continue;
                const f=frameFor(e),a=f.local(from),b=f.local(to);
                // Continuous segment coverage; endpoint membership alone fails for disconnected masks.
                if(segmentCovered(a,b,patches,f.scale)&&[a,b].every(p=>patches.some(c=>insideGroundPatch(p,c,f.scale)&&Number.isFinite(groundLocal(groundMesh(e,c),c,p)))))return true;
            }
            return false;
        }
        function collision(from,to){
            let first=false;
            for(const e of entries.values())if(collisionReady(e)){
                for(const mesh of e.colliders??[e.collider]){
                    const hit=Collision.contact(mesh,frameFor(e),from,to);
                    if(hit&&(!first||hit.fraction<first.fraction)){first=hit;e.lastHit={triangle:hit.triangle,fraction:hit.fraction};}
                }
                const large=verifiedPatches(e).find(c=>c.source==='underlay');
                if(large&&terrainMaskActive(large.polygon)){
                    const f=frameFor(e),a=f.local(from),b=f.local(to);
                    if(segmentCovered(a,b,[large],f.scale)){
                        const groundHit=Collision.contact(e.groundCollider,f,from,to);
                        if(groundHit&&(!first||groundHit.fraction<first.fraction))first=groundHit;
                    }
                }
            }
            return first;
        }
        function snapshot(){return Array.from(entries.values(),e=>({id:e.item.id,name:e.item.name,enabled:e.enabled,state:e.state,message:e.message??null,...remoteStatus(e),alignment:e.item.alignment,effectiveAlignment:e.effectiveAlignment??e.item.alignment,groundHeightM:e.groundHeightM??null,heightState:e.heightState??'original',heightError:e.heightError??null,heightAlignmentMode:e.item.heightAlignmentMode,calibration:e.item.heightCalibration??null,baseAnchorHeightM:e.base.alignment.ellipsoidHeightM,appliedHeightOffsetM:(e.effectiveAlignment??original(e)).ellipsoidHeightM-e.item.alignment.ellipsoidHeightM,heightOffsetM:e.item.heightOffsetM,bkgHeightOffsetM:e.item.bkgHeightOffsetM??0,buildingRegions:e.item.buildingRegions,terrainRegions:e.item.terrainRegions,replaceBuildings:e.item.replaceBuildings,clipTerrain:e.item.clipTerrain,visualOnly:!collisionReady(e),collisionState:e.collisionState??'idle',collisionError:e.collisionError??null,collisionReady:collisionReady(e),terrainReplacementReady:verifiedPatches(e).length>0,terrainReplacementApproved:verifiedPatches(e).length,terrainReplacementCandidates:candidatePatches(e).length,terrainSeamState:e.seamCheck?.state??'idle',groundUnderlayState:e.groundState??'idle',groundUnderlayVisible:e.groundModel?.show===true,groundUnderlayError:e.groundError??null,terrainSeamChecks:Array.from(e.seamCheck?.results.values()??[]),collisionTriangles:e.collider?(e.colliders??[e.collider]).reduce((n,m)=>n+m.triangleCount,0):null,collisionBytes:e.collider?(e.colliders??[e.collider]).reduce((n,m)=>n+m.byteLength,0):null,lastHit:e.lastHit??null})).concat(unavailableEntries.map(e=>({...e})));}
        const off=viewer.scene.preUpdate.addEventListener(()=>tick());
        // Terrain tiles may become resident *after* the first height sample has
        // failed. Retry as soon as Cesium drains its tile queue, without forcing
        // a GLB reload or requiring the user to toggle the scenery off and on.
        // A bounded timer above handles cases where no tile-ready event arrives.
        const offTerrain=viewer.scene.globe?.tileLoadProgressEvent?.addEventListener?.(pending=>{
            if(disposed||pending!==0||tileReadyRetryTimer!==null)return;
            const key=terrainKey();
            if(key==null||!Array.from(entries.values()).some(e=>e.enabled&&e.heightKey===key&&e.heightState==='unavailable'))return;
            viewer.scene.requestRender?.();
            tileReadyRetryTimer=setTimer(()=>{
                tileReadyRetryTimer=null;if(disposed)return;
                const currentKey=terrainKey();
                for(const e of entries.values())if(e.enabled&&e.heightKey===currentKey&&e.heightState==='unavailable'){
                    clearTimer(e.heightRetryTimer);e.heightRetryTimer=null;e.heightRetryAt=0;
                }
                tick(true);
            },0);
        });
        function dispose(){if(disposed)return;disposed=true;probeAbort?.abort();probeAbort=null;catalogRevision++;off?.();offTerrain?.();clearTimer(tileReadyRetryTimer);tileReadyRetryTimer=null;for(const e of entries.values())remove(e);entries.clear();unavailableEntries=[];}
        function previewModels(id){const e=entries.get(id);return e?.enabled?[...e.models]:[];}
        function beginAlignment(id){
            const e=entries.get(id);if(!e||e.preview)throw Error('Scenery is unavailable or already being edited');
            const status=snapshot().find(x=>x.id===id);e.preview={item:e.item,enabled:e.enabled,effectiveAlignment:e.effectiveAlignment,heightState:e.heightState,heightKey:e.heightKey,groundHeightM:e.groundHeightM};e.enabled=true;
            previewAlignment(id,status.effectiveAlignment,[]);return status;
        }
        function previewAlignment(id,alignment,corrections){
            const e=entries.get(id);if(!e?.preview)throw Error('No active scenery edit');const a=A.normalize(alignment),base=e.preview.item;
            let remoteIndex=0;const assets=base.assets.map(asset=>{const edit=asset.kind==='3d-tiles'?corrections[remoteIndex++]:null;return edit?{...asset,options:Tilesets.normalizeOptions({...asset.options,correction:edit.correction})}:asset;});
            e.heightRevision=(e.heightRevision??0)+1;e.heightPending=false;clearTimer(e.heightSampleTimer);e.heightSampleTimer=null;clearSeams(e);releaseUnderlay(e);
            e.item={...base,assets,alignment:hasRemote(e)?{...base.alignment,opacity:a.opacity}:a,heightAlignmentMode:'fixed',heightOffsetM:0,bkgHeightOffsetM:0,requireGroundCalibration:false,replaceBuildings:false,clipTerrain:false,buildingRegions:[],terrainRegions:[]};e.effectiveAlignment=original(e);e.collisionAlignment=null;
            for(const model of e.models){const remote=remoteAssets.get(model);if(remote)remote.asset=assets[remote.index];applyVisual(model,e.effectiveAlignment);model.show=true;}
            tick(true);viewer.scene.requestRender?.();
        }
        function endAlignment(id){
            const e=entries.get(id);if(!e?.preview)return;const base=e.preview;e.preview=null;e.item=base.item;e.enabled=base.enabled;
            e.heightRevision=(e.heightRevision??0)+1;e.heightPending=false;e.heightKey=base.heightKey;e.heightState=base.heightState;e.groundHeightM=base.groundHeightM;e.effectiveAlignment=base.effectiveAlignment??original(e);e.collisionAlignment=null;
            for(const model of e.models){const remote=remoteAssets.get(model);if(remote)remote.asset=e.item.assets[remote.index];applyVisual(model,e.effectiveAlignment);}
            syncCalibrationVisibility(e);tick(true);viewer.scene.requestRender?.();
        }
        function selectedScenery(primitive){return Array.from(entries.values()).find(e=>e.models.includes(primitive))?.item.id??null;}
        function setPreviewHidden(id,hidden){const e=entries.get(id);if(!e)throw Error('Unknown scenery');e.previewHidden=Boolean(hidden);syncCalibrationVisibility(e);viewer.scene.requestRender?.();}
        return {initialize,inspectTileset,bundledCatalog,replaceCatalog,tick,setEnabled,restorePreferences,setEdit,restoreEdits,activeRegions,replacementHeight,replacementPassage,collision,retry,snapshot,dispose,previewModels,setPreviewHidden,beginAlignment,previewAlignment,endAlignment,selectedScenery,visualOnlyModels:()=>Array.from(entries.values()).flatMap(e=>[...e.models,...(e.groundModel?.show?[e.groundModel]:[])])};
    }
    return {validate,distanceM,terrainAligned,fitGroundReference,pickRenderedGroundHeights,sampleAnchorGround,create,catalogUrl,managedModelUrl,insideGroundPatch,groundLocal,normalizeTerrainCertificate,verifyTerrainAsset,segmentCovered,seamPoints,evaluateSeam};
});
