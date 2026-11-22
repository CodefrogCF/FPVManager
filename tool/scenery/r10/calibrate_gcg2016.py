#!/usr/bin/env python3
"""Offline Rüdersdorf DGM1 / GCG2016 vertical calibration.

Produces a separate *reference-only* GLB/FPC, CSV seam audit, diagnostic plot,
and an auditable alignment report. Does not modify FPVManager production assets.

Usage (from repository root, with R8 + R9 installed):
  python tool/scenery/r10/calibrate_gcg2016.py /path/dgm_33417-5815.zip /path/de_bkg_gcg2016.tiff

Dependencies: numpy scipy pyproj rasterio matplotlib; tool/scenery/build_collision.py.
"""
import csv
import hashlib
import json
import struct
import sys
import zipfile
from pathlib import Path
import numpy as np
import rasterio
from pyproj import Transformer
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
sys.path.insert(0, str(HERE.parent))
from build_collision import AXIS, read_glb, build

GCG_DESC = 'de_bkg_gcg2016.tiff'

def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()

def make_geoid_transform(grid):
    # PROJ vgridshift forward adds the grid height anomaly to DHHN heights.
    # Explicit degree/radian conversion is essential for this low-level pipeline.
    pipeline = (
        '+proj=pipeline '
        '+step +proj=unitconvert +xy_in=deg +xy_out=rad '
        f'+step +proj=vgridshift +grids={str(grid)} +multiplier=1 '
        '+step +proj=unitconvert +xy_in=rad +xy_out=deg'
    )
    return Transformer.from_pipeline(pipeline)

def glb(destination, vertices, triangles):
    # Local coordinates follow FPVManager's adjusted glTF -> Cesium correction.
    vertices_glb = (vertices @ AXIS).astype('<f4')
    idx = triangles.astype('<u4').ravel()
    binary = vertices_glb.tobytes() + idx.tobytes()
    document = {
      'asset': {
        'version':'2.0', 'generator':'FPVManager R10 calibrated DGM1 reference',
        'copyright':'© GeoBasis-DE/LGB (dl-de/by-2-0); GCG2016 © BKG (CC BY 4.0), modified data',
        'extras': {
          'purpose':'reference only - not active terrain',
          'relativeVerticalDatum':'ellipsoidal ETRS89/GRS80 relative to calibrated ground point',
          'absoluteEllipsoidHeightSuppliedBy':'height_calibration.json',
          'notSuitableFor':'replacing existing model or bypassing active terrain collision'
        }
      },
      'scene':0,'scenes':[{'nodes':[0]}],'nodes':[{'mesh':0}],
      'meshes':[{'primitives':[{'attributes':{'POSITION':0},'indices':1,'material':0}]}],
      'materials':[{'name':'Calibrated DGM1 reference', 'doubleSided':True,
          'pbrMetallicRoughness':{'baseColorFactor':[.35,.55,.34,1.0],'metallicFactor':0,'roughnessFactor':1}}],
      'buffers':[{'byteLength':len(binary)}],
      'bufferViews':[{'buffer':0,'byteOffset':0,'byteLength':vertices_glb.nbytes,'target':34962},
                     {'buffer':0,'byteOffset':vertices_glb.nbytes,'byteLength':idx.nbytes,'target':34963}],
      'accessors':[{'bufferView':0,'componentType':5126,'count':len(vertices_glb),'type':'VEC3',
                    'min':vertices_glb.min(0).tolist(),'max':vertices_glb.max(0).tolist()},
                   {'bufferView':1,'componentType':5125,'count':len(idx),'type':'SCALAR',
                    'min':[int(idx.min())],'max':[int(idx.max())]}]
    }
    doc = json.dumps(document, separators=(',',':'), ensure_ascii=False).encode('utf-8')
    doc+=b' '*(-len(doc)%4)
    binary+=b'\x00'*(-len(binary)%4)
    chunks=struct.pack('<I4s',len(doc),b'JSON')+doc+struct.pack('<I4s',len(binary),b'BIN\0')+binary
    destination.write_bytes(struct.pack('<4sII',b'glTF',2,len(chunks)+12)+chunks)

