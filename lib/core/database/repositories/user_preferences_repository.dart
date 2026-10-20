import 'dart:convert';

import 'package:drift/drift.dart';

import '../../models/user_preferences.dart';
import '../fpv_database.dart';

abstract interface class UserPreferencesRepository {
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
  static const _order = 'map.overlayOrder';
  static const _keys = [_style, _visible, _opacity, _spotsVisible, _order];

  SimpleSelectStatement<$AppSettingsTable, AppSetting> _query() =>
      _database.select(_database.appSettings)
        ..where((table) => table.key.isIn(_keys));

  UserPreferences _read(List<AppSetting> rows) {
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
        overlayOrder: List.unmodifiable(order),
      );
    } on ArgumentError catch (error) {
      throw FormatException('Invalid stored preferences: $error');
    }
  }

  void _validateOpacity(double opacity) {
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
