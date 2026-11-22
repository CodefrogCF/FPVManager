#!/usr/bin/env python3
"""R15 revision: photo-aligned OPEN six-silo stair core and diveable roof.

Input: R15 exterior-platform GLB. Modifies only the local stair tower, its
rooftop gallery slab, and the previous photo-derived R15 rail overlay. The
adjacent existing R14 architecture and exterior ladder platform remain intact.
All geometry is approximate, not a survey. The owner's 2023 video frame shows
unobstructed inter-silo landings and flights with no continuous middle wall.
"""
from __future__ import annotations
import argparse,hashlib,json,struct
from pathlib import Path
import sys
import numpy as np
from build_collision import AXIS,read_glb,build
from reconstruct_ruedersdorf_r6 import Mesh,beam
from refine_ruedersdorf_r13 import get_accessor,compact

S=16.023268178233355
X0,X1=4.005,5.29
Y0,Y1=-2.29,-2.115
Z_LEVELS=[-2.005,-1.84,-1.60,-1.36,-1.14,-.91,-.70,-.47]
ROOF_HOLE=(4.43,4.94,-2.262,-2.142)
# top vertical dive center. No roof/slab/stair flight should touch this point.
TEST_XY=(4.79,-2.202)


def append_view(doc,buf,array,target=None):
    content=np.asarray(array).tobytes() if not isinstance(array,(bytes,bytearray)) else array
    buf.extend(b'\0'*(-len(buf)%4))
    off=len(buf);buf.extend(content)
    view={'buffer':0,'byteOffset':off,'byteLength':len(content)}
    if target is not None:view['target']=target
    idx=len(doc['bufferViews']);doc['bufferViews'].append(view)
    return idx


def append_accessor(doc,buf,array,kind,ctype,target):
    val=np.ascontiguousarray(array)
    meta={'bufferView':append_view(doc,buf,val,target),'componentType':ctype,'count':len(val),'type':kind}
    if kind=='VEC3' and target==34962:
        meta['min']=val.min(axis=0).tolist();meta['max']=val.max(axis=0).tolist()
    idx=len(doc['accessors']);doc['accessors'].append(meta)
    return idx


def is_in_bbox(pts,lo,hi,tol=1e-4):
    return np.all((pts>=np.array(lo)-tol)&(pts<=np.array(hi)+tol),axis=(1,2))


def cut_overlaps(doc,buf):
    report={}
    for mi,mesh in enumerate(doc['meshes']):
        if mi not in (15,17):
            continue
        for pi,prim in enumerate(mesh['primitives']):
            verts=get_accessor(doc,buf,prim['attributes']['POSITION'])@AXIS.T
            tri=get_accessor(doc,buf,prim['indices']).reshape(-1,3)
            xyz=verts[tri]
            center=xyz.mean(axis=1)
            mat=doc['materials'][prim['material']]['name']
            kill=np.zeros(len(tri),dtype=bool)
            if mi==15:
                # Remove the old R12 7-storey rebuild, including treads that
                # cross one another. Existing curved silos are in other meshes.
                if mat in ('R12 r6_floor','R12 r6_concrete','R12 r6_metal'):
                    tower=((center[:,0]>3.976)&(center[:,0]<5.318)&
                           (center[:,1]>-2.319)&(center[:,1]<-2.085)&
                           (center[:,2]>-2.065)&(center[:,2]<-.492))
                    kill|=tower
                # Delete JUST the 12 faces of the entire gallery roof/floor
                # box above the stair core. Reinsert a roof slab WITH an open
                # rectangular opening, not an invisible 'clipping' hole.
                if mat=='R12 r6_floor':
                    kill|=is_in_bbox(xyz,(3.999,-2.311,-.492),(5.301,-2.079,-.469))
                if mat=='R12 r6_roof':
                    kill|=is_in_bbox(xyz,(3.999,-2.311,-.254),(5.301,-2.079,-.229))
                # Remove the small solid headhouse covering the roof opening.
                if mat in ('R12 r6_brick','R12 r6_roof'):
                    kill|=is_in_bbox(xyz,(4.299,-2.281,-.231),(4.991,-2.079,-.112))
            else:
                # Replace the old R15 flight railing with rails following the
                # adjusted flights. It must not duplicate the new rail meshes.
                if mat=='R15 safety steel':
                    kill|=((center[:,0]>4.30)&(center[:,0]<5.0)&
                           (center[:,1]>-2.33)&(center[:,1]<-2.075)&
                           (center[:,2]>-2.06)&(center[:,2]<-.375))
            if np.any(kill):
                report[f'mesh{mi}_prim{pi}_{mat}']=int(kill.sum())
                old=doc['accessors'][prim['indices']]
                dtype='<u2' if old['componentType']==5123 else '<u4'
                replacement=tri[~kill].ravel().astype(dtype)
                prim['indices']=append_accessor(doc,buf,replacement,'SCALAR',old['componentType'],34963)
    return report


