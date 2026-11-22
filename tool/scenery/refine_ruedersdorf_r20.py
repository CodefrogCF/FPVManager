#!/usr/bin/env python3
"""R20 - rebuild the eastern *north-end* hall platform and refine interiors.

Input: exact R19 panorama-guided local_reference.glb.  Georeferenced local
axes are NOT cardinal: rotationDeg=99.7994 means local negative-X ~north and
local positive-Y ~east.  R16 mistakenly moved the former-ladder platform to
mid-hall on the WEST side.  This revision removes the R16 generated platform,
its mismatched roof pipe and ribs (only mesh #19), then places them at the
northern end of the EAST facade.  Open platform hole stays genuinely empty.

Interior details are photo-based approximations (panoramas 15862, 15867,
15872-73, 15878, 15884).  Original RAWscan meshes 0-14 and node registration
must never be changed.  Visual and FPC triangles derive from the same asset.
"""
from __future__ import annotations
import argparse
import hashlib
import json
import math
from pathlib import Path
import struct
import numpy as np
from build_collision import AXIS, build, read_glb
from reconstruct_ruedersdorf_r6 import Mesh, beam
from refine_ruedersdorf_r13 import compact, get_accessor
from refine_ruedersdorf_r17 import append_generated, replace_indices, SCALE, HALL_ROOF_BREACHES

SOURCE_SHA='a2c1be32e2804a3c489ab35193a4dd5ca0d7ecc289ebbadf2b9b2a35a2113363'
# High hall x: -5.06 (north end) to -1.49 (south end); east wall y=-.88.
# Total 4.81 x 5.29 m, 3.20 x 3.49 m central through-gap.
EAST_NORTH_PLATFORM=(-5.010,-4.710,-.885,-.555)
PLATFORM_GAP=(-4.960,-4.760,-.829,-.611)
PLATFORM_Z=-.117
OLD_MISPLACED=(-2.910,-2.670,-2.550,-2.310)


def remove_old_r16_west_platform(doc,buffer):
    """Remove the old generated landing/pipe/ribs, not all R16 geometry.

    R16 combined east six-silo roof/rooftop frame (x>4) and the west hall
    platform (x<-2).  Their position ranges are separated by >6 local units.
    Only mesh 19 is edited. Earlier source photogrammetry is immutable.
    """
    assert doc['meshes'][19]['name'].startswith('R16'), 'R16 mesh index changed'
    counts={}
    for p in doc['meshes'][19]['primitives']:
        pos=get_accessor(doc,buffer,p['attributes']['POSITION'])@AXIS.T
        t=get_accessor(doc,buffer,p['indices']).reshape(-1,3)
        xyz=pos[t]
        remove=(xyz[:,:,0].max(axis=1)<-2.56)
        mat=doc['materials'][p['material']]['name']
        counts[mat]=int(remove.sum())
        assert np.all((xyz[~remove,:,0].min(axis=1)>4.0)), mat
        replace_indices(doc,buffer,p,t[~remove])
    assert counts.get('R15 safety steel',0)>400,counts
    assert counts.get('R12 r6_roof',0)>10,counts
    assert counts.get('R12 r6_concrete',0)>10,counts
    return counts


def platform_ring(m,outer,gap,z):
    x0,x1,y0,y1=outer; a,b,c,d=gap
    assert x0<a<b<x1 and y0<c<d<y1
    # Solid ring in four strips, no single triangle across the center.
    for lo,hi,u,v in [(x0,a,y0,y1),(b,x1,y0,y1),
                      (a,b,y0,c),(a,b,d,y1)]:
        m.box(lo,hi,u,v,z-.008,z,'metal')
    # Underlying rusted edge frames only around the opening.
    for x in (a,b):m.box(x-.003,x+.003,c,d,z-.017,z+.003,'metal')
    for y in (c,d):m.box(a,b,y-.003,y+.003,z-.017,z+.003,'metal')
    return {'outer_local':list(outer),'open_gap_local':list(gap),
            'outer_m':[round((x1-x0)*SCALE,2),round((y1-y0)*SCALE,2)],
            'gap_m':[round((b-a)*SCALE,2),round((d-c)*SCALE,2)]}


