#!/usr/bin/env python3
"""R29: restore missing *real* RAWscan faces from the user's original scene.gltf/bin.

R28.1 restored an R26 snapshot, not the complete original source. The alleged
'green roof' area had already lost most of its photographed building triangles
in the early local_reference conversion, even before R26. This pass copies ONLY
missing original triangles within a bounded courtyard footprint, preserving
original positions, normals and UVs, attaching them to the existing raw-scan
mesh nodes so the existing root orientation remains correct. No substitute
building is fabricated. The lightweight 1024x1024 version of the original
texture atlas is retained to avoid an abrupt GPU memory increase on mobile.

Input is the already shifted R28.3 GLB; R28.2's bridging connector is absent.
"""
from __future__ import annotations
import argparse, hashlib, json, struct
from pathlib import Path
import numpy as np
from build_collision import AXIS, build, read_glb
from refine_ruedersdorf_r13 import get_accessor, compact
from refine_ruedersdorf_r15_silo import append_accessor
from refine_ruedersdorf_r24 import serialize_glb

SOURCE_SHA='3abcb17deddb0184515240e0abdcdc08ef693101e56a726ec690b34b534f38f3'
RAW_GLTF_SHA='9183dd521f9934595a5af557bcd1d33e82bb6f8b55bf0f8a44f93c66e39fb929'
RAW_BIN_SHA='801c21d223605293e8cc7bdd40676ea98cd5bc20837bde7c0125af5b8faba016'
# Bounded original courtyard building, while the neighboring original scan
# building, silo geometry and all replacement structures remain undisturbed.
REGION=(-4.47,-2.54,1.57,3.68,-2.055,-0.60)


def key(face):
    # Source coordinates are original glTF float32. Round to resist harmless
    # float representation differences from previous compacting steps.
    corners=np.rint(np.asarray(face)*1e6).astype(np.int64)
    return tuple(sorted(map(tuple,corners.tolist())))


def data(doc,buf,p):
    a=p['attributes'];return (get_accessor(doc,buf,a['POSITION']),
                              get_accessor(doc,buf,a['NORMAL']),
                              get_accessor(doc,buf,a['TEXCOORD_0']),
                              get_accessor(doc,buf,p['indices']).reshape(-1,3))


def face_selection(xyz):
    # Triangle center inside bounded site and vertices within a narrow guard.
    # Avoid reintroducing large unrelated scan polygons across the plant.
    cx=xyz.mean(axis=1); lo=xyz.min(axis=1);hi=xyz.max(axis=1)
    x0,x1,y0,y1,z0,z1=REGION
    return ((cx[:,0]>=x0)&(cx[:,0]<=x1)&(cx[:,1]>=y0)&(cx[:,1]<=y1)&
            (cx[:,2]>=z0)&(cx[:,2]<=z1)&
            (lo[:,0]>=x0-.045)&(hi[:,0]<=x1+.045)&
            (lo[:,1]>=y0-.045)&(hi[:,1]<=y1+.045)&
            (lo[:,2]>=z0-.045)&(hi[:,2]<=z1+.045))


def restore(doc,buf,raw_doc,raw_buf):
    R=AXIS@np.array(doc['nodes'][0]['matrix'],dtype=float).reshape(4,4,order='F')[:3,:3]
    raw_R=AXIS@np.array(raw_doc['nodes'][0]['matrix'],dtype=float).reshape(4,4,order='F')[:3,:3]
    assert np.allclose(raw_R,R,atol=1e-9)
    assert len(raw_doc['meshes'])==15 and len(doc['meshes'])>=15
    assert all(raw_doc['meshes'][i]['name']==doc['meshes'][i]['name'] for i in range(15))
    result={'region_local':list(REGION),'restored_meshes':{},'existing_original_triangles':0,
            'candidate_original_triangles':0,'restored_original_triangles':0}
    for mi in range(15):
        existing=set()
        for p in doc['meshes'][mi]['primitives']:
            if p.get('material')!=0:continue
            pos,_,_,indices=data(doc,buf,p)
            xyz=pos[indices]@R.T
            sel=face_selection(xyz)
            for face in pos[indices][sel]:existing.add(key(face))
        recovered=[]
        for raw_prim in raw_doc['meshes'][mi]['primitives']:
            if raw_prim.get('material')!=0:continue
            rp,rn,ru,idx=data(raw_doc,raw_buf,raw_prim)
            xyz=rp[idx]@raw_R.T
            candidate=face_selection(xyz)
            result['candidate_original_triangles']+=int(candidate.sum())
            for face_ix in np.flatnonzero(candidate):
                ids=idx[face_ix]
                h=key(rp[ids])
                if h in existing:
                    result['existing_original_triangles']+=1
                    continue
                existing.add(h)
                recovered.append((rp[ids],rn[ids],ru[ids]))
        if not recovered:continue
        positions=np.concatenate([r[0] for r in recovered]).astype('<f4')
        normals=np.concatenate([r[1] for r in recovered]).astype('<f4')
        uvs=np.concatenate([r[2] for r in recovered]).astype('<f4')
        indices=np.arange(len(positions),dtype='<u2' if len(positions)<65536 else '<u4')
        ia=append_accessor(doc,buf,positions,'VEC3',5126,34962)
        na=append_accessor(doc,buf,normals,'VEC3',5126,34962)
        ua=append_accessor(doc,buf,uvs,'VEC2',5126,34962)
        ie=append_accessor(doc,buf,indices,'SCALAR',5123 if len(positions)<65536 else 5125,34963)
        # Existing original textured material 0 has compatible UV mapping.
        doc['meshes'][mi]['primitives'].append({
            'attributes':{'POSITION':ia,'NORMAL':na,'TEXCOORD_0':ua},
            'indices':ie,'material':0,'mode':4,
        })
        count=len(recovered)
        result['restored_meshes'][str(mi)]=count
        result['restored_original_triangles']+=count
    assert result['restored_original_triangles']>2500, result
    return result


