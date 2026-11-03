(function (root, factory) {
    if (typeof module === 'object' && module.exports) module.exports = factory();
    else root.FPVDatedImagery = factory();
})(typeof globalThis !== 'undefined' ? globalThis : this, function () {
    'use strict';

    const SWISSEO = 'ch.swisstopo.swisseo_s2-sr_v200';
    const RAPID = 'ch.swisstopo.spezialbefliegungen';
    const MAX_TILE = 512;
    const MAX_COG_BYTES = 8 * 1024 * 1024;
    const MAX_COG_REQUESTS = 64;
    const MAX_OVERLAYS = 1;
    const CH = [5.5, 45.5, 10.9, 48.1];

    function validBounds(b) {
        return Array.isArray(b) && b.length === 4 && b.every(Number.isFinite) &&
            b[0] >= -180 && b[1] >= -90 && b[2] <= 180 && b[3] <= 90 &&
            b[0] < b[2] && b[1] < b[3];
    }
    function intersect(a,b) {
        if (!validBounds(a) || !validBounds(b)) return null;
        const box = [Math.max(a[0],b[0]),Math.max(a[1],b[1]),
            Math.min(a[2],b[2]),Math.min(a[3],b[3])];
        return validBounds(box) ? box : null;
    }
    function dateId(value) {
        if (typeof value !== 'string' ||
            !/^\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d\.\d{3}Z$/.test(value)) return null;
        const d = new Date(value);
        if (!Number.isFinite(d.valueOf()) || d.toISOString() !== value) return null;
        return value.slice(0,10) + 't' + value.slice(11,19).replace(/:/g,'');
    }
    function validate(command) {
        if (!command || typeof command !== 'object' || typeof command.visible !== 'boolean') {
            throw Error('Invalid dated imagery command');
        }
        if (!command.visible) return {visible:false};
        if (typeof command.id !== 'string' || command.id.length > 160 ||
            typeof command.acquiredUtc !== 'string' || !dateId(command.acquiredUtc) ||
            ![SWISSEO,RAPID].includes(command.product) || !validBounds(command.bbox) ||
            !Number.isFinite(command.opacity) || command.opacity < 0 || command.opacity > 1) {
            throw Error('Unsupported dated imagery metadata');
        }
        const mode = command.mode;
        if (command.product === SWISSEO) {
            if (mode !== 'swiss-eo-wms') throw Error('swissEO must use the official dated WMS');
            return {...command, wmsItem:dateId(command.acquiredUtc)};
        }
        if (mode !== 'rapid-cog' || ![2056,4326].includes(command.projection)) {
            throw Error('Rapid Mapping asset does not have a supported projection');
        }
        if (typeof command.assetUrl !== 'string' || command.assetUrl.length > 1200) {
            throw Error('Invalid Rapid Mapping asset URL');
        }
        const url = new URL(command.assetUrl);
        if (url.protocol !== 'https:' || !['data.geo.admin.ch','download.geo.admin.ch'].includes(url.hostname) ||
            !/\.tiff?(?:$|\?)/i.test(command.assetUrl)) {
            throw Error('Remote asset is not a verified official GeoTIFF');
        }
        if (!validBounds(command.searchBounds) || !intersect(command.searchBounds, command.bbox)) {
            throw Error('Selected acquisition does not cover the requested area');
        }
        return {...command};
    }

    // Swisstopo's WGS84 -> CH1903+ / LV95 approximate formula. This map
    // display transformation is NOT suitable for cadastral / survey geometry.
    function wgs84ToLv95(latitude, longitude) {
        const lat = (latitude * 3600 - 169028.66) / 10000;
        const lon = (longitude * 3600 - 26782.5) / 10000;
        const east = 2600072.37 + 211455.93*lon - 10938.51*lon*lat -
            0.36*lon*lat*lat - 44.54*lon*lon*lon;
        const north = 1200147.07 + 308807.95*lat + 3745.25*lon*lon +
            76.63*lat*lat - 194.56*lon*lon*lat + 119.79*lat*lat*lat;
        return [east,north];
    }
    function coord(latitude,longitude,epsg) {
        return epsg === 2056 ? wgs84ToLv95(latitude,longitude) : [longitude,latitude];
    }

    async function ensureGeoTiff() {
        if (globalThis.GeoTIFF?.fromCustomClient) return globalThis.GeoTIFF;
        if (typeof document === 'undefined') throw Error('Local GeoTIFF decoder unavailable');
        if (!ensureGeoTiff.pending) ensureGeoTiff.pending = new Promise((resolve,reject)=>{
            const script=document.createElement('script');
            script.src='vendor/geotiff/geotiff.js'; script.async=true;
            script.onload=()=>globalThis.GeoTIFF?.fromCustomClient
                ? resolve(globalThis.GeoTIFF) : reject(Error('GeoTIFF decoder not loaded'));
            script.onerror=()=>reject(Error('Local GeoTIFF decoder unavailable'));
            document.head.appendChild(script);
        }).catch(error=>{ensureGeoTiff.pending=null;throw error;});
        return ensureGeoTiff.pending;
    }

    /** Every byte read by GeoTIFF.js goes through a range-limited client. */
    function cappedClient(T,href,abort,{maxBytes=MAX_COG_BYTES,maxRequests=MAX_COG_REQUESTS,
        fetcher=globalThis.fetch}={}) {
        let spent=0,requests=0;
        return new class extends T.BaseClient {
            constructor(){super(href);}
            async request({headers={},signal}={}) {
                if (abort.signal.aborted) throw Error('Imagery selection cancelled');
                if (++requests > maxRequests) throw Error('COG request limit exceeded');
                const controller = new AbortController();
                const stop=()=>controller.abort();
                abort.signal.addEventListener('abort',stop,{once:true});
                signal?.addEventListener?.('abort',stop,{once:true});
                try {
                    const response=await fetcher(href,{headers,signal:controller.signal,mode:'cors',credentials:'omit',redirect:'follow'});
                    // Never accept a full-file HTTP 200 fallback for large COGs.
                    if(response.status!==206) throw Error('COG server must support HTTP byte-range requests');
                    const len=Number(response.headers.get('content-length')||0);
                    if(len>maxBytes-spent)throw Error('COG byte budget exceeded');
                    const buf=await response.arrayBuffer();
                    spent+=buf.byteLength;
                    if(spent>maxBytes)throw Error('COG byte budget exceeded');
                    return new class extends T.BaseResponse {
                        get status(){return response.status;}
                        getHeader(name){return response.headers.get(name);}
                        async getData(){return buf;}
                    }();
                } finally {
                    abort.signal.removeEventListener('abort',stop);
                    signal?.removeEventListener?.('abort',stop);
                }
            }
        }();
    }

    function imageWindow(image,rect,epsg) {
        const [originX,originY]=image.getOrigin(),[resX,resY]=image.getResolution();
        if (!Number.isFinite(resX)||!Number.isFinite(resY)||resX<=0||resY>=0 ||
            image.fileDirectory?.ModelTransformation ||
            image.getWidth()>100000 || image.getHeight()>100000) {
            throw Error('Unsupported rotated or unbounded GeoTIFF');
        }
        const pts=[[rect[0],rect[1]],[rect[2],rect[1]],
            [rect[0],rect[3]],[rect[2],rect[3]]].map(([lon,lat])=>{
                const [x,y]=coord(lat,lon,epsg);
                return [(x-originX)/resX,(y-originY)/resY];
            });
        const left=Math.max(0,Math.floor(Math.min(...pts.map(p=>p[0]))));
        const right=Math.min(image.getWidth(),Math.ceil(Math.max(...pts.map(p=>p[0]))));
        const top=Math.max(0,Math.floor(Math.min(...pts.map(p=>p[1]))));
        const bottom=Math.min(image.getHeight(),Math.ceil(Math.max(...pts.map(p=>p[1]))));
        if(left>=right || top>=bottom) throw Error('No raster coverage in selected area');
        return {window:[left,top,right,bottom],originX,originY,resX,resY,
            pixels:(right-left)*(bottom-top)};
    }

    async function readCog(T, command, abort, {maxBytes=MAX_COG_BYTES}={}) {
        const bounds=intersect(command.bbox,command.searchBounds);
        if(!bounds)throw Error('No imagery intersects the requested region');
        const source=await T.fromCustomClient(cappedClient(T,command.assetUrl,abort,{maxBytes}),
            {allowFullFile:false,blockSize:65536,cacheSize:2*1024*1024});
        try {
            const count=Math.min(8,await source.getImageCount());
            let image=null,window=null;
            for(let i=0;i<count;i++){
                if(abort.signal.aborted)throw Error('Cancelled');
                const candidate=await source.getImage(i);
                const keys=candidate.getGeoKeys();
                const crs=keys.ProjectedCSTypeGeoKey||keys.GeographicTypeGeoKey;
                if(crs!==command.projection) continue;
                if(candidate.getSamplesPerPixel()<3 || candidate.getSamplesPerPixel()>4)continue;
                const win=imageWindow(candidate,bounds,crs);
                if(win.pixels<=2*1024*1024){ image=candidate;window=win;break; }
            }
            if(!image)throw Error('No safe 3/4-channel GeoTIFF overview or verified projection');
            const width=MAX_TILE,height=MAX_TILE;
            const samples=image.getSamplesPerPixel()===4?[0,1,2,3]:[0,1,2];
            const raw=await image.readRasters({window:window.window,width,height,
                samples,interleave:true,resampleMethod:'nearest'});
            if(abort.signal.aborted)throw Error('Cancelled');
            if(raw.length!==width*height*samples.length)throw Error('Unexpected COG sample count');
            const none=Number(image.getGDALNoData?.());
            const hasNoData=Number.isFinite(none);
            const pixels=new Uint8ClampedArray(width*height*4);
            let valid=0;
            for(let y=0;y<height;y++)for(let x=0;x<width;x++){
                const lat=bounds[3]-(y+0.5)/height*(bounds[3]-bounds[1]);
                const lon=bounds[0]+(x+0.5)/width*(bounds[2]-bounds[0]);
                const [px,py]=coord(lat,lon,command.projection);
                const srcX=(px-window.originX)/window.resX;
                const srcY=(py-window.originY)/window.resY;
                const ix=Math.floor((srcX-window.window[0])/(window.window[2]-window.window[0])*width);
                const iy=Math.floor((srcY-window.window[1])/(window.window[3]-window.window[1])*height);
                if(ix<0||iy<0||ix>=width||iy>=height)continue;
                const src=(iy*width+ix)*samples.length,dst=(y*width+x)*4;
                const r=raw[src],g=raw[src+1],b=raw[src+2];
                if (![r,g,b].every(Number.isFinite) ||
                    hasNoData && [r,g,b].every(v=>v===none))continue;
                pixels[dst]=r;pixels[dst+1]=g;pixels[dst+2]=b;
                pixels[dst+3]=samples.length===4?raw[src+3]:255;
                if(pixels[dst+3]>0)valid++;
            }
            if(valid===0)throw Error('Selected raster has no valid pixels in this area');
            return {pixels,width,height,bounds,valid};
        } finally {
            // geotiff fromCustomClient has no guaranteed close operation.
            source.close?.();
        }
    }

    function create(C,viewer,emit=()=>{},opts={}) {
        const getViewer=typeof viewer==='function'?viewer:()=>viewer;
        const loadCog=opts.loadCog || readCog;
        const getTiff=opts.getTiff || ensureGeoTiff;
        let layer=null,objectUrl=null,disposed=false,revision=0,abort=null,selected=null;
        function state(name,reason) {if(!disposed)emit('dated-imagery-status',{state:name,...(reason?{reason}:{}),
            id:selected?.id||null});}
        function release() {
            abort?.abort(); abort=null;
            if(layer){getViewer()?.imageryLayers.remove(layer,true);layer=null;}
            if(objectUrl){URL.revokeObjectURL(objectUrl);objectUrl=null;}
            getViewer()?.scene.requestRender?.();
        }
        async function replace(input,signal) {
            const command=validate(input);
            const current=++revision;
            release();
            if(!command.visible){selected=null;state('off');return {status:'off'};}
            selected=command;
            state('loading');
            const controller=abort=new AbortController();
            const cancel=()=>controller.abort();
            signal?.addEventListener?.('abort',cancel,{once:true});
            const isCurrent=()=>!disposed&&current===revision&&!controller.signal.aborted;
            try {
                let provider;
                if(command.mode==='swiss-eo-wms'){
                    const uri=`https://wms.geo.admin.ch/?item=${command.wmsItem}`;
                    provider=new C.WebMapServiceImageryProvider({url:uri,layers:SWISSEO,
                        maximumLevel:12,enablePickFeatures:false,
                        rectangle:C.Rectangle.fromDegrees(...CH),
                        parameters:{transparent:true,format:'image/png',styles:'default'},
                        credit:new C.Credit('© swisstopo · Contains modified Copernicus Sentinel data',true)});
                } else {
                    const tiff=await getTiff();
                    const raster=await loadCog(tiff,command,controller);
                    if(!isCurrent())return {status:'cancelled'};
                    if(typeof document==='undefined')throw Error('Canvas unavailable');
                    const canvas=document.createElement('canvas');
                    canvas.width=raster.width;canvas.height=raster.height;
                    const ctx=canvas.getContext('2d',{willReadFrequently:false});
                    if(!ctx)throw Error('Canvas unavailable');
                    const data=ctx.createImageData(raster.width,raster.height);
                    data.data.set(raster.pixels);ctx.putImageData(data,0,0);
                    const blob=await new Promise(resolve=>canvas.toBlob(resolve,'image/png'));
                    if(!blob)throw Error('Cannot encode bounded imagery frame');
                    objectUrl=URL.createObjectURL(blob);
                    provider=await C.SingleTileImageryProvider.fromUrl(objectUrl,{
                        rectangle:C.Rectangle.fromDegrees(...raster.bounds),
                        credit:new C.Credit('Source: FOEN, swisstopo · Rapid Mapping',true)});
                }
                if(!isCurrent())return {status:'cancelled'};
                const view=getViewer();
                if(!view)throw Error('Globe unavailable');
                layer=view.imageryLayers.add(new C.ImageryLayer(provider,{alpha:command.opacity,show:true}));
                view.scene.requestRender?.();
                state('ready');
                return {status:'ready'};
            } catch(error) {
                if(isCurrent()){
                    release();state('failed',String(error?.message||error).slice(0,160));
                    throw error;
                }
                return {status:'cancelled'};
            } finally {
                signal?.removeEventListener?.('abort',cancel);
            }
        }
        function clear() {revision++;release();selected=null;state('off');return {status:'off'};}
        function dispose(){if(disposed)return;revision++;release();disposed=true;selected=null;}
        return {replace,clear,dispose, get selected(){return selected;}, get activeLayers(){return layer?MAX_OVERLAYS:0;}};
    }
    return {SWISSEO,RAPID,MAX_TILE,MAX_COG_BYTES,MAX_COG_REQUESTS,
        validate,dateId,intersect,wgs84ToLv95,coord,imageWindow,cappedClient,readCog,create};
});
