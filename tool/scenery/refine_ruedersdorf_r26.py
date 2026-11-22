#!/usr/bin/env python3
"""R26: replace the southwest ruin annex with independently modelled architecture.

The rebuild supersedes (not overlays) original RAWscan textured surfaces and
older R17/R19/R21/R23 procedural pieces *inside a bounded building volume*.
Fragment geometry on the boundary is clipped, retaining UV/normals/attribution
outside the mask. Terrain below the cut remains intact. GLB and FPC are built
from precisely the same final geometry.

The 3D outline and roof heights are taken from the existing scan and procedural
site survey approximation. Photos/panoramas constrain damaged architectural
features rather than metrically identifying each feature. A nearby damaged
forebuilding in the courtyard photos is NOT assumed to be this annex.
"""
from __future__ import annotations
import argparse
import hashlib
import json
import struct
from pathlib import Path

import numpy as np
from build_collision import AXIS, read_glb, build
from reconstruct_ruedersdorf_r6 import Mesh, beam, rubble
from refine_ruedersdorf_r13 import compact, get_accessor
from refine_ruedersdorf_r24 import append_generated, serialize_glb
from refine_ruedersdorf_r25 import cut_mesh, vertical_wall

SOURCE_SHA = '8bb546743b924e434082eea54913cb8082e98d2e31915f877ce4fbba36aa3cb7'
SCALE = 16.023268178233355
# Local axes: +X = predominantly south, +Y = predominantly east.
# Mask stops above ground so scan-derived ground and site landscaping survive.
SOUTHWEST_CUT = (2.365, 4.305, -5.075, -4.455, -1.968, -1.220)
GENERATED_MESHES = (15, 20, 22, 24, 26)
ANNEX = (2.505, 4.135, -4.954, -4.580)
FLOOR = -1.958
UPPER = -1.662
EAVE = -1.355


