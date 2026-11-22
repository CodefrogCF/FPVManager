#!/usr/bin/env python3
"""R23: scoped reconstruction of a multi-level production block and two small annexes.

Build on sha-validated R22, preserving the original 15 source scan meshes,
world transform, R20 exterior platform and all existing central/southeast silo
roof semantics. Uses panorama 15875 and 15878 for *shape and typology* of the
existing synthetic open production block, without claiming photo registration.
Existing R6 upper side slabs are selectively replaced, NOT overlaid, so their
new holes are genuinely open in both GLB and FPC. Small north-edge utility
building uses scan-bounded footprint and roof height; southeast ruined strip
remains roof-open. All generated details are unmeasured approximations.
"""
from __future__ import annotations
import argparse, hashlib, json, struct
from pathlib import Path
import numpy as np
from build_collision import AXIS, build, read_glb
from reconstruct_ruedersdorf_r6 import Mesh, beam
from refine_ruedersdorf_r13 import compact, get_accessor
from refine_ruedersdorf_r17 import append_generated, replace_indices, SCALE, region_hole_slab
from refine_ruedersdorf_r20 import serialize_glb

SOURCE_SHA='1905fa96ba2b3a089d5da2775e53fbaf4e0e100a5cae28e528c36d23e01f99f0'
PRODUCTION=(-4.28,-2.62,1.76,3.46,-1.99,-.75)
NORTH_EDGE=(-4.52,-3.77,5.79,6.12,-1.96,-1.24)
RUIN=(2.35,4.30,-4.95,-4.59,-1.95,-1.32)
UPPER_HOLES={
 'west':(-4.185,-4.035,2.060,2.225),
 'east':(-2.875,-2.725,2.405,2.585),
}


def remove_top_production_side_slabs(doc,buf):
    """Replace exactly two synthetic R6 top-tier side slab *boxes*."""
    removed=0
    for pr in doc['meshes'][15]['primitives']:
        if doc['materials'][pr['material']]['name']!='R12 r6_floor':continue
        pos=get_accessor(doc,buf,pr['attributes']['POSITION'])@AXIS.T
        tris=get_accessor(doc,buf,pr['indices']).reshape(-1,3)
        lo=pos[tris].min(1);hi=pos[tris].max(1)
        bounds=[(-4.240,-3.960,1.790,3.430),(-2.940,-2.660,1.790,3.430)]
        kill=np.zeros(len(tris),bool)
        for x0,x1,y0,y1 in bounds:
            kill|=((lo[:,0]>=x0-.0001)&(hi[:,0]<=x1+.0001)&
                    (lo[:,1]>=y0-.0001)&(hi[:,1]<=y1+.0001)&
                    (lo[:,2]>=-1.1841)&(hi[:,2]<=-1.1599)&
                    ((lo[:,1]<3.175)|((hi[:,0]-lo[:,0])>.1)))
        removed+=int(kill.sum())
        if kill.any():replace_indices(doc,buf,pr,tris[~kill])
    assert removed==24,('unexpected synthetic deck change',removed)
    return removed


