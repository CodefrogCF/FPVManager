// Generic scenery catalog with optional static CPU collision assets.
(function(root,factory){
    const api=factory(typeof module==='object'&&module.exports?require('./scenery_alignment.js'):root.FPVSceneryAlignment,
        typeof module==='object'&&module.exports?require('./scenery_collision.js'):root.FPVSceneryCollision,
        typeof module==='object'&&module.exports?require('./scenery_tileset_provider.js'):root.FPVSceneryTilesets,
        typeof module==='object'&&module.exports?require('./scenery_replacement.js'):root.FPVSceneryReplacement);
    if(typeof module==='object'&&module.exports)module.exports=api;else root.FPVSceneryManager=api;
})(typeof globalThis!=='undefined'?globalThis:this,function(A,Collision,Tilesets,Replacement){
    'use strict';
    const ROOT='assets/scenery/';
    const catalogUrl='./'+ROOT+'catalog.json';
    const storageKey='fpvmanager.scenery.enabled.v1';
    const MiB=1024*1024;
    // Separate cache targets from decoded GLB admission estimates and CPU FPC storage.
    const presets=Object.freeze({
        low:Object.freeze({remoteCacheBytes:64*MiB,localBudgetBytes:128*MiB,collisionBudgetBytes:128*MiB,maxVisualLoads:1,sseFactor:2}),
        balanced:Object.freeze({remoteCacheBytes:128*MiB,localBudgetBytes:128*MiB,collisionBudgetBytes:128*MiB,maxVisualLoads:2,sseFactor:1}),
        high:Object.freeze({remoteCacheBytes:256*MiB,localBudgetBytes:256*MiB,collisionBudgetBytes:128*MiB,maxVisualLoads:2,sseFactor:.5})
    });
    function streamingOptions(value={}){
        const preset=value.preset??'balanced';if(!Object.hasOwn(presets,preset))throw Error('Invalid scenery quality preset');
        const options={...presets[preset],...value,preset};
        for(const key of ['remoteCacheBytes','localBudgetBytes','collisionBudgetBytes'])if(!Number.isSafeInteger(options[key])||options[key]<16*MiB||options[key]>1024*MiB)throw Error('Invalid scenery memory budget');
        if(!Number.isInteger(options.maxVisualLoads)||options.maxVisualLoads<1||options.maxVisualLoads>4||!Number.isFinite(options.sseFactor)||options.sseFactor<.25||options.sseFactor>4)throw Error('Invalid scenery streaming limits');
        return options;
    }
    function validPoint(p){return p&&[p.latitude,p.longitude,p.height].every(Number.isFinite);}
    // Extrapolate only short, plausible movement; teleports never prefetch a world-spanning path.
    function predictPoint(previous,current,seconds,horizon=3){
        if(!validPoint(previous)||!validPoint(current)||seconds<=0||seconds>2)return null;
        const horizontal=distanceM(previous,current),vertical=current.height-previous.height;
        if(Math.hypot(horizontal,vertical)/seconds>150)return null;
        const f=Math.min(horizon/seconds,300/Math.max(1,Math.hypot(horizontal,vertical)));
        const longitude=((current.longitude+f*((current.longitude-previous.longitude+540)%360-180)+540)%360)-180;
        return {latitude:Math.max(-90,Math.min(90,current.latitude+f*(current.latitude-previous.latitude))),longitude,height:current.height+f*vertical};
    }
    function qualityOptions(asset,policy){
        const explicit=asset.options.qualityScreenSpaceError?.[policy.preset];
        return {...asset.options,maximumScreenSpaceError:explicit??Math.max(1,Math.min(128,asset.options.maximumScreenSpaceError*policy.sseFactor)),cacheBytes:policy.remoteCacheBytes};
    }
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
            // Alternative self-contained bundled GLBs must use the same local frame.
            // Managed assets cannot reference unverified alternative files.
            const visualLods=item.visualLods;
            if(visualLods!==undefined){
                if(!visualLods||typeof visualLods!=='object'||Array.isArray(visualLods))throw Error('Invalid visual LOD definitions');
                for(const [path,levels] of Object.entries(visualLods)){
                    if(!assets.some(a=>a.kind==='glb'&&!a.managed&&a.path===path)||!levels||typeof levels!=='object'||Array.isArray(levels))throw Error('Invalid visual LOD asset');
                    for(const [level,variant] of Object.entries(levels))if(!Object.hasOwn(presets,level)||!variant||typeof variant.path!=='string'||!/^([a-zA-Z0-9_-]+\/)*[a-zA-Z0-9_-]+\.glb$/.test(variant.path)||variant.path.startsWith('managed/')||!Number.isSafeInteger(variant.estimatedBytes)||variant.estimatedBytes<1||variant.estimatedBytes>1024*MiB)throw Error('Invalid visual LOD variant');
                }
            }
            if(item.collisionIndependent!==undefined&&typeof item.collisionIndependent!=='boolean')throw Error('Invalid collision loading policy');
            if(item.collisionSidedness!==undefined&&!['double','front','back'].includes(item.collisionSidedness))throw Error('Invalid collision sidedness');
            if(item.collisionIndependent){
                if(!Array.isArray(item.collisionResources)||item.collisionResources.length>16||item.collisionResources.length!==(item.collisionAssets??[]).length)throw Error('Invalid collision resources');
                for(const resource of item.collisionResources){
                    if(!resource||!(item.collisionAssets??[]).includes(resource.path)||resource.managed&&!/^managed\/[a-f0-9]{64}\.fpc$/.test(resource.path))throw Error('Invalid managed collision path');
                    if(resource.managed&&(!['cache','server'].includes(resource.backend)||!resource.metadata||!Number.isSafeInteger(resource.metadata.byteLength)||resource.metadata.byteLength<16||resource.metadata.byteLength>64*1024*1024||!Array.isArray(resource.metadata.localBounds)||resource.metadata.localBounds.length!==6||!resource.metadata.localBounds.every(Number.isFinite)))throw Error('Invalid collision metadata');
                }
            }
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
            return {...item,replacement:Replacement.normalize(item.replacement,alignment),...A.normalizeEdit({...item,alignment,buildingRegions},alignment),heightAlignmentMode,terrainCertificate,terrainCertificates,terrainUnderlay,assets,loadRadiusM,unloadRadiusM,enabled:item.enabled!==false};
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
        if(!/^[a-f0-9]{64}\.(glb|fpc)$/.test(key))throw Error('Invalid scenery cache key');
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
        if(hash+'.'+key.split('.').at(-1)!==key)throw Error('Local scenery checksum mismatch. Reimport the model.');
        const url=urls.createObjectURL(new Blob([bytes],{type:key.endsWith('.fpc')?'application/octet-stream':'model/gltf-binary'}));let released=false;
        return {url,release(){if(!released){released=true;urls.revokeObjectURL(url);}}};
    }
    function create(C,viewer,{fetchCatalog=()=>fetch(catalogUrl,{cache:'no-store'}).then(r=>{if(!r.ok)throw Error('Scenery catalog HTTP '+r.status);return r.json();}),
        debugWireframe=false,
        managedUrl=managedModelUrl,
        tilesetFactory=(url,options,signal)=>Tilesets.load(C,url,options,{signal}),
        probeTileset=(url,options)=>Tilesets.probe(C,url,options),
        canStreamRemote=()=>globalThis.navigator?.onLine!==false,flightPosition=()=>null,routeLookahead=()=>[],maxActiveTilesets=4,streaming={},diagnosticsEnabled=()=>false,
        modelFactory=(url,config,credit)=>C.Model.fromGltfAsync({url,modelMatrix:A.modelMatrix(C,config),scale:config.scale,allowPicking:true,enableCollision:false,enableDebugWireframe:debugWireframe,debugWireframe,credit,showCreditsOnScreen:true}),
        collisionFactory=(url,signal)=>Collision.load(url,signal),
        position=()=>{const x=viewer.camera.positionCartographic;return {latitude:C.Math.toDegrees(x.latitude),longitude:C.Math.toDegrees(x.longitude),height:x.height};},
        onStatus=()=>{},storage,now=()=>Date.now(),setTimer=setTimeout,clearTimer=clearTimeout,timeoutMs=60000,canLoad=()=>true,terrainKey=()=>null,terrainStable=()=>true,sampleGround=async()=>NaN,sampleSeamGround=null,terrainMaskActive=()=>false,regionalHeightMode=()=>false}={}){
        let unavailableEntries=[],initialCatalog=null;
        let disposed=false,entries=new Map(),lastTick=-Infinity,catalogRevision=0,tileReadyRetryTimer=null,probeAbort=null;
        const policy=streamingOptions(streaming);
        let lastMotion=null,localInFlight=0;
        const timings=new WeakMap(),history=[];
        const remember=(sample)=>{if(history.length===128)history.shift();history.push(sample);};
        function chosenAsset(e,asset){const variant=e.item.visualLods?.[asset.path]?.[policy.preset];return variant?{...asset,...variant}:asset;}
        function localEstimate(e){return e.item.assets.filter(a=>a.kind==='glb').reduce((n,a)=>n+(chosenAsset(e,a).estimatedBytes??64*MiB),e.base.terrainUnderlay?16*MiB:0);}
        function localResident(e){return Math.max(localEstimate(e),[...e.models,...(e.groundModel?[e.groundModel]:[])].filter(m=>!remoteAssets.has(m)).reduce((n,m)=>n+(m.statistics?.geometryByteLength??0)+(m.statistics?.texturesByteLength??0),0));}
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
            for(const model of models){model.cacheBytes=Math.floor(policy.remoteCacheBytes/models.length);model.maximumCacheOverflowBytes=0;}
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
        function remove(e){clearCollisionDebug(e);e.collisionReservedBytes=0;e.remoteAbort?.abort();e.remoteAbort=null;for(const release of e.pendingResources??[])release();e.pendingResources?.clear();clearTimer(e.heightSampleTimer);e.heightSampleTimer=null;clearTimer(e.heightRetryTimer);e.heightRetryTimer=null;releaseUnderlay(e);e.revision++;e.collisionAbort?.abort();clearTimer(e.collisionTimer);e.collisionTimer=null;e.collisionAbort=null;e.collider=null;e.colliders=[];e.terrainAssetVerified=false;e.collisionFrame=null;e.collisionAlignment=null;e.collisionState='idle';e.collisionError=null;e.lastHit=null;e.previewHidden=false;e.heightRevision=(e.heightRevision??0)+1;e.heightKey=null;e.heightPending=false;e.heightState=null;e.heightError=null;e.heightRetryAt=0;e.effectiveAlignment=original(e);e.groundHeightM=null;clearTimer(e.timer);e.timer=null;for(const model of e.models)disposeModel(model,true);e.models=[];rebalanceRemoteCache();e.ready=false;if(e.credit){display?.removeStaticCredit(e.credit);e.credit=null;}}
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
        function collisionReady(e){return !!((e.item.collisionIndependent||e.ready)&&e.enabled&&e.collider&&e.item.physicalCollisionsEnabled&&(e.item.collisionIndependent||e.item.alignment.opacity>=.99)&&terrainStable()&&heightReady(e));}
        function loadCollider(e,rev){
            if(!e.item.physicalCollisionsEnabled||['loading','ready'].includes(e.collisionState))return;
            if(Array.from(entries.values()).some(x=>(x!==e&&x.collisionState==='loading')||x.groundState==='loading')){e.collisionState='queued';return;}
            const required=(e.item.collisionAssets??[e.item.collisionAsset]).reduce((n,path)=>n+(e.item.collisionResources?.find(r=>r.path===path)?.metadata?.byteLength??(e.item.collisionIndependent?64:32)*MiB),0),occupied=Array.from(entries.values()).filter(x=>x!==e).reduce((n,x)=>n+(x.collisionReservedBytes??0)+(x.groundCollider?.byteLength??0),e.groundCollider?.byteLength??0);
            if(required>policy.collisionBudgetBytes){e.collisionState='error';e.collisionError='Collision asset estimate exceeds memory budget';return;}
            if(required+occupied>policy.collisionBudgetBytes){e.collisionState='queued';e.collisionError='Waiting for collision memory budget';return;}
            e.collisionReservedBytes=required;
            const abort=new AbortController();e.collisionAbort=abort;e.collisionState='loading';
            e.collisionTimer=setTimer(()=>{if(e.collisionRevision===collisionRev&&!abort.signal.aborted){abort.abort();e.collisionReservedBytes=0;e.collider=null;e.collisionState='error';e.collisionError='Collision asset load timed out';e.collisionTimer=null;}},timeoutMs);
            const collisionRev=(e.collisionRevision??0)+1;e.collisionRevision=collisionRev;const current=()=>!disposed&&e.collisionRevision===collisionRev&&!abort.signal.aborted;
            Promise.resolve().then(async()=>{
                const meshes=[];
                for(const path of e.item.collisionAssets??[e.item.collisionAsset]){
                    if(!current())return null;
                    const resource=e.item.collisionResources?.find(x=>x.path===path);
                    const acquired=resource?.managed?await managedUrl(resource):{url:'./'+ROOT+path,release(){}};
                    try{meshes.push(await collisionFactory(acquired.url,abort.signal));}finally{acquired.release();}
                    if(meshes.reduce((n,m)=>n+(m.byteLength??0),0)+occupied>policy.collisionBudgetBytes)throw Error('Collision geometry exceeds the active budget');
                }
                return meshes;
            }).then(meshes=>{
                if(!meshes||!current())return;
                e.colliders=meshes;const mesh=meshes[0];
                if(!current())return;clearTimer(e.collisionTimer);e.collisionTimer=null;e.collider=mesh;e.collisionState='ready';e.collisionReservedBytes=meshes.reduce((n,m)=>n+(m.byteLength??0),0);e.collisionError=null;syncCollisionDebug(e);viewer.scene.requestRender?.();tick(true);
                if(e.base.terrainCertificate)void verifyTerrainAsset(mesh,e.base.terrainCertificate).then(ok=>{if(current()&&e.collider===mesh){e.terrainAssetVerified=ok;viewer.scene.requestRender?.();}});
            }).catch(error=>{if(current()){clearTimer(e.collisionTimer);e.collisionTimer=null;e.collider=null;e.collisionReservedBytes=0;e.collisionState='error';e.collisionError=String(error?.message||error);tick(true);}});
        }
        function wantsUnderlay(e){
            return !!(terrainKey()!=null&&terrainStable()&&e.base.terrainUnderlay&&e.item.clipTerrain&&e.item.terrainRegions.some(p=>
                JSON.stringify(p)===JSON.stringify(e.base.terrainUnderlay.certificate.polygon)));
        }
        function loadUnderlay(e,rev){
            if(!wantsUnderlay(e)||e.groundState&&e.groundState!=='idle')return;
            const reserved=Array.from(entries.values()).reduce((n,x)=>n+(x.collisionReservedBytes??0)+(x.groundCollider?.byteLength??0),0);
            if(reserved+8*MiB>policy.collisionBudgetBytes||Array.from(entries.values()).some(x=>x.collisionState==='loading'))return;
            const underlay=e.base.terrainUnderlay,abort=new AbortController(),groundRev=(e.groundRevision??0)+1;
            e.groundRevision=groundRev;e.groundAbort=abort;e.groundState='loading';
            const current=()=>!disposed&&!abort.signal.aborted&&e.revision===rev&&e.groundRevision===groundRev&&wantsUnderlay(e);
            const credit=new C.Credit('© GeoBasis-DE/LGB (dl-de/by-2-0) · GCG2016 © BKG (CC BY 4.0) · DGM1 experimental underlay',true);
            localInFlight++;
            (async()=>{
                let model=null;
                try{
                    // Load collision first so a rejected collider cannot orphan a GLB.
                    const mesh=await collisionFactory('./'+ROOT+underlay.collisionAsset,abort.signal);
                    if(!current())return;
                    if(reserved+(mesh.byteLength??0)>policy.collisionBudgetBytes)throw Error('Underlay exceeds collision budget');
                    model=await modelFactory('./'+ROOT+underlay.asset,e.effectiveAlignment??e.item.alignment,credit);

                    if(!current()){disposeModel(model,false);return;}
                    applyVisual(model,e.effectiveAlignment??e.item.alignment);model.show=false;
                    viewer.scene.primitives.add(model);e.groundModel=model;model=null;
                    e.groundCollider=mesh;
                    const verified=await verifyTerrainAsset(mesh,underlay.certificate);
                    if(!current())return;
                    e.groundVerified=verified;e.groundState=verified?'ready':'error';
                    if(!verified){e.groundError='DGM1 collider hash mismatch or unavailable crypto';disposeModel(e.groundModel,true);e.groundModel=null;e.groundCollider=null;}
                    clearSeams(e);viewer.scene.requestRender?.();
                }catch(error){if(model)disposeModel(model,false);if(current()){if(e.groundModel){disposeModel(e.groundModel,true);e.groundModel=null;}e.groundCollider=null;e.groundState='error';e.groundError=String(error?.message??error);}}finally{localInFlight--;}
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
        function failVisual(e,message){
            releaseUnderlay(e);e.visualRevision=(e.visualRevision??0)+1;e.remoteAbort?.abort();clearTimer(e.timer);e.timer=null;
            for(const release of e.pendingResources??[])release();e.pendingResources?.clear();for(const model of e.models)disposeModel(model,true);e.models=[];rebalanceRemoteCache();if(e.credit){display?.removeStaticCredit(e.credit);e.credit=null;}e.ready=false;publish(e,'error',message);
        }
        async function load(e){
            const measure=diagnosticsEnabled(),hasLocal=e.item.assets.some(a=>a.kind==='glb');
            if(hasLocal)localInFlight++;
            const rev=e.revision,visualRev=(e.visualRevision??0)+1;e.visualRevision=visualRev;e.effectiveAlignment??=original(e);publish(e,'loading');if(e.item.collisionIndependent&&!['loading','ready','error'].includes(e.collisionState))loadCollider(e,rev);
            e.remoteAbort=new AbortController();e.tileFailures=0;e.tileError=null;e.tileErrorCategory=null;e.streamingState=hasRemote(e)?'loading':null;
            const current=()=>!disposed&&e.revision===rev&&e.visualRevision===visualRev;
            e.timer=setTimer(()=>{if(current()){if(e.item.collisionIndependent)failVisual(e,'Scenery visual load timed out');else{remove(e);publish(e,'error','Scenery load timed out');}}},timeoutMs);
            try{
                const remoteCount=e.item.assets.filter(a=>a.kind==='3d-tiles').length;
                const occupiedRemote=Array.from(entries.values()).filter(x=>x!==e&&['loading','ready'].includes(x.state)).reduce((n,x)=>n+x.item.assets.filter(a=>a.kind==='3d-tiles').length,0);
                if(remoteCount+occupiedRemote>maxActiveTilesets){if(e.item.collisionIndependent)failVisual(e,'External scenery capacity reached');else remove(e);publish(e,'unavailable','External scenery capacity reached. Disable another nearby provider.','RESOURCE_LIMIT');return;}
                const required=localEstimate(e);
                const occupied=Array.from(entries.values()).filter(x=>x!==e&&['loading','ready'].includes(x.state)).reduce((n,x)=>n+localResident(x),0);
                if(required>policy.localBudgetBytes)throw Error('Scenery exceeds the configured decoded resource budget.');
                if(required+occupied>policy.localBudgetBytes){
                    if(e.item.collisionIndependent)failVisual(e,'Waiting for local scenery memory budget');else remove(e);
                    publish(e,'unavailable','Local scenery memory budget reached.','LOCAL_BUDGET');return;
                }
                // Sequential loads cap concurrent GPU uploads; cancelled models cannot be attached later.
                for(const [assetIndex,sourceAsset] of e.item.assets.entries()){
                    const asset=chosenAsset(e,sourceAsset),assetStarted=now();
                    const title=e.item.sourceUrl?`<a href="${escape(e.item.sourceUrl)}" target="_blank" rel="noopener">${escape(e.item.name)}</a>`:escape(e.item.name);
                    const credit=new C.Credit(`${escape(e.item.author)} · ${title} · ${escape(e.item.license)} · ${escape(e.item.attribution??'')} · georeferenced placement; experimental simulation only`,true);
                    if(asset.kind==='3d-tiles'){
                        const model=await tilesetFactory(asset.url,qualityOptions(asset,policy),e.remoteAbort.signal);
                        const timing=measure&&current()?{kind:'tileset-root',loadMs:now()-assetStarted,firstTileMs:null,allTilesReadyMs:null,textureReadyMs:null}:null;
                        if(timing)remember(timing);
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
                            stops.push(model.tileLoad?.addEventListener(()=>{if(current()){if(timing&&timing.firstTileMs===null)timing.firstTileMs=now()-assetStarted;e.streamingState='streaming';e.tileError=null;e.tileErrorCategory=null;}}));
                            stops.push(model.allTilesLoaded?.addEventListener(()=>{if(current()&&e.streamingState!=='degraded'){e.streamingState='ready';if(timing&&timing.allTilesReadyMs===null)timing.allTilesReadyMs=now()-assetStarted;}}));
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
                    const timing=measure?{kind:'glb',loadMs:now()-assetStarted,readyMs:null,textureReadyMs:null}:null;
                    if(timing&&current()){timings.set(model,{sample:timing,started:assetStarted});remember(timing);}
                    e.pendingResources.delete(resource.release);
                    let offError,offTextures;
                    if(timing)offTextures=model.texturesReadyEvent?.addEventListener(()=>{if(current())timing.textureReadyMs=now()-assetStarted;});
                    modelReleases.set(model,()=>{offError?.();offTextures?.();resource.release();timings.delete(model);});
                    offError=model.errorEvent?.addEventListener(error=>{
                        if(current()){if(e.item.collisionIndependent)failVisual(e,String(error?.message||error));else{remove(e);publish(e,'error',String(error?.message||error));}}
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
                if(current()&&!e.item.collisionIndependent&&!['loading','ready','error'].includes(e.collisionState))loadCollider(e,rev);
                viewer.scene.requestRender?.();
            }catch(error){if(current()){if(e.item.collisionIndependent)failVisual(e,String(error?.message||error));else remove(e);const detail=hasRemote(e)?Tilesets.describe(error):null;publish(e,'error',detail?.message??String(error?.message||error),detail?.category??null);}}finally{if(hasLocal)localInFlight--;}
        }
        function tick(force=false){
            if(disposed)return;
            const t=now();if(!force&&t-lastTick<500)return;lastTick=t;
            const p=position();if(!validPoint(p))return;
            const airborne=flightPosition(),air=validPoint(airborne)?airborne:null,primary=air??p;
            const predicted=lastMotion&&lastMotion.air===!!air?predictPoint(lastMotion.point,primary,(t-lastMotion.time)/1000):null;
            if(!lastMotion||t>lastMotion.time)lastMotion={point:{...primary},time:t,air:!!air};
            const route=routeLookahead();
            // Route hints are limited to the immediate reachable area, never the entire route.
            const hints=[predicted,...(Array.isArray(route)?route.slice(0,8):[])].filter(q=>validPoint(q)&&distanceM(primary,q)<=1000);
            const distance=(e,point)=>Math.min(...e.item.assets.map(asset=>asset.kind==='3d-tiles'
                ?remoteDistance(e,asset,point)
                :Math.hypot(distanceM(e.item.alignment,point),Math.max(0,point.height-e.item.alignment.ellipsoidHeightM))));
            const candidates=Array.from(entries.values(),e=>{
                const camera=distance(e,p),aircraft=air?distance(e,air):camera,d=Math.min(camera,aircraft);
                const ahead=Math.min(d,...hints.map(q=>distance(e,q)));
                return {e,d,ahead,aircraft,priority:e.preview?-Infinity:(air?aircraft*.7+d*.3:d)};
            }).sort((a,b)=>a.priority-b.priority);
            // Release distant scenes before any new admissions, regardless of catalog ordering.
            for(const {e,d} of candidates){
                if(!e.enabled||!canLoad()||!e.preview&&d>e.item.unloadRadiusM){
                    if(e.state!=='idle'||e.collisionState&&e.collisionState!=='idle'){remove(e);publish(e,'idle');}
                }
            }
            // Physical geometry gets first admission; it is never switched by visual LOD.
            for(const {e,d,ahead} of candidates){
                if(!e.enabled||!canLoad()||!e.preview&&d>e.item.unloadRadiusM)continue;
                if(e.item.physicalCollisionsEnabled&&!['loading','ready','error'].includes(e.collisionState)&&
                    (e.preview||ahead<=e.item.loadRadiusM||e.state==='ready'||e.state==='loading'))loadCollider(e,e.revision);
            }
            for(const {e,d,ahead} of candidates){
                if(!e.enabled||!canLoad()||!e.preview&&d>e.item.unloadRadiusM)continue;
                if(hasRemote(e)&&!canStreamRemote()){
                    if(e.state!=='unavailable'||e.errorCategory!=='OFFLINE'){
                        if(e.item.collisionIndependent)failVisual(e,'External tilesets require an online globe');else remove(e);
                        publish(e,'unavailable','External tilesets require an online globe; no offline provider cache is created.','OFFLINE');
                    }
                    if(e.item.collisionIndependent)updateHeight(e);
                    continue;
                }
                if(e.state==='unavailable'&&e.errorCategory==='OFFLINE')publish(e,'idle');
                if(e.state==='unavailable'&&e.errorCategory==='RESOURCE_LIMIT'){
                    const count=Array.from(entries.values()).filter(x=>x!==e&&['loading','ready'].includes(x.state)).reduce((n,x)=>n+x.item.assets.filter(a=>a.kind==='3d-tiles').length,0);
                    if(count+e.item.assets.filter(a=>a.kind==='3d-tiles').length<=maxActiveTilesets)publish(e,'idle');
                }
                if(e.state==='unavailable'&&e.errorCategory==='LOCAL_BUDGET'){
                    const occupied=Array.from(entries.values()).filter(x=>x!==e&&['loading','ready'].includes(x.state)).reduce((n,x)=>n+localResident(x),0);
                    if(localEstimate(e)+occupied<=policy.localBudgetBytes)publish(e,'idle');
                }
                const loading=Array.from(entries.values()).filter(x=>x.state==='loading');
                if(e.state==='idle'&&(e.preview||ahead<=e.item.loadRadiusM)&&loading.length<policy.maxVisualLoads&&
                    !loading.some(x=>hasRemote(x)===hasRemote(e))&&(!e.item.assets.some(a=>a.kind==='glb')||localInFlight===0&&!loading.some(x=>x.item.assets.some(a=>a.kind==='glb'))))void load(e);
                if(!e.preview&&(e.state==='loading'||e.state==='ready'||e.item.collisionIndependent&&e.item.physicalCollisionsEnabled&&e.collisionState&&e.collisionState!=='idle'))updateHeight(e);
                if(e.state==='ready'&&wantsUnderlay(e)&&localInFlight===0&&!Array.from(entries.values()).some(x=>x.state==='loading'||x.groundState==='loading'))loadUnderlay(e,e.revision);
                else if(e.groundState&&e.groundState!=='idle'&&!wantsUnderlay(e))releaseUnderlay(e);
                syncUnderlay(e);syncCollisionDebug(e);
                for(const model of e.models){const timing=timings.get(model);if(timing&&model.ready&&timing.sample.readyMs===null)timing.sample.readyMs=now()-timing.started;}
                if(e.state==='loading'&&e.models.length===e.item.assets.length&&e.models.every(m=>remoteAssets.has(m)||m.ready===true)){
                    clearTimer(e.timer);e.timer=null;e.ready=true;publish(e,'ready');
                }
                updateSeams(e);
            }
        }
        function performanceSnapshot(){
            const entriesList=Array.from(entries.values()),models=entriesList.flatMap(e=>[...e.models,...(e.groundModel?[e.groundModel]:[])]);
            const remote=models.filter(m=>remoteAssets.has(m)),local=models.filter(m=>!remoteAssets.has(m));
            const meshes=entriesList.flatMap(e=>[...(e.colliders??[]),...(e.groundCollider?[e.groundCollider]:[])]);
            const activeMeshes=entriesList.filter(collisionReady).flatMap(e=>[...(e.colliders??[]),...(e.groundModel?.show&&e.groundCollider?[e.groundCollider]:[])]);
            return {preset:policy.preset,budgets:{remoteCacheBytes:policy.remoteCacheBytes,localBudgetBytes:policy.localBudgetBytes,collisionBudgetBytes:policy.collisionBudgetBytes,maxVisualLoads:policy.maxVisualLoads},
                loading:entriesList.filter(e=>e.state==='loading').length,localInFlight,residentModels:models.length,
                remoteEstimatedBytes:remote.reduce((n,m)=>n+(m.totalMemoryUsageInBytes??0),0),
                localEstimatedBytes:local.reduce((n,m)=>n+(m.statistics?.geometryByteLength??0)+(m.statistics?.texturesByteLength??0),0),
                localAdmissionBytes:entriesList.filter(e=>['ready','loading'].includes(e.state)).reduce((n,e)=>n+localResident(e),0),
                remoteStatsAvailable:remote.filter(m=>Number.isFinite(m.totalMemoryUsageInBytes)).length,localStatsAvailable:local.filter(m=>Number.isFinite(m.statistics?.geometryByteLength)&&Number.isFinite(m.statistics?.texturesByteLength)).length,
                selectedTileTriangles:remote.reduce((n,m)=>n+(m.statistics?.numberOfTrianglesSelected??0),0),
                shownModelTriangles:local.filter(m=>m.show!==false).reduce((n,m)=>n+(m.statistics?.trianglesLength??m.statistics?.triangleCount??0),0),
                collisionBytes:meshes.reduce((n,m)=>n+(m.byteLength??0),0),activeCollisionTriangles:activeMeshes.reduce((n,m)=>n+(m.triangleCount??0),0),
                loadSamples:history.map(s=>({...s})),caveat:'Cesium resource estimates and selected/submitted triangles, not full GPU memory or exact visible triangles; texture readiness is elapsed wall time, not decode time.'};
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
        function replacementReady(e){return !e.preview&&e.ready&&e.enabled&&e.state==='ready'&&e.item.alignment.opacity>=.99&&heightReady(e)&&terrainStable();}
        function clearReplacementCheck(e){if(e.replacementCheck){e.replacementCheck.abort.abort();clearTimer(e.replacementCheck.timer);e.replacementCheck=null;}}
        function updateReplacementCheck(e){
            if(!e.item.replacement?.terrain.enabled||!replacementReady(e)||!collisionReady(e)||terrainKey()==null){clearReplacementCheck(e);return;}
            const key=terrainKey(),alignment=e.effectiveAlignment??original(e),meshes=e.colliders??[e.collider];
            if(e.replacementCheck?.item===e.item&&e.replacementCheck.key===key&&e.replacementCheck.alignment===alignment&&e.replacementCheck.collider===e.collider)return;
            clearReplacementCheck(e);
            const check=e.replacementCheck={item:e.item,key,alignment,collider:e.collider,state:'pending',results:[],abort:new AbortController(),timer:null};
            const current=()=>!disposed&&e.replacementCheck===check&&!check.abort.signal.aborted&&terrainKey()===key&&replacementReady(e)&&collisionReady(e);
            const fail=message=>{if(current()){check.state='unavailable';check.message=message;check.results=[];check.abort.abort();viewer.scene.requestRender?.();}};
            if(alignment.pitchDeg||alignment.rollDeg){fail('Terrain replacement requires level scenery placement');return;}
            if(typeof sampleSeamGround!=='function'){fail('Terrain seam sampling unavailable');return;}
            const work=e.item.replacement.terrain.regions.map(region=>({region,points:Replacement.seamPoints(region,alignment)})),points=work.flatMap(w=>w.points);
            if(work.some(w=>!w.points.length)||points.length>2048){fail('Terrain perimeter exceeds the bounded seam sampling budget');return;}
            check.timer=setTimer(()=>fail('Terrain seam sampling timed out'),timeoutMs);
            (async()=>{try{
                const heights=[];for(let i=0;i<points.length;i+=128){if(!current())return;const batch=points.slice(i,i+128),values=await sampleSeamGround(batch,check.abort.signal);if(!Array.isArray(values)||values.length!==batch.length)throw Error('Incomplete terrain seam samples');heights.push(...values);}
                if(!current())return;let i=0;const frame=frameFor(e);
                const results=[];for(const w of work){let approved=true,samples=0,maxErrorM=0;
                    for(let j=0;j<w.points.length;j+=32){if(!current())return;const result=Replacement.evaluate(meshes,frame,w.region,w.points.slice(j,j+32),heights.slice(i+j,i+j+32));approved=approved&&result.approved;samples+=result.samples;maxErrorM=maxErrorM===null||result.maxErrorM===null?null:Math.max(maxErrorM,result.maxErrorM);if(j+32<w.points.length)await new Promise(resolve=>setTimeout(resolve,0));}
                    i+=w.points.length;results.push({approved,samples,maxErrorM,region:w.region});
                }
                if(!current())return;check.results=results;check.state='checked';viewer.scene.requestRender?.();
            }catch(error){fail(String(error.message||error));}finally{clearTimer(check.timer);check.timer=null;}})();
        }
        function approvedReplacement(e){const check=e.replacementCheck;return replacementReady(e)&&collisionReady(e)&&check?.state==='checked'&&!check.abort.signal.aborted&&check.item===e.item&&check.key===terrainKey()&&check.alignment===(e.effectiveAlignment??original(e))&&check.collider===e.collider?check.results.filter(r=>r.approved).map(r=>r.region):[];}
        function clearSeams(e,keepReplacement=false){if(!keepReplacement)clearReplacementCheck(e);if(e.seamCheck){e.seamCheck.abort.abort();clearTimer(e.seamCheck.timer);e.seamCheck=null;}}
        function updateSeams(e){updateReplacementCheck(e);
            const candidates=candidatePatches(e).filter(c=>c.seamToleranceM!==undefined);
            if(!candidates.length){clearSeams(e,true);return;}
            if(e.seamCheck&&e.seamCheck.item===e.item&&e.seamCheck.key===terrainKey()&&e.seamCheck.collider===e.collider&&e.seamCheck.groundCollider===e.groundCollider&&e.seamCheck.alignment===e.effectiveAlignment)return;
            clearSeams(e,true);
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
        function frameFor(e){if(!e.collisionFrame||e.collisionAlignment!==e.effectiveAlignment){e.collisionAlignment=e.effectiveAlignment;e.collisionFrame=Collision.transform(e.effectiveAlignment??original(e));}return e.collisionFrame;}
        function activeRegions(kind,forFlight=false,includeLegacy=true){
            if(kind==='terrain')return Array.from(entries.values()).flatMap(e=>{
                const generic=approvedReplacement(e).map(r=>r.polygon);
                if(e.item.replacement)return generic;if(!includeLegacy)return [];
                if(e.base.terrainCertificate)return verifiedPatches(e).map(c=>c.polygon);
                return !forFlight&&e.ready&&e.enabled&&e.state==='ready'&&e.item.alignment.opacity>=.99&&heightReady(e)&&e.item.clipTerrain?e.item.terrainRegions:[];
            });
            const generic=Array.from(entries.values()).filter(e=>replacementReady(e)&&e.item.replacement?.buildings.enabled).flatMap(e=>e.item.replacement.buildings.regions);
            return generic.concat(Array.from(entries.values()).filter(e=>!e.item.replacement&&e.ready&&e.enabled&&e.state==='ready'&&e.item.alignment.opacity>=.99&&heightReady(e)&&(!forFlight||collisionReady(e))&&e.item.replaceBuildings).flatMap(e=>e.item.buildingRegions));
        }
        function replacementHeight(point,maskActive){
            const candidates=[];let masked=false;
            for(const e of entries.values())for(const r of approvedReplacement(e))if(maskActive(r.polygon)&&Replacement.inside(point,r.polygon)){
                masked=true;const h=Replacement.ground(e.colliders??[e.collider],frameFor(e),r,point);if(Number.isFinite(h))candidates.push(h);
            }

            for(const e of entries.values()){
                const patches=verifiedPatches(e);if(!patches.length)continue;
                const f=frameFor(e),p=f.local(point);
                for(const c of patches){if(!maskActive(c.polygon)||!insideGroundPatch(p,c,f.scale))continue;
                    masked=true;const z=groundLocal(groundMesh(e,c),c,p);if(Number.isFinite(z))candidates.push(point.height+(z-p[2])*f.scale);}
            }
            return masked?(candidates.length?Math.max(...candidates):NaN):undefined;
        }
        function replacementPassage(from,to,maskActive){
            const polygons=Array.from(entries.values()).flatMap(e=>approvedReplacement(e).filter(r=>maskActive(r.polygon)).map(r=>r.polygon));
            if(polygons.length&&!Replacement.outsideIntervals(from,to,polygons).length)return true;
            for(const e of entries.values()){
                const patches=verifiedPatches(e).filter(c=>maskActive(c.polygon));if(!patches.length)continue;
                const f=frameFor(e),a=f.local(from),b=f.local(to);
                // Continuous segment coverage; endpoint membership alone fails for disconnected masks.
                if(segmentCovered(a,b,patches,f.scale)&&[a,b].every(p=>patches.some(c=>insideGroundPatch(p,c,f.scale)&&Number.isFinite(groundLocal(groundMesh(e,c),c,p)))))return true;
            }
            return false;
        }
        function clearCollisionDebug(e){for(const model of e.collisionDebugModels??[])viewer.scene.primitives.remove(model);e.collisionDebugModels=[];e.debugMeshes=null;}
        function syncCollisionDebug(e){
            if(!e.collisionDebug||!e.collider)return;
            try{
                const matrix=C.Matrix4.multiplyByUniformScale(A.modelMatrix(C,e.effectiveAlignment??original(e)),(e.effectiveAlignment??original(e)).scale,new C.Matrix4());
                if(e.debugMeshes!==e.colliders){clearCollisionDebug(e);e.debugMeshes=e.colliders;e.collisionDebugModels=e.colliders.map(mesh=>Collision.visualize(C,viewer,mesh,matrix));}
                else for(const model of e.collisionDebugModels)model.modelMatrix=matrix;
            }catch(error){clearCollisionDebug(e);e.collisionDebug=false;e.collisionDebugError=String(error.message);}
        }
        function setCollisionDebug(id,enabled){const e=entries.get(id);if(!e)throw Error('Unknown scenery');e.collisionDebug=enabled===true;e.collisionDebugError=null;if(!e.collisionDebug)clearCollisionDebug(e);else syncCollisionDebug(e);viewer.scene.requestRender?.();return snapshot();}
        function crossesRegion(from,to,b){
            if(!b)return false;const wrap=x=>((x+540)%360)-180,a=[wrap(from.longitude-b.west),from.latitude],q=[a[0]+wrap(to.longitude-from.longitude),to.latitude],span=Math.abs(b.east-b.west)>=359.999?360:(b.east-b.west+360)%360;
            for(const shift of [-360,0,360]){let low=0,high=1;for(let j=0;j<2;j++){const min=j===0?shift:b.south,max=j===0?shift+span:b.north,d=q[j]-a[j];if(Math.abs(d)<1e-12){if(a[j]<min||a[j]>max){high=-1;break;}}else{const x=(min-a[j])/d,y=(max-a[j])/d;low=Math.max(low,Math.min(x,y));high=Math.min(high,Math.max(x,y));}}if(low<=high)return true;}return false;
        }
        function collisionAvailability(from,to){
            for(const e of unavailableEntries)if(e.enabled&&crossesRegion(from,to,e.safetyRegion))return {ready:false,id:e.id,state:'unavailable',message:e.message};
            for(const e of entries.values())if(e.enabled&&e.item.physicalCollisionsEnabled&&e.item.collisionIndependent&&!collisionReady(e)){
                const resources=e.item.collisionResources??[],boxes=resources.map(r=>r.metadata?.localBounds).filter(Boolean);let intersects=false;
                if(boxes.length===resources.length&&heightReady(e)){
                    const frame=frameFor(e),p=frame.local(from),q=frame.local(to),radius=.25/frame.scale;
                    for(const box of boxes){let low=0,high=1;for(let j=0;j<3;j++){const d=q[j]-p[j];if(Math.abs(d)<1e-12){if(p[j]<box[j]-radius||p[j]>box[j+3]+radius){high=-1;break;}}else{const a=(box[j]-radius-p[j])/d,b=(box[j+3]+radius-p[j])/d;low=Math.max(low,Math.min(a,b));high=Math.min(high,Math.max(a,b));}}if(low<=high){intersects=true;break;}}
                }else{
                    intersects=crossesRegion(from,to,e.item.collisionRegion);
                }
                if(intersects){if(!['loading','ready','error'].includes(e.collisionState))loadCollider(e,e.revision);return {ready:false,id:e.item.id,state:e.collisionState??'loading',message:e.collisionError??'Scenery collision geometry is loading'};}
            }
            return {ready:true};
        }
        function collision(from,to){
            let first=false;
            for(const e of entries.values())if(collisionReady(e)){
                for(const mesh of e.colliders??[e.collider]){
                    const hit=Collision.contact(mesh,frameFor(e),from,to,.25,e.item.collisionSidedness??'double');
                    if(hit&&(!first||hit.fraction<first.fraction)){if(e.item.collisionIndependent)hit.independent=true;first=hit;e.lastHit={triangle:hit.triangle,fraction:hit.fraction};}
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
        function snapshot(){return Array.from(entries.values(),e=>({id:e.item.id,name:e.item.name,enabled:e.enabled,state:e.state,message:e.message??null,...remoteStatus(e),alignment:e.item.alignment,effectiveAlignment:e.effectiveAlignment??e.item.alignment,groundHeightM:e.groundHeightM??null,heightState:e.heightState??'original',heightError:e.heightError??null,heightAlignmentMode:e.item.heightAlignmentMode,calibration:e.item.heightCalibration??null,baseAnchorHeightM:e.base.alignment.ellipsoidHeightM,appliedHeightOffsetM:(e.effectiveAlignment??original(e)).ellipsoidHeightM-e.item.alignment.ellipsoidHeightM,heightOffsetM:e.item.heightOffsetM,bkgHeightOffsetM:e.item.bkgHeightOffsetM??0,buildingRegions:e.item.buildingRegions,terrainRegions:e.item.terrainRegions,replaceBuildings:e.item.replaceBuildings,clipTerrain:e.item.clipTerrain,visualOnly:!collisionReady(e),collisionState:e.collisionState??'idle',collisionError:e.collisionError??null,collisionReady:collisionReady(e),terrainReplacementReady:verifiedPatches(e).length>0,terrainReplacementApproved:verifiedPatches(e).length,terrainReplacementCandidates:candidatePatches(e).length,terrainSeamState:e.seamCheck?.state??'idle',groundUnderlayState:e.groundState??'idle',groundUnderlayVisible:e.groundModel?.show===true,groundUnderlayError:e.groundError??null,terrainSeamChecks:Array.from(e.seamCheck?.results.values()??[]),collisionTriangles:e.collider?(e.colliders??[e.collider]).reduce((n,m)=>n+m.triangleCount,0):null,collisionIndependent:e.item.collisionIndependent===true,replacementState:e.replacementCheck?.state??(e.item.replacement?.terrain.enabled?'waiting':'disabled'),replacementChecks:e.replacementCheck?.results??[],replacementError:e.replacementCheck?.message??null,replacementApplied:approvedReplacement(e).filter(r=>terrainMaskActive(r.polygon)).length,collisionDebug:e.collisionDebug===true,collisionDebugError:e.collisionDebugError??null,collisionBytes:e.collider?(e.colliders??[e.collider]).reduce((n,m)=>n+m.byteLength,0):null,lastHit:e.lastHit??null})).concat(unavailableEntries.map(e=>({...e})));}
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
        return {initialize,performanceSnapshot,resetPerformance:()=>{history.length=0;},inspectTileset,bundledCatalog,replaceCatalog,tick,setEnabled,restorePreferences,setEdit,restoreEdits,activeRegions,buildingFeatures:()=>Array.from(entries.values()).filter(e=>replacementReady(e)&&e.item.replacement?.buildings.enabled).flatMap(e=>e.item.replacement.buildings.features),replacementHeight,replacementPassage,collision,retry,snapshot,dispose,previewModels,setPreviewHidden,beginAlignment,previewAlignment,endAlignment,selectedScenery,collisionAvailability,setCollisionDebug,visualOnlyModels:()=>Array.from(entries.values()).flatMap(e=>[...e.models,...(e.collisionDebugModels??[]),...(e.groundModel?.show?[e.groundModel]:[])])};
    }
    return {validate,presets,streamingOptions,predictPoint,qualityOptions,distanceM,terrainAligned,fitGroundReference,pickRenderedGroundHeights,sampleAnchorGround,create,catalogUrl,managedModelUrl,insideGroundPatch,groundLocal,normalizeTerrainCertificate,verifyTerrainAsset,segmentCovered,seamPoints,evaluateSeam};
});
