#!/usr/bin/env python3
"""R12 refinement of the Ruedersdorf local scenery.

Builds on the exact R1 source scan and preserves the established R5-R11
workflow, while tightening scan removal around the rebuilt elements and
improving several reconstructed structures:
- alternate stair flights on both silo stair towers
- slightly sloped roof on the east/middle production building
- additional high-end through opening in the long hall, replacing a known
  floating artifact region
- slightly more conservative scan-removal envelopes around rebuilt stairs and
  floors to reduce z-fighting
"""
import argparse, hashlib, io, json, struct
from pathlib import Path
import numpy as np
from scipy.spatial import cKDTree

import reconstruct_ruedersdorf_r6 as base
from build_collision import AXIS, read_glb, build

# Slightly widened removal boxes around known rebuilt zones.

S=base.S
grid=base.grid
refine_roofs=base.refine_roofs

REGIONS=[
    ('long hall',[-5.20,-2.45,-1.98],[3.56,-0.74,0.30]),
    ('vaulted hall',[-3.50,-7.22,-1.98],[0.62,-4.66,-0.08]),
    ('silo stair frame',[1.20,3.52,-2.05],[1.61,4.30,-0.34]),
    ('open factory frame',[4.22,0.98,-2.00],[5.56,3.08,-0.86]),
    ('R6 west production block',[-4.35,1.69,-2.01],[-2.56,3.54,-0.60]),
    ('R6 six silo stair tower',[3.95,-2.36,-2.05],[5.34,-2.08,-0.36]),
]


def _remove_parts(m, names):
    drop={id(p) for name in names for p in m.parts.pop(name,[])}
    if not drop:
        return
    for name in list(m.groups):
        m.groups[name]=[f for f in m.groups[name] if id(f[0]) not in drop]


def _trim_part_bbox(m, part_name, lo, hi):
    """Remove triangles in one rebuilt part whose centroids lie inside bbox."""
    lo=np.asarray(lo,float); hi=np.asarray(hi,float)
    part=m.parts.get(part_name)
    if not part:
        return 0
    keep=[]; drop=set()
    for f in part:
        cen=f.mean(axis=0)
        if np.all(cen>=lo) and np.all(cen<=hi):
            drop.add(id(f))
        else:
            keep.append(f)
    m.parts[part_name]=keep
    if drop:
        for name in list(m.groups):
            m.groups[name]=[g for g in m.groups[name] if id(g[0]) not in drop]
    return len(drop)


def _sloped_roof_box(m,x0,x1,y0,y1,z_low,z_high,thickness=.024,mat='roof'):
    """Thin mono-pitch roof shell."""
    # top surface
    m.quad((x0,y0,z_low),(x1,y0,z_low),(x1,y1,z_high),(x0,y1,z_high),mat)
    # underside
    m.quad((x0,y1,z_high-thickness),(x1,y1,z_high-thickness),(x1,y0,z_low-thickness),(x0,y0,z_low-thickness),'concrete')
    # side strips
    m.quad((x0,y0,z_low),(x0,y1,z_high),(x0,y1,z_high-thickness),(x0,y0,z_low-thickness),'concrete')
    m.quad((x1,y0,z_low),(x1,y0,z_low-thickness),(x1,y1,z_high-thickness),(x1,y1,z_high),'concrete')
    m.quad((x0,y0,z_low),(x0,y0,z_low-thickness),(x1,y0,z_low-thickness),(x1,y0,z_low),'concrete')
    m.quad((x0,y1,z_high),(x1,y1,z_high),(x1,y1,z_high-thickness),(x0,y1,z_high-thickness),'concrete')


