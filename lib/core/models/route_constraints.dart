enum RouteVisibilityMode { unverified, vlos, fpvWithObserver, bvlos }

class RouteConstraints {
  const RouteConstraints({
    this.legalCeilingAgl = 120,
    this.operationalCeilingAgl,
    this.planningRadiusMeters,
    this.visibility = RouteVisibilityMode.unverified,
  });
  final double? legalCeilingAgl, operationalCeilingAgl, planningRadiusMeters;
  final RouteVisibilityMode visibility;
  void validate() {
    for (final n in [
      legalCeilingAgl,
      operationalCeilingAgl,
      planningRadiusMeters,
    ]) {
      if (n != null && (!n.isFinite || n < 0 || n > 100000)) {
        throw ArgumentError('Constraint must be between 0 and 100000 m');
      }
    }
  }

  Map<String, dynamic> toJson() => {
    'legalCeilingAgl': legalCeilingAgl,
    'operationalCeilingAgl': operationalCeilingAgl,
    'planningRadiusMeters': planningRadiusMeters,
    'visibility': visibility.name,
  };
  factory RouteConstraints.fromJson(Map<String, dynamic> j) {
    final v = RouteConstraints(
      legalCeilingAgl: (j['legalCeilingAgl'] as num?)?.toDouble(),
      operationalCeilingAgl: (j['operationalCeilingAgl'] as num?)?.toDouble(),
      planningRadiusMeters: (j['planningRadiusMeters'] as num?)?.toDouble(),
      visibility: RouteVisibilityMode.values.byName(j['visibility'] as String),
    );
    v.validate();
    return v;
  }
}
