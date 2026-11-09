'use strict';
const test=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs');
const E=require('../../web/scene_environment.js'),T=E.FPVTunnelFlythrough,I=E.FPVTunnelInfrastructure;
const Local=require('../../web/tunnel_offline_index.js');
const text=fs.readFileSync(require.resolve('../../web/data/tunnels/ch_tunnels_v1.json'),'utf8');
const catalogue=Local.create({fetcher:async()=>({ok:true,headers:{get:()=>null},text:async()=>text})});
const northId='osm:4214708:0',mainId='osm:49124512:0',ids=new Set([northId,mainId]);
const radians=Math.PI/180,R=6378137;
const metres=(a,b)=>Math.hypot((b[0]-a[0])*radians*R*Math.cos(a[1]*radians),(b[1]-a[1])*radians*R);

async function sourceAxis(){
    const query=await catalogue.query([8.57,46.66,8.61,46.68]);
    const routes=query.routes.filter(route=>ids.has(route.id));
    assert.equal(routes.length,2);
    const joined=T.joinConnectedRoutes(routes.map(route=>({id:route.id,route,sourceRoutes:[route]}))).entries[0].route;
    assert.deepEqual(joined.mergedRouteIds,[northId,mainId].sort());
    const path=joined.coordinates,distances=[0];
    for(let i=1;i<path.length;i++)distances.push(distances.at(-1)+metres(path[i-1],path[i]));
    const at=(distance,height=1102)=>{
        let i=0;while(i<distances.length-2&&distances[i+1]<distance)i++;
        const t=(distance-distances[i])/(distances[i+1]-distances[i]);
        return {longitude:path[i][0]+(path[i+1][0]-path[i][0])*t,
            latitude:path[i][1]+(path[i+1][1]-path[i][1])*t,height,
            heading:Math.atan2((path[i+1][0]-path[i][0])*Math.cos(path[i][1]*radians),path[i+1][1]-path[i][1])};
    };
    const project=p=>{
        let nearest=Infinity,along=0;
        for(let i=1;i<path.length;i++){
            const cos=Math.cos(path[i-1][1]*radians),dx=(path[i][0]-path[i-1][0])*radians*R*cos,
                dy=(path[i][1]-path[i-1][1])*radians*R,x=(p.longitude-path[i-1][0])*radians*R*cos,
                y=(p.latitude-path[i-1][1])*radians*R,den=dx*dx+dy*dy,t=Math.max(0,Math.min(1,(x*dx+y*dy)/den)),
                gap=Math.hypot(x-t*dx,y-t*dy);
            if(gap<nearest){nearest=gap;along=distances[i-1]+t*(distances[i]-distances[i-1]);}
        }
        return along;
    };
    return {routes,path,distances,total:distances.at(-1),at,project};
}

async function fixture(){
    const axis=await sourceAxis();
    class Value{constructor(options){Object.assign(this,options);}}
    const primitives=[],queries=[];
    const C={Geometry:Value,GeometryAttribute:Value,GeometryInstance:Value,Primitive:Value,
        CustomDataSource:class{constructor(){this.entities={add(){}};}},PolylineDashMaterialProperty:Value,
        Cartesian3:{fromDegrees:(x,y,z=0)=>({x:x*1000,y:y*1000,z}),fromDegreesArray:p=>p,clone:p=>p},
        Cartographic:{fromDegrees:(longitude,latitude)=>({longitude:longitude*radians,latitude:latitude*radians})},
        Math:{toDegrees:v=>v/radians},ComponentDatatype:{DOUBLE:1},PrimitiveType:{TRIANGLES:4},
        BoundingSphere:{fromVertices:()=>({})},Color:{ORANGE:'orange',fromBytes:(...values)=>values},
        ColorGeometryInstanceAttribute:{fromColor:value=>value},PerInstanceColorAppearance:Value};
    const viewer={camera:{positionCartographic:null,position:{},heading:0,pitch:0,roll:0,setView(){}},
        dataSources:{add(){},remove(){}},scene:{globe:{getHeight:()=>1600},requestRender(){},
            primitives:{add:p=>{primitives.push(p);return p;},remove:p=>{const i=primitives.indexOf(p);if(i>=0)primitives.splice(i,1);}}}};
    let clock=10000,phase=0,gate=null,lastBuild=Promise.resolve(),requests=0;
    const originalEndpointProbeCounts=[];
    const elevation=p=>{
        const d=axis.project(p);
        if(d<25)return 1100+phase*4;
        if(d>axis.total-25)return 1150-phase*3;
        if(Math.abs(d-axis.distances[9])<28)return 1108+phase;
        return 1600+phase*7;
    };
    const service=T.create(C,viewer,()=>{},{now:()=>clock,isSimulating:()=>true,
        sampleTerrain:async points=>{
            requests++;
            originalEndpointProbeCounts.push(points.filter(p=>{
                const d=axis.project(p);return d<25||d>axis.total-25;
            }).length);
            if(gate)await gate.promise;
            return points.map(elevation);
        }});
    service.setAutomaticEnabled(true);
    const infrastructure=I.create(C,viewer,()=>{},{now:()=>clock,isTerrainReady:()=>true,isOnline:()=>false,
        setTimer:()=>1,clearTimer(){},fetcher:async()=>{throw Error('Unexpected network call');},
        offlineIndex:{query:async box=>{
            const found=await catalogue.query(box),routes=found.routes.filter(route=>ids.has(route.id));
            queries.push(routes.map(route=>route.id));return {...found,routes};
        }},onRoutes:(routes,center)=>{lastBuild=service.setAutomaticRoutes(routes,center);}});
    infrastructure.setAutomatic(true);
    const floor=d=>1099.9+50*d/axis.total;
    const camera=d=>{
        const p=axis.at(d,floor(d)+2);viewer.camera.positionCartographic={longitude:p.longitude*radians,
            latitude:p.latitude*radians,height:p.height};return p;
    };
    const start=async()=>{
        camera(0);await infrastructure.prefetchFlight(axis.at(0));await lastBuild;
        assert.equal(service.diagnostics().count,1,JSON.stringify(service.diagnostics()));
        assert.equal(service.diagnostics().entries[0].id,`joined:${[northId,mainId].sort().join('+')}`);
    };
    return {axis,service,infrastructure,queries,primitives,originalEndpointProbeCounts,start,camera,floor,
        get build(){return lastBuild;},get requests(){return requests;},advance(ms=1000){clock+=ms;},phase(value){phase=value;},
        hold(){let resolve;const promise=new Promise(r=>{resolve=r;});gate={promise,resolve};},
        release(){const pending=gate;gate=null;pending?.resolve();},dispose(){infrastructure.dispose();service.dispose();}};
}

