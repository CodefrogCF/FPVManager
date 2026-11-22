#!/usr/bin/env python3
"""R13: conservative secondary-roof smoothing, duplicate cleanup and a reference-guided
external stair segment at the west silo. Keeps R12 geography and all existing model parts.
No photographs are embedded. Rebuild the FPC from the produced GLB.
"""
import argparse, hashlib, json, struct, sys
from pathlib import Path
import numpy as np
from scipy.spatial import cKDTree

# Reuses only the modelling helper functions, not the old reconstruction pipeline.
from build_collision import AXIS, read_glb, build
from reconstruct_ruedersdorf_r6 import Mesh, beam

S=16.023268178233355
# Previously identified annex roofs from preserved 2018 scan, never interior/building roofs.
ROOF_PATCHES=[
 ('west stepped annex A',(-5.64,-5.02,1.75,3.52,-1.62),.10),
 ('west stepped annex B',(-4.98,-4.37,1.75,3.52,-1.47),.09),
 ('north outbuilding high',(-1.30,.17,4.58,5.50,-1.40),.09),
 ('north outbuilding low',(.29,.74,4.58,5.42,-1.57),.09),
 ('northwest low roof',(-4.52,-3.77,5.79,6.12,-1.24),.08),
 ('eastern low-roof outbuilding',(2.13,2.59,-.43,.96,-1.55),.06),
]


def get_accessor(doc,buf,i):
 a=doc['accessors'][i];b=doc['bufferViews'][a['bufferView']]
 dtype=np.dtype({5121:'u1',5123:'<u2',5125:'<u4',5126:'<f4'}[a['componentType']])
 width={'SCALAR':1,'VEC3':3,'VEC2':2}[a['type']]
 return np.ndarray((a['count'],width),dtype=dtype,buffer=buf,offset=b.get('byteOffset',0)+a.get('byteOffset',0),strides=(b.get('byteStride',width*dtype.itemsize),dtype.itemsize)).copy()


def prepare_roof_fit(doc,buf):
 # Independent plane fits based on downward/vertical filtered scan faces.
 root=AXIS @ np.asarray(doc['nodes'][0]['matrix']).reshape(4,4,order='F')[:3,:3]
 centers=[];faces=[]
 for mesh in doc['meshes'][:15]:
  for pr in mesh['primitives']:
   v=get_accessor(doc,buf,pr['attributes']['POSITION'])@root.T
   tri=get_accessor(doc,buf,pr['indices']).reshape(-1,3)
   xyz=v[tri];c=xyz.mean(axis=1)
   n=np.cross(xyz[:,1]-xyz[:,0],xyz[:,2]-xyz[:,0]);mag=np.linalg.norm(n,axis=1)
   ok=np.abs(n[:,2])>.75*mag
   centers.append(c[ok])
 pts=np.concatenate(centers)
 fits=[]
 for name,(x0,x1,y0,y1,z),max_cm in ROOF_PATCHES:
  mask=(pts[:,0]>=x0)&(pts[:,0]<=x1)&(pts[:,1]>=y0)&(pts[:,1]<=y1)&(np.abs(pts[:,2]-z)<.1)
  c=pts[mask];A=np.c_[c[:,:2],np.ones(len(c))]
  if len(c)<150:continue
  coeff=np.linalg.lstsq(A,c[:,2],rcond=None)[0]
  rms=float(np.sqrt(np.mean((A@coeff-c[:,2])**2))*S)
  # Only accept a good, nearly planar, well-sampled roof (RMS under 30 cm).
  if rms>.30 or abs(coeff[0])>.18 or abs(coeff[1])>.18:continue
  fits.append((name,(x0,x1,y0,y1,z),np.asarray(coeff),max_cm,rms,len(c)))
 return fits


