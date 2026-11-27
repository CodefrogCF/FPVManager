#!/usr/bin/env python3
"""R34 south-building restoration geometry and collision regression."""
import hashlib,json,struct,sys
from pathlib import Path
import numpy as np
sys.path.insert(0,'tool/scenery')
from build_collision import AXIS, read_glb
from refine_ruedersdorf_r13 import get_accessor

GLB=Path('web/assets/scenery/local_reference.glb')
FPC=Path('web/assets/scenery/local_reference.fpc')
CAT=Path('web/assets/scenery/catalog.json')
REP=Path('tool/scenery/r34/refinement_R34_report.json')


def test():
    r=json.loads(REP.read_text())
    assert r['revision']=='R34'
    assert r['restored_south_building_triangles']==2328
    assert r['restored_r27_green_roof'] is False
    assert r['northern_original_scan_unchanged'] is True
    blob=GLB.read_bytes(); length=struct.unpack_from('<I',blob,12)[0]
    doc=json.loads(blob[20:20+length]); buf=blob[28+length:]
    assert len(doc['meshes'])==29
    assert not any('R27 courtyard forebuilding' in m['name'] for m in doc['meshes'])
    mesh=doc['meshes'][r['corrected_mesh_id']]
    assert mesh['name'].startswith('R25 first genuinely replaced scan')
    assert sum(get_accessor(doc,buf,p['indices']).size for p in mesh['primitives'])//3==3696
    # All south-building geometry is local +X (south) and +Y (east).
    # The north original source building is at negative local X and unrelated.
    restored=0
    for p in mesh['primitives']:
        pos=get_accessor(doc,buf,p['attributes']['POSITION'])@AXIS.T
        faces=get_accessor(doc,buf,p['indices']).reshape(-1,3)
        centroids=pos[faces].mean(axis=1)
        mask=((centroids[:,0]>4.29)&(centroids[:,0]<5.48)&
              (centroids[:,1]>.99)&(centroids[:,1]<2.76)&
              (centroids[:,2]>-2.012)&(centroids[:,2]<-.745))
        restored+=int(mask.sum())
    assert restored==2328,restored
    v,t=read_glb(GLB)
    f=FPC.read_bytes();magic,nv,nt,_=struct.unpack_from('<4sIII',f)
    assert magic==b'FPC1'
    assert nv==len(v)
    assert nt==len(np.unique(np.sort(t,axis=1),axis=0))
    # Later revisions may selectively remove unrelated north-gantry geometry.
    assert np.array_equal(v,np.frombuffer(f,dtype='<f4',count=nv*3,offset=16).reshape(-1,3))
    sha=hashlib.sha256(f).hexdigest()
    assert sha==json.loads(Path('tool/scenery/r35/refinement_R35_report.json').read_text())['fpc_sha256']
    catalog=json.loads(CAT.read_text())['sceneries'][0]
    assert catalog['bkgHeightOffsetM']==0
    assert len(catalog['terrainCertificates'])==15
    assert all(c['collisionSha256']==sha for c in catalog['terrainCertificates'])
    assert catalog['terrainCertificate']['collisionSha256']==sha
    print(json.dumps({'revision':'R34','restored_south_triangles':restored,
           'collision_triangles':nt,'bkg_offset':catalog['bkgHeightOffsetM']},indent=2))

if __name__=='__main__':test()
