import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpvmanager/core/osint/api_access_policy.dart';
import 'package:fpvmanager/core/osint/api_credential_vault.dart';
import 'package:fpvmanager/features/airspace/api_credentials_section.dart';

class FakeVault implements ApiCredentialVault {
  final saved = <String, String>{};
  @override
  Future<bool> contains(ApiAccessPolicy policy) async =>
      saved.containsKey(policy.id);
  @override
  Future<void> save(ApiAccessPolicy policy, String key) async {
    if (!policy.allowsUserKey) throw ArgumentError('Access denied');
    saved[policy.id] = key;
  }

  @override
  Future<void> remove(ApiAccessPolicy policy) async {
    saved.remove(policy.id);
  }
}

void main() {
  testWidgets('official airspace sources never display unsupported key entry', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ApiCredentialsSection(policies: OfficialAirspaceApis.sources),
        ),
      ),
    );
    expect(find.byType(TextField), findsNothing);
    expect(find.textContaining('BAZL works without one'), findsOneWidget);
  });

  testWidgets(
    'verified free-key providers allow add and remove without echoing secret',
    (tester) async {
      final vault = FakeVault();
      final policy = ApiAccessPolicy(
        id: 'free-service',
        name: 'Example verified free service',
        access: ApiAccessClass.verifiedFreeKey,
        registrationUri: Uri.parse('https://example.org/signup'),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ApiCredentialsSection(policies: [policy], vault: vault),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'private-token-123');
      await tester.pump();
      await tester.tap(find.text('Save key'));
      await tester.pump();
      await tester.pump();
      expect(vault.saved[policy.id], 'private-token-123');
      expect(find.text('private-token-123'), findsNothing);
      await tester.tap(find.text('Remove key'));
      await tester.pump();
      await tester.pump();
      expect(vault.saved, isEmpty);
    },
  );
}
