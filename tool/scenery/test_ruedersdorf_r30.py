#!/usr/bin/env python3
"""R30 regression: east scaffold removed, restored scan retained."""
from __future__ import annotations
import json, struct, sys
from pathlib import Path
import numpy as np
sys.path.insert(0,'tool/scenery')
from build_collision import AXIS, read_glb
from refine_ruedersdorf_r13 import get_accessor
from refine_ruedersdorf_r25 import EAST_CUT

GLB=Path('web/assets/scenery/local_reference.glb')
FPC=Path('web/assets/scenery/local_reference.fpc')
REPORT=Path('tool/scenery/r30/refinement_R30_report.json')
TARGET='R25 first genuinely replaced scan building shells with enterable openings'


def main():
    report=json.loads(REPORT.read_text())
    assert report['revision']=='R30'
    removed=report['removed_east_replacement']
    assert removed['removed_fully']>1500, removed
    raw=GLB.read_bytes(); n=struct.unpack_from('<I',raw,12)[0]
    doc=json.loads(raw[20:20+n]); buf=raw[28+n:]
    mesh_index=next(i for i,m in enumerate(doc['meshes']) if m.get('name')==TARGET)
    # No generated R25 geometry may remain inside the eastern replacement prism.
    inside=0
    for prim in doc['meshes'][mesh_index]['primitives']:
        pos=get_accessor(doc,buf,prim['attributes']['POSITION'])@AXIS.T
        idx=get_accessor(doc,buf,prim['indices']).reshape(-1,3)
        c=pos[idx].mean(1)
        q=((c[:,0]>EAST_CUT[0])&(c[:,0]<EAST_CUT[1])&
           (c[:,1]>EAST_CUT[2])&(c[:,1]<EAST_CUT[3])&
           (c[:,2]>EAST_CUT[4])&(c[:,2]<EAST_CUT[5]))
        inside+=int(q.sum())
    assert inside==0, f'East replacement triangles still present: {inside}'
    # The restored raw scan should still contribute many textured faces in the same area.
    root=AXIS@np.array(doc['nodes'][0]['matrix'],dtype=float).reshape(4,4,order='F')[:3,:3]
    restored=0
    for mesh in doc['meshes'][:15]:
        for prim in mesh['primitives']:
            if prim.get('material')!=0:
                continue
            pos=get_accessor(doc,buf,prim['attributes']['POSITION'])@root.T
            idx=get_accessor(doc,buf,prim['indices']).reshape(-1,3)
            c=pos[idx].mean(1)
            q=((c[:,0]>EAST_CUT[0])&(c[:,0]<EAST_CUT[1])&
               (c[:,1]>EAST_CUT[2])&(c[:,1]<EAST_CUT[3])&
               (c[:,2]>-2.2)&(c[:,2]<-.75))
            restored+=int(q.sum())
    assert restored>1500, f'Restored scan unexpectedly sparse: {restored}'
    v,t=read_glb(GLB)
    blob=FPC.read_bytes(); magic,nv,nt,nodes=struct.unpack_from('<4sIII',blob)
    assert magic==b'FPC1' and nv==len(v) and nt==len(np.unique(np.sort(t,axis=1),axis=0))
    print(json.dumps({'removed_generated_east_triangles':removed['removed_fully'],
        'remaining_r25_triangles_inside_cut':inside,
        'restored_scan_triangles_in_cut':restored,
        'collision_triangles':nt}, indent=2))


if __name__=='__main__': main()
