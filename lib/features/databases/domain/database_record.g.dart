// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database_record.dart';

// **************************************************************************
// _IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, invalid_use_of_protected_member, lines_longer_than_80_chars, constant_identifier_names, avoid_js_rounded_ints, no_leading_underscores_for_local_identifiers, require_trailing_commas, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_in_if_null_operators, library_private_types_in_public_api, prefer_const_constructors
// ignore_for_file: type=lint

extension GetDatabaseRecordCollection on Isar {
  IsarCollection<int, DatabaseRecord> get databaseRecords => this.collection();
}

final DatabaseRecordSchema = IsarGeneratedSchema(
  schema: IsarSchema(
    name: 'DatabaseRecord',
    idName: 'id',
    embedded: false,
    properties: [
      IsarPropertySchema(name: 'name', type: IsarType.string),
      IsarPropertySchema(name: 'username', type: IsarType.string),
      IsarPropertySchema(name: 'password', type: IsarType.string),
      IsarPropertySchema(name: 'engineAppId', type: IsarType.string),
      IsarPropertySchema(name: 'note', type: IsarType.string),
      IsarPropertySchema(name: 'createdAt', type: IsarType.dateTime),
    ],
    indexes: [
      IsarIndexSchema(
        name: 'name',
        properties: ["name"],
        unique: true,
        hash: false,
      ),
    ],
  ),
  converter: IsarObjectConverter<int, DatabaseRecord>(
    serialize: serializeDatabaseRecord,
    deserialize: deserializeDatabaseRecord,
    deserializeProperty: deserializeDatabaseRecordProp,
  ),
  getEmbeddedSchemas: () => [],
);

@isarProtected
int serializeDatabaseRecord(IsarWriter writer, DatabaseRecord object) {
  IsarCore.writeString(writer, 1, object.name);
  IsarCore.writeString(writer, 2, object.username);
  IsarCore.writeString(writer, 3, object.password);
  IsarCore.writeString(writer, 4, object.engineAppId);
  {
    final value = object.note;
    if (value == null) {
      IsarCore.writeNull(writer, 5);
    } else {
      IsarCore.writeString(writer, 5, value);
    }
  }
  IsarCore.writeLong(
    writer,
    6,
    object.createdAt.toUtc().microsecondsSinceEpoch,
  );
  return object.id;
}

@isarProtected
DatabaseRecord deserializeDatabaseRecord(IsarReader reader) {
  final object = DatabaseRecord();
  object.id = IsarCore.readId(reader);
  object.name = IsarCore.readString(reader, 1) ?? '';
  object.username = IsarCore.readString(reader, 2) ?? '';
  object.password = IsarCore.readString(reader, 3) ?? '';
  object.engineAppId = IsarCore.readString(reader, 4) ?? '';
  object.note = IsarCore.readString(reader, 5);
  {
    final value = IsarCore.readLong(reader, 6);
    if (value == -9223372036854775808) {
      object.createdAt = DateTime.fromMillisecondsSinceEpoch(
        0,
        isUtc: true,
      ).toLocal();
    } else {
      object.createdAt = DateTime.fromMicrosecondsSinceEpoch(
        value,
        isUtc: true,
      ).toLocal();
    }
  }
  return object;
}

@isarProtected
dynamic deserializeDatabaseRecordProp(IsarReader reader, int property) {
  switch (property) {
    case 0:
      return IsarCore.readId(reader);
    case 1:
      return IsarCore.readString(reader, 1) ?? '';
    case 2:
      return IsarCore.readString(reader, 2) ?? '';
    case 3:
      return IsarCore.readString(reader, 3) ?? '';
    case 4:
      return IsarCore.readString(reader, 4) ?? '';
    case 5:
      return IsarCore.readString(reader, 5);
    case 6:
      {
        final value = IsarCore.readLong(reader, 6);
        if (value == -9223372036854775808) {
          return DateTime.fromMillisecondsSinceEpoch(0, isUtc: true).toLocal();
        } else {
          return DateTime.fromMicrosecondsSinceEpoch(
            value,
            isUtc: true,
          ).toLocal();
        }
      }
    default:
      throw ArgumentError('Unknown property: $property');
  }
}

