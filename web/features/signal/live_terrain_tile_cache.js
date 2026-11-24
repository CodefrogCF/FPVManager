// Transient, provider-scoped cache of *highest available* Cesium terrain tiles.
// Unlike exact-position memoization, a decoded tile can answer new coordinates
// on the moving flight ray without another network request. Never persisted.
(function(root,factory){
    const api=factory();
    if(typeof module==='object'&&module.exports)module.exports=api;
    else root.FPVLiveTerrainTileCache=api;
})(typeof globalThis!=='undefined'?globalThis:this,function(){
    'use strict';
    // Closures preserve native Window timer receiver semantics; injected clocks still work.
    function create({C,capacity=128,ttlMs=120000,clock=()=>performance.now(),tileTimeoutMs=12000,
        timers={setTimeout:(fn,ms)=>setTimeout(fn,ms),clearTimeout:id=>clearTimeout(id)}}={}){
        if(!Number.isInteger(capacity)||capacity<1||capacity>128||!Number.isFinite(ttlMs)||ttlMs<1000)
            throw Error('Invalid live terrain tile cache limits');
        if(!Number.isFinite(tileTimeoutMs)||tileTimeoutMs<=0)throw Error('Invalid live terrain tile timeout');
        const tiles=new Map();
        let generation=0,source=null,generationController=new AbortController();
        const counts={tileRequests:0,tileCacheHits:0,fallbackSamples:0,timeouts:0};
        function reset(){++generation;generationController.abort(terrainError('SUPERSEDED','Live terrain provider changed'));generationController=new AbortController();tiles.clear();source=null;}
        function usable(){return tiles.size;}
        const delay=ms=>new Promise(resolve=>timers.setTimeout(resolve,ms));
        function terrainError(category,message){const error=Error(`${category}: ${message}`);error.category=category;return error;}
        // A caller can stop waiting without discarding useful shared tile I/O.
        // Shared I/O has its own finite budget, so a stalled promise cannot stay
        // in the cache and poison every following flight profile until TTL.
        function wait(work,signals=[],timeoutMs=null){
            return new Promise((resolve,reject)=>{
                const cleanups=[];let timer=null,settled=false;
                const finish=(fn,value)=>{
                    if(settled)return;settled=true;if(timer!==null)timers.clearTimeout(timer);
                    for(const cleanup of cleanups)cleanup();fn(value);
                };
                Promise.resolve(work).then(value=>finish(resolve,value),error=>finish(reject,error));
                for(const signal of signals){
                    if(!signal)continue;
                    const abort=()=>finish(reject,signal.reason?.category?signal.reason:terrainError('SUPERSEDED','Live terrain request cancelled'));
                    if(signal.aborted){abort();break;}
                    signal.addEventListener('abort',abort,{once:true});cleanups.push(()=>signal.removeEventListener('abort',abort));
                }
                if(!settled&&timeoutMs!==null)timer=timers.setTimeout(()=>{
                    counts.timeouts++;finish(reject,terrainError('TIMEOUT','Detailed terrain tile timed out'));
                },timeoutMs);
            });
        }
        async function nativeSample(provider,positions,signal,epoch){
            check(signal,epoch);counts.fallbackSamples+=positions.length;
            const result=await wait(C.sampleTerrainMostDetailed(provider,positions,true),[signal,generationController.signal]);
            check(signal,epoch);return result;
        }
        function check(signal,epoch){
            signal?.throwIfAborted?.();
            if(epoch!==generation)throw terrainError('SUPERSEDED','Live terrain provider changed');
        }
        function supported(provider){
            return typeof provider?.requestTileGeometry==='function'&&
                typeof provider?.availability?.computeMaximumLevelAtPosition==='function'&&
                typeof provider?.tilingScheme?.positionToTileXY==='function'&&
                typeof provider?.tilingScheme?.tileXYToRectangle==='function';
        }
        function remember(key,entry){
            tiles.delete(key);tiles.set(key,entry);
            while(tiles.size>capacity)tiles.delete(tiles.keys().next().value);
        }
        async function getTile(provider,group,epoch,signal){
            check(signal,epoch);
            const now=clock();
            const cached=tiles.get(group.key);
            if(cached&&now-cached.at<ttlMs){
                counts.tileCacheHits++;remember(group.key,cached);
                return wait(cached.work,[signal,generationController.signal]);
            }
            tiles.delete(group.key);
            const raw=(async()=>{
                let tile;
                for(let attempt=0;attempt<4;attempt++){
                    check(undefined,epoch);
                    counts.tileRequests++;
                    const request=provider.requestTileGeometry(group.x,group.y,group.level);
                    if(request!==undefined){tile=await request;break;}
                    // Cesium returns undefined while its request scheduler is full.
                    await delay(40*(attempt+1));
                }
                check(undefined,epoch);
                if(!tile||typeof tile.interpolateHeight!=='function')
                    throw Error('Detailed terrain tile unavailable');
                return tile;
            })();
            const work=wait(raw,[generationController.signal],tileTimeoutMs);
            const entry={at:now,work};
            remember(group.key,entry);
            // Evict failed work even if all consumers have already cancelled.
            work.catch(()=>{if(tiles.get(group.key)===entry)tiles.delete(group.key);});
            return wait(work,[signal,generationController.signal]);
        }
        async function sample(provider,positions,signal){
            if(!provider?.availability||typeof C?.sampleTerrainMostDetailed!=='function')
                throw Error('Detailed live terrain unavailable');
            // Preserve Cesium's own availability discovery when the maximum
            // terrain level is not known, or the provider lacks tile APIs.
            // Never interpret a level-12 or rendered-globe height as detailed.
            if(source!==provider){reset();source=provider;}
            if(!supported(provider))return nativeSample(provider,positions,signal,generation);
            // Keep the proven Cesium bulk sampling path for long-range
            // corridors, where caching hundreds of unrelated tiles would
            // evict useful near-field meshes and add request-scheduling cost.
            // Cesium Cartographic coordinates are radians.
            const first=positions[0];
            if(Math.abs(first.latitude)<=Math.PI/2&&Math.abs(first.longitude)<=Math.PI&&positions.some(p=>{
                const dy=(p.latitude-first.latitude)*6371009;
                const dx=(p.longitude-first.longitude)*6371009*Math.cos(first.latitude);
                return dx*dx+dy*dy>7000*7000;
            }))return nativeSample(provider,positions,signal,generation);
            const epoch=generation,groups=new Map();
            for(let i=0;i<positions.length;i++){
                const point=positions[i];
                const level=provider.availability.computeMaximumLevelAtPosition(point);
                if(!Number.isInteger(level)||level<=0)
                    return nativeSample(provider,positions,signal,generation);
                const tile=provider.tilingScheme.positionToTileXY(point,level);
                if(!tile||!Number.isInteger(tile.x)||!Number.isInteger(tile.y))
                    return nativeSample(provider,positions,signal,generation);
                const key=`${level}/${tile.x}/${tile.y}`;
                let group=groups.get(key);
                if(!group){group={key,level,x:tile.x,y:tile.y,indices:[]};groups.set(key,group);}
                group.indices.push(i);
            }
            const result=new Array(positions.length);
            // Long corridors can intersect more high-detail tiles than our RAM
            // budget. Process warm tiles FIRST: streaming the ray from the fixed
            // station to the drone otherwise evicts cached tail tiles before
            // reaching them on every subsequent flight update (LRU scan thrash).
            const pending=[...groups.values()].sort((a,b)=>
                Number(tiles.has(b.key))-Number(tiles.has(a.key)));
            let cursor=0;
            const fallbackGroups=[];
            // Four workers cap request pressure. A batch of 256 positions on
            // one terrain tile creates only one tile request, not 256.
            const worker=async()=>{
                while(cursor<pending.length){
                    check(signal,epoch);
                    const group=pending[cursor++];
                    try{
                        const tile=await getTile(provider,group,epoch,signal);
                        check(signal,epoch);
                        const rect=provider.tilingScheme.tileXYToRectangle(group.x,group.y,group.level);
                        for(const i of group.indices){
                            const point=positions[i];
                            const height=tile.interpolateHeight(rect,point.longitude,point.latitude);
                            if(!Number.isFinite(height)||Math.abs(height)>100000)
                                throw Error('Incomplete detailed terrain tile interpolation');
                            result[i]={...point,height};
                        }
                    }catch(error){
                        check(signal,epoch);
                        // One missing tile must not discard the other, already
                        // decoded and reusable high-detail tiles along the ray.
                        // Only this group requires Cesium's native fallback.
                        fallbackGroups.push(group);
                    }
                }
            };
            await Promise.all(Array.from({length:Math.min(4,pending.length)},worker));
            check(signal,epoch);
            // Availability can gain finer tiles while loading. Replace ONLY
            // affected groups, at Cesium's highest now-known resolution.
            const needFallback=new Set(fallbackGroups);
            for(const group of groups.values()){
                if(group.indices.some(i=>
                    provider.availability.computeMaximumLevelAtPosition(positions[i])!==group.level))
                    needFallback.add(group);
            }
            if(needFallback.size){
                const indices=[...needFallback].flatMap(group=>group.indices);
                const finer=await nativeSample(provider,indices.map(i=>positions[i]),signal,epoch);
                check(signal,epoch);
                if(!Array.isArray(finer)||finer.length!==indices.length)
                    throw Error('Incomplete detailed terrain fallback');
                for(let n=0;n<indices.length;n++){
                    const point=finer[n];
                    if(!Number.isFinite(point?.height)||Math.abs(point.height)>100000)
                        throw Error('Incomplete detailed terrain fallback');
                    result[indices[n]]=point;
                }
            }
            check(signal,epoch);
            if(result.some(point=>!Number.isFinite(point?.height)||Math.abs(point.height)>100000))
                throw Error('Incomplete detailed terrain profile');
            return result;
        }
        return {sample,reset,diagnostics:()=>({...counts,cachedTiles:usable(),generation}),get cachedTiles(){return usable();}};
    }
    return {create};
});
