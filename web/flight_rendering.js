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
                streaming.update(point);
            },
            streamingStatus:streaming.status,
            terrainCollision(from,to){
                // Globe.pick tests the original terrain triangles, including
                // fragments discarded by a portal material. Only a bounded
                // modeled passage may exempt those invisible fragments.
                if(terrainPassage(from,to)===true)return false;
                cartesian(from,a);cartesian(to,b);
                const length=C.Cartesian3.distance(a,b);if(length<.001)return false;
                C.Cartesian3.subtract(b,a,rayDirection);C.Cartesian3.normalize(rayDirection,rayDirection);
                C.Cartesian3.clone(a,ray.origin);C.Cartesian3.clone(rayDirection,ray.direction);
                const intersection=viewer.scene.globe.pick(ray,viewer.scene,hit);
                return !!intersection&&C.Cartesian3.distance(a,intersection)<=length+.001;
            }
        };
    }
    return {profiles,create,perspectiveFov,createStreamingBudget};
});
