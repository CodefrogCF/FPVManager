import 'dart:js_interop';

import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

import 'globe_controller.dart';
import '../../core/performance/app_lifecycle_probe.dart';
import 'globe_input_scope.dart';
import 'globe_page_path.dart';
import 'globe_view_lifecycle_policy.dart';

class GlobeView extends StatefulWidget {
  const GlobeView({
    super.key,
    required this.controller,
    this.offline = false,
    this.cachedMaps = false,
    this.cacheRevision = 0,
    this.floatingControls = false,
    this.menuOpen = false,
  });

  final GlobeController controller;
  final bool offline;
  final bool cachedMaps;
  final int cacheRevision;
  final bool floatingControls;
  final bool menuOpen;

  @override
  State<GlobeView> createState() => _GlobeViewState();
}

class _GlobeViewState extends State<GlobeView> with WidgetsBindingObserver {
  web.HTMLIFrameElement? _iframe;
  late final JSFunction _messageListener;
  bool _inputEnabled = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // HTML iframes handle DOM input before Flutter can hit-test the painted
    // menu, dialog or modal barrier above them. CSS must gate the iframe too.
    _inputEnabled =
        (ModalRoute.isCurrentOf(context) ?? true) &&
        GlobeInputScope.enabledOf(context);
    _applyInputState();
  }

  void _applyInputState() {
    final iframe = _iframe;
    if (iframe == null) return;
    iframe.style.pointerEvents = _inputEnabled ? 'auto' : 'none';
    iframe.tabIndex = _inputEnabled ? 0 : -1;
    if (!_inputEnabled) iframe.blur();
  }

  @override
  void initState() {
    super.initState();

    widget.controller.attach(_sendCommand);
    AppLifecycleProbe.record('web-globe-view-created');
    WidgetsBinding.instance.addObserver(this);

    _messageListener = ((web.Event event) {
      if (!mounted) return;

      final message = event as web.MessageEvent;

      if (message.origin != web.window.location.origin ||
          message.source != _iframe?.contentWindow) {
        return;
      }

      final data = message.data.dartify();

      if (data is String) {
        widget.controller.handleEvent(data);
      }
    }).toJS;

    web.window.addEventListener('message', _messageListener);
  }

  Future<void> _sendCommand(String command) async {
    final target = _iframe?.contentWindow;

    if (target == null) {
      throw StateError('Globe iframe is unavailable');
    }

    target.postMessage(command.toJS, web.window.location.origin.toJS);
  }

  @override
  void didUpdateWidget(covariant GlobeView oldWidget) {
    super.didUpdateWidget(oldWidget);

    final controllerChanged = GlobeViewLifecyclePolicy.reconnectBridge(
      oldWidget.controller,
      widget.controller,
    );
    if (controllerChanged) {
      // Cache and view-setting changes must not disconnect the existing
      // bridge; detaching also resets flight and route playback state.
      oldWidget.controller.detach();
      widget.controller.attach(_sendCommand);
    }
    if (GlobeViewLifecyclePolicy.reloadDocument(
      controllerChanged: controllerChanged,
      previousCachedMaps: oldWidget.cachedMaps,
      cachedMaps: widget.cachedMaps,
      previousCacheRevision: oldWidget.cacheRevision,
      cacheRevision: widget.cacheRevision,
      previousFloatingControls: oldWidget.floatingControls,
      floatingControls: widget.floatingControls,
    )) {
      // Cache changes can require a document reload, but not a second
      // bridge attachment while the controller instance is unchanged.
      _iframe?.src = _page;
      AppLifecycleProbe.record('web-iframe-navigation');
    }
  }

  String get _page => globePagePath(
    offline: widget.offline,
    cachedMaps: widget.cachedMaps,
    floatingControls: widget.floatingControls,
  );

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    web.window.removeEventListener('message', _messageListener);

    widget.controller.detach();
    AppLifecycleProbe.record('web-globe-view-disposed');
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    AppLifecycleProbe.appState(state);
    if (state == AppLifecycleState.resumed) {
      _iframe?.contentWindow?.postMessage(
        'fpvmanager-hello'.toJS,
        web.window.location.origin.toJS,
      );
    } else if (state == AppLifecycleState.paused) {
      widget.controller.suspend();
    }
  }

  @override
  Widget build(BuildContext context) {
    return HtmlElementView.fromTagName(
      tagName: 'iframe',
      onElementCreated: (Object element) {
        final iframe = element as web.HTMLIFrameElement;

        iframe.src = _page;

        iframe.style
          ..width = '100%'
          ..height = '100%'
          ..border = '0';

        iframe.setAttribute('title', 'FPVManager 3D Globe');

        _iframe = iframe;
        _applyInputState();
      },
    );
  }
}
