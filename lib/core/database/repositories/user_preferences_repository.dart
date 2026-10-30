import 'dart:convert';

import 'package:drift/drift.dart';

import '../../models/user_preferences.dart';
import '../../../features/obstacles/obstacle_models.dart';
import '../fpv_database.dart';

abstract interface class UserPreferencesRepository {
  static UserPreferences validatePersistedRows(List<AppSetting> rows) =>
      DriftUserPreferencesRepository._read(rows);
  const factory UserPreferencesRepository(FpvDatabase database) =
      DriftUserPreferencesRepository;

  Future<UserPreferences> getPreferences();
  Stream<UserPreferences> watchPreferences();
  Future<void> savePreferences(UserPreferences preferences);
  Future<void> resetPreferences();
}

/// Local preferences only. Unknown settings are preserved; malformed owned
/// settings raise FormatException so callers can offer explicit recovery.
final class DriftUserPreferencesRepository
    implements UserPreferencesRepository {
  const DriftUserPreferencesRepository(this._database);
  final FpvDatabase _database;
  static const _style = 'map.style';
  static const _visible = 'map.uas.visible';
  static const _opacity = 'map.uas.fillOpacity';
  static const _spotsVisible = 'map.spots.visible';
  static const _touchControls = 'simulation.touchControls.visible';
  static const _roadsVisible = 'map.roads.visible';
  static const _roadsOpacity = 'map.roads.opacity';
  static const _avalancheVisible = 'map.avalanche.visible';
  static const _avalancheOpacity = 'map.avalanche.opacity';
  static const _buildings = 'map.scene.buildings';
  static const _vegetation = 'map.scene.vegetation';
  static const _lighting = 'map.scene.lighting';
  static const _order = 'map.overlayOrder';
  static const _wmsVisible = 'map.obstacles.wms.visible';
  static const _wmsOpacity = 'map.obstacles.wms.opacity';
  static const _vectorsVisible = 'map.obstacles.vectors.visible';
  static const _modelsVisible = 'map.obstacles.vectors.models';
  static const _categories = 'map.obstacles.vectors.categories';
  static const _hazards = 'map.obstacles.hazards.visible';
  static const _buffer = 'map.obstacles.hazards.bufferMeters';
  static const _keys = [
    _style,
    _visible,
    _opacity,
    _spotsVisible,
    _touchControls,
    _order,
    _roadsVisible,
    _roadsOpacity,
    _avalancheVisible,
    _avalancheOpacity,
    _buildings,
    _vegetation,
    _lighting,
    _wmsVisible,
    _wmsOpacity,
    _vectorsVisible,
    _modelsVisible,
    _categories,
    _hazards,
    _buffer,
  ];

  SimpleSelectStatement<$AppSettingsTable, AppSetting> _query() =>
      _database.select(_database.appSettings)
        ..where((table) => table.key.isIn(_keys));

  static UserPreferences _read(List<AppSetting> rows) {
    final values = {for (final row in rows) row.key: row.value};
    const defaults = UserPreferences();
    try {
      final style = values[_style];
      final visible = values[_visible];
      final opacity = values[_opacity];
      final spotsVisible = values[_spotsVisible];
      if (spotsVisible != null &&
          spotsVisible != 'true' &&
          spotsVisible != 'false') {
        throw const FormatException('Invalid saved spots visibility setting');
      }
      final rawOrder = values[_order];
      final decodedOrder = rawOrder == null ? null : jsonDecode(rawOrder);
      if (decodedOrder != null &&
          (decodedOrder is! List ||
              decodedOrder.any((item) => item is! String))) {
        throw const FormatException('Invalid overlay order setting');
      }
      if (rawOrder != null && decodedOrder == null) {
        throw const FormatException('Invalid overlay order setting');
      }
      final order = decodedOrder == null
          ? defaults.overlayOrder
          : (decodedOrder as List)
                .map((item) => GlobeOverlay.values.byName(item as String))
                .toList();
      UserPreferences.validateOverlayOrder(order);
      if (visible != null && visible != 'true' && visible != 'false') {
        throw const FormatException('Invalid UAS visibility setting');
      }
      final parsedOpacity = opacity == null
          ? defaults.uasZonesFillOpacity
          : double.parse(opacity);
      _validateOpacity(parsedOpacity);
      final avalancheOpacity = values[_avalancheOpacity] == null
          ? defaults.avalancheOpacity
          : double.parse(values[_avalancheOpacity]!);
      _validateOpacity(avalancheOpacity);
      bool readBool(String key, bool fallback) {
        final value = values[key];
        if (value == null) return fallback;
        if (value != 'true' && value != 'false') {
          throw FormatException('Invalid $key');
        }
        return value == 'true';
      }

      final roadsOpacity = values[_roadsOpacity] == null
          ? defaults.roadsOpacity
          : double.parse(values[_roadsOpacity]!);
      _validateOpacity(roadsOpacity);
      final wmsOpacity = values[_wmsOpacity] == null
          ? defaults.obstacleWmsOpacity
          : double.parse(values[_wmsOpacity]!);
      _validateOpacity(wmsOpacity);
      final rawCategories = values[_categories] == null
          ? null
          : jsonDecode(values[_categories]!);
      if (rawCategories != null &&
          (rawCategories is! List ||
              rawCategories.any((c) => c is! String) ||
              rawCategories.toSet().length != rawCategories.length)) {
        throw const FormatException('Invalid obstacle category setting');
      }
      if (values[_categories] != null && rawCategories == null) {
        throw const FormatException('Invalid obstacle category setting');
      }
      final categories = rawCategories == null
          ? defaults.obstacleCategories
          : (rawCategories as List)
                .map((c) => ObstacleCategory.values.byName(c as String))
                .toSet();
      final buffer = values[_buffer] == null
          ? defaults.obstacleBufferMeters
          : double.parse(values[_buffer]!);
      UserPreferences.validateObstacleBuffer(buffer);
      return UserPreferences(
        mapStyle: style == null
            ? defaults.mapStyle
            : GlobeMapStyle.values.byName(style),
        uasZonesVisible: visible == null
            ? defaults.uasZonesVisible
            : visible == 'true',
        uasZonesFillOpacity: parsedOpacity,
        savedSpotsVisible: spotsVisible == null
            ? defaults.savedSpotsVisible
            : spotsVisible == 'true',
        roadsVisible: readBool(_roadsVisible, defaults.roadsVisible),
        touchControlsVisible: readBool(
          _touchControls,
          defaults.touchControlsVisible,
        ),
        roadsOpacity: roadsOpacity,
        avalancheVisible: readBool(
          _avalancheVisible,
          defaults.avalancheVisible,
        ),
        avalancheOpacity: avalancheOpacity,
        buildings3dVisible: readBool(_buildings, defaults.buildings3dVisible),
        vegetation3dVisible: readBool(
          _vegetation,
          defaults.vegetation3dVisible,
        ),
        realisticLighting: readBool(_lighting, defaults.realisticLighting),
        obstacleWmsVisible: readBool(_wmsVisible, defaults.obstacleWmsVisible),
        obstacleWmsOpacity: wmsOpacity,
        obstacleVectorsVisible: readBool(
          _vectorsVisible,
          defaults.obstacleVectorsVisible,
        ),
        obstacleCategories: Set.unmodifiable(categories),
        obstacleModelsVisible: readBool(
          _modelsVisible,
          defaults.obstacleModelsVisible,
        ),
        hazardAreasVisible: readBool(_hazards, defaults.hazardAreasVisible),
        obstacleBufferMeters: buffer,
        overlayOrder: List.unmodifiable(order),
      );
    } on ArgumentError catch (error) {
      throw FormatException('Invalid stored preferences: $error');
    }
  }

  static void _validateOpacity(double opacity) {
    if (!opacity.isFinite || opacity < 0 || opacity > 1) {
      throw ArgumentError('UAS opacity must be finite and between 0 and 1');
    }
  }

  @override
  Future<UserPreferences> getPreferences() async => _read(await _query().get());

  @override
  Stream<UserPreferences> watchPreferences() => _query().watch().map(_read);

  @override
  Future<void> savePreferences(UserPreferences preferences) {
    final snapshot = preferences.copyWith();
    _validateOpacity(snapshot.uasZonesFillOpacity);
    _validateOpacity(snapshot.obstacleWmsOpacity);
    _validateOpacity(snapshot.roadsOpacity);
    _validateOpacity(snapshot.avalancheOpacity);
    UserPreferences.validateObstacleBuffer(snapshot.obstacleBufferMeters);
    UserPreferences.validateOverlayOrder(snapshot.overlayOrder);
    final updatedAt = DateTime.now().toUtc();
    return _database.transaction(() async {
      await _database.batch((batch) {
        batch.insertAllOnConflictUpdate(_database.appSettings, [
          for (final entry in {
            _style: snapshot.mapStyle.name,
            _visible: snapshot.uasZonesVisible.toString(),
            _opacity: snapshot.uasZonesFillOpacity.toString(),
            _spotsVisible: snapshot.savedSpotsVisible.toString(),
            _roadsVisible: snapshot.roadsVisible.toString(),
            _roadsOpacity: snapshot.roadsOpacity.toString(),
            _touchControls: snapshot.touchControlsVisible.toString(),
            _avalancheVisible: snapshot.avalancheVisible.toString(),
            _avalancheOpacity: snapshot.avalancheOpacity.toString(),
            _buildings: snapshot.buildings3dVisible.toString(),
            _vegetation: snapshot.vegetation3dVisible.toString(),
            _lighting: snapshot.realisticLighting.toString(),
            _wmsVisible: snapshot.obstacleWmsVisible.toString(),
            _wmsOpacity: snapshot.obstacleWmsOpacity.toString(),
            _vectorsVisible: snapshot.obstacleVectorsVisible.toString(),
            _modelsVisible: snapshot.obstacleModelsVisible.toString(),
            _hazards: snapshot.hazardAreasVisible.toString(),
            _buffer: snapshot.obstacleBufferMeters.toString(),
            _categories: jsonEncode(
              snapshot.obstacleCategories.map((c) => c.name).toList()..sort(),
            ),
            _order: jsonEncode(
              snapshot.overlayOrder.map((item) => item.name).toList(),
            ),
          }.entries)
            AppSettingsCompanion.insert(
              key: entry.key,
              value: entry.value,
              updatedAt: Value(updatedAt),
            ),
        ]);
      });
    });
  }

  @override
  Future<void> resetPreferences() => (_database.delete(
    _database.appSettings,
  )..where((table) => table.key.isIn(_keys))).go();
}
