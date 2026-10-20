import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:fpvmanager/core/osint/cached_osint_provider.dart';
import 'package:fpvmanager/core/osint/osint_dataset.dart';
import 'package:fpvmanager/core/osint/osint_provider_state.dart';
import 'package:fpvmanager/core/osint/osint_source.dart';

class _Provider extends CachedOsintProvider<int> {
  _Provider(DateTime Function() now)
    : super(now: now, cacheDuration: const Duration(hours: 1));
  @override
  final source = OsintSource(
    id: 'test',
    name: 'Test dataset',
    publisher: 'Test',
    dataUri: Uri.parse('https://example.invalid/data'),
    metadataUri: Uri.parse('https://example.invalid/metadata'),
  );
  int calls = 0;
  Future<OsintDataset<int>> Function()? action;
  OsintDataset<int> dataset([int data = 1]) => OsintDataset(
    source: source,
    data: data,
    fetchedAtUtc: nowUtc,
    cacheExpiresAtUtc: nowUtc.add(cacheDuration),
  );
  @override
  Future<OsintDataset<int>> download() async {
    calls++;
    return action == null ? dataset() : await action!();
  }
}

void main() {
  late DateTime now;
  late _Provider provider;
  setUp(() {
    now = DateTime.utc(2026, 10, 20, 8);
    provider = _Provider(() => now);
  });
  tearDown(() => provider.dispose());

  test(
    'cache expiry and clock rollback do not masquerade as official validity',
    () async {
      final first = await provider.fetch();
      expect(first.source.licenseName, isNull);
      expect(first.validity, isNull);
      expect(provider.status.freshness, OsintFreshness.fresh);
      expect(await provider.fetch(), same(first));
      expect(provider.status.servedFromCache, isTrue);
      expect(provider.calls, 1);
      now = now.add(const Duration(hours: 1));
      expect(provider.status.freshness, OsintFreshness.stale);
      final second = await provider.fetch();
      expect(second, isNot(same(first)));
      now = now.subtract(const Duration(minutes: 1));
      expect(provider.status.freshness, OsintFreshness.clockSkew);
      await provider.fetch();
      expect(provider.calls, 3);
    },
  );

  test('concurrent and reentrant requests share one update', () async {
    final pending = Completer<OsintDataset<int>>();
    provider.action = () => pending.future;
    Future<OsintDataset<int>>? reentrant;
    provider.addListener(() {
      if (provider.status.update == OsintUpdateState.loading) {
        reentrant = provider.fetch(forceRefresh: true);
      }
    });
    final first = provider.fetch();
    final second = provider.fetch(forceRefresh: true);
    expect(identical(first, second), isTrue);
    expect(identical(first, reentrant), isTrue);
    expect(provider.calls, 1);
    pending.complete(provider.dataset());
    await first;
    expect(provider.status.update, OsintUpdateState.ready);
    expect(provider.status.lastAttemptAtUtc, now);
  });

  test(
    'failed refresh retains data and error until a successful network update',
    () async {
      final previous = await provider.fetch();
      provider.action = () => throw TimeoutException('fixture');
      await expectLater(
        provider.fetch(forceRefresh: true),
        throwsA(
          isA<OsintProviderException>().having(
            (e) => e.kind,
            'kind',
            OsintFailureKind.timeout,
          ),
        ),
      );
      expect(provider.cached, same(previous));
      expect(provider.status.update, OsintUpdateState.failed);
      expect(await provider.fetch(), same(previous));
      expect(provider.status.error?.kind, OsintFailureKind.timeout);
      provider.action = null;
      await provider.fetch(forceRefresh: true);
      expect(provider.status.error, isNull);
      expect(provider.status.update, OsintUpdateState.ready);
    },
  );

  test('disposal prevents late cache updates and further I/O', () async {
    final pending = Completer<OsintDataset<int>>();
    provider.action = () => pending.future;
    final request = provider.fetch();
    final check = expectLater(
      request,
      throwsA(
        isA<OsintProviderException>().having(
          (e) => e.kind,
          'kind',
          OsintFailureKind.disposed,
        ),
      ),
    );
    var notifications = 0;
    provider.addListener(() => notifications++);
    provider.dispose();
    pending.complete(provider.dataset());
    await check;
    expect(provider.cached, isNull);
    expect(notifications, 0);
    await expectLater(provider.fetch(), throwsA(isA<OsintProviderException>()));
    expect(provider.calls, 1);
  });

  test('wrong dataset identity cannot poison the previous cache', () async {
    final previous = await provider.fetch();
    provider.action = () async => OsintDataset(
      source: OsintSource(
        id: 'other',
        name: 'Other',
        publisher: 'Other',
        dataUri: provider.sourceUri,
        metadataUri: provider.source.metadataUri,
      ),
      data: 2,
      fetchedAtUtc: now,
      cacheExpiresAtUtc: now.add(const Duration(hours: 1)),
    );
    await expectLater(
      provider.fetch(forceRefresh: true),
      throwsA(
        isA<OsintProviderException>().having(
          (e) => e.kind,
          'kind',
          OsintFailureKind.invalidData,
        ),
      ),
    );
    expect(provider.cached, same(previous));
  });

  test('official periods support unknown/open bounds and exclusive ends', () {
    expect(OsintValidityPeriod().at(now), OsintValidity.unknown);
    final period = OsintValidityPeriod(
      from: now,
      until: now.add(const Duration(hours: 2)),
    );
    expect(
      period.at(now.subtract(const Duration(seconds: 1))),
      OsintValidity.notYetValid,
    );
    expect(period.at(now), OsintValidity.withinPeriod);
    expect(period.at(now.add(const Duration(hours: 2))), OsintValidity.expired);
    expect(
      () => OsintValidityPeriod(from: now, until: now),
      throwsArgumentError,
    );
  });
}
