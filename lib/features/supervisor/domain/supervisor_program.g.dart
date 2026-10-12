// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'supervisor_program.dart';

// **************************************************************************
// _IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, invalid_use_of_protected_member, lines_longer_than_80_chars, constant_identifier_names, avoid_js_rounded_ints, no_leading_underscores_for_local_identifiers, require_trailing_commas, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_in_if_null_operators, library_private_types_in_public_api, prefer_const_constructors
// ignore_for_file: type=lint

extension GetSupervisorProgramCollection on Isar {
  IsarCollection<int, SupervisorProgram> get supervisorPrograms =>
      this.collection();
}

final SupervisorProgramSchema = IsarGeneratedSchema(
  schema: IsarSchema(
    name: 'SupervisorProgram',
    idName: 'id',
    embedded: false,
    properties: [
      IsarPropertySchema(name: 'name', type: IsarType.string),
      IsarPropertySchema(name: 'command', type: IsarType.string),
      IsarPropertySchema(name: 'workingDir', type: IsarType.string),
      IsarPropertySchema(name: 'environmentJson', type: IsarType.string),
      IsarPropertySchema(name: 'autoStart', type: IsarType.bool),
      IsarPropertySchema(name: 'autoRestart', type: IsarType.bool),
      IsarPropertySchema(name: 'maxRestarts', type: IsarType.long),
      IsarPropertySchema(name: 'restartWindowSeconds', type: IsarType.long),
      IsarPropertySchema(name: 'restartDelaySeconds', type: IsarType.long),
      IsarPropertySchema(name: 'enabled', type: IsarType.bool),
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
  converter: IsarObjectConverter<int, SupervisorProgram>(
    serialize: serializeSupervisorProgram,
    deserialize: deserializeSupervisorProgram,
    deserializeProperty: deserializeSupervisorProgramProp,
  ),
  getEmbeddedSchemas: () => [],
);

@isarProtected
int serializeSupervisorProgram(IsarWriter writer, SupervisorProgram object) {
  IsarCore.writeString(writer, 1, object.name);
  IsarCore.writeString(writer, 2, object.command);
  IsarCore.writeString(writer, 3, object.workingDir);
  IsarCore.writeString(writer, 4, object.environmentJson);
  IsarCore.writeBool(writer, 5, value: object.autoStart);
  IsarCore.writeBool(writer, 6, value: object.autoRestart);
  IsarCore.writeLong(writer, 7, object.maxRestarts);
  IsarCore.writeLong(writer, 8, object.restartWindowSeconds);
  IsarCore.writeLong(writer, 9, object.restartDelaySeconds);
  IsarCore.writeBool(writer, 10, value: object.enabled);
  IsarCore.writeLong(
    writer,
    11,
    object.createdAt?.toUtc().microsecondsSinceEpoch ?? -9223372036854775808,
  );
  return object.id;
}

@isarProtected
SupervisorProgram deserializeSupervisorProgram(IsarReader reader) {
  final int _id;
  _id = IsarCore.readId(reader);
  final String _name;
  _name = IsarCore.readString(reader, 1) ?? '';
  final String _command;
  _command = IsarCore.readString(reader, 2) ?? '';
  final String _workingDir;
  _workingDir = IsarCore.readString(reader, 3) ?? '';
  final String _environmentJson;
  _environmentJson = IsarCore.readString(reader, 4) ?? '{}';
  final bool _autoStart;
  _autoStart = IsarCore.readBool(reader, 5);
  final bool _autoRestart;
  {
    if (IsarCore.readNull(reader, 6)) {
      _autoRestart = true;
    } else {
      _autoRestart = IsarCore.readBool(reader, 6);
    }
  }
  final int _maxRestarts;
  {
    final value = IsarCore.readLong(reader, 7);
    if (value == -9223372036854775808) {
      _maxRestarts = 5;
    } else {
      _maxRestarts = value;
    }
  }
  final int _restartWindowSeconds;
  {
    final value = IsarCore.readLong(reader, 8);
    if (value == -9223372036854775808) {
      _restartWindowSeconds = 60;
    } else {
      _restartWindowSeconds = value;
    }
  }
  final int _restartDelaySeconds;
  {
    final value = IsarCore.readLong(reader, 9);
    if (value == -9223372036854775808) {
      _restartDelaySeconds = 2;
    } else {
      _restartDelaySeconds = value;
    }
  }
  final bool _enabled;
  {
    if (IsarCore.readNull(reader, 10)) {
      _enabled = true;
    } else {
      _enabled = IsarCore.readBool(reader, 10);
    }
  }
  final DateTime? _createdAt;
  {
    final value = IsarCore.readLong(reader, 11);
    if (value == -9223372036854775808) {
      _createdAt = null;
    } else {
      _createdAt = DateTime.fromMicrosecondsSinceEpoch(
        value,
        isUtc: true,
      ).toLocal();
    }
  }
  final object = SupervisorProgram(
    id: _id,
    name: _name,
    command: _command,
    workingDir: _workingDir,
    environmentJson: _environmentJson,
    autoStart: _autoStart,
    autoRestart: _autoRestart,
    maxRestarts: _maxRestarts,
    restartWindowSeconds: _restartWindowSeconds,
    restartDelaySeconds: _restartDelaySeconds,
    enabled: _enabled,
    createdAt: _createdAt,
  );
  return object;
}

@isarProtected
dynamic deserializeSupervisorProgramProp(IsarReader reader, int property) {
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
      return IsarCore.readString(reader, 4) ?? '{}';
    case 5:
      return IsarCore.readBool(reader, 5);
    case 6:
      {
        if (IsarCore.readNull(reader, 6)) {
          return true;
        } else {
          return IsarCore.readBool(reader, 6);
        }
      }
    case 7:
      {
        final value = IsarCore.readLong(reader, 7);
        if (value == -9223372036854775808) {
          return 5;
        } else {
          return value;
        }
      }
    case 8:
      {
        final value = IsarCore.readLong(reader, 8);
        if (value == -9223372036854775808) {
          return 60;
        } else {
          return value;
        }
      }
    case 9:
      {
        final value = IsarCore.readLong(reader, 9);
        if (value == -9223372036854775808) {
          return 2;
        } else {
          return value;
        }
      }
    case 10:
      {
        if (IsarCore.readNull(reader, 10)) {
          return true;
        } else {
          return IsarCore.readBool(reader, 10);
        }
      }
    case 11:
      {
        final value = IsarCore.readLong(reader, 11);
        if (value == -9223372036854775808) {
          return null;
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

sealed class _SupervisorProgramUpdate {
  bool call({
    required int id,
    String? name,
    String? command,
    String? workingDir,
    String? environmentJson,
    bool? autoStart,
    bool? autoRestart,
    int? maxRestarts,
    int? restartWindowSeconds,
    int? restartDelaySeconds,
    bool? enabled,
    DateTime? createdAt,
  });
}

class _SupervisorProgramUpdateImpl implements _SupervisorProgramUpdate {
  const _SupervisorProgramUpdateImpl(this.collection);

  final IsarCollection<int, SupervisorProgram> collection;

  @override
  bool call({
    required int id,
    Object? name = ignore,
    Object? command = ignore,
    Object? workingDir = ignore,
    Object? environmentJson = ignore,
    Object? autoStart = ignore,
    Object? autoRestart = ignore,
    Object? maxRestarts = ignore,
    Object? restartWindowSeconds = ignore,
    Object? restartDelaySeconds = ignore,
    Object? enabled = ignore,
    Object? createdAt = ignore,
  }) {
    return collection.updateProperties(
          [id],
          {
            if (name != ignore) 1: name as String?,
            if (command != ignore) 2: command as String?,
            if (workingDir != ignore) 3: workingDir as String?,
            if (environmentJson != ignore) 4: environmentJson as String?,
            if (autoStart != ignore) 5: autoStart as bool?,
            if (autoRestart != ignore) 6: autoRestart as bool?,
            if (maxRestarts != ignore) 7: maxRestarts as int?,
            if (restartWindowSeconds != ignore) 8: restartWindowSeconds as int?,
            if (restartDelaySeconds != ignore) 9: restartDelaySeconds as int?,
            if (enabled != ignore) 10: enabled as bool?,
            if (createdAt != ignore) 11: createdAt as DateTime?,
          },
        ) >
        0;
  }
}

sealed class _SupervisorProgramUpdateAll {
  int call({
    required List<int> id,
    String? name,
    String? command,
    String? workingDir,
    String? environmentJson,
    bool? autoStart,
    bool? autoRestart,
    int? maxRestarts,
    int? restartWindowSeconds,
    int? restartDelaySeconds,
    bool? enabled,
    DateTime? createdAt,
  });
}

class _SupervisorProgramUpdateAllImpl implements _SupervisorProgramUpdateAll {
  const _SupervisorProgramUpdateAllImpl(this.collection);

  final IsarCollection<int, SupervisorProgram> collection;

  @override
  int call({
    required List<int> id,
    Object? name = ignore,
    Object? command = ignore,
    Object? workingDir = ignore,
    Object? environmentJson = ignore,
    Object? autoStart = ignore,
    Object? autoRestart = ignore,
    Object? maxRestarts = ignore,
    Object? restartWindowSeconds = ignore,
    Object? restartDelaySeconds = ignore,
    Object? enabled = ignore,
    Object? createdAt = ignore,
  }) {
    return collection.updateProperties(id, {
      if (name != ignore) 1: name as String?,
      if (command != ignore) 2: command as String?,
      if (workingDir != ignore) 3: workingDir as String?,
      if (environmentJson != ignore) 4: environmentJson as String?,
      if (autoStart != ignore) 5: autoStart as bool?,
      if (autoRestart != ignore) 6: autoRestart as bool?,
      if (maxRestarts != ignore) 7: maxRestarts as int?,
      if (restartWindowSeconds != ignore) 8: restartWindowSeconds as int?,
      if (restartDelaySeconds != ignore) 9: restartDelaySeconds as int?,
      if (enabled != ignore) 10: enabled as bool?,
      if (createdAt != ignore) 11: createdAt as DateTime?,
    });
  }
}

extension SupervisorProgramUpdate on IsarCollection<int, SupervisorProgram> {
  _SupervisorProgramUpdate get update => _SupervisorProgramUpdateImpl(this);

  _SupervisorProgramUpdateAll get updateAll =>
      _SupervisorProgramUpdateAllImpl(this);
}

sealed class _SupervisorProgramQueryUpdate {
  int call({
    String? name,
    String? command,
    String? workingDir,
    String? environmentJson,
    bool? autoStart,
    bool? autoRestart,
    int? maxRestarts,
    int? restartWindowSeconds,
    int? restartDelaySeconds,
    bool? enabled,
    DateTime? createdAt,
  });
}

class _SupervisorProgramQueryUpdateImpl
    implements _SupervisorProgramQueryUpdate {
  const _SupervisorProgramQueryUpdateImpl(this.query, {this.limit});

  final IsarQuery<SupervisorProgram> query;
  final int? limit;

  @override
  int call({
    Object? name = ignore,
    Object? command = ignore,
    Object? workingDir = ignore,
    Object? environmentJson = ignore,
    Object? autoStart = ignore,
    Object? autoRestart = ignore,
    Object? maxRestarts = ignore,
    Object? restartWindowSeconds = ignore,
    Object? restartDelaySeconds = ignore,
    Object? enabled = ignore,
    Object? createdAt = ignore,
  }) {
    return query.updateProperties(limit: limit, {
      if (name != ignore) 1: name as String?,
      if (command != ignore) 2: command as String?,
      if (workingDir != ignore) 3: workingDir as String?,
      if (environmentJson != ignore) 4: environmentJson as String?,
      if (autoStart != ignore) 5: autoStart as bool?,
      if (autoRestart != ignore) 6: autoRestart as bool?,
      if (maxRestarts != ignore) 7: maxRestarts as int?,
      if (restartWindowSeconds != ignore) 8: restartWindowSeconds as int?,
      if (restartDelaySeconds != ignore) 9: restartDelaySeconds as int?,
      if (enabled != ignore) 10: enabled as bool?,
      if (createdAt != ignore) 11: createdAt as DateTime?,
    });
  }
}

extension SupervisorProgramQueryUpdate on IsarQuery<SupervisorProgram> {
  _SupervisorProgramQueryUpdate get updateFirst =>
      _SupervisorProgramQueryUpdateImpl(this, limit: 1);

  _SupervisorProgramQueryUpdate get updateAll =>
      _SupervisorProgramQueryUpdateImpl(this);
}

class _SupervisorProgramQueryBuilderUpdateImpl
    implements _SupervisorProgramQueryUpdate {
  const _SupervisorProgramQueryBuilderUpdateImpl(this.query, {this.limit});

  final QueryBuilder<SupervisorProgram, SupervisorProgram, QOperations> query;
  final int? limit;

  @override
  int call({
    Object? name = ignore,
    Object? command = ignore,
    Object? workingDir = ignore,
    Object? environmentJson = ignore,
    Object? autoStart = ignore,
    Object? autoRestart = ignore,
    Object? maxRestarts = ignore,
    Object? restartWindowSeconds = ignore,
    Object? restartDelaySeconds = ignore,
    Object? enabled = ignore,
    Object? createdAt = ignore,
  }) {
    final q = query.build();
    try {
      return q.updateProperties(limit: limit, {
        if (name != ignore) 1: name as String?,
        if (command != ignore) 2: command as String?,
        if (workingDir != ignore) 3: workingDir as String?,
        if (environmentJson != ignore) 4: environmentJson as String?,
        if (autoStart != ignore) 5: autoStart as bool?,
        if (autoRestart != ignore) 6: autoRestart as bool?,
        if (maxRestarts != ignore) 7: maxRestarts as int?,
        if (restartWindowSeconds != ignore) 8: restartWindowSeconds as int?,
        if (restartDelaySeconds != ignore) 9: restartDelaySeconds as int?,
        if (enabled != ignore) 10: enabled as bool?,
        if (createdAt != ignore) 11: createdAt as DateTime?,
      });
    } finally {
      q.close();
    }
  }
}

extension SupervisorProgramQueryBuilderUpdate
    on QueryBuilder<SupervisorProgram, SupervisorProgram, QOperations> {
  _SupervisorProgramQueryUpdate get updateFirst =>
      _SupervisorProgramQueryBuilderUpdateImpl(this, limit: 1);

  _SupervisorProgramQueryUpdate get updateAll =>
      _SupervisorProgramQueryBuilderUpdateImpl(this);
}

extension SupervisorProgramQueryFilter
    on QueryBuilder<SupervisorProgram, SupervisorProgram, QFilterCondition> {
  QueryBuilder<SupervisorProgram, SupervisorProgram, QAfterFilterCondition>
  idEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(property: 0, value: value),
      );
    });
  }

  QueryBuilder<SupervisorProgram, SupervisorProgram, QAfterFilterCondition>
  idGreaterThan(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterCondition(property: 0, value: value),
      );
    });
  }

  QueryBuilder<SupervisorProgram, SupervisorProgram, QAfterFilterCondition>
  idGreaterThanOrEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterOrEqualCondition(property: 0, value: value),
      );
    });
  }

  QueryBuilder<SupervisorProgram, SupervisorProgram, QAfterFilterCondition>
  idLessThan(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(LessCondition(property: 0, value: value));
    });
  }

  QueryBuilder<SupervisorProgram, SupervisorProgram, QAfterFilterCondition>
  idLessThanOrEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessOrEqualCondition(property: 0, value: value),
      );
    });
  }

  QueryBuilder<SupervisorProgram, SupervisorProgram, QAfterFilterCondition>
  idBetween(int lower, int upper) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        BetweenCondition(property: 0, lower: lower, upper: upper),
      );
    });
  }

  QueryBuilder<SupervisorProgram, SupervisorProgram, QAfterFilterCondition>
  nameEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(property: 1, value: value, caseSensitive: caseSensitive),
      );
    });
  }

  QueryBuilder<SupervisorProgram, SupervisorProgram, QAfterFilterCondition>
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

  QueryBuilder<SupervisorProgram, SupervisorProgram, QAfterFilterCondition>
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

  QueryBuilder<SupervisorProgram, SupervisorProgram, QAfterFilterCondition>
  nameLessThan(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessCondition(property: 1, value: value, caseSensitive: caseSensitive),
      );
    });
  }

  QueryBuilder<SupervisorProgram, SupervisorProgram, QAfterFilterCondition>
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

  QueryBuilder<SupervisorProgram, SupervisorProgram, QAfterFilterCondition>
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

  QueryBuilder<SupervisorProgram, SupervisorProgram, QAfterFilterCondition>
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

  QueryBuilder<SupervisorProgram, SupervisorProgram, QAfterFilterCondition>
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

  QueryBuilder<SupervisorProgram, SupervisorProgram, QAfterFilterCondition>
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

  QueryBuilder<SupervisorProgram, SupervisorProgram, QAfterFilterCondition>
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

  QueryBuilder<SupervisorProgram, SupervisorProgram, QAfterFilterCondition>
  nameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const EqualCondition(property: 1, value: ''),
      );
    });
  }

  QueryBuilder<SupervisorProgram, SupervisorProgram, QAfterFilterCondition>
  nameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const GreaterCondition(property: 1, value: ''),
      );
    });
  }

  QueryBuilder<SupervisorProgram, SupervisorProgram, QAfterFilterCondition>
  commandEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(property: 2, value: value, caseSensitive: caseSensitive),
      );
    });
  }

  QueryBuilder<SupervisorProgram, SupervisorProgram, QAfterFilterCondition>
  commandGreaterThan(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<SupervisorProgram, SupervisorProgram, QAfterFilterCondition>
  commandGreaterThanOrEqualTo(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<SupervisorProgram, SupervisorProgram, QAfterFilterCondition>
  commandLessThan(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessCondition(property: 2, value: value, caseSensitive: caseSensitive),
      );
    });
  }

  QueryBuilder<SupervisorProgram, SupervisorProgram, QAfterFilterCondition>
  commandLessThanOrEqualTo(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<SupervisorProgram, SupervisorProgram, QAfterFilterCondition>
  commandBetween(String lower, String upper, {bool caseSensitive = true}) {
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

  QueryBuilder<SupervisorProgram, SupervisorProgram, QAfterFilterCondition>
  commandStartsWith(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<SupervisorProgram, SupervisorProgram, QAfterFilterCondition>
  commandEndsWith(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<SupervisorProgram, SupervisorProgram, QAfterFilterCondition>
  commandContains(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<SupervisorProgram, SupervisorProgram, QAfterFilterCondition>
  commandMatches(String pattern, {bool caseSensitive = true}) {
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

  QueryBuilder<SupervisorProgram, SupervisorProgram, QAfterFilterCondition>
  commandIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const EqualCondition(property: 2, value: ''),
      );
    });
  }

  QueryBuilder<SupervisorProgram, SupervisorProgram, QAfterFilterCondition>
  commandIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const GreaterCondition(property: 2, value: ''),
      );
    });
  }

  QueryBuilder<SupervisorProgram, SupervisorProgram, QAfterFilterCondition>
  workingDirEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(property: 3, value: value, caseSensitive: caseSensitive),
      );
    });
  }

  QueryBuilder<SupervisorProgram, SupervisorProgram, QAfterFilterCondition>
  workingDirGreaterThan(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<SupervisorProgram, SupervisorProgram, QAfterFilterCondition>
  workingDirGreaterThanOrEqualTo(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<SupervisorProgram, SupervisorProgram, QAfterFilterCondition>
  workingDirLessThan(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessCondition(property: 3, value: value, caseSensitive: caseSensitive),
      );
    });
  }

  QueryBuilder<SupervisorProgram, SupervisorProgram, QAfterFilterCondition>
  workingDirLessThanOrEqualTo(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<SupervisorProgram, SupervisorProgram, QAfterFilterCondition>
  workingDirBetween(String lower, String upper, {bool caseSensitive = true}) {
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

  QueryBuilder<SupervisorProgram, SupervisorProgram, QAfterFilterCondition>
  workingDirStartsWith(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<SupervisorProgram, SupervisorProgram, QAfterFilterCondition>
  workingDirEndsWith(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<SupervisorProgram, SupervisorProgram, QAfterFilterCondition>
  workingDirContains(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<SupervisorProgram, SupervisorProgram, QAfterFilterCondition>
  workingDirMatches(String pattern, {bool caseSensitive = true}) {
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

  QueryBuilder<SupervisorProgram, SupervisorProgram, QAfterFilterCondition>
  workingDirIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const EqualCondition(property: 3, value: ''),
      );
    });
  }

  QueryBuilder<SupervisorProgram, SupervisorProgram, QAfterFilterCondition>
  workingDirIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const GreaterCondition(property: 3, value: ''),
      );
    });
  }

  QueryBuilder<SupervisorProgram, SupervisorProgram, QAfterFilterCondition>
  environmentJsonEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(property: 4, value: value, caseSensitive: caseSensitive),
      );
    });
  }

  QueryBuilder<SupervisorProgram, SupervisorProgram, QAfterFilterCondition>
  environmentJsonGreaterThan(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<SupervisorProgram, SupervisorProgram, QAfterFilterCondition>
  environmentJsonGreaterThanOrEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
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

  QueryBuilder<SupervisorProgram, SupervisorProgram, QAfterFilterCondition>
  environmentJsonLessThan(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessCondition(property: 4, value: value, caseSensitive: caseSensitive),
      );
    });
  }

  QueryBuilder<SupervisorProgram, SupervisorProgram, QAfterFilterCondition>
  environmentJsonLessThanOrEqualTo(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<SupervisorProgram, SupervisorProgram, QAfterFilterCondition>
  environmentJsonBetween(
    String lower,
    String upper, {
    bool caseSensitive = true,
  }) {
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

  QueryBuilder<SupervisorProgram, SupervisorProgram, QAfterFilterCondition>
  environmentJsonStartsWith(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<SupervisorProgram, SupervisorProgram, QAfterFilterCondition>
  environmentJsonEndsWith(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<SupervisorProgram, SupervisorProgram, QAfterFilterCondition>
  environmentJsonContains(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<SupervisorProgram, SupervisorProgram, QAfterFilterCondition>
  environmentJsonMatches(String pattern, {bool caseSensitive = true}) {
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

  QueryBuilder<SupervisorProgram, SupervisorProgram, QAfterFilterCondition>
  environmentJsonIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const EqualCondition(property: 4, value: ''),
      );
    });
  }

  QueryBuilder<SupervisorProgram, SupervisorProgram, QAfterFilterCondition>
  environmentJsonIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const GreaterCondition(property: 4, value: ''),
      );
    });
  }

  QueryBuilder<SupervisorProgram, SupervisorProgram, QAfterFilterCondition>
  autoStartEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(property: 5, value: value),
      );
    });
  }

  QueryBuilder<SupervisorProgram, SupervisorProgram, QAfterFilterCondition>
  autoRestartEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(property: 6, value: value),
      );
    });
  }

  QueryBuilder<SupervisorProgram, SupervisorProgram, QAfterFilterCondition>
  maxRestartsEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(property: 7, value: value),
      );
    });
  }

  QueryBuilder<SupervisorProgram, SupervisorProgram, QAfterFilterCondition>
  maxRestartsGreaterThan(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterCondition(property: 7, value: value),
      );
    });
  }

  QueryBuilder<SupervisorProgram, SupervisorProgram, QAfterFilterCondition>
  maxRestartsGreaterThanOrEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterOrEqualCondition(property: 7, value: value),
      );
    });
  }

  QueryBuilder<SupervisorProgram, SupervisorProgram, QAfterFilterCondition>
  maxRestartsLessThan(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(LessCondition(property: 7, value: value));
    });
  }

  QueryBuilder<SupervisorProgram, SupervisorProgram, QAfterFilterCondition>
  maxRestartsLessThanOrEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessOrEqualCondition(property: 7, value: value),
      );
    });
  }

  QueryBuilder<SupervisorProgram, SupervisorProgram, QAfterFilterCondition>
  maxRestartsBetween(int lower, int upper) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        BetweenCondition(property: 7, lower: lower, upper: upper),
      );
    });
  }

  QueryBuilder<SupervisorProgram, SupervisorProgram, QAfterFilterCondition>
  restartWindowSecondsEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(property: 8, value: value),
      );
    });
  }

  QueryBuilder<SupervisorProgram, SupervisorProgram, QAfterFilterCondition>
  restartWindowSecondsGreaterThan(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterCondition(property: 8, value: value),
      );
    });
  }

  QueryBuilder<SupervisorProgram, SupervisorProgram, QAfterFilterCondition>
  restartWindowSecondsGreaterThanOrEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterOrEqualCondition(property: 8, value: value),
      );
    });
  }

  QueryBuilder<SupervisorProgram, SupervisorProgram, QAfterFilterCondition>
  restartWindowSecondsLessThan(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(LessCondition(property: 8, value: value));
    });
  }

  QueryBuilder<SupervisorProgram, SupervisorProgram, QAfterFilterCondition>
  restartWindowSecondsLessThanOrEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessOrEqualCondition(property: 8, value: value),
      );
    });
  }

  QueryBuilder<SupervisorProgram, SupervisorProgram, QAfterFilterCondition>
  restartWindowSecondsBetween(int lower, int upper) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        BetweenCondition(property: 8, lower: lower, upper: upper),
      );
    });
  }

  QueryBuilder<SupervisorProgram, SupervisorProgram, QAfterFilterCondition>
  restartDelaySecondsEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(property: 9, value: value),
      );
    });
  }

  QueryBuilder<SupervisorProgram, SupervisorProgram, QAfterFilterCondition>
  restartDelaySecondsGreaterThan(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterCondition(property: 9, value: value),
      );
    });
  }

  QueryBuilder<SupervisorProgram, SupervisorProgram, QAfterFilterCondition>
  restartDelaySecondsGreaterThanOrEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterOrEqualCondition(property: 9, value: value),
      );
    });
  }

  QueryBuilder<SupervisorProgram, SupervisorProgram, QAfterFilterCondition>
  restartDelaySecondsLessThan(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(LessCondition(property: 9, value: value));
    });
  }

  QueryBuilder<SupervisorProgram, SupervisorProgram, QAfterFilterCondition>
  restartDelaySecondsLessThanOrEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessOrEqualCondition(property: 9, value: value),
      );
    });
  }

  QueryBuilder<SupervisorProgram, SupervisorProgram, QAfterFilterCondition>
  restartDelaySecondsBetween(int lower, int upper) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        BetweenCondition(property: 9, lower: lower, upper: upper),
      );
    });
  }

  QueryBuilder<SupervisorProgram, SupervisorProgram, QAfterFilterCondition>
  enabledEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(property: 10, value: value),
      );
    });
  }

  QueryBuilder<SupervisorProgram, SupervisorProgram, QAfterFilterCondition>
  createdAtIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const IsNullCondition(property: 11));
    });
  }

  QueryBuilder<SupervisorProgram, SupervisorProgram, QAfterFilterCondition>
  createdAtIsNotNull() {
    return QueryBuilder.apply(not(), (query) {
      return query.addFilterCondition(const IsNullCondition(property: 11));
    });
  }

  QueryBuilder<SupervisorProgram, SupervisorProgram, QAfterFilterCondition>
  createdAtEqualTo(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(property: 11, value: value),
      );
    });
  }

  QueryBuilder<SupervisorProgram, SupervisorProgram, QAfterFilterCondition>
  createdAtGreaterThan(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterCondition(property: 11, value: value),
      );
    });
  }

  QueryBuilder<SupervisorProgram, SupervisorProgram, QAfterFilterCondition>
  createdAtGreaterThanOrEqualTo(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterOrEqualCondition(property: 11, value: value),
      );
    });
  }

  QueryBuilder<SupervisorProgram, SupervisorProgram, QAfterFilterCondition>
  createdAtLessThan(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessCondition(property: 11, value: value),
      );
    });
  }

  QueryBuilder<SupervisorProgram, SupervisorProgram, QAfterFilterCondition>
  createdAtLessThanOrEqualTo(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessOrEqualCondition(property: 11, value: value),
      );
    });
  }

  QueryBuilder<SupervisorProgram, SupervisorProgram, QAfterFilterCondition>
  createdAtBetween(DateTime? lower, DateTime? upper) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        BetweenCondition(property: 11, lower: lower, upper: upper),
      );
    });
  }
}

