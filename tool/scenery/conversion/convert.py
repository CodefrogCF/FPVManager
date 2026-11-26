#!/usr/bin/env python3
"""Offline geodata -> FPVManager scenery v1. Inputs are trusted local developer files."""
import argparse
import hashlib
import io
import json
import math
import os
from pathlib import Path
import re
import struct
import sys
import tempfile
import zipfile
from urllib.parse import urlsplit

import numpy as np
from pyproj import CRS, Transformer, network
from pyproj.transformer import TransformerGroup
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from build_collision import build as build_fpc

network.set_network_enabled(False)
MIB = 1024**2
MAX = 64*MIB
ELEMENTS = 2_000_000


def require(ok, message):
    if not ok:
        raise ValueError(message)


def json_bytes(value):
    # Dart jsonEncode emits shortest round-trip doubles, fixed notation for
    # exponents >= -6 and < 21. Only ASCII keys/strings in generated GLB.
    def encode(v):
        if isinstance(v, float):
            require(math.isfinite(v), 'Nonfinite JSON number')
            s = repr(v)
            if 'e' in s:
                a, e = s.split('e'); e = int(e)
                if -6 <= e < 21:
                    from decimal import Decimal
                    s = format(Decimal(s), 'f')
                    if '.' not in s:
                        s += '.0'
                else:
                    s = a + 'e' + ('+' if e >= 0 else '-') + str(abs(e))
            return s
        if isinstance(v, dict):
            return '{' + ','.join(encode(k)+':'+encode(x) for k,x in v.items()) + '}'
        if isinstance(v, (tuple,list)):
            return '[' + ','.join(map(encode,v)) + ']'
        return json.dumps(v, ensure_ascii=False, allow_nan=False, separators=(',',':'))
    return encode(value).encode('utf-8')


class Frame:
    def __init__(self, anchor):
        self.anchor = np.asarray(anchor, dtype=float)
        require(self.anchor.shape == (3,) and np.isfinite(self.anchor).all() and abs(self.anchor[0])<=180 and abs(self.anchor[1])<90 and -10000<=self.anchor[2]<=20000, 'Anchor must be lon, lat, WGS84 ellipsoid metres')
        self.to_ecef = Transformer.from_crs(4979,4978,always_xy=True)
        self.to_geo = Transformer.from_crs(4978,4979,always_xy=True)
        self.transformers = {}
        self.origin = np.array(self.to_ecef.transform(*self.anchor))
        lon = math.radians(self.anchor[0]); s,c = math.sin(lon),math.cos(lon)
        # Match the application/Cesium geodetic normal at the actual ECEF anchor.
        up = self.origin / np.array([1,1,1-6.6943799901413165e-3]); up /= np.linalg.norm(up)
        east = np.array([-s,c,0]); north = np.cross(up,east)
        self.axes = np.array([east,north,up])

    def from_geo(self, xyz):
        ecef = np.array(self.to_ecef.transform(*np.asarray(xyz).T, errcheck=True)).T
        return (ecef-self.origin) @ self.axes.T

    def to_geographic(self, enu):
        return np.array(self.to_geo.transform(*(np.asarray(enu)@self.axes+self.origin).T,errcheck=True)).T

    def transformer(self, crs, target):
        key=(crs.srs,target)
        if key not in self.transformers:
            group=TransformerGroup(crs,CRS.from_epsg(target),always_xy=True,allow_ballpark=False)
            require(group.best_available and group.transformers, 'Required datum transformation/grid unavailable; install it locally, never assume zero geoid correction')
            self.transformers[key]=group.transformers[0]
        return self.transformers[key]

    def convert(self, xyz, spec):
        xyz = np.asarray(xyz, dtype=float)
        require(xyz.ndim==2 and xyz.shape[1]==3 and np.isfinite(xyz).all(), 'Invalid source XYZ')
        if spec.get('crs') == 'LOCAL_ENU':
            require(spec.get('vertical')=='local', 'Local ENU requires vertical=local')
            if 'controls' in spec:
                return align(xyz, spec['controls'], self)
            require(spec.get('alreadyAligned') is True,'Local mesh requires controls or explicit alreadyAligned')
            return xyz
        crs = CRS.from_user_input(spec['crs'])
        vertical = spec['vertical']
        if vertical == 'ellipsoidal':
            require(not crs.is_compound and not crs.is_geocentric and (crs.is_geographic or crs.is_projected), 'Use a horizontal geographic/projected CRS with ellipsoidal heights')
            horizontal = crs.to_2d()
            lon,lat = self.transformer(horizontal,4326).transform(xyz[:,0],xyz[:,1],errcheck=True)
            # Explicitly WGS84 ellipsoid, not the source ellipsoid.
            geo = np.column_stack([lon,lat,xyz[:,2]])
        elif vertical == 'compound':
            require(crs.is_compound or (crs.is_geographic and len(crs.axis_info)==3), 'Compound or 3D geographic CRS required')
            geo=np.array(self.transformer(crs,4979).transform(*xyz.T,errcheck=True)).T
        else:
            raise ValueError('Explicit vertical=ellipsoidal (WGS84 heights), compound or local required')
        return self.from_geo(geo)