test('actual Gotthard north prefetch keeps the known portal fragment when the bundled forward query omits it',async()=>{
    const f=await fixture();
    try{
        await f.start();f.advance();
        const pilot=f.camera(450),target=f.service.flightCoverageTarget(pilot);
        assert.ok(target,'prefetch starts while the first 900 m window is still occupied');
        assert.ok(f.axis.project(target)>1400&&f.axis.project(target)<1500);
        await f.infrastructure.prefetchFlight(target);await f.build;
        assert.deepEqual(f.queries.at(-1),[mainId],'the real forward catalogue query no longer includes the 420 m north way');
        const debug=f.service.diagnostics();
        assert.equal(debug.count,1,JSON.stringify(debug));
        assert.deepEqual(debug.entries[0].members,[northId,mainId].sort());
        const end=f.axis.project({longitude:debug.entries[0].ends[1][0],latitude:debug.entries[0].ends[1][1]});
        assert.ok(end>2200,`fast completion installs the forward mesh before the old source window end: ${JSON.stringify(debug)}`);
        assert.ok(Math.abs(f.service.floorAt(pilot)-f.floor(450))<.02);
    }finally{f.dispose();}
});

test('async actual-catalogue handoffs preserve floor grade and continuous coverage through the complete Gotthard source axis',async()=>{
    const f=await fixture();
    try{
        await f.start();
        let handoffs=0;
        for(let hop=0;hop<20;hop++){
            const old=f.service.diagnostics().entries[0];
            if(old.portals[1])break;
            const oldEnd=f.axis.project({longitude:old.ends[1][0],latitude:old.ends[1][1]}),
                pilotDistance=oldEnd-450;
            f.advance(5000);const pilot=f.camera(pilotDistance),target=f.service.flightCoverageTarget(pilot);
            assert.ok(target,`handoff ${hop} has a source-aligned target ${JSON.stringify({oldEnd,total:f.axis.total,old})}`);
            const probesBefore=f.originalEndpointProbeCounts.length;
            f.phase(hop+1);f.hold();
            await f.infrastructure.prefetchFlight(target);
            const pending=f.build;
            assert.ok(Math.abs(f.service.floorAt(pilot)-f.floor(pilotDistance))<.02,'resident floor remains while terrain is pending');
            f.camera(oldEnd-40);f.release();await pending;
            const debug=f.service.diagnostics(),next=debug.entries[0];
            assert.equal(debug.count,1,JSON.stringify(debug));
            if(!next.portals[1])assert.ok(f.originalEndpointProbeCounts.slice(probesBefore).every(count=>count===0),
                'internal handoffs reuse remote original portal evidence instead of sampling it again');
            const nextEnd=f.axis.project({longitude:next.ends[1][0],latitude:next.ends[1][1]});
            assert.ok(nextEnd>Math.min(oldEnd+1000,f.axis.total-1),`prefetch extends physical geometry, not only its key: ${JSON.stringify(debug)}`);
            for(let d=oldEnd-80;d<=Math.min(oldEnd+1000,f.axis.total-2);d+=20){
                const p=f.axis.at(d,f.floor(d)+2);
                assert.ok(Math.abs(f.service.floorAt(p)-f.floor(d))<.02,`same source grade at ${d.toFixed(0)} m`);
                const q=f.axis.at(d+.5,f.floor(d+.5)+2);
                assert.equal(f.service.segmentInside(p,q),true,'no terrain-filled seam at the old window boundary');
                assert.equal(f.service.intersects(p,q),false,'no raised floor or internal cap across the handoff');
            }
            handoffs++;
        }
        const final=f.service.diagnostics().entries[0],south=f.axis.at(f.axis.total-2,f.floor(f.axis.total-2)+2);
        assert.ok(handoffs>=8,'the regression passes many successive windows, not only the first kilometre');
        assert.equal(final.portals[1],true,'the final resident window reaches the real south portal');
        assert.ok(Math.abs(f.service.floorAt(south)-f.floor(f.axis.total-2))<.02,
            'the resolved source grade remains continuous up to the south end');
        assert.ok(f.primitives.length<=1,'the handoff does not retain conflicting same-source collision meshes');
    }finally{f.release();f.dispose();}
});
