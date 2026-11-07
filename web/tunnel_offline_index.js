/* FPVManager bundled Swiss tunnel centerlines (ODbL; source: OSM/Geofabrik).
 * Generated at release preparation time from a full-country extract.
 * Never sends map coordinates to an external service. A missing generated
 * catalogue is explicitly reported, not treated as 'no tunnels'. */
(function(root,factory){
    const api=factory();
    if(typeof module==='object'&&module.exports)module.exports=api;
    else root.FPVTunnelOfflineIndex=api;
})(typeof globalThis!=='undefined'?globalThis:this,function(){
    'use strict';
    const URL='data/tunnels/ch_tunnels_v1.json';
    const WEST=5.8,SOUTH=45.6,STEP=.25,MAX_BYTES=24*1024*1024,MAX_RESULTS=160;
    const validPoint=p=>Array.isArray(p)&&p.length===2&&p.every(Number.isFinite)&&
        p[0]>=5.6&&p[0]<=11&&p[1]>=45.4&&p[1]<=48;
    const key=(lon,lat)=>`${Math.floor((lon-WEST)/STEP)}:${Math.floor((lat-SOUTH)/STEP)}`;
    function cells(box){
        if(!Array.isArray(box)||box.length!==4||!box.every(Number.isFinite)||
            box[0]>=box[2]||box[1]>=box[3])throw Error('Invalid offline tunnel viewport');
        const startX=Math.floor((box[0]-WEST)/STEP),endX=Math.floor((box[2]-WEST)/STEP);
        const startY=Math.floor((box[1]-SOUTH)/STEP),endY=Math.floor((box[3]-SOUTH)/STEP);
        if((endX-startX+1)*(endY-startY+1)>100)
            throw Error('Offline tunnel viewport exceeds search budget');
        const result=[];
        for(let x=startX;x<=endX;x++)for(let y=startY;y<=endY;y++)result.push(`${x}:${y}`);
        return result;
    }
    function segmentHits(a,b,box){
        // Liang-Barsky: includes a segment crossing the viewport even if
        // neither endpoint is inside it (e.g. long Alpine rail tunnels).
        let lo=0,hi=1;
        const dx=b[0]-a[0],dy=b[1]-a[1];
        const p=[-dx,dx,-dy,dy],q=[a[0]-box[0],box[2]-a[0],a[1]-box[1],box[3]-a[1]];
        for(let i=0;i<4;i++){
            if(p[i]===0){if(q[i]<0)return false;continue;}
            const t=q[i]/p[i];
            if(p[i]<0)lo=Math.max(lo,t);else hi=Math.min(hi,t);
            if(lo>hi)return false;
        }
        return true;
    }
    function intersects(points,box){
        for(let i=1;i<points.length;i++)if(segmentHits(points[i-1],points[i],box))return true;
        return false;
    }
    function verify(document){
        if(!document||document.schemaVersion!==1||document.generated!==true||
            document.tileDegrees!==STEP||!Array.isArray(document.routes)||
            typeof document.tiles!=='object'||!document.tiles||
            typeof document.source!=='string'||document.source!=='OpenStreetMap (Geofabrik Switzerland extract)'||
            typeof document.snapshotDateUtc!=='string')
            throw Error('Bundled Swiss tunnel index missing or not generated. Run tool/build_ch_tunnel_index.py --download before release.');
        if(document.routes.length>120000||Object.keys(document.tiles).length>2000)
            throw Error('Bundled tunnel index exceeds memory budget');
        for(const r of document.routes){
            if(!Array.isArray(r)||r.length!==6||!Number.isSafeInteger(r[0])||r[0]<1||
                !Number.isInteger(r[1])||r[1]<0||r[1]>1000||
                !['tunnel','underpass'].includes(r[2])||!['road','railway'].includes(r[3])||
                typeof r[4]!=='string'||r[4].length>120||!Array.isArray(r[5])||
                r[5].length<2||r[5].length>512||!r[5].every(validPoint))
                throw Error('Invalid coordinates or metadata in bundled tunnel index');
        }
        for(const [tile,ids] of Object.entries(document.tiles)){
            if(!/^-?\d+:-?\d+$/.test(tile)||!Array.isArray(ids)||ids.length>12000||
                !ids.every(n=>Number.isInteger(n)&&n>=0&&n<document.routes.length))
                throw Error('Invalid tile lookup in bundled tunnel index');
        }
        return document;
    }
    function create({fetcher=(...args)=>fetch(...args),url=URL}={}){
        let promise=null;
        async function load(){
            if(!promise)promise=(async()=>{
                const response=await fetcher(url,{cache:'force-cache'});
                if(!response?.ok)throw Error(`Bundled Swiss tunnel index cannot be loaded (HTTP ${response?.status??'unknown'}).`);
                const declared=Number(response.headers?.get?.('content-length')||0);
                if(declared>MAX_BYTES)throw Error('Bundled tunnel index exceeds size limit');
                const text=await response.text();
                if(text.length>MAX_BYTES)throw Error('Bundled tunnel index exceeds size limit');
                return verify(JSON.parse(text));
            })().catch(error=>{promise=null;throw error;});
            return promise;
        }
        async function query(box){
            const document=await load(),found=new Set();
            for(const tile of cells(box))for(const idx of document.tiles[tile]||[])found.add(idx);
            const routes=[];
            for(const idx of found){
                const [osmId,part,kind,transport,name,coordinates]=document.routes[idx];
                if(!intersects(coordinates,box))continue;
                routes.push({id:`osm:${osmId}:${part}`,name,kind,transport,coordinates,
                    endpointsVerified:false,heightReference:'unavailable',
                    source:document.source,sourceId:`way/${osmId}`});
            }
            // Stable, geographical sort. The camera is usually near box center;
            // ordering by bounding-envelope distance prevents arbitrary PBF order
            // deciding which six structures are actually displayed.
            const cx=(box[0]+box[2])/2,cy=(box[1]+box[3])/2;
            const distance=r=>Math.min(...r.coordinates.map(p=>
                Math.hypot((p[0]-cx)*Math.cos(cy*Math.PI/180),p[1]-cy)));
            routes.sort((a,b)=>distance(a)-distance(b)||a.id.localeCompare(b.id));
            const incomplete=routes.length>MAX_RESULTS;
            return {routes:routes.slice(0,MAX_RESULTS),incomplete,
                source:document.source,snapshotDateUtc:document.snapshotDateUtc,
                totalIndexRoutes:document.routes.length};
        }
        return {load,query};
    }
    return {create,verify,intersects,cells,key,URL};
});
