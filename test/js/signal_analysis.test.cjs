const test = require('node:test');
const assert = require('node:assert/strict');
const {validate, createLayer} = require('../../web/signal_analysis.js');
const state = {pilot:{latitude:47,longitude:8,height:502}, frequencyMhz:5800, fraction:.6, selected:0,
    rays:[{latitude:47.001,longitude:8.005,height:550,ground:500,state:'fresnelIntrusion'}]};
class Vector {
    constructor(x=0,y=0,z=0) {Object.assign(this,{x,y,z});}
    static fromDegrees(x,y,z) {return new Vector(x*10000,y*10000,z);}
    static subtract(a,b) {return new Vector(a.x-b.x,a.y-b.y,a.z-b.z);}
    static add(a,b) {return new Vector(a.x+b.x,a.y+b.y,a.z+b.z);}
    static magnitude(a) {return Math.hypot(a.x,a.y,a.z);}
    static multiplyByScalar(a,s) {return new Vector(a.x*s,a.y*s,a.z*s);}
    static normalize(a) {return this.multiplyByScalar(a,1/this.magnitude(a));}
    static dot(a,b) {return a.x*b.x+a.y*b.y+a.z*b.z;}
    static cross(a,b) {return new Vector(a.y*b.z-a.z*b.y,a.z*b.x-a.x*b.z,a.x*b.y-a.y*b.x);}
    static lerp(a,b,t) {return this.add(a,this.multiplyByScalar(this.subtract(b,a),t));}
    static UNIT_X = new Vector(1,0,0);
    static UNIT_Z = new Vector(0,0,1);
}
function setup() {
    const sources=[];
    class CustomDataSource {constructor(name) {this.name=name; const values=[]; this.entities={values,add:o=>values.push(o)};}}
    const color={withAlpha(){return this;}};
    const C={Cartesian3:Vector,CustomDataSource,Color:{GRAY:color,ORANGE:color,MEDIUMPURPLE:color,CYAN:color,YELLOW:color},ArcType:{NONE:0}};
    const viewer={dataSources:{add:s=>sources.push(s),remove:s=>sources.splice(sources.indexOf(s),1)},scene:{requestRender(){}}};
    return {layer:createLayer(C,viewer),sources};
}
test('radio overlay rejects invalid positions, unknown statuses, nonfinite values and unbounded counts',()=>{
    validate(state); validate({rays:[]});
    for(const bad of [{...state,frequencyMhz:NaN},{...state,selected:2},{...state,targetOffset:-1},
        {...state,targetOffset:4096},{...state,rays:Array(129).fill(state.rays[0])},
        {...state,rays:[{...state.rays[0],state:'safe'}]}, {...state,rays:[{...state.rays[0],height:null}]},
        {...state,pilot:{...state.pilot,latitude:91}}]) assert.throws(()=>validate(bad));
});
test('bounded 3D envelope, replacement, unknown heights and cleanup',()=>{
    const {layer,sources}=setup(); layer.set(state);
    assert.equal(sources.length,1);
    assert.equal(sources[0].entities.values.filter(e=>e.id.startsWith('signal-envelope')).length,4);
    assert.equal(sources[0].entities.values.find(e=>e.id==='signal-envelope-0').polyline.positions.length,65);
    assert.throws(()=>layer.set({...state,fraction:2})); assert.equal(sources.length,1);
    layer.set({...state,targetOffset:896,rays:[{...state.rays[0],height:null,state:'unknown'}]});
    assert.equal(sources.length,1); assert.equal(sources[0].entities.values.length,2);
    assert.match(sources[0].entities.values[1].name,/Radio target 897/);
    layer.clear(); assert.equal(sources.length,0); layer.dispose();
});
