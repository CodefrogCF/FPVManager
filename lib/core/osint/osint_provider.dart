import 'osint_dataset.dart';

abstract interface class OsintProvider<T> {
  String get id;

  Uri get sourceUri;

  Future<OsintDataset<T>> fetch({bool forceRefresh = false});

  void dispose();
}
