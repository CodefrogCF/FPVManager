"""Pure standard-library regression tests for local tunnel OBJ conversion."""
import argparse
import json
import tempfile
import unittest
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "tool"))
from convert_tunnel_obj import anchor_and_basis, enu_to_geodetic, read_obj, convert


class TunnelObjConversionTests(unittest.TestCase):
    def test_explicit_wgs84_anchor_preserves_local_enu_axes(self):
        basis = anchor_and_basis(8.2, 46.8, 500)
        lon, lat, height = enu_to_geodetic(0, 0, 0, basis)
        self.assertAlmostEqual(lon, 8.2, places=7)
        self.assertAlmostEqual(lat, 46.8, places=7)
        self.assertAlmostEqual(height, 500, places=5)
        east = enu_to_geodetic(10, 0, 0, basis)
        north = enu_to_geodetic(0, 10, 0, basis)
        up = enu_to_geodetic(0, 0, 10, basis)
        self.assertGreater(east[0], lon)
        self.assertAlmostEqual(east[1], lat, places=6)
        self.assertGreater(north[1], lat)
        self.assertAlmostEqual(north[0], lon, places=6)
        self.assertAlmostEqual(up[2], 510, places=3)

    def test_conversion_retains_independent_visual_and_collision_triangles(self):
        with tempfile.TemporaryDirectory() as tmp:
            directory = Path(tmp)
            visual = directory / "visual.obj"
            collision = directory / "collision.obj"
            output = directory / "output.json"
            visual.write_text('v 0 0 0\nv 10 0 0\nv 10 5 0\nv 0 5 0\nf 1 2 3 4\n')
            collision.write_text('v 0 0 0\nv 10 0 0\nv 10 5 0\nf -3 -2 -1\n')
            args = argparse.Namespace(lon=8.2, lat=46.8, height=500,
                visual=visual, collision=collision, output=output,
                source="CAD fixture", source_id="sample", identity="test")
            convert(args)
            model = json.loads(output.read_text())
            self.assertEqual(model["coordinateReference"], "EPSG:4979")
            self.assertEqual(model["elevationReference"], "WGS84_ELLIPSOID")
            self.assertEqual(model["visualMesh"]["triangles"], [[0, 1, 2], [0, 2, 3]])
            self.assertEqual(model["collisionMesh"]["triangles"], [[0, 1, 2]])

    def test_degenerate_geometry_and_invalid_anchor_rejected(self):
        with tempfile.TemporaryDirectory() as tmp:
            obj = Path(tmp) / "bad.obj"
            obj.write_text('v 0 0 0\nv 1 0 0\nv 2 0 0\nf 1 2 3\n')
            with self.assertRaisesRegex(ValueError, 'degenerate'):
                read_obj(obj, anchor_and_basis(8.2, 46.8, 500))
            args = argparse.Namespace(lon=100, lat=46.8, height=500,
                visual=obj, collision=obj, output=Path(tmp) / 'out.json',
                source='CAD fixture', source_id='sample', identity='test')
            with self.assertRaisesRegex(ValueError, 'Anchor'):
                convert(args)


if __name__ == '__main__':
    unittest.main()
