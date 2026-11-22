#!/usr/bin/env python3
"""R28.3 - remove the ad-hoc wall connector and shift the hall platform west.

This revision undoes R28.2's extra attachment object and instead moves the
existing small north-east exterior platform as a whole by roughly one metre
westward (toward the hall facade), matching the latest in-app comparison.

It also keeps the rest of the reconstructed plant unchanged.
"""
from __future__ import annotations
import argparse, hashlib, json, struct
from pathlib import Path
import numpy as np
from build_collision import AXIS, build, read_glb
from refine_ruedersdorf_r13 import get_accessor, compact
from refine_ruedersdorf_r15_silo import append_accessor
from refine_ruedersdorf_r24 import serialize_glb

SOURCE_SHA='7ceb9ac5d98a44ecff20a32201e305970774ba28717d5f75e50aac636ad2f655'
SCALE=16.023268178233355
SHIFT_LOCAL=1.0/SCALE  # about one metre
PLATFORM_MESH_NAME='R24 screenshot-guided platform resize, room block, clerestories and gantry'
CONNECTOR_PREFIX='R28.2 platform attachment'


def remove_last_connector(doc):
    removed={'meshes':0,'nodes':0}
    # remove matching scene nodes first, tracking mesh indices to delete
    kill_meshes=[]
    for i,m in enumerate(doc['meshes']):
        if m.get('name','').startswith(CONNECTOR_PREFIX):
            kill_meshes.append(i)
    if not kill_meshes:
        return removed
    kill_nodes=[]
    for i,n in enumerate(doc['nodes']):
        if n.get('mesh') in kill_meshes or n.get('name','').startswith('R28.2 platform facade connector'):
            kill_nodes.append(i)
    scene=doc['scenes'][doc.get('scene',0)]
    scene['nodes']=[n for n in scene.get('nodes',[]) if n not in kill_nodes]
    # rebuild nodes with remapped mesh indices
    mesh_map={}
    new_meshes=[]
    for i,m in enumerate(doc['meshes']):
        if i in kill_meshes:
            removed['meshes']+=1
            continue
        mesh_map[i]=len(new_meshes)
        new_meshes.append(m)
    new_nodes=[]
    node_map={}
    for i,n in enumerate(doc['nodes']):
        if i in kill_nodes:
            removed['nodes']+=1
            continue
        nn=dict(n)
        if 'mesh' in nn:
            nn['mesh']=mesh_map[nn['mesh']]
        node_map[i]=len(new_nodes)
        new_nodes.append(nn)
    scene['nodes']=[node_map[n] for n in scene['nodes'] if n in node_map]
    doc['meshes']=new_meshes
    doc['nodes']=new_nodes
    return removed


def shift_platform(doc, buf):
    moved_vertices=0
    moved_triangles=0
    delta=-SHIFT_LOCAL  # toward hall wall; user described as ~1 m west
    # find the R24 hall/platform mesh
    mesh_index=None
    for i,m in enumerate(doc['meshes']):
        if m.get('name')==PLATFORM_MESH_NAME:
            mesh_index=i;break
    if mesh_index is None:
        raise ValueError('Platform mesh not found')
    mesh=doc['meshes'][mesh_index]
    for prim in mesh['primitives']:
        pos=get_accessor(doc,buf,prim['attributes']['POSITION'])@AXIS.T
        idx=get_accessor(doc,buf,prim['indices']).reshape(-1,3)
        # select the platform assembly only (deck, posts, rails, braces)
        mask=((pos[:,0]>-5.02)&(pos[:,0]<-4.77)&
              (pos[:,1]>-0.90)&(pos[:,1]<-0.60)&
              (pos[:,2]>-0.40)&(pos[:,2]<0.20))
        if not mask.any():
            continue
        # ensure we are moving only triangles fully inside the platform cluster
        tri_mask=mask[idx].all(axis=1)
        if not tri_mask.any():
            continue
        verts=np.unique(idx[tri_mask].ravel())
        out=pos.copy()
        out[verts,1]+=delta
        moved_vertices+=len(verts)
        moved_triangles+=int(tri_mask.sum())
        prim['attributes']['POSITION']=append_accessor(doc,buf,(out@AXIS).astype('<f4'),'VEC3',5126,34962)
    return {'mesh_index':mesh_index,'shift_local_y':delta,'shift_m':round(abs(delta*SCALE),2),
            'moved_vertices':moved_vertices,'moved_triangles':moved_triangles}


def main(source, output, collision, report):
    raw=Path(source).read_bytes(); sha=hashlib.sha256(raw).hexdigest()
    if sha!=SOURCE_SHA:
        raise ValueError(f'Expected R28.2 GLB {SOURCE_SHA}; got {sha}')
    n=struct.unpack_from('<I',raw,12)[0]
    doc=json.loads(raw[20:20+n]); buf=bytearray(raw[28+n:])
    removed=remove_last_connector(doc)
    shift=shift_platform(doc,buf)
    doc['asset']['extras']['modifications'] += (
        ' R28.3: remove the ad-hoc hall-platform wall connector from R28.2 and '
        'shift the entire small north-east exterior platform about one metre '
        'westward toward the facade, matching the latest user comparison. '
        'No additional platform attachment object remains.'
    )
    buf=compact(doc,buf)
    serialize_glb(doc,buf,output)
    v,t=read_glb(output)
    unique=np.unique(np.sort(t,axis=1),axis=0)
    stats=build(v,unique,collision)
    stats.update({
        'revision':'R28.3',
        'source_sha256':sha,
        'glb_sha256':hashlib.sha256(Path(output).read_bytes()).hexdigest(),
        'fpc_sha256':hashlib.sha256(Path(collision).read_bytes()).hexdigest(),
        'removed_connector':removed,
        'platform_shift':shift,
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
