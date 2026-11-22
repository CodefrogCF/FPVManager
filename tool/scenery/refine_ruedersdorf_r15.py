#!/usr/bin/env python3
"""FPVManager Rüdersdorf R15: exterior access platform and photo-guided safety frame.

Consumes R14 GLB, produces GLB + exactly matching FPC. The 2023 user-owned FPV
still shows an open guard cage, former ladder platform and pipe at the high end of the
long hall. The precise camera position is not registered; dimensions are
reasonable approximations, not survey coordinates.

Changes are deliberately bounded to the exterior high-hall parapet and silo stair
side frames. The last R11 terrain underlay and all global georeferencing stay
unchanged. The mesh and collider always share the same triangle set.
"""
from __future__ import annotations
import argparse,hashlib,io,json,struct,sys
from pathlib import Path
import numpy as np
from PIL import Image
from scipy.ndimage import gaussian_filter
from build_collision import AXIS,read_glb,build
from reconstruct_ruedersdorf_r6 import Mesh,beam
from refine_ruedersdorf_r13 import get_accessor,compact

ROOT_SHA='36929fed395895b5d47c002a49de824ff68a12b920d83973634505ce50e6ea93'
SCALE=16.023268178233355
# Local geometry units ~16.02 m per unit; reference registration still approximate.
ROOF=(-5.06,-2.65,-2.304,-.880)
# The platform is OUTSIDE the south wall, not an opening through the roof.
EXTERIOR_PLATFORM=(-5.02,-4.78,-2.55,-2.31)
Z_TOP=-.078
Z_UNDER=-.117
LEVELS=[-2.005,-1.84,-1.60,-1.36,-1.14,-.91,-.70,-.47]


def sha(data):return hashlib.sha256(data).hexdigest()


def add_view(doc,buf,payload,target=None):
 data=np.asarray(payload).tobytes() if not isinstance(payload,(bytes,bytearray)) else payload
 buf.extend(b'\0'*(-len(buf)%4));o=len(buf);buf.extend(data)
 vi=len(doc['bufferViews']);item={'buffer':0,'byteOffset':o,'byteLength':len(data)}
 if target is not None:item['target']=target
 doc['bufferViews'].append(item)
 return vi


def add_accessor(doc,buf,array,kind,component,target):
 a=np.ascontiguousarray(array)
 vi=add_view(doc,buf,a,target)
 meta={'bufferView':vi,'componentType':component,'count':len(a),'type':kind}
 if kind=='VEC3' and target==34962:
  meta.update(min=a.min(axis=0).tolist(),max=a.max(axis=0).tolist())
 k=len(doc['accessors']);doc['accessors'].append(meta);return k


def replace_indices(doc,buf,pr,indices):
 old=doc['accessors'][pr['indices']]
 dtype=np.dtype('<u2' if old['componentType']==5123 else '<u4')
 pr['indices']=add_accessor(doc,buf,np.asarray(indices,dtype=dtype).reshape(-1),'SCALAR',old['componentType'],34963)


def add_exterior_platform(m):
    """Guarded remnant of a former exterior ladder platform.

    User's 2023 FPV still confirms that it attaches to the outer facade. The
    original ladder is no longer present, and the adjacent roof is intact.
    """
    m.part='R15 exterior former ladder platform'
    x0,x1,y0,y1=EXTERIOR_PLATFORM
    landing=-.116
    # Open metal lattice seen in the user's 2023 FPV still.  The grating is
    # modeled with actual spaced members rather than a fake solid plate, so
    # fly-through collision behavior follows visible geometry.
    edge=.011
    for x in (x0+edge/2,x1-edge/2):
        m.box(x-edge/2,x+edge/2,y0,y1,landing-.009,landing,'metal')
    for y in (y0+edge/2,y1-edge/2):
        m.box(x0,x1,y-edge/2,y+edge/2,landing-.009,landing,'metal')
    for x in np.linspace(x0+.027,x1-.027,8):
        m.box(x-.0025,x+.0025,y0+edge,y1-edge,landing-.006,landing,'metal')
    for y in np.linspace(y0+.027,y1-.027,7):
        m.box(x0+edge,x1-edge,y-.0025,y+.0025,landing-.006,landing,'metal')
    # Anchored brackets from facade towards outer corners; no roof penetration.
    for x in [x0+.035,x1-.035]:
        beam(m,(x,y1+.022,landing-.20),(x,y0+.006,landing-.012),.014,.014,'metal')
        m.box(x-.008,x+.008,y1-.018,y1+.025,landing-.24,landing-.19,'metal')
    # Four upright posts and open guard cage; one diagonal per side.
    cap=landing+.127
    for x in (x0,x1):
        for y in (y0,y1):
            m.box(x-.004,x+.004,y-.004,y+.004,landing,cap,'metal')
    for y in (y0,y1):
        m.box(x0,x1,y-.003,y+.003,cap-.006,cap+.002,'metal')
        m.box(x0,x1,y-.003,y+.003,landing+.062,landing+.068,'metal')
    m.box(x0-.003,x0+.003,y0,y1,cap-.006,cap+.002,'metal')
    m.box(x1-.003,x1+.003,y0,y0+.064,cap-.006,cap+.002,'metal')
    m.box(x1-.003,x1+.003,y1-.064,y1,cap-.006,cap+.002,'metal')
    beam(m,(x0,y0,landing+.015),(x1,y0,cap-.008),.010,.010,'metal')
    beam(m,(x1,y1,landing+.015),(x0,y1,cap-.008),.010,.010,'metal')
    # Short stabilizers; no reconstructed missing ladder and no through-roof
    # collision geometry. End wall and roof are untouched.
    for y in (y0+.035,y1-.035):
        m.box(x0+.008,x0+.014,y-.004,y+.004,landing-.02,landing+.035,'metal')


