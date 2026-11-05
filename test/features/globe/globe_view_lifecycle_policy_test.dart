import 'package:flutter_test/flutter_test.dart';
import 'package:fpvmanager/features/globe/globe_view_lifecycle_policy.dart';

void main() {
  test('cache and view changes never require bridge reconnection', () {
    final controller = Object();
    expect(
      GlobeViewLifecyclePolicy.reconnectBridge(controller, controller),
      isFalse,
    );
    for (final changes in <(bool, int, bool)>[
      (true, 0, false),
      (false, 1, false),
      (false, 0, true),
      (true, 1, true),
    ]) {
      expect(
        GlobeViewLifecyclePolicy.reloadDocument(
          controllerChanged: false,
          previousCachedMaps: false,
          cachedMaps: changes.$1,
          previousCacheRevision: 0,
          cacheRevision: changes.$2,
          previousFloatingControls: false,
          floatingControls: changes.$3,
        ),
        isTrue,
      );
    }
  });

  test('changing only menu focus never reloads Cesium', () {
    expect(
      GlobeViewLifecyclePolicy.reloadDocument(
        controllerChanged: false,
        previousCachedMaps: true,
        cachedMaps: true,
        previousCacheRevision: 10,
        cacheRevision: 10,
        previousFloatingControls: true,
        floatingControls: true,
      ),
      isFalse,
    );
  });

  test('replacing controller requires a new bridge and renderer session', () {
    final old = Object();
    final next = Object();
    expect(GlobeViewLifecyclePolicy.reconnectBridge(old, next), isTrue);
    expect(
      GlobeViewLifecyclePolicy.reloadDocument(
        controllerChanged: true,
        previousCachedMaps: false,
        cachedMaps: false,
        previousCacheRevision: 0,
        cacheRevision: 0,
        previousFloatingControls: false,
        floatingControls: false,
      ),
      isTrue,
    );
  });
}
