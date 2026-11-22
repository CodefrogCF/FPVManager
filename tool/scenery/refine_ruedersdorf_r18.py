#!/usr/bin/env python3
"""R18 - cautious panorama-guided geometric improvements to the long hall.

Source: verified R17 GLB.  360-degree panoramas 15860..15865 constrain
large-hall upper side landings and vault-like rib silhouettes.  This first
pass deliberately does NOT place the eastern/northern/southern tanks and
stairs: those scenes still need reliable 3D registration to a particular
structure.  All coordinates are APPROXIMATE and are not surveyed.

Both visual faces and the FPV collider are rebuilt from the same geometry.
Photogrammetric meshes (first 15), original GLB root transform, silo roof
openings and R16 platform are preserved as-is. CC BY-NC 4.0 source attribution
remains in the GLB asset metadata.
"""
from __future__ import annotations
import argparse
import hashlib
import json
from pathlib import Path
import struct
import numpy as np
from build_collision import AXIS,build,read_glb
from reconstruct_ruedersdorf_r6 import Mesh,beam
from refine_ruedersdorf_r13 import compact,get_accessor
from refine_ruedersdorf_r17 import append_generated,region_hole_slab,SCALE,HALL_ROOF_BREACHES

SOURCE_SHA = '617b62e08b46aa04b23d507aa6eae38ebe421eca8431231e144e9bbbd8587a7b'
REFERENCES = [
  '15860_Grosse_Halle_Sued.jpg',
  '15861_Grosse_Halle_Kessel.jpg',
  '15862_Grosse_Halle_Aussicht.jpg',
  '15863_Grosse_Halle_Nord.jpg',
  '15864_Grosse_Halle_1_Stock.jpg',
  '15865_Grosse_Halle_Dach.jpg',
]


def add_long_hall_roof_haunches(mesh):
    """Expose segmental vault ribs beneath existing roof; preserve R17 apertures.

    Panoramas 15860 and 15862 show repeating crosswise curved members,
    whereas R17 supplies almost exclusively straight transverse beams.
    The structural shape is estimated (not registered or surveyed).
    """
    mesh.part='R18 long hall segmental vault ribs'
    xs=np.linspace(-4.965,-1.575,14)
    ya,yb=-2.265,-.919
    ym=(ya+yb)/2
    nseg=12
    for x in xs:
        previous=None
        for j in range(nseg+1):
            y=ya+(yb-ya)*j/nseg
            u=(y-ym)/((yb-ya)/2)
            # Near the eaves a rib drops 2.1m; it rises to nearly
            # touch the roof deck at the aisle center.
            z=-.164-.132*u*u
            point=(float(x),float(y),float(z))
            if previous is not None:
                # R17 has REAL roof perforations: omit ribs across their
                # clear footprints. Otherwise R18 would create invisible
                # dive collisions beneath the three missing roof panels.
                cx=(previous[0]+point[0])*.5
                cy=(previous[1]+point[1])*.5
                in_aperture=any(a-.022<cx<b+.022 and c-.022<cy<d+.022
                                for a,b,c,d in HALL_ROOF_BREACHES)
                if not in_aperture:
                    beam(mesh,previous,point,.012,.018,'concrete')
            previous=point
        # Short vertical spring-to-column bracket, leaving window bands free.
        for y in (ya,yb):
            mesh.box(x-.018,x+.018,y-.017,y+.017,-.315,-.275,'concrete')
    return {'cross_bays':len(xs),'segments_per_bay':nseg,'roof_panels_unchanged':True}


def add_hall_broken_galleries(mesh):
    """Short mezzanine slabs along BOTH walls, central void always open.

    15862 elevated panorama and 15864 first-floor panorama show side floor
    platforms with broken patches and columns, not a full-width second floor.
    Slabs are limited to a short part of the high hall; positions are guesses.
    """
    mesh.part='R18 large hall partially surviving side mezzanines'
    x0,x1=-4.88,-3.80
    left=(-2.271,-1.999)
    right=(-1.186,-.913)
    z0,z1=-1.276,-1.257
    holes=[(-4.61,-4.47,-2.243,-2.116),
           (-4.14,-4.00,-1.069,-.957)]
    polys=0
    for side in (left,right):
        candidate=[h for h in holes if side[0]<h[2] and h[3]<side[1]]
        polys+=region_hole_slab(mesh,(x0,x1,side[0],side[1]),candidate,z0,z1,'concrete')
    # Four exposed reinforced concrete edge girders support the fragments.
    # No beam crosses the generous 13m central dive aisle.
    mesh.part='R18 hall mezzanine support girders'
    for inner in (left[1],right[0]):
        for a,b in [(-4.87,-4.61),(-4.47,-3.81)] if inner==left[1] else [(-4.87,-4.14),(-4.00,-3.81)]:
            mesh.box(a,b,inner-.010,inner+.010,z0-.038,z0,'concrete')
    for x in (-4.85,-4.28,-3.82):
        for y in (-2.22,-.968):
            mesh.box(x-.021,x+.021,y-.021,y+.021,-1.914,z1,'concrete')
            mesh.box(x-.043,x+.043,y-.043,y+.043,-1.316,-1.277,'concrete')
    # Rusted remaining guardrails only in segments; central gap is NOT
    # covered by a mesh or glass and remains usable for FPV dives.
    mesh.part='R18 hall gallery metal edge rail remnants'
    for inner,spans in ((left[1],[(-4.82,-4.48),(-4.15,-3.84)]),
                        (right[0],[(-4.83,-4.31),(-4.07,-3.85)])):
        for a,b in spans:
            for x in np.linspace(a,b,4):
                mesh.box(x-.003,x+.003,inner-.004,inner+.004,z1,z1+.065,'metal')
            mesh.box(a,b,inner-.004,inner+.004,z1+.058,z1+.064,'metal')
    return {'elevated_z_local':[z0,z1],'side_bands_local':[left,right],
            'x_range_local':[x0,x1],'real_opening_middle_local':[left[1],right[0]],
            'floor_panel_tiles':polys,'estimated':True,'panorama_support':REFERENCES}