def add_hall_through_opening(m):
    # Remove a bounded portion from the high end wall of the long hall and add
    # an access opening plus a small landing. Position is approximate but kept
    # inside the already reconstructed wall.
    _trim_part_bbox(m,'R5 reference-constrained hall and facade',[-5.09,-1.86,-0.84],[-5.03,-1.36,-0.34])
    m.part='R12 high-hall through opening'
    x0,x1=-5.072,-5.028
    y0,y1=-1.84,-1.38
    z0,z1=-0.82,-0.36
    # frame around the opening
    m.box(x0,x1,y0,y0+.035,z0,z1,'concrete')
    m.box(x0,x1,y1-.035,y1,z0,z1,'concrete')
    m.box(x0,x1,y0,y1,z0,z0+.035,'concrete')
    m.box(x0,x1,y0,y1,z1-.035,z1,'concrete')
    # small exterior landing and rails
    lx0,lx1=-5.11,-5.02
    ly0,ly1=-1.79,-1.45
    lz=-0.61
    m.box(lx0,lx1,ly0,ly1,lz-.014,lz,'metal')
    for y in [ly0,ly1]:
        m.box(lx0,lx1,y-.004,y+.004,lz,lz+.06,'metal')
    for x in [lx0+0.01,(lx0+lx1)/2,lx1-0.01]:
        for y in [ly0,ly1]:
            m.box(x-.003,x+.003,y-.003,y+.003,lz,lz+.06,'metal')


def silo_stair_frame_r12(m):
    m.part='silo stair frame'
    x0,x1,y0,y1=1.27,1.55,3.59,4.18
    base,top=-2.01,-.465
    levels=np.linspace(base,top,8)
    # frame
    for x in [x0,x1]:
        for y in [y0,y1]:
            m.box(x-.019,x+.019,y-.019,y+.019,base,top,'concrete')
    for k,z in enumerate(levels):
        m.box(x0-.01,x1+.01,y0-.025,y0+.025,z-.026,z,'concrete')
        m.box(x0-.01,x1+.01,y1-.025,y1+.025,z-.026,z,'concrete')
        for x in [x0,x1]:
            m.box(x-.02,x+.02,y0,y1,z-.026,z,'concrete')
        # alternating narrow landings at both ends
        m.box(x0,x1,y0,y0+.11,z-.022,z,'floor')
        m.box(x0,x1,y1-.11,y1,z-.022,z,'floor')
        if k < len(levels)-1:
            # alternating flights left/right and direction north/south
            left = (k % 2 == 0)
            xa,xb=(x0+.045,x0+.13) if left else (x1-.13,x1-.045)
            for s in range(12):
                l=s/12; u=(s+1)/12
                ya=y0+.11+(y1-y0-.22)*l
                yb=y0+.11+(y1-y0-.22)*u
                if k % 2:
                    ya,yb=y0+y1-yb,y0+y1-ya
                h=z+(levels[k+1]-z)*u
                m.box(xa,xb,ya,yb,h-.011,h,'metal')
            # guard on the open side of the flight
            gx = xb+.008 if left else xa-.008
            m.box(gx-.002,gx+.002,y0+.13,y1-.13,z+.02,levels[k+1]+.04,'metal')


