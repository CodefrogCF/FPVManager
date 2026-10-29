import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:web/web.dart' as web;

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
  web.HTMLIFrameElement? _iframe;
  late final JSFunction _listener;
  @override
  void initState() {
    super.initState();
    _listener = ((web.Event event) {
      unawaited(_handleMessage(event));
    }).toJS;
    web.window.addEventListener('message', _listener);
  }

  Future<void> _handleMessage(web.Event event) async {
    final e = event as web.MessageEvent;
    if (!mounted ||
        e.origin != web.window.location.origin ||
        e.source != _iframe?.contentWindow) {
      return;
    }
    final data = e.data.dartify();
    if (data is! String) return;
    try {
      final m = (jsonDecode(data) as Map)['offlinePreparation'] as Map?;
      if (m == null) return;
      if (m['type'] == 'ready') {
        final grid = await rootBundle.load('assets/geo/chgeo2004_ln02.bin');
        if (mounted) {
          _iframe?.contentWindow?.postMessage(
            jsonEncode({
              'startOffline': true,
              'config': widget.config,
              'grid': base64Encode(
                grid.buffer.asUint8List(grid.offsetInBytes, grid.lengthInBytes),
              ),
            }).toJS,
            web.window.location.origin.toJS,
          );
        }
      }
      if (m['type'] == 'complete') {
        widget.onComplete(
          OfflineRegion.fromJson(Map<String, dynamic>.from(m['region'] as Map)),
        );
      }
    } catch (_) {
      /* The page keeps its own user-visible failure status. */
    }
  }

  @override
  void dispose() {
    web.window.removeEventListener('message', _listener);
    _iframe?.src = 'about:blank';
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => HtmlElementView.fromTagName(
    tagName: 'iframe',
    onElementCreated: (element) {
      final frame = element as web.HTMLIFrameElement;
      _iframe = frame;
      frame.src = Uri.base.resolve('offline_preparation.html').toString();
      frame.style
        ..width = '100%'
        ..height = '100%'
        ..border = '0';
      frame.setAttribute('title', 'Offline-Bereich aufbereiten');
    },
  );
}
