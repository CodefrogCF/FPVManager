#!/usr/bin/env python3
"""R16 photographic corrections for the R15 Rüdersdorf site reconstruction.

This is a targeted and reversible edit, not a geodetic survey:
* Close the erroneously opened roof above the six-silo stair gallery; the
  intermediate stair shaft remains passable where it was already open.
* Remove the four-sided guard frame around that former roof aperture.
* Reconstruct the sheltered rooftop superstructure as an OPEN window-frame
  shell with a continuous roof, rather than an opaque solid headhouse.
* Move the former-ladder exterior platform to the north-east hall corner and
  replace its solid grating with a wide central opening (actual geometry).
* Move the short adjacent abandoned rooftop pipe and its mounts accordingly.

The third-party source asset is CC BY-NC 4.0 and must remain local. Geometry
and FPC are rebuilt together from one triangle source. The R11 DGM underlay
and site alignment are never modified.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import struct

import numpy as np

from build_collision import AXIS, build, read_glb
from reconstruct_ruedersdorf_r6 import Mesh, beam
from refine_ruedersdorf_r13 import compact, get_accessor
from refine_ruedersdorf_r15_silo import append_accessor

BASE_SHA = '0cae1ed0405ac32482b582498d03f954cd82d42f20042b276f700ef0734872c3'
SCALE = 16.023268178233355
OLD_PLATFORM = (-5.02, -4.78, -2.55, -2.31)
# x increases approximately north and -y approximately east under site heading.
# The source photograph locates the platform at the north-east hall corner;
# exact edges are an approximation as the perspective is not surveyed.
NEW_PLATFORM = (-2.91, -2.67, -2.55, -2.31)
HOLE = (-2.873, -2.707, -2.513, -2.347)
ROOF_HOLE = (4.43, 4.94, -2.262, -2.142)
ROOF_Z = (-.253, -.230)


def replace_indices(doc, buf, prim, indices):
    original = doc['accessors'][prim['indices']]
    component = original['componentType']
    arr = np.asarray(indices, dtype='<u2' if component == 5123 else '<u4').reshape(-1)
    prim['indices'] = append_accessor(doc, buf, arr, 'SCALAR', component, 34963)


def filter_generated_faces(doc, buf):
    """Remove only bounded R15 synthetic triangles, never original RAWscan."""
    counts = {}
    for im, mesh in enumerate(doc['meshes']):
        empty_primitives = []
        if im not in (17, 18):
            continue
        for ip, prim in enumerate(mesh['primitives']):
            mat = doc['materials'][prim['material']]['name']
            xyz = get_accessor(doc, buf, prim['attributes']['POSITION']) @ AXIS.T
            triangles = get_accessor(doc, buf, prim['indices']).reshape(-1, 3)
            center = xyz[triangles].mean(axis=1)
            x, y, z = center.T
            remove = np.zeros(len(triangles), dtype=bool)
            if im == 17:
                if mat == 'R15 safety steel':
                    # Obsolete south-end landing, rails, brackets and old pipe.
                    remove |= ((x > -5.09) & (x < -4.69) &
                               (y > -2.59) & (y < -2.24) &
                               (z > -.41) & (z < .08))
                    remove |= ((x > -4.78) & (x < -4.4) &
                               (y > -2.12) & (y < -1.88) &
                               (z > -.10) & (z < .11))
                elif mat in ('R12 r6_concrete', 'R12 roof'):
                    # Old pipe mounts or nearby ribs added in R15. Remove
                    # additions only: mesh 15 original roof remains intact.
                    remove[:] = True
            elif im == 18 and mat == 'R12 r6_metal':
                # The R15 rim above the false roof hole (96 triangle faces).
                # Stair guard rails below -.37 are left untouched.
                remove |= ((x > 4.40) & (x < 4.98) &
                           (y > -2.30) & (y < -2.11) &
                           (z > -.24) & (z < -.11))
            if np.any(remove):
                if im == 17 and mat == 'R15 safety steel':
                    assert int(remove.sum()) == 552, f'R15 synthetic platform/pipe changed: {remove.sum()}'
                if im == 18 and mat == 'R12 r6_metal':
                    assert int(remove.sum()) == 96, f'R15 roof rim changed: {remove.sum()}'
                if np.all(remove):
                    empty_primitives.append(ip)
                else:
                    replace_indices(doc, buf, prim, triangles[~remove])
                counts[f'mesh{im}_primitive{ip}_{mat}'] = int(remove.sum())
        for index in reversed(empty_primitives):
            mesh['primitives'].pop(index)
    assert sum(counts.values()) >= 700, counts
    return counts


def add_roof_and_equipment_gallery(mesh):
    """Real solid roof; preserve the open stairwell BELOW the roof deck."""
    mesh.part = 'R16 six-silo roof closure'
    x0, x1, y0, y1 = ROOF_HOLE
    z0, z1 = ROOF_Z
    mesh.box(x0, x1, y0, y1, z0, z1, 'roof')

    # Historically visible rooftop access/equipment room. R15 incorrectly
    # removed the prior solid headhouse entirely. Reconstruct as a lightweight
    # concrete frame with open/broken window apertures and an INTACT roof.
    # The surrounding R15 stair tower stays open under this level.
    mesh.part = 'R16 silo rooftop enclosed gallery frame'
    hx0, hx1, hy0, hy1 = 4.327, 4.981, -2.278, -2.082
    lower, upper = -.230, -.119
    # The surrounding frame does NOT cut the main roof slab below.
    for x in [hx0, 4.54, 4.75, hx1]:
        for y in [hy0, hy1]:
            mesh.box(x-.010, x+.010, y-.009, y+.009, lower, upper, 'concrete')
    for y in [hy0, hy1]:
        for zlo, zhi in [(lower, lower+.022), (upper-.024, upper)]:
            mesh.box(hx0, hx1, y-.011, y+.011, zlo, zhi, 'concrete')
    for x in [hx0, hx1]:
        for zlo, zhi in [(lower, lower+.022), (upper-.024, upper)]:
            mesh.box(x-.010, x+.010, hy0, hy1, zlo, zhi, 'concrete')
    # Roof on equipment gallery: fully continuous, no cutout or false hatch.
    mesh.box(hx0-.019, hx1+.019, hy0-.023, hy1+.023,
             upper-.008, upper+.011, 'roof')
    # Thin window mullions only where the photograph indicates exposed
    # industrial strip windows; avoid broad glass collision planes.
    for x in [4.435, 4.645, 4.854]:
        for y in [hy0, hy1]:
            mesh.box(x-.003, x+.003, y-.012, y+.012,
                     lower+.025, upper-.025, 'metal')


def ring_strip(mesh, xo0, xo1, yo0, yo1, xi0, xi1, yi0, yi1,
               zl, zh, material='metal'):
    """Four non-overlapping strips; the interior is empty, not transparent."""
    mesh.box(xo0, xi0, yo0, yo1, zl, zh, material)
    mesh.box(xi1, xo1, yo0, yo1, zl, zh, material)
    mesh.box(xi0, xi1, yo0, yi0, zl, zh, material)
    mesh.box(xi0, xi1, yi1, yo1, zl, zh, material)


def add_corrected_exterior_platform(mesh):
    mesh.part = 'R16 north-east exterior former ladder platform'
    x0, x1, y0, y1 = NEW_PLATFORM
    xi0, xi1, yi0, yi1 = HOLE
    z = -.117
    ring_strip(mesh, x0, x1, y0, y1, xi0, xi1, yi0, yi1,
               z-.008, z, 'metal')
    # 3-sided outer fence; an attachment/access side faces the hall.
    top = z+.135
    for x in (x0, x1):
        for y in (y0, y1):
            mesh.box(x-.0045, x+.0045, y-.0045, y+.0045,
                     z, top, 'metal')
    # rail along the outside facade edge and along short outside return.
    mesh.box(x0, x1, y0-.004, y0+.004, top-.007, top, 'metal')
    mesh.box(x0, x1, y0-.004, y0+.004, z+.065, z+.071, 'metal')
    for x in (x0, x1):
        mesh.box(x-.004, x+.004, y0, y1-.02, top-.007, top, 'metal')
    # Slender outriggers below rim; keep vertical center passage free.
    for x in (x0+.022, x1-.022):
        beam(mesh, (x, y1+.020, z-.16), (x, y0+.014, z-.008),
             .009, .009, 'metal')
        mesh.box(x-.007, x+.007, y1-.013, y1+.022,
                 z-.175, z-.145, 'metal')
    # Rim edging around large central opening, with NO crossing grating.
    for x in (xi0, xi1):
        mesh.box(x-.003, x+.003, yi0, yi1,
                 z-.008, z+.004, 'metal')
    for y in (yi0, yi1):
        mesh.box(xi0, xi1, y-.003, y+.003,
                 z-.008, z+.004, 'metal')
    # Spaced grating only ON the four exterior strips, not across opening.
    for xx in np.arange(x0+.013, x1-.009, .017):
        for ya,yb in ((y0+.009,yi0),(yi1,y1-.009)):
            if yb > ya:
                mesh.box(xx-.0015, xx+.0015, ya, yb, z-.003, z, 'metal')
    # Adjacent short pipe relocates with corrected north-east structure.
    mesh.part = 'R16 north-east hall roof pipe'
    mesh.cylinder((-2.972,-1.978,-.033),.027,.235,0,'metal',24)
    for x in (-3.060,-2.873):
        mesh.box(x-.008,x+.008,-1.998,-1.958,-.075,-.061,'concrete')
    mesh.part = 'R16 local hall roof ribs'
    for yy in (-1.91, -1.84, -1.77):
        mesh.box(-3.11,-2.70,yy-.004, yy+.004,
                 -.076,-.070,'roof')


def append_generated_mesh(doc, buf, geom):
    mats = {x.get('name'): i for i,x in enumerate(doc['materials'])}
    material = {'metal': mats['R15 safety steel'],
                'concrete': mats['R12 r6_concrete'],
                'roof': mats['R12 r6_roof']}
    prims=[];faces={}
    for name,group in geom.groups.items():
        if not group:
            continue
        pos = np.concatenate([f[0] for f in group]).astype('<f4')
        normal = np.concatenate([np.repeat(f[1][None,:],3,axis=0) for f in group]).astype('<f4')
        uv = np.concatenate([f[2] for f in group]).astype('<f4')
        assert len(pos) < 65535
        positions = append_accessor(doc, buf, (pos@AXIS).astype('<f4'), 'VEC3',5126,34962)
        normals = append_accessor(doc, buf, (normal@AXIS).astype('<f4'),'VEC3',5126,34962)
        uvs = append_accessor(doc, buf, uv,'VEC2',5126,34962)
        indices = append_accessor(doc, buf, np.arange(len(pos),dtype='<u2'),
                                  'SCALAR',5123,34963)
        prims.append({'attributes':{'POSITION':positions,'NORMAL':normals,
                                    'TEXCOORD_0':uvs},'indices':indices,
                      'material':material[name], 'mode':4})
        faces[name] = len(group)
    idx = len(doc['meshes'])
    doc['meshes'].append({'name':'R16 corrected roof closure and north-east hall platform',
                          'primitives':prims})
    ni=len(doc['nodes'])
    doc['nodes'].append({'name':'R16 roof and external open-center access platform',
                         'mesh':idx})
    doc['scenes'][doc.get('scene',0)]['nodes'].append(ni)
    return faces


def main(source, output, fpc_path, report_path):
    raw=Path(source).read_bytes()
    source_hash=hashlib.sha256(raw).hexdigest()
    if source_hash != BASE_SHA:
        raise ValueError(f'Expected validated R15 six-silo model {BASE_SHA}, got {source_hash}')
    jlen=struct.unpack_from('<I',raw,12)[0]
    doc=json.loads(raw[20:20+jlen]);binbuf=bytearray(raw[28+jlen:])
    oldroot=doc['nodes'][0].get('matrix')
    removed=filter_generated_faces(doc,binbuf)
    geom=Mesh()
    add_roof_and_equipment_gallery(geom)
    add_corrected_exterior_platform(geom)
    added=append_generated_mesh(doc,binbuf,geom)
    binbuf=compact(doc,binbuf)
    doc['asset']['extras']['modifications'] += (' R16: closes previously invented six-silo rooftop dive aperture '
        'and removes obsolete rim; rooftop frame with continuous closed roof; moves the former-ladder '
        'exterior platform to the north-east long-hall corner, reconstructs a large true central fly-through '
        'hole in the platform, repositions adjacent pipe and roof ribs; no change to surveyed status; '
        'all details are photo-guided approximations, CC BY-NC 4.0.')
    payload=json.dumps(doc,separators=(',',':'),ensure_ascii=False).encode('utf8')
    payload+=b' '*(-len(payload)%4)
    data=(struct.pack('<I4s',len(payload),b'JSON')+payload+
          struct.pack('<I4s',len(binbuf),b'BIN\0')+binbuf)
    Path(output).parent.mkdir(parents=True,exist_ok=True)
    Path(output).write_bytes(struct.pack('<4sII',b'glTF',2,len(data)+12)+data)
    assert doc['nodes'][0].get('matrix') == oldroot, 'Source registration changed'
    verts, faces = read_glb(output)
    # Duplicate faces at the same positions never need multiple contacts.
    unique_indices=np.unique(np.sort(faces,axis=1),axis=0,return_index=True)[1]
    result=build(verts,faces[np.sort(unique_indices)],fpc_path)
    fb=Path(fpc_path).read_bytes()
    nv,nt,_=struct.unpack_from('<III',fb,4)
    collider_vertices=np.frombuffer(fb,dtype='<f4',count=nv*3,offset=16).reshape(-1,3)
    collider_faces=np.frombuffer(fb,dtype='<u4',count=nt*3,offset=16+nv*12).reshape(-1,3)
    assert np.array_equal(verts,collider_vertices)
    assert np.array_equal(np.unique(np.sort(collider_faces,axis=1),axis=0),
                          np.unique(np.sort(faces,axis=1),axis=0))
    result.update({'r16':True,'source_sha256':source_hash,
        'glb_sha256':hashlib.sha256(Path(output).read_bytes()).hexdigest(),
        'fpc_sha256':hashlib.sha256(fb).hexdigest(),
        'removed_triangles':removed,'added_triangles':added,
        'visual_triangles':int(len(faces)), 'roof_hole_closed':ROOF_HOLE,
        'old_platform_removed':OLD_PLATFORM,'new_platform':NEW_PLATFORM,
        'platform_hole_local':HOLE,
        'platform_hole_size_m':[(HOLE[1]-HOLE[0])*SCALE,(HOLE[3]-HOLE[2])*SCALE],
        'site_alignment_preserved':True,'dgm_underlay_preserved':True,
        'photogrammetric_survey':False})
    Path(report_path).write_text(json.dumps(result,indent=2,ensure_ascii=False)+'\n')
    print(json.dumps(result,indent=2,ensure_ascii=False))

if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    for arg in ('source','output','collision','report'):
        parser.add_argument(arg)
    args=parser.parse_args()
    main(args.source,args.output,args.collision,args.report)
