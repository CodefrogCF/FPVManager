import 'package:fpvmanager/core/osint/osint_dataset.dart';
import 'package:fpvmanager/core/osint/osint_provider_state.dart';
import 'package:fpvmanager/features/mobility/road_routing.dart';
import 'package:fpvmanager/features/mobility/situational_provider.dart';

import 'route_traffic_fixtures.dart';

class RouteTrafficProvider extends SituationalProvider {
  RouteTrafficProvider(OsintProviderState<Map<String, dynamic>> state)
    : current = state,
      super(
        kind: SituationalKind.traffic,
        center: MobilityPoint(47, 8),
        now: () => trafficTime,
      );
  OsintProviderState<Map<String, dynamic>> current;
  @override
  OsintProviderState<Map<String, dynamic>> get status => current;
  void publish(OsintProviderState<Map<String, dynamic>> state) {
    current = state;
    notifyListeners();
  }

  @override
  Future<OsintDataset<Map<String, dynamic>>> download() async =>
      current.dataset!;
}
