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
    expect(settings.toJson()['video'], isA<Map<String, double>>());
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
      const stronger = RfBandProfile(
        frequencyMhz: 5800,
        eirpDbm: 20,
        receiverThresholdDbm: -105,
        fadeMarginDb: 12,
      );
      expect(
        stronger.theoreticalFreeSpaceRangeMeters,
        closeTo(videoDistance * 1.995262315, videoDistance * .001),
      );
      const weakerFade = RfBandProfile(
        frequencyMhz: 5800,
        eirpDbm: 14,
        receiverThresholdDbm: -105,
        fadeMarginDb: 18,
      );
      expect(
        weakerFade.theoreticalFreeSpaceRangeMeters,
        lessThan(videoDistance),
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

  test('adaptive LoS intervals have a strict bound at fast flight speeds', () {
    expect(LiveSamplingPolicy.interval(0).inMilliseconds, 800);
    expect(LiveSamplingPolicy.interval(15).inMilliseconds, 450);
    expect(LiveSamplingPolicy.interval(65).inMilliseconds, 250);
    expect(LiveSamplingPolicy.spacing(100), 8);
    expect(LiveSamplingPolicy.spacing(6000), 24);
    expect(LiveSamplingPolicy.maximumStaleness(70), 42);
  });
}
