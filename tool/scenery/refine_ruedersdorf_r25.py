#!/usr/bin/env python3
"""R25: true, bounded replacement of old scan/procedural building shells.

Two pilot buildings:
* Northwest small utility building: remove ALL original textured scan geometry
  inside a bounded volume, including partially crossing triangles, replace with
  independently authored outer walls, doors, windows, floor, roof, rooms & stair.
* Eastern/southeastern production frame: replace the R12-R24 procedural outer
  and inner building shell with open, accessible rooms and platforms (the raw
  scan at this position contains mainly terrain, not building walls).

Preserve the rest of the RAWscan including original UV/material outside masks;
retain asset attribution, georeference and other structural reconstructions.

Source: R24 exact SHA. Rebuilding FPC ensures removed surfaces are not collidable.
The building placement and architecture are photographic approximations, not
survey-grade plans.
"""
from __future__ import annotations
import argparse, hashlib, json, struct
from pathlib import Path
import numpy as np
from build_collision import AXIS,read_glb,build
from reconstruct_ruedersdorf_r6 import Mesh, beam
from refine_ruedersdorf_r13 import compact,get_accessor
from refine_ruedersdorf_r15_silo import append_accessor
from refine_ruedersdorf_r24 import serialize_glb,append_generated,region_hole_slab,SCALE

SOURCE_SHA='cc68e2732b9a9efb7e31ae36534251e0c5d914556a0997e97713ce073f94141d'
# Transform-space oriented building boxes, x toward south, y toward east.
NW_CUT=(-4.59,-3.67,5.70,6.21,-2.06,-1.09)
EAST_CUT=(4.29,5.48,0.99,2.76,-2.012,-.745)
# Specifically limit old procedurally-built *building* meshes, avoid real
# six-silo stairs outside these boxes and scan terrain at z<-2.012.
EAST_PROCEDURAL_MESHES=(15,20,22,23,24,27)
NW_PROCEDURAL_MESHES=(26,)


def replace_indices(doc,buffer,primitive,indices):
    prev=doc['accessors'][primitive['indices']]
    typ=prev['componentType']
    idx=np.asarray(indices,dtype='<u2' if typ==5123 else '<u4').reshape(-1)
    primitive['indices']=append_accessor(doc,buffer,idx,'SCALAR',typ,34963)


def clip_polygon(poly,axis,bound,keep_ge):
    """Clip an interpolatable polygon into inside/outside halfspaces."""
    if len(poly)<3:return []
    result=[]
    prev=poly[-1]; f_prev=float(prev[axis]-bound); prev_inside=(f_prev>=-1e-10 if keep_ge else f_prev<=1e-10)
    for curr in poly:
        f_curr=float(curr[axis]-bound); curr_inside=(f_curr>=-1e-10 if keep_ge else f_curr<=1e-10)
        if curr_inside != prev_inside:
            t=f_prev/(f_prev-f_curr)
            result.append(prev+t*(curr-prev))
        if curr_inside:result.append(curr)
        prev=curr;f_prev=f_curr;prev_inside=curr_inside
    return result


def difference_box(tri,box):
    """Triangle minus axis-aligned 3D box as zero or more retained polygons.

    Each polygon vertex packs local XYZ followed by raw POSITION, NORMAL, UV;
    every intersection linearly interpolates the original texture coordinates.
    """
    inside=[x.copy() for x in tri]
    kept=[]
    faces=[(0,box[0],True),(0,box[1],False),(1,box[2],True),
           (1,box[3],False),(2,box[4],True),(2,box[5],False)]
    for axis,limit,ge in faces:
        outside=clip_polygon(inside,axis,limit,not ge)
        if len(outside)>=3:kept.append(outside)
        inside=clip_polygon(inside,axis,limit,ge)
        if len(inside)<3:break
    tris=[]
    for poly in kept:
        for i in range(1,len(poly)-1):
            candidate=np.stack((poly[0],poly[i],poly[i+1]))
            p=candidate[:,:3]
            if np.linalg.norm(np.cross(p[1]-p[0],p[2]-p[0]))>1e-10:
                tris.append(candidate)
    return tris


