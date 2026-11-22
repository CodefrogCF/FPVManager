#!/usr/bin/env python3
"""Plot genuine R8 scan geometry against the calibrated R11 underlay; no invented images."""
import json,sys
from pathlib import Path
import numpy as np
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
ROOT=Path(__file__).resolve().parents[3];sys.path.insert(0,str(ROOT/'tool/scenery'))
from build_collision import read_glb

v,_=read_glb(ROOT/'web/assets/scenery/ruedersdorf_r11_ground.glb')
s,_=read_glb(ROOT/'web/assets/scenery/local_reference.glb')
report=json.loads((Path(__file__).parent/'underlay_report.json').read_text())
scale=16.023268178233355;root=report['terrainGroundRootEllipsoidM']
rect=report['certificate']['localBounds']
# Geographic clip outline: physical seam samples are interior to a genuine 1m DEM collar.
fig,axes=plt.subplots(1,2,figsize=(14.5,6.2),layout='constrained')
a=axes[0]
tri=a.tricontourf(v[:,0]*scale,v[:,1]*scale,(root+v[:,2]*scale),levels=26,cmap='terrain')
fig.colorbar(tri,ax=a,label='Ellipsoidische Bodenhöhe (m), ET/GRS80')
r=np.array(rect)*scale;a.plot([r[0],r[2],r[2],r[0],r[0]],[r[1],r[1],r[3],r[3],r[1]],color='#ff5e56',lw=2,label='Clipping-Polygon (geprüft)')
# R8 scan extents from real vertices, not a fictitious footprint.
sl=s[:,:2].min(axis=0)*scale;sh=s[:,:2].max(axis=0)*scale
a.plot([sl[0],sh[0],sh[0],sl[0],sl[0]],[sl[1],sl[1],sh[1],sh[1],sl[1]],lw=1.3,ls='--',color='#212121',label='R8-Scan-Grenzrahmen')
a.set(title='R11 · Vollflächige DGM1-Unterlage',xlabel='Lokales X (m)',ylabel='Lokales Y (m)',aspect='equal');a.legend(loc='lower left',fontsize=8)
# A measured elevation transect, not a reconstruction of original building floors.
b=axes[1]
y=0;sel=(np.abs(v[:,1]-y)<0.04)
x=v[sel,0]*scale;z=root+v[sel,2]*scale;ix=np.argsort(x)
b.plot(x[ix],z[ix],lw=2,color='#40916c',label='R11 DGM1/GCG2016 Unterlage')
# Original scan z within the lower part of the point cloud, far from roofs.
points=s[(np.abs(s[:,1]-y)<.10)&(s[:,2]>-2.7)&(s[:,2]<-1.6)]
if len(points):
 inds=np.linspace(0,len(points)-1,min(len(points),12000),dtype=int)
 b.scatter(points[inds,0]*scale,root+points[inds,2]*scale,s=2,alpha=.15,color='#6b5546',label='R8 untere Scan-Oberflächen (keine Geländeklassifikation)')
b.axvline(r[0],ls='--',lw=1,color='#ff5e56');b.axvline(r[2],ls='--',lw=1,color='#ff5e56')
b.set(title='Querschnitt durch y ≈ 0 (aus echten Modellen)',xlabel='Lokales X (m)',ylabel='Ellipsoidische Höhe (m)');b.legend(loc='upper right',fontsize=8)
# Licenses and provenance are in R11_README.md; keep axes unobstructed.
out=Path(__file__).parent/'R11_DGM1_Bodenvergleich.png';fig.savefig(out,dpi=170,bbox_inches='tight');plt.close(fig);print(out)
