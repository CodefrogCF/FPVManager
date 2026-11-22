#!/usr/bin/env python3
"""R22: detail three less-developed annex groups without claiming photo registration.

Only SOURCE_SHA-validated R21 GLB is accepted. Original scan meshes, repaired
silo/hall openings, geographic registration and R20 exterior platform are
preserved byte-for-byte. Building *footprints and roof elevations* are
constrained by the current source scan; repeatable industrial details are
approximate from panoramas 15871, 15874 and 15884 (the latter UNLOCATED).

No speculative opaque roof plates, infill walls, or blocked entrances are added.
All new generated geometry appears in the paired GLB and FPC; neither is a
surveyed or safe real-flight obstacle model.
"""
from __future__ import annotations
import argparse,hashlib,json,struct
from pathlib import Path
import numpy as np
from build_collision import read_glb,build
from reconstruct_ruedersdorf_r6 import Mesh,beam
from refine_ruedersdorf_r13 import compact
from refine_ruedersdorf_r17 import append_generated, SCALE
from refine_ruedersdorf_r20 import serialize_glb

SOURCE_SHA='80c44cbc4374b363018947f9122d6fea101603d8fb37acfa10aae72c7c8d5cef'
# Corrected local cardinals: -X north, +Y east; dimensions in original GLB units.
WEST_STEPS=[(-5.635,-5.025,1.755,3.515,-2.012,-1.620),
            (-4.975,-4.375,1.755,3.515,-1.986,-1.472)]
NORTH_OUTBUILDINGS=[(-1.295,.165,4.585,5.495,-1.962,-1.405),
                    (.295,.735,4.585,5.415,-1.985,-1.585)]
CENTER_UTILITY=(2.135,2.585,-.415,.950,-2.022,-1.555)


def wall_frame(m,axis,plane,a,b,zbase,ztop,bays=4):
    """Frame ONLY; actual window / doorway voids stay physically open."""
    for idx,t in enumerate(np.linspace(a,b,bays+1)):
        # Thin piers support the existing scanned roof shell, not a new wall.
        if axis=='x':
            m.box(plane-.008,plane+.008,float(t)-.009,float(t)+.009,
                  zbase+.055,ztop-.009,'concrete')
        else:
            m.box(float(t)-.009,float(t)+.009,plane-.008,plane+.008,
                  zbase+.055,ztop-.009,'concrete')
    for z in (zbase+(ztop-zbase)*.47,ztop-.043):
        for j,(s,e) in enumerate(zip(np.linspace(a,b,bays+1)[:-1],
                                     np.linspace(a,b,bays+1)[1:])):
            # Lower door in middle bay is fully empty, including any sill.
            if j==bays//2 and z<zbase+(ztop-zbase)*.60:continue
            if axis=='x':
                beam(m,(plane,s+.018,z),(plane,e-.018,z),.004,.006,'metal')
            else:
                beam(m,(s+.018,plane,z),(e-.018,plane,z),.004,.006,'metal')


def stepped_northern_annex(m):
    """Two clearly imprinted stepped roofs; keep the narrow air gap between."""
    report=[]
    for i,(xa,xb,ya,yb,ground,roof) in enumerate(WEST_STEPS):
        m.part=f'R22 stepped northern utility annex {i+1}: interior piers'
        piers=0
        for x in (xa+.045,xb-.045):
            for y in (ya+.065,(ya+yb)/2,yb-.065):
                # Wall-adjacent thin supports; center and lower portals open.
                m.box(x-.015,x+.015,y-.018,y+.018,ground+.03,roof-.028,'concrete')
                m.box(x-.025,x+.025,y-.025,y+.025,roof-.072,roof-.047,'concrete')
                piers+=1
        m.part=f'R22 stepped northern utility annex {i+1}: open windows'
        for x in (xa+.009,xb-.009):
            wall_frame(m,'x',x,ya+.042,yb-.042,ground,roof,4)
        m.part=f'R22 stepped northern utility annex {i+1}: exposed roof lattice'
        # Light longitudinal rails underneath its already scanned roof.
        for x in (xa+.063,(xa+xb)/2,xb-.063):
            beam(m,(x,ya+.08,roof-.050),(x,yb-.08,roof-.050),.007,.011,'concrete')
        for y in np.linspace(ya+.09,yb-.09,5):
            beam(m,(xa+.07,float(y),roof-.055),
                 (xb-.07,float(y),roof-.055),.007,.010,'metal')
        report.append({'range_local':[xa,xb,ya,yb],
                       'roof_from_scan_local':roof,'piers':piers,
                       'window_bays_per_side':4,'new_full_roof':False})
    return {'roofs':report,'open_interbuilding_gap_local':[WEST_STEPS[0][1],WEST_STEPS[1][0]],
            'reference_context':['15871_Hof_Nordost.jpg','15884_Zusaetzlicher_Panoramaeintrag_15884.jpg'],
            'panorama_15884_location_unknown':True}


