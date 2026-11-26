// Experimental BKG live service. Never passed to the project's offline cache.
(function(root,factory){const api=factory();if(typeof module==='object'&&module.exports)module.exports=api;else root.FPVRegional3D=api;})(typeof globalThis!=='undefined'?globalThis:this,function(){
    'use strict';
    const terrainUrl='https://sgx.geodatenzentrum.de/gdz_basemapde_3d_gelaende/dgm5_4326_mesh/';
    const buildingsUrl='https://sgx.geodatenzentrum.de/gdz_basemapde_3d_gebaeude/lod2_4326_dgm5.json';
    // The standalone alignment workbench uses a flat ellipsoid.
    const buildingsFlatUrl='https://sgx.geodatenzentrum.de/gdz_basemapde_3d_gebaeude/lod2_4326_null.json';
    function describeRequestError(error,url){
        const code=error?.statusCode??error?.status;
        const msg=String(error?.message||error||'Unknown error');
        return `${code>0?`HTTP ${code} · `:'HTTP-Status unbekannt · '}${msg} · ${url}${code>0?'':' · Netzwerk/CORS in Browser-Entwicklertools prüfen'}`;
    }
    // The 3D service's license applies only to test operation (not ordinary
    // offline/open-data use). All service resources must remain runtime-only.
    const licenseUrl='https://sgx.geodatenzentrum.de/web_public/gdz/lizenz/deu/lizenz_basemapde_3d-testbetrieb.pdf';
    // Germany's coarse outline from Natural Earth 1:110m (public domain).
    // Do not use the rectangular extent as a country classifier: Switzerland,
    // Austria, Czechia etc. also lie within the same bounding rectangle.
    // Near a national border this small-scale outline is approximate.
    const boundary=Object.freeze([[14.11969,53.75703],[14.35332,53.24817],[14.07452,52.98126],[14.4376,52.62485],[14.68503,52.08995],[14.6071,51.74519],[15.017,51.10667],[14.57072,51.00234],[14.30701,51.11727],[14.05623,50.92692],[13.33813,50.73323],[12.96684,50.48408],[12.24011,50.26634],[12.41519,49.96912],[12.52102,49.54742],[13.03133,49.30707],[13.59595,48.87717],[13.24336,48.41611],[12.8841,48.28915],[13.02585,47.63758],[12.93263,47.46765],[12.62076,47.67239],[12.14136,47.70308],[11.42641,47.52377],[10.5445,47.5664],[10.40208,47.30249],[9.89607,47.5802],[9.59423,47.52506],[8.52261,47.83083],[8.3173,47.61358],[7.46676,47.62058],[7.59368,48.33302],[8.09928,49.01778],[6.65823,49.20196],[6.18632,49.4638],[6.24275,49.90223],[6.04307,50.12805],[6.15666,50.80372],[5.98866,51.85162],[6.5894,51.85203],[6.84287,52.22844],[7.09205,53.14404],[6.90514,53.48216],[7.10042,53.69393],[7.93624,53.7483],[8.12171,53.52779],[8.80073,54.02079],[8.57212,54.39565],[8.52623,54.96274],[9.28205,54.83087],[9.92191,54.9831],[9.93958,54.59664],[10.95011,54.36361],[10.93947,54.00869],[11.95625,54.19649],[12.51844,54.47037],[13.64747,54.07551]]);
    const bounds=Object.freeze([5.98865,47.30248,15.01700,54.98311]);
    const creditHtml=`<a href="${licenseUrl}" target="_blank" rel="noopener">© GeoBasis-DE/BKG 2026 · basemap.de 3D · Testbetrieb · mit weiteren Diensten kombiniert (verändert)</a>`;
    function inCountry(longitude,latitude){
        let inside=false;
        for(let j=boundary.length-1,i=0;i<boundary.length;j=i++){
            const a=boundary[i],b=boundary[j];
            if((a[1]>latitude)!==(b[1]>latitude)&&longitude<(b[0]-a[0])*(latitude-a[1])/(b[1]-a[1])+a[0]) inside=!inside;
        }
        return inside;
    }
    function inRegion(p,previous=false){
        if(!p||![p.longitude,p.latitude,p.height].every(Number.isFinite))return false;
        if(p.height>(previous?100000:60000))return false;
        return p.longitude>=bounds[0]&&p.longitude<=bounds[2]&&p.latitude>=bounds[1]&&p.latitude<=bounds[3]&&inCountry(p.longitude,p.latitude);
    }
    // Cesium normally uses XMLHttpRequest, which follows a server's disk-cache
    // policy. For restricted BKG 3D resources we explicitly use Fetch with
    // cache:no-store, including child tiles and metadata. This is only a
    // transport policy; FPVManager never writes these bytes to offline caches.
    function installRuntimeOnlyTransport(C){
        const implementations=C.Resource?._Implementations;
        if(!implementations?.loadWithXhr)return false;
        if(implementations.loadWithXhr._fpvBkgNoStore)return true;
        const original=implementations.loadWithXhr;
        const match=/^https:\/\/(?:sgx|sg)\.geodatenzentrum\.de\/gdz_basemapde_3d_(?:gebaeude|gelaende)\//i;
        function restrictedLoad(url,responseType,method,data,headers,deferred,mime){
            if(typeof url!=='string'||!match.test(url)){
                return original.apply(this,arguments);
            }
            if(typeof fetch!=='function'||typeof AbortController!=='function'){
                deferred.reject(Error('BKG no-store transport is unavailable'));
                return {abort(){}}; // Fail closed rather than use disk-cached XHR.
            }
            const aborter=new AbortController();
            const options={method:method||'GET',headers,cache:'no-store',signal:aborter.signal,
                credentials:'omit',redirect:'follow'};
            if(data!=null)options.body=data;
            fetch(url,options).then(async response=>{
                if(!response.ok){
                    const failure=Error(`BKG service HTTP ${response.status}`);
                    failure.statusCode=response.status;
                    throw failure;
                }
                if(options.method==='HEAD'||options.method==='OPTIONS')return Object.fromEntries(response.headers.entries());
                if(response.status===204)return undefined;
                switch(responseType){
                    case 'arraybuffer': return response.arrayBuffer();
                    case 'blob': return response.blob();
                    case 'json': return response.json();
                    case 'document': {
                        if(typeof DOMParser==='undefined')throw Error('BKG XML decoding not available');
                        return new DOMParser().parseFromString(await response.text(),mime||'application/xml');
                    }
                    default: return response.text();
                }
            }).then(value=>deferred.resolve(value),error=>deferred.reject(error));
            return {abort(){aborter.abort();}};
        }
        restrictedLoad._fpvBkgNoStore=true;
        implementations.loadWithXhr=restrictedLoad;
        return true;
    }
    function terrain(C){
        if(!installRuntimeOnlyTransport(C)) throw Error('BKG terrain requires cache:no-store transport');
        return C.CesiumTerrainProvider.fromUrl(terrainUrl,{ellipsoid:C.Ellipsoid.WGS84,credit:new C.Credit(creditHtml,true)});
    }
    function create(C,viewer,{enabled=false,online=()=>true,position=()=>{const p=viewer.camera.positionCartographic;return {longitude:C.Math.toDegrees(p.longitude),latitude:C.Math.toDegrees(p.latitude),height:p.height};},
        navigationBusy=()=>false,onRegionChange=()=>{},onStatus=()=>{},buildingsRequested=()=>false,now=()=>Date.now(),
        loadTiles=()=>C.Cesium3DTileset.fromUrl(buildingsUrl,{maximumScreenSpaceError:24,cacheBytes:32*1024*1024,maximumCacheOverflowBytes:8*1024*1024,enableCollision:false,showCreditsOnScreen:true}),
        manageClipping=true,buildingRegions=()=>[],flightBuildingRegions=()=>[],terrainRegions=()=>[],flightTerrainRegions=()=>[],terrainReady=()=>false,setTimer=setTimeout,clearTimer=clearTimeout,timeoutMs=20000}={}){
        // Test harnesses may inject a mock Cesium object without Resource.
        // A real Cesium scene must never silently fall back to disk-cached XHR.
        if(C.Resource&&!installRuntimeOnlyTransport(C)) throw Error('BKG buildings require cache:no-store transport');
        let region=false,tiles=null,revision=0,pending=false,failed=false,last=-Infinity,disposed=false,timer=null,credit=null;
        const display=viewer.cesiumWidget?.creditDisplay;
        // Own only our own collections, never replace clipping supplied by another
        // feature (e.g. tunnel apertures). Separate masks for tiles and terrain.
        let buildingCut=null,terrainCut=null;
        function syncCut(owner,previous,regions){
            if(previous&&(previous.owner!==owner||owner?.clippingPolygons!==previous.collection||!regions.length)){
                if(previous.owner.clippingPolygons===previous.collection){previous.owner.clippingPolygons=undefined;viewer.scene.requestRender?.();}
                previous=null;
            }
            if(!owner||!regions.length||!C.ClippingPolygonCollection?.isSupported?.(viewer.scene)||!('clippingPolygons' in owner)){
                if(previous&&previous.owner.clippingPolygons===previous.collection){previous.owner.clippingPolygons=undefined;viewer.scene.requestRender?.();}
                return null;
            }
            if(owner.clippingPolygons&&!previous)return null;
            const key=JSON.stringify(regions);
            if(previous?.key===key)return previous;
            try{
                const collection=new C.ClippingPolygonCollection({polygons:regions.map(poly=>new C.ClippingPolygon({positions:poly.map(([lon,lat])=>C.Cartesian3.fromDegrees(lon,lat,0))}))});
                owner.clippingPolygons=collection;viewer.scene.requestRender?.();return {owner,collection,key,regionKeys:new Set(regions.map(p=>JSON.stringify(p)))};
            }catch(error){
                // A failed mask update must not leave stale holes from a previous approval.
                if(previous&&previous.owner.clippingPolygons===previous.collection){previous.owner.clippingPolygons=undefined;viewer.scene.requestRender?.();}
                console.warn('[scenery replacement]',error);return null;
            }
        }
        function syncCuts(){if(!manageClipping)return;
            const live=region&&online(),busy=navigationBusy();
            buildingCut=syncCut(tiles,buildingCut,live&&tiles?(busy?flightBuildingRegions():buildingRegions()):[]);
            const globe=viewer.scene.globe;
            terrainCut=syncCut(globe,terrainCut,live&&terrainReady()&&!globe?.material&&!globe?.clippingPlanes?.length?(busy?flightTerrainRegions():terrainRegions()):[]);
        }
        function remove(){buildingCut=syncCut(tiles,buildingCut,[]);revision++;pending=false;clearTimer(timer);timer=null;if(tiles){viewer.scene.primitives.remove(tiles);tiles=null;}if(credit){display?.removeStaticCredit(credit);credit=null;}viewer.scene.requestRender?.();}
        function destroy(x){if(!x.isDestroyed?.())x.destroy?.();}
        function load(){pending=true;const rev=++revision;onStatus('loading');timer=setTimer(()=>{if(rev===revision){remove();failed=true;onStatus('error');}},timeoutMs);
            Promise.resolve().then(loadTiles).then(x=>{if(disposed||rev!==revision){destroy(x);return;}clearTimer(timer);timer=null;pending=false;
                try{x.enableCollision=false;viewer.scene.primitives.add(x);tiles=x;credit=new C.Credit(creditHtml,true);display?.addStaticCredit(credit);onStatus('ready');syncCuts();viewer.scene.requestRender?.();}
                catch(e){if(tiles===x)remove();else destroy(x);failed=true;onStatus('error');}
            }).catch(()=>{if(!disposed&&rev===revision){clearTimer(timer);timer=null;pending=false;failed=true;onStatus('error');}});
        }
        function tick(force=false){if(disposed)return;syncCuts();const t=now();if(!force&&t-last<1000)return;last=t;
            const p=position(),optedIn=typeof enabled==='function'?enabled():enabled;
            const wanted=optedIn&&online()&&inRegion(p,region);
            // Switching while flying is deferred, except when the user revokes
            // test consent or the network disappears: do not keep streaming.
            if(wanted!==region&&(!navigationBusy()||!online()||!optedIn)){region=wanted;failed=false;onRegionChange(region);syncCuts();}
            const show=optedIn&&region&&online()&&buildingsRequested()&&p?.height<12000;
            if(!show){if(tiles||pending)remove();failed=false;return;}if(!tiles&&!pending&&!failed)load();
        }
        const off=viewer.scene.preUpdate.addEventListener(()=>tick());
        return {tick,buildingTileset:()=>tiles,region:()=>region,terrainMaskActive(polygon){
            // Never bypass terrain unless the clipping collection is ours and still applied.
            if(!terrainCut||!region||!online()||!terrainReady()||viewer.scene.globe.clippingPolygons!==terrainCut.collection||terrainCut.collection.enabled===false||!C.ClippingPolygonCollection?.isSupported?.(viewer.scene)||viewer.scene.globe.material||viewer.scene.globe.clippingPlanes?.length)return false;
            return terrainCut.regionKeys.has(JSON.stringify(polygon));
        },replacementStatus:()=>({buildingActive:!!buildingCut,terrainActive:!!terrainCut,supported:!!C.ClippingPolygonCollection?.isSupported?.(viewer.scene)}),visualOnlyModels:()=>tiles?[tiles]:[],retry(){failed=false;tick(true);},dispose(){if(disposed)return;disposed=true;off?.();remove();terrainCut=syncCut(viewer.scene.globe,terrainCut,[]);}};
    }
    return {bounds,boundary,inCountry,inRegion,terrain,create,installRuntimeOnlyTransport,terrainUrl,buildingsUrl,buildingsFlatUrl,describeRequestError,licenseUrl};
});
