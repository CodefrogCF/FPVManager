#!/usr/bin/env python3
"""Conservative site-specific refinement for the 2018 CC BY-NC scan. Requires numpy, scipy, Pillow.
Do not use on other scans. Original UVs, triangles, node transform and local Z retained.
"""
import argparse, hashlib, io, json, struct
from pathlib import Path
import numpy as np
from scipy.optimize import least_squares
from scipy.spatial import cKDTree
from PIL import Image, ImageFilter
from build_collision import read_glb, build, AXIS

SCALE=16.023268178233355
ORIGINAL_MD5='c687d665d1e0ee68f69477207941d103'

def smoothstep(x):
    x=np.clip(x,0,1); return x*x*(3-2*x)

def refine(v,t):
    out=v.copy(); stats=[]
    # Scan-local centers, not surveyed positions. Avoid feet, platforms and tops.
    for label,x,y,zmin,zmax,r0,search,cap in [
        ('chimney north-local',-5.43,.69,-1.3,2.08,.17,.27,.12),
        ('chimney south-local',-5.42,-1.97,-1.3,2.00,.17,.27,.12),
        ('outer silo',.015,3.875,-1.48,-.72,.39,.46,.14)]:
        sidx=np.flatnonzero((np.linalg.norm(v[:,:2]-[x,y],axis=1)<search)&(v[:,2]>=zmin)&(v[:,2]<=zmax)); p=v[sidx].astype(float)
        knots=[]; fits=[]
        for z in np.arange(zmin+.1,zmax-.09,.18):
            points=p[np.abs(p[:,2]-z)<.105,:2]
            if len(points)<40: continue
            fit=least_squares(lambda b:np.linalg.norm(points-b[:2],axis=1)-b[2],[x,y,r0],loss='soft_l1',f_scale=.005).x
            d=np.linalg.norm(points-fit[:2],axis=1)-fit[2]
            angle=np.arctan2(points[:,1]-fit[1],points[:,0]-fit[0]); bins=len(np.unique(np.floor((angle+np.pi)*12/np.pi)))
            if bins<22 or np.quantile(abs(d),.9)>.018 or not .6*r0<fit[2]<1.4*r0: continue
            knots.append(z);fits.append(fit)
        if len(knots)<3: raise ValueError('Insufficient reliable ring samples: '+label)
        fits=np.array(fits); q=np.column_stack([np.interp(p[:,2],knots,fits[:,i]) for i in range(3)])
        delta=p[:,:2]-q[:,:2]; radius=np.linalg.norm(delta,axis=1); residual=radius-q[:,2]
        # Smooth transitions and preserve outliers/details instead of pulling them into cylinder.
        weight=smoothstep((p[:,2]-zmin)/.23)*smoothstep((zmax-p[:,2])/.23)*smoothstep((.027-abs(residual))/.014)
        move=np.clip(-residual*.85,-cap/SCALE,cap/SCALE)*weight
        out[sidx,:2]=(p[:,:2]+delta/np.maximum(radius[:,None],1e-9)*move[:,None]).astype(np.float32)
        stats.append((label,sidx,q.copy()))
    # Reject edits of every vertex on any face which flips or nearly collapses.
    def normal(a):
        x,y,z=a[t[:,0]],a[t[:,1]],a[t[:,2]];return np.cross(y-x,z-x)
    old=normal(v); mag=np.linalg.norm(old,axis=1); rejected=0
    for _ in range(30):
        n=normal(out); bad=(np.einsum('ij,ij->i',old,n)<=0)|(np.linalg.norm(n,axis=1)<mag*.3)
        if not bad.any():break
        ids=np.unique(t[bad]); rejected+=int(np.count_nonzero(np.any(out[ids]!=v[ids],axis=1)));out[ids]=v[ids]
    else:raise ValueError('Cannot preserve face orientation')
    reports=[]
    for label,ids,q in stats:
        moved=np.linalg.norm(out[ids]-v[ids],axis=1)>1e-7
        a=np.linalg.norm(v[ids,:2]-q[:,:2],axis=1)-q[:,2];b=np.linalg.norm(out[ids,:2]-q[:,:2],axis=1)-q[:,2]
        reports.append({'region':label,'moved_vertices':int(moved.sum()),'radial_rms_before_m':float(np.sqrt(np.mean(a[moved]**2))*SCALE),'radial_rms_after_m':float(np.sqrt(np.mean(b[moved]**2))*SCALE)})
    return out,reports,rejected

