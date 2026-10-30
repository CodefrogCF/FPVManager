import 'dart:convert';
import 'dart:math';

import 'user_preferences.dart';

enum ActivityTool {
  groundRoutes('Bodenrouten'),
  observations('Messstationen'),
  places('Gespeicherte Orte'),
  routes('Flugrouten'),
  mobility('Navigation und Mobilität'),
  preflight('Flugvorbereitung'),
  weather('Wetter'),
  equipment('Ausrüstung'),
  offline('Offline und persönliche Daten');

  const ActivityTool(this.label);
  final String label;
}

enum ActivityAction {
  search('Ort oder Koordinaten suchen'),
  layers('Kartenebenen'),
  location('Standortanzeige'),
  ground('Bodenansicht'),
  simulation('Flugsimulation'),
  weather('Wetter'),
  terrain('Geländehöhe abfragen'),
  home('Karte zurücksetzen');

  const ActivityAction(this.label);
  final String label;
}

enum ActivityLayer {
  observations('Wetter- und Gewässermessstationen'),
  outdoor('Wegenetze, Natur und Sperrungen'),
  roads('Straßen und Wege'),
  labels('Orts- und Straßennamen'),
  buildings('3D-Gebäude'),
  vegetation('Vegetation'),
  airspace('UAS-Zonen'),
  obstacles('Luftfahrthindernisse'),
  avalanche('Lawineninformationen'),
  wind('Wind');

  const ActivityLayer(this.label);
  final String label;
}

const activityProfilesKey = 'activity.profiles.v1';
const activityProfileMaxBytes = 128 * 1024;
const activityProfileMaxCount = 32;

