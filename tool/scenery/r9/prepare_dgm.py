#!/usr/bin/env python3
"""Build an independent DGM1 reference surface, NOT a production replacement.
Usage from repository root: python tool/scenery/r9/prepare_dgm.py <GeoTIFF>
Dependencies: numpy scipy rasterio pyproj matplotlib. Existing build_collision.py.
"""
import sys, json, struct, hashlib, subprocess, csv
from pathlib import Path
import numpy as np
import rasterio
from scipy.ndimage import map_coordinates
from pyproj import Transformer
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[2]
sys.path.insert(0,str(HERE.parent))
from build_collision import AXIS, read_glb, build

def sha(p): return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def glb(path,v,t):
    # Root is identity; inverse Cesium axis correction maps local ENU into glTF.
    p=(v@AXIS).astype('<f4'); idx=t.astype('<u4').ravel(); data=p.tobytes()+idx.tobytes()
    d={'asset':{'version':'2.0','generator':'FPVManager DGM1 reference R9','copyright':'GeoBasis-DE/LGB, dl-de/by-2-0, data modified','extras':{'verticalDatum':'DHHN2016 relative to raster anchor; NOT absolute ellipsoid','source':'dgm_33417-5815'}},'scene':0,'scenes':[{'nodes':[0]}],'nodes':[{'mesh':0}],'meshes':[{'primitives':[{'attributes':{'POSITION':0},'indices':1,'material':0}]}],'materials':[{'name':'DGM reference (not phototextured)','doubleSided':True,'pbrMetallicRoughness':{'baseColorFactor':[.38,.55,.33,1],'metallicFactor':0,'roughnessFactor':1}}],'buffers':[{'byteLength':len(data)}],'bufferViews':[{'buffer':0,'byteOffset':0,'byteLength':p.nbytes,'target':34962},{'buffer':0,'byteOffset':p.nbytes,'byteLength':idx.nbytes,'target':34963}],'accessors':[{'bufferView':0,'componentType':5126,'count':len(p),'type':'VEC3','min':p.min(0).tolist(),'max':p.max(0).tolist()},{'bufferView':1,'componentType':5125,'count':len(idx),'type':'SCALAR','min':[int(idx.min())],'max':[int(idx.max())]}]}
    js=json.dumps(d,separators=(',',':')).encode();js+=b' '*(-len(js)%4);data+=b'\0'*(-len(data)%4)
    chunks=struct.pack('<I4s',len(js),b'JSON')+js+struct.pack('<I4s',len(data),b'BIN\0')+data
    path.write_bytes(struct.pack('<4sII',b'glTF',2,len(chunks)+12)+chunks)

