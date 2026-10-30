const test=require('node:test'),assert=require('node:assert/strict');
const {create}=require('../../web/globe_positions.js');
function setup(){
    const sources=[],camera=[],events=[],listeners=new Map();let terrain=true,navigating=false;
    class Data{constructor(){this.entities={values:[],removeAll(){this.values=[];},add(value){this.values.push(value);return value;}};}}
    const color=value=>({value,withAlpha(alpha){return {value,alpha};}});
    const C={CustomDataSource:Data,Cartesian3:{fromDegrees:(longitude,latitude,height)=>({longitude,latitude,height})},
        Cartographic:{fromDegrees:(longitude,latitude)=>({longitude,latitude})},Color:{GRAY:color('gray'),WHITE:color('white'),BLACK:color('black'),fromCssColorString:color},
        HeightReference:{CLAMP_TO_GROUND:2},LabelStyle:{FILL_AND_OUTLINE:3},Cartesian2:class{},DistanceDisplayCondition:class{}};
    const viewer={dataSources:{add:v=>sources.push(v),remove:v=>sources.splice(sources.indexOf(v),1)},
        canvas:{addEventListener:(name,fn)=>listeners.set(name,fn),removeEventListener:name=>listeners.delete(name)},
        scene:{globe:{getHeight:()=>1000},requestRender(){}},camera:{flyTo:command=>camera.push(command)}};
    const layer=create(C,viewer,(type,value)=>events.push({type,...value}),{isTerrainReady:()=>terrain,isNavigationActive:()=>navigating});
    const fix={latitude:47,longitude:8,accuracyMeters:12,timeUtc:'2026-10-30T12:00:00Z',stale:false,heading:null};
    const command={enabled:true,follow:false,recenter:true,fix};
    return {layer,sources,camera,events,listeners,command,terrain:v=>terrain=v,navigating:v=>navigating=v,entities:()=>sources[0].entities.values};
}
test('location is distinct from search and saved spots, shows accuracy, and does not repeatedly move a manual camera',()=>{
    const p=setup();p.layer.location(p.command);assert.equal(p.camera.length,1);assert.equal(p.camera[0].destination.height,2500);
    assert.equal(p.entities().find(e=>e.ellipse).ellipse.semiMajorAxis,12);
    p.layer.location({...p.command,recenter:false,fix:{...p.command.fix,latitude:47.001}});assert.equal(p.camera.length,1);
    p.layer.destination({latitude:46.95,longitude:7.44,name:'Bern, Bahnhofplatz'});assert.ok(p.entities().some(e=>e.id==='fpv-search-destination'));
    assert.ok(p.entities().some(e=>e.id==='fpv-device-position'));
    p.layer.location({enabled:false,follow:false,recenter:false,fix:null});assert.equal(p.entities().length,1);p.layer.dispose();
    assert.equal(p.sources.length,0);assert.equal(p.listeners.size,0);
});
test('stale fixes and missing terrain never invent headings, AGL or a successful current location',()=>{
    const p=setup();p.terrain(false);p.layer.location(p.command);assert.equal(p.camera[0].destination.height,12000);
    p.layer.location({...p.command,follow:true,fix:{...p.command.fix,stale:true,heading:90}});
    assert.equal(p.camera.length,1);assert.equal(p.entities().filter(e=>e.polyline).length,0);
    assert.equal(p.entities().find(e=>e.point).point.color.value,'gray');
    for(const bad of [{accuracyMeters:NaN},{heading:360},{latitude:91}])assert.throws(()=>p.layer.location({...p.command,fix:{...p.command.fix,...bad}}));
    p.layer.dispose();
});
test('following stops on map interaction and is suspended during simulation; restored search never moves the camera',()=>{
    const p=setup();p.layer.location({...p.command,follow:true});p.listeners.get('pointerdown')();
    assert.deepEqual(p.events.at(-1),{type:'location-follow-changed',following:false});
    p.layer.location({...p.command,recenter:false,follow:false});assert.equal(p.camera.length,1);
    p.navigating(true);p.layer.location({...p.command,follow:true});assert.equal(p.camera.length,1);
    p.layer.destination({latitude:47,longitude:8,name:'Restored destination',recenter:false});assert.equal(p.camera.length,1);p.layer.dispose();
});
