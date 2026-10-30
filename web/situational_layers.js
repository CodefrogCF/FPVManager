(function(root,factory){
    if(typeof module==='object'&&module.exports)module.exports=factory();
    else root.FPVSituationalLayers=factory();
})(typeof globalThis!=='undefined'?globalThis:this,function(){
    'use strict';
    const definitions={
        roads:{layer:'ch.swisstopo.swisstlm3d-strassen',label:'Roads and paths',attribution:'© swisstopo · geo.admin.ch',bounds:[3.329595,44.074747,14.278255,49.200438]},
        heliports:{layer:'ch.bazl.flugplaetze-heliports',label:'Aerodrome / heliport',attribution:'BAZL / FOCA · geo.admin.ch'},
        wildfire:{layer:'ch.bafu.gefahren-waldbrand_warnung',label:'Wildfire warning',attribution:'BAFU / FOEN · geo.admin.ch'}
    };
    const credits={road:'OSRM / FOSSGIS · © OpenStreetMap contributors · ODbL 1.0',
        traffic:'Datenquelle: Verkehrsdaten-Plattform (VDP) ASTRA','traffic-counters':'Datenquelle: Verkehrsdaten-Plattform (VDP) ASTRA · Messstellen',aircraft:'adsb.lol community · ODbL 1.0 · incomplete reception',
        avalanche:'<a href="https://www.slf.ch" target="_blank" rel="noopener">WSL-Institut für Schnee- und Lawinenforschung SLF</a> · CC BY 4.0'};
    const trafficColors={closure:'#e75c54',accident:'#e75c54',congestion:'#ef9847',roadworks:'#d6b74f',weather:'#55a9db',hazard:'#bb82cf',other:'#aab4b7'};
    function validate(command){
        if(!command||!['road','traffic','traffic-counters','aircraft','avalanche',...Object.keys(definitions)].includes(command.id)||typeof command.visible!=='boolean')throw new Error('Invalid situational layer');
        if(definitions[command.id]){
            if(!Number.isFinite(command.opacity)||command.opacity<0||command.opacity>1)throw new Error('Invalid layer opacity');
            return;
        }
        if(!command.visible)return;
        if(command.id==='avalanche'&&(!Number.isFinite(command.opacity)||command.opacity<0||command.opacity>1))throw new Error('Invalid avalanche opacity');
        if(!Array.isArray(command.features)||command.features.length>1000)throw new Error('Invalid awareness feature count');
        let vertices=0;const ids=new Set();
        for(const feature of command.features){
            if(typeof feature.id!=='string'||feature.id.length>160||ids.has(feature.id)||typeof feature.name!=='string'||feature.name.length>200||
                typeof feature.detail!=='string'||feature.detail.length>(command.id==='avalanche'?16000:1200))throw new Error('Invalid awareness feature');
            ids.add(feature.id);
            const geometry=feature.geometry;
            if(command.id==='avalanche'){
                if(!geometry||!['Polygon','MultiPolygon'].includes(geometry.type)||!Number.isInteger(feature.level)||feature.level<0||feature.level>5)throw new Error('Invalid avalanche polygon');
                const polygons=geometry.type==='Polygon'?[geometry.coordinates]:geometry.coordinates;
                if(!Array.isArray(polygons)||!polygons.length||polygons.length>256)throw new Error('Invalid avalanche parts');
                for(const polygon of polygons){
                    if(!Array.isArray(polygon)||!polygon.length||polygon.length>64)throw new Error('Invalid avalanche rings');
                    for(const ring of polygon){
                        if(!Array.isArray(ring)||ring.length<4||(vertices+=ring.length)>20000)throw new Error('Avalanche vertex limit');
                        for(const p of ring)if(!Array.isArray(p)||p.length!==2||!p.every(Number.isFinite)||p[0]<5.5||p[0]>11||p[1]<45.5||p[1]>48.5)throw new Error('Invalid avalanche coordinate');
                        if(ring[0][0]!==ring.at(-1)[0]||ring[0][1]!==ring.at(-1)[1])throw new Error('Unclosed avalanche ring');
                    }
                }
                for(const field of ['timestampUtc','validFromUtc','validUntilUtc'])if(typeof feature[field]!=='string'||!Number.isFinite(Date.parse(feature[field])))throw new Error('Invalid avalanche validity');
                continue;
            }
            if(!geometry||!['Point','LineString'].includes(geometry.type))throw new Error('Unsupported awareness geometry');
            if((['aircraft','traffic-counters'].includes(command.id)&&geometry.type!=='Point')||(command.id==='road'&&geometry.type!=='LineString'))throw new Error('Unsupported layer geometry');
            const positions=geometry.type==='Point'?[geometry.coordinates]:geometry.coordinates;
            if(!Array.isArray(positions)||positions.length<(geometry.type==='Point'?1:2))throw new Error('Invalid awareness coordinates');
            vertices+=positions.length;if(vertices>20000)throw new Error('Awareness geometry limit exceeded');
            for(const p of positions)if(!Array.isArray(p)||p.length!==2||!p.every(Number.isFinite)||Math.abs(p[0])>180||Math.abs(p[1])>90)throw new Error('Invalid awareness position');
            for(const field of ['timestampUtc','validFromUtc','validUntilUtc'])if(feature[field]!=null&&(!Number.isFinite(Date.parse(feature[field]))||typeof feature[field]!=='string'))throw new Error('Invalid awareness time');
            if(command.id==='traffic'&&feature.category!=null&&!Object.hasOwn(trafficColors,feature.category))throw new Error('Invalid traffic category');
        }
    }
    function create(C,viewer,emit,wmsFactory,{yieldBatch=()=>new Promise(r=>setTimeout(r,0)),now=()=>Date.now(),timers=globalThis}={}){
        const layers=new Map(),wms=new Map(),generations=new Map(),staged=new Set();let disposed=false;
        const escape=s=>s.replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
        function remove(record){if(!record)return;viewer.dataSources.remove(record.source,true);viewer.cesiumWidget?.creditDisplay?.removeStaticCredit(record.credit);}
        function visibility(){
            const rectangle=viewer.camera.computeViewRectangle?.(viewer.scene.globe.ellipsoid),time=now();
            for(const [id,record] of layers)for(const {entity,feature} of record.entries){
                let shown=true;
                if(feature.validUntilUtc&&Date.parse(feature.validUntilUtc)<=time)shown=false;
                if(id==='avalanche'&&feature.validFromUtc&&Date.parse(feature.validFromUtc)>time)shown=false;
                if(id==='traffic'&&((feature.validFromUtc&&Date.parse(feature.validFromUtc)>time)||feature.suspended===true))shown=false;
                if(id==='traffic-counters'){
                    const age=time-Date.parse(feature.timestampUtc);
                    shown=shown&&Number.isFinite(age)&&age>=-5000&&age<=180000;
                }
                if(id==='aircraft'){
                    const age=time-Date.parse(feature.timestampUtc);
                    // Unknown/future timestamps never become a current aircraft fix.
                    shown=shown&&Number.isFinite(age)&&age>=-5000&&age<=300000;
                    entity.point.color=C.Color.fromCssColorString(age>30000?'#e6b64d':'#55c6e8');
                }
                if(rectangle&&feature.geometry.type==='Point'){
                    const [lon,lat]=feature.geometry.coordinates,p=C.Cartographic.fromDegrees(lon,lat);
                    if(C.Rectangle.contains)shown=shown&&C.Rectangle.contains(rectangle,p);
                }
                entity.show=shown;
            }
            viewer.scene.requestRender();
        }
        const stopViewport=viewer.camera.moveEnd?.addEventListener(visibility);
        const timer=timers.setInterval(visibility,15000);
        function clear(id){generations.set(id,(generations.get(id)||0)+1);remove(layers.get(id));layers.delete(id);}
        async function set(command){
            validate(command);if(disposed)throw new Error('Situational layers disposed');
            if(definitions[command.id]){
                if(!wms.has(command.id)){
                    const d=definitions[command.id];
                    wms.set(command.id,wmsFactory(C,viewer,(_,state)=>emit('situational-status',{id:command.id,...state}),{
                        definition:{url:'https://wms.geo.admin.ch/',layer:d.layer,bounds:d.bounds??[5.8,45.7,10.7,47.9]},
                        label:d.label,attribution:d.attribution,statusEvent:'situational-status'}));
                }
                wms.get(command.id).set(command);return {};
            }
            if(!command.visible){clear(command.id);return {};}
            const generation=(generations.get(command.id)||0)+1;generations.set(command.id,generation);
            const source=new C.CustomDataSource(`FPVManager ${command.id}`),entries=[];staged.add(source);
            const credit=new C.Credit(credits[command.id],true);
            const current=()=>!disposed&&generation===generations.get(command.id);
            try{
                for(let i=0;i<command.features.length;i++){
                    if(!current())return {superseded:true};
                    const feature=command.features[i],g=feature.geometry,color=C.Color.fromCssColorString(command.id==='road'?'#96cc76':command.id==='traffic'?(trafficColors[feature.category]??trafficColors.other):'#55c6e8');
                    const entity={id:`situational-${command.id}-${feature.id}`,name:feature.name,
                        description:`<p>${escape(feature.detail).replace(/\n/g,'<br>')}</p><p>${credits[command.id]}</p>`,properties:{situationalLayer:command.id,situationalFeature:feature.id}};
                    if(command.id==='avalanche'){
                        const palette=['#89949e','#ccff66','#ffff00','#ff9900','#ff0000','#660000'];
                        const base=C.Color.fromCssColorString(palette[feature.level]);
                        const polygons=g.type==='Polygon'?[g.coordinates]:g.coordinates;
                        for(let j=0;j<polygons.length;j++){
                            if(!current())return {superseded:true};
                            const rings=polygons[j],hierarchy=new C.PolygonHierarchy(C.Cartesian3.fromDegreesArray(rings[0].flat()),
                                rings.slice(1).map(r=>new C.PolygonHierarchy(C.Cartesian3.fromDegreesArray(r.flat()))));
                            entries.push({entity:source.entities.add({...entity,id:entity.id+'-'+j,
                                polygon:{hierarchy,material:base.withAlpha(command.opacity),heightReference:C.HeightReference.CLAMP_TO_GROUND,
                                    classificationType:C.ClassificationType.TERRAIN}}),feature});
                            if(j%20===19)await yieldBatch();
                        }
                    }else if(g.type==='Point'){
                        entity.position=C.Cartesian3.fromDegrees(...g.coordinates);
                        entity.point={pixelSize:command.id==='traffic'?12:9,color,outlineColor:C.Color.BLACK,outlineWidth:1,heightReference:C.HeightReference.CLAMP_TO_GROUND,
                            disableDepthTestDistance:Number.POSITIVE_INFINITY};
                    }else entity.polyline={positions:C.Cartesian3.fromDegreesArray(g.coordinates.flat()),width:4,material:color,clampToGround:true};
                    if(command.id!=='avalanche')entries.push({entity:source.entities.add(entity),feature});
                    if(i%100===99)await yieldBatch();
                }
                await viewer.dataSources.add(source);
                if(!current())return {superseded:true};
                remove(layers.get(command.id));layers.set(command.id,{source,entries,credit});staged.delete(source);
                viewer.cesiumWidget?.creditDisplay?.addStaticCredit(credit);visibility();return {count:entries.length};
            }finally{if(!current()||staged.has(source)){staged.delete(source);viewer.dataSources.remove(source,true);}}
        }
        function pick(entity){
            for(const [id,record] of layers){
                const found=record.entries.find(e=>e.entity===entity);
                if(found){emit('situational-selected',{id,name:found.feature.name,detail:found.feature.detail});return found.feature;}
            }
            return false;
        }
        return {set,pick,dispose(){disposed=true;timers.clearInterval(timer);stopViewport?.();for(const record of layers.values())remove(record);
            layers.clear();for(const source of staged)viewer.dataSources.remove(source,true);staged.clear();for(const layer of wms.values())layer.dispose();wms.clear();}};
    }
    return {create,validate,definitions};
});
