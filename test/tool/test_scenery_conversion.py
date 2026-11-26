import hashlib
import importlib.util
import json
from pathlib import Path
import struct
import subprocess
import sys
import tempfile
import unittest
import zipfile

ROOT = Path(__file__).resolve().parents[2]
TOOL = ROOT / 'tool/scenery/conversion'
if all(importlib.util.find_spec(x) for x in ('numpy','pyproj','PIL','shapely','lxml','rasterio','trimesh','scipy')):
    sys.path.insert(0,str(TOOL))
    import convert as c
    import numpy as np
    import rasterio
    from rasterio.transform import from_origin
    from PIL import Image
else:
    c=None


@unittest.skipIf(c is None,'Install scenery conversion requirements')
class ConversionTests(unittest.TestCase):
    def setUp(self):
        self.tmp=tempfile.TemporaryDirectory(); self.addCleanup(self.tmp.cleanup)
        self.base=Path(self.tmp.name)
        self.example=TOOL/'examples'
        self.recipe=json.loads((self.example/'open_wall.json').read_text())
        self.frame=c.Frame(self.recipe['anchor'])

    def test_coordinate_precision_and_inverse(self):
        xyz=np.array([[500000,5300000,100],[500001,5300000,100],[500000,5300001,103]])
        a=self.frame.convert(xyz,self.recipe['visual'][0]); self.assertLess(np.linalg.norm(a[0]),.001)
        self.assertAlmostEqual(np.linalg.norm(a[1]-a[0]),1,places=2)
        self.assertAlmostEqual(a[2,2],3,places=3)
        self.assertTrue(np.allclose(self.frame.from_geo(self.frame.to_geographic(a)),a,atol=1e-7))
        with self.assertRaises(ValueError): self.frame.convert(xyz,{'crs':'EPSG:25832','vertical':'orthometric'})

    def test_control_points(self):
        a=np.array([[0,0,0],[2,0,0],[0,3,0],[0,0,4]],float); b=a[:,[1,0,2]]*2; b[:,0]*=-1; b+=np.array([3,4,5])
        controls=[{'local':x.tolist(),'wgs84':y.tolist()} for x,y in zip(a,self.frame.to_geographic(b))]
        self.assertTrue(np.allclose(c.align(a,controls,self.frame),b,atol=1e-6))
        with self.assertRaises(ValueError): c.align(a,controls[:2],self.frame)

    def test_package_reproducible_and_real_js_collider(self):
        a=self.base/'a.fpvscenery'; b=self.base/'b.fpvscenery'
        m=c.convert(self.recipe,self.example,a); c.convert(self.recipe,self.example,b)
        self.assertEqual(a.read_bytes(),b.read_bytes()); self.assertFalse(m['scenery']['visibility']['enabled'])
        self.assertIn('EPSG:25832',m['scenery']['source']['attribution'])
        self.assertTrue(m['scenery']['replacement']['buildings']['enabled'])
        with zipfile.ZipFile(a) as z:
            self.assertIsNone(z.testzip()); self.assertTrue(all(x.compress_type==0 and not x.extra for x in z.infolist()))
            for name,meta in m['files'].items():
                data=z.read(name); self.assertEqual(hashlib.sha256(data).hexdigest(),meta['sha256']); self.assertEqual(len(data),meta['bytes'])
            glb=m['scenery']['assets'][0]; g=z.read('assets/'+glb['uri']); self.assertEqual(g[:4],b'glTF')
            n=struct.unpack_from('<I',g,12)[0]; doc=json.loads(g[20:20+n]); self.assertEqual(doc['accessors'][0]['count'],glb['model']['vertices'])
            fpc=m['scenery']['assets'][1]; path=self.base/'wall.fpc'; path.write_bytes(z.read('assets/'+fpc['uri']))
        js="const fs=require('node:fs'); const c=require('./web/features/scenery/scenery_collision.js'); const b=fs.readFileSync(process.argv[1]); const m=c.parse(b.buffer.slice(b.byteOffset,b.byteOffset+b.byteLength)); if(m.triangleCount!==8)process.exit(2); const hole=c.rfTrace(m,[5,-1,3],[5,1,3],1,868,0,{nodes:8192,triangles:4096}); const wall=c.rfTrace(m,[2,-1,3],[2,1,3],1,868,0,{nodes:8192,triangles:4096}); if(!hole.complete||hole.hits.length||!wall.complete||!wall.hits.length)process.exit(3);"
        subprocess.run(['node','-e',js,str(path)],cwd=ROOT,check=True)
        # The hole is not filled by either source triangulation or FPC generation.
        mesh=c.load(self.recipe['visual'][0],self.frame,self.example)[0]; tri=mesh.v[mesh.f]; area=np.linalg.norm(np.cross(tri[:,1]-tri[:,0],tri[:,2]-tri[:,0]),axis=1).sum()/2
        self.assertAlmostEqual(area,56,delta=.1)
        with self.assertRaises(FileExistsError): c.convert(self.recipe,self.example,a)

    def test_citygml_local_xlinks_and_external_denial(self):
        from lxml import etree
        doc=etree.parse(str(self.example/'open_wall.gml'))
        ns={'g':'http://www.opengis.net/gml'}; poly=doc.xpath('//g:Polygon',namespaces=ns)[0]
        poly.set('{http://www.opengis.net/gml}id','wallpolygon')
        parent=poly.getparent(); parent.remove(poly); doc.getroot().append(poly)
        parent.set('{http://www.w3.org/1999/xlink}href','#wallpolygon')
        path=self.base/'linked.gml'; doc.write(str(path))
        self.assertEqual(len(c.citygml(path,self.recipe['visual'][0],self.frame)[0].f),8)
        parent.set('{http://www.w3.org/1999/xlink}href','https://example.invalid/wall')
        doc.write(str(path))
        with self.assertRaises(ValueError): c.citygml(path,self.recipe['visual'][0],self.frame)

    def test_raster_lods_texture_and_nodata(self):
        profile=dict(driver='GTiff',width=5,height=5,count=1,dtype='float32',crs='EPSG:25832',transform=from_origin(500000,5300005,1,1),nodata=-9999)
        with rasterio.open(self.base/'dem.tif','w',**profile) as ds: ds.write(np.full((5,5),100,dtype='float32'),1)
        with rasterio.open(self.base/'rgb.tif','w',**dict(profile,count=3,dtype='uint8',nodata=None)) as ds: ds.write(np.full((3,5,5),150,dtype='uint8'))
        s=dict(self.recipe['visual'][0],type='dem',path='dem.tif',orthophoto='rgb.tif',orthophotoSource=dict(author='Tests',license='CC0',attribution='Synthetic RGB',redistributionAllowed=True))
        r=dict(self.recipe,visual=[s],collision=[[dict(s,orthophoto=None)]],lods={'low':[dict(s,stride=2,textureMaxSize=3)]}); r.pop('replacementEnu')
        m=c.convert(r,self.base,self.base/'r.fpvscenery')['scenery']; self.assertEqual([a['model']['triangles'] for a in m['assets']],[32,8,32]); self.assertEqual(m['assets'][0]['model']['textures'],1)
        self.assertEqual(m['extensions']['lods'],{'visual':{'low':'visual-low'}})
        with rasterio.open(self.base/'dem.tif','r+') as ds:
            v=ds.read(1); v[1,1]=-9999; ds.write(v,1)
        self.assertLess(len(c.dem(self.base/'dem.tif',dict(s,stride=2),self.frame,self.base)[0].f),8)

    def test_local_external_mesh_and_rights(self):
        (self.base/'mesh.obj').write_text('v 0 0 0\nv 2 0 0\nv 0 0 3\nf 1 2 3\n')
        s=dict(self.recipe['visual'][0],type='mesh',path='mesh.obj',crs='LOCAL_ENU',vertical='local',alreadyAligned=True)
        m=c.load(s,self.frame,self.base)[0]; self.assertEqual(m.v.max(0).tolist(),[2,0,3]); self.assertEqual(len(m.f),1)
        s['redistributionAllowed']=False
        with self.assertRaises(ValueError): c.convert(dict(self.recipe,visual=[s]),self.base,self.base/'bad.fpvscenery')
        self.assertFalse((self.base/'bad.fpvscenery').exists())

    @unittest.skipUnless(importlib.util.find_spec('laspy'),'laspy not installed')
    def test_las_and_laz_ground_only(self):
        import laspy
        from pyproj import CRS
        hdr=laspy.LasHeader(point_format=3,version='1.2'); hdr.add_crs(CRS.from_epsg(25832)); hdr.offsets=[500000,5300000,100]; hdr.scales=[.01,.01,.01]
        las=laspy.LasData(hdr); las.x=[500000,500001,500000,500001]; las.y=[5300000,5300000,5300001,5300001]; las.z=[100,100,100,120]; las.classification=[2,2,2,6]
        for ext in ('las','laz'):
            if ext=='laz' and not importlib.util.find_spec('lazrs'): continue
            p=self.base/('ground.'+ext); las.write(p)
            s=dict(self.recipe['visual'][0],type='las',path=p.name,groundOnly=True,maxEdgeM=5)
            m=c.cloud(p,s,self.frame); self.assertEqual(len(m[0].f),1); self.assertLess(m[0].v[:,2].max(),.01)

if __name__=='__main__': unittest.main()