extension SupervisorProgramQueryObject
    on QueryBuilder<SupervisorProgram, SupervisorProgram, QFilterCondition> {}

extension SupervisorProgramQuerySortBy
    on QueryBuilder<SupervisorProgram, SupervisorProgram, QSortBy> {
  QueryBuilder<SupervisorProgram, SupervisorProgram, QAfterSortBy> sortById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(0);
    });
  }

  QueryBuilder<SupervisorProgram, SupervisorProgram, QAfterSortBy>
  sortByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(0, sort: Sort.desc);
    });
  }

  QueryBuilder<SupervisorProgram, SupervisorProgram, QAfterSortBy> sortByName({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(1, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<SupervisorProgram, SupervisorProgram, QAfterSortBy>
  sortByNameDesc({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(1, sort: Sort.desc, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<SupervisorProgram, SupervisorProgram, QAfterSortBy>
  sortByCommand({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(2, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<SupervisorProgram, SupervisorProgram, QAfterSortBy>
  sortByCommandDesc({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(2, sort: Sort.desc, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<SupervisorProgram, SupervisorProgram, QAfterSortBy>
  sortByWorkingDir({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(3, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<SupervisorProgram, SupervisorProgram, QAfterSortBy>
  sortByWorkingDirDesc({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(3, sort: Sort.desc, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<SupervisorProgram, SupervisorProgram, QAfterSortBy>
  sortByEnvironmentJson({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(4, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<SupervisorProgram, SupervisorProgram, QAfterSortBy>
  sortByEnvironmentJsonDesc({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(4, sort: Sort.desc, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<SupervisorProgram, SupervisorProgram, QAfterSortBy>
  sortByAutoStart() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(5);
    });
  }

  QueryBuilder<SupervisorProgram, SupervisorProgram, QAfterSortBy>
  sortByAutoStartDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(5, sort: Sort.desc);
    });
  }

  QueryBuilder<SupervisorProgram, SupervisorProgram, QAfterSortBy>
  sortByAutoRestart() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(6);
    });
  }

  QueryBuilder<SupervisorProgram, SupervisorProgram, QAfterSortBy>
  sortByAutoRestartDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(6, sort: Sort.desc);
    });
  }

  QueryBuilder<SupervisorProgram, SupervisorProgram, QAfterSortBy>
  sortByMaxRestarts() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(7);
    });
  }

  QueryBuilder<SupervisorProgram, SupervisorProgram, QAfterSortBy>
  sortByMaxRestartsDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(7, sort: Sort.desc);
    });
  }

  QueryBuilder<SupervisorProgram, SupervisorProgram, QAfterSortBy>
  sortByRestartWindowSeconds() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(8);
    });
  }

  QueryBuilder<SupervisorProgram, SupervisorProgram, QAfterSortBy>
  sortByRestartWindowSecondsDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(8, sort: Sort.desc);
    });
  }

  QueryBuilder<SupervisorProgram, SupervisorProgram, QAfterSortBy>
  sortByRestartDelaySeconds() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(9);
    });
  }

  QueryBuilder<SupervisorProgram, SupervisorProgram, QAfterSortBy>
  sortByRestartDelaySecondsDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(9, sort: Sort.desc);
    });
  }

  QueryBuilder<SupervisorProgram, SupervisorProgram, QAfterSortBy>
  sortByEnabled() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(10);
    });
  }

  QueryBuilder<SupervisorProgram, SupervisorProgram, QAfterSortBy>
  sortByEnabledDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(10, sort: Sort.desc);
    });
  }

  QueryBuilder<SupervisorProgram, SupervisorProgram, QAfterSortBy>
  sortByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(11);
    });
  }

  QueryBuilder<SupervisorProgram, SupervisorProgram, QAfterSortBy>
  sortByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(11, sort: Sort.desc);
    });
  }
}

