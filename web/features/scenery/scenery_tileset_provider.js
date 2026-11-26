// Remote visuals share Cesium's request scheduler and cooperative header loader.
(function(root,factory){
    const api=factory(typeof module==='object'&&module.exports?require('../scene/scene_tile_loading.js'):root.FPVSceneTileLoading,
        typeof module==='object'&&module.exports?require('./scenery_alignment.js'):root.FPVSceneryAlignment);
    if(typeof module==='object'&&module.exports)module.exports=api;else root.FPVSceneryTilesets=api;
})(typeof globalThis!=='undefined'?globalThis:this,function(Loading,A){
    'use strict';
    const marker='X-FPV-Scenery-Scope',registries=new WeakMap(),MAX_BYTES=64*1024*1024;
    const embedded=value=>typeof value==='string'&&value.length<=MAX_BYTES*4/3+1024&&/^data:(?:application\/(?:octet-stream|gltf-buffer|gltf-binary)|image\/(?:png|jpeg|webp|ktx2|avif))(?:;[^,]*)?,/i.test(value);
    function failure(category,message,status){const error=Error(message);error.category=category;if(status)error.statusCode=status;return error;}
    function safeUrl(value,base){
        if(typeof value!=='string'||!value||/[\u0000-\u0020\\]/.test(value))throw failure('INVALID_URL','Enter a valid HTTPS resource URL.');
        let url;try{url=new URL(value,base);}catch(_){throw failure('INVALID_URL','Enter a complete HTTPS tileset URL.');}
        if(url.protocol!=='https:'||url.username||url.password||url.hash||url.href.length>2048)throw failure('INVALID_URL','Tileset resources require HTTPS without credentials or fragments.');
        return url.href;
    }
    function describe(error){
        if(error?.category)return {category:error.category,message:String(error.message).slice(0,512)};
        const text=String(error?.message??error??'');
        const status=error?.statusCode??error?.status??Number(/(?:status(?: code)?[:= ]+|HTTP\s+)(\d{3})/i.exec(text)?.[1]);
        if(status>0)return {category:'HTTP_ERROR',message:`Provider returned HTTP ${status}. Check the endpoint and its access requirements.`};
        if(/version|extension|unsupported|invalid.*tile|invalid.*content/i.test(text))return {category:'UNSUPPORTED',message:'The tileset or tile content is unsupported by this Cesium version. '+text.replace(/https?:\/\/\S+/g,'[resource]').slice(0,250)};
        if(error?.name==='AbortError')return {category:'CANCELLED',message:'Tileset request cancelled.'};
        return {category:'NETWORK_OR_CORS',message:'Provider request failed. Check connectivity, HTTPS certificates and provider CORS permission. Browsers cannot reliably distinguish these failures.'};
    }
    async function validateDocument(doc,base,{pause=()=>new Promise(r=>setTimeout(r,0))}={}){
        if(!doc||typeof doc!=='object'||!['1.0','1.1'].includes(doc.asset?.version)||!doc.root||!Number.isFinite(doc.geometricError)||doc.geometricError<0)throw failure('UNSUPPORTED','Expected an OGC 3D Tiles 1.0 or 1.1 tileset with a root and geometric error.');
        const stack=[[doc.root,0]];let nodes=0;
        while(stack.length){
            const [tile,depth]=stack.pop();
            if(!tile||typeof tile!=='object'||depth>128||++nodes>300000)throw failure('INVALID_TILESET','Tileset hierarchy exceeds structural limits.');
            const b=tile.boundingVolume;
            const extensionVolume=b?.extensions&&typeof b.extensions==='object'&&!Array.isArray(b.extensions)&&Object.keys(b.extensions).length>0;
            const standardVolumes=b?['region','box','sphere'].filter(key=>b[key]!==undefined).length:0;
            if(!b||standardVolumes!==1&&!(standardVolumes===0&&extensionVolume))throw failure('INVALID_TILESET','A tile needs a bounding volume supported by Cesium.');
            const volume=b?.region??b?.box??b?.sphere,length=b?.region?6:b?.box?12:4;
            if(standardVolumes&&( !Array.isArray(volume)||volume.length!==length||!volume.every(Number.isFinite)||
                b.sphere&&volume[3]<0||b.region&&(volume[0]<-Math.PI||volume[0]>Math.PI||volume[2]<-Math.PI||volume[2]>Math.PI||volume[1]<-Math.PI/2||volume[3]>Math.PI/2||volume[1]>volume[3]||volume[4]>volume[5])))throw failure('INVALID_TILESET','Invalid tile bounding volume.');
            if(tile.transform!==undefined&&(!Array.isArray(tile.transform)||tile.transform.length!==16||!tile.transform.every(Number.isFinite)||[3,7,11].some(i=>tile.transform[i]!==0)||tile.transform[15]!==1))throw failure('INVALID_TILESET','Invalid tile transform.');
            if(tile.geometricError!==undefined&&(!Number.isFinite(tile.geometricError)||tile.geometricError<0))throw failure('INVALID_TILESET','Invalid tile geometric error.');
            if(tile.refine!==undefined&&!['ADD','REPLACE'].includes(tile.refine))throw failure('INVALID_TILESET','Unsupported refinement mode.');
            if(tile.content&&tile.contents)throw failure('INVALID_TILESET','A tile cannot define both content and contents.');
            if(tile.contents!==undefined&&!Array.isArray(tile.contents))throw failure('INVALID_TILESET','Invalid tile contents.');
            for(const content of tile.contents??(tile.content?[tile.content]:[])){
                if(typeof(content?.uri??content?.url)!=='string')throw failure('INVALID_TILESET','Tile content URI is missing.');
                if(!embedded(content.uri??content.url))safeUrl(content.uri??content.url,base);
            }
            const implicit=tile.implicitTiling??tile.extensions?.['3DTILES_implicit_tiling'];
            if(implicit){
                if(!['QUADTREE','OCTREE'].includes(implicit.subdivisionScheme)||!Number.isInteger(implicit.subtreeLevels)||implicit.subtreeLevels<1)throw failure('INVALID_TILESET','Invalid implicit tiling definition.');
                safeUrl(implicit.subtrees?.uri,base);
            }
            if(tile.children!==undefined&&!Array.isArray(tile.children))throw failure('INVALID_TILESET','Invalid tile children.');
            for(const child of tile.children??[])stack.push([child,depth+1]);
            if(nodes%64===0)await pause();
        }
        return doc;
    }
    function normalizeOptions(value){
        if(!value||typeof value!=='object'||!['1.0','1.1'].includes(value.version)||!['provider','no-store'].includes(value.cachePolicy)||!Number.isFinite(value.maximumScreenSpaceError)||value.maximumScreenSpaceError<1||value.maximumScreenSpaceError>128)throw failure('INVALID_OPTIONS','Invalid tileset version, caching or screen-space error setting.');
        if(value.qualityScreenSpaceError!==undefined){
            const levels=value.qualityScreenSpaceError;
            if(!levels||typeof levels!=='object'||Array.isArray(levels)||Object.entries(levels).some(([key,n])=>!['low','balanced','high'].includes(key)||!Number.isFinite(n)||n<1||n>128))throw failure('INVALID_OPTIONS','Invalid quality-specific screen-space error.');
        }
        const sphere=value.boundingSphere;
        if(!sphere||!Array.isArray(sphere.center)||sphere.center.length!==3||!sphere.center.every(x=>Number.isFinite(x)&&Math.abs(x)<=1e9)||!Number.isFinite(sphere.radiusM)||sphere.radiusM<0||sphere.radiusM>1e8)throw failure('INVALID_OPTIONS','Validated tileset bounds are required.');
        const c=value.correction??{};
        if(typeof c!=='object'||Array.isArray(c))throw failure('INVALID_OPTIONS','Invalid positioning correction.');
        for(const [key,min,max]of [['eastM',-1e6,1e6],['northM',-1e6,1e6],['upM',-1e6,1e6],['headingDeg',-360,360],['pitchDeg',-90,90],['rollDeg',-180,180],['scale',.01,1000]]){
            const n=c[key]??(key==='scale'?1:0);if(!Number.isFinite(n)||n<min||n>max)throw failure('INVALID_OPTIONS','Invalid positioning correction.');
        }
        return {...value,boundingSphere:{center:[...sphere.center],radiusM:sphere.radiusM},correction:{eastM:0,northM:0,upM:0,headingDeg:0,pitchDeg:0,rollDeg:0,scale:1,...c}};
    }
    function correctionMatrix(C,pivot,correction={}){
        const c={eastM:0,northM:0,upM:0,headingDeg:0,pitchDeg:0,rollDeg:0,scale:1,...correction};
        if(c.eastM===0&&c.northM===0&&c.upM===0&&c.headingDeg===0&&c.pitchDeg===0&&c.rollDeg===0&&c.scale===1)return C.Matrix4.clone(C.Matrix4.IDENTITY);
        const config=A.normalize({...pivot,rotationDeg:c.headingDeg,pitchDeg:c.pitchDeg,rollDeg:c.rollDeg,scale:1,opacity:1});
        const origin=C.Cartesian3.fromDegrees(config.longitude,config.latitude,config.ellipsoidHeightM),enu=C.Transforms.eastNorthUpToFixedFrame(origin);
        const matrix=A.modelMatrix(C,config),offset=C.Matrix4.multiplyByPointAsVector(enu,new C.Cartesian3(c.eastM,c.northM,c.upM),new C.Cartesian3());
        C.Matrix4.setTranslation(matrix,C.Cartesian3.add(origin,offset,new C.Cartesian3()),matrix);
        C.Matrix4.multiplyByUniformScale(matrix,c.scale,matrix);
        return C.Matrix4.multiply(matrix,C.Matrix4.inverseTransformation(enu,new C.Matrix4()),new C.Matrix4());
    }
    function applyCorrection(C,tileset,pivot,correction,original){
        tileset.modelMatrix=C.Matrix4.multiply(correctionMatrix(C,pivot,correction),original??C.Matrix4.IDENTITY,new C.Matrix4());
    }
    function distance(C,point,sphere,pivot,correction){
        const source=new C.BoundingSphere(new C.Cartesian3(...sphere.center),sphere.radiusM);
        const corrected=C.BoundingSphere.transform(source,correctionMatrix(C,pivot,correction),new C.BoundingSphere());
        return Math.max(0,C.Cartesian3.distance(C.Cartesian3.fromDegrees(point.longitude,point.latitude,point.height),corrected.center)-corrected.radius);
    }
    // The marker is removed inside the local transport. It is never sent to a
    // provider and forces Cesium image requests through its scheduled blob path.
    function transportRegistry(C){
        const impl=C.Resource?._Implementations;
        if(!impl?.loadWithXhr)throw failure('UNSUPPORTED','Scoped Cesium resource transport is unavailable.');
        let registry=registries.get(impl);if(registry)return registry;
        const original=impl.loadWithXhr,owners=new Map();let sequence=0;
        impl.loadWithXhr=function(url,type,method,data,headers,deferred,mime){
            const entry=Object.entries(headers??{}).find(([key])=>key.toLowerCase()===marker.toLowerCase());
            if(!entry)return original.apply(this,arguments);
            const owner=owners.get(entry[1]);
            if(!owner){deferred.reject(failure('CANCELLED','Tileset resource owner was released.'));return {abort(){}};}
            if(/^data:/i.test(url)){
                if(!embedded(url)){deferred.reject(failure('INVALID_URL','Unsupported or oversized embedded tile resource.'));return {abort(){}};}
                const clean=Object.fromEntries(Object.entries(headers??{}).filter(([key])=>key.toLowerCase()!==marker.toLowerCase()));
                return original.call(this,url,type,method,data,clean,deferred,mime);
            }
            return owner.request(url,type,method,data,headers,deferred,mime);
        };
        registry={owners,next:()=>String(++sequence)};registries.set(impl,registry);return registry;
    }
    function createScope(C,{cachePolicy='no-store',fetcher=globalThis.fetch,setTimer=setTimeout,clearTimer=clearTimeout,requestTimeoutMs=15000,signal}={}){
        if(!['no-store','provider'].includes(cachePolicy))throw failure('INVALID_OPTIONS','Unsupported cache policy.');
        if(typeof fetcher!=='function'||typeof AbortController!=='function')throw failure('UNSUPPORTED','Scoped provider streaming requires Fetch and AbortController.');
        const registry=transportRegistry(C),id=registry.next(),active=new Set(),wrapped=new WeakSet();let disposed=false;
        const scope={prepareRoot:null,dispose,resource:resource=>decorate(typeof resource==='string'?new C.Resource({url:resource}):resource)};
        function dispose(){if(disposed)return;disposed=true;signal?.removeEventListener('abort',dispose);registry.owners.delete(id);for(const controller of active)controller.abort();active.clear();}
        function decorate(resource){
            if(wrapped.has(resource))return resource;wrapped.add(resource);resource.headers[marker]=id;
            const clone=resource.clone,derived=resource.getDerivedResource,fetchJson=resource.fetchJson;
            resource.clone=function(result){return decorate(clone.call(this,result));};
            resource.getDerivedResource=function(options){
                const next=derived.call(this,options);
                if(typeof options?.url==='string'&&/^data:/i.test(options.url)){
                    if(!embedded(options.url))throw failure('INVALID_URL','Unsupported or oversized embedded tile resource.');
                    return next;
                }
                if(options?.url&&!options.url.startsWith('fpv-scene-fragment://')){
                    const requested=new URL(options.url,this.url);safeUrl(requested.href);
                    if(requested.origin!==new URL(this.url).origin){
                        const explicit=new Set([...requested.searchParams.keys(),...Object.keys(options.queryParameters??{})]);
                        for(const key of Object.keys(this.queryParameters))if(!explicit.has(key))delete next.queryParameters[key];
                    }
                }
                return next;
            };
            resource.fetchJson=function(...args){
                const pending=fetchJson.apply(this,args);if(!pending)return pending;
                return pending.then(async doc=>{if(doc?.root&&doc?.asset){await validateDocument(doc,this.url);return scope.prepareRoot?scope.prepareRoot(doc,this):doc;}return doc;});
            };
            resource.retryAttempts=2;resource.retryCallback=async(_resource,error)=>{
                if(disposed||signal?.aborted||!['NETWORK_OR_CORS','TIMEOUT','HTTP_ERROR'].includes(describe(error).category))return false;
                const status=error?.statusCode;if(status&&![408,429].includes(status)&&status<500)return false;
                await new Promise(resolve=>{const finish=()=>{clearTimer(timer);signal?.removeEventListener('abort',finish);resolve();};const timer=setTimer(finish,Math.min(2000,250*2**(_resource._retryCount??0)));signal?.addEventListener('abort',finish,{once:true});});
                return !disposed&&!signal?.aborted;
            };
            return resource;
        }
        async function readResponse(response,type,url,mime){
            const declared=Number(response.headers.get('content-length'));if(declared>MAX_BYTES)throw failure('RESOURCE_LIMIT','A tileset resource exceeds 64 MiB.');
            const reader=response.body?.getReader();if(!reader)throw failure('INVALID_TILESET','Empty provider response.');
            const parts=[];let total=0;
            try{for(;;){const {done,value}=await reader.read();if(done)break;total+=value.byteLength;if(total>MAX_BYTES)throw failure('RESOURCE_LIMIT','A tileset resource exceeds 64 MiB.');parts.push(value);}}
            catch(error){await reader.cancel().catch(()=>{});throw error;}finally{reader.releaseLock();}
            const bytes=new Uint8Array(total);let offset=0;for(const part of parts){bytes.set(part,offset);offset+=part.length;}
            const json=type==='json'||/application\/(?:[^;]+\+)?json/.test(response.headers.get('content-type')??'')||new URL(url).pathname.endsWith('.json');
            let document;
            if(json){try{document=JSON.parse(new TextDecoder('utf-8',{fatal:true}).decode(bytes));}catch(_){throw failure('INVALID_TILESET','Provider returned invalid JSON.');}
                if(document?.root||document?.asset?.version==='1.0'||document?.asset?.version==='1.1')await validateDocument(document,url);}
            if(type==='json')return document;
            if(type==='arraybuffer')return bytes.buffer;
            if(type==='blob')return new Blob([bytes],{type:response.headers.get('content-type')??mime??'application/octet-stream'});
            if(type==='document')return new DOMParser().parseFromString(new TextDecoder().decode(bytes),mime??'application/xml');
            return new TextDecoder().decode(bytes);
        }
        registry.owners.set(id,{request(url,type,method,data,headers,deferred,mime){
            const aborter=new AbortController();active.add(aborter);let timedOut=false;
            const timer=setTimer(()=>{timedOut=true;aborter.abort();},requestTimeoutMs);
            Promise.resolve().then(()=>{
                if(disposed||signal?.aborted)throw failure('CANCELLED','Tileset request cancelled.');
                safeUrl(url);if(method&&method!=='GET'&&method!=='HEAD')throw failure('INVALID_URL','Only provider GET/HEAD requests are supported.');
                const clean=Object.fromEntries(Object.entries(headers??{}).filter(([key])=>key.toLowerCase()!==marker.toLowerCase()));
                return fetcher(url,{method:method??'GET',headers:clean,credentials:'omit',referrerPolicy:'no-referrer',cache:cachePolicy==='provider'?'default':'no-store',signal:aborter.signal});
            }).then(async response=>{
                safeUrl(response.url||url);
                if(!response.ok)throw failure('HTTP_ERROR',`Provider returned HTTP ${response.status}.`,response.status);
                if(method==='HEAD')return Object.fromEntries(response.headers.entries());
                return readResponse(response,type,response.url||url,mime);
            }).then(result=>deferred.resolve(result),error=>{aborter.abort();deferred.reject(timedOut?failure('TIMEOUT','Provider request timed out.'):error);})
              .finally(()=>{clearTimer(timer);active.delete(aborter);});
            return {abort(){aborter.abort();}};
        }});
        signal?.addEventListener('abort',dispose,{once:true});if(signal?.aborted)dispose();return scope;
    }
    function metadata(C,tileset){
        const sphere=tileset.boundingSphere;
        if(!sphere||![sphere.center.x,sphere.center.y,sphere.center.z,sphere.radius].every(Number.isFinite))throw failure('INVALID_TILESET','Tileset has no finite georeferenced bounds.');
        const magnitude=C.Cartesian3.magnitude(sphere.center);
        if(magnitude<1e6&&sphere.radius<5e6)throw failure('INVALID_TILESET','Tileset bounds are not georeferenced to Earth (WGS84/ECEF). Use local model import for ungeoreferenced assets.');
        let rectangle;try{rectangle=magnitude<1?C.Rectangle.MAX_VALUE:C.Rectangle.fromBoundingSphere(sphere,C.Ellipsoid.WGS84);}catch(_){throw failure('INVALID_TILESET','Tileset bounds cannot be projected onto WGS84.');}
        const cart=C.Cartographic.fromCartesian(sphere.center)??C.Cartographic.fromRadians((rectangle.west+rectangle.east)/2,(rectangle.south+rectangle.north)/2,0);
        return {version:tileset.asset.version,anchor:{longitude:C.Math.toDegrees(cart.longitude),latitude:C.Math.toDegrees(cart.latitude),heightM:Math.max(-10000,Math.min(20000,cart.height)),reference:'WGS84_ELLIPSOID'},
            bounds:Object.fromEntries(['west','south','east','north'].map(key=>[key,C.Math.toDegrees(rectangle[key])])),
            boundingSphere:{center:[sphere.center.x,sphere.center.y,sphere.center.z],radiusM:sphere.radius},copyright:typeof tileset.asset.copyright==='string'?tileset.asset.copyright.slice(0,2048):null};
    }
    async function load(C,url,options,{signal,fetcher,loaderFactory=Loading.create}={}){
        safeUrl(url);const scope=createScope(C,{cachePolicy:options.cachePolicy,signal,fetcher}),loader=loaderFactory(C);let tileset;
        try{
            tileset=await loader.load(scope.resource(url),{maximumScreenSpaceError:options.maximumScreenSpaceError,cacheBytes:options.cacheBytes??64*1024*1024,maximumCacheOverflowBytes:0,
                preloadWhenHidden:false,preloadFlightDestinations:false,showCreditsOnScreen:true,enableCollision:false},prepare=>{scope.prepareRoot=prepare;});
            if(signal?.aborted)throw failure('CANCELLED','Tileset load cancelled.');
            let released=false;const destroy=tileset.destroy;
            tileset.destroy=function(...args){if(!released){released=true;scope.dispose();loader.dispose();}return destroy.apply(this,args);};
            return tileset;
        }catch(error){if(tileset&&!tileset.isDestroyed())tileset.destroy();scope.dispose();loader.dispose();throw error;}
    }
    async function probe(C,url,options={}){
        let tileset;try{tileset=await load(C,url,{cachePolicy:options.cachePolicy??'no-store',maximumScreenSpaceError:16},options);return metadata(C,tileset);}
        finally{if(tileset&&!tileset.isDestroyed())tileset.destroy();}
    }
    return {safeUrl,describe,validateDocument,normalizeOptions,correctionMatrix,applyCorrection,distance,createScope,load,probe,metadata};
});