def run(src,dst,col,report,preview_dir):
    raw=Path(src).read_bytes()
    if hashlib.md5(raw).hexdigest()!=ORIGINAL_MD5:raise ValueError('Expected exact original scan')
    v,t=read_glb(src); out,regions,rejected=refine(v,t); tree=cKDTree(v)
    n=struct.unpack_from('<I',raw,12)[0];doc=json.loads(raw[20:20+n]);buf=bytearray(raw[28+n:]);
    # Original GLB has one root matrix, identity descendants and static primitives.
    m=np.asarray(doc['nodes'][0]['matrix']).reshape((4,4),order='F')[:3,:3]; a=AXIS@m
    for mesh in doc['meshes']:
        for p in mesh['primitives']:
            acc=doc['accessors'][p['attributes']['POSITION']]; view=doc['bufferViews'][acc['bufferView']]; off=view.get('byteOffset',0)+acc.get('byteOffset',0)
            pos=np.ndarray((acc['count'],3),dtype='<f4',buffer=buf,offset=off,strides=(view.get('byteStride',12),4))
            world=(pos@m.T@AXIS.T).astype('<f4'); dist,ids=tree.query(world);assert dist.max()<1e-7
            changed=np.any(out[ids]!=v[ids],axis=1); pos[changed]=(out[ids[changed]]@a).astype('<f4')
            acc['min']=pos.min(0).tolist();acc['max']=pos.max(0).tolist()
            del pos
    # Original unlit diffuse atlas: bounded tone correction, mild sharpening (no generated detail).
    imview=doc['bufferViews'][doc['images'][0]['bufferView']]; off=imview['byteOffset']; im=Image.open(io.BytesIO(buf[off:off+imview['byteLength']])).convert('RGB');
    lut=[round(255*(i/255)**.86) for i in range(256)]; enhanced=im.point(lut*3).filter(ImageFilter.UnsharpMask(radius=.8,percent=55,threshold=4));
    preview_dir=Path(preview_dir); preview_dir.mkdir(parents=True,exist_ok=True)
    im.save(preview_dir/'atlas_original.png');enhanced.save(preview_dir/'atlas_refined.png')
    # Lossless embedded PNG; replace original last image buffer view, not append unused JPEG.
    stream=io.BytesIO();enhanced.save(stream,format='PNG'); payload=stream.getvalue();buf=buf[:off]+payload;imview['byteLength']=len(payload);imview['name']='refined_baseColor.png';doc['images'][0]['mimeType']='image/png';doc['buffers'][0]['byteLength']=len(buf);buf+=b'\0'*(-len(buf)%4)
    doc['asset']['extras']['modifications']='FPVManager experimental: bounded shaft/silo radial refinement and tone correction of original atlas; not surveyed; CC BY-NC 4.0.'
    js=json.dumps(doc,separators=(',',':'),ensure_ascii=False).encode();js+=b' '*(-len(js)%4); chunks=struct.pack('<I4s',len(js),b'JSON')+js+struct.pack('<I4s',len(buf),b'BIN\0')+buf;Path(dst).write_bytes(struct.pack('<4sII',b'glTF',2,12+len(chunks))+chunks)
    v2,t2=read_glb(dst); assert len(t2)==len(t);assert np.max(np.abs(v2[t2]-out[t]))<2e-6
    _, keep=np.unique(np.sort(t2,axis=1),axis=0,return_index=True); tclean=t2[np.sort(keep)]; result=build(v2,tclean,col)
    change=np.linalg.norm(out-v,axis=1)*SCALE
    r={'source_md5':ORIGINAL_MD5,'visual_triangles':len(t2),'unique_positions':len(v2),'modified_unique_positions':int(np.count_nonzero(change>1e-6)),'max_displacement_m':float(change.max()),'reverted_vertices_for_face_safety':rejected,'duplicate_collision_faces_removed':int(len(t2)-len(tclean)),'regions':regions,'collision':result,'texture_resolution':list(im.size),'z_unchanged':bool(np.array_equal(v[:,2],out[:,2]))}
    Path(report).write_text(json.dumps(r,indent=2));print(json.dumps(r,indent=2))
    np.savez(preview_dir/'comparison.npz',v=v,out=out)

if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('source');p.add_argument('glb');p.add_argument('fpc');p.add_argument('report');p.add_argument('preview_dir');a=p.parse_args();run(a.source,a.glb,a.fpc,a.report,a.preview_dir)
