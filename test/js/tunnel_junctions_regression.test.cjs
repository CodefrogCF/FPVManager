'use strict';
const test=require('node:test'),assert=require('node:assert/strict');
const T=require('../../web/scene_environment.js').FPVTunnelFlythrough;
const origin=[8.4,46.8],scale=111319.49079327358;
const point=(x,y=0,z)=>[origin[0]+x/(scale*Math.cos(origin[1]*Math.PI/180)),origin[1]+y/scale,
    ...(z===undefined?[]:[z])];
const route=(id,coordinates,extra={})=>({id,name:id,kind:'tunnel',transport:'road',
    source:'OpenStreetMap',coordinates,...extra});
const entries=routes=>routes.map(route=>({id:route.id,key:route.id,route,sourceRoutes:[route]}));
const network=()=>T.connectTunnelJunctions(entries([
    route('branch',[point(0,0),point(0,25),point(0,50)]),
    route('receiver',[point(-100),point(0),point(100)])]));
const pose=(x,y,height=502)=>({longitude:point(x,y)[0],latitude:point(x,y)[1],height});

test('endpoint-on-axis junction is ordered after its receiving bore and has no invented portal',()=>{
    const result=network();
    assert.equal(result.connected,1);
    assert.deepEqual(result.entries.map(e=>e.id),['receiver','branch']);
    const branch=result.entries[1].route,receiver=result.entries[0].route;
    assert.deepEqual(branch.portalEnds,[false,true]);
    assert.equal(branch.junctionEndpoints[0].routeId,'receiver');
    assert.ok(Math.abs(receiver.junctions[0].distanceMeters-100)<.001);
    assert.deepEqual(receiver.portalEnds,[true,true]);
    const reversed=T.connectTunnelJunctions(entries([
        route('receiver',[point(-100),point(0),point(100)]),
        route('branch',[point(0,50),point(0,25),point(0,0)])]));
    assert.deepEqual(reversed.entries[1].route.portalEnds,[true,false]);
});

test('an exact endpoint may connect inside a sparse segment without an extra source vertex',()=>{
    const result=T.connectTunnelJunctions(entries([
        route('main',[point(-100),point(100)]),route('side',[point(0),point(0,50)])]));
    assert.equal(result.connected,1);
    assert.equal(result.entries.find(e=>e.id==='side').route.junctionEndpoints[0].routeId,'main');
});

test('parallel bores, near misses, incompatible transport, known surface ends and separate levels do not join',()=>{
    const receiver=route('main',[point(-100),point(0),point(100)]);
    for(const branch of [
        route('side',[point(0,.5),point(0,50)]),
        route('side',[point(0),point(50)]),
        route('side',[point(0),point(0,50)],{transport:'railway'}),
        route('side',[point(0),point(0,50)],{layer:-1}),
        route('side',[point(0),point(0,50)],{roadApproaches:[[point(0,-4)],null]}),
        route('side',[point(0,0,540),point(0,50,540)])]){
        const main={...receiver,layer:0,coordinates:receiver.coordinates.map(p=>[...p,500])};
        assert.equal(T.connectTunnelJunctions(entries([main,branch])).connected,0,JSON.stringify(branch));
    }
    const stacked={...receiver,id:'stacked'};
    assert.equal(T.connectTunnelJunctions(entries([receiver,stacked,
        route('side',[point(0),point(0,50)])])).connected,0,'overlapping unknown levels remain ambiguous');
});

test('a split receiving axis at a true T node is joined before attaching the perpendicular branch',()=>{
    const serial=T.joinConnectedRoutes(entries([
        route('left',[point(-100),point(0)],{name:'Main'}),
        route('right',[point(0),point(100)],{name:'Main'}),
        route('branch',[point(0),point(0,50)])]));
    assert.equal(serial.joined,1);
    const graph=T.connectTunnelJunctions(serial.entries);
    assert.equal(graph.connected,1);
    assert.equal(graph.entries.find(e=>e.id==='branch').route.junctionEndpoints[0].routeId,'joined:left+right');
});

test('joining receiving source fragments preserves known vertical separation from an overlying branch',()=>{
    const serial=T.joinConnectedRoutes(entries([
        route('left',[point(-100,0,500),point(0,0,500)],{name:'Main'}),
        route('right',[point(0,0,500),point(100,0,500)],{name:'Main'}),
        route('branch',[point(0,0,540),point(0,50,540)])]));
    assert.equal(serial.joined,1);
    assert.ok(serial.entries.find(e=>e.id==='joined:left+right').route.coordinates.every(p=>p[2]===500));
    assert.equal(T.connectTunnelJunctions(serial.entries).connected,0,
        'the same map position at a known separate level is not an underground node');
});

