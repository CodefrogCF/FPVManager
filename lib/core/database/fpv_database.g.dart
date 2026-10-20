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
  final bool isFavorite;
  final DateTime createdAt;
  const Spot({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    this.notes,
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
    bool? isFavorite,
    DateTime? createdAt,
  }) => Spot(
    id: id ?? this.id,
    name: name ?? this.name,
    latitude: latitude ?? this.latitude,
    longitude: longitude ?? this.longitude,
    notes: notes.present ? notes.value : this.notes,
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
          ..write('isFavorite: $isFavorite, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, name, latitude, longitude, notes, isFavorite, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Spot &&
          other.id == this.id &&
          other.name == this.name &&
          other.latitude == this.latitude &&
          other.longitude == this.longitude &&
          other.notes == this.notes &&
          other.isFavorite == this.isFavorite &&
          other.createdAt == this.createdAt);
}

class SpotsCompanion extends UpdateCompanion<Spot> {
  final Value<int> id;
  final Value<String> name;
  final Value<double> latitude;
  final Value<double> longitude;
  final Value<String?> notes;
  final Value<bool> isFavorite;
  final Value<DateTime> createdAt;
  const SpotsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.latitude = const Value.absent(),
    this.longitude = const Value.absent(),
    this.notes = const Value.absent(),
    this.isFavorite = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  SpotsCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    required double latitude,
    required double longitude,
    this.notes = const Value.absent(),
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
    Expression<bool>? isFavorite,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (notes != null) 'notes': notes,
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
    Value<bool>? isFavorite,
    Value<DateTime>? createdAt,
  }) {
    return SpotsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      notes: notes ?? this.notes,
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
          ..write('isFavorite: $isFavorite, ')
          ..write('createdAt: $createdAt')
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
  final String? notes;
  final DateTime createdAt;
  const Drone({
    required this.id,
    required this.name,
    required this.type,
    this.takeoffWeightGrams,
    this.maxSpeedMetersPerSecond,
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
          ..write('notes: $notes, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    type,
    takeoffWeightGrams,
    maxSpeedMetersPerSecond,
    notes,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Drone &&
          other.id == this.id &&
          other.name == this.name &&
          other.type == this.type &&
          other.takeoffWeightGrams == this.takeoffWeightGrams &&
          other.maxSpeedMetersPerSecond == this.maxSpeedMetersPerSecond &&
          other.notes == this.notes &&
          other.createdAt == this.createdAt);
}

class DronesCompanion extends UpdateCompanion<Drone> {
  final Value<int> id;
  final Value<String> name;
  final Value<String> type;
  final Value<double?> takeoffWeightGrams;
  final Value<double?> maxSpeedMetersPerSecond;
  final Value<String?> notes;
  final Value<DateTime> createdAt;
  const DronesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.type = const Value.absent(),
    this.takeoffWeightGrams = const Value.absent(),
    this.maxSpeedMetersPerSecond = const Value.absent(),
    this.notes = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  DronesCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    this.type = const Value.absent(),
    this.takeoffWeightGrams = const Value.absent(),
    this.maxSpeedMetersPerSecond = const Value.absent(),
    this.notes = const Value.absent(),
    this.createdAt = const Value.absent(),
  }) : name = Value(name);
  static Insertable<Drone> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? type,
    Expression<double>? takeoffWeightGrams,
    Expression<double>? maxSpeedMetersPerSecond,
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
          ..write('notes: $notes, ')
          ..write('createdAt: $createdAt')
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
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
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
      )!,
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
  final int cycleCount;
  final String? notes;
  const Battery({
    required this.id,
    required this.name,
    required this.chemistry,
    required this.cellCount,
    required this.capacityMah,
    this.weightGrams,
    required this.cycleCount,
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
    map['cycle_count'] = Variable<int>(cycleCount);
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
      cycleCount: Value(cycleCount),
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
      cycleCount: serializer.fromJson<int>(json['cycleCount']),
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
      'cycleCount': serializer.toJson<int>(cycleCount),
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
    int? cycleCount,
    Value<String?> notes = const Value.absent(),
  }) => Battery(
    id: id ?? this.id,
    name: name ?? this.name,
    chemistry: chemistry ?? this.chemistry,
    cellCount: cellCount ?? this.cellCount,
    capacityMah: capacityMah ?? this.capacityMah,
    weightGrams: weightGrams.present ? weightGrams.value : this.weightGrams,
    cycleCount: cycleCount ?? this.cycleCount,
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
          other.notes == this.notes);
}

