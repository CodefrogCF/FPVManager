#!/usr/bin/env python3
"""R22: preserve all previous meshes, correct orientation and GLB/FPC parity."""
from __future__ import annotations
import hashlib,json,struct,sys
from pathlib import Path
import numpy as np
from build_collision import AXIS,read_glb
from refine_ruedersdorf_r13 import get_accessor
from refine_ruedersdorf_r22 import WEST_STEPS,NORTH_OUTBUILDINGS,CENTER_UTILITY

def load(p):
    b=Path(p).read_bytes();n=struct.unpack_from('<I',b,12)[0]
    return json.loads(b[20:20+n]),b[28+n:]

def check(source,glb,fpc,catalog):
    old,ob=load(source);new,nb=load(glb)
    assert len(old['meshes'])==25 and len(new['meshes'])==26
    assert new['meshes'][-1]['name'].startswith('R22')
    assert old['nodes'][0]==new['nodes'][0]
    assert old['scenes'][old.get('scene',0)]['nodes']==new['scenes'][new.get('scene',0)]['nodes'][:-1]
    for i in range(25):
        a,b=old['meshes'][i],new['meshes'][i]
        assert a['name']==b['name'] and len(a['primitives'])==len(b['primitives']),i
        for pa,pb in zip(a['primitives'],b['primitives']):
            assert pa['material']==pb['material'],i
            assert np.array_equal(get_accessor(old,ob,pa['indices']),get_accessor(new,nb,pb['indices'])),i
            for key in pa['attributes']:
                assert np.array_equal(get_accessor(old,ob,pa['attributes'][key]),get_accessor(new,nb,pb['attributes'][key])),(i,key)
    # R22 appended materials only at independently scanned building footprints.
    pts=[]
    for p in new['meshes'][-1]['primitives']:
        pts.append(get_accessor(new,nb,p['attributes']['POSITION'])@AXIS.T)
    pts=np.concatenate(pts)
    allowed=[*WEST_STEPS,*NORTH_OUTBUILDINGS,CENTER_UTILITY]
    covered=np.zeros(len(pts),dtype=bool)
    for x0,x1,y0,y1,z0,z1 in allowed:
        # Tiny out-of-footprint roof decorations are intentionally disallowed.
        inside=(pts[:,0]>=x0-.03)&(pts[:,0]<=x1+.03)&(pts[:,1]>=y0-.03)&(pts[:,1]<=y1+.03)&(pts[:,2]>=z0-.04)&(pts[:,2]<=z1+.11)
        covered|=inside
    assert covered.all(),('R22 vertices outside scanned annex footprints',pts[~covered][:8])
    v,t=read_glb(glb);raw=Path(fpc).read_bytes();magic,nv,nt,_=struct.unpack_from('<4sIII',raw)
    assert magic==b'FPC1' and nv==len(v) and nt==len(np.unique(np.sort(t,axis=1),axis=0))
    fv=np.frombuffer(raw,dtype='<f4',count=nv*3,offset=16).reshape(-1,3)
    ft=np.frombuffer(raw,dtype='<u4',count=nt*3,offset=16+nv*12).reshape(-1,3)
    assert np.array_equal(v,fv)
    assert np.array_equal(np.unique(np.sort(t,axis=1),axis=0),np.unique(np.sort(ft,axis=1),axis=0))
    sc=next(s for s in json.loads(Path(catalog).read_text())['sceneries'] if s['id']=='de-bb-ruedersdorf-chemical-plant')
    sha=hashlib.sha256(raw).hexdigest()
    assert sc['terrainCertificate']['collisionSha256']==sha
    assert len(sc['terrainCertificates'])==16 and all(c['collisionSha256']==sha for c in sc['terrainCertificates'])
    assert sc['terrainUnderlay']['certificate']['collisionSha256']!=sha
    assert sc['alignment']['scale']==16.023268178233355
    assert sc['alignment']['rotationDeg']==99.7993823133657
    assert sc['surveyVerified'] is False
    print(json.dumps({'passed':True,'original_25_meshe_exactly_preserved':True,
        'scanned_roof_footprints_respected':True,'georeference_unchanged':True,
        'triangle_count':len(t),'fpc_unique_triangle_count':nt,'new_geometry_vertices':len(pts),
        'fpc_sha256':sha},indent=2))

if __name__=='__main__':check(*sys.argv[1:])
