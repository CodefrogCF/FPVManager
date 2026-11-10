(function(root,factory){
    const api=factory();
    if(typeof module==='object'&&module.exports)module.exports=api;
    else root.FPVFlightRendering=api;
})(typeof globalThis!=='undefined'?globalThis:this,function(){
    'use strict';
    const DEG=Math.PI/180;
    // Cesium's PerspectiveFrustum.fov denotes the larger field angle.
    // Convert a horizontal camera setting for portrait canvases.
    function perspectiveFov(horizontalDegrees,aspect){
        if(!Number.isFinite(horizontalDegrees)||horizontalDegrees<50||horizontalDegrees>140)throw Error('Invalid horizontal FOV');
        if(!Number.isFinite(aspect)||aspect<=0)throw Error('Invalid canvas aspect ratio');
        const horizontal=horizontalDegrees*DEG;
        return aspect>=1?horizontal:2*Math.atan(Math.tan(horizontal/2)/aspect);
    }
    const profiles=Object.freeze({
        quality:Object.freeze({resolutionScale:1,msaaSamples:4}),
        balanced:Object.freeze({resolutionScale:.85,msaaSamples:2}),
        performance:Object.freeze({resolutionScale:.75,msaaSamples:1}),
        compatibility:Object.freeze({resolutionScale:.65,msaaSamples:1})
    });
    // Retain recently viewed terrain and its attached imagery for return turns.
    // Cesium's LRU target counts tiles, not bytes; tiles needed by the current
    // frame may exceed it. Keep preloading and terrain detail unchanged.
    const flightTileCacheSize=512;
    function createTerrainShaderWarmup(C,viewer,{now=()=>performance.now(),pause=ms=>new Promise(resolve=>setTimeout(resolve,ms)),
        timeoutMs=15000}={}){
        const scene=viewer.scene,set=scene.globe._surfaceShaderSet;
        const noop={prepare:async()=>{},status:()=>({supported:false})};
        if(!set||typeof set.getShaderProgram!=='function'||!C.DerivedCommand?.createLogDepthCommand||!C.DrawCommand)return noop;
        const original=set.getShaderProgram;
        let seed=null,completed=0,total=0,preparing=false,elapsed=0;
        // This instance belongs to this viewer. Keep a snapshot: Cesium reuses
        // its options object for the next tile/imagery combination.
        set.getShaderProgram=function(options){
            const result=original.call(this,options);
            if(!seed&&options.frameState.mode===C.SceneMode.SCENE3D){
                seed={...options,surfaceTile:{...options.surfaceTile,
                    renderedMesh:{encoding:options.surfaceTile.renderedMesh.encoding}}};
            }
            return result;
        };
        async function prepare(signal,onProgress=()=>{}){
            const start=now(),deadline=start+timeoutMs;
            const cancelled=()=>signal?.aborted||scene.isDestroyed?.()||now()>=deadline;
            const check=()=>{signal?.throwIfAborted();return !cancelled();};
            preparing=true;completed=total=0;onProgress({completed,total});
            try{
                // Let the pending flight pose reach terrain selection before
                // collecting the normal surface-shader options.
                seed=null;scene.requestRender();await pause(0);
                while(!seed&&check())await pause(16);
                if(!seed||!check())return;
                const options=seed,gl=options.frameState.context?._gl;
                if(!gl||gl.isContextLost?.())return;
                const programs=new Set(),context=options.frameState.context,encoding=options.surfaceTile.renderedMesh.encoding;
                for(const quantization of [C.TerrainQuantization.NONE,C.TerrainQuantization.BITS12])
                    for(const enableFog of [false,true])for(const showUndergroundColor of [false,true])
                        for(let textures=0;textures<=4;textures++){
                            const variant=Object.assign(Object.create(encoding),{quantization});
                            const surfaceTile={...options.surfaceTile,renderedMesh:{encoding:variant},surfaceShader:undefined};
                            const base=original.call(set,{...options,surfaceTile,enableFog,showUndergroundColor,numberOfDayTextures:textures});
                            const command=new C.DrawCommand({shaderProgram:base});
                            programs.add(scene.logarithmicDepthBuffer
                                ?C.DerivedCommand.createLogDepthCommand(command,context).command.shaderProgram:base);
                        }
                const extension=gl.getExtension('KHR_parallel_shader_compile');
                const queue=[...programs];total=queue.length;onProgress({completed,total});
                async function compile(shader){
                    if(shader._program){completed++;onProgress({completed,total});return;}
                    if(typeof shader._bind!=='function'||typeof shader._vertexShaderText!=='string'||
                        typeof shader._fragmentShaderText!=='string')return;
                    let program=null,vs=null,fs=null;
                    try{
                        if(extension){
                            // Start driver compilation without asking LINK_STATUS
                            // (which waits synchronously). Poll the non-blocking
                            // completion flag while flight controls are pending.
                            vs=gl.createShader(gl.VERTEX_SHADER);fs=gl.createShader(gl.FRAGMENT_SHADER);program=gl.createProgram();
                            if(!vs||!fs||!program)return;
                            gl.shaderSource(vs,shader._vertexShaderText);gl.compileShader(vs);
                            gl.shaderSource(fs,shader._fragmentShaderText);gl.compileShader(fs);
                            gl.attachShader(program,vs);gl.attachShader(program,fs);
                            for(const [name,index] of Object.entries(shader._attributeLocations||{}))gl.bindAttribLocation(program,index,name);
                            gl.linkProgram(program);gl.flush();
                            while(!gl.getProgramParameter(program,extension.COMPLETION_STATUS_KHR)){
                                if(!check())return;await pause(10);
                            }
                            if(!check()||!gl.getProgramParameter(program,gl.LINK_STATUS))return;
                        }
                        if(!check())return;
                        // Initialize Cesium's own cached program and uniform
                        // bookkeeping using the warmed driver cache. Restore
                        // GL binding so an idle render never uses this program.
                        const bound=gl.getParameter(gl.CURRENT_PROGRAM);
                        try{shader._bind();completed++;onProgress({completed,total});}finally{gl.useProgram(bound);}
                    }finally{
                        if(program)gl.deleteProgram(program);if(vs)gl.deleteShader(vs);if(fs)gl.deleteShader(fs);
                    }
                }
                async function worker(){
                    while(queue.length&&check()){
                        const shader=queue.shift();await compile(shader);await pause(0);
                    }
                }
                await Promise.allSettled([worker(),worker()]);
                signal?.throwIfAborted();
            }catch(error){
                if(signal?.aborted)throw error;
                // Unsupported private runtime details must not prevent flight.
                // Ordinary Cesium compilation remains available as fallback.
            }finally{preparing=false;elapsed=now()-start;}
        }
        return {prepare,status:()=>({supported:true,preparing,completed,total,elapsed})};
    }
    const terrainPickerOwners=new WeakMap();
    function createTerrainMeshPicker(C,{maxBytes=16*1024*1024,maxMeshes=64}={}){
        const prototype=C.TerrainMesh?.prototype;
        if(!prototype||typeof prototype.pick!=='function'||!C.IntersectionTests?.rayTriangleParametric||
            !C.IntersectionTests?.rayAxisAlignedBoundingBox)return {start(){},stop(){},status:()=>({supported:false})};
        let owner=terrainPickerOwners.get(prototype);
        if(!owner){
            const original=prototype.pick,caches=new Map(),a=new C.Cartesian3(),b=new C.Cartesian3(),c=new C.Cartesian3();
            const box={minimum:new C.Cartesian3(),maximum:new C.Cartesian3()},interval=new C.Interval(),stack=new Uint32Array(32);
            let users=0,bytes=0,clock=0,builds=0,evictions=0,triangleTests=0;
            function forget(mesh){const cached=caches.get(mesh);if(cached){bytes-=cached.bytes;caches.delete(mesh);}}
            function cacheFor(mesh){
                const vertices=mesh.vertices,indices=mesh.indices,encoding=mesh.encoding,stride=mesh.stride;
                if(!ArrayBuffer.isView(vertices)||!ArrayBuffer.isView(indices)||!Number.isInteger(stride)||stride<3||
                    vertices.length%stride||indices.length%3||typeof encoding?.getExaggeratedPosition!=='function')return null;
                const count=vertices.length/stride,groups=Math.ceil(indices.length/192);
                let leafBase=1;while(leafBase<groups)leafBase*=2;
                const required=count*24+leafBase*96;
                if(count>65536||!count||required>maxBytes)return null;
                let cached=caches.get(mesh);
                if(cached&&(cached.vertices!==vertices||cached.indices!==indices||cached.encoding!==encoding||
                    cached.exaggeration!==encoding.exaggeration||cached.relativeHeight!==encoding.exaggerationRelativeHeight)){
                    forget(mesh);cached=null;
                }
                if(cached){cached.used=++clock;return cached;}
                while(caches.size&&(bytes+required>maxBytes||caches.size>=maxMeshes)){
                    let oldest=null,age=Infinity;
                    for(const [key,value] of caches)if(value.used<age){oldest=key;age=value.used;}
                    forget(oldest);evictions++;
                }
                const positions=new Float64Array(count*3),bounds=new Float64Array(leafBase*12);
                for(let i=0;i<count;i++){
                    encoding.getExaggeratedPosition(vertices,i,a);
                    if(!Number.isFinite(a.x)||!Number.isFinite(a.y)||!Number.isFinite(a.z))return null;
                    positions[i*3]=a.x;positions[i*3+1]=a.y;positions[i*3+2]=a.z;
                }
                // Neighboring triangles in Cesium's terrain index buffer form
                // small spatial batches. Decode each shared vertex once and
                // bound 64 triangles per batch, including all skirt triangles.
                // This avoids the default picker's first-use full-mesh decode
                // and large temporary per-triangle arrays on the render thread.
                for(let group=0;group<groups;group++){
                    let minX=Infinity,minY=Infinity,minZ=Infinity,maxX=-Infinity,maxY=-Infinity,maxZ=-Infinity;
                    const end=Math.min(indices.length,(group+1)*192);
                    for(let j=group*192;j<end;j++){
                        const k=indices[j]*3;if(k<0||k>=positions.length)return null;
                        const x=positions[k],y=positions[k+1],z=positions[k+2];
                        minX=Math.min(minX,x);minY=Math.min(minY,y);minZ=Math.min(minZ,z);
                        maxX=Math.max(maxX,x);maxY=Math.max(maxY,y);maxZ=Math.max(maxZ,z);
                    }
                    const k=(leafBase+group)*6;
                    bounds[k]=minX-.001;bounds[k+1]=minY-.001;bounds[k+2]=minZ-.001;
                    bounds[k+3]=maxX+.001;bounds[k+4]=maxY+.001;bounds[k+5]=maxZ+.001;
                }
                // A small binary hierarchy also bounds empty space between
                // batches; warm height queries need not scan every batch box.
                for(let group=groups;group<leafBase;group++){
                    const k=(leafBase+group)*6;
                    bounds[k]=bounds[k+1]=bounds[k+2]=Infinity;
                    bounds[k+3]=bounds[k+4]=bounds[k+5]=-Infinity;
                }
                for(let node=leafBase-1;node>0;node--){
                    const k=node*6,a=node*12,b=a+6;
                    for(let axis=0;axis<3;axis++){
                        bounds[k+axis]=Math.min(bounds[a+axis],bounds[b+axis]);
                        bounds[k+axis+3]=Math.max(bounds[a+axis+3],bounds[b+axis+3]);
                    }
                }
                cached={vertices,indices,encoding,positions,bounds,leafBase,bytes:required,used:++clock,
                    exaggeration:encoding.exaggeration,relativeHeight:encoding.exaggerationRelativeHeight};
                caches.set(mesh,cached);bytes+=required;builds++;return cached;
            }
            function pick(ray,cullBackFaces,mode,projection){
                if(mode!==C.SceneMode?.SCENE3D)return original.call(this,ray,cullBackFaces,mode,projection);
                const cache=cacheFor(this);
                if(!cache)return original.call(this,ray,cullBackFaces,mode,projection);
                const {positions,indices,bounds,leafBase}=cache;
                let best=Infinity,depth=1;stack[0]=1;
                while(depth){
                    const node=stack[--depth],k=node*6;
                    if(bounds[k]>bounds[k+3])continue;
                    box.minimum.x=bounds[k];box.minimum.y=bounds[k+1];box.minimum.z=bounds[k+2];
                    box.maximum.x=bounds[k+3];box.maximum.y=bounds[k+4];box.maximum.z=bounds[k+5];
                    const range=C.IntersectionTests.rayAxisAlignedBoundingBox(ray,box,interval);
                    if(!range||range.stop<0||range.start>best)continue;
                    if(node<leafBase){stack[depth++]=node*2;stack[depth++]=node*2+1;continue;}
                    const group=node-leafBase;
                    const end=Math.min(indices.length,(group+1)*192);
                    for(let j=group*192;j<end;j+=3){
                        const x=indices[j]*3,y=indices[j+1]*3,z=indices[j+2]*3;
                        a.x=positions[x];a.y=positions[x+1];a.z=positions[x+2];
                        b.x=positions[y];b.y=positions[y+1];b.z=positions[y+2];
                        c.x=positions[z];c.y=positions[z+1];c.z=positions[z+2];
                        const hit=C.IntersectionTests.rayTriangleParametric(ray,a,b,c,cullBackFaces);
                        triangleTests++;
                        if(hit!==undefined&&hit>=0&&hit<best)best=hit;
                    }
                }
                return best<Infinity?C.Ray.getPoint(ray,best):undefined;
            }
            const updateExaggeration=prototype.updateExaggeration,updateSceneMode=prototype.updateSceneMode;
            function exaggeration(...args){forget(this);return updateExaggeration.apply(this,args);}
            function sceneMode(...args){forget(this);return updateSceneMode.apply(this,args);}
            owner={
                start(){
                    if(users++===0){
                        prototype.pick=pick;
                        if(updateExaggeration)prototype.updateExaggeration=exaggeration;
                        if(updateSceneMode)prototype.updateSceneMode=sceneMode;
                    }
                },
                stop(){
                    if(users&&--users===0){
                        if(prototype.pick===pick)prototype.pick=original;
                        if(prototype.updateExaggeration===exaggeration)prototype.updateExaggeration=updateExaggeration;
                        if(prototype.updateSceneMode===sceneMode)prototype.updateSceneMode=updateSceneMode;
                        caches.clear();bytes=0;
                    }
                },
                status:()=>({supported:true,active:users>0,bytes,meshes:caches.size,builds,evictions,triangleTests})
            };
            terrainPickerOwners.set(prototype,owner);
        }
        let active=false;
        return {start(){if(!active){active=true;owner.start();}},stop(){if(active){active=false;owner.stop();}},status:owner.status};
    }
    function publicTerrainSegmentIntersects(C,viewer,ray,limit,result){
        const intersection=viewer.scene.globe.pick(ray,viewer.scene,result);
        return !!intersection&&C.Cartesian3.distance(ray.origin,intersection)<=limit;
    }
    function terrainSegmentIntersects(C,viewer,ray,from,length,result){
        const scene=viewer.scene,globe=scene.globe,limit=length+.001;
        // Globe.pick traces to the horizon and can initialize expensive mesh
        // pickers in many distant tiles. A collision sweep only needs the few
        // rendered tiles its SHORT segment can actually reach. Keep the normal
        // Cesium triangle test, including skirts and back-face culling.
        // The private tile list is guarded for our pinned runtime; unsupported
        // scene modes/runtimes retain the original public pick path.
        const tiles=globe._surface?._tilesToRender;
        if(!C.SceneMode||scene.mode!==C.SceneMode.SCENE3D||!Array.isArray(tiles)||
            !Number.isFinite(from.latitude)||!Number.isFinite(from.longitude)||
            Math.abs(from.latitude)>85||from.height< -1e6||length>1000)
            return publicTerrainSegmentIntersects(C,viewer,ray,limit,result);
        const latitude=from.latitude*DEG,longitude=from.longitude*DEG;
        // A spherical cap around the origin bounds the geodetic footprint of
        // the entire ECEF segment. The conservative 5000-km radius is smaller
        // than Earth's radius even below the supported terrain elevations;
        // padding also covers coordinate quantization at tile boundaries.
        const latitudePad=(limit+.25)/5000000+1e-10;
        const longitudePad=Math.min(Math.PI,latitudePad/Math.cos(Math.abs(latitude)+latitudePad));
        for(const tile of tiles){
            const r=tile.rectangle;
            if(!r||!Number.isFinite(r.west)||!Number.isFinite(r.east)||
                !Number.isFinite(r.south)||!Number.isFinite(r.north))
                return publicTerrainSegmentIntersects(C,viewer,ray,limit,result);
            if(latitude<r.south-latitudePad||latitude>r.north+latitudePad)continue;
            const insideLongitude=r.west<=r.east
                ?longitude>=r.west&&longitude<=r.east
                :longitude>=r.west||longitude<=r.east;
            if(!insideLongitude&&longitudePad<Math.PI){
                let west=Math.abs(longitude-r.west),east=Math.abs(longitude-r.east);
                if(west>Math.PI)west=2*Math.PI-west;
                if(east>Math.PI)east=2*Math.PI-east;
                if(Math.min(west,east)>longitudePad)continue;
            }
            if(!tile.data)continue;
            if(typeof tile.data.pick!=='function')
                return publicTerrainSegmentIntersects(C,viewer,ray,limit,result);
            const intersection=tile.data.pick(ray,scene.mode,scene.mapProjection,true,result);
            if(intersection&&C.Cartesian3.distance(ray.origin,intersection)<=limit)return true;
        }
        return false;
    }
    function createStreamingBudget(globe,{now=()=>performance.now()}={}){
        let active=false,lastTime=null,heading=0,pitch=0,roll=0,slowFrames=0;
        let holdUntil=0,nextRefinement=0,target=2,changes=0;
        const angle=(a,b)=>Math.abs(Math.atan2(Math.sin(a-b),Math.cos(a-b)));
        function reset(){lastTime=null;slowFrames=0;holdUntil=nextRefinement=0;target=2;}
        function apply(value){
            target=value;
            if(globe.maximumScreenSpaceError!==value){globe.maximumScreenSpaceError=value;changes++;}
        }
        return {
            start(){active=true;reset();},
            stop(){active=false;reset();},
            update(point){
                if(!active)return;
                const time=now();
                if(!Number.isFinite(time))return;
                const elapsed=lastTime===null?0:Math.max(0,time-lastTime);
                const h=Number.isFinite(point.heading)?point.heading:0,
                    p=Number.isFinite(point.pitch)?point.pitch:0,
                    r=Number.isFinite(point.roll)?point.roll:0;
                const turning=elapsed>0&&elapsed<250&&
                    Math.max(angle(h,heading),angle(p,pitch),angle(r,roll))>1.2*elapsed/1000;
                heading=h;pitch=p;roll=r;lastTime=time;
                slowFrames=elapsed>28?Math.min(3,slowFrames+(elapsed>50?2:1)):Math.max(0,slowFrames-1);
                const nearGround=Number.isFinite(point.agl)&&point.agl>=0&&point.agl<100;
                // Refinement/textures arrive in bursts near the surface and
                // after fast view changes. Ease their demand briefly instead
                // of repeatedly loading fine tiles that leave the view at once.
                // Resident meshes, collision sweeps and pixel resolution stay
                // intact. Normal, settled flight keeps the selected detail.
                const pressure=!point.paused&&globe.tilesLoaded===false&&
                    (turning||(nearGround&&slowFrames>=2));
                if(pressure){
                    holdUntil=time+800;nextRefinement=holdUntil;
                    if(target!==4)apply(4);
                }else if(target>2&&time>=holdUntil&&time>=nextRefinement){
                    apply(Math.max(2,target-.5));
                    nextRefinement=time+300;
                }
            },
            status:()=>({active,terrainScreenSpaceError:target,adjustments:changes})
        };
    }
    function create(C,viewer,{onProfile=()=>{},terrainPassage=()=>false,now}={}){
        // Each result stays private to this adapter. Cesium copies camera
        // poses; no retained scene geometry refers to these scratch objects.
        const destination=new C.Cartesian3(),transform=new C.Matrix4(),direction=new C.Cartesian3(),up=new C.Cartesian3();
        const local=new C.Cartesian3(),a=new C.Cartesian3(),b=new C.Cartesian3(),rayDirection=new C.Cartesian3(),hit=new C.Cartesian3();
        const ray=new C.Ray(),location=new C.Cartographic();
        const euler={heading:0,pitch:0,roll:0},body={direction,up},view={destination,orientation:euler};
        const ellipsoid=viewer.scene.globe.ellipsoid;
        const streaming=createStreamingBudget(viewer.scene.globe,{now});
        const meshPicker=createTerrainMeshPicker(C);
        const shaderWarmup=createTerrainShaderWarmup(C,viewer);
        function cartesian(point,result){return C.Cartesian3.fromDegrees(point.longitude,point.latitude,point.height,ellipsoid,result);}
        function world(vector,result){
            local.x=vector.east;local.y=vector.north;local.z=vector.up;
            return C.Matrix4.multiplyByPointAsVector(transform,local,result);
        }
        return {
            captureGraphics:()=>({resolutionScale:viewer.resolutionScale,msaaSamples:viewer.scene.msaaSamples,
                tileCacheSize:viewer.scene.globe.tileCacheSize,maximumScreenSpaceError:viewer.scene.globe.maximumScreenSpaceError}),
            restoreGraphics(saved){
                streaming.stop();
                meshPicker.stop();
                viewer.resolutionScale=saved.resolutionScale;viewer.scene.msaaSamples=saved.msaaSamples;
                viewer.scene.globe.tileCacheSize=saved.tileCacheSize;
                viewer.scene.globe.maximumScreenSpaceError=saved.maximumScreenSpaceError;
                onProfile('balanced');
            },
            applyGraphics(profile){
                if(!Object.hasOwn(profiles,profile))throw new Error('Unknown flight graphics profile');
                const settings=profiles[profile];
                viewer.scene.globe.maximumScreenSpaceError=2;
                streaming.start();
                meshPicker.start();
                viewer.resolutionScale=settings.resolutionScale;viewer.scene.msaaSamples=settings.msaaSamples;
                viewer.scene.globe.tileCacheSize=Math.max(viewer.scene.globe.tileCacheSize,flightTileCacheSize);
                onProfile(profile);
                viewer.scene.requestRender();
            },
            renderedHeight(point){
                C.Cartographic.fromDegrees(point.longitude,point.latitude,0,location);
                return viewer.scene.globe.getHeight(location);
            },
            applyPose(point){
                if(Number.isFinite(point.cameraFovDegrees)&&viewer.camera.frustum){
                    const frustum=viewer.camera.frustum;
                    const canvas=viewer.scene.canvas;
                    const aspect=canvas&&canvas.clientHeight>0?canvas.clientWidth/canvas.clientHeight:frustum.aspectRatio;
                    frustum.fov=perspectiveFov(point.cameraFovDegrees,aspect||1);
                }
                cartesian(point,destination);
                let orientation=euler;
                if(point.direction&&point.up){
                    C.Transforms.eastNorthUpToFixedFrame(destination,ellipsoid,transform);
                    world(point.direction,direction);world(point.up,up);orientation=body;
                }else{euler.heading=point.heading;euler.pitch=point.pitch;euler.roll=point.roll??0;}
                view.orientation=orientation;viewer.camera.setView(view);
                // Shader preparation is a pending transition, not a slow
                // flight frame. Start the streaming clock with active motion.
                if(!point.pending)streaming.update(point);
            },
            streamingStatus:streaming.status,
            terrainPickerStatus:meshPicker.status,
            prepareGraphics:shaderWarmup.prepare,
            shaderWarmupStatus:shaderWarmup.status,
            terrainCollision(from,to){
                // Globe.pick tests the original terrain triangles, including
                // fragments discarded by a portal material. Only a bounded
                // modeled passage may exempt those invisible fragments.
                if(terrainPassage(from,to)===true)return false;
                cartesian(from,a);cartesian(to,b);
                const length=C.Cartesian3.distance(a,b);if(length<.001)return false;
                C.Cartesian3.subtract(b,a,rayDirection);C.Cartesian3.normalize(rayDirection,rayDirection);
                C.Cartesian3.clone(a,ray.origin);C.Cartesian3.clone(rayDirection,ray.direction);
                return terrainSegmentIntersects(C,viewer,ray,from,length,hit);
            }
        };
    }
    return {profiles,create,perspectiveFov,createStreamingBudget,terrainSegmentIntersects,createTerrainMeshPicker,createTerrainShaderWarmup};
});