sealed class _DatabaseRecordUpdate {
  bool call({
    required int id,
    String? name,
    String? username,
    String? password,
    String? engineAppId,
    String? note,
    DateTime? createdAt,
  });
}

class _DatabaseRecordUpdateImpl implements _DatabaseRecordUpdate {
  const _DatabaseRecordUpdateImpl(this.collection);

  final IsarCollection<int, DatabaseRecord> collection;

  @override
  bool call({
    required int id,
    Object? name = ignore,
    Object? username = ignore,
    Object? password = ignore,
    Object? engineAppId = ignore,
    Object? note = ignore,
    Object? createdAt = ignore,
  }) {
    return collection.updateProperties(
          [id],
          {
            if (name != ignore) 1: name as String?,
            if (username != ignore) 2: username as String?,
            if (password != ignore) 3: password as String?,
            if (engineAppId != ignore) 4: engineAppId as String?,
            if (note != ignore) 5: note as String?,
            if (createdAt != ignore) 6: createdAt as DateTime?,
          },
        ) >
        0;
  }
}

sealed class _DatabaseRecordUpdateAll {
  int call({
    required List<int> id,
    String? name,
    String? username,
    String? password,
    String? engineAppId,
    String? note,
    DateTime? createdAt,
  });
}

class _DatabaseRecordUpdateAllImpl implements _DatabaseRecordUpdateAll {
  const _DatabaseRecordUpdateAllImpl(this.collection);

  final IsarCollection<int, DatabaseRecord> collection;

  @override
  int call({
    required List<int> id,
    Object? name = ignore,
    Object? username = ignore,
    Object? password = ignore,
    Object? engineAppId = ignore,
    Object? note = ignore,
    Object? createdAt = ignore,
  }) {
    return collection.updateProperties(id, {
      if (name != ignore) 1: name as String?,
      if (username != ignore) 2: username as String?,
      if (password != ignore) 3: password as String?,
      if (engineAppId != ignore) 4: engineAppId as String?,
      if (note != ignore) 5: note as String?,
      if (createdAt != ignore) 6: createdAt as DateTime?,
    });
  }
}

extension DatabaseRecordUpdate on IsarCollection<int, DatabaseRecord> {
  _DatabaseRecordUpdate get update => _DatabaseRecordUpdateImpl(this);

  _DatabaseRecordUpdateAll get updateAll => _DatabaseRecordUpdateAllImpl(this);
}

sealed class _DatabaseRecordQueryUpdate {
  int call({
    String? name,
    String? username,
    String? password,
    String? engineAppId,
    String? note,
    DateTime? createdAt,
  });
}

class _DatabaseRecordQueryUpdateImpl implements _DatabaseRecordQueryUpdate {
  const _DatabaseRecordQueryUpdateImpl(this.query, {this.limit});

  final IsarQuery<DatabaseRecord> query;
  final int? limit;

  @override
  int call({
    Object? name = ignore,
    Object? username = ignore,
    Object? password = ignore,
    Object? engineAppId = ignore,
    Object? note = ignore,
    Object? createdAt = ignore,
  }) {
    return query.updateProperties(limit: limit, {
      if (name != ignore) 1: name as String?,
      if (username != ignore) 2: username as String?,
      if (password != ignore) 3: password as String?,
      if (engineAppId != ignore) 4: engineAppId as String?,
      if (note != ignore) 5: note as String?,
      if (createdAt != ignore) 6: createdAt as DateTime?,
    });
  }
}

extension DatabaseRecordQueryUpdate on IsarQuery<DatabaseRecord> {
  _DatabaseRecordQueryUpdate get updateFirst =>
      _DatabaseRecordQueryUpdateImpl(this, limit: 1);

  _DatabaseRecordQueryUpdate get updateAll =>
      _DatabaseRecordQueryUpdateImpl(this);
}

class _DatabaseRecordQueryBuilderUpdateImpl
    implements _DatabaseRecordQueryUpdate {
  const _DatabaseRecordQueryBuilderUpdateImpl(this.query, {this.limit});

  final QueryBuilder<DatabaseRecord, DatabaseRecord, QOperations> query;
  final int? limit;

  @override
  int call({
    Object? name = ignore,
    Object? username = ignore,
    Object? password = ignore,
    Object? engineAppId = ignore,
    Object? note = ignore,
    Object? createdAt = ignore,
  }) {
    final q = query.build();
    try {
      return q.updateProperties(limit: limit, {
        if (name != ignore) 1: name as String?,
        if (username != ignore) 2: username as String?,
        if (password != ignore) 3: password as String?,
        if (engineAppId != ignore) 4: engineAppId as String?,
        if (note != ignore) 5: note as String?,
        if (createdAt != ignore) 6: createdAt as DateTime?,
      });
    } finally {
      q.close();
    }
  }
}

