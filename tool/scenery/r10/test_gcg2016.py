"""GCG2016 calibration regression checks; invoke with python -m unittest discover."""
import json
import math
import os
import unittest
from pathlib import Path
from pyproj import Transformer

HERE=Path(__file__).resolve().parent

class TestGCG2016(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.report=json.loads((HERE/'height_calibration.json').read_text())
        cls.grid=Path(os.environ.get('R10_GCG_GRID','/mnt/data/de_bkg_gcg2016.tiff'))
    def test_anchor_conversion(self):
        a=self.report['anchor']
        self.assertAlmostEqual(a['terrain_ellipsoid_m'],a['dgm_nhn_m']+a['gcg2016_anomaly_m'],places=8)
        self.assertAlmostEqual(a['model_root_ellipsoid_m'],a['terrain_ellipsoid_m']-a['model_reference_local_up']*16.023268178233355,places=7)
        self.assertTrue(79<a['terrain_ellipsoid_m']<81)
    def test_grid_provenance(self):
        self.assertEqual(self.report['sources']['gcg2016_grid'],'de_bkg_gcg2016.tiff')
        self.assertEqual(len(self.report['sources']['gcg2016_sha256']),64)
        self.assertEqual(len(self.report['sources']['dgm_geotiff_sha256']),64)
    def test_geoid_variation_small_but_not_constant(self):
        q=self.report['grid_local']
        self.assertGreater(q['geoid_anomaly_variation_m'],0.001)
        self.assertLess(q['geoid_anomaly_variation_m'],0.03)
    def test_seam_audit_unchanged_conservative(self):
        self.assertEqual(self.report['seam_sample_count'],536)
        self.assertEqual(len(self.report['seams']),16)
        self.assertEqual(sum(x['within_0_5m'] for x in self.report['seams']),7)
        for row in self.report['seams']:
            self.assertEqual(row['within_0_5m'],row['max_abs_m']<=.5)
    def test_grid_real_pyproj_interpolation(self):
        if not self.grid.exists():self.skipTest('Original GCG grid not supplied to test environment')
        a=self.report['anchor']
        pipeline=f'+proj=pipeline +step +proj=unitconvert +xy_in=deg +xy_out=rad +step +proj=vgridshift +grids={self.grid} +multiplier=1 +step +proj=unitconvert +xy_in=rad +xy_out=deg'
        _,_,height=Transformer.from_pipeline(pipeline).transform(a['longitude'],a['latitude'],0.)
        self.assertAlmostEqual(height,a['gcg2016_anomaly_m'],places=7)

if __name__=='__main__':unittest.main()