def run(tif):
    cat=ROOT/'web/assets/scenery/catalog.json'; asset=cat.parent/'local_reference.fpc'; item=json.loads(cat.read_text())['sceneries'][0]; A=item['alignment'];s=A['scale'];up=item['groundReferenceLocalUp']; angle=np.deg2rad(-A['rotationDeg']);cos,sin=np.cos(angle),np.sin(angle);rad=np.deg2rad(A['latitude']);w=np.sqrt(1-.00669437999014*np.sin(rad)**2);east=6378137/w*np.cos(rad)*np.pi/180;north=6378137*(1-.00669437999014)/w**3*np.pi/180
    if sha(asset)!=item['terrainCertificate']['collisionSha256']:raise ValueError('R8 collision hash mismatch')
    T=Transformer.from_crs(4326,25833,always_xy=True)
    def geographic(x,y):return A['longitude']+s*(cos*x-sin*y)/east,A['latitude']+s*(sin*x+cos*y)/north
    def local(lon,lat):
        e=(np.array(lon)-A['longitude'])*east/s;n=(np.array(lat)-A['latitude'])*north/s
        return cos*e+sin*n,-sin*e+cos*n
    raw=asset.read_bytes();_,nv,nt,nn=struct.unpack_from('<4sIII',raw);sv=np.frombuffer(raw,dtype='<f4',offset=16,count=nv*3).reshape(-1,3)
    with rasterio.open(tif) as ds:
        if ds.crs is None or 'DHHN2016' not in ds.crs.to_wkt() or '25833' not in ds.crs.to_wkt():raise ValueError('Unexpected CRS or vertical datum')
        if ds.width!=1000 or ds.height!=1000 or ds.res!=(1.,1.):raise ValueError('Unexpected DGM raster size')
        h=ds.read(1); invalid=(h==ds.nodata)|~np.isfinite(h)
        def sample(lon,lat):
            x,y=T.transform(lon,lat);c,r=~ds.transform*(np.asarray(x),np.asarray(y));c=np.atleast_1d(c)-.5;r=np.atleast_1d(r)-.5
            if np.any((c<0)|(c>ds.width-1)|(r<0)|(r>ds.height-1)):raise ValueError('DGM tile does not cover requested point')
            if np.any(map_coordinates(invalid.astype(float),[r,c],order=1)>0):raise ValueError('DGM nodata')
            return map_coordinates(h.astype(float),[r,c],order=1)
        anchor=float(sample(A['longitude'],A['latitude'])[0]);lo=sv[:,:2].min(0);hi=sv[:,:2].max(0); margin=5/s
        nx,ny=np.ceil((hi-lo+2*margin)*s).astype(int)+1
        xs=np.linspace(lo[0]-margin,hi[0]+margin,nx);ys=np.linspace(lo[1]-margin,hi[1]+margin,ny);X,Y=np.meshgrid(xs,ys);lon,lat=geographic(X.ravel(),Y.ravel());H=sample(lon,lat).reshape(X.shape)
        V=np.column_stack([X.ravel(),Y.ravel(),up+(H.ravel()-anchor)/s]).astype('<f4')
        q=(np.arange(ny-1)[:,None]*nx+np.arange(nx-1)).ravel();F=np.stack([np.stack([q,q+1,q+nx+1],1),np.stack([q,q+nx+1,q+nx],1)],1).reshape(-1,3).astype('<u4')
        glb(HERE/'dgm_reference.glb',V,F);v,t=read_glb(HERE/'dgm_reference.glb');geometry=build(v,t,HERE/'dgm_reference.fpc')
        assert len(t)==2*(nx-1)*(ny-1) and np.isfinite(v).all()
        groups=json.loads(subprocess.check_output(['node',str(HERE/'seam.cjs')],cwd=ROOT))
        stats=[]; rows=[]
        for i,g in enumerate(groups):
            lon=np.array([p['longitude'] for p in g]);lat=np.array([p['latitude'] for p in g]);dgm=sample(lon,lat);scan=np.array([p['scanRelM'] for p in g])+anchor;err=scan-dgm
            if not np.isfinite(err).all():raise ValueError('Invalid collision sample')
            stats.append(dict(region=i+1,samples=len(g),min_m=float(err.min()),max_m=float(err.max()),median_m=float(np.median(err)),rms_m=float(np.sqrt(np.mean(err**2))),max_abs_m=float(abs(err).max()),within_0_5m=bool(abs(err).max()<=.5)))
            rows.extend(zip([i+1]*len(g),lon,lat,dgm,scan,err))
        with (HERE/'seam_comparison.csv').open('w',newline='') as fp:
            wr=csv.writer(fp);wr.writerow(['region','lon','lat','dgm_nhn_m','scan_nhn_relative_estimate_m','scan_minus_dgm_m']);wr.writerows(rows)
        lon,lat=geographic(sv[:,0],sv[:,1]);ex,no=T.transform(lon,lat);result={'source_sha256':sha(tif),'source_crs':ds.crs.to_wkt(),'source_bounds':list(ds.bounds),'anchor_nhn_m':anchor,'alignment':A,'ground_reference_local_up':up,'mesh_utm_bounds':[float(ex.min()),float(no.min()),float(ex.max()),float(no.max())],'reference_extent_local':[float(xs[0]),float(ys[0]),float(xs[-1]),float(ys[-1])],'reference_grid':[int(nx),int(ny)],'reference_ground_range_nhn':[float(H.min()),float(H.max())],'geometry':geometry,'reference_glb_sha256':sha(HERE/'dgm_reference.glb'),'reference_fpc_sha256':sha(HERE/'dgm_reference.fpc'),'source_r8_collision_sha256':sha(asset),'seams':stats,'limits':'Relative DHHN2016 heights; no GCG2016 conversion, not an absolute/validated seam or active collider.'}
        (HERE/'report.json').write_text(json.dumps(result,indent=2));
        fig,ax=plt.subplots(figsize=(10,9));plot=ax.pcolormesh(X*s,Y*s,H,shading='auto',cmap='terrain');fig.colorbar(plot,ax=ax,label='DGM1 elevation (m NHN)');ax.scatter(sv[::40,0]*s,sv[::40,1]*s,s=.4,c='black',alpha=.15,label='R8 geometry (sampled vertices)');
        for st,c in zip(stats,item['terrainCertificates']):
            x0,y0,x1,y1=np.array(c['localBounds'])*s; col='#18d2fb' if st['within_0_5m'] else '#e63946';ax.plot([x0,x1,x1,x0,x0],[y0,y0,y1,y1,y0],c=col,lw=1.8);ax.text((x0+x1)/2,(y0+y1)/2,str(st['region']),ha='center',va='center',color='white',fontsize=8,bbox=dict(facecolor='black',alpha=.6,pad=1,edgecolor='none'))
        ax.set(title='Rüdersdorf · DGM1 and R8 ground seam comparison\nCyan: all sampled residuals ≤ 0.5 m; red: larger residuals',xlabel='Model-local x (m)',ylabel='Model-local y (m)',aspect='equal');ax.legend(loc='lower left');fig.text(.03,.02,'© GeoBasis-DE/LGB, dl-de/by-2-0, data modified · R8 scan: Andrea Spognetta, CC BY-NC 4.0\nRelative anchor fit only; no live terrain approval.',fontsize=8);fig.savefig(HERE/'dgm_comparison.png',dpi=150,bbox_inches='tight');plt.close(fig)
        print(json.dumps(result,indent=2))
if __name__=='__main__':run(sys.argv[1])
