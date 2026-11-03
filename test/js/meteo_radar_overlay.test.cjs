const test=require('node:test'),assert=require('node:assert/strict');
require('../../web/meteo_radar_overlay.js');
const radar=globalThis.FPVMeteoRadar;
const command={type:'set-meteoswiss-radar',product:'RZC',units:'mm/h',
  timestampUtc:'2026-11-03T12:30:00Z',source:'Source: MeteoSwiss · STAC FSDI',
  assetName:'RZC263081230VL.x01.h5',
  assetUrl:'https://data.geo.admin.ch/radar/RZC263081230VL.x01.h5'};
function fixture(matrix=[0,1,255,2]){
  const av=value=>({value});
  const where={attrs:{xsize:av(2),ysize:av(2),xscale:av(1000),yscale:av(1000),
    LL_lon:av(7.4386),LL_lat:av(46.95108),projdef:av('+proj=somerc +datum=CH1903+') }};
  const what={attrs:{gain:av(.1),offset:av(0),nodata:av(255),undetect:av(0)}};
  const dataset={shape:[2,2],value:new Uint8Array(matrix)};
  return {get:path=>({'where':where,'dataset1/data1/what':what,'dataset1/data1/data':dataset})[path]};
}
test('STAC URL, product, source and file extension are verified',()=>{
  assert.doesNotThrow(()=>radar.validate(command));
  assert.throws(()=>radar.validate({...command,assetUrl:'https://evil.example/RZC263081230VL.x01.h5'}));
  assert.throws(()=>radar.validate({...command,product:'TZC'}));
  assert.throws(()=>radar.validate({...command,units:'mm'}));
});
test('LV95 -> WGS84 -> LV95 is within metres near Bern',()=>{
  const pos=radar.wgsToLv95(7.4386,46.95108);
  assert.ok(Math.abs(pos.e-2600000)<1200);
  assert.ok(Math.abs(pos.n-1200000)<1200);
  const degrees=radar.lv95ToWgs(pos.e,pos.n);
  assert.ok(Math.abs(degrees.lon-7.4386)<.0002);
  assert.ok(Math.abs(degrees.lat-46.95108)<.0002);
});
test('ODIM calibration and nodata are distinct from genuinely undetectable rain',()=>{
  const f=radar.parseOdim(fixture(),'RZC');const out=radar.warp(f,16);
  assert.ok(out.valid>0);assert.ok(out.missing>0);
  let transparent=0;for(let i=3;i<out.pixels.length;i+=4)if(out.pixels[i]===0)transparent++;
  assert.ok(transparent>0);
  assert.throws(()=>radar.warp(radar.parseOdim(fixture([255,255,255,255]),'RZC'),8),/No valid radar/);
  assert.throws(()=>radar.parseOdim({get:()=>null},'RZC'),/Unsupported/);
});
test('unbounded file download fails even without content-length',async()=>{
  const abort=new AbortController();const chunks=[new Uint8Array(2*1024*1024),new Uint8Array(2*1024*1024)];
  let i=0;const fetcher=async()=>({ok:true,headers:{get:()=>null},body:{getReader:()=>({
    async read(){return i<chunks.length?{done:false,value:chunks[i++]}:{done:true}},
    async cancel(){},releaseLock(){} })}});
  await assert.rejects(()=>radar.limitedDownload('x',abort.signal,fetcher),/download exceeds limit/);
});
test('image layer replaces and disposes with at most two cached frames',async()=>{
  const old=global.document;
  global.document={createElement:()=>({width:0,height:0,toDataURL:()=> 'data:image/png;base64,AA',
    getContext:()=>({createImageData:(w,h)=>({data:new Uint8ClampedArray(w*h*4)}),putImageData(){}})}),
    getElementById:()=>null};
  const added=[],deleted=[];
  const C={SingleTileImageryProvider:{fromUrl:async(src,opts)=>({src,opts})},Rectangle:{fromDegrees:(...a)=>a}};
  const viewer={imageryLayers:{addImageryProvider:p=>{added.push(p);return p},remove:(p,d)=>{deleted.push(p)}},scene:{requestRender(){}}};
  const fetcher=async()=>({ok:true,headers:{get:()=>null},body:null,arrayBuffer:async()=>new Uint8Array(32).buffer});
  const decoder=async()=>radar.parseOdim(fixture(),'RZC');
  const overlay=radar.create(C,()=>viewer,{fetcher,decoder});
  try{
    await overlay.replace(command);await overlay.replace({...command,assetUrl:'https://data.geo.admin.ch/other/RZC263081230VL.x01.h5'});
    await overlay.replace({...command,timestampUtc:'2026-11-03T12:35:00Z'});
    assert.equal(overlay.cachedCount,2);assert.equal(added.length,3);assert.equal(deleted.length,2);
    overlay.dispose();assert.equal(overlay.cachedCount,0);assert.equal(deleted.length,3);
  }finally{global.document=old;}
});
