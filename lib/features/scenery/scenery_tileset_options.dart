import 'dart:convert';

const remoteTilesetProvider = 'remote-tiles';
const remoteTilesetFormat = '3d-tiles';

String validateTilesetUrl(Object? value) {
  if (value is! String ||
      value.length > 2048 ||
      RegExp(r'[\x00-\x20\\]').hasMatch(value)) {
    throw const FormatException('Enter a complete HTTPS tileset URL');
  }
  final uri = Uri.tryParse(value);
  if (uri == null ||
      uri.scheme != 'https' ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty ||
      uri.hasFragment) {
    throw const FormatException(
      'Tilesets require HTTPS without credentials or fragments',
    );
  }
  return uri.toString();
}

Map<String, dynamic> validateTilesetOptions(Object? value) {
  if (value is! Map<String, dynamic>) {
    throw const FormatException('Missing tileset configuration');
  }
  final options = jsonDecode(jsonEncode(value)) as Map<String, dynamic>;
  void number(Object? n, num min, num max) {
    if (n is! num || !n.isFinite || n < min || n > max) {
      throw const FormatException('Invalid tileset option or bounds');
    }
  }

  if (!['1.0', '1.1'].contains(options['version']) ||
      !['provider', 'no-store'].contains(options['cachePolicy'])) {
    throw const FormatException(
      'Unsupported tileset version or caching policy',
    );
  }
  number(options['maximumScreenSpaceError'], 1, 128);
  final sphere = options['boundingSphere'];
  if (sphere is! Map ||
      sphere['center'] is! List ||
      (sphere['center'] as List).length != 3) {
    throw const FormatException('Validated tileset bounds are required');
  }
  for (final v in sphere['center'] as List) {
    number(v, -1e9, 1e9);
  }
  number(sphere['radiusM'], 0, 1e8);
  final correction = options['correction'] ?? <String, dynamic>{};
  if (correction is! Map) {
    throw const FormatException('Invalid positioning correction');
  }
  for (final key in ['eastM', 'northM', 'upM']) {
    number(correction[key] ?? 0, -1e6, 1e6);
  }
  number(correction['headingDeg'] ?? 0, -360, 360);
  number(correction['pitchDeg'] ?? 0, -90, 90);
  number(correction['rollDeg'] ?? 0, -180, 180);
  number(correction['scale'] ?? 1, .01, 1000);
  options['correction'] = {
    'eastM': 0,
    'northM': 0,
    'upM': 0,
    'headingDeg': 0,
    'pitchDeg': 0,
    'rollDeg': 0,
    'scale': 1,
    ...correction.cast<String, dynamic>(),
  };
  return options;
}