extension SupervisorProgramQuerySortThenBy
    on QueryBuilder<SupervisorProgram, SupervisorProgram, QSortThenBy> {
  QueryBuilder<SupervisorProgram, SupervisorProgram, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(0);
    });
  }

  QueryBuilder<SupervisorProgram, SupervisorProgram, QAfterSortBy>
  thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(0, sort: Sort.desc);
    });
  }

  QueryBuilder<SupervisorProgram, SupervisorProgram, QAfterSortBy> thenByName({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(1, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<SupervisorProgram, SupervisorProgram, QAfterSortBy>
  thenByNameDesc({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(1, sort: Sort.desc, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<SupervisorProgram, SupervisorProgram, QAfterSortBy>
  thenByCommand({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(2, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<SupervisorProgram, SupervisorProgram, QAfterSortBy>
  thenByCommandDesc({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(2, sort: Sort.desc, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<SupervisorProgram, SupervisorProgram, QAfterSortBy>
  thenByWorkingDir({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(3, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<SupervisorProgram, SupervisorProgram, QAfterSortBy>
  thenByWorkingDirDesc({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(3, sort: Sort.desc, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<SupervisorProgram, SupervisorProgram, QAfterSortBy>
  thenByEnvironmentJson({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(4, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<SupervisorProgram, SupervisorProgram, QAfterSortBy>
  thenByEnvironmentJsonDesc({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(4, sort: Sort.desc, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<SupervisorProgram, SupervisorProgram, QAfterSortBy>
  thenByAutoStart() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(5);
    });
  }

  QueryBuilder<SupervisorProgram, SupervisorProgram, QAfterSortBy>
  thenByAutoStartDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(5, sort: Sort.desc);
    });
  }

  QueryBuilder<SupervisorProgram, SupervisorProgram, QAfterSortBy>
  thenByAutoRestart() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(6);
    });
  }

  QueryBuilder<SupervisorProgram, SupervisorProgram, QAfterSortBy>
  thenByAutoRestartDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(6, sort: Sort.desc);
    });
  }

  QueryBuilder<SupervisorProgram, SupervisorProgram, QAfterSortBy>
  thenByMaxRestarts() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(7);
    });
  }

  QueryBuilder<SupervisorProgram, SupervisorProgram, QAfterSortBy>
  thenByMaxRestartsDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(7, sort: Sort.desc);
    });
  }

  QueryBuilder<SupervisorProgram, SupervisorProgram, QAfterSortBy>
  thenByRestartWindowSeconds() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(8);
    });
  }

  QueryBuilder<SupervisorProgram, SupervisorProgram, QAfterSortBy>
  thenByRestartWindowSecondsDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(8, sort: Sort.desc);
    });
  }

  QueryBuilder<SupervisorProgram, SupervisorProgram, QAfterSortBy>
  thenByRestartDelaySeconds() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(9);
    });
  }

  QueryBuilder<SupervisorProgram, SupervisorProgram, QAfterSortBy>
  thenByRestartDelaySecondsDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(9, sort: Sort.desc);
    });
  }

  QueryBuilder<SupervisorProgram, SupervisorProgram, QAfterSortBy>
  thenByEnabled() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(10);
    });
  }

  QueryBuilder<SupervisorProgram, SupervisorProgram, QAfterSortBy>
  thenByEnabledDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(10, sort: Sort.desc);
    });
  }

  QueryBuilder<SupervisorProgram, SupervisorProgram, QAfterSortBy>
  thenByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(11);
    });
  }

  QueryBuilder<SupervisorProgram, SupervisorProgram, QAfterSortBy>
  thenByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(11, sort: Sort.desc);
    });
  }
}

