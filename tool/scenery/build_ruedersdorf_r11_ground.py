#!/usr/bin/env python3
"""R11: form an optional survey-referenced bare-earth underlay, not a replacement of photographed floors.

Inputs are the prior R8 Scenery GLB/FPC and the datum-calibrated R10 DEM GLB. The R11
underlay is deliberately opt-in and may be displayed/used for physical replacement
only if the live terrain seam check authorizes the *same* polygon.
"""
from __future__ import annotations
import argparse, hashlib, json, struct, sys
from pathlib import Path
import numpy as np

HERE=Path(__file__).resolve().parent
sys.path.insert(0,str(HERE))
from build_collision import AXIS,read_glb,build

S=16.023268178233355

def sha(path): return hashlib.sha256(Path(path).read_bytes()).hexdigest()

def write_glb(path,v,t):
    q=(v@AXIS).astype('<f4');idx=t.astype('<u4').ravel();buf=q.tobytes()+idx.tobytes();buf+=b'\x00'*(-len(buf)%4)
    doc={'asset':{'version':'2.0','generator':'FPVManager R11 calibrated DGM1 underlay',
         'copyright':'© GeoBasis-DE/LGB, dl-de/by-2-0; GCG2016 © BKG, CC BY 4.0 (modified data)',
         'extras':{'purpose':'EXPERIMENTAL opt-in underlay; not surveyed building floors',
                   'heightReference':'ETRS89/GRS80 ellipsoidal relative to site model anchor',
                   'datum':'DGM1 DHHN2016 plus GCG2016',
                   'renderOnlyIf':'R11 FPC and live terrain seam/clipping verified',
                   'interiorVisualBiasM':0.1,'doNotUseAs':'source for building roofs or interiors'}},
         'scene':0,'scenes':[{'nodes':[0]}],'nodes':[{'mesh':0}],
         'meshes':[{'primitives':[{'attributes':{'POSITION':0},'indices':1,'material':0}]}],
         'materials':[{'name':'R11 DGM1 bare earth (experimental)','doubleSided':True,
           'pbrMetallicRoughness':{'baseColorFactor':[.32,.39,.28,1.0],'metallicFactor':0.,'roughnessFactor':1.}}],
         'buffers':[{'byteLength':len(buf)}],
         'bufferViews':[{'buffer':0,'byteOffset':0,'byteLength':q.nbytes,'target':34962},
                        {'buffer':0,'byteOffset':q.nbytes,'byteLength':idx.nbytes,'target':34963}],
         'accessors':[{'bufferView':0,'componentType':5126,'count':len(q),'type':'VEC3','min':q.min(0).tolist(),'max':q.max(0).tolist()},
                      {'bufferView':1,'componentType':5125,'count':len(idx),'type':'SCALAR','min':[int(idx.min())],'max':[int(idx.max())]}]}
    txt=json.dumps(doc,separators=(',',':'),ensure_ascii=False).encode('utf-8');txt+=b' '*(-len(txt)%4)
    body=struct.pack('<I4s',len(txt),b'JSON')+txt+struct.pack('<I4s',len(buf),b'BIN\x00')+buf
    Path(path).write_bytes(struct.pack('<4sII',b'glTF',2,len(body)+12)+body)

