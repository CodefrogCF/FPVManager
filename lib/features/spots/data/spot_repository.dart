import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../core/database/fpv_database.dart';
import '../../../core/database/repository_validation.dart';
import '../../../core/models/spot_classification.dart';
import 'spot_photo.dart';
import 'spot_query.dart';

abstract interface class SpotRepository {
  const factory SpotRepository(FpvDatabase database) = DriftSpotRepository;

  Future<int> createSpot({
    required String name,
    required double latitude,
    required double longitude,
    String? notes,
    List<PreparedSpotPhoto> photos = const [],
    SpotClassification? classification,
  });
  Future<List<Spot>> getAllSpots();
  Stream<List<Spot>> watchSpots();
  Future<Spot?> getSpot(int id);
  Future<bool> updateSpot({
    required int id,
    required String name,
    required double latitude,
    required double longitude,
    String? notes,
    List<int>? retainedPhotoIds,
    List<PreparedSpotPhoto> newPhotos = const [],
    SpotClassification? classification,
  });
  Future<int> deleteSpot(int id);
  Future<bool> setFavorite({required int id, required bool isFavorite});
  Future<List<SpotPhotoPreview>> getPhotos(int spotId);
  Stream<List<SpotPhotoPreview>> watchPhotos(int spotId);
  Future<Uint8List?> getPhotoBytes({required int spotId, required int photoId});
  Future<SpotPage> getSpotPage({
    SpotFilter? filter,
    int? beforeId,
    int limit = 50,
  });
  Stream<SpotPage> watchSpotPage({
    SpotFilter? filter,
    int? beforeId,
    int limit = 50,
  });
  Stream<List<SpotMapEntry>> watchMapSpots();
  Stream<void> watchListChanges();
  Future<List<String>> getTags(int spotId);
  Stream<SpotDetails?> watchDetails(int spotId);
  Future<List<String>> findCategories(String prefix, {int limit = 20});
  Future<List<String>> findTags(String prefix, {int limit = 20});
}

final class DriftSpotRepository implements SpotRepository {
  const DriftSpotRepository(this._database);

  final FpvDatabase _database;

  @override
  Stream<void> watchListChanges() => _database
      .tableUpdates(
        TableUpdateQuery.onAllTables([_database.spots, _database.spotTags]),
      )
      .map((_) {});

  void _validate({
    required String name,
    required double latitude,
    required double longitude,
  }) {
    RepositoryValidation.text(name, 'name');
    RepositoryValidation.coordinates(latitude, longitude);
  }

  @override
  Future<int> createSpot({
    required String name,
    required double latitude,
    required double longitude,
    String? notes,
    List<PreparedSpotPhoto> photos = const [],
    SpotClassification? classification,
  }) {
    _validate(name: name, latitude: latitude, longitude: longitude);
    final prepared = _validatePhotos(photos);
    final labels = classification ?? SpotClassification();
    return _database.transaction(() async {
      final id = await _database
          .into(_database.spots)
          .insert(
            SpotsCompanion.insert(
              name: name.trim(),
              latitude: latitude,
              longitude: longitude,
              notes: Value(notes),
              category: Value(labels.category),
              categoryKey: Value(labels.categoryKey),
              searchText: Value(
                SpotClassification.searchText(
                  name: name.trim(),
                  notes: notes,
                  category: labels.category,
                  tags: labels.tags,
                ),
              ),
            ),
          );
      await _insertPhotos(id, prepared);
      await _insertTags(id, labels.tags);
      return id;
    });
  }

  @override
  Future<List<Spot>> getAllSpots() {
    return (_database.select(_database.spots)..orderBy([
          (table) =>
              OrderingTerm(expression: table.id, mode: OrderingMode.desc),
        ]))
        .get();
  }

  @override
  Stream<List<Spot>> watchSpots() {
    return (_database.select(_database.spots)..orderBy([
          (table) =>
              OrderingTerm(expression: table.id, mode: OrderingMode.desc),
        ]))
        .watch();
  }

  @override
  Future<Spot?> getSpot(int id) {
    RepositoryValidation.id(id);
    return (_database.select(
      _database.spots,
    )..where((table) => table.id.equals(id))).getSingleOrNull();
  }

