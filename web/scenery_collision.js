// Static, texture-free local-space collider. No GPU reads or network in sweeps.
(function(root,factory){const api=factory(typeof module==='object'&&module.exports?require('./scene_environment.js').FPVTunnelFlythrough:root.FPVTunnelFlythrough);if(typeof module==='object'&&module.exports)module.exports=api;else root.FPVSceneryCollision=api;})(globalThis,function(T){
    'use strict';
    const maxBytes=64*1024*1024;
    const sub=(a,b)=>a.map((v,i)=>v-b[i]),dot=(a,b)=>a.reduce((s,v,i)=>s+v*b[i],0);
    const cross=(a,b)=>[a[1]*b[2]-a[2]*b[1],a[2]*b[0]-a[0]*b[2],a[0]*b[1]-a[1]*b[0]];
    const lerp=(a,b,t)=>a.map((v,i)=>v+(b[i]-v)*t);
    function parse(buffer){
        if(!(buffer instanceof ArrayBuffer)||buffer.byteLength<16||buffer.byteLength>maxBytes)throw Error('Invalid collision asset size');
        const h=new DataView(buffer),v=h.getUint32(4,true),t=h.getUint32(8,true),n=h.getUint32(12,true);
        if(h.getUint32(0,true)!==0x31435046||!v||v>2000000||!t||t>2000000||!n||n>2*t||16+12*v+12*t+32*n!==buffer.byteLength)throw Error('Invalid FPC1 header');
        const vertices=new Float32Array(buffer,16,3*v),indices=new Uint32Array(buffer,16+12*v,3*t),bounds=new Float32Array(buffer,16+12*v+12*t,6*n),children=new Int32Array(buffer,16+12*v+12*t+24*n,2*n);
        for(const x of vertices)if(!Number.isFinite(x)||Math.abs(x)>1e5)throw Error('Invalid vertex');
        for(const x of indices)if(x>=v)throw Error('Invalid triangle index');
        // Validate the tree, contiguous leaf coverage and actual triangle bounds.
        let nextNode=0,nextTriangle=0;
        function visit(i,parent,depth){
            if(i!==nextNode++||i>=n||depth>48)throw Error('Invalid BVH topology');
            const b=i*6;
            for(let j=0;j<3;j++)if(!Number.isFinite(bounds[b+j])||!Number.isFinite(bounds[b+j+3])||bounds[b+j]>bounds[b+j+3]||(parent>=0&&(bounds[b+j]<bounds[parent+j]||bounds[b+j+3]>bounds[parent+j+3])))throw Error('Invalid BVH bounds');
            const l=children[2*i],r=children[2*i+1];
            if(l<0){const start=-l-1;if(start!==nextTriangle||r<1||r>16||start+r>t)throw Error('Invalid BVH leaf');
                nextTriangle+=r;
                for(let k=3*start;k<3*(start+r);k++)for(let j=0;j<3;j++){const x=vertices[3*indices[k]+j];if(x<bounds[b+j]||x>bounds[b+j+3])throw Error('Triangle outside BVH leaf');}
            }else{visit(l,b,depth+1);visit(r,b,depth+1);}
        }
        visit(0,-1,0);if(nextNode!==n||nextTriangle!==t)throw Error('Incomplete BVH');
        return {vertices,indices,bounds,children,triangleCount:t,nodeCount:n,byteLength:buffer.byteLength};
    }
    async function load(url,signal){
        const r=await fetch(url,{signal,cache:'no-store'});if(!r.ok)throw Error('Collision asset HTTP '+r.status);
        if(Number(r.headers.get('content-length'))>maxBytes)throw Error('Collision asset exceeds size limit');
        // Local assets only; stream cap also covers missing Content-Length.
        if(!r.body?.getReader)return parse(await r.arrayBuffer());
        const reader=r.body.getReader(),chunks=[];let size=0;
        try{for(;;){const {value,done}=await reader.read();if(done)break;size+=value.byteLength;if(size>maxBytes){await reader.cancel();throw Error('Collision asset exceeds size limit');}chunks.push(value);}}
        finally{reader.releaseLock();}
        const data=new Uint8Array(size);let off=0;for(const c of chunks){data.set(c,off);off+=c.length;}return parse(data.buffer);
    }
    function triangle(mesh,i){return [0,1,2].map(j=>{const k=mesh.indices[i*3+j]*3;return [mesh.vertices[k],mesh.vertices[k+1],mesh.vertices[k+2]];});}
    function faceNormal(p,q,tri,radius,fraction){
        const [a,b,c]=tri;let n=cross(sub(b,a),sub(c,a));const len=Math.hypot(...n);if(len<1e-12||fraction===0)return null;n=n.map(x=>x/len);
        const center=lerp(p,q,fraction),d=dot(sub(center,a),n);
        // Edge/corner contacts may have a different normal: use hard stop.
        if(Math.abs(Math.abs(d)-radius)>Math.max(1e-6,radius*.02))return null;
        const contact=center.map((x,i)=>x-d*n[i]);
        for(const [u,v] of [[a,b],[b,c],[c,a]])if(dot(cross(sub(v,u),sub(contact,u)),n)<-1e-9)return null;
        n=n.map(x=>x*Math.sign(d));return dot(n,sub(q,p))<0?n:null;
    }
    function sweep(mesh,p,q,radius){
        if(!mesh||![...p,...q,radius].every(Number.isFinite)||radius<=0)return null;
        const r2=radius*radius,stack=[0];let best=null,fraction=1;
        while(stack.length){const i=stack.pop(),b=i*6,end=lerp(p,q,fraction);let overlap=true;
            for(let j=0;j<3;j++)if(Math.max(p[j],end[j])+radius<mesh.bounds[b+j]||Math.min(p[j],end[j])-radius>mesh.bounds[b+j+3]){overlap=false;break;}
            if(!overlap)continue;
            const l=mesh.children[2*i],r=mesh.children[2*i+1];if(l>=0){stack.push(r,l);continue;}
            for(let k=-l-1;k<-l-1+r;k++){
                const tri=triangle(mesh,k);
                if(!T.sweptSphereHitsTriangle(p,lerp(p,q,fraction),tri,r2))continue;
                let lo=0,hi=fraction;
                if(T.sweptSphereHitsTriangle(p,p,tri,r2))hi=0;
                else for(let step=0;step<16;step++){const mid=(lo+hi)/2;if(T.sweptSphereHitsTriangle(p,lerp(p,q,mid),tri,r2))hi=mid;else lo=mid;}
                fraction=hi;best={fraction:hi,normal:faceNormal(p,q,tri,radius,hi),triangle:k};if(hi===0)return best;
            }
        }
        return best;
    }
    // Same WGS84 local ENU transform as scenery_alignment.modelMatrix,
    // including clockwise heading and the Cesium model's uniform scale.
    const rad=Math.PI/180;
    function ecef(lon,lat,h){const x=lon*rad,y=lat*rad,s=Math.sin(y),c=Math.cos(y),n=6378137/Math.sqrt(1-.0066943799901413165*s*s);return [(n+h)*c*Math.cos(x),(n+h)*c*Math.sin(x),(n*(1-.0066943799901413165)+h)*s];}
    function transform(a){const lon=a.longitude*rad,lat=a.latitude*rad,h=a.rotationDeg*rad,c=Math.cos(h),s=Math.sin(h),origin=ecef(a.longitude,a.latitude,a.ellipsoidHeightM);
        const east=[-Math.sin(lon),Math.cos(lon),0],north=[-Math.sin(lat)*Math.cos(lon),-Math.sin(lat)*Math.sin(lon),Math.cos(lat)],up=[Math.cos(lat)*Math.cos(lon),Math.cos(lat)*Math.sin(lon),Math.sin(lat)];
        return {local(p){const d=sub(ecef(p.longitude,p.latitude,p.height),origin),e=dot(d,east),n=dot(d,north);return [(c*e-s*n)/a.scale,(s*e+c*n)/a.scale,dot(d,up)/a.scale];},normal(n){return n?{east:c*n[0]+s*n[1],north:-s*n[0]+c*n[1],up:n[2]}:null;},scale:a.scale};
    }
    function contact(mesh,frame,from,to,radius=.25){const hit=sweep(mesh,frame.local(from),frame.local(to),radius/frame.scale);return hit?{kind:'scenery',fraction:hit.fraction,normal:frame.normal(hit.normal),triangle:hit.triangle}:false;}
    return {parse,load,sweep,transform,contact,maxBytes};
});