def reconstruction(mesh: Mesh) -> dict:
    x0,x1,y0,y1=ANNEX
    mesh.part='R26 southwest annex discontinuous structural frame'
    xposts=[x0,3.095,3.425,3.845,x1]
    for x in xposts:
        for y in (y0+.018,y1-.018):
            mesh.box(x-.014,x+.014,y-.017,y+.017,FLOOR,EAVE,'concrete')
            # Small exposed capitals; do not fill window and doorway bays.
            mesh.box(x-.026,x+.026,y-.021,y+.021,EAVE-.052,EAVE-.027,'concrete')
    # Ensure that the two opposite outer walls have *real* door/window voids.
    mesh.part='R26 southwest annex cut-out lower masonry walls'
    front_open=[(2.77,3.06,FLOOR+.006,FLOOR+.294),
                (3.52,3.79,FLOOR+.006,FLOOR+.282),
                (2.55,2.71,FLOOR+.344,FLOOR+.488),
                (3.15,3.42,FLOOR+.341,FLOOR+.488),
                (3.83,4.08,FLOOR+.354,FLOOR+.488)]
    rear_open=[(2.69,2.99,FLOOR+.004,FLOOR+.296),
               (3.44,3.71,FLOOR+.008,FLOOR+.293),
               (2.55,2.74,FLOOR+.349,FLOOR+.481),
               (3.09,3.37,FLOOR+.340,FLOOR+.481),
               (3.82,4.11,FLOOR+.350,FLOOR+.485)]
    front_tiles=vertical_wall(mesh,'y',y0,(x0,x1),(FLOOR,EAVE-.071),front_open,
                              'brick',.018)
    # Rear masonry is partially missing; leave one full-height opening.
    rear_tiles=vertical_wall(mesh,'y',y1,(x0,x1),(FLOOR,EAVE-.095),rear_open,
                             'brick',.016)
    # Gables have open passages to neighboring structures and courtyard.
    left=[(y0+.088,y0+.270,FLOOR+.005,FLOOR+.283),
          (y0+.090,y0+.288,FLOOR+.338,FLOOR+.478)]
    right=[(y0+.076,y0+.303,FLOOR+.005,FLOOR+.307),
           (y0+.095,y0+.294,FLOOR+.342,FLOOR+.474)]
    gables=vertical_wall(mesh,'x',x0,(y0,y1),(FLOOR,EAVE-.070),left,'concrete',.016)
    gables+=vertical_wall(mesh,'x',x1,(y0,y1),(FLOOR,EAVE-.093),right,'concrete',.014)

    # Dark, loose glazing frames: transparent empty openings remain passable.
    mesh.part='R26 southwest annex remaining mullions and open windows'
    windows=0
    for x in (2.625,3.285,3.940):
        for y in (y0,y1):
            mesh.box(x-.003,x+.003,y-.012,y+.012,FLOOR+.340,FLOOR+.492,'metal')
            windows+=1

    # Open interior: retained ledges do not span the room width; the central
    # aisle is left open both horizontally and vertically.
    mesh.part='R26 southwest annex interrupted elevated service platforms'
    floor_sections=[(x0+.032,2.988,y1-.143,y1-.030),
                    (3.500,x1-.032,y1-.145,y1-.030),
                    (x0+.024,2.730,y0+.035,y0+.112),
                    (3.860,x1-.028,y0+.030,y0+.110)]
    for a,b,c,d in floor_sections:
        mesh.box(a,b,c,d,UPPER-.015,UPPER,'concrete')
    # Internal partitions stop short of the middle; there are no obsolete
    # full-width synthetic floors or sheets across doors.
    mesh.part='R26 southwest annex partial interior retaining walls'
    for x,a,b in [(2.985,y1-.143,y1-.030),(3.502,y1-.145,y1-.034)]:
        mesh.box(x-.012,x+.012,a,b,FLOOR+.02,UPPER-.007,'concrete')

    # Ruined exposed stair: real risers, no opaque stair-shaped block. It
    # climbs the interior edge beside the central circulation opening.
    mesh.part='R26 southwest annex broken stair and edge rails'
    stair_steps=11
    for i in range(stair_steps):
        y=y0+.076+i*.021
        z=FLOOR+(i+1)*(UPPER-FLOOR)/stair_steps
        # A few missing treads match the damaged, partly collapsed state.
        if i in (3,7):
            continue
        mesh.box(3.605,3.727,y,y+.018,z-.011,z,'concrete')
    beam(mesh,(3.600,y0+.071,FLOOR+.080),(3.600,y0+.309,UPPER+.081),.005,.006,'metal')
    beam(mesh,(3.734,y0+.077,FLOOR+.065),(3.734,y0+.303,UPPER+.080),.005,.006,'metal')
    # A detached sloping flight, fractured rather than continuous wall.
    mesh.part='R26 southwest annex damaged external flight remnants'
    for i in range(6):
        xx=3.80+i*.047
        z=FLOOR+.033*(i+1)
        if i!=4:
            mesh.box(xx,xx+.043,y0+.032,y0+.160,z-.010,z,'concrete')

    # Upper beams and a few surviving roof fragments. Wide central bays
    # are explicitly roof-open for free flight (no invisible ceiling).
    mesh.part='R26 southwest annex open and destroyed roof'
    roof_patches=[(x0+.018,x0+.272,y0+.020,y1-.018),
                  (3.226,3.466,y0+.020,y1-.020),
                  (3.952,x1-.020,y0+.018,y1-.018)]
    for a,b,c,d in roof_patches:
        mesh.box(a,b,c,d,EAVE-.024,EAVE,'roof')
    rafters=0
    for x in xposts:
        beam(mesh,(x,y0+.021,EAVE-.027),(x,y1-.021,EAVE-.027),.009,.011,'concrete')
        rafters+=1
    for y in (y0+.036,y1-.036):
        for a,b in ((x0+.029,x0+.270),(3.227,3.461),(3.956,x1-.025)):
            beam(mesh,(a,y,EAVE-.011),(b,y,EAVE-.011),.008,.010,'metal')

    mesh.part='R26 southwest annex broken braces, debris and metal scraps'
    braces=0
    for xa,xb in ((x0+.052,x0+.290),(3.240,3.448),(3.907,x1-.045)):
        beam(mesh,(xa,y0+.018,UPPER+.045),(xb,y1-.019,EAVE-.030),.008,.010,'metal')
        braces+=1
    # Small deterministic rubble piles inside the perimeter; no sealed entry.
    for i,center in enumerate([(2.600,-4.765,FLOOR-.003),
                               (3.208,-4.770,FLOOR-.002),
                               (4.030,-4.801,FLOOR-.003)]):
        rubble(mesh,center,.105,.075,.035,.19*i,i+501)

    return {'approximate_footprint_local':[x0,x1,y0,y1],
            'approximate_footprint_m':[round((x1-x0)*SCALE,1),round((y1-y0)*SCALE,1)],
            'wall_panels':front_tiles+rear_tiles+gables,
            'doors_or_passages':6,'window_voids':8,'window_mullions':windows,
            'elevated_floor_fragments':len(floor_sections),
            'stair_treads':stair_steps-2+5,
            'roof_patches':len(roof_patches),'open_roof_bays':2,
            'rafters':rafters,'diagonal_braces':braces,
            'floor_elevation_local':FLOOR,'roof_elevation_local':EAVE,
            'damaged_forebuilding_photos_exactly_registered':False}


