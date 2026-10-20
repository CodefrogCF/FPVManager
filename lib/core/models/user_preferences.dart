enum GlobeMapStyle { satellite, topographic, relief }

enum GlobeOverlay { uasZones, savedSpots }

/// Preferences supported by the current map. Reading alone never writes defaults.
class UserPreferences {
  const UserPreferences({
    this.mapStyle = GlobeMapStyle.satellite,
    this.uasZonesVisible = false,
    this.uasZonesFillOpacity = 0.20,
    this.savedSpotsVisible = true,
    this.overlayOrder = const [GlobeOverlay.uasZones, GlobeOverlay.savedSpots],
  });

  final GlobeMapStyle mapStyle;
  final bool uasZonesVisible;
  final double uasZonesFillOpacity;
  final bool savedSpotsVisible;

  /// Back to front. Terrain and the selected base map stay below the overlays.
  final List<GlobeOverlay> overlayOrder;

  UserPreferences copyWith({
    GlobeMapStyle? mapStyle,
    bool? uasZonesVisible,
    double? uasZonesFillOpacity,
    bool? savedSpotsVisible,
    List<GlobeOverlay>? overlayOrder,
  }) => UserPreferences(
    mapStyle: mapStyle ?? this.mapStyle,
    uasZonesVisible: uasZonesVisible ?? this.uasZonesVisible,
    uasZonesFillOpacity: uasZonesFillOpacity ?? this.uasZonesFillOpacity,
    savedSpotsVisible: savedSpotsVisible ?? this.savedSpotsVisible,
    overlayOrder: List.unmodifiable(overlayOrder ?? this.overlayOrder),
  );

  static void validateOverlayOrder(List<GlobeOverlay> order) {
    if (order.length != GlobeOverlay.values.length ||
        order.toSet().length != GlobeOverlay.values.length) {
      throw ArgumentError('Each supported overlay must occur exactly once');
    }
  }
}
