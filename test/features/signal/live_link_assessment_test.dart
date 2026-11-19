import 'package:flutter_test/flutter_test.dart';
import 'package:fpvmanager/core/geo/geo_coordinate_service.dart';
import 'package:fpvmanager/features/signal/live_link_assessment.dart';
import 'package:fpvmanager/features/signal/radio_analysis.dart';

void main() {
  const pos = Wgs84Coordinate(latitude: 47, longitude: 8);
  final at = DateTime.utc(2026, 11, 19);
  test('sampled terrain obstruction never implies RC or video loss', () {
    for (final (state, expected) in [
      (RadioPathState.obstructed, LivePathVisibility.obstructed),
      (RadioPathState.fresnelIntrusion, LivePathVisibility.fresnelIntrusion),
      (RadioPathState.noSampledObstruction, LivePathVisibility.clear),
    ]) {
      final assessment = LiveLinkAssessment.fromTerrainProfile(
        RadioPathResult(
          target: pos,
          altitude: 900,
          state: state,
          minimumClearance: -4,
        ),
        sampledAt: at,
      );
      expect(assessment.visibility, expected);
      expect(assessment.hasCurrentGeometry, true);
      expect(assessment.source, LiveAssessmentSource.sampledTerrain);
      expect(assessment.confidence, LiveAssessmentConfidence.approximate);
      expect(assessment.rcQuality, LiveRadioQuality.unknown);
      expect(assessment.videoQuality, LiveRadioQuality.unknown);
      expect(assessment.sampledAt, at);
      expect(assessment.toJson()['controlLink'], 'unknown');
      expect(assessment.toJson()['videoLink'], 'unknown');
    }
  });
  test('unknown data cannot be interpreted as a clear connection', () {
    const assessment = LiveLinkAssessment();
    expect(assessment.hasCurrentGeometry, false);
    expect(assessment.visibility, LivePathVisibility.unknown);
    final unknown = LiveLinkAssessment.fromTerrainProfile(
      const RadioPathResult(target: pos, state: RadioPathState.unknown),
      sampledAt: at,
    );
    expect(unknown.hasCurrentGeometry, false);
    expect(unknown.source, LiveAssessmentSource.unavailable);
  });
}
