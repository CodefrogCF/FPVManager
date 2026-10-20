// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'fpv_database.dart';

// ignore_for_file: type=lint
class $SpotsTable extends Spots with TableInfo<$SpotsTable, Spot> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SpotsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 120,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _latitudeMeta = const VerificationMeta(
    'latitude',
  );
  @override
  late final GeneratedColumn<double> latitude = GeneratedColumn<double>(
    'latitude',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _longitudeMeta = const VerificationMeta(
    'longitude',
  );
  @override
  late final GeneratedColumn<double> longitude = GeneratedColumn<double>(
    'longitude',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _categoryMeta = const VerificationMeta(
    'category',
  );
  @override
  late final GeneratedColumn<String> category = GeneratedColumn<String>(
    'category',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _categoryKeyMeta = const VerificationMeta(
    'categoryKey',
  );
  @override
  late final GeneratedColumn<String> categoryKey = GeneratedColumn<String>(
    'category_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _searchTextMeta = const VerificationMeta(
    'searchText',
  );
  @override
  late final GeneratedColumn<String> searchText = GeneratedColumn<String>(
    'search_text',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _isFavoriteMeta = const VerificationMeta(
    'isFavorite',
  );
  @override
  late final GeneratedColumn<bool> isFavorite = GeneratedColumn<bool>(
    'is_favorite',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_favorite" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    latitude,
    longitude,
    notes,
    category,
    categoryKey,
    searchText,
    isFavorite,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'spots';
  @override
  VerificationContext validateIntegrity(
    Insertable<Spot> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('latitude')) {
      context.handle(
        _latitudeMeta,
        latitude.isAcceptableOrUnknown(data['latitude']!, _latitudeMeta),
      );
    } else if (isInserting) {
      context.missing(_latitudeMeta);
    }
    if (data.containsKey('longitude')) {
      context.handle(
        _longitudeMeta,
        longitude.isAcceptableOrUnknown(data['longitude']!, _longitudeMeta),
      );
    } else if (isInserting) {
      context.missing(_longitudeMeta);
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    if (data.containsKey('category')) {
      context.handle(
        _categoryMeta,
        category.isAcceptableOrUnknown(data['category']!, _categoryMeta),
      );
    }
    if (data.containsKey('category_key')) {
      context.handle(
        _categoryKeyMeta,
        categoryKey.isAcceptableOrUnknown(
          data['category_key']!,
          _categoryKeyMeta,
        ),
      );
    }
    if (data.containsKey('search_text')) {
      context.handle(
        _searchTextMeta,
        searchText.isAcceptableOrUnknown(data['search_text']!, _searchTextMeta),
      );
    }
    if (data.containsKey('is_favorite')) {
      context.handle(
        _isFavoriteMeta,
        isFavorite.isAcceptableOrUnknown(data['is_favorite']!, _isFavoriteMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Spot map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Spot(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      latitude: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}latitude'],
      )!,
      longitude: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}longitude'],
      )!,
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
      category: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category'],
      ),
      categoryKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category_key'],
      )!,
      searchText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}search_text'],
      )!,
      isFavorite: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_favorite'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $SpotsTable createAlias(String alias) {
    return $SpotsTable(attachedDatabase, alias);
  }
}

