importScripts('vendor/geotiff/geotiff.js','offline_preparation_engine.js','offline_preparation_storage.js');
let sequence=0;const replies=new Map();
function native(operation,payload){const id=++sequence;return new Promise((resolve,reject)=>{replies.set(id,{resolve,reject});postMessage({type:'storage',requestId:id,operation,...payload},payload.bytes?[payload.bytes.buffer]:[]);});}
self.onmessage=async event=>{
 const m=event.data;if(m.type==='reply'){const reply=replies.get(m.requestId);if(reply){replies.delete(m.requestId);m.error?reply.reject(Error(m.error)):reply.resolve(m.value);}return;}
 if(m.type!=='start')return;
 try{
  const storage=m.native?{begin:config=>native('begin',{config}),has:(id,key)=>native('has',{id,key}),bindSources:(id,fingerprint)=>native('sources',{id,fingerprint}),write:(id,key,bytes,budget)=>native('write',{id,key,bytes,budget}),commit:region=>native('commit',{region})}:FPVPreparationStorage.create({caches,root:new URL('offline/maps/',self.location.href).href,crypto,estimate:()=>navigator.storage.estimate(),persist:()=>navigator.storage.persist?.()});
  const grid=FPVOfflinePreparation.heightGrid(m.grid),canvas=new OffscreenCanvas(256,256),context=canvas.getContext('2d');
  const region=await FPVOfflinePreparation.prepare(m.config,{GeoTIFF,storage,grid,progress:value=>postMessage({type:'progress',...value}),encodeImage:async rgba=>{context.putImageData(new ImageData(rgba,256,256),0,0);const blob=await canvas.convertToBlob({type:'image/png'});return new Uint8Array(await blob.arrayBuffer());}});
  postMessage({type:'complete',region});
 }catch(error){postMessage({type:'error',message:error.name==='QuotaExceededError'?'Browser-Speicher voll. Vorhandene Region bleibt erhalten.':String(error.message??error)});}
};
