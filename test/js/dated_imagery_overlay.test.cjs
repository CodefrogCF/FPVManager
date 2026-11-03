const test=require('node:test');
const assert=require('node:assert/strict');
const M=require('../../web/dated_imagery_overlay.js');
const time='2025-05-30T12:30:25.000Z';
const bounds=[7.35,46.85,7.55,47.05];
const swiss={type:'set-dated-imagery',visible:true,id:'2025-05-30t123025',
  product:M.SWISSEO,acquiredUtc:time,bbox:bounds,opacity:.7,mode:'swiss-eo-wms'};
const rapid={...swiss,id:'ram-2025-05-30t12302500',product:M.RAPID,
  mode:'rapid-cog',projection:2056,
  assetUrl:'https://data.geo.admin.ch/ram-2025-rgb.tif',searchBounds:[7.42,46.94,7.46,46.97]};
function fake(){
  const layers=[],events=[];
  const C={WebMapServiceImageryProvider:class {constructor(opts){Object.assign(this,opts);}},
    SingleTileImageryProvider:{fromUrl:async()=>({kind:'single'})},
    Rectangle:{fromDegrees:(...v)=>v},
    Credit:class {constructor(name,shown){this.name=name;this.shown=shown;}},
    ImageryLayer:class {constructor(provider,opts){this.provider=provider;Object.assign(this,opts);}}};
  const viewer={imageryLayers:{add:l=>{layers.push(l);return l;},
    remove:l=>{const i=layers.indexOf(l);if(i>=0)layers.splice(i,1);}},
    scene:{requestRender:()=>{}}};
  const layer=M.create(C,()=>viewer,(name,payload)=>events.push({name,payload}));
  return {layer,C,viewer,layers,events};
}
test('strict product, acquisition and projection validation prevents fake live or mast geometry',()=>{
  assert.equal(M.validate(swiss).wmsItem,'2025-05-30t123025');
  assert.equal(M.validate(rapid).projection,2056);
  for(const p of [{...swiss,acquiredUtc:'invalid'}, {...swiss,opacity:2},
    {...swiss,mode:'rapid-cog'}, {...rapid,projection:21781},
    {...rapid,assetUrl:'https://evil.example/ortho.tif'},
    {...rapid,searchBounds:[1,1,2,2]}])assert.throws(()=>M.validate(p));
  assert.deepEqual(M.validate({visible:false}),{visible:false});
  assert.equal(M.dateId('2025-02-30T12:30:25.000Z'),null);
});
test('swissEO uses documented date-specific WMS; replacement/clear leaves basemap untouched',async()=>{
  const p=fake();
  await p.layer.replace(swiss);
  assert.equal(p.layers.length,1);
  assert.equal(p.layers[0].provider.layers,M.SWISSEO);
  assert.equal(p.layers[0].provider.url,'https://wms.geo.admin.ch/?item=2025-05-30t123025');
  assert.equal(p.layers[0].provider.maximumLevel,12);
  assert.match(p.layers[0].provider.credit.name,/swisstopo/);
  await p.layer.replace({...swiss,id:'new',opacity:.4});
  assert.equal(p.layers.length,1);
  assert.equal(p.layers[0].alpha,.4);
  assert.equal(p.layer.selected.id,'new');
  p.layer.clear(); assert.equal(p.layers.length,0);
  assert.equal(p.events.at(-1).payload.state,'off');
  await p.layer.replace(swiss);
  p.layer.dispose();
  assert.equal(p.layers.length,0);
  assert.equal(p.layer.activeLayers,0);
});
test('LV95 formula and source-pixel window align Bern correctly and reject rotated rasters',()=>{
  const [e,n]=M.wgs84ToLv95(46.951082877,7.438632495);
  assert.ok(Math.abs(e-2600000)<150,`${e}`);
  assert.ok(Math.abs(n-1200000)<150,`${n}`);
  const image={getOrigin:()=>[2599000,1201000],getResolution:()=>[10,-10],
    getWidth:()=>200,getHeight:()=>200,fileDirectory:{}};
  const win=M.imageWindow(image,[7.435,46.945,7.443,46.957],2056);
  assert.ok(win.pixels>0 && win.pixels<=200*200);
  assert.throws(()=>M.imageWindow({...image,fileDirectory:{ModelTransformation:[1]}},
    [7.435,46.945,7.443,46.957],2056));
});
test('COG range client enforces byte and request limits; never accepts HTTP 200 full TIFF',async()=>{
  const T={BaseClient:class {constructor(url){this.url=url;}},BaseResponse:class{}};
  const ctrl=new AbortController();
  const fetcher=async()=>({status:206,headers:{get:n=>n==='content-length'?'4':null},
    arrayBuffer:async()=>new Uint8Array([1,2,3,4]).buffer});
  const client=M.cappedClient(T,'https://data.geo.admin.ch/test.tif',ctrl,
    {maxBytes:5,maxRequests:3,fetcher});
  const response=await client.request({headers:{Range:'bytes=0-3'}});
  assert.equal(response.status,206);
  assert.equal((await response.getData()).byteLength,4);
  await assert.rejects(client.request({headers:{Range:'bytes=4-7'}}),/byte budget/);
  const full=M.cappedClient(T,'https://data.geo.admin.ch/test.tif',ctrl,
    {fetcher:async()=>({status:200,headers:{get:()=>null}})});
  await assert.rejects(full.request(),/byte-range/);
  ctrl.abort();
  await assert.rejects(client.request(),/cancelled/);
});
test('COG decoding rejects missing/no-data pixels without rendering zero as a clear image',async()=>{
  const fakeImage={getGeoKeys:()=>({ProjectedCSTypeGeoKey:2056}),
    getSamplesPerPixel:()=>3,getOrigin:()=>[2599000,1201000],
    getResolution:()=>[10,-10],getWidth:()=>200,getHeight:()=>200,
    fileDirectory:{},getGDALNoData:()=>0,
    readRasters:async({width,height})=>new Uint8Array(width*height*3).fill(0)};
  const T={fromCustomClient:async()=>({getImageCount:async()=>1,
    getImage:async()=>fakeImage,close:()=>{}}),BaseClient:class{},BaseResponse:class{}};
  await assert.rejects(M.readCog(T,rapid,new AbortController()),/no valid pixels/);
});
test('pending COG decode is cancelled on clear; reload does not restore stale layer',async()=>{
  const p=fake();
  let finish;
  const stub=M.create(p.C,()=>p.viewer,()=>{},
    {getTiff:async()=>({}),loadCog:async()=>new Promise(resolve=>finish=resolve)});
  const job=stub.replace(rapid);
  for(let i=0;i<20&&!finish;i++)await Promise.resolve();
  assert.equal(typeof finish,'function');
  stub.clear();
  finish({bounds:rapid.searchBounds,width:1,height:1,pixels:new Uint8Array(4)});
  const result=await job;
  assert.equal(result.status,'cancelled');
  assert.equal(p.layers.length,0);
  stub.dispose();
  const reload=fake();
  assert.equal(reload.layers.length,0);
  await reload.layer.replace(swiss);
  assert.equal(reload.layers.length,1);
  reload.layer.dispose();
});