def add_gallery_ring(m,z0,z1,mat):
    # Replaces a rectangular solid slab by four NON-overlapping strips.
    # The source box is x=[4,5.3], y=[-2.31,-2.08].
    x0,x1,y0,y1=ROOF_HOLE
    m.box(4.0,5.30,-2.31,y0,z0,z1,mat)
    m.box(4.0,5.30,y1,-2.08,z0,z1,mat)
    m.box(4.0,x0,y0,y1,z0,z1,mat)
    m.box(x1,5.30,y0,y1,z0,z1,mat)


def add_rebuilt_stairs(m):
    m.part='R15 open six-silo stair frame'
    x0,x1,y0,y1=X0,X1,Y0,Y1
    # Only peripheral concrete posts and lateral cross beams. No center wall.
    xs=[x0,4.31,4.99,x1]
    for x in xs:
        for y in [y0,y1]:
            m.box(x-.018,x+.018,y-.015,y+.015,Z_LEVELS[0],Z_LEVELS[-1],'concrete')
    for k,z in enumerate(Z_LEVELS):
        # Perimeter beams at edges; leave the middle completely open.
        for y in [y0,y1]:
            m.box(x0,x1,y-.017,y+.017,z-.020,z,'concrete')
        for x in [x0,x1]:
            m.box(x-.021,x+.021,y0,y1,z-.025,z,'concrete')
        # two landing bays with a clear central shaft
        if k==0:
            m.box(x0,4.35,y0,y1,z-.021,z,'floor')
            m.box(4.95,x1,y0,y1,z-.021,z,'floor')
        else:
            m.box(x0,4.36,y0,y1,z-.020,z,'floor')
            m.box(4.94,x1,y0,y1,z-.020,z,'floor')
        # No full-width center deck; no passage-blocking slab.
    for k,(z0,z1) in enumerate(zip(Z_LEVELS[:-1],Z_LEVELS[1:])):
        # The lower and upper sides of the stairs alternate per story,
        # as seen in 2023 FPV footage: return flights, not crossing staircases.
        south=(k%2==0)
        ya,yb=(-2.278,-2.229) if south else (-2.178,-2.127)
        xs0,xs1=(4.35,4.94) if south else (4.94,4.35)
        for j in range(14):
            a=xs0+(xs1-xs0)*j/14
            b=xs0+(xs1-xs0)*(j+1)/14
            lo,hi=sorted((a,b))
            height=z0+(z1-z0)*(j+1)/14
            m.box(lo,hi,ya,yb,height-.010,height,'concrete')
        # Side rail placed outside stair flight, not in central dive shaft.
        yguard=ya-.008 if south else yb+.008
        beam(m,(xs0,yguard,z0+.06),(xs1,yguard,z1+.06),.004,.004,'metal')
        for portion in [0,0.5,1]:
            x=xs0+(xs1-xs0)*portion
            z=z0+(z1-z0)*portion
            beam(m,(x,yguard,z+.010),(x,yguard,z+.06),.003,.003,'metal')
        # Open-ended landing safety guard, not a full blocking wall.
        landx=4.94 if south else 4.35
        m.box(landx-.004,landx+.004,y0+.018,y0+.048,z1,z1+.057,'metal')
        m.box(landx-.004,landx+.004,y1-.047,y1-.018,z1,z1+.057,'metal')
    # The landing at rooftop level must not cap the central stair void.
    m.part='R15 open silo gallery roof'
    add_gallery_ring(m,-.491,-.470,'floor')
    add_gallery_ring(m,-.253,-.230,'roof')
    # Roof edge outline / fall-protection frame, no mesh across the hole.
    xa,xb,ya,yb=ROOF_HOLE
    for x in [xa,xb]:
        for y in [ya,yb]:
            m.box(x-.004,x+.004,y-.004,y+.004,-.230,-.152,'metal')
    for y in [ya,yb]:
        m.box(xa,xb,y-.004,y+.004,-.158,-.152,'metal')
    for x in [xa,xb]:
        m.box(x-.004,x+.004,ya,yb,-.158,-.152,'metal')


