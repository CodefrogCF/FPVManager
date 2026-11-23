(function(root,factory) {
    if (typeof module === 'object' && module.exports) module.exports = factory();
    else root.FPVObstacleModels = factory();
})(typeof globalThis !== 'undefined' ? globalThis : this, function() {
    'use strict';
    const types = Object.freeze({TRANSMISSION_LINE:'power-pylon', POLE:'utility-pole',
        MAST:'antenna-mast', TOWER:'lattice-tower', CRANE:'tower-crane', STACK:'chimney',
        WINDMILL:'wind-turbine', CABLE_CAR:'cableway-support', CATENARY:'cableway-support'});
    const range = 6000;
    // The obstacle feed is the official Swiss BAZL/Skyguide source, NOT an
    // OpenStreetMap import. Optional OSM tags refine only schematic visuals.
    // Reference point: OSM way 210985229 (Säntis transmitter); position is
    // used solely for a bounded model choice, never to replace source height.
    const SAENTIS = Object.freeze({longitude:9.342444, latitude:47.249464,
        height:123.5, toleranceMeters:80});
    const catalog = new Set([...Object.values(types),'communication-tower',
        'communication-lattice','observation-tower']);
    const tagValue = (tags,key) => typeof tags?.[key] === 'string'
        ? tags[key].trim().toLowerCase() : '';
    function nearbySite(coordinates, site=SAENTIS) {
        if (!Array.isArray(coordinates) || coordinates.length < 2 ||
            !coordinates.slice(0,2).every(Number.isFinite)) return false;
        const [lon,lat]=coordinates;
        return Math.hypot((lon-site.longitude)*111320*Math.cos(site.latitude*Math.PI/180),
            (lat-site.latitude)*111320) < site.toleranceMeters;
    }
    // Explicit tags take priority. Sparse BAZL obstacle classes fall back
    // conservatively; large generic POLE objects are never wooden crosses.
    function classify(sourceType, heightAgl, osmTags={}, coordinates=null) {
        const type=String(sourceType??'').trim().toUpperCase();
        const height=Number.isFinite(heightAgl)&&heightAgl>0&&heightAgl<1500?heightAgl:null;
        const man=tagValue(osmTags,'man_made'), tower=tagValue(osmTags,'tower:type'),
            structure=tagValue(osmTags,'tower:construction') || tagValue(osmTags,'construction'),
            power=tagValue(osmTags,'power');
        const hasOsmTower=man==='tower'||man==='mast'||man==='communications_tower';
        if (power==='tower') return 'power-pylon';
        if (power==='pole') return 'utility-pole';
        if (hasOsmTower) {
            if (tower==='observation'||tower==='watchtower') return 'observation-tower';
            if (tower==='communication'||tower==='communications'||man==='communications_tower'||
                tagValue(osmTags,'communication:mobile_phone')==='yes'||
                tagValue(osmTags,'communication:radio')==='yes'||
                tagValue(osmTags,'communication:television')==='yes') {
                if (structure.includes('lattice')||structure.includes('freestanding_lattice'))
                    return 'communication-lattice';
                return man==='mast'?'antenna-mast':'communication-tower';
            }
            if (structure.includes('lattice')) return 'lattice-tower';
            return man==='mast'?'antenna-mast':'lattice-tower';
        }
        if (!Object.hasOwn(types,type) && !['COMMUNICATION_TOWER','OBSERVATION_TOWER',
            'COMMUNICATION_MAST'].includes(type)) return null;
        if (type==='OBSERVATION_TOWER') return 'observation-tower';
        if (type==='COMMUNICATION_TOWER') return 'communication-tower';
        if (type==='COMMUNICATION_MAST') return 'antenna-mast';
        if (['POLE','TOWER','MAST'].includes(type) && height!==null &&
            Math.abs(height-SAENTIS.height)<35 && nearbySite(coordinates))
            return 'communication-tower';
        if (type==='POLE' && height!==null && height>=30) return 'antenna-mast';
        if (type==='TOWER' && height!==null && height>=45) return 'communication-tower';
        return types[type]??null;
    }
    function uri(sourceType,heightAgl,osmTags,coordinates) {
        const name=classify(sourceType,heightAgl,osmTags,coordinates);
        return name && catalog.has(name)?`models/obstacles/${name}.glb`:null;
    }
    function rangeFor(heightAgl) {
        return Number.isFinite(heightAgl)&&heightAgl>=80?12000:range;
    }
    // One listener per source, no frame polling or extra terrain queries. Keep
    // the original symbols until a model really is ready, also on load failure.
    function create(C,viewer) {
        const entries = new Map();
        let disposed = false, stopAdded = null, stopRemoved = null;
        function detach(entry) { entry.stopReady?.(); entry.stopError?.(); entry.stopReady=entry.stopError=null; }
        function display(entry,ready,failed=false) {
            entry.marker.point.distanceDisplayCondition = new C.DistanceDisplayCondition(ready ? entry.range : 0,Number.MAX_VALUE);
            entry.stem.polyline.distanceDisplayCondition = new C.DistanceDisplayCondition(ready ? entry.range : 0,Number.MAX_VALUE);
            entry.entity.model.show = !failed;
            viewer.scene.requestRender?.();
        }
        function listen() {
        if (stopAdded) return;
        stopAdded = viewer.scene.primitives?.primitiveAdded?.addEventListener(primitive => {
            const entry = entries.get(primitive.id?.id);
            if (!entry || disposed) return;
            detach(entry); entry.primitive = primitive;
            const showModel = ready => {
                if (disposed || !entries.has(entry.entity.id) || entry.primitive !== primitive) return;
                display(entry,ready,!ready);
            };
            entry.stopReady = primitive.readyEvent.addEventListener(() => showModel(true));
            entry.stopError = primitive.errorEvent.addEventListener(() => showModel(false));
            if (primitive.ready) showModel(true);
        });
        stopRemoved = viewer.scene.primitives?.primitiveRemoved?.addEventListener(primitive => {
            const entry=entries.get(primitive.id?.id);
            if (!entry || entry.primitive !== primitive || disposed) return;
            detach(entry); entry.primitive=null; display(entry,false);
        });
        }
        return {
            add(sourceType,agl,position,source,marker,stem,osmTags={},coordinates=null) {
                const asset = uri(sourceType,agl,osmTags,coordinates);
                if (!asset) return null;
                listen();
                const visibleRange=rangeFor(agl);
                const entity = source.entities.add({position,show:false,model:{uri:asset,
                    scale:agl,minimumPixelSize:0,maximumScale:agl,
                    enableVerticalExaggeration:false,heightReference:C.HeightReference.NONE,
                    runAnimations:false,shadows:C.ShadowMode.DISABLED,
                    distanceDisplayCondition:new C.DistanceDisplayCondition(0,visibleRange)}});
                entries.set(entity.id,{entity,marker,stem,range:visibleRange});
                return entity;
            },
            remove(entity) {
                const entry=entries.get(entity.id);
                if (entry) { detach(entry); entries.delete(entity.id); }
                if (!entries.size) { stopAdded?.(); stopRemoved?.(); stopAdded=stopRemoved=null; }
            },
            dispose() {
                disposed = true; stopAdded?.(); stopRemoved?.();
                for (const e of entries.values()) detach(e);
                entries.clear();
            }
        };
    }
    return {uri,classify,create,range,rangeFor,nearbySite};
});
