#!/usr/bin/env python3
"""R27 replace the courtyard forebuilding by the four-silo area, not a scan overlay.

User photographs: damaged forebuilding from courtyard facing SW, views of the
collapsed external stair/rubble, and courtyard facing south. The documented
R6 'other production' footprint beside the two eastern silo cylinders is a
non-surveyed positional match. Our model replaces that *entire* obsolete R6+
R19/R23 envelope and its overlapping original scan fragments inside a narrow
volume, then builds a low accessible forebuilding with genuine door/window
holes, a two-height open concrete porch and a broken exterior inclined slab.
The cliff-like scan chunks and geometry outside the masks are retained with UV
interpolation. Ground below the masks and adjacent silo geometry are retained.

Four newly generated self-contained textures are embedded in GLB and applied
only to R27 meshes; no reference photographs are embedded/reproduced.
"""
from __future__ import annotations
import argparse, hashlib, io, json, struct
from pathlib import Path
import numpy as np
from PIL import Image
from build_collision import AXIS, read_glb, build
from reconstruct_ruedersdorf_r6 import Mesh, beam, rubble
from refine_ruedersdorf_r13 import compact
from refine_ruedersdorf_r24 import append_generated, serialize_glb
from refine_ruedersdorf_r25 import cut_mesh, vertical_wall

SOURCE_SHA = '3a8f8431806491cba7ca2fccb1084c7c9f9825b550750cfa659f1f1f2b843f2b'
SCALE = 16.023268178233355
# +X predominantly south, +Y predominantly east. Footprint is an approximate
# identification, not photograph-to-world registration.
COURTYARD_MASK = (-4.340, -2.570, 1.650, 3.570, -2.010, -.660)
RAMP_MASK = (-3.540, -2.945, 3.570, 4.310, -2.006, -1.185)
# Exclude R13 silo stair (mesh 16) so the nearby two silos remain intact.
OLD_PROCEDURAL = (15, 20, 22, 23, 24, 26, 27)
ENVELOPE = (-4.235, -2.705, 1.812, 3.290)
FLOOR, UPPER, ROOF = -1.966, -1.584, -1.313


def _noise(seed, size=256):
    rng=np.random.default_rng(seed)
    small=rng.normal(size=(32,32)).astype('f4')
    blurred=np.array(Image.fromarray(((small-small.min())/(small.max()-small.min())*255).astype('uint8')).resize((size,size),Image.Resampling.BILINEAR),dtype='f4')
    blurred=(blurred-127)/60
    fine=rng.normal(size=(size,size)).astype('f4')*.28
    return blurred+fine


