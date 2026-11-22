#!/usr/bin/env python3
"""Run the photo-guided R19 preservation and paired-collider checks."""
import json,struct,hashlib,sys
from pathlib import Path
import numpy as np
from build_collision import AXIS,read_glb
from refine_ruedersdorf_r13 import get_accessor

def load(path):
    raw=Path(path).read_bytes();n=struct.unpack_from('<I',raw,12)[0]
    return json.loads(raw[20:20+n]),raw[28+n:]

def go(r18,r19,fpc,catalog):
    old,ob=load(r18);new,nb=load(r19)
    assert new['nodes'][0]==old['nodes'][0]
    assert len(new['meshes'])==len(old['meshes'])+1==23
    assert new['meshes'][-1]['name'].startswith('R19')
    for old_mesh,new_mesh in zip(old['meshes'][:15],new['meshes'][:15]):
        assert old_mesh['name']==new_mesh['name']
        for o,n in zip(old_mesh['primitives'],new_mesh['primitives']):
            assert o['material']==n['material']
            assert np.array_equal(get_accessor(old,ob,o['indices']),get_accessor(new,nb,n['indices']))
            for channel in o['attributes']:
                assert np.array_equal(get_accessor(old,ob,o['attributes'][channel]),get_accessor(new,nb,n['attributes'][channel]))
    # Validate old slabs have genuinely been removed from the R6 generated
    # primitive, instead of being visually concealed by transparent tanks.
    for mat in ('R12 r6_floor','R12 r6_concrete'):
        def count(doc,buf):
            for p in doc['meshes'][15]['primitives']:
                if doc['materials'][p['material']]['name']==mat:
                    return len(get_accessor(doc,buf,p['indices']))//3
        assert count(old,ob)>count(new,nb),mat
    v,t=read_glb(r19)
    data=Path(fpc).read_bytes();magic,nv,nt,nodes=struct.unpack_from('<4sIII',data)
    assert magic==b'FPC1' and nv==len(v) and nt<=len(t) and nt>=948000
    fv=np.frombuffer(data,dtype='<f4',count=nv*3,offset=16).reshape(-1,3)
    ft=np.frombuffer(data,dtype='<u4',count=nt*3,offset=16+nv*12).reshape(-1,3)
    assert np.array_equal(v,fv)
    assert np.array_equal(np.unique(np.sort(t,axis=1),axis=0),np.unique(np.sort(ft,axis=1),axis=0))
    item=next(c for c in json.loads(Path(catalog).read_text())['sceneries']
              if c['id']=='de-bb-ruedersdorf-chemical-plant')
    sha=hashlib.sha256(data).hexdigest()
    assert item['terrainCertificate']['collisionSha256']==sha
    assert len(item['terrainCertificates'])==16
    assert all(c['collisionSha256']==sha for c in item['terrainCertificates'])
    assert item['alignment']['scale']==16.023268178233355
    assert item['surveyVerified'] is False
    assert item['terrainUnderlay']['certificate']['collisionSha256']!=sha
    print(json.dumps(dict(status='passed',source_scan_meshes_preserved=15,
          visual_triangles=len(t),collider_unique_triangles=nt,
          collider_sha256=sha,certificates=16,registration_preserved=True),indent=2))

if __name__=='__main__':go(*sys.argv[1:])
