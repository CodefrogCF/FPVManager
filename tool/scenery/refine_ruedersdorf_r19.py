#!/usr/bin/env python3
"""R19 - directly implement approximate interior architecture from 25 panoramas.

Uses the verified R18 visual model (R17 + elevated high-hall galleries).
The matching collider is regenerated from the finished visual triangles.
The original 15 RAWscan meshes and site placement remain immutable.

Registration is NOT surveyed: R19 matches unmistakable *building types*,
levels, exposed stair/ceiling forms, and clear voids to existing R6 shells.
Do not treat the inferred sub-building coordinates as archaeological survey.
Photo attribution remains in GLB metadata; no photos embedded.
"""
from __future__ import annotations
import argparse, hashlib, json, struct
from pathlib import Path
import numpy as np
from build_collision import AXIS,read_glb,build
from reconstruct_ruedersdorf_r6 import Mesh,beam
from refine_ruedersdorf_r13 import compact,get_accessor
from refine_ruedersdorf_r17 import append_generated,replace_indices, SCALE

R18_SHA='7cbc0c3a47f4fe063db381d84e6057910a76125a83b51f84b0fd23659b2e4f59'
REFS={
 'east':['15872_Ostgebaeude_Kessel.jpg','15873_Ostgebaeude_Dachraum.jpg'],
 'vault':['15867_Nordhalle_innen.jpg','15868_Nordhalle_Dach.jpg','15875_Suedosthalle_innen.jpg'],
 'south':['15878_Suedgebaeude_Lochraum.jpg','15879_Suedgebaeude_Kessel_Sockel.jpg','15882_Suedgebaeude_Kessel.jpg'],
 'annex':['15883_Suedwesthalle.jpg','15884_Zusaetzlicher_Panoramaeintrag_15884.jpg'],
}


def remove_false_east_storeys(doc,buf):
    """Replace the R6 two full-area synthetic suspended floors by a tank hall.

    No changes to scan primitive 0..14. R6 floor slabs cross the 4 vessels
    shown under one roof in panorama 15872; their crossing concrete beams
    must go too. Keep exterior walls, roof and rear connecting staircase.
    """
    changed={}
    for p in doc['meshes'][15]['primitives']:
        material=doc['materials'][p['material']]['name']
        if material not in ('R12 r6_floor','R12 r6_concrete'):continue
        xyz=get_accessor(doc,buf,p['attributes']['POSITION']) @ AXIS.T
        t=get_accessor(doc,buf,p['indices']).reshape(-1,3)
        corners=xyz[t];lo=corners.min(1);hi=corners.max(1)
        if material=='R12 r6_floor':
            # First and second floating slabs only; the foundation and roof
            # are untouched. Remove entire synthetic boxes, not arbitrary
            # corners of rectangles (avoids non-manifold scraps).
            center=corners.mean(1)
            kill=((lo[:,0]>4.39)&(hi[:,0]<5.40)&
                  (lo[:,1]>1.09)&(hi[:,1]<2.64)&
                  (((center[:,2]>-1.68)&(center[:,2]<-1.64))|
                   ((center[:,2]>-1.40)&(center[:,2]<-1.36))))
        else:
            # Four interior slab beams on each storey, but not the
            # perimeter columns. Their characteristic transverse boxes are
            # 4.41..5.38 x and 1.406..2.594 y.
            kill=((lo[:,0]>4.399)&(hi[:,0]<5.401)&
                  (lo[:,1]>1.397)&(hi[:,1]<2.601)&
                  (lo[:,2]>-1.710)&(hi[:,2]<-1.350)&
                  ((hi[:,2]<-1.630)|(lo[:,2]>-1.430)))
        changed[material]=int(kill.sum())
        replace_indices(doc,buf,p,t[~kill])
    assert changed['R12 r6_floor'] >= 26,changed
    assert changed['R12 r6_concrete'] >= 48,changed
    return changed


