import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

/// Web implementation of the CesiumJS globe.
class GlobeView extends StatelessWidget {
  const GlobeView({super.key});

  @override
  Widget build(BuildContext context) {
    return HtmlElementView.fromTagName(
      tagName: 'iframe',
      onElementCreated: (Object element) {
        final iframe = element as web.HTMLIFrameElement;

        iframe.src = 'globe.html';

        iframe.style
          ..width = '100%'
          ..height = '100%'
          ..border = '0';

        iframe.setAttribute('title', 'FPVManager 3D Globe');
      },
    );
  }
}