extension SupervisorProgramQueryWhereDistinct
    on QueryBuilder<SupervisorProgram, SupervisorProgram, QDistinct> {
  QueryBuilder<SupervisorProgram, SupervisorProgram, QAfterDistinct>
  distinctByName({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(1, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<SupervisorProgram, SupervisorProgram, QAfterDistinct>
  distinctByCommand({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(2, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<SupervisorProgram, SupervisorProgram, QAfterDistinct>
  distinctByWorkingDir({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(3, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<SupervisorProgram, SupervisorProgram, QAfterDistinct>
  distinctByEnvironmentJson({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(4, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<SupervisorProgram, SupervisorProgram, QAfterDistinct>
  distinctByAutoStart() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(5);
    });
  }

  QueryBuilder<SupervisorProgram, SupervisorProgram, QAfterDistinct>
  distinctByAutoRestart() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(6);
    });
  }

  QueryBuilder<SupervisorProgram, SupervisorProgram, QAfterDistinct>
  distinctByMaxRestarts() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(7);
    });
  }

  QueryBuilder<SupervisorProgram, SupervisorProgram, QAfterDistinct>
  distinctByRestartWindowSeconds() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(8);
    });
  }

  QueryBuilder<SupervisorProgram, SupervisorProgram, QAfterDistinct>
  distinctByRestartDelaySeconds() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(9);
    });
  }

  QueryBuilder<SupervisorProgram, SupervisorProgram, QAfterDistinct>
  distinctByEnabled() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(10);
    });
  }

  QueryBuilder<SupervisorProgram, SupervisorProgram, QAfterDistinct>
  distinctByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(11);
    });
  }
}