def add_geometry(doc,buf,m):
    available={x.get('name'):i for i,x in enumerate(doc['materials'])}
    mats={'floor':available['R12 r6_floor'],'concrete':available['R12 r6_concrete'],
          'metal':available['R12 r6_metal'],'roof':available['R12 r6_roof']}
    prims=[];counts={}
    for name,faces in m.groups.items():
        if not faces:continue
        pos=np.concatenate([f[0] for f in faces]).astype('<f4')
        norm=np.concatenate([np.repeat(f[1][None,:],3,axis=0) for f in faces]).astype('<f4')
        uv=np.concatenate([f[2] for f in faces]).astype('<f4')
        ia=append_accessor(doc,buf,(pos@AXIS).astype('<f4'),'VEC3',5126,34962)
        na=append_accessor(doc,buf,(norm@AXIS).astype('<f4'),'VEC3',5126,34962)
        ua=append_accessor(doc,buf,uv,'VEC2',5126,34962)
        indices=np.arange(len(pos),dtype='<u2' if len(pos)<=65535 else '<u4')
        idx=append_accessor(doc,buf,indices,'SCALAR',5123 if len(pos)<=65535 else 5125,34963)
        prims.append({'attributes':{'POSITION':ia,'NORMAL':na,'TEXCOORD_0':ua},
                      'indices':idx,'material':mats[name],'mode':4})
        counts[name]=len(faces)
    mid=len(doc['meshes'])
    doc['meshes'].append({'name':'R15 corrected open six-silo stair tower + roof dive','primitives':prims})
    ni=len(doc['nodes'])
    doc['nodes'].append({'name':'R15 corrected stair flights, no core wall, roof dive', 'mesh':mid})
    doc['scenes'][doc.get('scene',0)]['nodes'].append(ni)
    return counts


def main(src,dst,collision,report):
    raw=Path(src).read_bytes()
    jlen=struct.unpack_from('<I',raw,12)[0]
    doc=json.loads(raw[20:20+jlen]);buf=bytearray(raw[28+jlen:])
    if not any(m.get('name','').startswith('R15 exterior platform') for m in doc['meshes']):
        raise ValueError('Expected R15 external-platform GLB')
    removed=cut_overlaps(doc,buf)
    m=Mesh();add_rebuilt_stairs(m)
    generated=add_geometry(doc,buf,m)
    buf=compact(doc,buf)
    doc['asset']['extras']['modifications'] += (' R15 silo update: photo-guided open six-silo stair flights, no continuous central wall; '
        'cut two gallery slabs and remove solid headhouse, replace with roof opening and structural ring; '
        'external long-hall platform and intact long-hall roof unchanged. CC BY-NC 4.0.')
    j=json.dumps(doc,separators=(',',':'),ensure_ascii=False).encode();j+=b' '*(-len(j)%4)
    chunks=struct.pack('<I4s',len(j),b'JSON')+j+struct.pack('<I4s',len(buf),b'BIN\0')+buf
    Path(dst).write_bytes(struct.pack('<4sII',b'glTF',2,12+len(chunks))+chunks)
    verts,triangles=read_glb(dst)
    _,unique_idx=np.unique(np.sort(triangles,axis=1),axis=0,return_index=True)
    result=build(verts,triangles[np.sort(unique_idx)],collision)
    fpc=Path(collision).read_bytes()
    nverts,ntris,nnodes=struct.unpack_from('<III',fpc,4)
    fv=np.frombuffer(fpc,dtype='<f4',count=nverts*3,offset=16).reshape(-1,3)
    ft=np.frombuffer(fpc,dtype='<u4',count=ntris*3,offset=16+nverts*12).reshape(-1,3)
    assert np.array_equal(verts,fv)
    assert np.array_equal(np.unique(np.sort(ft,axis=1),axis=0),np.unique(np.sort(triangles,axis=1),axis=0))
    result.update({'removed_triangles':removed,'added_triangles':generated,'visual_triangles':len(triangles),
                   'sha256_glb':hashlib.sha256(Path(dst).read_bytes()).hexdigest(),
                   'sha256_fpc':hashlib.sha256(fpc).hexdigest(),
                   'roof_hole_local':ROOF_HOLE,'dive_center_local':TEST_XY,
                   'surveyed':False,'owner_video_frame_year':2023,'exterior_platform_untouched':True})
    Path(report).write_text(json.dumps(result,indent=2,ensure_ascii=False))
    print(json.dumps(result,indent=2,ensure_ascii=False))

if __name__=='__main__':
    p=argparse.ArgumentParser()
    for arg in ('src','dst','fpc','report'):p.add_argument(arg)
    a=p.parse_args();main(a.src,a.dst,a.fpc,a.report)
