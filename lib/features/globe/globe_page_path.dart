String globePagePath({
  bool offline = false,
  bool cachedMaps = false,
  bool floatingControls = false,
}) {
  final parameters = {
    if (offline) 'offline': '1' else if (cachedMaps) 'cachedMaps': '1',
    if (floatingControls) 'chrome': 'floating',
    // Local developer preview only. Must be explicitly opted into at build time.
    if (const bool.fromEnvironment('FPV_SCENERY_PREVIEW'))
      'sceneryPreview': '1',
    // BKG service terms currently restrict the service to test operation.
    if (const bool.fromEnvironment('FPV_SCENERY_COLLISION_DEBUG'))
      'sceneryCollisionDebug': '1',
    if (const bool.fromEnvironment('FPV_REGIONAL_3D_TEST'))
      'regional3DTest': '1',
  };
  return Uri(
    path: 'globe.html',
    queryParameters: parameters.isEmpty ? null : parameters,
  ).toString();
}
