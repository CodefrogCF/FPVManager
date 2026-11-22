#!/usr/bin/env python3
"""R17 – reference-guided plant interiors, apertures, and secondary buildings.

Consumes the verified R16 output, not the unmodified R15 source.  Includes
actual openings in both render and collider; does not modify photogrammetric
scan meshes (0..14), georeferencing, or terrain underlay.  Photos do NOT
provide surveyed coordinates. New details are scaled approximations.

Separate locations:
* Central FOUR-silo narrow stair: open roof dive, NO continuous rust wall.
* South-eastern SIX-silo stair/head-house: CLOSED roof (preserve R16).
* Long hall: replace high-level synthetic roof with damaged panels, reveal
  two authentic-style masonry breaches and add internal roof/vessel detail.
* Other buildings: roofline/fenestration structural details without capping
  existing vaulted-hall skylights or obstructing circulation openings.
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
from refine_ruedersdorf_r15_silo import append_accessor

SOURCE_SHA = '13170f9b302567b1f57779dadfcfaa7df77529f666aedb01cef64431072ac980'
SCALE = 16.023268178233355
CENTRAL_OPENING = (1.285,1.535,3.745,3.995)
CENTRAL_ROOF = (1.12,1.70,3.72,4.02)
SOUTHEAST_CLOSED = (4.43,4.94,-2.262,-2.142)
HALL_ROOF_BOUNDS = (-5.06,-1.49,-2.304,-.880)
# The original long-hall roof already has a narrow broken panel near x=-2.60.
# Remaining openings are inferred from visible daylight in the supplied
# underside pictures, but their exact placement remains approximate.
HALL_ROOF_BREACHES = [
    (-4.43,-4.15,-1.81,-1.42),
    (-3.60,-3.28,-1.84,-1.42),
    (-2.76,-2.50,-1.72,-1.44),
]


def replace_indices(doc,buffer,primitive,indices):
    prior=doc['accessors'][primitive['indices']]
    ctype=prior['componentType']
    values=np.asarray(indices,dtype='<u2' if ctype==5123 else '<u4').reshape(-1)
    primitive['indices']=append_accessor(doc,buffer,values,'SCALAR',ctype,34963)


def repair_synthetic_geometry(doc,buffer):
    """Operate on procedural R12 only, never the underlying 15 scan meshes."""
    removed={}
    meshes=doc['meshes']
    assert len(meshes)==20 and meshes[-1]['name'].startswith('R16 corrected')
    high_x0,high_x1,low_y,high_y=HALL_ROOF_BOUNDS
    for pno,prim in enumerate(meshes[15]['primitives']):
        material=doc['materials'][prim['material']]['name']
        xyz=get_accessor(doc,buffer,prim['attributes']['POSITION'])@AXIS.T
        tri=get_accessor(doc,buffer,prim['indices']).reshape(-1,3)
        face=xyz[tri]
        cen=face.mean(1)
        lo=face.min(1); hi=face.max(1)
        x,y,z=cen.T
        kill=np.zeros(len(tri),dtype=bool)
        if material=='R12 concrete':
            # Original connector rooftop is an entire solid 9.3m x 4.8m
            # cuboid, directly obstructing a dive down the central stairs.
            kill |= ((lo[:,0]>=CENTRAL_ROOF[0]-.0001)&
                     (hi[:,0]<=CENTRAL_ROOF[1]+.0001)&
                     (lo[:,1]>=CENTRAL_ROOF[2]-.0001)&
                     (hi[:,1]<=CENTRAL_ROOF[3]+.0001)&
                     (lo[:,2]>=-.491)&(hi[:,2]<=-.464))
        if material=='R12 roof':
            # Replace the FULL high-hall roof skin (four boxes) with
            # genuine openings. Structural concrete crossbeams remain.
            kill |= ((lo[:,0]>=high_x0-.0001)&(hi[:,0]<=high_x1+.0001)&
                     (lo[:,1]>=low_y-.0001)&(hi[:,1]<=high_y+.0001)&
                     (lo[:,2]>=-.118)&(hi[:,2]<=-.079+1e-3))
        if material in ('R12 brick','R12 metal'):
            # Breaches in the photo-visible long hall east wall close to the
            # tanks. Remove only full synthetic panel rectangles; the facade
            # pillars, load-bearing columns and original scan remain.
            # Main low entrance between two vessel bays (one exact bay).
            at_east=(lo[:,1]>=-.893)&(hi[:,1]<=-.867)
            within_one=(lo[:,0]>=-2.510)&(hi[:,0]<=-2.252)
            ground=(lo[:,2]>=-1.921)&(hi[:,2]<=-1.519)
            kill |= at_east & within_one & ground
            # Broken upper masonry panel in adjoining bay.  Avoid beams.
            within_other=(lo[:,0]>=-2.765)&(hi[:,0]<=-2.508)
            upper=(lo[:,2]>=-1.521)&(hi[:,2]<=-1.398)
            kill |= at_east & within_other & upper
        if material in ('R12 metal','R12 r6_metal'):
            # Old railings of the capped central FOUR-silo platform extend
            # straight across the prospective roof opening; remove their
            # parallel bars only, retain other stair and perimeter rails.
            central=((x>=CENTRAL_OPENING[0])&(x<=CENTRAL_OPENING[1])&
                     (y>=CENTRAL_OPENING[2])&(y<=CENTRAL_OPENING[3])&
                     (z>-.466)&(z<-.398))
            kill |= central
            if material=='R12 r6_metal':
                # R6 speculative continuous sheet/rail across the very top
                # of the stair: vertical 4m-wide rectangle, not a step. It
                # blocks the central dive even after the old roof is removed.
                kill |= ((lo[:,0]>=1.405)&(hi[:,0]<=1.419)&
                         (lo[:,1]>=3.69)&(hi[:,1]<=4.08)&
                         (lo[:,2]>-.69)&(hi[:,2]>-.44)&(hi[:,2]<-.39))
        if kill.any():
            removed[f'R12_p{pno}_{material}']=int(kill.sum())
            replace_indices(doc,buffer,prim,tri[~kill])
    # R15 generated an exposed diagonal rail exactly across the roof-dive
    # center of the central FOUR-silo stair (not the real photo rail layout).
    # Keep all other R15 handrails and the outer stair edges intact.
    p=meshes[17]['primitives'][0]
    xyz=get_accessor(doc,buffer,p['attributes']['POSITION'])@AXIS.T
    triangles=get_accessor(doc,buffer,p['indices']).reshape(-1,3)
    centers=xyz[triangles].mean(1)
    remove=((centers[:,0]>1.422)&(centers[:,0]<1.436)&
            (centers[:,1]>3.68)&(centers[:,1]<4.08)&
            (centers[:,2]>-.633)&(centers[:,2]<-.389))
    removed['R15_central_stair_rail']=int(remove.sum())
    assert removed['R15_central_stair_rail']==12, removed
    replace_indices(doc,buffer,p,triangles[~remove])
    # R12 roof had exactly 48 faces over the long high hall.  Do not silently
    # ship a doubled roof in case upstream generation has changed.
    assert removed.get('R12_p4_R12 roof')==48, removed
    assert removed.get('R12_p1_R12 concrete')==12, removed
    return removed


def region_hole_slab(m,outer,holes,z0,z1,material):
    """Discrete solid plate tiles: their holes are EMPTY in GLB and FPC."""
    x0,x1,y0,y1=outer
    xx=sorted({x0,x1,*[x for a,b,c,d in holes for x in (a,b)]})
    yy=sorted({y0,y1,*[y for a,b,c,d in holes for y in (c,d)]})
    tiles=0
    for a,b in zip(xx[:-1],xx[1:]):
        for c,d in zip(yy[:-1],yy[1:]):
            if not (x0 <= a < b <= x1 and y0 <= c < d <= y1):
                continue
            mx,my=(a+b)/2,(c+d)/2
            if any(q0<mx<q1 and r0<my<r1 for q0,q1,r0,r1 in holes):
                continue
            m.box(a,b,c,d,z0,z1,material);tiles+=1
    return tiles


def add_central_stair_roof(m):
    # R5 x=1.12..1.70 platform was solid; true aperture into the stairs.
    m.part='R17 central four-silo roof dive ring'
    x0,x1,y0,y1=CENTRAL_ROOF
    h0,h1,v0,v1=CENTRAL_OPENING
    # Roof extends to stair side faces; upper steps/rails are not capped.
    region_hole_slab(m,(x0,x1,y0,y1),[CENTRAL_OPENING],-.490,-.465,'concrete')
    for x in (x0+.013,x1-.013):
        for y in (y0+.01,y1-.01):
            m.box(x-.004,x+.004,y-.004,y+.004,-.465,-.394,'metal')
    # Safe edge barrier not a cage over middle dive shaft.
    for x in (x0+.013,x1-.013):
        m.box(x-.003,x+.003,y0+.008,y1-.008,-.403,-.398,'metal')
    for y in (y0+.01,y1-.01):
        m.box(x0+.008,x1-.008,y-.003,y+.003,-.403,-.398,'metal')
    # The strip around the central opening is unglazed, with no central wall.
    return {'opening_local':CENTRAL_OPENING,'opening_m':[round((h1-h0)*SCALE,2),round((v1-v0)*SCALE,2)]}


def add_high_hall_revisions(m):
    m.part='R17 large hall missing roof panels'
    count=region_hole_slab(m,HALL_ROOF_BOUNDS,HALL_ROOF_BREACHES,-.117,-.078,'roof')
    # Visible cross-lattice underside and concrete girders; the axis of the
    # hall stays clear for FPV flight. Keep all members above z=-.18.
    m.part='R17 large hall roof underside structure'
    for y in (-2.20,-1.96,-1.19,-.99):
        beam(m,(-5.00,y,-.141),(-1.53,y,-.141),.010,.020,'concrete')
    for x in np.linspace(-4.99,-1.54,13):
        beam(m,(x,-2.235,-.152),(x,-.948,-.152),.008,.015,'concrete')
    # Narrow dual overhead crane runways with side supporting brackets.
    m.part='R17 hall longitudinal gantry and gantry tracks'
    for y in (-2.205,-1.000):
        m.box(-4.94,-1.61,y-.012,y+.012,-.385,-.361,'metal')
        for x in np.linspace(-4.94,-1.61,11):
            beam(m,(x,y,-.363),(x,y+(.055 if y < -1.6 else -.055),-.19),.007,.012,'metal')
    # Visible supporting spine (the existing main concrete pier is retained).
    m.part='R17 hall vessel foundations and manifolds'
    for y in (-1.761,-1.543,-1.325,-1.107):
        # Keep center of the cylindrical vessels closed; only external pipe
        # fittings and short brackets, not false collision plates at ends.
        for xe in (-2.963,-2.338):
            m.cylinder((xe,y,-1.762),.028,.018,0,'metal',12)
        for xe in (-2.89,-2.41):
            m.box(xe-.020,xe+.020,y-.012,y+.012,-1.920,-1.855,'metal')
    # A network of narrow suspended side pipes visible in interior photos.
    for z in (-1.38,-1.33,-1.28):
        beam(m,(-3.23,-2.245,z),(-1.83,-2.245,z),.012,.012,'metal')
        for x in (-3.04,-2.36,-1.95):
            beam(m,(x,-2.245,z),(x,-2.276,z+.063),.007,.007,'metal')
    # Broken opening should have masonry edges, not an untextured invisible
    # clipping boundary. This thin frame stays outside both clear openings.
    m.part='R17 hall wall damage edges'
    for x in (-2.752,-2.520):
        m.box(x-.010,x+.010,-.891,-.877,-1.521,-1.409,'brick')
    # Internal elevated service platform next to the previously existing
    # four-vessel foundation, with rail on the far wall, not in the passage.
    m.part='R17 hall maintenance platform'
    m.box(-3.18,-2.86,-2.264,-2.135,-1.27,-1.257,'metal')
    for x in (-3.16,-3.02,-2.88):
        m.box(x-.004,x+.004,-2.262,-2.254,-1.257,-1.183,'metal')
    m.box(-3.18,-2.86,-2.262,-2.254,-1.188,-1.183,'metal')
    return {'roof_panels':count,'roof_holes_local':HALL_ROOF_BREACHES,'wall_openings':'east wall near existing tanks, two bays'}


def add_other_building_details(m):
    # Correspond to pre-existing R6 building footprints; no new monolithic
    # filler slabs are created on top of existing roofs or the silo shafts.
    m.part='R17 east production exterior stair guards'
    for z in (-1.666,-1.381):
        # Existing two-tier service landing on right side of east frame.
        m.box(4.40,5.34,2.611,2.616,z+.06,z+.067,'metal')
        for x in (4.43,4.73,5.03,5.32):
            m.box(x-.003,x+.003,2.611,2.616,z,z+.065,'metal')
    # Existing R6 stair at y 2.68..2.88, x 5.08..5.31.
    for base in (-1.94,-1.65):
        beam(m,(5.08,2.67,base+.061),(5.31,2.67,base+.35),.006,.007,'metal')
    m.part='R17 west production block window top lintels'
    # Bay/window geometry follows surviving bricked panel widths from R6.
    for x in (-4.04,-3.64,-3.24,-2.84):
        m.box(x-.024,x+.024,1.750,1.770,-1.18,-.78,'concrete')
    m.part='R17 vaulted hall skylight retainers'
    # The vaulted roof has real R6 skylight holes; their central spans stay
    # untouched. These are short clips outside the missing-panel footprints.
    for x in (-2.68,-1.74,-.79):
        for y in (-6.94,-4.94):
            beam(m,(x-.13,y,-.735),(x+.13,y,-.735),.009,.009,'metal')
    m.part='R17 damaged side annex frame repairs'
    # Lightweight, exposed steel on the courtyard-facing south-east annex
    # rather than opaque fill across its open/ruined façade.
    for x in (2.56,3.07,3.58,4.09):
        m.box(x-.007,x+.007,-4.955,-4.935,-1.56,-1.33,'metal')
    m.box(2.55,4.10,-4.952,-4.942,-1.346,-1.336,'metal')
    return {'regions':['east production structure','west production block','vaulted hall','south-east courtyard annex'],'solid_capping_added':False}


def append_generated(doc,buf,geometry):
    available={m.get('name'):idx for idx,m in enumerate(doc['materials'])}
    mats={'concrete':available['R12 r6_concrete'],'roof':available['R12 r6_roof'],
          'metal':available['R15 safety steel'],'brick':available['R12 r6_brick']}
    parts=[];count={}
    for mat,faces in geometry.groups.items():
        if not faces:continue
        p=np.concatenate([f[0] for f in faces]).astype('<f4')
        normals=np.concatenate([np.repeat(f[1][None,:],3,axis=0) for f in faces]).astype('<f4')
        uv=np.concatenate([f[2] for f in faces]).astype('<f4')
        ia=append_accessor(doc,buf,(p@AXIS).astype('<f4'),'VEC3',5126,34962)
        na=append_accessor(doc,buf,(normals@AXIS).astype('<f4'),'VEC3',5126,34962)
        ua=append_accessor(doc,buf,uv,'VEC2',5126,34962)
        component=5123 if len(p)<65536 else 5125
        ind=np.arange(len(p),dtype='<u2' if component==5123 else '<u4')
        idx=append_accessor(doc,buf,ind,'SCALAR',component,34963)
        parts.append({'attributes':{'POSITION':ia,'NORMAL':na,'TEXCOORD_0':ua},
                      'indices':idx,'material':mats[mat],'mode':4})
        count[mat]=len(faces)
    meshno=len(doc['meshes'])
    doc['meshes'].append({'name':'R17 hall interiors, central silo dive, nearby buildings','primitives':parts})
    nodeno=len(doc['nodes'])
    doc['nodes'].append({'name':'R17 reference-guided structures and true openings','mesh':meshno})
    doc['scenes'][doc.get('scene',0)]['nodes'].append(nodeno)
    return count


def main(src,output,fpc,report):
    raw=Path(src).read_bytes(); hash_before=hashlib.sha256(raw).hexdigest()
    if hash_before!=SOURCE_SHA:
        raise ValueError(f'Expected verified R16 GLB {SOURCE_SHA}, got {hash_before}')
    n=struct.unpack_from('<I',raw,12)[0]
    doc=json.loads(raw[20:20+n]);buf=bytearray(raw[28+n:])
    root_before=json.dumps(doc['nodes'][0],sort_keys=True)
    original_scan=[m['name'] for m in doc['meshes'][:15]]
    removed=repair_synthetic_geometry(doc,buf)
    mesh=Mesh();four=add_central_stair_roof(mesh)
    hall=add_high_hall_revisions(mesh);other=add_other_building_details(mesh)
    added=append_generated(doc,buf,mesh)
    buf=compact(doc,buf)
    assert json.dumps(doc['nodes'][0],sort_keys=True)==root_before
    assert [m['name'] for m in doc['meshes'][:15]]==original_scan
    doc['asset']['extras']['modifications'] += (' R17: central four-silo rooftop stair dive reopened with true ring aperture (no middle wall); '
        'south-east six-silo roof remains sealed; high long-hall roof replaced with missing roof panels, '
        'two distinct wall breaches and extra photo-guided tank, gangway and overhead beams; '
        'secondary industrial buildings retain existing window and stair openings; geometry remains an '
        'unsurveyed approximation and carries original CC BY-NC 4.0 attribution.')
    doc['buffers'][0]['byteLength']=len(buf)
    b=json.dumps(doc,separators=(',',':'),ensure_ascii=False).encode('utf8')
    b+=b' '*(-len(b)%4)
    payload=struct.pack('<I4s',len(b),b'JSON')+b+struct.pack('<I4s',len(buf),b'BIN\0')+buf
    Path(output).parent.mkdir(parents=True,exist_ok=True)
    Path(output).write_bytes(struct.pack('<4sII',b'glTF',2,len(payload)+12)+payload)
    v,t=read_glb(output)
    _,idx=np.unique(np.sort(t,axis=1),axis=0,return_index=True)
    summary=build(v,t[np.sort(idx)],fpc)
    data=Path(fpc).read_bytes()
    nv,nt,nodes=struct.unpack_from('<III',data,4)
    fv=np.frombuffer(data,dtype='<f4',count=nv*3,offset=16).reshape(-1,3)
    ft=np.frombuffer(data,dtype='<u4',count=nt*3,offset=16+nv*12).reshape(-1,3)
    assert np.array_equal(fv,v)
    assert np.array_equal(np.unique(np.sort(ft,axis=1),axis=0),np.unique(np.sort(t,axis=1),axis=0))
    summary.update({'revision':'R17','r16_input_sha256':hash_before,
        'glb_sha256':hashlib.sha256(Path(output).read_bytes()).hexdigest(),
        'fpc_sha256':hashlib.sha256(data).hexdigest(),
        'removed_triangles':removed,'added_triangles':added,
        'central_four_silos':four,'south_east_six_silos_closed':SOUTHEAST_CLOSED,
        'long_hall':hall,'other_buildings':other,'visual_triangles':len(t),
        'georeference_unchanged':True,'source_scan_unchanged':True,'surveyed':False})
    Path(report).write_text(json.dumps(summary,indent=2,ensure_ascii=False)+'\n')
    print(json.dumps(summary,indent=2,ensure_ascii=False))


if __name__=='__main__':
    a=argparse.ArgumentParser(description=__doc__)
    for key in ('source','output','collision','report'): a.add_argument(key)
    v=a.parse_args();main(v.source,v.output,v.collision,v.report)
