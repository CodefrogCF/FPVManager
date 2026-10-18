import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'globe_controller.dart';

/// Native implementation of the FPVManager 3D globe.
///
/// Android and iOS use a native WebView.
/// Other native platforms display a fallback.
class GlobeView extends StatefulWidget {
  const GlobeView({super.key, required this.controller});

  final GlobeController controller;

  @override
  State<GlobeView> createState() => _GlobeViewState();
}

class _GlobeViewState extends State<GlobeView> {
  WebViewController? _controller;

  bool _loading = true;
  String? _error;
  String? _coordinates;

  bool get _supported => Platform.isAndroid || Platform.isIOS;

  @override
  void initState() {
    super.initState();

    widget.controller.attach(_sendCommand);

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
      final controller = WebViewController();

      await controller.setJavaScriptMode(JavaScriptMode.unrestricted);

      await controller.setBackgroundColor(const Color(0xFF101820));

      // Communication from CesiumJS to Flutter.
      await controller.addJavaScriptChannel(
        'FPVBridge',
        onMessageReceived: _handleJavaScriptMessage,
      );

      await controller.setNavigationDelegate(
        NavigationDelegate(
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
            final scheme = Uri.tryParse(request.url)?.scheme;

            // Allow local assets but prevent navigation
            // to arbitrary external websites.
            if (scheme == 'file' || scheme == 'about') {
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

      final html = await rootBundle.loadString('web/globe.html');

      await controller.loadHtmlString(
        html,
        baseUrl: 'https://appassets.androidplatform.net/',
      );
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  @override
  void didUpdateWidget(covariant GlobeView oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.detach();
      widget.controller.attach(_sendCommand);
    }
  }

  @override
  void dispose() {
    widget.controller.detach();
    super.dispose();
  }

  void _handleJavaScriptMessage(JavaScriptMessage message) {
    widget.controller.handleEvent(message.message);
    try {
      final decoded = jsonDecode(message.message);

      if (decoded is! Map<String, dynamic>) return;

      switch (decoded['type']) {
        case 'globe-ready':
          debugPrint('FPVManager: CesiumJS globe initialized');

        case 'point-selected':
          final latitude = decoded['latitude'];
          final longitude = decoded['longitude'];
          final altitude = decoded['altitude'];

          if (latitude is num &&
              longitude is num &&
              altitude is num &&
              mounted) {
            setState(() {
              _coordinates =
                  '${latitude.toStringAsFixed(5)}, '
                  '${longitude.toStringAsFixed(5)} | '
                  '${altitude.toStringAsFixed(1)} m';
            });
          }

        case 'globe-error':
          if (!mounted) return;

          setState(() {
            _error = decoded['message']?.toString() ?? 'Unknown globe error';
            _loading = false;
          });
      }
    } catch (error) {
      debugPrint('Invalid globe message: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
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

    return Stack(
      fit: StackFit.expand,
      children: [
        WebViewWidget(controller: controller),

        if (_loading) const Center(child: CircularProgressIndicator()),

        if (_coordinates != null)
          Positioned(
            left: 12,
            right: 12,
            bottom: 12,
            child: IgnorePointer(
              child: Center(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: const Color(0xDD101820),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Text(_coordinates!, textAlign: TextAlign.center),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
