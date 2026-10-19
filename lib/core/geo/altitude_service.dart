import 'geo_coordinate_service.dart';

/// A relative height above local terrain, not a geodetic vertical datum.
class AboveGroundHeight {
  const AboveGroundHeight(this.meters);

  final double meters;
}

/// Calculations at one horizontal position. Callers supply ground at that point.
/// No geoid offsets or implicit datum conversions are applied here.
class AltitudeService {
  const AltitudeService();

  ReferencedElevation fromAboveGround({
    required AboveGroundHeight height,
    required ReferencedElevation ground,
  }) {
    _validate(ground);
    if (!height.meters.isFinite || height.meters < 0) {
      throw ArgumentError('AGL height must be finite and nonnegative');
    }
    final meters = ground.meters + height.meters;
    if (!meters.isFinite) throw ArgumentError('Altitude exceeds numeric range');
    return ReferencedElevation(meters: meters, reference: ground.reference);
  }

  AboveGroundHeight toAboveGround({
    required ReferencedElevation altitude,
    required ReferencedElevation ground,
  }) {
    _validate(altitude);
    _validate(ground);
    if (altitude.reference != ground.reference) {
      throw ArgumentError('Altitude and terrain must use the same datum');
    }
    final meters = altitude.meters - ground.meters;
    if (!meters.isFinite) throw ArgumentError('AGL exceeds numeric range');
    // A negative result explicitly indicates an altitude below the terrain model.
    return AboveGroundHeight(meters);
  }

  void _validate(ReferencedElevation elevation) {
    if (!elevation.meters.isFinite ||
        elevation.reference == VerticalReference.unverified) {
      throw ArgumentError('A finite height with a known datum is required');
    }
  }
}