def east_frame_r12(m):
    m.part='R12 east production building'
    x0,x1,y0,y1=4.35,5.43,1.05,2.95
    zbase,top=-1.94,-1.05
    m.box(x0+.02,x1-.02,y0+.02,y1-.02,zbase-.032,zbase,'floor')
    es=np.linspace(y0,y1,6)
    for x in [x0,x1]:
        ops=[]
        for i,(a,b) in enumerate(zip(es[:-1],es[1:])):
            if x==x0:
                ops.append((a+.055,b-.055,zbase,-1.73 if i!=2 else -1.64))
            if x==x1 and i in [0,4]:
                ops.append((a+.08,b-.05,zbase,-1.77))
            for j,(c,d) in enumerate([(-1.64,-1.45),(-1.34,-1.11)]):
                ops.append((a+.055,b-.045,c,d))
                if (i+j)%2:
                    grid(m,0,x,a+.055,b-.045,c,d,2,1)
        if x==x1:
            ops.append((1.55,2.45,zbase,-1.72))
        base.facade(m,0,y0,y1,x,zbase,top,ops)
        for y in es:
            zstart=-1.72 if x==x1 and 1.55<y<2.45 else zbase
            m.box(x-.035,x+.035,y-.024,y+.024,zstart,top,'concrete')
    for y in [y0,y1]:
        ops=[(x0+.10,x0+.29,zbase,-1.75),(x0+.38,x0+.68,-1.62,-1.45),(x0+.75,x1-.10,-1.62,-1.45),(x0+.14,x0+.41,-1.32,-1.13),(x0+.61,x1-.10,-1.32,-1.13)]
        base.facade(m,1,x0,x1,y,zbase,top,ops)
    for z in [-1.65,-1.37]:
        # slightly inset slab extents to avoid coplanar overlap with facade/frame members
        m.box(x0+.06,x1-.05,y0+.06,2.60,z-.020,z,'floor')
        m.box(x0+.06,x0+.71,2.60,y1-.05,z-.020,z,'floor')
        for y in es[1:-1]:
            m.box(x0+.06,x1-.05,y-.024,y+.024,z-.046,z,'concrete')
    for z in [zbase,-1.65]:
        for j in range(11):
            x=x0+.73+j*.021
            h=z+.29*(j+1)/11
            m.box(x,x+.021,2.68,2.88,h-.012,h,'concrete')
    # Slight mono-pitch roof matching the visible scan profile.
    _sloped_roof_box(m,x0,x1,y0,y1,top-.012,top+.055,thickness=.022,mat='roof')


def six_tower_r12(m):
    m.part='R6 six silo stair tower'
    x0,x1,y0,y1=4.005,5.29,-2.29,-2.115
    base=-2.005
    levels=[base,-1.84,-1.60,-1.36,-1.14,-.91,-.70,-.47]
    xs=[x0,4.32,4.64,4.98,x1]
    m.box(x0,x1,y0,y1,base-.023,base,'floor')
    for x in xs:
        for y in [y0,y1]:
            m.box(x-.021,x+.021,y-.019,y+.019,base,levels[-1],'concrete')
    for k,z in enumerate(levels[1:]):
        for y in [y0,y1]:
            m.box(x0,x1,y-.024,y+.024,z-.032,z,'concrete')
        for x in xs:
            m.box(x-.024,x+.024,y0,y1,z-.032,z,'concrete')
        m.box(x0,4.32,y0,y1,z-.021,z,'floor')
        m.box(4.98,x1,y0,y1,z-.021,z,'floor')
        if k==len(levels)-2:
            m.box(4.32,4.98,y0,y1,z-.021,z,'floor')
        z0=levels[k]
        # Zig-zag flights: alternate between the lower and upper side of the core.
        side_low = (k % 2 == 0)
        ya,yb=(y0+.026,y0+.094) if side_low else (y1-.094,y1-.026)
        for i in range(14):
            a=4.32+.66*i/14
            b=4.32+.66*(i+1)/14
            if not side_low:
                a,b=4.32+4.98-b,4.32+4.98-a
            h=z0+(z-z0)*(i+1)/14
            m.box(a,b,ya,yb,h-.010,h,'concrete')
        # alternating landing plates that visibly swap sides
        if k < len(levels)-2:
            ly0,ly1=(y0,y0+.11) if side_low else (y1-.11,y1)
            m.box(4.31,4.99,ly0,ly1,z-.020,z,'floor')
        if k>0:
            for a,b in [(x0,4.32),(4.98,x1)]:
                rail_y = y0+.022 if side_low else y1-.028
                for x in [a+.025,(a+b)/2,b-.025]:
                    m.box(x-.003,x+.003,rail_y-.003,rail_y+.003,z,z+.056,'metal')
                m.box(a+.025,b-.025,rail_y-.003,rail_y+.003,z+.050,z+.056,'metal')


