import 'dart:convert';

/// An authenticated wrapper around WebView2 messages from the local globe.
/// The native webview must never accept arbitrary messages from remote pages.
const String windowsGlobeChannel = 'fpvmanager-globe';

/// Only the private loopback asset server is allowed as a top-level page.
bool isTrustedWindowsGlobeUrl(String? candidate, Uri assetOrigin) {
  if (candidate == null) return false;
  final uri = Uri.tryParse(candidate);
  return uri != null &&
      uri.scheme == 'http' &&
      uri.host == '127.0.0.1' &&
      uri.port == assetOrigin.port &&
      uri.path == '/globe.html';
}

/// A document-created bridge that is only exposed to our loopback origin.
/// The nonce binds events to this particular webview instance.
String windowsGlobeInjection({
  required Uri assetOrigin,
  required String nonce,
}) =>
    '''
(() => {
  if (window.location.origin !== ${jsonEncode(assetOrigin.origin)}) return;
  Object.defineProperty(window, 'FPVBridge', {
    value: Object.freeze({
      postMessage: (event) => {
        if (typeof event !== 'string' || event.length > 131072) return;
        window.chrome.webview.postMessage({
          channel: ${jsonEncode(windowsGlobeChannel)},
          nonce: ${jsonEncode(nonce)},
          event
        });
      }
    }),
    configurable: false,
    writable: false,
  });
})();
''';

/// Extract a renderer event only if the instance nonce and channel match.
String? decodeWindowsGlobeMessage(Object? payload, String nonce) {
  if (payload is! Map ||
      payload['channel'] != windowsGlobeChannel ||
      payload['nonce'] != nonce) {
    return null;
  }
  final event = payload['event'];
  if (event is! String || event.length > 131072) return null;
  return event;
}
