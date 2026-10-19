enum GlobeMapStyle { satellite, topographic, relief }

/// Preferences supported by the current map. Reading alone never writes defaults.
class UserPreferences {
  const UserPreferences({
    this.mapStyle = GlobeMapStyle.satellite,
    this.uasZonesVisible = false,
    this.uasZonesFillOpacity = 0.20,
  });

  final GlobeMapStyle mapStyle;
  final bool uasZonesVisible;
  final double uasZonesFillOpacity;
}
