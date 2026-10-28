@TestOn('browser')
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:web/web.dart' as web;
import 'package:fpvmanager/features/home/home_map_workspace.dart';

void main() {
  testWidgets(
    'floating controls intercept DOM hits while uncovered globe remains interactive',
    (tester) async {
      var presses = 0;
      await tester.binding.setSurfaceSize(const Size(800, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HomeMapWorkspace(
              globe: HtmlElementView.fromTagName(
                tagName: 'iframe',
                onElementCreated: (element) {
                  final frame = element as web.HTMLIFrameElement;
                  frame.id = 'pointer-test-globe';
                  frame.src = 'about:blank';
                  frame.style
                    ..width = '100%'
                    ..height = '100%'
                    ..border = '0';
                },
              ),
              navigation: IconButton(
                tooltip: 'Navigation',
                onPressed: () => presses++,
                icon: const Icon(Icons.menu),
              ),
              actions: IconButton(
                tooltip: 'Layers',
                onPressed: () => presses++,
                icon: const Icon(Icons.layers_outlined),
              ),
              selection: const SizedBox.shrink(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)),
      );
      final centre = tester.getCenter(find.byTooltip('Layers'));
      expect(
        web.document.elementFromPoint(centre.dx, centre.dy)?.tagName,
        isNot('IFRAME'),
      );
      expect(web.document.elementFromPoint(400, 300)?.id, 'pointer-test-globe');
      await tester.tap(find.byTooltip('Layers'));
      await tester.pumpAndSettle();
      expect(presses, 1);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );
}