extension SupervisorProgramQueryProperty1
    on QueryBuilder<SupervisorProgram, SupervisorProgram, QProperty> {
  QueryBuilder<SupervisorProgram, int, QAfterProperty> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(0);
    });
  }

  QueryBuilder<SupervisorProgram, String, QAfterProperty> nameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(1);
    });
  }

  QueryBuilder<SupervisorProgram, String, QAfterProperty> commandProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(2);
    });
  }

  QueryBuilder<SupervisorProgram, String, QAfterProperty> workingDirProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(3);
    });
  }

  QueryBuilder<SupervisorProgram, String, QAfterProperty>
  environmentJsonProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(4);
    });
  }

  QueryBuilder<SupervisorProgram, bool, QAfterProperty> autoStartProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(5);
    });
  }

  QueryBuilder<SupervisorProgram, bool, QAfterProperty> autoRestartProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(6);
    });
  }

  QueryBuilder<SupervisorProgram, int, QAfterProperty> maxRestartsProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(7);
    });
  }

  QueryBuilder<SupervisorProgram, int, QAfterProperty>
  restartWindowSecondsProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(8);
    });
  }

  QueryBuilder<SupervisorProgram, int, QAfterProperty>
  restartDelaySecondsProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(9);
    });
  }

  QueryBuilder<SupervisorProgram, bool, QAfterProperty> enabledProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(10);
    });
  }

  QueryBuilder<SupervisorProgram, DateTime?, QAfterProperty>
  createdAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(11);
    });
  }
}

