#!/usr/bin/env python3
"""R29 structural regression: exact GLB/FPC matching and restored raw source."""
from __future__ import annotations
import hashlib,json,struct,sys
from pathlib import Path
import numpy as np
sys.path.insert(0,'tool/scenery')
from build_collision import AXIS, read_glb
from refine_ruedersdorf_r13 import get_accessor

GLB=Path('web/assets/scenery/local_reference.glb')
FPC=Path('web/assets/scenery/local_reference.fpc')
CATALOG=Path('web/assets/scenery/catalog.json')
REPORT=Path('tool/scenery/r29/refinement_R29_report.json')


def main():
    report=json.loads(REPORT.read_text())
    assert report['revision']=='R29'
    assert report['restored_original_triangles']>25000
    assert len(report['restored_meshes'])==15
    assert report['original_material_0_retained']
    raw=GLB.read_bytes();n=struct.unpack_from('<I',raw,12)[0]
    doc=json.loads(raw[20:20+n]); buf=bytearray(raw[28+n:])
    assert all(m['primitives'] for m in doc['meshes']), 'Empty glTF mesh'
    assert any(m['name'].startswith('R24 screenshot-guided') for m in doc['meshes'])
    assert not any(m['name'].startswith('R28.2 platform attachment') for m in doc['meshes'])
    assert doc['meshes'][0]['primitives'][-1]['material']==0
    assert len(doc['meshes'][0]['primitives'])>=2
    heights=[]
    R=AXIS@np.array(doc['nodes'][0]['matrix']).reshape(4,4,order='F')[:3,:3]
    for m in doc['meshes'][:15]:
        for p in m['primitives']:
            if p['material']!=0:continue
            pos=get_accessor(doc,buf,p['attributes']['POSITION'])@R.T
            idx=get_accessor(doc,buf,p['indices']).reshape(-1,3)
            c=pos[idx].mean(1)
            q=(c[:,0]>-4.235)&(c[:,0]<-2.705)&(c[:,1]>1.812)&(c[:,1]<3.290)&(c[:,2]>-1.5)
            heights.extend(c[q,2].tolist())
    assert len(heights)>=3000, f'Original roof/walls still missing: {len(heights)} faces'
    v,t=read_glb(GLB)
    blob=FPC.read_bytes()
    magic,nv,nt,nodes=struct.unpack_from('<4sIII',blob)
    assert magic==b'FPC1' and nv==len(v) and nt==len(np.unique(np.sort(t,axis=1),axis=0))
    xyz=np.frombuffer(blob,dtype='<f4',count=nv*3,offset=16).reshape(-1,3)
    assert np.array_equal(v,xyz),'GLB/FPC vertex mismatch'
    sha=hashlib.sha256(blob).hexdigest()
    item=json.loads(CATALOG.read_text())['sceneries'][0]
    assert item['terrainCertificate']['collisionSha256']==sha
    assert all(c['collisionSha256']==sha for c in item['terrainCertificates'])
    print(json.dumps({'restored_triangles':report['restored_original_triangles'],
          'scanned_high_roof_wall_triangles':len(heights),
          'collision_triangles':nt,'terrain_certificates':len(item['terrainCertificates'])},indent=2))


if __name__=='__main__':main()
