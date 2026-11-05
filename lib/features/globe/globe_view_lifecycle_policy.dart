/// Keeps connection ownership separate from document refresh decisions.
///
/// A cache revision or visual preference may reload Cesium's document, but
/// must not detach and reattach an unchanged Flutter controller.
class GlobeViewLifecyclePolicy {
  const GlobeViewLifecyclePolicy._();

  static bool reconnectBridge(Object previous, Object next) =>
      !identical(previous, next);

  static bool reloadDocument({
    required bool controllerChanged,
    required bool previousCachedMaps,
    required bool cachedMaps,
    required int previousCacheRevision,
    required int cacheRevision,
    required bool previousFloatingControls,
    required bool floatingControls,
  }) =>
      controllerChanged ||
      previousCachedMaps != cachedMaps ||
      previousCacheRevision != cacheRevision ||
      previousFloatingControls != floatingControls;
}