class BatteriesCompanion extends UpdateCompanion<Battery> {
  final Value<int> id;
  final Value<String> name;
  final Value<String> chemistry;
  final Value<int> cellCount;
  final Value<int> capacityMah;
  final Value<double?> weightGrams;
  final Value<int> cycleCount;
  final Value<String?> notes;
  const BatteriesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.chemistry = const Value.absent(),
    this.cellCount = const Value.absent(),
    this.capacityMah = const Value.absent(),
    this.weightGrams = const Value.absent(),
    this.cycleCount = const Value.absent(),
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
    Value<int>? cycleCount,
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
          ..write('notes: $notes')
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
  late final $SpotPhotosTable spotPhotos = $SpotPhotosTable(this);
  late final $DronesTable drones = $DronesTable(this);
  late final $BatteriesTable batteries = $BatteriesTable(this);
  late final $RadioEquipmentTable radioEquipment = $RadioEquipmentTable(this);
  late final $FlightPlansTable flightPlans = $FlightPlansTable(this);
  late final $FlightWaypointsTable flightWaypoints = $FlightWaypointsTable(
    this,
  );
  late final $AppSettingsTable appSettings = $AppSettingsTable(this);
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
    spotPhotos,
    drones,
    batteries,
    radioEquipment,
    flightPlans,
    flightWaypoints,
    appSettings,
    spotPhotosSpotId,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
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
  Value<bool> isFavorite,
  Value<DateTime> createdAt,
});
typedef $$SpotsTableUpdateCompanionBuilder = SpotsCompanion Function({
  Value<int> id,
  Value<String> name,
  Value<double> latitude,
  Value<double> longitude,
  Value<String?> notes,
  Value<bool> isFavorite,
  Value<DateTime> createdAt,
});

