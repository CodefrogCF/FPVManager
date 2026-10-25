(async()=>{
 if('serviceWorker'in navigator&&window.isSecureContext){
  try{
   const controller=new AbortController(),timer=setTimeout(()=>controller.abort(),4000);let version=null;
   try{const response=await fetch('offline_asset_manifest.json',{cache:'no-store',signal:controller.signal});
    if(response.ok){const manifest=await response.json();if(/^[0-9a-f]{64}$/.test(manifest.version))version=manifest.version;}
   }catch(_){}finally{clearTimeout(timer);}
   const current=navigator.serviceWorker.controller;
   // Offline startup keeps the installed snapshot; a development server has no manifest.
   if(version||!current){
    await navigator.serviceWorker.register('offline_service_worker.js'+(version?'?v='+version:''));
    if(!current)await Promise.race([
     new Promise(resolve=>navigator.serviceWorker.addEventListener('controllerchange',resolve,{once:true})),
     new Promise(resolve=>setTimeout(resolve,5000))]);
   }
  }catch(_){/* The online app and local records do not require a service worker. */}
 }
 const script=document.createElement('script');script.src='flutter_bootstrap.js';script.async=true;document.body.append(script);
})();
