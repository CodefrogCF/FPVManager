import 'package:flutter_test/flutter_test.dart';
import 'package:fpvmanager/features/signal/rf_profile_settings.dart';
import 'package:fpvmanager/features/signal/live_sampling_policy.dart';
import 'package:fpvmanager/features/signal/live_radio_controller.dart';

void main() {
  test('simulated CE profiles remain independent and validated', () {
    const settings = RfProfileSettings();
    expect(settings.enabled, true);
    expect(settings.video.frequencyMhz, 5800);
    expect(settings.control.frequencyMhz, 868);
    expect(settings.control.eirpDbm, 14);
    expect(settings.videoScenario, RfScenario.eu);
    expect(settings.toJson()['video'], isA<Map<String, double>>());
    expect(settings.toJson()['videoScenario'], 'eu');
    expect(
      () => const RfBandProfile(
        frequencyMhz: 0,
        eirpDbm: 14,
        receiverThresholdDbm: -110,
        fadeMarginDb: 12,
      ).validate(),
      throwsArgumentError,
    );
    expect(const LiveRadioSettings().enabled, true);
  });

  test(
    'theoretical free-space distances respond to frequency and link margin',
    () {
      const reference = RfProfileSettings();
      final videoDistance = reference.video.theoreticalFreeSpaceRangeMeters;
      final rcDistance = reference.control.theoreticalFreeSpaceRangeMeters;
      expect(videoDistance, greaterThan(100));
      expect(rcDistance, greaterThan(videoDistance));
      const legacyBaseline = RfBandProfile(
        frequencyMhz: 5800,
        eirpDbm: 14,
        receiverThresholdDbm: -105,
        fadeMarginDb: 12,
      );
      const stronger = RfBandProfile(
        frequencyMhz: 5800,
        eirpDbm: 20,
        receiverThresholdDbm: -105,
        fadeMarginDb: 12,
      );
      expect(
        stronger.theoreticalFreeSpaceRangeMeters,
        closeTo(
          legacyBaseline.theoreticalFreeSpaceRangeMeters * 1.995262315,
          legacyBaseline.theoreticalFreeSpaceRangeMeters * .001,
        ),
      );
      const weakerFade = RfBandProfile(
        frequencyMhz: 5800,
        eirpDbm: 14,
        receiverThresholdDbm: -105,
        fadeMarginDb: 18,
      );
      expect(
        weakerFade.theoreticalFreeSpaceRangeMeters,
        lessThan(legacyBaseline.theoreticalFreeSpaceRangeMeters),
      );
      expect(
        () => const RfBandProfile(
          frequencyMhz: double.nan,
          eirpDbm: 14,
          receiverThresholdDbm: -105,
          fadeMarginDb: 12,
        ).theoreticalFreeSpaceRangeMeters,
        throwsArgumentError,
      );
    },
  );

  test('EU and FCC scenarios are per-link presets and retain custom input', () {
    expect(RfReferencePresets.video(RfScenario.eu).eirpDbm, 13.9);
    expect(RfReferencePresets.video(RfScenario.fcc).eirpDbm, 32.9);
    expect(RfReferencePresets.control(RfScenario.eu).frequencyMhz, 868);
    expect(RfReferencePresets.control(RfScenario.fcc).frequencyMhz, 915);
    const custom = RfProfileSettings(
      videoScenario: RfScenario.custom,
      video: RfBandProfile(
        frequencyMhz: 5700,
        eirpDbm: 25,
        receiverThresholdDbm: -110,
        fadeMarginDb: 10,
      ),
    );
    expect(custom.toJson()['videoScenario'], 'custom');
    expect(custom.video.eirpDbm, 25);
  });

  test('adaptive LoS intervals have a strict bound at fast flight speeds', () {
    expect(LiveSamplingPolicy.interval(0).inMilliseconds, 800);
    expect(LiveSamplingPolicy.interval(15).inMilliseconds, 400);
    expect(LiveSamplingPolicy.interval(65).inMilliseconds, 200);
    expect(LiveSamplingPolicy.spacing(100), 5);
    expect(LiveSamplingPolicy.spacing(6000), 6);
    // All live tiers must satisfy the shared RouteSamplingPlan constraints.
    for (final distance in [
      1.0,
      100.0,
      1000.0,
      5999.0,
      6000.0,
      6001.0,
      20000.0,
      50000.0,
    ]) {
      expect(LiveSamplingPolicy.spacing(distance), inInclusiveRange(5, 100));
    }
    expect(LiveSamplingPolicy.maximumStaleness(70), 42);
  });
}