def vessel_cage(m,cx,cy,z0,z1,r):
    """Hollow open-bottom industrial sheet vessel, no fictional solid plug."""
    n=32
    aa=np.linspace(0,2*np.pi,n+1)
    for i in range(n):
        a,b=aa[i],aa[i+1]
        def v(angle,radius,z):return (cx+radius*np.cos(angle),cy+radius*np.sin(angle),z)
        m.quad(v(a,r,z0),v(b,r,z0),v(b,r,z1),v(a,r,z1),'concrete')
        # Add 3 circumferential bands and slender vertical patch seams.
        for z in (z0+.055,z0+.085,z0+.38):
            m.quad(v(a,r+.004,z),v(b,r+.004,z),
                   v(b,r+.004,z+.006),v(a,r+.004,z+.006),'metal')
        if i%4==0:
            beam(m,v(a,r+.003,z0+.09),v(a,r+.003,z1-.03),.003,.004,'metal')
    # Leave bottom open in order to preserve the actual walkable floor and
    # avoid falsely sealing an existing lower passage; there is a closed
    # upper dish at roof height.
    m.cylinder((cx,cy,z1-.006),r,.012,2,'concrete',n)


def add_east_production_tank_hall(m):
    """Four tanks under an upper concrete canopy (15872), no mid-level floors."""
    m.part='R19 east covered four-vessel bay'
    cxs=[4.73]*4;ys=[1.31,1.67,2.03,2.39]
    for x,y in zip(cxs,ys):
        vessel_cage(m,x,y,-1.910,-1.112,.146)
        # Circular foot plinth with a short rusty outlet offset away from
        # the open aisle and away from the front facade.
        m.cylinder((x,y,-1.918),.148,.016,2,'concrete',28)
        m.cylinder((x+.145,y,-1.84),.012,.07,0,'metal',10)
    # Beam-and-arch soffit on the existing roof, NOT a second ceiling slab.
    m.part='R19 east exposed roof haunches'
    for y in [1.14,1.50,1.86,2.22,2.56]:
        left=(4.38,y,-1.18);middle=(4.91,y,-1.092);right=(5.40,y,-1.18)
        beam(m,left,middle,.018,.017,'concrete')
        beam(m,middle,right,.018,.017,'concrete')
    # Narrow horizontal pipework is kept above the walking aisle and does
    # not cut across the open door at the far side of the building.
    m.part='R19 east vessel external manifolds'
    for y in ys:
        beam(m,(4.90,y,-1.71),(5.02,y,-1.71),.006,.006,'metal')
    return {'vessels':4,'tank_diameter_m':round(2*.146*SCALE,2),
            'tank_height_m':round((1.910-1.112)*SCALE,2),
            'roof_and_ground_preserved':True,'panoramas':REFS['east']}


def add_vaulted_hall_arch_and_walkways(m):
    """Open core and raised side landings from interior panoramas."""
    # R6 shell has a transverse circular roof arc, approximate its underside
    # without adding any new collision roof across existing skylights.
    x_values=[-2.88,-2.16,-1.43,-.70,.03]
    ym=(-7.08-4.80)/2
    def rheight(y):
        half=1.14;rise=.50;rad=(half*half+rise*rise)/(2*rise)
        return -.73+rise-rad+np.sqrt(max(0,rad*rad-(y-ym)**2))-.043
    m.part='R19 vaulted hall exposed transverse ceiling arcs'
    for x in x_values:
        ys=np.linspace(-7.02,-4.86,14)
        for a,b in zip(ys[:-1],ys[1:]):
            beam(m,(x,float(a),rheight(float(a))),
                 (x,float(b),rheight(float(b))),.017,.017,'concrete')
    # Detached upper concrete side floors are supported by columns, leaving
    # a broad open middle. Avoid R6 skylights and entrances.
    m.part='R19 vaulted hall two retained upper service decks'
    side_decks=[(-3.22,-2.83,-6.76,-5.30),(-.02,.38,-6.75,-5.26)]
    for x0,x1,y0,y1 in side_decks:
        for a,b in [(y0,y0+.44),(y0+.56,y1)]:
            m.box(x0,x1,a,b,-1.370,-1.343,'concrete')
        for x in (x0+.045,x1-.045):
            for y in (y0+.08,y1-.09):
                m.box(x-.023,x+.023,y-.023,y+.023,-1.917,-1.365,'concrete')
        # Rail only on surviving end segments, never bridging the middle.
        inside=x1 if x0 < -2 else x0
        for a,b in [(y0+.05,y0+.39),(y0+.64,y1-.08)]:
            m.box(inside-.005,inside+.005,a,b,-1.282,-1.276,'metal')
            for y in [a,b]:m.box(inside-.005,inside+.005,y-.004,y+.004,-1.347,-1.282,'metal')
    # A short visibly exposed flight to the west elevated deck, passing
    # beside the open room instead of filling its central atrium.
    m.part='R19 vaulted hall access stair'
    for j in range(14):
        y0=-6.70+j*.033;z=-1.915+(j+1)/14*(1.915-1.346)
        m.box(-2.97,-2.85,y0,y0+.030,z-.010,z,'concrete')
    for x in (-2.969,-2.851):
        beam(m,(x,-6.69,-1.85),(x,-6.25,-1.28),.005,.006,'metal')
    return {'arch_bays':len(x_values),'broken_side_decks':2,
            'central_clear_zone_local_x':[-2.83,-.02],
            'photos':REFS['vault'],'placement_is_approximate':True}


