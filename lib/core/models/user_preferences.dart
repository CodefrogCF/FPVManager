import '../../features/obstacles/obstacle_models.dart';
import 'outdoor_layer.dart';

enum GlobeMapStyle { satellite, topographic, relief }

enum GlobeOverlay { uasZones, savedSpots }

enum NavigationEnvironmentMode {
  inherit,
  disabled,
  enabled;

  bool? get override => switch (this) {
    inherit => null,
    disabled => false,
    enabled => true,
  };
}

/// Preferences supported by the current map. Reading alone never writes defaults.
class UserPreferences {
  const UserPreferences({
    this.mapStyle = GlobeMapStyle.satellite,
    this.outdoorLayers = const {},
    this.uasZonesVisible = false,
    this.uasZonesFillOpacity = 0.20,
    this.savedSpotsVisible = true,
    this.touchControlsVisible = true,
    this.roadsVisible = false,
    this.labelsVisible = false,
    this.roadsOpacity = .8,
    this.avalancheVisible = false,
    this.avalancheOpacity = .35,
    this.buildings3dVisible = false,
    this.vegetation3dVisible = false,
    this.realisticLighting = false,
    this.navigationBuildings = NavigationEnvironmentMode.inherit,
    this.navigationVegetation = NavigationEnvironmentMode.inherit,
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
  final Map<OutdoorLayer, OutdoorLayerPreference> outdoorLayers;
  final bool uasZonesVisible;
  final double uasZonesFillOpacity;
  final bool savedSpotsVisible;
  final bool touchControlsVisible;
  final bool roadsVisible;
  final bool labelsVisible;
  final double roadsOpacity;
  final bool avalancheVisible;
  final double avalancheOpacity;
  final bool buildings3dVisible, vegetation3dVisible, realisticLighting;
  final NavigationEnvironmentMode navigationBuildings, navigationVegetation;
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
    Map<OutdoorLayer, OutdoorLayerPreference>? outdoorLayers,
    bool? uasZonesVisible,
    double? uasZonesFillOpacity,
    bool? savedSpotsVisible,
    bool? touchControlsVisible,
    bool? roadsVisible,
    bool? labelsVisible,
    double? roadsOpacity,
    bool? avalancheVisible,
    double? avalancheOpacity,
    bool? buildings3dVisible,
    bool? vegetation3dVisible,
    bool? realisticLighting,
    NavigationEnvironmentMode? navigationBuildings,
    NavigationEnvironmentMode? navigationVegetation,
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
    outdoorLayers: Map.unmodifiable(outdoorLayers ?? this.outdoorLayers),
    uasZonesVisible: uasZonesVisible ?? this.uasZonesVisible,
    uasZonesFillOpacity: uasZonesFillOpacity ?? this.uasZonesFillOpacity,
    savedSpotsVisible: savedSpotsVisible ?? this.savedSpotsVisible,
    touchControlsVisible: touchControlsVisible ?? this.touchControlsVisible,
    roadsVisible: roadsVisible ?? this.roadsVisible,
    labelsVisible: labelsVisible ?? this.labelsVisible,
    roadsOpacity: roadsOpacity ?? this.roadsOpacity,
    avalancheVisible: avalancheVisible ?? this.avalancheVisible,
    avalancheOpacity: avalancheOpacity ?? this.avalancheOpacity,
    buildings3dVisible: buildings3dVisible ?? this.buildings3dVisible,
    vegetation3dVisible: vegetation3dVisible ?? this.vegetation3dVisible,
    realisticLighting: realisticLighting ?? this.realisticLighting,
    navigationBuildings: navigationBuildings ?? this.navigationBuildings,
    navigationVegetation: navigationVegetation ?? this.navigationVegetation,
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
