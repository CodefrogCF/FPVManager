#!/usr/bin/env python3
"""R8: trim low, steep scan cutoff skirts; certify multiple existing ground areas.
This deliberately never creates speculative floors under unobserved terrain.
Requires numpy, shapely>=2, existing build_collision.py. R7 input only.
"""
import argparse, hashlib, json, struct
from pathlib import Path
import numpy as np
from shapely import box, polygons, union_all, prepare, covers
from build_collision import AXIS, read_glb, build

S=16.023268178233355
Z=(-2.5,-1.75)
LEGACY=(-2.5,-.43,-1.8,.43)
LEGACY_Z=(-2.16,-1.91)
# Coverage proof permits overlapping mask rectangles and a 0.025 local-unit guard.
MARGIN=.025
PAD=.065
STEP=.2
CUT_BAND_X=8.45
CUT_BAND_Y=8.05


def sha(path):return hashlib.sha256(Path(path).read_bytes()).hexdigest()

def trim(src,dst):
    raw=Path(src).read_bytes(); length=struct.unpack_from('<I',raw,12)[0]
    doc=json.loads(raw[20:20+length]);buf=bytearray(raw[28+length:]);
    if 'R7:' not in doc['asset']['extras']['modifications']:raise ValueError('Use the R7 source GLB')
    assert len(doc['meshes'])==16 and len(doc['nodes'])==18
    matrix=AXIS@np.array(doc['nodes'][0]['matrix']).reshape(4,4,order='F')[:3,:3]
    def get(i):
        a=doc['accessors'][i];b=doc['bufferViews'][a['bufferView']];dtype=np.dtype({5123:'<u2',5125:'<u4',5126:'<f4'}[a['componentType']]);w={'SCALAR':1,'VEC3':3,'VEC2':2}[a['type']]
        return np.ndarray((a['count'],w),dtype=dtype,buffer=buf,offset=b.get('byteOffset',0)+a.get('byteOffset',0),strides=(b.get('byteStride',w*dtype.itemsize),dtype.itemsize)).copy()
    removed=[];stats=[]
    for i,mesh in enumerate(doc['meshes'][:15]):
        for p in mesh['primitives']:
            pos=(get(p['attributes']['POSITION'])@matrix.T).astype('f4');t=get(p['indices']).reshape(-1,3);xyz=pos[t];n=np.cross(xyz[:,1]-xyz[:,0],xyz[:,2]-xyz[:,0]);mag=np.linalg.norm(n,axis=1)
            # Very narrow outer cutoff strips only (2.4–2.5 m). No roof, building, frame or interior changes.
            side=((np.abs(xyz[:,:,0]).min(1)>CUT_BAND_X)&(np.ptp(xyz[:,:,0],axis=1)<.03))|((np.abs(xyz[:,:,1]).min(1)>CUT_BAND_Y)&(np.ptp(xyz[:,:,1],axis=1)<.03))
            mask=side&(xyz[:,:,2].max(1)<-2.15)&(np.abs(n[:,2])<.4*mag)
            if not mask.any():continue
            removed.append(xyz[mask]);stats.append({'scan_mesh':i,'removed_faces':int(mask.sum())})
            new=t[~mask].ravel();a=doc['accessors'][p['indices']].copy();old=doc['bufferViews'][a['bufferView']];buf.extend(b'\0'*(-len(buf)%4));a['bufferView']=len(doc['bufferViews']);a['count']=len(new);a.pop('byteOffset',None);a.pop('min',None);a.pop('max',None)
            doc['bufferViews'].append({'buffer':0,'byteOffset':len(buf),'byteLength':new.nbytes,'target':34963});buf.extend(new.tobytes());p['indices']=len(doc['accessors']);doc['accessors'].append(a)
    # Remove unreachable index buffers; positions and UVs unchanged (including protected reconstructed primitives).
    usedacc=sorted({a for mesh in doc['meshes'] for p in mesh['primitives'] for a in [*p['attributes'].values(),p['indices']]});amap={k:i for i,k in enumerate(usedacc)};doc['accessors']=[doc['accessors'][i] for i in usedacc]
    for mesh in doc['meshes']:
        for p in mesh['primitives']:p['attributes']={k:amap[v] for k,v in p['attributes'].items()};p['indices']=amap[p['indices']]
    usedviews=sorted({x['bufferView'] for x in doc['accessors']+doc['images']});vmap={k:i for i,k in enumerate(usedviews)};newbuf=bytearray();newviews=[]
    for k in usedviews:
        b=doc['bufferViews'][k].copy();off=b.get('byteOffset',0);newbuf.extend(b'\0'*(-len(newbuf)%4));b['byteOffset']=len(newbuf);newbuf.extend(buf[off:off+b['byteLength']]);newviews.append(b)
    for x in doc['accessors']+doc['images']:x['bufferView']=vmap[x['bufferView']]
    doc['bufferViews']=newviews;doc['buffers'][0]['byteLength']=len(newbuf);newbuf.extend(b'\0'*(-len(newbuf)%4));doc['asset']['extras']['modifications']+=' R8: bounded outer low/steep cutoff trim; no surveyed terrain or invented ground. CC BY-NC 4.0.'
    js=json.dumps(doc,separators=(',',':'),ensure_ascii=False).encode();js+=b' '*(-len(js)%4);chunks=struct.pack('<I4s',len(js),b'JSON')+js+struct.pack('<I4s',len(newbuf),b'BIN\0')+newbuf
    Path(dst).write_bytes(struct.pack('<4sII',b'glTF',2,len(chunks)+12)+chunks)
    r=np.concatenate(removed) if removed else np.empty((0,3,3));return r,stats