def add_south_block_stairs_and_hole_edges(m):
    """Expose short switchback staircase in existing open west factory block."""
    # West block's existing ring floors have a center atrium. Only stair
    # landings along the far wall are introduced, with NO floor spanning it.
    m.part='R19 west block exposed atrium stair'
    for run in range(2):
        za=-1.985+run*.285
        for j in range(12):
            frac=(j+1)/12
            a=2.72+j*.032
            b=a+.030
            if run%2:a,b=3.16-(j+1)*.032,3.16-j*.032
            z=za+frac*.283
            xl,xr=((-3.71,-3.56) if run==0 else (-3.42,-3.27))
            m.box(xl,xr,min(a,b),max(a,b),z-.011,z,'concrete')
        xl,xr=((-3.71,-3.56) if run==0 else (-3.42,-3.27))
        # Outer rail along the stair pitch, no central concrete curtain.
        beam(m,(xl,2.74,za+.04),(xl,3.12,za+.32),.006,.006,'metal')
        # The landing lies inside the existing open atrium and doesn't cap
        # the multiple-storey view; do not build a solid end-wall.
        m.box(xl,xr,3.12,3.19,za+.271,za+.284,'concrete')
    m.part='R19 west block broken interior edge rail'
    for z in [-1.70,-1.43,-1.16]:
        for ya,yb in [(1.88,2.21),(2.36,2.72)]:
            x=-3.954
            for y in (ya,yb):m.box(x-.004,x+.004,y-.004,y+.004,z,z+.061,'metal')
            m.box(x-.004,x+.004,ya,yb,z+.053,z+.061,'metal')
    return {'stair_runs':2,'steps':24,'center_open':True,
            'photos':REFS['south'],'placement_is_approximate':True}


def add_annex_open_roof_frame(m):
    """Lightweight roof and porch trusses in partially demolished annex."""
    m.part='R19 ruined courtyard annex open frame'
    # Existing R17 north frontage posts x=2.56..4.09 at y=-4.95.
    # Back row is intentionally open; no broad new collision wall.
    for x in [2.57,2.95,3.33,3.71,4.08]:
        m.box(x-.009,x+.009,-4.58,-4.562,-1.922,-1.340,'concrete')
        beam(m,(x,-4.96,-1.340),(x,-4.58,-1.345),.013,.014,'concrete')
    # A few broken upper-level pieces, not a continuous solid roof.
    for x0,x1 in [(2.58,2.91),(3.34,3.70)]:
        m.box(x0,x1,-4.945,-4.60,-1.347,-1.329,'roof')
    # Collapsed interior catwalk, with a wide empty central gap.
    m.part='R19 ruined annex balcony remnants'
    for x0,x1 in [(2.59,3.06),(3.58,4.06)]:
        m.box(x0,x1,-4.76,-4.70,-1.647,-1.634,'metal')
        for x in (x0+.012,x1-.012):
            beam(m,(x,-4.70,-1.644),(x,-4.61,-1.72),.006,.006,'metal')
    return {'open_roof_bays':3,'retained_panel_bays':2,
            'no_continuous_infill':True,'photos':REFS['annex'],
            'placement_is_approximate':True}


