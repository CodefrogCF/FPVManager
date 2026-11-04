import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:webview_flutter_windows/webview_flutter_windows.dart' as win;

import '../../core/geo/geo_coordinate_service.dart';
import '../offline/offline_map_store_native.dart';
import 'globe_asset_server.dart';
import 'globe_controller.dart';
import 'globe_page_path.dart';
import 'globe_windows_bridge.dart';

/// Windows implementation of the same CesiumJS renderer used on Android/iOS.
/// WebView2 loads assets from FPVManager's private, manifest-restricted server.
class GlobeViewWindows extends StatefulWidget {
  const GlobeViewWindows({
    super.key,
    required this.controller,
    this.offline = false,
    this.cachedMaps = false,
    this.cacheRevision = 0,
    this.floatingControls = false,
  });

  final GlobeController controller;
  final bool offline;
  final bool cachedMaps;
  final int cacheRevision;
  final bool floatingControls;

  @override
  State<GlobeViewWindows> createState() => _GlobeViewWindowsState();
}

class _GlobeViewWindowsState extends State<GlobeViewWindows>
    with WidgetsBindingObserver {
  final win.WebviewController _webview = win.WebviewController();
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  GlobeAssetServer? _assetServer;
  late final Future<void> _initialization;
  String? _error;
  String? _coordinates;
  bool _initialized = false;
  bool _loading = true;
  bool _disposed = false;

  String get _page => globePagePath(
    offline: widget.offline,
    cachedMaps: widget.cachedMaps,
    floatingControls: widget.floatingControls,
  );

  @override
  void initState() {
    super.initState();
    widget.controller.attach(_sendCommand);
    widget.controller.addListener(_onControllerChanged);
    WidgetsBinding.instance.addObserver(this);
    _initialization = _initialize();
  }

  Future<void> _initialize() async {
    try {
      final version = await win.WebviewController.getWebViewVersion();
      if (version == null) {
        throw StateError(
          'Microsoft Edge WebView2 Runtime is not installed. '
          'Install it from https://developer.microsoft.com/microsoft-edge/webview2/',
        );
      }
      if (_disposed) return;

      final server = await GlobeAssetServer.start(
        offlineCache: NativeOfflineMapStore(),
      );
      _assetServer = server;
      if (_disposed) return;

      await _webview.initialize();
      if (_disposed) return;

      await _webview.setBackgroundColor(const Color(0xff10140f));
      await _webview.setPopupWindowPolicy(win.WebviewPopupWindowPolicy.deny);
      await _webview.setDevToolsEnabled(false);

      final secureRandom = Random.secure();
      final nonceBytes = List<int>.generate(
        24,
        (_) => secureRandom.nextInt(256),
      );
      final nonce = base64UrlEncode(nonceBytes);

      // Register the bridge before navigation; Cesium sends "globe-ready"
      // during page startup and would otherwise lose the first event.
      _subscriptions.add(
        _webview.webMessage.listen((Object? message) {
          if (_disposed || !mounted) return;
          final event = decodeWindowsGlobeMessage(message, nonce);
          if (event != null) widget.controller.handleEvent(event);
        }),
      );
      _subscriptions.add(
        _webview.loadingState.listen((state) {
          if (_disposed || !mounted) return;
          if (state == win.LoadingState.loading) {
            widget.controller.rendererLoading();
            setState(() {
              _loading = true;
              _error = null;
            });
          } else if (state == win.LoadingState.navigationCompleted) {
            setState(() => _loading = false);
          }
        }),
      );
      _subscriptions.add(
        _webview.onLoadError.listen((error) {
          if (_disposed || !mounted) return;
          setState(() {
            _error = 'WebView2: $error';
            _loading = false;
          });
        }),
      );
      _subscriptions.add(
        _webview.url.listen((url) {
          if (_disposed || !mounted) return;
          if (!isTrustedWindowsGlobeUrl(url, server.origin)) {
            // A document should never leave our private asset-server origin.
            // Revert an accidental navigation without launching the URL.
            unawaited(
              _webview.loadUrl(server.origin.resolve(_page).toString()),
            );
          }
        }),
      );
      await _webview.addScriptToExecuteOnDocumentCreated(
        windowsGlobeInjection(assetOrigin: server.origin, nonce: nonce),
      );
      if (_disposed || !mounted) return;
      setState(() => _initialized = true);
      await _webview.loadUrl(server.origin.resolve(_page).toString());
    } catch (error) {
      if (_disposed || !mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
  }

  Future<void> _sendCommand(String command) async {
    if (!_initialized || _disposed) {
      throw StateError('Windows 3D globe is not initialized');
    }
    await _webview.executeScript(
      'window.FPVManager.receive(${jsonEncode(command)});',
    );
  }

  void _onControllerChanged() {
    if (!mounted) return;
    final point = widget.controller.selectedPoint;
    setState(() {
      _coordinates = point == null
          ? null
          : '${point.latitude.toStringAsFixed(5)}, '
                '${point.longitude.toStringAsFixed(5)} | '
                '${point.altitude.toStringAsFixed(1)} m '
                '(${point.heightReference.label})';
      _error = widget.controller.error;
    });
  }

  @override
  void didUpdateWidget(covariant GlobeViewWindows oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onControllerChanged);
      oldWidget.controller.detach();
      widget.controller.attach(_sendCommand);
      widget.controller.addListener(_onControllerChanged);
    }
    if (_initialized &&
        (oldWidget.controller != widget.controller ||
            oldWidget.cachedMaps != widget.cachedMaps ||
            oldWidget.cacheRevision != widget.cacheRevision ||
            oldWidget.floatingControls != widget.floatingControls)) {
      final server = _assetServer;
      if (server != null) {
        unawaited(_webview.loadUrl(server.origin.resolve(_page).toString()));
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_initialized || _disposed) return;
    if (state == AppLifecycleState.paused) widget.controller.suspend();
    if (state == AppLifecycleState.resumed) {
      unawaited(_resumeRenderer());
    }
  }

  Future<void> _resumeRenderer() async {
    try {
      await _webview.executeScript('window.FPVManager?.hello();');
    } catch (_) {
      if (!_disposed) await _webview.reload();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    widget.controller.removeListener(_onControllerChanged);
    widget.controller.detach();
    unawaited(_cleanup());
    super.dispose();
  }

  Future<void> _cleanup() async {
    try {
      await _initialization;
    } catch (_) {
      // The initialization path displays its own error.
    }
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    try {
      await _webview.dispose();
    } catch (_) {
      // WebView2 may already have been torn down during window shutdown.
    }
    await _assetServer?.close();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline,
                color: Colors.orangeAccent,
                size: 48,
              ),
              const SizedBox(height: 16),
              const Text(
                'Failed to load 3D globe',
                style: TextStyle(fontSize: 20),
              ),
              const SizedBox(height: 8),
              SelectableText(_error!, textAlign: TextAlign.center),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (_initialized) win.Webview(_webview),
              if (_loading || !_initialized)
                const Center(child: CircularProgressIndicator()),
            ],
          ),
        ),
        if (_coordinates != null && !widget.floatingControls)
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Text(_coordinates!, textAlign: TextAlign.center),
            ),
          ),
      ],
    );
  }
}
