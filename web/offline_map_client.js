(()=>{
 const enabled=window.FPVNativeOfflineCache===true||Boolean(navigator.serviceWorker?.controller?.scriptURL&&new URL(navigator.serviceWorker.controller.scriptURL).pathname.endsWith('/offline_service_worker.js'));
 if(!enabled)return;
 window.FPVMapProviderConfig={...window.FPVMapProviderConfig,
  cacheRoot:new URL('offline/maps/',location.href).href,
  cacheOnly:new URLSearchParams(location.search).get('cachedMaps')==='1'};
})();
