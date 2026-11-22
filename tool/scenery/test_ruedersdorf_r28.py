#!/usr/bin/env python3
"""R28 model: scan-derived footprint, original context, collision consistency."""
from __future__ import annotations
import json,hashlib,struct,sys
from pathlib import Path
import numpy as np
from build_collision import read_glb
from refine_ruedersdorf_r28 import SOURCE,TARGET,SCALE

def main(glb,fpc,report):
    p=Path(glb);q=Path(fpc);r=json.loads(Path(report).read_text())
    assert r['revision']=='R28' and r['original_scan_preserved']
    assert hashlib.sha256(p.read_bytes()).hexdigest()==r['glb_sha256']
    assert hashlib.sha256(q.read_bytes()).hexdigest()==r['fpc_sha256']
    v,t=read_glb(glb); f=q.read_bytes()
    magic,nv,nt,_=struct.unpack_from('<4sIII',f)
    assert magic==b'FPC1' and nv==len(v)
    assert np.array_equal(v,np.frombuffer(f,dtype='<f4',count=nv*3,offset=16).reshape(-1,3))
    assert nt==len(np.unique(np.sort(t,axis=1),axis=0))
    bbox=[round((TARGET[1]-TARGET[0])*SCALE,2),round((TARGET[3]-TARGET[2])*SCALE,2)]
    assert bbox==r['target_footprint_m']
    assert r['target_footprint_m'][0]>r['source_footprint_m'][0]
    assert r['target_footprint_m'][1]>r['source_footprint_m'][1]
    print('R28 PASS:',bbox,'m footprint,',nt,'matching collision triangles')
if __name__=='__main__':main(*sys.argv[1:])
