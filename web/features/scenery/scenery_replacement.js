// Explicit geographic masks. Physics only trusts clipping still owned/applied here.
(function(root,factory){const api=factory(typeof module==='object'&&module.exports?require('./scenery_alignment.js'):root.FPVSceneryAlignment,typeof module==='object'&&module.exports?require('./scenery_collision.js'):root.FPVSceneryCollision);if(typeof module==='object'&&module.exports)module.exports=api;else root.FPVSceneryReplacement=api;})(globalThis,function(A,Collision){
    'use strict';
    function normalize(value,anchor){
        if(value===undefined)return null;
        const b=value?.buildings,t=value?.terrain;
        if(value?.schemaVersion!==1||typeof b?.enabled!=='boolean'||typeof t?.enabled!=='boolean'||!Array.isArray(b.regions)||!Array.isArray(b.features)||b.features.length>128||!Array.isArray(t.regions)||t.regions.length>24)throw Error('Invalid replacement configuration');
        const regions=A.normalizeRegions(b.regions,anchor),seen=new Set();
        const features=b.features.map(f=>{
            if(!['swisstopo','bkg'].includes(f?.provider)||typeof f.property!=='string'||!/^[A-Za-z_][A-Za-z0-9_:.-]{0,127}$/.test(f.property)||typeof f.id!=='string'||!f.id.trim()||f.id.length>256||seen.has(JSON.stringify(f)))throw Error('Invalid building identifier');
            const result={provider:f.provider,property:f.property,id:f.id},key=JSON.stringify(result);if(seen.has(key))throw Error('Duplicate building identifier');seen.add(key);return result;
        });
        const terrain=t.regions.map(r=>{if(!r||![r.minimumUpM,r.maximumUpM,r.seamToleranceM].every(Number.isFinite)||Math.abs(r.minimumUpM)>1e5||Math.abs(r.maximumUpM)>1e5||r.maximumUpM<=r.minimumUpM||r.seamToleranceM<.05||r.seamToleranceM>.5)throw Error('Invalid replacement ground range/seam tolerance');return {polygon:A.normalizeRegions([r.polygon],anchor)[0],minimumUpM:r.minimumUpM,maximumUpM:r.maximumUpM,seamToleranceM:r.seamToleranceM};});
        if(b.enabled&&!regions.length&&!features.length||t.enabled&&!terrain.length)throw Error('Enabled replacement needs a region or identifier');
        return {schemaVersion:1,buildings:{enabled:b.enabled,regions,features},terrain:{enabled:t.enabled,regions:terrain}};
    }
    const unwrap=(x,reference)=>reference+((x-reference+540)%360-180);
    function inside(point,polygon){
        if(!point||!polygon?.length)return false;
        const x=point.longitude,y=point.latitude;let yes=false;
        for(let j=polygon.length-1,i=0;i<polygon.length;j=i++){
            const ax=unwrap(polygon[j][0],x),ay=polygon[j][1],bx=unwrap(polygon[i][0],x),by=polygon[i][1];
            if(Math.abs((bx-ax)*(y-ay)-(by-ay)*(x-ax))<1e-13&&x>=Math.min(ax,bx)-1e-12&&x<=Math.max(ax,bx)+1e-12&&y>=Math.min(ay,by)-1e-12&&y<=Math.max(ay,by)+1e-12)return true;
            if((ay>y)!==(by>y)&&x<(bx-ax)*(y-ay)/(by-ay)+ax)yes=!yes;
        }return yes;
    }
    // Partition at every polygon edge, then classify intervals. This preserves
    // terrain in concavities and between disconnected/overlapping masks.
    function outsideIntervals(from,to,polygons){
        const x=from.longitude,y=from.latitude,dx=unwrap(to.longitude,x)-x,dy=to.latitude-y,cuts=[0,1];
        for(const poly of polygons)for(let j=poly.length-1,i=0;i<poly.length;j=i++){
            const a=poly[j],b=poly[i],ax=unwrap(a[0],x),bx=unwrap(b[0],x),ex=bx-ax,ey=b[1]-a[1],den=dx*ey-dy*ex;
            if(Math.abs(den)<1e-20)continue;
            const qx=ax-x,qy=a[1]-y,t=(qx*ey-qy*ex)/den,u=(qx*dy-qy*dx)/den;
            if(t>0&&t<1&&u>=0&&u<=1)cuts.push(t);
        }
        cuts.sort((a,b)=>a-b);const result=[];
        for(let i=1;i<cuts.length;i++){const a=cuts[i-1],b=cuts[i];if(b-a<1e-12)continue;const t=(a+b)/2;
            if(!polygons.some(p=>inside({longitude:x+dx*t,latitude:y+dy*t},p))){const last=result.at(-1);if(last&&Math.abs(last[1]-a)<1e-10)last[1]=b;else result.push([a,b]);}}
        if(!result.length&&cuts.length===2&&!polygons.some(p=>inside(from,p)))return [[0,1]];
        return result;
    }
    function seamPoints(region,alignment){
        const p=region.polygon,out=[];
        for(let i=0;i<p.length;i++){const a=p[i],b=p[(i+1)%p.length],u=A.localPoint(alignment,{longitude:a[0],latitude:a[1]}),v=A.localPoint(alignment,{longitude:b[0],latitude:b[1]}),n=Math.max(1,Math.ceil(Math.hypot(v.x-u.x,v.y-u.y)/3));
            if(out.length+n>2048)return [];
            for(let j=0;j<n;j++)out.push({longitude:((a[0]+(unwrap(b[0],a[0])-a[0])*j/n+540)%360)-180,latitude:a[1]+(b[1]-a[1])*j/n});
        }return out;
    }
    function ground(meshes,frame,region,point){
        const p=frame.local(point),hi=region.maximumUpM,lo=region.minimumUpM,epsilon=1e-5;let best=-Infinity;
        for(const mesh of meshes){const hit=Collision.sweep(mesh,[p[0],p[1],hi+epsilon],[p[0],p[1],lo-epsilon],epsilon);if(hit)best=Math.max(best,hi+epsilon-(hi-lo+2*epsilon)*hit.fraction-epsilon);}
        return Number.isFinite(best)?point.height+(best-p[2])*frame.scale:undefined;
    }
    function evaluate(meshes,frame,region,points,heights){
        if(!points.length||!Array.isArray(heights)||points.length!==heights.length)return {approved:false,samples:0,maxErrorM:null};
        let max=0;for(let i=0;i<points.length;i++){const h=heights[i];if(!Number.isFinite(h))return {approved:false,samples:i,maxErrorM:null};const z=ground(meshes,frame,region,{...points[i],height:h});if(!Number.isFinite(z))return {approved:false,samples:i,maxErrorM:null};max=Math.max(max,Math.abs(z-h));}
        return {approved:max<=region.seamToleranceM,samples:points.length,maxErrorM:max};
    }
    function create(C,viewer,{buildingTargets=()=>[],buildingRegions=()=>[],buildingFeatures=()=>[],terrainRegions=()=>[],terrainReady=()=>false,terrainKey=()=>null}={}){
        const scene=viewer.scene,leases=new Map(),featureOwners=new Map();let disposed=false,revision=0,signature='',lastStatus={};
        const polygonKey=p=>JSON.stringify(p),supported=()=>!!C.ClippingPolygonCollection?.isSupported?.(scene);
        function release(key){const old=leases.get(key);if(!old)return;
            // Cesium 1.145 loaded tile models can retain the collection after
            // tileset detachment. Disable/empty our own instance first so those
            // models release the cut too, without reloading provider content.
            old.collection.enabled=false;old.collection.removeAll?.();try{if(old.owner.clippingPolygons===old.collection)old.owner.clippingPolygons=undefined;}catch(_){}leases.delete(key);scene.requestRender?.();}
        function clip(key,owner,regions){
            const old=leases.get(key);if(old&&(old.owner!==owner||old.owner.clippingPolygons!==old.collection||!regions.length))release(key);
            if(!owner||!regions.length)return null;
            if(!supported()||!('clippingPolygons' in owner))return 'Polygon clipping is unsupported';
            if(owner.clippingPolygons&&owner.clippingPolygons!==leases.get(key)?.collection)return 'Another feature owns polygon clipping';
            const unique=[...new Map(regions.map(p=>[polygonKey(p),p])).values()],hash=JSON.stringify(unique);
            if(leases.get(key)?.key===hash)return null;
            try{const prior=leases.get(key);if(prior){prior.collection.enabled=false;prior.collection.removeAll?.();}
                const collection=new C.ClippingPolygonCollection({polygons:unique.map(p=>new C.ClippingPolygon({positions:p.map(([lon,lat])=>C.Cartesian3.fromDegrees(lon,lat,0))}))});owner.clippingPolygons=collection;leases.set(key,{owner,collection,key:hash,regions:unique});scene.requestRender?.();return null;}
            catch(error){release(key);return String(error.message||error);}
        }
        function restoreFeature(owner,feature){const value=owner.hidden.get(feature);if(value===undefined)return;try{feature.show=value.show;}catch(_){}owner.hidden.delete(feature);}
        function disposeFeatures(key){const owner=featureOwners.get(key);if(!owner)return;for(const feature of owner.hidden.keys())restoreFeature(owner,feature);for(const off of owner.off)off?.();featureOwners.delete(key);}
        function visit(content,fn){if(!content)return;for(const inner of content.innerContents??[])visit(inner,fn);for(let i=0;i<(content.featuresLength??0);i++)fn(content.getFeature(i));}
        function matches(owner,f){for(const [property,ids]of owner.index){try{const value=f.getProperty(property);if((typeof value==='string'||typeof value==='number'&&Number.isSafeInteger(value))&&ids.has(String(value)))return true;}catch(_){}}return false;}
        function syncFeatures(target,rules){
            let owner=featureOwners.get(target.key);if(owner&&owner.tileset!==target.tileset){disposeFeatures(target.key);owner=null;}
            if(!rules.length){disposeFeatures(target.key);return;}
            if(!owner){owner={tileset:target.tileset,hidden:new Map(),off:[],rules,index:new Map(),signature:''};featureOwners.set(target.key,owner);
                if(!target.tileset.tileVisible?.addEventListener){owner.error='Provider has no feature visibility events';return;}
                owner.off.push(target.tileset.tileVisible.addEventListener(tile=>visit(tile.content,f=>{
                    const match=matches(owner,f);
                    if(match){if(!owner.hidden.has(f))owner.hidden.set(f,{show:f.show,tile});f.show=false;}else restoreFeature(owner,f);
                })));
                owner.off.push(target.tileset.tileUnload?.addEventListener?.(tile=>{for(const [f,v]of owner.hidden)if(v.tile===tile)owner.hidden.delete(f);}));
            }
            const signature=JSON.stringify(rules);if(owner.signature===signature)return;owner.signature=signature;owner.rules=rules;owner.index=new Map();for(const rule of rules){if(!owner.index.has(rule.property))owner.index.set(rule.property,new Set());owner.index.get(rule.property).add(rule.id);}
            // Apply changed IDs immediately to already hidden features; newly
            // selected resident features are visited on the next Cesium frame.
            for(const f of [...owner.hidden.keys()])if(!matches(owner,f))restoreFeature(owner,f);
        }
        function active(lease){return lease&&lease.owner.clippingPolygons===lease.collection&&lease.collection.enabled!==false&&lease.collection.inverse!==true&&(lease.collection.length===undefined||lease.collection.length===lease.regions.length)&&supported();}
        function sync(){if(disposed)return;const targets=buildingTargets().filter(t=>t.tileset&&t.tileset.show!==false),keys=new Set(),errors=[];
            const buildings=buildingRegions(),features=buildingFeatures();for(const target of targets){keys.add(target.key);const err=clip('buildings:'+target.key,target.tileset,buildings);if(err)errors.push(target.key+': '+err);syncFeatures(target,features.filter(f=>f.provider===target.key));}
            for(const key of [...leases.keys()])if(key.startsWith('buildings:')&&!keys.has(key.slice(10)))release(key);
            for(const key of [...featureOwners.keys()])if(!keys.has(key))disposeFeatures(key);
            const globe=scene.globe,requestedTerrain=terrainRegions(),blocked=!!globe?.material||!!globe?.clippingPlanes?.length,terrain=terrainReady()&&!blocked?requestedTerrain:[];
            if(blocked&&requestedTerrain.length)errors.push('Terrain clipping is reserved by a globe material or clipping planes');
            if(leases.has('terrain')&&leases.get('terrain').provider!==terrainKey())release('terrain');
            const err=clip('terrain',globe,terrain);if(err)errors.push('terrain: '+err);if(leases.has('terrain'))leases.get('terrain').provider=terrainKey();
            const current=JSON.stringify({buildings:[...leases].filter(([k,v])=>k.startsWith('buildings:')&&active(v)).map(([k,v])=>[k,v.key]),terrain:active(leases.get('terrain'))?leases.get('terrain').key:null,features:features.filter(f=>keys.has(f.provider))});
            if(current!==signature){signature=current;revision++;scene.requestRender?.();}
            lastStatus={supported:supported(),buildingActive:[...leases].some(([k,v])=>k.startsWith('buildings:')&&active(v))||[...featureOwners.values()].some(o=>o.hidden.size>0),terrainActive:active(leases.get('terrain'))===true,hiddenFeatures:[...featureOwners.values()].reduce((n,o)=>n+o.hidden.size,0),errors:[...errors,...[...featureOwners.values()].map(o=>o.error).filter(Boolean)],revision};
        }
        function terrainPolygons(){const lease=leases.get('terrain');return terrainReady()&&lease?.provider===terrainKey()&&active(lease)?lease.regions:[];}
        const off=scene.preUpdate?.addEventListener?.(sync);
        return {sync,revision:()=>revision,status:()=>{sync();return {...lastStatus};},terrainMaskActive:p=>terrainPolygons().some(poly=>polygonKey(poly)===polygonKey(p)),terrainIntervals:(a,b)=>outsideIntervals(a,b,terrainPolygons()),
            dispose(){if(disposed)return;disposed=true;off?.();for(const key of [...leases.keys()])release(key);for(const key of [...featureOwners.keys()])disposeFeatures(key);}};
    }
    return {normalize,inside,outsideIntervals,seamPoints,ground,evaluate,create};
});
