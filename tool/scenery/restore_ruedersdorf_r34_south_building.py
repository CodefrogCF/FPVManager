#!/usr/bin/env python3
"""R34: restore the *southern* courtyard's R25 production building, not R27.

In R30 the complete east-production block was mistakenly called scaffolding,
and 2328 triangles were unreferenced in R25 mesh index 27. The actual source
scan restored in R29 lies in a separate NORTHERN footprint (local x<0).
The R25 southern architecture lies at local +X=South, +Y=East. Its original
per-vertex POSITION/NORMAL/UV attributes remain intact in the current R33.1
GLB, because R30 changed only triangle indices. Recover exactly those indices
without importing source textures, changing another mesh or manufacturing a
new structure. Regenerate the exact GLB-backed FPC collision asset.

The BKG height correction already calibrated by the user is a separate runtime
setting; this operation does not touch it.
"""
from __future__ import annotations
import argparse, hashlib, json, struct
from pathlib import Path
import numpy as np
from build_collision import AXIS, build, read_glb
from refine_ruedersdorf_r13 import get_accessor, compact
from refine_ruedersdorf_r15_silo import append_accessor

R33_1_SHA='0c3d1c5627d525ce1b8daa1117da7e573c8d9d3f97eb72e3bdd49d54072205ef'
MESH_NAME='R25 first genuinely replaced scan building shells with enterable openings'
LOCAL_SOUTH_BUILDING=(4.29,5.48,0.99,2.76,-2.012,-0.745)
# Expected R30 index counts and still-resident source vertex counts, from
# direct checks of the R29 and R33.1 source asset primitives.
RETAINED_INDEX_COUNTS=(576,2808,288,432)
FULL_SOURCE_VERTEX_COUNTS=(2484,6120,1116,1368)
EXPECTED_RESTORED_TRIS=2328


def read(path):
    raw=Path(path).read_bytes()
    if raw[:4]!=b'glTF' or struct.unpack_from('<I',raw,4)[0]!=2:
        raise ValueError('GLB 2 required')
    jlen=struct.unpack_from('<I',raw,12)[0]
    return raw,json.loads(raw[20:20+jlen]),bytearray(raw[28+jlen:])


def serialize_glb(doc,buf,path):
    doc['buffers'][0]['byteLength']=len(buf)
    packed=json.dumps(doc,separators=(',',':'),ensure_ascii=False).encode('utf-8')
    packed+=b' '*(-len(packed)%4)
    buf.extend(b'\0'*(-len(buf)%4))
    payload=struct.pack('<I4s',len(packed),b'JSON')+packed+struct.pack('<I4s',len(buf),b'BIN\0')+buf
    Path(path).write_bytes(struct.pack('<4sII',b'glTF',2,len(payload)+12)+payload)