def add_pipe_and_roof_traces(m):
 m.part='R15 rooftop pipe and longitudinal elements'
 # Short horizontal abandoned steel pipe adjacent to cage (2023 screenshot).
 # Lateral geometry does not overlap the exterior landing.
 m.cylinder((-4.605,-1.994,Z_TOP+.045),.027,.235,0,'metal',24)
 for x in [-4.696,-4.51]:
  m.box(x-.009,x+.009,-2.015,-1.973,Z_TOP+.004,Z_TOP+.018,'concrete')
 # A few slender longitudinal roof ribs; original roof stays intact.
 for y in [-1.905,-1.85,-1.795]:
  m.box(-5.005,-4.315,y-.004,y+.004,Z_TOP+.002,Z_TOP+.007,'roof')


def add_silo_stair_rail_refinements(m):
 m.part='R15 silo stair continuity'
 # Two towers are already switchback in R12. Add exposed side handrails at
 # every distinct stair flight. Keep them offset from the tread surfaces by
 # approximately 5-8 cm and outside the flyable core.
 for k in range(len(LEVELS)-1):
  z0,z1=LEVELS[k:k+2]
  # six-silo tower: alternating y side / direction
  y=(-2.314 if k%2==0 else -2.091)
  x0,x1=(4.32,4.98) if k%2==0 else (4.98,4.32)
  beam(m,(x0,y,z0+.062),(x1,y,z1+.062),.005,.005,'metal')
  for f in [0,.5,1]:
   x=x0+(x1-x0)*f;z=z0+(z1-z0)*f
   beam(m,(x,y,z+.009),(x,y,z+.062),.004,.004,'metal')
 # four-silo narrow tower: alternating eastern/western flights.
 levels=np.linspace(-2.01,-.465,8)
 for k,(z0,z1) in enumerate(zip(levels[:-1],levels[1:])):
  x=1.429 if k%2==0 else 1.249
  y0,y1=(3.70,4.07) if k%2==0 else (4.07,3.70)
  beam(m,(x,y0,z0+.060),(x,y1,z1+.060),.004,.004,'metal')


def material_texture(seed=15023,side=256):
 # Own deterministic material, not copied frames: aged galvanized handrail.
 rng=np.random.default_rng(seed);n=rng.standard_normal((side,side)).astype('f4')
 n=gaussian_filter(n,4);n/=max(n.std(),1e-3)
 fine=rng.standard_normal((side,side)).astype('f4')
 rust=np.clip((n-.1)*.19,0,.4)
 base=np.asarray([85,87,84])[None,None,:]+n[:,:,None]*5+fine[:,:,None]*3+rust[:,:,None]*[44,10,-7]
 raw=Image.fromarray(np.clip(base,0,255).astype('uint8'))
 output=io.BytesIO();raw.save(output,format='PNG');return output.getvalue()