def main(source,output,collision,report):
    path=Path(source);raw=path.read_bytes(); digest=hashlib.sha256(raw).hexdigest()
    if digest!=SOURCE_SHA:
        raise ValueError(f'R18 requires verified R17 SHA {SOURCE_SHA}, got {digest}')
    n=struct.unpack_from('<I',raw,12)[0]
    doc=json.loads(raw[20:20+n]);buf=bytearray(raw[28+n:])
    root=json.dumps(doc['nodes'][0],sort_keys=True)
    source_names=[m['name'] for m in doc['meshes'][:15]]
    assert len(doc['meshes'])==21 and doc['meshes'][-1]['name'].startswith('R17')
    m=Mesh()
    arches=add_long_hall_roof_haunches(m)
    galleries=add_hall_broken_galleries(m)
    added=append_generated(doc,buf,m)
    doc['meshes'][-1]['name']='R18 panorama-guided elevated galleries and curved hall ribs'
    doc['nodes'][-1]['name']='R18 panoramic hall interior architecture'
    buf=compact(doc,buf)
    assert json.dumps(doc['nodes'][0],sort_keys=True)==root
    assert [k['name'] for k in doc['meshes'][:15]]==source_names
    doc['asset']['extras']['modifications']+=(
        ' R18: tentative partial first-floor side galleries with empty center '
        'and missing floor patches, segmental roof arch/haunch outlines, '
        'based on panoramas 15860 and 15862-15864. No measured registration; '
        'external platform and silo openings preserved without changes; '
        'original CC BY-NC 4.0 attribution retained.')
    doc['buffers'][0]['byteLength']=len(buf)
    b=json.dumps(doc,separators=(',',':'),ensure_ascii=False).encode('utf8');b+=b' '*(-len(b)%4)
    payload=struct.pack('<I4s',len(b),b'JSON')+b+struct.pack('<I4s',len(buf),b'BIN\0')+buf
    Path(output).parent.mkdir(parents=True,exist_ok=True)
    Path(output).write_bytes(struct.pack('<4sII',b'glTF',2,len(payload)+12)+payload)
    v,t=read_glb(output)
    _,unique=np.unique(np.sort(t,axis=1),axis=0,return_index=True)
    summary=build(v,t[np.sort(unique)],collision)
    data=Path(collision).read_bytes()
    nv,nt,nnodes=struct.unpack_from('<III',data,4)
    fv=np.frombuffer(data,dtype='<f4',count=nv*3,offset=16).reshape(-1,3)
    ft=np.frombuffer(data,dtype='<u4',count=nt*3,offset=16+nv*12).reshape(-1,3)
    assert np.array_equal(v,fv)
    assert np.array_equal(np.unique(np.sort(t,axis=1),axis=0),np.unique(np.sort(ft,axis=1),axis=0))
    summary.update({'revision':'R18','source_sha256':digest,
      'glb_sha256':hashlib.sha256(Path(output).read_bytes()).hexdigest(),
      'fpc_sha256':hashlib.sha256(data).hexdigest(),
      'source_meshes_preserved':15,'georeferencing_preserved':True,
      'added_triangles_by_material':added,'roof_haunches':arches,
      'broken_side_galleries':galleries,'visual_triangles':len(t),
      'photo_based_not_surveyed':True})
    Path(report).parent.mkdir(parents=True,exist_ok=True)
    Path(report).write_text(json.dumps(summary,ensure_ascii=False,indent=2)+'\n')
    print(json.dumps(summary,indent=2,ensure_ascii=False))

if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__)
    for field in ('source','output','collision','report'):p.add_argument(field)
    a=p.parse_args();main(a.source,a.output,a.collision,a.report)