  @override
  Future<bool> updateSpot({
    required int id,
    required String name,
    required double latitude,
    required double longitude,
    String? notes,
    List<int>? retainedPhotoIds,
    List<PreparedSpotPhoto> newPhotos = const [],
    SpotClassification? classification,
  }) async {
    RepositoryValidation.id(id);
    _validate(name: name, latitude: latitude, longitude: longitude);

    final prepared = _validatePhotos(newPhotos);
    final retained = retainedPhotoIds == null
        ? null
        : List<int>.unmodifiable(retainedPhotoIds);
    if (retained != null) {
      for (final photoId in retained) {
        RepositoryValidation.id(photoId);
      }
      if (retained.toSet().length != retained.length) {
        throw ArgumentError('Duplicate photo IDs');
      }
    }
    return _database.transaction(() async {
      final current = await getSpot(id);
      if (current == null) return false;
      final labels =
          classification ??
          SpotClassification(
            category: current.category,
            tags: await getTags(id),
          );
      final table = _database.spotPhotos;
      final existing =
          await (_database.selectOnly(table)
                ..addColumns([table.id])
                ..where(table.spotId.equals(id)))
              .map((row) => row.read(table.id)!)
              .get();
      if (retained != null &&
          !retained.every((photoId) => existing.contains(photoId))) {
        throw ArgumentError(
          'Photo does not belong to this spot or was removed',
        );
      }
      final keptCount = retained?.length ?? existing.length;
      if (keptCount + prepared.length > SpotPhotoLimits.maxPhotos) {
        throw ArgumentError('A spot can have at most six photos');
      }
      final changed =
          await (_database.update(
            _database.spots,
          )..where((table) => table.id.equals(id))).write(
            SpotsCompanion(
              name: Value(name.trim()),
              latitude: Value(latitude),
              longitude: Value(longitude),
              notes: Value(notes),
              category: Value(labels.category),
              categoryKey: Value(labels.categoryKey),
              searchText: Value(
                SpotClassification.searchText(
                  name: name.trim(),
                  notes: notes,
                  category: labels.category,
                  tags: labels.tags,
                ),
              ),
            ),
          );

      if (changed == 0) return false;
      if (retained != null) {
        await (_database.delete(_database.spotPhotos)..where(
              (table) => table.spotId.equals(id) & table.id.isNotIn(retained),
            ))
            .go();
      }
      await _insertPhotos(id, prepared);
      if (classification != null) {
        await (_database.delete(
          _database.spotTags,
        )..where((table) => table.spotId.equals(id))).go();
        await _insertTags(id, labels.tags);
      }
      return true;
    });
  }

