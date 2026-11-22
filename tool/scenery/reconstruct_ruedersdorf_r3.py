#!/usr/bin/env python3
"""Experimental R3 for Ruedersdorf R1 only. Procedural geometry in Cesium-corrected
local axes. Requires numpy, scipy, Pillow. No third-party photos embedded.
"""
import argparse, hashlib, io, json, struct
from pathlib import Path
import numpy as np
from PIL import Image
from scipy.ndimage import gaussian_filter
from scipy.optimize import least_squares
from scipy.spatial import cKDTree
from build_collision import AXIS, read_glb, build
S=16.023268178233355
REGIONS=[('long hall',[-5.13,-2.42,-1.965],[3.52,-.77,.18]),('vaulted hall',[-3.48,-7.19,-1.965],[.60,-4.69,-.10]),('silo stair frame',[1.245,3.50,-1.985],[1.58,4.26,-.40]),('open factory frame',[4.26,.96,-1.97],[5.52,3.04,-.90])]
CX,CY=-.367,1.958
Z0,ZT=-2.025,.46
COLORS={'concrete':(112,112,105),'floor':(108,101,89),'brick':(108,99,87),'brickdark':(61,52,45),'chimney':(100,78,64),'metal':(82,68,56),'roof':(75,74,70)}
class Mesh:
 def __init__(self):self.groups={};self.parts={};self.part=''
 def tri(self,a,b,c,mat):
  p=np.array([a,b,c],float);n=np.cross(p[1]-p[0],p[2]-p[0]);l=np.linalg.norm(n)
  if l<1e-10:return
  n/=l;axis=np.argmax(abs(n));uv=p[:,[i for i in range(3) if i!=axis]]*S/2
  self.groups.setdefault(mat,[]).append((p,n,uv));self.parts.setdefault(self.part,[]).append(p)
 def quad(self,a,b,c,d,mat='concrete'):self.tri(a,b,c,mat);self.tri(a,c,d,mat)
 def box(self,x0,x1,y0,y1,z0,z1,mat='concrete'):
  if min(x1-x0,y1-y0,z1-z0)<1e-7:return
  a,b,c,d=(x0,y0,z0),(x1,y0,z0),(x1,y1,z0),(x0,y1,z0);e,f,g,h=(x0,y0,z1),(x1,y0,z1),(x1,y1,z1),(x0,y1,z1)
  for q in [(d,c,b,a),(e,f,g,h),(a,b,f,e),(b,c,g,f),(c,d,h,g),(d,a,e,h)]:self.quad(*q,mat)
 def cylinder(self,center,r,length,axis=0,mat='metal',N=40):
  c=np.array(center);other=[j for j in range(3) if j!=axis];a=[];b=[]
  for i in range(N):
   p=c.copy();p[other]+=r*np.array([np.cos(i*2*np.pi/N),np.sin(i*2*np.pi/N)]);p[axis]-=length/2;a.append(p);q=p.copy();q[axis]+=length;b.append(q)
  ca=c.copy();ca[axis]-=length/2;cb=c.copy();cb[axis]+=length/2
  for i in range(N):
   j=(i+1)%N;self.quad(a[i],a[j],b[j],b[i],mat);self.tri(ca,a[j],a[i],mat);self.tri(cb,b[i],b[j],mat)

# Approximate blocked window fields by (wall side, bay, floor). Not a survey.
BLOCKED_FIELDS={
 (14,-2.32):{(1,0),(3,2),(6,1),(10,3),(12,0),(12,4)},
 (14,-.865):{(0,1),(5,3),(8,0),(10,2),(13,4)},
 (19,-2.32):{(2,0),(5,1),(11,2),(16,0)},
 (19,-.865):{(1,2),(6,0),(14,1),(17,2)},
}
PARTIAL_FIELDS={
 (14,-2.32):{(2,1),(9,4)},(14,-.865):{(7,1),(11,3)},
 (19,-2.32):{(4,2),(12,0)},(19,-.865):{(3,0),(15,2)},
}

