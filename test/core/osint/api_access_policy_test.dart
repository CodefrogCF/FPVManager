import 'package:flutter_test/flutter_test.dart';
import 'package:fpvmanager/core/osint/api_access_policy.dart';

void main() {
  test('no existing airspace integration should solicit an API key', () {
    for (final service in OfficialAirspaceApis.sources) {
      expect(service.allowsUserKey, isFalse, reason: service.name);
    }
  });
  test(
    'only verified free keys with official HTTPS signup become eligible',
    () {
      expect(
        ApiAccessPolicy(
          id: 'example',
          name: 'Example',
          access: ApiAccessClass.verifiedFreeKey,
          registrationUri: Uri.parse('https://example.org/register'),
        ).allowsUserKey,
        isTrue,
      );
      expect(
        ApiAccessPolicy(
          id: 'paid',
          name: 'Paid',
          access: ApiAccessClass.paidOrUnverified,
          registrationUri: Uri.parse('https://example.org/register'),
        ).allowsUserKey,
        isFalse,
      );
      expect(
        ApiAccessPolicy(
          id: 'wrong',
          name: 'Wrong',
          access: ApiAccessClass.verifiedFreeKey,
          registrationUri: Uri.parse('http://example.org/register'),
        ).allowsUserKey,
        isFalse,
      );
      expect(
        ApiAccessPolicy(
          id: 'unpublished',
          name: 'Unpublished',
          access: ApiAccessClass.verifiedFreeKey,
        ).allowsUserKey,
        isFalse,
      );
    },
  );
}
