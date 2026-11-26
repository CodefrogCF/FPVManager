// Validation runs away from the simulation thread. Transfer the original bytes
// back, so the main thread creates typed views without parsing the BVH again.
importScripts('./scenery_collision.js');
self.onmessage=event=>{
    try{FPVSceneryCollision.parse(event.data);self.postMessage({buffer:event.data},[event.data]);}
    catch(error){self.postMessage({error:String(error?.message??error).slice(0,512)});}
};
