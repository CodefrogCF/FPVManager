#!/usr/bin/env python3
"""R20 -> R21 exact source preservation and finished visual=collision parity."""
from __future__ import annotations
import hashlib,json,struct,sys
from pathlib import Path
import numpy as np
from build_collision import AXIS, read_glb
from refine_ruedersdorf_r13 import get_accessor


def load(path):
    raw=Path(path).read_bytes();length=struct.unpack_from('<I',raw,12)[0]
    return json.loads(raw[20:20+length]),raw[28+length:]


def check(source,glb,fpc,catalog):
    old,ob=load(source);new,nb=load(glb)
    assert len(new['meshes'])==25 and len(old['meshes'])==24
    assert old['nodes'][0]==new['nodes'][0]
    assert new['meshes'][-1]['name'].startswith('R21')
    for i in list(range(15))+[23]:  # scanned originals and R20 outdoor platform
        a,b=old['meshes'][i],new['meshes'][i]
        assert a['name']==b['name'] and len(a['primitives'])==len(b['primitives'])
        for pa,pb in zip(a['primitives'],b['primitives']):
            assert pa['material']==pb['material']
            assert np.array_equal(get_accessor(old,ob,pa['indices']),get_accessor(new,nb,pb['indices']))
            for key in pa['attributes']:
                assert np.array_equal(get_accessor(old,ob,pa['attributes'][key]),get_accessor(new,nb,pb['attributes'][key]))
    def counts(doc,buf,mat):
        return {name:sum(len(get_accessor(doc,buf,pr['indices']))//3
                    for pr in doc['meshes'][15]['primitives']
                    if doc['materials'][pr['material']]['name']==name)
                for name in mat}
    # The obsolete inclined R6 roof box was removed from generated geometry;
    # original scanned geometry outside R6 remains untouched.
    mats=('R12 r6_roof','R12 r6_concrete')
    a=counts(old,ob,mats);b=counts(new,nb,mats)
    assert a['R12 r6_roof']==b['R12 r6_roof']+2
    assert a['R12 r6_concrete']==b['R12 r6_concrete']+10
    # Short R18 gallery mesh steel primitive completely eliminated; concrete
    # curved roof ribs retained, no empty accessors in GLB.
    assert len(new['meshes'][21]['primitives'])==1
    assert new['meshes'][21]['primitives'][0]['material']==old['meshes'][21]['primitives'][0]['material']
    vs,faces=read_glb(glb)
    raw=Path(fpc).read_bytes();magic,nv,nt,_=struct.unpack_from('<4sIII',raw)
    assert magic==b'FPC1' and nv==len(vs) and nt<=len(faces)
    v=np.frombuffer(raw,dtype='<f4',count=nv*3,offset=16).reshape(-1,3)
    t=np.frombuffer(raw,dtype='<u4',count=nt*3,offset=16+nv*12).reshape(-1,3)
    assert np.array_equal(v,vs)
    assert np.array_equal(np.unique(np.sort(faces,axis=1),axis=0),np.unique(np.sort(t,axis=1),axis=0))
    d=json.loads(Path(catalog).read_text());scene=next(i for i in d['sceneries'] if i['id']=='de-bb-ruedersdorf-chemical-plant')
    sha=hashlib.sha256(raw).hexdigest()
    assert scene['terrainCertificate']['collisionSha256']==sha
    assert all(c['collisionSha256']==sha for c in scene['terrainCertificates'])
    assert len(scene['terrainCertificates'])==16
    assert scene['alignment']['rotationDeg']==99.7993823133657
    assert scene['surveyVerified'] is False
    assert scene['terrainUnderlay']['certificate']['collisionSha256']!=sha
    print(json.dumps({'passed':True,'original_scan_meshes_intact':15,'R20_platform_mesh_identical':True,
          'removed_old_east_roof_box_faces':12,'roof_rib_mesh_retained':True,
          'visual_faces':len(faces),'unique_collider_faces':nt,'fpc_sha256':sha},indent=2))

if __name__=='__main__':check(*sys.argv[1:])
