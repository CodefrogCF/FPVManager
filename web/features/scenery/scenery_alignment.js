// Georeferenced, local-only scenery preview transforms. No network or persistence.
(function (root, factory) {
    const api = factory();
    if (typeof module === 'object' && module.exports) module.exports = api;
    else root.FPVSceneryAlignment = api;
})(typeof globalThis !== 'undefined' ? globalThis : this, function () {
    'use strict';

    const STORAGE_KEY = 'fpvmanager.scenery.ruedersdorf.alignment.v1';
    const DEFAULT = Object.freeze({
        schemaVersion: 1,
        longitude: 13.789789,
        latitude: 52.484197,
        ellipsoidHeightM: 0,
        scale: 10,
        rotationDeg: 0,
        opacity: 0.62
    });
    const limits = Object.freeze({
        longitude: [-180, 180], latitude: [-90, 90],
        ellipsoidHeightM: [-10000, 20000], scale: [0.01, 1000],
        rotationDeg: [-360, 360], opacity: [0.02, 1]
    });

    function normalize(input = DEFAULT) {
        if (!input || typeof input !== 'object' || Array.isArray(input)) throw Error('Invalid scenery alignment');
        if (input.schemaVersion !== undefined && input.schemaVersion !== 1) throw Error('Unsupported scenery alignment version');
        const config = {schemaVersion: 1};
        for (const [key, [min, max]] of Object.entries(limits)) {
            const value = input[key] === undefined ? DEFAULT[key] : input[key];
            if (typeof value !== 'number' || !Number.isFinite(value) || value < min || value > max)
                throw Error(`Invalid scenery alignment ${key}`);
            config[key] = value;
        }
        for(const [key,limit] of [['pitchDeg',90],['rollDeg',180]])if(Object.hasOwn(input,key)){
            if(!Number.isFinite(input[key])||Math.abs(input[key])>limit)throw Error('Invalid scenery '+key);
            config[key]=input[key];
        }
        return config;
    }

    // Cesium HPR convention: negative Z heading, negative Y pitch, positive X
    // roll. Shared by visual and CPU collision geometry.
    function rotationMatrix(input){
        const a=normalize(input),rad=Math.PI/180,h=-a.rotationDeg*rad,
            p=-(a.pitchDeg??0)*rad,r=(a.rollDeg??0)*rad,
            ch=Math.cos(h),sh=Math.sin(h),cp=Math.cos(p),sp=Math.sin(p),cr=Math.cos(r),sr=Math.sin(r);
        return [ch*cp,ch*sp*sr-sh*cr,ch*sp*cr+sh*sr,
            sh*cp,sh*sp*sr+ch*cr,sh*sp*cr-ch*sr,-sp,cp*sr,cp*cr];
    }

    // Positive degrees: clockwise around the local ENU up axis. Model rotation
    // is independent of glTF up-axis correction handled by Cesium's Model.
    function modelMatrix(Cesium, input) {
        const value = normalize(input);
        const origin = Cesium.Cartesian3.fromDegrees(value.longitude, value.latitude, value.ellipsoidHeightM);
        const enu = Cesium.Transforms.eastNorthUpToFixedFrame(origin);
        const rotation = Cesium.Matrix4.fromRotationTranslation(
            value.pitchDeg||value.rollDeg?Cesium.Matrix3.fromRowMajorArray(rotationMatrix(value)):
                Cesium.Matrix3.fromRotationZ(-Cesium.Math.toRadians(value.rotationDeg)));
        return Cesium.Matrix4.multiply(enu, rotation, new Cesium.Matrix4());
    }

    function apply(Cesium, model, input) {
        const value = normalize(input);
        model.modelMatrix = modelMatrix(Cesium, value);
        model.scale = value.scale;
        model.color = new Cesium.Color(1, 1, 1, value.opacity);
        return value;
    }

    // Compose an ECEF correction with an ENU model without changing its assets.
    // This keeps local visuals and CPU collision meshes together in mixed scenes.
    function transformed(C,input,correction){
        const a=normalize(input),source=C.Matrix4.multiplyByUniformScale(modelMatrix(C,a),a.scale,new C.Matrix4()),m=C.Matrix4.multiply(correction,source,new C.Matrix4());
        const position=C.Matrix4.getTranslation(m,new C.Cartesian3()),cart=C.Cartographic.fromCartesian(position),scale=C.Matrix4.getMaximumScale(m);
        if(!cart||!Number.isFinite(scale)||scale<=0)throw Error('Invalid scenery correction');
        const enu=C.Transforms.eastNorthUpToFixedFrame(position),world=C.Matrix3.multiplyByScalar(C.Matrix4.getMatrix3(m,new C.Matrix3()),1/scale,new C.Matrix3()),rotation=C.Matrix3.multiply(C.Matrix3.transpose(C.Matrix4.getMatrix3(enu,new C.Matrix3()),new C.Matrix3()),world,new C.Matrix3()),hpr=C.HeadingPitchRoll.fromQuaternion(C.Quaternion.fromRotationMatrix(rotation));
        return normalize({...a,longitude:C.Math.toDegrees(cart.longitude),latitude:C.Math.toDegrees(cart.latitude),ellipsoidHeightM:cart.height,scale,rotationDeg:C.Math.toDegrees(hpr.heading),pitchDeg:C.Math.toDegrees(hpr.pitch),rollDeg:C.Math.toDegrees(hpr.roll)});
    }

    function exportDocument(input) {
        const alignment = normalize(input);
        return {
            ...alignment,
            description: 'Experimental visual alignment; not surveyed or terrain calibrated',
            asset: 'local_reference.glb',
            source: 'Andrea Spognetta (spogna), Abandoned Chemical plant Ruedersdorf – RAWscan',
            originalUrl: 'https://sketchfab.com/3d-models/abandoned-chemical-plant-rudersdorf-rawscan-d2464ec36fb644f28e904e5517f1da64',
            license: 'CC BY-NC',
            heightDatum: 'WGS84 ellipsoid',
            surveyVerified: false,
            physicalCollisionsEnabled: false
        };
    }

    // Approximate meter nudges are for visual editing, not geodetic surveying.
    function nudge(input, eastM = 0, northM = 0) {
        const cfg = normalize(input);
        const cos = Math.cos(cfg.latitude * Math.PI / 180);
        if (Math.abs(cos) < 0.0001) throw Error('Longitude nudge too close to a pole');
        return normalize({...cfg,
            latitude: cfg.latitude + northM / 111320,
            longitude: cfg.longitude + eastM / (111320 * cos)
        });
    }

    // Local tangent-plane approximation, using WGS84 curvature at the anchor.
    // Intended only for compact scenery sites, not survey-grade geodesy.
    function metric(anchor) {
        const rad=anchor.latitude*Math.PI/180, a=6378137, e2=0.00669437999014;
        const w=Math.sqrt(1-e2*Math.sin(rad)**2);
        const east=a/w*Math.cos(rad)*Math.PI/180, north=a*(1-e2)/w**3*Math.PI/180;
        if(Math.abs(east)<100)throw Error('Control points too close to pole');
        return {east,north};
    }
    function offset(anchor,east,north) {
        const m=metric(anchor);
        const longitude=anchor.longitude+east/m.east;return {longitude:longitude>=-180&&longitude<=180?longitude:((longitude+540)%360)-180,latitude:anchor.latitude+north/m.north};
    }
    function localPoint(anchor,p) {
        const m=metric(anchor);
        return {x:((p.longitude-anchor.longitude+540)%360-180)*m.east,y:(p.latitude-anchor.latitude)*m.north};
    }
    // Source points are unscaled model EN coordinates (after glTF up-axis
    // conversion); target points are corresponding WGS84 ground positions.
    function fitControlPoints(input,pairs) {
        const cfg=normalize(input);
        if(!Array.isArray(pairs)||pairs.length<3||pairs.length>64)throw Error('Use 3–64 control point pairs');
        const points=pairs.map(({source,target})=>{
            if(!source||!target||![source.x,source.y,target.longitude,target.latitude].every(Number.isFinite)||
                Math.abs(source.x)>1e5||Math.abs(source.y)>1e5||Math.abs(target.longitude)>180||Math.abs(target.latitude)>90)throw Error('Invalid control point');
            const t=localPoint(cfg,target);
            if(Math.hypot(t.x,t.y)>10000)throw Error('Control points must be near the scenery');
            return {x:source.x,y:source.y,u:t.x,v:t.y};
        });
        const mean=k=>points.reduce((sum,p)=>sum+p[k],0)/points.length;
        const x=mean('x'),y=mean('y'),u=mean('u'),v=mean('v');
        let d=0,a=0,b=0,xx=0,yy=0,xy=0;
        for(const p of points){const X=p.x-x,Y=p.y-y,U=p.u-u,V=p.v-v;
            d+=X*X+Y*Y;a+=X*U+Y*V;b+=X*V-Y*U;xx+=X*X;yy+=Y*Y;xy+=X*Y;}
        if(d<1e-8||(xx*yy-xy*xy)/(d*d)<1e-5)throw Error('Spread control points across the site (not collinear)');
        a/=d;b/=d;
        const scale=Math.hypot(a,b),tx=u-a*x+b*y,ty=v-b*x-a*y;
        const residualsM=points.map(p=>Math.hypot(a*p.x-b*p.y+tx-p.u,b*p.x+a*p.y+ty-p.v));
        return {alignment:normalize({...cfg,...offset(cfg,tx,ty),scale,rotationDeg:-Math.atan2(b,a)*180/Math.PI}),
            residualsM,rmsM:Math.sqrt(residualsM.reduce((sum,r)=>sum+r*r,0)/points.length),maxM:Math.max(...residualsM)};
    }
    // Regions are explicit geographic polygons (not the entire bounding sphere).
    // Reject self intersections and keep edits local to the configured site.
    function normalizeRegions(value,anchor) {
        if(value===undefined)return [];
        if(!Array.isArray(value)||value.length>24)throw Error('Invalid replacement regions');
        return value.map(poly=>{
            if(!Array.isArray(poly)||poly.length<3||poly.length>64)throw Error('Use 3–64 vertices per region');
            const pts=poly.map(p=>{
                if(!Array.isArray(p)||p.length!==2||!p.every(Number.isFinite)||Math.abs(p[0])>180||Math.abs(p[1])>90)throw Error('Invalid region coordinate');
                const local=localPoint(anchor,{longitude:p[0],latitude:p[1]});
                if(Math.hypot(local.x,local.y)>1000)throw Error('Replacement region exceeds 1 km from anchor');
                return local;
            });
            const cross=(a,b,c)=>(b.x-a.x)*(c.y-a.y)-(b.y-a.y)*(c.x-a.x);
            const n=pts.length;
            let area=0;
            for(let i=0;i<n;i++){
                const a=pts[i],b=pts[(i+1)%n];area+=a.x*b.y-a.y*b.x;
                if(Math.hypot(a.x-b.x,a.y-b.y)<0.1)throw Error('Duplicate or adjacent region vertices too close');
                for(let j=i+2;j<n;j++){
                    if(i===0&&j===n-1)continue;
                    const c=pts[j],d=pts[(j+1)%n];
                    const overlap=Math.max(Math.min(a.x,b.x),Math.min(c.x,d.x))<=Math.min(Math.max(a.x,b.x),Math.max(c.x,d.x))&&Math.max(Math.min(a.y,b.y),Math.min(c.y,d.y))<=Math.min(Math.max(a.y,b.y),Math.max(c.y,d.y));
                    if(overlap&&cross(a,b,c)*cross(a,b,d)<=0&&cross(c,d,a)*cross(c,d,b)<=0)throw Error('Self-intersecting region');
                }
            }
            if(Math.abs(area)<2||Math.abs(area)>500000)throw Error('Invalid region area');
            // Cesium accepts either winding; use counter-clockwise consistently.
            return (area<0?[...poly].reverse():poly).map(p=>[...p]);
        });
    }
    function projectFootprint(points,alignment){
        const cfg=normalize(alignment),angle=-cfg.rotationDeg*Math.PI/180;
        if(!Array.isArray(points)||points.length<3||points.length>64)throw Error('Invalid model-local footprint');
        const polygon=points.map(p=>{
            if(!Array.isArray(p)||p.length!==2||!p.every(Number.isFinite))throw Error('Invalid model-local footprint vertex');
            const [x,y]=p, pos=offset(cfg,cfg.scale*(Math.cos(angle)*x-Math.sin(angle)*y),cfg.scale*(Math.sin(angle)*x+Math.cos(angle)*y));
            return [pos.longitude,pos.latitude];
        });return normalizeRegions([polygon],cfg)[0];
    }
    function normalizeEdit(value,base) {
        if(!value||typeof value!=='object'||Array.isArray(value)||!value.alignment||typeof value.alignment!=='object'||Array.isArray(value.alignment))throw Error('Invalid scenery edit');
        const alignment=normalize({...base,...value.alignment});
        const heightOffsetM=value.heightOffsetM??0;
        if(!Number.isFinite(heightOffsetM)||Math.abs(heightOffsetM)>20)throw Error('Height fine adjustment must be within ±20 m');
        const bkgHeightOffsetM=value.bkgHeightOffsetM??0;
        if(!Number.isFinite(bkgHeightOffsetM)||Math.abs(bkgHeightOffsetM)>60)throw Error('BKG height correction must be within ±60 m');
        normalize({...alignment,ellipsoidHeightM:alignment.ellipsoidHeightM+heightOffsetM});
        if(value.replaceBuildings!==undefined&&typeof value.replaceBuildings!=='boolean')throw Error('Invalid building replacement switch');
        if(value.clipTerrain!==undefined&&typeof value.clipTerrain!=='boolean')throw Error('Invalid terrain replacement switch');
        return {alignment,heightOffsetM,bkgHeightOffsetM,buildingRegions:normalizeRegions(value.buildingRegions,alignment),terrainRegions:normalizeRegions(value.terrainRegions,alignment),replaceBuildings:value.replaceBuildings===true,clipTerrain:value.clipTerrain===true};
    }
    return {DEFAULT, STORAGE_KEY, normalize, rotationMatrix, modelMatrix, apply, transformed, exportDocument, nudge,fitControlPoints,localPoint,offset,normalizeRegions,normalizeEdit,projectFootprint};
});