def wall(m,axis,lo,hi,plane,base,top,n,rows,door_idx=None):
 thick=.022;edges=np.linspace(lo,hi,n+1)
 def block(a,b,z0,z1,mat='brick'):
  if axis==0:m.box(a,b,plane-thick/2,plane+thick/2,z0,z1,mat)
  else:m.box(plane-thick/2,plane+thick/2,a,b,z0,z1,mat)
 for i in range(n):
  a,b=edges[i:i+2];p=.022;block(a,a+p,base,top,'concrete');block(b-p,b,base,top,'concrete');last=base
  for j in range(rows):
   zh=(top-base)/rows;start=base+j*zh+zh*.29;end=base+j*zh+zh*.77
   if j==0 and i==door_idx:start=base;end=max(end,base+.18)
   block(a+p,b-p,last,start)
   if j>0 and i%3==1:
    u=(a+b)/2;block(u-.005,u+.005,start,end,'metal')
    if i%2==1:block(a+p,b-p,(start+end)/2-.004,(start+end)/2+.004,'metal')
    if i%4==1:
     for u in [a+(b-a)*.33,a+(b-a)*.67]:block(u-.003,u+.003,start,end,'metal')
   # Preserve R2 frames. Additional obstructions are intentionally visible.
   if m.part=='long hall and facade' and axis==0 and not(j==0 and i==door_idx):
    if (i,j) in BLOCKED_FIELDS.get((n,plane),set()):
     block(a+p,b-p,start,end,'brick' if (i+j)%3 else 'metal')
    elif (i,j) in PARTIAL_FIELDS.get((n,plane),set()):
     block(a+p,a+p+(b-a-2*p)*.42,start,end,'brick')
   last=end
  block(a+p,b-p,last,top)

def hall(m,x0,x1,y0,y1,base,top,n,rows,door,curved=False,ends=(True,True)):
 m.box(x0,x1,y0,y1,base-.045,base,'floor')
 for y in [y0,y1]:wall(m,0,x0,x1,y,base,top,n,rows,door)
 for x,active in zip([x0,x1],ends):
  if active:wall(m,1,y0,y1,x,base,top,4,rows,1)
 for x in np.linspace(x0+.06,x1-.06,n+1):
  for y in [y0+.045,y1-.045]:m.box(x-.027,x+.027,y-.035,y+.035,base,top,'concrete')
  if not curved:m.box(x-.032,x+.032,y0+.025,y1-.025,top-.085,top-.035,'concrete')
 if not curved:m.box(x0,x1,y0,y1,top-.026,top+.013,'roof');return
 ys=np.linspace(y0,y1,21);mid=(y0+y1)/2;half=(y1-y0)/2;zs=top+.49*np.sqrt(np.maximum(0,1-((ys-mid)/half)**2))
 for j in range(len(ys)-1):
  a,b=ys[j:j+2];u,v=zs[j:j+2]
  # Reconstructed missing skylight panels (approximate positions, survey unavailable).
  ribs=np.linspace(x0+.05,x1-.05,n+1)
  spans=[(x0,ribs[0])]+list(zip(ribs[:-1],ribs[1:]))+[(ribs[-1],x1)]
  for k,(l,r) in enumerate(spans):
   gap=(k in [3,6,9] and j in [9,10])
   if gap:continue
   m.quad((l,a,u),(r,a,u),(r,b,v),(l,b,v),'roof');m.quad((l,b,v-.026),(r,b,v-.026),(r,a,u-.026),(l,a,u-.026),'concrete')
   # Trim vertical edges beside the actual opening; not a transparent fake skylight.
   if j in [8,11] and k in [3,6,9]:
    yy,zz=(b,v) if j==8 else (a,u)
    m.quad((l,yy,zz),(r,yy,zz),(r,yy,zz-.026),(l,yy,zz-.026),'roof')
  for x in [x0,x1]:m.quad((x,a,top),(x,b,top),(x,b,v),(x,a,u),'brick')
  for x in np.linspace(x0+.05,x1-.05,n+1):
   Q=[(x-.028,a,u-.12),(x+.028,a,u-.12),(x+.028,b,v-.12),(x-.028,b,v-.12),(x-.028,a,u-.028),(x+.028,a,u-.028),(x+.028,b,v-.028),(x-.028,b,v-.028)]
   for ids in [(0,1,2,3),(4,7,6,5),(0,4,5,1),(1,5,6,2),(2,6,7,3),(3,7,4,0)]:m.quad(*(Q[i] for i in ids),'concrete')
 for y,z in [(y0,zs[0]),(y1,zs[-1])]:m.quad((x0,y,z),(x1,y,z),(x1,y,z-.026),(x0,y,z-.026),'roof')

