import 'radio_analysis.dart';

/// A geometric terrain assessment is not a measurement or prediction of RF
/// control/video reception. Consumers must not infer link loss from this type.
enum LivePathVisibility { unknown, clear, fresnelIntrusion, obstructed }

enum LiveAssessmentSource { unavailable, sampledTerrain }

enum LiveAssessmentConfidence { unavailable, limited, approximate }

enum LiveRadioQuality { unknown }

/// Shared, immutable input for later HUD/failsafe features.
///
/// RC and video quality stay independent and unknown until an explicit radio
/// propagation model is configured. LOS/Fresnel results must never by
/// themselves trigger simulated failsafe or claim an RSSI/LQ value.
class LiveLinkAssessment {
  const LiveLinkAssessment({
    this.visibility = LivePathVisibility.unknown,
    this.source = LiveAssessmentSource.unavailable,
    this.confidence = LiveAssessmentConfidence.unavailable,
    this.rcQuality = LiveRadioQuality.unknown,
    this.videoQuality = LiveRadioQuality.unknown,
    this.sampledAt,
    this.sampleCount = 0,
    this.samplingTier,
    this.maximumSampleGapMeters,
    this.minimumClearanceMeters,
    this.minimumFresnelMarginMeters,
  });

  final LivePathVisibility visibility;
  final LiveAssessmentSource source;
  final LiveAssessmentConfidence confidence;
  final LiveRadioQuality rcQuality;
  final LiveRadioQuality videoQuality;
  final DateTime? sampledAt;
  final int sampleCount;
  final String? samplingTier;
  final double? maximumSampleGapMeters;
  final double? minimumClearanceMeters;
  final double? minimumFresnelMarginMeters;

  bool get hasCurrentGeometry =>
      source == LiveAssessmentSource.sampledTerrain &&
      visibility != LivePathVisibility.unknown;

  /// Stable, presentation-agnostic snapshot for the WebGL HUD bridge.
  /// In particular, unknown RC/video values cannot masquerade as a loss event.
  Map<String, Object?> toJson() => {
    'visibility': visibility.name,
    'source': source.name,
    'confidence': confidence.name,
    'controlLink': rcQuality.name,
    'videoLink': videoQuality.name,
    'sampledAtMs': sampledAt?.millisecondsSinceEpoch,
    'sampleCount': sampleCount,
    'samplingTier': samplingTier,
    'maximumSampleGapMeters': maximumSampleGapMeters,
    'minimumClearanceMeters': minimumClearanceMeters,
    'minimumFresnelMarginMeters': minimumFresnelMarginMeters,
  };

  factory LiveLinkAssessment.fromTerrainProfile(
    RadioPathResult result, {
    required DateTime sampledAt,
    bool coverageLimited = false,
    double? maximumSampleGapMeters,
    String? samplingTier,
  }) => LiveLinkAssessment(
    visibility: switch (result.state) {
      RadioPathState.unknown => LivePathVisibility.unknown,
      RadioPathState.obstructed => LivePathVisibility.obstructed,
      RadioPathState.fresnelIntrusion => LivePathVisibility.fresnelIntrusion,
      RadioPathState.noSampledObstruction => LivePathVisibility.clear,
    },
    source: result.state == RadioPathState.unknown
        ? LiveAssessmentSource.unavailable
        : LiveAssessmentSource.sampledTerrain,
    confidence: result.state == RadioPathState.unknown
        ? LiveAssessmentConfidence.unavailable
        : coverageLimited
        ? LiveAssessmentConfidence.limited
        : LiveAssessmentConfidence.approximate,
    sampledAt: sampledAt,
    sampleCount: result.profile.length,
    samplingTier: samplingTier,
    maximumSampleGapMeters: maximumSampleGapMeters,
    minimumClearanceMeters: result.minimumClearance,
    minimumFresnelMarginMeters: result.minimumFresnelClearance,
  );
}
