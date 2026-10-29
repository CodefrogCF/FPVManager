import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/models/user_preferences.dart';
import '../../core/osint/osint_provider_state.dart';
import '../../core/osint/osint_source.dart';
import 'avalanche_bulletin.dart';
import 'avalanche_provider.dart';

class AvalancheMapController extends ChangeNotifier {
  AvalancheMapController({
    required this.provider,
    required this.send,
    required this.preferences,
    required this.savePreferences,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now {
    provider.addListener(_changed);
  }
  final AvalancheProvider provider;
  final Future<void> Function(Map<String, dynamic>) send;
  final UserPreferences Function() preferences;
  final Future<void> Function(UserPreferences) savePreferences;
  final DateTime Function() _now;
  bool visible = false, loading = false;
  double opacity = .35;
  String period = 'all';
  String? error;
  bool _disposed = false;
  int _epoch = 0;
  Timer? _clock;
  Timer? _cooldown;
  int get refreshWaitSeconds => provider.retryAfterSeconds;
  String? _displayKey;
  OsintProviderState<Map<String, dynamic>> get status => provider.status;
  OsintDataState get dataState {
    final state = status;
    final data = state.dataset;
    if (data == null) return OsintDataState.unavailable;
    if (state.error != null) return OsintDataState.refreshFailed;
    if (data.freshnessAt(_now()) == OsintFreshness.clockSkew) {
      return OsintDataState.clockSkew;
    }
    if (data.validity?.at(_now()) == OsintValidity.expired) {
      return OsintDataState.expired;
    }
    if (data.validity?.at(_now()) == OsintValidity.notYetValid) {
      return OsintDataState.unavailable;
    }
    return data.freshnessAt(_now()) == OsintFreshness.fresh &&
            !data.requiresRevalidation
        ? OsintDataState.fresh
        : OsintDataState.stale;
  }

  String get message {
    if (status.dataset == null) return 'Kein Lawinenbulletin geladen';
    if (status.dataset!.validity?.at(_now()) == OsintValidity.notYetValid) {
      return 'Bulletin noch nicht gültig · derzeit keine gültige Karte';
    }
    if (dataState == OsintDataState.expired) {
      return 'Bulletin abgelaufen · keine aktuelle Lawinenbeurteilung';
    }
    if (dataState != OsintDataState.fresh) {
      return 'Veralteter / nicht bestätigter Stand · aktuelle Lage prüfen';
    }
    if (status.dataset!.data['empty'] == true) {
      return 'Kein aktives Bulletin veröffentlicht · keine Entwarnung';
    }
    return 'Publiziertes Bulletin · Höhenlagen und Tagesabschnitte beachten';
  }

  Map<String, dynamic> command() => {
    'id': 'avalanche',
    'visible': visible,
    'opacity': opacity,
    'stale': dataState != OsintDataState.fresh,
    'features': !visible || status.dataset == null
        ? <Map<String, dynamic>>[]
        : avalancheFeatures(
            status.dataset!.data,
            stale: dataState != OsintDataState.fresh,
            period: period,
          ),
  };
  void _changed() {
    if (_disposed) return;
    _updateCooldown();
    notifyListeners();
  }

  void _updateCooldown() {
    if (!visible || _disposed || refreshWaitSeconds == 0) {
      _cooldown?.cancel();
      _cooldown = null;
      return;
    }
    _cooldown ??= Timer.periodic(const Duration(seconds: 1), (_) => _changed());
  }

  Future<void> _push({bool force = false}) async {
    if (_disposed) return;
    final data = status.dataset;
    final key =
        '$visible:$opacity:$period:${data?.fetchedAtUtc}:${data?.lastCheckedAtUtc}:$dataState';
    if (!force && _displayKey == key) return;
    try {
      await send(command());
      if (!_disposed) _displayKey = key;
    } catch (_) {
      if (!_disposed) {
        error =
            'Lawinenkarte konnte nicht dargestellt werden. Erneut versuchen.';
      }
    }
    _changed();
  }

  void _schedule() {
    _updateCooldown();
    _clock?.cancel();
    _clock = null;
    if (visible && !_disposed) {
      _clock = Timer.periodic(
        const Duration(minutes: 1),
        (_) => unawaited(_push()),
      );
    }
  }

  Future<void> options({
    bool? enabled,
    double? alpha,
    String? selectedPeriod,
  }) async {
    if (_disposed) return;
    final value = alpha ?? opacity;
    if (!value.isFinite ||
        value < 0 ||
        value > 1 ||
        !{'all', 'earlier', 'later'}.contains(selectedPeriod ?? period)) {
      throw ArgumentError('Ungültige Lawinenkarten-Einstellung');
    }
    visible = enabled ?? visible;
    opacity = value;
    period = selectedPeriod ?? period;
    await savePreferences(
      preferences().copyWith(
        avalancheVisible: visible,
        avalancheOpacity: opacity,
      ),
    );
    _schedule();
    _changed();
    if (visible && status.dataset == null) {
      await refresh(force: false);
    } else {
      await _push();
    }
  }

  Future<void> restore(bool enabled, double alpha) async {
    final wasVisible = visible;
    visible = enabled;
    opacity = alpha;
    _schedule();
    if (visible) {
      await provider.loadCached();
    }
    if (visible || wasVisible) await _push(force: true);
    _changed();
  }

  Future<void> refresh({bool force = true}) async {
    if (_disposed || loading) return;
    if (refreshWaitSeconds > 0) {
      _changed();
      return;
    }
    final epoch = ++_epoch;
    loading = true;
    error = null;
    _changed();
    try {
      if (!force && status.dataset == null) {
        await provider.loadCached();
        await _push();
      }
      if (_disposed || epoch != _epoch) return;
      await provider.fetch(forceRefresh: force);
    } catch (_) {
      if (!_disposed && epoch == _epoch) error = status.error?.message ?? 'SLF-Bulletin nicht verfügbar. Vorhandene Daten bleiben als alter Stand erkennbar.';
    } finally {
      if (!_disposed && epoch == _epoch) {
        loading = false;
        await _push(force: true);
        _changed();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    ++_epoch;
    _clock?.cancel();
    _cooldown?.cancel();
    provider.removeListener(_changed);
    provider.dispose();
    super.dispose();
  }
}
