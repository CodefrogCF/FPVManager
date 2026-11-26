"""Synthetic tests for the local RF grid preparation policy (no provider requests)."""
import importlib.util
from pathlib import Path
from types import SimpleNamespace
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
if importlib.util.find_spec('pyproj'):
    spec = importlib.util.spec_from_file_location('prepare_bkg_rf_grid', ROOT / 'tool/scenery/reference/prepare_bkg_rf_grid.py')
    grid_tool = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(grid_tool)
else:
    grid_tool = None


@unittest.skipIf(grid_tool is None, 'Install pyproj for geoid preparation tests')
class BkgGridTests(unittest.TestCase):
    def test_preparation_validates_controls_and_excludes_outside_point(self):
        with tempfile.TemporaryDirectory() as tmp:
            grid = Path(tmp) / 'de_bkg_gcg2016.tif'
            grid.write_bytes(b'synthetic test only')
            coords = [(13.779+i*.003, 52.482+j*.005) for j in range(2) for i in range(4)]
            offset = lambda x,y: 38.9 + .2*(x-13.78) - .1*(y-52.48)
            controls = [dict(longitude=x,latitude=y,dhhn2016M=40.,ellipsoidM=40+offset(x,y),meshM=40.1) for x,y in coords]
            controls.append(dict(longitude=13.79,latitude=52.479,dhhn2016M=-9.,ellipsoidM=30.,meshM=5.))
            report = dict(providerUrl=grid_tool.PROVIDER,coldVsNativeMaxM=0,warmVsNativeMaxM=0,source='Synthetic controls',points=controls)
            op = SimpleNamespace(grids=[SimpleNamespace(short_name=grid.name,available=True)])
            transform = SimpleNamespace(operations=[op],transform=lambda x,y,z,**kw:(x,y,z+offset(x,y)))
            group = SimpleNamespace(best_available=True,transformers=[transform])
            utm = SimpleNamespace(transform=lambda x,y,**kw:(x,y))
            with patch.object(grid_tool,'TransformerGroup',return_value=group), patch.object(grid_tool.Transformer,'from_crs',return_value=utm), patch.object(grid_tool.datadir,'append_data_dir'), patch.object(grid_tool.network,'set_network_enabled'):
                result = grid_tool.prepare(grid,report)
                self.assertEqual(result['acceptedControls'],8)
                self.assertEqual(result['excludedControls'],1)
                self.assertEqual(len(result['values']),121)
                self.assertEqual(len(result['controls']),8)
                self.assertAlmostEqual(result['normalRmsM'],.1)
                controls[0]['meshM'] += 39
                with self.assertRaises(ValueError):
                    grid_tool.prepare(grid,report)
