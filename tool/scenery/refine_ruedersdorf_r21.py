#!/usr/bin/env python3
"""R21 photo-audit update from R20, with cardinal directions rechecked.

This *edits* the short inaccurate R18 long-hall side galleries rather than
stacking overlapping geometry. Photo-guided geometry includes east-production
upper gallery/hatch and shallow vaulted ceiling, broken northern hall ribs,
separate ruins/atria features. Original RAWscan meshes 0..14 and north/east
placement are immutable. This is NOT metric photogrammetry or a certified
safety map, and physical obstacle clearance must not be inferred from it.

Reference review: 42 named photographs (especially 'große_halle' and the
north-east platform) and panoramas 15860..15884 with 15 Cesium screenshots.
The panoramas are spherical views without registered camera positions. Their
relative layouts constrain forms, but not 3D coordinates with survey accuracy.
"""
from __future__ import annotations
import argparse, hashlib, json, math, struct
from pathlib import Path
import numpy as np
from build_collision import AXIS, build, read_glb
from reconstruct_ruedersdorf_r6 import Mesh, beam, rubble
from refine_ruedersdorf_r13 import compact, get_accessor
from refine_ruedersdorf_r17 import append_generated, replace_indices, SCALE, HALL_ROOF_BREACHES
from refine_ruedersdorf_r20 import EAST_NORTH_PLATFORM, PLATFORM_GAP, serialize_glb

SOURCE_SHA = '604d76efec7c8899a445cec8012bbdf4a59fe1f85250d79e9fd2bbc304ad5bf6'
# R20 geographic orientation: local -X ~ north, local +Y ~ east.
LONG_HALL=(-5.06,-1.49,-2.304,-.880)
EAST_ATTIC=(4.35,5.43,1.05,2.95)
# The legacy R6 covering slab is wholly solid even though the upper-room
# panorama has a floor hatch. Remove only the legacy R6 upper cap and
# rebuild the upper-room deck from distinct plates around a real cut-out.
EAST_OPEN_HATCH=(4.80,5.04,1.79,2.20)


def replace_short_gallery_model(doc, buf):
    """Remove only R18's synthetic floor/rail mesh faces; keep curved ribs.

    R18 gallery geometry is distinctly below z=-.75; the R18 concrete roof
    ribs are above z=-.40. The first 15 source scan meshes are untouched.
    """
    assert doc['meshes'][21]['name'].startswith('R18')
    removed={}
    kept=[]
    for prim in doc['meshes'][21]['primitives']:
        mat=doc['materials'][prim['material']]['name']
        pos=get_accessor(doc,buf,prim['attributes']['POSITION'])@AXIS.T
        tri=get_accessor(doc,buf,prim['indices']).reshape(-1,3)
        z=pos[tri][:,:,2].mean(1)
        if mat=='R15 safety steel':drop=np.ones(len(tri),bool)
        elif mat=='R12 r6_concrete':drop=z<-.75
        else:raise AssertionError(f'Unexpected R18 primitive {mat}')
        removed[mat]=int(drop.sum())
        if not drop.all():
            replace_indices(doc,buf,prim,tri[~drop])
            kept.append(prim)
    doc['meshes'][21]['primitives']=kept
    assert removed.get('R15 safety steel',0)>100,removed
    assert removed.get('R12 r6_concrete',0)>150,removed
    return removed


def remove_east_legacy_solid_roof(doc, buf):
    """R6 12-triangle full roof box wrongly caps the observed hatch.

    Earlier R13/R19 edits left this one-sided full-covering sheet in the R6
    generated mesh; replacing it is essential to genuine top-room access.
    Do NOT remove unrelated roofs or parts of the original scan.
    """
    count=0
    for pr in doc['meshes'][15]['primitives']:
        if doc['materials'][pr['material']]['name'] not in ('R12 r6_roof','R12 r6_concrete'):continue
        xyz=get_accessor(doc,buf,pr['attributes']['POSITION'])@AXIS.T
        tri=get_accessor(doc,buf,pr['indices']).reshape(-1,3)
        verts=xyz[tri];lo=verts.min(1);hi=verts.max(1)
        kill=((lo[:,0]>=4.34)&(hi[:,0]<=5.44)&
              (lo[:,1]>=1.04)&(hi[:,1]<=2.96)&
              (lo[:,2]>=-1.11)&(hi[:,2]<=-.94))
        count+=int(kill.sum())
        if kill.any():replace_indices(doc,buf,pr,tri[~kill])
    assert count==12, f'Expected 12 obsolete east-roof box triangles, got {count}'
    return count