def procedural_png(kind):
    size=256; noise=_noise({'concrete':2701,'brick':2702,'roof':2703,'metal':2704}[kind],size)
    if kind=='concrete':
        rgb=np.array([135,132,120],dtype='f4')[None,None,:]+noise[:,:,None]*18
        streak=np.random.default_rng(771).random(size)
        rgb-=((np.arange(size)[:,None]%31)/31*streak[None,:])[:,:,None]*11
    elif kind=='brick':
        rgb=np.array([174,160,139],dtype='f4')[None,None,:]+noise[:,:,None]*19
        ys,xs=np.mgrid[:size,:size];row=(ys//14)
        mortar=((ys%14)<2)|(((xs+(row%2)*17)%34)<2)
        rgb=np.where(mortar[:,:,None],rgb*.67+np.array([35,37,34]),rgb)
        bleach=np.random.default_rng(772).random((size//14+1,size//34+2))
        offset=np.clip((bleach[np.minimum(row,bleach.shape[0]-1),np.minimum((xs+(row%2)*17)//34,bleach.shape[1]-1)]-.5)*24,-12,12)
        rgb+=offset[:,:,None]
    elif kind=='roof':
        rgb=np.array([81,85,76],dtype='f4')[None,None,:]+noise[:,:,None]*21
        green=np.clip(noise+.3,0,1.6)
        rgb+=green[:,:,None]*np.array([-12,10,-14],dtype='f4')
    else:
        rgb=np.array([81,76,69],dtype='f4')[None,None,:]+noise[:,:,None]*22
        rust=np.clip(noise,0,1.4)
        rgb+=rust[:,:,None]*np.array([33,-6,-18],dtype='f4')
    a=np.clip(rgb,0,255).astype('uint8')
    im=Image.fromarray(a,'RGB')
    out=io.BytesIO();im.save(out,format='PNG',optimize=True)
    return out.getvalue()


def add_r27_materials(doc,buf):
    """Embed original procedural texture PNGs without external file references."""
    names={}
    if 'samplers' not in doc:doc['samplers']=[]
    sampler=len(doc['samplers']); doc['samplers'].append({'magFilter':9729,'minFilter':9987,'wrapS':10497,'wrapT':10497})
    for key,label in [('concrete','R27 stained concrete'),('brick','R27 bleached brick'),
                      ('roof','R27 mossy roof'),('metal','R27 oxidized steel')]:
        raw=procedural_png(key)
        buf.extend(b'\0'*(-len(buf)%4))
        view=len(doc['bufferViews'])
        doc['bufferViews'].append({'buffer':0,'byteOffset':len(buf),'byteLength':len(raw)})
        buf.extend(raw)
        image=len(doc['images']);doc['images'].append({'name':label,'bufferView':view,'mimeType':'image/png'})
        texture=len(doc['textures']);doc['textures'].append({'name':label,'sampler':sampler,'source':image})
        material=len(doc['materials'])
        doc['materials'].append({'name':label,'doubleSided':True,
          'pbrMetallicRoughness':{'baseColorTexture':{'index':texture},'metallicFactor':0.0,'roughnessFactor':0.94}})
        names[key]=material
    return names


def inclined_slab(m, a,b,c,d,material='concrete'):
    """One real sloping thin plate, defined by four top vertices (in world local)."""
    thick=.010
    m.quad(a,b,c,d,material)
    bottom=[(p[0],p[1],p[2]-thick) for p in (a,b,c,d)]
    m.quad(bottom[3],bottom[2],bottom[1],bottom[0],material)
    for j in range(4):
        k=(j+1)%4
        m.quad((a,b,c,d)[j],bottom[j],bottom[k],(a,b,c,d)[k],material)


def build_forebuilding(m):
    x0,x1,y0,y1=ENVELOPE
    # Photograph: a low podium wing of brickwork LEFT, with a deep concrete
    # entrance canopy and column-supported open center RIGHT, below the silo.
    m.part='R27 courtyard forebuilding brick wing with genuinely open doors'
    m.box(x0,x1,y0,y1,FLOOR-.012,FLOOR,'concrete')
    cutouts={
      'front':[(x0+.10,x0+.29,FLOOR+.005,FLOOR+.267),
               (x0+.390,x0+.54,FLOOR+.005,FLOOR+.260),
               (x0+.345,x0+.380,FLOOR+.310,FLOOR+.400)],
      'rear':[(x0+.115,x0+.305,FLOOR+.007,FLOOR+.268),
              (x0+.380,x0+.555,FLOOR+.027,FLOOR+.257)],
      'left':[(y0+.36,y0+.60,FLOOR+.009,FLOOR+.285),
              (y0+.72,y0+.89,FLOOR+.302,FLOOR+.420)]
    }
    front_panels=vertical_wall(m,'y',y1,(x0,-3.603),(FLOOR,ROOF-.028),cutouts['front'],'brick',.018)
    rear_panels=vertical_wall(m,'y',y0,(x0,-3.608),(FLOOR,ROOF-.035),cutouts['rear'],'brick',.016)
    left_panels=vertical_wall(m,'x',x0,(y0,y1),(FLOOR,ROOF-.024),cutouts['left'],'concrete',.019)
    # Wide central porch has NO infill curtain: the opening is the entrance.
    m.part='R27 front open undercroft and pier capitals'
    posts=0
    for x in (-3.585,-3.184,-2.730):
        for y in (y0+.04,y1-.035):
            m.box(x-.024,x+.024,y-.025,y+.025,FLOOR,ROOF-.013,'concrete')
            m.box(x-.040,x+.040,y-.042,y+.042,ROOF-.108,ROOF-.080,'concrete')
            posts+=1
    # Small partial back wall with an actual walk-through opening in middle.
    rear_bays=vertical_wall(m,'y',y0,(-3.57,x1),(FLOOR,ROOF-.058),
         [(-3.300,-3.065,FLOOR+.007,FLOOR+.292)],'concrete',.014)
    # Fragmentary upper brick course above left front ground-level openings
    # (front face follows photograph; no windows filled with collision glass).
    for x in (x0+.06,x0+.32,x0+.56):
        m.box(x-.009,x+.009,y1-.009,y1+.009,FLOOR+.335,ROOF-.025,'concrete')
    # Full-height pillar at an annex entrance, deliberately not centered on
    # opening. Floor and false roof from R6 have been removed first.
    m.part='R27 surviving flat roof slab, edge flaking and drain run'
    # main continuous slab, only short notch at east edge, no false dive hole
    for xa,xb,ya,yb in [(x0,x1-.048,y0,y1-.015),
                        (x1-.048,x1,y0,y1-.45),
                        (x1-.048,x1,y1-.365,y1-.015)]:
        m.box(xa,xb,ya,yb,ROOF-.029,ROOF,'roof')
    m.box(x0-.015,x1-.020,y1-.025,y1+.025,ROOF-.045,ROOF-.029,'concrete')
    m.box(x0+.015,x1-.040,y0-.014,y0+.014,ROOF-.037,ROOF-.029,'concrete')
    for x in (-3.97,-3.56,-3.14,-2.79):
        beam(m,(x,y0+.03,ROOF-.07),(x,y1-.045,ROOF-.07),.014,.015,'concrete')
    # Additional lower garage-wing porch on the right with a separate
    # slab/lintel, open exterior and no shutter panels.
    m.part='R27 low side canopy with unblocked two-bay garage entrance'
    wing=(-3.230,-2.765,y1-.035,y1+.235)
    wx0,wx1,wy0,wy1=wing
    canopy_z=ROOF-.073
    m.box(wx0,wx1,wy0,wy1,canopy_z-.021,canopy_z,'roof')
    for x in (wx0+.027,wx1-.027):
        for y in (wy1-.023,):
            m.box(x-.021,x+.021,y-.022,y+.022,FLOOR,canopy_z-.016,'concrete')
    # A few upper-level brick rail fragments on the roof edge.
    m.part='R27 fractured low parapets and roof handrail fragments'
    for xa,xb in [(-4.205,-4.043),(-3.90,-3.73)]:
        m.box(xa,xb,y0-.008,y0+.013,ROOF,ROOF+.037,'concrete')
    for x in (-4.155,-3.915,-3.465):
        m.box(x-.005,x+.005,y0+.010,y0+.016,ROOF,ROOF+.053,'metal')
    # Real ramps rather than an opaque false collision wall. The diagonal
    # tread is broken into irregular slabs; its underside stays visible.
    m.part='R27 fallen exterior inclined concrete stair slab with gaps'
    ramp_x0,ramp_x1=-3.45,-3.052
    y_hi,y_lo=y1+.022,4.106
    z_hi,z_lo=ROOF+.007,FLOOR+.055
    ramp_panels=0
    def rheight(y):return z_hi+(z_lo-z_hi)*(y-y_hi)/(y_lo-y_hi)
    edges=np.linspace(y_hi,y_lo,17)
    for i,(a,b) in enumerate(zip(edges[:-1],edges[1:])):
        if i in (5,11):continue # damaged-through slab gaps
        jitter=(i%5-2)*.004
        xa=ramp_x0+jitter if i!=8 else ramp_x0+.052
        xb=ramp_x1-jitter if i not in (3,14) else ramp_x1-.042
        # explicit top face, bottom face, and edge quads
        z0,z1=rheight(a),rheight(b)
        inclined_slab(m,(xa,a,z0),(xb,a,z0),(xb,b,z1),(xa,b,z1),'concrete')
        ramp_panels+=1
        if i%3==0:
            beam(m,(xa+.012,a,z0+.004),(xa+.010,b,z1+.005),.005,.005,'metal')
    # Exposed partial stringer/rebar, with deliberate breaks; no full-size
    # stair walls that would block flying underneath the inclined slab.
    m.part='R27 broken steel stringers, open under-ramp space'
    for x in (ramp_x0+.020,ramp_x1-.022):
        for ya,yb in [(y_hi+.02,y_hi+.29),(y_hi+.37,y_hi+.53),(y_hi+.61,y_lo-.03)]:
            beam(m,(x,ya,rheight(ya)-.028),(x,yb,rheight(yb)-.029),.009,.010,'metal')
    # Broken column on the garage side; crossing under the ramp remains open.
    m.part='R27 rubble debris at stair foot, floor-level only'
    rubble_count=0
    for i in range(26):
        xx=ramp_x0-.095+(i%5)*.108
        yy=3.565+(i//5)*.110
        zz=FLOOR+.013+(i%4)*.009
        rubble(m,(xx,yy,zz),.067+(i%3)*.024,.072,.026+(i%3)*.017,i*.37,2710+i)
        rubble_count+=1
    # Open roof and door circulation above remains usable even with ruins.
    return {'building_local':[x0,x1,y0,y1],
        'building_footprint_m':[round((x1-x0)*SCALE,1),round((y1-y0)*SCALE,1)],
        'low_roof_height_m':round((ROOF-FLOOR)*SCALE,1),
        'brick_facade_tiles':front_panels+rear_panels+left_panels,
        'rear_bays':rear_bays,'door_voids':6,'open_undercroft_post_count':posts,
        'inclined_broken_stair_segments':ramp_panels,'rubble_chunks':rubble_count,
        'two_stair_gaps':True,'fully_accessible_exterior_and_internal_openings':True,
        'photo_to_mesh_registration':'not surveyed, R6 footprint used as approximate locator'}


def main(src,dst,fpc,report):
    raw=Path(src).read_bytes();sha=hashlib.sha256(raw).hexdigest()
    if sha!=SOURCE_SHA:raise ValueError(f'Expected R26 GLB sha {SOURCE_SHA}; got {sha}')
    n=struct.unpack_from('<I',raw,12)[0]
    doc=json.loads(raw[20:20+n]);buf=bytearray(raw[28+n:])
    assert len(doc['meshes'])==30 and doc['meshes'][-1]['name'].startswith('R26')
    root_before=json.dumps(doc['nodes'][0],sort_keys=True)
    old_mesh_names=[m['name'] for m in doc['meshes'][:15]]
    scan_cuts={str(mi):cut_mesh(doc,buf,mi,COURTYARD_MASK,raw_scan=True) for mi in range(15)}
    overlays={str(mi):cut_mesh(doc,buf,mi,COURTYARD_MASK) for mi in OLD_PROCEDURAL}
    ramp_scan={str(mi):cut_mesh(doc,buf,mi,RAMP_MASK,raw_scan=True) for mi in range(15)}
    # Cut prior geometry touching the collapsed stair only where necessary;
    # neighbouring silo stairs (mesh 16) are intentionally not altered.
    ramp_overlays={str(mi):cut_mesh(doc,buf,mi,RAMP_MASK) for mi in OLD_PROCEDURAL}
    for mesh in doc['meshes']:
        mesh['primitives']=[p for p in mesh['primitives'] if doc['accessors'][p['indices']]['count']>0]
    removed_raw=sum(v['removed_fully'] for v in scan_cuts.values())+sum(v['removed_fully'] for v in ramp_scan.values())
    removed_old=sum(v['removed_fully'] for v in overlays.values())+sum(v['removed_fully'] for v in ramp_overlays.values())
    assert removed_old>2500,('Obsolete production shell not replaced',removed_old)
    geom=Mesh();details=build_forebuilding(geom)
    added=append_generated(doc,buf,geom,
        'R27 courtyard forebuilding, genuine facade voids and collapsed external staircase',
        'R27 independently authored courtyard forebuilding')
    material_ids=add_r27_materials(doc,buf)
    available={m['name']:i for i,m in enumerate(doc['materials'])}
    reverse={'R12 r6_concrete':'concrete','R12 r6_brick':'brick',
             'R12 r6_roof':'roof','R15 safety steel':'metal'}
    for prim in doc['meshes'][-1]['primitives']:
        orig=doc['materials'][prim['material']]['name']
        prim['material']=material_ids[reverse[orig]]
    doc['asset']['extras']['modifications']+=(
        ' R27: courtyard forebuilding photo-constrained full replacement, cut '
        'old R6/R19/R23 production block and clipped intersecting original RAWscan '
        'triangles and UVs in bounded x/y/z volumes; open brick door/window voids, '
        'column-supported low roof, partially detached collapsed inclined stair '
        'with broken segments and rubble, independent embedded aged concrete/brick/'
        'mossy roof/rust materials. Preserve surrounding silo shells, R13 silo access '
        'stair, ground, georeference, scanned source attribution; unsurveyed locator.')
    buf=compact(doc,buf)
    assert old_mesh_names==[m['name'] for m in doc['meshes'][:15]]
    assert root_before==json.dumps(doc['nodes'][0],sort_keys=True)
    serialize_glb(doc,buf,dst)
    v,t=read_glb(dst);unique=np.unique(np.sort(t,axis=1),axis=0)
    stats=build(v,unique,fpc)
    b=Path(fpc).read_bytes();magic,nv,nt,_=struct.unpack_from('<4sIII',b)
    assert magic==b'FPC1' and nv==len(v) and nt==len(unique)
    assert np.array_equal(np.frombuffer(b,dtype='<f4',count=nv*3,offset=16).reshape(-1,3),v)
    stats.update(revision='R27',r26_source_sha256=sha,
        glb_sha256=hashlib.sha256(Path(dst).read_bytes()).hexdigest(),
        fpc_sha256=hashlib.sha256(b).hexdigest(),
        raw_removed_fully=removed_raw,old_procedural_removed_fully=removed_old,
        raw_cuts=scan_cuts,old_overlay_cuts=overlays,
        raw_ramp_cuts=ramp_scan,old_ramp_cuts=ramp_overlays,
        original_scan_mesh_groups_retained=15,georeference_unchanged=True,
        preserved_adjacent_silo_stair_mesh=16,model_details=details,
        materials_embedded=[doc['materials'][i]['name'] for i in material_ids.values()],
        generated_faces_by_material=added,visual_triangles=len(t),unique_collision_triangles=nt,
        photo_registration='approximate, not surveyed')
    Path(report).parent.mkdir(parents=True,exist_ok=True)
    Path(report).write_text(json.dumps(stats,indent=2,ensure_ascii=False)+'\n')
    print(f'R27: scan={removed_raw} fully removed; obsolete={removed_old} removed; visual={len(t)}, FPC={nt}')

if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__)
    for key in ('source','output','collision','report'):p.add_argument(key)
    a=p.parse_args();main(a.source,a.output,a.collision,a.report)
