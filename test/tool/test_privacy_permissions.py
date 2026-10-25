"""Guard the app-owned Android privacy configuration without an APK build."""
from pathlib import Path
import unittest
import xml.etree.ElementTree as ET

ROOT=Path(__file__).resolve().parents[2]
ANDROID='{http://schemas.android.com/apk/res/android}'


class PrivacyPermissionsTest(unittest.TestCase):
    def test_only_foreground_location_and_network_permissions_are_declared(self):
        manifest=ET.parse(ROOT/'android/app/src/main/AndroidManifest.xml').getroot()
        self.assertEqual({p.attrib[ANDROID+'name'] for p in manifest.findall('uses-permission')},{
            'android.permission.INTERNET','android.permission.ACCESS_COARSE_LOCATION','android.permission.ACCESS_FINE_LOCATION'})
        app=manifest.find('application')
        self.assertEqual(app.attrib[ANDROID+'allowBackup'],'false')
        self.assertEqual(app.attrib[ANDROID+'fullBackupContent'],'false')
        self.assertEqual(app.attrib[ANDROID+'dataExtractionRules'],'@xml/data_extraction_rules')

    def test_cloud_and_device_transfer_exclude_local_records_caches_and_credentials(self):
        rules=ET.parse(ROOT/'android/app/src/main/res/xml/data_extraction_rules.xml').getroot()
        for name in ['cloud-backup','device-transfer']:
            domains={e.attrib['domain'] for e in rules.find(name).findall('exclude') if e.attrib['path']=='.'}
            self.assertEqual(domains,{'root','file','database','sharedpref','external','device_root','device_file','device_database','device_sharedpref'})


if __name__=='__main__':
    unittest.main()