def ground_coverage(v,t,zrange=Z):
    p=v[t];z=p[:,:,2];n=np.cross(p[:,1]-p[:,0],p[:,2]-p[:,0]);mag=np.linalg.norm(n,axis=1)
    good=(z.min(1)>zrange[0])&(z.max(1)<zrange[1])&(np.abs(n[:,2])>.65*mag)&(mag>1e-12)
    # Precision grid solely suppresses numerical seams (< 0.2 micrometres at world scale).
    g=union_all(polygons(p[good,:,:2]),grid_size=1e-8).buffer(1e-7)
    return g,int(good.sum())


def find_rects(g,limit=15):
    prepare(g);xs=np.arange(-8.,8.01,STEP).round(4);ys=np.arange(-7.8,7.81,STEP).round(4);a,b=np.meshgrid(xs[:-1],ys[:-1]);mask=covers(g,box(a-PAD,b-PAD,a+STEP+PAD,b+STEP+PAD));rects=[]
    for k in range(limit):
        best=(0,None)
        for y in range(mask.shape[0]):
            row=np.ones(mask.shape[1],bool)
            for yy in range(y,mask.shape[0]):
                row &= mask[yy];starts=np.flatnonzero(np.diff(np.r_[False,row,False].astype('i1'))==1);ends=np.flatnonzero(np.diff(np.r_[False,row,False].astype('i1'))==-1)
                if len(starts):
                    i=np.argmax(ends-starts);area=(yy-y+1)*(ends[i]-starts[i]);
                    if area>best[0]:best=(area,(y,yy+1,starts[i],ends[i]))
        if best[0]<9:break
        y,yy,x,xx=best[1];mask[y:yy,x:xx]=False
        r=[float(xs[x]-.04),float(ys[y]-.04),float(xs[xx]+.04),float(ys[yy]+.04)]
        if not g.covers(box(*r).buffer(MARGIN)):raise ValueError('Ground coverage incomplete')
        rects.append(r)
    return rects


def certify(v,t,rects,hash_):
    out=[];p=v[t];z=p[:,:,2];n=np.cross(p[:,1]-p[:,0],p[:,2]-p[:,0]);mag=np.linalg.norm(n,axis=1)
    mins=p.min(1);maxs=p.max(1)
    for i,r in enumerate(rects):
        x0,y0,x1,y1=r;zr=LEGACY_Z if i==0 else Z
        good=(z.min(1)>zr[0])&(z.max(1)<zr[1])&(mins[:,0]<x1+MARGIN)&(maxs[:,0]>x0-MARGIN)&(mins[:,1]<y1+MARGIN)&(maxs[:,1]>y0-MARGIN)
        if i!=0:good&=(np.abs(n[:,2])>.65*mag)&(mag>1e-12)
        g=union_all(polygons(p[good,:,:2]),grid_size=1e-8).buffer(1e-7)
        if not g.covers(box(*r).buffer(MARGIN)):raise ValueError(f'Ground coverage incomplete: {r}; uncovered {box(*r).buffer(MARGIN).difference(g).area}')
        out.append(dict(localBounds=list(r),localGroundRange=list(zr),coverageMarginLocal=MARGIN,coverageAreaM2=box(*r).area*S*S,groundTrianglesConsidered=int(good.sum()),collisionSha256=hash_,seamToleranceM=.5))
        print('certified region',i,flush=True)
    return out

def main(src,dst,fpc,report,regions=None):
    removed,stats=trim(src,dst);v,t=read_glb(dst);_,keep=np.unique(np.sort(t,axis=1),axis=0,return_index=True);tc=t[np.sort(keep)];result=build(v,tc,fpc)
    raw=Path(fpc).read_bytes();_,nv,nt,nn=struct.unpack_from('<4sIII',raw);fv=np.frombuffer(raw,dtype='<f4',count=nv*3,offset=16).reshape(-1,3);ft=np.frombuffer(raw,dtype='<u4',count=nt*3,offset=16+nv*12).reshape(-1,3);assert np.array_equal(fv,v);assert np.array_equal(np.unique(np.sort(ft,axis=1),axis=0),np.unique(np.sort(t,axis=1),axis=0))
    if regions:rects=json.loads(Path(regions).read_text())
    else:
        g,_=ground_coverage(v,t);rects=[list(LEGACY)]+find_rects(g)
    assert rects[0]==list(LEGACY) and len(rects)<=16
    certs=certify(v,t,rects,sha(fpc))
    # Check bounding box of retained/reconstructed mesh and all triangles in the building areas.
    oldv,oldt=read_glb(src);assert len(oldt)-len(t)==len(removed)
    report_obj=dict(source_sha256=sha(src),visual_sha256=sha(dst),collision_sha256=sha(fpc),visual_triangles=len(t),collision=result,removed_scan_faces=len(removed),removed_by_mesh=stats,removed_local_bounds=[removed.min((0,1)).tolist(),removed.max((0,1)).tolist()] if len(removed) else [],terrain_certificates=certs,certified_union_m2=union_all([box(*r) for r in rects]).area*S*S,unique_triangle_parity=True,model_bounds_before=[oldv[oldt].min((0,1)).tolist(),oldv[oldt].max((0,1)).tolist()],model_bounds_after=[v[t].min((0,1)).tolist(),v[t].max((0,1)).tolist()])
    Path(report).write_text(json.dumps(report_obj,indent=2));print(json.dumps(report_obj,indent=2))

if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('src');p.add_argument('dst');p.add_argument('fpc');p.add_argument('report');p.add_argument('--regions',help='Optional preselected local rectangles (still re-certified)');a=p.parse_args();main(a.src,a.dst,a.fpc,a.report,a.regions)