def make_geometry():
 m=Mesh();m.part='long hall and facade'
 hall(m,-5.035,-1.46,-2.32,-.865,-1.92,-.055,14,5,4,ends=(True,False))
 hall(m,-1.46,3.42,-2.32,-.865,-1.92,-.678,19,3,9,ends=(False,True))
 m.box(-1.471,-1.449,-2.32,-.865,-.678,-.055,'brick')
 m.part='hall interior fittings'
 for i in range(4):
  x=-3.85+i*.38;m.box(x-.14,x+.14,-2.18,-1.80,-1.92,-1.88);m.cylinder((x,-1.99,-1.78),.096,.29,1)
 # Move the R2 partition away from the window approach.
 m.box(-4.80,-4.39,-1.31,-1.16,-1.92,-1.65,'brick')
 m.part='R3 hall partitions and machinery'
 # Approximate workshop cells, leaving an uninterrupted central aisle.
 for x,side in [(-4.76,0),(-3.22,1),(-2.25,0),(-.82,1),(.48,0),(1.68,1),(2.66,0)]:
  a,b=(-2.14,-1.82) if side==0 else (-1.34,-1.06)
  mid=(a+b)/2;w=.068;top=-.91 if x>-1.46 else -1.05
  m.box(x-.021,x+.021,a,mid-w,-1.92,top,'brick')
  m.box(x-.021,x+.021,mid+w,b,-1.92,top,'brick')
  m.box(x-.021,x+.021,mid-w,mid+w,-1.72,top,'concrete')
 for x0,x1,y in [(-4.65,-4.13,-1.83),(-2.97,-2.44,-1.34),(-.52,.15,-1.82),(1.90,2.45,-1.34)]:
  mid=(x0+x1)/2;w=.075
  m.box(x0,mid-w,y-.018,y+.018,-1.92,-1.57,'brick')
  m.box(mid+w,x1,y-.018,y+.018,-1.92,-1.57,'brick')
  m.box(mid-w,mid+w,y-.018,y+.018,-1.73,-1.57,'concrete')
 # Machinery plinths and cylindrical vessels.
 for x,y in [(-4.12,-1.11),(-2.72,-2.03),(-.18,-1.15),(.82,-2.04),(2.25,-2.03),(2.95,-1.15)]:
  m.box(x-.105,x+.105,y-.085,y+.085,-1.92,-1.88,'concrete')
  m.cylinder((x,y,-1.79),.067,.18,2,'metal',40)
  m.cylinder((x,y,-1.69),.027,.045,2,'metal',24)
  for dx in [-.075,.075]:m.box(x+dx-.009,x+dx+.009,y-.075,y+.075,-1.88,-1.75,'metal')
 # Overhead pipes and hangers.
 for y in [-1.88,-1.30]:
  m.cylinder((-3.25,y,-.47),.026,3.1,0,'metal',24)
  m.cylinder((.92,y,-.84),.023,4.4,0,'metal',24)
  for x in [-4.4,-3.3,-2.2,-.6,.65,1.9,3.0]:
   z=-.47 if x<-1.46 else -.84
   m.box(x-.011,x+.011,y-.037,y+.037,z,z+.085,'metal')
 for x,z in [(-3.05,-.43),(-2.05,-.43),(.20,-.85),(2.15,-.85)]:
  m.cylinder((x,-1.59,z),.025,.92,1,'metal',24)
 # Elevated service platforms with partial railings.
 for x0,x1,y0,y1,z in [(-4.60,-3.94,-2.13,-1.86,-.99),(-2.88,-2.32,-1.31,-1.08,-.79),(.85,1.43,-2.13,-1.85,-1.24)]:
  m.box(x0,x1,y0,y1,z-.028,z,'floor')
  for x in [x0,x1]:
   for y in [y0,y1]:m.box(x-.012,x+.012,y-.012,y+.012,-1.92,z,'metal')
  for x in np.linspace(x0,x1,4):m.box(x-.007,x+.007,y1-.007,y1+.007,z,z+.063,'metal')
  m.box(x0,x1,y1-.007,y1+.007,z+.055,z+.064,'metal')
 for x,y in [(-4.47,-2.02),(-2.08,-1.12),(.1,-2.03),(1.12,-1.14),(3.08,-2.06)]:
  m.box(x-.065,x+.065,y-.047,y+.047,-1.92,-1.88,'concrete')
 m.part='vaulted hall and facade';hall(m,-3.36,.50,-7.08,-4.80,-1.92,-.73,12,4,5,True)
 # Additional independent four-bay / four-level concrete frame. Footprint and roof height from scan;
 # precisely which slabs were missing is not visible in source. The atrium is an explicit training reconstruction.
 m.part='open multistorey factory frame'
 x0,x1,y0,y1=4.35,5.43,1.05,2.95;base=-1.94;top=-1.05
 levels=np.linspace(base,top,5);ys=np.linspace(y0,y1,6)
 m.box(x0,x1,y0,y1,base-.035,base,'floor')
 for x in [x0,x1]:
  for y in ys:m.box(x-.025,x+.025,y-.024,y+.024,base,top)
 for y in [y0,y1]:
  m.box((x0+x1)/2-.025,(x0+x1)/2+.025,y-.025,y+.025,base,top)
 for k,z in enumerate(levels[1:],1):
  # Four perimeter slabs around the open vertical atrium.
  xA,xB,yA,yB=4.64,5.13,1.64,2.42
  for a,b,c,d in [(x0,xA,y0,y1),(xB,x1,y0,y1),(xA,xB,y0,yA),(xA,xB,yB,y1)]:m.box(a,b,c,d,z-.026,z,'floor' if k<4 else 'roof')
  for x in [x0,x1]:m.box(x-.035,x+.035,y0,y1,z-.058,z)
  for y in [y0,y1]:m.box(x0,x1,y-.035,y+.035,z-.058,z)
  # Sparse intact infill below sill and remaining upper brick panels, not solid floor-to-ceiling boxes.
  if k<4:
   for i,(a,b) in enumerate(zip(ys[:-1],ys[1:])):
    if (i+k)%3==0:m.box(x1-.018,x1+.018,a+.025,b-.025,z,z+.075,'brick')
   # Selected railing around the atrium, leaving side entries open.
   for y in [yA,yB]:
    m.box(xA,xB,y-.004,y+.004,z+.056,z+.064,'metal')
    for x in [xA,(xA+xB)/2,xB]:m.box(x-.004,x+.004,y-.004,y+.004,z,z+.064,'metal')
 # Short broken stair ramp/treads along a side wall between first two levels.
 for i in range(12):
  yy=y0+.18+i*.035;zz=base+(levels[1]-base)*(i+1)/12;m.box(x1-.18,x1-.06,yy,yy+.035,zz-.012,zz,'metal')
 m.part='silo stair frame';x0,x1,y0,y1=1.27,1.55,3.59,4.18;base=-2.01;top=-.465;levels=np.linspace(base,top,8)
 for x in [x0,x1]:
  for y in [y0,y1]:m.box(x-.019,x+.019,y-.019,y+.019,base,top)
 for k,z in enumerate(levels):
  m.box(x0-.01,x1+.01,y0-.025,y0+.025,z-.026,z);m.box(x0-.01,x1+.01,y1-.025,y1+.025,z-.026,z)
  for x in [x0,x1]:m.box(x-.02,x+.02,y0,y1,z-.026,z)
  m.box(x0,x1,y0,y0+.12,z-.022,z);m.box(x0,x1,y1-.12,y1,z-.022,z)
  if k<len(levels)-1:
   for s in range(12):
    l=s/12;u=(s+1)/12;ya=y0+.12+(y1-y0-.24)*l;yb=y0+.12+(y1-y0-.24)*u
    if k%2:ya,yb=y0+y1-yb,y0+y1-ya
    h=z+(levels[k+1]-z)*u;m.box(x0+.04,x0+.13,ya,yb,h-.012,h,'metal')
 m.part='silo connector platform';m.box(1.12,1.70,3.72,4.02,-.49,-.465)
 for y in [3.73,4.01]:
  for x in np.linspace(1.13,1.69,5):m.box(x-.004,x+.004,y-.004,y+.004,-.465,-.405,'metal')
  m.box(1.12,1.70,y-.004,y+.004,-.408,-.400,'metal')
 m.part='hollow middle chimney';zlist=[Z0,-1.89,-1.63,-1.53,-1.4,-1.,-.5,0,.30,ZT];radius=[.20,.198,.181,.179,.176,.166,.157,.147,.142,.140];N=96;ang=np.linspace(-np.pi,np.pi,N+1);door=np.array([abs(abs((ang[i]+ang[i+1])/2)-np.pi)<np.deg2rad(18) for i in range(N)])
 def point(i,k,inner):
  r=radius[k]-(.033 if inner else 0);return (CX+r*np.cos(ang[i]),CY+r*np.sin(ang[i]),zlist[k])
 def hole(i,k):return door[i%N] and k == 1
 for k in range(len(zlist)-1):
  for i in range(N):
   j=i+1
   if hole(i,k):continue
   m.quad(point(i,k,0),point(j,k,0),point(j,k+1,0),point(i,k+1,0),'chimney');m.quad(point(j,k,1),point(i,k,1),point(i,k+1,1),point(j,k+1,1),'brickdark')
   if k==0 or hole(i,k-1):m.quad(point(i,k,0),point(i,k,1),point(j,k,1),point(j,k,0),'brickdark')
   if k==len(zlist)-2 or hole(i,k+1):m.quad(point(i,k+1,0),point(j,k+1,0),point(j,k+1,1),point(i,k+1,1),'brickdark')
   if hole(i-1,k):m.quad(point(i,k,0),point(i,k+1,0),point(i,k+1,1),point(i,k,1),'brickdark')
   if hole(j,k):m.quad(point(j,k,0),point(j,k,1),point(j,k+1,1),point(j,k+1,0),'brickdark')
 # Squared concrete surround visible in the 2018 small-chimney photograph.
 m.box(CX-.219,CX-.163,CY-.101,CY-.066,-2.025,-1.60,'concrete')
 m.box(CX-.219,CX-.163,CY+.066,CY+.101,-2.025,-1.60,'concrete')
 m.box(CX-.219,CX-.163,CY-.101,CY+.101,-1.63,-1.60,'concrete')
 m.box(CX-.219,CX-.163,CY-.101,CY+.101,-1.92,-1.89,'concrete')
 # Bottom slab only; the upper rim remains an open annulus.
 m.cylinder((CX,CY,Z0-.012),.178,.024,2,'floor',96)
 return m

