(function(root,factory){
    if(typeof module==='object'&&module.exports)module.exports=factory();
    else root.FPVRoadNavigation=factory();
})(typeof globalThis!=='undefined'?globalThis:this,function(){
    'use strict';
    function validate(command){
        if(typeof command.active!=='boolean'||typeof command.follow!=='boolean')throw new Error('Invalid road navigation state');
        const distance=command.cameraDistanceMeters??550;
        if(!Number.isFinite(distance)||distance<60||distance>1800)throw new Error('Invalid navigation camera distance');
        const p=command.position;if(p==null)return;
        if(!Number.isFinite(p.latitude)||!Number.isFinite(p.longitude)||Math.abs(p.latitude)>90||Math.abs(p.longitude)>180||
            !Number.isFinite(p.heading)||p.heading<0||p.heading>=360)throw new Error('Invalid road navigation position');
    }
    function create(C,viewer,onFollow=()=>{}){
        let marker=null,saved=null,latest=null,disposed=false,terrainPending=false,groundReady=false,groundFrames=0;
        function follow(){
            if(!latest?.active||!latest.follow||!latest.position)return;
            const p=latest.position,location=C.Cartographic.fromDegrees(p.longitude,p.latitude);
            // Early fill meshes can report a finite ellipsoid-like height while
            // real terrain is still loading. Complete the initial overview first.
            const sampled=viewer.scene.globe.getHeight(location),known=Number.isFinite(sampled)&&(groundReady||(groundFrames>=2&&viewer.scene.globe.tilesLoaded===true)),height=known?sampled:0;
            if(known)groundReady=true;
            terrainPending=!known;
            const target=C.Cartesian3.fromDegrees(p.longitude,p.latitude,height);
            viewer.camera.lookAt(target,new C.HeadingPitchRange(C.Math.toRadians(p.heading),C.Math.toRadians(known?-65:-90),known?(latest.cameraDistanceMeters??550):12000));
            viewer.camera.lookAtTransform(C.Matrix4.IDENTITY);viewer.scene.requestRender();
        }
        const removeTerrain=viewer.scene.globe.tileLoadProgressEvent.addEventListener(count=>{if(count===0)follow();});
        const removeFrame=viewer.scene.postRender.addEventListener(()=>{if(terrainPending){groundFrames++;follow();}});
        function stop(){
            latest=null;terrainPending=false;groundReady=false;groundFrames=0;if(marker){viewer.entities.remove(marker);marker=null;}
            if(saved){viewer.scene.screenSpaceCameraController.enableInputs=saved.inputs;
                viewer.camera.lookAtTransform(C.Matrix4.IDENTITY);
                viewer.camera.setView({destination:saved.destination,orientation:{direction:saved.direction,up:saved.up}});saved=null;}
        }
        const manager={get active(){return !!latest?.active;},get following(){return !!latest?.follow;},
        toggleFollow(){
            if(!latest?.active)return;
            const follow=!latest.follow;manager.set({...latest,follow});onFollow(follow);
        },set(command){
            validate(command);if(disposed)throw new Error('Road navigation disposed');
            if(!command.active){stop();return {};}
            if(!saved)saved={inputs:viewer.scene.screenSpaceCameraController.enableInputs,
                destination:C.Cartesian3.clone(viewer.camera.positionWC),direction:C.Cartesian3.clone(viewer.camera.directionWC),up:C.Cartesian3.clone(viewer.camera.upWC)};
            const p=command.position,previous=latest?.position;
            const jump=p&&previous&&Math.hypot(p.latitude-previous.latitude,
                ((p.longitude-previous.longitude+540)%360-180)*Math.cos(p.latitude*Math.PI/180))>.01;
            if(command.follow&&(!latest?.follow||!previous||jump)){groundReady=false;groundFrames=0;}
            latest=command;viewer.scene.screenSpaceCameraController.enableInputs=!command.follow;
            if(!marker)marker=viewer.entities.add({id:'road-navigation-position',name:'Aktueller Standort',
                point:{pixelSize:18,color:C.Color.fromCssColorString('#00a331'),outlineColor:C.Color.WHITE,outlineWidth:3,
                    heightReference:C.HeightReference.CLAMP_TO_GROUND,disableDepthTestDistance:Number.POSITIVE_INFINITY}});
            marker.show=!!command.position;
            if(command.position)marker.position=C.Cartesian3.fromDegrees(command.position.longitude,command.position.latitude);
            follow();viewer.scene.requestRender();return {};
        },dispose(){if(disposed)return;stop();removeTerrain();removeFrame();disposed=true;}};
        return manager;
    }
    return {create,validate};
});