def rebuild_east_north_access_platform(m):
    m.part='R20 north-east former-ladder landing open grating ring'
    x0,x1,y0,y1=EAST_NORTH_PLATFORM
    a,b,c,d=PLATFORM_GAP;z=PLATFORM_Z
    summary=platform_ring(m,EAST_NORTH_PLATFORM,PLATFORM_GAP,z)
    # Grating in perimeter strips only; no lattice covering the opening.
    m.part='R20 perimeter-only rusted grating'
    for x in np.arange(x0+.012,x1-.009,.019):
        for ya,yb in ((y0+.008,c-.002),(d+.002,y1-.008)):
            if ya<yb:m.box(x-.0012,x+.0012,ya,yb,z-.001,z+.0006,'metal')
    for y in np.arange(y0+.012,y1-.009,.021):
        for xa,xb in ((x0+.006,a-.003),(b+.003,x1-.006)):
            if xa<xb:m.box(xa,xb,y-.0012,y+.0012,z-.001,z+.0006,'metal')
    # Exterior guard on free/east side, short returns at both ends;
    # NO rail along the attached western side, and none across the center.
    m.part='R20 outside-edge landing rails and partly surviving cage'
    t=z+.115
    for x in (x0+.005,x1-.005):
        for y in (y1-.006,y0+.035):
            m.box(x-.004,x+.004,y-.004,y+.004,z,t,'metal')
        beam(m,(x,y0+.030,t-.006),(x,y1-.009,t-.006),.006,.007,'metal')
    for x in np.linspace(x0+.012,x1-.012,5):
        m.box(x-.003,x+.003,y1-.006,y1+.002,z,t,'metal')
    m.box(x0+.005,x1-.005,y1-.006,y1+.002,t-.007,t,'metal')
    m.box(x0+.005,x1-.005,y1-.006,y1+.002,z+.052,z+.058,'metal')
    # Two small outer triangular outriggers anchored into the EAST facade.
    # End geometry stays outside the real mid-platform dive path.
    m.part='R20 east wall brackets beneath landing'
    for x in (x0+.022,x1-.022):
        beam(m,(x,y0-.011,z-.16),(x,y1-.016,z-.008),.010,.012,'metal')
        m.box(x-.010,x+.010,y0-.026,y0+.012,z-.184,z-.140,'metal')
    # Subtle shortened ladder stub BELOW north edge only, because the old
    # ladder no longer exists; avoid a false ladder crossing the roof.
    m.part='R20 surviving exterior ladder top mounting tabs'
    for x in (x0+.022,x0+.057):
        m.box(x-.004,x+.004,y1-.019,y1+.013,z-.090,z-.007,'metal')
    summary.update({'previous_location_local':list(OLD_MISPLACED),
                    'attachment':'east facade at north end, no roof cut',
                    'original_panorama':'große_halle_nord_ost_dach_mit_plattform_schräge_draufsicht.png',
                    'model_not_surveyed':True})
    return summary


def adjust_roof_pipe(m):
    """Pipe is on roof INSIDE east parapet and adjacent to platform."""
    m.part='R20 realigned short pipe on north-east roof'
    m.cylinder((-4.856,-1.025,-.031),.026,.224,0,'metal',20)
    for x in (-4.944,-4.770):
        m.box(x-.007,x+.007,-1.052,-.998,-.076,-.061,'concrete')
    # Recovered short purlin fragments, never spanning existing roof gaps.
    m.part='R20 roof purlins next to former ladder platform'
    for y in (-1.125,-1.075):
        m.box(-4.991,-4.690,y-.003,y+.003,-.076,-.070,'roof')
    return {'pipe_center_local':[-4.856,-1.025,-.031],
            'on_roof_inside_east_facade':True}