def repair_original_roofs(doc,buf,report):
 fits=prepare_roof_fit(doc,buf)
 root=AXIS @ np.asarray(doc['nodes'][0]['matrix']).reshape(4,4,order='F')[:3,:3]
 inverse=np.linalg.inv(root)
 moved_all=set();per_patch=[]
 # Each original primitive has a standalone vertex buffer; operate in local space.
 for name,(x0,x1,y0,y1,z0),coeff,max_cm,rms,nfaces in fits:
  moved=0;max_move=0.;res_before=[];res_after=[]
  for mesh in doc['meshes'][:15]:
   for pr in mesh['primitives']:
    idx=pr['attributes']['POSITION'];a=doc['accessors'][idx];bv=doc['bufferViews'][a['bufferView']]
    arr=get_accessor(doc,buf,idx)
    xyz=arr@root.T
    # Band includes only roof-level points, not walls, tanks, doors or mechanical units.
    cand=(xyz[:,0]>x0)&(xyz[:,0]<x1)&(xyz[:,1]>y0)&(xyz[:,1]<y1)&(abs(xyz[:,2]-z0)<.09)
    if not cand.any():continue
    ids=np.flatnonzero(cand)
    p=xyz[ids];pred=p[:,0]*coeff[0]+p[:,1]*coeff[1]+coeff[2]
    residual=pred-p[:,2]
    # Fade to zero over 8 cm local coordinate at selected patch edges.
    edge=np.minimum.reduce([p[:,0]-x0,x1-p[:,0],p[:,1]-y0,y1-p[:,1]])
    w=np.clip(edge/.08,0,1);w=w*w*(3-2*w)
    delta=np.clip(residual*.8,-max_cm/S,max_cm/S)*w
    chosen=np.abs(delta)>1e-7
    if not chosen.any():continue
    p2=p.copy();p2[:,2]+=delta
    # Entire affected triangle normals checked after tentative modification.
    indices=get_accessor(doc,buf,pr['indices']).reshape(-1,3)
    transformed=xyz.copy();transformed[ids]=p2
    hit=np.zeros(len(xyz),bool);hit[ids]=chosen
    affected=np.any(hit[indices],axis=1)
    if affected.any():
     a0=xyz[indices[affected]];a1=transformed[indices[affected]]
     n0=np.cross(a0[:,1]-a0[:,0],a0[:,2]-a0[:,0]);n1=np.cross(a1[:,1]-a1[:,0],a1[:,2]-a1[:,0])
     bad=(np.einsum('ij,ij->i',n0,n1)<=0)|(np.linalg.norm(n1,axis=1)<np.linalg.norm(n0,axis=1)*.3)
     if bad.any():
      unsafe=np.unique(indices[affected][bad]);hit[unsafe]=False
      chosen=hit[ids]
      p2[~chosen]=p[~chosen]
    if not chosen.any():continue
    new_xyz=xyz.copy();new_xyz[ids[chosen]]=p2[chosen]
    local=new_xyz@inverse.T
    # write into buffer, same accessor dimensions, preserve UV data and materials
    if a['componentType']!=5126 or bv.get('byteStride',12)!=12:raise ValueError('Unsupported position stride')
    start=bv.get('byteOffset',0)+a.get('byteOffset',0)
    buf[start:start+arr.nbytes]=local.astype('<f4').tobytes()
    moved+=int(chosen.sum());max_move=max(max_move,float(abs(delta[chosen]).max()*S))
    res_before.extend(np.abs(residual[chosen]).tolist());res_after.extend(np.abs(pred[chosen]-p2[chosen,2]).tolist())
  per_patch.append(dict(name=name,source_faces=nfaces,plane=coeff.tolist(),original_roof_rms_m=rms,vertices_moved=moved,max_displacement_m=max_move,corrected_mean_residual_m=float(np.mean(res_after)*S) if res_after else 0))
 report['roof_refinements']=per_patch
 return report


def external_silo_stair():
 """Approximate a south-facing exposed stair section on the west two-silo block.
 Placement and precise number of steps are NOT surveyed (photo-derived concept).
 """
 m=Mesh();m.part='R13 west-silo exterior access stair'
 center=np.array([-2.1134,2.1267])
 low,high=-1.985,-1.55
 r_inner=.425;r_outer=.505;steps=40
 angles=np.linspace(np.deg2rad(-35),np.deg2rad(-145),steps+1)
 def pos(r,a,z):return (center[0]+r*np.cos(a),center[1]+r*np.sin(a),z)
 for i in range(steps):
  a,b=angles[i:i+2];z0=low+(high-low)*i/steps;z1=low+(high-low)*(i+1)/steps
  # Individual treads separated in vertical dimension and following the exterior curvature.
  m.quad(pos(r_inner,a,z1),pos(r_outer,a,z1),pos(r_outer,b,z1),pos(r_inner,b,z1),'metal')
  m.quad(pos(r_inner,b,z1-.005),pos(r_outer,b,z1-.005),pos(r_outer,a,z1-.005),pos(r_inner,a,z1-.005),'metal')
  for aa in (a,b):
   m.quad(pos(r_inner,aa,z1-.005),pos(r_inner,aa,z1),pos(r_outer,aa,z1),pos(r_outer,aa,z1-.005),'metal')
  # outer slender posts at alternating steps with raised handrail
  if i%4==0:
   a0=a;top=z1+.055
   beam(m,pos(r_outer+.012,a0,z1),pos(r_outer+.012,a0,top),.005,.005,'metal')
  if i%8==0:
   # Cantilever brace into the photographed silo shell, below the footplate.
   beam(m,pos(.382,a,z1-.090),pos(r_outer-.01,a,z1-.005),.012,.012,'metal')
  if i:
   za=low+(high-low)*i/steps+.055;zb=z1+.055
   beam(m,pos(r_outer+.012,a,za),pos(r_outer+.012,b,zb),.006,.006,'metal')
 # small isolated landing at the end, no invented through-door
 a=angles[-1];m.box(center[0]+r_outer*np.cos(a)-.06,center[0]+r_outer*np.cos(a)+.06,
                        center[1]+r_outer*np.sin(a)-.06,center[1]+r_outer*np.sin(a)+.06,
                        high-.014,high,'metal')
 return m


