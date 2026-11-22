#!/usr/bin/env python3
"""Experimental R6 for Ruedersdorf R1 only. Procedural geometry in Cesium-corrected
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
REGIONS.append(('R6 west production block',[-4.33,1.71,-1.987],[-2.59,3.50,-.62]))
REGIONS.append(('R6 six silo stair tower',[3.97,-2.34,-1.985],[5.32,-2.111,-.485]))
CX,CY=-.367,1.958
Z0,ZT=-2.025,.46
COLORS={'concrete':(112,112,105),'floor':(108,101,89),'brick':(108,99,87),'brickdark':(61,52,45),'chimney':(100,78,64),'metal':(82,68,56),'roof':(75,74,70),'tank':(112,119,115)}
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


def beam(m,a,b,width,depth,mat='metal'):
 a,b=np.asarray(a,float),np.asarray(b,float);d=b-a;d/=np.linalg.norm(d);u=np.cross(d,[0,0,1])
 if np.linalg.norm(u)<1e-8:u=np.cross(d,[0,1,0])
 u*=width/(2*np.linalg.norm(u));v=np.cross(d,u);v*=depth/(2*np.linalg.norm(v));A=[a-u-v,a+u-v,a+u+v,a-u+v];B=[b-u-v,b+u-v,b+u+v,b-u+v]
 m.quad(*A[::-1],mat);m.quad(*B,mat)
 for i in range(4):j=(i+1)%4;m.quad(A[i],A[j],B[j],B[i],mat)

def rubble(m,center,length,width,height,angle,seed):
 rng=np.random.default_rng(seed);x,y,z=center;ca,sa=np.cos(angle),np.sin(angle);ring=np.array([[-.5,-.32],[.16,-.5],[.5,-.23],[.42,.42],[-.22,.5],[-.5,.12]]);base=[];top=[]
 for a,b in ring:
  u,v=a*length,b*width;base.append((x+u*ca-v*sa,y+u*sa+v*ca,z));top.append((x+.78*(u*ca-v*sa),y+.78*(u*sa+v*ca),z+height*rng.uniform(.48,1)))
 for i in range(6):j=(i+1)%6;m.quad(base[i],base[j],top[j],top[i],'concrete')
 for i in range(1,5):m.tri(base[0],base[i+1],base[i],'concrete');m.tri(top[0],top[i],top[i+1],'concrete')

def damaged_wall(m,x0,x1,y,z0,heights,thick=.035):
 xs=np.linspace(x0,x1,len(heights))
 for i in range(len(xs)-1):
  a,b=xs[i:i+2];u,v=heights[i:i+2];l,r=y-thick/2,y+thick/2
  m.quad((a,l,z0),(b,l,z0),(b,l,v),(a,l,u),'brick');m.quad((b,r,z0),(a,r,z0),(a,r,u),(b,r,v),'brick');m.quad((a,l,u),(b,l,v),(b,r,v),(a,r,u),'brickdark');m.quad((a,r,z0),(b,r,z0),(b,l,z0),(a,l,z0),'brick')
 for a,h in [(xs[0],heights[0]),(xs[-1],heights[-1])]:m.quad((a,y-thick/2,z0),(a,y+thick/2,z0),(a,y+thick/2,h),(a,y-thick/2,h),'brickdark')

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
 if not curved:
  if m.part=='long hall and facade' and n==14:
   a,b,c,d=-2.65,-2.55,-1.71,-1.45
   for l,r,u,v in [(x0,a,y0,y1),(b,x1,y0,y1),(a,b,y0,c),(a,b,d,y1)]:m.box(l,r,u,v,top-.026,top+.013,'roof')
  else:m.box(x0,x1,y0,y1,top-.026,top+.013,'roof')
  return
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

# R5: window bands from orthographic original scan, photo-constrained hall interior.
# X is the long hall axis. Heights are in original local units; positions of individual
# surviving panes and tank bank along X are estimates, not metrically registered photos.
HIGH_BANDS=[(-1.76,-1.52),(-1.40,-1.16),(-1.01,-.77),(-.53,-.32),(-.29,-.13)]
LOW_BANDS=[(-1.76,-1.56),(-1.46,-1.25),(-.98,-.77)]

def facade_r5(m,x0,x1,y,zbase,ztop,n,bands,doors,back=False):
 thickness=.024;edges=np.linspace(x0,x1,n+1);high=n==14
 def block(a,b,z0,z1,mat='brick'):
  m.box(a,b,y-thickness/2,y+thickness/2,z0,z1,mat)
 for i,(a,b) in enumerate(zip(edges[:-1],edges[1:])):
  p=.021;block(a,a+p,zbase,ztop,'concrete');block(b-p,b,zbase,ztop,'concrete');last=zbase
  for j,(s,e) in enumerate(bands):
   if j==0 and i in doors:s=zbase;e=max(e,zbase+.23)
   block(a+p,b-p,last,s)
   # Back elevation: long solid infill below the clerestory is visible in the 2018 exterior photo.
   # The exact bay-by-bay condition cannot be read reliably in the scan.
   closed=(not high and back and j==1 and i not in [2,9,15]) or (not high and back and j==2 and i>=16) or (not high and back and j==0 and i not in doors and i in [0,1,5,6,13,17,18])
   if j==0 and i in doors:closed=False
   if closed:block(a+p,b-p,s,e,'brick')
   elif not(j==0 and i in doors):
    # Surviving glazing grids differ by bay; sparse damaged grids leave larger openings.
    u=a+p;v=b-p
    if (i+j)%4!=0:
     for frac in ([.25,.50,.75] if (i+j)%3==0 else [.5]):
      c=u+(v-u)*frac;block(c-.0025,c+.0025,s,e,'metal')
     if (i+2*j)%3!=0:
      for frac in ([.33,.67] if (i+j)%2==0 else [.5]):
       c=s+(e-s)*frac;block(u,v,c-.0025,c+.0025,'metal')
    # Small masonry remnants, not invisible collision panels.
    if high and (i,j) in {(2,0),(8,1),(12,0)}:block(u,u+(v-u)*.32,s,e,'brick')
   last=e
  block(a+p,b-p,last,ztop)

def tank_r5(m,x,y,z,r,length):
 # Dished ends. Four horizontal vessels point along the hall, not across it.
 N=40;depth=.055;stations=[(-length/2,0),(-length/2+depth*.2,r*.60),(-length/2+depth*.45,r*.85),(-length/2+depth,r), (length/2-depth,r),(length/2-depth*.45,r*.85),(length/2-depth*.2,r*.60),(length/2,0)]
 def ring(i,j):
  xx,rr=stations[i];a=j*2*np.pi/N;return (x+xx,y+rr*np.cos(a),z+rr*np.sin(a))
 for i in range(len(stations)-1):
  for j in range(N):m.quad(ring(i,j),ring(i,j+1),ring(i+1,j+1),ring(i+1,j),'tank')
 for xx in [x-length*.30,x+length*.30]:
  m.box(xx-.035,xx+.035,y-r*.72,y+r*.72,-1.877,z-r+.015,'concrete')
 for xx in [x-length*.25,x+length*.22]:m.cylinder((xx,y,z+r+.017),.016,.034,2,'metal',20)

def make_geometry():
 m=Mesh();m.part='R5 reference-constrained hall and facade'
 x0,xt,x1=-5.06,-1.49,3.44;y0,y1=-2.304,-.880;base=-1.92;high,low=-.091,-.720
 m.box(x0,x1,y0,y1,base-.045,base,'floor')
 for y in [y0,y1]:
  facade_r5(m,x0,xt,y,base,high,14,HIGH_BANDS,{4} if y==y1 else {1,9},back=y==y1)
  facade_r5(m,xt,x1,y,base,low,19,LOW_BANDS,{9} if y==y1 else {2,15},back=y==y1)
 # End elevations: photos show the upper transverse wall divided into five bays and two window rows.
 wall(m,1,y0,y1,x0,base,high,5,5,1)
 wall(m,1,y0,y1,x1,base,low,5,3,1)
 wall(m,1,y0,y1,xt,low,high,5,2,None)
 for a,b,n,top in [(x0,xt,14,high),(xt,x1,19,low)]:
  for x in np.linspace(a+.025,b-.025,n+1):
   for y in [y0+.032,y1-.032]:
    m.box(x-.025,x+.025,y-.026,y+.026,base,top,'concrete')
    # Haunched concrete brackets under the transverse roof girders.
    beam(m,(x,y,top-.19),(x,y+(.105 if y< -1.5 else -.105),top-.065),.05,.052,'concrete')
   m.box(x-.025,x+.025,y0+.035,y1-.035,top-.105,top-.034,'concrete')
  # Keep existing high roof opening, with surrounding reinforced concrete beams.
  if n==14:
   l,r,u,v=-2.65,-2.55,-1.71,-1.45
   for f,g,h,k in [(a,l,y0,y1),(r,b,y0,y1),(l,r,y0,u),(l,r,v,y1)]:m.box(f,g,h,k,top-.026,top+.013,'roof')
  else:m.box(a,b,y0,y1,top-.026,top+.013,'roof')
 # Main interior spine column visible in the tank photographs, under the high/low transition.
 m.box(xt-.034,xt+.034,-1.592-.031,-1.592+.031,base,low+.013,'concrete')
 m.box(xt-.071,xt+.071,-1.592-.065,-1.592+.065,base,base+.1,'concrete')
 m.part='R5 four longitudinal tanks on shared foundation'
 m.box(-3.025,-2.275,-1.874,-.984,base,base+.043,'concrete')
 for y in [-1.761,-1.543,-1.325,-1.107]:tank_r5(m,-2.65,y,-1.762,.099,.61)
 # Adjacent elevated concrete structure is visible to the right of the tanks in the overview.
 m.part='R5 adjacent concrete structure'
 a,b,c,d=-2.985,-2.305,-2.274,-1.984;z=-1.55
 for x in [a+.025,b-.025]:
  for y in [c+.025,d-.025]:m.box(x-.025,x+.025,y-.025,y+.025,base,z,'concrete')
 m.box(a,b,c,d,z-.035,z,'concrete')
 for y in [c,d]:m.box(a,b,y-.014,y+.014,-1.68,-1.60,'concrete')
 m.box(b-.028,b,c,d,base,-1.60,'brick')
 # Narrow elevated maintenance ledge along high windows in reference image, not a hall-wide obstruction.
 m.part='R5 maintenance ledge'
 for a,b in [(-4.96,-3.97),(-3.82,-2.92)]:
  c,d=-2.272,-2.169;z=-.57;m.box(a,b,c,d,z-.014,z,'metal')
  for x in np.linspace(a,b,5):
   beam(m,(x,d,z-.12),(x,c,z-.02),.012,.012,'metal');m.box(x-.004,x+.004,c-.004,c+.004,z,z+.06,'metal')
  m.box(a,b,c-.004,c+.004,z+.055,z+.062,'metal')
 # Keep the large axis largely empty; remove speculative workshop partitions and extra vessels.
 # A small amount of non-surveyed perimeter debris remains; no extra tanks or artificial maze.
 m.part='R5 perimeter rubble'
 for k,(x,y) in enumerate([(-4.85,-2.17),(-2.20,-2.15),(.40,-2.15),(2.8,-.99)]):
  for j in range(4):rubble(m,(x+.025*j,y+.012*(j%2),base),.055,.036,.025,j*.8,k*4+j)
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
 m.part='R4 factory frame and loading hopper'
 z=-1.50;xx,yy=5.29,2.69
 A=[(xx-.095,yy-.12,z+.15),(xx+.095,yy-.12,z+.15),(xx+.095,yy+.12,z+.15),(xx-.095,yy+.12,z+.15)];B=[(xx-.028,yy-.035,z),(xx+.028,yy-.035,z),(xx+.028,yy+.035,z),(xx-.028,yy+.035,z)]
 for k in range(4):j=(k+1)%4;m.quad(A[k],A[j],B[j],B[k],'metal')
 m.quad(*B,'metal');m.cylinder((xx,yy,z-.025),.025,.055,2,'metal',24)
 for j in range(9):
  zz=-1.715+j*.025;yy=2.60+j*.025;m.box(4.39,4.50,yy,yy+.025,zz-.012,zz,'metal')
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
 m.part='hollow middle chimney';zlist=[Z0,-1.89,-1.63,-1.53,-1.4,-1.,-.5,0,.30,ZT];radius=[.20,.198,.181,.179,.176,.166,.157,.147,.142,.140];N=96;ang=np.linspace(-np.pi,np.pi,N+1);door=np.array([min(abs((ang[i]+ang[i+1])/2),abs(abs((ang[i]+ang[i+1])/2)-np.pi))<np.deg2rad(18) for i in range(N)])
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
 for side in [-1,1]:
  lo,hi=sorted([CX+side*.219,CX+side*.163])
  for y0,y1,z0,z1 in [(CY-.101,CY-.066,-2.025,-1.60),(CY+.066,CY+.101,-2.025,-1.60),(CY-.101,CY+.101,-1.63,-1.60),(CY-.101,CY+.101,-1.92,-1.89)]:m.box(lo,hi,y0,y1,z0,z1,'concrete')
 # Bottom slab only; the upper rim remains an open annulus.
 m.cylinder((CX,CY,Z0-.012),.178,.024,2,'floor',96)
 return m

def refine_silos(v,t):
 # Only two additional well-supported sections; others are connected, obscured or poorly sampled.
 out=v.copy();report=[]
 for x,y,r0 in [(.0147,3.8762,.3901),(.904,3.864,.4),(1.9256,3.8608,.4024),(2.808,3.857,.392),(-2.1134,2.1267,.4045),(-2.1107,2.9956,.3955),(4.210,.040,.402),(5.0519,.0471,.4099),(4.2362,-.8221,.4163),(5.0508,-.8163,.4095),(4.2419,-1.7137,.4302),(5.0288,-1.6967,.4309)]:
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
 fine=gaussian_filter(rng.normal(size=(N,N)),1.5,mode='wrap');fine/=max(fine.std(),1e-9)
 patch=gaussian_filter(rng.normal(size=(N,N)),11,mode='wrap');patch/=max(patch.std(),1e-9)
 damp=gaussian_filter(rng.normal(size=(N,N)),(45,3),mode='wrap');damp/=max(damp.std(),1e-9)
 level+=fine*3+np.maximum(patch-.16,0)*-13+np.maximum(damp-.35,0)*-10
 color=np.array(COLORS[mat],float)[None,None,:]+level[:,:,None]
 if mat=='tank':
  rust=np.clip((patch+.3*fine-.30)/2,0,1);color+=rust[:,:,None]*np.array([8,-29,-34]);color+=np.maximum(damp,0)[:,:,None]*np.array([-12,-22,-19])
 elif mat=='metal':
  rust=np.clip((patch+.8*fine*.3+.45)/2,0,1);color+=rust[:,:,None]*np.array([19,-3,-13])
 elif mat in ['concrete','brick','floor']:
  peel=np.clip((patch-.65)*1.8,0,1);color+=peel[:,:,None]*np.array([15,14,11]);color+=np.maximum(damp,0)[:,:,None]*np.array([-5,1,-5])
 img=np.clip(color,0,255).astype('u1');s=io.BytesIO();Image.fromarray(img).save(s,format='PNG');return s.getvalue()

# R6: local dimensions derived from original scan; photo appearance is not a survey.
FOUR=[(.0147,3.8762,.3901),(.904,3.864,.4),(1.9256,3.8608,.4024),(2.8079,3.8566,.392)]
SIX=[(4.2205,.036,.4059),(5.0519,.0471,.4099),(4.2362,-.8221,.4163),(5.0508,-.8163,.4095),(4.2419,-1.7137,.4302),(5.0288,-1.6967,.4309)]
ROOFS=[('west stepped annex A',-5.64,-5.02,1.75,3.52,-1.62),('west stepped annex B',-4.98,-4.37,1.75,3.52,-1.47),('north annex high',-1.30,.17,4.58,5.50,-1.40),('north annex low',.29,.74,4.58,5.42,-1.57),('small northwest roof',-4.52,-3.77,5.79,6.12,-1.24),('east low annex roof',2.13,2.59,-.43,.96,-1.55),('southeast narrow annex',2.35,4.30,-4.95,-4.59,-1.61)]
def facade(m,axis,lo,hi,plane,base,top,ops,mat='brick',thick=.026):
 xs=sorted(set([lo,hi]+[q for a,b,c,d in ops for q in (a,b) if lo<q<hi]));zs=sorted(set([base,top]+[q for a,b,c,d in ops for q in (c,d) if base<q<top]))
 for a,b in zip(xs[:-1],xs[1:]):
  for c,d in zip(zs[:-1],zs[1:]):
   if any(l<(a+b)/2<r and u<(c+d)/2<v for l,r,u,v in ops):continue
   if axis==0:m.box(plane-thick/2,plane+thick/2,a,b,c,d,mat)
   else:m.box(a,b,plane-thick/2,plane+thick/2,c,d,mat)
def grid(m,axis,plane,a,b,c,d,nv=1,nh=1):
 def block(l,r,u,v):
  if axis==0:m.box(plane-.004,plane+.004,l,r,u,v,'metal')
  else:m.box(l,r,plane-.004,plane+.004,u,v,'metal')
 for x in np.linspace(a,b,nv+2)[1:-1]:block(x-.0018,x+.0018,c,d)
 for z in np.linspace(c,d,nh+2)[1:-1]:block(a,b,z-.0018,z+.0018)
def vault_r6(m):
 m.part='R6 vaulted hall shell';x0,x1,y0,y1=-3.36,.50,-7.08,-4.80;base,top=-1.92,-.73
 m.box(x0,x1,y0,y1,base-.045,base,'floor');edges=np.linspace(x0,x1,13)
 for y in [y0,y1]:
  ops=[]
  for i,(a,b) in enumerate(zip(edges[:-1],edges[1:])):
   for j,(c,d) in enumerate([(-1.75,-1.57),(-1.49,-1.31),(-1.20,-1.03),(-.96,-.79)]):
    if y==y1 and j==0 and a<-.91 and b>-1.72:continue
    if (i,j) in [(0,0),(11,0),(9,1)] or (y==y0 and i in [0,1,11] and j==1):continue
    l,r=a+.035,b-.025;ops.append((l,r,c,d))
    if (i+j)%3:grid(m,1,y,l,r,c,d,2 if j>0 else 1,1)
  ops.append((-1.72,-.91,base,-1.61) if y==y1 else (-1.59,-1.36,base,-1.69))
  facade(m,1,x0,x1,y,base,top,ops)
  for x in edges:m.box(x-.024,x+.024,y-.028,y+.028,-1.61 if y==y1 and -1.73<x<-.90 else base,top,'concrete')
 ys=np.linspace(y0,y1,25);mid=(y0+y1)/2;half=(y1-y0)/2;rise=.50;rad=(half*half+rise*rise)/(2*rise)
 def roofz(y):return top+rise-rad+np.sqrt(np.maximum(0,rad*rad-(y-mid)**2))
 zs=roofz(ys)
 for x in [x0,x1]:
  es=np.linspace(y0,y1,9);ops=[]
  for i,(a,b) in enumerate(zip(es[:-1],es[1:])):
   if i in [1,2,3,4,6]:ops.append((a+.05,b-.04,-1.52,-1.09));grid(m,0,x,a+.05,b-.04,-1.52,-1.09,1,3)
   if i in [0,2,5,7]:ops.append((a+.04,b-.04,-1.83,-1.63))
  facade(m,0,y0,y1,x,base,top,ops)
  for a,b,u,v in zip(ys[:-1],ys[1:],zs[:-1],zs[1:]):
   m.quad((x-.013,a,top),(x-.013,b,top),(x-.013,b,v),(x-.013,a,u),'brick');m.quad((x+.013,b,top),(x+.013,a,top),(x+.013,a,u),(x+.013,b,v),'brick')
  for y in es:m.box(x-.035,x+.035,y-.024,y+.024,base,float(roofz(y)),'concrete')
 ribs=np.linspace(x0+.05,x1-.05,13);spans=[(x0,ribs[0])]+list(zip(ribs[:-1],ribs[1:]))+[(ribs[-1],x1)]
 for j,(a,b,u,v) in enumerate(zip(ys[:-1],ys[1:],zs[:-1],zs[1:])):
  for k,(l,r) in enumerate(spans):
   if k in [3,6,9] and j in [11,12]:continue
   m.quad((l,a,u),(r,a,u),(r,b,v),(l,b,v),'roof');m.quad((l,b,v-.026),(r,b,v-.026),(r,a,u-.026),(l,a,u-.026),'concrete')
  for x in ribs:
   Q=[(x-.028,a,u-.10),(x+.028,a,u-.10),(x+.028,b,v-.10),(x-.028,b,v-.10),(x-.028,a,u-.026),(x+.028,a,u-.026),(x+.028,b,v-.026),(x-.028,b,v-.026)]
   for ids in [(0,1,2,3),(4,7,6,5),(0,4,5,1),(1,5,6,2),(2,6,7,3),(3,7,4,0)]:m.quad(*(Q[i] for i in ids),'concrete')
 for k in [3,6,9]:
  l,r=spans[k];a,b=ys[11],ys[13];z=-.23
  for x in [l+.02,r-.02]:
   for y in [a,b]:m.box(x-.006,x+.006,y-.006,y+.006,z,z+.047,'metal')
   m.box(x-.005,x+.005,a,b,z+.040,z+.047,'metal')
  for y in [a,b]:m.box(l+.02,r-.02,y-.005,y+.005,z+.040,z+.047,'metal')
def east_frame_r6(m):
 m.part='R6 east production building';x0,x1,y0,y1=4.35,5.43,1.05,2.95;base,top=-1.94,-1.05
 m.box(x0,x1,y0,y1,base-.035,base,'floor');es=np.linspace(y0,y1,6)
 for x in [x0,x1]:
  ops=[]
  for i,(a,b) in enumerate(zip(es[:-1],es[1:])):
   if x==x0:ops.append((a+.055,b-.055,base,-1.73 if i!=2 else -1.64))
   if x==x1 and i in [0,4]:ops.append((a+.08,b-.05,base,-1.77))
   for j,(c,d) in enumerate([(-1.64,-1.45),(-1.34,-1.11)]):
    ops.append((a+.055,b-.045,c,d))
    if (i+j)%2:grid(m,0,x,a+.055,b-.045,c,d,2,1)
  if x==x1:ops.append((1.55,2.45,base,-1.72))
  facade(m,0,y0,y1,x,base,top,ops)
  for y in es:m.box(x-.035,x+.035,y-.024,y+.024,-1.72 if x==x1 and 1.55<y<2.45 else base,top)
 for y in [y0,y1]:
  ops=[(x0+.10,x0+.29,base,-1.75),(x0+.38,x0+.68,-1.62,-1.45),(x0+.75,x1-.10,-1.62,-1.45),(x0+.14,x0+.41,-1.32,-1.13),(x0+.61,x1-.10,-1.32,-1.13)]
  facade(m,1,x0,x1,y,base,top,ops)
 for z in [-1.65,-1.37]:
  m.box(x0+.03,x1-.03,y0+.05,2.62,z-.024,z,'floor');m.box(x0+.03,x0+.72,2.62,y1-.03,z-.024,z,'floor')
  for y in es[1:-1]:m.box(x0+.03,x1-.03,y-.027,y+.027,z-.049,z,'concrete')
 for z in [base,-1.65]:
  for j in range(11):
   x=x0+.73+j*.021;h=z+.29*(j+1)/11;m.box(x,x+.021,2.68,2.88,h-.012,h,'concrete')
 m.box(x0,x1,y0,y1,top-.024,top,'roof')
def west_block_r6(m):
 m.part='R6 west production block';x0,x1,y0,y1=-4.28,-2.62,1.76,3.46;base,top=-1.99,-.75
 m.box(x0,x1,y0,y1,base-.025,base,'floor')
 for y in [y0,y1]:
  ops=[(-3.96,-3.64,-1.39,-.78),(-3.32,-2.77,-1.20,-1.02),(-3.32,-2.77,-1.56,-1.38),(-3.25,-2.81,base,-1.79)] if y==y0 else [(-3.80,-3.50,base,-1.77),(-3.88,-3.16,-1.65,-1.50),(-3.92,-3.18,-1.36,-1.20),(-3.93,-3.05,-1.08,-.88),(-3.10,-2.75,-1.65,-.95)]
  facade(m,1,x0,x1,y,base,top,ops)
  for i in [x0,-4.07,-3.56,x1]:m.box(i-.019,i+.019,y-.023,y+.023,base,top)
 for x in [x0,x1]:
  ops=[(a+.05,b-.05,-1.18,-.91) for a,b in zip(np.linspace(y0,y1,5)[:-1],np.linspace(y0,y1,5)[1:])]
  facade(m,0,y0,y1,x,base,top,ops)
 for z in [-1.70,-1.43,-1.16]:
  m.box(x0+.04,x0+.32,y0+.03,y1-.03,z-.024,z,'floor');m.box(x1-.32,x1-.04,y0+.03,y1-.03,z-.024,z,'floor');m.box(x0+.32,x1-.32,y1-.28,y1-.03,z-.024,z,'floor')
 m.box(x0,x1,y0,y1,top-.025,top,'roof')
def roof_rail(m,x,y,r,z,arc=(0,2*np.pi)):
 a,b=arc;N=max(5,int((b-a)*r/.09));aa=np.linspace(a,b,N+1);r-=.022
 for k,t in enumerate(aa):
  p=(x+r*np.cos(t),y+r*np.sin(t));m.box(p[0]-.0035,p[0]+.0035,p[1]-.0035,p[1]+.0035,z-.005,z+.06,'metal')
  if k:
   u=aa[k-1];q=(x+r*np.cos(u),y+r*np.sin(u))
   for zz in [z+.027,z+.060]:beam(m,(*q,zz),(*p,zz),.005,.005,'metal')
def curved_base(m,cx,cy,r,j):
 N=96;angles=np.linspace(-np.pi,np.pi,N+1);zs=[-2.005,-1.80,-1.72,-1.68];ro=r*.975;ri=ro-.035
 def P(k,a,inner):
  rr=ri if inner else ro;return (cx+rr*np.cos(angles[a]),cy+rr*np.sin(angles[a]),zs[k])
 def gap(i,k):return (k==1 and i%8 in [2,3,4,5,6]) or (k==0 and j in [0,3] and ((i-70)%96 in range(8) or (i-22)%96 in range(8)))
 for k in range(3):
  for i in range(N):
   h=i+1
   if gap(i,k):continue
   m.quad(P(k,i,0),P(k,h,0),P(k+1,h,0),P(k+1,i,0),'concrete');m.quad(P(k,h,1),P(k,i,1),P(k+1,i,1),P(k+1,h,1),'concrete')
   if k==0 or gap(i,k-1):m.quad(P(k,i,0),P(k,i,1),P(k,h,1),P(k,h,0),'concrete')
   if k==2 or gap(i,k+1):m.quad(P(k+1,i,0),P(k+1,h,0),P(k+1,h,1),P(k+1,i,1),'concrete')
   if gap((i-1)%N,k):m.quad(P(k,i,0),P(k+1,i,0),P(k+1,i,1),P(k,i,1),'concrete')
   if gap(h%N,k):m.quad(P(k,h,0),P(k,h,1),P(k+1,h,1),P(k+1,h,0),'concrete')
 m.cylinder((cx,cy,-1.675),ro,.022,2,'concrete',96)
 for a in [0,np.pi/2,np.pi,3*np.pi/2]:
  x,y=cx+.16*np.cos(a),cy+.16*np.sin(a);m.box(x-.026,x+.026,y-.026,y+.026,-2.005,-1.69,'concrete')
def refine_roofs(v,t):
 out=v.copy();reports=[]
 for name,a,b,c,d,target in ROOFS:
  ids=np.flatnonzero((v[:,0]>a)&(v[:,0]<b)&(v[:,1]>c)&(v[:,1]<d)&(abs(v[:,2]-target)<.055))
  if len(ids)<80:continue
  p=v[ids].astype(float);A=np.column_stack([p[:,:2],np.ones(len(p))]);coef=least_squares(lambda k:A@k-p[:,2],[0,0,target],loss='soft_l1',f_scale=.012).x;err=A@coef-p[:,2];med=np.median(abs(err))
  if med>.023 or np.linalg.norm(coef[:2])>.18:continue
  dist=np.minimum.reduce([p[:,0]-a,b-p[:,0],p[:,1]-c,d-p[:,1]]);w=np.clip(dist/.10,0,1);w=w*w*(3-2*w);delta=np.clip(err*.65,-.12/S,.12/S)*w;out[ids,2]=(p[:,2]+delta).astype('f4');reports.append({'building':name,'candidate_vertices':len(ids),'median_plane_residual_m':float(med*S),'plane':coef.tolist()})
 old=np.cross(v[t[:,1]]-v[t[:,0]],v[t[:,2]]-v[t[:,0]]);mag=np.linalg.norm(old,axis=1)
 for _ in range(30):
  n=np.cross(out[t[:,1]]-out[t[:,0]],out[t[:,2]]-out[t[:,0]]);bad=(mag>1e-12)&((np.einsum('ij,ij->i',old,n)<=0)|(np.linalg.norm(n,axis=1)<.3*mag))
  if not bad.any():break
  ids=np.unique(t[bad]);out[ids]=v[ids]
 else:raise ValueError('Unsafe roof refinement')
 delta=np.linalg.norm(out-v,axis=1)*S;return out,{'patches':reports,'moved_vertices':int((delta>1e-6).sum()),'max_displacement_m':float(delta.max())}
def six_tower_r6(m):
 # Scan elevations show seven lower storey openings and diagonal stair flight silhouette.
 # Reference image shows concrete skeleton; precise surviving stair layout not surveyed.
 m.part='R6 six silo stair tower';x0,x1,y0,y1=4.005,5.29,-2.29,-2.115;base=-2.005;levels=[base,-1.84,-1.60,-1.36,-1.14,-.91,-.70,-.47]
 xs=[x0,4.32,4.64,4.98,x1]
 m.box(x0,x1,y0,y1,base-.023,base,'floor')
 for x in xs:
  for y in [y0,y1]:m.box(x-.021,x+.021,y-.019,y+.019,base,levels[-1],'concrete')
 for k,z in enumerate(levels[1:]):
  for y in [y0,y1]:m.box(x0,x1,y-.024,y+.024,z-.032,z,'concrete')
  for x in xs:m.box(x-.024,x+.024,y0,y1,z-.032,z,'concrete')
  # Narrow platform in each end bay; no fabricated wall in the open frame.
  m.box(x0,4.32,y0,y1,z-.021,z,'floor');m.box(4.98,x1,y0,y1,z-.021,z,'floor')
  if k==len(levels)-2:m.box(4.32,4.98,y0,y1,z-.021,z,'floor')
  z0=levels[k]
  for i in range(14):
   a=4.32+.66*i/14;b=4.32+.66*(i+1)/14
   if k%2:a,b=4.32+4.98-b,4.32+4.98-a
   h=z0+(z-z0)*(i+1)/14;m.box(a,b,y0+.025,y0+.10,h-.010,h,'concrete')
  # Sparse guardrail on upper landing, supported on the outside edge.
  if k>0:
   for a,b in [(x0,4.32),(4.98,x1)]:
    for x in [a+.025,(a+b)/2,b-.025]:m.box(x-.003,x+.003,y0+.022,y0+.028,z,z+.056,'metal')
    m.box(a+.025,b-.025,y0+.022,y0+.028,z+.050,z+.056,'metal')

GALLERY=[(4.07,4.35,-2.08,.20), (4.35,5.22,-.075,.20), (4.96,5.22,-.30,-.075), (4.96,5.22,-2.08,-1.35), (4.0,5.30,-2.31,-2.08)]
def gallery_r6(m):
 m.part='R6 six silo roof gallery';base,top=-.47,-.23
 for a,b,c,d in GALLERY:
  m.box(a,b,c,d,base-.021,base,'floor');m.box(a,b,c,d,top-.023,top,'roof')
 # U-shaped roof plan is visible in original point projection. Continuous passage is only assumed
 # at contacts between rectangles. Referenced photographs show long strips of window openings.
 walls=[(0,4.07,-2.08,.20,12),(0,4.35,-2.08,-.075,11),(1,.20,4.07,5.22,6),(1,-.075,4.35,4.96,3),(0,5.22,-.30,.20,3),(0,4.96,-.30,-.075,1),(1,-.30,4.96,5.22,1),(0,4.96,-2.08,-1.35,4),(0,5.22,-2.08,-1.35,4),(1,-1.35,4.96,5.22,1),(1,-2.31,4.0,5.30,6),(0,4.0,-2.31,-2.08,1),(0,5.30,-2.31,-2.08,1),(1,-2.08,4.0,4.07,1),(1,-2.08,4.35,4.96,3),(1,-2.08,5.22,5.30,1)]
 for axis,p,lo,hi,n in walls:
  ops=[]
  for i,(a,b) in enumerate(zip(np.linspace(lo,hi,n+1)[:-1],np.linspace(lo,hi,n+1)[1:])):
   if axis==0 and p==4.07 and a< -1.52 and b> -1.64:continue
   if b-a<.095 or i%7==5:continue
   l,r=a+.017,b-.017;c,d=-.397,-.264
   ops.append((l,r,c,d))
   if i%3:grid(m,axis,p,l,r,c,d,2,1)
  if axis==0 and p==4.07:ops.append((-1.645,-1.512,base,-.26)) # approximate gangway portal
  facade(m,axis,lo,hi,p,base,top,ops,'brick',.020)
 # Raised central headhouse visible on the southern scan elevation. Its interior is unobserved.
 a,b,c,d=4.31,4.98,-2.27,-2.09
 m.box(a,b,c,d,-.23,-.12,'brick');m.box(a-.01,b+.01,c-.01,d+.01,-.12,-.113,'roof')

def gangway_r6(m):
 # Scan: bridge at y=-1.58, x=3.44..3.85, walking level ~-0.46.
 # R5 roof is lower than the scan; stairs are an approximate connection.
 m.part='R6 hall to silo roof gangway'
 l,r=-1.626,-1.530
 m.box(3.43,4.085,l,r,-.47,-.445,'concrete')
 for j in range(16):
  a=3.10+j*.021;h=-.707+(.262*(j+1)/16)
  m.box(a,a+.021,l,r,-.707,h,'concrete')
 for y in (l+.005,r-.005):
  for x in np.linspace(3.44,4.02,7):m.box(x-.003,x+.003,y-.003,y+.003,-.445,-.382,'metal')
  for z in (-.413,-.382):m.box(3.44,4.06,y-.003,y+.003,z-.003,z+.003,'metal')
  for j in range(0,16,3):
   x=3.11+j*.021;h=-.707+.262*(j+1)/16
   m.box(x-.003,x+.003,y-.003,y+.003,h,h+.06,'metal')
  beam(m,(3.10,y,-.647),(3.44,y,-.385),.006,.006,'metal')
  m.box(3.44,3.84,y-.004,y+.004,-.489,-.468,'metal')

_make_r5=make_geometry
def make_geometry():
 m=_make_r5();drop={id(p) for name in ['vaulted hall and facade','open multistorey factory frame','R4 factory frame and loading hopper'] for p in m.parts.pop(name)}
 for name in m.groups:m.groups[name]=[f for f in m.groups[name] if id(f[0]) not in drop]
 vault_r6(m);east_frame_r6(m);west_block_r6(m);six_tower_r6(m);gallery_r6(m);gangway_r6(m)
 m.part='R6 four silo plinths'
 for i,(x,y,r) in enumerate(FOUR):curved_base(m,x,y,r,i)
 m.part='R6 silo roof rails'
 for x,y,r in FOUR:roof_rail(m,x,y,r,-.461)
 for x,y,r in SIX:
  if y>=-1.6:roof_rail(m,x,y,r,-.46,(np.pi/2,3*np.pi/2) if x<4.6 else (-np.pi/2,np.pi/2))
 # Segregate newly built parts, so R5 visual materials remain identical.
 newids={id(p) for name,pp in m.parts.items() if name.startswith('R6 ') for p in pp}
 for name in list(m.groups):
  if name not in ['concrete','roof','floor','metal','brick']:continue
  other=[];new=[]
  for f in m.groups[name]:
   if id(f[0]) in newids:
    new.append((f[0],f[1],f[2]*(.50 if name in ['concrete','roof','floor'] else 1.0)))
   else:other.append(f)
  if new:m.groups['r6_'+name]=new;m.groups[name]=other
 return m

_original_texture=texture
def texture(mat):
 if not mat.startswith('r6_'):return _original_texture(mat)
 base=mat[3:];raw=_original_texture(base);im=np.array(Image.open(io.BytesIO(raw)).convert('RGB')).astype(float)
 # Larger-scale lower-frequency variation and grey cement, no copied photographs.
 if base in ['concrete','roof','floor']:
  smooth=gaussian_filter(im,(1.5,1.5,0),mode='wrap');im=.35*im+.65*smooth
  if base=='concrete':im+=np.array([8,9,11])
  if base=='roof':im+=np.array([-3,-3,0])
 s=io.BytesIO();Image.fromarray(np.clip(im,0,255).astype('u1')).save(s,format='PNG');return s.getvalue()

def main(src,dst,fpc,report):
 raw=Path(src).read_bytes();n=struct.unpack_from('<I',raw,12)[0];doc=json.loads(raw[20:20+n]);buf=bytearray(raw[28+n:]);assert hashlib.sha256(raw).hexdigest()=='91b8aff253ad527fcff6bed1784434fb25d11909baea6ea506dbaaeff4f03005','Exact R1 input required'
 old_v,old_t=read_glb(src); refined,silo_report=refine_silos(old_v,old_t);refined,roof_report=refine_roofs(refined,old_t);tree=cKDTree(old_v)
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
 a=AXIS@np.array(doc['nodes'][0]['matrix']).reshape(4,4,order='F')[:3,:3];removed={r[0]:0 for r in REGIONS};removed['chimney']=0;removed['R6 silo plinths']=0;removed['R6 six silo gallery']=0;removed['R6 roof gangway']=0
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
   for cx,cy,r in FOUR:
    rr=np.linalg.norm(cen[:,:2]-[cx,cy],axis=1);kill=(rr<r+.055)&(cen[:,2]>-1.985)&(cen[:,2]<-1.695);removed['R6 silo plinths']+=int((kill&~mask).sum());mask|=kill
   for x0,x1,y0,y1 in GALLERY:
    kill=(cen[:,0]>x0-.022)&(cen[:,0]<x1+.022)&(cen[:,1]>y0-.022)&(cen[:,1]<y1+.022)&(cen[:,2]>-.462)&(cen[:,2]<-.065);removed['R6 six silo gallery']+=int((kill&~mask).sum());mask|=kill
   kill=(cen[:,0]>3.43)&(cen[:,0]<3.94)&(cen[:,1]>-1.655)&(cen[:,1]<-1.50)&(cen[:,2]>-.51)&(cen[:,2]<-.38);removed['R6 roof gangway']+=int((kill&~mask).sum());mask|=kill
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
  pos=np.concatenate([f[0] for f in faces]);normal=np.concatenate([np.repeat(f[1][None,:],3,axis=0) for f in faces]);uv=np.concatenate([f[2] for f in faces]);imgidx=len(doc['images']);doc['images'].append({'bufferView':view(texture(name)),'mimeType':'image/png','name':'R6 procedural '+name});texidx=len(doc['textures']);doc['textures'].append({'sampler':0,'source':imgidx});mi=len(doc['materials']);doc['materials'].append({'name':'R6 '+name,'doubleSided':True,'pbrMetallicRoughness':{'baseColorTexture':{'index':texidx},'metallicFactor':0.0,'roughnessFactor':.94}})
  prims.append({'attributes':{'POSITION':acc((pos@AXIS).astype('<f4'),'VEC3',5126,34962),'NORMAL':acc((normal@AXIS).astype('<f4'),'VEC3',5126,34962),'TEXCOORD_0':acc(uv.astype('<f4'),'VEC2',5126,34962)},'indices':acc(np.arange(len(pos),dtype='<u2' if len(pos)<=65536 else '<u4'),'SCALAR',5123 if len(pos)<=65536 else 5125,34963),'material':mi,'mode':4})
 mi=len(doc['meshes']);doc['meshes'].append({'name':'R6 reference-constrained reconstructed geometry','primitives':prims});ni=len(doc['nodes']);doc['nodes'].append({'name':'R6 experimental reconstruction','mesh':mi});doc['scenes'][doc.get('scene',0)]['nodes'].append(ni)
 doc['asset']['extras']['modifications']='FPVManager R6: R5 long hall and chimney retained; revised vaulted hall, east and west blocks, four silo plinths and roof rails, hall-to-silo gangway, bounded scan roof repairs; historical approximation, not surveyed; CC BY-NC 4.0.'
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
 rep={'source_sha256':hashlib.sha256(raw).hexdigest(),'removed_scan_faces':removed,'silo_surface_refinement':silo_report,'roof_surface_refinement':roof_report,'reconstructed_triangles':{k:len(vv) for k,vv in m.parts.items()},'hall_high_bands':HIGH_BANDS,'hall_low_bands':LOW_BANDS,'tank_count':4,'original_triangles':len(old_t),'visual_triangles':len(t),'collision':result,'unique_triangle_parity':True,'local_bounds_before':[old_v.min(0).tolist(),old_v.max(0).tolist()],'local_bounds_after':[v[t].min((0,1)).tolist(),v[t].max((0,1)).tolist()]};Path(report).write_text(json.dumps(rep,indent=2));print(json.dumps(rep,indent=2));return m
if __name__=='__main__':
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('src');p.add_argument('dst');p.add_argument('fpc');p.add_argument('report');args=p.parse_args();main(args.src,args.dst,args.fpc,args.report)
