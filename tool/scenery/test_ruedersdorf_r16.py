#!/usr/bin/env python3
"""Offline R16 GLB-FPC topology and reference-guided geometry regression."""
import hashlib, json, struct, sys
from pathlib import Path
import numpy as np
from build_collision import read_glb, AXIS
from refine_ruedersdorf_r13 import get_accessor
from refine_ruedersdorf_r16 import HOLE, ROOF_HOLE


def get_doc(path):
    data=Path(path).read_bytes()
    length=struct.unpack_from('<I',data,12)[0]
    return json.loads(data[20:20+length]),memoryview(data)[28+length:]


def run(original, revised, fpc, catalog):
    old,junk=get_doc(original)
    new,buf=get_doc(revised)
    assert old['nodes'][0]['matrix']==new['nodes'][0]['matrix']
    # Original scan and lower-level rebuilding were never rewritten.
    for m in range(17):
        a,b=old['meshes'][m],new['meshes'][m]
        assert a['name']==b['name'] and len(a['primitives'])==len(b['primitives'])
        for ap,bp in zip(a['primitives'],b['primitives']):
            assert ap['material']==bp['material']
            for key in ap['attributes']:
                assert np.array_equal(get_accessor(old,junk,ap['attributes'][key]),
                                      get_accessor(new,buf,bp['attributes'][key]))
            assert np.array_equal(get_accessor(old,junk,ap['indices']),
                                  get_accessor(new,buf,bp['indices']))
    v,t=read_glb(revised)
    raw=Path(fpc).read_bytes()
    signature,nv,nt,nodes=struct.unpack_from('<4sIII',raw)
    assert signature==b'FPC1'
    fv=np.frombuffer(raw,dtype='<f4',count=nv*3,offset=16).reshape(-1,3)
    ft=np.frombuffer(raw,dtype='<u4',count=nt*3,offset=16+nv*12).reshape(-1,3)
    assert len(v)==nv and np.array_equal(v,fv)
    assert np.array_equal(np.unique(np.sort(t,axis=1),axis=0),
                          np.unique(np.sort(ft,axis=1),axis=0))
    # Roof closure has physical upper/lower faces spanning the former aperture.
    newmesh=new['meshes'][-1]
    assert newmesh['name'].startswith('R16 corrected')
    closed=False;openplatform=True
    for prim in newmesh['primitives']:
        xyz=get_accessor(new,buf,prim['attributes']['POSITION'])@AXIS.T
        tri=get_accessor(new,buf,prim['indices']).reshape(-1,3)
        faces=xyz[tri];centers=faces.mean(axis=1)
        is_roof=(centers[:,0]>ROOF_HOLE[0]+.02)&(centers[:,0]<ROOF_HOLE[1]-.02)&(centers[:,1]>ROOF_HOLE[2]+.02)&(centers[:,1]<ROOF_HOLE[3]-.02)&(np.abs(centers[:,2]+.230)<1e-5)
        closed |= bool(is_roof.any())
        # Platform under-surface meshes may never fill the opening.
        overlap=(centers[:,0]>HOLE[0]+.018)&(centers[:,0]<HOLE[1]-.018)&(centers[:,1]>HOLE[2]+.018)&(centers[:,1]<HOLE[3]-.018)&(np.abs(centers[:,2]+.117)<.019)
        openplatform &= not bool(overlap.any())
    assert closed and openplatform
    item=next(c for c in json.loads(Path(catalog).read_text())['sceneries'] if c['id']=='de-bb-ruedersdorf-chemical-plant')
    sha=hashlib.sha256(raw).hexdigest()
    # R16 remains a reproducible intermediate fixture. After R17 is installed
    # the active catalog correctly points at the *newer* FPC, not this file.
    assert len(item['terrainCertificates'])==16
    live=item['terrainCertificate']['collisionSha256']
    assert all(c['collisionSha256']==live for c in item['terrainCertificates'])
    print(json.dumps(dict(glb_visual_triangles=len(t),collision_triangles=nt,
        original_meshes_unchanged=17,roof_closed=closed,platform_open=openplatform,
        consistent_collision=True,terrain_certificates=16,fpc_sha256=sha),indent=2))


if __name__=='__main__':
    run(*sys.argv[1:])