extension SupervisorProgramQueryProperty2<R>
    on QueryBuilder<SupervisorProgram, R, QAfterProperty> {
  QueryBuilder<SupervisorProgram, (R, int), QAfterProperty> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(0);
    });
  }

  QueryBuilder<SupervisorProgram, (R, String), QAfterProperty> nameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(1);
    });
  }

  QueryBuilder<SupervisorProgram, (R, String), QAfterProperty>
  commandProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(2);
    });
  }

  QueryBuilder<SupervisorProgram, (R, String), QAfterProperty>
  workingDirProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(3);
    });
  }

  QueryBuilder<SupervisorProgram, (R, String), QAfterProperty>
  environmentJsonProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(4);
    });
  }

  QueryBuilder<SupervisorProgram, (R, bool), QAfterProperty>
  autoStartProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(5);
    });
  }

  QueryBuilder<SupervisorProgram, (R, bool), QAfterProperty>
  autoRestartProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(6);
    });
  }

  QueryBuilder<SupervisorProgram, (R, int), QAfterProperty>
  maxRestartsProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(7);
    });
  }

  QueryBuilder<SupervisorProgram, (R, int), QAfterProperty>
  restartWindowSecondsProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(8);
    });
  }

  QueryBuilder<SupervisorProgram, (R, int), QAfterProperty>
  restartDelaySecondsProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(9);
    });
  }

  QueryBuilder<SupervisorProgram, (R, bool), QAfterProperty> enabledProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(10);
    });
  }

  QueryBuilder<SupervisorProgram, (R, DateTime?), QAfterProperty>
  createdAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(11);
    });
  }
}

