import 'package:flutter_test/flutter_test.dart';
import 'package:fpvmanager/features/globe/globe_controller.dart';
import 'package:fpvmanager/features/globe/globe_view_status.dart';

void main() {
  test('identical displayed values do not change native map chrome', () {
    final globe = GlobeController();
    addTearDown(globe.dispose);
    final initial = GlobeViewStatus.fromController(globe);
    expect(initial, const GlobeViewStatus());
    expect(GlobeViewStatus.fromController(globe), initial);
    expect(initial.hashCode, GlobeViewStatus.fromController(globe).hashCode);
    expect(const GlobeViewStatus(error: 'load failed'), isNot(initial));
    expect(const GlobeViewStatus(coordinates: '46.0, 8.0'), isNot(initial));
  });
}