String newActivityProfileId() {
  final random = Random.secure();
  return List.generate(
    16,
    (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();
}

/// Only display configuration belongs here, never permissions or provider keys.
class ActivityMapDefaults {
  const ActivityMapDefaults({this.style, this.savedPlaces, this.lighting});
  final GlobeMapStyle? style;
  final bool? savedPlaces, lighting;
  Map<String, dynamic> toJson() => {
    'style': style?.name,
    'savedPlaces': savedPlaces,
    'lighting': lighting,
  };

  factory ActivityMapDefaults.fromJson(Object? value) {
    final map = _object(value, {'style', 'savedPlaces', 'lighting'});
    final style = map['style'];
    if ((style != null && !GlobeMapStyle.values.any((e) => e.name == style)) ||
        (map['savedPlaces'] != null && map['savedPlaces'] is! bool) ||
        (map['lighting'] != null && map['lighting'] is! bool)) {
      throw const FormatException('Ungültige Kartenstartwerte');
    }
    return ActivityMapDefaults(
      style: style == null
          ? null
          : GlobeMapStyle.values.byName(style as String),
      savedPlaces: map['savedPlaces'] as bool?,
      lighting: map['lighting'] as bool?,
    );
  }
}

class ActivityProfile {
  ActivityProfile({
    required this.id,
    required this.name,
    this.map = const ActivityMapDefaults(),
    Iterable<ActivityTool> tools = const [],
    Iterable<ActivityAction> actions = const [],
    Iterable<ActivityLayer> layers = const [],
  }) : tools = List.unmodifiable(tools),
       actions = List.unmodifiable(actions),
       layers = List.unmodifiable(layers);

  final String id, name;
  final ActivityMapDefaults map;
  final List<ActivityTool> tools;
  final List<ActivityAction> actions;
  final List<ActivityLayer> layers;

  ActivityProfile copyWith({String? id, String? name}) => ActivityProfile(
    id: id ?? this.id,
    name: name ?? this.name,
    map: map,
    tools: tools,
    actions: actions,
    layers: layers,
  );

  Map<String, dynamic> toJson({bool portable = false}) => {
    if (!portable) 'id': id,
    'name': name,
    'map': map.toJson(),
    'tools': tools.map((e) => e.name).toList(),
    'actions': actions.map((e) => e.name).toList(),
    'layers': layers.map((e) => e.name).toList(),
  };

  factory ActivityProfile.fromJson(Object? value, {String? importedId}) {
    final map = _object(value, {
      'name',
      'map',
      'tools',
      'actions',
      'layers',
      if (importedId == null) 'id',
    });
    return ActivityProfile(
      id: _text(importedId ?? map['id'], 64),
      name: _text(map['name'], 64),
      map: ActivityMapDefaults.fromJson(map['map']),
      tools: _enums(map['tools'], ActivityTool.values),
      actions: _enums(map['actions'], ActivityAction.values),
      layers: _enums(map['layers'], ActivityLayer.values),
    );
  }
}

class ActivityProfileCatalog {
  ActivityProfileCatalog({
    required Iterable<ActivityProfile> profiles,
    this.selectedId,
    this.firstUseDone = false,
  }) : profiles = List.unmodifiable(profiles);
  final List<ActivityProfile> profiles;
  final String? selectedId;
  final bool firstUseDone;
  ActivityProfile? get selected =>
      profiles.where((p) => p.id == selectedId).firstOrNull;

  String encode() => jsonEncode({
    'version': 1,
    'profiles': profiles.map((p) => p.toJson()).toList(),
    'selectedId': selectedId,
    'firstUseDone': firstUseDone,
  });

  factory ActivityProfileCatalog.decode(String source) {
    final map = _object(_decode(source), {
      'version',
      'profiles',
      'selectedId',
      'firstUseDone',
    });
    if (map['version'] is! int || map['version'] != 1) {
      throw const FormatException('Nicht unterstützte Profilversion');
    }
    final items = map['profiles'];
    if (items is! List ||
        items.length > activityProfileMaxCount ||
        map['firstUseDone'] is! bool) {
      throw const FormatException('Ungültige Profilsammlung');
    }
    final profiles = items.map((p) => ActivityProfile.fromJson(p)).toList();
    final ids = profiles.map((p) => p.id).toSet();
    if (ids.length != profiles.length ||
        (map['selectedId'] != null && !ids.contains(map['selectedId']))) {
      throw const FormatException('Ungültige Profilauswahl');
    }
    return ActivityProfileCatalog(
      profiles: profiles,
      selectedId: map['selectedId'] as String?,
      firstUseDone: map['firstUseDone'] as bool,
    );
  }

  factory ActivityProfileCatalog.initial() =>
      ActivityProfileCatalog(profiles: activityProfileTemplates());
}

List<ActivityProfile> activityProfileTemplates() {
  ActivityProfile preset(
    String id,
    String name,
    List<ActivityTool> tools,
    List<ActivityLayer> layers, {
    bool fpv = false,
  }) => ActivityProfile(
    id: id,
    name: name,
    map: ActivityMapDefaults(
      style: fpv ? GlobeMapStyle.satellite : GlobeMapStyle.topographic,
      savedPlaces: true,
    ),
    tools: tools,
    actions: [
      ActivityAction.search,
      ActivityAction.layers,
      ActivityAction.location,
      if (fpv) ActivityAction.ground,
      if (fpv) ActivityAction.simulation,
      ActivityAction.weather,
    ],
    layers: layers,
  );
  return [
    preset(
      'fpv',
      'FPV',
      [
        ActivityTool.places,
        ActivityTool.routes,
        ActivityTool.preflight,
        ActivityTool.weather,
        ActivityTool.equipment,
      ],
      [ActivityLayer.airspace, ActivityLayer.obstacles, ActivityLayer.wind],
      fpv: true,
    ),
    preset(
      'hiking',
      'Wandern',
      [
        ActivityTool.groundRoutes,
        ActivityTool.places,
        ActivityTool.observations,
        ActivityTool.weather,
        ActivityTool.offline,
      ],
      [ActivityLayer.roads, ActivityLayer.avalanche, ActivityLayer.wind],
    ),
    preset(
      'cycling',
      'Radfahren',
      [
        ActivityTool.groundRoutes,
        ActivityTool.mobility,
        ActivityTool.places,
        ActivityTool.observations,
        ActivityTool.weather,
      ],
      [ActivityLayer.roads, ActivityLayer.labels],
    ),
    preset(
      'photography',
      'Fotografie',
      [ActivityTool.places, ActivityTool.weather, ActivityTool.offline],
      [ActivityLayer.buildings, ActivityLayer.vegetation],
    ),
    preset(
      'family',
      'Familie',
      [ActivityTool.places, ActivityTool.mobility, ActivityTool.weather],
      [ActivityLayer.roads, ActivityLayer.labels],
    ),
    preset(
      'explore',
      'Entdecken',
      [
        ActivityTool.places,
        ActivityTool.mobility,
        ActivityTool.weather,
        ActivityTool.offline,
      ],
      [ActivityLayer.roads, ActivityLayer.labels, ActivityLayer.buildings],
    ),
  ];
}

String encodeActivityProfile(ActivityProfile profile) => jsonEncode({
  'format': 'fpvmanager-activity-profile',
  'version': 1,
  'profile': profile.toJson(portable: true),
});

ActivityProfile decodeActivityProfile(String source) {
  final map = _object(_decode(source), {'format', 'version', 'profile'});
  if (map['format'] != 'fpvmanager-activity-profile' ||
      map['version'] is! int ||
      map['version'] != 1) {
    throw const FormatException(
      'Nicht unterstütztes Profilformat oder Version',
    );
  }
  return ActivityProfile.fromJson(
    map['profile'],
    importedId: newActivityProfileId(),
  );
}

Object? _decode(String source) {
  if (source.length > activityProfileMaxBytes ||
      utf8.encode(source).length > activityProfileMaxBytes) {
    throw const FormatException('Profildatei ist zu groß (maximal 128 KiB)');
  }
  var depth = 0, quoted = false, escaped = false;
  for (final c in source.codeUnits) {
    if (quoted) {
      if (escaped) {
        escaped = false;
      } else if (c == 92) {
        escaped = true;
      } else if (c == 34) {
        quoted = false;
      }
    } else if (c == 34) {
      quoted = true;
    } else if (c == 91 || c == 123) {
      if (++depth > 12) {
        throw const FormatException('Profildatei ist zu tief verschachtelt');
      }
    } else if (c == 93 || c == 125) {
      depth--;
    }
  }
  return jsonDecode(source);
}

Map<String, dynamic> _object(Object? value, Set<String> keys) {
  if (value is! Map<String, dynamic> ||
      value.keys.any((k) => !keys.contains(k)) ||
      keys.any((k) => !value.containsKey(k))) {
    throw const FormatException('Unbekannte oder fehlende Profilfelder');
  }
  return value;
}

String _text(Object? value, int limit) {
  if (value is! String ||
      value.trim().isEmpty ||
      value.length > limit ||
      RegExp(r'[\x00-\x1f\x7f]').hasMatch(value)) {
    throw const FormatException('Ungültiger Profilname oder Bezeichner');
  }
  return value.trim();
}

List<T> _enums<T extends Enum>(Object? value, List<T> allowed) {
  if (value is! List ||
      value.length > allowed.length ||
      value.toSet().length != value.length ||
      value.any((e) => !allowed.any((a) => a.name == e))) {
    throw const FormatException('Unbekannte oder doppelte Profiloptionen');
  }
  return value.map((e) => allowed.byName(e as String)).toList();
}
