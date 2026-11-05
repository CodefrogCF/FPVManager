import 'dart:io' show Platform;

bool get desktopGlobeInteractionEnabled =>
    Platform.isWindows && !Platform.environment.containsKey('FLUTTER_TEST');
