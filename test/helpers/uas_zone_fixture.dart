const uasFixtureAttributes = <String, String>{
  'identifier': 'fixture-zone-1',
  'name': 'Fixture zone',
  'type': 'COMMON',
  'reason': 'NATURE',
  'restriction': 'REQ_AUTHORISATION',
  'restrictionConditions': 'Synthetic restriction supplied by the fixture.',
  'message': 'Synthetic authority information.',
  'permanent': 'YES',
  'startDateTime': '',
  'endDateTime': '',
  'startTime': '00:00:00.00+02:00',
  'endTime': '00:00:00.00+02:00',
  'uomDimensions': 'M',
  'lowerLimit': '0',
  'lowerVerticalReference': 'AGL',
  'upperLimit': '900',
  'upperVerticalReference': 'AMSL',
  'authorityName': 'Fixture authority',
  'siteURL': 'https://example.invalid/authority',
};

Map<String, dynamic> uasFixtureFeature({
  Map<String, Object?> overrides = const {},
}) => {
  'type': 'Feature',
  'geometry': {
    'type': 'Polygon',
    'coordinates': [
      [
        [8.0, 47.0],
        [8.1, 47.0],
        [8.1, 47.1],
        [8.0, 47.0],
      ],
    ],
  },
  'properties': {...uasFixtureAttributes, ...overrides},
};

Map<String, dynamic> uasFixtureCollection(List<Object?> features) => {
  'type': 'FeatureCollection',
  'features': features,
};
