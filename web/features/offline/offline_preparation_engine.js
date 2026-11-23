(function(root,factory){const api=factory();if(typeof module==='object'&&module.exports)module.exports=api;else root.FPVOfflinePreparation=api;})(globalThis,function(){

'use strict';

const collections={terrain:'ch.swisstopo.swissalti3d',topographic:'ch.swisstopo.pixelkarte-farbe-pk25.noscale',satellite:'ch.swisstopo.swissimage-dop10'};

const clamp=(v,a,b)=>Math.max(a,Math.min(b,v)), rad=Math.PI/180;

function validate(c){

 if(!c||!['west','east','south','north'].every(k=>Number.isFinite(c[k]))||c.west<5.8||c.east>10.7||c.south<45.6||c.north>48||c.west>=c.east||c.south>=c.north||!Array.isArray(c.maps)||c.maps.length>3||new Set(c.maps).size!==c.maps.length||c.maps.some(s=>!['topographic','satellite','relief'].includes(s))||(!c.maps.length&&!c.includeTerrain)||!Number.isInteger(c.imageryLevel)||c.imageryLevel<10||c.imageryLevel>17||!Number.isInteger(c.terrainLevel)||c.terrainLevel<8||c.terrainLevel>16||typeof c.name!=='string'||!c.name.trim()||c.name.length>80||!Number.isSafeInteger(c.budget)||c.budget<1048576||c.budget>32*1024**3)throw Error('Ungültige Regionsauswahl.');

 if(c.scope!=='switzerland'&&(!Number.isFinite(c.radiusKm)||c.radiusKm<=0||c.radiusKm>25))throw Error('Radius muss zwischen 0 und 25 km liegen.');

 if(!['radius','switzerland'].includes(c.scope)||c.scope==='radius'&&(!Number.isFinite(c.centerLatitude)||!Number.isFinite(c.centerLongitude)))throw Error('Ungültiger Mittelpunkt.');

 return c;

}

function range(c,z,terrain){const n=2**z,px=lon=>(lon+180)/360*n*(terrain?2:1),py=lat=>terrain?(lat+90)/180*n:(1-Math.asinh(Math.tan(lat*rad))/Math.PI)/2*n;return [Math.floor(px(c.west)),Math.ceil(px(c.east))-1,Math.floor(Math.min(py(c.south),py(c.north))),Math.ceil(Math.max(py(c.south),py(c.north)))-1];}

function count(c,terrain){let n=0;for(let z=0;z<=(terrain?c.terrainLevel:c.imageryLevel);z++){const r=range(c,z,terrain);n+=(r[1]-r[0]+1)*(r[3]-r[2]+1);}return n;}

function estimate(c){validate(c);const terrain=c.includeTerrain?count(c,true):0,imagery=count(c,false)*c.maps.length;return {tiles:terrain+imagery+1,bytes:terrain*75134+imagery*65536};}

function lv95(lon,lat){const p=(lat*3600-169028.66)/10000,l=(lon*3600-26782.5)/10000;return [2600072.37+211455.93*l-10938.51*l*p-.36*l*p*p-44.54*l*l*l,1200147.07+308807.95*p+3745.25*l*l+76.63*p*p-194.56*l*l*p+119.79*p*p*p];}

function inside(c,lon,lat){if(lon<c.west||lon>c.east||lat<c.south||lat>c.north)return false;if(c.scope==='switzerland')return true;const dx=(lon-c.centerLongitude)*111.195*Math.cos(c.centerLatitude*rad),dy=(lat-c.centerLatitude)*111.195;return dx*dx+dy*dy<=c.radiusKm*c.radiusKm+1e-8;}

function heightGrid(buffer){const d=new DataView(buffer);if(d.byteLength!==40+559*253*4||d.getUint32(0,true)!==0x4e4c4843||d.getUint32(4,true)!==0x01003230)throw Error('Höhenreferenz fehlt.');const west=d.getFloat64(16,true),north=d.getFloat64(24,true),step=d.getFloat64(32,true);return (lon,lat)=>{const x=(lon-west)/step,y=(north-lat)/step;if(x<0||x>558||y<0||y>252)return null;const c=Math.min(557,Math.floor(x)),r=Math.min(251,Math.floor(y)),dx=x-c,dy=y-r,at=(a,b)=>d.getFloat32(40+(b*559+a)*4,true);const h=at(c,r)*(1-dx)*(1-dy)+at(c+1,r)*dx*(1-dy)+at(c,r+1)*(1-dx)*dy+at(c+1,r+1)*dx*dy;return h>40&&h<60?h:null;};}

async function boundedJson(url,signal){const controller=new AbortController(),abort=()=>controller.abort();signal?.addEventListener('abort',abort,{once:true});if(signal?.aborted)abort();const timer=setTimeout(abort,30000);try{const response=await fetch(url,{signal:controller.signal,credentials:'omit',redirect:'error'});if(!response.ok)throw Error('Quellenkatalog nicht erreichbar ('+response.status+').');const reader=response.body.getReader();let size=0,parts=[];for(;;){const {done,value}=await reader.read();if(done)break;if((size+=value.length)>8*1024**2){await reader.cancel();throw Error('Quellenkatalog zu groß.');}parts.push(value);}const all=new Uint8Array(size);let i=0;for(const p of parts){all.set(p,i);i+=p.length;}return JSON.parse(new TextDecoder().decode(all));}finally{clearTimeout(timer);signal?.removeEventListener('abort',abort);}}

// GeoTIFF's custom client keeps each HTTP response bounded and pins an exposed

// ETag across range requests. It never follows redirects or accepts full files.

function rangeClient(GeoTIFF,url,versions=new Map()){let etag=versions.get(url)?.etag??null;return new class extends GeoTIFF.BaseClient{

 async request({headers,signal}={}){const range=new Headers(headers).get('range'),match=/^bytes=(\d+)-(\d+)$/.exec(range??'');if(!match||+match[2]- +match[1]>4*1024**2)throw Error('Rasterblock zu groß.');const controller=new AbortController(),abort=()=>controller.abort();signal?.addEventListener('abort',abort,{once:true});if(signal?.aborted)controller.abort();const timer=setTimeout(abort,30000);try{const h=new Headers(headers);if(etag)h.set('If-Match',etag);const response=await fetch(url,{headers:h,signal:controller.signal,credentials:'omit',redirect:'error'});if(response.status!==206)throw Error('Raster-Teilabruf fehlgeschlagen ('+response.status+').');if(/no-store|private/i.test(response.headers.get('cache-control')??''))throw Error('Quelle erlaubt derzeit keine lokale Zwischenspeicherung.');const cr=/^bytes (\d+)-(\d+)\/(\d+)$/.exec(response.headers.get('content-range')??'');if(response.headers.get('content-range')&&(!cr||+cr[1]!==+match[1]||+cr[2]>+match[2]||+cr[2]<+cr[1]||+cr[3]>512*1024**2))throw Error('Ungültiger Raster-Teilbereich.');const next=response.headers.get('etag');if(etag&&next&&next!==etag)throw Error('Quelldatei wurde während des Abrufs geändert.');const modified=response.headers.get('last-modified'),previous=versions.get(url);if(previous?.modified&&modified&&previous.modified!==modified)throw Error('Quelldatei wurde während des Abrufs geändert.');if(next&&!next.startsWith('W/'))etag=next;versions.set(url,{etag,modified});const reader=response.body.getReader(),parts=[];let size=0;for(;;){const {done,value}=await reader.read();if(done)break;if((size+=value.length)>4*1024**2+1){await reader.cancel();throw Error('Rasterblock überschreitet die Größenbegrenzung.');}parts.push(value);}const bytes=new Uint8Array(size);let at=0;for(const p of parts){bytes.set(p,at);at+=p.length;}return {ok:true,status:206,getHeader:name=>response.headers.get(name),getData:async()=>bytes.buffer};}finally{clearTimeout(timer);signal?.removeEventListener('abort',abort);}}

 }(url);}

async function discover(c,kind,{signal,progress,json=boundedJson}={}){

 const collection=collections[kind],path='/api/stac/v1/collections/'+collection+'/items',first=new URL('https://data.geo.admin.ch'+path);

 // Padding includes adjacent raster sheets despite approximate LV95 conversion.

 first.search=new URLSearchParams({bbox:[c.west-.00015,c.south-.00015,c.east+.00015,c.north+.00015].join(','),limit:'100'});

 let next=first.href,pages=0,items=0;const selected=new Map(),seen=new Set();

 while(next){if(++pages>2000||seen.has(next))throw Error('Unvollständiger Quellenkatalog.');seen.add(next);const page=await json(next,signal);if(page.type!=='FeatureCollection'||!Array.isArray(page.features)||(items+=page.features.length)>200000)throw Error('Ungültiger Quellenkatalog.');

  for(const item of page.features){if(item.collection!==collection||typeof item.id!=='string'||!item.assets||!item.properties)throw Error('Ungültiger Quelldatensatz.');const match=(kind==='topographic'?/^swiss-map-raster25_\d{4}_(\d{4})$/:kind==='satellite'?/^swissimage-dop10_\d{4}_(\d{4}-\d{4})$/:/^swissalti3d_\d{4}_(\d{4}-\d{4})$/).exec(item.id);if(!match)throw Error('Unbekanntes Quellenraster.');const time=Date.parse(item.properties.datetime);if(!Number.isFinite(time)||time>Date.now()+86400000)throw Error('Ungültige Quellenausgabe.');const supported=[];

   for(const [id,a] of Object.entries(item.assets)){if(!String(a.type).startsWith('image/tiff')||a['proj:epsg']!==2056||a.gsd!==(kind==='topographic'?1.25:2)||(kind==='topographic'&&a['geoadmin:variant']!=='komb')||(kind==='terrain'&&!id.endsWith('_2056_5728.tif')))continue;

    if(!/^[a-z0-9_.-]+\.tif$/.test(id)||id.includes('..')||!id.startsWith(item.id+'_'))throw Error('Ungültiger Quelldateiname.');const expected='https://data.geo.admin.ch/'+collection+'/'+item.id+'/'+id;if(a.href!==expected||!/^1220[0-9a-f]{64}$/i.test(a['file:checksum']??''))throw Error('Nicht unterstützte Downloadquelle.');const b=item.bbox;if(!Array.isArray(b)||b.length!==4||!b.every(Number.isFinite)||b[0]>=b[2]||b[1]>=b[3])throw Error('Ungültige Quellenabdeckung.');supported.push({kind,id,itemId:item.id,url:expected,sha256:a['file:checksum'].slice(4),time:new Date(time).toISOString(),bounds:b,resolution:a.gsd});

   }

   if(supported.length!==1)throw Error('Downloadformat nicht verfügbar: '+item.id);const a=supported[0],old=selected.get(match[1]);if(!old||a.time>old.time)selected.set(match[1],a);else if(a.time===old.time&&a.sha256!==old.sha256)throw Error('Mehrdeutige Quellenausgabe.');if(selected.size>60000)throw Error('Quellenumfang überschritten.');

  }

  const links=page.links?.filter(l=>l.rel==='next');if(!links||links.length>1)throw Error('Ungültige Katalogseiten.');next=links[0]?.href??null;if(next){const u=new URL(next);if(u.origin!==first.origin||u.pathname!==path||u.username||u.password||u.hash||[...u.searchParams.keys()].some(k=>!['bbox','limit','cursor'].includes(k)))throw Error('Ungültige Katalogverknüpfung.');}

  progress?.({phase:'Quellen prüfen · '+kind+' · '+selected.size+' Kartenblätter',done:pages,total:null});

 }

 if(!selected.size)throw Error('Keine offiziellen Downloadquellen für '+kind+'.');return [...selected.values()];

}

// Sources and decoded raster blocks have independent bounded LRU caches. HTTP

// ranges avoid loading complete map sheets or nationwide rasters into memory.

class RasterReader{

 constructor(GeoTIFF,assets,signal){this.GeoTIFF=GeoTIFF;this.assets=assets;this.signal=signal;this.open=new Map();this.blocks=new Map();this.blockBytes=0;this.index=new Map();this.versions=new Map();for(const a of assets){const b=a.bounds;for(let x=Math.floor(b[0]*20);x<=Math.floor(b[2]*20);x++)for(let y=Math.floor(b[1]*20);y<=Math.floor(b[3]*20);y++){const k=x+','+y;if(!this.index.has(k))this.index.set(k,[]);this.index.get(k).push(a);}}}

 async image(a){if(this.open.has(a.url)){const i=this.open.get(a.url);this.open.delete(a.url);this.open.set(a.url,i);return i;}const t=await this.GeoTIFF.fromCustomClient(rangeClient(this.GeoTIFF,a.url,this.versions),{allowFullFile:false,blockSize:65536,cacheSize:16,maxRanges:0},this.signal),image=await t.getImage();const g=image.getGeoKeys(),origin=image.getOrigin(),res=image.getResolution();if(g.ProjectedCSTypeGeoKey!==2056||g.GTRasterTypeGeoKey!==1||image.fileDirectory.ModelTransformation||a.kind==='terrain'&&g.VerticalCSTypeGeoKey&&g.VerticalCSTypeGeoKey!==5728||res[0]<=0||res[1]>=0||Math.abs(res[0]-a.resolution)>.01||Math.abs(res[1]+a.resolution)>.01||image.getWidth()*image.getHeight()>1e9||image.getTileWidth()*image.getTileHeight()>1048576)throw Error('Nicht unterstütztes Quellenraster.');const i={image,origin,res};this.open.set(a.url,i);if(this.open.size>8)this.open.delete(this.open.keys().next().value);return i;}

 async sampleMany(points,rgb){const out=new Array(points.length).fill(null),groups=new Map();

  for(let i=0;i<points.length;i++){const p=points[i];if(!p)continue;const candidates=this.index.get(Math.floor(p[0]*20)+','+Math.floor(p[1]*20))??[];for(const a of candidates){const b=a.bounds;if(p[0]<b[0]||p[0]>b[2]||p[1]<b[1]||p[1]>b[3])continue;const projected=lv95(...p); // Exact raster bounds are checked below, not just the STAC box.

    if(!groups.has(a))groups.set(a,[]);groups.get(a).push([i,projected]);}

  }

  for(const [a,list] of groups){const {image,origin,res}=await this.image(a),tw=image.getTileWidth(),th=image.getTileHeight(),blocks=new Map();for(const [i,p] of list){if(out[i]!==null)continue;const x=Math.floor((p[0]-origin[0])/res[0]),y=Math.floor((p[1]-origin[1])/res[1]);if(x<0||y<0||x>=image.getWidth()||y>=image.getHeight())continue;const bx=Math.floor(x/tw)*tw,by=Math.floor(y/th)*th,k=bx+','+by;if(!blocks.has(k))blocks.set(k,{bx,by,pixels:[]});blocks.get(k).pixels.push([i,x,y]);}

   for(const [k,b] of blocks){

    const key=a.url+':'+rgb+':'+k;let block=this.blocks.get(key);this.blocks.delete(key);

    const w=Math.min(tw,image.getWidth()-b.bx),h=Math.min(th,image.getHeight()-b.by),nodata=image.getGDALNoData();

    if(!block){const options={window:[b.bx,b.by,b.bx+w,b.by+h],interleave:true,signal:this.signal};

     const data=rgb?await image.readRGB(options):await image.readRasters({...options,samples:[0]});

     const mask=rgb&&nodata!==null?await image.readRasters({...options,samples:[0]}):null;

     block={data,mask,bytes:data.byteLength+(mask?.byteLength??0)};this.blockBytes+=block.bytes;

    }

    this.blocks.set(key,block);while(this.blockBytes>32*1024**2&&this.blocks.size>1){const first=this.blocks.keys().next().value;this.blockBytes-=this.blocks.get(first).bytes;this.blocks.delete(first);}

    for(const [i,x,y] of b.pixels){const pixel=(y-b.by)*w+x-b.bx,at=pixel*(rgb?3:1);

     if(block.mask&&(block.mask[pixel]===nodata||!Number.isFinite(block.mask[pixel])))continue;

     if(rgb)out[i]=[block.data[at],block.data[at+1],block.data[at+2]];

     else{const v=block.data[at];if(Number.isFinite(v)&&v!==nodata&&v>=-1000&&v<=15000)out[i]=v;}

    }



   }

  }return out;

 }

}

function mesh(c,z,x,y,heights){const size=65,step=180/2**z,west=x*step-180,south=y*step-90,w=Math.max(west,c.west),e=Math.min(west+step,c.east),s=Math.max(south,c.south),n=Math.min(south+step,c.north),u0=clamp(Math.floor((w-west)/step*32767),0,32767),u1=clamp(Math.ceil((e-west)/step*32767),0,32767),v0=clamp(Math.floor((s-south)/step*32767),0,32767),v1=clamp(Math.ceil((n-south)/step*32767),0,32767);

 if(u1<=u0||v1<=v0)return null;const triangles=[];for(let r=0;r<64;r++)for(let col=0;col<64;col++){const i=r*65+col;for(const tri of [[i,i+1,i+65],[i+1,i+66,i+65]])if(tri.every(j=>heights[j]!==null&&Number.isFinite(heights[j])))triangles.push(...tri);}if(!triangles.length)return null;

 const order=[],remap=new Map();for(const i of triangles)if(!remap.has(i)){remap.set(i,order.length);order.push(i);}let low=Infinity,high=-Infinity;for(const i of order){low=Math.min(low,heights[i]);high=Math.max(high,heights[i]);}const u=[],v=[],h=[],xyz=[];for(const i of order){const uu=Math.round(u0+(u1-u0)*(i%65)/64),vv=Math.round(v0+(v1-v0)*Math.floor(i/65)/64);u.push(uu);v.push(vv);h.push(Math.round((heights[i]-low)/(high-low||1)*32767));const phi=(south+vv/32767*step)*rad,lam=(west+uu/32767*step)*rad,N=6378137/Math.sqrt(1-6.6943799901413165e-3*Math.sin(phi)**2);xyz.push([(N+heights[i])*Math.cos(phi)*Math.cos(lam),(N+heights[i])*Math.cos(phi)*Math.sin(lam),(N*(1-6.6943799901413165e-3)+heights[i])*Math.sin(phi)]);}

 const center=[0,1,2].map(axis=>xyz.reduce((n,p)=>n+p[axis],0)/xyz.length),radius=Math.max(...xyz.map(p=>Math.hypot(...p.map((v,i)=>v-center[i]))))+1,ellipsoid=[6378137,6378137,6356752.314245179],dir=center.map((v,i)=>v/ellipsoid[i]),length=Math.hypot(...dir);for(let i=0;i<3;i++)dir[i]/=length;let magnitude=1;for(const p of xyz){const q=p.map((v,i)=>v/ellipsoid[i]),len=Math.hypot(...q),m=Math.max(len,1),cos=clamp(q.reduce((s,v,i)=>s+v/len*dir[i],0),-1,1),den=cos/m-Math.sqrt(1-cos*cos)*Math.sqrt(m*m-1)/m;if(den<=0)throw Error('Ungültiger Geländehorizont.');magnitude=Math.max(magnitude,1/den);}

 const edges=[Array.from({length:65},(_,r)=>r*65),Array.from({length:65},(_,col)=>64-col),Array.from({length:65},(_,r)=>(64-r)*65+64),Array.from({length:65},(_,col)=>64*65+col)].map(a=>a.filter(i=>remap.has(i)).map(i=>remap.get(i)));

 const bytes=new Uint8Array(88+4+order.length*6+4+triangles.length*2+edges.reduce((n,a)=>n+4+a.length*2,0)),d=new DataView(bytes.buffer);let at=0;const f64=n=>{d.setFloat64(at,n,true);at+=8;},f32=n=>{d.setFloat32(at,n,true);at+=4;},u32=n=>{d.setUint32(at,n,true);at+=4;},u16=n=>{d.setUint16(at,n,true);at+=2;};center.forEach(f64);f32(low);f32(high);center.forEach(f64);f64(radius);dir.forEach(v=>f64(v*magnitude));u32(order.length);for(const a of [u,v,h]){let previous=0;for(const v of a){const delta=v-previous;u16(delta<0?-delta*2-1:delta*2);previous=v;}}u32(triangles.length/3);let highest=0;for(const i of triangles){const n=remap.get(i);u16(highest-n);if(n===highest)highest++;}for(const edge of edges){u32(edge.length);edge.forEach(u16);}return bytes;

}

async function prepare(c,{GeoTIFF,storage,grid,progress=()=>{},signal,discoverSources=discover,encodeImage}){

 validate(c);const expected=estimate(c);if(expected.tiles>2000000)throw Error('Zu viele Kacheln: Detailgrad reduzieren.');if(expected.bytes>c.budget)throw Error('Geschätzter Speicherbedarf überschreitet das gewählte Speicherlimit.');const job=await storage.begin(c),assets=[];for(const kind of [...(c.includeTerrain||c.maps.includes('relief')?['terrain']:[]),...c.maps.filter(s=>s!=='relief')])assets.push(...await discoverSources(c,kind,{signal,progress}));

 const fingerprint=[...new Uint8Array(await crypto.subtle.digest('SHA-256',new TextEncoder().encode(assets.map(a=>a.id+':'+a.sha256).sort().join('\n'))))].map(n=>n.toString(16).padStart(2,'0')).join('');await storage.bindSources(job.id,fingerprint);

 const readers={};for(const kind of ['terrain','satellite','topographic'])if(assets.some(a=>a.kind===kind))readers[kind]=new RasterReader(GeoTIFF,assets.filter(a=>a.kind===kind),signal);let done=0,written=0,missingTerrain=0;const available=[];

 const emit=async(key,generate)=>{if(signal?.aborted)throw new DOMException('Unterbrochen','AbortError');if(!await storage.has(job.id,key)){const bytes=await generate();if(bytes){await storage.write(job.id,key,bytes,c.budget);written++;}}done++;if(done%4===0)progress({phase:'Offline-Daten aufbereiten',done,total:expected.tiles});};

 if(c.includeTerrain)for(let z=0;z<=c.terrainLevel;z++){const ranges=[],r=range(c,z,true);for(let y=r[2];y<=r[3];y++){let start=null;for(let x=r[0];x<=r[1];x++){const key=`terrain/${z}/${x}/${y}.terrain`;let exists=await storage.has(job.id,key);await emit(key,async()=>{const step=180/2**z,w=Math.max(c.west,x*step-180),e=Math.min(c.east,(x+1)*step-180),s=Math.max(c.south,y*step-90),n=Math.min(c.north,(y+1)*step-90),points=[];for(let row=0;row<65;row++)for(let col=0;col<65;col++){const lon=w+(e-w)*col/64,lat=s+(n-s)*row/64;points.push(inside(c,lon,lat)?[lon,lat]:null);}const h=await readers.terrain.sampleMany(points,false);for(let i=0;i<h.length;i++){const offset=points[i]?grid(...points[i]):null;h[i]=h[i]!==null&&offset!==null?h[i]+offset:null;}const bytes=mesh(c,z,x,y,h);exists=!!bytes;if(!bytes)missingTerrain++;return bytes;});if(exists){if(start===null)start=x;}if(start!==null&&(!exists||x===r[1])){ranges.push({startX:start,endX:exists?x:x-1,startY:y,endY:y});start=null;}}}available.push(ranges);}

 if(c.includeTerrain&&!available[0]?.length)throw Error('Keine darstellbare Geländeabdeckung.');

 for(const style of c.maps)for(let z=0;z<=c.imageryLevel;z++){const r=range(c,z,false);for(let x=r[0];x<=r[1];x++)for(let y=r[2];y<=r[3];y++)await emit(`imagery/${style}/${z}/${x}/${y}.png`,async()=>{const points=[];for(let row=0;row<256;row++)for(let col=0;col<256;col++){const lon=(x+(col+.5)/256)/2**z*360-180,lat=Math.atan(Math.sinh(Math.PI*(1-2*(y+(row+.5)/256)/2**z)))/rad;points.push(inside(c,lon,lat)?[lon,lat]:null);}const values=await readers[style==='relief'?'terrain':style].sampleMany(points,style!=='relief'),rgba=new Uint8ClampedArray(256*256*4);for(let i=0;i<values.length;i++){const v=values[i];if(v===null)continue; // Neutral terrain retains natural sun/night shading; no baked shadows.

 const rgb=style==='relief'?[185,191,170]:v;rgba.set([...rgb,255],i*4);}return encodeImage(rgba);});}

 if(c.includeTerrain)await storage.write(job.id,'terrain/layer.json',new TextEncoder().encode(JSON.stringify({tilejson:'2.1.0',format:'quantized-mesh-1.0',version:'1',scheme:'tms',projection:'EPSG:4326',tiles:['{z}/{x}/{y}.terrain'],maxzoom:c.terrainLevel,available})),c.budget);

 // Persist provenance in bounded pieces, not a nationwide JSON bridge message.

 for(let i=0;i<assets.length;i+=100)await storage.write(job.id,`sources/${i/100}.json`,new TextEncoder().encode(JSON.stringify(assets.slice(i,i+100))),c.budget);

 const resourceCount=(c.includeTerrain?available.reduce((n,level)=>n+level.reduce((n,r)=>n+(r.endX-r.startX+1)*(r.endY-r.startY+1),0),0)+1:0)+count(c,false)*c.maps.length+Math.ceil(assets.length/100);

 const dates=assets.map(a=>a.time).sort(),region={...c,id:c.id,name:c.name,style:c.maps[0]??'relief',packageId:job.id,packageActive:true,preparedAtUtc:new Date().toISOString(),packageTiles:resourceCount,sourceDates:dates[0]+' – '+dates.at(-1),provenance:{attribution:'© swisstopo',sourceCount:assets.length,sourcePlanRetrievedAtUtc:new Date().toISOString(),sourceHeightReference:'LN02',heightReference:'WGS84 ellipsoid (CHGeo2004; ETRS89 approximation)',sourceIntegrity:'Official HTTPS range reads; expected full-file SHA-256 retained in source index, not verified for partial downloads',coverage:'Published source coverage within selected area; border and NoData gaps remain unavailable',missingTerrainTiles:missingTerrain,collections:[...new Set(assets.map(a=>a.kind))].map(kind=>'https://data.geo.admin.ch/api/stac/v1/collections/'+collections[kind])}};

 region.id=job.regionId??region.id;const saved=await storage.commit(region);if(saved)Object.assign(region,saved);progress({phase:'Offline-Bereich gespeichert',done:expected.tiles,total:expected.tiles});return region;

}

return {validate,range,count,estimate,lv95,inside,heightGrid,discover,RasterReader,mesh,prepare,collections,rangeClient};

});