def main(src,dst,fpc,report):
    raw=Path(src).read_bytes(); sha=hashlib.sha256(raw).hexdigest()
    if sha!=SOURCE_SHA:
        raise ValueError(f'Expected verified R25 GLB {SOURCE_SHA}, got {sha}')
    n=struct.unpack_from('<I',raw,12)[0]
    doc=json.loads(raw[20:20+n]); buf=bytearray(raw[28+n:])
    assert len(doc['meshes'])==29 and doc['meshes'][-1]['name'].startswith('R25')
    scan_names=[m['name'] for m in doc['meshes'][:15]]
    root_before=json.dumps(doc['nodes'][0],sort_keys=True)
    scan_cut={str(mi):cut_mesh(doc,buf,mi,SOUTHWEST_CUT,raw_scan=True)
              for mi in range(15)}
    old_cut={str(mi):cut_mesh(doc,buf,mi,SOUTHWEST_CUT)
             for mi in GENERATED_MESHES}
    raw_deleted=sum(v['removed_fully'] for v in scan_cut.values())
    old_deleted=sum(v['removed_fully'] for v in old_cut.values())
    assert raw_deleted>=2500, f'Target region unexpectedly empty: {raw_deleted}'
    assert old_deleted>=300, f'Old overlays not removed: {old_deleted}'
    for mesh in doc['meshes']:
        mesh['primitives']=[p for p in mesh['primitives']
                            if doc['accessors'][p['indices']]['count']>0]
    geom=Mesh()
    built=reconstruction(geom)
    added=append_generated(doc,buf,geom,
      'R26 south-west annex replaced scan shell with open ruin architecture',
      'R26 photo-guided ruin replacement, exposed treads and roof gaps')
    extras=doc['asset'].setdefault('extras',{})
    extras['modifications']=extras.get('modifications','')+(
        ' R26: southwest ruined annex (x2.365..4.305, y-5.075..-4.455, '
        'z-1.968..-1.220) clipped out of original photogrammetry, including '
        'partially intersecting scan faces with interpolated source UVs, and '
        'obsolete generated R17/R19/R21/R23 overlays. Replaced with an original '
        'open/ruined construction: pilasters, passages and windows cut through '
        'masonry, incomplete elevated platforms, broken stairs, exposed beams, '
        'partial roof. Retain scan terrain beneath and outside mask, unchanged '
        'world placement, site attribution and all other existing structures. '
        'Building proportions remain unsurveyed approximations.')
    buf=compact(doc,buf)
    assert root_before==json.dumps(doc['nodes'][0],sort_keys=True)
    assert scan_names==[m['name'] for m in doc['meshes'][:15]]
    serialize_glb(doc,buf,dst)
    v,t=read_glb(dst)
    unique=np.unique(np.sort(t,axis=1),axis=0)
    summary=build(v,unique,fpc)
    data=Path(fpc).read_bytes()
    magic,nv,nt,_=struct.unpack_from('<4sIII',data)
    assert magic==b'FPC1' and nv==len(v) and nt==len(unique)
    vv=np.frombuffer(data,dtype='<f4',count=nv*3,offset=16).reshape(-1,3)
    assert np.array_equal(v,vv)
    summary.update(revision='R26',r25_input_sha256=sha,
      glb_sha256=hashlib.sha256(Path(dst).read_bytes()).hexdigest(),
      fpc_sha256=hashlib.sha256(data).hexdigest(),
      original_scan_cut=scan_cut,obsolete_generated_cut=old_cut,
      original_scan_triangles_fully_removed=raw_deleted,
      old_procedural_triangles_fully_removed=old_deleted,
      scan_boundary_clipped_triangles=sum(vv['clipped_partial'] for vv in scan_cut.values()),
      retained_scan_mesh_groups=15,georeference_unchanged=True,
      model_details=built,new_geometry_by_material=added,
      visible_triangles=len(t),unique_collision_triangles=nt,
      cut_region_local=SOUTHWEST_CUT,photo_registration='unsurveyed')
    Path(report).parent.mkdir(parents=True,exist_ok=True)
    Path(report).write_text(json.dumps(summary,indent=2,ensure_ascii=False)+'\n')
    print(f'R26: removed {raw_deleted} original scan triangles and {old_deleted} older generated triangles; {len(t)} visual, {nt} collision')

if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__)
    for name in ('source','output','collision','report'):p.add_argument(name)
    a=p.parse_args();main(a.source,a.output,a.collision,a.report)
