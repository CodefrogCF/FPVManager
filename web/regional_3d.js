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
    const licenseUrl='https://basemap.de/data/produkte/3d/lizenzen/lizenz_basemapde_3D-Beta.pdf';
    const bounds=Object.freeze([11.1528,51.2635,14.8390,53.6099]);
    const creditHtml=`<a href="${licenseUrl}" target="_blank" rel="noopener">© GeoBasis-DE/BKG 2026 · 3D-Beta · combined with other sources · test only</a>`;
    function inRegion(p,previous=false){if(!p||![p.longitude,p.latitude,p.height].every(Number.isFinite))return false;const d=previous ? 0.1 : 0;return p.longitude>=bounds[0]-d&&p.longitude<=bounds[2]+d&&p.latitude>=bounds[1]-d&&p.latitude<=bounds[3]+d&&p.height<=(previous?100000:60000);}
    function terrain(C){return C.CesiumTerrainProvider.fromUrl(terrainUrl,{ellipsoid:C.Ellipsoid.WGS84,credit:new C.Credit(creditHtml,true)});}
    function create(C,viewer,{enabled=false,online=()=>true,position=()=>{const p=viewer.camera.positionCartographic;return {longitude:C.Math.toDegrees(p.longitude),latitude:C.Math.toDegrees(p.latitude),height:p.height};},
        navigationBusy=()=>false,onRegionChange=()=>{},onStatus=()=>{},buildingsRequested=()=>false,now=()=>Date.now(),
        loadTiles=()=>C.Cesium3DTileset.fromUrl(buildingsUrl,{maximumScreenSpaceError:24,cacheBytes:32*1024*1024,maximumCacheOverflowBytes:8*1024*1024,enableCollision:false,showCreditsOnScreen:true}),
        buildingRegions=()=>[],flightBuildingRegions=()=>[],terrainRegions=()=>[],flightTerrainRegions=()=>[],terrainReady=()=>false,setTimer=setTimeout,clearTimer=clearTimeout,timeoutMs=20000}={}){
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
        function syncCuts(){
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
            const p=position(),wanted=enabled&&online()&&inRegion(p,region);
            // Do not change terrain underneath an active or starting flight.
            if(wanted!==region&&(!navigationBusy()||!online())){region=wanted;failed=false;onRegionChange(region);syncCuts();}
            const show=region&&online()&&buildingsRequested()&&p?.height<12000;
            if(!show){if(tiles||pending)remove();failed=false;return;}if(!tiles&&!pending&&!failed)load();
        }
        const off=viewer.scene.preUpdate.addEventListener(()=>tick());
        return {tick,region:()=>region,terrainMaskActive(polygon){
            // Never bypass terrain unless the clipping collection is ours and still applied.
            if(!terrainCut||!region||!online()||!terrainReady()||viewer.scene.globe.clippingPolygons!==terrainCut.collection||terrainCut.collection.enabled===false||!C.ClippingPolygonCollection?.isSupported?.(viewer.scene)||viewer.scene.globe.material||viewer.scene.globe.clippingPlanes?.length)return false;
            return terrainCut.regionKeys.has(JSON.stringify(polygon));
        },replacementStatus:()=>({buildingActive:!!buildingCut,terrainActive:!!terrainCut,supported:!!C.ClippingPolygonCollection?.isSupported?.(viewer.scene)}),visualOnlyModels:()=>tiles?[tiles]:[],retry(){failed=false;tick(true);},dispose(){if(disposed)return;disposed=true;off?.();remove();terrainCut=syncCut(viewer.scene.globe,terrainCut,[]);}};
    }
    return {bounds,inRegion,terrain,create,terrainUrl,buildingsUrl,buildingsFlatUrl,describeRequestError,licenseUrl};
});