def hall_mezzanines(m):
    """Retained *disconnected* platforms extend along most of the high hall.

    15862/15864: upper walkways on BOTH sides of a large open central drop,
    punctured by missing floor fields, narrow exposed edge girders, rusted
    railing remnants. The R18 ~17 m fragment was too short for this layout.
    """
    m.part='R21 long hall upper floor remnants on both walls'
    spans=[(-4.93,-4.49),(-4.39,-3.82),(-3.72,-3.31),
           (-3.20,-2.78),(-2.67,-2.19),(-2.09,-1.62)]
    sides=[(-2.260,-2.012),(-1.196,-.930)]
    z0,z1=-1.275,-1.252
    panels=0
    for si,(y0,y1) in enumerate(sides):
        for k,(a,b) in enumerate(spans):
            # staggered true floor gaps: no underside/middle collision cap.
            if (si,k) in {(0,3),(1,2)}:continue
            holes=[]
            if (si+k)%3!=1:
                xc=a+(b-a)*.56
                holes=[(xc-.055,xc+.055,y0+.045,y1-.045)]
            xx=sorted({a,b,*[c for h in holes for c in h[:2]]})
            yy=sorted({y0,y1,*[c for h in holes for c in h[2:]]})
            for xa,xb in zip(xx[:-1],xx[1:]):
                for ya,yb in zip(yy[:-1],yy[1:]):
                    if any(ha<(xa+xb)/2<hb and hc<(ya+yb)/2<hd for ha,hb,hc,hd in holes):continue
                    m.box(xa,xb,ya,yb,z0,z1,'concrete');panels+=1
            # Broken girders stop at deck gaps, never span the central aisle.
            iy=y1 if si==0 else y0
            m.box(a,b,iy-.010,iy+.010,z0-.032,z0,'concrete')
            for x in (a+.035,b-.035):
                # The eastern tank-bank doorway at x≈-2.65..-2.38 must
                # remain completely unobstructed (R17 test / reference).
                if si==1 and -2.80<x<-2.15:
                    continue
                oy=y0+.028 if si==0 else y1-.028
                m.box(x-.018,x+.018,oy-.021,oy+.021,-1.904,z0,'concrete')
            # Staggered posts, leaving deliberately interrupted guardrail.
            if k in (0,2,4,5):
                aa=a+.035;bb=min(a+.18,b-.035)
                for x in (aa,bb):m.box(x-.003,x+.003,iy-.004,iy+.004,z1,z1+.067,'metal')
                beam(m,(aa,iy,z1+.063),(bb,iy,z1+.063),.004,.004,'metal')
    # Surviving transverse gallery frame with no solid middle bridge.
    m.part='R21 broken hall gallery underbraces'
    for x in (-4.36,-3.67,-2.59,-1.87):
        for y0,y1 in sides:
            inside=y1 if y0<-1.5 else y0
            outside=y0 if y0<-1.5 else y1
            beam(m,(x,outside,-1.43),(x,inside,-1.270),.010,.010,'concrete')
    return {'retained_floor_tiles':panels,'bay_spans':spans,'lateral_bands':sides,
            'central_open_aisle_m':round((sides[1][0]-sides[0][1])*SCALE,1),
            'source_panorama':['15862_Grosse_Halle_Aussicht.jpg','15864_Grosse_Halle_1_Stock.jpg'],
            'precision':'unsurveyed approximate'}


def hall_roof_repairs(m):
    """Add supporting cross-bracing on visible intact vault panels only."""
    m.part='R21 long hall roof diagonal haunch braces excluding all dive holes'
    count=0
    for x in (-4.70,-4.11,-3.55,-3.02,-2.40,-1.87):
        for y0,y1 in ((-2.16,-2.02),(-1.18,-1.04)):
            cx=x;cy=(y0+y1)/2
            if any(a-.04<cx<b+.04 and c-.05<cy<d+.05 for a,b,c,d in HALL_ROOF_BREACHES):continue
            beam(m,(x,y0,-.240),(x+.030,y1,-.156),.009,.012,'concrete');count+=1
    # Two original photo-borne exterior breaches near the tank bank remain
    # ACTUAL voids; no masonry plates across them.
    return {'intact_bay_diagonal_braces':count,'roof_holes_unchanged':len(HALL_ROOF_BREACHES)}