def refine_hall_structural_details(m):
    """Make the monumental hall structure readable from upper galleries.

    Panoramas 15860/15862/15864 show curved concrete soffit bays and
    intact fragments of galleries framing the four horizontal tanks.
    Keep open center and all R17 roof voids unobstructed.
    """
    m.part='R20 long hall longitudinal roof purlin and arch bracing'
    purlins=0
    for y in (-2.145,-1.91,-1.225,-1.025):
        # These run on the SIDE of the central damaged roof panels, do not
        # form a synthetic collision sheet over any R17 apertures.
        xs=np.linspace(-4.975,-1.600,45)
        for xa,xb in zip(xs[:-1],xs[1:]):
            cx=(float(xa)+float(xb))/2
            if any(aa-.030<cx<bb+.030 and cc-.045<y<dd+.045
                   for aa,bb,cc,dd in HALL_ROOF_BREACHES):
                continue
            # follows existing R18 approximate haunch underside, under roof
            u=(y+1.592)/.673
            z=-.169-.132*u*u-.012
            beam(m,(float(xa),y,z),(float(xb),y,z),.005,.008,'concrete')
            purlins+=1
    # Partial hanging braces anchored into perimeter concrete columns.
    m.part='R20 hall cantilever brackets below old crane gallery'
    brackets=0
    for x in (-4.86,-4.31,-3.73,-3.18,-2.61,-2.05):
        for y,delta in [(-2.215,.075),(-.972,-.075)]:
            beam(m,(x,y,-.62),(x,y+delta,-.51),.008,.009,'metal')
            brackets+=1
    # Tanks remain exactly four horizontal vessels; additional fittings
    # only at their ends and below their foundations, no cap across aisle.
    m.part='R20 four horizontal tank outlet pipes and mounts'
    fittings=0
    for y in (-1.761,-1.543,-1.325,-1.107):
        for x in (-2.969,-2.330):
            m.cylinder((x,y,-1.760),.030,.010,0,'metal',16)
            fittings+=1
    return {'longitudinal_purlin_segments':purlins,'side_brackets':brackets,
            'tank_end_fittings':fittings,'preserved_roof_voids':3}


def refine_north_vaulted_hall(m):
    """Lightweight longitudinal vault/coffer outlines, no new ceiling skin."""
    m.part='R20 north vaulted hall roof coffer lines'
    mid=(-7.08-4.80)/2
    half=1.14;rise=.50;rad=(half*half+rise*rise)/(2*rise)
    longitudinal=0
    for y in (-6.79,-6.34,-5.54,-5.09):
        z=-.73+rise-rad+math.sqrt(max(0,rad*rad-(y-mid)**2))-.061
        for a,b in zip(np.linspace(-3.23,.38,18)[:-1],np.linspace(-3.23,.38,18)[1:]):
            beam(m,(float(a),y,z),(float(b),y,z),.007,.010,'concrete')
            longitudinal+=1
    # Sparse column capital blocks help define vaulted volume without
    # introducing full-area intermediate floors or false door caps.
    m.part='R20 north vaulted hall pier capitals'
    capitals=0
    for x in (-2.89,-2.16,-1.43,-.70,.03):
        for y in (-7.00,-4.88):
            m.box(x-.046,x+.046,y-.026,y+.026,-1.111,-1.087,'concrete')
            capitals+=1
    return {'longitudinal_coffer_segments':longitudinal,
            'small_pier_capitals':capitals,'open_atrium_preserved':True}


def refine_east_vessel_hall(m):
    """Thin pipework/column details without reconstructing false mid-floors."""
    m.part='R20 east vessel hall articulated wall piers'
    piers=0
    for y in (1.14,1.50,1.86,2.22,2.56):
        for x in (4.405,5.384):
            m.box(x-.008,x+.008,y-.011,y+.011,-1.79,-1.15,'concrete')
            piers+=1
    # Small overhead pipe connectors staggered BETWEEN vessels. The aisle
    # at x=5.16 remains free below z=-1.35.
    m.part='R20 east vessel upper service pipe nipples'
    fittings=0
    for y in (1.31,1.67,2.03,2.39):
        beam(m,(4.74,y,-1.105),(4.81,y,-1.105),.005,.007,'metal')
        fittings+=1
    return {'perimeter_column_piers':piers,'roof_service_connections':fittings,
            'no_mid_level_slabs':True}


def refine_south_stairwell(m):
    m.part='R20 west block loose atrium edge guard remnants'
    count=0
    # The panorama includes eroded handrails, not a solid divider.
    for z in (-1.700,-1.425,-1.163):
        for a,b in ((2.02,2.17),(2.40,2.55)):
            beam(m,(-3.943,a,z+.020),(-3.943,b,z+.078),.004,.005,'metal')
            count+=1
    return {'fragmented_rails':count,'central_stair_void_left_open':True}