def production_atrium(m):
    """Panorama-guided coffered soffit, fragmentary side decks and stair trim.

    No speculative new central solid deck: R6's existing vertical atrium stays
    free. Upper side slabs are distinct pieces with holes, replacing full R6
    slab boxes. Use narrow, high roof ribs that do not cap the center void.
    """
    m.part='R23 production block top deck with 2 real service openings'
    z0,z1=-1.184,-1.160
    plates=0
    for outer,hole in [((-4.24,-3.96,1.79,3.43),UPPER_HOLES['west']),
                       ((-2.94,-2.66,1.79,3.43),UPPER_HOLES['east'])]:
        plates+=region_hole_slab(m,outer,[hole],z0,z1,'concrete')
    m.part='R23 production block exposed hatch rims'
    for hx0,hx1,hy0,hy1 in UPPER_HOLES.values():
        for x in (hx0,hx1):m.box(x-.003,x+.003,hy0,hy1,z0-.007,z1+.003,'metal')
        for y in (hy0,hy1):m.box(hx0,hx1,y-.003,y+.003,z0-.007,z1+.003,'metal')
        # One short remnant of protective rail, deliberately NOT a full cage.
        for x in (hx0,hx1):m.box(x-.003,x+.003,hy0-.002,hy0+.002,z1,z1+.064,'metal')
        beam(m,(hx0,hy0,z1+.059),(hx1,hy0,z1+.059),.004,.004,'metal')

    # Existing -0.75 roof is scanned and must stay continuous; put concrete
    # arch/coffer ribs below it, not a second roof or a forced false skylight.
    m.part='R23 production block shallow-coffer roof soffit frame'
    arches=0
    for x in np.linspace(-4.185,-2.715,6):
        for ya,yb in zip(np.linspace(1.85,3.37,9)[:-1],np.linspace(1.85,3.37,9)[1:]):
            beam(m,(float(x),float(ya),-.807),
                 (float(x),float(yb),-.807),.010,.015,'concrete');arches+=1
    for y in np.linspace(1.85,3.37,9):
        beam(m,(-4.19,float(y),-.805),(-2.71,float(y),-.805),.011,.015,'concrete');arches+=1

    # Perimeter supports / distinct pier capitals; do not introduce a solid
    # rusty curtain through central stairs, atrium or door openings.
    m.part='R23 production block piers and split-beam capitals'
    piers=0
    for x in (-4.105,-2.795):
        for y in (1.92,2.34,3.32):
            m.box(x-.016,x+.016,y-.018,y+.018,-1.956,-.83,'concrete')
            m.box(x-.035,x+.035,y-.034,y+.034,-.895,-.864,'concrete')
            piers+=1
    m.part='R23 production block wall-mounted service brackets'
    for x in (-4.17,-2.73):
        for y in (1.99,2.40,2.99):
            beam(m,(x,y,-1.025),(x+(.04 if x<-3 else -.04),y,-.93),.007,.007,'metal')
    # Stair edge details fit R19 stair positions. No new solid landing inside
    # the main atrium or speculative new staircase position.
    m.part='R23 existing production switchback stair edge trims'
    rails=0
    for x,y0,y1,z0,z1 in [(-3.705,2.745,3.105,-1.925,-1.66),
                          (-3.275,2.755,3.115,-1.638,-1.365)]:
        beam(m,(x,y0,z0),(x,y1,z1),.004,.006,'metal');rails+=1
        for frac in (.18,.82):
            y=y0+(y1-y0)*frac;z=z0+(z1-z0)*frac
            beam(m,(x,y,z-.055),(x,y,z),.004,.004,'metal')
    return {'replaced_R6_slabs':2,'upper_floor_tile_count':plates,
            'real_open_service_holes_local':UPPER_HOLES,
            'coffer_underside_segments':arches,'inner_perimeter_piers':piers,
            'stair_guardrail_runs':rails,'roof_unchanged':True,
            'reference_shapes':['15875_Suedosthalle_innen.jpg','15878_Suedgebaeude_Lochraum.jpg'],
            'panorama_georegistration':'not established; architectural approximation only'}


def north_edge_utilities(m):
    """Existing 12x5m scan-footprint utility room, no new opaque roof."""
    xa,xb,ya,yb,ground,roof=NORTH_EDGE
    m.part='R23 north edge small utility frame'
    piers=0
    for x in np.linspace(xa+.055,xb-.055,5):
        for y in (ya+.035,yb-.035):
            m.box(x-.010,x+.010,y-.013,y+.013,ground+.045,roof-.018,'concrete')
            piers+=1
    m.part='R23 north edge utility windows and open service entrance'
    for y in (ya+.016,yb-.016):
        for x in np.linspace(xa+.11,xb-.11,6):
            # Only small mullions, no opaque glazing/large wall panels.
            m.box(x-.003,x+.003,y-.005,y+.005,ground+.29,roof-.09,'metal')
        beam(m,(xa+.09,y,ground+.30),(xb-.09,y,ground+.30),.004,.004,'metal')
    m.part='R23 north edge partial ceiling frame'
    for x in np.linspace(xa+.08,xb-.08,5):
        beam(m,(float(x),ya+.04,roof-.055),(float(x),yb-.04,roof-.055),.009,.014,'concrete')
    # Scanned roof geometry is left untouched. Free air beneath remains.
    return {'footprint_local':[xa,xb,ya,yb],'scan_roof_z':roof,
            'perimeter_supports':piers,'full_roof_invented':False,
            'references':['15871_Hof_Nordost.jpg','15880_Suedgebaeude_Aussicht_Nord.jpg'],
            'building_to_panorama_registration':False}


