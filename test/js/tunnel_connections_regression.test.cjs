'use strict';
const test=require('node:test'),assert=require('node:assert/strict');
const T=require('../../web/scene_environment.js').FPVTunnelFlythrough;
const origin=[8.4,46.8],point=x=>[origin[0]+x/(111319.49*Math.cos(origin[1]*Math.PI/180)),origin[1]];
const route=(id,from,to,extra={})=>({id,name:'Test tunnel',kind:'tunnel',transport:'road',
    source:'OpenStreetMap',sourceId:`way/${id}`,coordinates:[point(from),point(to)],...extra});
const entries=routes=>routes.map(route=>({id:route.id,key:route.id,route,sourceRoutes:[route]}));

test('serial ways share one source profile and retain only their outer road approaches',()=>{
    const approach=Array.from({length:5},(_,i)=>point(-4*(i+1)));
    const a=route('a',0,70,{roadApproaches:[approach,null],roadApproachKinds:['road',null]});
    const b=route('b',140,70,{roadApproaches:[approach,null],roadApproachKinds:['bridge',null]});
    const result=T.joinConnectedRoutes(entries([b,a]));
    assert.equal(result.joined,1);
    assert.equal(result.entries.length,1);
    const joined=result.entries[0].route;
    assert.deepEqual(joined.coordinates,[point(0),point(70),point(140)]);
    assert.deepEqual(joined.roadApproaches,[approach,approach]);
    assert.deepEqual(joined.roadApproachKinds,['road','bridge']);
    assert.deepEqual(joined.mergedRouteIds,['a','b']);
    assert.deepEqual(a.coordinates,[point(0),point(70)],'source geometry remains untouched');
    assert.deepEqual(T.joinConnectedRoutes(entries([a,b])).entries[0].route,joined,
        'identity and direction do not depend on the viewport result order');
});

test('tunnel and covered-gallery transitions keep separate cover intervals within one road grade',()=>{
    const a=route('a',0,80),b=route('b',80,150,{kind:'underpass'});
    const result=T.joinConnectedRoutes(entries([a,b]));
    assert.equal(result.joined,1);
    const joined=result.entries[0].route;
    assert.equal(joined.kind,'tunnel');
    assert.deepEqual(joined.coveredIntervals.map(p=>p.kind),['tunnel','underpass']);
    assert.ok(Math.abs(joined.coveredIntervals[0].end-80)<.01);
    assert.ok(Math.abs(joined.coveredIntervals[1].end-150)<.01);
});

test('Via Lucmagn source ways share a single endpoint without an internal portal',()=>{
    const shared=[8.8553185,46.6854623];
    const gallery=route('osm:1510278500:0',0,1,{name:'Via Lucmagn',kind:'underpass',
        coordinates:[[8.8543242,46.6863568],shared]});
    const bore=route('osm:267574658:0',0,1,{name:'Via Lucmagn',
        coordinates:[shared,[8.8554295,46.6815132]]});
    const result=T.joinConnectedRoutes(entries([gallery,bore]));
    assert.equal(result.joined,1);
    assert.equal(result.entries[0].route.coordinates.filter(p=>p[0]===shared[0]&&p[1]===shared[1]).length,1);
    assert.deepEqual(result.entries[0].route.mergedRouteIds,['osm:1510278500:0','osm:267574658:0']);
});

