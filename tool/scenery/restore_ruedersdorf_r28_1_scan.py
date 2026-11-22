#!/usr/bin/env python3
"""R28.1: temporarily restore the *original textured scan* at the green-roof site.

Source MUST be the certified R26 GLB: R27 destroyed/clipped original scan data
within the forebuilding mask, and R28 enlarged the inaccurate replacement.
Rebuild from R26, retaining every raw photogrammetry mesh exactly, while
cutting old *procedural* building construction within the original R27 mask.
The corrected terrain fitting in R28's JS is independent and remains active.

Do not substitute the R26 synthetic production shell or the R27/R28 green roof
for source scan. Preserve the surrounding silo stair and all other structures.
"""
from __future__ import annotations
import argparse, hashlib, json, struct
from pathlib import Path
import numpy as np
from build_collision import build, read_glb
from refine_ruedersdorf_r13 import compact, get_accessor
from refine_ruedersdorf_r24 import serialize_glb
from refine_ruedersdorf_r25 import cut_mesh
from refine_ruedersdorf_r27 import COURTYARD_MASK, RAMP_MASK, OLD_PROCEDURAL, prune_empty_meshes

R26_SHA='3a8f8431806491cba7ca2fccb1084c7c9f9825b550750cfa659f1f1f2b843f2b'
R26_SCAN_GEOMETRY_SHA='89f0925b812959096acb7249855ed28dd20179d92d457eb920a5bf57d22fb64f'


def scan_fingerprint(doc,buf):
    h=hashlib.sha256()
    for mesh in doc['meshes'][:15]:
        for prim in mesh['primitives']:
            for key in ('POSITION','NORMAL','TEXCOORD_0'):
                h.update(get_accessor(doc,buf,prim['attributes'][key]).tobytes())
            h.update(get_accessor(doc,buf,prim['indices']).tobytes())
            h.update(str(prim['material']).encode())
    return h.hexdigest()


def main(source,output,collision,report):
    raw=Path(source).read_bytes()
    got=hashlib.sha256(raw).hexdigest()
    if got!=R26_SHA:
        raise ValueError(f'Requires exact R26 pre-forebuilding scan asset, expected {R26_SHA}; got {got}')
    n=struct.unpack_from('<I',raw,12)[0]
    doc=json.loads(raw[20:20+n]);buf=bytearray(raw[28+n:])
    if len(doc['meshes'])!=30 or not doc['meshes'][-1]['name'].startswith('R26'):
        raise ValueError('Unexpected R26 mesh topology; refusing to alter unrelated scan content')
    root=json.dumps(doc['nodes'][0],sort_keys=True)
    raw_meshes=json.dumps(doc['meshes'][:15],sort_keys=True)
    assert scan_fingerprint(doc,buf)==R26_SCAN_GEOMETRY_SHA
    # R27 forebuilding occupied these exact two masks, including damaged ramp.
    # Do NOT cut mesh 0-14: they contain original textured scan fragments.
    # Do NOT cut mesh 16: adjacent silo stair must remain accessible.
    counts={}
    for idx in OLD_PROCEDURAL:
        counts[str(idx)]={
            'main':cut_mesh(doc,buf,idx,COURTYARD_MASK),
            'stair_ramp':cut_mesh(doc,buf,idx,RAMP_MASK),
        }
    for mesh in doc['meshes']:
        mesh['primitives']=[p for p in mesh['primitives'] if doc['accessors'][p['indices']]['count']>0]
    retired=prune_empty_meshes(doc)
    assert all(m['primitives'] for m in doc['meshes'])
    assert root==json.dumps(doc['nodes'][0],sort_keys=True)
    assert raw_meshes==json.dumps(doc['meshes'][:15],sort_keys=True)
    removed=sum(c['removed_fully'] for entry in counts.values() for c in entry.values())
    assert removed>2500,('Expected previous synthetic building to be excised',removed)
    # No generated replacement is introduced: source scan is the visible result.
    doc['asset']['extras']['modifications']+= (
        ' R28.1: user-requested temporary fallback for the inaccurate green-roof '
        'courtyard forebuilding. Restored R26 original photogrammetry mesh (all 15 '
        'scan primitives + their original UV materials), removing the pre-existing '
        'synthetic production block in the forebuilding and ramp volumes. No new '
        'building geometry or textures. Preserve all other scene detail. Replacement '
        'will be reconsidered when new user references are available.')
    buf=compact(doc,buf)
    assert scan_fingerprint(doc,buf)==R26_SCAN_GEOMETRY_SHA
    serialize_glb(doc,buf,output)
    v,t=read_glb(output)
    faces=np.unique(np.sort(t,axis=1),axis=0)
    stats=build(v,faces,collision)
    c=Path(collision).read_bytes()
    magic,nv,nt,_=struct.unpack_from('<4sIII',c)
    assert magic==b'FPC1' and nv==len(v) and nt==len(faces)
    assert np.array_equal(np.frombuffer(c,dtype='<f4',count=nv*3,offset=16).reshape(-1,3),v)
    stats.update(revision='R28.1',r26_source_sha256=got,
        glb_sha256=hashlib.sha256(Path(output).read_bytes()).hexdigest(),
        fpc_sha256=hashlib.sha256(c).hexdigest(),
        original_raw_scan_meshes_unchanged=15,
        raw_scan_geometry_sha256=R26_SCAN_GEOMETRY_SHA,
        scanned_original_textures_preserved=True,
        removed_synthetic_triangles=removed,
        retired_empty_meshes=retired,
        detailed_replacement_added=False,
        neighboring_silo_access_mesh_16_preserved=True,
        previous_courtyard_mask=list(COURTYARD_MASK),
        previous_ramp_mask=list(RAMP_MASK),
        deleted_synthetic_by_mesh=counts,
        visual_triangles=len(t),collision_triangles=nt,
        terrain_alignment_managed_by_R28_web_code=True)
    Path(report).parent.mkdir(parents=True,exist_ok=True)
    Path(report).write_text(json.dumps(stats,indent=2,ensure_ascii=False)+'\n')
    print(f'R28.1: original scan restored, {removed} old synthetic triangles removed; {nt} collision triangles')


if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__)
    for arg in ('source','output','collision','report'):
        p.add_argument(arg)
    a=p.parse_args();main(a.source,a.output,a.collision,a.report)
