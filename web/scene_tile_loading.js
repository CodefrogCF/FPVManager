(function(root,factory){
    const api=factory();
    if(typeof module==='object'&&module.exports)module.exports=api;else root.FPVSceneTileLoading=api;
})(typeof globalThis!=='undefined'?globalThis:this,function(){
    'use strict';
    const registries=new WeakMap();
    const pause=()=>new Promise(resolve=>setTimeout(resolve,0));
    const now=()=>performance.now();
    // Keep the geometry, transforms, metadata and LOD thresholds intact. Only
    // turn large explicit header subtrees into ordinary external tilesets.
    // Blob contents stay local to this viewer; no new provider is involved.
    async function partition(json,baseUrl,{maxNodes=64,makeUrl,pause:yieldTask=pause,now:clock=now,
        budgetMs=2,signal}={}){
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
        if(nodes.length<=maxNodes)return json;
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
        return {...json,root:copies.get(json.root)};
    }
    function create(C){
        const factory=C.Cesium3DTileContentFactory,resourcePrototype=C.Resource?.prototype;
        const legacy={load:(url,options)=>C.Cesium3DTileset.fromUrl(url,options),dispose(){},status:()=>({supported:false})};
        if(!factory||typeof factory.externalTileset!=='function'||!resourcePrototype?.getUrlComponent||
            !globalThis.URL?.createObjectURL||!globalThis.Blob)return legacy;
        let registry=registries.get(factory);
        if(!registry){
            const external=factory.externalTileset,getUrl=resourcePrototype.getUrlComponent;
            const owners=new WeakMap(),blobUrls=new Set(),queue=[];
            let references=0,timer=null,prepared=0,fragments=0,liveBytes=0,maxConstructionMs=0,preparation=Promise.resolve();
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
                for(const url of owner.urls.keys()){URL.revokeObjectURL(url);blobUrls.delete(url);}
                liveBytes-=owner.bytes;owner.urls.clear();owner.bytes=0;
            }
            function urlComponent(...args){
                // Derived resources inherit a provider's version query. Local
                // blob URLs must be fetched without that inherited suffix.
                return blobUrls.has(this._url)?this._url:getUrl.apply(this,args);
            }
            async function slicedExternal(tileset,tile,resource,json){
                const owner=owners.get(tileset);
                if(!owner)return external(tileset,tile,resource,json);
                const signal=owner.abort.signal;signal.throwIfAborted();
                let result=json;
                if(!blobUrls.has(resource._url)){
                    const created=[];
                    try{
                        const task=preparation.then(()=>partition(json,resource.url,{signal,makeUrl:data=>{
                            const blob=new Blob([JSON.stringify(data)],{type:'application/json'});
                            if(owner.bytes+blob.size>64*1024*1024)throw Error('Local tileset header budget reached');
                            const url=URL.createObjectURL(blob);
                            owner.urls.set(url,blob.size);owner.bytes+=blob.size;liveBytes+=blob.size;blobUrls.add(url);created.push(url);fragments++;return url;
                        }}));
                        preparation=task.catch(()=>{});result=await task;
                        if(result!==json)prepared++;
                    }catch(error){
                        for(const url of created){
                            URL.revokeObjectURL(url);const size=owner.urls.get(url)||0;
                            owner.bytes-=size;liveBytes-=size;owner.urls.delete(url);blobUrls.delete(url);
                        }
                        if(signal.aborted)throw error;
                        result=json;
                    }
                }
                return enqueue(()=>external(tileset,tile,resource,result),signal);
            }
            registry={
                acquire(){if(references++===0){factory.externalTileset=slicedExternal;resourcePrototype.getUrlComponent=urlComponent;}},
                release(){if(--references===0){
                    if(factory.externalTileset===slicedExternal)factory.externalTileset=external;
                    if(resourcePrototype.getUrlComponent===urlComponent)resourcePrototype.getUrlComponent=getUrl;
                }},
                owners,releaseOwner:release,
                status:()=>({supported:true,prepared,fragments,liveFragments:blobUrls.size,liveBytes,queued:queue.length,maxConstructionMs})
            };
            registries.set(factory,registry);
        }
        registry.acquire();const active=new Set();let disposed=false;
        return {
            async load(url,options){
                const owner={abort:new AbortController(),urls:new Map(),bytes:0};active.add(owner);
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
    return {partition,create};
});
