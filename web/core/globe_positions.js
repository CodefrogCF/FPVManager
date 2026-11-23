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
    function createSpotGrounding(C, scene){
        const {globe}=scene,ellipsoid=globe.ellipsoid;
        const ray=new C.Ray(),intersection=new C.Cartesian3(),origin=new C.Cartographic();
        const spots=new Map(),renderedMeshes=new Map();
        let pending=null,dirty=true;

        function refresh(){dirty=true;scene.requestRender();}

        function update(){
            if(!spots.size)return;
            const tiles=globe._surface?._tilesRenderedThisFrame;
            if(tiles){
                let changed=renderedMeshes.size!==tiles.size;
                if(!changed)for(const tile of tiles){
                    if(!renderedMeshes.has(tile)||renderedMeshes.get(tile)!==tile.data?.renderedMesh){changed=true;break;}
                }
                if(changed){
                    renderedMeshes.clear();
                    for(const tile of tiles)renderedMeshes.set(tile,tile.data?.renderedMesh);
                    dirty=true;
                }
            }
            if(!pending&&dirty){pending=spots.values();dirty=false;}
            if(!pending)return;
            const deadline=performance.now()+2;
            for(let count=0;count<64;count++){
                const next=pending.next();
                if(next.done){pending=null;break;}
                const spot=next.value,{entity,position}=spot;
                // Follow the mesh actually drawn under the spot. Asynchronous
                // height references can retain finer or older terrain heights.
                let tile;
                if(tiles)for(const candidate of tiles){
                    if(candidate.data?.renderedMesh&&C.Rectangle.contains(candidate.rectangle,position)&&
                        (!tile||candidate.level>tile.level))tile=candidate;
                }
                const mesh=tile?.data.renderedMesh;
                if(mesh&&mesh===spot.mesh)continue;
                let hit;
                if(tile||!tiles){
                    origin.longitude=position.longitude;
                    origin.latitude=position.latitude;
                    origin.height=100000;
                    ellipsoid.cartographicToCartesian(origin,ray.origin);
                    ellipsoid.geodeticSurfaceNormalCartographic(position,ray.direction);
                    C.Cartesian3.negate(ray.direction,ray.direction);
                    hit=globe.pick(ray,scene,intersection);
                }
                spot.mesh=hit?mesh:undefined;
                if(hit)entity.position.setValue(hit);
                if(entity.show!==Boolean(hit))entity.show=Boolean(hit);
                if(performance.now()>=deadline)break;
            }
            if(pending||dirty)scene.requestRender();
        }
        const removeUpdate=scene.postRender.addEventListener(update);
        return {
            set(entity, longitude, latitude){
                const previous=spots.get(entity.id);
                const position=C.Cartographic.fromDegrees(longitude,latitude);
                if(previous&&C.Cartographic.equals(previous.position,position))return;
                entity.show=false;
                spots.set(entity.id,{entity,position});
                refresh();
            },
            remove(id){spots.delete(id);},
            dispose(){removeUpdate();spots.clear();renderedMeshes.clear();pending=null;}
        };
    }
    return {create,createSpotGrounding};
});
