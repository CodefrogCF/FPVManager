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
      'image (bundled components)': 'assets/licenses/image-LICENSE-other.md',
      'archive (bundled components)':
          'assets/licenses/archive-LICENSE-other.md',
    }.entries) {
      final text = await rootBundle.loadString(entry.value);
      yield LicenseEntryWithLineBreaks([entry.key], text);
    }
  });
}