class Spot extends DataClass implements Insertable<Spot> {
  final int id;
  final String name;
  final double latitude;
  final double longitude;
  final String? notes;
  final String? category;
  final String categoryKey;
  final String searchText;
  final bool isFavorite;
  final DateTime createdAt;
  const Spot({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    this.notes,
    this.category,
    required this.categoryKey,
    required this.searchText,
    required this.isFavorite,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['latitude'] = Variable<double>(latitude);
    map['longitude'] = Variable<double>(longitude);
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    if (!nullToAbsent || category != null) {
      map['category'] = Variable<String>(category);
    }
    map['category_key'] = Variable<String>(categoryKey);
    map['search_text'] = Variable<String>(searchText);
    map['is_favorite'] = Variable<bool>(isFavorite);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  SpotsCompanion toCompanion(bool nullToAbsent) {
    return SpotsCompanion(
      id: Value(id),
      name: Value(name),
      latitude: Value(latitude),
      longitude: Value(longitude),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
      category: category == null && nullToAbsent
          ? const Value.absent()
          : Value(category),
      categoryKey: Value(categoryKey),
      searchText: Value(searchText),
      isFavorite: Value(isFavorite),
      createdAt: Value(createdAt),
    );
  }

  factory Spot.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Spot(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      latitude: serializer.fromJson<double>(json['latitude']),
      longitude: serializer.fromJson<double>(json['longitude']),
      notes: serializer.fromJson<String?>(json['notes']),
      category: serializer.fromJson<String?>(json['category']),
      categoryKey: serializer.fromJson<String>(json['categoryKey']),
      searchText: serializer.fromJson<String>(json['searchText']),
      isFavorite: serializer.fromJson<bool>(json['isFavorite']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'latitude': serializer.toJson<double>(latitude),
      'longitude': serializer.toJson<double>(longitude),
      'notes': serializer.toJson<String?>(notes),
      'category': serializer.toJson<String?>(category),
      'categoryKey': serializer.toJson<String>(categoryKey),
      'searchText': serializer.toJson<String>(searchText),
      'isFavorite': serializer.toJson<bool>(isFavorite),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  Spot copyWith({
    int? id,
    String? name,
    double? latitude,
    double? longitude,
    Value<String?> notes = const Value.absent(),
    Value<String?> category = const Value.absent(),
    String? categoryKey,
    String? searchText,
    bool? isFavorite,
    DateTime? createdAt,
  }) => Spot(
    id: id ?? this.id,
    name: name ?? this.name,
    latitude: latitude ?? this.latitude,
    longitude: longitude ?? this.longitude,
    notes: notes.present ? notes.value : this.notes,
    category: category.present ? category.value : this.category,
    categoryKey: categoryKey ?? this.categoryKey,
    searchText: searchText ?? this.searchText,
    isFavorite: isFavorite ?? this.isFavorite,
    createdAt: createdAt ?? this.createdAt,
  );
  Spot copyWithCompanion(SpotsCompanion data) {
    return Spot(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      latitude: data.latitude.present ? data.latitude.value : this.latitude,
      longitude: data.longitude.present ? data.longitude.value : this.longitude,
      notes: data.notes.present ? data.notes.value : this.notes,
      category: data.category.present ? data.category.value : this.category,
      categoryKey: data.categoryKey.present
          ? data.categoryKey.value
          : this.categoryKey,
      searchText: data.searchText.present
          ? data.searchText.value
          : this.searchText,
      isFavorite: data.isFavorite.present
          ? data.isFavorite.value
          : this.isFavorite,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Spot(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('latitude: $latitude, ')
          ..write('longitude: $longitude, ')
          ..write('notes: $notes, ')
          ..write('category: $category, ')
          ..write('categoryKey: $categoryKey, ')
          ..write('searchText: $searchText, ')
          ..write('isFavorite: $isFavorite, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    latitude,
    longitude,
    notes,
    category,
    categoryKey,
    searchText,
    isFavorite,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Spot &&
          other.id == this.id &&
          other.name == this.name &&
          other.latitude == this.latitude &&
          other.longitude == this.longitude &&
          other.notes == this.notes &&
          other.category == this.category &&
          other.categoryKey == this.categoryKey &&
          other.searchText == this.searchText &&
          other.isFavorite == this.isFavorite &&
          other.createdAt == this.createdAt);
}

class SpotsCompanion extends UpdateCompanion<Spot> {
  final Value<int> id;
  final Value<String> name;
  final Value<double> latitude;
  final Value<double> longitude;
  final Value<String?> notes;
  final Value<String?> category;
  final Value<String> categoryKey;
  final Value<String> searchText;
  final Value<bool> isFavorite;
  final Value<DateTime> createdAt;
  const SpotsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.latitude = const Value.absent(),
    this.longitude = const Value.absent(),
    this.notes = const Value.absent(),
    this.category = const Value.absent(),
    this.categoryKey = const Value.absent(),
    this.searchText = const Value.absent(),
    this.isFavorite = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  SpotsCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    required double latitude,
    required double longitude,
    this.notes = const Value.absent(),
    this.category = const Value.absent(),
    this.categoryKey = const Value.absent(),
    this.searchText = const Value.absent(),
    this.isFavorite = const Value.absent(),
    this.createdAt = const Value.absent(),
  }) : name = Value(name),
       latitude = Value(latitude),
       longitude = Value(longitude);
  static Insertable<Spot> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<double>? latitude,
    Expression<double>? longitude,
    Expression<String>? notes,
    Expression<String>? category,
    Expression<String>? categoryKey,
    Expression<String>? searchText,
    Expression<bool>? isFavorite,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (notes != null) 'notes': notes,
      if (category != null) 'category': category,
      if (categoryKey != null) 'category_key': categoryKey,
      if (searchText != null) 'search_text': searchText,
      if (isFavorite != null) 'is_favorite': isFavorite,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  SpotsCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<double>? latitude,
    Value<double>? longitude,
    Value<String?>? notes,
    Value<String?>? category,
    Value<String>? categoryKey,
    Value<String>? searchText,
    Value<bool>? isFavorite,
    Value<DateTime>? createdAt,
  }) {
    return SpotsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      notes: notes ?? this.notes,
      category: category ?? this.category,
      categoryKey: categoryKey ?? this.categoryKey,
      searchText: searchText ?? this.searchText,
      isFavorite: isFavorite ?? this.isFavorite,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (latitude.present) {
      map['latitude'] = Variable<double>(latitude.value);
    }
    if (longitude.present) {
      map['longitude'] = Variable<double>(longitude.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (category.present) {
      map['category'] = Variable<String>(category.value);
    }
    if (categoryKey.present) {
      map['category_key'] = Variable<String>(categoryKey.value);
    }
    if (searchText.present) {
      map['search_text'] = Variable<String>(searchText.value);
    }
    if (isFavorite.present) {
      map['is_favorite'] = Variable<bool>(isFavorite.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SpotsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('latitude: $latitude, ')
          ..write('longitude: $longitude, ')
          ..write('notes: $notes, ')
          ..write('category: $category, ')
          ..write('categoryKey: $categoryKey, ')
          ..write('searchText: $searchText, ')
          ..write('isFavorite: $isFavorite, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $SpotTagsTable extends SpotTags with TableInfo<$SpotTagsTable, SpotTag> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SpotTagsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _spotIdMeta = const VerificationMeta('spotId');
  @override
  late final GeneratedColumn<int> spotId = GeneratedColumn<int>(
    'spot_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES spots (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _tagMeta = const VerificationMeta('tag');
  @override
  late final GeneratedColumn<String> tag = GeneratedColumn<String>(
    'tag',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 32,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [spotId, tag];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'spot_tags';
  @override
  VerificationContext validateIntegrity(
    Insertable<SpotTag> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('spot_id')) {
      context.handle(
        _spotIdMeta,
        spotId.isAcceptableOrUnknown(data['spot_id']!, _spotIdMeta),
      );
    } else if (isInserting) {
      context.missing(_spotIdMeta);
    }
    if (data.containsKey('tag')) {
      context.handle(
        _tagMeta,
        tag.isAcceptableOrUnknown(data['tag']!, _tagMeta),
      );
    } else if (isInserting) {
      context.missing(_tagMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {spotId, tag};
  @override
  SpotTag map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SpotTag(
      spotId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}spot_id'],
      )!,
      tag: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tag'],
      )!,
    );
  }

  @override
  $SpotTagsTable createAlias(String alias) {
    return $SpotTagsTable(attachedDatabase, alias);
  }
}

class SpotTag extends DataClass implements Insertable<SpotTag> {
  final int spotId;
  final String tag;
  const SpotTag({required this.spotId, required this.tag});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['spot_id'] = Variable<int>(spotId);
    map['tag'] = Variable<String>(tag);
    return map;
  }

  SpotTagsCompanion toCompanion(bool nullToAbsent) {
    return SpotTagsCompanion(spotId: Value(spotId), tag: Value(tag));
  }

  factory SpotTag.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SpotTag(
      spotId: serializer.fromJson<int>(json['spotId']),
      tag: serializer.fromJson<String>(json['tag']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'spotId': serializer.toJson<int>(spotId),
      'tag': serializer.toJson<String>(tag),
    };
  }

  SpotTag copyWith({int? spotId, String? tag}) =>
      SpotTag(spotId: spotId ?? this.spotId, tag: tag ?? this.tag);
  SpotTag copyWithCompanion(SpotTagsCompanion data) {
    return SpotTag(
      spotId: data.spotId.present ? data.spotId.value : this.spotId,
      tag: data.tag.present ? data.tag.value : this.tag,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SpotTag(')
          ..write('spotId: $spotId, ')
          ..write('tag: $tag')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(spotId, tag);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SpotTag &&
          other.spotId == this.spotId &&
          other.tag == this.tag);
}

class SpotTagsCompanion extends UpdateCompanion<SpotTag> {
  final Value<int> spotId;
  final Value<String> tag;
  final Value<int> rowid;
  const SpotTagsCompanion({
    this.spotId = const Value.absent(),
    this.tag = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SpotTagsCompanion.insert({
    required int spotId,
    required String tag,
    this.rowid = const Value.absent(),
  }) : spotId = Value(spotId),
       tag = Value(tag);
  static Insertable<SpotTag> custom({
    Expression<int>? spotId,
    Expression<String>? tag,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (spotId != null) 'spot_id': spotId,
      if (tag != null) 'tag': tag,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SpotTagsCompanion copyWith({
    Value<int>? spotId,
    Value<String>? tag,
    Value<int>? rowid,
  }) {
    return SpotTagsCompanion(
      spotId: spotId ?? this.spotId,
      tag: tag ?? this.tag,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (spotId.present) {
      map['spot_id'] = Variable<int>(spotId.value);
    }
    if (tag.present) {
      map['tag'] = Variable<String>(tag.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SpotTagsCompanion(')
          ..write('spotId: $spotId, ')
          ..write('tag: $tag, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SpotPhotosTable extends SpotPhotos
    with TableInfo<$SpotPhotosTable, SpotPhoto> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SpotPhotosTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _spotIdMeta = const VerificationMeta('spotId');
  @override
  late final GeneratedColumn<int> spotId = GeneratedColumn<int>(
    'spot_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES spots (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _imageBytesMeta = const VerificationMeta(
    'imageBytes',
  );
  @override
  late final GeneratedColumn<Uint8List> imageBytes = GeneratedColumn<Uint8List>(
    'image_bytes',
    aliasedName,
    false,
    type: DriftSqlType.blob,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _thumbnailBytesMeta = const VerificationMeta(
    'thumbnailBytes',
  );
  @override
  late final GeneratedColumn<Uint8List> thumbnailBytes =
      GeneratedColumn<Uint8List>(
        'thumbnail_bytes',
        aliasedName,
        false,
        type: DriftSqlType.blob,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _widthMeta = const VerificationMeta('width');
  @override
  late final GeneratedColumn<int> width = GeneratedColumn<int>(
    'width',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _heightMeta = const VerificationMeta('height');
  @override
  late final GeneratedColumn<int> height = GeneratedColumn<int>(
    'height',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    spotId,
    imageBytes,
    thumbnailBytes,
    width,
    height,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'spot_photos';
  @override
  VerificationContext validateIntegrity(
    Insertable<SpotPhoto> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('spot_id')) {
      context.handle(
        _spotIdMeta,
        spotId.isAcceptableOrUnknown(data['spot_id']!, _spotIdMeta),
      );
    } else if (isInserting) {
      context.missing(_spotIdMeta);
    }
    if (data.containsKey('image_bytes')) {
      context.handle(
        _imageBytesMeta,
        imageBytes.isAcceptableOrUnknown(data['image_bytes']!, _imageBytesMeta),
      );
    } else if (isInserting) {
      context.missing(_imageBytesMeta);
    }
    if (data.containsKey('thumbnail_bytes')) {
      context.handle(
        _thumbnailBytesMeta,
        thumbnailBytes.isAcceptableOrUnknown(
          data['thumbnail_bytes']!,
          _thumbnailBytesMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_thumbnailBytesMeta);
    }
    if (data.containsKey('width')) {
      context.handle(
        _widthMeta,
        width.isAcceptableOrUnknown(data['width']!, _widthMeta),
      );
    } else if (isInserting) {
      context.missing(_widthMeta);
    }
    if (data.containsKey('height')) {
      context.handle(
        _heightMeta,
        height.isAcceptableOrUnknown(data['height']!, _heightMeta),
      );
    } else if (isInserting) {
      context.missing(_heightMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SpotPhoto map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SpotPhoto(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      spotId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}spot_id'],
      )!,
      imageBytes: attachedDatabase.typeMapping.read(
        DriftSqlType.blob,
        data['${effectivePrefix}image_bytes'],
      )!,
      thumbnailBytes: attachedDatabase.typeMapping.read(
        DriftSqlType.blob,
        data['${effectivePrefix}thumbnail_bytes'],
      )!,
      width: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}width'],
      )!,
      height: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}height'],
      )!,
    );
  }

  @override
  $SpotPhotosTable createAlias(String alias) {
    return $SpotPhotosTable(attachedDatabase, alias);
  }
}

class SpotPhoto extends DataClass implements Insertable<SpotPhoto> {
  final int id;
  final int spotId;
  final Uint8List imageBytes;
  final Uint8List thumbnailBytes;
  final int width;
  final int height;
  const SpotPhoto({
    required this.id,
    required this.spotId,
    required this.imageBytes,
    required this.thumbnailBytes,
    required this.width,
    required this.height,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['spot_id'] = Variable<int>(spotId);
    map['image_bytes'] = Variable<Uint8List>(imageBytes);
    map['thumbnail_bytes'] = Variable<Uint8List>(thumbnailBytes);
    map['width'] = Variable<int>(width);
    map['height'] = Variable<int>(height);
    return map;
  }

  SpotPhotosCompanion toCompanion(bool nullToAbsent) {
    return SpotPhotosCompanion(
      id: Value(id),
      spotId: Value(spotId),
      imageBytes: Value(imageBytes),
      thumbnailBytes: Value(thumbnailBytes),
      width: Value(width),
      height: Value(height),
    );
  }

  factory SpotPhoto.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SpotPhoto(
      id: serializer.fromJson<int>(json['id']),
      spotId: serializer.fromJson<int>(json['spotId']),
      imageBytes: serializer.fromJson<Uint8List>(json['imageBytes']),
      thumbnailBytes: serializer.fromJson<Uint8List>(json['thumbnailBytes']),
      width: serializer.fromJson<int>(json['width']),
      height: serializer.fromJson<int>(json['height']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'spotId': serializer.toJson<int>(spotId),
      'imageBytes': serializer.toJson<Uint8List>(imageBytes),
      'thumbnailBytes': serializer.toJson<Uint8List>(thumbnailBytes),
      'width': serializer.toJson<int>(width),
      'height': serializer.toJson<int>(height),
    };
  }

  SpotPhoto copyWith({
    int? id,
    int? spotId,
    Uint8List? imageBytes,
    Uint8List? thumbnailBytes,
    int? width,
    int? height,
  }) => SpotPhoto(
    id: id ?? this.id,
    spotId: spotId ?? this.spotId,
    imageBytes: imageBytes ?? this.imageBytes,
    thumbnailBytes: thumbnailBytes ?? this.thumbnailBytes,
    width: width ?? this.width,
    height: height ?? this.height,
  );
  SpotPhoto copyWithCompanion(SpotPhotosCompanion data) {
    return SpotPhoto(
      id: data.id.present ? data.id.value : this.id,
      spotId: data.spotId.present ? data.spotId.value : this.spotId,
      imageBytes: data.imageBytes.present
          ? data.imageBytes.value
          : this.imageBytes,
      thumbnailBytes: data.thumbnailBytes.present
          ? data.thumbnailBytes.value
          : this.thumbnailBytes,
      width: data.width.present ? data.width.value : this.width,
      height: data.height.present ? data.height.value : this.height,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SpotPhoto(')
          ..write('id: $id, ')
          ..write('spotId: $spotId, ')
          ..write('imageBytes: $imageBytes, ')
          ..write('thumbnailBytes: $thumbnailBytes, ')
          ..write('width: $width, ')
          ..write('height: $height')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    spotId,
    $driftBlobEquality.hash(imageBytes),
    $driftBlobEquality.hash(thumbnailBytes),
    width,
    height,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SpotPhoto &&
          other.id == this.id &&
          other.spotId == this.spotId &&
          $driftBlobEquality.equals(other.imageBytes, this.imageBytes) &&
          $driftBlobEquality.equals(
            other.thumbnailBytes,
            this.thumbnailBytes,
          ) &&
          other.width == this.width &&
          other.height == this.height);
}

class SpotPhotosCompanion extends UpdateCompanion<SpotPhoto> {
  final Value<int> id;
  final Value<int> spotId;
  final Value<Uint8List> imageBytes;
  final Value<Uint8List> thumbnailBytes;
  final Value<int> width;
  final Value<int> height;
  const SpotPhotosCompanion({
    this.id = const Value.absent(),
    this.spotId = const Value.absent(),
    this.imageBytes = const Value.absent(),
    this.thumbnailBytes = const Value.absent(),
    this.width = const Value.absent(),
    this.height = const Value.absent(),
  });
  SpotPhotosCompanion.insert({
    this.id = const Value.absent(),
    required int spotId,
    required Uint8List imageBytes,
    required Uint8List thumbnailBytes,
    required int width,
    required int height,
  }) : spotId = Value(spotId),
       imageBytes = Value(imageBytes),
       thumbnailBytes = Value(thumbnailBytes),
       width = Value(width),
       height = Value(height);
  static Insertable<SpotPhoto> custom({
    Expression<int>? id,
    Expression<int>? spotId,
    Expression<Uint8List>? imageBytes,
    Expression<Uint8List>? thumbnailBytes,
    Expression<int>? width,
    Expression<int>? height,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (spotId != null) 'spot_id': spotId,
      if (imageBytes != null) 'image_bytes': imageBytes,
      if (thumbnailBytes != null) 'thumbnail_bytes': thumbnailBytes,
      if (width != null) 'width': width,
      if (height != null) 'height': height,
    });
  }

  SpotPhotosCompanion copyWith({
    Value<int>? id,
    Value<int>? spotId,
    Value<Uint8List>? imageBytes,
    Value<Uint8List>? thumbnailBytes,
    Value<int>? width,
    Value<int>? height,
  }) {
    return SpotPhotosCompanion(
      id: id ?? this.id,
      spotId: spotId ?? this.spotId,
      imageBytes: imageBytes ?? this.imageBytes,
      thumbnailBytes: thumbnailBytes ?? this.thumbnailBytes,
      width: width ?? this.width,
      height: height ?? this.height,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (spotId.present) {
      map['spot_id'] = Variable<int>(spotId.value);
    }
    if (imageBytes.present) {
      map['image_bytes'] = Variable<Uint8List>(imageBytes.value);
    }
    if (thumbnailBytes.present) {
      map['thumbnail_bytes'] = Variable<Uint8List>(thumbnailBytes.value);
    }
    if (width.present) {
      map['width'] = Variable<int>(width.value);
    }
    if (height.present) {
      map['height'] = Variable<int>(height.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SpotPhotosCompanion(')
          ..write('id: $id, ')
          ..write('spotId: $spotId, ')
          ..write('imageBytes: $imageBytes, ')
          ..write('thumbnailBytes: $thumbnailBytes, ')
          ..write('width: $width, ')
          ..write('height: $height')
          ..write(')'))
        .toString();
  }
}

class $DronesTable extends Drones with TableInfo<$DronesTable, Drone> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DronesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 120,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('quadcopter'),
  );
  static const VerificationMeta _takeoffWeightGramsMeta =
      const VerificationMeta('takeoffWeightGrams');
  @override
  late final GeneratedColumn<double> takeoffWeightGrams =
      GeneratedColumn<double>(
        'takeoff_weight_grams',
        aliasedName,
        true,
        type: DriftSqlType.double,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _maxSpeedMetersPerSecondMeta =
      const VerificationMeta('maxSpeedMetersPerSecond');
  @override
  late final GeneratedColumn<double> maxSpeedMetersPerSecond =
      GeneratedColumn<double>(
        'max_speed_meters_per_second',
        aliasedName,
        true,
        type: DriftSqlType.double,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _lengthMmMeta = const VerificationMeta(
    'lengthMm',
  );
  @override
  late final GeneratedColumn<double> lengthMm = GeneratedColumn<double>(
    'length_mm',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _widthMmMeta = const VerificationMeta(
    'widthMm',
  );
  @override
  late final GeneratedColumn<double> widthMm = GeneratedColumn<double>(
    'width_mm',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _heightMmMeta = const VerificationMeta(
    'heightMm',
  );
  @override
  late final GeneratedColumn<double> heightMm = GeneratedColumn<double>(
    'height_mm',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _propellerDiameterInchesMeta =
      const VerificationMeta('propellerDiameterInches');
  @override
  late final GeneratedColumn<double> propellerDiameterInches =
      GeneratedColumn<double>(
        'propeller_diameter_inches',
        aliasedName,
        true,
        type: DriftSqlType.double,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _propellerPitchInchesMeta =
      const VerificationMeta('propellerPitchInches');
  @override
  late final GeneratedColumn<double> propellerPitchInches =
      GeneratedColumn<double>(
        'propeller_pitch_inches',
        aliasedName,
        true,
        type: DriftSqlType.double,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _propellerCountMeta = const VerificationMeta(
    'propellerCount',
  );
  @override
  late final GeneratedColumn<int> propellerCount = GeneratedColumn<int>(
    'propeller_count',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _motorCountMeta = const VerificationMeta(
    'motorCount',
  );
  @override
  late final GeneratedColumn<int> motorCount = GeneratedColumn<int>(
    'motor_count',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _motorKvMeta = const VerificationMeta(
    'motorKv',
  );
  @override
  late final GeneratedColumn<double> motorKv = GeneratedColumn<double>(
    'motor_kv',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _cruiseSpeedMetersPerSecondMeta =
      const VerificationMeta('cruiseSpeedMetersPerSecond');
  @override
  late final GeneratedColumn<double> cruiseSpeedMetersPerSecond =
      GeneratedColumn<double>(
        'cruise_speed_meters_per_second',
        aliasedName,
        true,
        type: DriftSqlType.double,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _maxClimbRateMetersPerSecondMeta =
      const VerificationMeta('maxClimbRateMetersPerSecond');
  @override
  late final GeneratedColumn<double> maxClimbRateMetersPerSecond =
      GeneratedColumn<double>(
        'max_climb_rate_meters_per_second',
        aliasedName,
        true,
        type: DriftSqlType.double,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _hoverPowerWattsMeta = const VerificationMeta(
    'hoverPowerWatts',
  );
  @override
  late final GeneratedColumn<double> hoverPowerWatts = GeneratedColumn<double>(
    'hover_power_watts',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _cruisePowerWattsMeta = const VerificationMeta(
    'cruisePowerWatts',
  );
  @override
  late final GeneratedColumn<double> cruisePowerWatts = GeneratedColumn<double>(
    'cruise_power_watts',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _maxPowerWattsMeta = const VerificationMeta(
    'maxPowerWatts',
  );
  @override
  late final GeneratedColumn<double> maxPowerWatts = GeneratedColumn<double>(
    'max_power_watts',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _referenceVoltageVoltsMeta =
      const VerificationMeta('referenceVoltageVolts');
  @override
  late final GeneratedColumn<double> referenceVoltageVolts =
      GeneratedColumn<double>(
        'reference_voltage_volts',
        aliasedName,
        true,
        type: DriftSqlType.double,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _configurationMeta = const VerificationMeta(
    'configuration',
  );
  @override
  late final GeneratedColumn<String> configuration = GeneratedColumn<String>(
    'configuration',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _propellerDescriptionMeta =
      const VerificationMeta('propellerDescription');
  @override
  late final GeneratedColumn<String> propellerDescription =
      GeneratedColumn<String>(
        'propeller_description',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _motorDescriptionMeta = const VerificationMeta(
    'motorDescription',
  );
  @override
  late final GeneratedColumn<String> motorDescription = GeneratedColumn<String>(
    'motor_description',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _escDescriptionMeta = const VerificationMeta(
    'escDescription',
  );
  @override
  late final GeneratedColumn<String> escDescription = GeneratedColumn<String>(
    'esc_description',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _measurementContextMeta =
      const VerificationMeta('measurementContext');
  @override
  late final GeneratedColumn<String> measurementContext =
      GeneratedColumn<String>(
        'measurement_context',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    type,
    takeoffWeightGrams,
    maxSpeedMetersPerSecond,
    lengthMm,
    widthMm,
    heightMm,
    propellerDiameterInches,
    propellerPitchInches,
    propellerCount,
    motorCount,
    motorKv,
    cruiseSpeedMetersPerSecond,
    maxClimbRateMetersPerSecond,
    hoverPowerWatts,
    cruisePowerWatts,
    maxPowerWatts,
    referenceVoltageVolts,
    configuration,
    propellerDescription,
    motorDescription,
    escDescription,
    measurementContext,
    notes,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'drones';
  @override
  VerificationContext validateIntegrity(
    Insertable<Drone> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    }
    if (data.containsKey('takeoff_weight_grams')) {
      context.handle(
        _takeoffWeightGramsMeta,
        takeoffWeightGrams.isAcceptableOrUnknown(
          data['takeoff_weight_grams']!,
          _takeoffWeightGramsMeta,
        ),
      );
    }
    if (data.containsKey('max_speed_meters_per_second')) {
      context.handle(
        _maxSpeedMetersPerSecondMeta,
        maxSpeedMetersPerSecond.isAcceptableOrUnknown(
          data['max_speed_meters_per_second']!,
          _maxSpeedMetersPerSecondMeta,
        ),
      );
    }
    if (data.containsKey('length_mm')) {
      context.handle(
        _lengthMmMeta,
        lengthMm.isAcceptableOrUnknown(data['length_mm']!, _lengthMmMeta),
      );
    }
    if (data.containsKey('width_mm')) {
      context.handle(
        _widthMmMeta,
        widthMm.isAcceptableOrUnknown(data['width_mm']!, _widthMmMeta),
      );
    }
    if (data.containsKey('height_mm')) {
      context.handle(
        _heightMmMeta,
        heightMm.isAcceptableOrUnknown(data['height_mm']!, _heightMmMeta),
      );
    }
    if (data.containsKey('propeller_diameter_inches')) {
      context.handle(
        _propellerDiameterInchesMeta,
        propellerDiameterInches.isAcceptableOrUnknown(
          data['propeller_diameter_inches']!,
          _propellerDiameterInchesMeta,
        ),
      );
    }
    if (data.containsKey('propeller_pitch_inches')) {
      context.handle(
        _propellerPitchInchesMeta,
        propellerPitchInches.isAcceptableOrUnknown(
          data['propeller_pitch_inches']!,
          _propellerPitchInchesMeta,
        ),
      );
    }
    if (data.containsKey('propeller_count')) {
      context.handle(
        _propellerCountMeta,
        propellerCount.isAcceptableOrUnknown(
          data['propeller_count']!,
          _propellerCountMeta,
        ),
      );
    }
    if (data.containsKey('motor_count')) {
      context.handle(
        _motorCountMeta,
        motorCount.isAcceptableOrUnknown(data['motor_count']!, _motorCountMeta),
      );
    }
    if (data.containsKey('motor_kv')) {
      context.handle(
        _motorKvMeta,
        motorKv.isAcceptableOrUnknown(data['motor_kv']!, _motorKvMeta),
      );
    }
    if (data.containsKey('cruise_speed_meters_per_second')) {
      context.handle(
        _cruiseSpeedMetersPerSecondMeta,
        cruiseSpeedMetersPerSecond.isAcceptableOrUnknown(
          data['cruise_speed_meters_per_second']!,
          _cruiseSpeedMetersPerSecondMeta,
        ),
      );
    }
    if (data.containsKey('max_climb_rate_meters_per_second')) {
      context.handle(
        _maxClimbRateMetersPerSecondMeta,
        maxClimbRateMetersPerSecond.isAcceptableOrUnknown(
          data['max_climb_rate_meters_per_second']!,
          _maxClimbRateMetersPerSecondMeta,
        ),
      );
    }
    if (data.containsKey('hover_power_watts')) {
      context.handle(
        _hoverPowerWattsMeta,
        hoverPowerWatts.isAcceptableOrUnknown(
          data['hover_power_watts']!,
          _hoverPowerWattsMeta,
        ),
      );
    }
    if (data.containsKey('cruise_power_watts')) {
      context.handle(
        _cruisePowerWattsMeta,
        cruisePowerWatts.isAcceptableOrUnknown(
          data['cruise_power_watts']!,
          _cruisePowerWattsMeta,
        ),
      );
    }
    if (data.containsKey('max_power_watts')) {
      context.handle(
        _maxPowerWattsMeta,
        maxPowerWatts.isAcceptableOrUnknown(
          data['max_power_watts']!,
          _maxPowerWattsMeta,
        ),
      );
    }
    if (data.containsKey('reference_voltage_volts')) {
      context.handle(
        _referenceVoltageVoltsMeta,
        referenceVoltageVolts.isAcceptableOrUnknown(
          data['reference_voltage_volts']!,
          _referenceVoltageVoltsMeta,
        ),
      );
    }
    if (data.containsKey('configuration')) {
      context.handle(
        _configurationMeta,
        configuration.isAcceptableOrUnknown(
          data['configuration']!,
          _configurationMeta,
        ),
      );
    }
    if (data.containsKey('propeller_description')) {
      context.handle(
        _propellerDescriptionMeta,
        propellerDescription.isAcceptableOrUnknown(
          data['propeller_description']!,
          _propellerDescriptionMeta,
        ),
      );
    }
    if (data.containsKey('motor_description')) {
      context.handle(
        _motorDescriptionMeta,
        motorDescription.isAcceptableOrUnknown(
          data['motor_description']!,
          _motorDescriptionMeta,
        ),
      );
    }
    if (data.containsKey('esc_description')) {
      context.handle(
        _escDescriptionMeta,
        escDescription.isAcceptableOrUnknown(
          data['esc_description']!,
          _escDescriptionMeta,
        ),
      );
    }
    if (data.containsKey('measurement_context')) {
      context.handle(
        _measurementContextMeta,
        measurementContext.isAcceptableOrUnknown(
          data['measurement_context']!,
          _measurementContextMeta,
        ),
      );
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Drone map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Drone(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      takeoffWeightGrams: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}takeoff_weight_grams'],
      ),
      maxSpeedMetersPerSecond: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}max_speed_meters_per_second'],
      ),
      lengthMm: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}length_mm'],
      ),
      widthMm: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}width_mm'],
      ),
      heightMm: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}height_mm'],
      ),
      propellerDiameterInches: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}propeller_diameter_inches'],
      ),
      propellerPitchInches: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}propeller_pitch_inches'],
      ),
      propellerCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}propeller_count'],
      ),
      motorCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}motor_count'],
      ),
      motorKv: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}motor_kv'],
      ),
      cruiseSpeedMetersPerSecond: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}cruise_speed_meters_per_second'],
      ),
      maxClimbRateMetersPerSecond: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}max_climb_rate_meters_per_second'],
      ),
      hoverPowerWatts: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}hover_power_watts'],
      ),
      cruisePowerWatts: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}cruise_power_watts'],
      ),
      maxPowerWatts: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}max_power_watts'],
      ),
      referenceVoltageVolts: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}reference_voltage_volts'],
      ),
      configuration: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}configuration'],
      ),
      propellerDescription: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}propeller_description'],
      ),
      motorDescription: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}motor_description'],
      ),
      escDescription: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}esc_description'],
      ),
      measurementContext: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}measurement_context'],
      ),
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $DronesTable createAlias(String alias) {
    return $DronesTable(attachedDatabase, alias);
  }
}

class Drone extends DataClass implements Insertable<Drone> {
  final int id;
  final String name;
  final String type;
  final double? takeoffWeightGrams;
  final double? maxSpeedMetersPerSecond;
  final double? lengthMm;
  final double? widthMm;
  final double? heightMm;
  final double? propellerDiameterInches;
  final double? propellerPitchInches;
  final int? propellerCount;
  final int? motorCount;
  final double? motorKv;
  final double? cruiseSpeedMetersPerSecond;
  final double? maxClimbRateMetersPerSecond;
  final double? hoverPowerWatts;
  final double? cruisePowerWatts;
  final double? maxPowerWatts;
  final double? referenceVoltageVolts;
  final String? configuration;
  final String? propellerDescription;
  final String? motorDescription;
  final String? escDescription;
  final String? measurementContext;
  final String? notes;
  final DateTime createdAt;
  const Drone({
    required this.id,
    required this.name,
    required this.type,
    this.takeoffWeightGrams,
    this.maxSpeedMetersPerSecond,
    this.lengthMm,
    this.widthMm,
    this.heightMm,
    this.propellerDiameterInches,
    this.propellerPitchInches,
    this.propellerCount,
    this.motorCount,
    this.motorKv,
    this.cruiseSpeedMetersPerSecond,
    this.maxClimbRateMetersPerSecond,
    this.hoverPowerWatts,
    this.cruisePowerWatts,
    this.maxPowerWatts,
    this.referenceVoltageVolts,
    this.configuration,
    this.propellerDescription,
    this.motorDescription,
    this.escDescription,
    this.measurementContext,
    this.notes,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['type'] = Variable<String>(type);
    if (!nullToAbsent || takeoffWeightGrams != null) {
      map['takeoff_weight_grams'] = Variable<double>(takeoffWeightGrams);
    }
    if (!nullToAbsent || maxSpeedMetersPerSecond != null) {
      map['max_speed_meters_per_second'] = Variable<double>(
        maxSpeedMetersPerSecond,
      );
    }
    if (!nullToAbsent || lengthMm != null) {
      map['length_mm'] = Variable<double>(lengthMm);
    }
    if (!nullToAbsent || widthMm != null) {
      map['width_mm'] = Variable<double>(widthMm);
    }
    if (!nullToAbsent || heightMm != null) {
      map['height_mm'] = Variable<double>(heightMm);
    }
    if (!nullToAbsent || propellerDiameterInches != null) {
      map['propeller_diameter_inches'] = Variable<double>(
        propellerDiameterInches,
      );
    }
    if (!nullToAbsent || propellerPitchInches != null) {
      map['propeller_pitch_inches'] = Variable<double>(propellerPitchInches);
    }
    if (!nullToAbsent || propellerCount != null) {
      map['propeller_count'] = Variable<int>(propellerCount);
    }
    if (!nullToAbsent || motorCount != null) {
      map['motor_count'] = Variable<int>(motorCount);
    }
    if (!nullToAbsent || motorKv != null) {
      map['motor_kv'] = Variable<double>(motorKv);
    }
    if (!nullToAbsent || cruiseSpeedMetersPerSecond != null) {
      map['cruise_speed_meters_per_second'] = Variable<double>(
        cruiseSpeedMetersPerSecond,
      );
    }
    if (!nullToAbsent || maxClimbRateMetersPerSecond != null) {
      map['max_climb_rate_meters_per_second'] = Variable<double>(
        maxClimbRateMetersPerSecond,
      );
    }
    if (!nullToAbsent || hoverPowerWatts != null) {
      map['hover_power_watts'] = Variable<double>(hoverPowerWatts);
    }
    if (!nullToAbsent || cruisePowerWatts != null) {
      map['cruise_power_watts'] = Variable<double>(cruisePowerWatts);
    }
    if (!nullToAbsent || maxPowerWatts != null) {
      map['max_power_watts'] = Variable<double>(maxPowerWatts);
    }
    if (!nullToAbsent || referenceVoltageVolts != null) {
      map['reference_voltage_volts'] = Variable<double>(referenceVoltageVolts);
    }
    if (!nullToAbsent || configuration != null) {
      map['configuration'] = Variable<String>(configuration);
    }
    if (!nullToAbsent || propellerDescription != null) {
      map['propeller_description'] = Variable<String>(propellerDescription);
    }
    if (!nullToAbsent || motorDescription != null) {
      map['motor_description'] = Variable<String>(motorDescription);
    }
    if (!nullToAbsent || escDescription != null) {
      map['esc_description'] = Variable<String>(escDescription);
    }
    if (!nullToAbsent || measurementContext != null) {
      map['measurement_context'] = Variable<String>(measurementContext);
    }
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  DronesCompanion toCompanion(bool nullToAbsent) {
    return DronesCompanion(
      id: Value(id),
      name: Value(name),
      type: Value(type),
      takeoffWeightGrams: takeoffWeightGrams == null && nullToAbsent
          ? const Value.absent()
          : Value(takeoffWeightGrams),
      maxSpeedMetersPerSecond: maxSpeedMetersPerSecond == null && nullToAbsent
          ? const Value.absent()
          : Value(maxSpeedMetersPerSecond),
      lengthMm: lengthMm == null && nullToAbsent
          ? const Value.absent()
          : Value(lengthMm),
      widthMm: widthMm == null && nullToAbsent
          ? const Value.absent()
          : Value(widthMm),
      heightMm: heightMm == null && nullToAbsent
          ? const Value.absent()
          : Value(heightMm),
      propellerDiameterInches: propellerDiameterInches == null && nullToAbsent
          ? const Value.absent()
          : Value(propellerDiameterInches),
      propellerPitchInches: propellerPitchInches == null && nullToAbsent
          ? const Value.absent()
          : Value(propellerPitchInches),
      propellerCount: propellerCount == null && nullToAbsent
          ? const Value.absent()
          : Value(propellerCount),
      motorCount: motorCount == null && nullToAbsent
          ? const Value.absent()
          : Value(motorCount),
      motorKv: motorKv == null && nullToAbsent
          ? const Value.absent()
          : Value(motorKv),
      cruiseSpeedMetersPerSecond:
          cruiseSpeedMetersPerSecond == null && nullToAbsent
          ? const Value.absent()
          : Value(cruiseSpeedMetersPerSecond),
      maxClimbRateMetersPerSecond:
          maxClimbRateMetersPerSecond == null && nullToAbsent
          ? const Value.absent()
          : Value(maxClimbRateMetersPerSecond),
      hoverPowerWatts: hoverPowerWatts == null && nullToAbsent
          ? const Value.absent()
          : Value(hoverPowerWatts),
      cruisePowerWatts: cruisePowerWatts == null && nullToAbsent
          ? const Value.absent()
          : Value(cruisePowerWatts),
      maxPowerWatts: maxPowerWatts == null && nullToAbsent
          ? const Value.absent()
          : Value(maxPowerWatts),
      referenceVoltageVolts: referenceVoltageVolts == null && nullToAbsent
          ? const Value.absent()
          : Value(referenceVoltageVolts),
      configuration: configuration == null && nullToAbsent
          ? const Value.absent()
          : Value(configuration),
      propellerDescription: propellerDescription == null && nullToAbsent
          ? const Value.absent()
          : Value(propellerDescription),
      motorDescription: motorDescription == null && nullToAbsent
          ? const Value.absent()
          : Value(motorDescription),
      escDescription: escDescription == null && nullToAbsent
          ? const Value.absent()
          : Value(escDescription),
      measurementContext: measurementContext == null && nullToAbsent
          ? const Value.absent()
          : Value(measurementContext),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
      createdAt: Value(createdAt),
    );
  }

  factory Drone.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Drone(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      type: serializer.fromJson<String>(json['type']),
      takeoffWeightGrams: serializer.fromJson<double?>(
        json['takeoffWeightGrams'],
      ),
      maxSpeedMetersPerSecond: serializer.fromJson<double?>(
        json['maxSpeedMetersPerSecond'],
      ),
      lengthMm: serializer.fromJson<double?>(json['lengthMm']),
      widthMm: serializer.fromJson<double?>(json['widthMm']),
      heightMm: serializer.fromJson<double?>(json['heightMm']),
      propellerDiameterInches: serializer.fromJson<double?>(
        json['propellerDiameterInches'],
      ),
      propellerPitchInches: serializer.fromJson<double?>(
        json['propellerPitchInches'],
      ),
      propellerCount: serializer.fromJson<int?>(json['propellerCount']),
      motorCount: serializer.fromJson<int?>(json['motorCount']),
      motorKv: serializer.fromJson<double?>(json['motorKv']),
      cruiseSpeedMetersPerSecond: serializer.fromJson<double?>(
        json['cruiseSpeedMetersPerSecond'],
      ),
      maxClimbRateMetersPerSecond: serializer.fromJson<double?>(
        json['maxClimbRateMetersPerSecond'],
      ),
      hoverPowerWatts: serializer.fromJson<double?>(json['hoverPowerWatts']),
      cruisePowerWatts: serializer.fromJson<double?>(json['cruisePowerWatts']),
      maxPowerWatts: serializer.fromJson<double?>(json['maxPowerWatts']),
      referenceVoltageVolts: serializer.fromJson<double?>(
        json['referenceVoltageVolts'],
      ),
      configuration: serializer.fromJson<String?>(json['configuration']),
      propellerDescription: serializer.fromJson<String?>(
        json['propellerDescription'],
      ),
      motorDescription: serializer.fromJson<String?>(json['motorDescription']),
      escDescription: serializer.fromJson<String?>(json['escDescription']),
      measurementContext: serializer.fromJson<String?>(
        json['measurementContext'],
      ),
      notes: serializer.fromJson<String?>(json['notes']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'type': serializer.toJson<String>(type),
      'takeoffWeightGrams': serializer.toJson<double?>(takeoffWeightGrams),
      'maxSpeedMetersPerSecond': serializer.toJson<double?>(
        maxSpeedMetersPerSecond,
      ),
      'lengthMm': serializer.toJson<double?>(lengthMm),
      'widthMm': serializer.toJson<double?>(widthMm),
      'heightMm': serializer.toJson<double?>(heightMm),
      'propellerDiameterInches': serializer.toJson<double?>(
        propellerDiameterInches,
      ),
      'propellerPitchInches': serializer.toJson<double?>(propellerPitchInches),
      'propellerCount': serializer.toJson<int?>(propellerCount),
      'motorCount': serializer.toJson<int?>(motorCount),
      'motorKv': serializer.toJson<double?>(motorKv),
      'cruiseSpeedMetersPerSecond': serializer.toJson<double?>(
        cruiseSpeedMetersPerSecond,
      ),
      'maxClimbRateMetersPerSecond': serializer.toJson<double?>(
        maxClimbRateMetersPerSecond,
      ),
      'hoverPowerWatts': serializer.toJson<double?>(hoverPowerWatts),
      'cruisePowerWatts': serializer.toJson<double?>(cruisePowerWatts),
      'maxPowerWatts': serializer.toJson<double?>(maxPowerWatts),
      'referenceVoltageVolts': serializer.toJson<double?>(
        referenceVoltageVolts,
      ),
      'configuration': serializer.toJson<String?>(configuration),
      'propellerDescription': serializer.toJson<String?>(propellerDescription),
      'motorDescription': serializer.toJson<String?>(motorDescription),
      'escDescription': serializer.toJson<String?>(escDescription),
      'measurementContext': serializer.toJson<String?>(measurementContext),
      'notes': serializer.toJson<String?>(notes),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  Drone copyWith({
    int? id,
    String? name,
    String? type,
    Value<double?> takeoffWeightGrams = const Value.absent(),
    Value<double?> maxSpeedMetersPerSecond = const Value.absent(),
    Value<double?> lengthMm = const Value.absent(),
    Value<double?> widthMm = const Value.absent(),
    Value<double?> heightMm = const Value.absent(),
    Value<double?> propellerDiameterInches = const Value.absent(),
    Value<double?> propellerPitchInches = const Value.absent(),
    Value<int?> propellerCount = const Value.absent(),
    Value<int?> motorCount = const Value.absent(),
    Value<double?> motorKv = const Value.absent(),
    Value<double?> cruiseSpeedMetersPerSecond = const Value.absent(),
    Value<double?> maxClimbRateMetersPerSecond = const Value.absent(),
    Value<double?> hoverPowerWatts = const Value.absent(),
    Value<double?> cruisePowerWatts = const Value.absent(),
    Value<double?> maxPowerWatts = const Value.absent(),
    Value<double?> referenceVoltageVolts = const Value.absent(),
    Value<String?> configuration = const Value.absent(),
    Value<String?> propellerDescription = const Value.absent(),
    Value<String?> motorDescription = const Value.absent(),
    Value<String?> escDescription = const Value.absent(),
    Value<String?> measurementContext = const Value.absent(),
    Value<String?> notes = const Value.absent(),
    DateTime? createdAt,
  }) => Drone(
    id: id ?? this.id,
    name: name ?? this.name,
    type: type ?? this.type,
    takeoffWeightGrams: takeoffWeightGrams.present
        ? takeoffWeightGrams.value
        : this.takeoffWeightGrams,
    maxSpeedMetersPerSecond: maxSpeedMetersPerSecond.present
        ? maxSpeedMetersPerSecond.value
        : this.maxSpeedMetersPerSecond,
    lengthMm: lengthMm.present ? lengthMm.value : this.lengthMm,
    widthMm: widthMm.present ? widthMm.value : this.widthMm,
    heightMm: heightMm.present ? heightMm.value : this.heightMm,
    propellerDiameterInches: propellerDiameterInches.present
        ? propellerDiameterInches.value
        : this.propellerDiameterInches,
    propellerPitchInches: propellerPitchInches.present
        ? propellerPitchInches.value
        : this.propellerPitchInches,
    propellerCount: propellerCount.present
        ? propellerCount.value
        : this.propellerCount,
    motorCount: motorCount.present ? motorCount.value : this.motorCount,
    motorKv: motorKv.present ? motorKv.value : this.motorKv,
    cruiseSpeedMetersPerSecond: cruiseSpeedMetersPerSecond.present
        ? cruiseSpeedMetersPerSecond.value
        : this.cruiseSpeedMetersPerSecond,
    maxClimbRateMetersPerSecond: maxClimbRateMetersPerSecond.present
        ? maxClimbRateMetersPerSecond.value
        : this.maxClimbRateMetersPerSecond,
    hoverPowerWatts: hoverPowerWatts.present
        ? hoverPowerWatts.value
        : this.hoverPowerWatts,
    cruisePowerWatts: cruisePowerWatts.present
        ? cruisePowerWatts.value
        : this.cruisePowerWatts,
    maxPowerWatts: maxPowerWatts.present
        ? maxPowerWatts.value
        : this.maxPowerWatts,
    referenceVoltageVolts: referenceVoltageVolts.present
        ? referenceVoltageVolts.value
        : this.referenceVoltageVolts,
    configuration: configuration.present
        ? configuration.value
        : this.configuration,
    propellerDescription: propellerDescription.present
        ? propellerDescription.value
        : this.propellerDescription,
    motorDescription: motorDescription.present
        ? motorDescription.value
        : this.motorDescription,
    escDescription: escDescription.present
        ? escDescription.value
        : this.escDescription,
    measurementContext: measurementContext.present
        ? measurementContext.value
        : this.measurementContext,
    notes: notes.present ? notes.value : this.notes,
    createdAt: createdAt ?? this.createdAt,
  );
  Drone copyWithCompanion(DronesCompanion data) {
    return Drone(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      type: data.type.present ? data.type.value : this.type,
      takeoffWeightGrams: data.takeoffWeightGrams.present
          ? data.takeoffWeightGrams.value
          : this.takeoffWeightGrams,
      maxSpeedMetersPerSecond: data.maxSpeedMetersPerSecond.present
          ? data.maxSpeedMetersPerSecond.value
          : this.maxSpeedMetersPerSecond,
      lengthMm: data.lengthMm.present ? data.lengthMm.value : this.lengthMm,
      widthMm: data.widthMm.present ? data.widthMm.value : this.widthMm,
      heightMm: data.heightMm.present ? data.heightMm.value : this.heightMm,
      propellerDiameterInches: data.propellerDiameterInches.present
          ? data.propellerDiameterInches.value
          : this.propellerDiameterInches,
      propellerPitchInches: data.propellerPitchInches.present
          ? data.propellerPitchInches.value
          : this.propellerPitchInches,
      propellerCount: data.propellerCount.present
          ? data.propellerCount.value
          : this.propellerCount,
      motorCount: data.motorCount.present
          ? data.motorCount.value
          : this.motorCount,
      motorKv: data.motorKv.present ? data.motorKv.value : this.motorKv,
      cruiseSpeedMetersPerSecond: data.cruiseSpeedMetersPerSecond.present
          ? data.cruiseSpeedMetersPerSecond.value
          : this.cruiseSpeedMetersPerSecond,
      maxClimbRateMetersPerSecond: data.maxClimbRateMetersPerSecond.present
          ? data.maxClimbRateMetersPerSecond.value
          : this.maxClimbRateMetersPerSecond,
      hoverPowerWatts: data.hoverPowerWatts.present
          ? data.hoverPowerWatts.value
          : this.hoverPowerWatts,
      cruisePowerWatts: data.cruisePowerWatts.present
          ? data.cruisePowerWatts.value
          : this.cruisePowerWatts,
      maxPowerWatts: data.maxPowerWatts.present
          ? data.maxPowerWatts.value
          : this.maxPowerWatts,
      referenceVoltageVolts: data.referenceVoltageVolts.present
          ? data.referenceVoltageVolts.value
          : this.referenceVoltageVolts,
      configuration: data.configuration.present
          ? data.configuration.value
          : this.configuration,
      propellerDescription: data.propellerDescription.present
          ? data.propellerDescription.value
          : this.propellerDescription,
      motorDescription: data.motorDescription.present
          ? data.motorDescription.value
          : this.motorDescription,
      escDescription: data.escDescription.present
          ? data.escDescription.value
          : this.escDescription,
      measurementContext: data.measurementContext.present
          ? data.measurementContext.value
          : this.measurementContext,
      notes: data.notes.present ? data.notes.value : this.notes,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Drone(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('type: $type, ')
          ..write('takeoffWeightGrams: $takeoffWeightGrams, ')
          ..write('maxSpeedMetersPerSecond: $maxSpeedMetersPerSecond, ')
          ..write('lengthMm: $lengthMm, ')
          ..write('widthMm: $widthMm, ')
          ..write('heightMm: $heightMm, ')
          ..write('propellerDiameterInches: $propellerDiameterInches, ')
          ..write('propellerPitchInches: $propellerPitchInches, ')
          ..write('propellerCount: $propellerCount, ')
          ..write('motorCount: $motorCount, ')
          ..write('motorKv: $motorKv, ')
          ..write('cruiseSpeedMetersPerSecond: $cruiseSpeedMetersPerSecond, ')
          ..write('maxClimbRateMetersPerSecond: $maxClimbRateMetersPerSecond, ')
          ..write('hoverPowerWatts: $hoverPowerWatts, ')
          ..write('cruisePowerWatts: $cruisePowerWatts, ')
          ..write('maxPowerWatts: $maxPowerWatts, ')
          ..write('referenceVoltageVolts: $referenceVoltageVolts, ')
          ..write('configuration: $configuration, ')
          ..write('propellerDescription: $propellerDescription, ')
          ..write('motorDescription: $motorDescription, ')
          ..write('escDescription: $escDescription, ')
          ..write('measurementContext: $measurementContext, ')
          ..write('notes: $notes, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    name,
    type,
    takeoffWeightGrams,
    maxSpeedMetersPerSecond,
    lengthMm,
    widthMm,
    heightMm,
    propellerDiameterInches,
    propellerPitchInches,
    propellerCount,
    motorCount,
    motorKv,
    cruiseSpeedMetersPerSecond,
    maxClimbRateMetersPerSecond,
    hoverPowerWatts,
    cruisePowerWatts,
    maxPowerWatts,
    referenceVoltageVolts,
    configuration,
    propellerDescription,
    motorDescription,
    escDescription,
    measurementContext,
    notes,
    createdAt,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Drone &&
          other.id == this.id &&
          other.name == this.name &&
          other.type == this.type &&
          other.takeoffWeightGrams == this.takeoffWeightGrams &&
          other.maxSpeedMetersPerSecond == this.maxSpeedMetersPerSecond &&
          other.lengthMm == this.lengthMm &&
          other.widthMm == this.widthMm &&
          other.heightMm == this.heightMm &&
          other.propellerDiameterInches == this.propellerDiameterInches &&
          other.propellerPitchInches == this.propellerPitchInches &&
          other.propellerCount == this.propellerCount &&
          other.motorCount == this.motorCount &&
          other.motorKv == this.motorKv &&
          other.cruiseSpeedMetersPerSecond == this.cruiseSpeedMetersPerSecond &&
          other.maxClimbRateMetersPerSecond ==
              this.maxClimbRateMetersPerSecond &&
          other.hoverPowerWatts == this.hoverPowerWatts &&
          other.cruisePowerWatts == this.cruisePowerWatts &&
          other.maxPowerWatts == this.maxPowerWatts &&
          other.referenceVoltageVolts == this.referenceVoltageVolts &&
          other.configuration == this.configuration &&
          other.propellerDescription == this.propellerDescription &&
          other.motorDescription == this.motorDescription &&
          other.escDescription == this.escDescription &&
          other.measurementContext == this.measurementContext &&
          other.notes == this.notes &&
          other.createdAt == this.createdAt);
}

class DronesCompanion extends UpdateCompanion<Drone> {
  final Value<int> id;
  final Value<String> name;
  final Value<String> type;
  final Value<double?> takeoffWeightGrams;
  final Value<double?> maxSpeedMetersPerSecond;
  final Value<double?> lengthMm;
  final Value<double?> widthMm;
  final Value<double?> heightMm;
  final Value<double?> propellerDiameterInches;
  final Value<double?> propellerPitchInches;
  final Value<int?> propellerCount;
  final Value<int?> motorCount;
  final Value<double?> motorKv;
  final Value<double?> cruiseSpeedMetersPerSecond;
  final Value<double?> maxClimbRateMetersPerSecond;
  final Value<double?> hoverPowerWatts;
  final Value<double?> cruisePowerWatts;
  final Value<double?> maxPowerWatts;
  final Value<double?> referenceVoltageVolts;
  final Value<String?> configuration;
  final Value<String?> propellerDescription;
  final Value<String?> motorDescription;
  final Value<String?> escDescription;
  final Value<String?> measurementContext;
  final Value<String?> notes;
  final Value<DateTime> createdAt;
  const DronesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.type = const Value.absent(),
    this.takeoffWeightGrams = const Value.absent(),
    this.maxSpeedMetersPerSecond = const Value.absent(),
    this.lengthMm = const Value.absent(),
    this.widthMm = const Value.absent(),
    this.heightMm = const Value.absent(),
    this.propellerDiameterInches = const Value.absent(),
    this.propellerPitchInches = const Value.absent(),
    this.propellerCount = const Value.absent(),
    this.motorCount = const Value.absent(),
    this.motorKv = const Value.absent(),
    this.cruiseSpeedMetersPerSecond = const Value.absent(),
    this.maxClimbRateMetersPerSecond = const Value.absent(),
    this.hoverPowerWatts = const Value.absent(),
    this.cruisePowerWatts = const Value.absent(),
    this.maxPowerWatts = const Value.absent(),
    this.referenceVoltageVolts = const Value.absent(),
    this.configuration = const Value.absent(),
    this.propellerDescription = const Value.absent(),
    this.motorDescription = const Value.absent(),
    this.escDescription = const Value.absent(),
    this.measurementContext = const Value.absent(),
    this.notes = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  DronesCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    this.type = const Value.absent(),
    this.takeoffWeightGrams = const Value.absent(),
    this.maxSpeedMetersPerSecond = const Value.absent(),
    this.lengthMm = const Value.absent(),
    this.widthMm = const Value.absent(),
    this.heightMm = const Value.absent(),
    this.propellerDiameterInches = const Value.absent(),
    this.propellerPitchInches = const Value.absent(),
    this.propellerCount = const Value.absent(),
    this.motorCount = const Value.absent(),
    this.motorKv = const Value.absent(),
    this.cruiseSpeedMetersPerSecond = const Value.absent(),
    this.maxClimbRateMetersPerSecond = const Value.absent(),
    this.hoverPowerWatts = const Value.absent(),
    this.cruisePowerWatts = const Value.absent(),
    this.maxPowerWatts = const Value.absent(),
    this.referenceVoltageVolts = const Value.absent(),
    this.configuration = const Value.absent(),
    this.propellerDescription = const Value.absent(),
    this.motorDescription = const Value.absent(),
    this.escDescription = const Value.absent(),
    this.measurementContext = const Value.absent(),
    this.notes = const Value.absent(),
    this.createdAt = const Value.absent(),
  }) : name = Value(name);
  static Insertable<Drone> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? type,
    Expression<double>? takeoffWeightGrams,
    Expression<double>? maxSpeedMetersPerSecond,
    Expression<double>? lengthMm,
    Expression<double>? widthMm,
    Expression<double>? heightMm,
    Expression<double>? propellerDiameterInches,
    Expression<double>? propellerPitchInches,
    Expression<int>? propellerCount,
    Expression<int>? motorCount,
    Expression<double>? motorKv,
    Expression<double>? cruiseSpeedMetersPerSecond,
    Expression<double>? maxClimbRateMetersPerSecond,
    Expression<double>? hoverPowerWatts,
    Expression<double>? cruisePowerWatts,
    Expression<double>? maxPowerWatts,
    Expression<double>? referenceVoltageVolts,
    Expression<String>? configuration,
    Expression<String>? propellerDescription,
    Expression<String>? motorDescription,
    Expression<String>? escDescription,
    Expression<String>? measurementContext,
    Expression<String>? notes,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (type != null) 'type': type,
      if (takeoffWeightGrams != null)
        'takeoff_weight_grams': takeoffWeightGrams,
      if (maxSpeedMetersPerSecond != null)
        'max_speed_meters_per_second': maxSpeedMetersPerSecond,
      if (lengthMm != null) 'length_mm': lengthMm,
      if (widthMm != null) 'width_mm': widthMm,
      if (heightMm != null) 'height_mm': heightMm,
      if (propellerDiameterInches != null)
        'propeller_diameter_inches': propellerDiameterInches,
      if (propellerPitchInches != null)
        'propeller_pitch_inches': propellerPitchInches,
      if (propellerCount != null) 'propeller_count': propellerCount,
      if (motorCount != null) 'motor_count': motorCount,
      if (motorKv != null) 'motor_kv': motorKv,
      if (cruiseSpeedMetersPerSecond != null)
        'cruise_speed_meters_per_second': cruiseSpeedMetersPerSecond,
      if (maxClimbRateMetersPerSecond != null)
        'max_climb_rate_meters_per_second': maxClimbRateMetersPerSecond,
      if (hoverPowerWatts != null) 'hover_power_watts': hoverPowerWatts,
      if (cruisePowerWatts != null) 'cruise_power_watts': cruisePowerWatts,
      if (maxPowerWatts != null) 'max_power_watts': maxPowerWatts,
      if (referenceVoltageVolts != null)
        'reference_voltage_volts': referenceVoltageVolts,
      if (configuration != null) 'configuration': configuration,
      if (propellerDescription != null)
        'propeller_description': propellerDescription,
      if (motorDescription != null) 'motor_description': motorDescription,
      if (escDescription != null) 'esc_description': escDescription,
      if (measurementContext != null) 'measurement_context': measurementContext,
      if (notes != null) 'notes': notes,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  DronesCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<String>? type,
    Value<double?>? takeoffWeightGrams,
    Value<double?>? maxSpeedMetersPerSecond,
    Value<double?>? lengthMm,
    Value<double?>? widthMm,
    Value<double?>? heightMm,
    Value<double?>? propellerDiameterInches,
    Value<double?>? propellerPitchInches,
    Value<int?>? propellerCount,
    Value<int?>? motorCount,
    Value<double?>? motorKv,
    Value<double?>? cruiseSpeedMetersPerSecond,
    Value<double?>? maxClimbRateMetersPerSecond,
    Value<double?>? hoverPowerWatts,
    Value<double?>? cruisePowerWatts,
    Value<double?>? maxPowerWatts,
    Value<double?>? referenceVoltageVolts,
    Value<String?>? configuration,
    Value<String?>? propellerDescription,
    Value<String?>? motorDescription,
    Value<String?>? escDescription,
    Value<String?>? measurementContext,
    Value<String?>? notes,
    Value<DateTime>? createdAt,
  }) {
    return DronesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      takeoffWeightGrams: takeoffWeightGrams ?? this.takeoffWeightGrams,
      maxSpeedMetersPerSecond:
          maxSpeedMetersPerSecond ?? this.maxSpeedMetersPerSecond,
      lengthMm: lengthMm ?? this.lengthMm,
      widthMm: widthMm ?? this.widthMm,
      heightMm: heightMm ?? this.heightMm,
      propellerDiameterInches:
          propellerDiameterInches ?? this.propellerDiameterInches,
      propellerPitchInches: propellerPitchInches ?? this.propellerPitchInches,
      propellerCount: propellerCount ?? this.propellerCount,
      motorCount: motorCount ?? this.motorCount,
      motorKv: motorKv ?? this.motorKv,
      cruiseSpeedMetersPerSecond:
          cruiseSpeedMetersPerSecond ?? this.cruiseSpeedMetersPerSecond,
      maxClimbRateMetersPerSecond:
          maxClimbRateMetersPerSecond ?? this.maxClimbRateMetersPerSecond,
      hoverPowerWatts: hoverPowerWatts ?? this.hoverPowerWatts,
      cruisePowerWatts: cruisePowerWatts ?? this.cruisePowerWatts,
      maxPowerWatts: maxPowerWatts ?? this.maxPowerWatts,
      referenceVoltageVolts:
          referenceVoltageVolts ?? this.referenceVoltageVolts,
      configuration: configuration ?? this.configuration,
      propellerDescription: propellerDescription ?? this.propellerDescription,
      motorDescription: motorDescription ?? this.motorDescription,
      escDescription: escDescription ?? this.escDescription,
      measurementContext: measurementContext ?? this.measurementContext,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (takeoffWeightGrams.present) {
      map['takeoff_weight_grams'] = Variable<double>(takeoffWeightGrams.value);
    }
    if (maxSpeedMetersPerSecond.present) {
      map['max_speed_meters_per_second'] = Variable<double>(
        maxSpeedMetersPerSecond.value,
      );
    }
    if (lengthMm.present) {
      map['length_mm'] = Variable<double>(lengthMm.value);
    }
    if (widthMm.present) {
      map['width_mm'] = Variable<double>(widthMm.value);
    }
    if (heightMm.present) {
      map['height_mm'] = Variable<double>(heightMm.value);
    }
    if (propellerDiameterInches.present) {
      map['propeller_diameter_inches'] = Variable<double>(
        propellerDiameterInches.value,
      );
    }
    if (propellerPitchInches.present) {
      map['propeller_pitch_inches'] = Variable<double>(
        propellerPitchInches.value,
      );
    }
    if (propellerCount.present) {
      map['propeller_count'] = Variable<int>(propellerCount.value);
    }
    if (motorCount.present) {
      map['motor_count'] = Variable<int>(motorCount.value);
    }
    if (motorKv.present) {
      map['motor_kv'] = Variable<double>(motorKv.value);
    }
    if (cruiseSpeedMetersPerSecond.present) {
      map['cruise_speed_meters_per_second'] = Variable<double>(
        cruiseSpeedMetersPerSecond.value,
      );
    }
    if (maxClimbRateMetersPerSecond.present) {
      map['max_climb_rate_meters_per_second'] = Variable<double>(
        maxClimbRateMetersPerSecond.value,
      );
    }
    if (hoverPowerWatts.present) {
      map['hover_power_watts'] = Variable<double>(hoverPowerWatts.value);
    }
    if (cruisePowerWatts.present) {
      map['cruise_power_watts'] = Variable<double>(cruisePowerWatts.value);
    }
    if (maxPowerWatts.present) {
      map['max_power_watts'] = Variable<double>(maxPowerWatts.value);
    }
    if (referenceVoltageVolts.present) {
      map['reference_voltage_volts'] = Variable<double>(
        referenceVoltageVolts.value,
      );
    }
    if (configuration.present) {
      map['configuration'] = Variable<String>(configuration.value);
    }
    if (propellerDescription.present) {
      map['propeller_description'] = Variable<String>(
        propellerDescription.value,
      );
    }
    if (motorDescription.present) {
      map['motor_description'] = Variable<String>(motorDescription.value);
    }
    if (escDescription.present) {
      map['esc_description'] = Variable<String>(escDescription.value);
    }
    if (measurementContext.present) {
      map['measurement_context'] = Variable<String>(measurementContext.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DronesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('type: $type, ')
          ..write('takeoffWeightGrams: $takeoffWeightGrams, ')
          ..write('maxSpeedMetersPerSecond: $maxSpeedMetersPerSecond, ')
          ..write('lengthMm: $lengthMm, ')
          ..write('widthMm: $widthMm, ')
          ..write('heightMm: $heightMm, ')
          ..write('propellerDiameterInches: $propellerDiameterInches, ')
          ..write('propellerPitchInches: $propellerPitchInches, ')
          ..write('propellerCount: $propellerCount, ')
          ..write('motorCount: $motorCount, ')
          ..write('motorKv: $motorKv, ')
          ..write('cruiseSpeedMetersPerSecond: $cruiseSpeedMetersPerSecond, ')
          ..write('maxClimbRateMetersPerSecond: $maxClimbRateMetersPerSecond, ')
          ..write('hoverPowerWatts: $hoverPowerWatts, ')
          ..write('cruisePowerWatts: $cruisePowerWatts, ')
          ..write('maxPowerWatts: $maxPowerWatts, ')
          ..write('referenceVoltageVolts: $referenceVoltageVolts, ')
          ..write('configuration: $configuration, ')
          ..write('propellerDescription: $propellerDescription, ')
          ..write('motorDescription: $motorDescription, ')
          ..write('escDescription: $escDescription, ')
          ..write('measurementContext: $measurementContext, ')
          ..write('notes: $notes, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $DroneParameterSourcesTable extends DroneParameterSources
    with TableInfo<$DroneParameterSourcesTable, DroneParameterSource> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DroneParameterSourcesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _droneIdMeta = const VerificationMeta(
    'droneId',
  );
  @override
  late final GeneratedColumn<int> droneId = GeneratedColumn<int>(
    'drone_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES drones (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _parameterKeyMeta = const VerificationMeta(
    'parameterKey',
  );
  @override
  late final GeneratedColumn<String> parameterKey = GeneratedColumn<String>(
    'parameter_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
    'source',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [droneId, parameterKey, source];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'drone_parameter_sources';
  @override
  VerificationContext validateIntegrity(
    Insertable<DroneParameterSource> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('drone_id')) {
      context.handle(
        _droneIdMeta,
        droneId.isAcceptableOrUnknown(data['drone_id']!, _droneIdMeta),
      );
    } else if (isInserting) {
      context.missing(_droneIdMeta);
    }
    if (data.containsKey('parameter_key')) {
      context.handle(
        _parameterKeyMeta,
        parameterKey.isAcceptableOrUnknown(
          data['parameter_key']!,
          _parameterKeyMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_parameterKeyMeta);
    }
    if (data.containsKey('source')) {
      context.handle(
        _sourceMeta,
        source.isAcceptableOrUnknown(data['source']!, _sourceMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {droneId, parameterKey};
  @override
  DroneParameterSource map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DroneParameterSource(
      droneId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}drone_id'],
      )!,
      parameterKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}parameter_key'],
      )!,
      source: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source'],
      )!,
    );
  }

  @override
  $DroneParameterSourcesTable createAlias(String alias) {
    return $DroneParameterSourcesTable(attachedDatabase, alias);
  }
}

class DroneParameterSource extends DataClass
    implements Insertable<DroneParameterSource> {
  final int droneId;
  final String parameterKey;
  final String source;
  const DroneParameterSource({
    required this.droneId,
    required this.parameterKey,
    required this.source,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['drone_id'] = Variable<int>(droneId);
    map['parameter_key'] = Variable<String>(parameterKey);
    map['source'] = Variable<String>(source);
    return map;
  }

  DroneParameterSourcesCompanion toCompanion(bool nullToAbsent) {
    return DroneParameterSourcesCompanion(
      droneId: Value(droneId),
      parameterKey: Value(parameterKey),
      source: Value(source),
    );
  }

  factory DroneParameterSource.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DroneParameterSource(
      droneId: serializer.fromJson<int>(json['droneId']),
      parameterKey: serializer.fromJson<String>(json['parameterKey']),
      source: serializer.fromJson<String>(json['source']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'droneId': serializer.toJson<int>(droneId),
      'parameterKey': serializer.toJson<String>(parameterKey),
      'source': serializer.toJson<String>(source),
    };
  }

  DroneParameterSource copyWith({
    int? droneId,
    String? parameterKey,
    String? source,
  }) => DroneParameterSource(
    droneId: droneId ?? this.droneId,
    parameterKey: parameterKey ?? this.parameterKey,
    source: source ?? this.source,
  );
  DroneParameterSource copyWithCompanion(DroneParameterSourcesCompanion data) {
    return DroneParameterSource(
      droneId: data.droneId.present ? data.droneId.value : this.droneId,
      parameterKey: data.parameterKey.present
          ? data.parameterKey.value
          : this.parameterKey,
      source: data.source.present ? data.source.value : this.source,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DroneParameterSource(')
          ..write('droneId: $droneId, ')
          ..write('parameterKey: $parameterKey, ')
          ..write('source: $source')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(droneId, parameterKey, source);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DroneParameterSource &&
          other.droneId == this.droneId &&
          other.parameterKey == this.parameterKey &&
          other.source == this.source);
}

class DroneParameterSourcesCompanion
    extends UpdateCompanion<DroneParameterSource> {
  final Value<int> droneId;
  final Value<String> parameterKey;
  final Value<String> source;
  final Value<int> rowid;
  const DroneParameterSourcesCompanion({
    this.droneId = const Value.absent(),
    this.parameterKey = const Value.absent(),
    this.source = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DroneParameterSourcesCompanion.insert({
    required int droneId,
    required String parameterKey,
    required String source,
    this.rowid = const Value.absent(),
  }) : droneId = Value(droneId),
       parameterKey = Value(parameterKey),
       source = Value(source);
  static Insertable<DroneParameterSource> custom({
    Expression<int>? droneId,
    Expression<String>? parameterKey,
    Expression<String>? source,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (droneId != null) 'drone_id': droneId,
      if (parameterKey != null) 'parameter_key': parameterKey,
      if (source != null) 'source': source,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DroneParameterSourcesCompanion copyWith({
    Value<int>? droneId,
    Value<String>? parameterKey,
    Value<String>? source,
    Value<int>? rowid,
  }) {
    return DroneParameterSourcesCompanion(
      droneId: droneId ?? this.droneId,
      parameterKey: parameterKey ?? this.parameterKey,
      source: source ?? this.source,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (droneId.present) {
      map['drone_id'] = Variable<int>(droneId.value);
    }
    if (parameterKey.present) {
      map['parameter_key'] = Variable<String>(parameterKey.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DroneParameterSourcesCompanion(')
          ..write('droneId: $droneId, ')
          ..write('parameterKey: $parameterKey, ')
          ..write('source: $source, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $BatteriesTable extends Batteries
    with TableInfo<$BatteriesTable, Battery> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BatteriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 120,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _chemistryMeta = const VerificationMeta(
    'chemistry',
  );
  @override
  late final GeneratedColumn<String> chemistry = GeneratedColumn<String>(
    'chemistry',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('LiPo'),
  );
  static const VerificationMeta _cellCountMeta = const VerificationMeta(
    'cellCount',
  );
  @override
  late final GeneratedColumn<int> cellCount = GeneratedColumn<int>(
    'cell_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _capacityMahMeta = const VerificationMeta(
    'capacityMah',
  );
  @override
  late final GeneratedColumn<int> capacityMah = GeneratedColumn<int>(
    'capacity_mah',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _weightGramsMeta = const VerificationMeta(
    'weightGrams',
  );
  @override
  late final GeneratedColumn<double> weightGrams = GeneratedColumn<double>(
    'weight_grams',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _cycleCountMeta = const VerificationMeta(
    'cycleCount',
  );
  @override
  late final GeneratedColumn<int> cycleCount = GeneratedColumn<int>(
    'cycle_count',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isTypeMeta = const VerificationMeta('isType');
  @override
  late final GeneratedColumn<bool> isType = GeneratedColumn<bool>(
    'is_type',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_type" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _typeIdMeta = const VerificationMeta('typeId');
  @override
  late final GeneratedColumn<int> typeId = GeneratedColumn<int>(
    'type_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES batteries (id) ON DELETE SET NULL',
    ),
  );
  static const VerificationMeta _nominalVoltageVoltsMeta =
      const VerificationMeta('nominalVoltageVolts');
  @override
  late final GeneratedColumn<double> nominalVoltageVolts =
      GeneratedColumn<double>(
        'nominal_voltage_volts',
        aliasedName,
        true,
        type: DriftSqlType.double,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _energyWhMeta = const VerificationMeta(
    'energyWh',
  );
  @override
  late final GeneratedColumn<double> energyWh = GeneratedColumn<double>(
    'energy_wh',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _chargePercentMeta = const VerificationMeta(
    'chargePercent',
  );
  @override
  late final GeneratedColumn<double> chargePercent = GeneratedColumn<double>(
    'charge_percent',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _availabilityMeta = const VerificationMeta(
    'availability',
  );
  @override
  late final GeneratedColumn<String> availability = GeneratedColumn<String>(
    'availability',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('unknown'),
  );
  static const VerificationMeta _conditionNotesMeta = const VerificationMeta(
    'conditionNotes',
  );
  @override
  late final GeneratedColumn<String> conditionNotes = GeneratedColumn<String>(
    'condition_notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    chemistry,
    cellCount,
    capacityMah,
    weightGrams,
    cycleCount,
    isType,
    typeId,
    nominalVoltageVolts,
    energyWh,
    chargePercent,
    availability,
    conditionNotes,
    notes,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'batteries';
  @override
  VerificationContext validateIntegrity(
    Insertable<Battery> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('chemistry')) {
      context.handle(
        _chemistryMeta,
        chemistry.isAcceptableOrUnknown(data['chemistry']!, _chemistryMeta),
      );
    }
    if (data.containsKey('cell_count')) {
      context.handle(
        _cellCountMeta,
        cellCount.isAcceptableOrUnknown(data['cell_count']!, _cellCountMeta),
      );
    } else if (isInserting) {
      context.missing(_cellCountMeta);
    }
    if (data.containsKey('capacity_mah')) {
      context.handle(
        _capacityMahMeta,
        capacityMah.isAcceptableOrUnknown(
          data['capacity_mah']!,
          _capacityMahMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_capacityMahMeta);
    }
    if (data.containsKey('weight_grams')) {
      context.handle(
        _weightGramsMeta,
        weightGrams.isAcceptableOrUnknown(
          data['weight_grams']!,
          _weightGramsMeta,
        ),
      );
    }
    if (data.containsKey('cycle_count')) {
      context.handle(
        _cycleCountMeta,
        cycleCount.isAcceptableOrUnknown(data['cycle_count']!, _cycleCountMeta),
      );
    }
    if (data.containsKey('is_type')) {
      context.handle(
        _isTypeMeta,
        isType.isAcceptableOrUnknown(data['is_type']!, _isTypeMeta),
      );
    }
    if (data.containsKey('type_id')) {
      context.handle(
        _typeIdMeta,
        typeId.isAcceptableOrUnknown(data['type_id']!, _typeIdMeta),
      );
    }
    if (data.containsKey('nominal_voltage_volts')) {
      context.handle(
        _nominalVoltageVoltsMeta,
        nominalVoltageVolts.isAcceptableOrUnknown(
          data['nominal_voltage_volts']!,
          _nominalVoltageVoltsMeta,
        ),
      );
    }
    if (data.containsKey('energy_wh')) {
      context.handle(
        _energyWhMeta,
        energyWh.isAcceptableOrUnknown(data['energy_wh']!, _energyWhMeta),
      );
    }
    if (data.containsKey('charge_percent')) {
      context.handle(
        _chargePercentMeta,
        chargePercent.isAcceptableOrUnknown(
          data['charge_percent']!,
          _chargePercentMeta,
        ),
      );
    }
    if (data.containsKey('availability')) {
      context.handle(
        _availabilityMeta,
        availability.isAcceptableOrUnknown(
          data['availability']!,
          _availabilityMeta,
        ),
      );
    }
    if (data.containsKey('condition_notes')) {
      context.handle(
        _conditionNotesMeta,
        conditionNotes.isAcceptableOrUnknown(
          data['condition_notes']!,
          _conditionNotesMeta,
        ),
      );
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Battery map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Battery(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      chemistry: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}chemistry'],
      )!,
      cellCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}cell_count'],
      )!,
      capacityMah: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}capacity_mah'],
      )!,
      weightGrams: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}weight_grams'],
      ),
      cycleCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}cycle_count'],
      ),
      isType: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_type'],
      )!,
      typeId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}type_id'],
      ),
      nominalVoltageVolts: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}nominal_voltage_volts'],
      ),
      energyWh: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}energy_wh'],
      ),
      chargePercent: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}charge_percent'],
      ),
      availability: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}availability'],
      )!,
      conditionNotes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}condition_notes'],
      ),
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
    );
  }

  @override
  $BatteriesTable createAlias(String alias) {
    return $BatteriesTable(attachedDatabase, alias);
  }
}

class Battery extends DataClass implements Insertable<Battery> {
  final int id;
  final String name;
  final String chemistry;
  final int cellCount;
  final int capacityMah;
  final double? weightGrams;
  final int? cycleCount;
  final bool isType;
  final int? typeId;
  final double? nominalVoltageVolts;
  final double? energyWh;
  final double? chargePercent;
  final String availability;
  final String? conditionNotes;
  final String? notes;
  const Battery({
    required this.id,
    required this.name,
    required this.chemistry,
    required this.cellCount,
    required this.capacityMah,
    this.weightGrams,
    this.cycleCount,
    required this.isType,
    this.typeId,
    this.nominalVoltageVolts,
    this.energyWh,
    this.chargePercent,
    required this.availability,
    this.conditionNotes,
    this.notes,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['chemistry'] = Variable<String>(chemistry);
    map['cell_count'] = Variable<int>(cellCount);
    map['capacity_mah'] = Variable<int>(capacityMah);
    if (!nullToAbsent || weightGrams != null) {
      map['weight_grams'] = Variable<double>(weightGrams);
    }
    if (!nullToAbsent || cycleCount != null) {
      map['cycle_count'] = Variable<int>(cycleCount);
    }
    map['is_type'] = Variable<bool>(isType);
    if (!nullToAbsent || typeId != null) {
      map['type_id'] = Variable<int>(typeId);
    }
    if (!nullToAbsent || nominalVoltageVolts != null) {
      map['nominal_voltage_volts'] = Variable<double>(nominalVoltageVolts);
    }
    if (!nullToAbsent || energyWh != null) {
      map['energy_wh'] = Variable<double>(energyWh);
    }
    if (!nullToAbsent || chargePercent != null) {
      map['charge_percent'] = Variable<double>(chargePercent);
    }
    map['availability'] = Variable<String>(availability);
    if (!nullToAbsent || conditionNotes != null) {
      map['condition_notes'] = Variable<String>(conditionNotes);
    }
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    return map;
  }

  BatteriesCompanion toCompanion(bool nullToAbsent) {
    return BatteriesCompanion(
      id: Value(id),
      name: Value(name),
      chemistry: Value(chemistry),
      cellCount: Value(cellCount),
      capacityMah: Value(capacityMah),
      weightGrams: weightGrams == null && nullToAbsent
          ? const Value.absent()
          : Value(weightGrams),
      cycleCount: cycleCount == null && nullToAbsent
          ? const Value.absent()
          : Value(cycleCount),
      isType: Value(isType),
      typeId: typeId == null && nullToAbsent
          ? const Value.absent()
          : Value(typeId),
      nominalVoltageVolts: nominalVoltageVolts == null && nullToAbsent
          ? const Value.absent()
          : Value(nominalVoltageVolts),
      energyWh: energyWh == null && nullToAbsent
          ? const Value.absent()
          : Value(energyWh),
      chargePercent: chargePercent == null && nullToAbsent
          ? const Value.absent()
          : Value(chargePercent),
      availability: Value(availability),
      conditionNotes: conditionNotes == null && nullToAbsent
          ? const Value.absent()
          : Value(conditionNotes),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
    );
  }

  factory Battery.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Battery(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      chemistry: serializer.fromJson<String>(json['chemistry']),
      cellCount: serializer.fromJson<int>(json['cellCount']),
      capacityMah: serializer.fromJson<int>(json['capacityMah']),
      weightGrams: serializer.fromJson<double?>(json['weightGrams']),
      cycleCount: serializer.fromJson<int?>(json['cycleCount']),
      isType: serializer.fromJson<bool>(json['isType']),
      typeId: serializer.fromJson<int?>(json['typeId']),
      nominalVoltageVolts: serializer.fromJson<double?>(
        json['nominalVoltageVolts'],
      ),
      energyWh: serializer.fromJson<double?>(json['energyWh']),
      chargePercent: serializer.fromJson<double?>(json['chargePercent']),
      availability: serializer.fromJson<String>(json['availability']),
      conditionNotes: serializer.fromJson<String?>(json['conditionNotes']),
      notes: serializer.fromJson<String?>(json['notes']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'chemistry': serializer.toJson<String>(chemistry),
      'cellCount': serializer.toJson<int>(cellCount),
      'capacityMah': serializer.toJson<int>(capacityMah),
      'weightGrams': serializer.toJson<double?>(weightGrams),
      'cycleCount': serializer.toJson<int?>(cycleCount),
      'isType': serializer.toJson<bool>(isType),
      'typeId': serializer.toJson<int?>(typeId),
      'nominalVoltageVolts': serializer.toJson<double?>(nominalVoltageVolts),
      'energyWh': serializer.toJson<double?>(energyWh),
      'chargePercent': serializer.toJson<double?>(chargePercent),
      'availability': serializer.toJson<String>(availability),
      'conditionNotes': serializer.toJson<String?>(conditionNotes),
      'notes': serializer.toJson<String?>(notes),
    };
  }

  Battery copyWith({
    int? id,
    String? name,
    String? chemistry,
    int? cellCount,
    int? capacityMah,
    Value<double?> weightGrams = const Value.absent(),
    Value<int?> cycleCount = const Value.absent(),
    bool? isType,
    Value<int?> typeId = const Value.absent(),
    Value<double?> nominalVoltageVolts = const Value.absent(),
    Value<double?> energyWh = const Value.absent(),
    Value<double?> chargePercent = const Value.absent(),
    String? availability,
    Value<String?> conditionNotes = const Value.absent(),
    Value<String?> notes = const Value.absent(),
  }) => Battery(
    id: id ?? this.id,
    name: name ?? this.name,
    chemistry: chemistry ?? this.chemistry,
    cellCount: cellCount ?? this.cellCount,
    capacityMah: capacityMah ?? this.capacityMah,
    weightGrams: weightGrams.present ? weightGrams.value : this.weightGrams,
    cycleCount: cycleCount.present ? cycleCount.value : this.cycleCount,
    isType: isType ?? this.isType,
    typeId: typeId.present ? typeId.value : this.typeId,
    nominalVoltageVolts: nominalVoltageVolts.present
        ? nominalVoltageVolts.value
        : this.nominalVoltageVolts,
    energyWh: energyWh.present ? energyWh.value : this.energyWh,
    chargePercent: chargePercent.present
        ? chargePercent.value
        : this.chargePercent,
    availability: availability ?? this.availability,
    conditionNotes: conditionNotes.present
        ? conditionNotes.value
        : this.conditionNotes,
    notes: notes.present ? notes.value : this.notes,
  );
  Battery copyWithCompanion(BatteriesCompanion data) {
    return Battery(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      chemistry: data.chemistry.present ? data.chemistry.value : this.chemistry,
      cellCount: data.cellCount.present ? data.cellCount.value : this.cellCount,
      capacityMah: data.capacityMah.present
          ? data.capacityMah.value
          : this.capacityMah,
      weightGrams: data.weightGrams.present
          ? data.weightGrams.value
          : this.weightGrams,
      cycleCount: data.cycleCount.present
          ? data.cycleCount.value
          : this.cycleCount,
      isType: data.isType.present ? data.isType.value : this.isType,
      typeId: data.typeId.present ? data.typeId.value : this.typeId,
      nominalVoltageVolts: data.nominalVoltageVolts.present
          ? data.nominalVoltageVolts.value
          : this.nominalVoltageVolts,
      energyWh: data.energyWh.present ? data.energyWh.value : this.energyWh,
      chargePercent: data.chargePercent.present
          ? data.chargePercent.value
          : this.chargePercent,
      availability: data.availability.present
          ? data.availability.value
          : this.availability,
      conditionNotes: data.conditionNotes.present
          ? data.conditionNotes.value
          : this.conditionNotes,
      notes: data.notes.present ? data.notes.value : this.notes,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Battery(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('chemistry: $chemistry, ')
          ..write('cellCount: $cellCount, ')
          ..write('capacityMah: $capacityMah, ')
          ..write('weightGrams: $weightGrams, ')
          ..write('cycleCount: $cycleCount, ')
          ..write('isType: $isType, ')
          ..write('typeId: $typeId, ')
          ..write('nominalVoltageVolts: $nominalVoltageVolts, ')
          ..write('energyWh: $energyWh, ')
          ..write('chargePercent: $chargePercent, ')
          ..write('availability: $availability, ')
          ..write('conditionNotes: $conditionNotes, ')
          ..write('notes: $notes')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    chemistry,
    cellCount,
    capacityMah,
    weightGrams,
    cycleCount,
    isType,
    typeId,
    nominalVoltageVolts,
    energyWh,
    chargePercent,
    availability,
    conditionNotes,
    notes,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Battery &&
          other.id == this.id &&
          other.name == this.name &&
          other.chemistry == this.chemistry &&
          other.cellCount == this.cellCount &&
          other.capacityMah == this.capacityMah &&
          other.weightGrams == this.weightGrams &&
          other.cycleCount == this.cycleCount &&
          other.isType == this.isType &&
          other.typeId == this.typeId &&
          other.nominalVoltageVolts == this.nominalVoltageVolts &&
          other.energyWh == this.energyWh &&
          other.chargePercent == this.chargePercent &&
          other.availability == this.availability &&
          other.conditionNotes == this.conditionNotes &&
          other.notes == this.notes);
}

class BatteriesCompanion extends UpdateCompanion<Battery> {
  final Value<int> id;
  final Value<String> name;
  final Value<String> chemistry;
  final Value<int> cellCount;
  final Value<int> capacityMah;
  final Value<double?> weightGrams;
  final Value<int?> cycleCount;
  final Value<bool> isType;
  final Value<int?> typeId;
  final Value<double?> nominalVoltageVolts;
  final Value<double?> energyWh;
  final Value<double?> chargePercent;
  final Value<String> availability;
  final Value<String?> conditionNotes;
  final Value<String?> notes;
  const BatteriesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.chemistry = const Value.absent(),
    this.cellCount = const Value.absent(),
    this.capacityMah = const Value.absent(),
    this.weightGrams = const Value.absent(),
    this.cycleCount = const Value.absent(),
    this.isType = const Value.absent(),
    this.typeId = const Value.absent(),
    this.nominalVoltageVolts = const Value.absent(),
    this.energyWh = const Value.absent(),
    this.chargePercent = const Value.absent(),
    this.availability = const Value.absent(),
    this.conditionNotes = const Value.absent(),
    this.notes = const Value.absent(),
  });
  BatteriesCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    this.chemistry = const Value.absent(),
    required int cellCount,
    required int capacityMah,
    this.weightGrams = const Value.absent(),
    this.cycleCount = const Value.absent(),
    this.isType = const Value.absent(),
    this.typeId = const Value.absent(),
    this.nominalVoltageVolts = const Value.absent(),
    this.energyWh = const Value.absent(),
    this.chargePercent = const Value.absent(),
    this.availability = const Value.absent(),
    this.conditionNotes = const Value.absent(),
    this.notes = const Value.absent(),
  }) : name = Value(name),
       cellCount = Value(cellCount),
       capacityMah = Value(capacityMah);
  static Insertable<Battery> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? chemistry,
    Expression<int>? cellCount,
    Expression<int>? capacityMah,
    Expression<double>? weightGrams,
    Expression<int>? cycleCount,
    Expression<bool>? isType,
    Expression<int>? typeId,
    Expression<double>? nominalVoltageVolts,
    Expression<double>? energyWh,
    Expression<double>? chargePercent,
    Expression<String>? availability,
    Expression<String>? conditionNotes,
    Expression<String>? notes,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (chemistry != null) 'chemistry': chemistry,
      if (cellCount != null) 'cell_count': cellCount,
      if (capacityMah != null) 'capacity_mah': capacityMah,
      if (weightGrams != null) 'weight_grams': weightGrams,
      if (cycleCount != null) 'cycle_count': cycleCount,
      if (isType != null) 'is_type': isType,
      if (typeId != null) 'type_id': typeId,
      if (nominalVoltageVolts != null)
        'nominal_voltage_volts': nominalVoltageVolts,
      if (energyWh != null) 'energy_wh': energyWh,
      if (chargePercent != null) 'charge_percent': chargePercent,
      if (availability != null) 'availability': availability,
      if (conditionNotes != null) 'condition_notes': conditionNotes,
      if (notes != null) 'notes': notes,
    });
  }

  BatteriesCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<String>? chemistry,
    Value<int>? cellCount,
    Value<int>? capacityMah,
    Value<double?>? weightGrams,
    Value<int?>? cycleCount,
    Value<bool>? isType,
    Value<int?>? typeId,
    Value<double?>? nominalVoltageVolts,
    Value<double?>? energyWh,
    Value<double?>? chargePercent,
    Value<String>? availability,
    Value<String?>? conditionNotes,
    Value<String?>? notes,
  }) {
    return BatteriesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      chemistry: chemistry ?? this.chemistry,
      cellCount: cellCount ?? this.cellCount,
      capacityMah: capacityMah ?? this.capacityMah,
      weightGrams: weightGrams ?? this.weightGrams,
      cycleCount: cycleCount ?? this.cycleCount,
      isType: isType ?? this.isType,
      typeId: typeId ?? this.typeId,
      nominalVoltageVolts: nominalVoltageVolts ?? this.nominalVoltageVolts,
      energyWh: energyWh ?? this.energyWh,
      chargePercent: chargePercent ?? this.chargePercent,
      availability: availability ?? this.availability,
      conditionNotes: conditionNotes ?? this.conditionNotes,
      notes: notes ?? this.notes,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (chemistry.present) {
      map['chemistry'] = Variable<String>(chemistry.value);
    }
    if (cellCount.present) {
      map['cell_count'] = Variable<int>(cellCount.value);
    }
    if (capacityMah.present) {
      map['capacity_mah'] = Variable<int>(capacityMah.value);
    }
    if (weightGrams.present) {
      map['weight_grams'] = Variable<double>(weightGrams.value);
    }
    if (cycleCount.present) {
      map['cycle_count'] = Variable<int>(cycleCount.value);
    }
    if (isType.present) {
      map['is_type'] = Variable<bool>(isType.value);
    }
    if (typeId.present) {
      map['type_id'] = Variable<int>(typeId.value);
    }
    if (nominalVoltageVolts.present) {
      map['nominal_voltage_volts'] = Variable<double>(
        nominalVoltageVolts.value,
      );
    }
    if (energyWh.present) {
      map['energy_wh'] = Variable<double>(energyWh.value);
    }
    if (chargePercent.present) {
      map['charge_percent'] = Variable<double>(chargePercent.value);
    }
    if (availability.present) {
      map['availability'] = Variable<String>(availability.value);
    }
    if (conditionNotes.present) {
      map['condition_notes'] = Variable<String>(conditionNotes.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BatteriesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('chemistry: $chemistry, ')
          ..write('cellCount: $cellCount, ')
          ..write('capacityMah: $capacityMah, ')
          ..write('weightGrams: $weightGrams, ')
          ..write('cycleCount: $cycleCount, ')
          ..write('isType: $isType, ')
          ..write('typeId: $typeId, ')
          ..write('nominalVoltageVolts: $nominalVoltageVolts, ')
          ..write('energyWh: $energyWh, ')
          ..write('chargePercent: $chargePercent, ')
          ..write('availability: $availability, ')
          ..write('conditionNotes: $conditionNotes, ')
          ..write('notes: $notes')
          ..write(')'))
        .toString();
  }
}

class $BatteryDronesTable extends BatteryDrones
    with TableInfo<$BatteryDronesTable, BatteryDrone> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BatteryDronesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _batteryIdMeta = const VerificationMeta(
    'batteryId',
  );
  @override
  late final GeneratedColumn<int> batteryId = GeneratedColumn<int>(
    'battery_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES batteries (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _droneIdMeta = const VerificationMeta(
    'droneId',
  );
  @override
  late final GeneratedColumn<int> droneId = GeneratedColumn<int>(
    'drone_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES drones (id) ON DELETE CASCADE',
    ),
  );
  @override
  List<GeneratedColumn> get $columns => [batteryId, droneId];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'battery_drones';
  @override
  VerificationContext validateIntegrity(
    Insertable<BatteryDrone> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('battery_id')) {
      context.handle(
        _batteryIdMeta,
        batteryId.isAcceptableOrUnknown(data['battery_id']!, _batteryIdMeta),
      );
    } else if (isInserting) {
      context.missing(_batteryIdMeta);
    }
    if (data.containsKey('drone_id')) {
      context.handle(
        _droneIdMeta,
        droneId.isAcceptableOrUnknown(data['drone_id']!, _droneIdMeta),
      );
    } else if (isInserting) {
      context.missing(_droneIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {batteryId, droneId};
  @override
  BatteryDrone map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BatteryDrone(
      batteryId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}battery_id'],
      )!,
      droneId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}drone_id'],
      )!,
    );
  }

  @override
  $BatteryDronesTable createAlias(String alias) {
    return $BatteryDronesTable(attachedDatabase, alias);
  }
}