def main(source,raw_gltf,raw_bin,output,collision,report):
    raw=Path(source).read_bytes();source_sha=hashlib.sha256(raw).hexdigest()
    if source_sha!=SOURCE_SHA:raise ValueError(f'Expected R28.3 asset {SOURCE_SHA}, got {source_sha}')
    gltf_bytes=Path(raw_gltf).read_bytes();bin_bytes=Path(raw_bin).read_bytes()
    if hashlib.sha256(gltf_bytes).hexdigest()!=RAW_GLTF_SHA or hashlib.sha256(bin_bytes).hexdigest()!=RAW_BIN_SHA:
        raise ValueError('Original 2022 RAWscan scene.gltf/scene.bin do not match the user source; refusing restoration')
    raw_doc=json.loads(gltf_bytes); raw_buf=bytearray(bin_bytes)
    n=struct.unpack_from('<I',raw,12)[0];doc=json.loads(raw[20:20+n]);buf=bytearray(raw[28+n:])
    root_before=json.dumps(doc['nodes'][0],sort_keys=True)
    result=restore(doc,buf,raw_doc,raw_buf)
    doc['asset']['extras']['modifications']+=(
        ' R29: restored the genuine 2022 Spognetta RAWscan building geometry and '
        'original UVs missing from the early local_reference conversion in the '
        'courtyard region; no fabricated green-roof building. R28.3 east facade '
        'platform relocation retained without R28.2 connector. The existing '
        'mobile-resolution original scan texture atlas is retained.')
    buf=compact(doc,buf)
    assert root_before==json.dumps(doc['nodes'][0],sort_keys=True)
    serialize_glb(doc,buf,output)
    v,t=read_glb(output)
    unique=np.unique(np.sort(t,axis=1),axis=0)
    stats=build(v,unique,collision)
    f=Path(collision).read_bytes();_,nv,nt,_=struct.unpack_from('<4sIII',f)
    assert nv==len(v) and nt==len(unique)
    assert np.array_equal(np.frombuffer(f,dtype='<f4',count=nv*3,offset=16).reshape(-1,3),v)
    stats.update(result)
    stats.update(revision='R29',r28_3_source_sha256=source_sha,
        original_raw_source_gltf_sha256=RAW_GLTF_SHA,
        original_raw_source_bin_sha256=RAW_BIN_SHA,
        glb_sha256=hashlib.sha256(Path(output).read_bytes()).hexdigest(),
        fpc_sha256=hashlib.sha256(f).hexdigest(),
        collidable_triangles=nt,original_material_0_retained=True)
    Path(report).parent.mkdir(parents=True,exist_ok=True)
    Path(report).write_text(json.dumps(stats,indent=2,ensure_ascii=False)+'\n')
    print(json.dumps({k:stats[k] for k in ('revision','restored_original_triangles','restored_meshes','collidable_triangles','glb_sha256','fpc_sha256')},indent=2))


if __name__=='__main__':
    a=argparse.ArgumentParser(description=__doc__)
    for v in ('source','raw_gltf','raw_bin','output','collision','report'):a.add_argument(v)
    args=a.parse_args();main(args.source,args.raw_gltf,args.raw_bin,args.output,args.collision,args.report)
