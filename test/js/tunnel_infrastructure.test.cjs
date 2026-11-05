const test = require('node:test');
const assert = require('node:assert/strict');
const T = require('../../web/scene_environment.js').FPVTunnelInfrastructure;
const tick = () => new Promise(r => setImmediate(r));
const road = (n, coords = [[8.3,46.9],[8.3001,46.9001]]) => ({
    type:'Feature',featureId:String(n),geometry:{type:'LineString',coordinates:coords},
    properties:{KUNSTBAUTE:n===1?1000:1100,STRASSENNAME:`Tunnel ${n}`},
});
function fixture({respond=()=>({results:[]}), time=()=>2000, getHeight=()=>500}={}){
    const events=[], requested=[], drawn=[], positions=[], listeners=new Set();
    const camera={position:{x:1},heading:.3,pitch:-.4,roll:0,
        setView:p=>positions.push(p)};
    const C={
        CustomDataSource:class{constructor(name){this.name=name;this.entities={items:[],add:i=>this.entities.items.push(i)};}},
        Cartesian3:{fromDegreesArray:a=>a,fromDegrees:(lon,lat,h)=>({lon,lat,h}),clone:p=>({...p})},
        Cartographic:{fromDegrees:(lon,lat)=>({lon,lat})},
        Color:{ORANGE:'orange'},PolylineDashMaterialProperty:class{constructor(o){this.options=o}},
    };
    const viewer={camera,dataSources:{add:d=>drawn.push(d),remove:d=>{const i=drawn.indexOf(d);if(i>=0)drawn.splice(i,1);}},
        scene:{globe:{getHeight},requestRender(){},preRender:{addEventListener(cb){listeners.add(cb);return()=>listeners.delete(cb)}}}};
    const fetcher=async(url,options)=>{requested.push({url,options});return {ok:true,status:200,
        headers:{get:()=>null}, text:async()=>JSON.stringify(respond(new URL(url).searchParams.get('layers')))};};
    const module=T.create(C,viewer,(type,data)=>events.push({type,...data}),{fetcher,now:time,isTerrainReady:()=>true});
    return {module,C,viewer,events,requested,drawn,positions,listeners};
}
test('official object codes and line features preserve provenance without inventing tunnel portals or heights',()=>{
    assert.equal(T.category(1000),'tunnel');assert.equal(T.category('Tunnel'),'tunnel');
    assert.equal(T.category(1100),'underpass');assert.equal(T.category(1200),'underpass');
    assert.equal(T.category(200),null);assert.equal(T.category(1000,'railway'),null);
    assert.equal(T.category('Tunnel','railway'),'tunnel');
    assert.throws(()=>T.bounds(8,46.8,5000));assert.throws(()=>T.bounds(17,46.8));
    const b=T.bounds(8.3,46.9,600), url=T.urlFor(b,'road');
    assert.match(url,/swisstlm3d-strassen/);assert.match(url,/geometryFormat=geojson/);
    assert.equal(new URL(url).searchParams.get('sr'),'4326');
    assert.throws(()=>T.urlFor(b,'guess'));
    const feature=T.parseIdentify({results:[road(1),road(2),road(3)]},'road');
    assert.equal(feature.routes.length,3);assert.equal(feature.routes[0].kind,'tunnel');
    assert.equal(feature.routes[1].kind,'underpass');
    assert.equal(feature.routes[0].heightReference,'unavailable');
    assert.equal(feature.routes[0].endpointsVerified,false);
    assert.equal(feature.routes[0].source,T.LAYERS.road);
});
test('unknown, invalid and incomplete geometry is not converted into fake 3D infrastructure',()=>{
    const invalid=road(1,[[3000000,1200000],[3000001,1200001]]);
    const good=road(2);
    const unknown=road(1);unknown.properties.KUNSTBAUTE=999998;
    const outcome=T.parseIdentify({results:[invalid,good,unknown]});
    assert.equal(outcome.routes.length,1);assert.equal(outcome.incomplete,true);
    assert.throws(()=>T.parseIdentify({results:new Array(201).fill(good)}));
    assert.equal(T.parseIdentify({results:[{featureId:1,properties:{KUNSTBAUTE:1000},geometry:null}]}).incomplete,true);
});
test('manual bounded search builds labelled schematic lines, focuses endpoints, and cleans resources',async()=>{
    const f=fixture({respond:layer=>({results:layer.includes('strassen')?[road(1),road(2)]:[]})});
    f.module.set({routesVisible:true,explorationAllowed:true});
    const result=await f.module.scan({longitude:8.3,latitude:46.9});
    assert.equal(result.count,2);assert.equal(f.requested.length,2);
    assert.equal(result.routes[0].source,T.LAYERS.road);
    assert.equal(f.drawn.length,1);
    assert.equal(f.drawn[0].entities.items.length,6);
    assert.match(f.drawn[0].entities.items[1].name,/NOT verified portal/);
    assert.equal(f.drawn[0].entities.items[0].polyline.clampToGround,true);
    assert.match(f.drawn[0].entities.items[0].description,/Schematic surface/);
    assert.equal(f.module.pick({id:`fpv-tunnel-${result.routes[0].id}`}),true);
    assert.equal(f.events.at(-1).portalsVerified,false);
    f.module.focus({routeId:result.routes[0].id});
    assert.equal(f.positions.at(-1).destination.h,506);
    const state=f.module.explore({routeId:result.routes[0].id});
    assert.equal(state.mode,'schematic-surface');assert.equal(f.listeners.size,1);
    f.module.stop();assert.equal(f.listeners.size,0);
    assert.equal(f.positions.at(-1).destination.x,1,'restores original camera');
    f.module.set({routesVisible:false,explorationAllowed:false});
    assert.equal(f.drawn.length,0);assert.equal(f.module.status().count,0);
    f.module.dispose();
});
test('no support for tunneled flying with absent terrain, failed services, or disabled user consent',async()=>{
    const f=fixture({respond:()=>({results:[road(1)]}),getHeight:()=>undefined});
    await assert.rejects(f.module.scan({longitude:8.3,latitude:46.9}),/Enable tunnel/);
    f.module.set({routesVisible:true,explorationAllowed:false});
    const result=await f.module.scan({longitude:8.3,latitude:46.9});
    assert.throws(()=>f.module.explore({routeId:result.routes[0].id}),/Enable/);
    f.module.set({routesVisible:true,explorationAllowed:true});
    assert.throws(()=>f.module.focus({routeId:result.routes[0].id}),/Terrain elevation missing/);
    assert.throws(()=>f.module.explore({routeId:result.routes[0].id}),/Terrain elevation missing/);
    assert.equal(f.listeners.size,0);f.module.dispose();
});
test('stale responses are discarded and disposal aborts fetches',async()=>{
    let signal=null,resolve;
    const C={CustomDataSource:class{},Cartesian3:{},Cartographic:{}};
    const camera={};
    const viewer={camera,scene:{requestRender(){}},dataSources:{remove(){}}};
    const m=T.create(C,viewer,()=>{},{now:()=>2000,fetcher:(_url,{signal:s})=>{
        signal=s;return new Promise(r=>resolve=r);
    }});
    m.set({routesVisible:true,explorationAllowed:false});
    const pending=m.scan({longitude:8.3,latitude:46.9});
    await tick();assert.equal(signal.aborted,false);
    m.dispose();assert.equal(signal.aborted,true);
    resolve({ok:true,status:200,headers:{get:()=>null},text:async()=>JSON.stringify({results:[road(1)]})});
    await assert.rejects(pending);
});
test('official service failure and incomplete coverage never create false no-tunnel claims',async()=>{
    const f=fixture({respond:layer=>({results:layer.includes('strassen')?new Array(200).fill(0).map((_,i)=>road(i+100)):[]})});
    f.module.set({routesVisible:true,explorationAllowed:false});
    const result=await f.module.scan({longitude:8.3,latitude:46.9});
    assert.equal(result.incomplete,true);assert.ok(result.count<=48);
    f.module.dispose();
});
