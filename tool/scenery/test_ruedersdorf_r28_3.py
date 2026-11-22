#!/usr/bin/env python3
from __future__ import annotations
import json, struct, sys
from pathlib import Path
import numpy as np
sys.path.insert(0, 'tool/scenery')
from build_collision import AXIS
from refine_ruedersdorf_r13 import get_accessor

REPORT=Path('tool/scenery/r28_3/refinement_R28_3_report.json')
GLB=Path('web/assets/scenery/local_reference.glb')


def main():
    report=json.loads(REPORT.read_text())
    assert report['platform_shift']['shift_m']==1.0
    assert report['removed_connector']['meshes']==1
    raw=GLB.read_bytes(); n=struct.unpack_from('<I',raw,12)[0]
    doc=json.loads(raw[20:20+n]); buf=bytearray(raw[28+n:])
    assert not any(m.get('name','').startswith('R28.2 platform attachment') for m in doc['meshes'])
    mesh=[m for m in doc['meshes'] if m.get('name')=='R24 screenshot-guided platform resize, room block, clerestories and gantry'][0]
    ys=[]
    for p in mesh['primitives']:
        pos=get_accessor(doc,buf,p['attributes']['POSITION'])@AXIS.T
        mask=((pos[:,0]>-5.02)&(pos[:,0]<-4.77)&(pos[:,1]>-0.90)&(pos[:,1]<-0.60)&(pos[:,2]>-0.40)&(pos[:,2]<0.20))
        if mask.any():ys.extend(pos[mask,1].tolist())
    assert ys, 'platform vertices not found'
    assert min(ys)<-0.86, min(ys)
    print(json.dumps({'platform_vertex_count':len(ys),'min_y':min(ys),'max_y':max(ys)}))

if __name__=='__main__':
    main()
