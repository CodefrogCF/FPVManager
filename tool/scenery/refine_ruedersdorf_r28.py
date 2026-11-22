#!/usr/bin/env python3
"""R28: correct the R27 forebuilding envelope against earlier scan-derived bounds.

The R27 forebuilding was squeezed into a smaller interior rectangle, with an
arbitrarily short roof plan. The older R6 scan-constrained footprint is used as
an explicit size reference, rather than extending the building based on photo
perspective. Do not merge it with the distinct northern scanned building.
Preserves R27 openings/stair, all other scene meshes and source georeference.
Rebuilds CPU collision from the finished visible GLB.
"""
from __future__ import annotations
import argparse,hashlib,json,struct
from pathlib import Path
import numpy as np
from build_collision import AXIS,read_glb,build
from refine_ruedersdorf_r13 import get_accessor,compact
from refine_ruedersdorf_r15_silo import append_accessor
from refine_ruedersdorf_r24 import serialize_glb

SOURCE_SHA='40272a0a2e48b575ffd8917be5aac7380b5cf58bb50afadff049ca494222b9f4'
SOURCE=(-4.235,-2.705,1.812,3.290)
# Footprint inset from the scan-derived R6 production region [-4.33,-2.59] x [1.71,3.50].
# R27's collapsed stair extends beyond this volume; preserve its slope/length.
TARGET=(-4.305,-2.615,1.735,3.475)
SCALE=16.023268178233355


def remap_axis(value,source_lo,source_hi,target_lo,target_hi):
    factor=(target_hi-target_lo)/(source_hi-source_lo)
    result=np.where(value<source_lo,value+target_lo-source_lo,
               np.where(value>source_hi,value+target_hi-source_hi,
                        target_lo+(value-source_lo)*factor))
    return result


def main(source,output,collision,report):
    raw=Path(source).read_bytes(); sha=hashlib.sha256(raw).hexdigest()
    if sha!=SOURCE_SHA:raise ValueError(f'Expected validated R27.1 GLB {SOURCE_SHA}; received {sha}')
    n=struct.unpack_from('<I',raw,12)[0]
    doc=json.loads(raw[20:20+n]);buf=bytearray(raw[28+n:])
    assert doc['meshes'][-1]['name'].startswith('R27 courtyard forebuilding')
    original_root=json.dumps(doc['nodes'][0],sort_keys=True)
    original_scan=[json.dumps(m,sort_keys=True) for m in doc['meshes'][:15]]
    changed=0
    for prim in doc['meshes'][-1]['primitives']:
        pos=get_accessor(doc,buf,prim['attributes']['POSITION'])@AXIS.T
        out=pos.copy()
        out[:,0]=remap_axis(pos[:,0],SOURCE[0],SOURCE[1],TARGET[0],TARGET[1])
        out[:,1]=remap_axis(pos[:,1],SOURCE[2],SOURCE[3],TARGET[2],TARGET[3])
        # R27 uses independent vertices per triangle. Recalculate normals
        # after anisotropic scaling; otherwise lighting can be inaccurate.
        idx=get_accessor(doc,buf,prim['indices']).reshape(-1,3)
        normals=np.zeros_like(out)
        for a,b,c in idx:
            nrm=np.cross(out[b]-out[a],out[c]-out[a]);length=np.linalg.norm(nrm)
            if length>1e-12:nrm/=length
            normals[a]=normals[b]=normals[c]=nrm
        prim['attributes']['POSITION']=append_accessor(doc,buf,(out@AXIS).astype('<f4'),'VEC3',5126,34962)
        prim['attributes']['NORMAL']=append_accessor(doc,buf,(normals@AXIS).astype('<f4'),'VEC3',5126,34962)
        changed+=len(idx)
    doc['meshes'][-1]['name']='R28 R27 courtyard forebuilding resized to scan-derived production footprint'
    doc['nodes'][-1]['name']='R28 scan-envelope matched courtyard forebuilding'
    doc['asset']['extras']['modifications']+=(
        ' R28: enlarge R27 courtyard roof/structure to the earlier scan-derived R6 '
        'production envelope, preserving the adjacent original scanned building as '
        'a separate structure, keeping openings and damaged stair. Heights remain '
        'uncertain where original photogrammetry contains ground only; no invented '
        'full-height storeys. Georeferencing and source attribution unchanged.')
    buf=compact(doc,buf)
    assert original_root==json.dumps(doc['nodes'][0],sort_keys=True)
    assert original_scan==[json.dumps(m,sort_keys=True) for m in doc['meshes'][:15]]
    serialize_glb(doc,buf,output)
    v,t=read_glb(output); unique=np.unique(np.sort(t,axis=1),axis=0)
    stats=build(v,unique,collision)
    blob=Path(collision).read_bytes();magic,nv,nt,_=struct.unpack_from('<4sIII',blob)
    assert magic==b'FPC1' and nv==len(v) and nt==len(unique)
    assert np.array_equal(np.frombuffer(blob,dtype='<f4',count=nv*3,offset=16).reshape(-1,3),v)
    stats.update(revision='R28',r27_source_sha256=sha,
        glb_sha256=hashlib.sha256(Path(output).read_bytes()).hexdigest(),
        fpc_sha256=hashlib.sha256(blob).hexdigest(),
        source_footprint_local=SOURCE,target_footprint_local=TARGET,
        source_footprint_m=[round((SOURCE[1]-SOURCE[0])*SCALE,2),round((SOURCE[3]-SOURCE[2])*SCALE,2)],
        target_footprint_m=[round((TARGET[1]-TARGET[0])*SCALE,2),round((TARGET[3]-TARGET[2])*SCALE,2)],
        triangles_in_resized_mesh=changed, original_scan_preserved=True,
        model_height_unchanged=True, collision_triangles=nt,
        scan_source_region='R6 west production block scan-constrained region; not surveyed',
        photo_registration='not surveyed')
    Path(report).parent.mkdir(parents=True,exist_ok=True)
    Path(report).write_text(json.dumps(stats,indent=2,ensure_ascii=False)+'\n')
    print('R28:',stats['target_footprint_m'],'m footprint,',nt,'collision triangles')

if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__)
    for name in ('source','output','collision','report'):p.add_argument(name)
    a=p.parse_args();main(a.source,a.output,a.collision,a.report)