def southwest_ruin_bracing(m):
    """R19/R21 destroyed narrow annex: retain all roof and doorway gaps."""
    m.part='R23 partially collapsed south-west frame cross-ties'
    ties=0
    for x in (2.73,3.12,3.52,3.92):
        beam(m,(x,-4.935,-1.389),(x+.11,-4.60,-1.447),.006,.009,'concrete')
        beam(m,(x+.02,-4.927,-1.68),(x+.045,-4.72,-1.48),.005,.006,'metal')
        ties+=2
    m.part='R23 ruined annex discontinuous window lintels'
    for x0,x1 in ((2.66,2.93),(3.42,3.69),(3.83,4.06)):
        beam(m,(x0,-4.605,-1.59),(x1,-4.605,-1.59),.005,.008,'metal')
    return {'light_cross_ties':ties,'door_bays_unfilled':True,'no_new_roof':True,
            'references':['15883_Suedwesthalle.jpg','beschädigtes_vorgebäude_innen_blickrichtun_nord_ost_auf_nord_östliches_gebäude.jpg'],
            'approximation':True}


def main(source,output,collision,report):
    raw=Path(source).read_bytes();sha=hashlib.sha256(raw).hexdigest()
    if sha!=SOURCE_SHA:raise ValueError(f'Expected validated R22 GLB {SOURCE_SHA}; got {sha}')
    n=struct.unpack_from('<I',raw,12)[0];doc=json.loads(raw[20:20+n]);buf=bytearray(raw[28+n:])
    assert len(doc['meshes'])==26 and doc['meshes'][-1]['name'].startswith('R22')
    scan_before=[json.dumps(x,sort_keys=True) for x in doc['meshes'][:15]]
    root_before=json.dumps(doc['nodes'][0],sort_keys=True)
    removals=remove_top_production_side_slabs(doc,buf)
    m=Mesh()
    production=production_atrium(m)
    utility=north_edge_utilities(m)
    ruin=southwest_ruin_bracing(m)
    materials=append_generated(doc,buf,m)
    doc['meshes'][-1]['name']='R23 production atrium, north-edge utility and open ruin refinements'
    doc['nodes'][-1]['name']='R23 real top-side floor holes, roof coffers, exposed supports'
    doc['asset']['extras']['modifications']+=(
        ' R23: higher detail multi-storey open production block, replace exactly two procedural '
        'upper floor boxes with real cut-through service gaps (same visible/collision geometry); '
        'existing roof coffers, piers, stair-edge rails; scan-bounded small north-edge utility '
        'house and open annex frame remnants. Panoramas 15875, 15878 and 15883 constrain visual '
        'typology, NOT surveyed positions. Source scan, georeference, R20 platform, central four-silo '
        'roof dive and six-silo closed roof preserved. Not a safety map; CC BY-NC attribution.')
    buf=compact(doc,buf)
    assert scan_before==[json.dumps(x,sort_keys=True) for x in doc['meshes'][:15]]
    assert root_before==json.dumps(doc['nodes'][0],sort_keys=True)
    serialize_glb(doc,buf,output)
    v,t=read_glb(output)
    unique=np.unique(np.sort(t,axis=1),axis=0)
    stats=build(v,unique,collision)
    f=Path(collision).read_bytes();magic,nv,nt,_=struct.unpack_from('<4sIII',f)
    assert magic==b'FPC1' and nv==len(v) and nt==len(unique)
    fv=np.frombuffer(f,dtype='<f4',count=nv*3,offset=16).reshape(-1,3)
    assert np.array_equal(v,fv)
    stats.update(revision='R23',r22_sha256=sha,
                 glb_sha256=hashlib.sha256(Path(output).read_bytes()).hexdigest(),
                 fpc_sha256=hashlib.sha256(f).hexdigest(),
                 removed_synthetic_side_deck_triangles=removals,
                 original_scan_meshes_preserved=15,georeference_preserved=True,
                 r20_platform_and_silo_roof_semantics_preserved=True,
                 geometry_added_by_material=materials,
                 production_block=production,north_edge_utility=utility,
                 southwest_annex=ruin,
                 visual_triangles=len(t),unique_collision_triangles=nt,
                 panorama_position_is_unsurveyed=True)
    Path(report).parent.mkdir(parents=True,exist_ok=True)
    Path(report).write_text(json.dumps(stats,indent=2,ensure_ascii=False)+'\n')
    print(json.dumps(stats,indent=2,ensure_ascii=False))

if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__)
    for key in ('source','output','collision','report'):p.add_argument(key)
    a=p.parse_args();main(a.source,a.output,a.collision,a.report)