def align(vertices, controls, frame):
    a=np.asarray([x['local'] for x in controls],float)
    b=frame.from_geo([x['wgs84'] for x in controls])
    require(len(a)>=3 and a.shape==b.shape and np.isfinite(a).all() and np.isfinite(b).all(), 'At least 3 finite control points required')
    ac=a-a.mean(0); bc=b-b.mean(0)
    require(np.linalg.matrix_rank(ac)>=2 and np.linalg.matrix_rank(bc)>=2,'Collinear control points')
    u,s,vt=np.linalg.svd(ac.T@bc); sign=np.ones(3); sign[-1]=np.linalg.det(u@vt)
    r=u@np.diag(sign)@vt; scale=(s@sign)/(ac**2).sum()
    require(.01<=scale<=1000,'Control scale out of range')
    t=b.mean(0)-a.mean(0)@r*scale
    rms=float(np.sqrt(np.mean(np.sum((a@r*scale+t-b)**2,axis=1))))
    require(rms<=0.5, f'Control point RMS {rms:.3f} m exceeds 0.5 m')
    print(f'Control point RMS: {rms:.4f} m, scale: {scale:.8f}',file=sys.stderr)
    return vertices@r*scale+t


class Mesh:
    def __init__(self, v, f, uv=None, image=None):
        # Binary millimetre lattice avoids sub-mm numerical noise and guarantees
        # ordinary decimal GLB accessor bounds compatible with Dart canonical JSON.
        v=(np.rint(np.asarray(v,dtype=float)*1024)/1024).astype('<f4'); v[v==0]=0; f=np.asarray(f,dtype=np.int64)
        require(v.ndim==2 and v.shape[1]==3 and 0<len(v)<=ELEMENTS and np.isfinite(v).all() and np.abs(v).max()<=100000,'Invalid/local vertex limit exceeded')
        require(f.ndim==2 and f.shape[1]==3 and 0<len(f)<=ELEMENTS and f.min()>=0 and f.max()<len(v),'Invalid triangle indices')
        cross=np.cross(v[f[:,1]].astype(float)-v[f[:,0]],v[f[:,2]].astype(float)-v[f[:,0]])
        f=f[np.sum(cross**2,axis=1)>=1e-20]
        require(len(f)>0,'No nondegenerate triangles')
        used, inverse=np.unique(f,return_inverse=True)
        self.v=v[used]; self.f=inverse.reshape(-1,3).astype('<u4')
        self.uv=None if uv is None else np.asarray(uv,dtype='<f4')[used]
        # Weld only identical vertex attributes, retaining texture seams. No
        # triangle removal or hole filling beyond degenerate faces.
        if self.uv is None:
            self.v, remap = np.unique(self.v,axis=0,return_inverse=True)
        else:
            packed, remap = np.unique(np.column_stack([self.v,self.uv]),axis=0,return_inverse=True)
            self.v, self.uv = packed[:,:3].copy(), packed[:,3:].copy()
        self.f = remap.reshape(-1)[self.f].astype('<u4')
        self.image=image
        if image is not None:
            require(self.uv is not None and self.uv.shape==(len(self.v),2) and np.isfinite(self.uv).all(),'Texture requires finite UVs')


