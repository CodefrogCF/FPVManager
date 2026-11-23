(function(root,factory){
    if(typeof module==='object'&&module.exports)module.exports=factory();
    else root.FPVRoadNavigation=factory();
})(typeof globalThis!=='undefined'?globalThis:this,function(){
    'use strict';
    const graphics=Object.freeze({resolutionScale:.9,msaaSamples:2,tileCacheSize:256});
    const longitude=value=>((value+540)%360)-180;
    const angle=(from,to)=>longitude(to-from);
    const distance=(a,b)=>Math.hypot(a.latitude-b.latitude,
        longitude(a.longitude-b.longitude)*Math.cos((a.latitude+b.latitude)*Math.PI/360))*111195;
    function validate(command){
        if(typeof command.active!=='boolean'||typeof command.follow!=='boolean')throw new Error('Invalid road navigation state');
        const d=command.cameraDistanceMeters??550;
        if(!Number.isFinite(d)||d<60||d>1800)throw new Error('Invalid navigation camera distance');
        const p=command.position;if(p==null)return;
        if(!Number.isFinite(p.latitude)||!Number.isFinite(p.longitude)||Math.abs(p.latitude)>90||Math.abs(p.longitude)>180||
            !Number.isFinite(p.heading)||p.heading<0||p.heading>=360)throw new Error('Invalid road navigation position');
    }
    function create(C,viewer,onFollow=()=>{},{now=()=>performance.now(),onActive=()=>{},isTerrainReady=()=>true}={}){
        const scene=viewer.scene,globe=scene.globe,camera=viewer.camera;
        const location=new C.Cartographic(),target=new C.Cartesian3(),markerWorld=new C.Cartesian3();
        const offset=new C.HeadingPitchRange(),from={},to={},display={},heights=new Map();
        const lastPose={},resumeView={destination:new C.Cartesian3(),orientation:{}};
        const metrics={fixes:0,frames:0,terrainQueries:0,cameraUpdates:0,markerUpdates:0};
        let marker=null,saved=null,latest=null,disposed=false,hasPosition=false,groundReady=false,groundFrames=0;
        let start=0,duration=0,lastFixAt=null,lastFrame=null,lastGroundAt=-Infinity,terrainDirty=true;
        let height=0,wantedHeight=0,range=12000,pitch=-90,force=true,resume=null;
        function interpolate(at){
            if(!hasPosition)return;
            const fraction=duration?Math.min(1,Math.max(0,(at-start)/duration)):1;
            // Stop at the latest accepted fix; never extrapolate vehicle motion.
            display.latitude=from.latitude+(to.latitude-from.latitude)*fraction;
            display.longitude=longitude(from.longitude+longitude(to.longitude-from.longitude)*fraction);
            display.heading=(from.heading+angle(from.heading,to.heading)*fraction+360)%360;
        }
        function terrain(at){
            if(at-lastGroundAt<200)return;
            if(!isTerrainReady()){lastGroundAt=at;heights.clear();terrainDirty=true;return;}
            const key=display.latitude.toFixed(4)+','+display.longitude.toFixed(4);
            if(!terrainDirty&&at-lastGroundAt<1000&&heights.has(key))return;
            lastGroundAt=at;
            // Finite fill meshes can still be ellipsoid-like before real tiles load.
            if(!groundReady&&(groundFrames<2||globe.tilesLoaded!==true))return;
            let value;const cached=heights.get(key);
            if(!terrainDirty&&cached&&at-cached.at<10000)value=cached.height;
            else{
                C.Cartographic.fromDegrees(display.longitude,display.latitude,0,location);
                metrics.terrainQueries++;value=globe.getHeight(location);
                if(Number.isFinite(value)){
                    heights.delete(key);heights.set(key,{height:value,at});
                    while(heights.size>256)heights.delete(heights.keys().next().value);
                }
            }
            terrainDirty=false;
            if(Number.isFinite(value)){wantedHeight=value;groundReady=true;}
        }
        function draw(at,frame=false){
            if(!latest?.active||!hasPosition)return;
            if(frame){metrics.frames++;groundFrames++;}
            const gap=lastFrame==null?0:(at-lastFrame)/1000;
            // A suspended loop catches up to its last fix, never a backlog.
            if(gap>1)duration=0;
            const dt=Math.max(0,Math.min(.1,gap));lastFrame=at;
            interpolate(at);
            const previousX=markerWorld.x,previousY=markerWorld.y,previousZ=markerWorld.z;
            C.Cartesian3.fromDegrees(display.longitude,display.latitude,0,globe.ellipsoid,markerWorld);
            if(force||markerWorld.x!==previousX||markerWorld.y!==previousY||markerWorld.z!==previousZ){
                marker.position.setValue(markerWorld);metrics.markerUpdates++;
            }
            if(!latest.follow){force=false;return;}
            terrain(at);
            const blend=1-Math.exp(-dt/.18),wantedRange=groundReady?(latest.cameraDistanceMeters??550):12000;
            height+=(wantedHeight-height)*blend;range+=(wantedRange-range)*blend;
            pitch+=((groundReady?-65:-90)-pitch)*blend;
            if(Math.abs(range-wantedRange)<.02)range=wantedRange;
            if(Math.abs(height-wantedHeight)<.005)height=wantedHeight;
            if(Math.abs(pitch-(groundReady?-65:-90))<.001)pitch=groundReady?-65:-90;
            if(force||resume||display.latitude!==lastPose.latitude||display.longitude!==lastPose.longitude||
                display.heading!==lastPose.heading||height!==lastPose.height||range!==lastPose.range||pitch!==lastPose.pitch){
                C.Cartesian3.fromDegrees(display.longitude,display.latitude,height,globe.ellipsoid,target);
                offset.heading=C.Math.toRadians(display.heading);offset.pitch=C.Math.toRadians(pitch);offset.range=range;
                camera.lookAt(target,offset);camera.lookAtTransform(C.Matrix4.IDENTITY);
                if(resume){
                    const t=Math.min(1,Math.max(0,(at-resume.at)/650)),blend=t*t*(3-2*t),radians=Math.PI/180;
                    C.Cartesian3.lerp(resume.position,camera.positionWC,blend,resumeView.destination);
                    resumeView.orientation.heading=resume.heading+angle(resume.heading/radians,camera.heading/radians)*radians*blend;
                    resumeView.orientation.pitch=resume.pitch+(camera.pitch-resume.pitch)*blend;
                    resumeView.orientation.roll=resume.roll*(1-blend);
                    camera.setView(resumeView);if(t===1)resume=null;
                }
                Object.assign(lastPose,display,{height,range,pitch});metrics.cameraUpdates++;scene.requestRender();
            }
            force=false;
        }
        const removeTerrain=globe.tileLoadProgressEvent.addEventListener(count=>{if(count===0){terrainDirty=true;heights.clear();}});
        // Update the pose before Cesium traverses terrain, models and entities.
        const removeFrame=scene.preUpdate.addEventListener(()=>draw(now(),true));
        function stop(){
            const wasActive=!!latest?.active;
            latest=null;hasPosition=false;lastFrame=null;lastFixAt=null;resume=null;heights.clear();
            if(marker){viewer.entities.remove(marker);marker=null;}
            if(saved){
                scene.screenSpaceCameraController.enableInputs=saved.inputs;
                viewer.resolutionScale=saved.resolutionScale;scene.msaaSamples=saved.msaaSamples;
                globe.tileCacheSize=saved.tileCacheSize;
                camera.lookAtTransform(C.Matrix4.IDENTITY);
                camera.setView({destination:saved.destination,orientation:{direction:saved.direction,up:saved.up}});saved=null;
            }
            if(wasActive)onActive(false);
        }
        const manager={get active(){return !!latest?.active;},get following(){return !!latest?.follow;},
            // Read only by diagnostics; no per-frame bridge messages/location logs.
            get metrics(){return {...metrics};},
            toggleFollow(){if(!latest?.active)return;const follow=!latest.follow;manager.set({...latest,follow});onFollow(follow);},
            set(command){
                validate(command);if(disposed)throw new Error('Road navigation disposed');
                if(!command.active){stop();return {};}
                const at=now(),starting=!latest?.active;
                if(!saved){
                    saved={inputs:scene.screenSpaceCameraController.enableInputs,
                        destination:C.Cartesian3.clone(camera.positionWC),direction:C.Cartesian3.clone(camera.directionWC),up:C.Cartesian3.clone(camera.upWC),
                        resolutionScale:viewer.resolutionScale,msaaSamples:scene.msaaSamples,tileCacheSize:globe.tileCacheSize};
                    viewer.resolutionScale=Math.min(viewer.resolutionScale,graphics.resolutionScale);
                    scene.msaaSamples=Math.min(scene.msaaSamples,graphics.msaaSamples);
                    globe.tileCacheSize=graphics.tileCacheSize;
                    onActive(true);
                }
                const p=command.position,resuming=command.follow&&!latest?.follow;
                if(!command.follow)resume=null;
                else if(resuming&&!starting&&hasPosition)resume={at,position:C.Cartesian3.clone(camera.positionWC),
                    heading:camera.heading,pitch:camera.pitch,roll:camera.roll};
                if(!marker)marker=viewer.entities.add({id:'road-navigation-position',name:'Aktueller Standort',
                    position:new C.ConstantPositionProperty(),
                    point:{pixelSize:18,color:C.Color.fromCssColorString('#00a331'),outlineColor:C.Color.WHITE,outlineWidth:3,
                        heightReference:C.HeightReference.CLAMP_TO_GROUND,disableDepthTestDistance:Number.POSITIVE_INFINITY}});
                marker.show=!!p;
                if(p){
                    const changed=!hasPosition||p.latitude!==to.latitude||p.longitude!==to.longitude||p.heading!==to.heading;
                    if(changed){
                        interpolate(at);const jump=!hasPosition||distance(display,p)>250;
                        Object.assign(from,jump?p:display);Object.assign(to,p);start=at;
                        duration=jump?0:Math.max(150,Math.min(1000,lastFixAt==null?600:at-lastFixAt));
                        lastFixAt=at;metrics.fixes++;
                        if(jump){
                            groundReady=false;groundFrames=0;height=0;wantedHeight=0;range=12000;pitch=-90;
                            lastGroundAt=-Infinity;terrainDirty=true;
                        }
                    }
                    hasPosition=true;
                }else{hasPosition=false;duration=0;lastFixAt=null;lastFrame=null;}
                latest={...command,position:p?{...p}:null};scene.screenSpaceCameraController.enableInputs=!command.follow;
                if(starting||resuming){camera.cancelFlight();force=true;lastFrame=at;}
                draw(at);scene.requestRender();return {};
            },
            dispose(){if(disposed)return;stop();removeTerrain();removeFrame();disposed=true;}
        };
        return manager;
    }
    return {create,validate,graphics};
});