def append_geometry(doc,buf,m,roof_mat):
 existing={mat.get('name'):i for i,mat in enumerate(doc['materials'])}
 concrete_mat=existing.get('R12 r6_concrete',existing.get('R12 concrete'))
 metal_mat=existing.get('R12 r6_metal',existing.get('R12 metal'))
 assert concrete_mat is not None and metal_mat is not None
 image_id=len(doc['images']);doc['images'].append({'name':'R15 generated oxidized safety steel','mimeType':'image/png','bufferView':add_view(doc,buf,material_texture())})
 tex_id=len(doc['textures']);doc['textures'].append({'sampler':doc['textures'][0].get('sampler',0),'source':image_id})
 special_mi=len(doc['materials']);doc['materials'].append({'name':'R15 safety steel','doubleSided':True,'pbrMetallicRoughness':{'baseColorTexture':{'index':tex_id},'metallicFactor':0.,'roughnessFactor':.93}})
 mats={'roof':roof_mat,'concrete':concrete_mat,'metal':special_mi}
 prims=[];counts={}
 for name,faces in m.groups.items():
  if not faces:continue
  pos=np.concatenate([f[0] for f in faces]).astype('<f4')
  norm=np.concatenate([np.repeat(f[1][None,:],3,axis=0) for f in faces]).astype('<f4')
  uv=np.concatenate([f[2] for f in faces]).astype('<f4')
  ai=add_accessor(doc,buf,(pos@AXIS).astype('<f4'),'VEC3',5126,34962)
  ni=add_accessor(doc,buf,(norm@AXIS).astype('<f4'),'VEC3',5126,34962)
  ui=add_accessor(doc,buf,uv,'VEC2',5126,34962)
  ix=np.arange(len(pos),dtype='<u2' if len(pos)<65536 else '<u4')
  ii=add_accessor(doc,buf,ix,'SCALAR',5123 if len(pos)<65536 else 5125,34963)
  prims.append({'attributes':{'POSITION':ai,'NORMAL':ni,'TEXCOORD_0':ui},'indices':ii,'material':mats[name],'mode':4})
  counts[name]=len(faces)
 mesh_id=len(doc['meshes']);doc['meshes'].append({'name':'R15 exterior platform and silo stair details','primitives':prims})
 ni=len(doc['nodes']);doc['nodes'].append({'name':'R15 exterior former ladder platform','mesh':mesh_id});doc['scenes'][doc.get('scene',0)]['nodes'].append(ni)
 return counts


def main(src,dst,fpc,report):
 raw=Path(src).read_bytes();source_sha=sha(raw)
 if source_sha!=ROOT_SHA:raise ValueError(f'Expected validated R14 GLB (SHA {ROOT_SHA}), got {source_sha}')
 jlen=struct.unpack_from('<I',raw,12)[0]
 doc=json.loads(raw[20:20+jlen]);buf=bytearray(raw[28+jlen:]);
 roof_mat=next(i for i,mat in enumerate(doc['materials']) if mat.get('name')=='R12 roof')
 removed=0
 m=Mesh();add_exterior_platform(m);add_pipe_and_roof_traces(m);add_silo_stair_rail_refinements(m)
 counts=append_geometry(doc,buf,m,roof_mat)
 from refine_ruedersdorf_r13 import compact
 buf=compact(doc,buf)
 doc['asset']['extras']['modifications']+=' R15: external former ladder platform, open guard frame, diagonal braces and rooftop pipe, plus stair safety rails; no roof hatch, missing ladder not reconstructed; source owner 2023 FPV stills; approximate placement; original photographs not embedded; CC BY-NC 4.0.'
 j=json.dumps(doc,separators=(',',':'),ensure_ascii=False).encode();j+=b' '*(-len(j)%4)
 chunks=struct.pack('<I4s',len(j),b'JSON')+j+struct.pack('<I4s',len(buf),b'BIN\0')+buf
 Path(dst).write_bytes(struct.pack('<4sII',b'glTF',2,len(chunks)+12)+chunks)
 v,t=read_glb(dst)
 _,ids=np.unique(np.sort(t,axis=1),axis=0,return_index=True)
 result=build(v,t[np.sort(ids)],fpc)
 fp=Path(fpc).read_bytes();nv,nt,nn=struct.unpack_from('<III',fp,4)
 fv=np.frombuffer(fp,dtype='<f4',count=nv*3,offset=16).reshape(-1,3)
 ft=np.frombuffer(fp,dtype='<u4',count=nt*3,offset=16+nv*12).reshape(-1,3)
 assert np.array_equal(v,fv)
 assert np.array_equal(np.unique(np.sort(ft,axis=1),axis=0),np.unique(np.sort(t,axis=1),axis=0))
 r={'source_sha256':source_sha,'output_glb_sha256':sha(Path(dst).read_bytes()),'output_fpc_sha256':sha(fp),'source_visual_triangles':939546,'visual_triangles':len(t),'collision_triangles':len(ft),'collision_bvh_nodes':nn,'roof_faces_removed':0,'r15_added_faces_by_material':counts,'geometry_parity':True,'exterior_platform':list(EXTERIOR_PLATFORM),'roof_opening_created':False,'missing_ladder_reconstructed':False,'roof_top_z_local':Z_TOP,'roof_under_z_local':Z_UNDER,'screenshot_year':2023,'metric_camera_registration':False,'other_model_georeferencing_unchanged':True}
 Path(report).write_text(json.dumps(r,indent=2,ensure_ascii=False))
 print(json.dumps(r,indent=2,ensure_ascii=False))
 return r


if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('src');p.add_argument('dst');p.add_argument('fpc');p.add_argument('report');a=p.parse_args();main(a.src,a.dst,a.fpc,a.report)