def refine_silos(v,t):
 # Only two additional well-supported sections; others are connected, obscured or poorly sampled.
 out=v.copy();report=[]
 for x,y,r0 in [(2.808,3.857,.392),(4.210,.040,.402)]:
  ids=np.flatnonzero((np.linalg.norm(v[:,:2]-[x,y],axis=1)<.46)&(v[:,2]>-1.64)&(v[:,2]<-.72));p=v[ids].astype(float);knots=[];fits=[]
  for z in np.arange(-1.55,-.74,.18):
   q=p[abs(p[:,2]-z)<.10,:2]
   if len(q)<50:continue
   fit=least_squares(lambda b:np.linalg.norm(q-b[:2],axis=1)-b[2],[x,y,r0],loss='soft_l1',f_scale=.006).x
   rr=np.linalg.norm(q-fit[:2],axis=1)-fit[2];angles=np.arctan2(q[:,1]-fit[1],q[:,0]-fit[0]);bins=len(np.unique(np.floor((angles+np.pi)*12/np.pi)))
   if bins>=18 and .34<fit[2]<.46 and np.quantile(abs(rr),.75)<.035 and np.linalg.norm(fit[:2]-[x,y])<.08:knots.append(z);fits.append(fit)
  if len(knots)<3:continue
  f=np.array(fits);q=np.column_stack([np.interp(p[:,2],knots,f[:,i]) for i in range(3)]);d=p[:,:2]-q[:,:2];rad=np.linalg.norm(d,axis=1);err=rad-q[:,2]
  def smooth(a):a=np.clip(a,0,1);return a*a*(3-2*a)
  w=smooth((p[:,2]-min(knots))/.17)*smooth((max(knots)-p[:,2])/.17)*smooth((.024-abs(err))/.014)
  delta=np.clip(-err*.7,-.10/S,.10/S)*w;out[ids,:2]=(p[:,:2]+d/np.maximum(rad[:,None],1e-9)*delta[:,None]).astype('f4')
  report.append({'center':[x,y],'accepted_ring_fits':len(knots)})
 def norm(a):return np.cross(a[t[:,1]]-a[t[:,0]],a[t[:,2]]-a[t[:,0]])
 old=norm(v);mag=np.linalg.norm(old,axis=1)
 for _ in range(30):
  n=norm(out);bad=(mag>1e-12)&((np.einsum('ij,ij->i',old,n)<=0)|(np.linalg.norm(n,axis=1)<.3*mag))
  if not bad.any():break
  i=np.unique(t[bad]);out[i]=v[i]
 else:raise ValueError('Unsafe silo refinement')
 change=np.linalg.norm(out-v,axis=1)*S
 return out,{'sections':report,'moved_vertices':int((change>1e-6).sum()),'max_displacement_m':float(change.max())}

