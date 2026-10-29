(function(root,factory){const api=factory();if(typeof module==='object'&&module.exports)module.exports=api;else root.FPVPreparationStorage=api;})(globalThis,function(){
'use strict';
const validKey=k=>typeof k==='string'&&/^(terrain\/layer\.json|terrain\/\d{1,2}\/\d{1,7}\/\d{1,7}\.terrain|imagery\/(topographic|satellite|relief)\/\d{1,2}\/\d{1,7}\/\d{1,7}\.png|sources\/\d{1,4}\.json)$/.test(k);
function create({caches,root,crypto,estimate,persist}){
 let cache,job,used=0,count=0;const open=async()=>cache??=await caches.open('fpvmanager-offline-maps-v1:'+root),journal=root+'preparation.json';
 async function save(){await (await open()).put(journal,new Response(JSON.stringify(job)));}
 return {
 async begin(config){await persist?.();const quota=await estimate?.();if(quota?.quota&&Math.min(config.budget,config.estimatedBytes??config.budget)>(quota.quota-(quota.usage??0))*.9)throw Error('Nicht genügend Browser-Speicher. Detailgrad oder Ebenen reduzieren.');
  const c=await open(),old=await c.match(journal),signature=JSON.stringify(Object.fromEntries(Object.entries(config).filter(([k])=>k!=='id')));job=old?await old.json():null;if(!job||job.signature!==signature){if(job?.id&&/^[0-9a-f]{64}$/.test(job.id)){const regions=await c.match(root+'regions.json'),active=regions?(await regions.json()).regions:[];if(!active.some(r=>r.packageId===job.id))for(const request of await c.keys())if(request.url.startsWith(root+'prepared/'+job.id+'/'))await c.delete(request);}job={id:[...crypto.getRandomValues(new Uint8Array(32))].map(n=>n.toString(16).padStart(2,'0')).join(''),signature,regionId:config.id};await save();}
  used=0;count=0;for(const r of await c.keys())if(r.url.startsWith(root+'prepared/'+job.id+'/')){const response=await c.match(r);used+=Number(response.headers.get('x-fpv-size'));count++;}if(quota?.quota&&Math.max(0,(config.estimatedBytes??config.budget)-used)>(quota.quota-(quota.usage??0))*.9)throw Error('Nicht genügend Browser-Speicher. Detailgrad oder Ebenen reduzieren.');return job;
 },
 async bindSources(id,fingerprint){if(id!==job?.id||!/^[0-9a-f]{64}$/.test(fingerprint))throw Error('Ungültige Quellenausgabe.');if(job.fingerprint!==fingerprint&&count>0){for(const r of await (await open()).keys())if(r.url.startsWith(root+'prepared/'+id+'/'))await cache.delete(r);used=0;count=0;}job.fingerprint=fingerprint;await save();},
 async has(id,key){if(id!==job?.id||!validKey(key))throw Error('Ungültiger Offline-Schlüssel.');return !!await (await open()).match(root+'prepared/'+id+'/'+key);},
 async write(id,key,bytes,budget){if(id!==job?.id||!validKey(key)||!(bytes instanceof Uint8Array)||bytes.length>4*1024**2)throw Error('Ungültige Offline-Daten.');const c=await open(),url=root+'prepared/'+id+'/'+key,old=await c.match(url),previous=old?Number(old.headers.get('x-fpv-size')):0;if(used+bytes.length-previous>budget)throw Error('Speicherlimit erreicht. Vorhandene Region bleibt erhalten.');await c.put(url,new Response(bytes,{headers:{'content-type':key.endsWith('.json')?'application/json':key.endsWith('.png')?'image/png':'application/octet-stream','x-fpv-size':String(bytes.length),'x-fpv-fetched-at':new Date().toISOString()}}));used+=bytes.length-previous;if(!old)count++;},
 async commit(region){if(region.packageId!==job?.id||!count)throw Error('Offline-Aufbereitung unvollständig.');const c=await open(),response=await c.match(root+'regions.json'),previous=response?(await response.json()).regions:[];if(previous.filter(r=>r.id!==region.id).length>=12)throw Error('Höchstens 12 Offline-Regionen.');const actual=(await c.keys()).filter(r=>r.url.startsWith(root+'prepared/'+job.id+'/')).length;if(region.packageTiles!==actual)throw Error('Vorbereitete Dateien wurden verändert. Erneut starten.');region.packageTiles=count;const regions=[...previous.filter(r=>r.id!==region.id).map(r=>({...r,packageActive:false})),region];await c.put(root+'regions.json',new Response(JSON.stringify({revision:Date.now()*1000,regions})));await c.delete(journal);
  // Publication is the commit point. Cleanup failures must not undo success.
  try{const ids=new Set(regions.map(r=>r.packageId).filter(Boolean));for(const r of await c.keys()){const m=/\/prepared\/([0-9a-f]{64})\//.exec(r.url);if(m&&!ids.has(m[1]))await c.delete(r);}}catch(_){}
 }
 };
}
return {create,validKey};
});
