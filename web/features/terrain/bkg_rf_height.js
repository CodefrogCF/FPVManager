/* Local experimental BKG radio height adapter. Rendering keeps native mesh heights. */
(function(root,factory){const api=factory();if(typeof module==='object'&&module.exports)module.exports=api;else root.FPVBkgRfHeight=api;})(typeof globalThis!=='undefined'?globalThis:this,function(){
    'use strict';
    function create(grid){
        // Generated from the user's local GCG2016 raster and independent probe.
        // A rectangular experimental coverage is deliberately not nationwide certification.
        const valid=grid?.schema===1&&grid?.datum==='DHHN2016'&&grid?.provider==='https://sgx.geodatenzentrum.de/gdz_basemapde_3d_gelaende/dgm5_4326_mesh/'&&
            [grid.west,grid.south,grid.stepLon,grid.stepLat].every(Number.isFinite)&&grid.stepLon>0&&grid.stepLat>0&&
            Number.isInteger(grid.cols)&&Number.isInteger(grid.rows)&&grid.cols>=2&&grid.rows>=2&&grid.cols*grid.rows<=10000&&
            Array.isArray(grid.values)&&grid.values.length===grid.cols*grid.rows&&grid.values.every(v=>Number.isFinite(v)&&v>10&&v<100)&&
            grid.west>=13.775-1e-9&&grid.south>=52.481-1e-9&&grid.west+(grid.cols-1)*grid.stepLon<=13.800+1e-9&&grid.south+(grid.rows-1)*grid.stepLat<=52.491+1e-9;
        function offset(p){
            if(!valid||!p||!Number.isFinite(p.longitude)||!Number.isFinite(p.latitude))return null;
            const x=(p.longitude-grid.west)/grid.stepLon,y=(p.latitude-grid.south)/grid.stepLat;
            if(x< -1e-8||y< -1e-8||x>grid.cols-1+1e-8||y>grid.rows-1+1e-8)return null;
            const i=Math.min(grid.cols-2,Math.max(0,Math.floor(x))),j=Math.min(grid.rows-2,Math.max(0,Math.floor(y)));
            const a=Math.max(0,Math.min(1,x-i)),b=Math.max(0,Math.min(1,y-j)),k=j*grid.cols+i,v=grid.values;
            return (1-b)*((1-a)*v[k]+a*v[k+1])+b*((1-a)*v[k+grid.cols]+a*v[k+grid.cols+1]);
        }
        function requireOffset(p){const z=offset(p);if(z===null)throw Error(valid?'TERRAIN_UNAVAILABLE: outside experimental regional RF coverage':'TERRAIN_UNAVAILABLE: BKG height datum grid not prepared');return z;}
        function height(p,h,direction=1){if(!Number.isFinite(h))throw Error('Invalid regional RF height');return h+direction*requireOffset(p);}
        function point(p,direction){if(!p)return p;const z=requireOffset(p),out={...p};for(const key of ['height','ground'])if(Number.isFinite(out[key]))out[key]+=direction*z;return out;}
        function command(c,direction){return {...c,pilot:point(c.pilot,direction),rays:c.rays?.map(p=>point(p,direction)),obstruction:point(c.obstruction,direction)};}
        function offsets(points){return points.map(requireOffset);}
        const controls=valid&&Array.isArray(grid.controls)&&grid.controls.length>=8&&grid.controls.length<=64&&
            grid.controls.every(p=>offset(p)!==null&&Number.isFinite(p.dhhn2016M))?grid.controls.map(p=>({...p})):[];
        function validateNative(heights){
            if(controls.length<8||!Array.isArray(heights)||heights.length!==controls.length||
                heights.some((h,i)=>!Number.isFinite(h)||Math.abs(h-controls[i].dhhn2016M)>2))
                throw Error('TERRAIN_UNAVAILABLE: regional RF control height mismatch');
        }
        return {available:!!valid&&controls.length>=8,offset,height,point,command,offsets,controls,validateNative};
    }
    // One shared control check per provider identity. Temporary failures are
    // retried with a bounded cooldown, not at flight observation frequency.
    function verifier(adapter,clock=()=>Date.now()){
        let state=null;
        async function ensure(provider,sample){
            if(!adapter.available||!provider)throw Error('TERRAIN_UNAVAILABLE: regional RF reference unavailable');
            if(!state||state.provider!==provider)state={provider,verified:false,pending:null,retryAt:0};
            const entry=state;
            if(entry.verified)return;
            if(entry.pending)return entry.pending;
            if(clock()<entry.retryAt)throw Error('TERRAIN_UNAVAILABLE: regional RF reference check pending retry');
            entry.pending=Promise.resolve().then(()=>sample(adapter.controls)).then(heights=>{
                adapter.validateNative(heights);
                if(state!==entry)throw Error('TERRAIN_UNAVAILABLE: regional RF provider changed');
                entry.verified=true;
            }).catch(error=>{entry.retryAt=clock()+10000;throw error;}).finally(()=>{entry.pending=null;});
            return entry.pending;
        }
        return {ensure,verified:provider=>state?.provider===provider&&state.verified};
    }
    return {create,verifier};
});
