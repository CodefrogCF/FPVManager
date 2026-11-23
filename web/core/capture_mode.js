// UI-only clean capture switch. Never changes flight state, telemetry, or credits.
(function(root,factory){
    const api=factory();
    if(typeof module==='object'&&module.exports)module.exports=api;
    else root.FPVCaptureMode=api;
})(typeof globalThis!=='undefined'?globalThis:this,function(){
    'use strict';
    function set(doc,enabled){
        if(typeof enabled!=='boolean')throw new Error('Invalid capture mode');
        if(!doc?.body?.classList?.toggle)throw new Error('Capture document unavailable');
        doc.body.classList.toggle('capture-mode',enabled);
        return {enabled};
    }
    return {set};
});
