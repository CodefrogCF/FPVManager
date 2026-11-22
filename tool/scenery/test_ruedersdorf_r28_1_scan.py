#!/usr/bin/env python3
"""Validate R28.1 fallback against original RAWscan and derived collision FPC."""
from __future__ import annotations
import hashlib,json,struct,sys
from pathlib import Path
import numpy as np
from build_collision import AXIS,read_glb
from refine_ruedersdorf_r13 import get_accessor
from restore_ruedersdorf_r28_1_scan import (R26_SCAN_GEOMETRY_SHA,scan_fingerprint)


def main(glb,fpc,report):
    data=Path(glb).read_bytes();collision=Path(fpc).read_bytes()
    summary=json.loads(Path(report).read_text())
    assert summary['revision']=='R28.1'
    assert summary['scanned_original_textures_preserved']
    assert summary['original_raw_scan_meshes_unchanged']==15
    assert not summary['detailed_replacement_added']
    assert summary['removed_synthetic_triangles']>=4000
    assert summary['raw_scan_geometry_sha256']==R26_SCAN_GEOMETRY_SHA
    assert hashlib.sha256(data).hexdigest()==summary['glb_sha256']
    assert hashlib.sha256(collision).hexdigest()==summary['fpc_sha256']
    n=struct.unpack_from('<I',data,12)[0]
    doc=json.loads(data[20:20+n]);buf=data[28+n:]
    assert all(mesh['primitives'] for mesh in doc['meshes']), 'Invalid empty GLB mesh'
    assert all(doc['meshes'][i]['name'].startswith('Object_') for i in range(15))
    assert scan_fingerprint(doc,buf)==R26_SCAN_GEOMETRY_SHA
    assert not any(mesh.get('name','').startswith(('R27 courtyard forebuilding','R28 R27 courtyard'))
                   for mesh in doc['meshes'])
    v,t=read_glb(glb)
    magic,nv,nt,_=struct.unpack_from('<4sIII',collision)
    assert magic==b'FPC1' and nv==len(v)
    cv=np.frombuffer(collision,dtype='<f4',count=nv*3,offset=16).reshape(-1,3)
    ct=np.frombuffer(collision,dtype='<u4',count=nt*3,offset=16+nv*12).reshape(-1,3)
    assert np.array_equal(cv,v)
    assert np.array_equal(np.unique(np.sort(t,axis=1),axis=0),
                          np.unique(np.sort(ct,axis=1),axis=0))
    # Both old shell and its ramp must remain free of generated construction.
    assert summary['neighboring_silo_access_mesh_16_preserved']
    print(f'R28.1 PASS: all 15 scan meshes exactly match R26 original, '
          f'{summary["removed_synthetic_triangles"]} fake faces removed, '
          f'{nt} FPC triangles aligned with GLB')


if __name__=='__main__':
    main(*sys.argv[1:])