def build_r11(root):
    root=Path(root)
    cat=root/'web/assets/scenery/catalog.json'; catalog=json.loads(cat.read_text());item=catalog['sceneries'][0]
    r8_fpc=root/'web/assets/scenery/local_reference.fpc'
    r8_glb=root/'web/assets/scenery/local_reference.glb'
    r10=root/'tool/scenery/r10/dgm_ellipsoid_reference.glb'
    r10_cal=json.loads((root/'tool/scenery/r10/height_calibration.json').read_text())
    if sha(r8_fpc)!=r10_cal['sources']['r8_collision_sha256']:
        raise ValueError('R8 collider differs from calibrated R10 source')
    if sha(r10)!=r10_cal['reference_glb_sha256']:
        raise ValueError('R10 calibrated DGM changed')
    sv,st=read_glb(r8_glb)
    dv,dt=read_glb(r10)
    assert len(dv)==78638 and len(dt)==156156
    # R10 mesh has a regular 1-m projected grid. Drop the outermost cell on
    # each side. The GLB boundary now coincides with the polygon clip boundary.
    # The model stays entirely inside the surveyed source's coverage.
    eps=1e-5
    bounds=np.array([dv[:,:2].min(0),dv[:,:2].max(0)])
    dx=np.sort(np.unique(dv[:,0]));dy=np.sort(np.unique(dv[:,1]))
    if len(dx)!=287 or len(dy)!=274: raise ValueError('Unexpected regular reference grid')
    inside=(dv[:,0]>=dx[1]-eps)&(dv[:,0]<=dx[-2]+eps)&(dv[:,1]>=dy[1]-eps)&(dv[:,1]<=dy[-2]+eps)
    index=np.full(len(dv),-1,dtype='i4');index[inside]=np.arange(inside.sum(),dtype='i4')
    tri=dt[np.all(inside[dt],axis=1)];v=dv[inside].copy();f=index[tri].astype('<u4')
    assert len(v)==(287-2)*(274-2) and len(f)==2*(287-3)*(274-3)
    # A <=10cm continuous *visual clearance* from the original scan within
    # its XY extent reduces z-fighting on almost-coincident, photographed ground.
    # The outer surveyed collar is not biased (seam heights remain unchanged).
    lo=sv[:,:2].min(0);hi=sv[:,:2].max(0)
    distance=np.minimum.reduce([v[:,0]-lo[0],hi[0]-v[:,0],v[:,1]-lo[1],hi[1]-v[:,1]])
    fade=np.clip(distance/(4./S),0,1)
    bias=.10*fade
    v[:,2]-=(bias/S).astype('<f4')
    base=root/'web/assets/scenery';glb=base/'ruedersdorf_r11_ground.glb';fpc=base/'ruedersdorf_r11_ground.fpc'
    write_glb(glb,v,f)
    vv,tt=read_glb(glb)
    info=build(vv,tt,fpc)
    # Check every unique triangle and dataset footprint, not just vertex counts.
    av=np.unique(np.sort(tt,axis=1),axis=0);af=np.unique(np.sort(f,axis=1),axis=0)
    assert np.array_equal(vv,vv.astype('<f4')) and len(av)==len(af)
    # Inset clip/cert boundary by ~0.96 m from the actual mesh perimeter.
    # This resolves floating-point edge precision in Cesium ECEF-to-local math
    # and keeps a full cell of actual triangles under every seam sample.
    b=[float(v[:,0].min()+.06),float(v[:,1].min()+.06),float(v[:,0].max()-.06),float(v[:,1].max()-.06)]
    zr=[float(v[:,2].min()-.03),float(v[:,2].max()+.03)]
    certificate={'localBounds':b,'localGroundRange':zr,'coverageMarginLocal':0.025,
                 'collisionSha256':sha(fpc),'seamToleranceM':0.25}
    # Boundaries are exactly on a mesh gridline, certify all cell centers in the
    # defined rectangle and all boundary vertices, without claiming physical
    # identity with the live BKG DGM5 terrain at runtime.
    from scipy.spatial import cKDTree
    grid=cKDTree(v[:,:2]); unique_xy=np.unique(v[:,:2],axis=0)
    assert len(unique_xy)==len(v)
    query=np.array([[b[0],b[1]],[b[2],b[1]],[b[2],b[3]],[b[0],b[3]],[0,0]])
    d,_=grid.query(query)
    assert d.max()<1.0/S,('Ground grid not covering certificate corners',d)
    assert np.all((v[:,2]>zr[0])&(v[:,2]<zr[1]))
    assert (v[:,2].max()-v[:,2].min())*S<15
    assert 0.09<=float(bias.max())<=.101
    data={'schemaVersion':1,'experimental':True,'modelGlb':glb.name,'collisionAsset':fpc.name,
          'collisionSourceSha256':sha(r8_fpc),'scanGlbSha256':sha(r8_glb),
          'calibratedReferenceSha256':sha(r10),'terrainGroundRootEllipsoidM':r10_cal['anchor']['model_root_ellipsoid_m'],
          'terrainAnchorEllipsoidM':r10_cal['anchor']['terrain_ellipsoid_m'],
          'alignment':item['alignment'],'groundReferenceLocalUp':item['groundReferenceLocalUp'],
          'visualBiasM':0.10,'source':['DGM1 © GeoBasis-DE/LGB, dl-de/by-2-0','GCG2016 © BKG CC BY 4.0'],
          'geometry':info,'certificate':certificate,
          'coverageAreaM2':(b[2]-b[0])*(b[3]-b[1])*S*S,
          'notes':['Do not use DGM as a model of elevated building floors',
                   'The 10 cm visual underlay is a rendering clearance, not a measured ground correction',
                   'Use only with matching scene height and successful live boundary/clipping checks',
                   'The BKG 3D-Beta DGM5 live provider has not been validated against this DGM1 offline reference']}
    (root/'tool/scenery/r11').mkdir(exist_ok=True)
    (root/'tool/scenery/r11/underlay_report.json').write_text(json.dumps(data,indent=2,ensure_ascii=False)+'\n')
    return data

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('repository_root',nargs='?',default=Path(__file__).parents[2]);a=p.parse_args()
    print(json.dumps(build_r11(a.repository_root),indent=2,ensure_ascii=False))
