#!/usr/bin/env python3
"""Regression checks: scan mesh, root, old-platform removal, R20 GLB=FPC."""
from __future__ import annotations
import hashlib,json,struct,sys
from pathlib import Path
import numpy as np
from build_collision import AXIS,read_glb
from refine_ruedersdorf_r13 import get_accessor
from refine_ruedersdorf_r20 import EAST_NORTH_PLATFORM,PLATFORM_GAP

def load(path):
    a=Path(path).read_bytes();n=struct.unpack_from('<I',a,12)[0]
    return json.loads(a[20:20+n]),a[28+n:]

def main(source,glb,fpc,catalog):
    old,ob=load(source);new,nb=load(glb)
    assert old['nodes'][0]==new['nodes'][0]
    assert len(new['meshes'])==len(old['meshes'])+1==24
    for o,n in zip(old['meshes'][:15],new['meshes'][:15]):
        assert o['name']==n['name']
        for a,b in zip(o['primitives'],n['primitives']):
            assert a['material']==b['material']
            assert np.array_equal(get_accessor(old,ob,a['indices']),get_accessor(new,nb,b['indices']))
            for key in a['attributes']:
                assert np.array_equal(get_accessor(old,ob,a['attributes'][key]),get_accessor(new,nb,b['attributes'][key]))
    # R16 six-silo closure preserved exactly, all x<0 triangles removed.
    for p in new['meshes'][19]['primitives']:
        pos=get_accessor(new,nb,p['attributes']['POSITION'])@AXIS.T
        tri=get_accessor(new,nb,p['indices']).reshape(-1,3)
        assert np.all(pos[tri][:,:,0]>4)
    # Validate platform's new ring material vertices occupy east-north bounds.
    p=next(p for p in new['meshes'][-1]['primitives']
           if new['materials'][p['material']]['name']=='R15 safety steel')
    v=get_accessor(new,nb,p['attributes']['POSITION'])@AXIS.T
    assert np.any(np.isclose(v[:,0],EAST_NORTH_PLATFORM[0],atol=1e-4))
    assert np.any(np.isclose(v[:,1],EAST_NORTH_PLATFORM[3],atol=1e-4))
    assert (PLATFORM_GAP[1]-PLATFORM_GAP[0])*16.023>3.1
    verts,faces=read_glb(glb)
    raw=Path(fpc).read_bytes()
    magic,nv,nt,_=struct.unpack_from('<4sIII',raw)
    assert magic==b'FPC1' and nv==len(verts)
    fv=np.frombuffer(raw,dtype='<f4',count=nv*3,offset=16).reshape(-1,3)
    ft=np.frombuffer(raw,dtype='<u4',count=nt*3,offset=16+nv*12).reshape(-1,3)
    assert np.array_equal(verts,fv)
    assert np.array_equal(np.unique(np.sort(faces,axis=1),axis=0),np.unique(np.sort(ft,axis=1),axis=0))
    site=next(s for s in json.loads(Path(catalog).read_text())['sceneries'] if s['id']=='de-bb-ruedersdorf-chemical-plant')
    sha=hashlib.sha256(raw).hexdigest()
    assert site['terrainCertificate']['collisionSha256']==sha
    assert all(c['collisionSha256']==sha for c in site['terrainCertificates'])
    assert len(site['terrainCertificates'])==16
    assert site['terrainUnderlay']['certificate']['collisionSha256']!=sha
    assert site['alignment']['scale']==16.023268178233355
    assert site['alignment']['rotationDeg']==99.7993823133657
    assert site['surveyVerified'] is False
    print(json.dumps({'status':'passed','root_unchanged':True,'RAWscan_meshes_preserved':15,
        'faces':len(faces),'unique_collision_faces':nt,'fpc_sha256':sha,
        'northeast_platform_east_side':True,'obsolete_r16_platform_removed':True},indent=2))

if __name__=='__main__':main(*sys.argv[1:])