def cut_mesh(doc,buf,mesh_index,box,raw_scan=False):
    """Remove a building volume while keeping all surface outside its box.

    Unlike centroid deletion, boundary triangles are *split*. All attributes
    are preserved on fragments so raw scan texture outside the replacement
    boundary remains valid. Scan mesh parent transform is accounted for.
    """
    root=np.array(doc['nodes'][0]['matrix'],dtype=float).reshape(4,4,order='F')[:3,:3]
    transform=AXIS@root if raw_scan else AXIS
    orig=doc['meshes'][mesh_index]['primitives'][:]
    count={'removed_fully':0,'clipped_partial':0,'retained_unaffected':0,'fragment_triangles':0}
    for prim in orig:
        attrs=prim['attributes']; mat=prim['material']
        pos=get_accessor(doc,buf,attrs['POSITION']).astype(np.float64)
        normal=get_accessor(doc,buf,attrs['NORMAL']).astype(np.float64)
        uv=get_accessor(doc,buf,attrs['TEXCOORD_0']).astype(np.float64)
        local=pos@transform.T
        t=get_accessor(doc,buf,prim['indices']).reshape(-1,3)
        faces=local[t];lo=faces.min(1);hi=faces.max(1)
        # Strict bbox overlap: boundary-only faces are retained.
        overlap=((hi[:,0]>box[0])&(lo[:,0]<box[1])&
                 (hi[:,1]>box[2])&(lo[:,1]<box[3])&
                 (hi[:,2]>box[4])&(lo[:,2]<box[5]))
        fully=((lo[:,0]>=box[0])&(hi[:,0]<=box[1])&
               (lo[:,1]>=box[2])&(hi[:,1]<=box[3])&
               (lo[:,2]>=box[4])&(hi[:,2]<=box[5]))
        keep=~overlap
        count['removed_fully']+=int((fully&overlap).sum())
        count['retained_unaffected']+=int(keep.sum())
        # Process only partly-intersecting triangles. Their inner portions
        # must be discarded; never keep an original triangle over a doorway.
        overlap_partial=np.flatnonzero(overlap&~fully)
        count['clipped_partial']+=len(overlap_partial)
        fragments=[]
        for i in overlap_partial:
            ids=t[i]
            pack=np.concatenate((local[ids],pos[ids],normal[ids],uv[ids]),axis=1)
            fragments+=difference_box(pack,box)
        replace_indices(doc,buf,prim,t[keep])
        if fragments:
            v=np.concatenate(fragments).astype(np.float64)
            # Preserve raw glTF local coordinates, normals and UVs. Fragments
            # attach to the same mesh/node and original textured material.
            p=v[:,3:6].astype('<f4')
            no=v[:,6:9]
            length=np.linalg.norm(no,axis=1)
            no=np.divide(no,length[:,None],out=np.zeros_like(no),where=length[:,None]>1e-10).astype('<f4')
            u=v[:,9:11].astype('<f4')
            ia=append_accessor(doc,buf,p,'VEC3',5126,34962)
            na=append_accessor(doc,buf,no,'VEC3',5126,34962)
            ua=append_accessor(doc,buf,u,'VEC2',5126,34962)
            component=5123 if len(p)<65536 else 5125
            indices=np.arange(len(p),dtype='<u2' if component==5123 else '<u4')
            idx=append_accessor(doc,buf,indices,'SCALAR',component,34963)
            newp={'attributes':{'POSITION':ia,'NORMAL':na,'TEXCOORD_0':ua},
                  'indices':idx,'material':mat,'mode':4}
            doc['meshes'][mesh_index]['primitives'].append(newp)
            count['fragment_triangles']+=len(fragments)
    return count


def vertical_wall(m,axis,const,bounds,zrange,openings,material='brick',thickness=.016):
    """Create a real wall with rectangular cutouts for doors and windows.

    Openings are axis-horizontal position / height rectangles; no collision
    faces are generated over the holes.
    """
    a,b=bounds;z0,z1=zrange
    breaks_a=sorted({a,b,*[k for u,v,l,h in openings for k in (u,v)]})
    breaks_z=sorted({z0,z1,*[k for u,v,l,h in openings for k in (l,h)]})
    count=0
    for x0,x1 in zip(breaks_a[:-1],breaks_a[1:]):
        for h0,h1 in zip(breaks_z[:-1],breaks_z[1:]):
            mid=(x0+x1)/2; z=(h0+h1)/2
            if any(u<mid<v and l<z<h for u,v,l,h in openings):continue
            if axis=='x':m.box(const-thickness/2,const+thickness/2,x0,x1,h0,h1,material)
            else:m.box(x0,x1,const-thickness/2,const+thickness/2,h0,h1,material)
            count+=1
    return count


