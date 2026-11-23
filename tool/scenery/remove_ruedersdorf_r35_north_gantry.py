#!/usr/bin/env python3
"""R35 – remove ONLY the R24 outdoor scaffold overlapping the northern RAWscan.

Reference: user's north-up annotated overhead (2026-11-23 09:44). The
misplaced piece is the R24 'north-side outdoor scaffold/gantry' in local
X -5.28..-3.92, Y 1.34..2.42. This synthetic two-canopy scaffold partly
covers the already photographed R29 scan building north of the courtyard.

Its complete 190 triangles are still in the single R24 procedural mesh;
remove those indexed faces with a tight coordinate mask, not the underlying
photogrammetry, the R22 reconstructed interior annexes or the R34 southern
production building. R35 changes no local alignment, vertical offsets or
geographic transforms. Rebuild FPC from resulting GLB geometry.
"""
from __future__ import annotations
import argparse, hashlib, json
from pathlib import Path
import numpy as np
from build_collision import AXIS, read_glb, build
from refine_ruedersdorf_r13 import get_accessor, compact
from refine_ruedersdorf_r15_silo import append_accessor
from restore_ruedersdorf_r34_south_building import read, serialize_glb

SOURCE_R34_SHA='d6257addb55e9cbc84b213a5b47ea735627bb9b4eb8114bd87869034a98a87db'
R24_MESH_NAME='R24 screenshot-guided platform resize, room block, clerestories and gantry'
# Just outside the exact generated gantry footprint and its rails/posts/roof.
GANTRY_REMOVE=(-5.32,-3.87, 1.29,2.47, -2.02,-1.23)
EXPECTED_BY_PRIMITIVE=(112,4,16,24,17,17)
EXPECTED_REMOVED=sum(EXPECTED_BY_PRIMITIVE)


def remove(source, output, collision, report):
    raw,doc,buf=read(source)
    source_sha=hashlib.sha256(raw).hexdigest()
    if source_sha!=SOURCE_R34_SHA:
        raise ValueError(f'Expected exact R34 GLB ({SOURCE_R34_SHA}); got {source_sha}')
    hits=[i for i,m in enumerate(doc['meshes']) if m.get('name')==R24_MESH_NAME]
    if len(hits)!=1: raise ValueError('R24 original gantry mesh must be uniquely present')
    mesh_id=hits[0]
    mesh=doc['meshes'][mesh_id]
    if len(mesh['primitives'])!=len(EXPECTED_BY_PRIMITIVE):
        raise ValueError('Unexpected R24 mesh primitive count')
    untouched_meshes=json.dumps([m for i,m in enumerate(doc['meshes']) if i!=mesh_id],sort_keys=True)
    old_nodes=json.dumps(doc['nodes'],sort_keys=True)
    old_alignment=doc['nodes'][0]['matrix'][:]
    xmin,xmax,ymin,ymax,zmin,zmax=GANTRY_REMOVE
    removed=[]
    retained=[]
    for pi,prim in enumerate(mesh['primitives']):
        vertices=get_accessor(doc,buf,prim['attributes']['POSITION']).astype('f8')@AXIS.T
        triangles=get_accessor(doc,buf,prim['indices']).reshape(-1,3)
        tri_xyz=vertices[triangles]
        low=tri_xyz.min(axis=1); high=tri_xyz.max(axis=1)
        within=((low[:,0]>xmin)&(high[:,0]<xmax)&
                (low[:,1]>ymin)&(high[:,1]<ymax)&
                (low[:,2]>zmin)&(high[:,2]<zmax))
        # No triangle may straddle the sub-volume; that would require actual
        # triangle clipping to avoid accidentally deleting another building.
        center=tri_xyz.mean(axis=1)
        centroid_inside=((center[:,0]>xmin)&(center[:,0]<xmax)&
                         (center[:,1]>ymin)&(center[:,1]<ymax)&
                         (center[:,2]>zmin)&(center[:,2]<zmax))
        if not np.array_equal(within,centroid_inside):
            raise ValueError(f'R24 primitive {pi}: geometry crosses gantry bounds')
        count=int(within.sum()); removed.append(count)
        if count!=EXPECTED_BY_PRIMITIVE[pi]:
            raise ValueError(f'R24 primitive {pi}: expected {EXPECTED_BY_PRIMITIVE[pi]} gantry faces, got {count}')
        keep=triangles[~within].reshape(-1)
        if len(keep):
            prev=doc['accessors'][prim['indices']]
            ctype=prev['componentType']
            out_type='<u2' if ctype==5123 else '<u4'
            prim['indices']=append_accessor(doc,buf,keep.astype(out_type),'SCALAR',ctype,34963)
            retained.append(prim)
    if sum(removed)!=EXPECTED_REMOVED or len(retained)!=2:
        raise ValueError(f'Expected {EXPECTED_REMOVED} faces and two surviving primitives; got {removed}/{len(retained)}')
    mesh['primitives']=retained
    if untouched_meshes!=json.dumps([m for i,m in enumerate(doc['meshes']) if i!=mesh_id],sort_keys=True):
        raise ValueError('Unrelated mesh changed')
    if json.dumps(doc['nodes'],sort_keys=True)!=old_nodes or doc['nodes'][0]['matrix']!=old_alignment:
        raise ValueError('Georeferencing or scene nodes changed')
    doc['asset'].setdefault('extras',{})['modifications']=(
        doc['asset'].get('extras',{}).get('modifications','')+
        ' R35: removed exactly 190 R24 north-side outdoor scaffold/gantry triangles'
        ' (two roof canopies, deck, posts, rails and braces) at local X'
        ' -5.28..-3.92, Y 1.34..2.42 where the synthetic model overlapped the'
        ' original north-building RAWscan. All 15 original scan meshes and'
        ' the R34 restored southern production building remain unchanged.'
        ' GLB/FPC rebuilt from the same geometry; BKG user height offset retained.'
    )
    compacted=compact(doc,buf)
    serialize_glb(doc,compacted,output)
    vertices,triangles=read_glb(output)
    unique=np.unique(np.sort(triangles,axis=1),axis=0)
    stats=build(vertices,unique,collision)
    stats.update(revision='R35',source_sha256=source_sha,
                 glb_sha256=hashlib.sha256(Path(output).read_bytes()).hexdigest(),
                 fpc_sha256=hashlib.sha256(Path(collision).read_bytes()).hexdigest(),
                 corrected_mesh_id=mesh_id,
                 removed_north_gantry_triangles=int(sum(removed)),
                 removed_by_primitive=removed,
                 clipped_local_box=list(GANTRY_REMOVE),
                 kept_primitives=len(retained),
                 original_scan_and_southern_reconstruction_untouched=True,
                 alignment_and_height_offset_unchanged=True,
                 unique_collision_triangles=int(len(unique)))
    Path(report).parent.mkdir(parents=True,exist_ok=True)
    Path(report).write_text(json.dumps(stats,indent=2,ensure_ascii=False)+'\n',encoding='utf-8')
    print(json.dumps(stats,indent=2,ensure_ascii=False))

if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    for key in ('source','output','collision','report'):parser.add_argument(key)
    args=parser.parse_args()
    remove(args.source,args.output,args.collision,args.report)
