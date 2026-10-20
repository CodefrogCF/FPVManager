import 'package:flutter/foundation.dart';

import 'osint_dataset.dart';
import 'osint_provider_state.dart';
import 'osint_source.dart';

abstract interface class OsintProvider<T> implements Listenable {
  OsintSource get source;

  String get id;

  Uri get sourceUri;

  OsintProviderState<T> get status;

  Future<OsintDataset<T>> fetch({bool forceRefresh = false});

  void dispose();
}
