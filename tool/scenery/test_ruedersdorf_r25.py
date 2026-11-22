#!/usr/bin/env python3
"""R25 scan replacement and collider opening regression tests."""
import hashlib,json,struct,sys
from pathlib import Path
import numpy as np
from build_collision import AXIS,read_glb
from refine_ruedersdorf_r13 import get_accessor
from refine_ruedersdorf_r25 import NW_CUT

def ray_hit(tris,low,high,start,end):
    a=np.array(start,dtype=np.float64);b=np.array(end,dtype=np.float64);d=b-a
    chosen=np.all((high>=np.minimum(a,b)-1e-6)&(low<=np.maximum(a,b)+1e-6),axis=1)
    tri=tris[chosen]
    if not len(tri):return False
    e1=tri[:,1]-tri[:,0];e2=tri[:,2]-tri[:,0]
    p=np.cross(np.broadcast_to(d,e2.shape),e2)
    determinant=np.einsum('ij,ij->i',e1,p)
    good=np.abs(determinant)>1e-10
    inv=np.zeros(len(tri));inv[good]=1/determinant[good]
    tv=a-tri[:,0];u=np.einsum('ij,ij->i',tv,p)*inv
    q=np.cross(tv,e1);w=np.einsum('j,ij->i',d,q)*inv
    travel=np.einsum('ij,ij->i',e2,q)*inv
    return bool(np.any(good&(u>=-1e-6)&(w>=-1e-6)&(u+w<=1+1e-6)&(travel>=0)&(travel<=1)))

def main(glb,fpc,report):
    raw=Path(glb).read_bytes();data=json.loads(Path(report).read_text())
    assert hashlib.sha256(raw).hexdigest()==data['glb_sha256']
    col=Path(fpc).read_bytes();assert hashlib.sha256(col).hexdigest()==data['fpc_sha256']
    v,t=read_glb(glb)
    magic,nv,nt,_=struct.unpack_from('<4sIII',col)
    assert magic==b'FPC1' and nv==len(v) and nt==len(np.unique(np.sort(t,axis=1),axis=0))
    assert np.array_equal(np.frombuffer(col,dtype='<f4',count=nv*3,offset=16).reshape(-1,3),v)
    num=struct.unpack_from('<I',raw,12)[0];doc=json.loads(raw[20:20+num]);buf=bytearray(raw[28+num:])
    root=np.asarray(doc['nodes'][0]['matrix']).reshape(4,4,order='F')[:3,:3]
    a,b,c,d,e,f=NW_CUT;hidden=0
    for mesh in doc['meshes'][:15]:
        for pr in mesh['primitives']:
            p=(get_accessor(doc,buf,pr['attributes']['POSITION'])@root.T)@AXIS.T
            ix=get_accessor(doc,buf,pr['indices']).reshape(-1,3)
            cen=p[ix].mean(1)
            hidden+=int(np.count_nonzero((cen[:,0]>a+1e-4)&(cen[:,0]<b-1e-4)&
                (cen[:,1]>c+1e-4)&(cen[:,1]<d-1e-4)&
                (cen[:,2]>e+1e-4)&(cen[:,2]<f-1e-4)))
    assert hidden==0,('original scan remains in building',hidden)
    removed=sum(x['removed_fully'] for x in data['scan_cut'].values())
    assert removed>=3000
    tri=v[t].astype(np.float64);low=tri.min(1);high=tri.max(1)
    tests=[
        ('northwest entrance',(-4.18,5.70,-1.85),(-4.18,5.82,-1.85),False),
        ('northwest wall',(-4.36,5.70,-1.85),(-4.36,5.82,-1.85),True),
        ('northwest window',(-4.40,5.70,-1.52),(-4.40,5.81,-1.52),False),
        ('northwest window wall',(-4.40,5.70,-1.70),(-4.40,5.81,-1.70),True),
        ('northwest hatch',(-4.22,5.94,-1.37),(-4.22,5.94,-1.13),False),
        ('northwest roof',(-4.40,5.94,-1.37),(-4.40,5.94,-1.13),True),
        ('east entrance',(4.24,1.87,-1.79),(4.46,1.87,-1.79),False),
        ('east facade',(4.24,1.60,-1.79),(4.46,1.60,-1.79),True),
        ('east skylight',(4.58,1.65,-.93),(4.58,1.65,-.72),False),
        ('east roof',(4.83,1.65,-.93),(4.83,1.65,-.72),True),
    ]
    for name,p0,p1,expected in tests:
        result=ray_hit(tri,low,high,p0,p1)
        if result!=expected:raise AssertionError(f'{name}: collision {result}, expected {expected}')
    print(f'R25 PASS: {removed} original scan triangles replaced; no scan residues in building; {len(tests)} collision rays')

if __name__=='__main__':main(*sys.argv[1:])
