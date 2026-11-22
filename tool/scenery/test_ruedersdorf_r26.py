#!/usr/bin/env python3
"""R26 raw-scan replacement, geometry and matching collision mesh regression."""
from __future__ import annotations
import hashlib
import json
import struct
import sys
from pathlib import Path

import numpy as np
from build_collision import AXIS, read_glb
from refine_ruedersdorf_r13 import get_accessor
from refine_ruedersdorf_r25 import cut_mesh
from refine_ruedersdorf_r26 import SOUTHWEST_CUT


def ray_hit(tris, low, high, start, end):
    a=np.array(start,dtype=np.float64)
    b=np.array(end,dtype=np.float64);d=b-a
    cand=np.all((high>=np.minimum(a,b)-1e-6)&(low<=np.maximum(a,b)+1e-6),axis=1)
    t=tris[cand]
    if not len(t):return False
    e1=t[:,1]-t[:,0];e2=t[:,2]-t[:,0]
    p=np.cross(np.broadcast_to(d,e2.shape),e2)
    det=np.einsum('ij,ij->i',e1,p)
    good=np.abs(det)>1e-10
    inv=np.zeros(len(t));inv[good]=1/det[good]
    delta=a-t[:,0]
    u=np.einsum('ij,ij->i',delta,p)*inv
    q=np.cross(delta,e1)
    v=np.einsum('j,ij->i',d,q)*inv
    step=np.einsum('ij,ij->i',e2,q)*inv
    return bool(np.any(good&(u>=-1e-6)&(v>=-1e-6)&(u+v<=1+1e-6)&
                       (step>=0)&(step<=1)))


def main(glb,fpc,report):
    raw=Path(glb).read_bytes()
    col=Path(fpc).read_bytes()
    rpt=json.loads(Path(report).read_text())
    assert rpt['revision']=='R26'
    assert hashlib.sha256(raw).hexdigest()==rpt['glb_sha256']
    assert hashlib.sha256(col).hexdigest()==rpt['fpc_sha256']
    v,t=read_glb(glb)
    magic,nv,nt,_=struct.unpack_from('<4sIII',col)
    assert magic==b'FPC1' and nv==len(v)
    assert nt==len(np.unique(np.sort(t,axis=1),axis=0))
    assert np.array_equal(np.frombuffer(col,dtype='<f4',count=nv*3,offset=16).reshape(-1,3),v)
    faces=np.frombuffer(col,dtype='<u4',count=nt*3,offset=16+nv*12).reshape(-1,3)
    assert np.array_equal(np.unique(np.sort(faces,axis=1),axis=0),
                          np.unique(np.sort(t,axis=1),axis=0))

    n=struct.unpack_from('<I',raw,12)[0]
    doc=json.loads(raw[20:20+n]);buf=bytearray(raw[28+n:])
    assert len(doc['meshes'])==30
    assert all(doc['meshes'][i]['name'].startswith('Object_') for i in range(15))
    assert doc['meshes'][-1]['name'].startswith('R26')

    root=np.asarray(doc['nodes'][0]['matrix']).reshape(4,4,order='F')[:3,:3]
    x0,x1,y0,y1,z0,z1=SOUTHWEST_CUT
    scan_residuals=0
    for mesh in doc['meshes'][:15]:
        for prim in mesh['primitives']:
            pos=(get_accessor(doc,buf,prim['attributes']['POSITION'])@root.T)@AXIS.T
            tris=get_accessor(doc,buf,prim['indices']).reshape(-1,3)
            center=pos[tris].mean(1)
            scan_residuals+=int(np.count_nonzero(
                (center[:,0]>x0+1e-4)&(center[:,0]<x1-1e-4)&
                (center[:,1]>y0+1e-4)&(center[:,1]<y1-1e-4)&
                (center[:,2]>z0+1e-4)&(center[:,2]<z1-1e-4)))
    assert scan_residuals==0, f'Original scan still inside rebuilt annex: {scan_residuals}'
    assert rpt['original_scan_triangles_fully_removed']>=5000
    assert rpt['old_procedural_triangles_fully_removed']>=500

    # Use the actual FPC triangle soup, not a procedural geometry-only proxy.
    collision_tri=v[faces].astype(np.float64)
    lo=collision_tri.min(1);hi=collision_tri.max(1)
    cases=[
        ('front entrance 1', (2.90,-5.01,-1.82),(2.90,-4.89,-1.82),False),
        ('front entrance 2', (3.65,-5.01,-1.82),(3.65,-4.89,-1.82),False),
        ('front solid wall', (2.62,-5.01,-1.82),(2.62,-4.89,-1.82),True),
        ('front broken window',(3.29,-5.01,-1.56),(3.29,-4.89,-1.56),False),
        ('solid below window',(3.29,-5.01,-1.75),(3.29,-4.89,-1.75),True),
        ('rear entrance',(2.83,-4.64,-1.82),(2.83,-4.54,-1.82),False),
        ('rear solid wall',(3.18,-4.64,-1.82),(3.18,-4.54,-1.82),True),
        ('west side exit',(2.46,-4.77,-1.83),(2.54,-4.77,-1.83),False),
        ('west side wall',(2.46,-4.63,-1.83),(2.54,-4.63,-1.83),True),
        ('damaged roof gap',(3.17,-4.75,-1.45),(3.17,-4.75,-1.24),False),
        ('remaining roof patch',(2.62,-4.75,-1.45),(2.62,-4.75,-1.24),True),
        ('surviving upper floor',(2.72,-4.67,-1.73),(2.72,-4.67,-1.60),True),
        ('open middle volume',(3.27,-4.77,-1.73),(3.27,-4.77,-1.60),False),
    ]
    for label,a,b,expected in cases:
        actual=ray_hit(collision_tri,lo,hi,a,b)
        assert actual==expected, f'{label}: collision={actual}, expected={expected}'
    # R25 doors/windows remain free after altering a different building.
    previous=[
        ('R25 northwest entry',(-4.18,5.70,-1.85),(-4.18,5.82,-1.85),False),
        ('R25 northwest window',(-4.40,5.70,-1.52),(-4.40,5.81,-1.52),False),
        ('R25 northwest wall',(-4.36,5.70,-1.85),(-4.36,5.82,-1.85),True),
        ('R25 east entry',(4.24,1.87,-1.79),(4.46,1.87,-1.79),False),
        ('R25 east wall',(4.24,1.60,-1.79),(4.46,1.60,-1.79),True),
        ('R25 east skylight',(4.58,1.65,-.93),(4.58,1.65,-.72),False),
    ]
    for label,a,b,expected in previous:
        assert ray_hit(collision_tri,lo,hi,a,b)==expected,label
    print(f'R26 PASS: {len(cases)+len(previous)} collision rays, '
          f'{rpt["original_scan_triangles_fully_removed"]} raw triangles removed, '
          f'no old scan inside replacement, GLB/FPC match')


if __name__=='__main__':main(*sys.argv[1:])
