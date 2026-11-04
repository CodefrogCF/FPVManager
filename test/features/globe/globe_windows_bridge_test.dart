import 'package:flutter_test/flutter_test.dart';
import 'package:fpvmanager/features/globe/globe_windows_bridge.dart';

void main() {
  final origin = Uri.parse('http://127.0.0.1:42105');

  test('Windows bridge accepts only the loopback globe document', () {
    expect(
      isTrustedWindowsGlobeUrl('http://127.0.0.1:42105/globe.html', origin),
      isTrue,
    );
    expect(
      isTrustedWindowsGlobeUrl(
        'http://127.0.0.1:42105/globe.html?offline=1',
        origin,
      ),
      isTrue,
    );
    expect(
      isTrustedWindowsGlobeUrl('http://localhost:42105/globe.html', origin),
      isFalse,
    );
    expect(
      isTrustedWindowsGlobeUrl('http://127.0.0.1:42106/globe.html', origin),
      isFalse,
    );
    expect(
      isTrustedWindowsGlobeUrl('https://example.org/globe.html', origin),
      isFalse,
    );
  });

  test('Windows bridge forwards only nonce-bound messages', () {
    final payload = <String, Object?>{
      'channel': windowsGlobeChannel,
      'nonce': 'nonce-1',
      'event': '{"type":"globe-ready"}',
    };
    expect(
      decodeWindowsGlobeMessage(payload, 'nonce-1'),
      '{"type":"globe-ready"}',
    );
    expect(decodeWindowsGlobeMessage(payload, 'nonce-2'), isNull);
    expect(
      decodeWindowsGlobeMessage({...payload, 'channel': 'other'}, 'nonce-1'),
      isNull,
    );
    expect(
      decodeWindowsGlobeMessage({...payload, 'event': 42}, 'nonce-1'),
      isNull,
    );
  });

  test(
    'Bootstrap script restricts the injected bridge to the local origin',
    () {
      final script = windowsGlobeInjection(
        assetOrigin: origin,
        nonce: 'nonce-1',
      );
      expect(script, contains('http://127.0.0.1:42105'));
      expect(script, contains('window.chrome.webview.postMessage'));
      expect(script, contains('nonce-1'));
    },
  );
}