def make_geometry():
    # start from the pre-R6 geometry (R5 + chimney + small stair tower)
    m=base._make_r5()
    _remove_parts(m,['vaulted hall and facade','open multistorey factory frame','R4 factory frame and loading hopper','silo stair frame'])
    # targeted hall opening fix
    add_hall_through_opening(m)
    # rebuilt pieces
    base.vault_r6(m)
    east_frame_r12(m)
    base.west_block_r6(m)
    six_tower_r12(m)
    base.gallery_r6(m)
    base.gangway_r6(m)
    silo_stair_frame_r12(m)
    m.part='R6 four silo plinths'
    for i,(x,y,r) in enumerate(base.FOUR):
        base.curved_base(m,x,y,r,i)
    m.part='R6 silo roof rails'
    for x,y,r in base.FOUR:
        base.roof_rail(m,x,y,r,-.461)
    for x,y,r in base.SIX:
        if y>=-1.6:
            base.roof_rail(m,x,y,r,-.46,(np.pi/2,3*np.pi/2) if x<4.6 else (-np.pi/2,np.pi/2))
    newids={id(p) for name,pp in m.parts.items() if name.startswith('R6 ') or name.startswith('R12 ') or name=='silo stair frame' for p in pp}
    for name in list(m.groups):
        if name not in ['concrete','roof','floor','metal','brick']:
            continue
        other=[];new=[]
        for f in m.groups[name]:
            if id(f[0]) in newids:
                new.append((f[0],f[1],f[2]*(.50 if name in ['concrete','roof','floor'] else 1.0)))
            else:
                other.append(f)
        if new:
            m.groups['r6_'+name]=new
            m.groups[name]=other
    return m


def texture(mat):
    return base.texture(mat)