test('parallel bores, open-road gaps, forks and grade-separated axes remain independent',()=>{
    const a=route('a',0,80),b=route('b',80,160);
    assert.equal(T.joinConnectedRoutes(entries([a,{...b,coordinates:b.coordinates.map(p=>[p[0],p[1]+.00004])}])).joined,0);
    assert.equal(T.joinConnectedRoutes(entries([a,route('gap',82,160)])).joined,0);
    assert.equal(T.joinConnectedRoutes(entries([a,b,route('fork',80,170)])).joined,0);
    assert.equal(T.joinConnectedRoutes(entries([{...a,layer:0},{...b,layer:-1}])).joined,0);
    assert.equal(T.joinConnectedRoutes(entries([a,{...b,name:'Another tunnel'}])).joined,0);
    assert.equal(T.joinConnectedRoutes(entries([a,{...b,transport:'railway'}])).joined,0);
    assert.equal(T.joinConnectedRoutes(entries([a,{...b,coordinates:[[...point(80),540],[...point(160),540]]},
        ])).joined,1,'a missing elevation is not interpreted as a surveyed height');
    assert.equal(T.joinConnectedRoutes(entries([{...a,coordinates:[[...point(0),500],[...point(80),500]]},
        {...b,coordinates:[[...point(80),540],[...point(160),540]]}])).joined,0);
    const road=Array.from({length:5},(_,i)=>point(84+i*4));
    assert.equal(T.joinConnectedRoutes(entries([{...a,roadApproaches:[null,road]},b])).joined,0,
        'a mapped open road marks a genuine portal');
});

test('several serial fragments form one stable path with no repeated boundary vertices',()=>{
    const result=T.joinConnectedRoutes(entries([route('c',240,160),route('b',80,160),route('a',0,80)]));
    assert.equal(result.joined,2);
    assert.deepEqual(result.entries[0].route.coordinates,[point(0),point(80),point(160),point(240)]);
});

test('adjacent tunnel fragments do not create a false cover transition at their shared source node',()=>{
    const a=route('a',0,70,{coordinates:[point(0),point(35),point(70)]});
    const b=route('b',70,140,{coordinates:[point(70),point(105),point(140)]});
    const joined=T.joinConnectedRoutes(entries([a,b])).entries[0].route;
    assert.equal(joined.coveredIntervals.length,1);
    const model=T.procedural(joined,[500,520,501,520,500],{profile:'vaulted'});
    assert.ok(model.sections[2].floorMetersWgs84+5<=501,
        'a map-way split inside a tunnel cannot expose its roof above terrain');
});

test('parallel merging preserves connected-road evidence from a reversed second carriageway',()=>{
    const a=route('a',0,140);
    const shift=p=>[p[0],p[1]+4/111319.49];
    const startRoad=Array.from({length:5},(_,i)=>shift(point(-4*(i+1))));
    const endRoad=Array.from({length:5},(_,i)=>shift(point(140+4*(i+1))));
    const b=route('b',140,0,{coordinates:[shift(point(140)),shift(point(0))],
        roadApproaches:[endRoad,startRoad],roadApproachKinds:['road','bridge']});
    const result=T.mergeParallelRoutes(entries([a,b]));
    assert.equal(result.merged,1);
    assert.deepEqual(result.entries[0].route.roadApproaches,[startRoad,endRoad]);
    assert.deepEqual(result.entries[0].route.roadApproachKinds,['bridge','road']);
    assert.deepEqual(a.roadApproaches,undefined);
});

test('parallel ways with incompatible bridge evidence or malformed road samples stay independent',()=>{
    const startRoad=Array.from({length:5},(_,i)=>point(-4*(i+1)));
    const a=route('a',0,140,{roadApproaches:[startRoad,null],roadApproachKinds:['road',null]});
    const b=route('b',0,140,{coordinates:[point(0),point(140)].map(p=>[p[0],p[1]+4/111319.49]),
        roadApproaches:[startRoad,null],roadApproachKinds:['bridge',null]});
    assert.equal(T.mergeParallelRoutes(entries([a,b])).merged,0);
    assert.equal(T.mergeParallelRoutes(entries([a,{...b,roadApproachKinds:['road',null],
        roadApproaches:[[[8.4,46.8]],null]}])).merged,0,
        'invalid known road evidence cannot be bypassed during a merge');
});

const section=(x,height)=>({longitude:point(x)[0],latitude:origin[1],floorMetersWgs84:height,
    widthMeters:6,heightMeters:5});