def build_north_utility(m):
    """Replace scan shell with a complete, accessible site-bounded building."""
    xa,xb,ya,yb=(-4.545,-3.735,5.755,6.155)
    floor=-1.982; roof=-1.233
    m.part='R25 northwest utility rebuilt foundation and perimeter walls'
    m.box(xa,xb,ya,yb,floor-.018,floor,'concrete')
    # West/east gables: one open 2.9-m-wide entrance, one broken window.
    openings={
        'south':[(xa+.27,xa+.47,floor+.005,floor+.24),
                 (xa+.075,xa+.21,floor+.37,floor+.55),
                 (xa+.57,xa+.73,floor+.37,floor+.55)],
        'north':[(xa+.12,xa+.29,floor+.37,floor+.54),
                 (xa+.48,xa+.66,floor+.36,floor+.54)],
        'east':[(ya+.10,ya+.29,floor+.015,floor+.27),
                (ya+.11,ya+.31,floor+.42,floor+.55)],
        'west':[(ya+.12,ya+.26,floor+.40,floor+.55)],
    }
    panels=0
    for name,y in (('south',ya),('north',yb)):
        panels+=vertical_wall(m,'y',y,(xa,xb),(floor,roof),openings[name])
    for name,x in (('west',xa),('east',xb)):
        panels+=vertical_wall(m,'x',x,(ya,yb),(floor,roof),openings[name])
    # Real roof cut only over small service hatch; not an invented roof dive.
    m.part='R25 northwest utility pitched/fragmentary roof'
    hatch=(-4.28,-4.13,5.875,6.015)
    region_hole_slab(m,(xa-.018,xb+.018,ya-.016,yb+.016),[hatch],roof-.016,roof,'roof')
    for x in np.linspace(xa+.06,xb-.06,5):
        beam(m,(x,ya+.012,roof-.034),(x,yb-.012,roof-.034),.009,.012,'concrete')
    # A broken transverse inner wall with an actually open doorway.
    m.part='R25 northwest utility accessible rooms and service mezzanine'
    partitions=vertical_wall(m,'x',-4.16,(ya+.015,yb-.015),(floor,roof-.06),
        [(ya+.115,ya+.265,floor+.006,floor+.23)],'concrete',.012)
    # partial mezzanine on northern edge; middle and east doorway remain open
    m.box(-4.53,-4.21,yb-.16,yb-.028,floor+.31,floor+.325,'concrete')
    m.box(-4.06,-3.76,yb-.15,yb-.028,floor+.31,floor+.325,'concrete')
    # short stair on west flank, safe open center
    for i in range(8):
        z=floor+.04*(i+1)
        y=ya+.035+i*.017
        m.box(xa+.028,xa+.12,y,y+.017,z-.011,z,'metal')
    m.part='R25 northwest utility windows frames and fragmented handrails'
    for x in (xa+.10,xa+.60):
        m.box(x-.004,x+.004,ya-.012,ya+.012,floor+.35,floor+.58,'metal')
    for y in (ya+.07,yb-.045):
        beam(m,(xa+.03,y,floor+.393),(xa+.10,y,floor+.393),.004,.004,'metal')
    return {'footprint':[xa,xb,ya,yb],'door_openings':2,
            'window_openings':6,'wall_panels':panels,'partition_panels':partitions,
            'roof_service_hatch_local':hatch,'no_original_scan_shell_inside_cut':True}


