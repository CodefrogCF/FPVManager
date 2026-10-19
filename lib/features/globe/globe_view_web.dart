import 'dart:js_interop';

import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

import 'globe_controller.dart';

class GlobeView extends StatefulWidget {
  const GlobeView({super.key, required this.controller, this.offline = false});

  final GlobeController controller;
  final bool offline;

  @override
  State<GlobeView> createState() => _GlobeViewState();
}

class _GlobeViewState extends State<GlobeView> with WidgetsBindingObserver {
  web.HTMLIFrameElement? _iframe;
  late final JSFunction _messageListener;

  @override
  void initState() {
    super.initState();

    widget.controller.attach(_sendCommand);
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

    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.detach();
      widget.controller.attach(_sendCommand);
      // A new controller starts its request/marker IDs from the beginning.
      // Reload so the renderer creates a fresh protocol session as well.
      _iframe?.src = widget.offline ? 'globe.html?offline=1' : 'globe.html';
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    web.window.removeEventListener('message', _messageListener);

    widget.controller.detach();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
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

        iframe.src = widget.offline ? 'globe.html?offline=1' : 'globe.html';

        iframe.style
          ..width = '100%'
          ..height = '100%'
          ..border = '0';

        iframe.setAttribute('title', 'FPVManager 3D Globe');

        _iframe = iframe;
      },
    );
  }
}
