import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../globe/globe_asset_server.dart';
import 'offline_map_store_native.dart';
import 'offline_preparation_storage_native.dart';
import 'offline_region.dart';

class OfflinePreparationSurface extends StatefulWidget {
  const OfflinePreparationSurface({
    super.key,
    required this.config,
    required this.onComplete,
  });
  final Map<String, dynamic> config;
  final ValueChanged<OfflineRegion> onComplete;
  @override
  State<OfflinePreparationSurface> createState() =>
      _OfflinePreparationSurfaceState();
}

class _OfflinePreparationSurfaceState extends State<OfflinePreparationSurface> {
  final _store = NativeOfflineMapStore();
  late final _storage = NativeOfflinePreparationStorage(_store);
  GlobeAssetServer? _server;
  WebViewController? _view;
  String? _error;
  Future<void> _pending = Future.value();
  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    try {
      if (!Platform.isAndroid && !Platform.isIOS) {
        throw const FormatException(
          'Aufbereitung ist für Android und Web verfügbar.',
        );
      }
      if (Platform.isAndroid) {
        final remaining = await _storage.remainingBytes(widget.config);
        final available = await const MethodChannel(
          'com.codefrog.fpvmanager/offline_storage',
        ).invokeMethod<int>('availableBytes');
        if (available != null && remaining > available * .9) {
          if (mounted) {
            setState(
              () => _error = 'Nicht genügend freier Gerätespeicher. Detailgrad oder Ebenen reduzieren.',
            );
          }
          return;
        }
      }
      final server = await GlobeAssetServer.start();
      if (!mounted) {
        await server.close();
        return;
      }
      _server = server;
      final view = WebViewController();
      _view = view;
      await view.setJavaScriptMode(JavaScriptMode.unrestricted);
      if (!mounted) return;
      await view.setBackgroundColor(Theme.of(context).colorScheme.surface);
      await view.addJavaScriptChannel(
        'OfflineBridge',
        onMessageReceived: (message) {
          _pending = _pending.then((_) => _handle(message.message));
        },
      );
      await view.setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (r) => r.url.startsWith('${server.origin}/')
              ? NavigationDecision.navigate
              : NavigationDecision.prevent,
        ),
      );
      await view.loadRequest(server.origin.resolve('offline_preparation.html'));
      if (mounted) setState(() {});
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Offline-Aufbereitung konnte nicht gestartet werden.',
        );
      }
    }
  }

  Future<void> _handle(String text) async {
    if (!mounted || text.length > 6 * 1024 * 1024) return;
    try {
      final m = jsonDecode(text) as Map<String, dynamic>;
      switch (m['type']) {
        case 'ready':
          if (!mounted) return;
          await _view!.runJavaScript(
            'window.startPreparation(${jsonEncode(widget.config)},null,"offline_height_grid.bin");',
          );
        case 'storage':
          Object? value;
          String? error;
          try {
            switch (m['operation']) {
              case 'begin':
                value = await _storage.begin(
                  Map<String, dynamic>.from(m['config'] as Map),
                );
              case 'has':
                value = await _storage.has(
                  m['id'] as String,
                  m['key'] as String,
                );
              case 'sources':
                await _storage.bindSources(
                  m['id'] as String,
                  m['fingerprint'] as String,
                );
              case 'write':
                await _storage.write(
                  m['id'] as String,
                  m['key'] as String,
                  base64Decode(m['data'] as String),
                  m['budget'] as int,
                );
              case 'commit':
                value = (await _storage.commit(
                  Map<String, dynamic>.from(m['region'] as Map),
                )).toJson();
              default:
                throw const FormatException('Unknown storage action');
            }
          } catch (e) {
            error = e is FormatException ? e.message : 'Lokales Speichern fehlgeschlagen. Freien Gerätespeicher prüfen; bisherige Region bleibt erhalten.';
          }
          if (mounted) {
            await _view!.runJavaScript(
              'window.offlineReply(${jsonEncode({'requestId': m['requestId'], 'value': value, 'error': ?error})});',
            );
          }
        case 'complete':
          widget.onComplete(
            OfflineRegion.fromJson(
              Map<String, dynamic>.from(m['region'] as Map),
            ),
          );
        case 'error':
          setState(() => _error = m['message'] as String);
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Offline-Aufbereitung wurde unterbrochen. Bereits vorbereitete Kacheln bleiben für einen erneuten Versuch erhalten.',
        );
      }
    }
  }

  @override
  void dispose() {
    unawaited(_pending.then((_) => _store.close()));
    unawaited(_server?.close() ?? Future.value());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _error != null
      ? Padding(padding: const EdgeInsets.all(20), child: Text(_error!))
      : _view == null
      ? const Center(child: CircularProgressIndicator())
      : WebViewWidget(controller: _view!);
}
