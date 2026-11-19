(function (root, factory) {
    const api = factory();
    if (typeof module === 'object' && module.exports) module.exports = api;
    else root.FPVSignalAnalysis = api;
})(typeof globalThis !== 'undefined' ? globalThis : this, function () {
    'use strict';
    const states = ['unknown', 'obstructed', 'fresnelIntrusion', 'noSampledObstruction'];
    function point(p, allowNull = false) {
        if (!p || !Number.isFinite(p.latitude) || Math.abs(p.latitude) > 90 ||
            !Number.isFinite(p.longitude) || Math.abs(p.longitude) > 180 ||
            !(allowNull && p.height === null) && (!Number.isFinite(p.height) || Math.abs(p.height) > 100000)) throw new Error('Invalid signal position');
    }
    function validate(command) {
        if (!Array.isArray(command.rays) || command.rays.length > 128) throw new Error('Invalid radio path count');
        if (!command.rays.length) return;
        point(command.pilot);
        if (!Number.isFinite(command.frequencyMhz) || command.frequencyMhz < 10 || command.frequencyMhz > 100000 ||
            !Number.isFinite(command.fraction) || command.fraction < 0 || command.fraction > 1 ||
            !Number.isInteger(command.selected) || command.selected < 0 || command.selected >= command.rays.length ||
            (command.targetOffset !== undefined && (!Number.isInteger(command.targetOffset) || command.targetOffset < 0 ||
                command.targetOffset + command.rays.length > 4096))) throw new Error('Invalid Fresnel configuration');
        if (command.showPilot !== undefined && typeof command.showPilot !== 'boolean') throw Error('Invalid ground station display');
        if (command.showTargetMarkers !== undefined && typeof command.showTargetMarkers !== 'boolean') throw Error('Invalid target marker visibility');
        for (const ray of command.rays) {
            point(ray, true);
            if (!states.includes(ray.state) || !Number.isFinite(ray.ground) || Math.abs(ray.ground) > 100000 ||
                (ray.height === null && ray.state !== 'unknown')) throw new Error('Invalid radio path state');
        }
    }
    function createLayer(Cesium, viewer, {name='Geometric radio analysis'}={}) {
        let source = null, stationSource = null;
        // Separate from the ephemeral Fresnel/ray visualization. A ground
        // station remains visible when sampled LOS is unknown or expires.
        function setStation(position) {
            if (position !== null) {
                if (!position || !Number.isFinite(position.latitude) || Math.abs(position.latitude) > 90 ||
                    !Number.isFinite(position.longitude) || Math.abs(position.longitude) > 180) throw Error('Invalid ground station');
            }
            if (stationSource) viewer.dataSources.remove(stationSource, true);
            stationSource = null;
            if (position) {
                stationSource = new Cesium.CustomDataSource('Simulated ground station');
                stationSource.entities.add({id:'live-radio-ground-station', name:'Ground station (simulated)',
                    position:Cesium.Cartesian3.fromDegrees(position.longitude, position.latitude),
                    point:{pixelSize:12, color:Cesium.Color.YELLOW,
                        heightReference:Cesium.HeightReference?.CLAMP_TO_GROUND,
                        disableDepthTestDistance:Number.POSITIVE_INFINITY}});
                viewer.dataSources.add(stationSource);
            }
            viewer.scene.requestRender();
        }
        function clear() { if (source) viewer.dataSources.remove(source, true); source = null; viewer.scene.requestRender(); }
        function set(command) {
            validate(command);
            if (!command.rays.length) { clear(); return {}; }
            if(command.obstruction)point(command.obstruction);
            const replacement = new Cesium.CustomDataSource(name);
            replacement.fpvVisualOnly = true;
            const C = Cesium.Cartesian3;
            const pilot = C.fromDegrees(command.pilot.longitude, command.pilot.latitude, command.pilot.height);
            if (command.showPilot !== false) replacement.entities.add({id:'signal-pilot', name:'Pilot antenna', position:pilot, point:{pixelSize:12, color:Cesium.Color.YELLOW}});
            if(command.obstruction)replacement.entities.add({id:'signal-obstruction',name:'Potential sampled obstruction',
                position:C.fromDegrees(command.obstruction.longitude,command.obstruction.latitude,command.obstruction.height),point:{pixelSize:12,color:Cesium.Color.ORANGE,disableDepthTestDistance:Number.POSITIVE_INFINITY}});
            const colors = [Cesium.Color.GRAY, Cesium.Color.ORANGE, Cesium.Color.MEDIUMPURPLE, Cesium.Color.CYAN];
            command.rays.forEach((ray, index) => {
                const color = colors[states.indexOf(ray.state)], target = C.fromDegrees(ray.longitude, ray.latitude, ray.height ?? ray.ground);
                if(command.showTargetMarkers!==false)replacement.entities.add({id:`signal-target-${index}`, name:`Radio target ${(command.targetOffset ?? 0) + index + 1}: ${ray.state}`, position:target, point:{pixelSize: index === command.selected ? 12 : 7, color}});
                if (ray.height === null || ray.state === 'unknown') return;
                replacement.entities.add({id:`signal-ray-${index}`, properties:{fpvNonCollidable:true}, polyline:{positions:[pilot, target], width: index === command.selected ? 4 : 1, material:color.withAlpha(index === command.selected ? 1 : .35), arcType:Cesium.ArcType.NONE}});
                if (index !== command.selected) return;
                const delta = C.subtract(target, pilot, new C()), length = C.magnitude(delta);
                if (length < 1) return;
                const direction = C.normalize(delta, new C());
                const axis = Math.abs(C.dot(direction, C.UNIT_Z)) > .9 ? C.UNIT_X : C.UNIT_Z;
                const u = C.normalize(C.cross(direction, axis, new C()), new C()), v = C.cross(direction, u, new C());
                function envelope(t, angle) {
                    const radius = Math.sqrt(299792458 / (command.frequencyMhz * 1e6) * length * t * (1 - t)) * command.fraction;
                    const center = C.lerp(pilot, target, t, new C());
                    return C.add(center, C.add(C.multiplyByScalar(u, radius * Math.cos(angle), new C()), C.multiplyByScalar(v, radius * Math.sin(angle), new C()), new C()), new C());
                }
                const material = Cesium.Color.MEDIUMPURPLE.withAlpha(.65);
                for (let edge = 0; edge < 4; edge++) replacement.entities.add({id:`signal-envelope-${edge}`, properties:{fpvNonCollidable:true}, polyline:{positions:Array.from({length:65}, (_,i) => envelope(i / 64, edge * Math.PI / 2)), width:1, material, arcType:Cesium.ArcType.NONE}});
                for (const [i,t] of [.25,.5,.75].entries()) replacement.entities.add({id:`signal-ring-${i}`, properties:{fpvNonCollidable:true}, polyline:{positions:Array.from({length:33}, (_,n) => envelope(t, n * Math.PI / 16)), width:1, material, arcType:Cesium.ArcType.NONE}});
            });
            clear(); source = replacement; viewer.dataSources.add(source); viewer.scene.requestRender(); return {};
        }
        return {set, clear, setStation, dispose(){ clear(); setStation(null); }};
    }
    return {validate, createLayer};
});