def append_stair(doc,buf,report):
 mesh=external_silo_stair()
 existing={mat.get('name'):i for i,mat in enumerate(doc['materials'])}
 mat_idx=existing.get('R12 r6_metal')
 if mat_idx is None:
  mat_idx=next((i for i,m in enumerate(doc['materials']) if 'metal' in m.get('name','').lower()),None)
 if mat_idx is None:raise ValueError('Metal material not found')
 faces=mesh.groups['metal']
 pos=np.concatenate([f[0] for f in faces]).astype('<f4');normal=np.concatenate([np.repeat(f[1][None,:],3,axis=0) for f in faces]).astype('<f4');uv=np.concatenate([f[2] for f in faces]).astype('<f4')
 def add(data,target):
  raw=np.asarray(data).tobytes();buf.extend(b'\0'*(-len(buf)%4));o=len(buf);buf.extend(raw)
  idx=len(doc['bufferViews']);doc['bufferViews'].append(dict(buffer=0,byteOffset=o,byteLength=len(raw),target=target));return idx
 def acc(arr,typ,comp,target):
  b=add(arr,target);i=len(doc['accessors']);meta=dict(bufferView=b,componentType=comp,count=len(arr),type=typ)
  if typ=='VEC3':meta.update(min=arr.min(axis=0).tolist(),max=arr.max(axis=0).tolist())
  doc['accessors'].append(meta);return i
 posacc=acc((pos@AXIS).astype('<f4'),'VEC3',5126,34962)
 normacc=acc((normal@AXIS).astype('<f4'),'VEC3',5126,34962)
 uvacc=acc(uv,'VEC2',5126,34962)
 ids=np.arange(len(pos),dtype='<u2'); assert len(pos)<=65535
 triacc=acc(ids,'SCALAR',5123,34963)
 p={'attributes':{'POSITION':posacc,'NORMAL':normacc,'TEXCOORD_0':uvacc},'indices':triacc,'material':mat_idx,'mode':4}
 meshidx=len(doc['meshes']);doc['meshes'].append({'name':'R13 west silo exterior access stair, photo-guided approximation','primitives':[p]})
 ni=len(doc['nodes']);doc['nodes'].append({'name':'R13 modeled exterior access stair','mesh':meshidx})
 doc['scenes'][doc.get('scene',0)]['nodes'].append(ni)
 report['external_stair']={'triangles':len(faces),'rise_m':(.435*S),'steps':40,'surveyed':False,'part':'south-facing exterior arc on west double-silo group, one segment'}


def dedup_within_primitive(doc,buf,report):
 # Remove same triangle repeated inside one primitive; preserve cross-material overlays.
 counts=[]
 for im,mesh in enumerate(doc['meshes']):
  for ip,pr in enumerate(mesh['primitives']):
   tri=get_accessor(doc,buf,pr['indices']).reshape(-1,3)
   pos=get_accessor(doc,buf,pr['attributes']['POSITION'])
   xyz=pos[tri].astype('<f4',copy=False)
   vertex_order=np.lexsort((xyz[:,:,2],xyz[:,:,1],xyz[:,:,0]),axis=1)
   canon=np.take_along_axis(xyz,vertex_order[:,:,None],axis=1).copy()
   keys=np.ascontiguousarray(canon.reshape(-1,9)).view(np.dtype('V36')).reshape(-1)
   _,ix=np.unique(keys,return_index=True)
   if len(ix)==len(tri):continue
   tris=tri[np.sort(ix)].reshape(-1)
   a=doc['accessors'][pr['indices']].copy()
   dtype=np.dtype({5123:'<u2',5125:'<u4'}[a['componentType']]);raw=tris.astype(dtype).tobytes()
   buf.extend(b'\0'*(-len(buf)%4));o=len(buf);buf.extend(raw)
   vi=len(doc['bufferViews']);doc['bufferViews'].append(dict(buffer=0,byteOffset=o,byteLength=len(raw),target=34963))
   a.update(bufferView=vi,count=len(tris));a.pop('min',None);a.pop('max',None);a.pop('byteOffset',None)
   ai=len(doc['accessors']);doc['accessors'].append(a);pr['indices']=ai
   counts.append({'mesh':im,'primitive':ip,'removed_duplicates':len(tri)-len(ix)})
 report['deduplicated_triangles']=counts


