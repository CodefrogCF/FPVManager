#!/usr/bin/env python3
"""Build a texture-free, indexed triangle collider for a locally licensed GLB.
Requires numpy. No network, no mesh filling, no geometry simplification.
Output coordinates match Cesium Model default Y-up/Z-forward correction.
"""
import argparse
import json
import struct
from pathlib import Path
import numpy as np

MAX_TRIANGLES = 2_000_000
MAX_VERTICES = 2_000_000
# Cesium ModelUtility.getAxisCorrectionMatrix(Y,Z): Y_UP_TO_Z_UP @ Z_UP_TO_X_UP
AXIS = np.array([[0,0,1],[1,0,0],[0,1,0]], dtype=np.float64)


def read_glb(path):
    data = Path(path).read_bytes()
    if len(data) < 20 or struct.unpack_from('<4sII', data) != (b'glTF', 2, len(data)):
        raise ValueError('Invalid GLB')
    chunks = {}
    pos = 12
    while pos < len(data):
        n, key = struct.unpack_from('<I4s', data, pos)
        pos += 8
        if n % 4 or pos+n > len(data) or key in chunks:
            raise ValueError('Invalid GLB chunk')
        chunks[key] = memoryview(data)[pos:pos+n]
        pos += n
    doc = json.loads(bytes(chunks[b'JSON']))
    buf = chunks[b'BIN\0']
    if len(doc['buffers']) != 1 or 'uri' in doc['buffers'][0] or doc.get('animations') or doc.get('skins'):
        raise ValueError('Only static self-contained GLB meshes are supported')
    def accessor(i, kind):
        a = doc['accessors'][i]
        if a['type'] != kind or a.get('sparse') or a.get('normalized'):
            raise ValueError('Unsupported accessor')
        dt = {5121:'u1',5123:'<u2',5125:'<u4',5126:'<f4'}.get(a['componentType'])
        if dt is None or (kind=='VEC3') != (a['componentType']==5126):
            raise ValueError('Unsupported component type')
        dt = np.dtype(dt)
        v = doc['bufferViews'][a['bufferView']]
        if v.get('buffer',0) != 0 or v.get('extensions'):
            raise ValueError('Unsupported buffer view')
        width = 3 if kind=='VEC3' else 1
        count = a['count']; base = v.get('byteOffset',0); offset = a.get('byteOffset',0)
        stride = v.get('byteStride',dt.itemsize*width)
        if not 0 < count <= MAX_TRIANGLES*3 or stride < width*dt.itemsize or offset < 0 or base < 0 or base+v['byteLength'] > len(buf) or offset+(count-1)*stride+width*dt.itemsize > v['byteLength']:
            raise ValueError('Accessor exceeds buffer')
        return np.ndarray((count,width),dtype=dt,buffer=buf,offset=base+offset,strides=(stride,dt.itemsize))
    def matrix(node):
        if 'matrix' in node:
            m = np.array(node['matrix'],dtype=float).reshape((4,4),order='F')
        else:
            x,y,z,w = node.get('rotation',[0,0,0,1]); s = node.get('scale',[1,1,1]); t = node.get('translation',[0,0,0])
            m = np.eye(4)
            m[:3,:3] = np.array([[1-2*(y*y+z*z),2*(x*y-z*w),2*(x*z+y*w)],[2*(x*y+z*w),1-2*(x*x+z*z),2*(y*z-x*w)],[2*(x*z-y*w),2*(y*z+x*w),1-2*(x*x+y*y)]]) @ np.diag(s)
            m[:3,3] = t
        if not np.isfinite(m).all() or not np.allclose(m[3],[0,0,0,1]):
            raise ValueError('Invalid node transform')
        return m
    vertices, triangles = [], []
    total_v = total_t = 0
    def walk(i,parent,ancestors):
        nonlocal total_v,total_t
        if i in ancestors or len(ancestors)>128: raise ValueError('Invalid node tree')
        node = doc['nodes'][i]; transform = parent @ matrix(node)
        if 'mesh' in node:
            for p in doc['meshes'][node['mesh']]['primitives']:
                if p.get('mode',4)!=4 or p.get('extensions') or p.get('targets'):
                    raise ValueError('Only uncompressed static triangle primitives supported')
                v = accessor(p['attributes']['POSITION'],'VEC3')
                indices = accessor(p['indices'],'SCALAR').reshape(-1) if 'indices' in p else np.arange(len(v))
                if len(indices)%3 or indices.max(initial=0)>=len(v): raise ValueError('Invalid indices')
                v = ((v @ transform[:3,:3].T + transform[:3,3]) @ AXIS.T).astype('<f4')
                if not np.isfinite(v).all() or np.abs(v).max(initial=0)>1e5: raise ValueError('Invalid local vertices')
                triangles.append(indices.reshape(-1,3).astype('<u4')+total_v)
                vertices.append(v); total_v+=len(v); total_t+=len(indices)//3
                if total_v>MAX_VERTICES or total_t>MAX_TRIANGLES: raise ValueError('Geometry limit exceeded')
        for child in node.get('children',[]): walk(child,transform,ancestors|{i})
    for i in doc['scenes'][doc.get('scene',0)]['nodes']: walk(i,np.eye(4),set())
    if not triangles: raise ValueError('No triangles')
    v=np.concatenate(vertices); t=np.concatenate(triangles)
    # Merge only identical positions; no welding tolerance, gap filling or simplification.
    v,inv=np.unique(v,axis=0,return_inverse=True)
    return v.astype('<f4'),inv.reshape(-1)[t].astype('<u4')


def build(v,t,destination):
    # Median split over the widest centroid axis; leaf ranges index one contiguous array.
    mins=np.minimum(np.minimum(v[t[:,0]],v[t[:,1]]),v[t[:,2]])
    maxs=np.maximum(np.maximum(v[t[:,0]],v[t[:,1]]),v[t[:,2]])
    centers=(mins+maxs)*.5
    order=np.arange(len(t)); bounds=[]; children=[]
    def split(start,end):
        ids=order[start:end]; lo=mins[ids].min(axis=0); hi=maxs[ids].max(axis=0)
        node=len(bounds); bounds.append(np.r_[lo,hi]); children.append(None)
        if end-start<=16:
            children[node]=(-start-1,end-start)
        else:
            axis=int(np.argmax(np.ptp(centers[ids],axis=0))); mid=(end-start)//2
            order[start:end]=ids[np.argpartition(centers[ids,axis],mid)]
            left=split(start,start+mid); right=split(start+mid,end)
            children[node]=(left,right)
        return node
    split(0,len(t))
    with Path(destination).open('wb') as f:
        f.write(struct.pack('<4sIII',b'FPC1',len(v),len(t),len(bounds)))
        for a in [v.astype('<f4'),t[order].astype('<u4'),np.array(bounds,dtype='<f4'),np.array(children,dtype='<i4')]: f.write(a.tobytes())
    return {'vertices':len(v),'triangles':len(t),'nodes':len(bounds),'bounds':bounds[0].tolist(),'bytes':Path(destination).stat().st_size}


if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('glb');p.add_argument('output');a=p.parse_args()
    print(json.dumps(build(*read_glb(a.glb),a.output),indent=2))
