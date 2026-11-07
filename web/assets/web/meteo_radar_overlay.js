/* Independent MeteoSwiss observation layer, not a forecast. Requires h5wasm at runtime. */
(function(root){
'use strict';
const MAX_BYTES=3145728, MAX_PIXELS=1500000, SIDE=256;
const WASM_URL='https://cdn.jsdelivr.net/npm/h5wasm@0.10.3/dist/esm/hdf5_hl.js';
function validate(c){
  if(!c||c.type!=='set-meteoswiss-radar'||!['RZC','CPC'].includes(c.product)||
    c.units!==(c.product==='RZC'?'mm/h':'mm')||c.source!=='Source: MeteoSwiss · STAC FSDI'||
    !Number.isFinite(Date.parse(c.timestampUtc))||typeof c.assetUrl!=='string'||typeof c.assetName!=='string')throw Error('Invalid radar metadata');
  const url=new URL(c.assetUrl);
  if(url.protocol!=='https:'||url.hostname!=='data.geo.admin.ch'||url.username||url.password||
    url.pathname.split('/').at(-1)!==c.assetName||c.assetName.length>150||
    !new RegExp(`^${c.product}[a-zA-Z0-9_.-]+\\.h5$`).test(c.assetName))throw Error('Untrusted radar asset');
}
function attr(obj,key){let a=obj?.attrs?.[key]?.value;if(Array.isArray(a)&&a.length===1)a=a[0];
  return a instanceof Uint8Array?new TextDecoder().decode(a).replace(/\0+$/,''):a;}
// Swisstopo approximate EPSG:2056/WGS84 formulas (meter accuracy for raster display).
function wgsToLv95(lon,lat){const a=(lat*3600-169028.66)/10000,b=(lon*3600-26782.5)/10000;
  return {e:2600072.37+211455.93*b-10938.51*b*a-.36*b*a*a-44.54*b*b*b,
    n:1200147.07+308807.95*a+3745.25*b*b+76.63*a*a-194.56*b*b*a+119.79*a*a*a};}
function lv95ToWgs(e,n){const y=(e-2600000)/1e6,x=(n-1200000)/1e6;
  return {lon:(2.6779094+4.728982*y+.791484*y*x+.1306*y*x*x-.0436*y*y*y)*100/36,
    lat:(16.9023892+3.238272*x-.270978*y*y-.002528*x*x-.0447*y*y*x-.014*x*x*x)*100/36};}
function parseOdim(file,product){
  const where=file.get('where'),what=file.get('dataset1/data1/what')??file.get('dataset1/what');
  const dataset=file.get('dataset1/data1/data');
  if(!where||!what||!dataset||!Array.isArray(dataset.shape)||dataset.shape.length!==2)throw Error('Unsupported ODIM layout');
  const [h,w]=dataset.shape;
  if(!Number.isInteger(w)||!Number.isInteger(h)||w<1||h<1||w*h>MAX_PIXELS)throw Error('Oversized radar grid');
  const xs=Number(attr(where,'xscale')),ys=Number(attr(where,'yscale'));
  const lon=Number(attr(where,'LL_lon')),lat=Number(attr(where,'LL_lat'));
  const proj=String(attr(where,'projdef')??'');
  if(Number(attr(where,'xsize'))!==w||Number(attr(where,'ysize'))!==h||
    ![xs,ys,lon,lat].every(Number.isFinite)||xs<=0||xs>10000||ys<=0||ys>10000||
    lon<5||lon>12||lat<45||lat>49||!/somerc|2056|swiss|ch1903/i.test(proj))throw Error('Unsupported georeferencing');
  const gain=Number(attr(what,'gain')),offset=Number(attr(what,'offset'));
  const nodata=Number(attr(what,'nodata')),undetect=Number(attr(what,'undetect'));
  if(![gain,offset,nodata,undetect].every(Number.isFinite)||gain<=0)throw Error('Unknown calibration/no-data rules');
  const pixels=dataset.value;if(!pixels||pixels.length!==w*h)throw Error('Incomplete radar pixels');
  return {product,w,h,xs,ys,ll:wgsToLv95(lon,lat),gain,offset,nodata,undetect,pixels};
}
function color(v,product='RZC'){if(v<=0)return [0,0,0,0];
  const t=product==='RZC'?[.1,.5,2,10,30]:[.2,1,3,10,30];
  if(v<t[0])return [69,164,225,110];
  if(v<t[1])return [42,113,223,135];if(v<t[2])return [80,64,191,165];
  if(v<t[3])return [173,58,172,180];if(v<t[4])return [231,105,44,200];return [224,35,52,220];}
function warp(r,size=SIDE){
  if(!Number.isInteger(size)||size<2||size>SIDE)throw Error('Output exceeds pixel limit');
  const {e,n}=r.ll, corners=[lv95ToWgs(e,n),lv95ToWgs(e+r.w*r.xs,n),lv95ToWgs(e,n+r.h*r.ys),lv95ToWgs(e+r.w*r.xs,n+r.h*r.ys)];
  const b={west:Math.min(...corners.map(x=>x.lon)),east:Math.max(...corners.map(x=>x.lon)),
    south:Math.min(...corners.map(x=>x.lat)),north:Math.max(...corners.map(x=>x.lat))};
  if(b.west<4||b.east>13||b.south<44||b.north>50)throw Error('Unexpected radar coverage');
  const pixels=new Uint8ClampedArray(size*size*4);let missing=0,valid=0;
  for(let y=0;y<size;y++)for(let x=0;x<size;x++){
    const p=wgsToLv95(b.west+(x+.5)/size*(b.east-b.west), b.north-(y+.5)/size*(b.north-b.south));
    const sx=Math.floor((p.e-e)/r.xs),sy=r.h-1-Math.floor((p.n-n)/r.ys);
    if(sx<0||sx>=r.w||sy<0||sy>=r.h){missing++;pixels.set([95,95,95,55],(y*size+x)*4);continue;}
    const raw=r.pixels[sy*r.w+sx];if(!Number.isFinite(raw)||raw===r.nodata){missing++;pixels.set([95,95,95,55],(y*size+x)*4);continue;}
    const v=raw===r.undetect?0:raw*r.gain+r.offset;
    if(!Number.isFinite(v)||v<0){missing++;continue;}
    valid++;pixels.set(color(v,r.product),(y*size+x)*4);
  }
  if(!valid)throw Error('No valid radar pixels; not a zero-precipitation frame');
  return {pixels,width:size,height:size,bounds:b,missing,valid};
}
async function limitedDownload(url,signal,fetcher){
  const response=await fetcher(url,{signal,cache:'no-store'});
  if(!response.ok)throw Error(`Radar HTTP ${response.status}`);
  if(Number(response.headers?.get?.('content-length'))>MAX_BYTES)throw Error('Radar download exceeds limit');
  if(!response.body?.getReader){const bytes=new Uint8Array(await response.arrayBuffer());
    if(bytes.byteLength>MAX_BYTES)throw Error('Radar download exceeds limit');return bytes;}
  const reader=response.body.getReader();const chunks=[];let count=0;
  try{while(true){if(signal.aborted)throw Error('Cancelled');const part=await reader.read();if(part.done)break;
      count+=part.value.length;if(count>MAX_BYTES)throw Error('Radar download exceeds limit');chunks.push(part.value);}}
  finally{if(count>MAX_BYTES||signal.aborted)await reader.cancel().catch(()=>{});reader.releaseLock();}
  const data=new Uint8Array(count);let i=0;for(const chunk of chunks){data.set(chunk,i);i+=chunk.length;}return data;
}
async function nativeDecoder(bytes,product,load=()=>import(WASM_URL).then(m=>m.default??m)){
  const h5=await load(),module=await h5.ready;
  const filename=`/fpv_radar_${Date.now()}_${Math.floor(Math.random()*1e6)}.h5`;
  module.FS.writeFile(filename,bytes);let f;
  try{f=new h5.File(filename,'r');return parseOdim(f,product);}
  finally{try{f?.close();}finally{module.FS.unlink(filename);}}
}
function create(C,getViewer,{fetcher=(...args)=>fetch(...args),decoder=nativeDecoder}={}){
  let revision=0,active=null,controller=null,layer=null,disposed=false,credit=null,creditViewer=null;
  const cache=new Map();
  function clear(){revision++;controller?.abort();controller=null;cache.clear();
    const viewer=getViewer();if(layer&&viewer)viewer.imageryLayers.remove(layer,true);layer=null;active=null;
    const legend=typeof document==='undefined'?null:document.getElementById('radar-legend');if(legend)legend.hidden=true;
    viewer?.scene.requestRender?.();return {};}
  async function replace(command,signal){
    validate(command);if(disposed)throw Error('Radar disposed');
    const generation=++revision;controller?.abort();controller=new AbortController();const request=controller;
    signal?.addEventListener('abort',()=>request.abort(),{once:true});
    const key=command.assetUrl+'|'+command.timestampUtc+'|'+(command.catalogueUpdatedUtc??'');
    let frame=cache.get(key);
    if(!frame){const bytes=await limitedDownload(command.assetUrl,request.signal,fetcher);
      if(request.signal.aborted||generation!==revision)return {superseded:true};
      const raster=await decoder(bytes,command.product);
      if(request.signal.aborted||generation!==revision)return {superseded:true};
      frame=warp(raster);cache.set(key,frame);while(cache.size>2)cache.delete(cache.keys().next().value);}
    const viewer=getViewer();if(!viewer||disposed)throw Error('Globe unavailable');
    const canvas=document.createElement('canvas');canvas.width=frame.width;canvas.height=frame.height;
    const ctx=canvas.getContext('2d');if(!ctx)throw Error('Canvas unavailable');
    const image=ctx.createImageData(frame.width,frame.height);image.data.set(frame.pixels);ctx.putImageData(image,0,0);
    const b=frame.bounds;
    const provider=await C.SingleTileImageryProvider.fromUrl(canvas.toDataURL('image/png'),
      {rectangle:C.Rectangle.fromDegrees(b.west,b.south,b.east,b.north),credit:'Source: MeteoSwiss'});
    if(request.signal.aborted||generation!==revision||disposed)return {superseded:true};
    const next=viewer.imageryLayers.addImageryProvider(provider);if(layer)viewer.imageryLayers.remove(layer,true);
    layer=next;active={...command,missingPixels:frame.missing,validPixels:frame.valid};
    if(C.Credit&&creditViewer!==viewer){if(credit)creditViewer?.cesiumWidget?.creditDisplay?.removeStaticCredit(credit);
      creditViewer=viewer;credit=new C.Credit('Source: MeteoSwiss',true);viewer.cesiumWidget?.creditDisplay?.addStaticCredit(credit);}
    const legend=document.getElementById('radar-legend');if(legend){legend.hidden=false;
      legend.textContent=`Source: MeteoSwiss · ${command.product==='RZC'?'Radar estimate':'CombiPrecip 60-minute total'} · ${command.units} · ${command.timestampUtc} · ${frame.missing} missing/uncovered pixels (grey) · Dry = transparent · Not a forecast`;}
    viewer.scene.requestRender();return {validPixels:frame.valid,missingPixels:frame.missing};
  }
  function dispose(){clear();disposed=true;cache.clear();if(credit)creditViewer?.cesiumWidget?.creditDisplay?.removeStaticCredit(credit);credit=null;creditViewer=null;}
  return {replace,clear,dispose,get active(){return active;},get cachedCount(){return cache.size;}};
}
root.FPVMeteoRadar={validate,attr,wgsToLv95,lv95ToWgs,parseOdim,warp,color,limitedDownload,create};
})(typeof globalThis!=='undefined'?globalThis:this);
