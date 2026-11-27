#!/usr/bin/env python3
"""R35: removed only the R24 gantry; original scan and south building remain."""
import hashlib,json,struct,sys
from pathlib import Path
import numpy as np
sys.path.insert(0,'tool/scenery')
from build_collision import AXIS, read_glb
from refine_ruedersdorf_r13 import get_accessor
from remove_ruedersdorf_r35_north_gantry import GANTRY_REMOVE, R24_MESH_NAME

GLB=Path('web/assets/scenery/local_reference.glb')
FPC=Path('web/assets/scenery/local_reference.fpc')
CAT=Path('web/assets/scenery/catalog.json')
REPORT=Path('tool/scenery/r35/refinement_R35_report.json')

def main():
 rep=json.loads(REPORT.read_text())
 assert rep['revision']=='R35' and rep['removed_north_gantry_triangles']==190
 raw=GLB.read_bytes();n=struct.unpack_from('<I',raw,12)[0]
 doc=json.loads(raw[20:20+n]);buffer=raw[28+n:]
 assert len(doc['meshes'])==29
 assert sum(1 for m in doc['meshes'] if m['name']==R24_MESH_NAME)==1
 assert len(doc['meshes'][rep['corrected_mesh_id']]['primitives'])==2
 assert rep['glb_sha256']==hashlib.sha256(raw).hexdigest()
 x0,x1,y0,y1,z0,z1=GANTRY_REMOVE
 inside=0
 for prim in doc['meshes'][rep['corrected_mesh_id']]['primitives']:
  xyz=get_accessor(doc,buffer,prim['attributes']['POSITION'])@AXIS.T
  faces=get_accessor(doc,buffer,prim['indices']).reshape(-1,3)
  ctr=xyz[faces].mean(1)
  inside+=int(((ctr[:,0]>x0)&(ctr[:,0]<x1)&
               (ctr[:,1]>y0)&(ctr[:,1]<y1)&
               (ctr[:,2]>z0)&(ctr[:,2]<z1)).sum())
 assert inside==0, f'Remaining R24 gantry geometry: {inside}'
 # R34 restored the R25 *southern* building; it must still be complete.
 southern=next(m for m in doc['meshes'] if m['name'].startswith('R25 first genuinely replaced'))
 assert sum(get_accessor(doc,buffer,p['indices']).size for p in southern['primitives'])//3==3696
 # And the REAL scanned north structure must remain independently visible.
 frame=AXIS@np.asarray(doc['nodes'][0]['matrix']).reshape(4,4,order='F')[:3,:3]
 scanned=0
 for mesh in doc['meshes'][:15]:
  for p in mesh['primitives']:
   xyz=get_accessor(doc,buffer,p['attributes']['POSITION'])@frame.T
   faces=get_accessor(doc,buffer,p['indices']).reshape(-1,3)
   c=xyz[faces].mean(1)
   scanned+=int(((c[:,0]>x0)&(c[:,0]<x1)&(c[:,1]>y0)&(c[:,1]<y1)&
                 (c[:,2]>-2.0)&(c[:,2]<-0.55)).sum())
 assert scanned>5000, f'Original north-building scan missing: {scanned}'
 v,t=read_glb(GLB)
 f=FPC.read_bytes();magic,nv,nt,_=struct.unpack_from('<4sIII',f)
 assert magic==b'FPC1' and nv==len(v) and nt==975919
 assert nt==len(np.unique(np.sort(t,axis=1),axis=0))
 assert np.array_equal(v,np.frombuffer(f,dtype='<f4',count=nv*3,offset=16).reshape(-1,3))
 sha=hashlib.sha256(f).hexdigest()
 assert rep['fpc_sha256']==sha
 scene=json.loads(CAT.read_text())['sceneries'][0]
 assert scene['terrainCertificate']['collisionSha256']==sha
 assert len(scene['terrainCertificates'])==15
 assert all(c['collisionSha256']==sha for c in scene['terrainCertificates'])
 assert scene['bkgHeightOffsetM']==0
 print(json.dumps({'revision':'R35','removed_gantry_triangles':190,'north_original_scan_triangles':scanned,
   'south_reconstruction_triangles':3696,'collision_triangles':nt,'bkg_offset_m':scene['bkgHeightOffsetM']},indent=2))

if __name__=='__main__':main()
