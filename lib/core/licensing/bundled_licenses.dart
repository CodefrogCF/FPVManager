import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

bool _registered = false;

/// Adds upstream component notices that Flutter's package LICENSE collector
/// does not collect. The notices load only when the licence list is opened.
/// The project's root LICENSE is collected by Flutter and is not added here.
void registerBundledLicenses() {
  if (_registered) {
    return;
  }
  _registered = true;
  LicenseRegistry.addLicense(() async* {
    for (final entry in const {
      'FPVManager attribution': 'NOTICE',
      'image (bundled components)': 'assets/licenses/image-LICENSE-other.md',
      'archive (bundled components)':
          'assets/licenses/archive-LICENSE-other.md',
      'GeoTIFF.js': 'web/vendor/geotiff/LICENSE',
      'GeoTIFF.js (bundled components)':
          'web/vendor/geotiff/THIRD_PARTY_NOTICES.txt',
      'h5wasm (NIST)': 'web/vendor/h5wasm/LICENSE.txt',
      'h5wasm (bundled components)':
          'web/vendor/h5wasm/THIRD_PARTY_NOTICES.txt',
    }.entries) {
      final text = await rootBundle.loadString(entry.value);
      yield LicenseEntryWithLineBreaks([entry.key], text);
    }
  });
}
