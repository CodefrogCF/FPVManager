(function(root,factory){
    const api=factory();
    if(typeof module==='object'&&module.exports)module.exports=api;
    else root.FPVFlightRendering=api;
})(typeof globalThis!=='undefined'?globalThis:this,function(){
    'use strict';
    const profiles=Object.freeze({
        quality:Object.freeze({resolutionScale:1,msaaSamples:4}),
        balanced:Object.freeze({resolutionScale:.85,msaaSamples:2}),
        performance:Object.freeze({resolutionScale:.75,msaaSamples:1})
    });
    // Retain recently viewed terrain and its attached imagery for return turns.
    // Cesium's LRU target counts tiles, not bytes; tiles needed by the current
    // frame may exceed it. Keep preloading and terrain detail unchanged.
    const flightTileCacheSize=512;
    function create(C,viewer){
        // Each result stays private to this adapter. Cesium copies camera
        // poses; no retained scene geometry refers to these scratch objects.
        const destination=new C.Cartesian3(),transform=new C.Matrix4(),direction=new C.Cartesian3(),up=new C.Cartesian3();
        const local=new C.Cartesian3(),a=new C.Cartesian3(),b=new C.Cartesian3(),rayDirection=new C.Cartesian3(),hit=new C.Cartesian3();
        const ray=new C.Ray(),location=new C.Cartographic();
        const euler={heading:0,pitch:0,roll:0},body={direction,up},view={destination,orientation:euler};
        const ellipsoid=viewer.scene.globe.ellipsoid;
        function cartesian(point,result){return C.Cartesian3.fromDegrees(point.longitude,point.latitude,point.height,ellipsoid,result);}
        function world(vector,result){
            local.x=vector.east;local.y=vector.north;local.z=vector.up;
            return C.Matrix4.multiplyByPointAsVector(transform,local,result);
        }
        return {
            captureGraphics:()=>({resolutionScale:viewer.resolutionScale,msaaSamples:viewer.scene.msaaSamples,
                tileCacheSize:viewer.scene.globe.tileCacheSize,maximumScreenSpaceError:viewer.scene.globe.maximumScreenSpaceError}),
            restoreGraphics(saved){
                viewer.resolutionScale=saved.resolutionScale;viewer.scene.msaaSamples=saved.msaaSamples;
                viewer.scene.globe.tileCacheSize=saved.tileCacheSize;
                viewer.scene.globe.maximumScreenSpaceError=saved.maximumScreenSpaceError;
            },
            applyGraphics(profile){
                if(!Object.hasOwn(profiles,profile))throw new Error('Unknown flight graphics profile');
                const settings=profiles[profile];
                viewer.scene.globe.maximumScreenSpaceError=2;
                viewer.resolutionScale=settings.resolutionScale;viewer.scene.msaaSamples=settings.msaaSamples;
                viewer.scene.globe.tileCacheSize=Math.max(viewer.scene.globe.tileCacheSize,flightTileCacheSize);
                viewer.scene.requestRender();
            },
            renderedHeight(point){
                C.Cartographic.fromDegrees(point.longitude,point.latitude,0,location);
                return viewer.scene.globe.getHeight(location);
            },
            applyPose(point){
                cartesian(point,destination);
                let orientation=euler;
                if(point.direction&&point.up){
                    C.Transforms.eastNorthUpToFixedFrame(destination,ellipsoid,transform);
                    world(point.direction,direction);world(point.up,up);orientation=body;
                }else{euler.heading=point.heading;euler.pitch=point.pitch;euler.roll=point.roll??0;}
                view.orientation=orientation;viewer.camera.setView(view);
            },
            terrainCollision(from,to){
                cartesian(from,a);cartesian(to,b);
                const length=C.Cartesian3.distance(a,b);if(length<.001)return false;
                C.Cartesian3.subtract(b,a,rayDirection);C.Cartesian3.normalize(rayDirection,rayDirection);
                C.Cartesian3.clone(a,ray.origin);C.Cartesian3.clone(rayDirection,ray.direction);
                const intersection=viewer.scene.globe.pick(ray,viewer.scene,hit);
                return !!intersection&&C.Cartesian3.distance(a,intersection)<=length+.001;
            }
        };
    }
    return {profiles,create};
});
