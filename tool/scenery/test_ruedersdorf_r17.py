#!/usr/bin/env python3
"""R17 visual/FPC parity and preservation checks (run after refining)."""
import hashlib
import json
import struct
import sys
from pathlib import Path
import numpy as np
from build_collision import AXIS,read_glb
from refine_ruedersdorf_r13 import get_accessor


def read(path):
    contents=Path(path).read_bytes()
    n=struct.unpack_from('<I',contents,12)[0]
    return json.loads(contents[20:20+n]),memoryview(contents)[28+n:]


def test(old_glb,new_glb,collision,catalog):
    original,obuf=read(old_glb);current,cbuf=read(new_glb)
    assert original['nodes'][0]==current['nodes'][0], 'Registration must remain unchanged'
    assert len(current['meshes'])==len(original['meshes'])+1
    assert current['meshes'][-1]['name'].startswith('R17')
    assert len(original['meshes'])>=20
    # Photogrammetric source meshes must be byte-exact, after repacking.
    for before,after in zip(original['meshes'][:15],current['meshes'][:15]):
        assert before['name']==after['name']
        for a,b in zip(before['primitives'],after['primitives']):
            assert a['material']==b['material']
            for channel in a['attributes']:
                assert np.array_equal(get_accessor(original,obuf,a['attributes'][channel]),
                                      get_accessor(current,cbuf,b['attributes'][channel]))
            assert np.array_equal(get_accessor(original,obuf,a['indices']),
                                  get_accessor(current,cbuf,b['indices']))
    vertices,triangles=read_glb(new_glb)
    data=Path(collision).read_bytes()
    magic,nv,nt,nnodes=struct.unpack_from('<4sIII',data)
    assert magic==b'FPC1' and nv==len(vertices)
    fv=np.frombuffer(data,dtype='<f4',count=nv*3,offset=16).reshape(-1,3)
    ft=np.frombuffer(data,dtype='<u4',count=nt*3,offset=16+nv*12).reshape(-1,3)
    assert np.array_equal(vertices,fv)
    assert np.array_equal(np.unique(np.sort(ft,axis=1),axis=0),
                          np.unique(np.sort(triangles,axis=1),axis=0))
    assert nt<=945000, 'R17 should not add an excessive number of faces'
    item=next(s for s in json.loads(Path(catalog).read_text())['sceneries']
              if s['id']=='de-bb-ruedersdorf-chemical-plant')
    digest=hashlib.sha256(data).hexdigest()
    assert item['terrainCertificate']['collisionSha256']==digest
    assert len(item['terrainCertificates'])==16
    assert all(c['collisionSha256']==digest for c in item['terrainCertificates'])
    assert item['alignment']['scale']==16.023268178233355
    assert item['alignment']['rotationDeg']==99.7993823133657
    assert item['surveyVerified'] is False
    print(json.dumps({'result':'passed','photogrammetric_meshes_preserved':15,
        'visual_triangles':len(triangles),'collision_triangles':nt,
        'collision_sha256':digest,'certified_patches':16,
        'source_alignment_preserved':True},indent=2))


if __name__=='__main__':
    test(*sys.argv[1:])