def east_top_stair_and_roof(m):
    """Make 15873 upper hall a bounded, shallow-vaulted room with a hatch.

    Four lower tanks from 15872 remain. Roof is continuous (photo 15873
    shows a ceiling), while its existing U-shaped *upper floor* is patched
    only around a smaller truly open central stairway opening.
    """
    m.part='R21 east building infill around real central upper hatch'
    xa,xb,ya,yb=EAST_ATTIC
    hx0,hx1,hy0,hy1=EAST_OPEN_HATCH
    xs=[xa,hx0,hx1,xb];ys=[ya,hy0,hy1,yb]
    fill=0
    for a,b in zip(xs[:-1],xs[1:]):
        for c,d in zip(ys[:-1],ys[1:]):
            if a>=hx0 and b<=hx1 and c>=hy0 and d<=hy1:continue
            m.box(a,b,c,d,-1.078,-1.052,'concrete');fill+=1
    # Hatch rails and rusty cut edges: never place a beam across its center.
    m.part='R21 upper east hatch rim and partially intact guardrail'
    for x in (hx0,hx1):
        m.box(x-.004,x+.004,hy0,hy1,-1.080,-1.046,'metal')
    for y in (hy0,hy1):
        m.box(hx0,hx1,y-.004,y+.004,-1.080,-1.046,'metal')
    for x,y in ((hx0,hy0),(hx1,hy0),(hx1,hy1)):
        m.box(x-.005,x+.005,y-.005,y+.005,-1.050,-.967,'metal')
    beam(m,(hx0,hy0,-.970),(hx1,hy0,-.970),.005,.005,'metal')
    beam(m,(hx1,hy0,-.970),(hx1,hy1,-.970),.005,.005,'metal')
    # Roof vault seen in 15873, with NO false opening in the ceiling.
    m.part='R21 east upper room shallow barrel vaulted roof'
    x0,x1,y0,y1=EAST_ATTIC
    n_x,n_y=16,12
    def height(x):
        u=(x-(x0+x1)/2)/((x1-x0)/2)
        return -.906+.117*max(0,1-u*u)
    for ay,by in zip(np.linspace(y0,y1,n_y+1)[:-1],np.linspace(y0,y1,n_y+1)[1:]):
        for ax,bx in zip(np.linspace(x0,x1,n_x+1)[:-1],np.linspace(x0,x1,n_x+1)[1:]):
            za,zb=height(ax),height(bx)
            m.quad((ax,ay,za),(bx,ay,zb),(bx,by,zb),(ax,by,za),'roof')
            m.quad((ax,by,za-.012),(bx,by,zb-.012),(bx,ay,zb-.012),(ax,ay,za-.012),'concrete')
    # Five real transverse concrete rib-like strips, below vault only.
    m.part='R21 east upper room vault ribs and window piers'
    rib_segs=0
    for y in np.linspace(y0+.06,y1-.06,6):
        xx=np.linspace(x0+.018,x1-.018,15)
        for a,b in zip(xx[:-1],xx[1:]):
            beam(m,(float(a),float(y),height(a)-.018),(float(b),float(y),height(b)-.018),.012,.015,'concrete')
            rib_segs+=1
    # Continuous windows in photograph have frames, not opaque walls.
    for x in (x0+.012,x1-.012):
        for y in np.linspace(y0+.10,y1-.10,10):
            m.box(x-.006,x+.006,y-.007,y+.007,-1.051,-.900,'concrete')
        for z in (-.997,-.938):
            beam(m,(x,y0+.045,z),(x,y1-.045,z),.004,.004,'metal')
    # A few overhead rusted pipe ends in the roof room, photographed near
    # the center stair; no long fictitious pipe closing the hatch.
    m.part='R21 east upper hatch short disused duct stubs'
    for y in (1.40,2.65):
        m.cylinder((4.76,y,-.999),.023,.050,2,'metal',12)
    return {'upper_floor_fill_tiles':fill,'through_hatch_local':list(EAST_OPEN_HATCH),
            'through_hatch_size_m':[round((hx1-hx0)*SCALE,2),round((hy1-hy0)*SCALE,2)],
            'covered_ceiling':True,'vault_roof_panels':n_x*n_y,'vault_rib_segments':rib_segs,
            'source_panorama':['15872_Ostgebaeude_Kessel.jpg','15873_Ostgebaeude_Dachraum.jpg'],
            'approximation_not_measured':True}


