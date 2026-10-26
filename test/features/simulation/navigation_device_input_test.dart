import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpvmanager/features/simulation/navigation_device_input.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const method = MethodChannel('com.codefrog.fpvmanager/navigation_input');
  const event = 'com.codefrog.fpvmanager/navigation_events';
  const codec = StandardMethodCodec();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final calls = <bool>[];
  final neutral = <String, dynamic>{
    'forward': 0.0,
    'right': 0.0,
    'yaw': 0.0,
    'pitch': 0.0,
    'vertical': 0.0,
    'reset': false,
    'exit': false,
    'connected': true,
  };
  Future<void> emit(Map<String, dynamic> value) async {
    await messenger.handlePlatformMessage(
      event,
      codec.encodeSuccessEnvelope(value),
      (_) {},
    );
  }

  setUp(() {
    calls.clear();
    messenger.setMockMethodCallHandler(method, (call) async {
      calls.add(call.arguments['enabled'] as bool);
      return null;
    });
    messenger.setMockMethodCallHandler(
      const MethodChannel(event),
      (_) async => null,
    );
  });
  tearDown(() {
    messenger.setMockMethodCallHandler(method, null);
    messenger.setMockMethodCallHandler(const MethodChannel(event), null);
  });
  testWidgets(
    'native adapter is opt-in, coalesces valid inputs and neutralizes an expired stream',
    (tester) async {
      final sent = <Map<String, dynamic>>[];
      var elapsed = Duration.zero;
      final input = NavigationDeviceInput(
        (frame) async => sent.add(Map.of(frame)),
        elapsed: () => elapsed,
      );
      addTearDown(input.dispose);
      await tester.pump();
      await emit(neutral);
      await tester.pump(const Duration(milliseconds: 40));
      expect(sent, isEmpty);
      input.setEnabled(true);
      await tester.pump();
      await emit({...neutral, 'forward': .2});
      await emit({
        ...neutral,
        'forward': .8,
        'deviceId': 'must not cross bridge',
      });
      await tester.pump(const Duration(milliseconds: 40));
      expect(sent.single['forward'], .8);
      expect(sent.single.containsKey('deviceId'), isFalse);
      await emit({...neutral, 'forward': double.nan});
      await tester.pump(const Duration(milliseconds: 40));
      expect(sent.last['forward'], .8);
      elapsed = const Duration(milliseconds: 300);
      await tester.pump(const Duration(milliseconds: 300));
      expect(sent.last['forward'], 0);
      expect(sent.last['connected'], isTrue);
      expect(sent.last['stale'], isTrue);
      input.setEnabled(false);
      final count = sent.length;
      await tester.pump(const Duration(milliseconds: 100));
      expect(sent.length, count);
      input.dispose();
      await tester.pump();
      expect(calls, [true, false]);
    },
  );
  testWidgets(
    'one slow bridge command bounds outstanding work and multiple owners clean up independently',
    (tester) async {
      final pending = Completer<void>();
      var count = 0;
      final first = NavigationDeviceInput((_) {
        count++;
        return pending.future;
      });
      final second = NavigationDeviceInput((_) async {});
      addTearDown(first.dispose);
      addTearDown(second.dispose);
      first.setEnabled(true);
      second.setEnabled(true);
      await tester.pump();
      await emit(neutral);
      await tester.pump(const Duration(milliseconds: 40));
      await tester.pump(const Duration(milliseconds: 300));
      expect(count, 1);
      first.dispose();
      await tester.pump();
      expect(calls, [true]);
      second.dispose();
      pending.complete();
      await tester.pump();
      expect(calls, [true, false]);
    },
  );
  testWidgets(
    'native radio channels are bounded, keep connection generation and expire without retaining identifiers',
    (tester) async {
      final sent = <Map<String, dynamic>>[];
      var elapsed = Duration.zero;
      final input = NavigationDeviceInput(
        (frame) async => sent.add(Map.of(frame)),
        elapsed: () => elapsed,
      );
      addTearDown(input.dispose);
      input.setEnabled(true);
      await tester.pump();
      final radio = {
        ...neutral,
        'axes': [0.0, 0.0, -1.0, 0.0],
        'generation': 7,
        'serial': 'private',
      };
      await emit(radio);
      await tester.pump(const Duration(milliseconds: 40));
      expect(sent.last['axes'], [0.0, 0.0, -1.0, 0.0]);
      expect(sent.last['generation'], 7);
      expect(sent.last.containsKey('serial'), isFalse);
      for (final invalid in [
        {...radio, 'axes': List.filled(17, 0.0)},
        {
          ...radio,
          'axes': [double.nan],
        },
        {
          ...radio,
          'axes': [2.0],
        },
        {...radio, 'generation': -1},
      ]) {
        await emit(invalid);
        await tester.pump(const Duration(milliseconds: 40));
        expect(sent.last['generation'], 7);
        expect(sent.last['axes'], radio['axes']);
      }
      elapsed = const Duration(milliseconds: 300);
      await tester.pump(const Duration(milliseconds: 40));
      expect(sent.last['connected'], true);
      expect(sent.last['stale'], true);
      expect(sent.last['generation'], 7);
      expect(sent.last.containsKey('axes'), false);
      await emit({
        ...radio,
        'axes': [0.0, 0.0, .8, 0.0],
      });
      await tester.pump(const Duration(milliseconds: 40));
      expect(sent.last['axes'], [0.0, 0.0, .8, 0.0]);
      expect(sent.last['stale'], isNot(true));
      await emit({...neutral, 'connected': false, 'generation': 8});
      await tester.pump(const Duration(milliseconds: 40));
      expect(sent.last['connected'], false);
      input.dispose();
      await tester.pump();
    },
  );
}