function modeledNetwork(){
    const graph=network(),receiver=graph.entries[0],branch=graph.entries[1];
    receiver.model=T.procedural(receiver.route,[500,550,500],{profile:'vaulted'});
    const floor=T.closest(receiver.model,pose(0,0)).floor;
    branch.model=T.procedural(branch.route,[550,550,505],{
        profile:'vaulted',junctionEndpointHeights:[floor,null]});
    return {receiver,branch,graph};
}

test('branch floor inherits underground receiving height while each real surface end keeps its own grade',()=>{
    const {receiver,branch}=modeledNetwork();
    assert.ok(Math.abs(receiver.model.sections[1].floorMetersWgs84-499.9)<1e-8);
    assert.equal(branch.model.sections[0].floorMetersWgs84,receiver.model.sections[1].floorMetersWgs84);
    assert.ok(Math.abs(branch.model.sections.at(-1).floorMetersWgs84-504.9)<1e-8);
    assert.deepEqual(branch.model.portalFloorMethods,['underground-junction','terrain-fallback']);
    assert.deepEqual(branch.model.portalEnds,[false,true]);
    assert.equal(branch.model.portalClipMask[0],false);
    assert.throws(()=>T.procedural(branch.route,[550,550,505]),/Receiving tunnel elevation unavailable/,
        'a missing receiving profile can never restore surface elevation at the junction');
});

test('visual and collision lining both open the branch mouth and preserve the opposite wall and floor',()=>{
    const {receiver,branch}=modeledNetwork(),line=[pose(0,-2),pose(0,12)];
    assert.equal(T.collision(receiver.model,...line,.2),true,'unopened receiving lining blocks the branch');
    T.attachJunctionOpenings([receiver,branch]);
    assert.equal(T.collision(receiver.model,...line,.2),false,'receiving mouth is open');
    assert.equal(T.collision(branch.model,...line,.2),false,'branch mouth is open');
    for(const model of [receiver.model,branch.model])
        assert.equal(T.collision(model,pose(-8,1),pose(8,1),.2),false,
            'branch walls inside the receiving bore cannot bisect the through road');
    assert.equal(T.collision(receiver.model,pose(0,-2),pose(0,-8),.2),true,'opposite lining stays solid');
    assert.equal(T.collision(receiver.model,pose(0,0,502),pose(0,0,499),.2),true,'junction keeps a road floor');
    const C={Geometry:class{constructor(o){Object.assign(this,o);}},
        GeometryAttribute:class{constructor(o){Object.assign(this,o);}},
        Cartesian3:{fromDegrees:(x,y,z)=>({x,y,z})},ComponentDatatype:{DOUBLE:1},
        PrimitiveType:{TRIANGLES:4},BoundingSphere:{fromVertices:()=>({})}};
    for(const model of [receiver.model,branch.model]){
        const rendered=T.geometry(C,model);
        assert.equal(rendered.indices.length/3,T.collisionMesh(model).triangleCount,
            'rendering and collision use identical clipped lining fragments');
    }
});

test('reported Schöllenen branch ends on another tunnel underground, not the nearby Gotthard road gallery',()=>{
    const catalogue=require('../../web/data/tunnels/ch_tunnels_v1.json');
    const ids=[1416585072,175953553,24765230];
    const routes=catalogue.routes.filter(r=>ids.includes(r[0])).map(r=>route(`osm:${r[0]}:${r[1]}`,r[5],{
        kind:r[2],transport:r[3],name:r[4],roadApproaches:r[6]}));
    const result=T.connectTunnelJunctions(entries(routes));
    assert.equal(result.connected,1);
    const branch=result.entries.find(e=>e.id==='osm:1416585072:0').route;
    assert.equal(branch.junctionEndpoints[0].routeId,'osm:175953553:0');
    assert.deepEqual(branch.portalEnds,[false,true]);
    assert.deepEqual(result.entries.find(e=>e.id==='osm:24765230:0').route.portalEnds,[true,true],
        'the separate road gallery 30 m away is not part of this underground node');
});

function renderer(){
    class Value{constructor(options){Object.assign(this,options);}}
    const C={Geometry:Value,GeometryAttribute:Value,GeometryInstance:Value,Primitive:Value,
        Cartesian3:{fromDegrees:(x,y,z=0)=>({x:x*1000,y:y*1000,z})},
        ComponentDatatype:{DOUBLE:1},PrimitiveType:{TRIANGLES:4},
        BoundingSphere:{fromVertices:()=>({})},Color:{fromBytes:(...values)=>values},
        ColorGeometryInstanceAttribute:{fromColor:value=>value},PerInstanceColorAppearance:Value};
    const primitives=[];
    const viewer={scene:{globe:{},primitives:{add:p=>{primitives.push(p);return p;},
        remove:p=>{const i=primitives.indexOf(p);if(i>=0)primitives.splice(i,1);}},requestRender(){}}};
    return {C,viewer};
}

