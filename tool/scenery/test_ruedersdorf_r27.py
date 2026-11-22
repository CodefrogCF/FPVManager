#!/usr/bin/env python3
"""R27 scan substitution, embedded material and collision regression checks."""
from __future__ import annotations
import hashlib, io, json, struct, sys
from pathlib import Path
import numpy as np
from PIL import Image
from build_collision import AXIS, read_glb
from refine_ruedersdorf_r13 import get_accessor
from refine_ruedersdorf_r26 import SOUTHWEST_CUT
from refine_ruedersdorf_r27 import COURTYARD_MASK, OLD_PROCEDURAL, RAMP_MASK
from test_ruedersdorf_r26 import ray_hit


def count_residuals(doc,buf,mesh_indices,region):
    root=np.asarray(doc['nodes'][0]['matrix']).reshape(4,4,order='F')[:3,:3]
    a,b,c,d,e,f=region; hidden=0
    for i in mesh_indices:
        for pr in doc['meshes'][i]['primitives']:
            pos=get_accessor(doc,buf,pr['attributes']['POSITION'])
            local=pos@(root.T@AXIS.T if i<15 else AXIS.T)
            tri=get_accessor(doc,buf,pr['indices']).reshape(-1,3)
            centers=local[tri].mean(1)
            hidden+=int(np.count_nonzero(
                (centers[:,0]>a+1e-4)&(centers[:,0]<b-1e-4)&
                (centers[:,1]>c+1e-4)&(centers[:,1]<d-1e-4)&
                (centers[:,2]>e+1e-4)&(centers[:,2]<f-1e-4)))
    return hidden


def main(glb,fpc,report):
    raw=Path(glb).read_bytes();col=Path(fpc).read_bytes();rpt=json.loads(Path(report).read_text())
    assert rpt['revision']=='R27'
    assert hashlib.sha256(raw).hexdigest()==rpt['glb_sha256']
    assert hashlib.sha256(col).hexdigest()==rpt['fpc_sha256']
    v,t=read_glb(glb)
    magic,nv,nt,_=struct.unpack_from('<4sIII',col)
    assert magic==b'FPC1' and nv==len(v)
    faces=np.frombuffer(col,dtype='<u4',count=nt*3,offset=16+nv*12).reshape(-1,3)
    assert nt==len(np.unique(np.sort(t,axis=1),axis=0))
    assert np.array_equal(np.frombuffer(col,dtype='<f4',count=nv*3,offset=16).reshape(-1,3),v)
    assert np.array_equal(np.unique(np.sort(faces,axis=1),axis=0),np.unique(np.sort(t,axis=1),axis=0))
    n=struct.unpack_from('<I',raw,12)[0];doc=json.loads(raw[20:20+n]);buf=bytearray(raw[28+n:])
    assert len(doc['meshes'])==30 and doc['meshes'][-1]['name'].startswith('R27')
    assert all(mesh['primitives'] for mesh in doc['meshes']), 'Empty glTF mesh after reconstruction'
    assert rpt['removed_invalid_empty_meshes']==[{'index':26,'name':'R23 production atrium, north-edge utility and open ruin refinements'}]
    assert all(doc['meshes'][i]['name'].startswith('Object_') for i in range(15))
    for region in (COURTYARD_MASK,RAMP_MASK):
        assert count_residuals(doc,buf,list(range(15)),region)==0,'Original scan remains inside R27 cut'
        assert count_residuals(doc,buf,(15,20,22,23,24,26),region)==0,'Old production shell remains in R27 cut'
    assert rpt['old_procedural_removed_fully']>=3500
    assert rpt['raw_removed_fully']>=100
    # Verify that R27 actually includes its own embedded materials/textures,
    # rather than exposing the original blurred scan image assets again.
    names={m.get('name') for m in doc['materials']}
    assert len([x for x in names if x.startswith('R27 ')])==4
    for asset in doc['images'][-4:]:
        view=doc['bufferViews'][asset['bufferView']]
        off=view['byteOffset'];length=view['byteLength']
        im=Image.open(io.BytesIO(buf[off:off+length]))
        im.verify()

    triangles=v[faces].astype(np.float64);lo=triangles.min(1);hi=triangles.max(1)
    probes=[
        ('front entrance 1',(-4.03,3.49,-1.84),(-4.03,3.11,-1.84),False),
        ('front entrance 2',(-3.77,3.49,-1.84),(-3.77,3.11,-1.84),False),
        ('solid front masonry',(-3.665,3.49,-1.84),(-3.665,3.10,-1.84),True),
        ('left front wall',(-4.20,3.49,-1.83),(-4.20,3.10,-1.83),True),
        ('upper window void',(-3.869,3.49,-1.617),(-3.869,3.10,-1.617),False),
        ('rear entrance',(-4.03,1.67,-1.84),(-4.03,1.95,-1.84),False),
        ('rear wall',(-4.18,1.67,-1.84),(-4.18,1.95,-1.84),True),
        ('west side doorway',(-4.40,2.3,-1.82),(-4.10,2.3,-1.82),False),
        ('west side masonry',(-4.40,1.95,-1.82),(-4.10,1.95,-1.82),True),
        ('open front undercroft',(-3.46,3.48,-1.79),(-3.46,3.08,-1.79),False),
        ('roof slab',(-3.5,2.45,-1.49),(-3.5,2.45,-1.15),True),
        ('surviving ramp slab',(-3.24,3.43,-1.95),(-3.24,3.43,-1.20),True),
        ('gap in collapsed ramp',(-3.24,3.58,-1.70),(-3.24,3.58,-1.23),False),
        ('lower ramp remnant',(-3.24,3.75,-1.95),(-3.24,3.75,-1.20),True),
        ('nearby courtyard free',(-3.78,3.80,-1.86),(-3.78,3.40,-1.86),False),
        ('neighboring silo body',(-2.19,2.66,-1.38),(-2.19,2.66,-.45),True),
        ('central four-silo roof dive',(1.41,3.85,-.58),(1.41,3.85,-.35),False),
        ('main hall external landing gap',(-4.876,-.726,-.15),(-4.876,-.726,-.04),False),
        ('R26 front entrance',(2.90,-5.01,-1.82),(2.90,-4.89,-1.82),False),
        ('R26 front intact wall',(2.62,-5.01,-1.82),(2.62,-4.89,-1.82),True),
        ('R26 rear entrance',(2.83,-4.64,-1.82),(2.83,-4.54,-1.82),False),
        ('R25 northwest doorway',(-4.18,5.70,-1.85),(-4.18,5.82,-1.85),False),
        ('R25 northwest wall',(-4.36,5.70,-1.85),(-4.36,5.82,-1.85),True),
        ('R25 east doorway',(4.24,1.87,-1.79),(4.46,1.87,-1.79),False),
        ('R25 east wall',(4.24,1.60,-1.79),(4.46,1.60,-1.79),True),
    ]
    for label,start,end,expected in probes:
        actual=ray_hit(triangles,lo,hi,start,end)
        if actual!=expected:raise AssertionError(f'{label}: hit={actual}, expected={expected}')
    print(f'R27 PASS: {len(probes)} scene rays, GLB/FPC exact triangles, '
          f'{rpt["raw_removed_fully"]} raw and {rpt["old_procedural_removed_fully"]} old faces removed, '
          'four embedded procedural textures, scan masks clear')

if __name__=='__main__':main(*sys.argv[1:])