extension SupervisorProgramQueryProperty3<R1, R2>
    on QueryBuilder<SupervisorProgram, (R1, R2), QAfterProperty> {
  QueryBuilder<SupervisorProgram, (R1, R2, int), QOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(0);
    });
  }

  QueryBuilder<SupervisorProgram, (R1, R2, String), QOperations>
  nameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(1);
    });
  }

  QueryBuilder<SupervisorProgram, (R1, R2, String), QOperations>
  commandProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(2);
    });
  }

  QueryBuilder<SupervisorProgram, (R1, R2, String), QOperations>
  workingDirProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(3);
    });
  }

  QueryBuilder<SupervisorProgram, (R1, R2, String), QOperations>
  environmentJsonProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(4);
    });
  }

  QueryBuilder<SupervisorProgram, (R1, R2, bool), QOperations>
  autoStartProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(5);
    });
  }

  QueryBuilder<SupervisorProgram, (R1, R2, bool), QOperations>
  autoRestartProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(6);
    });
  }

  QueryBuilder<SupervisorProgram, (R1, R2, int), QOperations>
  maxRestartsProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(7);
    });
  }

  QueryBuilder<SupervisorProgram, (R1, R2, int), QOperations>
  restartWindowSecondsProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(8);
    });
  }

  QueryBuilder<SupervisorProgram, (R1, R2, int), QOperations>
  restartDelaySecondsProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(9);
    });
  }

  QueryBuilder<SupervisorProgram, (R1, R2, bool), QOperations>
  enabledProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(10);
    });
  }

  QueryBuilder<SupervisorProgram, (R1, R2, DateTime?), QOperations>
  createdAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(11);
    });
  }
}