def northeastern_courtyard_outbuildings(m):
    """High and low buildings with original scan-surveyed roof profiles."""
    detail=[]
    for i,(xa,xb,ya,yb,ground,roof) in enumerate(NORTH_OUTBUILDINGS):
        m.part=f'R22 east courtyard outbuilding {i+1}: loadbearing frame'
        n=5 if i==0 else 2
        ys=np.linspace(ya+.06,yb-.06,n)
        supports=0
        for x in (xa+.045,xb-.045):
            for y in ys:
                m.box(x-.015,x+.015,float(y)-.017,float(y)+.017,
                      ground+.035,roof-.026,'concrete')
                m.box(x-.026,x+.026,float(y)-.029,float(y)+.029,
                      roof-.077,roof-.046,'concrete')
                supports+=1
        m.part=f'R22 east courtyard outbuilding {i+1}: fenestration skeleton'
        wall_frame(m,'y',ya+.012,xa+.048,xb-.048,ground,roof,4 if i==0 else 2)
        wall_frame(m,'y',yb-.012,xa+.048,xb-.048,ground,roof,4 if i==0 else 2)
        for x in (xa+.035,xb-.035):
            wall_frame(m,'x',x,ya+.044,yb-.044,ground,roof,3)
        m.part=f'R22 east courtyard outbuilding {i+1}: ceiling beams'
        for y in ys:
            beam(m,(xa+.052,float(y),roof-.068),
                 (xb-.052,float(y),roof-.068),.009,.018,'concrete')
        # One narrow, partial inner service ledge ONLY in the larger building.
        # No floor across the entrance, and a free open central height volume.
        if i==0:
            m.part='R22 taller east courtyard annex fragmented service ledge'
            z=ground+(roof-ground)*.45
            for a,b in ((ya+.08,ya+.29),(ya+.44,ya+.61)):
                m.box(xa+.045,xa+.165,a,b,z-.014,z,'metal')
                for y in (a+.012,b-.012):
                    beam(m,(xa+.16,y,z-.013),(xa+.10,y,z-.10),.008,.008,'metal')
        detail.append({'range_local':[xa,xb,ya,yb],
                       'roof_from_scan_local':roof,'perimeter_supports':supports,
                       'roof_kept':True,'center_and_doors_open':True})
    return {'buildings':detail,
            'reference_context':['15871_Hof_Nordost.jpg','15874_Zentraler_Platz.jpg'],
            'no_photographic_building_registration':True}


def central_low_service_annex(m):
    """Small scanned shallow-roof annex, formerly roof only, not a new hall."""
    xa,xb,ya,yb,ground,roof=CENTER_UTILITY
    m.part='R22 central low-roof annex wall-column frame'
    for y in np.linspace(ya+.055,yb-.055,6):
        for x in (xa+.035,xb-.035):
            m.box(x-.012,x+.012,float(y)-.013,float(y)+.013,
                  ground+.048,roof-.015,'concrete')
    # Long side windows and open door-sized center bays, no opaque infill.
    m.part='R22 central low-roof annex side window frames'
    for x in (xa+.012,xb-.012):
        wall_frame(m,'x',x,ya+.038,yb-.038,ground,roof,6)
    # Above-head rooftop processing remnants. There is already a scanned
    # continuous roof at -1.555; do not add a parallel opaque panel.
    m.part='R22 central low-roof annex lightweight piping'
    for y in (ya+.19,yb-.24):
        beam(m,(xa+.065,y,roof-.047),(xb-.065,y,roof-.047),.006,.008,'metal')
    # Two stub ducts on the existing roof, aligned with the long axis.
    m.part='R22 low-roof annex short roof vent remnants'
    for y in (ya+.32,yb-.34):
        m.cylinder(((xa+xb)/2,y,roof+.045),.018,.085,2,'metal',12)
    return {'range_local':[xa,xb,ya,yb],
            'roof_local':roof,'perimeter_posts':12,'partial_roof_vents':2,
            'new_opaque_wall_or_roof':False,
            'context':['15874_Zentraler_Platz.jpg','15884_Zusaetzlicher_Panoramaeintrag_15884.jpg'],
            'panorama_15884_used_as_style_only':True}