def geographic(alignment, xs, ys):
    # Same local-to-geographic approximation used in the existing FPVManager
    # scene transform. Valid only for the small (few-hundred-metre) Rüdersdorf site.
    a = np.deg2rad(-alignment['rotationDeg'])
    co,si = np.cos(a),np.sin(a)
    lat=np.deg2rad(alignment['latitude'])
    w=np.sqrt(1-0.00669437999014*np.sin(lat)**2)
    east=6378137/w*np.cos(lat)*np.pi/180
    north=6378137*(1-0.00669437999014)/w**3*np.pi/180
    scale=alignment['scale']
    return alignment['longitude']+scale*(co*xs-si*ys)/east, alignment['latitude']+scale*(si*xs+co*ys)/north

def calculate(dgm_zip, grid):
    dgm_zip=Path(dgm_zip).resolve();grid=Path(grid).resolve()
    r9=json.loads((HERE.parent/'r9/report.json').read_text())
    catalog=json.loads((ROOT/'web/assets/scenery/catalog.json').read_text())
    item=catalog['sceneries'][0];alignment=item['alignment']
    assert r9['alignment']==alignment, 'R9 and R8 alignment mismatch'
    assert sha(ROOT/'web/assets/scenery/local_reference.fpc')==r9['source_r8_collision_sha256']
    assert sha(HERE.parent/'r9/dgm_reference.glb')==r9['reference_glb_sha256']
    assert sha(HERE.parent/'r9/dgm_reference.fpc')==r9['reference_fpc_sha256']
    with rasterio.open(grid) as g:
        tags=g.tags()
        if tags.get('TYPE')!='VERTICAL_OFFSET_GEOGRAPHIC_TO_VERTICAL' or tags.get('target_crs_epsg_code')!='7837':
            raise ValueError('Not GCG2016 ETRS89 -> DHHN2016 grid')
        if '10283' not in str(g.crs) or g.nodata is None:
            raise ValueError('Unexpected GCG CRS or nodata')
        if g.bounds.left>alignment['longitude'] or g.bounds.right<alignment['longitude'] or g.bounds.bottom>alignment['latitude'] or g.bounds.top<alignment['latitude']:
            raise ValueError('GCG raster does not cover Rüdersdorf')
    t=make_geoid_transform(grid)
    def anomaly(lon,lat):
        _,_,n=t.transform(lon,lat,np.zeros_like(np.asarray(lon,dtype=float)))
        n=np.asarray(n,dtype=float)
        if not np.isfinite(n).all() or np.any(np.abs(n)>150): raise ValueError('Invalid GCG2016 interpolated values')
        return n
    if not any(name.endswith('.tif') for name in zipfile.ZipFile(dgm_zip).namelist()):
        raise ValueError('No DGM GeoTIFF in archive')
    tifname=next(name for name in zipfile.ZipFile(dgm_zip).namelist() if name.endswith('.tif'))
    with zipfile.ZipFile(dgm_zip) as z:
        actual_dgm_hash=hashlib.sha256(z.read(tifname)).hexdigest()
    if actual_dgm_hash!=r9['source_sha256']:
        raise ValueError('DGM GeoTIFF differs from R9 source')
    with rasterio.open(f'zip://{dgm_zip}!{tifname}') as ds:
        if 'DHHN2016' not in ds.crs.to_wkt() or '25833' not in ds.crs.to_wkt():
            raise ValueError('Unexpected DGM CRS')
        if ds.res != (1,1): raise ValueError('Unexpected DGM resolution')
        lon0,lat0=alignment['longitude'],alignment['latitude']
        utm=Transformer.from_crs(4326,25833,always_xy=True)
        dgm_data=ds.read(1)
        from scipy.ndimage import map_coordinates
        def elevation(lon,lat):
            x,y=utm.transform(lon,lat)
            col,row=(~ds.transform)*(np.asarray(x),np.asarray(y))
            col=np.atleast_1d(col)-.5;row=np.atleast_1d(row)-.5
            if np.any(col<0) or np.any(row<0) or np.any(col>ds.width-1) or np.any(row>ds.height-1):
                raise ValueError('Requested location outside DGM raster')
            h=map_coordinates(dgm_data.astype(float),[row,col],order=1)
            if not np.isfinite(h).all() or np.any(h<=-9999): raise ValueError('DGM nodata')
            return h
        nhn_anchor=float(elevation([lon0],[lat0])[0]); n_anchor=float(anomaly([lon0],[lat0])[0]); ell_anchor=nhn_anchor+n_anchor
        # R9 mesh already encodes the DGM1 relative to the NHN at the anchor.
        # Correct only *relative* geoid variation; absolute anchor height is
        # stored separately as a calibrated Cesium placement, avoiding double lift.
        source=HERE.parent/'r9/dgm_reference.glb'
        v,t_faces=read_glb(source)
        lon,lat=geographic(alignment,v[:,0],v[:,1])
        n=anomaly(lon,lat)
        corrected=v.copy();corrected[:,2]+=(n-n_anchor)/alignment['scale']
        glb_path=HERE/'dgm_ellipsoid_reference.glb'
        fpc_path=HERE/'dgm_ellipsoid_reference.fpc'
        glb(glb_path,corrected,t_faces)
        vv,tt=read_glb(glb_path)
        build_info=build(vv,tt,fpc_path)
        assert len(tt)==len(t_faces) and np.allclose(vv,corrected,atol=1e-6)
        assert np.array_equal(vv,corrected)
        # Exact unique triangle parity between our GLB and FPC.
        raw=fpc_path.read_bytes();_magic,nv,nt,nn=struct.unpack_from('<4sIII',raw)
        assert _magic==b'FPC1' and nt==len(t_faces) and nv==len(vv)
        vertices_fpc=np.frombuffer(raw,dtype='<f4',offset=16,count=nv*3).reshape(-1,3)
        assert np.array_equal(vv,vertices_fpc)
        seams=[];results=[]
        with (HERE.parent/'r9/seam_comparison.csv').open() as fp:
            for row in csv.DictReader(fp):
                region=int(row['region']);lonr=float(row['lon']);latr=float(row['lat'])
                nr=float(anomaly([lonr],[latr])[0])
                dgm=float(row['dgm_nhn_m']);scn=float(row['scan_nhn_relative_estimate_m'])
                datum_scan=scn+n_anchor # Scene keeps same fixed vertical offset for all vertices.
                dgm_ell=dgm+nr
                results.append([region,lonr,latr,nr,dgm_ell,datum_scan,datum_scan-dgm_ell])
        by_region={}
        for region,*values in results:
            by_region.setdefault(region,[]).append(values[-1])
        for region,errors in sorted(by_region.items()):
            errors=np.asarray(errors)
            seams.append({'region':region,'samples':len(errors),'min_m':float(errors.min()),'max_m':float(errors.max()),'max_abs_m':float(np.abs(errors).max()),'rms_m':float(np.sqrt(np.mean(errors**2))),'within_0_5m':bool(np.abs(errors).max()<=.5)})
        assert len(results)==536 and len(seams)==16
        with (HERE/'seam_comparison_ellipsoid.csv').open('w',newline='') as fp:
            writer=csv.writer(fp);writer.writerow(['region','lon','lat','gcg2016_anomaly_m','dgm_ellipsoid_m','scan_ellipsoid_assumed_m','residual_m']);writer.writerows(results)
        root_anchor=ell_anchor-alignment['scale']*item['groundReferenceLocalUp']
        # Simulated Cesium output with already active regional 3D terrain is
        # terrainAligned(item, sampleGround), NOT catalog root height plus N.
        sample_lon, sample_lat=geographic(alignment, v[:,0],v[:,1])
        dgm_nhn=elevation(sample_lon,sample_lat)
        diffs=(dgm_nhn+n)-ell_anchor
        geoid_gradient_range=float(np.ptp(n))
        report={
          'status':'calibrated geodetic reference, not active terrain replacement',
          'sources':{'gcg2016_grid':str(grid.name),'gcg2016_sha256':sha(grid),'gcg2016_license':tags.get('TIFFTAG_COPYRIGHT'),
                     'dgm_zip':str(dgm_zip.name),'dgm_sha256_zip':sha(dgm_zip),
                     'dgm_geotiff_sha256':r9['source_sha256'],
                     'r8_collision_sha256':r9['source_r8_collision_sha256']},
          'anchor':{'longitude':lon0,'latitude':lat0,'dgm_nhn_m':nhn_anchor,'gcg2016_anomaly_m':n_anchor,
                    'terrain_ellipsoid_m':ell_anchor,'model_reference_local_up':item['groundReferenceLocalUp'],
                    'model_root_ellipsoid_m':root_anchor,'original_catalog_root_ellipsoid_m':alignment['ellipsoidHeightM'],
                    'root_minus_old_root_m':root_anchor-alignment['ellipsoidHeightM']},
          'grid_local':{'xsize':r9['reference_grid'][0], 'ysize':r9['reference_grid'][1],
                        'geoid_anomaly_min_m':float(n.min()),'geoid_anomaly_max_m':float(n.max()),
                        'geoid_anomaly_variation_m':geoid_gradient_range,
                        'terrain_local_relative_ellipsoid_min_m':float(diffs.min()),'terrain_local_relative_ellipsoid_max_m':float(diffs.max()),
                        'vertical_correction_vs_r9_local_min_m':float((n-n_anchor).min()),'vertical_correction_vs_r9_local_max_m':float((n-n_anchor).max())},
          'geometry':build_info, 'reference_glb_sha256':sha(glb_path),'reference_fpc_sha256':sha(fpc_path),
          'seams':seams,'seam_sample_count':len(results),
          'limits':['ETRS89 and WGS84 used as equivalent only for this local scenery scale',
                    'Does not certify 3D Beta provider vertical datum',
                    'Bare-earth DGM1 is not an indoor floor model; elevated hall floors must not be flattened',
                    'R8 catalog, physics, 16 terrain certificates and original GLB/FPC intentionally unchanged',
                    'No automatic region-wide clipping or verified continuous provider seam']}
        (HERE/'height_calibration.json').write_text(json.dumps(report,indent=2,ensure_ascii=False)+'\n')
        fig,axes=plt.subplots(1,2,figsize=(12,5),constrained_layout=True)
        X=vv[:,0].reshape(r9['reference_grid'][1],r9['reference_grid'][0])*alignment['scale']
        Y=vv[:,1].reshape(r9['reference_grid'][1],r9['reference_grid'][0])*alignment['scale']
        H=(dgm_nhn+n).reshape(X.shape)
        plot=axes[0].tricontourf(X[::3,::3].ravel(),Y[::3,::3].ravel(),H[::3,::3].ravel(),levels=22,cmap='terrain')
        fig.colorbar(plot,ax=axes[0],label='Ellipsoidische Höhe (m)')
        axes[0].set(title='DGM1 + GCG2016',xlabel='lokal x (m)',ylabel='lokal y (m)',aspect='equal')
        xx=np.arange(1,17)
        err=[s['max_abs_m'] for s in seams]
        axes[1].bar(xx,err,color=['#398b70' if e<=.5 else '#a95e4e' for e in err])
        axes[1].axhline(.5,color='black',ls='--',lw=1)
        axes[1].set(title='Randabweichung Scan / DGM1',xlabel='R8-Ersatzfläche',ylabel='max. Abweichung (m)',xticks=xx)
        fig.suptitle('Rüdersdorf R10 – amtlicher Höhenbezug (Referenz, kein aktiver Geländeersatz)')
        fig.text(.04,.005,'© GeoBasis-DE/LGB (dl-de/by-2-0), BKG GCG2016 (CC BY 4.0), Daten geändert; Scan © Andrea Spognetta (CC BY-NC 4.0)',fontsize=7)
        fig.savefig(HERE/'R10_height_calibration.png',dpi=140)
        plt.close(fig)
        print(json.dumps({'anchor':report['anchor'],'geoid_variation_m':geoid_gradient_range,
                          'approved_regions':sum(s['within_0_5m'] for s in seams),'total_regions':len(seams),
                          'geometry':build_info},indent=2))
        return report

if __name__ == '__main__':
    if len(sys.argv)!=3:raise SystemExit('Usage: calibrate_gcg2016.py DGM1.zip de_bkg_gcg2016.tiff')
    calculate(sys.argv[1],sys.argv[2])