def build_east_block(m):
    """New independently authored shell with entrance and open stacked rooms."""
    xa,xb,ya,yb=4.36,5.41,1.075,2.67
    floor=-1.976; roof=-.802
    m.part='R25 east production reconstructed exterior with open entrance'
    m.box(xa,xb,ya,yb,floor-.015,floor,'concrete')
    # Four facades: large industrial doors on two sides, window slots at
    # successive levels. Faces are made only around holes.
    entrances={
     'west':[(ya+.68,ya+.95,floor+.004,floor+.29),
             (ya+.24,ya+.47,floor+.47,floor+.64)],
     'east':[(ya+1.00,ya+1.29,floor+.004,floor+.31),
             (ya+.26,ya+.50,floor+.45,floor+.65)],
     'south':[(xa+.13,xa+.33,floor+.004,floor+.28),
              (xa+.53,xa+.81,floor+.47,floor+.66)],
     'north':[(xa+.20,xa+.46,floor+.43,floor+.64),
              (xa+.66,xa+.90,floor+.75,floor+.96)],
    }
    wall_tiles=0
    for side,x in (('west',xa),('east',xb)):
        wall_tiles+=vertical_wall(m,'x',x,(ya,yb),(floor,roof),entrances[side], 'brick',.018)
    for side,y in (('south',ya),('north',yb)):
        wall_tiles+=vertical_wall(m,'y',y,(xa,xb),(floor,roof),entrances[side], 'brick',.018)
    # Existing photo-informed upper room dome: only beams, accessible edge.
    m.part='R25 east production actual intermediate floors and clear atrium'
    level_heights=(-1.67,-1.40,-1.14)
    slab_count=0
    for z in level_heights:
        # Left and right galleries; central aisle remains open full-height.
        for x0,x1 in ((xa+.030,xa+.29),(xb-.29,xb-.03)):
            for y0,y1 in ((ya+.035,ya+.62),(ya+.82,yb-.045)):
                m.box(x0,x1,y0,y1,z-.015,z,'concrete');slab_count+=1
        if z < -1.20: # staggered crossing, gaps between bridge fragments
            m.box(xa+.30,xb-.30,ya+1.20,ya+1.36,z-.015,z,'metal');slab_count+=1
    for x in (xa+.05,xb-.05):
        for y in np.linspace(ya+.09,yb-.09,5):
            # Never place a full-height post into either open entrance bay.
            if x==xa+.05 and ya+.68-.02 < y < ya+.95+.02: continue
            if x==xb-.05 and ya+1.00-.02 < y < ya+1.29+.02: continue
            m.box(x-.014,x+.014,y-.014,y+.014,floor,roof-.018,'concrete')
    # Corridor room partitions split on both sides, doors open.
    partitions=0
    for x in (xa+.31,xb-.31):
        for y0,y1 in ((ya+.035,ya+.55),(ya+.81,yb-.035)):
            partitions+=vertical_wall(m,'x',x,(y0,y1),(floor,-1.21),
                [(y0+.17,y0+.34,floor+.006,floor+.23)],'concrete',.011)
    # two real open flights, mostly along west edge
    m.part='R25 east production stairs and handrails'
    for level in range(2):
        z0=floor+level*.30
        for i in range(9):
            y=ya+.18+i*.049
            z=z0+.034*(i+1)
            m.box(xa+.08,xa+.23,y,y+.042,z-.010,z,'metal')
        beam(m,(xa+.075,ya+.18,z0+.11),(xa+.075,ya+.61,z0+.41),.004,.005,'metal')
    m.part='R25 east production top skylight strips and ventilators'
    roof_holes=[(xa+.16,xa+.30,ya+.46,ya+.70),
                (xb-.31,xb-.17,ya+1.03,ya+1.30)]
    region_hole_slab(m,(xa,xb,ya,yb),roof_holes,roof-.018,roof,'roof')
    for y in (ya+.12,ya+.55,ya+1.01,ya+1.46):
        beam(m,(xa+.045,y,roof-.028),(xb-.045,y,roof-.028),.008,.012,'metal')
    return {'footprint':[xa,xb,ya,yb], 'wall_panels':wall_tiles,
            'true_openings':sum(len(a) for a in entrances.values()),
            'floor_fragments':slab_count,'partition_panels':partitions,
            'roof_lightwell_holes':roof_holes,
            'no_old_procedural_walls_or_vessels_in_cut':True}


