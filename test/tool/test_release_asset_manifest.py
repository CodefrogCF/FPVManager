"""Exercises deployment paths that a JavaScript test cannot check."""

import plistlib
from pathlib import Path
import unittest

from tool.check_release_artifacts import renderer_files


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
