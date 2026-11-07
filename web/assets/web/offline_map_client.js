(()=>{
 const enabled=window.FPVNativeOfflineCache===true||Boolean(navigator.serviceWorker?.controller?.scriptURL&&new URL(navigator.serviceWorker.controller.scriptURL).pathname.endsWith('/offline_service_worker.js'));
 if(!enabled)return;
 window.FPVMapProviderConfig={...window.FPVMapProviderConfig,
  cacheRoot:new URL('offline/maps/',location.href).href,
  cacheOnly:new URLSearchParams(location.search).get('cachedMaps')==='1'};
 if(window.FPVMapProviderConfig.cacheOnly||navigator.onLine===false){
  const abort=new AbortController(),timer=setTimeout(()=>abort.abort(),4000);
  window.FPVPreparedOfflineReady=fetch(new URL('offline/maps/prepared.json',location.href),{cache:'no-store',credentials:'omit',signal:abort.signal})
   .then(async response=>{if(!response.ok)throw Error('Offline package metadata unavailable');const region=await response.json();
    if(region!==null){if(!/^[0-9a-f]{64}$/.test(region.packageId)||![region.west,region.south,region.east,region.north].every(Number.isFinite)||region.west>=region.east||region.south>=region.north)throw Error('Invalid offline package');
     window.FPVMapProviderConfig.prepared=region;}
   }).catch(()=>{window.FPVMapProviderConfig.preparedUnavailable=true;}).finally(()=>clearTimeout(timer));
 }
})();
