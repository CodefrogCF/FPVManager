import contextlib
import hashlib
import importlib.util
import io
import json
import os
from pathlib import Path
import struct
import tempfile
import unittest
from unittest.mock import patch
import zipfile

import numpy as np
import rasterio
from rasterio.transform import from_origin
from pyproj import Transformer

ROOT=Path(__file__).resolve().parents[2]
spec=importlib.util.spec_from_file_location('prepare',ROOT/'tool/prepare_offline_region.py')
prepare=importlib.util.module_from_spec(spec)
spec.loader.exec_module(prepare)


class OfficialRegionPreparationTest(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory(dir=ROOT/'.dart_tool',prefix='region-gis-test-')
        assert Path(self.temp.name).resolve().is_relative_to((ROOT/'.dart_tool').resolve())
        self.addCleanup(self.temp.cleanup)
        self.folder=Path(self.temp.name)
        self.cache=self.folder/'sources'
        self.cache.mkdir()
        self.output=self.folder/'region.fpvregion'
        lon,lat=8.4,46.7
        east,north=Transformer.from_crs(4326,2056,always_xy=True).transform(lon,lat)
        self.plan={'format':'fpvmanager-official-sources','version':1,'region':{
            'id':'synthetic-prepared','name':'Synthetic test region','west':lon-.003,'east':lon+.003,
            'south':lat-.003,'north':lat+.003,'style':'topographic','imageryLevel':10,'terrainLevel':8},'assets':[]}
        for terrain in (True,False):
            collection='ch.swisstopo.swissalti3d' if terrain else 'ch.swisstopo.pixelkarte-farbe-pk25.noscale'
            item='synthetic-test-terrain' if terrain else 'synthetic-test-map'
            asset=item+'.tif'
            path=self.folder/asset
            resolution=2 if terrain else 1.25
            size=1000 if terrain else 1600
            values=np.full((size,size),1000.,dtype='float32') if terrain else np.full((size,size),7,dtype='uint8')
            with rasterio.open(path,'w',driver='GTiff',width=size,height=size,count=1,dtype=values.dtype,
                    crs='EPSG:2056',transform=from_origin(east-1000,north+1000,resolution,resolution),
                    tiled=True,blockxsize=256,blockysize=256,compress='LZW') as ds:
                ds.write(values,1)
                if not terrain:
                    ds.write_colormap(1,{i:(i,120,190,255) for i in range(256)})
            sha=hashlib.sha256(path.read_bytes()).hexdigest()
            (self.cache/(sha+'.tif')).write_bytes(path.read_bytes())
            self.plan['assets'].append({'collection':collection,'itemId':item,'assetId':asset,
                'url':f'https://data.geo.admin.ch/{collection}/{item}/{asset}','sha256':sha,
                'sourceTimeUtc':'2020-01-01T00:00:00Z','updatedAtUtc':'2025-01-01T00:00:00Z',
                'resolutionMeters':resolution,'horizontalReference':'EPSG:2056',
                'verticalReference':'LN02' if terrain else 'notApplicable'})

    def run_prepare(self,**kwargs):
        with contextlib.redirect_stdout(io.StringIO()):
            return prepare.prepare(self.plan,self.output,self.cache,terrain_level=8,**kwargs)

    def test_complete_package_uses_cached_checked_sources_and_converted_heights(self):
        with patch.object(prepare,'build_opener',side_effect=AssertionError('No network expected')):
            manifest=self.run_prepare()
        self.assertGreater(len(manifest['files']),20)
        self.assertLess(self.output.stat().st_size,prepare.MAX_PACKAGE)
        with zipfile.ZipFile(self.output) as archive:
            self.assertTrue(all(i.compress_type==zipfile.ZIP_STORED for i in archive.infolist()))
            for name,info in manifest['files'].items():
                body=archive.read(name)
                self.assertEqual(hashlib.sha256(body).hexdigest(),info['sha256'])
            mesh=archive.read('terrain/0/1/0.terrain')
            self.assertEqual(struct.unpack_from('<I',mesh,88)[0],65*65)
            low,high=struct.unpack_from('<2f',mesh,24)
            self.assertGreater(low,1040)
            self.assertLess(high,1060)
            self.assertEqual(manifest['heightReference'],'wgs84Ellipsoid')
            if os.environ.get('FPV_WRITE_OFFLINE_FIXTURE')=='1':
                fixture=ROOT/'test/fixtures/offline/prepared.fpvregion'
                manifest['preparedAtUtc']='2026-01-01T00:00:00Z'
                with zipfile.ZipFile(fixture,'w',compression=zipfile.ZIP_STORED) as out:
                    for name in manifest['files']:
                        out.writestr(name,archive.read(name))
                    out.writestr('manifest.json',json.dumps(manifest,ensure_ascii=False,sort_keys=True,separators=(',',':')).encode())

    def test_failure_keeps_existing_package_and_removes_partial_output(self):
        self.output.write_bytes(b'previous valid snapshot')
        with self.assertRaisesRegex(ValueError,'Output exists'):
            self.run_prepare()
        with patch.object(prepare.HeightGrid,'offsets',side_effect=ValueError('Missing height reference')):
            with self.assertRaisesRegex(ValueError,'Missing height'):
                self.run_prepare(replace=True)
        self.assertEqual(self.output.read_bytes(),b'previous valid snapshot')
        self.assertEqual(list(self.folder.glob('*.partial')),[])

    def test_foreign_urls_and_unsupported_references_are_rejected_before_download(self):
        self.plan['assets'][0]['url']='https://example.com/unknown.tif'
        with self.assertRaisesRegex(ValueError,'Untrusted source'):
            self.run_prepare()
        self.assertFalse(self.output.exists())

    def test_missing_conversion_coverage_is_not_replaced_with_zero(self):
        grid=prepare.HeightGrid()
        with self.assertRaisesRegex(ValueError,'height-conversion coverage'):
            grid.offsets(np.array([5.81]),np.array([46.7]))


if __name__=='__main__':
    unittest.main()