def main(source,output,collision,report):
    raw=Path(source).read_bytes();sha=hashlib.sha256(raw).hexdigest()
    if sha!=SOURCE_SHA:
        raise ValueError(f'Expected validated R21 GLB {SOURCE_SHA}; got {sha}')
    n=struct.unpack_from('<I',raw,12)[0]
    doc=json.loads(raw[20:20+n]);buf=bytearray(raw[28+n:])
    assert len(doc['meshes'])==25 and doc['meshes'][-1]['name'].startswith('R21')
    scan_before=[json.dumps(x,sort_keys=True) for x in doc['meshes'][:15]]
    root_before=json.dumps(doc['nodes'][0],sort_keys=True)
    m=Mesh()
    a=stepped_northern_annex(m)
    b=northeastern_courtyard_outbuildings(m)
    c=central_low_service_annex(m)
    groups=append_generated(doc,buf,m)
    doc['meshes'][-1]['name']='R22 unfinished stepped annexes, east court utilities and low service house'
    doc['nodes'][-1]['name']='R22 scan-footprint anchored annex detail geometry'
    doc['asset']['extras']['modifications']+=(
        ' R22: finish less-reconstructed structures within source-scanned roof footprints: '
        'two northern stepped annex blocks, north-east tall/low outbuildings and central low-roof service annex. '
        'Repeatable exposed columns, roof beam details and window framing, with lower doors open. '
        'No invented new opaque roof/wall; panorama 15884 used only as generic construction reference, '
        'not mapped to surveyed coordinates. Original RAWscan meshes, R20 platform, all R21 structures intact. '
        'Not a survey, not for real obstacle clearance; preserve RAWscan license attribution.')
    buf=compact(doc,buf)
    assert scan_before==[json.dumps(x,sort_keys=True) for x in doc['meshes'][:15]]
    assert root_before==json.dumps(doc['nodes'][0],sort_keys=True)
    serialize_glb(doc,buf,output)
    v,t=read_glb(output)
    unique=np.unique(np.sort(t,axis=1),axis=0)
    stats=build(v,unique,collision)
    f=Path(collision).read_bytes()
    magic,nv,nt,_=struct.unpack_from('<4sIII',f)
    assert magic==b'FPC1' and nv==len(v) and nt==len(unique)
    fv=np.frombuffer(f,dtype='<f4',count=nv*3,offset=16).reshape(-1,3)
    assert np.array_equal(v,fv)
    stats.update(revision='R22',r21_sha256=sha,
                 glb_sha256=hashlib.sha256(Path(output).read_bytes()).hexdigest(),
                 fpc_sha256=hashlib.sha256(f).hexdigest(),
                 original_scan_preserved=15,registration_preserved=True,
                 previous_silo_and_platform_structures_unchanged=True,
                 geometry_added_by_material=groups,
                 northern_stepped_annex=a,east_courtyard_buildings=b,central_service_annex=c,
                 visual_triangles=len(t),unique_collision_triangles=nt,
                 reference_geometry_unsurveyed=True)
    Path(report).parent.mkdir(parents=True,exist_ok=True)
    Path(report).write_text(json.dumps(stats,indent=2,ensure_ascii=False)+'\n')
    print(json.dumps(stats,indent=2,ensure_ascii=False))

if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__)
    for arg in ('source','output','collision','report'):p.add_argument(arg)
    a=p.parse_args();main(a.source,a.output,a.collision,a.report)