def restore(source,output,collision,report):
    raw,doc,buf=read(source)
    sha=hashlib.sha256(raw).hexdigest()
    if sha!=R33_1_SHA:
        raise ValueError('R33.1 source asset mismatch: '+sha)
    targets=[i for i,m in enumerate(doc['meshes']) if m.get('name')==MESH_NAME]
    if len(targets)!=1:raise ValueError('R25 southern production building mesh not found')
    mesh_id=targets[0]; mesh=doc['meshes'][mesh_id]
    if len(mesh['primitives'])!=4:raise ValueError('Unexpected R25 primitive count')
    # Stable fingerprints of all untouched geometry, including all 15 original
    # 2022 photographed RAWscan meshes and the R26 southwest ruin annex.
    before=[json.dumps(m,sort_keys=True) for k,m in enumerate(doc['meshes']) if k!=mesh_id]
    node_before=json.dumps(doc['nodes'],sort_keys=True)
    ref_offset_before=doc['nodes'][0]['matrix'][:]
    recovered=0
    by_material={}
    for pi,prim in enumerate(mesh['primitives']):
        positions=get_accessor(doc,buf,prim['attributes']['POSITION'])
        normals=get_accessor(doc,buf,prim['attributes']['NORMAL'])
        uvs=get_accessor(doc,buf,prim['attributes']['TEXCOORD_0'])
        existing=get_accessor(doc,buf,prim['indices']).reshape(-1)
        full_count=FULL_SOURCE_VERTEX_COUNTS[pi]
        if len(positions)!=full_count or len(normals)!=full_count or len(uvs)!=full_count:
            raise ValueError(f'R25 source vertex/normal/UV counts changed in primitive {pi}')
        if len(existing)!=RETAINED_INDEX_COUNTS[pi] or not np.array_equal(existing,np.arange(len(existing))):
            raise ValueError(f'R30 retained primitive {pi} is no longer the known prefix')
        # All omitted faces must lie within the SOUTHERN cut volume, leaving
        # the R29 original NORTH building completely untouched.
        missing=positions[len(existing):].reshape(-1,3)@AXIS.T
        xmin,xmax,ymin,ymax,zmin,zmax=LOCAL_SOUTH_BUILDING
        centers=missing.reshape(-1,3,3).mean(axis=1)
        if not np.all((centers[:,0]>xmin)&(centers[:,0]<xmax)&
                      (centers[:,1]>ymin)&(centers[:,1]<ymax)&
                      (centers[:,2]>zmin)&(centers[:,2]<zmax)):
            raise ValueError(f'R25 omitted primitive {pi} has triangles outside the south building')
        complete=np.arange(full_count,dtype='<u2')
        prim['indices']=append_accessor(doc,buf,complete,'SCALAR',5123,34963)
        delta=(full_count-len(existing))//3
        recovered+=delta
        by_material[doc['materials'][prim['material']]['name']]=delta
    if recovered!=EXPECTED_RESTORED_TRIS:
        raise ValueError(f'Expected 2328 restored south-building triangles, found {recovered}')
    assert before==[json.dumps(m,sort_keys=True) for k,m in enumerate(doc['meshes']) if k!=mesh_id]
    assert node_before==json.dumps(doc['nodes'],sort_keys=True)
    assert doc['nodes'][0]['matrix']==ref_offset_before
    assert all('R27 courtyard forebuilding' not in m.get('name','') for m in doc['meshes'])
    doc['asset'].setdefault('extras',{}).setdefault('modifications','')
    doc['asset']['extras']['modifications']+= (
        ' R34: restored exactly 2328 R25 east-production / southern courtyard'
        ' building faces (walls, room slabs, open roof and steel details) that'
        ' R30 had mistakenly removed while repairing a different northern scan'
        ' building. No R27 green-roof reconstruction added. Original scan'
        ' meshes and world alignment unchanged; FPC collision regenerated.')
    compacted=compact(doc,buf)
    serialize_glb(doc,compacted,output)
    verts,tri=read_glb(output)
    unique=np.unique(np.sort(tri,axis=1),axis=0)
    stats=build(verts,unique,collision)
    stats.update(revision='R34',source_sha256=sha,
        glb_sha256=hashlib.sha256(Path(output).read_bytes()).hexdigest(),
        fpc_sha256=hashlib.sha256(Path(collision).read_bytes()).hexdigest(),
        corrected_mesh_id=mesh_id,
        restored_south_building_triangles=recovered,
        restored_by_material=by_material,
        southern_bbox_local=list(LOCAL_SOUTH_BUILDING),
        northern_original_scan_unchanged=True,
        bkg_user_height_offset_unchanged=True,
        restored_r27_green_roof=False,
        collisions=int(len(unique)))
    Path(report).parent.mkdir(parents=True,exist_ok=True)
    Path(report).write_text(json.dumps(stats,indent=2,ensure_ascii=False)+'\n',encoding='utf-8')
    print(json.dumps(stats,indent=2,ensure_ascii=False))

if __name__=='__main__':
    ap=argparse.ArgumentParser(description=__doc__)
    for arg in ('source','output','collision','report'):ap.add_argument(arg)
    opt=ap.parse_args()
    restore(opt.source,opt.output,opt.collision,opt.report)