  /// Optional source metadata for OSM-imported spots. Never merged into
  /// user-controlled name, coordinates, notes or classification on refresh.
  Future<Map<String, dynamic>?> osmProvenance(int id) async {
    RepositoryValidation.id(id);
    final row = await (_database.select(
      _database.appSettings,
    )..where((s) => s.key.equals('spot.osm.source.$id.v1'))).getSingleOrNull();
    if (row == null) {
      return null;
    }
    try {
      return Map<String, dynamic>.from(jsonDecode(row.value) as Map);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<int> deleteSpot(int id) {
    RepositoryValidation.id(id);
    return _database.transaction(() async {
      // Keep the OSM provenance/index linked to this personal spot only.
      final osmSource =
          await (_database.select(_database.appSettings)
                ..where((s) => s.key.equals('spot.osm.source.$id.v1')))
              .getSingleOrNull();
      if (osmSource != null) {
        try {
          final metadata = jsonDecode(osmSource.value) as Map;
          final reference = metadata['reference'];
          if (reference is String &&
              RegExp(r'^(node|way|relation)/[1-9][0-9]*$')
                  .hasMatch(reference)) {
            final parts = reference.split('/');
            final indexKey = 'spot.osm.index.${parts[0]}.${parts[1]}.v1';
            await (_database.delete(
                  _database.appSettings,
                )..where((s) => s.key.equals(indexKey) & s.value.equals('$id')))
                .go();
          }
        } on FormatException {
          // Invalid metadata should not prevent a user from deleting their spot.
        } on TypeError {
          // Treat malformed provenance as non-authoritative.
        }
        await (_database.delete(
          _database.appSettings,
        )..where((s) => s.key.equals('spot.osm.source.$id.v1'))).go();
      }
      // Spot-owned access notes must not survive deletion of their spot.
      await (_database.delete(
        _database.appSettings,
      )..where((table) => table.key.equals('mobility.access.$id.v1'))).go();
      return (_database.delete(
        _database.spots,
      )..where((table) => table.id.equals(id))).go();
    });
  }

  @override
  Future<bool> setFavorite({required int id, required bool isFavorite}) async {
    RepositoryValidation.id(id);
    return await (_database.update(_database.spots)
              ..where((table) => table.id.equals(id)))
            .write(SpotsCompanion(isFavorite: Value(isFavorite))) >
        0;
  }

  List<PreparedSpotPhoto> _validatePhotos(List<PreparedSpotPhoto> photos) {
    final snapshot = List<PreparedSpotPhoto>.unmodifiable(photos);
    if (snapshot.length > SpotPhotoLimits.maxPhotos) {
      throw ArgumentError('A spot can have at most six photos');
    }
    for (final photo in snapshot) {
      bool isJpeg(Uint8List bytes, int limit) =>
          bytes.length >= 4 &&
          bytes.length <= limit &&
          bytes[0] == 0xff &&
          bytes[1] == 0xd8 &&
          bytes[bytes.length - 2] == 0xff &&
          bytes.last == 0xd9;
      if (photo.width <= 0 ||
          photo.height <= 0 ||
          photo.width > SpotPhotoLimits.maxImageEdge ||
          photo.height > SpotPhotoLimits.maxImageEdge ||
          !isJpeg(photo.imageBytes, SpotPhotoLimits.maxImageBytes) ||
          !isJpeg(photo.thumbnailBytes, SpotPhotoLimits.maxThumbnailBytes)) {
        throw ArgumentError('Invalid prepared spot photo');
      }
    }
    return snapshot;
  }

  Future<void> _insertPhotos(int spotId, List<PreparedSpotPhoto> photos) =>
      _database.batch((batch) {
        batch.insertAll(_database.spotPhotos, [
          for (final photo in photos)
            SpotPhotosCompanion.insert(
              spotId: spotId,
              imageBytes: photo.imageBytes,
              thumbnailBytes: photo.thumbnailBytes,
              width: photo.width,
              height: photo.height,
            ),
        ]);
      });

  Selectable<SpotPhotoPreview> _photoQuery(int spotId) {
    RepositoryValidation.id(spotId);
    final table = _database.spotPhotos;
    return (_database.selectOnly(table)
          ..addColumns([
            table.id,
            table.spotId,
            table.thumbnailBytes,
            table.width,
            table.height,
          ])
          ..where(table.spotId.equals(spotId))
          ..orderBy([OrderingTerm.asc(table.id)]))
        .map(
          (row) => SpotPhotoPreview(
            id: row.read(table.id)!,
            spotId: row.read(table.spotId)!,
            thumbnailBytes: row
                .read(table.thumbnailBytes)!
                .asUnmodifiableView(),
            width: row.read(table.width)!,
            height: row.read(table.height)!,
          ),
        );
  }

  @override
  Future<List<SpotPhotoPreview>> getPhotos(int spotId) =>
      _photoQuery(spotId).get();

  @override
  Stream<List<SpotPhotoPreview>> watchPhotos(int spotId) =>
      _photoQuery(spotId).watch();

  @override
  Future<Uint8List?> getPhotoBytes({
    required int spotId,
    required int photoId,
  }) async {
    RepositoryValidation.id(spotId);
    RepositoryValidation.id(photoId);
    final table = _database.spotPhotos;
    final row =
        await (_database.selectOnly(table)
              ..addColumns([table.imageBytes])
              ..where(table.spotId.equals(spotId) & table.id.equals(photoId)))
            .getSingleOrNull();
    return row?.read(table.imageBytes)?.asUnmodifiableView();
  }

  Future<void> _insertTags(int spotId, List<String> tags) =>
      _database.batch((batch) {
        batch.insertAll(_database.spotTags, [
          for (final tag in tags)
            SpotTagsCompanion.insert(spotId: spotId, tag: tag),
        ]);
      });

  @override
  Future<List<String>> getTags(int spotId) {
    RepositoryValidation.id(spotId);
    return (_database.selectOnly(_database.spotTags)
          ..addColumns([_database.spotTags.tag])
          ..where(_database.spotTags.spotId.equals(spotId))
          ..orderBy([OrderingTerm.asc(_database.spotTags.tag)]))
        .map((row) => row.read(_database.spotTags.tag)!)
        .get();
  }

  void _limit(int value) {
    if (value < 1 || value > 100) {
      throw ArgumentError('Page/option limit must be between 1 and 100');
    }
  }

  Selectable<SpotSummary> _pageQuery(
    SpotFilter filter,
    int? beforeId,
    int limit,
  ) {
    _limit(limit);
    RepositoryValidation.optionalId(beforeId);
    final clauses = <String>[];
    final variables = <Variable>[];
    for (final term in filter.terms) {
      clauses.add('instr(s.search_text, ?) > 0');
      variables.add(Variable.withString(term));
    }
    if (filter.favoritesOnly) clauses.add('s.is_favorite = 1');
    if (filter.classification.category != null) {
      clauses.add('s.category_key = ?');
      variables.add(Variable.withString(filter.classification.categoryKey));
    }
    for (final tag in filter.classification.tags) {
      clauses.add(
        'EXISTS (SELECT 1 FROM spot_tags f WHERE f.spot_id = s.id AND f.tag = ?)',
      );
      variables.add(Variable.withString(tag));
    }
    if (beforeId != null) {
      clauses.add('s.id < ?');
      variables.add(Variable.withInt(beforeId));
    }
    variables.add(Variable.withInt(limit + 1));
    return _database
        .customSelect(
          '''
      SELECT s.id, s.name, s.latitude, s.longitude, s.is_favorite, s.category,
             substr(coalesce(s.notes, ''), 1, 120) AS notes_preview,
             (SELECT group_concat(tag, char(31)) FROM
               (SELECT tag FROM spot_tags WHERE spot_id = s.id ORDER BY tag)) AS tags
      FROM spots s
      ${clauses.isEmpty ? '' : 'WHERE ${clauses.join(' AND ')}'}
      ORDER BY s.id DESC LIMIT ?
    ''',
          variables: variables,
          readsFrom: {_database.spots, _database.spotTags},
        )
        .map(
          (row) => SpotSummary(
            id: row.read<int>('id'),
            name: row.read<String>('name'),
            latitude: row.read<double>('latitude'),
            longitude: row.read<double>('longitude'),
            isFavorite: row.read<bool>('is_favorite'),
            category: row.readNullable<String>('category'),
            notesPreview: row.read<String>('notes_preview'),
            tags: row.readNullable<String>('tags')?.split('\u001f') ?? const [],
          ),
        );
  }

  SpotPage _page(List<SpotSummary> rows, int limit) =>
      SpotPage(items: rows.take(limit), hasNext: rows.length > limit);

  @override
  Future<SpotPage> getSpotPage({
    SpotFilter? filter,
    int? beforeId,
    int limit = 50,
  }) async => _page(
    await _pageQuery(filter ?? SpotFilter(), beforeId, limit).get(),
    limit,
  );

  @override
  Stream<SpotPage> watchSpotPage({
    SpotFilter? filter,
    int? beforeId,
    int limit = 50,
  }) => _pageQuery(
    filter ?? SpotFilter(),
    beforeId,
    limit,
  ).watch().map((rows) => _page(rows, limit));

  @override
  Stream<SpotDetails?> watchDetails(int spotId) {
    RepositoryValidation.id(spotId);
    final spots = _database.spots;
    final tags = _database.spotTags;
    return (_database.select(spots).join([
            leftOuterJoin(tags, tags.spotId.equalsExp(spots.id)),
          ])
          ..where(spots.id.equals(spotId))
          ..orderBy([OrderingTerm.asc(tags.tag)]))
        .watch()
        .map(
          (rows) => rows.isEmpty
              ? null
              : SpotDetails(
                  spot: rows.first.readTable(spots),
                  tags: [
                    for (final row in rows)
                      if (row.readTableOrNull(tags) case final tag?) tag.tag,
                  ],
                ),
        );
  }

  @override
  Future<List<String>> findCategories(String prefix, {int limit = 20}) {
    _limit(limit);
    return _database
        .customSelect(
          'SELECT min(category) AS value FROM spots WHERE category IS NOT NULL AND instr(category_key, ?) > 0 GROUP BY category_key ORDER BY category_key LIMIT ?',
          variables: [
            Variable.withString(prefix.trim().toLowerCase()),
            Variable.withInt(limit),
          ],
          readsFrom: {_database.spots},
        )
        .map((row) => row.read<String>('value'))
        .get();
  }

  @override
  Future<List<String>> findTags(String prefix, {int limit = 20}) {
    _limit(limit);
    return _database
        .customSelect(
          'SELECT DISTINCT tag AS value FROM spot_tags WHERE instr(tag, ?) > 0 ORDER BY tag LIMIT ?',
          variables: [
            Variable.withString(prefix.trim().toLowerCase()),
            Variable.withInt(limit),
          ],
          readsFrom: {_database.spotTags},
        )
        .map((row) => row.read<String>('value'))
        .get();
  }

  @override
  Stream<List<SpotMapEntry>> watchMapSpots() {
    final table = _database.spots;
    return (_database.selectOnly(table)
          ..addColumns([table.id, table.name, table.latitude, table.longitude])
          ..orderBy([OrderingTerm.desc(table.id)]))
        .watch()
        .map(
          (rows) => List<SpotMapEntry>.unmodifiable(
            rows.map(
              (row) => SpotMapEntry(
                id: row.read(table.id)!,
                name: row.read(table.name)!,
                latitude: row.read(table.latitude)!,
                longitude: row.read(table.longitude)!,
              ),
            ),
          ),
        )
        .distinct((previous, next) {
          if (previous.length != next.length) return false;
          for (var i = 0; i < previous.length; i++) {
            if (previous[i] != next[i]) return false;
          }
          return true;
        });
  }
}
