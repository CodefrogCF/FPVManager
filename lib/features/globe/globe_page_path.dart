String globePagePath({
  bool offline = false,
  bool cachedMaps = false,
  bool floatingControls = false,
}) {
  final parameters = {
    if (offline) 'offline': '1' else if (cachedMaps) 'cachedMaps': '1',
    if (floatingControls) 'chrome': 'floating',
  };
  return Uri(
    path: 'globe.html',
    queryParameters: parameters.isEmpty ? null : parameters,
  ).toString();
}