class BatteryDrone extends DataClass implements Insertable<BatteryDrone> {
  final int batteryId;
  final int droneId;
  const BatteryDrone({required this.batteryId, required this.droneId});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['battery_id'] = Variable<int>(batteryId);
    map['drone_id'] = Variable<int>(droneId);
    return map;
  }

  BatteryDronesCompanion toCompanion(bool nullToAbsent) {
    return BatteryDronesCompanion(
      batteryId: Value(batteryId),
      droneId: Value(droneId),
    );
  }

  factory BatteryDrone.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BatteryDrone(
      batteryId: serializer.fromJson<int>(json['batteryId']),
      droneId: serializer.fromJson<int>(json['droneId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'batteryId': serializer.toJson<int>(batteryId),
      'droneId': serializer.toJson<int>(droneId),
    };
  }

  BatteryDrone copyWith({int? batteryId, int? droneId}) => BatteryDrone(
    batteryId: batteryId ?? this.batteryId,
    droneId: droneId ?? this.droneId,
  );
  BatteryDrone copyWithCompanion(BatteryDronesCompanion data) {
    return BatteryDrone(
      batteryId: data.batteryId.present ? data.batteryId.value : this.batteryId,
      droneId: data.droneId.present ? data.droneId.value : this.droneId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BatteryDrone(')
          ..write('batteryId: $batteryId, ')
          ..write('droneId: $droneId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(batteryId, droneId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BatteryDrone &&
          other.batteryId == this.batteryId &&
          other.droneId == this.droneId);
}

class BatteryDronesCompanion extends UpdateCompanion<BatteryDrone> {
  final Value<int> batteryId;
  final Value<int> droneId;
  final Value<int> rowid;
  const BatteryDronesCompanion({
    this.batteryId = const Value.absent(),
    this.droneId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  BatteryDronesCompanion.insert({
    required int batteryId,
    required int droneId,
    this.rowid = const Value.absent(),
  }) : batteryId = Value(batteryId),
       droneId = Value(droneId);
  static Insertable<BatteryDrone> custom({
    Expression<int>? batteryId,
    Expression<int>? droneId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (batteryId != null) 'battery_id': batteryId,
      if (droneId != null) 'drone_id': droneId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  BatteryDronesCompanion copyWith({
    Value<int>? batteryId,
    Value<int>? droneId,
    Value<int>? rowid,
  }) {
    return BatteryDronesCompanion(
      batteryId: batteryId ?? this.batteryId,
      droneId: droneId ?? this.droneId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (batteryId.present) {
      map['battery_id'] = Variable<int>(batteryId.value);
    }
    if (droneId.present) {
      map['drone_id'] = Variable<int>(droneId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BatteryDronesCompanion(')
          ..write('batteryId: $batteryId, ')
          ..write('droneId: $droneId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $FlightPlansTable extends FlightPlans
    with TableInfo<$FlightPlansTable, FlightPlan> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FlightPlansTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 120,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _droneIdMeta = const VerificationMeta(
    'droneId',
  );
  @override
  late final GeneratedColumn<int> droneId = GeneratedColumn<int>(
    'drone_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES drones (id) ON DELETE SET NULL',
    ),
  );
  static const VerificationMeta _startSpotIdMeta = const VerificationMeta(
    'startSpotId',
  );
  @override
  late final GeneratedColumn<int> startSpotId = GeneratedColumn<int>(
    'start_spot_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES spots (id) ON DELETE SET NULL',
    ),
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    droneId,
    startSpotId,
    notes,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'flight_plans';
  @override
  VerificationContext validateIntegrity(
    Insertable<FlightPlan> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('drone_id')) {
      context.handle(
        _droneIdMeta,
        droneId.isAcceptableOrUnknown(data['drone_id']!, _droneIdMeta),
      );
    }
    if (data.containsKey('start_spot_id')) {
      context.handle(
        _startSpotIdMeta,
        startSpotId.isAcceptableOrUnknown(
          data['start_spot_id']!,
          _startSpotIdMeta,
        ),
      );
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  FlightPlan map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return FlightPlan(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      droneId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}drone_id'],
      ),
      startSpotId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}start_spot_id'],
      ),
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $FlightPlansTable createAlias(String alias) {
    return $FlightPlansTable(attachedDatabase, alias);
  }
}

class FlightPlan extends DataClass implements Insertable<FlightPlan> {
  final int id;
  final String name;
  final int? droneId;
  final int? startSpotId;
  final String? notes;
  final DateTime createdAt;
  const FlightPlan({
    required this.id,
    required this.name,
    this.droneId,
    this.startSpotId,
    this.notes,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || droneId != null) {
      map['drone_id'] = Variable<int>(droneId);
    }
    if (!nullToAbsent || startSpotId != null) {
      map['start_spot_id'] = Variable<int>(startSpotId);
    }
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  FlightPlansCompanion toCompanion(bool nullToAbsent) {
    return FlightPlansCompanion(
      id: Value(id),
      name: Value(name),
      droneId: droneId == null && nullToAbsent
          ? const Value.absent()
          : Value(droneId),
      startSpotId: startSpotId == null && nullToAbsent
          ? const Value.absent()
          : Value(startSpotId),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
      createdAt: Value(createdAt),
    );
  }

  factory FlightPlan.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return FlightPlan(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      droneId: serializer.fromJson<int?>(json['droneId']),
      startSpotId: serializer.fromJson<int?>(json['startSpotId']),
      notes: serializer.fromJson<String?>(json['notes']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'droneId': serializer.toJson<int?>(droneId),
      'startSpotId': serializer.toJson<int?>(startSpotId),
      'notes': serializer.toJson<String?>(notes),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  FlightPlan copyWith({
    int? id,
    String? name,
    Value<int?> droneId = const Value.absent(),
    Value<int?> startSpotId = const Value.absent(),
    Value<String?> notes = const Value.absent(),
    DateTime? createdAt,
  }) => FlightPlan(
    id: id ?? this.id,
    name: name ?? this.name,
    droneId: droneId.present ? droneId.value : this.droneId,
    startSpotId: startSpotId.present ? startSpotId.value : this.startSpotId,
    notes: notes.present ? notes.value : this.notes,
    createdAt: createdAt ?? this.createdAt,
  );
  FlightPlan copyWithCompanion(FlightPlansCompanion data) {
    return FlightPlan(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      droneId: data.droneId.present ? data.droneId.value : this.droneId,
      startSpotId: data.startSpotId.present
          ? data.startSpotId.value
          : this.startSpotId,
      notes: data.notes.present ? data.notes.value : this.notes,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('FlightPlan(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('droneId: $droneId, ')
          ..write('startSpotId: $startSpotId, ')
          ..write('notes: $notes, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, name, droneId, startSpotId, notes, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FlightPlan &&
          other.id == this.id &&
          other.name == this.name &&
          other.droneId == this.droneId &&
          other.startSpotId == this.startSpotId &&
          other.notes == this.notes &&
          other.createdAt == this.createdAt);
}

class FlightPlansCompanion extends UpdateCompanion<FlightPlan> {
  final Value<int> id;
  final Value<String> name;
  final Value<int?> droneId;
  final Value<int?> startSpotId;
  final Value<String?> notes;
  final Value<DateTime> createdAt;
  const FlightPlansCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.droneId = const Value.absent(),
    this.startSpotId = const Value.absent(),
    this.notes = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  FlightPlansCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    this.droneId = const Value.absent(),
    this.startSpotId = const Value.absent(),
    this.notes = const Value.absent(),
    this.createdAt = const Value.absent(),
  }) : name = Value(name);
  static Insertable<FlightPlan> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<int>? droneId,
    Expression<int>? startSpotId,
    Expression<String>? notes,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (droneId != null) 'drone_id': droneId,
      if (startSpotId != null) 'start_spot_id': startSpotId,
      if (notes != null) 'notes': notes,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  FlightPlansCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<int?>? droneId,
    Value<int?>? startSpotId,
    Value<String?>? notes,
    Value<DateTime>? createdAt,
  }) {
    return FlightPlansCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      droneId: droneId ?? this.droneId,
      startSpotId: startSpotId ?? this.startSpotId,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (droneId.present) {
      map['drone_id'] = Variable<int>(droneId.value);
    }
    if (startSpotId.present) {
      map['start_spot_id'] = Variable<int>(startSpotId.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FlightPlansCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('droneId: $droneId, ')
          ..write('startSpotId: $startSpotId, ')
          ..write('notes: $notes, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $BatteryFlightPlansTable extends BatteryFlightPlans
    with TableInfo<$BatteryFlightPlansTable, BatteryFlightPlan> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BatteryFlightPlansTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _batteryIdMeta = const VerificationMeta(
    'batteryId',
  );
  @override
  late final GeneratedColumn<int> batteryId = GeneratedColumn<int>(
    'battery_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES batteries (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _planIdMeta = const VerificationMeta('planId');
  @override
  late final GeneratedColumn<int> planId = GeneratedColumn<int>(
    'plan_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES flight_plans (id) ON DELETE CASCADE',
    ),
  );
  @override
  List<GeneratedColumn> get $columns => [batteryId, planId];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'battery_flight_plans';
  @override
  VerificationContext validateIntegrity(
    Insertable<BatteryFlightPlan> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('battery_id')) {
      context.handle(
        _batteryIdMeta,
        batteryId.isAcceptableOrUnknown(data['battery_id']!, _batteryIdMeta),
      );
    } else if (isInserting) {
      context.missing(_batteryIdMeta);
    }
    if (data.containsKey('plan_id')) {
      context.handle(
        _planIdMeta,
        planId.isAcceptableOrUnknown(data['plan_id']!, _planIdMeta),
      );
    } else if (isInserting) {
      context.missing(_planIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {batteryId, planId};
  @override
  BatteryFlightPlan map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BatteryFlightPlan(
      batteryId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}battery_id'],
      )!,
      planId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}plan_id'],
      )!,
    );
  }

  @override
  $BatteryFlightPlansTable createAlias(String alias) {
    return $BatteryFlightPlansTable(attachedDatabase, alias);
  }
}

class BatteryFlightPlan extends DataClass
    implements Insertable<BatteryFlightPlan> {
  final int batteryId;
  final int planId;
  const BatteryFlightPlan({required this.batteryId, required this.planId});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['battery_id'] = Variable<int>(batteryId);
    map['plan_id'] = Variable<int>(planId);
    return map;
  }

  BatteryFlightPlansCompanion toCompanion(bool nullToAbsent) {
    return BatteryFlightPlansCompanion(
      batteryId: Value(batteryId),
      planId: Value(planId),
    );
  }

  factory BatteryFlightPlan.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BatteryFlightPlan(
      batteryId: serializer.fromJson<int>(json['batteryId']),
      planId: serializer.fromJson<int>(json['planId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'batteryId': serializer.toJson<int>(batteryId),
      'planId': serializer.toJson<int>(planId),
    };
  }

  BatteryFlightPlan copyWith({int? batteryId, int? planId}) =>
      BatteryFlightPlan(
        batteryId: batteryId ?? this.batteryId,
        planId: planId ?? this.planId,
      );
  BatteryFlightPlan copyWithCompanion(BatteryFlightPlansCompanion data) {
    return BatteryFlightPlan(
      batteryId: data.batteryId.present ? data.batteryId.value : this.batteryId,
      planId: data.planId.present ? data.planId.value : this.planId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BatteryFlightPlan(')
          ..write('batteryId: $batteryId, ')
          ..write('planId: $planId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(batteryId, planId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BatteryFlightPlan &&
          other.batteryId == this.batteryId &&
          other.planId == this.planId);
}

class BatteryFlightPlansCompanion extends UpdateCompanion<BatteryFlightPlan> {
  final Value<int> batteryId;
  final Value<int> planId;
  final Value<int> rowid;
  const BatteryFlightPlansCompanion({
    this.batteryId = const Value.absent(),
    this.planId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  BatteryFlightPlansCompanion.insert({
    required int batteryId,
    required int planId,
    this.rowid = const Value.absent(),
  }) : batteryId = Value(batteryId),
       planId = Value(planId);
  static Insertable<BatteryFlightPlan> custom({
    Expression<int>? batteryId,
    Expression<int>? planId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (batteryId != null) 'battery_id': batteryId,
      if (planId != null) 'plan_id': planId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  BatteryFlightPlansCompanion copyWith({
    Value<int>? batteryId,
    Value<int>? planId,
    Value<int>? rowid,
  }) {
    return BatteryFlightPlansCompanion(
      batteryId: batteryId ?? this.batteryId,
      planId: planId ?? this.planId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (batteryId.present) {
      map['battery_id'] = Variable<int>(batteryId.value);
    }
    if (planId.present) {
      map['plan_id'] = Variable<int>(planId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BatteryFlightPlansCompanion(')
          ..write('batteryId: $batteryId, ')
          ..write('planId: $planId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $RadioEquipmentTable extends RadioEquipment
    with TableInfo<$RadioEquipmentTable, RadioEquipmentData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RadioEquipmentTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 120,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _categoryMeta = const VerificationMeta(
    'category',
  );
  @override
  late final GeneratedColumn<String> category = GeneratedColumn<String>(
    'category',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _frequencyMhzMeta = const VerificationMeta(
    'frequencyMhz',
  );
  @override
  late final GeneratedColumn<double> frequencyMhz = GeneratedColumn<double>(
    'frequency_mhz',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _maxPowerMwMeta = const VerificationMeta(
    'maxPowerMw',
  );
  @override
  late final GeneratedColumn<double> maxPowerMw = GeneratedColumn<double>(
    'max_power_mw',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    category,
    frequencyMhz,
    maxPowerMw,
    notes,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'radio_equipment';
  @override
  VerificationContext validateIntegrity(
    Insertable<RadioEquipmentData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('category')) {
      context.handle(
        _categoryMeta,
        category.isAcceptableOrUnknown(data['category']!, _categoryMeta),
      );
    } else if (isInserting) {
      context.missing(_categoryMeta);
    }
    if (data.containsKey('frequency_mhz')) {
      context.handle(
        _frequencyMhzMeta,
        frequencyMhz.isAcceptableOrUnknown(
          data['frequency_mhz']!,
          _frequencyMhzMeta,
        ),
      );
    }
    if (data.containsKey('max_power_mw')) {
      context.handle(
        _maxPowerMwMeta,
        maxPowerMw.isAcceptableOrUnknown(
          data['max_power_mw']!,
          _maxPowerMwMeta,
        ),
      );
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  RadioEquipmentData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RadioEquipmentData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      category: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category'],
      )!,
      frequencyMhz: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}frequency_mhz'],
      ),
      maxPowerMw: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}max_power_mw'],
      ),
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
    );
  }

  @override
  $RadioEquipmentTable createAlias(String alias) {
    return $RadioEquipmentTable(attachedDatabase, alias);
  }
}

class RadioEquipmentData extends DataClass
    implements Insertable<RadioEquipmentData> {
  final int id;
  final String name;
  final String category;
  final double? frequencyMhz;
  final double? maxPowerMw;
  final String? notes;
  const RadioEquipmentData({
    required this.id,
    required this.name,
    required this.category,
    this.frequencyMhz,
    this.maxPowerMw,
    this.notes,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['category'] = Variable<String>(category);
    if (!nullToAbsent || frequencyMhz != null) {
      map['frequency_mhz'] = Variable<double>(frequencyMhz);
    }
    if (!nullToAbsent || maxPowerMw != null) {
      map['max_power_mw'] = Variable<double>(maxPowerMw);
    }
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    return map;
  }

  RadioEquipmentCompanion toCompanion(bool nullToAbsent) {
    return RadioEquipmentCompanion(
      id: Value(id),
      name: Value(name),
      category: Value(category),
      frequencyMhz: frequencyMhz == null && nullToAbsent
          ? const Value.absent()
          : Value(frequencyMhz),
      maxPowerMw: maxPowerMw == null && nullToAbsent
          ? const Value.absent()
          : Value(maxPowerMw),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
    );
  }

  factory RadioEquipmentData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RadioEquipmentData(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      category: serializer.fromJson<String>(json['category']),
      frequencyMhz: serializer.fromJson<double?>(json['frequencyMhz']),
      maxPowerMw: serializer.fromJson<double?>(json['maxPowerMw']),
      notes: serializer.fromJson<String?>(json['notes']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'category': serializer.toJson<String>(category),
      'frequencyMhz': serializer.toJson<double?>(frequencyMhz),
      'maxPowerMw': serializer.toJson<double?>(maxPowerMw),
      'notes': serializer.toJson<String?>(notes),
    };
  }

  RadioEquipmentData copyWith({
    int? id,
    String? name,
    String? category,
    Value<double?> frequencyMhz = const Value.absent(),
    Value<double?> maxPowerMw = const Value.absent(),
    Value<String?> notes = const Value.absent(),
  }) => RadioEquipmentData(
    id: id ?? this.id,
    name: name ?? this.name,
    category: category ?? this.category,
    frequencyMhz: frequencyMhz.present ? frequencyMhz.value : this.frequencyMhz,
    maxPowerMw: maxPowerMw.present ? maxPowerMw.value : this.maxPowerMw,
    notes: notes.present ? notes.value : this.notes,
  );
  RadioEquipmentData copyWithCompanion(RadioEquipmentCompanion data) {
    return RadioEquipmentData(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      category: data.category.present ? data.category.value : this.category,
      frequencyMhz: data.frequencyMhz.present
          ? data.frequencyMhz.value
          : this.frequencyMhz,
      maxPowerMw: data.maxPowerMw.present
          ? data.maxPowerMw.value
          : this.maxPowerMw,
      notes: data.notes.present ? data.notes.value : this.notes,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RadioEquipmentData(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('category: $category, ')
          ..write('frequencyMhz: $frequencyMhz, ')
          ..write('maxPowerMw: $maxPowerMw, ')
          ..write('notes: $notes')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, name, category, frequencyMhz, maxPowerMw, notes);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RadioEquipmentData &&
          other.id == this.id &&
          other.name == this.name &&
          other.category == this.category &&
          other.frequencyMhz == this.frequencyMhz &&
          other.maxPowerMw == this.maxPowerMw &&
          other.notes == this.notes);
}

class RadioEquipmentCompanion extends UpdateCompanion<RadioEquipmentData> {
  final Value<int> id;
  final Value<String> name;
  final Value<String> category;
  final Value<double?> frequencyMhz;
  final Value<double?> maxPowerMw;
  final Value<String?> notes;
  const RadioEquipmentCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.category = const Value.absent(),
    this.frequencyMhz = const Value.absent(),
    this.maxPowerMw = const Value.absent(),
    this.notes = const Value.absent(),
  });
  RadioEquipmentCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    required String category,
    this.frequencyMhz = const Value.absent(),
    this.maxPowerMw = const Value.absent(),
    this.notes = const Value.absent(),
  }) : name = Value(name),
       category = Value(category);
  static Insertable<RadioEquipmentData> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? category,
    Expression<double>? frequencyMhz,
    Expression<double>? maxPowerMw,
    Expression<String>? notes,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (category != null) 'category': category,
      if (frequencyMhz != null) 'frequency_mhz': frequencyMhz,
      if (maxPowerMw != null) 'max_power_mw': maxPowerMw,
      if (notes != null) 'notes': notes,
    });
  }

  RadioEquipmentCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<String>? category,
    Value<double?>? frequencyMhz,
    Value<double?>? maxPowerMw,
    Value<String?>? notes,
  }) {
    return RadioEquipmentCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      frequencyMhz: frequencyMhz ?? this.frequencyMhz,
      maxPowerMw: maxPowerMw ?? this.maxPowerMw,
      notes: notes ?? this.notes,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (category.present) {
      map['category'] = Variable<String>(category.value);
    }
    if (frequencyMhz.present) {
      map['frequency_mhz'] = Variable<double>(frequencyMhz.value);
    }
    if (maxPowerMw.present) {
      map['max_power_mw'] = Variable<double>(maxPowerMw.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RadioEquipmentCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('category: $category, ')
          ..write('frequencyMhz: $frequencyMhz, ')
          ..write('maxPowerMw: $maxPowerMw, ')
          ..write('notes: $notes')
          ..write(')'))
        .toString();
  }
}

class $FlightWaypointsTable extends FlightWaypoints
    with TableInfo<$FlightWaypointsTable, FlightWaypoint> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FlightWaypointsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _planIdMeta = const VerificationMeta('planId');
  @override
  late final GeneratedColumn<int> planId = GeneratedColumn<int>(
    'plan_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES flight_plans (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _sequenceNumberMeta = const VerificationMeta(
    'sequenceNumber',
  );
  @override
  late final GeneratedColumn<int> sequenceNumber = GeneratedColumn<int>(
    'sequence_number',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _latitudeMeta = const VerificationMeta(
    'latitude',
  );
  @override
  late final GeneratedColumn<double> latitude = GeneratedColumn<double>(
    'latitude',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _longitudeMeta = const VerificationMeta(
    'longitude',
  );
  @override
  late final GeneratedColumn<double> longitude = GeneratedColumn<double>(
    'longitude',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _heightMetersMeta = const VerificationMeta(
    'heightMeters',
  );
  @override
  late final GeneratedColumn<double> heightMeters = GeneratedColumn<double>(
    'height_meters',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _heightReferenceMeta = const VerificationMeta(
    'heightReference',
  );
  @override
  late final GeneratedColumn<String> heightReference = GeneratedColumn<String>(
    'height_reference',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('unverified'),
  );
  static const VerificationMeta _altitudeModeMeta = const VerificationMeta(
    'altitudeMode',
  );
  @override
  late final GeneratedColumn<String> altitudeMode = GeneratedColumn<String>(
    'altitude_mode',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('absolute'),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    planId,
    sequenceNumber,
    latitude,
    longitude,
    heightMeters,
    heightReference,
    altitudeMode,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'flight_waypoints';
  @override
  VerificationContext validateIntegrity(
    Insertable<FlightWaypoint> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('plan_id')) {
      context.handle(
        _planIdMeta,
        planId.isAcceptableOrUnknown(data['plan_id']!, _planIdMeta),
      );
    } else if (isInserting) {
      context.missing(_planIdMeta);
    }
    if (data.containsKey('sequence_number')) {
      context.handle(
        _sequenceNumberMeta,
        sequenceNumber.isAcceptableOrUnknown(
          data['sequence_number']!,
          _sequenceNumberMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_sequenceNumberMeta);
    }
    if (data.containsKey('latitude')) {
      context.handle(
        _latitudeMeta,
        latitude.isAcceptableOrUnknown(data['latitude']!, _latitudeMeta),
      );
    } else if (isInserting) {
      context.missing(_latitudeMeta);
    }
    if (data.containsKey('longitude')) {
      context.handle(
        _longitudeMeta,
        longitude.isAcceptableOrUnknown(data['longitude']!, _longitudeMeta),
      );
    } else if (isInserting) {
      context.missing(_longitudeMeta);
    }
    if (data.containsKey('height_meters')) {
      context.handle(
        _heightMetersMeta,
        heightMeters.isAcceptableOrUnknown(
          data['height_meters']!,
          _heightMetersMeta,
        ),
      );
    }
    if (data.containsKey('height_reference')) {
      context.handle(
        _heightReferenceMeta,
        heightReference.isAcceptableOrUnknown(
          data['height_reference']!,
          _heightReferenceMeta,
        ),
      );
    }
    if (data.containsKey('altitude_mode')) {
      context.handle(
        _altitudeModeMeta,
        altitudeMode.isAcceptableOrUnknown(
          data['altitude_mode']!,
          _altitudeModeMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  FlightWaypoint map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return FlightWaypoint(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      planId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}plan_id'],
      )!,
      sequenceNumber: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sequence_number'],
      )!,
      latitude: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}latitude'],
      )!,
      longitude: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}longitude'],
      )!,
      heightMeters: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}height_meters'],
      ),
      heightReference: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}height_reference'],
      )!,
      altitudeMode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}altitude_mode'],
      )!,
    );
  }

  @override
  $FlightWaypointsTable createAlias(String alias) {
    return $FlightWaypointsTable(attachedDatabase, alias);
  }
}

class FlightWaypoint extends DataClass implements Insertable<FlightWaypoint> {
  final int id;
  final int planId;
  final int sequenceNumber;
  final double latitude;
  final double longitude;

  /// Optional planned height.
  ///
  /// Must not be used for safety calculations
  /// without a verified height reference.
  final double? heightMeters;
  final String heightReference;
  final String altitudeMode;
  const FlightWaypoint({
    required this.id,
    required this.planId,
    required this.sequenceNumber,
    required this.latitude,
    required this.longitude,
    this.heightMeters,
    required this.heightReference,
    required this.altitudeMode,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['plan_id'] = Variable<int>(planId);
    map['sequence_number'] = Variable<int>(sequenceNumber);
    map['latitude'] = Variable<double>(latitude);
    map['longitude'] = Variable<double>(longitude);
    if (!nullToAbsent || heightMeters != null) {
      map['height_meters'] = Variable<double>(heightMeters);
    }
    map['height_reference'] = Variable<String>(heightReference);
    map['altitude_mode'] = Variable<String>(altitudeMode);
    return map;
  }

  FlightWaypointsCompanion toCompanion(bool nullToAbsent) {
    return FlightWaypointsCompanion(
      id: Value(id),
      planId: Value(planId),
      sequenceNumber: Value(sequenceNumber),
      latitude: Value(latitude),
      longitude: Value(longitude),
      heightMeters: heightMeters == null && nullToAbsent
          ? const Value.absent()
          : Value(heightMeters),
      heightReference: Value(heightReference),
      altitudeMode: Value(altitudeMode),
    );
  }

  factory FlightWaypoint.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return FlightWaypoint(
      id: serializer.fromJson<int>(json['id']),
      planId: serializer.fromJson<int>(json['planId']),
      sequenceNumber: serializer.fromJson<int>(json['sequenceNumber']),
      latitude: serializer.fromJson<double>(json['latitude']),
      longitude: serializer.fromJson<double>(json['longitude']),
      heightMeters: serializer.fromJson<double?>(json['heightMeters']),
      heightReference: serializer.fromJson<String>(json['heightReference']),
      altitudeMode: serializer.fromJson<String>(json['altitudeMode']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'planId': serializer.toJson<int>(planId),
      'sequenceNumber': serializer.toJson<int>(sequenceNumber),
      'latitude': serializer.toJson<double>(latitude),
      'longitude': serializer.toJson<double>(longitude),
      'heightMeters': serializer.toJson<double?>(heightMeters),
      'heightReference': serializer.toJson<String>(heightReference),
      'altitudeMode': serializer.toJson<String>(altitudeMode),
    };
  }

  FlightWaypoint copyWith({
    int? id,
    int? planId,
    int? sequenceNumber,
    double? latitude,
    double? longitude,
    Value<double?> heightMeters = const Value.absent(),
    String? heightReference,
    String? altitudeMode,
  }) => FlightWaypoint(
    id: id ?? this.id,
    planId: planId ?? this.planId,
    sequenceNumber: sequenceNumber ?? this.sequenceNumber,
    latitude: latitude ?? this.latitude,
    longitude: longitude ?? this.longitude,
    heightMeters: heightMeters.present ? heightMeters.value : this.heightMeters,
    heightReference: heightReference ?? this.heightReference,
    altitudeMode: altitudeMode ?? this.altitudeMode,
  );
  FlightWaypoint copyWithCompanion(FlightWaypointsCompanion data) {
    return FlightWaypoint(
      id: data.id.present ? data.id.value : this.id,
      planId: data.planId.present ? data.planId.value : this.planId,
      sequenceNumber: data.sequenceNumber.present
          ? data.sequenceNumber.value
          : this.sequenceNumber,
      latitude: data.latitude.present ? data.latitude.value : this.latitude,
      longitude: data.longitude.present ? data.longitude.value : this.longitude,
      heightMeters: data.heightMeters.present
          ? data.heightMeters.value
          : this.heightMeters,
      heightReference: data.heightReference.present
          ? data.heightReference.value
          : this.heightReference,
      altitudeMode: data.altitudeMode.present
          ? data.altitudeMode.value
          : this.altitudeMode,
    );
  }

  @override
  String toString() {
    return (StringBuffer('FlightWaypoint(')
          ..write('id: $id, ')
          ..write('planId: $planId, ')
          ..write('sequenceNumber: $sequenceNumber, ')
          ..write('latitude: $latitude, ')
          ..write('longitude: $longitude, ')
          ..write('heightMeters: $heightMeters, ')
          ..write('heightReference: $heightReference, ')
          ..write('altitudeMode: $altitudeMode')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    planId,
    sequenceNumber,
    latitude,
    longitude,
    heightMeters,
    heightReference,
    altitudeMode,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FlightWaypoint &&
          other.id == this.id &&
          other.planId == this.planId &&
          other.sequenceNumber == this.sequenceNumber &&
          other.latitude == this.latitude &&
          other.longitude == this.longitude &&
          other.heightMeters == this.heightMeters &&
          other.heightReference == this.heightReference &&
          other.altitudeMode == this.altitudeMode);
}

class FlightWaypointsCompanion extends UpdateCompanion<FlightWaypoint> {
  final Value<int> id;
  final Value<int> planId;
  final Value<int> sequenceNumber;
  final Value<double> latitude;
  final Value<double> longitude;
  final Value<double?> heightMeters;
  final Value<String> heightReference;
  final Value<String> altitudeMode;
  const FlightWaypointsCompanion({
    this.id = const Value.absent(),
    this.planId = const Value.absent(),
    this.sequenceNumber = const Value.absent(),
    this.latitude = const Value.absent(),
    this.longitude = const Value.absent(),
    this.heightMeters = const Value.absent(),
    this.heightReference = const Value.absent(),
    this.altitudeMode = const Value.absent(),
  });
  FlightWaypointsCompanion.insert({
    this.id = const Value.absent(),
    required int planId,
    required int sequenceNumber,
    required double latitude,
    required double longitude,
    this.heightMeters = const Value.absent(),
    this.heightReference = const Value.absent(),
    this.altitudeMode = const Value.absent(),
  }) : planId = Value(planId),
       sequenceNumber = Value(sequenceNumber),
       latitude = Value(latitude),
       longitude = Value(longitude);
  static Insertable<FlightWaypoint> custom({
    Expression<int>? id,
    Expression<int>? planId,
    Expression<int>? sequenceNumber,
    Expression<double>? latitude,
    Expression<double>? longitude,
    Expression<double>? heightMeters,
    Expression<String>? heightReference,
    Expression<String>? altitudeMode,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (planId != null) 'plan_id': planId,
      if (sequenceNumber != null) 'sequence_number': sequenceNumber,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (heightMeters != null) 'height_meters': heightMeters,
      if (heightReference != null) 'height_reference': heightReference,
      if (altitudeMode != null) 'altitude_mode': altitudeMode,
    });
  }

  FlightWaypointsCompanion copyWith({
    Value<int>? id,
    Value<int>? planId,
    Value<int>? sequenceNumber,
    Value<double>? latitude,
    Value<double>? longitude,
    Value<double?>? heightMeters,
    Value<String>? heightReference,
    Value<String>? altitudeMode,
  }) {
    return FlightWaypointsCompanion(
      id: id ?? this.id,
      planId: planId ?? this.planId,
      sequenceNumber: sequenceNumber ?? this.sequenceNumber,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      heightMeters: heightMeters ?? this.heightMeters,
      heightReference: heightReference ?? this.heightReference,
      altitudeMode: altitudeMode ?? this.altitudeMode,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (planId.present) {
      map['plan_id'] = Variable<int>(planId.value);
    }
    if (sequenceNumber.present) {
      map['sequence_number'] = Variable<int>(sequenceNumber.value);
    }
    if (latitude.present) {
      map['latitude'] = Variable<double>(latitude.value);
    }
    if (longitude.present) {
      map['longitude'] = Variable<double>(longitude.value);
    }
    if (heightMeters.present) {
      map['height_meters'] = Variable<double>(heightMeters.value);
    }
    if (heightReference.present) {
      map['height_reference'] = Variable<String>(heightReference.value);
    }
    if (altitudeMode.present) {
      map['altitude_mode'] = Variable<String>(altitudeMode.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FlightWaypointsCompanion(')
          ..write('id: $id, ')
          ..write('planId: $planId, ')
          ..write('sequenceNumber: $sequenceNumber, ')
          ..write('latitude: $latitude, ')
          ..write('longitude: $longitude, ')
          ..write('heightMeters: $heightMeters, ')
          ..write('heightReference: $heightReference, ')
          ..write('altitudeMode: $altitudeMode')
          ..write(')'))
        .toString();
  }
}

class $AppSettingsTable extends AppSettings
    with TableInfo<$AppSettingsTable, AppSetting> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AppSettingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'app_settings';
  @override
  VerificationContext validateIntegrity(
    Insertable<AppSetting> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  AppSetting map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AppSetting(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $AppSettingsTable createAlias(String alias) {
    return $AppSettingsTable(attachedDatabase, alias);
  }
}

class AppSetting extends DataClass implements Insertable<AppSetting> {
  final String key;
  final String value;
  final DateTime updatedAt;
  const AppSetting({
    required this.key,
    required this.value,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  AppSettingsCompanion toCompanion(bool nullToAbsent) {
    return AppSettingsCompanion(
      key: Value(key),
      value: Value(value),
      updatedAt: Value(updatedAt),
    );
  }

  factory AppSetting.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AppSetting(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  AppSetting copyWith({String? key, String? value, DateTime? updatedAt}) =>
      AppSetting(
        key: key ?? this.key,
        value: value ?? this.value,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  AppSetting copyWithCompanion(AppSettingsCompanion data) {
    return AppSetting(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AppSetting(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AppSetting &&
          other.key == this.key &&
          other.value == this.value &&
          other.updatedAt == this.updatedAt);
}

class AppSettingsCompanion extends UpdateCompanion<AppSetting> {
  final Value<String> key;
  final Value<String> value;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const AppSettingsCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AppSettingsCompanion.insert({
    required String key,
    required String value,
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<AppSetting> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AppSettingsCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return AppSettingsCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AppSettingsCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$FpvDatabase extends GeneratedDatabase {
  _$FpvDatabase(QueryExecutor e) : super(e);
  $FpvDatabaseManager get managers => $FpvDatabaseManager(this);
  late final $SpotsTable spots = $SpotsTable(this);
  late final $SpotTagsTable spotTags = $SpotTagsTable(this);
  late final $SpotPhotosTable spotPhotos = $SpotPhotosTable(this);
  late final $DronesTable drones = $DronesTable(this);
  late final $DroneParameterSourcesTable droneParameterSources =
      $DroneParameterSourcesTable(this);
  late final $BatteriesTable batteries = $BatteriesTable(this);
  late final $BatteryDronesTable batteryDrones = $BatteryDronesTable(this);
  late final $FlightPlansTable flightPlans = $FlightPlansTable(this);
  late final $BatteryFlightPlansTable batteryFlightPlans =
      $BatteryFlightPlansTable(this);
  late final $RadioEquipmentTable radioEquipment = $RadioEquipmentTable(this);
  late final $FlightWaypointsTable flightWaypoints = $FlightWaypointsTable(
    this,
  );
  late final $AppSettingsTable appSettings = $AppSettingsTable(this);
  late final Index spotsCategoryId = Index(
    'spots_category_id',
    'CREATE INDEX spots_category_id ON spots (category_key, id)',
  );
  late final Index spotsFavoriteId = Index(
    'spots_favorite_id',
    'CREATE INDEX spots_favorite_id ON spots (is_favorite, id)',
  );
  late final Index spotTagsTagSpot = Index(
    'spot_tags_tag_spot',
    'CREATE INDEX spot_tags_tag_spot ON spot_tags (tag, spot_id)',
  );
  late final Index spotPhotosSpotId = Index(
    'spot_photos_spot_id',
    'CREATE INDEX spot_photos_spot_id ON spot_photos (spot_id)',
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    spots,
    spotTags,
    spotPhotos,
    drones,
    droneParameterSources,
    batteries,
    batteryDrones,
    flightPlans,
    batteryFlightPlans,
    radioEquipment,
    flightWaypoints,
    appSettings,
    spotsCategoryId,
    spotsFavoriteId,
    spotTagsTagSpot,
    spotPhotosSpotId,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'spots',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('spot_tags', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'spots',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('spot_photos', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'drones',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('drone_parameter_sources', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'batteries',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('batteries', kind: UpdateKind.update)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'batteries',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('battery_drones', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'drones',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('battery_drones', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'drones',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('flight_plans', kind: UpdateKind.update)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'spots',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('flight_plans', kind: UpdateKind.update)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'batteries',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('battery_flight_plans', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'flight_plans',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('battery_flight_plans', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'flight_plans',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('flight_waypoints', kind: UpdateKind.delete)],
    ),
  ]);
}

typedef $$SpotsTableCreateCompanionBuilder = SpotsCompanion Function({
  Value<int> id,
  required String name,
  required double latitude,
  required double longitude,
  Value<String?> notes,
  Value<String?> category,
  Value<String> categoryKey,
  Value<String> searchText,
  Value<bool> isFavorite,
  Value<DateTime> createdAt,
});
typedef $$SpotsTableUpdateCompanionBuilder = SpotsCompanion Function({
  Value<int> id,
  Value<String> name,
  Value<double> latitude,
  Value<double> longitude,
  Value<String?> notes,
  Value<String?> category,
  Value<String> categoryKey,
  Value<String> searchText,
  Value<bool> isFavorite,
  Value<DateTime> createdAt,
});

final class $$SpotsTableReferences
    extends BaseReferences<_$FpvDatabase, $SpotsTable, Spot> {
  $$SpotsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$SpotTagsTable, List<SpotTag>> _spotTagsRefsTable(
    _$FpvDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.spotTags,
    aliasName: 'spots__id__spot_tags__spot_id',
  );

  $$SpotTagsTableProcessedTableManager get spotTagsRefs {
    final manager = $$SpotTagsTableTableManager(
      $_db,
      $_db.spotTags,
    ).filter((f) => f.spotId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_spotTagsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$SpotPhotosTable, List<SpotPhoto>>
  _spotPhotosRefsTable(_$FpvDatabase db) => MultiTypedResultKey.fromTable(
    db.spotPhotos,
    aliasName: 'spots__id__spot_photos__spot_id',
  );

  $$SpotPhotosTableProcessedTableManager get spotPhotosRefs {
    final manager = $$SpotPhotosTableTableManager(
      $_db,
      $_db.spotPhotos,
    ).filter((f) => f.spotId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_spotPhotosRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$FlightPlansTable, List<FlightPlan>>
  _flightPlansRefsTable(_$FpvDatabase db) => MultiTypedResultKey.fromTable(
    db.flightPlans,
    aliasName: 'spots__id__flight_plans__start_spot_id',
  );

  $$FlightPlansTableProcessedTableManager get flightPlansRefs {
    final manager = $$FlightPlansTableTableManager(
      $_db,
      $_db.flightPlans,
    ).filter((f) => f.startSpotId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_flightPlansRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$SpotsTableFilterComposer extends Composer<_$FpvDatabase, $SpotsTable> {
  $$SpotsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get latitude => $composableBuilder(
    column: $table.latitude,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get longitude => $composableBuilder(
    column: $table.longitude,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get categoryKey => $composableBuilder(
    column: $table.categoryKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get searchText => $composableBuilder(
    column: $table.searchText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isFavorite => $composableBuilder(
    column: $table.isFavorite,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> spotTagsRefs(
    Expression<bool> Function($$SpotTagsTableFilterComposer f) f,
  ) {
    final $$SpotTagsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.spotTags,
      getReferencedColumn: (t) => t.spotId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SpotTagsTableFilterComposer(
            $db: $db,
            $table: $db.spotTags,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> spotPhotosRefs(
    Expression<bool> Function($$SpotPhotosTableFilterComposer f) f,
  ) {
    final $$SpotPhotosTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.spotPhotos,
      getReferencedColumn: (t) => t.spotId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SpotPhotosTableFilterComposer(
            $db: $db,
            $table: $db.spotPhotos,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> flightPlansRefs(
    Expression<bool> Function($$FlightPlansTableFilterComposer f) f,
  ) {
    final $$FlightPlansTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.flightPlans,
      getReferencedColumn: (t) => t.startSpotId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FlightPlansTableFilterComposer(
            $db: $db,
            $table: $db.flightPlans,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$SpotsTableOrderingComposer
    extends Composer<_$FpvDatabase, $SpotsTable> {
  $$SpotsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get latitude => $composableBuilder(
    column: $table.latitude,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get longitude => $composableBuilder(
    column: $table.longitude,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get categoryKey => $composableBuilder(
    column: $table.categoryKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get searchText => $composableBuilder(
    column: $table.searchText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isFavorite => $composableBuilder(
    column: $table.isFavorite,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SpotsTableAnnotationComposer
    extends Composer<_$FpvDatabase, $SpotsTable> {
  $$SpotsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<double> get latitude =>
      $composableBuilder(column: $table.latitude, builder: (column) => column);

  GeneratedColumn<double> get longitude =>
      $composableBuilder(column: $table.longitude, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<String> get category =>
      $composableBuilder(column: $table.category, builder: (column) => column);

  GeneratedColumn<String> get categoryKey => $composableBuilder(
    column: $table.categoryKey,
    builder: (column) => column,
  );

  GeneratedColumn<String> get searchText => $composableBuilder(
    column: $table.searchText,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isFavorite => $composableBuilder(
    column: $table.isFavorite,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  Expression<T> spotTagsRefs<T extends Object>(
    Expression<T> Function($$SpotTagsTableAnnotationComposer a) f,
  ) {
    final $$SpotTagsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.spotTags,
      getReferencedColumn: (t) => t.spotId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SpotTagsTableAnnotationComposer(
            $db: $db,
            $table: $db.spotTags,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> spotPhotosRefs<T extends Object>(
    Expression<T> Function($$SpotPhotosTableAnnotationComposer a) f,
  ) {
    final $$SpotPhotosTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.spotPhotos,
      getReferencedColumn: (t) => t.spotId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SpotPhotosTableAnnotationComposer(
            $db: $db,
            $table: $db.spotPhotos,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> flightPlansRefs<T extends Object>(
    Expression<T> Function($$FlightPlansTableAnnotationComposer a) f,
  ) {
    final $$FlightPlansTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.flightPlans,
      getReferencedColumn: (t) => t.startSpotId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FlightPlansTableAnnotationComposer(
            $db: $db,
            $table: $db.flightPlans,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$SpotsTableTableManager
    extends
        RootTableManager<
          _$FpvDatabase,
          $SpotsTable,
          Spot,
          $$SpotsTableFilterComposer,
          $$SpotsTableOrderingComposer,
          $$SpotsTableAnnotationComposer,
          $$SpotsTableCreateCompanionBuilder,
          $$SpotsTableUpdateCompanionBuilder,
          (Spot, $$SpotsTableReferences),
          Spot,
          PrefetchHooks Function({
            bool spotTagsRefs,
            bool spotPhotosRefs,
            bool flightPlansRefs,
          })
        > {
  $$SpotsTableTableManager(_$FpvDatabase db, $SpotsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SpotsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SpotsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SpotsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<double> latitude = const Value.absent(),
                Value<double> longitude = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<String?> category = const Value.absent(),
                Value<String> categoryKey = const Value.absent(),
                Value<String> searchText = const Value.absent(),
                Value<bool> isFavorite = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => SpotsCompanion(
                id: id,
                name: name,
                latitude: latitude,
                longitude: longitude,
                notes: notes,
                category: category,
                categoryKey: categoryKey,
                searchText: searchText,
                isFavorite: isFavorite,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                required double latitude,
                required double longitude,
                Value<String?> notes = const Value.absent(),
                Value<String?> category = const Value.absent(),
                Value<String> categoryKey = const Value.absent(),
                Value<String> searchText = const Value.absent(),
                Value<bool> isFavorite = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => SpotsCompanion.insert(
                id: id,
                name: name,
                latitude: latitude,
                longitude: longitude,
                notes: notes,
                category: category,
                categoryKey: categoryKey,
                searchText: searchText,
                isFavorite: isFavorite,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SpotsTable, Spot>(table),
                  $$SpotsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                spotTagsRefs = false,
                spotPhotosRefs = false,
                flightPlansRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (spotTagsRefs) db.spotTags,
                    if (spotPhotosRefs) db.spotPhotos,
                    if (flightPlansRefs) db.flightPlans,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (spotTagsRefs)
                        await $_getPrefetchedData<Spot, $SpotsTable, SpotTag>(
                          currentTable: table,
                          referencedTable: $$SpotsTableReferences
                              ._spotTagsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$SpotsTableReferences(
                                db,
                                table,
                                p0,
                              ).spotTagsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.spotId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (spotPhotosRefs)
                        await $_getPrefetchedData<Spot, $SpotsTable, SpotPhoto>(
                          currentTable: table,
                          referencedTable: $$SpotsTableReferences
                              ._spotPhotosRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$SpotsTableReferences(
                                db,
                                table,
                                p0,
                              ).spotPhotosRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.spotId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (flightPlansRefs)
                        await $_getPrefetchedData<
                          Spot,
                          $SpotsTable,
                          FlightPlan
                        >(
                          currentTable: table,
                          referencedTable: $$SpotsTableReferences
                              ._flightPlansRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$SpotsTableReferences(
                                db,
                                table,
                                p0,
                              ).flightPlansRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.startSpotId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$SpotsTableProcessedTableManager =
    ProcessedTableManager<
      _$FpvDatabase,
      $SpotsTable,
      Spot,
      $$SpotsTableFilterComposer,
      $$SpotsTableOrderingComposer,
      $$SpotsTableAnnotationComposer,
      $$SpotsTableCreateCompanionBuilder,
      $$SpotsTableUpdateCompanionBuilder,
      (Spot, $$SpotsTableReferences),
      Spot,
      PrefetchHooks Function({
        bool spotTagsRefs,
        bool spotPhotosRefs,
        bool flightPlansRefs,
      })
    >;
typedef $$SpotTagsTableCreateCompanionBuilder = SpotTagsCompanion Function({
  required int spotId,
  required String tag,
  Value<int> rowid,
});
typedef $$SpotTagsTableUpdateCompanionBuilder = SpotTagsCompanion Function({
  Value<int> spotId,
  Value<String> tag,
  Value<int> rowid,
});

final class $$SpotTagsTableReferences
    extends BaseReferences<_$FpvDatabase, $SpotTagsTable, SpotTag> {
  $$SpotTagsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $SpotsTable _spotIdTable(_$FpvDatabase db) =>
      db.spots.createAlias('spot_tags__spot_id__spots__id');

  $$SpotsTableProcessedTableManager get spotId {
    final $_column = $_itemColumn<int>('spot_id')!;

    final manager = $$SpotsTableTableManager(
      $_db,
      $_db.spots,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_spotIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$SpotTagsTableFilterComposer
    extends Composer<_$FpvDatabase, $SpotTagsTable> {
  $$SpotTagsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get tag => $composableBuilder(
    column: $table.tag,
    builder: (column) => ColumnFilters(column),
  );

  $$SpotsTableFilterComposer get spotId {
    final $$SpotsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.spotId,
      referencedTable: $db.spots,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SpotsTableFilterComposer(
            $db: $db,
            $table: $db.spots,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SpotTagsTableOrderingComposer
    extends Composer<_$FpvDatabase, $SpotTagsTable> {
  $$SpotTagsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get tag => $composableBuilder(
    column: $table.tag,
    builder: (column) => ColumnOrderings(column),
  );

  $$SpotsTableOrderingComposer get spotId {
    final $$SpotsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.spotId,
      referencedTable: $db.spots,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SpotsTableOrderingComposer(
            $db: $db,
            $table: $db.spots,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SpotTagsTableAnnotationComposer
    extends Composer<_$FpvDatabase, $SpotTagsTable> {
  $$SpotTagsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get tag =>
      $composableBuilder(column: $table.tag, builder: (column) => column);

  $$SpotsTableAnnotationComposer get spotId {
    final $$SpotsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.spotId,
      referencedTable: $db.spots,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SpotsTableAnnotationComposer(
            $db: $db,
            $table: $db.spots,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SpotTagsTableTableManager
    extends
        RootTableManager<
          _$FpvDatabase,
          $SpotTagsTable,
          SpotTag,
          $$SpotTagsTableFilterComposer,
          $$SpotTagsTableOrderingComposer,
          $$SpotTagsTableAnnotationComposer,
          $$SpotTagsTableCreateCompanionBuilder,
          $$SpotTagsTableUpdateCompanionBuilder,
          (SpotTag, $$SpotTagsTableReferences),
          SpotTag,
          PrefetchHooks Function({bool spotId})
        > {
  $$SpotTagsTableTableManager(_$FpvDatabase db, $SpotTagsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SpotTagsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SpotTagsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SpotTagsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> spotId = const Value.absent(),
            Value<String> tag = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) => SpotTagsCompanion(spotId: spotId, tag: tag, rowid: rowid),
          createCompanionCallback:
              ({
                required int spotId,
                required String tag,
                Value<int> rowid = const Value.absent(),
              }) => SpotTagsCompanion.insert(
                spotId: spotId,
                tag: tag,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SpotTagsTable, SpotTag>(table),
                  $$SpotTagsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({spotId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (spotId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.spotId,
                        referencedTable: $$SpotTagsTableReferences._spotIdTable(
                          db,
                        ),
                        referencedColumn: $$SpotTagsTableReferences
                            ._spotIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$SpotTagsTableProcessedTableManager =
    ProcessedTableManager<
      _$FpvDatabase,
      $SpotTagsTable,
      SpotTag,
      $$SpotTagsTableFilterComposer,
      $$SpotTagsTableOrderingComposer,
      $$SpotTagsTableAnnotationComposer,
      $$SpotTagsTableCreateCompanionBuilder,
      $$SpotTagsTableUpdateCompanionBuilder,
      (SpotTag, $$SpotTagsTableReferences),
      SpotTag,
      PrefetchHooks Function({bool spotId})
    >;
typedef $$SpotPhotosTableCreateCompanionBuilder = SpotPhotosCompanion Function({
  Value<int> id,
  required int spotId,
  required Uint8List imageBytes,
  required Uint8List thumbnailBytes,
  required int width,
  required int height,
});
typedef $$SpotPhotosTableUpdateCompanionBuilder = SpotPhotosCompanion Function({
  Value<int> id,
  Value<int> spotId,
  Value<Uint8List> imageBytes,
  Value<Uint8List> thumbnailBytes,
  Value<int> width,
  Value<int> height,
});

final class $$SpotPhotosTableReferences
    extends BaseReferences<_$FpvDatabase, $SpotPhotosTable, SpotPhoto> {
  $$SpotPhotosTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $SpotsTable _spotIdTable(_$FpvDatabase db) =>
      db.spots.createAlias('spot_photos__spot_id__spots__id');

  $$SpotsTableProcessedTableManager get spotId {
    final $_column = $_itemColumn<int>('spot_id')!;

    final manager = $$SpotsTableTableManager(
      $_db,
      $_db.spots,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_spotIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$SpotPhotosTableFilterComposer
    extends Composer<_$FpvDatabase, $SpotPhotosTable> {
  $$SpotPhotosTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<Uint8List> get imageBytes => $composableBuilder(
    column: $table.imageBytes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<Uint8List> get thumbnailBytes => $composableBuilder(
    column: $table.thumbnailBytes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get width => $composableBuilder(
    column: $table.width,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get height => $composableBuilder(
    column: $table.height,
    builder: (column) => ColumnFilters(column),
  );

  $$SpotsTableFilterComposer get spotId {
    final $$SpotsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.spotId,
      referencedTable: $db.spots,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SpotsTableFilterComposer(
            $db: $db,
            $table: $db.spots,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SpotPhotosTableOrderingComposer
    extends Composer<_$FpvDatabase, $SpotPhotosTable> {
  $$SpotPhotosTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<Uint8List> get imageBytes => $composableBuilder(
    column: $table.imageBytes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<Uint8List> get thumbnailBytes => $composableBuilder(
    column: $table.thumbnailBytes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get width => $composableBuilder(
    column: $table.width,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get height => $composableBuilder(
    column: $table.height,
    builder: (column) => ColumnOrderings(column),
  );

  $$SpotsTableOrderingComposer get spotId {
    final $$SpotsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.spotId,
      referencedTable: $db.spots,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SpotsTableOrderingComposer(
            $db: $db,
            $table: $db.spots,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SpotPhotosTableAnnotationComposer
    extends Composer<_$FpvDatabase, $SpotPhotosTable> {
  $$SpotPhotosTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<Uint8List> get imageBytes => $composableBuilder(
    column: $table.imageBytes,
    builder: (column) => column,
  );

  GeneratedColumn<Uint8List> get thumbnailBytes => $composableBuilder(
    column: $table.thumbnailBytes,
    builder: (column) => column,
  );

  GeneratedColumn<int> get width =>
      $composableBuilder(column: $table.width, builder: (column) => column);

  GeneratedColumn<int> get height =>
      $composableBuilder(column: $table.height, builder: (column) => column);

  $$SpotsTableAnnotationComposer get spotId {
    final $$SpotsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.spotId,
      referencedTable: $db.spots,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SpotsTableAnnotationComposer(
            $db: $db,
            $table: $db.spots,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SpotPhotosTableTableManager
    extends
        RootTableManager<
          _$FpvDatabase,
          $SpotPhotosTable,
          SpotPhoto,
          $$SpotPhotosTableFilterComposer,
          $$SpotPhotosTableOrderingComposer,
          $$SpotPhotosTableAnnotationComposer,
          $$SpotPhotosTableCreateCompanionBuilder,
          $$SpotPhotosTableUpdateCompanionBuilder,
          (SpotPhoto, $$SpotPhotosTableReferences),
          SpotPhoto,
          PrefetchHooks Function({bool spotId})
        > {
  $$SpotPhotosTableTableManager(_$FpvDatabase db, $SpotPhotosTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SpotPhotosTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SpotPhotosTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SpotPhotosTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> spotId = const Value.absent(),
                Value<Uint8List> imageBytes = const Value.absent(),
                Value<Uint8List> thumbnailBytes = const Value.absent(),
                Value<int> width = const Value.absent(),
                Value<int> height = const Value.absent(),
              }) => SpotPhotosCompanion(
                id: id,
                spotId: spotId,
                imageBytes: imageBytes,
                thumbnailBytes: thumbnailBytes,
                width: width,
                height: height,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int spotId,
                required Uint8List imageBytes,
                required Uint8List thumbnailBytes,
                required int width,
                required int height,
              }) => SpotPhotosCompanion.insert(
                id: id,
                spotId: spotId,
                imageBytes: imageBytes,
                thumbnailBytes: thumbnailBytes,
                width: width,
                height: height,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SpotPhotosTable, SpotPhoto>(table),
                  $$SpotPhotosTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({spotId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (spotId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.spotId,
                        referencedTable: $$SpotPhotosTableReferences
                            ._spotIdTable(db),
                        referencedColumn: $$SpotPhotosTableReferences
                            ._spotIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$SpotPhotosTableProcessedTableManager =
    ProcessedTableManager<
      _$FpvDatabase,
      $SpotPhotosTable,
      SpotPhoto,
      $$SpotPhotosTableFilterComposer,
      $$SpotPhotosTableOrderingComposer,
      $$SpotPhotosTableAnnotationComposer,
      $$SpotPhotosTableCreateCompanionBuilder,
      $$SpotPhotosTableUpdateCompanionBuilder,
      (SpotPhoto, $$SpotPhotosTableReferences),
      SpotPhoto,
      PrefetchHooks Function({bool spotId})
    >;
typedef $$DronesTableCreateCompanionBuilder = DronesCompanion Function({
  Value<int> id,
  required String name,
  Value<String> type,
  Value<double?> takeoffWeightGrams,
  Value<double?> maxSpeedMetersPerSecond,
  Value<double?> lengthMm,
  Value<double?> widthMm,
  Value<double?> heightMm,
  Value<double?> propellerDiameterInches,
  Value<double?> propellerPitchInches,
  Value<int?> propellerCount,
  Value<int?> motorCount,
  Value<double?> motorKv,
  Value<double?> cruiseSpeedMetersPerSecond,
  Value<double?> maxClimbRateMetersPerSecond,
  Value<double?> hoverPowerWatts,
  Value<double?> cruisePowerWatts,
  Value<double?> maxPowerWatts,
  Value<double?> referenceVoltageVolts,
  Value<String?> configuration,
  Value<String?> propellerDescription,
  Value<String?> motorDescription,
  Value<String?> escDescription,
  Value<String?> measurementContext,
  Value<String?> notes,
  Value<DateTime> createdAt,
});
typedef $$DronesTableUpdateCompanionBuilder = DronesCompanion Function({
  Value<int> id,
  Value<String> name,
  Value<String> type,
  Value<double?> takeoffWeightGrams,
  Value<double?> maxSpeedMetersPerSecond,
  Value<double?> lengthMm,
  Value<double?> widthMm,
  Value<double?> heightMm,
  Value<double?> propellerDiameterInches,
  Value<double?> propellerPitchInches,
  Value<int?> propellerCount,
  Value<int?> motorCount,
  Value<double?> motorKv,
  Value<double?> cruiseSpeedMetersPerSecond,
  Value<double?> maxClimbRateMetersPerSecond,
  Value<double?> hoverPowerWatts,
  Value<double?> cruisePowerWatts,
  Value<double?> maxPowerWatts,
  Value<double?> referenceVoltageVolts,
  Value<String?> configuration,
  Value<String?> propellerDescription,
  Value<String?> motorDescription,
  Value<String?> escDescription,
  Value<String?> measurementContext,
  Value<String?> notes,
  Value<DateTime> createdAt,
});

final class $$DronesTableReferences
    extends BaseReferences<_$FpvDatabase, $DronesTable, Drone> {
  $$DronesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<
    $DroneParameterSourcesTable,
    List<DroneParameterSource>
  >
  _droneParameterSourcesRefsTable(_$FpvDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.droneParameterSources,
        aliasName: 'drones__id__drone_parameter_sources__drone_id',
      );

  $$DroneParameterSourcesTableProcessedTableManager
  get droneParameterSourcesRefs {
    final manager = $$DroneParameterSourcesTableTableManager(
      $_db,
      $_db.droneParameterSources,
    ).filter((f) => f.droneId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _droneParameterSourcesRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$BatteryDronesTable, List<BatteryDrone>>
  _batteryDronesRefsTable(_$FpvDatabase db) => MultiTypedResultKey.fromTable(
    db.batteryDrones,
    aliasName: 'drones__id__battery_drones__drone_id',
  );

  $$BatteryDronesTableProcessedTableManager get batteryDronesRefs {
    final manager = $$BatteryDronesTableTableManager(
      $_db,
      $_db.batteryDrones,
    ).filter((f) => f.droneId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_batteryDronesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$FlightPlansTable, List<FlightPlan>>
  _flightPlansRefsTable(_$FpvDatabase db) => MultiTypedResultKey.fromTable(
    db.flightPlans,
    aliasName: 'drones__id__flight_plans__drone_id',
  );

  $$FlightPlansTableProcessedTableManager get flightPlansRefs {
    final manager = $$FlightPlansTableTableManager(
      $_db,
      $_db.flightPlans,
    ).filter((f) => f.droneId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_flightPlansRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$DronesTableFilterComposer
    extends Composer<_$FpvDatabase, $DronesTable> {
  $$DronesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get takeoffWeightGrams => $composableBuilder(
    column: $table.takeoffWeightGrams,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get maxSpeedMetersPerSecond => $composableBuilder(
    column: $table.maxSpeedMetersPerSecond,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get lengthMm => $composableBuilder(
    column: $table.lengthMm,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get widthMm => $composableBuilder(
    column: $table.widthMm,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get heightMm => $composableBuilder(
    column: $table.heightMm,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get propellerDiameterInches => $composableBuilder(
    column: $table.propellerDiameterInches,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get propellerPitchInches => $composableBuilder(
    column: $table.propellerPitchInches,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get propellerCount => $composableBuilder(
    column: $table.propellerCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get motorCount => $composableBuilder(
    column: $table.motorCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get motorKv => $composableBuilder(
    column: $table.motorKv,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get cruiseSpeedMetersPerSecond => $composableBuilder(
    column: $table.cruiseSpeedMetersPerSecond,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get maxClimbRateMetersPerSecond => $composableBuilder(
    column: $table.maxClimbRateMetersPerSecond,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get hoverPowerWatts => $composableBuilder(
    column: $table.hoverPowerWatts,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get cruisePowerWatts => $composableBuilder(
    column: $table.cruisePowerWatts,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get maxPowerWatts => $composableBuilder(
    column: $table.maxPowerWatts,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get referenceVoltageVolts => $composableBuilder(
    column: $table.referenceVoltageVolts,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get configuration => $composableBuilder(
    column: $table.configuration,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get propellerDescription => $composableBuilder(
    column: $table.propellerDescription,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get motorDescription => $composableBuilder(
    column: $table.motorDescription,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get escDescription => $composableBuilder(
    column: $table.escDescription,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get measurementContext => $composableBuilder(
    column: $table.measurementContext,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> droneParameterSourcesRefs(
    Expression<bool> Function($$DroneParameterSourcesTableFilterComposer f) f,
  ) {
    final $$DroneParameterSourcesTableFilterComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.droneParameterSources,
          getReferencedColumn: (t) => t.droneId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$DroneParameterSourcesTableFilterComposer(
                $db: $db,
                $table: $db.droneParameterSources,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<bool> batteryDronesRefs(
    Expression<bool> Function($$BatteryDronesTableFilterComposer f) f,
  ) {
    final $$BatteryDronesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.batteryDrones,
      getReferencedColumn: (t) => t.droneId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BatteryDronesTableFilterComposer(
            $db: $db,
            $table: $db.batteryDrones,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> flightPlansRefs(
    Expression<bool> Function($$FlightPlansTableFilterComposer f) f,
  ) {
    final $$FlightPlansTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.flightPlans,
      getReferencedColumn: (t) => t.droneId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FlightPlansTableFilterComposer(
            $db: $db,
            $table: $db.flightPlans,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$DronesTableOrderingComposer
    extends Composer<_$FpvDatabase, $DronesTable> {
  $$DronesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get takeoffWeightGrams => $composableBuilder(
    column: $table.takeoffWeightGrams,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get maxSpeedMetersPerSecond => $composableBuilder(
    column: $table.maxSpeedMetersPerSecond,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get lengthMm => $composableBuilder(
    column: $table.lengthMm,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get widthMm => $composableBuilder(
    column: $table.widthMm,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get heightMm => $composableBuilder(
    column: $table.heightMm,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get propellerDiameterInches => $composableBuilder(
    column: $table.propellerDiameterInches,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get propellerPitchInches => $composableBuilder(
    column: $table.propellerPitchInches,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get propellerCount => $composableBuilder(
    column: $table.propellerCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get motorCount => $composableBuilder(
    column: $table.motorCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get motorKv => $composableBuilder(
    column: $table.motorKv,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get cruiseSpeedMetersPerSecond => $composableBuilder(
    column: $table.cruiseSpeedMetersPerSecond,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get maxClimbRateMetersPerSecond => $composableBuilder(
    column: $table.maxClimbRateMetersPerSecond,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get hoverPowerWatts => $composableBuilder(
    column: $table.hoverPowerWatts,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get cruisePowerWatts => $composableBuilder(
    column: $table.cruisePowerWatts,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get maxPowerWatts => $composableBuilder(
    column: $table.maxPowerWatts,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get referenceVoltageVolts => $composableBuilder(
    column: $table.referenceVoltageVolts,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get configuration => $composableBuilder(
    column: $table.configuration,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get propellerDescription => $composableBuilder(
    column: $table.propellerDescription,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get motorDescription => $composableBuilder(
    column: $table.motorDescription,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get escDescription => $composableBuilder(
    column: $table.escDescription,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get measurementContext => $composableBuilder(
    column: $table.measurementContext,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DronesTableAnnotationComposer
    extends Composer<_$FpvDatabase, $DronesTable> {
  $$DronesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<double> get takeoffWeightGrams => $composableBuilder(
    column: $table.takeoffWeightGrams,
    builder: (column) => column,
  );

  GeneratedColumn<double> get maxSpeedMetersPerSecond => $composableBuilder(
    column: $table.maxSpeedMetersPerSecond,
    builder: (column) => column,
  );

  GeneratedColumn<double> get lengthMm =>
      $composableBuilder(column: $table.lengthMm, builder: (column) => column);

  GeneratedColumn<double> get widthMm =>
      $composableBuilder(column: $table.widthMm, builder: (column) => column);

  GeneratedColumn<double> get heightMm =>
      $composableBuilder(column: $table.heightMm, builder: (column) => column);

  GeneratedColumn<double> get propellerDiameterInches => $composableBuilder(
    column: $table.propellerDiameterInches,
    builder: (column) => column,
  );

  GeneratedColumn<double> get propellerPitchInches => $composableBuilder(
    column: $table.propellerPitchInches,
    builder: (column) => column,
  );

  GeneratedColumn<int> get propellerCount => $composableBuilder(
    column: $table.propellerCount,
    builder: (column) => column,
  );

  GeneratedColumn<int> get motorCount => $composableBuilder(
    column: $table.motorCount,
    builder: (column) => column,
  );

  GeneratedColumn<double> get motorKv =>
      $composableBuilder(column: $table.motorKv, builder: (column) => column);

  GeneratedColumn<double> get cruiseSpeedMetersPerSecond => $composableBuilder(
    column: $table.cruiseSpeedMetersPerSecond,
    builder: (column) => column,
  );

  GeneratedColumn<double> get maxClimbRateMetersPerSecond => $composableBuilder(
    column: $table.maxClimbRateMetersPerSecond,
    builder: (column) => column,
  );

  GeneratedColumn<double> get hoverPowerWatts => $composableBuilder(
    column: $table.hoverPowerWatts,
    builder: (column) => column,
  );

  GeneratedColumn<double> get cruisePowerWatts => $composableBuilder(
    column: $table.cruisePowerWatts,
    builder: (column) => column,
  );

  GeneratedColumn<double> get maxPowerWatts => $composableBuilder(
    column: $table.maxPowerWatts,
    builder: (column) => column,
  );

  GeneratedColumn<double> get referenceVoltageVolts => $composableBuilder(
    column: $table.referenceVoltageVolts,
    builder: (column) => column,
  );

  GeneratedColumn<String> get configuration => $composableBuilder(
    column: $table.configuration,
    builder: (column) => column,
  );

  GeneratedColumn<String> get propellerDescription => $composableBuilder(
    column: $table.propellerDescription,
    builder: (column) => column,
  );

  GeneratedColumn<String> get motorDescription => $composableBuilder(
    column: $table.motorDescription,
    builder: (column) => column,
  );

  GeneratedColumn<String> get escDescription => $composableBuilder(
    column: $table.escDescription,
    builder: (column) => column,
  );

  GeneratedColumn<String> get measurementContext => $composableBuilder(
    column: $table.measurementContext,
    builder: (column) => column,
  );

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  Expression<T> droneParameterSourcesRefs<T extends Object>(
    Expression<T> Function($$DroneParameterSourcesTableAnnotationComposer a) f,
  ) {
    final $$DroneParameterSourcesTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.droneParameterSources,
          getReferencedColumn: (t) => t.droneId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$DroneParameterSourcesTableAnnotationComposer(
                $db: $db,
                $table: $db.droneParameterSources,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<T> batteryDronesRefs<T extends Object>(
    Expression<T> Function($$BatteryDronesTableAnnotationComposer a) f,
  ) {
    final $$BatteryDronesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.batteryDrones,
      getReferencedColumn: (t) => t.droneId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BatteryDronesTableAnnotationComposer(
            $db: $db,
            $table: $db.batteryDrones,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> flightPlansRefs<T extends Object>(
    Expression<T> Function($$FlightPlansTableAnnotationComposer a) f,
  ) {
    final $$FlightPlansTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.flightPlans,
      getReferencedColumn: (t) => t.droneId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FlightPlansTableAnnotationComposer(
            $db: $db,
            $table: $db.flightPlans,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$DronesTableTableManager
    extends
        RootTableManager<
          _$FpvDatabase,
          $DronesTable,
          Drone,
          $$DronesTableFilterComposer,
          $$DronesTableOrderingComposer,
          $$DronesTableAnnotationComposer,
          $$DronesTableCreateCompanionBuilder,
          $$DronesTableUpdateCompanionBuilder,
          (Drone, $$DronesTableReferences),
          Drone,
          PrefetchHooks Function({
            bool droneParameterSourcesRefs,
            bool batteryDronesRefs,
            bool flightPlansRefs,
          })
        > {
  $$DronesTableTableManager(_$FpvDatabase db, $DronesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DronesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DronesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DronesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<double?> takeoffWeightGrams = const Value.absent(),
                Value<double?> maxSpeedMetersPerSecond = const Value.absent(),
                Value<double?> lengthMm = const Value.absent(),
                Value<double?> widthMm = const Value.absent(),
                Value<double?> heightMm = const Value.absent(),
                Value<double?> propellerDiameterInches = const Value.absent(),
                Value<double?> propellerPitchInches = const Value.absent(),
                Value<int?> propellerCount = const Value.absent(),
                Value<int?> motorCount = const Value.absent(),
                Value<double?> motorKv = const Value.absent(),
                Value<double?> cruiseSpeedMetersPerSecond =
                    const Value.absent(),
                Value<double?> maxClimbRateMetersPerSecond =
                    const Value.absent(),
                Value<double?> hoverPowerWatts = const Value.absent(),
                Value<double?> cruisePowerWatts = const Value.absent(),
                Value<double?> maxPowerWatts = const Value.absent(),
                Value<double?> referenceVoltageVolts = const Value.absent(),
                Value<String?> configuration = const Value.absent(),
                Value<String?> propellerDescription = const Value.absent(),
                Value<String?> motorDescription = const Value.absent(),
                Value<String?> escDescription = const Value.absent(),
                Value<String?> measurementContext = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => DronesCompanion(
                id: id,
                name: name,
                type: type,
                takeoffWeightGrams: takeoffWeightGrams,
                maxSpeedMetersPerSecond: maxSpeedMetersPerSecond,
                lengthMm: lengthMm,
                widthMm: widthMm,
                heightMm: heightMm,
                propellerDiameterInches: propellerDiameterInches,
                propellerPitchInches: propellerPitchInches,
                propellerCount: propellerCount,
                motorCount: motorCount,
                motorKv: motorKv,
                cruiseSpeedMetersPerSecond: cruiseSpeedMetersPerSecond,
                maxClimbRateMetersPerSecond: maxClimbRateMetersPerSecond,
                hoverPowerWatts: hoverPowerWatts,
                cruisePowerWatts: cruisePowerWatts,
                maxPowerWatts: maxPowerWatts,
                referenceVoltageVolts: referenceVoltageVolts,
                configuration: configuration,
                propellerDescription: propellerDescription,
                motorDescription: motorDescription,
                escDescription: escDescription,
                measurementContext: measurementContext,
                notes: notes,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                Value<String> type = const Value.absent(),
                Value<double?> takeoffWeightGrams = const Value.absent(),
                Value<double?> maxSpeedMetersPerSecond = const Value.absent(),
                Value<double?> lengthMm = const Value.absent(),
                Value<double?> widthMm = const Value.absent(),
                Value<double?> heightMm = const Value.absent(),
                Value<double?> propellerDiameterInches = const Value.absent(),
                Value<double?> propellerPitchInches = const Value.absent(),
                Value<int?> propellerCount = const Value.absent(),
                Value<int?> motorCount = const Value.absent(),
                Value<double?> motorKv = const Value.absent(),
                Value<double?> cruiseSpeedMetersPerSecond =
                    const Value.absent(),
                Value<double?> maxClimbRateMetersPerSecond =
                    const Value.absent(),
                Value<double?> hoverPowerWatts = const Value.absent(),
                Value<double?> cruisePowerWatts = const Value.absent(),
                Value<double?> maxPowerWatts = const Value.absent(),
                Value<double?> referenceVoltageVolts = const Value.absent(),
                Value<String?> configuration = const Value.absent(),
                Value<String?> propellerDescription = const Value.absent(),
                Value<String?> motorDescription = const Value.absent(),
                Value<String?> escDescription = const Value.absent(),
                Value<String?> measurementContext = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => DronesCompanion.insert(
                id: id,
                name: name,
                type: type,
                takeoffWeightGrams: takeoffWeightGrams,
                maxSpeedMetersPerSecond: maxSpeedMetersPerSecond,
                lengthMm: lengthMm,
                widthMm: widthMm,
                heightMm: heightMm,
                propellerDiameterInches: propellerDiameterInches,
                propellerPitchInches: propellerPitchInches,
                propellerCount: propellerCount,
                motorCount: motorCount,
                motorKv: motorKv,
                cruiseSpeedMetersPerSecond: cruiseSpeedMetersPerSecond,
                maxClimbRateMetersPerSecond: maxClimbRateMetersPerSecond,
                hoverPowerWatts: hoverPowerWatts,
                cruisePowerWatts: cruisePowerWatts,
                maxPowerWatts: maxPowerWatts,
                referenceVoltageVolts: referenceVoltageVolts,
                configuration: configuration,
                propellerDescription: propellerDescription,
                motorDescription: motorDescription,
                escDescription: escDescription,
                measurementContext: measurementContext,
                notes: notes,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$DronesTable, Drone>(table),
                  $$DronesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                droneParameterSourcesRefs = false,
                batteryDronesRefs = false,
                flightPlansRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (droneParameterSourcesRefs) db.droneParameterSources,
                    if (batteryDronesRefs) db.batteryDrones,
                    if (flightPlansRefs) db.flightPlans,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (droneParameterSourcesRefs)
                        await $_getPrefetchedData<
                          Drone,
                          $DronesTable,
                          DroneParameterSource
                        >(
                          currentTable: table,
                          referencedTable: $$DronesTableReferences
                              ._droneParameterSourcesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$DronesTableReferences(
                                db,
                                table,
                                p0,
                              ).droneParameterSourcesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.droneId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (batteryDronesRefs)
                        await $_getPrefetchedData<
                          Drone,
                          $DronesTable,
                          BatteryDrone
                        >(
                          currentTable: table,
                          referencedTable: $$DronesTableReferences
                              ._batteryDronesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$DronesTableReferences(
                                db,
                                table,
                                p0,
                              ).batteryDronesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.droneId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (flightPlansRefs)
                        await $_getPrefetchedData<
                          Drone,
                          $DronesTable,
                          FlightPlan
                        >(
                          currentTable: table,
                          referencedTable: $$DronesTableReferences
                              ._flightPlansRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$DronesTableReferences(
                                db,
                                table,
                                p0,
                              ).flightPlansRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.droneId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$DronesTableProcessedTableManager =
    ProcessedTableManager<
      _$FpvDatabase,
      $DronesTable,
      Drone,
      $$DronesTableFilterComposer,
      $$DronesTableOrderingComposer,
      $$DronesTableAnnotationComposer,
      $$DronesTableCreateCompanionBuilder,
      $$DronesTableUpdateCompanionBuilder,
      (Drone, $$DronesTableReferences),
      Drone,
      PrefetchHooks Function({
        bool droneParameterSourcesRefs,
        bool batteryDronesRefs,
        bool flightPlansRefs,
      })
    >;
typedef $$DroneParameterSourcesTableCreateCompanionBuilder =
    DroneParameterSourcesCompanion Function({
      required int droneId,
      required String parameterKey,
      required String source,
      Value<int> rowid,
    });
typedef $$DroneParameterSourcesTableUpdateCompanionBuilder =
    DroneParameterSourcesCompanion Function({
      Value<int> droneId,
      Value<String> parameterKey,
      Value<String> source,
      Value<int> rowid,
    });

final class $$DroneParameterSourcesTableReferences
    extends
        BaseReferences<
          _$FpvDatabase,
          $DroneParameterSourcesTable,
          DroneParameterSource
        > {
  $$DroneParameterSourcesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $DronesTable _droneIdTable(_$FpvDatabase db) =>
      db.drones.createAlias('drone_parameter_sources__drone_id__drones__id');

  $$DronesTableProcessedTableManager get droneId {
    final $_column = $_itemColumn<int>('drone_id')!;

    final manager = $$DronesTableTableManager(
      $_db,
      $_db.drones,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_droneIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$DroneParameterSourcesTableFilterComposer
    extends Composer<_$FpvDatabase, $DroneParameterSourcesTable> {
  $$DroneParameterSourcesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get parameterKey => $composableBuilder(
    column: $table.parameterKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnFilters(column),
  );

  $$DronesTableFilterComposer get droneId {
    final $$DronesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.droneId,
      referencedTable: $db.drones,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DronesTableFilterComposer(
            $db: $db,
            $table: $db.drones,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DroneParameterSourcesTableOrderingComposer
    extends Composer<_$FpvDatabase, $DroneParameterSourcesTable> {
  $$DroneParameterSourcesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get parameterKey => $composableBuilder(
    column: $table.parameterKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );

  $$DronesTableOrderingComposer get droneId {
    final $$DronesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.droneId,
      referencedTable: $db.drones,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DronesTableOrderingComposer(
            $db: $db,
            $table: $db.drones,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DroneParameterSourcesTableAnnotationComposer
    extends Composer<_$FpvDatabase, $DroneParameterSourcesTable> {
  $$DroneParameterSourcesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get parameterKey => $composableBuilder(
    column: $table.parameterKey,
    builder: (column) => column,
  );

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  $$DronesTableAnnotationComposer get droneId {
    final $$DronesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.droneId,
      referencedTable: $db.drones,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DronesTableAnnotationComposer(
            $db: $db,
            $table: $db.drones,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DroneParameterSourcesTableTableManager
    extends
        RootTableManager<
          _$FpvDatabase,
          $DroneParameterSourcesTable,
          DroneParameterSource,
          $$DroneParameterSourcesTableFilterComposer,
          $$DroneParameterSourcesTableOrderingComposer,
          $$DroneParameterSourcesTableAnnotationComposer,
          $$DroneParameterSourcesTableCreateCompanionBuilder,
          $$DroneParameterSourcesTableUpdateCompanionBuilder,
          (DroneParameterSource, $$DroneParameterSourcesTableReferences),
          DroneParameterSource,
          PrefetchHooks Function({bool droneId})
        > {
  $$DroneParameterSourcesTableTableManager(
    _$FpvDatabase db,
    $DroneParameterSourcesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DroneParameterSourcesTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$DroneParameterSourcesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$DroneParameterSourcesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> droneId = const Value.absent(),
                Value<String> parameterKey = const Value.absent(),
                Value<String> source = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DroneParameterSourcesCompanion(
                droneId: droneId,
                parameterKey: parameterKey,
                source: source,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required int droneId,
                required String parameterKey,
                required String source,
                Value<int> rowid = const Value.absent(),
              }) => DroneParameterSourcesCompanion.insert(
                droneId: droneId,
                parameterKey: parameterKey,
                source: source,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<
                    $DroneParameterSourcesTable,
                    DroneParameterSource
                  >(table),
                  $$DroneParameterSourcesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({droneId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (droneId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.droneId,
                        referencedTable: $$DroneParameterSourcesTableReferences
                            ._droneIdTable(db),
                        referencedColumn: $$DroneParameterSourcesTableReferences
                            ._droneIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$DroneParameterSourcesTableProcessedTableManager =
    ProcessedTableManager<
      _$FpvDatabase,
      $DroneParameterSourcesTable,
      DroneParameterSource,
      $$DroneParameterSourcesTableFilterComposer,
      $$DroneParameterSourcesTableOrderingComposer,
      $$DroneParameterSourcesTableAnnotationComposer,
      $$DroneParameterSourcesTableCreateCompanionBuilder,
      $$DroneParameterSourcesTableUpdateCompanionBuilder,
      (DroneParameterSource, $$DroneParameterSourcesTableReferences),
      DroneParameterSource,
      PrefetchHooks Function({bool droneId})
    >;
typedef $$BatteriesTableCreateCompanionBuilder = BatteriesCompanion Function({
  Value<int> id,
  required String name,
  Value<String> chemistry,
  required int cellCount,
  required int capacityMah,
  Value<double?> weightGrams,
  Value<int?> cycleCount,
  Value<bool> isType,
  Value<int?> typeId,
  Value<double?> nominalVoltageVolts,
  Value<double?> energyWh,
  Value<double?> chargePercent,
  Value<String> availability,
  Value<String?> conditionNotes,
  Value<String?> notes,
});
typedef $$BatteriesTableUpdateCompanionBuilder = BatteriesCompanion Function({
  Value<int> id,
  Value<String> name,
  Value<String> chemistry,
  Value<int> cellCount,
  Value<int> capacityMah,
  Value<double?> weightGrams,
  Value<int?> cycleCount,
  Value<bool> isType,
  Value<int?> typeId,
  Value<double?> nominalVoltageVolts,
  Value<double?> energyWh,
  Value<double?> chargePercent,
  Value<String> availability,
  Value<String?> conditionNotes,
  Value<String?> notes,
});

final class $$BatteriesTableReferences
    extends BaseReferences<_$FpvDatabase, $BatteriesTable, Battery> {
  $$BatteriesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $BatteriesTable _typeIdTable(_$FpvDatabase db) =>
      db.batteries.createAlias('batteries__type_id__batteries__id');

  $$BatteriesTableProcessedTableManager? get typeId {
    final $_column = $_itemColumn<int>('type_id');
    if ($_column == null) return null;
    final manager = $$BatteriesTableTableManager(
      $_db,
      $_db.batteries,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_typeIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$BatteryDronesTable, List<BatteryDrone>>
  _batteryDronesRefsTable(_$FpvDatabase db) => MultiTypedResultKey.fromTable(
    db.batteryDrones,
    aliasName: 'batteries__id__battery_drones__battery_id',
  );

  $$BatteryDronesTableProcessedTableManager get batteryDronesRefs {
    final manager = $$BatteryDronesTableTableManager(
      $_db,
      $_db.batteryDrones,
    ).filter((f) => f.batteryId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_batteryDronesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$BatteryFlightPlansTable, List<BatteryFlightPlan>>
  _batteryFlightPlansRefsTable(_$FpvDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.batteryFlightPlans,
        aliasName: 'batteries__id__battery_flight_plans__battery_id',
      );

  $$BatteryFlightPlansTableProcessedTableManager get batteryFlightPlansRefs {
    final manager = $$BatteryFlightPlansTableTableManager(
      $_db,
      $_db.batteryFlightPlans,
    ).filter((f) => f.batteryId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _batteryFlightPlansRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$BatteriesTableFilterComposer
    extends Composer<_$FpvDatabase, $BatteriesTable> {
  $$BatteriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get chemistry => $composableBuilder(
    column: $table.chemistry,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get cellCount => $composableBuilder(
    column: $table.cellCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get capacityMah => $composableBuilder(
    column: $table.capacityMah,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get weightGrams => $composableBuilder(
    column: $table.weightGrams,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get cycleCount => $composableBuilder(
    column: $table.cycleCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isType => $composableBuilder(
    column: $table.isType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get nominalVoltageVolts => $composableBuilder(
    column: $table.nominalVoltageVolts,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get energyWh => $composableBuilder(
    column: $table.energyWh,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get chargePercent => $composableBuilder(
    column: $table.chargePercent,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get availability => $composableBuilder(
    column: $table.availability,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get conditionNotes => $composableBuilder(
    column: $table.conditionNotes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  $$BatteriesTableFilterComposer get typeId {
    final $$BatteriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.typeId,
      referencedTable: $db.batteries,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BatteriesTableFilterComposer(
            $db: $db,
            $table: $db.batteries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> batteryDronesRefs(
    Expression<bool> Function($$BatteryDronesTableFilterComposer f) f,
  ) {
    final $$BatteryDronesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.batteryDrones,
      getReferencedColumn: (t) => t.batteryId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BatteryDronesTableFilterComposer(
            $db: $db,
            $table: $db.batteryDrones,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> batteryFlightPlansRefs(
    Expression<bool> Function($$BatteryFlightPlansTableFilterComposer f) f,
  ) {
    final $$BatteryFlightPlansTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.batteryFlightPlans,
      getReferencedColumn: (t) => t.batteryId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BatteryFlightPlansTableFilterComposer(
            $db: $db,
            $table: $db.batteryFlightPlans,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$BatteriesTableOrderingComposer
    extends Composer<_$FpvDatabase, $BatteriesTable> {
  $$BatteriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get chemistry => $composableBuilder(
    column: $table.chemistry,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get cellCount => $composableBuilder(
    column: $table.cellCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get capacityMah => $composableBuilder(
    column: $table.capacityMah,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get weightGrams => $composableBuilder(
    column: $table.weightGrams,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get cycleCount => $composableBuilder(
    column: $table.cycleCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isType => $composableBuilder(
    column: $table.isType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get nominalVoltageVolts => $composableBuilder(
    column: $table.nominalVoltageVolts,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get energyWh => $composableBuilder(
    column: $table.energyWh,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get chargePercent => $composableBuilder(
    column: $table.chargePercent,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get availability => $composableBuilder(
    column: $table.availability,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get conditionNotes => $composableBuilder(
    column: $table.conditionNotes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  $$BatteriesTableOrderingComposer get typeId {
    final $$BatteriesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.typeId,
      referencedTable: $db.batteries,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BatteriesTableOrderingComposer(
            $db: $db,
            $table: $db.batteries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$BatteriesTableAnnotationComposer
    extends Composer<_$FpvDatabase, $BatteriesTable> {
  $$BatteriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get chemistry =>
      $composableBuilder(column: $table.chemistry, builder: (column) => column);

  GeneratedColumn<int> get cellCount =>
      $composableBuilder(column: $table.cellCount, builder: (column) => column);

  GeneratedColumn<int> get capacityMah => $composableBuilder(
    column: $table.capacityMah,
    builder: (column) => column,
  );

  GeneratedColumn<double> get weightGrams => $composableBuilder(
    column: $table.weightGrams,
    builder: (column) => column,
  );

  GeneratedColumn<int> get cycleCount => $composableBuilder(
    column: $table.cycleCount,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isType =>
      $composableBuilder(column: $table.isType, builder: (column) => column);

  GeneratedColumn<double> get nominalVoltageVolts => $composableBuilder(
    column: $table.nominalVoltageVolts,
    builder: (column) => column,
  );

  GeneratedColumn<double> get energyWh =>
      $composableBuilder(column: $table.energyWh, builder: (column) => column);

  GeneratedColumn<double> get chargePercent => $composableBuilder(
    column: $table.chargePercent,
    builder: (column) => column,
  );

  GeneratedColumn<String> get availability => $composableBuilder(
    column: $table.availability,
    builder: (column) => column,
  );

  GeneratedColumn<String> get conditionNotes => $composableBuilder(
    column: $table.conditionNotes,
    builder: (column) => column,
  );

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  $$BatteriesTableAnnotationComposer get typeId {
    final $$BatteriesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.typeId,
      referencedTable: $db.batteries,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BatteriesTableAnnotationComposer(
            $db: $db,
            $table: $db.batteries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> batteryDronesRefs<T extends Object>(
    Expression<T> Function($$BatteryDronesTableAnnotationComposer a) f,
  ) {
    final $$BatteryDronesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.batteryDrones,
      getReferencedColumn: (t) => t.batteryId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BatteryDronesTableAnnotationComposer(
            $db: $db,
            $table: $db.batteryDrones,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> batteryFlightPlansRefs<T extends Object>(
    Expression<T> Function($$BatteryFlightPlansTableAnnotationComposer a) f,
  ) {
    final $$BatteryFlightPlansTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.batteryFlightPlans,
          getReferencedColumn: (t) => t.batteryId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$BatteryFlightPlansTableAnnotationComposer(
                $db: $db,
                $table: $db.batteryFlightPlans,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$BatteriesTableTableManager
    extends
        RootTableManager<
          _$FpvDatabase,
          $BatteriesTable,
          Battery,
          $$BatteriesTableFilterComposer,
          $$BatteriesTableOrderingComposer,
          $$BatteriesTableAnnotationComposer,
          $$BatteriesTableCreateCompanionBuilder,
          $$BatteriesTableUpdateCompanionBuilder,
          (Battery, $$BatteriesTableReferences),
          Battery,
          PrefetchHooks Function({
            bool typeId,
            bool batteryDronesRefs,
            bool batteryFlightPlansRefs,
          })
        > {
  $$BatteriesTableTableManager(_$FpvDatabase db, $BatteriesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BatteriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BatteriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BatteriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> chemistry = const Value.absent(),
                Value<int> cellCount = const Value.absent(),
                Value<int> capacityMah = const Value.absent(),
                Value<double?> weightGrams = const Value.absent(),
                Value<int?> cycleCount = const Value.absent(),
                Value<bool> isType = const Value.absent(),
                Value<int?> typeId = const Value.absent(),
                Value<double?> nominalVoltageVolts = const Value.absent(),
                Value<double?> energyWh = const Value.absent(),
                Value<double?> chargePercent = const Value.absent(),
                Value<String> availability = const Value.absent(),
                Value<String?> conditionNotes = const Value.absent(),
                Value<String?> notes = const Value.absent(),
              }) => BatteriesCompanion(
                id: id,
                name: name,
                chemistry: chemistry,
                cellCount: cellCount,
                capacityMah: capacityMah,
                weightGrams: weightGrams,
                cycleCount: cycleCount,
                isType: isType,
                typeId: typeId,
                nominalVoltageVolts: nominalVoltageVolts,
                energyWh: energyWh,
                chargePercent: chargePercent,
                availability: availability,
                conditionNotes: conditionNotes,
                notes: notes,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                Value<String> chemistry = const Value.absent(),
                required int cellCount,
                required int capacityMah,
                Value<double?> weightGrams = const Value.absent(),
                Value<int?> cycleCount = const Value.absent(),
                Value<bool> isType = const Value.absent(),
                Value<int?> typeId = const Value.absent(),
                Value<double?> nominalVoltageVolts = const Value.absent(),
                Value<double?> energyWh = const Value.absent(),
                Value<double?> chargePercent = const Value.absent(),
                Value<String> availability = const Value.absent(),
                Value<String?> conditionNotes = const Value.absent(),
                Value<String?> notes = const Value.absent(),
              }) => BatteriesCompanion.insert(
                id: id,
                name: name,
                chemistry: chemistry,
                cellCount: cellCount,
                capacityMah: capacityMah,
                weightGrams: weightGrams,
                cycleCount: cycleCount,
                isType: isType,
                typeId: typeId,
                nominalVoltageVolts: nominalVoltageVolts,
                energyWh: energyWh,
                chargePercent: chargePercent,
                availability: availability,
                conditionNotes: conditionNotes,
                notes: notes,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$BatteriesTable, Battery>(table),
                  $$BatteriesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                typeId = false,
                batteryDronesRefs = false,
                batteryFlightPlansRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (batteryDronesRefs) db.batteryDrones,
                    if (batteryFlightPlansRefs) db.batteryFlightPlans,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (typeId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.typeId,
                            referencedTable: $$BatteriesTableReferences
                                ._typeIdTable(db),
                            referencedColumn: $$BatteriesTableReferences
                                ._typeIdTable(db)
                                .id,
                          ) as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (batteryDronesRefs)
                        await $_getPrefetchedData<
                          Battery,
                          $BatteriesTable,
                          BatteryDrone
                        >(
                          currentTable: table,
                          referencedTable: $$BatteriesTableReferences
                              ._batteryDronesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$BatteriesTableReferences(
                                db,
                                table,
                                p0,
                              ).batteryDronesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.batteryId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (batteryFlightPlansRefs)
                        await $_getPrefetchedData<
                          Battery,
                          $BatteriesTable,
                          BatteryFlightPlan
                        >(
                          currentTable: table,
                          referencedTable: $$BatteriesTableReferences
                              ._batteryFlightPlansRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$BatteriesTableReferences(
                                db,
                                table,
                                p0,
                              ).batteryFlightPlansRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.batteryId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$BatteriesTableProcessedTableManager =
    ProcessedTableManager<
      _$FpvDatabase,
      $BatteriesTable,
      Battery,
      $$BatteriesTableFilterComposer,
      $$BatteriesTableOrderingComposer,
      $$BatteriesTableAnnotationComposer,
      $$BatteriesTableCreateCompanionBuilder,
      $$BatteriesTableUpdateCompanionBuilder,
      (Battery, $$BatteriesTableReferences),
      Battery,
      PrefetchHooks Function({
        bool typeId,
        bool batteryDronesRefs,
        bool batteryFlightPlansRefs,
      })
    >;
typedef $$BatteryDronesTableCreateCompanionBuilder =
    BatteryDronesCompanion Function({
      required int batteryId,
      required int droneId,
      Value<int> rowid,
    });
typedef $$BatteryDronesTableUpdateCompanionBuilder =
    BatteryDronesCompanion Function({
      Value<int> batteryId,
      Value<int> droneId,
      Value<int> rowid,
    });

final class $$BatteryDronesTableReferences
    extends BaseReferences<_$FpvDatabase, $BatteryDronesTable, BatteryDrone> {
  $$BatteryDronesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $BatteriesTable _batteryIdTable(_$FpvDatabase db) =>
      db.batteries.createAlias('battery_drones__battery_id__batteries__id');

  $$BatteriesTableProcessedTableManager get batteryId {
    final $_column = $_itemColumn<int>('battery_id')!;

    final manager = $$BatteriesTableTableManager(
      $_db,
      $_db.batteries,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_batteryIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $DronesTable _droneIdTable(_$FpvDatabase db) =>
      db.drones.createAlias('battery_drones__drone_id__drones__id');

  $$DronesTableProcessedTableManager get droneId {
    final $_column = $_itemColumn<int>('drone_id')!;

    final manager = $$DronesTableTableManager(
      $_db,
      $_db.drones,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_droneIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$BatteryDronesTableFilterComposer
    extends Composer<_$FpvDatabase, $BatteryDronesTable> {
  $$BatteryDronesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  $$BatteriesTableFilterComposer get batteryId {
    final $$BatteriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.batteryId,
      referencedTable: $db.batteries,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BatteriesTableFilterComposer(
            $db: $db,
            $table: $db.batteries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$DronesTableFilterComposer get droneId {
    final $$DronesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.droneId,
      referencedTable: $db.drones,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DronesTableFilterComposer(
            $db: $db,
            $table: $db.drones,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$BatteryDronesTableOrderingComposer
    extends Composer<_$FpvDatabase, $BatteryDronesTable> {
  $$BatteryDronesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  $$BatteriesTableOrderingComposer get batteryId {
    final $$BatteriesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.batteryId,
      referencedTable: $db.batteries,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BatteriesTableOrderingComposer(
            $db: $db,
            $table: $db.batteries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$DronesTableOrderingComposer get droneId {
    final $$DronesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.droneId,
      referencedTable: $db.drones,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DronesTableOrderingComposer(
            $db: $db,
            $table: $db.drones,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$BatteryDronesTableAnnotationComposer
    extends Composer<_$FpvDatabase, $BatteryDronesTable> {
  $$BatteryDronesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  $$BatteriesTableAnnotationComposer get batteryId {
    final $$BatteriesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.batteryId,
      referencedTable: $db.batteries,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BatteriesTableAnnotationComposer(
            $db: $db,
            $table: $db.batteries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$DronesTableAnnotationComposer get droneId {
    final $$DronesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.droneId,
      referencedTable: $db.drones,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DronesTableAnnotationComposer(
            $db: $db,
            $table: $db.drones,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$BatteryDronesTableTableManager
    extends
        RootTableManager<
          _$FpvDatabase,
          $BatteryDronesTable,
          BatteryDrone,
          $$BatteryDronesTableFilterComposer,
          $$BatteryDronesTableOrderingComposer,
          $$BatteryDronesTableAnnotationComposer,
          $$BatteryDronesTableCreateCompanionBuilder,
          $$BatteryDronesTableUpdateCompanionBuilder,
          (BatteryDrone, $$BatteryDronesTableReferences),
          BatteryDrone,
          PrefetchHooks Function({bool batteryId, bool droneId})
        > {
  $$BatteryDronesTableTableManager(_$FpvDatabase db, $BatteryDronesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BatteryDronesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BatteryDronesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BatteryDronesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> batteryId = const Value.absent(),
                Value<int> droneId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BatteryDronesCompanion(
                batteryId: batteryId,
                droneId: droneId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required int batteryId,
                required int droneId,
                Value<int> rowid = const Value.absent(),
              }) => BatteryDronesCompanion.insert(
                batteryId: batteryId,
                droneId: droneId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$BatteryDronesTable, BatteryDrone>(table),
                  $$BatteryDronesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({batteryId = false, droneId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (batteryId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.batteryId,
                        referencedTable: $$BatteryDronesTableReferences
                            ._batteryIdTable(db),
                        referencedColumn: $$BatteryDronesTableReferences
                            ._batteryIdTable(db)
                            .id,
                      ) as T;
                    }
                    if (droneId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.droneId,
                        referencedTable: $$BatteryDronesTableReferences
                            ._droneIdTable(db),
                        referencedColumn: $$BatteryDronesTableReferences
                            ._droneIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$BatteryDronesTableProcessedTableManager =
    ProcessedTableManager<
      _$FpvDatabase,
      $BatteryDronesTable,
      BatteryDrone,
      $$BatteryDronesTableFilterComposer,
      $$BatteryDronesTableOrderingComposer,
      $$BatteryDronesTableAnnotationComposer,
      $$BatteryDronesTableCreateCompanionBuilder,
      $$BatteryDronesTableUpdateCompanionBuilder,
      (BatteryDrone, $$BatteryDronesTableReferences),
      BatteryDrone,
      PrefetchHooks Function({bool batteryId, bool droneId})
    >;
typedef $$FlightPlansTableCreateCompanionBuilder =
    FlightPlansCompanion Function({
      Value<int> id,
      required String name,
      Value<int?> droneId,
      Value<int?> startSpotId,
      Value<String?> notes,
      Value<DateTime> createdAt,
    });
typedef $$FlightPlansTableUpdateCompanionBuilder =
    FlightPlansCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<int?> droneId,
      Value<int?> startSpotId,
      Value<String?> notes,
      Value<DateTime> createdAt,
    });

final class $$FlightPlansTableReferences
    extends BaseReferences<_$FpvDatabase, $FlightPlansTable, FlightPlan> {
  $$FlightPlansTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $DronesTable _droneIdTable(_$FpvDatabase db) =>
      db.drones.createAlias('flight_plans__drone_id__drones__id');

  $$DronesTableProcessedTableManager? get droneId {
    final $_column = $_itemColumn<int>('drone_id');
    if ($_column == null) return null;
    final manager = $$DronesTableTableManager(
      $_db,
      $_db.drones,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_droneIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $SpotsTable _startSpotIdTable(_$FpvDatabase db) =>
      db.spots.createAlias('flight_plans__start_spot_id__spots__id');

  $$SpotsTableProcessedTableManager? get startSpotId {
    final $_column = $_itemColumn<int>('start_spot_id');
    if ($_column == null) return null;
    final manager = $$SpotsTableTableManager(
      $_db,
      $_db.spots,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_startSpotIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$BatteryFlightPlansTable, List<BatteryFlightPlan>>
  _batteryFlightPlansRefsTable(_$FpvDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.batteryFlightPlans,
        aliasName: 'flight_plans__id__battery_flight_plans__plan_id',
      );

  $$BatteryFlightPlansTableProcessedTableManager get batteryFlightPlansRefs {
    final manager = $$BatteryFlightPlansTableTableManager(
      $_db,
      $_db.batteryFlightPlans,
    ).filter((f) => f.planId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _batteryFlightPlansRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$FlightWaypointsTable, List<FlightWaypoint>>
  _flightWaypointsRefsTable(_$FpvDatabase db) => MultiTypedResultKey.fromTable(
    db.flightWaypoints,
    aliasName: 'flight_plans__id__flight_waypoints__plan_id',
  );

  $$FlightWaypointsTableProcessedTableManager get flightWaypointsRefs {
    final manager = $$FlightWaypointsTableTableManager(
      $_db,
      $_db.flightWaypoints,
    ).filter((f) => f.planId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _flightWaypointsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$FlightPlansTableFilterComposer
    extends Composer<_$FpvDatabase, $FlightPlansTable> {
  $$FlightPlansTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $$DronesTableFilterComposer get droneId {
    final $$DronesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.droneId,
      referencedTable: $db.drones,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DronesTableFilterComposer(
            $db: $db,
            $table: $db.drones,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$SpotsTableFilterComposer get startSpotId {
    final $$SpotsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.startSpotId,
      referencedTable: $db.spots,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SpotsTableFilterComposer(
            $db: $db,
            $table: $db.spots,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> batteryFlightPlansRefs(
    Expression<bool> Function($$BatteryFlightPlansTableFilterComposer f) f,
  ) {
    final $$BatteryFlightPlansTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.batteryFlightPlans,
      getReferencedColumn: (t) => t.planId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BatteryFlightPlansTableFilterComposer(
            $db: $db,
            $table: $db.batteryFlightPlans,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> flightWaypointsRefs(
    Expression<bool> Function($$FlightWaypointsTableFilterComposer f) f,
  ) {
    final $$FlightWaypointsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.flightWaypoints,
      getReferencedColumn: (t) => t.planId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FlightWaypointsTableFilterComposer(
            $db: $db,
            $table: $db.flightWaypoints,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$FlightPlansTableOrderingComposer
    extends Composer<_$FpvDatabase, $FlightPlansTable> {
  $$FlightPlansTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$DronesTableOrderingComposer get droneId {
    final $$DronesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.droneId,
      referencedTable: $db.drones,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DronesTableOrderingComposer(
            $db: $db,
            $table: $db.drones,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$SpotsTableOrderingComposer get startSpotId {
    final $$SpotsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.startSpotId,
      referencedTable: $db.spots,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SpotsTableOrderingComposer(
            $db: $db,
            $table: $db.spots,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$FlightPlansTableAnnotationComposer
    extends Composer<_$FpvDatabase, $FlightPlansTable> {
  $$FlightPlansTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$DronesTableAnnotationComposer get droneId {
    final $$DronesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.droneId,
      referencedTable: $db.drones,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DronesTableAnnotationComposer(
            $db: $db,
            $table: $db.drones,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$SpotsTableAnnotationComposer get startSpotId {
    final $$SpotsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.startSpotId,
      referencedTable: $db.spots,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SpotsTableAnnotationComposer(
            $db: $db,
            $table: $db.spots,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> batteryFlightPlansRefs<T extends Object>(
    Expression<T> Function($$BatteryFlightPlansTableAnnotationComposer a) f,
  ) {
    final $$BatteryFlightPlansTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.batteryFlightPlans,
          getReferencedColumn: (t) => t.planId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$BatteryFlightPlansTableAnnotationComposer(
                $db: $db,
                $table: $db.batteryFlightPlans,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<T> flightWaypointsRefs<T extends Object>(
    Expression<T> Function($$FlightWaypointsTableAnnotationComposer a) f,
  ) {
    final $$FlightWaypointsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.flightWaypoints,
      getReferencedColumn: (t) => t.planId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FlightWaypointsTableAnnotationComposer(
            $db: $db,
            $table: $db.flightWaypoints,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$FlightPlansTableTableManager
    extends
        RootTableManager<
          _$FpvDatabase,
          $FlightPlansTable,
          FlightPlan,
          $$FlightPlansTableFilterComposer,
          $$FlightPlansTableOrderingComposer,
          $$FlightPlansTableAnnotationComposer,
          $$FlightPlansTableCreateCompanionBuilder,
          $$FlightPlansTableUpdateCompanionBuilder,
          (FlightPlan, $$FlightPlansTableReferences),
          FlightPlan,
          PrefetchHooks Function({
            bool droneId,
            bool startSpotId,
            bool batteryFlightPlansRefs,
            bool flightWaypointsRefs,
          })
        > {
  $$FlightPlansTableTableManager(_$FpvDatabase db, $FlightPlansTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FlightPlansTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FlightPlansTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FlightPlansTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int?> droneId = const Value.absent(),
                Value<int?> startSpotId = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => FlightPlansCompanion(
                id: id,
                name: name,
                droneId: droneId,
                startSpotId: startSpotId,
                notes: notes,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                Value<int?> droneId = const Value.absent(),
                Value<int?> startSpotId = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => FlightPlansCompanion.insert(
                id: id,
                name: name,
                droneId: droneId,
                startSpotId: startSpotId,
                notes: notes,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$FlightPlansTable, FlightPlan>(table),
                  $$FlightPlansTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                droneId = false,
                startSpotId = false,
                batteryFlightPlansRefs = false,
                flightWaypointsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (batteryFlightPlansRefs) db.batteryFlightPlans,
                    if (flightWaypointsRefs) db.flightWaypoints,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (droneId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.droneId,
                            referencedTable: $$FlightPlansTableReferences
                                ._droneIdTable(db),
                            referencedColumn: $$FlightPlansTableReferences
                                ._droneIdTable(db)
                                .id,
                          ) as T;
                        }
                        if (startSpotId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.startSpotId,
                            referencedTable: $$FlightPlansTableReferences
                                ._startSpotIdTable(db),
                            referencedColumn: $$FlightPlansTableReferences
                                ._startSpotIdTable(db)
                                .id,
                          ) as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (batteryFlightPlansRefs)
                        await $_getPrefetchedData<
                          FlightPlan,
                          $FlightPlansTable,
                          BatteryFlightPlan
                        >(
                          currentTable: table,
                          referencedTable: $$FlightPlansTableReferences
                              ._batteryFlightPlansRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$FlightPlansTableReferences(
                                db,
                                table,
                                p0,
                              ).batteryFlightPlansRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.planId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (flightWaypointsRefs)
                        await $_getPrefetchedData<
                          FlightPlan,
                          $FlightPlansTable,
                          FlightWaypoint
                        >(
                          currentTable: table,
                          referencedTable: $$FlightPlansTableReferences
                              ._flightWaypointsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$FlightPlansTableReferences(
                                db,
                                table,
                                p0,
                              ).flightWaypointsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.planId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$FlightPlansTableProcessedTableManager =
    ProcessedTableManager<
      _$FpvDatabase,
      $FlightPlansTable,
      FlightPlan,
      $$FlightPlansTableFilterComposer,
      $$FlightPlansTableOrderingComposer,
      $$FlightPlansTableAnnotationComposer,
      $$FlightPlansTableCreateCompanionBuilder,
      $$FlightPlansTableUpdateCompanionBuilder,
      (FlightPlan, $$FlightPlansTableReferences),
      FlightPlan,
      PrefetchHooks Function({
        bool droneId,
        bool startSpotId,
        bool batteryFlightPlansRefs,
        bool flightWaypointsRefs,
      })
    >;
typedef $$BatteryFlightPlansTableCreateCompanionBuilder =
    BatteryFlightPlansCompanion Function({
      required int batteryId,
      required int planId,
      Value<int> rowid,
    });
typedef $$BatteryFlightPlansTableUpdateCompanionBuilder =
    BatteryFlightPlansCompanion Function({
      Value<int> batteryId,
      Value<int> planId,
      Value<int> rowid,
    });

final class $$BatteryFlightPlansTableReferences
    extends
        BaseReferences<
          _$FpvDatabase,
          $BatteryFlightPlansTable,
          BatteryFlightPlan
        > {
  $$BatteryFlightPlansTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $BatteriesTable _batteryIdTable(_$FpvDatabase db) => db.batteries
      .createAlias('battery_flight_plans__battery_id__batteries__id');

  $$BatteriesTableProcessedTableManager get batteryId {
    final $_column = $_itemColumn<int>('battery_id')!;

    final manager = $$BatteriesTableTableManager(
      $_db,
      $_db.batteries,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_batteryIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $FlightPlansTable _planIdTable(_$FpvDatabase db) => db.flightPlans
      .createAlias('battery_flight_plans__plan_id__flight_plans__id');

  $$FlightPlansTableProcessedTableManager get planId {
    final $_column = $_itemColumn<int>('plan_id')!;

    final manager = $$FlightPlansTableTableManager(
      $_db,
      $_db.flightPlans,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_planIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$BatteryFlightPlansTableFilterComposer
    extends Composer<_$FpvDatabase, $BatteryFlightPlansTable> {
  $$BatteryFlightPlansTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  $$BatteriesTableFilterComposer get batteryId {
    final $$BatteriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.batteryId,
      referencedTable: $db.batteries,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BatteriesTableFilterComposer(
            $db: $db,
            $table: $db.batteries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$FlightPlansTableFilterComposer get planId {
    final $$FlightPlansTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.planId,
      referencedTable: $db.flightPlans,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FlightPlansTableFilterComposer(
            $db: $db,
            $table: $db.flightPlans,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$BatteryFlightPlansTableOrderingComposer
    extends Composer<_$FpvDatabase, $BatteryFlightPlansTable> {
  $$BatteryFlightPlansTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  $$BatteriesTableOrderingComposer get batteryId {
    final $$BatteriesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.batteryId,
      referencedTable: $db.batteries,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BatteriesTableOrderingComposer(
            $db: $db,
            $table: $db.batteries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$FlightPlansTableOrderingComposer get planId {
    final $$FlightPlansTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.planId,
      referencedTable: $db.flightPlans,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FlightPlansTableOrderingComposer(
            $db: $db,
            $table: $db.flightPlans,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$BatteryFlightPlansTableAnnotationComposer
    extends Composer<_$FpvDatabase, $BatteryFlightPlansTable> {
  $$BatteryFlightPlansTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  $$BatteriesTableAnnotationComposer get batteryId {
    final $$BatteriesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.batteryId,
      referencedTable: $db.batteries,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BatteriesTableAnnotationComposer(
            $db: $db,
            $table: $db.batteries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$FlightPlansTableAnnotationComposer get planId {
    final $$FlightPlansTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.planId,
      referencedTable: $db.flightPlans,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FlightPlansTableAnnotationComposer(
            $db: $db,
            $table: $db.flightPlans,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$BatteryFlightPlansTableTableManager
    extends
        RootTableManager<
          _$FpvDatabase,
          $BatteryFlightPlansTable,
          BatteryFlightPlan,
          $$BatteryFlightPlansTableFilterComposer,
          $$BatteryFlightPlansTableOrderingComposer,
          $$BatteryFlightPlansTableAnnotationComposer,
          $$BatteryFlightPlansTableCreateCompanionBuilder,
          $$BatteryFlightPlansTableUpdateCompanionBuilder,
          (BatteryFlightPlan, $$BatteryFlightPlansTableReferences),
          BatteryFlightPlan,
          PrefetchHooks Function({bool batteryId, bool planId})
        > {
  $$BatteryFlightPlansTableTableManager(
    _$FpvDatabase db,
    $BatteryFlightPlansTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BatteryFlightPlansTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BatteryFlightPlansTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BatteryFlightPlansTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> batteryId = const Value.absent(),
                Value<int> planId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BatteryFlightPlansCompanion(
                batteryId: batteryId,
                planId: planId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required int batteryId,
                required int planId,
                Value<int> rowid = const Value.absent(),
              }) => BatteryFlightPlansCompanion.insert(
                batteryId: batteryId,
                planId: planId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$BatteryFlightPlansTable, BatteryFlightPlan>(
                    table,
                  ),
                  $$BatteryFlightPlansTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({batteryId = false, planId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (batteryId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.batteryId,
                        referencedTable: $$BatteryFlightPlansTableReferences
                            ._batteryIdTable(db),
                        referencedColumn: $$BatteryFlightPlansTableReferences
                            ._batteryIdTable(db)
                            .id,
                      ) as T;
                    }
                    if (planId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.planId,
                        referencedTable: $$BatteryFlightPlansTableReferences
                            ._planIdTable(db),
                        referencedColumn: $$BatteryFlightPlansTableReferences
                            ._planIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$BatteryFlightPlansTableProcessedTableManager =
    ProcessedTableManager<
      _$FpvDatabase,
      $BatteryFlightPlansTable,
      BatteryFlightPlan,
      $$BatteryFlightPlansTableFilterComposer,
      $$BatteryFlightPlansTableOrderingComposer,
      $$BatteryFlightPlansTableAnnotationComposer,
      $$BatteryFlightPlansTableCreateCompanionBuilder,
      $$BatteryFlightPlansTableUpdateCompanionBuilder,
      (BatteryFlightPlan, $$BatteryFlightPlansTableReferences),
      BatteryFlightPlan,
      PrefetchHooks Function({bool batteryId, bool planId})
    >;
typedef $$RadioEquipmentTableCreateCompanionBuilder =
    RadioEquipmentCompanion Function({
      Value<int> id,
      required String name,
      required String category,
      Value<double?> frequencyMhz,
      Value<double?> maxPowerMw,
      Value<String?> notes,
    });
typedef $$RadioEquipmentTableUpdateCompanionBuilder =
    RadioEquipmentCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<String> category,
      Value<double?> frequencyMhz,
      Value<double?> maxPowerMw,
      Value<String?> notes,
    });

class $$RadioEquipmentTableFilterComposer
    extends Composer<_$FpvDatabase, $RadioEquipmentTable> {
  $$RadioEquipmentTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get frequencyMhz => $composableBuilder(
    column: $table.frequencyMhz,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get maxPowerMw => $composableBuilder(
    column: $table.maxPowerMw,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );
}

class $$RadioEquipmentTableOrderingComposer
    extends Composer<_$FpvDatabase, $RadioEquipmentTable> {
  $$RadioEquipmentTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get frequencyMhz => $composableBuilder(
    column: $table.frequencyMhz,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get maxPowerMw => $composableBuilder(
    column: $table.maxPowerMw,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$RadioEquipmentTableAnnotationComposer
    extends Composer<_$FpvDatabase, $RadioEquipmentTable> {
  $$RadioEquipmentTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get category =>
      $composableBuilder(column: $table.category, builder: (column) => column);

  GeneratedColumn<double> get frequencyMhz => $composableBuilder(
    column: $table.frequencyMhz,
    builder: (column) => column,
  );

  GeneratedColumn<double> get maxPowerMw => $composableBuilder(
    column: $table.maxPowerMw,
    builder: (column) => column,
  );

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);
}

class $$RadioEquipmentTableTableManager
    extends
        RootTableManager<
          _$FpvDatabase,
          $RadioEquipmentTable,
          RadioEquipmentData,
          $$RadioEquipmentTableFilterComposer,
          $$RadioEquipmentTableOrderingComposer,
          $$RadioEquipmentTableAnnotationComposer,
          $$RadioEquipmentTableCreateCompanionBuilder,
          $$RadioEquipmentTableUpdateCompanionBuilder,
          (
            RadioEquipmentData,
            BaseReferences<
              _$FpvDatabase,
              $RadioEquipmentTable,
              RadioEquipmentData
            >,
          ),
          RadioEquipmentData,
          PrefetchHooks Function()
        > {
  $$RadioEquipmentTableTableManager(
    _$FpvDatabase db,
    $RadioEquipmentTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RadioEquipmentTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RadioEquipmentTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RadioEquipmentTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> category = const Value.absent(),
                Value<double?> frequencyMhz = const Value.absent(),
                Value<double?> maxPowerMw = const Value.absent(),
                Value<String?> notes = const Value.absent(),
              }) => RadioEquipmentCompanion(
                id: id,
                name: name,
                category: category,
                frequencyMhz: frequencyMhz,
                maxPowerMw: maxPowerMw,
                notes: notes,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                required String category,
                Value<double?> frequencyMhz = const Value.absent(),
                Value<double?> maxPowerMw = const Value.absent(),
                Value<String?> notes = const Value.absent(),
              }) => RadioEquipmentCompanion.insert(
                id: id,
                name: name,
                category: category,
                frequencyMhz: frequencyMhz,
                maxPowerMw: maxPowerMw,
                notes: notes,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$RadioEquipmentTable, RadioEquipmentData>(table),
                  BaseReferences<
                    _$FpvDatabase,
                    $RadioEquipmentTable,
                    RadioEquipmentData
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$RadioEquipmentTableProcessedTableManager =
    ProcessedTableManager<
      _$FpvDatabase,
      $RadioEquipmentTable,
      RadioEquipmentData,
      $$RadioEquipmentTableFilterComposer,
      $$RadioEquipmentTableOrderingComposer,
      $$RadioEquipmentTableAnnotationComposer,
      $$RadioEquipmentTableCreateCompanionBuilder,
      $$RadioEquipmentTableUpdateCompanionBuilder,
      (
        RadioEquipmentData,
        BaseReferences<_$FpvDatabase, $RadioEquipmentTable, RadioEquipmentData>,
      ),
      RadioEquipmentData,
      PrefetchHooks Function()
    >;
typedef $$FlightWaypointsTableCreateCompanionBuilder =
    FlightWaypointsCompanion Function({
      Value<int> id,
      required int planId,
      required int sequenceNumber,
      required double latitude,
      required double longitude,
      Value<double?> heightMeters,
      Value<String> heightReference,
      Value<String> altitudeMode,
    });
typedef $$FlightWaypointsTableUpdateCompanionBuilder =
    FlightWaypointsCompanion Function({
      Value<int> id,
      Value<int> planId,
      Value<int> sequenceNumber,
      Value<double> latitude,
      Value<double> longitude,
      Value<double?> heightMeters,
      Value<String> heightReference,
      Value<String> altitudeMode,
    });

final class $$FlightWaypointsTableReferences
    extends
        BaseReferences<_$FpvDatabase, $FlightWaypointsTable, FlightWaypoint> {
  $$FlightWaypointsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $FlightPlansTable _planIdTable(_$FpvDatabase db) =>
      db.flightPlans.createAlias('flight_waypoints__plan_id__flight_plans__id');

  $$FlightPlansTableProcessedTableManager get planId {
    final $_column = $_itemColumn<int>('plan_id')!;

    final manager = $$FlightPlansTableTableManager(
      $_db,
      $_db.flightPlans,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_planIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$FlightWaypointsTableFilterComposer
    extends Composer<_$FpvDatabase, $FlightWaypointsTable> {
  $$FlightWaypointsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sequenceNumber => $composableBuilder(
    column: $table.sequenceNumber,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get latitude => $composableBuilder(
    column: $table.latitude,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get longitude => $composableBuilder(
    column: $table.longitude,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get heightMeters => $composableBuilder(
    column: $table.heightMeters,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get heightReference => $composableBuilder(
    column: $table.heightReference,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get altitudeMode => $composableBuilder(
    column: $table.altitudeMode,
    builder: (column) => ColumnFilters(column),
  );

  $$FlightPlansTableFilterComposer get planId {
    final $$FlightPlansTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.planId,
      referencedTable: $db.flightPlans,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FlightPlansTableFilterComposer(
            $db: $db,
            $table: $db.flightPlans,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$FlightWaypointsTableOrderingComposer
    extends Composer<_$FpvDatabase, $FlightWaypointsTable> {
  $$FlightWaypointsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sequenceNumber => $composableBuilder(
    column: $table.sequenceNumber,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get latitude => $composableBuilder(
    column: $table.latitude,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get longitude => $composableBuilder(
    column: $table.longitude,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get heightMeters => $composableBuilder(
    column: $table.heightMeters,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get heightReference => $composableBuilder(
    column: $table.heightReference,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get altitudeMode => $composableBuilder(
    column: $table.altitudeMode,
    builder: (column) => ColumnOrderings(column),
  );

  $$FlightPlansTableOrderingComposer get planId {
    final $$FlightPlansTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.planId,
      referencedTable: $db.flightPlans,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FlightPlansTableOrderingComposer(
            $db: $db,
            $table: $db.flightPlans,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$FlightWaypointsTableAnnotationComposer
    extends Composer<_$FpvDatabase, $FlightWaypointsTable> {
  $$FlightWaypointsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get sequenceNumber => $composableBuilder(
    column: $table.sequenceNumber,
    builder: (column) => column,
  );

  GeneratedColumn<double> get latitude =>
      $composableBuilder(column: $table.latitude, builder: (column) => column);

  GeneratedColumn<double> get longitude =>
      $composableBuilder(column: $table.longitude, builder: (column) => column);

  GeneratedColumn<double> get heightMeters => $composableBuilder(
    column: $table.heightMeters,
    builder: (column) => column,
  );

  GeneratedColumn<String> get heightReference => $composableBuilder(
    column: $table.heightReference,
    builder: (column) => column,
  );

  GeneratedColumn<String> get altitudeMode => $composableBuilder(
    column: $table.altitudeMode,
    builder: (column) => column,
  );

  $$FlightPlansTableAnnotationComposer get planId {
    final $$FlightPlansTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.planId,
      referencedTable: $db.flightPlans,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FlightPlansTableAnnotationComposer(
            $db: $db,
            $table: $db.flightPlans,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$FlightWaypointsTableTableManager
    extends
        RootTableManager<
          _$FpvDatabase,
          $FlightWaypointsTable,
          FlightWaypoint,
          $$FlightWaypointsTableFilterComposer,
          $$FlightWaypointsTableOrderingComposer,
          $$FlightWaypointsTableAnnotationComposer,
          $$FlightWaypointsTableCreateCompanionBuilder,
          $$FlightWaypointsTableUpdateCompanionBuilder,
          (FlightWaypoint, $$FlightWaypointsTableReferences),
          FlightWaypoint,
          PrefetchHooks Function({bool planId})
        > {
  $$FlightWaypointsTableTableManager(
    _$FpvDatabase db,
    $FlightWaypointsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FlightWaypointsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FlightWaypointsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FlightWaypointsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> planId = const Value.absent(),
                Value<int> sequenceNumber = const Value.absent(),
                Value<double> latitude = const Value.absent(),
                Value<double> longitude = const Value.absent(),
                Value<double?> heightMeters = const Value.absent(),
                Value<String> heightReference = const Value.absent(),
                Value<String> altitudeMode = const Value.absent(),
              }) => FlightWaypointsCompanion(
                id: id,
                planId: planId,
                sequenceNumber: sequenceNumber,
                latitude: latitude,
                longitude: longitude,
                heightMeters: heightMeters,
                heightReference: heightReference,
                altitudeMode: altitudeMode,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int planId,
                required int sequenceNumber,
                required double latitude,
                required double longitude,
                Value<double?> heightMeters = const Value.absent(),
                Value<String> heightReference = const Value.absent(),
                Value<String> altitudeMode = const Value.absent(),
              }) => FlightWaypointsCompanion.insert(
                id: id,
                planId: planId,
                sequenceNumber: sequenceNumber,
                latitude: latitude,
                longitude: longitude,
                heightMeters: heightMeters,
                heightReference: heightReference,
                altitudeMode: altitudeMode,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$FlightWaypointsTable, FlightWaypoint>(table),
                  $$FlightWaypointsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({planId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (planId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.planId,
                        referencedTable: $$FlightWaypointsTableReferences
                            ._planIdTable(db),
                        referencedColumn: $$FlightWaypointsTableReferences
                            ._planIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$FlightWaypointsTableProcessedTableManager =
    ProcessedTableManager<
      _$FpvDatabase,
      $FlightWaypointsTable,
      FlightWaypoint,
      $$FlightWaypointsTableFilterComposer,
      $$FlightWaypointsTableOrderingComposer,
      $$FlightWaypointsTableAnnotationComposer,
      $$FlightWaypointsTableCreateCompanionBuilder,
      $$FlightWaypointsTableUpdateCompanionBuilder,
      (FlightWaypoint, $$FlightWaypointsTableReferences),
      FlightWaypoint,
      PrefetchHooks Function({bool planId})
    >;
typedef $$AppSettingsTableCreateCompanionBuilder =
    AppSettingsCompanion Function({
      required String key,
      required String value,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });
typedef $$AppSettingsTableUpdateCompanionBuilder =
    AppSettingsCompanion Function({
      Value<String> key,
      Value<String> value,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$AppSettingsTableFilterComposer
    extends Composer<_$FpvDatabase, $AppSettingsTable> {
  $$AppSettingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AppSettingsTableOrderingComposer
    extends Composer<_$FpvDatabase, $AppSettingsTable> {
  $$AppSettingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AppSettingsTableAnnotationComposer
    extends Composer<_$FpvDatabase, $AppSettingsTable> {
  $$AppSettingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$AppSettingsTableTableManager
    extends
        RootTableManager<
          _$FpvDatabase,
          $AppSettingsTable,
          AppSetting,
          $$AppSettingsTableFilterComposer,
          $$AppSettingsTableOrderingComposer,
          $$AppSettingsTableAnnotationComposer,
          $$AppSettingsTableCreateCompanionBuilder,
          $$AppSettingsTableUpdateCompanionBuilder,
          (
            AppSetting,
            BaseReferences<_$FpvDatabase, $AppSettingsTable, AppSetting>,
          ),
          AppSetting,
          PrefetchHooks Function()
        > {
  $$AppSettingsTableTableManager(_$FpvDatabase db, $AppSettingsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AppSettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AppSettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AppSettingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<String> value = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AppSettingsCompanion(
                key: key,
                value: value,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String key,
                required String value,
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AppSettingsCompanion.insert(
                key: key,
                value: value,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$AppSettingsTable, AppSetting>(table),
                  BaseReferences<_$FpvDatabase, $AppSettingsTable, AppSetting>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AppSettingsTableProcessedTableManager =
    ProcessedTableManager<
      _$FpvDatabase,
      $AppSettingsTable,
      AppSetting,
      $$AppSettingsTableFilterComposer,
      $$AppSettingsTableOrderingComposer,
      $$AppSettingsTableAnnotationComposer,
      $$AppSettingsTableCreateCompanionBuilder,
      $$AppSettingsTableUpdateCompanionBuilder,
      (
        AppSetting,
        BaseReferences<_$FpvDatabase, $AppSettingsTable, AppSetting>,
      ),
      AppSetting,
      PrefetchHooks Function()
    >;

class $FpvDatabaseManager {
  final _$FpvDatabase _db;
  $FpvDatabaseManager(this._db);
  $$SpotsTableTableManager get spots =>
      $$SpotsTableTableManager(_db, _db.spots);
  $$SpotTagsTableTableManager get spotTags =>
      $$SpotTagsTableTableManager(_db, _db.spotTags);
  $$SpotPhotosTableTableManager get spotPhotos =>
      $$SpotPhotosTableTableManager(_db, _db.spotPhotos);
  $$DronesTableTableManager get drones =>
      $$DronesTableTableManager(_db, _db.drones);
  $$DroneParameterSourcesTableTableManager get droneParameterSources =>
      $$DroneParameterSourcesTableTableManager(_db, _db.droneParameterSources);
  $$BatteriesTableTableManager get batteries =>
      $$BatteriesTableTableManager(_db, _db.batteries);
  $$BatteryDronesTableTableManager get batteryDrones =>
      $$BatteryDronesTableTableManager(_db, _db.batteryDrones);
  $$FlightPlansTableTableManager get flightPlans =>
      $$FlightPlansTableTableManager(_db, _db.flightPlans);
  $$BatteryFlightPlansTableTableManager get batteryFlightPlans =>
      $$BatteryFlightPlansTableTableManager(_db, _db.batteryFlightPlans);
  $$RadioEquipmentTableTableManager get radioEquipment =>
      $$RadioEquipmentTableTableManager(_db, _db.radioEquipment);
  $$FlightWaypointsTableTableManager get flightWaypoints =>
      $$FlightWaypointsTableTableManager(_db, _db.flightWaypoints);
  $$AppSettingsTableTableManager get appSettings =>
      $$AppSettingsTableTableManager(_db, _db.appSettings);
}