def main(src,dst,fpc,report):
    data=Path(src).read_bytes();sha=hashlib.sha256(data).hexdigest()
    if sha!=SOURCE_SHA:raise ValueError(f'Expected R24 SHA {SOURCE_SHA}, got {sha}')
    n=struct.unpack_from('<I',data,12)[0]
    doc=json.loads(data[20:20+n]);buf=bytearray(data[28+n:])
    root_before=json.dumps(doc['nodes'][0],sort_keys=True)
    assert len(doc['meshes'])==28 and doc['meshes'][-1]['name'].startswith('R24')
    scan_names=[m['name'] for m in doc['meshes'][:15]]
    scan_cut={}
    for mi in range(15):
        scan_cut[str(mi)]=cut_mesh(doc,buf,mi,NW_CUT,raw_scan=True)
    assert sum(c['removed_fully'] for c in scan_cut.values())>1000,scan_cut
    nw_old={str(mi):cut_mesh(doc,buf,mi,NW_CUT) for mi in NW_PROCEDURAL_MESHES}
    east_old={str(mi):cut_mesh(doc,buf,mi,EAST_CUT) for mi in EAST_PROCEDURAL_MESHES}
    # glTF requires positive accessor counts; drop now-empty old primitives.
    for mesh in doc['meshes']:
        mesh['primitives']=[p for p in mesh['primitives']
            if doc['accessors'][p['indices']]['count']>0]
    m=Mesh(); northwest=build_north_utility(m);east=build_east_block(m)
    materials=append_generated(doc,buf,m,
      'R25 first genuinely replaced scan building shells with enterable openings',
      'R25 northwest scan-shell and east procedural-shell replacements')
    extras=doc['asset'].setdefault('extras',{})
    extras['modifications']=extras.get('modifications','') + (
      ' R25: northwest utility raw scan and its generated overlapping structures clipped '
      'out of a surveyed-coordinate but unsurveyed-accuracy building prism, preserving '
      'original textured triangles outside; new enterable exterior/rooms/doors/windows '
      'and collider replace removed surfaces. Also fully replace east synthetic shell, '
      'with open doors, walkways and rooms. Bounding geometry estimates only. Original '
      'attribution, world registration, and all other buildings unchanged.')
    buf=compact(doc,buf)
    assert root_before==json.dumps(doc['nodes'][0],sort_keys=True)
    assert scan_names==[m['name'] for m in doc['meshes'][:15]]
    serialize_glb(doc,buf,dst)
    vertices,triangles=read_glb(dst)
    unique=np.unique(np.sort(triangles,axis=1),axis=0)
    stats=build(vertices,unique,fpc)
    col=Path(fpc).read_bytes()
    magic,nv,nt,_=struct.unpack_from('<4sIII',col)
    assert magic==b'FPC1' and nv==len(vertices) and nt==len(unique)
    cv=np.frombuffer(col,dtype='<f4',count=nv*3,offset=16).reshape(-1,3)
    assert np.array_equal(vertices,cv)
    stats.update(revision='R25', source_r24_sha256=sha,
        glb_sha256=hashlib.sha256(Path(dst).read_bytes()).hexdigest(),
        fpc_sha256=hashlib.sha256(col).hexdigest(),
        scan_cut=scan_cut, northwest_generated_removed=nw_old,
        east_generated_removed=east_old, northwest_replacement=northwest,
        east_replacement=east, new_geometry=materials,
        rendered_triangles=len(triangles), collision_triangles=nt,
        scan_mesh_count_retained=15, georeference_preserved=True,
        precision='unsurveyed photographic approximation',
        replacement_regions={'northwest':NW_CUT,'east':EAST_CUT})
    Path(report).parent.mkdir(parents=True,exist_ok=True)
    Path(report).write_text(json.dumps(stats,indent=2,ensure_ascii=False)+'\n')
    print('R25 completed:',len(triangles),'visual triangles,',nt,'collision triangles; raw scan clipped:',
          sum(c['removed_fully'] for c in scan_cut.values()))

if __name__=='__main__':
    ap=argparse.ArgumentParser(description=__doc__)
    for k in ('source','output','collision','report'):ap.add_argument(k)
    a=ap.parse_args(); main(a.source,a.output,a.collision,a.report)