test('moving tunnel windows match the resident grade throughout overlap, not just its median height',()=>{
    const old={partial:true,sections:[0,20,40,60,80].map(x=>section(x,500+x*.04))};
    const next={partial:true,sections:[40,50,60,70,80,100,120].map(x=>section(x,504+x*.065))};
    const result=T.alignContinuation(next,old);
    assert.equal(result.aligned,true);
    for(const s of next.sections.slice(0,5)){
        const resident=T.closest(old,{longitude:s.longitude,latitude:s.latitude,height:503});
        assert.ok(Math.abs(resident.floor-s.floorMetersWgs84)<1e-8,'every shared floor sample agrees');
    }
    assert.ok(Math.abs(next.sections.at(-1).floorMetersWgs84-next.sections.at(-2).floorMetersWgs84)<2);
});

test('a vertical conflict anywhere in the overlap refuses an unsafe partial correction',()=>{
    const old={partial:true,sections:[0,20,40,60].map(x=>section(x,500))};
    const next={partial:true,sections:[20,40,60,80].map((x,i)=>section(x,i===0?516:504))};
    const original=next.sections.map(s=>s.floorMetersWgs84);
    assert.equal(T.alignContinuation(next,old).reason,'elevation-conflict');
    assert.deepEqual(next.sections.map(s=>s.floorMetersWgs84),original);
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

test('automatic tunnel-gallery models use one continuous floor across a raised shared terrain node',async()=>{
    const f=renderer(),a=route('a',0,70,{coordinates:[point(0),point(35),point(70)]}),
        b=route('b',70,140,{kind:'underpass',coordinates:[point(70),point(105),point(140)]});
    const service=T.create(f.C,f.viewer,()=>{},{sampleTerrain:async points=>points.map(p=>{
        const x=(p.longitude-origin[0])*111319.49*Math.cos(origin[1]*Math.PI/180);
        return x>1&&x<71?530:500;
    })});
    service.setAutomaticEnabled(true);
    try{
        const result=await service.setAutomaticRoutes([a,b],{longitude:point(70)[0],latitude:origin[1]});
        assert.equal(result.count,1,JSON.stringify(service.diagnostics()));
        assert.equal(result.joined,1);
        const pose=x=>({longitude:point(x)[0],latitude:origin[1],height:502});
        assert.ok(Math.abs(service.floorAt(pose(69))-499.9)<.01);
        assert.ok(Math.abs(service.floorAt(pose(71))-499.9)<.01);
        assert.equal(service.segmentInside(pose(69),pose(71)),true);
        const diagnostics=service.diagnostics();
        assert.deepEqual(diagnostics.entries[0].members,['a','b']);
        assert.deepEqual(diagnostics.entries[0].portals,[true,true]);
    }finally{service.dispose();}
});

test('viewport topology changes replace old source members without retaining duplicate floors or portals',async()=>{
    const f=renderer(),a=route('a',0,70,{kind:'underpass'}),b=route('b',70,140,{kind:'underpass'});
    const service=T.create(f.C,f.viewer,()=>{},{sampleTerrain:async points=>points.map(()=>500)});
    service.setAutomaticEnabled(true);
    const center={longitude:point(70)[0],latitude:origin[1]};
    try{
        await service.setAutomaticRoutes([a],center);
        assert.deepEqual(service.diagnostics().entries.map(e=>e.id),['a']);
        await service.setAutomaticRoutes([a,b],center);
        assert.deepEqual(service.diagnostics().entries.map(e=>e.id),['joined:a+b'],
            'expanded source context replaces the old standalone portal');
        await service.setAutomaticRoutes([a],center);
        assert.deepEqual(service.diagnostics().entries.map(e=>e.id),['a'],
            'a reduced viewport does not retain the overlapping complete path');
    }finally{service.dispose();}
});