def compact(doc,buf):
 used_acc=sorted(set([x for m in doc['meshes'] for pr in m['primitives'] for x in list(pr['attributes'].values())+[pr['indices']]]))
 amap={v:i for i,v in enumerate(used_acc)};doc['accessors']=[doc['accessors'][i] for i in used_acc]
 for m in doc['meshes']:
  for p in m['primitives']:
   p['attributes']={k:amap[v] for k,v in p['attributes'].items()};p['indices']=amap[p['indices']]
 use_views=sorted({a['bufferView'] for a in doc['accessors']}|{i['bufferView'] for i in doc['images']})
 vmap={k:i for i,k in enumerate(use_views)};newbuf=bytearray();newviews=[]
 for vi in use_views:
  b=doc['bufferViews'][vi].copy();o=b.get('byteOffset',0);newbuf.extend(b'\0'*(-len(newbuf)%4));b['byteOffset']=len(newbuf);newbuf.extend(buf[o:o+b['byteLength']]);newviews.append(b)
 for a in doc['accessors']:a['bufferView']=vmap[a['bufferView']]
 for i in doc['images']:i['bufferView']=vmap[i['bufferView']]
 doc['bufferViews']=newviews;doc['buffers'][0]['byteLength']=len(newbuf)
 newbuf.extend(b'\0'*(-len(newbuf)%4))
 return newbuf


def main(src,dst,fpc,rep):
 raw=Path(src).read_bytes();n=struct.unpack_from('<I',raw,12)[0];doc=json.loads(raw[20:20+n]);buf=bytearray(raw[28+n:])
 if 'R12' not in doc.get('asset',{}).get('extras',{}).get('modifications',''):
  raise ValueError('Input must be R12 GLB')
 r={'source_sha256':hashlib.sha256(raw).hexdigest()}
 repair_original_roofs(doc,buf,r)
 append_stair(doc,buf,r)
 dedup_within_primitive(doc,buf,r)
 buf=compact(doc,buf)
 doc['asset']['extras']['modifications']+=' R13: conservatively smoothed well-observed peripheral annex roofs, removed exact coincident triangles, added a reference-guided but not surveyed exterior stair segment on western silo; CC BY-NC 4.0.'
 js=json.dumps(doc,separators=(',',':'),ensure_ascii=False).encode('utf8');js+=b' '*(-len(js)%4)
 chunks=struct.pack('<I4s',len(js),b'JSON')+js+struct.pack('<I4s',len(buf),b'BIN\0')+buf
 Path(dst).write_bytes(struct.pack('<4sII',b'glTF',2,12+len(chunks))+chunks)
 v,t=read_glb(dst)
 # collision file contains each unique triangle at exact rendered positions
 _,ix=np.unique(np.sort(t,axis=1),axis=0,return_index=True)
 result=build(v,t[np.sort(ix)],fpc)
 # verify exact matching vertex array and canonical triangles
 rawf=Path(fpc).read_bytes();nv,nt,nn=struct.unpack_from('<III',rawf,4)
 fv=np.frombuffer(rawf,dtype='<f4',count=nv*3,offset=16).reshape(-1,3)
 ft=np.frombuffer(rawf,dtype='<u4',count=nt*3,offset=16+nv*12).reshape(-1,3)
 assert np.array_equal(fv,v)
 assert np.array_equal(np.unique(np.sort(ft,axis=1),axis=0),np.unique(np.sort(t,axis=1),axis=0))
 r.update(visual_sha256=hashlib.sha256(Path(dst).read_bytes()).hexdigest(),collision_sha256=hashlib.sha256(rawf).hexdigest(),visual_triangles=len(t),collision=result,exact_geometry_parity=True)
 Path(rep).write_text(json.dumps(r,indent=2,ensure_ascii=False))
 print(json.dumps(r,indent=2,ensure_ascii=False))


if __name__=='__main__':
 ap=argparse.ArgumentParser();ap.add_argument('src');ap.add_argument('dst');ap.add_argument('fpc');ap.add_argument('report');args=ap.parse_args();main(args.src,args.dst,args.fpc,args.report)