test('automatic terrain batches resolve the receiver before a camera-nearest underground branch',async()=>{
    const f=renderer(),graph=network();
    const service=T.create(f.C,f.viewer,()=>{},{sampleTerrain:async points=>points.map(p=>{
        const x=(p.longitude-origin[0])*scale*Math.cos(origin[1]*Math.PI/180);
        const y=(p.latitude-origin[1])*scale;
        return Math.abs(x)>99||y>49?500:550;
    })});
    service.setAutomaticEnabled(true);
    try{
        const result=await service.setAutomaticRoutes(graph.entries.map(e=>({...e.route,
            portalEnds:undefined,junctionEndpoints:undefined,junctions:undefined})),pose(0,1));
        assert.equal(result.count,2,JSON.stringify(service.diagnostics()));
        assert.equal(result.junctions,1);
        assert.ok(Math.abs(service.floorAt(pose(0,1))-499.9)<.01);
        assert.deepEqual(service.diagnostics().entries.find(e=>e.id==='branch').portals,[false,true]);
        assert.equal(service.segmentInside(pose(0,-2),pose(0,12)),true,
            'crossing the underground node cannot fall back to the terrain above both bores');
    }finally{service.dispose();}
});

test('a tolerated map-node offset at a receiving bend still resolves its floor and mouth opening',async()=>{
    const f=renderer(),routes=[route('receiver',[point(-100),point(0),point(0,100)]),
        route('branch',[point(.1),point(25,-25),point(50,-50)])];
    const graph=T.connectTunnelJunctions(entries(routes));
    assert.equal(graph.connected,1);
    const receiver=graph.entries[0],branch=graph.entries[1];
    receiver.model=T.procedural(receiver.route,[500,550,500],{profile:'vaulted'});
    const near=T.closest(receiver.model,pose(.1,0));
    assert.ok(near.raw>1&&near.segment===0,'the preceding segment wins an equal-distance bend projection');
    branch.model=T.procedural(branch.route,[550,550,500],{
        profile:'vaulted',junctionEndpointHeights:[near.floor,null]});
    T.attachJunctionOpenings([receiver,branch]);
    assert.equal(receiver.model.junctionOpenings.length,1);
    assert.equal(branch.model.junctionOpenings.length,1);
    const service=T.create(f.C,f.viewer,()=>{},{sampleTerrain:async points=>points.map(p=>{
        const x=(p.longitude-origin[0])*scale*Math.cos(origin[1]*Math.PI/180),
            y=(p.latitude-origin[1])*scale;
        return x< -99||y>99||x>49?500:550;
    })});
    service.setAutomaticEnabled(true);
    try{
        const result=await service.setAutomaticRoutes(routes,pose(0,0));
        assert.equal(result.count,2,JSON.stringify(service.diagnostics()));
        assert.equal(result.junctions,1);
    }finally{service.dispose();}
});

test('a long branch retains its resolved source-junction height after both camera windows move past the node',async()=>{
    const f=renderer(),routes=[route('receiver',[point(-5000),point(0),point(5000)]),
        route('branch',[point(0),point(2000,400),point(4000,800)])];
    const service=T.create(f.C,f.viewer,()=>{},{sampleTerrain:async points=>points.map(p=>{
        const x=(p.longitude-origin[0])*scale*Math.cos(origin[1]*Math.PI/180),
            y=(p.latitude-origin[1])*scale;
        return Math.abs(x)>4999||(x>3999&&y>799)?500:550;
    })});
    service.setAutomaticEnabled(true);
    try{
        for(const x of [0,700,1400,2100,2800]){
            const result=await service.setAutomaticRoutes(routes,pose(x,x*.2));
            assert.equal(result.count,2,JSON.stringify(service.diagnostics()));
            assert.ok(Math.abs(service.floorAt(pose(x,x*.2))-499.9)<.01);
            if(x>=1400){
                const branch=service.diagnostics().entries.find(e=>e.id==='branch');
                const firstX=(branch.ends[0][0]-origin[0])*scale*Math.cos(origin[1]*Math.PI/180);
                assert.ok(firstX>x-900,'a stale resident branch cannot stand in for an advancing source window');
            }
        }
    }finally{service.dispose();}
});
