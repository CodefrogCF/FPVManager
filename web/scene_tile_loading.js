(function(root,factory){
    const api=factory();
    if(typeof module==='object'&&module.exports)module.exports=api;else root.FPVSceneTileLoading=api;
})(typeof globalThis!=='undefined'?globalThis:this,function(){
    'use strict';
    const registries=new WeakMap();
    const pause=()=>new Promise(resolve=>setTimeout(resolve,0));
    const now=()=>performance.now();
    function validRegion(region){
        return Array.isArray(region)&&region.length===6&&region.every(Number.isFinite)&&
            region[0]>=-Math.PI&&region[2]<=Math.PI&&region[0]<=region[2]&&
            region[1]>=-Math.PI/2&&region[3]<=Math.PI/2&&region[1]<=region[3]&&region[4]<=region[5];
    }
    function encloseRegion(region,other){
        // Geographic regions are global, regardless of the tile's transform.
        // Keep unsupported/dateline-wrapping volumes on their original path.
        if(!validRegion(region)||!validRegion(other))return region;
        if(region[0]<=other[0]&&region[1]<=other[1]&&region[2]>=other[2]&&region[3]>=other[3]&&
            region[4]<=other[4]&&region[5]>=other[5])return region;
        const next=[Math.min(region[0],other[0]),Math.min(region[1],other[1]),
            Math.max(region[2],other[2]),Math.max(region[3],other[3]),
            Math.min(region[4],other[4]),Math.max(region[5],other[5])];
        return next.every((value,i)=>value===region[i])?region:next;
    }
    function encloseTileAncestors(tile,region){
        let expanded=0;
        for(let node=tile;node;node=node.parent){
            const volume=node._header?.boundingVolume,current=volume?.region;
            if(!validRegion(current)||!validRegion(region))break;
            const next=encloseRegion(current,region);
            if(next!==current){
                if(typeof node.createBoundingVolume!=='function')break;
                const replacement={...volume,region:next};
                // Refresh Cesium's cached volume as well as the header;
                // unchanged transforms would otherwise retain the old bounds.
                node._boundingVolume=node.createBoundingVolume(replacement,node.computedTransform,node._boundingVolume);
                node._header={...node._header,boundingVolume:replacement};
                node._updatedVisibilityFrame=-1;
                node._debugBoundingVolume=node._debugBoundingVolume&&node._debugBoundingVolume.destroy();
                expanded++;
            }
            region=next;
        }
        return expanded;
    }
    // Keep the geometry, transforms, metadata and LOD thresholds intact. Only
    // turn large explicit header subtrees into ordinary external tilesets.
    // Fragment contents stay local to this viewer.
    async function partition(json,baseUrl,{maxNodes=64,makeUrl,pause:yieldTask=pause,now:clock=now,
        budgetMs=2,signal,onBoundsExpanded=()=>{}}={}){
        if(!json?.root||!json.asset||!['0.0','1.0','1.1'].includes(json.asset.version)||
            !makeUrl||!Number.isInteger(maxNodes)||maxNodes<4)return json;
        let deadline=clock()+budgetMs,checks=0;
        function yieldIfNeeded(force=false){
            signal?.throwIfAborted();
            if((++checks%64===0||force)&&clock()>=deadline)return yieldTask().then(()=>{
                deadline=clock()+budgetMs;signal?.throwIfAborted();
            });
        }
        const nodes=[],stack=[json.root],seen=new Set();
        while(stack.length){
            const node=stack.pop();
            if(!node||typeof node!=='object'||seen.has(node)||node.implicitTiling||
                node.extensions?.['3DTILES_implicit_tiling']||!node.boundingVolume||
                node.children!==undefined&&!Array.isArray(node.children))return json;
            seen.add(node);nodes.push(node);
            if(nodes.length>300000)return json;
            for(const child of node.children||[])stack.push(child);
            const pending=yieldIfNeeded();if(pending)await pending;
        }
        const split=nodes.length>maxNodes;let expanded=0;
        const base=new URL(baseUrl);
        if(json.asset.tilesetVersion!=null)base.searchParams.set('v',String(json.asset.tilesetVersion));
        const query=new Map();
        for(const [key,value] of base.searchParams){if(!query.has(key))query.set(key,[]);query.get(key).push(value);}
        function absolute(uri){
            if(typeof uri!=='string')return uri;
            if(/^data:/i.test(uri))return uri;
            const url=new URL(uri,base);
            for(const [key,values] of query)if(!url.searchParams.has(key))
                for(const value of values)url.searchParams.append(key,value);
            return url.href;
        }
        function content(value){
            const result={...value};
            if(value.uri!==undefined)result.uri=absolute(value.uri);
            if(value.url!==undefined)result.url=absolute(value.url);
            return result;
        }
        const asset={...json.asset};delete asset.tilesetVersion;
        const template={...json,asset};delete template.root;
        const copies=new Map(),sizes=new Map();
        function external(node){
            const root={...node};delete root.transform;
            const uri=makeUrl({...template,root});
            const proxy={...node,content:{uri}};delete proxy.contents;delete proxy.children;
            sizes.set(proxy,1);return proxy;
        }
        for(let i=nodes.length-1;i>=0;i--){
            const source=nodes[i],copy={...source};
            if(source.content)copy.content=content(source.content);
            if(source.contents)copy.contents=source.contents.map(content);
            let children=(source.children||[]).map(child=>copies.get(child));
            // Some building tiles describe their grid cell, while their own
            // content bounds include a hall extending beyond that cell. Cesium
            // rejects the tile before testing its larger content volume. Carry
            // the complete content/child regions up the hierarchy so a visible
            // roof or facade cannot disappear when its cell leaves the view.
            let region=source.boundingVolume.region;
            for(const item of [copy.content,...(copy.contents||[])])region=encloseRegion(region,item?.boundingVolume?.region);
            for(const child of children)region=encloseRegion(region,child.boundingVolume.region);
            if(region!==source.boundingVolume.region){
                copy.boundingVolume={...source.boundingVolume,region};expanded++;
            }
            let count=1+children.reduce((sum,child)=>sum+sizes.get(child),0);
            if(count>maxNodes){
                const deferred=[];
                for(const child of children){
                    deferred.push(sizes.get(child)>1?external(child):child);
                    const pending=yieldIfNeeded(true);if(pending)await pending;
                }
                children=deferred;
                while(children.length+1>maxNodes){
                    const groups=[];
                    for(let k=0;k<children.length;k+=maxNodes-1){
                        const group={boundingVolume:copy.boundingVolume,geometricError:copy.geometricError,
                            ...(copy.refine?{refine:copy.refine}:{}),children:children.slice(k,k+maxNodes-1)};
                        groups.push(external(group));
                        const pending=yieldIfNeeded(true);if(pending)await pending;
                    }
                    children=groups;const pending=yieldIfNeeded();if(pending)await pending;
                }
                count=1+children.length;
            }
            if(source.children!==undefined)copy.children=children;
            copies.set(source,copy);sizes.set(copy,count);
            const pending=yieldIfNeeded();if(pending)await pending;
        }
        if(!split&&!expanded)return json;
        onBoundsExpanded(expanded);
        return {...json,root:copies.get(json.root)};
    }
    function create(C,{headerBudgetBytes=64*1024*1024}={}){
        const factory=C.Cesium3DTileContentFactory,resourcePrototype=C.Resource?.prototype;
        const legacy={load:(url,options)=>C.Cesium3DTileset.fromUrl(url,options),dispose(){},status:()=>({supported:false})};
        if(!factory||typeof factory.externalTileset!=='function'||!resourcePrototype?.getUrlComponent||
            !resourcePrototype?.fetchArrayBuffer||!C.RequestState||!globalThis.TextEncoder)return legacy;
        let registry=registries.get(factory);
        if(!registry){
            const external=factory.externalTileset,getUrl=resourcePrototype.getUrlComponent;
            const fetchBuffer=resourcePrototype.fetchArrayBuffer;
            const owners=new WeakMap(),localFragments=new Map(),queue=[];
            const encoder=new TextEncoder(),prefix='fpv-scene-fragment://local/';
            let references=0,timer=null,prepared=0,fragments=0,liveBytes=0,expandedBounds=0,maxConstructionMs=0,preparation=Promise.resolve();
            function drain(){
                timer=null;const deadline=now()+2;
                do{
                    const job=queue.shift();if(!job)break;
                    try{job.signal.throwIfAborted();const start=now(),result=job.run();
                        maxConstructionMs=Math.max(maxConstructionMs,now()-start);job.resolve(result);
                    }catch(error){job.reject(error);}
                }while(queue.length&&now()<deadline);
                if(queue.length)timer=setTimeout(drain,8);
            }
            const enqueue=(run,signal)=>new Promise((resolve,reject)=>{
                queue.push({run,signal,resolve,reject});if(timer===null)timer=setTimeout(drain,0);
            });
            function release(owner){
                owner.abort.abort();
                for(const url of owner.urls.keys())localFragments.delete(url);
                liveBytes-=owner.bytes;owner.urls.clear();owner.bytes=0;
            }
            function urlComponent(...args){
                // Local fragment identities must omit the inherited provider query.
                return this._url.startsWith(prefix)?this._url:getUrl.apply(this,args);
            }
            function fetchArrayBuffer(...args){
                if(!this._url.startsWith(prefix))return fetchBuffer.apply(this,args);
                if(this.request.cancelled){
                    this.request.state=C.RequestState.CANCELLED;
                    return Promise.reject(new DOMException('Local tileset request cancelled','AbortError'));
                }
                const buffer=localFragments.get(this._url);
                if(!buffer)return Promise.reject(Error('Local tileset fragment has been released'));
                // Cesium processes this local JSON through its regular external-
                // tileset path. Skip the browser's blob registration and fetch.
                this.request.state=C.RequestState.RECEIVED;
                return Promise.resolve(buffer);
            }
            async function slicedExternal(tileset,tile,resource,json){
                const owner=owners.get(tileset);
                if(!owner)return external(tileset,tile,resource,json);
                const signal=owner.abort.signal;signal.throwIfAborted();
                let result=json;
                if(!resource._url.startsWith(prefix)){
                    const created=[];
                    try{
                        const task=preparation.then(()=>partition(json,resource.url,{signal,onBoundsExpanded:count=>{expandedBounds+=count;},makeUrl:data=>{
                            const buffer=encoder.encode(JSON.stringify(data)).buffer;
                            if(owner.bytes+buffer.byteLength>owner.headerBudgetBytes){
                                const error=Error('Local tileset header budget reached');error.code='FPV_HEADER_BUDGET';throw error;
                            }
                            const url=`${prefix}${++fragments}.json`;
                            owner.urls.set(url,buffer.byteLength);owner.bytes+=buffer.byteLength;liveBytes+=buffer.byteLength;
                            localFragments.set(url,buffer);created.push(url);return url;
                        }}));
                        preparation=task.catch(()=>{});result=await task;
                        if(result!==json)prepared++;
                    }catch(error){
                        for(const url of created){
                            const size=owner.urls.get(url)||0;
                            owner.bytes-=size;liveBytes-=size;owner.urls.delete(url);localFragments.delete(url);
                        }
                        if(signal.aborted)throw error;
                        result=json;
                        if(error.code==='FPV_HEADER_BUDGET'){
                            // Bounds correctness must also survive the memory
                            // fallback. Repair without making more fragments.
                            const task=preparation.then(()=>partition(json,resource.url,{signal,maxNodes:300001,
                                makeUrl(){},onBoundsExpanded:count=>{expandedBounds+=count;}}));
                            preparation=task.catch(()=>{});result=await task;
                        }
                    }
                }
                return enqueue(()=>{
                    expandedBounds+=encloseTileAncestors(tile,result.root?.boundingVolume?.region);
                    return external(tileset,tile,resource,result);
                },signal);
            }
            registry={
                acquire(){if(references++===0){factory.externalTileset=slicedExternal;resourcePrototype.getUrlComponent=urlComponent;
                    resourcePrototype.fetchArrayBuffer=fetchArrayBuffer;}},
                release(){if(--references===0){
                    if(factory.externalTileset===slicedExternal)factory.externalTileset=external;
                    if(resourcePrototype.getUrlComponent===urlComponent)resourcePrototype.getUrlComponent=getUrl;
                    if(resourcePrototype.fetchArrayBuffer===fetchArrayBuffer)resourcePrototype.fetchArrayBuffer=fetchBuffer;
                }},
                owners,releaseOwner:release,
                status:()=>({supported:true,prepared,fragments,liveFragments:localFragments.size,liveBytes,queued:queue.length,expandedBounds,maxConstructionMs})
            };
            registries.set(factory,registry);
        }
        registry.acquire();const active=new Set();let disposed=false;
        return {
            async load(url,options){
                const owner={abort:new AbortController(),urls:new Map(),bytes:0,headerBudgetBytes};active.add(owner);
                try{
                    const tileset=await C.Cesium3DTileset.fromUrl(url,options);
                    if(disposed){tileset.destroy();throw Error('Scene loader disposed');}
                    registry.owners.set(tileset,owner);
                    const destroy=tileset.destroy;
                    tileset.destroy=function(...args){registry.releaseOwner(owner);active.delete(owner);return destroy.apply(this,args);};
                    return tileset;
                }catch(error){registry.releaseOwner(owner);active.delete(owner);throw error;}
            },
            status:registry.status,
            dispose(){if(disposed)return;disposed=true;for(const owner of active)registry.releaseOwner(owner);active.clear();registry.release();}
        };
    }
    return {partition,create,encloseRegion,encloseTileAncestors};
});