def serialize_glb(doc,buf,dst):
    doc['buffers'][0]['byteLength']=len(buf)
    t=json.dumps(doc,ensure_ascii=False,separators=(',',':')).encode('utf8')
    t+=b' '*(-len(t)%4)
    payload=struct.pack('<I4s',len(t),b'JSON')+t+struct.pack('<I4s',len(buf),b'BIN\x00')+buf
    Path(dst).parent.mkdir(parents=True,exist_ok=True)
    Path(dst).write_bytes(struct.pack('<4sII',b'glTF',2,len(payload)+12)+payload)


def main(source,output,collision,report):
    raw=Path(source).read_bytes();sha=hashlib.sha256(raw).hexdigest()
    if sha!=SOURCE_SHA:raise ValueError('Expected validated R19 GLB: '+sha)
    jlen=struct.unpack_from('<I',raw,12)[0]
    doc=json.loads(raw[20:20+jlen]);buf=bytearray(raw[28+jlen:])
    initial_root=json.dumps(doc['nodes'][0],sort_keys=True)
    old_mesh_names=[m['name'] for m in doc['meshes'][:15]]
    assert len(doc['meshes'])==23 and doc['meshes'][-1]['name'].startswith('R19')
    removed=remove_old_r16_west_platform(doc,buf)
    geom=Mesh()
    platform=rebuild_east_north_access_platform(geom)
    pipe=adjust_roof_pipe(geom)
    hall=refine_hall_structural_details(geom)
    vaulted=refine_north_vaulted_hall(geom)
    east=refine_east_vessel_hall(geom)
    south=refine_south_stairwell(geom)
    added=append_generated(doc,buf,geom)
    doc['meshes'][-1]['name']='R20 corrected east facade north-end platform and panorama refinements'
    doc['nodes'][-1]['name']='R20 east-north open landing, fitted roofs, halls and tank frames'
    doc['asset']['extras']['modifications']+=(
        ' R20: Correct R16 local axis/cardinal interpretation: rebuilt roof-level '
        'former-ladder landing on EAST high-hall wall at NORTH end, with a genuinely '
        'empty large central fly-through hole. Remove old WEST-side R16 landing '
        'and misplaced pipe/ribs; place old pipe on roof near corrected platform. '
        'Add photo-inferred upper hall purlins, vault/coffer ribs, service columns '
        'and sparse handrail fragments without capping central voids. '
        'No surveyed accuracy; preserve original scan and CC BY-NC attribution.')
    buf=compact(doc,buf)
    assert json.dumps(doc['nodes'][0],sort_keys=True)==initial_root
    assert [m['name'] for m in doc['meshes'][:15]]==old_mesh_names
    serialize_glb(doc,buf,output)
    v,t=read_glb(output)
    unique=np.unique(np.sort(t,axis=1),axis=0)
    result=build(v,unique,collision)
    fb=Path(collision).read_bytes()
    magic,nv,nt,_=struct.unpack_from('<4sIII',fb)
    assert magic==b'FPC1' and nv==len(v) and nt==len(unique)
    fv=np.frombuffer(fb,dtype='<f4',count=nv*3,offset=16).reshape(-1,3)
    ft=np.frombuffer(fb,dtype='<u4',count=nt*3,offset=16+nv*12).reshape(-1,3)
    assert np.array_equal(v,fv)
    assert np.array_equal(unique,np.unique(np.sort(ft,axis=1),axis=0))
    result.update({'revision':'R20','R19_source_sha256':sha,
                   'glb_sha256':hashlib.sha256(Path(output).read_bytes()).hexdigest(),
                   'fpc_sha256':hashlib.sha256(fb).hexdigest(),
                   'original_scan_meshes_preserved':15,
                   'registration_preserved':True,'approximate_not_surveyed':True,
                   'removed_misplaced_r16_triangles':removed,
                   'added_triangles_by_material':added,
                   'platform':platform,'repositioned_roof_pipe':pipe,
                   'long_hall':hall,'north_vaulted_hall':vaulted,
                   'east_vessel_hall':east,'south_stairwell':south,
                   'visual_triangles':int(len(t)),
                   'unique_collision_triangles':int(len(unique))})
    Path(report).parent.mkdir(parents=True,exist_ok=True)
    Path(report).write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
    print(json.dumps(result,ensure_ascii=False,indent=2))

if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    for arg in ('source','output','collision','report'):parser.add_argument(arg)
    a=parser.parse_args();main(a.source,a.output,a.collision,a.report)
