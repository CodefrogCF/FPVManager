import 'package:flutter_test/flutter_test.dart';
import 'package:fpvmanager/features/airspace/uas_restriction.dart';
import 'package:fpvmanager/features/airspace/uas_zone_details.dart';
import 'package:fpvmanager/features/airspace/uas_dataset_assessment.dart';

import '../../helpers/uas_zone_fixture.dart';

void main() {
  test('classifies CodeRestrictionType, never CodeZoneType COMMON', () {
    const expected = <String, UasRestrictionCategory>{
      'PROHIBITED': UasRestrictionCategory.prohibited,
      'REQ_AUTHORISATION': UasRestrictionCategory.authorisation,
      'REQ_AUTHORISATION.MTOM_ALL': UasRestrictionCategory.authorisation,
      'REQ_AUTHORISATION.MTOM_FROM': UasRestrictionCategory.authorisation,
      'REQ_AUTHORISATION.CTR': UasRestrictionCategory.authorisation,
      'REQ_AUTHORIZATION': UasRestrictionCategory.authorisation,
      'CONDITIONAL': UasRestrictionCategory.conditional,
      'NO_RESTRICTION': UasRestrictionCategory.informational,
      'USPACE': UasRestrictionCategory.unknown,
      'UNRECOGNISED_NEW_CODE': UasRestrictionCategory.unknown,
    };
    for (final entry in expected.entries) {
      final model = UasRestriction.fromAttributes({
        'type': 'COMMON',
        'restriction': entry.key,
      });
      expect(model.category, entry.value, reason: entry.key);
      expect(model.restrictionCode, entry.key);
      expect(model.rawType, 'COMMON');
    }
  });

  test('unknown and missing codes never imply flight permission', () {
    expect(UasRestriction.fromAttributes({}).category,
        UasRestrictionCategory.unknown);
    expect(UasRestriction.fromAttributes({'restriction': 'NO_RESTRICTION'}).category,
        UasRestrictionCategory.informational);
    expect(UasRestriction.fromAttributes({'type': 'PROHIBITED', 'restriction': 'UNKNOWN'}).category,
        UasRestrictionCategory.unknown);
  });

  test('validity, authority, vertical references and source properties remain separate', () {
    final details = UasZoneDetails.fromFeature(
      uasFixtureFeature(overrides: {
        'type': 'COMMON',
        'permanent': 'NO',
        'startDateTime': '2026-10-22T14:00:00+02:00',
        'endDateTime': '2026-10-23T14:00:00+02:00',
        'restriction': 'REQ_AUTHORISATION.MTOM_FROM',
      }),
      fallbackId: 'fallback',
    );
    final model = details.restriction;
    expect(model.hasSchedule, isTrue);
    expect(model.validFromUtc, DateTime.utc(2026, 10, 22, 12));
    expect(model.validUntilUtc, DateTime.utc(2026, 10, 23, 12));
    expect(model.lower.reference, 'AGL');
    expect(model.upper.reference, 'AMSL');
    expect(model.authority.name, 'Fixture authority');
    expect(model.authority.website.toString(), 'https://example.invalid/authority');
    expect(details.value('restriction'), 'REQ_AUTHORISATION.MTOM_FROM');
    expect(model.category, UasRestrictionCategory.authorisation);
    expect(model.mapHexColor, '#b8860b');
    expect(model.restrictionMeaning, contains('take-off mass'));
  });

  test('CTR subtype has its own color and conditional explanation', () {
    final ctr = UasRestriction.fromAttributes({
      'type': 'COMMON', 'restriction': 'REQ_AUTHORISATION.CTR',
    });
    expect(ctr.category, UasRestrictionCategory.authorisation);
    expect(ctr.mapHexColor, '#7b1fa2');
    expect(ctr.restrictionMeaning, contains('120 m AGL'));
    final missing = UasRestriction.fromAttributes({'type': 'COMMON'});
    expect(missing.category, UasRestrictionCategory.unknown);
    expect(missing.mapHexColor, '#757575');
  });

  test('malformed dates and unsupported link protocols are flagged', () {
    final model = UasRestriction.fromAttributes({
      'type': '??',
      'permanent': 'SOMETIMES',
      'startDateTime': 'not a timestamp',
      'siteURL': 'javascript:alert(1)',
    });
    expect(model.category, UasRestrictionCategory.unknown);
    expect(model.unrecognisedValues, hasLength(5));
    expect(model.validFromUtc, isNull);
    expect(model.authority.website, isNull);
  });

  test('overlapping features are counted individually without collapsing restrictions', () {
    final assessment = UasDatasetAssessment.inspect(uasFixtureCollection([
      uasFixtureFeature(overrides: {'restriction': 'PROHIBITED'}),
      uasFixtureFeature(overrides: {'restriction': 'CONDITIONAL'}),
      uasFixtureFeature(overrides: {'restriction': 'UNSUPPORTED'}),
    ]));
    expect(assessment.renderedFeatureCount, 3);
    expect(assessment.categoryCounts[UasRestrictionCategory.prohibited], 1);
    expect(assessment.categoryCounts[UasRestrictionCategory.conditional], 1);
    expect(assessment.categoryCounts[UasRestrictionCategory.unknown], 1);
  });
}