final class $$SpotsTableReferences
    extends BaseReferences<_$FpvDatabase, $SpotsTable, Spot> {
  $$SpotsTableReferences(super.$_db, super.$_table, super.$_typedResult);

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

  ColumnFilters<bool> get isFavorite => $composableBuilder(
    column: $table.isFavorite,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

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

  GeneratedColumn<bool> get isFavorite => $composableBuilder(
    column: $table.isFavorite,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

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
          PrefetchHooks Function({bool spotPhotosRefs, bool flightPlansRefs})
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
                Value<bool> isFavorite = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => SpotsCompanion(
                id: id,
                name: name,
                latitude: latitude,
                longitude: longitude,
                notes: notes,
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
                Value<bool> isFavorite = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => SpotsCompanion.insert(
                id: id,
                name: name,
                latitude: latitude,
                longitude: longitude,
                notes: notes,
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
              ({spotPhotosRefs = false, flightPlansRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (spotPhotosRefs) db.spotPhotos,
                    if (flightPlansRefs) db.flightPlans,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
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
      PrefetchHooks Function({bool spotPhotosRefs, bool flightPlansRefs})
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
  Value<String?> notes,
  Value<DateTime> createdAt,
});
typedef $$DronesTableUpdateCompanionBuilder = DronesCompanion Function({
  Value<int> id,
  Value<String> name,
  Value<String> type,
  Value<double?> takeoffWeightGrams,
  Value<double?> maxSpeedMetersPerSecond,
  Value<String?> notes,
  Value<DateTime> createdAt,
});

final class $$DronesTableReferences
    extends BaseReferences<_$FpvDatabase, $DronesTable, Drone> {
  $$DronesTableReferences(super.$_db, super.$_table, super.$_typedResult);

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

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

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

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

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
          PrefetchHooks Function({bool flightPlansRefs})
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
                Value<String?> notes = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => DronesCompanion(
                id: id,
                name: name,
                type: type,
                takeoffWeightGrams: takeoffWeightGrams,
                maxSpeedMetersPerSecond: maxSpeedMetersPerSecond,
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
                Value<String?> notes = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => DronesCompanion.insert(
                id: id,
                name: name,
                type: type,
                takeoffWeightGrams: takeoffWeightGrams,
                maxSpeedMetersPerSecond: maxSpeedMetersPerSecond,
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
          prefetchHooksCallback: ({flightPlansRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (flightPlansRefs) db.flightPlans],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (flightPlansRefs)
                    await $_getPrefetchedData<Drone, $DronesTable, FlightPlan>(
                      currentTable: table,
                      referencedTable: $$DronesTableReferences
                          ._flightPlansRefsTable(db),
                      managerFromTypedResult: (p0) => $$DronesTableReferences(
                        db,
                        table,
                        p0,
                      ).flightPlansRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.droneId == item.id),
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
      PrefetchHooks Function({bool flightPlansRefs})
    >;
typedef $$BatteriesTableCreateCompanionBuilder = BatteriesCompanion Function({
  Value<int> id,
  required String name,
  Value<String> chemistry,
  required int cellCount,
  required int capacityMah,
  Value<double?> weightGrams,
  Value<int> cycleCount,
  Value<String?> notes,
});
typedef $$BatteriesTableUpdateCompanionBuilder = BatteriesCompanion Function({
  Value<int> id,
  Value<String> name,
  Value<String> chemistry,
  Value<int> cellCount,
  Value<int> capacityMah,
  Value<double?> weightGrams,
  Value<int> cycleCount,
  Value<String?> notes,
});

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

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );
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

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );
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

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);
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
          (Battery, BaseReferences<_$FpvDatabase, $BatteriesTable, Battery>),
          Battery,
          PrefetchHooks Function()
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
                Value<int> cycleCount = const Value.absent(),
                Value<String?> notes = const Value.absent(),
              }) => BatteriesCompanion(
                id: id,
                name: name,
                chemistry: chemistry,
                cellCount: cellCount,
                capacityMah: capacityMah,
                weightGrams: weightGrams,
                cycleCount: cycleCount,
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
                Value<int> cycleCount = const Value.absent(),
                Value<String?> notes = const Value.absent(),
              }) => BatteriesCompanion.insert(
                id: id,
                name: name,
                chemistry: chemistry,
                cellCount: cellCount,
                capacityMah: capacityMah,
                weightGrams: weightGrams,
                cycleCount: cycleCount,
                notes: notes,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$BatteriesTable, Battery>(table),
                  BaseReferences<_$FpvDatabase, $BatteriesTable, Battery>(
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
      (Battery, BaseReferences<_$FpvDatabase, $BatteriesTable, Battery>),
      Battery,
      PrefetchHooks Function()
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
                flightWaypointsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
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
        bool flightWaypointsRefs,
      })
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
  $$SpotPhotosTableTableManager get spotPhotos =>
      $$SpotPhotosTableTableManager(_db, _db.spotPhotos);
  $$DronesTableTableManager get drones =>
      $$DronesTableTableManager(_db, _db.drones);
  $$BatteriesTableTableManager get batteries =>
      $$BatteriesTableTableManager(_db, _db.batteries);
  $$RadioEquipmentTableTableManager get radioEquipment =>
      $$RadioEquipmentTableTableManager(_db, _db.radioEquipment);
  $$FlightPlansTableTableManager get flightPlans =>
      $$FlightPlansTableTableManager(_db, _db.flightPlans);
  $$FlightWaypointsTableTableManager get flightWaypoints =>
      $$FlightWaypointsTableTableManager(_db, _db.flightWaypoints);
  $$AppSettingsTableTableManager get appSettings =>
      $$AppSettingsTableTableManager(_db, _db.appSettings);
}