def northern_hall_details(m):
    """The north hall panoramas show piers, deep capitals, short wall pipes."""
    m.part='R21 north vaulted hall exposed column head joints'
    piers=0
    for x in (-2.88,-2.16,-1.43,-.70,.03):
        for y in (-6.98,-4.91):
            m.box(x-.038,x+.038,y-.038,y+.038,-1.26,-1.215,'concrete')
            m.box(x-.017,x+.017,y-.017,y+.017,-1.920,-1.263,'concrete')
            piers+=1
    m.part='R21 north hall surviving equipment brackets'
    brackets=0
    for x in (-2.78,-1.58,-.25):
        for y in (-6.96,-4.96):
            beam(m,(x,y,-1.62),(x+.055,y+(.07 if y < -6 else -.07),-1.51),.009,.011,'metal')
            brackets+=1
    return {'column_joints':piers,'equipment_brackets':brackets,
            'panorama':['15867_Nordhalle_innen.jpg','15868_Nordhalle_Dach.jpg'],
            'roof_openings_preserved':True}


def exposed_northeast_block_atrium(m):
    """Conservative edge finishing around pre-existing 3-level open atrium.

    Historical R19 calls this the 'south' block, but under the corrected
    R20 orientation its LOCAL -X/+Y position is roughly north-east. It
    would be unjustified to teleport its existing stairs to a different
    building on the strength of panorama filenames alone.
    """
    m.part='R21 open production block exposed broken stair nosings'
    treads=0
    for z in (-1.70,-1.43,-1.16):
        for y0,y1 in ((2.08,2.31),(2.50,2.70)):
            # East edge of atrium but not the center or passage.
            m.box(-2.975,-2.966,y0,y1,z-.012,z,'concrete')
            treads+=1
    m.part='R21 production block partial rim reinforcement'
    for z in (-1.70,-1.43,-1.16):
        for x0,x1 in ((-3.93,-3.74),(-3.23,-3.05)):
            beam(m,(x0,3.164,z-.019),(x1,3.164,z-.019),.009,.011,'metal')
    return {'broken_nosings':treads,'clear_central_void_unchanged':True,
            'orientation_note':'The modeled block lies at negative X (+north) and positive Y (+east); pano south naming is not georegistered.'}


def courtyard_ruin(m):
    """Add diagonal broken roof tie members, with open bays and rubble."""
    m.part='R21 partially collapsed courtyard structure diagonal ties'
    ties=0
    for x in (2.64,3.06,3.52,4.00):
        beam(m,(x,-4.92,-1.357),(x+.07,-4.59,-1.464),.010,.012,'concrete')
        ties+=1
    m.part='R21 courtyard annex small loose debris'
    debris=0
    for i,(x,y) in enumerate(((2.68,-4.85),(2.80,-4.72),(3.14,-4.87),
                            (3.28,-4.63),(3.65,-4.87),(3.86,-4.74))):
        rubble(m,(x,y,-1.92),.07,.055,.027,.38+i*.31,i+421)
        debris+=1
    return {'short_diagonal_ties':ties,'loose_rubble_piles':debris,
            'continuous_roof_added':False,
            'source_photos':['beschädigtes_vorgebäude_große_halle_standort_innenhof_blickrichtun_süd_west.jpg','15883_Suedwesthalle.jpg']}


