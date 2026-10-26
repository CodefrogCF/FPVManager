(function(root,factory) {
    if (typeof module === 'object' && module.exports) module.exports = factory();
    else root.FPVObstacleModels = factory();
})(typeof globalThis !== 'undefined' ? globalThis : this, function() {
    'use strict';
    const types = Object.freeze({TRANSMISSION_LINE:'power-pylon', POLE:'utility-pole',
        MAST:'antenna-mast', TOWER:'lattice-tower', CRANE:'tower-crane', STACK:'chimney',
        WINDMILL:'wind-turbine', CABLE_CAR:'cableway-support', CATENARY:'cableway-support'});
    const range = 6000;
    function uri(sourceType) {
        const type = String(sourceType ?? '').toUpperCase();
        const name = Object.hasOwn(types,type) ? types[type] : null;
        return name ? `models/obstacles/${name}.glb` : null;
    }
    // One listener per source, no frame polling or extra terrain queries. Keep
    // the original symbols until a model really is ready, also on load failure.
    function create(C,viewer) {
        const entries = new Map();
        let disposed = false, stopAdded = null, stopRemoved = null;
        function detach(entry) { entry.stopReady?.(); entry.stopError?.(); entry.stopReady=entry.stopError=null; }
        function display(entry,ready,failed=false) {
            entry.marker.point.distanceDisplayCondition = new C.DistanceDisplayCondition(ready ? range : 0,Number.MAX_VALUE);
            entry.stem.polyline.distanceDisplayCondition = new C.DistanceDisplayCondition(ready ? range : 0,Number.MAX_VALUE);
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
            add(sourceType,agl,position,source,marker,stem) {
                const asset = uri(sourceType);
                if (!asset) return null;
                listen();
                const entity = source.entities.add({position,show:false,model:{uri:asset,
                    scale:agl,minimumPixelSize:0,maximumScale:agl,
                    enableVerticalExaggeration:false,heightReference:C.HeightReference.NONE,
                    runAnimations:false,shadows:C.ShadowMode.DISABLED,
                    distanceDisplayCondition:new C.DistanceDisplayCondition(0,range)}});
                entries.set(entity.id,{entity,marker,stem});
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
    return {uri,create,range};
});
