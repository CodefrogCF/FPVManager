#!/usr/bin/env python3
"""R30: remove the obsolete R25 east-block scaffold after restoring the scan.

R29 brought back the original raw-scan geometry for the eastern low building,
but the earlier R25 east-production replacement mesh still occupied the same
bounded footprint. In the app this appears as a synthetic scaffold / roof-frame
standing on top of the restored scan building. R30 removes only that bounded
R25 replacement volume and keeps the restored raw scan plus all unrelated
reconstructions unchanged.
"""
from __future__ import annotations
import argparse, hashlib, json, struct
from pathlib import Path
import numpy as np
from build_collision import read_glb, build
from refine_ruedersdorf_r13 import compact
from refine_ruedersdorf_r24 import serialize_glb
from refine_ruedersdorf_r25 import EAST_CUT, cut_mesh

SOURCE_SHA='30f826d65700c1ba36520d3857a2e0504c7eb7c6722982e1f53ddb552fd87b8e'
TARGET_MESH_NAME='R25 first genuinely replaced scan building shells with enterable openings'


def main(source, output, collision, report):
    raw=Path(source).read_bytes(); sha=hashlib.sha256(raw).hexdigest()
    if sha!=SOURCE_SHA:
        raise ValueError(f'Expected R29 GLB {SOURCE_SHA}; got {sha}')
    n=struct.unpack_from('<I',raw,12)[0]
    doc=json.loads(raw[20:20+n]); buf=bytearray(raw[28+n:])
    target=None
    for i,m in enumerate(doc['meshes']):
        if m.get('name')==TARGET_MESH_NAME:
            target=i;break
    if target is None:
        raise ValueError('R25 replacement mesh not found')
    removed=cut_mesh(doc,buf,target,EAST_CUT)
    # Drop now-empty primitives, if any. Keep the northwest R25 replacement.
    doc['meshes'][target]['primitives']=[p for p in doc['meshes'][target]['primitives']
        if doc['accessors'][p['indices']]['count']>0]
    if not doc['meshes'][target]['primitives']:
        raise ValueError('Target mesh became empty; unexpected northwest utility loss')
    doc['asset'].setdefault('extras',{})['modifications']=doc['asset'].get('extras',{}).get('modifications','') + (
        ' R30: remove the obsolete R25 east-production replacement/scaffold within '
        'the bounded EAST_CUT volume after restoring the original raw scan in R29. '
        'The restored scan building remains visible; only the synthetic overlapping '
        'roof-frame, posts, floors and walls in that footprint are removed.'
    )
    buf=compact(doc,buf)
    serialize_glb(doc,buf,output)
    v,t=read_glb(output)
    unique=np.unique(np.sort(t,axis=1),axis=0)
    stats=build(v,unique,collision)
    stats.update({
        'revision':'R30',
        'source_sha256':sha,
        'glb_sha256':hashlib.sha256(Path(output).read_bytes()).hexdigest(),
        'fpc_sha256':hashlib.sha256(Path(collision).read_bytes()).hexdigest(),
        'target_mesh_index':target,
        'east_cut':list(EAST_CUT),
        'removed_east_replacement':removed,
        'visual_triangles':int(len(t)),
        'unique_collision_triangles':int(len(unique)),
    })
    Path(report).parent.mkdir(parents=True, exist_ok=True)
    Path(report).write_text(json.dumps(stats,indent=2,ensure_ascii=False)+'\n')
    print(json.dumps(stats,indent=2,ensure_ascii=False))


if __name__=='__main__':
    ap=argparse.ArgumentParser(description=__doc__)
    for a in ('source','output','collision','report'):
        ap.add_argument(a)
    args=ap.parse_args(); main(args.source,args.output,args.collision,args.report)
