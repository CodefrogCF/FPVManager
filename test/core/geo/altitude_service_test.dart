import 'package:flutter_test/flutter_test.dart';
import 'package:fpvmanager/core/geo/altitude_service.dart';
import 'package:fpvmanager/core/geo/geo_coordinate_service.dart';

void main() {
  const service = AltitudeService();
  const ellipsoid = ReferencedElevation(
    meters: 1580,
    reference: VerticalReference.wgs84Ellipsoid,
  );
  const ln02 = ReferencedElevation(
    meters: 1480,
    reference: VerticalReference.ln02,
  );

  test('AGL offsets preserve the ground datum rather than inventing AMSL', () {
    const agl = AboveGroundHeight(120);
    final wgs84 = service.fromAboveGround(height: agl, ground: ellipsoid);
    final swiss = service.fromAboveGround(height: agl, ground: ln02);
    expect(wgs84.meters, 1700);
    expect(wgs84.reference, VerticalReference.wgs84Ellipsoid);
    expect(swiss.meters, 1600);
    expect(swiss.reference, VerticalReference.ln02);
    expect(
      service.toAboveGround(altitude: wgs84, ground: ellipsoid).meters,
      120,
    );
    expect(service.toAboveGround(altitude: swiss, ground: ln02).meters, 120);
  });

  test(
    'ground is zero AGL; an absolute height below terrain is negative AGL',
    () {
      expect(service.toAboveGround(altitude: ln02, ground: ln02).meters, 0);
      expect(
        service
            .toAboveGround(
              altitude: const ReferencedElevation(
                meters: 1470,
                reference: VerticalReference.ln02,
              ),
              ground: ln02,
            )
            .meters,
        -10,
      );
    },
  );

  test('different sea-level datums and ellipsoids cannot be subtracted', () {
    for (final reference in [
      VerticalReference.wgs84Ellipsoid,
      VerticalReference.besselEllipsoid,
      VerticalReference.lhn95,
    ]) {
      expect(
        () => service.toAboveGround(
          altitude: ReferencedElevation(meters: 1600, reference: reference),
          ground: ln02,
        ),
        throwsArgumentError,
      );
    }
  });

  test('unknown or nonfinite ground heights cannot be promoted to a datum', () {
    for (final ground in [
      const ReferencedElevation(
        meters: 1500,
        reference: VerticalReference.unverified,
      ),
      const ReferencedElevation(
        meters: double.nan,
        reference: VerticalReference.ln02,
      ),
      const ReferencedElevation(
        meters: double.infinity,
        reference: VerticalReference.ln02,
      ),
    ]) {
      expect(
        () => service.fromAboveGround(
          height: const AboveGroundHeight(120),
          ground: ground,
        ),
        throwsArgumentError,
      );
      expect(
        () => service.toAboveGround(altitude: ground, ground: ln02),
        throwsArgumentError,
      );
    }
  });

  test('invalid AGL input and overflowing arithmetic are rejected', () {
    for (final meters in [-1.0, double.nan, double.infinity]) {
      expect(
        () => service.fromAboveGround(
          height: AboveGroundHeight(meters),
          ground: ln02,
        ),
        throwsArgumentError,
      );
    }
    const huge = ReferencedElevation(
      meters: 1.7e308,
      reference: VerticalReference.ln02,
    );
    expect(
      () => service.fromAboveGround(
        height: const AboveGroundHeight(1.7e308),
        ground: huge,
      ),
      throwsArgumentError,
    );
    expect(
      () => service.toAboveGround(
        altitude: huge,
        ground: const ReferencedElevation(
          meters: -1.7e308,
          reference: VerticalReference.ln02,
        ),
      ),
      throwsArgumentError,
    );
  });
}
