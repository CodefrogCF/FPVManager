import '../../features/obstacles/obstacle_models.dart';

enum GlobeMapStyle { satellite, topographic, relief }

enum GlobeOverlay { uasZones, savedSpots }

/// Preferences supported by the current map. Reading alone never writes defaults.
class UserPreferences {
  const UserPreferences({
    this.mapStyle = GlobeMapStyle.satellite,
    this.uasZonesVisible = false,
    this.uasZonesFillOpacity = 0.20,
    this.savedSpotsVisible = true,
    this.roadsVisible = false,
    this.roadsOpacity = .8,
    this.avalancheVisible = false,
    this.avalancheOpacity = .35,
    this.buildings3dVisible = false,
    this.vegetation3dVisible = false,
    this.realisticLighting = false,
    this.obstacleWmsVisible = false,
    this.obstacleWmsOpacity = 0.8,
    this.obstacleVectorsVisible = false,
    this.obstacleModelsVisible = false,
    this.hazardAreasVisible = false,
    this.obstacleBufferMeters = 30,
    this.obstacleCategories = const {...ObstacleCategory.values},
    this.overlayOrder = const [GlobeOverlay.uasZones, GlobeOverlay.savedSpots],
  });

  final GlobeMapStyle mapStyle;
  final bool uasZonesVisible;
  final double uasZonesFillOpacity;
  final bool savedSpotsVisible;
  final bool roadsVisible;
  final double roadsOpacity;
  final bool avalancheVisible;
  final double avalancheOpacity;
  final bool buildings3dVisible, vegetation3dVisible, realisticLighting;
  final bool obstacleWmsVisible, obstacleVectorsVisible;
  final bool obstacleModelsVisible;
  final double obstacleWmsOpacity;
  final bool hazardAreasVisible;
  final double obstacleBufferMeters;
  final Set<ObstacleCategory> obstacleCategories;

  /// Back to front. Terrain and the selected base map stay below the overlays.
  final List<GlobeOverlay> overlayOrder;

  UserPreferences copyWith({
    GlobeMapStyle? mapStyle,
    bool? uasZonesVisible,
    double? uasZonesFillOpacity,
    bool? savedSpotsVisible,
    bool? roadsVisible,
    double? roadsOpacity,
    bool? avalancheVisible,
    double? avalancheOpacity,
    bool? buildings3dVisible,
    bool? vegetation3dVisible,
    bool? realisticLighting,
    bool? obstacleWmsVisible,
    double? obstacleWmsOpacity,
    bool? obstacleVectorsVisible,
    bool? obstacleModelsVisible,
    bool? hazardAreasVisible,
    double? obstacleBufferMeters,
    Set<ObstacleCategory>? obstacleCategories,
    List<GlobeOverlay>? overlayOrder,
  }) => UserPreferences(
    mapStyle: mapStyle ?? this.mapStyle,
    uasZonesVisible: uasZonesVisible ?? this.uasZonesVisible,
    uasZonesFillOpacity: uasZonesFillOpacity ?? this.uasZonesFillOpacity,
    savedSpotsVisible: savedSpotsVisible ?? this.savedSpotsVisible,
    roadsVisible: roadsVisible ?? this.roadsVisible,
    roadsOpacity: roadsOpacity ?? this.roadsOpacity,
    avalancheVisible: avalancheVisible ?? this.avalancheVisible,
    avalancheOpacity: avalancheOpacity ?? this.avalancheOpacity,
    buildings3dVisible: buildings3dVisible ?? this.buildings3dVisible,
    vegetation3dVisible: vegetation3dVisible ?? this.vegetation3dVisible,
    realisticLighting: realisticLighting ?? this.realisticLighting,
    obstacleWmsVisible: obstacleWmsVisible ?? this.obstacleWmsVisible,
    obstacleWmsOpacity: obstacleWmsOpacity ?? this.obstacleWmsOpacity,
    obstacleVectorsVisible:
        obstacleVectorsVisible ?? this.obstacleVectorsVisible,
    obstacleModelsVisible: obstacleModelsVisible ?? this.obstacleModelsVisible,
    hazardAreasVisible: hazardAreasVisible ?? this.hazardAreasVisible,
    obstacleBufferMeters: obstacleBufferMeters ?? this.obstacleBufferMeters,
    obstacleCategories: Set.unmodifiable(
      obstacleCategories ?? this.obstacleCategories,
    ),
    overlayOrder: List.unmodifiable(overlayOrder ?? this.overlayOrder),
  );

  static void validateOverlayOrder(List<GlobeOverlay> order) {
    if (order.length != GlobeOverlay.values.length ||
        order.toSet().length != GlobeOverlay.values.length) {
      throw ArgumentError('Each supported overlay must occur exactly once');
    }
  }

  static void validateObstacleBuffer(double meters) {
    if (!meters.isFinite || meters < 0 || meters > 1000) {
      throw ArgumentError('Obstacle buffer must be between 0 and 1000 m');
    }
  }
}