extension DatabaseRecordQueryBuilderUpdate
    on QueryBuilder<DatabaseRecord, DatabaseRecord, QOperations> {
  _DatabaseRecordQueryUpdate get updateFirst =>
      _DatabaseRecordQueryBuilderUpdateImpl(this, limit: 1);

  _DatabaseRecordQueryUpdate get updateAll =>
      _DatabaseRecordQueryBuilderUpdateImpl(this);
}

extension DatabaseRecordQueryFilter
    on QueryBuilder<DatabaseRecord, DatabaseRecord, QFilterCondition> {
  QueryBuilder<DatabaseRecord, DatabaseRecord, QAfterFilterCondition> idEqualTo(
    int value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(property: 0, value: value),
      );
    });
  }

  QueryBuilder<DatabaseRecord, DatabaseRecord, QAfterFilterCondition>
  idGreaterThan(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterCondition(property: 0, value: value),
      );
    });
  }

  QueryBuilder<DatabaseRecord, DatabaseRecord, QAfterFilterCondition>
  idGreaterThanOrEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterOrEqualCondition(property: 0, value: value),
      );
    });
  }

  QueryBuilder<DatabaseRecord, DatabaseRecord, QAfterFilterCondition>
  idLessThan(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(LessCondition(property: 0, value: value));
    });
  }

  QueryBuilder<DatabaseRecord, DatabaseRecord, QAfterFilterCondition>
  idLessThanOrEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessOrEqualCondition(property: 0, value: value),
      );
    });
  }

  QueryBuilder<DatabaseRecord, DatabaseRecord, QAfterFilterCondition> idBetween(
    int lower,
    int upper,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        BetweenCondition(property: 0, lower: lower, upper: upper),
      );
    });
  }

  QueryBuilder<DatabaseRecord, DatabaseRecord, QAfterFilterCondition>
  nameEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(property: 1, value: value, caseSensitive: caseSensitive),
      );
    });
  }

  QueryBuilder<DatabaseRecord, DatabaseRecord, QAfterFilterCondition>
  nameGreaterThan(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterCondition(
          property: 1,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<DatabaseRecord, DatabaseRecord, QAfterFilterCondition>
  nameGreaterThanOrEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterOrEqualCondition(
          property: 1,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<DatabaseRecord, DatabaseRecord, QAfterFilterCondition>
  nameLessThan(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessCondition(property: 1, value: value, caseSensitive: caseSensitive),
      );
    });
  }

  QueryBuilder<DatabaseRecord, DatabaseRecord, QAfterFilterCondition>
  nameLessThanOrEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessOrEqualCondition(
          property: 1,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<DatabaseRecord, DatabaseRecord, QAfterFilterCondition>
  nameBetween(String lower, String upper, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        BetweenCondition(
          property: 1,
          lower: lower,
          upper: upper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<DatabaseRecord, DatabaseRecord, QAfterFilterCondition>
  nameStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        StartsWithCondition(
          property: 1,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<DatabaseRecord, DatabaseRecord, QAfterFilterCondition>
  nameEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EndsWithCondition(
          property: 1,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<DatabaseRecord, DatabaseRecord, QAfterFilterCondition>
  nameContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        ContainsCondition(
          property: 1,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<DatabaseRecord, DatabaseRecord, QAfterFilterCondition>
  nameMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        MatchesCondition(
          property: 1,
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<DatabaseRecord, DatabaseRecord, QAfterFilterCondition>
  nameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const EqualCondition(property: 1, value: ''),
      );
    });
  }

  QueryBuilder<DatabaseRecord, DatabaseRecord, QAfterFilterCondition>
  nameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const GreaterCondition(property: 1, value: ''),
      );
    });
  }

  QueryBuilder<DatabaseRecord, DatabaseRecord, QAfterFilterCondition>
  usernameEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(property: 2, value: value, caseSensitive: caseSensitive),
      );
    });
  }

  QueryBuilder<DatabaseRecord, DatabaseRecord, QAfterFilterCondition>
  usernameGreaterThan(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterCondition(
          property: 2,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<DatabaseRecord, DatabaseRecord, QAfterFilterCondition>
  usernameGreaterThanOrEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterOrEqualCondition(
          property: 2,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<DatabaseRecord, DatabaseRecord, QAfterFilterCondition>
  usernameLessThan(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessCondition(property: 2, value: value, caseSensitive: caseSensitive),
      );
    });
  }

  QueryBuilder<DatabaseRecord, DatabaseRecord, QAfterFilterCondition>
  usernameLessThanOrEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessOrEqualCondition(
          property: 2,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<DatabaseRecord, DatabaseRecord, QAfterFilterCondition>
  usernameBetween(String lower, String upper, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        BetweenCondition(
          property: 2,
          lower: lower,
          upper: upper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<DatabaseRecord, DatabaseRecord, QAfterFilterCondition>
  usernameStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        StartsWithCondition(
          property: 2,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<DatabaseRecord, DatabaseRecord, QAfterFilterCondition>
  usernameEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EndsWithCondition(
          property: 2,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<DatabaseRecord, DatabaseRecord, QAfterFilterCondition>
  usernameContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        ContainsCondition(
          property: 2,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<DatabaseRecord, DatabaseRecord, QAfterFilterCondition>
  usernameMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        MatchesCondition(
          property: 2,
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<DatabaseRecord, DatabaseRecord, QAfterFilterCondition>
  usernameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const EqualCondition(property: 2, value: ''),
      );
    });
  }

  QueryBuilder<DatabaseRecord, DatabaseRecord, QAfterFilterCondition>
  usernameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const GreaterCondition(property: 2, value: ''),
      );
    });
  }

  QueryBuilder<DatabaseRecord, DatabaseRecord, QAfterFilterCondition>
  passwordEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(property: 3, value: value, caseSensitive: caseSensitive),
      );
    });
  }

  QueryBuilder<DatabaseRecord, DatabaseRecord, QAfterFilterCondition>
  passwordGreaterThan(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterCondition(
          property: 3,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<DatabaseRecord, DatabaseRecord, QAfterFilterCondition>
  passwordGreaterThanOrEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterOrEqualCondition(
          property: 3,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<DatabaseRecord, DatabaseRecord, QAfterFilterCondition>
  passwordLessThan(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessCondition(property: 3, value: value, caseSensitive: caseSensitive),
      );
    });
  }

  QueryBuilder<DatabaseRecord, DatabaseRecord, QAfterFilterCondition>
  passwordLessThanOrEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessOrEqualCondition(
          property: 3,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<DatabaseRecord, DatabaseRecord, QAfterFilterCondition>
  passwordBetween(String lower, String upper, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        BetweenCondition(
          property: 3,
          lower: lower,
          upper: upper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<DatabaseRecord, DatabaseRecord, QAfterFilterCondition>
  passwordStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        StartsWithCondition(
          property: 3,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<DatabaseRecord, DatabaseRecord, QAfterFilterCondition>
  passwordEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EndsWithCondition(
          property: 3,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<DatabaseRecord, DatabaseRecord, QAfterFilterCondition>
  passwordContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        ContainsCondition(
          property: 3,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<DatabaseRecord, DatabaseRecord, QAfterFilterCondition>
  passwordMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        MatchesCondition(
          property: 3,
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<DatabaseRecord, DatabaseRecord, QAfterFilterCondition>
  passwordIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const EqualCondition(property: 3, value: ''),
      );
    });
  }

  QueryBuilder<DatabaseRecord, DatabaseRecord, QAfterFilterCondition>
  passwordIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const GreaterCondition(property: 3, value: ''),
      );
    });
  }

  QueryBuilder<DatabaseRecord, DatabaseRecord, QAfterFilterCondition>
  engineAppIdEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(property: 4, value: value, caseSensitive: caseSensitive),
      );
    });
  }

  QueryBuilder<DatabaseRecord, DatabaseRecord, QAfterFilterCondition>
  engineAppIdGreaterThan(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterCondition(
          property: 4,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<DatabaseRecord, DatabaseRecord, QAfterFilterCondition>
  engineAppIdGreaterThanOrEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterOrEqualCondition(
          property: 4,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<DatabaseRecord, DatabaseRecord, QAfterFilterCondition>
  engineAppIdLessThan(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessCondition(property: 4, value: value, caseSensitive: caseSensitive),
      );
    });
  }

  QueryBuilder<DatabaseRecord, DatabaseRecord, QAfterFilterCondition>
  engineAppIdLessThanOrEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessOrEqualCondition(
          property: 4,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<DatabaseRecord, DatabaseRecord, QAfterFilterCondition>
  engineAppIdBetween(String lower, String upper, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        BetweenCondition(
          property: 4,
          lower: lower,
          upper: upper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<DatabaseRecord, DatabaseRecord, QAfterFilterCondition>
  engineAppIdStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        StartsWithCondition(
          property: 4,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<DatabaseRecord, DatabaseRecord, QAfterFilterCondition>
  engineAppIdEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EndsWithCondition(
          property: 4,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<DatabaseRecord, DatabaseRecord, QAfterFilterCondition>
  engineAppIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        ContainsCondition(
          property: 4,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<DatabaseRecord, DatabaseRecord, QAfterFilterCondition>
  engineAppIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        MatchesCondition(
          property: 4,
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<DatabaseRecord, DatabaseRecord, QAfterFilterCondition>
  engineAppIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const EqualCondition(property: 4, value: ''),
      );
    });
  }

  QueryBuilder<DatabaseRecord, DatabaseRecord, QAfterFilterCondition>
  engineAppIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const GreaterCondition(property: 4, value: ''),
      );
    });
  }

  QueryBuilder<DatabaseRecord, DatabaseRecord, QAfterFilterCondition>
  noteIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const IsNullCondition(property: 5));
    });
  }

  QueryBuilder<DatabaseRecord, DatabaseRecord, QAfterFilterCondition>
  noteIsNotNull() {
    return QueryBuilder.apply(not(), (query) {
      return query.addFilterCondition(const IsNullCondition(property: 5));
    });
  }

  QueryBuilder<DatabaseRecord, DatabaseRecord, QAfterFilterCondition>
  noteEqualTo(String? value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(property: 5, value: value, caseSensitive: caseSensitive),
      );
    });
  }

  QueryBuilder<DatabaseRecord, DatabaseRecord, QAfterFilterCondition>
  noteGreaterThan(String? value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterCondition(
          property: 5,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<DatabaseRecord, DatabaseRecord, QAfterFilterCondition>
  noteGreaterThanOrEqualTo(String? value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterOrEqualCondition(
          property: 5,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<DatabaseRecord, DatabaseRecord, QAfterFilterCondition>
  noteLessThan(String? value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessCondition(property: 5, value: value, caseSensitive: caseSensitive),
      );
    });
  }

  QueryBuilder<DatabaseRecord, DatabaseRecord, QAfterFilterCondition>
  noteLessThanOrEqualTo(String? value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessOrEqualCondition(
          property: 5,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<DatabaseRecord, DatabaseRecord, QAfterFilterCondition>
  noteBetween(String? lower, String? upper, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        BetweenCondition(
          property: 5,
          lower: lower,
          upper: upper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<DatabaseRecord, DatabaseRecord, QAfterFilterCondition>
  noteStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        StartsWithCondition(
          property: 5,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<DatabaseRecord, DatabaseRecord, QAfterFilterCondition>
  noteEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EndsWithCondition(
          property: 5,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<DatabaseRecord, DatabaseRecord, QAfterFilterCondition>
  noteContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        ContainsCondition(
          property: 5,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<DatabaseRecord, DatabaseRecord, QAfterFilterCondition>
  noteMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        MatchesCondition(
          property: 5,
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<DatabaseRecord, DatabaseRecord, QAfterFilterCondition>
  noteIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const EqualCondition(property: 5, value: ''),
      );
    });
  }

  QueryBuilder<DatabaseRecord, DatabaseRecord, QAfterFilterCondition>
  noteIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const GreaterCondition(property: 5, value: ''),
      );
    });
  }

  QueryBuilder<DatabaseRecord, DatabaseRecord, QAfterFilterCondition>
  createdAtEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(property: 6, value: value),
      );
    });
  }

  QueryBuilder<DatabaseRecord, DatabaseRecord, QAfterFilterCondition>
  createdAtGreaterThan(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterCondition(property: 6, value: value),
      );
    });
  }

  QueryBuilder<DatabaseRecord, DatabaseRecord, QAfterFilterCondition>
  createdAtGreaterThanOrEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterOrEqualCondition(property: 6, value: value),
      );
    });
  }

  QueryBuilder<DatabaseRecord, DatabaseRecord, QAfterFilterCondition>
  createdAtLessThan(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(LessCondition(property: 6, value: value));
    });
  }

  QueryBuilder<DatabaseRecord, DatabaseRecord, QAfterFilterCondition>
  createdAtLessThanOrEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessOrEqualCondition(property: 6, value: value),
      );
    });
  }

  QueryBuilder<DatabaseRecord, DatabaseRecord, QAfterFilterCondition>
  createdAtBetween(DateTime lower, DateTime upper) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        BetweenCondition(property: 6, lower: lower, upper: upper),
      );
    });
  }
}