def merge(meshes):
    v=[]; f=[]; n=0
    for m in meshes:
        v.append(m.v); f.append(m.f+n); n+=len(m.v)
    return Mesh(np.concatenate(v),np.concatenate(f))


def citygml(path, spec, frame):
    from lxml import etree
    import shapely
    from shapely.geometry import Polygon
    root=etree.parse(str(path),etree.XMLParser(resolve_entities=False,no_network=True,load_dtd=False))
    require(not root.docinfo.doctype,'DTD not supported')
    ns={'g':'http://www.opengis.net/gml'}
    # CityGML 1/2: explicit LoD2 surface/solid polygons. Local XLinks are
    # resolved by gml:id, never followed over the network. Reject unsupported
    # surface encodings instead of silently returning a partial building.
    lods=root.xpath('//*[starts-with(local-name(),"lod2")]')
    require(lods,'No LoD2 geometry')
    polygons=[]; ids={}
    for e in root.xpath('//*[@g:id]',namespaces=ns):
        ident=e.get('{http://www.opengis.net/gml}id')
        require(ident not in ids,'Duplicate GML identifier'); ids[ident]=e
    def walk(e, ancestors):
        require(len(ancestors)<=64 and e not in ancestors,'Cyclic or deep LoD2 XLink')
        q=etree.QName(e)
        if q.namespace==ns['g']:
            if q.localname=='Polygon': polygons.append(e); return
            require(q.localname not in {'Triangle','Rectangle','PolygonPatch','TriangulatedSurface','Tin','Surface','OrientableSurface'},'Unsupported LoD2 surface representation; preprocess to polygons')
        href=e.get('{http://www.w3.org/1999/xlink}href')
        if href is not None:
            require(href.startswith('#') and href[1:] in ids,'Unresolved or external LoD2 XLink')
            walk(ids[href[1:]],ancestors|{e})
        for child in e:
            if isinstance(child.tag,str): walk(child,ancestors|{e})
    for lod in lods: walk(lod,set())
    polys=polygons
    require(polys,'No supported LoD2 polygons')
    for e in root.xpath('//*[@srsName]'):
        declared=CRS.from_user_input(e.get('srsName'))
        configured=CRS.from_user_input(spec['crs'])
        require(declared.to_2d().equals(configured.to_2d(),ignore_axis_order=True),'CityGML CRS mismatch')
        if declared.is_compound: require(declared.equals(configured,ignore_axis_order=True),'CityGML vertical CRS mismatch')
    meshes=[]; seen=set()
    for poly in polys:
        if poly in seen: continue
        seen.add(poly)
        rings=[]
        for ring in poly.xpath('./g:exterior/g:LinearRing|./g:interior/g:LinearRing',namespaces=ns):
            pos=ring.xpath('./g:posList|./g:pos',namespaces=ns)
            require(pos,'Only explicit 3D LinearRing pos/posList supported')
            coords=[]
            for e in pos:
                dims=[x.get('srsDimension') for x in [e,*e.iterancestors()] if x.get('srsDimension') is not None]
                require(not dims or dims[0]=='3','Only 3D GML coordinate lists supported')
                raw=[float(x) for x in (e.text or '').split()]
                require(len(raw)%3==0 and len(raw)>0 and (etree.QName(e).localname!='pos' or len(raw)==3),'Invalid GML coordinate list')
                if e.get('count') is not None: require(int(e.get('count'))==len(raw)//3,'GML count mismatch')
                coords.extend(raw)
            a=np.array(coords).reshape(-1,3)
            # GML native axis order is explicit in the recipe.
            if spec['axisOrder']=='yxz': a=a[:,[1,0,2]]
            else: require(spec['axisOrder']=='xyz','axisOrder must be xyz or yxz')
            require(len(a)>=4 and np.array_equal(a[0],a[-1]),'Unclosed GML ring')
            rings.append(frame.convert(a[:-1],spec))
        require(rings,'Missing exterior ring')
        origin=rings[0][0]; a=rings[0]-origin
        _,_,vt=np.linalg.svd(a,full_matrices=False)
        axes=vt[:2]; normal=np.cross(axes[0],axes[1])
        require(max(np.max(np.abs((r-origin)@normal)) for r in rings)<=.10,'Nonplanar LoD2 polygon (>0.10 m)')
        flat=[(r-origin)@axes.T for r in rings]; p=Polygon(flat[0],flat[1:])
        require(p.is_valid and p.area>1e-10,'Invalid polygon or hole')
        # Constrained triangulation retains interior rings and concavities.
        ts=shapely.constrained_delaunay_triangles(p)
        v=np.concatenate([np.asarray(t.exterior.coords)[:3]@axes+origin for t in ts.geoms])
        f=np.arange(len(v)).reshape(-1,3)
        desired=np.cross(rings[0],np.roll(rings[0],-1,axis=0)).sum(0)
        flip=(np.cross(v[f[:,1]]-v[f[:,0]],v[f[:,2]]-v[f[:,0]])@desired)<0
        f[flip]=f[flip][:,[0,2,1]]
        meshes.append(Mesh(v,f))
    return [merge(meshes)]


def dem(path,spec,frame,base):
    import rasterio
    from rasterio.warp import transform
    with rasterio.open(path) as ds:
        require(ds.crs and CRS.from_user_input(ds.crs).to_2d().equals(CRS.from_user_input(spec['crs']).to_2d(),ignore_axis_order=True),'DEM CRS mismatch')
        if CRS.from_user_input(ds.crs).is_compound: require(CRS.from_user_input(ds.crs).equals(CRS.from_user_input(spec['crs']),ignore_axis_order=True),'DEM vertical CRS mismatch')
        stride=spec.get('stride',1); require(type(stride) is int and stride>=1,'Invalid DEM stride')
        require(ds.width*ds.height<=4_000_000,'Crop DEM to <=4 million pixels first')
        full=ds.read(1,masked=True); rr=np.unique(np.r_[np.arange(0,ds.height,stride),ds.height-1]); cc=np.unique(np.r_[np.arange(0,ds.width,stride),ds.width-1]); z=full[np.ix_(rr,cc)]; rows,cols=np.meshgrid(rr+.5,cc+.5,indexing='ij')
        x=ds.transform.a*cols+ds.transform.b*rows+ds.transform.c; y=ds.transform.d*cols+ds.transform.e*rows+ds.transform.f
        good=~np.ma.getmaskarray(z)&np.isfinite(z.data); require(good.sum()>=3,'Missing DEM samples')
        h,w=z.shape; ids=np.arange(h*w).reshape(h,w); a=ids[:-1,:-1]; b=ids[:-1,1:]; c=ids[1:,:-1]; d=ids[1:,1:]
        # Grid cells containing missing samples are never bridged.
        cell=good[:-1,:-1]&good[:-1,1:]&good[1:,:-1]&good[1:,1:]
        if stride>1:
            missing=(np.ma.getmaskarray(full)|~np.isfinite(full.data)).astype(np.int64)
            integral=np.pad(missing,((1,0),(1,0))).cumsum(0).cumsum(1)
            r0,r1=rr[:-1,None],rr[1:,None]+1; c0,c1=cc[None,:-1],cc[None,1:]+1
            cell &= (integral[r1,c1]-integral[r0,c1]-integral[r1,c0]+integral[r0,c0])==0
        f=np.concatenate([np.stack([a,c,b],-1)[cell],np.stack([b,c,d],-1)[cell]])
        v=np.zeros((h*w,3)); v[good.ravel()]=frame.convert(np.column_stack([x[good],y[good],z.data[good]]),spec)
        if ds.transform.a*ds.transform.e-ds.transform.b*ds.transform.d>0: f=f[:,[0,2,1]]
        uv=None; image=None
        if spec.get('orthophoto'):
            with rasterio.open(base/spec['orthophoto']) as ortho:
                require(ortho.crs and 0<ortho.width<=4096 and 0<ortho.height<=4096 and ortho.count in (3,4),'Use cropped RGB(A) orthophoto <=4096 px')
                require(all(t=='uint8' for t in ortho.dtypes),'Orthophoto must be uint8')
                xx,yy=transform(CRS.from_user_input(ds.crs).to_2d().to_wkt(),CRS.from_user_input(ortho.crs).to_2d().to_wkt(),x[good].tolist(),y[good].tolist()); inv=~ortho.transform
                col,row=inv*(np.array(xx),np.array(yy)); require(np.all((col>=0)&(col<=ortho.width)&(row>=0)&(row<=ortho.height)),'Orthophoto does not cover DEM')
                uv=np.zeros((h*w,2)); uv[good.ravel()]=np.column_stack([col/ortho.width,row/ortho.height]); image=Image.fromarray(ortho.read([1,2,3]).transpose(1,2,0))
                size=spec.get('textureMaxSize',4096); require(type(size) is int and 1<=size<=4096,'Invalid texture size'); image.thumbnail((size,size),Image.Resampling.LANCZOS)
        return [Mesh(v,f,uv,image)]


def cloud(path,spec,frame):
    import laspy
    from scipy.spatial import Delaunay
    with laspy.open(path) as src:
        require(src.header.point_count<=500_000,'Crop point cloud to <=500k points first')
        declared=src.header.parse_crs(); require(declared is not None and CRS.from_user_input(declared).to_2d().equals(CRS.from_user_input(spec['crs']).to_2d(),ignore_axis_order=True),'LAS CRS mismatch')
        if CRS.from_user_input(declared).is_compound: require(CRS.from_user_input(declared).equals(CRS.from_user_input(spec['crs']),ignore_axis_order=True),'LAS vertical CRS mismatch')
        p=src.read()
    # Ground-only 2.5D surface; never reconstruct buildings/interiors from XY TIN.
    require(spec.get('groundOnly') is True,'LAS/LAZ adapter supports classified ground only')
    mask=np.asarray(p.classification)==2; xyz=np.column_stack([p.x[mask],p.y[mask],p.z[mask]])
    require(len(xyz)>=3,'No classified ground points')
    v=frame.convert(xyz,spec); _,ix=np.unique(v[:,:2],axis=0,return_index=True); v=v[ix]
    require(len(v)>=3 and np.linalg.matrix_rank(v[:,:2]-v[:,:2].mean(0))>=2,'Insufficient noncollinear ground points')
    f=Delaunay(v[:,:2]).simplices; max_edge=float(spec['maxEdgeM']); require(0<max_edge<=100,'Invalid point cloud maxEdgeM')
    edge=np.max([np.linalg.norm(v[f[:,i]]-v[f[:,(i+1)%3]],axis=1) for i in range(3)],axis=0)
    return [Mesh(v,f[edge<=max_edge])]


def external(path,spec,frame):
    import trimesh
    require(path.suffix.lower() in {'.obj','.ply','.stl','.glb','.gltf'},'Unsupported mesh type')
    scene=trimesh.load_scene(path,process=False,allow_remote=False)
    meshes=[]
    for node in sorted(scene.graph.nodes_geometry):
        mat, key=scene.graph[node]; m=scene.geometry[key]
        require(isinstance(m,trimesh.Trimesh),'Only triangle meshes supported')
        v=trimesh.transform_points(m.vertices,mat)
        axes=spec.get('axisConvention','enu')
        if axes=='cesium_gltf': v=v[:,[2,0,1]]
        elif axes=='y_up_east': v=v[:,[0,2,1]]*np.array([1,-1,1])
        else: require(axes=='enu','Unknown mesh axisConvention')
        f=np.asarray(m.faces).copy()
        if np.linalg.det(mat[:3,:3])<0: f=f[:,[0,2,1]]
        uv=None; image=None
        if isinstance(m.visual,trimesh.visual.texture.TextureVisuals):
            material=m.visual.material
            image=getattr(material,'image',None)
            if image is None: image=getattr(material,'baseColorTexture',None)
            require(image is not None and m.visual.uv is not None,'Unsupported textured material')
            require(not any(getattr(material,key,None) is not None for key in ('normalTexture','metallicRoughnessTexture','occlusionTexture','emissiveTexture')) or spec.get('allowBaseColorOnly') is True,'Extra material maps would be discarded; explicitly allowBaseColorOnly')
            require(image.width<=4096 and image.height<=4096,'Texture exceeds 4096 px')
            uv=np.asarray(m.visual.uv).copy(); uv[:,1]=1-uv[:,1]
            size=spec.get('textureMaxSize',4096); require(type(size) is int and 1<=size<=4096,'Invalid texture size'); image=image.copy(); image.thumbnail((size,size),Image.Resampling.LANCZOS)
        elif m.visual.kind is not None:
            require(spec.get('allowUntextured') is True,'Vertex/face colors not preserved: opt in to untextured conversion')
        return_mesh=Mesh(frame.convert(v,spec),f,uv,image)
        meshes.append(return_mesh)
    require(meshes,'No external triangle meshes')
    return meshes


def load(spec,frame,base):
    path=base/spec['path']; require(path.is_file() and path.stat().st_size<=512*MIB,'Source missing or exceeds 512 MiB')
    kind=spec['type']
    if kind=='citygml': return citygml(path,spec,frame)
    if kind=='dem': return dem(path,spec,frame,base)
    if kind=='las': return cloud(path,spec,frame)
    if kind=='mesh': return external(path,spec,frame)
    raise ValueError('Unknown source adapter')


def glb(meshes):
    doc={'asset':{'version':'2.0','generator':'FPVManager scenery converter v1'},'buffers':[], 'bufferViews':[], 'accessors':[], 'meshes':[{'primitives':[]}], 'nodes':[{'mesh':0}], 'scenes':[{'nodes':[0]}], 'scene':0, 'materials':[], 'extensionsUsed':['KHR_materials_unlit']}
    binary=bytearray(); texbytes=0
    def view(b):
        binary.extend(b'\0'*(-len(binary)%4)); offset=len(binary); binary.extend(b)
        doc['bufferViews'].append({'buffer':0,'byteOffset':offset,'byteLength':len(b)}); return len(doc['bufferViews'])-1
    def acc(a,kind,component,position=False):
        require(0<len(a)<=ELEMENTS,'GLB accessor exceeds 2 million elements; split the source')
        o={'bufferView':view(a.tobytes()),'componentType':component,'count':len(a),'type':kind}
        if position: o.update(min=a.min(0).astype(float).tolist(),max=a.max(0).astype(float).tolist())
        doc['accessors'].append(o); return len(doc['accessors'])-1
    for m in meshes:
        # Cesium default correction maps glTF (x,y,z) -> ENU (z,x,y).
        p={'attributes':{'POSITION':acc(np.ascontiguousarray(m.v[:,[1,2,0]]),'VEC3',5126,True)},'indices':acc(m.f.reshape(-1),'SCALAR',5125),'material':len(doc['materials'])}
        material={'doubleSided':True,'extensions':{'KHR_materials_unlit':{}},'pbrMetallicRoughness':{'metallicFactor':0,'roughnessFactor':1}}
        if m.image is not None:
            buf=io.BytesIO()
            if 'A' in m.image.getbands():
                im=m.image.convert('RGBA'); im.save(buf,format='PNG'); mime='image/png'; material['alphaMode']='BLEND'
            else:
                im=m.image.convert('RGB'); im.save(buf,format='JPEG',quality=88,subsampling=0); mime='image/jpeg'
            doc.setdefault('images',[]).append({'bufferView':view(buf.getvalue()),'mimeType':mime}); doc.setdefault('textures',[]).append({'source':len(doc['images'])-1})
            material['pbrMetallicRoughness']['baseColorTexture']={'index':len(doc['textures'])-1}; p['attributes']['TEXCOORD_0']=acc(m.uv,'VEC2',5126)
            texbytes+=math.ceil(im.width*im.height*16/3)
        doc['materials'].append(material); doc['meshes'][0]['primitives'].append(p)
    vertices=sum(len(m.v) for m in meshes); triangles=sum(len(m.f) for m in meshes)
    require(vertices<=ELEMENTS and triangles<=ELEMENTS and len(meshes)<=1024,'Model element limit exceeded')
    doc['buffers']=[{'byteLength':len(binary)}]; estimate=len(binary)+vertices*32+texbytes
    require(estimate<=128*MIB,'Decoded model budget exceeded')
    j=json_bytes(doc); require(len(j)<=4*MIB and len(doc['bufferViews'])<=8192 and len(doc['accessors'])<=8192,'GLB structure budget exceeded'); j+=b' '*(-len(j)%4); binary.extend(b'\0'*(-len(binary)%4))
    out=struct.pack('<4sII',b'glTF',2,28+len(j)+len(binary))+struct.pack('<I4s',len(j),b'JSON')+j+struct.pack('<I4s',len(binary),b'BIN\0')+binary
    bounds=np.r_[np.min([m.v.min(0) for m in meshes],0),np.max([m.v.max(0) for m in meshes],0)].astype(float).tolist()
    return out,dict(localBounds=bounds,vertices=vertices,triangles=triangles,textures=len(doc.get('images',[])),estimatedBytes=estimate,byteLength=len(out))


def collision(meshes):
    m=merge(meshes); v,ix=np.unique(m.v,axis=0,return_inverse=True); f=ix.reshape(-1)[m.f].astype('<u4')
    with tempfile.TemporaryDirectory() as tmp:
        p=Path(tmp)/'mesh.fpc'; info=build_fpc(v,f,p); data=p.read_bytes()
    return data,dict(localBounds=info['bounds'],vertices=info['vertices'],triangles=info['triangles'],textures=0,estimatedBytes=len(data),byteLength=len(data))


def convert(recipe, base, output):
    require(recipe.get('redistributionAllowed') is True,'Explicit redistribution permission required')
    ident=recipe['id']; require(re.fullmatch('[a-z0-9_-]{1,80}',ident),'Invalid scenery ID')
    revision=recipe.get('revision',1); require(type(revision) is int and 1<=revision<=2147483647,'Invalid revision')
    frame=Frame(recipe['anchor']); assets=[]; entries={}; lods={}; provenance=[]
    def add(id,role,fmt,specs):
        require(specs,'Empty source list')
        meshes=[]
        for s in specs:
            for k in ('author','license','attribution'):
                require(isinstance(s.get(k),str) and s[k].strip(),'Every source needs author/license/attribution')
            require(s.get('redistributionAllowed') is True,'Source redistribution not confirmed')
            if s.get('orthophoto'):
                o=s.get('orthophotoSource',{}); require(o.get('redistributionAllowed') is True and all(o.get(k) for k in ('author','license','attribution')),'Orthophoto source rights/credit required')
                provenance.append(f"Orthophoto: {o['author']}; {o['license']}; {o['attribution']}")
            provenance.append(f"{s['author']}; {s['license']}; {s['attribution']}; CRS={s['crs']}; vertical={s['vertical']}")
            meshes.extend(load(s,frame,base))
        data,meta=glb(meshes) if fmt=='glb' else collision(meshes)
        require(0<len(data)<=MAX,'Asset exceeds 64 MiB')
        key=hashlib.sha256(data).hexdigest()+'.'+fmt; entries['assets/'+key]=data
        require(sum(map(len,entries.values()))<MAX,'Assets exceed total 64 MiB package budget')
        assets.append(dict(id=id,role=role,provider='managed',format=fmt,uri=key,model=meta))
    add('visual','visual','glb',recipe['visual'])
    for level,specs in sorted(recipe.get('lods',{}).items()):
        require(level in {'low','balanced','high'},'Unknown LOD preset'); id='visual-'+level; add(id,'visual','glb',specs); lods.setdefault('visual',{})[level]=id
    for i,specs in enumerate(recipe.get('collision',[])):
        require(i<16,'Too many collision assets'); add('collision-'+str(i),'collision','fpc',specs)
    cs=[a['id'] for a in assets if a['role']=='collision']; source=recipe['source'].copy()
    source['attribution']+=' | '+' | '.join(dict.fromkeys(provenance))
    for k in ('author','license','attribution'):
        require(isinstance(source[k],str) and 0<len(source[k].strip())<=2048,'Source metadata missing or too long')
    if source.get('url'):
        url=urlsplit(source['url']); require(url.scheme=='https' and url.hostname and not (url.username or url.password or url.query or url.fragment),'Source URL must be safe HTTPS')
    name=recipe['name']; desc=recipe.get('description',''); require(0<len(name.strip())<=120 and len(desc)<=4096,'Invalid name/description')
    # Bounds are recomputed by importer; supply conservative geographic bounds.
    corners=[]
    for a in assets:
        b=a['model']['localBounds']; corners.extend([[b[x],b[1+y],b[2+z]] for x in (0,3) for y in (0,3) for z in (0,3)])
    geo=frame.to_geographic(corners); lon,lat,height=map(float,frame.anchor); unwrapped=(geo[:,0]-lon+180)%360-180+lon
    wrap=lambda x: float((x+180)%360-180)
    scenery=dict(schemaVersion=1,id=ident,name=name,description=desc,source=source,anchor=dict(longitude=lon,latitude=lat,heightM=height,reference='WGS84_ELLIPSOID'),bounds=dict(west=wrap(unwrapped.min()),south=float(geo[:,1].min()),east=wrap(unwrapped.max()),north=float(geo[:,1].max())),rotation=dict(headingDeg=0,pitchDeg=0,rollDeg=0),scale=1,assets=assets,collision=dict(enabled=bool(cs),assetIds=cs,sidedness='double'),visibility=dict(enabled=False,loadRadiusM=2500,unloadRadiusM=4000),minimumAppVersion='0.19.29')
    if lods: scenery['extensions']={'lods':lods}
    # Replacement is intentionally opt-in: exact user-reviewed local footprint, not a bounding rectangle.
    if 'replacementEnu' in recipe:
        from shapely.geometry import Polygon
        regions=[]
        for raw in recipe['replacementEnu']:
            a=np.asarray(raw,float); p=Polygon(a)
            require(a.ndim==2 and a.shape[1]==2 and 3<=len(a)<=64 and np.isfinite(a).all() and np.linalg.norm(a,axis=1).max()<=990 and p.is_valid and 1.1<=p.area<=249000 and np.linalg.norm(a-np.roll(a,1,axis=0),axis=1).min()>.11,'Invalid replacement footprint')
            regions.append(frame.to_geographic(np.column_stack([a,np.zeros(len(a))]))[:,:2].tolist())
        require(0<len(regions)<=24 and cs,'Building replacement needs explicit regions and collision geometry')
        scenery['replacement']=dict(schemaVersion=1,buildings=dict(enabled=True,regions=regions,features=[]),terrain=dict(enabled=False,regions=[]))
    require(len(json_bytes(scenery))<=128*1024,'Scenery manifest too large')
    manifest=dict(format='fpvmanager-scenery',version=1,revision=revision,metadataOnly=False,redistributionAllowed=True,scenery=scenery,files={k:dict(bytes=len(v),sha256=hashlib.sha256(v).hexdigest()) for k,v in entries.items()})
    entries={'manifest.json':json_bytes(manifest),**entries}
    require(sum(76+2*len(k)+len(v) for k,v in entries.items())+22<=MAX,'Package exceeds 64 MiB; split source or simplify')
    output=Path(output); require(output.suffix=='.fpvscenery','Output must end in .fpvscenery')
    with tempfile.NamedTemporaryFile(dir=output.parent,delete=False) as tmp: temp=Path(tmp.name)
    try:
        with zipfile.ZipFile(temp,'w',compression=zipfile.ZIP_STORED,allowZip64=False) as z:
            for k,v in entries.items():
                info=zipfile.ZipInfo(k); info.create_system=0; z.writestr(info,v)
        # Exclusive publish, no overwrite; works on Windows too.
        os.link(temp,output)
    finally: temp.unlink(missing_ok=True)
    return manifest


def main():
    p=argparse.ArgumentParser(description=__doc__); p.add_argument('recipe',type=Path); p.add_argument('output',type=Path); args=p.parse_args()
    try:
        m=convert(json.loads(args.recipe.read_text(encoding='utf-8')),args.recipe.parent,args.output)
        print(f"{args.output}: {len(m['files'])} resources")
    except (ValueError,OSError,KeyError,ImportError) as e:
        p.exit(2,f'Conversion failed: {e}\n')

if __name__=='__main__': main()