def main(src,dst,fpc,report):
    data=Path(src).read_bytes();digest=hashlib.sha256(data).hexdigest()
    if digest!=R18_SHA:raise ValueError(f'Expected verified R18 source {R18_SHA}, got {digest}')
    n=struct.unpack_from('<I',data,12)[0]
    doc=json.loads(data[20:20+n]);buf=bytearray(data[28+n:])
    scans=[m['name'] for m in doc['meshes'][:15]]
    registration=json.dumps(doc['nodes'][0],sort_keys=True)
    # Preserve exactly the existing central-four-silo roof gap, R16 exterior
    # platform, and the sealed south-east six-silo headhouse.
    assert len(doc['meshes'])==22 and doc['meshes'][-1]['name'].startswith('R18')
    removed=remove_false_east_storeys(doc,buf)
    geom=Mesh()
    east=add_east_production_tank_hall(geom)
    vault=add_vaulted_hall_arch_and_walkways(geom)
    south=add_south_block_stairs_and_hole_edges(geom)
    annex=add_annex_open_roof_frame(geom)
    added=append_generated(doc,buf,geom)
    doc['meshes'][-1]['name']='R19 panorama-guided multi-building interior structures'
    doc['nodes'][-1]['name']='R19 four east vessels, vaults, west stairs, ruin details'
    doc['asset']['extras']['modifications']+=(' R19: approximate interiors based on ' 
        '15867/15872/15875/15878/15882/15883/15884 panoramas: ' 
        'four tall tanks replace obsolete two levels of east synthetic floor, ' 
        'arched ribs and interrupted gallery decks, exposed south block stairs, ' 
        'open courtyard annex. No photo-to-world registration or dimensional survey. '
        'All originally scanned geometry, georeferencing, and attribution preserved.')
    buf=compact(doc,buf)
    assert json.dumps(doc['nodes'][0],sort_keys=True)==registration
    assert [m['name'] for m in doc['meshes'][:15]]==scans
    doc['buffers'][0]['byteLength']=len(buf)
    text=json.dumps(doc,ensure_ascii=False,separators=(',',':')).encode('utf8')
    text+=b' '*(-len(text)%4)
    payload=struct.pack('<I4s',len(text),b'JSON')+text+struct.pack('<I4s',len(buf),b'BIN\0')+buf
    Path(dst).parent.mkdir(parents=True,exist_ok=True)
    Path(dst).write_bytes(struct.pack('<4sII',b'glTF',2,len(payload)+12)+payload)
    v,t=read_glb(dst)
    unique=np.unique(np.sort(t,axis=1),axis=0)
    # Current FPC uses unique triangle faces, identical to built-in collider.
    summary=build(v,unique,fpc)
    cv,ct=read_glb(dst)
    assert len(v)==len(cv) and len(t)==len(ct)
    collision=Path(fpc).read_bytes()
    nv,nt,_=struct.unpack_from('<III',collision,4)
    assert nt==len(unique)
    fv=np.frombuffer(collision,dtype='<f4',count=nv*3,offset=16).reshape(-1,3)
    ft=np.frombuffer(collision,dtype='<u4',count=nt*3,offset=16+nv*12).reshape(-1,3)
    assert np.array_equal(v,fv)
    assert np.array_equal(unique,np.unique(np.sort(ft,axis=1),axis=0))
    summary.update(dict(revision='R19',R18_source_sha256=digest,
      glb_sha256=hashlib.sha256(Path(dst).read_bytes()).hexdigest(),
      fpc_sha256=hashlib.sha256(collision).hexdigest(),
      photo_based_not_surveyed=True,first_15_scan_meshes_unchanged=True,
      root_georeference_unchanged=True,removed_old_east_geometry=removed,
      added_triangles_per_material=added,east_tanks=east,vault=vault,
      southern_block=south,south_east_annex=annex,visual_triangles=len(t)))
    Path(report).parent.mkdir(parents=True,exist_ok=True)
    Path(report).write_text(json.dumps(summary,ensure_ascii=False,indent=2)+'\n')
    print(json.dumps(summary,ensure_ascii=False,indent=2))

if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__)
    for key in ['src','dst','fpc','report']:p.add_argument(key)
    a=p.parse_args();main(a.src,a.dst,a.fpc,a.report)