def main(source,output,collision,report):
    raw=Path(source).read_bytes();sha=hashlib.sha256(raw).hexdigest()
    if sha!=SOURCE_SHA:raise ValueError('Expected verified R20 GLB: '+sha)
    n=struct.unpack_from('<I',raw,12)[0]
    doc=json.loads(raw[20:20+n]);buf=bytearray(raw[28+n:])
    assert len(doc['meshes'])==24 and doc['meshes'][-1]['name'].startswith('R20')
    scan_names=[m['name'] for m in doc['meshes'][:15]]
    scan_json=[json.dumps(m,sort_keys=True) for m in doc['meshes'][:15]]
    root=json.dumps(doc['nodes'][0],sort_keys=True)
    old_platform=np.array(EAST_NORTH_PLATFORM)
    removed=replace_short_gallery_model(doc,buf)
    removed_east_sheet=remove_east_legacy_solid_roof(doc,buf)
    geom=Mesh()
    hall=hall_mezzanines(geom)
    roof=hall_roof_repairs(geom)
    east=east_top_stair_and_roof(geom)
    northern=northern_hall_details(geom)
    atrium=exposed_northeast_block_atrium(geom)
    ruined=courtyard_ruin(geom)
    added=append_generated(doc,buf,geom)
    doc['meshes'][-1]['name']='R21 photo-audited long galleries, east roof and hatch, hall and annex details'
    doc['nodes'][-1]['name']='R21 R20 geographic alignment preserved; reference constrained interior geometry'
    doc['asset']['extras']['modifications']+=(' R21: source-photo/panorama audit with corrected model cardinal axes; '
         'replace short R18 elevated hall galleries by long, discontinuous dual-side concrete decks; '
         'true floor voids and roof holes kept clear; remove obsolete R6 solid east top roof, shallow enclosed barrel-vault upper east production '
         'roof and narrowed open upper stair hatch per panorama 15873; northern hall pier details, '
         'broken courtyard braces, atrium lip reinforcement. Original 15 RAWscan meshes unchanged; '
         'R20 east/north exterior platform and central/south-east silo roof distinctions unchanged. '
         'Photo-based heuristic, never survey or real flight safety reference; CC BY-NC provenance retained.')
    buf=compact(doc,buf)
    assert [m['name'] for m in doc['meshes'][:15]]==scan_names
    assert [json.dumps(m,sort_keys=True) for m in doc['meshes'][:15]]==scan_json
    assert json.dumps(doc['nodes'][0],sort_keys=True)==root
    serialize_glb(doc,buf,output)
    v,t=read_glb(output)
    unique=np.unique(np.sort(t,axis=1),axis=0)
    meta=build(v,unique,collision)
    f=Path(collision).read_bytes();magic,nv,nt,_=struct.unpack_from('<4sIII',f)
    assert magic==b'FPC1' and nv==len(v) and nt==len(unique)
    fv=np.frombuffer(f,dtype='<f4',count=nv*3,offset=16).reshape(-1,3)
    ft=np.frombuffer(f,dtype='<u4',count=nt*3,offset=16+nv*12).reshape(-1,3)
    assert np.array_equal(v,fv)
    assert np.array_equal(unique,np.unique(np.sort(ft,axis=1),axis=0))
    meta.update(revision='R21',source_r20_sha256=sha,
                glb_sha256=hashlib.sha256(Path(output).read_bytes()).hexdigest(),
                fpc_sha256=hashlib.sha256(f).hexdigest(),
                source_scan_meshes_preserved=15,registration_preserved=True,
                retained_r20_northeast_platform_local=old_platform.tolist(),
                preserved_south_east_silo_closed=True,
                preserved_central_silo_dive=True,
                removed_r18_short_gallery_triangles=removed,
                removed_obsolete_east_roof_triangles=removed_east_sheet,
                added_triangles_by_material=added,extended_high_hall_galleries=hall,
                hall_roof=roof,east_upper_room=east,north_vault=northern,
                northeast_atrium=atrium,annex=ruined,visual_triangles=len(t),
                unique_collision_triangles=len(unique),surveyed=False)
    Path(report).parent.mkdir(parents=True,exist_ok=True)
    Path(report).write_text(json.dumps(meta,indent=2,ensure_ascii=False)+'\n')
    print(json.dumps(meta,indent=2,ensure_ascii=False))

if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__)
    for k in ('source','output','collision','report'):p.add_argument(k)
    a=p.parse_args();main(a.source,a.output,a.collision,a.report)