extension DatabaseRecordQueryObject
    on QueryBuilder<DatabaseRecord, DatabaseRecord, QFilterCondition> {}

extension DatabaseRecordQuerySortBy
    on QueryBuilder<DatabaseRecord, DatabaseRecord, QSortBy> {
  QueryBuilder<DatabaseRecord, DatabaseRecord, QAfterSortBy> sortById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(0);
    });
  }

  QueryBuilder<DatabaseRecord, DatabaseRecord, QAfterSortBy> sortByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(0, sort: Sort.desc);
    });
  }

  QueryBuilder<DatabaseRecord, DatabaseRecord, QAfterSortBy> sortByName({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(1, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<DatabaseRecord, DatabaseRecord, QAfterSortBy> sortByNameDesc({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(1, sort: Sort.desc, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<DatabaseRecord, DatabaseRecord, QAfterSortBy> sortByUsername({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(2, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<DatabaseRecord, DatabaseRecord, QAfterSortBy>
  sortByUsernameDesc({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(2, sort: Sort.desc, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<DatabaseRecord, DatabaseRecord, QAfterSortBy> sortByPassword({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(3, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<DatabaseRecord, DatabaseRecord, QAfterSortBy>
  sortByPasswordDesc({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(3, sort: Sort.desc, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<DatabaseRecord, DatabaseRecord, QAfterSortBy> sortByEngineAppId({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(4, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<DatabaseRecord, DatabaseRecord, QAfterSortBy>
  sortByEngineAppIdDesc({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(4, sort: Sort.desc, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<DatabaseRecord, DatabaseRecord, QAfterSortBy> sortByNote({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(5, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<DatabaseRecord, DatabaseRecord, QAfterSortBy> sortByNoteDesc({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(5, sort: Sort.desc, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<DatabaseRecord, DatabaseRecord, QAfterSortBy> sortByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(6);
    });
  }

  QueryBuilder<DatabaseRecord, DatabaseRecord, QAfterSortBy>
  sortByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(6, sort: Sort.desc);
    });
  }
}

extension DatabaseRecordQuerySortThenBy
    on QueryBuilder<DatabaseRecord, DatabaseRecord, QSortThenBy> {
  QueryBuilder<DatabaseRecord, DatabaseRecord, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(0);
    });
  }

  QueryBuilder<DatabaseRecord, DatabaseRecord, QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(0, sort: Sort.desc);
    });
  }

  QueryBuilder<DatabaseRecord, DatabaseRecord, QAfterSortBy> thenByName({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(1, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<DatabaseRecord, DatabaseRecord, QAfterSortBy> thenByNameDesc({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(1, sort: Sort.desc, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<DatabaseRecord, DatabaseRecord, QAfterSortBy> thenByUsername({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(2, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<DatabaseRecord, DatabaseRecord, QAfterSortBy>
  thenByUsernameDesc({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(2, sort: Sort.desc, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<DatabaseRecord, DatabaseRecord, QAfterSortBy> thenByPassword({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(3, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<DatabaseRecord, DatabaseRecord, QAfterSortBy>
  thenByPasswordDesc({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(3, sort: Sort.desc, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<DatabaseRecord, DatabaseRecord, QAfterSortBy> thenByEngineAppId({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(4, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<DatabaseRecord, DatabaseRecord, QAfterSortBy>
  thenByEngineAppIdDesc({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(4, sort: Sort.desc, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<DatabaseRecord, DatabaseRecord, QAfterSortBy> thenByNote({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(5, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<DatabaseRecord, DatabaseRecord, QAfterSortBy> thenByNoteDesc({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(5, sort: Sort.desc, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<DatabaseRecord, DatabaseRecord, QAfterSortBy> thenByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(6);
    });
  }

  QueryBuilder<DatabaseRecord, DatabaseRecord, QAfterSortBy>
  thenByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(6, sort: Sort.desc);
    });
  }
}

extension DatabaseRecordQueryWhereDistinct
    on QueryBuilder<DatabaseRecord, DatabaseRecord, QDistinct> {
  QueryBuilder<DatabaseRecord, DatabaseRecord, QAfterDistinct> distinctByName({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(1, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<DatabaseRecord, DatabaseRecord, QAfterDistinct>
  distinctByUsername({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(2, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<DatabaseRecord, DatabaseRecord, QAfterDistinct>
  distinctByPassword({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(3, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<DatabaseRecord, DatabaseRecord, QAfterDistinct>
  distinctByEngineAppId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(4, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<DatabaseRecord, DatabaseRecord, QAfterDistinct> distinctByNote({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(5, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<DatabaseRecord, DatabaseRecord, QAfterDistinct>
  distinctByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(6);
    });
  }
}

extension DatabaseRecordQueryProperty1
    on QueryBuilder<DatabaseRecord, DatabaseRecord, QProperty> {
  QueryBuilder<DatabaseRecord, int, QAfterProperty> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(0);
    });
  }

  QueryBuilder<DatabaseRecord, String, QAfterProperty> nameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(1);
    });
  }

  QueryBuilder<DatabaseRecord, String, QAfterProperty> usernameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(2);
    });
  }

  QueryBuilder<DatabaseRecord, String, QAfterProperty> passwordProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(3);
    });
  }

  QueryBuilder<DatabaseRecord, String, QAfterProperty> engineAppIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(4);
    });
  }

  QueryBuilder<DatabaseRecord, String?, QAfterProperty> noteProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(5);
    });
  }

  QueryBuilder<DatabaseRecord, DateTime, QAfterProperty> createdAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(6);
    });
  }
}

extension DatabaseRecordQueryProperty2<R>
    on QueryBuilder<DatabaseRecord, R, QAfterProperty> {
  QueryBuilder<DatabaseRecord, (R, int), QAfterProperty> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(0);
    });
  }

  QueryBuilder<DatabaseRecord, (R, String), QAfterProperty> nameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(1);
    });
  }

  QueryBuilder<DatabaseRecord, (R, String), QAfterProperty> usernameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(2);
    });
  }

  QueryBuilder<DatabaseRecord, (R, String), QAfterProperty> passwordProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(3);
    });
  }

  QueryBuilder<DatabaseRecord, (R, String), QAfterProperty>
  engineAppIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(4);
    });
  }

  QueryBuilder<DatabaseRecord, (R, String?), QAfterProperty> noteProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(5);
    });
  }

  QueryBuilder<DatabaseRecord, (R, DateTime), QAfterProperty>
  createdAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(6);
    });
  }
}

extension DatabaseRecordQueryProperty3<R1, R2>
    on QueryBuilder<DatabaseRecord, (R1, R2), QAfterProperty> {
  QueryBuilder<DatabaseRecord, (R1, R2, int), QOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(0);
    });
  }

  QueryBuilder<DatabaseRecord, (R1, R2, String), QOperations> nameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(1);
    });
  }

  QueryBuilder<DatabaseRecord, (R1, R2, String), QOperations>
  usernameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(2);
    });
  }

  QueryBuilder<DatabaseRecord, (R1, R2, String), QOperations>
  passwordProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(3);
    });
  }

  QueryBuilder<DatabaseRecord, (R1, R2, String), QOperations>
  engineAppIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(4);
    });
  }

  QueryBuilder<DatabaseRecord, (R1, R2, String?), QOperations> noteProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(5);
    });
  }

  QueryBuilder<DatabaseRecord, (R1, R2, DateTime), QOperations>
  createdAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(6);
    });
  }
}