def main(src,dst,fpc,report):
    raw=Path(src).read_bytes()
    n=struct.unpack_from('<I',raw,12)[0]
    doc=json.loads(raw[20:20+n])
    buf=bytearray(raw[28+n:])
    source_sha=hashlib.sha256(raw).hexdigest()
    old_v,old_t=read_glb(src)
    refined,silo_report=base.refine_silos(old_v,old_t)
    refined,roof_report=refine_roofs(refined,old_t)
    tree=cKDTree(old_v)

    def view(payload,target=None):
        buf.extend(b'\0'*(-len(buf)%4))
        i=len(doc['bufferViews'])
        a={'buffer':0,'byteOffset':len(buf),'byteLength':len(payload)}
        if target:
            a['target']=target
        doc['bufferViews'].append(a)
        buf.extend(payload)
        return i

    def acc(a,typ,ctype,target):
        i=len(doc['accessors'])
        a=np.ascontiguousarray(a)
        d={'bufferView':view(a.tobytes(),target),'componentType':ctype,'count':len(a),'type':typ}
        if typ=='VEC3' and target==34962:
            d.update(min=a.min(axis=0).tolist(),max=a.max(axis=0).tolist())
        doc['accessors'].append(d)
        return i

    def get(i):
        a=doc['accessors'][i]
        b=doc['bufferViews'][a['bufferView']]
        dt=np.dtype({5123:'<u2',5125:'<u4',5126:'<f4'}[a['componentType']])
        w={'SCALAR':1,'VEC3':3,'VEC2':2}[a['type']]
        return np.ndarray((a['count'],w),dtype=dt,buffer=buf,offset=b.get('byteOffset',0)+a.get('byteOffset',0),strides=(b.get('byteStride',w*dt.itemsize),dt.itemsize)).copy()

    a=AXIS@np.array(doc['nodes'][0]['matrix']).reshape(4,4,order='F')[:3,:3]
    removed={r[0]:0 for r in REGIONS}
    removed['chimney']=0
    removed['R6 silo plinths']=0
    removed['R6 six silo gallery']=0
    removed['R6 roof gangway']=0
    for mesh in doc['meshes']:
        for p in mesh['primitives']:
            pos=get(p['attributes']['POSITION'])
            v=(pos@a.T).astype('f4')
            dist,ids=tree.query(v)
            assert dist.max()<1e-6
            changed=np.any(refined[ids]!=v,axis=1)
            if changed.any():
                v=refined[ids]
                pos[changed]=(v[changed]@a).astype('<f4')
            t=get(p['indices']).reshape(-1,3)
            cen=v[t].mean(1)
            mask=np.zeros(len(t),bool)
            for name,lo,hi in REGIONS:
                kill=np.all((cen>=lo)&(cen<=hi),axis=1)
                removed[name]+=int(kill.sum())
                mask|=kill
            kill=(np.linalg.norm(cen[:,:2]-[base.CX,base.CY],axis=1)<.268)&(cen[:,2]>-1.985)&(cen[:,2]<.55)
            removed['chimney']+=int(kill.sum())
            mask|=kill
            for cx,cy,r in base.FOUR:
                rr=np.linalg.norm(cen[:,:2]-[cx,cy],axis=1)
                kill=(rr<r+.055)&(cen[:,2]>-1.985)&(cen[:,2]<-1.695)
                removed['R6 silo plinths']+=int((kill&~mask).sum())
                mask|=kill
            for x0,x1,y0,y1 in base.GALLERY:
                kill=(cen[:,0]>x0-.022)&(cen[:,0]<x1+.022)&(cen[:,1]>y0-.022)&(cen[:,1]<y1+.022)&(cen[:,2]>-.462)&(cen[:,2]<-.065)
                removed['R6 six silo gallery']+=int((kill&~mask).sum())
                mask|=kill
            kill=(cen[:,0]>3.43)&(cen[:,0]<3.94)&(cen[:,1]>-1.655)&(cen[:,1]<-1.50)&(cen[:,2]>-.51)&(cen[:,2]<-.38)
            removed['R6 roof gangway']+=int((kill&~mask).sum())
            mask|=kill
            surviving=t[~mask]
            used,remap=np.unique(surviving,return_inverse=True)
            assert len(used)>0
            attrs={}
            for key,idx in p['attributes'].items():
                ar=doc['accessors'][idx]
                val=pos if key=='POSITION' else get(idx)
                attrs[key]=acc(val[used].astype('<f4'),ar['type'],5126,34962)
            p['attributes']=attrs
            dtype,ctype=('<u2',5123) if len(used)<=65536 else ('<u4',5125)
            p['indices']=acc(remap.astype(dtype).ravel(),'SCALAR',ctype,34963)

    m=make_geometry()
    prims=[]
    for name,faces in m.groups.items():
        pos=np.concatenate([f[0] for f in faces])
        normal=np.concatenate([np.repeat(f[1][None,:],3,axis=0) for f in faces])
        uv=np.concatenate([f[2] for f in faces])
        imgidx=len(doc['images'])
        doc['images'].append({'bufferView':view(texture(name)),'mimeType':'image/png','name':'R12 procedural '+name})
        texidx=len(doc['textures'])
        doc['textures'].append({'sampler':0,'source':imgidx})
        mi=len(doc['materials'])
        doc['materials'].append({'name':'R12 '+name,'doubleSided':True,'pbrMetallicRoughness':{'baseColorTexture':{'index':texidx},'metallicFactor':0.0,'roughnessFactor':.94}})
        prims.append({'attributes':{'POSITION':acc((pos@AXIS).astype('<f4'),'VEC3',5126,34962),'NORMAL':acc((normal@AXIS).astype('<f4'),'VEC3',5126,34962),'TEXCOORD_0':acc(uv.astype('<f4'),'VEC2',5126,34962)},'indices':acc(np.arange(len(pos),dtype='<u2' if len(pos)<=65536 else '<u4'),'SCALAR',5123 if len(pos)<=65536 else 5125,34963),'material':mi,'mode':4})
    mi=len(doc['meshes'])
    doc['meshes'].append({'name':'R12 reference-constrained reconstructed geometry','primitives':prims})
    ni=len(doc['nodes'])
    doc['nodes'].append({'name':'R12 experimental reconstruction','mesh':mi})
    doc['scenes'][doc.get('scene',0)]['nodes'].append(ni)
    doc['asset']['extras']['modifications']='FPVManager R12: reduced z-fighting around silo stairs and east floors, alternating silo stair flights, sloped east production roof, high-hall through opening, bounded scan cleanup; historical approximation, not surveyed; CC BY-NC 4.0.'

    usedacc=set()
    for mesh in doc['meshes']:
        for p in mesh['primitives']:
            usedacc.update(p['attributes'].values())
            usedacc.add(p['indices'])
    akeys=sorted(usedacc)
    amap={k:i for i,k in enumerate(akeys)}
    doc['accessors']=[doc['accessors'][k] for k in akeys]
    for mesh in doc['meshes']:
        for p in mesh['primitives']:
            p['attributes']={k:amap[v] for k,v in p['attributes'].items()}
            p['indices']=amap[p['indices']]
    usedviews=sorted({a['bufferView'] for a in doc['accessors']}|{i['bufferView'] for i in doc['images']})
    vmap={k:i for i,k in enumerate(usedviews)}
    newbuf=bytearray(); newviews=[]
    for k in usedviews:
        bv=doc['bufferViews'][k].copy(); off=bv.get('byteOffset',0)
        newbuf.extend(b'\0'*(-len(newbuf)%4))
        bv['byteOffset']=len(newbuf)
        newbuf.extend(buf[off:off+bv['byteLength']])
        newviews.append(bv)
    for obj in doc['accessors']+doc['images']:
        obj['bufferView']=vmap[obj['bufferView']]
    doc['bufferViews']=newviews
    buf=newbuf
    doc['buffers'][0]['byteLength']=len(buf)
    buf.extend(b'\0'*(-len(buf)%4))
    js=json.dumps(doc,separators=(',',':'),ensure_ascii=False).encode()
    js+=b' '*(-len(js)%4)
    chunks=struct.pack('<I4s',len(js),b'JSON')+js+struct.pack('<I4s',len(buf),b'BIN\0')+buf
    Path(dst).write_bytes(struct.pack('<4sII',b'glTF',2,12+len(chunks))+chunks)

    v,t=read_glb(dst)
    _,keep=np.unique(np.sort(t,axis=1),axis=0,return_index=True)
    tclean=t[np.sort(keep)]
    result=build(v,tclean,fpc)
    rawf=Path(fpc).read_bytes()
    _,nv,nt,nn=struct.unpack_from('<4sIII',rawf)
    fv=np.frombuffer(rawf,dtype='<f4',count=nv*3,offset=16).reshape(-1,3)
    ft=np.frombuffer(rawf,dtype='<u4',count=nt*3,offset=16+nv*12).reshape(-1,3)
    assert np.array_equal(fv,v)
    assert np.array_equal(np.unique(np.sort(ft,axis=1),axis=0),np.unique(np.sort(t,axis=1),axis=0))
    rep={
        'source_sha256':source_sha,
        'removed_scan_faces':removed,
        'silo_surface_refinement':silo_report,
        'roof_surface_refinement':roof_report,
        'reconstructed_triangles':{k:len(vv) for k,vv in m.parts.items()},
        'hall_high_bands':base.HIGH_BANDS,
        'hall_low_bands':base.LOW_BANDS,
        'tank_count':4,
        'original_triangles':len(old_t),
        'visual_triangles':len(t),
        'collision':result,
        'unique_triangle_parity':True,
        'local_bounds_before':[old_v.min(0).tolist(),old_v.max(0).tolist()],
        'local_bounds_after':[v[t].min((0,1)).tolist(),v[t].max((0,1)).tolist()],
        'r12_notes':{
            'east_roof':'sloped mono-pitch shell',
            'silo_stair_layout':'alternating left/right flights on both rebuilt stair towers',
            'hall_high_end_fix':'through opening inserted; bounded floating artifact region removed',
        },
    }
    Path(report).write_text(json.dumps(rep,indent=2))
    print(json.dumps(rep,indent=2))
    return m


if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('src')
    p.add_argument('dst')
    p.add_argument('fpc')
    p.add_argument('report')
    args=p.parse_args()
    main(args.src,args.dst,args.fpc,args.report)
