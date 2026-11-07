(function(root,factory){
    const api=factory();
    if(typeof module==='object'&&module.exports)module.exports=api;else root.FPVGlobePositions=api;
})(typeof globalThis!=='undefined'?globalThis:this,function(){
    'use strict';
    function create(C,viewer,send=()=>{}, {isTerrainReady=()=>true,isNavigationActive=()=>false}={}){
        const entities=new C.CustomDataSource('device-and-search-positions');
        let requested=null,destination=null,following=false,disposed=false;
        Promise.resolve(viewer.dataSources.add(entities)).then(()=>{if(disposed)viewer.dataSources.remove(entities,true);});
        const cleanups=[];
        function valid(p){return p&&Number.isFinite(p.latitude)&&Number.isFinite(p.longitude)&&Math.abs(p.latitude)<=90&&Math.abs(p.longitude)<=180;}
        function point(p){return C.Cartesian3.fromDegrees(p.longitude,p.latitude,0);}
        function focus(p){
            if(isNavigationActive())return;
            const ground=isTerrainReady()?viewer.scene.globe.getHeight(C.Cartographic.fromDegrees(p.longitude,p.latitude)):undefined;
            viewer.camera.flyTo({destination:C.Cartesian3.fromDegrees(p.longitude,p.latitude,Number.isFinite(ground)?ground+1500:12000),
                orientation:{heading:0,pitch:-Math.PI/2,roll:0},duration:.6});
        }
        function draw(){
            entities.entities.removeAll();
            const fix=requested?.enabled?requested.fix:null;
            if(fix){
                const color=fix.stale?C.Color.GRAY:C.Color.fromCssColorString('#5eb4ff');
                const radius=Math.min(10000,Math.max(1,fix.accuracyMeters));
                entities.entities.add({id:'fpv-device-accuracy',position:point(fix),ellipse:{semiMajorAxis:radius,semiMinorAxis:radius,
                    material:color.withAlpha(.13),heightReference:C.HeightReference.CLAMP_TO_GROUND},fpvPositionMarker:true});
                entities.entities.add({id:'fpv-device-position',position:point(fix),point:{pixelSize:13,color,outlineColor:C.Color.WHITE,
                    outlineWidth:2,heightReference:C.HeightReference.CLAMP_TO_GROUND,disableDepthTestDistance:Number.POSITIVE_INFINITY},fpvPositionMarker:true});
                if(fix.heading!==null&&!fix.stale){
                    const heading=fix.heading*Math.PI/180;
                    const end={latitude:Math.max(-90,Math.min(90,fix.latitude+25*Math.cos(heading)/111320)),
                        longitude:fix.longitude+25*Math.sin(heading)/(111320*Math.max(.01,Math.cos(fix.latitude*Math.PI/180)))};
                    if(valid(end))entities.entities.add({id:'fpv-device-course',polyline:{positions:[point(fix),point(end)],width:4,
                        clampToGround:true,material:color},fpvPositionMarker:true});
                }
            }
            if(destination)entities.entities.add({id:'fpv-search-destination',position:point(destination),
                point:{pixelSize:12,color:C.Color.fromCssColorString('#f8c449'),outlineColor:C.Color.BLACK,outlineWidth:2,
                    heightReference:C.HeightReference.CLAMP_TO_GROUND,disableDepthTestDistance:Number.POSITIVE_INFINITY},
                label:{text:destination.name,font:'14px sans-serif',fillColor:C.Color.WHITE,outlineColor:C.Color.BLACK,outlineWidth:3,
                    style:C.LabelStyle.FILL_AND_OUTLINE,pixelOffset:new C.Cartesian2(0,-24),heightReference:C.HeightReference.CLAMP_TO_GROUND,
                    distanceDisplayCondition:new C.DistanceDisplayCondition(0,60000)},fpvPositionMarker:true});
            viewer.scene.requestRender();
        }
        function manual(){if(!following)return;following=false;send('location-follow-changed',{following:false});}
        for(const type of ['pointerdown','wheel']){viewer.canvas.addEventListener(type,manual);cleanups.push(()=>viewer.canvas.removeEventListener(type,manual));}
        return {
            location(command){
                if(disposed)return {};
                const p=command.fix;
                if(typeof command.enabled!=='boolean'||typeof command.follow!=='boolean'||typeof command.recenter!=='boolean'||
                    (p!==null&&(!valid(p)||!Number.isFinite(p.accuracyMeters)||p.accuracyMeters<0||typeof p.stale!=='boolean'||
                        typeof p.timeUtc!=='string'||!Number.isFinite(Date.parse(p.timeUtc))||
                        p.heading!==null&&(!Number.isFinite(p.heading)||p.heading<0||p.heading>=360))))throw Error('Invalid device location');
                requested=command;following=command.enabled&&command.follow&&!!p&&!p.stale;
                draw();if(command.enabled&&p&&!p.stale&&(command.recenter||following))focus(p);return {};
            },
            destination(command){
                if(!valid(command)||typeof command.name!=='string'||command.name.length>250)throw Error('Invalid search destination');
                destination={latitude:command.latitude,longitude:command.longitude,name:command.name};draw();if(command.recenter!==false)focus(destination);return {};
            },
            dispose(){if(disposed)return;disposed=true;for(const remove of cleanups)remove();viewer.dataSources.remove(entities,true);}
        };
    }
    return {create};
});