def texture(mat):
 rng=np.random.default_rng(sum(map(ord,mat))+2026);N=512;yy,xx=np.mgrid[:N,:N];noise=gaussian_filter(rng.normal(size=(N,N)),3,mode='wrap');noise*=15/max(noise.std(),1e-9);coarse=gaussian_filter(rng.normal(size=(N,N)),20,mode='wrap');coarse*=12/max(coarse.std(),1e-9);level=noise*.32+coarse*.66+rng.normal(0,3.8,(N,N));
 if mat in ['concrete','brick','chimney','brickdark']:
  streak=gaussian_filter(rng.normal(size=(N,N)),(45,2),mode='wrap');streak*=5/max(streak.std(),1e-9);level+=streak
 if mat in ['brick','brickdark','chimney']:
  row=yy//24;shift=(row%2)*32;mortar=(yy%24<3)|((xx+shift)%64<3);level+=np.where(mortar,18,-5)
 if mat=='roof':level-=np.where(xx%128<3,12,0)
 img=np.clip(np.array(COLORS[mat])[None,None,:]+level[:,:,None],0,255).astype('u1');s=io.BytesIO();Image.fromarray(img).save(s,format='PNG');return s.getvalue()

def main(src,dst,fpc,report):
 raw=Path(src).read_bytes();n=struct.unpack_from('<I',raw,12)[0];doc=json.loads(raw[20:20+n]);buf=bytearray(raw[28+n:]);assert hashlib.sha256(raw).hexdigest()=='91b8aff253ad527fcff6bed1784434fb25d11909baea6ea506dbaaeff4f03005','Exact R1 input required'
 old_v,old_t=read_glb(src); refined,silo_report=refine_silos(old_v,old_t);tree=cKDTree(old_v)
 def view(payload,target=None):
  buf.extend(b'\0'*(-len(buf)%4));i=len(doc['bufferViews']);a={'buffer':0,'byteOffset':len(buf),'byteLength':len(payload)}
  if target:a['target']=target
  doc['bufferViews'].append(a);buf.extend(payload);return i
 def acc(a,typ,ctype,target):
  i=len(doc['accessors']);a=np.ascontiguousarray(a);d={'bufferView':view(a.tobytes(),target),'componentType':ctype,'count':len(a),'type':typ}
  if typ=='VEC3' and target==34962:d.update(min=a.min(axis=0).tolist(),max=a.max(axis=0).tolist())
  doc['accessors'].append(d);return i
 def get(i):
  a=doc['accessors'][i];b=doc['bufferViews'][a['bufferView']];dt=np.dtype({5123:'<u2',5125:'<u4',5126:'<f4'}[a['componentType']]);w={'SCALAR':1,'VEC3':3,'VEC2':2}[a['type']];return np.ndarray((a['count'],w),dtype=dt,buffer=buf,offset=b.get('byteOffset',0)+a.get('byteOffset',0),strides=(b.get('byteStride',w*dt.itemsize),dt.itemsize)).copy()
 a=AXIS@np.array(doc['nodes'][0]['matrix']).reshape(4,4,order='F')[:3,:3];removed={r[0]:0 for r in REGIONS};removed['chimney']=0
 for mesh in doc['meshes']:
  for p in mesh['primitives']:
   pos=get(p['attributes']['POSITION']);v=(pos@a.T).astype('f4');dist,ids=tree.query(v);assert dist.max()<1e-6
   changed=np.any(refined[ids]!=v,axis=1)
   if changed.any():
    v=refined[ids];pos[changed]=(v[changed]@a).astype('<f4')
   t=get(p['indices']).reshape(-1,3);cen=v[t].mean(1);mask=np.zeros(len(t),bool)
   for name,lo,hi in REGIONS:
    kill=np.all((cen>=lo)&(cen<=hi),axis=1);removed[name]+=int(kill.sum());mask|=kill
   kill=(np.linalg.norm(cen[:,:2]-[CX,CY],axis=1)<.268)&(cen[:,2]>-1.985)&(cen[:,2]<.55);removed['chimney']+=int(kill.sum());mask|=kill
   # Drop unused vertices and preserve UVs on retained triangles exactly.
   surviving=t[~mask];used,remap=np.unique(surviving,return_inverse=True);assert len(used)>0
   attrs={}
   for key,idx in p['attributes'].items():
    ar=doc['accessors'][idx];val=pos if key=='POSITION' else get(idx)
    attrs[key]=acc(val[used].astype('<f4'),ar['type'],5126,34962)
   p['attributes']=attrs;dtype,ctype=('<u2',5123) if len(used)<=65536 else ('<u4',5125)
   p['indices']=acc(remap.astype(dtype).ravel(),'SCALAR',ctype,34963)
 m=make_geometry();prims=[]
 for name,faces in m.groups.items():
  pos=np.concatenate([f[0] for f in faces]);normal=np.concatenate([np.repeat(f[1][None,:],3,axis=0) for f in faces]);uv=np.concatenate([f[2] for f in faces]);imgidx=len(doc['images']);doc['images'].append({'bufferView':view(texture(name)),'mimeType':'image/png','name':'R2 procedural '+name});texidx=len(doc['textures']);doc['textures'].append({'sampler':0,'source':imgidx});mi=len(doc['materials']);doc['materials'].append({'name':'R2 '+name,'doubleSided':True,'pbrMetallicRoughness':{'baseColorTexture':{'index':texidx},'metallicFactor':0.0,'roughnessFactor':.94}})
  prims.append({'attributes':{'POSITION':acc((pos@AXIS).astype('<f4'),'VEC3',5126,34962),'NORMAL':acc((normal@AXIS).astype('<f4'),'VEC3',5126,34962),'TEXCOORD_0':acc(uv.astype('<f4'),'VEC2',5126,34962)},'indices':acc(np.arange(len(pos),dtype='<u2' if len(pos)<=65536 else '<u4'),'SCALAR',5123 if len(pos)<=65536 else 5125,34963),'material':mi,'mode':4})
 mi=len(doc['meshes']);doc['meshes'].append({'name':'R3 approximate reconstructed geometry','primitives':prims});ni=len(doc['nodes']);doc['nodes'].append({'name':'R3 experimental reconstruction','mesh':mi});doc['scenes'][doc.get('scene',0)]['nodes'].append(ni)
 doc['asset']['extras']['modifications']='FPVManager R3: R2 reconstruction plus intentionally obstructed window fields, approximate partitions, machinery, platforms and pipework; procedural textures; not surveyed; CC BY-NC 4.0.'
 # Compact buffer views; eliminate obsolete index buffers.
 usedacc=set()
 for mesh in doc['meshes']:
  for p in mesh['primitives']:usedacc.update(p['attributes'].values());usedacc.add(p['indices'])
 akeys=sorted(usedacc);amap={k:i for i,k in enumerate(akeys)};doc['accessors']=[doc['accessors'][k] for k in akeys]
 for mesh in doc['meshes']:
  for p in mesh['primitives']:p['attributes']={k:amap[v] for k,v in p['attributes'].items()};p['indices']=amap[p['indices']]
 usedviews=sorted({a['bufferView'] for a in doc['accessors']}|{i['bufferView'] for i in doc['images']});vmap={k:i for i,k in enumerate(usedviews)};newbuf=bytearray();newviews=[]
 for k in usedviews:
  bv=doc['bufferViews'][k].copy();off=bv.get('byteOffset',0);newbuf.extend(b'\0'*(-len(newbuf)%4));bv['byteOffset']=len(newbuf);newbuf.extend(buf[off:off+bv['byteLength']]);newviews.append(bv)
 for obj in doc['accessors']+doc['images']:obj['bufferView']=vmap[obj['bufferView']]
 doc['bufferViews']=newviews;buf=newbuf;doc['buffers'][0]['byteLength']=len(buf);buf.extend(b'\0'*(-len(buf)%4));js=json.dumps(doc,separators=(',',':'),ensure_ascii=False).encode();js+=b' '*(-len(js)%4);chunks=struct.pack('<I4s',len(js),b'JSON')+js+struct.pack('<I4s',len(buf),b'BIN\0')+buf;Path(dst).write_bytes(struct.pack('<4sII',b'glTF',2,12+len(chunks))+chunks)
 v,t=read_glb(dst);_,keep=np.unique(np.sort(t,axis=1),axis=0,return_index=True);tclean=t[np.sort(keep)];result=build(v,tclean,fpc)
 rawf=Path(fpc).read_bytes();_,nv,nt,nn=struct.unpack_from('<4sIII',rawf);fv=np.frombuffer(rawf,dtype='<f4',count=nv*3,offset=16).reshape(-1,3);ft=np.frombuffer(rawf,dtype='<u4',count=nt*3,offset=16+nv*12).reshape(-1,3);assert np.array_equal(fv,v);assert np.array_equal(np.unique(np.sort(ft,axis=1),axis=0),np.unique(np.sort(t,axis=1),axis=0))
 rep={'source_sha256':hashlib.sha256(raw).hexdigest(),'removed_scan_faces':removed,'silo_surface_refinement':silo_report,'reconstructed_triangles':{k:len(vv) for k,vv in m.parts.items()},'blocked_window_fields':sum(map(len,BLOCKED_FIELDS.values())),'partial_window_fields':sum(map(len,PARTIAL_FIELDS.values())),'original_triangles':len(old_t),'visual_triangles':len(t),'collision':result,'unique_triangle_parity':True,'local_bounds_before':[old_v.min(0).tolist(),old_v.max(0).tolist()],'local_bounds_after':[v[t].min((0,1)).tolist(),v[t].max((0,1)).tolist()]};Path(report).write_text(json.dumps(rep,indent=2));print(json.dumps(rep,indent=2));return m
if __name__=='__main__':
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('src');p.add_argument('dst');p.add_argument('fpc');p.add_argument('report');args=p.parse_args();main(args.src,args.dst,args.fpc,args.report)
