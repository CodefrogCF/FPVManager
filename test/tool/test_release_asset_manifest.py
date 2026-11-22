"""Exercises deployment paths that a JavaScript test cannot check."""

import plistlib
import json
import struct
import tempfile
from pathlib import Path
import unittest

from tool.check_release_artifacts import (
    renderer_files, validate_glb_meshes, check_optional_local_scenery,
)


ROOT = Path(__file__).resolve().parents[2]


class ReleaseAssetTest(unittest.TestCase):
    def test_native_renderer_and_decoders_are_declared(self):
        lines = (ROOT / 'pubspec.yaml').read_text(encoding='utf-8').splitlines()
        assets = {line[6:] for line in lines if line.startswith('    - ')}
        for asset in renderer_files(ROOT):
            with self.subTest(asset=asset):
                self.assertTrue((ROOT / asset).is_file())
                directory = Path(asset).parent.as_posix() + '/'
                self.assertTrue(asset in assets or directory in assets, asset)
        radar = (ROOT / 'web/meteo_radar_overlay.js').read_text(encoding='utf-8')
        self.assertIn('./vendor/h5wasm/hdf5_hl.js', radar)
        self.assertNotIn('cdn.jsdelivr.net', radar)


    def test_empty_glb_mesh_rejected_before_release(self):
        def make_glb(meshes, nodes):
            doc = json.dumps({'asset': {'version': '2.0'},
                              'meshes': meshes, 'nodes': nodes}).encode()
            doc += b' ' * (-len(doc) % 4)
            chunk = struct.pack('<I4s', len(doc), b'JSON') + doc
            return struct.pack('<4sII', b'glTF', 2, 12 + len(chunk)) + chunk

        valid = make_glb([{'primitives': [{'attributes': {'POSITION': 0}}]}],
                          [{'mesh': 0}])
        self.assertEqual(validate_glb_meshes(valid), 1)
        with self.assertRaisesRegex(ValueError, 'empty glTF mesh at index 0'):
            validate_glb_meshes(make_glb([{'primitives': []}], [{'mesh': 0}]))
        with self.assertRaisesRegex(ValueError, 'refers to missing mesh'):
            validate_glb_meshes(make_glb([{'primitives': [{'attributes': {}}]}],
                                         [{'mesh': 2}]))

    def test_installed_local_scenery_glb_has_no_empty_meshes(self):
        path = ROOT / 'web/assets/scenery/local_reference.glb'
        if not path.is_file():
            self.skipTest('Optional CC BY-NC local scan is not installed')
        self.assertGreater(validate_glb_meshes(path.read_bytes(), path.name), 15)

    def test_local_optional_scenery_must_be_bundled_if_present(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            asset_dir = root / 'web/assets/scenery'
            asset_dir.mkdir(parents=True)
            catalog = {'sceneries': [{'assets': [{'path': 'local_reference.glb'}],
                                      'collisionAsset': 'local_reference.fpc'}]}
            (asset_dir / 'catalog.json').write_text(json.dumps(catalog))
            # Nontracked original is optional in public CI.
            check_optional_local_scenery(lambda _: None, '', root)
            (asset_dir / 'local_reference.glb').write_bytes(b'bad')
            with self.assertRaises(KeyError):
                check_optional_local_scenery(lambda name: {}[name], '', root)
            with self.assertRaisesRegex(ValueError, 'truncated GLB'):
                check_optional_local_scenery(lambda _: b'bad', '', root)

    def test_ios_foreground_purpose_and_app_manifest_are_in_runner(self):
        runner = ROOT / 'ios/Runner'
        info = plistlib.loads((runner / 'Info.plist').read_bytes())
        purpose = info['NSLocationWhenInUseUsageDescription']
        self.assertIn('while the app is open', purpose)
        manifest = plistlib.loads((runner / 'PrivacyInfo.xcprivacy').read_bytes())
        self.assertIs(manifest['NSPrivacyTracking'], False)
        project = (ROOT / 'ios/Runner.xcodeproj/project.pbxproj').read_text(
            encoding='utf-8'
        )
        self.assertIn('path = PrivacyInfo.xcprivacy;', project)
        self.assertIn('/* PrivacyInfo.xcprivacy in Resources */,', project)
