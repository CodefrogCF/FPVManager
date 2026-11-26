// Editor coordinates are post-glTF-axis-conversion local ENU metres.
(function(root,factory){const api=factory(typeof module==='object'&&module.exports?require('./scenery_alignment.js'):root.FPVSceneryAlignment,typeof module==='object'&&module.exports?require('./scenery_tileset_provider.js'):root.FPVSceneryTilesets);if(typeof module==='object'&&module.exports)module.exports=api;else root.FPVSceneryEditorMath=api;})(typeof globalThis!=='undefined'?globalThis:this,function(A,T){
    'use strict';
    const clone=v=>JSON.parse(JSON.stringify(v));
    function normalize(v){return A.normalize({...v,pitchDeg:v.pitchDeg??0,rollDeg:v.rollDeg??0});}
    function xyz(C,p){return C.Cartesian3.fromDegrees(p.longitude,p.latitude,p.ellipsoidHeightM??p.heightM);}
    function geographic(C,p){const c=C.Cartographic.fromCartesian(p);if(!c)throw Error('Position is not on Earth');return {longitude:C.Math.toDegrees(c.longitude),latitude:C.Math.toDegrees(c.latitude),ellipsoidHeightM:c.height};}
    function frame(C,p){return C.Transforms.eastNorthUpToFixedFrame(xyz(C,p));}
    function matrix(C,v){return C.Matrix4.multiplyByUniformScale(A.modelMatrix(C,v),v.scale,new C.Matrix4());}
    function point(C,v,local){return C.Matrix4.multiplyByPoint(matrix(C,v),new C.Cartesian3(local.x,local.y,local.z??0),new C.Cartesian3());}
    function local(C,v,world){const p=C.Matrix4.multiplyByPoint(C.Matrix4.inverse(matrix(C,v),new C.Matrix4()),world,new C.Cartesian3());return {x:p.x,y:p.y,z:p.z};}
    function translate(C,v,east,north,up){const m=frame(C,v),p=C.Matrix4.multiplyByPoint(m,new C.Cartesian3(east,north,up),new C.Cartesian3());return normalize({...v,...geographic(C,p)});}
    function hpr(C,m){const q=C.Quaternion.fromRotationMatrix(m);const h=C.HeadingPitchRoll.fromQuaternion(q);return {rotationDeg:C.Math.toDegrees(h.heading),pitchDeg:C.Math.toDegrees(h.pitch),rollDeg:C.Math.toDegrees(h.roll)};}
    function initial(C,doc,effective){const remote=doc.assets.find(a=>a.provider==='remote-tiles');if(!remote)return normalize({...effective,opacity:doc.extensions?.cesium?.alignment?.opacity??1});
        const pivot={longitude:doc.anchor.longitude,latitude:doc.anchor.latitude,ellipsoidHeightM:doc.anchor.heightM},c=remote.tileset.correction??{},d=T.correctionMatrix(C,pivot,c);
        return normalize({...pivot,...geographic(C,C.Matrix4.multiplyByPoint(d,xyz(C,pivot),new C.Cartesian3())),rotationDeg:c.headingDeg??0,pitchDeg:c.pitchDeg??0,rollDeg:c.rollDeg??0,scale:c.scale??1,opacity:doc.extensions?.cesium?.alignment?.opacity??1});
    }
    function remoteCorrections(C,doc,state){
        const assets=doc.assets.filter(a=>a.provider==='remote-tiles');if(!assets.length)return [];
        const pivot={longitude:doc.anchor.longitude,latitude:doc.anchor.latitude,ellipsoidHeightM:doc.anchor.heightM},enu=frame(C,pivot),inverse=C.Matrix4.inverseTransformation(enu,new C.Matrix4());
        // Rotation is expressed in the source pivot's ENU axes, like #147.
        const target=matrix(C,{...state,...pivot}),rotation=C.Matrix4.getMatrix3(target,new C.Matrix3());
        const desired=C.Matrix4.fromRotationTranslation(rotation,xyz(C,state));C.Matrix4.multiply(desired,inverse,desired);
        const old=T.correctionMatrix(C,pivot,assets[0].tileset.correction),delta=C.Matrix4.multiply(desired,C.Matrix4.inverse(old,new C.Matrix4()),new C.Matrix4());
        return assets.map(asset=>{const d=C.Matrix4.multiply(delta,T.correctionMatrix(C,pivot,asset.tileset.correction),new C.Matrix4()),m=C.Matrix4.multiply(inverse,C.Matrix4.multiply(d,enu,new C.Matrix4()),new C.Matrix4()),s=C.Matrix4.getMaximumScale(m),r=C.Matrix3.multiplyByScalar(C.Matrix4.getMatrix3(m,new C.Matrix3()),1/s,new C.Matrix3()),angles=hpr(C,r),p=C.Matrix4.getTranslation(m,new C.Cartesian3());return {id:asset.id,correction:{eastM:p.x,northM:p.y,upM:p.z,headingDeg:angles.rotationDeg,pitchDeg:angles.pitchDeg,rollDeg:angles.rollDeg,scale:s}};});
    }
    function placement(C,doc,state,reference,relativeHeight){return {alignment:normalize(state),reference,heightM:reference==='TERRAIN_RELATIVE'?relativeHeight:state.ellipsoidHeightM,remoteCorrections:remoteCorrections(C,doc,state)};}
    function residuals(C,alignment,pairs){
        if(!Array.isArray(pairs)||pairs.length<1||pairs.length>64)throw Error('Use 1–64 control point pairs');
        const residualsM=pairs.map(p=>C.Cartesian3.distance(point(C,alignment,p.source),xyz(C,p.target)));
        if(!residualsM.every(Number.isFinite))throw Error('Invalid control point');
        return {residualsM,rmsM:Math.sqrt(residualsM.reduce((n,x)=>n+x*x,0)/pairs.length),maxM:Math.max(...residualsM)};
    }
    function history(value,limit=80){let current=clone(value),past=[],future=[];return {get value(){return clone(current);},get canUndo(){return !!past.length;},get canRedo(){return !!future.length;},set(v){if(JSON.stringify(v)===JSON.stringify(current))return;past.push(current);if(past.length>limit)past.shift();current=clone(v);future=[];},undo(){if(past.length){future.push(current);current=past.pop();}return clone(current);},redo(){if(future.length){past.push(current);current=future.pop();}return clone(current);}};}
    // Jacobi eigenvectors of a symmetric 4x4 matrix (Horn's absolute orientation).
    function eigen(matrix){const a=matrix.map(r=>[...r]),v=Array.from({length:4},(_,i)=>Array.from({length:4},(_,j)=>+(i===j)));
        for(let n=0;n<80;n++){let p=0,q=1;for(let i=0;i<4;i++)for(let j=i+1;j<4;j++)if(Math.abs(a[i][j])>Math.abs(a[p][q])){p=i;q=j;}if(Math.abs(a[p][q])<1e-12)break;
            const angle=.5*Math.atan2(2*a[p][q],a[q][q]-a[p][p]),c=Math.cos(angle),s=Math.sin(angle);
            for(let k=0;k<4;k++){const x=a[k][p],y=a[k][q];a[k][p]=c*x-s*y;a[k][q]=s*x+c*y;const u=v[k][p],w=v[k][q];v[k][p]=c*u-s*w;v[k][q]=s*u+c*w;}
            for(let k=0;k<4;k++){const x=a[p][k],y=a[q][k];a[p][k]=c*x-s*y;a[q][k]=s*x+c*y;}}
        const i=a.map((r,i)=>r[i]).reduce((best,x,i)=>x>a[best][best]?i:best,0);return v.map(row=>row[i]);
    }
    function fit(C,input,pairs){
        const value=normalize(input);if(!Array.isArray(pairs)||pairs.length<3||pairs.length>64)throw Error('Use 3–64 control point pairs');
        const origin=frame(C,value),inv=C.Matrix4.inverseTransformation(origin,new C.Matrix4());
        const points=pairs.map(p=>{if(!p?.source||!p.target||![p.source.x,p.source.y,p.source.z,p.target.longitude,p.target.latitude,p.target.heightM].every(Number.isFinite)||Math.abs(p.target.longitude)>180||Math.abs(p.target.latitude)>90||Math.max(...Object.values(p.source).map(Math.abs))>1e5)throw Error('Invalid control point');const t=C.Matrix4.multiplyByPoint(inv,xyz(C,p.target),new C.Cartesian3());if(C.Cartesian3.magnitude(t)>10000)throw Error('Control points must be within 10 km of the anchor');return {s:new C.Cartesian3(p.source.x,p.source.y,p.source.z),t};});
        const mean=k=>C.Cartesian3.divideByScalar(points.reduce((a,p)=>C.Cartesian3.add(a,p[k],a),new C.Cartesian3()),points.length,new C.Cartesian3()),ms=mean('s'),mt=mean('t');
        const centered=points.map(p=>({s:C.Cartesian3.subtract(p.s,ms,new C.Cartesian3()),t:C.Cartesian3.subtract(p.t,mt,new C.Cartesian3())}));
        let variance=0,spread=0;const h=Array.from({length:3},()=>[0,0,0]);
        for(const p of centered){variance+=C.Cartesian3.magnitudeSquared(p.s);for(const q of centered)spread=Math.max(spread,C.Cartesian3.magnitudeSquared(C.Cartesian3.cross(p.s,q.s,new C.Cartesian3())));const s=[p.s.x,p.s.y,p.s.z],t=[p.t.x,p.t.y,p.t.z];for(let i=0;i<3;i++)for(let j=0;j<3;j++)h[i][j]+=s[i]*t[j];}
        if(variance<1e-8||spread/variance**2<1e-7)throw Error('Spread control points across the model; collinear points cannot determine rotation');
        const [[xx,xy,xz],[yx,yy,yz],[zx,zy,zz]]=h,q=eigen([[xx+yy+zz,yz-zy,zx-xz,xy-yx],[yz-zy,xx-yy-zz,xy+yx,zx+xz],[zx-xz,xy+yx,-xx+yy-zz,yz+zy],[xy-yx,zx+xz,yz+zy,-xx-yy+zz]]),r=C.Matrix3.fromQuaternion(C.Quaternion.normalize(new C.Quaternion(q[1],q[2],q[3],q[0]),new C.Quaternion()));
        const scale=centered.reduce((n,p)=>n+C.Cartesian3.dot(p.t,C.Matrix3.multiplyByVector(r,p.s,new C.Cartesian3())),0)/variance;if(!Number.isFinite(scale)||scale<=0)throw Error('Control points do not determine a valid uniform scale');
        const translation=C.Cartesian3.subtract(mt,C.Cartesian3.multiplyByScalar(C.Matrix3.multiplyByVector(r,ms,new C.Cartesian3()),scale,new C.Cartesian3()),new C.Cartesian3()),geo=geographic(C,C.Matrix4.multiplyByPoint(origin,translation,new C.Cartesian3()));
        const worldRotation=C.Matrix3.multiply(C.Matrix4.getMatrix3(origin,new C.Matrix3()),r,new C.Matrix3()),newR=C.Matrix3.multiply(C.Matrix3.transpose(C.Matrix4.getMatrix3(frame(C,geo),new C.Matrix3()),new C.Matrix3()),worldRotation,new C.Matrix3()),alignment=normalize({...value,...geo,...hpr(C,newR),scale});
        const residualsM=points.map(p=>C.Cartesian3.distance(C.Cartesian3.add(C.Cartesian3.multiplyByScalar(C.Matrix3.multiplyByVector(r,p.s,new C.Cartesian3()),scale,new C.Cartesian3()),translation,new C.Cartesian3()),p.t));
        return {alignment,residualsM,rmsM:Math.sqrt(residualsM.reduce((n,x)=>n+x*x,0)/points.length),maxM:Math.max(...residualsM)};
    }
    return {normalize,xyz,geographic,frame,matrix,point,local,translate,initial,placement,remoteCorrections,history,fit,residuals};
});
