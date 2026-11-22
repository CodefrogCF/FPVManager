#!/usr/bin/env python3
"""Reference-inspired R7 from exact R1 input. No photographs embedded."""
import argparse,hashlib,io,json,struct
from pathlib import Path
import numpy as np
from scipy.ndimage import gaussian_filter
from PIL import Image
from shapely import polygons,union_all,box
import reconstruct_ruedersdorf_r6 as r6
from build_collision import read_glb
S=r6.S;PATCH=(-2.5,-.43,-1.8,.43);Z=(-2.16,-1.91);MARGIN=.025
old_grid=r6.grid;old_texture=r6.texture;old_roofs=r6.refine_roofs
changes=dict(frame_fields=0,irregular_bars=0,broken_bars=0)
def grid(m,axis,plane,a,b,c,d,nv=1,nh=1):
 if not m.part.startswith('R6 '):return old_grid(m,axis,plane,a,b,c,d,nv,nh)
 rng=np.random.default_rng(int.from_bytes(hashlib.sha256(repr((axis,plane,a,b,c,d)).encode()).digest()[:8],'little'));changes['frame_fields']+=1
 def block(l,r,u,v):
  if min(r-l,v-u)<1e-5:return
  if axis==0:m.box(plane-.004,plane+.004,l,r,u,v,'metal')
  else:m.box(l,r,plane-.004,plane+.004,u,v,'metal')
 for x in np.linspace(a,b,nv+2)[1:-1]:
  x+=rng.uniform(-.002,.002);w=rng.uniform(.0015,.0022);changes['irregular_bars']+=1
  if rng.random()<.18:
   block(x-w,x+w,c,c+(d-c)*.38);block(x-w,x+w,c+(d-c)*.72,d);changes['broken_bars']+=1
  else:block(x-w,x+w,c,d)
 for z in np.linspace(c,d,nh+2)[1:-1]:
  z+=rng.uniform(-.002,.002);w=rng.uniform(.0015,.0022);changes['irregular_bars']+=1
  if rng.random()<.15:
   block(a,a+(b-a)*.38,z-w,z+w);block(a+(b-a)*.72,b,z-w,z+w);changes['broken_bars']+=1
  else:block(a,b,z-w,z+w)
def texture(mat):
 raw=old_texture(mat)
 if not mat.startswith('r6_'):return raw
 base=mat[3:];im=np.asarray(Image.open(io.BytesIO(raw)).convert('RGB'),dtype=float).copy();h,w=im.shape[:2];rng=np.random.default_rng(7000+sum(map(ord,mat)))
 def noise(s):
  n=gaussian_filter(rng.normal(size=(h,w)),s,mode='wrap');return n/max(n.std(),1e-9)
 broad=noise((26,26));streak=noise((48,2.5));grain=noise((1.1,1.1));peel=noise((8,8));fine=noise((.65,.65))
 if base in ('concrete','brick'):
  damp=np.clip((streak+.42*broad-.35)/2,0,1);exposed=np.clip((peel+.35*grain-.82)*1.7,0,1)
  im+=broad[:,:,None]*5+grain[:,:,None]*3+damp[:,:,None]*np.array([-28,-25,-23])+exposed[:,:,None]*np.array([10,-4,-12]);im+=np.clip((fine+peel-1.8)*.5,0,1)[:,:,None]*np.array([-21,-19,-16])
 elif base=='metal':
  rust=np.clip((peel+.40*grain+.2)/2,0,1);dark=np.clip((streak-.3)*.7,0,1)
  im+=rust[:,:,None]*np.array([26,1,-14])+dark[:,:,None]*np.array([-23,-20,-18])+grain[:,:,None]*3
 elif base in ('roof','floor'):
  dirt=np.clip((broad+.35*peel-.4)*.65,0,1);im+=dirt[:,:,None]*np.array([-22,-19,-16])+grain[:,:,None]*3;im+=np.clip((peel-.85)*.8,0,1)[:,:,None]*np.array([3,8,-4])
 s=io.BytesIO();Image.fromarray(np.clip(im,0,255).astype('u1')).save(s,format='PNG');return s.getvalue()
