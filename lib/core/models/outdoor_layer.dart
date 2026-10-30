import 'dart:convert';

enum OutdoorLayerGroup { nature, networks, closures }

enum OutdoorLayer {
  wildlife(
    'Wildruhezonen',
    'ch.bafu.wrz-wildruhezonen_portal',
    OutdoorLayerGroup.nature,
    'BAFU / Kantone',
  ),
  hiking(
    'Wanderwege',
    'ch.swisstopo.swisstlm3d-wanderwege',
    OutdoorLayerGroup.networks,
    'swisstopo / Kantone',
  ),
  cycling(
    'Velorouten',
    'ch.astra.veloland',
    OutdoorLayerGroup.networks,
    'ASTRA / SchweizMobil',
  ),
  mountainBiking(
    'Mountainbike-Routen',
    'ch.astra.mountainbikeland',
    OutdoorLayerGroup.networks,
    'ASTRA / SchweizMobil',
  ),
  winterWalking(
    'Winterwanderwege',
    'ch.astra.winterwanderwege',
    OutdoorLayerGroup.networks,
    'ASTRA / SchweizMobil',
  ),
  snowshoe(
    'Schneeschuhrouten',
    'ch.swisstopo-karto.schneeschuhrouten',
    OutdoorLayerGroup.networks,
    'swisstopo',
  ),
  skiTouring(
    'Skitouren',
    'ch.swisstopo-karto.skitouren',
    OutdoorLayerGroup.networks,
    'swisstopo',
  ),
  hikingClosures(
    'Sperrungen und Umleitungen · Wandern',
    'ch.astra.wanderland-sperrungen_umleitungen',
    OutdoorLayerGroup.closures,
    'ASTRA / Schweizer Wanderwege',
  ),
  cyclingClosures(
    'Sperrungen und Umleitungen · Velo',
    'ch.astra.veloland-sperrungen_umleitungen',
    OutdoorLayerGroup.closures,
    'ASTRA / SchweizMobil',
  ),
  mtbClosures(
    'Sperrungen und Umleitungen · Mountainbike',
    'ch.astra.mountainbikeland-sperrungen_umleitungen',
    OutdoorLayerGroup.closures,
    'ASTRA / SchweizMobil',
  );

  const OutdoorLayer(this.label, this.serviceLayer, this.group, this.publisher);
  final String label, serviceLayer, publisher;
  final OutdoorLayerGroup group;
  String get rendererId => 'outdoor-$name';
  Uri get legend => Uri.https(
    'api3.geo.admin.ch',
    '/rest/services/api/MapServer/$serviceLayer/legend',
  );
}

const outdoorPreferencesKey = 'map.outdoor.v1';

class OutdoorLayerPreference {
  const OutdoorLayerPreference({this.visible = false, this.opacity = .65});
  final bool visible;
  final double opacity;
  OutdoorLayerPreference copyWith({bool? visible, double? opacity}) =>
      OutdoorLayerPreference(
        visible: visible ?? this.visible,
        opacity: opacity ?? this.opacity,
      );
  Map<String, dynamic> toJson() => {'visible': visible, 'opacity': opacity};
}

String encodeOutdoorPreferences(
  Map<OutdoorLayer, OutdoorLayerPreference> preferences,
) {
  final json = jsonEncode({
    for (final e in preferences.entries) e.key.name: e.value.toJson(),
  });
  decodeOutdoorPreferences(json);
  return json;
}

Map<OutdoorLayer, OutdoorLayerPreference> decodeOutdoorPreferences(
  String? text,
) {
  if (text == null) return const {};
  if (text.length > 4096) {
    throw const FormatException('Outdoor-Einstellungen sind zu groß');
  }
  final raw = jsonDecode(text);
  if (raw is! Map || raw.length > OutdoorLayer.values.length) {
    throw const FormatException('Ungültige Outdoor-Einstellungen');
  }
  final result = <OutdoorLayer, OutdoorLayerPreference>{};
  for (final e in raw.entries) {
    final layer = OutdoorLayer.values.where((l) => l.name == e.key).firstOrNull;
    final value = e.value;
    if (layer == null ||
        value is! Map ||
        value.length != 2 ||
        value['visible'] is! bool ||
        value['opacity'] is! num ||
        !(value['opacity'] as num).isFinite ||
        value['opacity'] < 0 ||
        value['opacity'] > 1) {
      throw const FormatException('Ungültige Outdoor-Kartenebene');
    }
    result[layer] = OutdoorLayerPreference(
      visible: value['visible'] as bool,
      opacity: (value['opacity'] as num).toDouble(),
    );
  }
  return Map.unmodifiable(result);
}
