import 'dart:convert';
import 'dart:io';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'globe_controller.dart';
import 'globe_asset_server.dart';
import 'globe_page_path.dart';
import 'globe_view_windows.dart';
import '../offline/offline_map_store_native.dart';
import '../../core/geo/geo_coordinate_service.dart';
import '../../core/theme/app_theme.dart';
import '../simulation/navigation_device_input.dart';

/// Native implementation of the FPVManager 3D globe.
///
/// Android and iOS use their native WebView. Windows uses Edge WebView2.
/// Other native platforms display a fallback.
class GlobeView extends StatefulWidget {
  const GlobeView({
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
  State<GlobeView> createState() => _GlobeViewState();
}

class _GlobeViewState extends State<GlobeView> with WidgetsBindingObserver {
  WebViewController? _controller;
  GlobeAssetServer? _assetServer;
  NavigationDeviceInput? _deviceInput;

  bool _loading = true;
  String? _error;
  String? _coordinates;

  bool get _supported => Platform.isAndroid || Platform.isIOS;

  // Flutter's VM widget-test runner sets FLUTTER_TEST, including when the
  // tests run on Windows. Do not initialize native WebView2 in that runner:
  // its persistent loading animation would prevent pumpAndSettle() from
  // completing. The regular Windows desktop build still uses WebView2.
  // See Flutter's defaultTargetPlatform implementation for the same flag.
  bool get _useWindowsRenderer =>
      Platform.isWindows && !Platform.environment.containsKey('FLUTTER_TEST');

  @override
  void initState() {
    super.initState();
    // The Windows child owns the renderer protocol and WebView2 lifecycle.
    if (_useWindowsRenderer) return;

    widget.controller.attach(_sendCommand);
    widget.controller.addListener(_onControllerChanged);
    WidgetsBinding.instance.addObserver(this);
    if (Platform.isAndroid) {
      _deviceInput = NavigationDeviceInput(
        (frame) => widget.controller.sendNavigationInput(frame),
      );
    }

    if (_supported) {
      _initializeGlobe();
    }
  }

  Future<void> _sendCommand(String command) async {
    final controller = _controller;

    if (controller == null) {
      throw StateError('WebView is not initialized');
    }

    await controller.runJavaScript(
      'window.FPVManager.receive(${jsonEncode(command)});',
    );
  }

  Future<void> _initializeGlobe() async {
    try {
      final server = await GlobeAssetServer.start(
        offlineCache: NativeOfflineMapStore(),
      );
      if (!mounted) {
        await server.close();
        return;
      }
      _assetServer = server;
      final controller = WebViewController();

      await controller.setJavaScriptMode(JavaScriptMode.unrestricted);

      await controller.setBackgroundColor(AppTheme.dark.colorScheme.surface);

      // Communication from CesiumJS to Flutter.
      await controller.addJavaScriptChannel(
        'FPVBridge',
        onMessageReceived: _handleJavaScriptMessage,
      );

      await controller.setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (!mounted) return;
            widget.controller.rendererLoading();
            setState(() {
              _loading = true;
              _error = null;
            });
          },
          onPageFinished: (_) {
            if (!mounted) return;

            setState(() {
              _loading = false;
            });
          },
          onWebResourceError: (error) {
            if (error.isForMainFrame == true) {
              if (!mounted) return;

              setState(() {
                _error = error.description;
                _loading = false;
              });
            } else {
              debugPrint('Globe resource error: ${error.description}');
            }
          },
          onNavigationRequest: (request) {
            final uri = Uri.tryParse(request.url);
            if (uri?.scheme == 'http' &&
                    uri?.host == '127.0.0.1' &&
                    uri?.port == server.origin.port ||
                request.url == 'about:blank') {
              return NavigationDecision.navigate;
            }

            return NavigationDecision.prevent;
          },
        ),
      );

      if (!mounted) return;

      setState(() {
        _controller = controller;
      });

      await controller.loadRequest(server.origin.resolve(_page));
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  String get _page => globePagePath(
    offline: widget.offline,
    cachedMaps: widget.cachedMaps,
    floatingControls: widget.floatingControls,
  );

  @override
  void didUpdateWidget(covariant GlobeView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_useWindowsRenderer) return;
    if ((oldWidget.cachedMaps != widget.cachedMaps ||
            oldWidget.cacheRevision != widget.cacheRevision ||
            oldWidget.floatingControls != widget.floatingControls) &&
        _assetServer != null) {
      unawaited(_controller?.loadRequest(_assetServer!.origin.resolve(_page)));
    }

    if (oldWidget.controller != widget.controller) {
      _deviceInput?.setEnabled(false);
      oldWidget.controller.removeListener(_onControllerChanged);
      oldWidget.controller.detach();
      widget.controller.attach(_sendCommand);
      widget.controller.addListener(_onControllerChanged);
      unawaited(_controller?.reload() ?? Future<void>.value());
    }
  }

  @override
  void dispose() {
    if (_useWindowsRenderer) {
      super.dispose();
      return;
    }
    _deviceInput?.dispose();
    WidgetsBinding.instance.removeObserver(this);
    widget.controller.removeListener(_onControllerChanged);
    widget.controller.detach();
    unawaited(_assetServer?.close() ?? Future<void>.value());
    super.dispose();
  }

  void _handleJavaScriptMessage(JavaScriptMessage message) {
    if (!mounted) return;
    widget.controller.handleEvent(message.message);
  }

  void _onControllerChanged() {
    if (!mounted) return;
    _deviceInput?.setEnabled(
      widget.controller.navigationActive &&
          widget.controller.navigationFocused &&
          widget.controller.isReady,
    );
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
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_supported) return;
    if (state != AppLifecycleState.resumed) _deviceInput?.setEnabled(false);
    if (state == AppLifecycleState.paused) widget.controller.suspend();
    if (state == AppLifecycleState.resumed) {
      unawaited(_resumeRenderer());
    }
  }

  Future<void> _resumeRenderer() async {
    try {
      await _controller?.runJavaScript('window.FPVManager?.hello();');
    } catch (_) {
      if (mounted) await _controller?.reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_useWindowsRenderer) {
      return GlobeViewWindows(
        controller: widget.controller,
        offline: widget.offline,
        cachedMaps: widget.cachedMaps,
        cacheRevision: widget.cacheRevision,
        floatingControls: widget.floatingControls,
      );
    }
    if (!_supported) {
      return const Center(
        child: Text(
          'Native 3D globe is currently supported '
          'on Android and iOS.',
          textAlign: TextAlign.center,
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline,
                size: 48,
                color: Colors.orangeAccent,
              ),
              const SizedBox(height: 16),
              const Text(
                'Failed to load 3D globe',
                style: TextStyle(fontSize: 20),
              ),
              const SizedBox(height: 8),
              Text(_error!, textAlign: TextAlign.center),
            ],
          ),
        ),
      );
    }

    final controller = _controller;

    if (controller == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        Expanded(
          child: Stack(
            fit: StackFit.expand,
            children: [
              WebViewWidget(controller: controller),
              if (_loading) const Center(child: CircularProgressIndicator()),
            ],
          ),
        ),

        // Keep the selected-point footer outside the map's source credits.
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