def refine_ground(v,t):
 out,report=old_roofs(v,t);before=out.copy();x0,y0,x1,y1=PATCH
 ids=np.flatnonzero((out[:,0]>x0-.04)&(out[:,0]<x1+.04)&(out[:,1]>y0-.04)&(out[:,1]<y1+.04)&(out[:,2]>Z[0])&(out[:,2]<Z[1]))
 p=out[ids].astype(float);A=np.c_[p[:,:2],np.ones(len(p))];coef=np.linalg.lstsq(A,p[:,2],rcond=None)[0]
 dist=np.minimum.reduce([p[:,0]-(x0-.04),(x1+.04)-p[:,0],p[:,1]-(y0-.04),(y1+.04)-p[:,1]]);w=np.clip(dist/.12,0,1);w=w*w*(3-2*w)
 out[ids,2]=(p[:,2]+np.clip((A@coef-p[:,2])*.30,-.10/S,.10/S)*w).astype('f4');n0=np.cross(before[t[:,1]]-before[t[:,0]],before[t[:,2]]-before[t[:,0]]);mag=np.linalg.norm(n0,axis=1)
 for _ in range(20):
  n1=np.cross(out[t[:,1]]-out[t[:,0]],out[t[:,2]]-out[t[:,0]]);bad=(mag>1e-12)&((np.einsum('ij,ij->i',n0,n1)<=0)|(np.linalg.norm(n1,axis=1)<.3*mag))
  if not bad.any():break
  ix=np.unique(t[bad]);out[ix]=before[ix]
 else:raise ValueError('Unsafe ground normal changes')
 disp=np.linalg.norm(out-before,axis=1)*S;report['R7_courtyard']={'moved_vertices':int((disp>1e-6).sum()),'max_displacement_m':float(disp.max()),'plane':coef.tolist()};return out,report
def certify(path):
 v,t=read_glb(path);p=v[t];x0,y0,x1,y1=PATCH
 good=(p[:,:,2].min(1)>Z[0])&(p[:,:,2].max(1)<Z[1])&(p[:,:,0].min(1)>x0-.3)&(p[:,:,0].max(1)<x1+.3)&(p[:,:,1].min(1)>y0-.3)&(p[:,:,1].max(1)<y1+.3)
 g=union_all(polygons(p[good,:,:2]));target=box(*PATCH).buffer(MARGIN)
 if not g.buffer(1e-8).covers(target):raise ValueError(f'Ground coverage incomplete: {target.difference(g).area}')
 return {'localBounds':list(PATCH),'localGroundRange':list(Z),'coverageMarginLocal':MARGIN,'coverageAreaM2':float(box(*PATCH).area*S*S),'groundTrianglesConsidered':int(good.sum())}
def main(src,dst,fpc,report):
 r6.grid=grid;r6.texture=texture;r6.refine_roofs=refine_ground;r6.main(src,dst,fpc,report);rep=json.loads(Path(report).read_text());rep['R7_frame_changes']=changes;rep['R7_terrain_certificate']=certify(dst);rep['R7_terrain_certificate']['collisionSha256']=hashlib.sha256(Path(fpc).read_bytes()).hexdigest()
 raw=Path(dst).read_bytes();n=struct.unpack_from('<I',raw,12)[0];j=json.loads(raw[20:20+n]);j['asset']['extras']['modifications']+=' R7: procedural weathering, selected broken mullions, bounded courtyard ground refinement; not surveyed.';js=json.dumps(j,separators=(',',':'),ensure_ascii=False).encode();js+=b' '*(-len(js)%4);chunks=struct.pack('<I4s',len(js),b'JSON')+js+raw[20+n:];Path(dst).write_bytes(struct.pack('<4sII',b'glTF',2,len(chunks)+12)+chunks);rep['R7_glbSha256']=hashlib.sha256(Path(dst).read_bytes()).hexdigest();Path(report).write_text(json.dumps(rep,indent=2));print(json.dumps(rep['R7_terrain_certificate'],indent=2));print(changes)
if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('src');p.add_argument('dst');p.add_argument('fpc');p.add_argument('report');a=p.parse_args();main(a.src,a.dst,a.fpc,a.report)
