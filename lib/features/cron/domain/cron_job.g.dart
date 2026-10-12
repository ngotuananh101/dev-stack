// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'cron_job.dart';

// **************************************************************************
// _IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, invalid_use_of_protected_member, lines_longer_than_80_chars, constant_identifier_names, avoid_js_rounded_ints, no_leading_underscores_for_local_identifiers, require_trailing_commas, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_in_if_null_operators, library_private_types_in_public_api, prefer_const_constructors
// ignore_for_file: type=lint

extension GetCronJobCollection on Isar {
  IsarCollection<int, CronJob> get cronJobs => this.collection();
}

final CronJobSchema = IsarGeneratedSchema(
  schema: IsarSchema(
    name: 'CronJob',
    idName: 'id',
    embedded: false,
    properties: [
      IsarPropertySchema(name: 'name', type: IsarType.string),
      IsarPropertySchema(name: 'schedule', type: IsarType.string),
      IsarPropertySchema(name: 'command', type: IsarType.string),
      IsarPropertySchema(name: 'workingDir', type: IsarType.string),
      IsarPropertySchema(name: 'enabled', type: IsarType.bool),
      IsarPropertySchema(name: 'lastRunAt', type: IsarType.dateTime),
      IsarPropertySchema(name: 'lastStatus', type: IsarType.string),
      IsarPropertySchema(name: 'lastExitCode', type: IsarType.long),
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
  converter: IsarObjectConverter<int, CronJob>(
    serialize: serializeCronJob,
    deserialize: deserializeCronJob,
    deserializeProperty: deserializeCronJobProp,
  ),
  getEmbeddedSchemas: () => [],
);

@isarProtected
int serializeCronJob(IsarWriter writer, CronJob object) {
  IsarCore.writeString(writer, 1, object.name);
  IsarCore.writeString(writer, 2, object.schedule);
  IsarCore.writeString(writer, 3, object.command);
  IsarCore.writeString(writer, 4, object.workingDir);
  IsarCore.writeBool(writer, 5, value: object.enabled);
  IsarCore.writeLong(
    writer,
    6,
    object.lastRunAt?.toUtc().microsecondsSinceEpoch ?? -9223372036854775808,
  );
  {
    final value = object.lastStatus;
    if (value == null) {
      IsarCore.writeNull(writer, 7);
    } else {
      IsarCore.writeString(writer, 7, value);
    }
  }
  IsarCore.writeLong(writer, 8, object.lastExitCode ?? -9223372036854775808);
  IsarCore.writeLong(
    writer,
    9,
    object.createdAt?.toUtc().microsecondsSinceEpoch ?? -9223372036854775808,
  );
  return object.id;
}

@isarProtected
CronJob deserializeCronJob(IsarReader reader) {
  final int _id;
  _id = IsarCore.readId(reader);
  final String _name;
  _name = IsarCore.readString(reader, 1) ?? '';
  final String _schedule;
  _schedule = IsarCore.readString(reader, 2) ?? '';
  final String _command;
  _command = IsarCore.readString(reader, 3) ?? '';
  final String _workingDir;
  _workingDir = IsarCore.readString(reader, 4) ?? '';
  final bool _enabled;
  {
    if (IsarCore.readNull(reader, 5)) {
      _enabled = true;
    } else {
      _enabled = IsarCore.readBool(reader, 5);
    }
  }
  final DateTime? _lastRunAt;
  {
    final value = IsarCore.readLong(reader, 6);
    if (value == -9223372036854775808) {
      _lastRunAt = null;
    } else {
      _lastRunAt = DateTime.fromMicrosecondsSinceEpoch(
        value,
        isUtc: true,
      ).toLocal();
    }
  }
  final String? _lastStatus;
  _lastStatus = IsarCore.readString(reader, 7);
  final int? _lastExitCode;
  {
    final value = IsarCore.readLong(reader, 8);
    if (value == -9223372036854775808) {
      _lastExitCode = null;
    } else {
      _lastExitCode = value;
    }
  }
  final DateTime? _createdAt;
  {
    final value = IsarCore.readLong(reader, 9);
    if (value == -9223372036854775808) {
      _createdAt = null;
    } else {
      _createdAt = DateTime.fromMicrosecondsSinceEpoch(
        value,
        isUtc: true,
      ).toLocal();
    }
  }
  final object = CronJob(
    id: _id,
    name: _name,
    schedule: _schedule,
    command: _command,
    workingDir: _workingDir,
    enabled: _enabled,
    lastRunAt: _lastRunAt,
    lastStatus: _lastStatus,
    lastExitCode: _lastExitCode,
    createdAt: _createdAt,
  );
  return object;
}

@isarProtected
dynamic deserializeCronJobProp(IsarReader reader, int property) {
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
      {
        if (IsarCore.readNull(reader, 5)) {
          return true;
        } else {
          return IsarCore.readBool(reader, 5);
        }
      }
    case 6:
      {
        final value = IsarCore.readLong(reader, 6);
        if (value == -9223372036854775808) {
          return null;
        } else {
          return DateTime.fromMicrosecondsSinceEpoch(
            value,
            isUtc: true,
          ).toLocal();
        }
      }
    case 7:
      return IsarCore.readString(reader, 7);
    case 8:
      {
        final value = IsarCore.readLong(reader, 8);
        if (value == -9223372036854775808) {
          return null;
        } else {
          return value;
        }
      }
    case 9:
      {
        final value = IsarCore.readLong(reader, 9);
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

sealed class _CronJobUpdate {
  bool call({
    required int id,
    String? name,
    String? schedule,
    String? command,
    String? workingDir,
    bool? enabled,
    DateTime? lastRunAt,
    String? lastStatus,
    int? lastExitCode,
    DateTime? createdAt,
  });
}

class _CronJobUpdateImpl implements _CronJobUpdate {
  const _CronJobUpdateImpl(this.collection);

  final IsarCollection<int, CronJob> collection;

  @override
  bool call({
    required int id,
    Object? name = ignore,
    Object? schedule = ignore,
    Object? command = ignore,
    Object? workingDir = ignore,
    Object? enabled = ignore,
    Object? lastRunAt = ignore,
    Object? lastStatus = ignore,
    Object? lastExitCode = ignore,
    Object? createdAt = ignore,
  }) {
    return collection.updateProperties(
          [id],
          {
            if (name != ignore) 1: name as String?,
            if (schedule != ignore) 2: schedule as String?,
            if (command != ignore) 3: command as String?,
            if (workingDir != ignore) 4: workingDir as String?,
            if (enabled != ignore) 5: enabled as bool?,
            if (lastRunAt != ignore) 6: lastRunAt as DateTime?,
            if (lastStatus != ignore) 7: lastStatus as String?,
            if (lastExitCode != ignore) 8: lastExitCode as int?,
            if (createdAt != ignore) 9: createdAt as DateTime?,
          },
        ) >
        0;
  }
}

sealed class _CronJobUpdateAll {
  int call({
    required List<int> id,
    String? name,
    String? schedule,
    String? command,
    String? workingDir,
    bool? enabled,
    DateTime? lastRunAt,
    String? lastStatus,
    int? lastExitCode,
    DateTime? createdAt,
  });
}

class _CronJobUpdateAllImpl implements _CronJobUpdateAll {
  const _CronJobUpdateAllImpl(this.collection);

  final IsarCollection<int, CronJob> collection;

  @override
  int call({
    required List<int> id,
    Object? name = ignore,
    Object? schedule = ignore,
    Object? command = ignore,
    Object? workingDir = ignore,
    Object? enabled = ignore,
    Object? lastRunAt = ignore,
    Object? lastStatus = ignore,
    Object? lastExitCode = ignore,
    Object? createdAt = ignore,
  }) {
    return collection.updateProperties(id, {
      if (name != ignore) 1: name as String?,
      if (schedule != ignore) 2: schedule as String?,
      if (command != ignore) 3: command as String?,
      if (workingDir != ignore) 4: workingDir as String?,
      if (enabled != ignore) 5: enabled as bool?,
      if (lastRunAt != ignore) 6: lastRunAt as DateTime?,
      if (lastStatus != ignore) 7: lastStatus as String?,
      if (lastExitCode != ignore) 8: lastExitCode as int?,
      if (createdAt != ignore) 9: createdAt as DateTime?,
    });
  }
}

extension CronJobUpdate on IsarCollection<int, CronJob> {
  _CronJobUpdate get update => _CronJobUpdateImpl(this);

  _CronJobUpdateAll get updateAll => _CronJobUpdateAllImpl(this);
}

sealed class _CronJobQueryUpdate {
  int call({
    String? name,
    String? schedule,
    String? command,
    String? workingDir,
    bool? enabled,
    DateTime? lastRunAt,
    String? lastStatus,
    int? lastExitCode,
    DateTime? createdAt,
  });
}

class _CronJobQueryUpdateImpl implements _CronJobQueryUpdate {
  const _CronJobQueryUpdateImpl(this.query, {this.limit});

  final IsarQuery<CronJob> query;
  final int? limit;

  @override
  int call({
    Object? name = ignore,
    Object? schedule = ignore,
    Object? command = ignore,
    Object? workingDir = ignore,
    Object? enabled = ignore,
    Object? lastRunAt = ignore,
    Object? lastStatus = ignore,
    Object? lastExitCode = ignore,
    Object? createdAt = ignore,
  }) {
    return query.updateProperties(limit: limit, {
      if (name != ignore) 1: name as String?,
      if (schedule != ignore) 2: schedule as String?,
      if (command != ignore) 3: command as String?,
      if (workingDir != ignore) 4: workingDir as String?,
      if (enabled != ignore) 5: enabled as bool?,
      if (lastRunAt != ignore) 6: lastRunAt as DateTime?,
      if (lastStatus != ignore) 7: lastStatus as String?,
      if (lastExitCode != ignore) 8: lastExitCode as int?,
      if (createdAt != ignore) 9: createdAt as DateTime?,
    });
  }
}

extension CronJobQueryUpdate on IsarQuery<CronJob> {
  _CronJobQueryUpdate get updateFirst =>
      _CronJobQueryUpdateImpl(this, limit: 1);

  _CronJobQueryUpdate get updateAll => _CronJobQueryUpdateImpl(this);
}

class _CronJobQueryBuilderUpdateImpl implements _CronJobQueryUpdate {
  const _CronJobQueryBuilderUpdateImpl(this.query, {this.limit});

  final QueryBuilder<CronJob, CronJob, QOperations> query;
  final int? limit;

  @override
  int call({
    Object? name = ignore,
    Object? schedule = ignore,
    Object? command = ignore,
    Object? workingDir = ignore,
    Object? enabled = ignore,
    Object? lastRunAt = ignore,
    Object? lastStatus = ignore,
    Object? lastExitCode = ignore,
    Object? createdAt = ignore,
  }) {
    final q = query.build();
    try {
      return q.updateProperties(limit: limit, {
        if (name != ignore) 1: name as String?,
        if (schedule != ignore) 2: schedule as String?,
        if (command != ignore) 3: command as String?,
        if (workingDir != ignore) 4: workingDir as String?,
        if (enabled != ignore) 5: enabled as bool?,
        if (lastRunAt != ignore) 6: lastRunAt as DateTime?,
        if (lastStatus != ignore) 7: lastStatus as String?,
        if (lastExitCode != ignore) 8: lastExitCode as int?,
        if (createdAt != ignore) 9: createdAt as DateTime?,
      });
    } finally {
      q.close();
    }
  }
}

extension CronJobQueryBuilderUpdate
    on QueryBuilder<CronJob, CronJob, QOperations> {
  _CronJobQueryUpdate get updateFirst =>
      _CronJobQueryBuilderUpdateImpl(this, limit: 1);

  _CronJobQueryUpdate get updateAll => _CronJobQueryBuilderUpdateImpl(this);
}

extension CronJobQueryFilter
    on QueryBuilder<CronJob, CronJob, QFilterCondition> {
  QueryBuilder<CronJob, CronJob, QAfterFilterCondition> idEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(property: 0, value: value),
      );
    });
  }

  QueryBuilder<CronJob, CronJob, QAfterFilterCondition> idGreaterThan(
    int value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterCondition(property: 0, value: value),
      );
    });
  }

  QueryBuilder<CronJob, CronJob, QAfterFilterCondition> idGreaterThanOrEqualTo(
    int value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterOrEqualCondition(property: 0, value: value),
      );
    });
  }

  QueryBuilder<CronJob, CronJob, QAfterFilterCondition> idLessThan(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(LessCondition(property: 0, value: value));
    });
  }

  QueryBuilder<CronJob, CronJob, QAfterFilterCondition> idLessThanOrEqualTo(
    int value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessOrEqualCondition(property: 0, value: value),
      );
    });
  }

  QueryBuilder<CronJob, CronJob, QAfterFilterCondition> idBetween(
    int lower,
    int upper,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        BetweenCondition(property: 0, lower: lower, upper: upper),
      );
    });
  }

  QueryBuilder<CronJob, CronJob, QAfterFilterCondition> nameEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(property: 1, value: value, caseSensitive: caseSensitive),
      );
    });
  }

  QueryBuilder<CronJob, CronJob, QAfterFilterCondition> nameGreaterThan(
    String value, {
    bool caseSensitive = true,
  }) {
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

  QueryBuilder<CronJob, CronJob, QAfterFilterCondition>
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

  QueryBuilder<CronJob, CronJob, QAfterFilterCondition> nameLessThan(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessCondition(property: 1, value: value, caseSensitive: caseSensitive),
      );
    });
  }

  QueryBuilder<CronJob, CronJob, QAfterFilterCondition> nameLessThanOrEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
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

  QueryBuilder<CronJob, CronJob, QAfterFilterCondition> nameBetween(
    String lower,
    String upper, {
    bool caseSensitive = true,
  }) {
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

  QueryBuilder<CronJob, CronJob, QAfterFilterCondition> nameStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
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

  QueryBuilder<CronJob, CronJob, QAfterFilterCondition> nameEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
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

  QueryBuilder<CronJob, CronJob, QAfterFilterCondition> nameContains(
    String value, {
    bool caseSensitive = true,
  }) {
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

  QueryBuilder<CronJob, CronJob, QAfterFilterCondition> nameMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
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

  QueryBuilder<CronJob, CronJob, QAfterFilterCondition> nameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const EqualCondition(property: 1, value: ''),
      );
    });
  }

  QueryBuilder<CronJob, CronJob, QAfterFilterCondition> nameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const GreaterCondition(property: 1, value: ''),
      );
    });
  }

  QueryBuilder<CronJob, CronJob, QAfterFilterCondition> scheduleEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(property: 2, value: value, caseSensitive: caseSensitive),
      );
    });
  }

  QueryBuilder<CronJob, CronJob, QAfterFilterCondition> scheduleGreaterThan(
    String value, {
    bool caseSensitive = true,
  }) {
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

  QueryBuilder<CronJob, CronJob, QAfterFilterCondition>
  scheduleGreaterThanOrEqualTo(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<CronJob, CronJob, QAfterFilterCondition> scheduleLessThan(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessCondition(property: 2, value: value, caseSensitive: caseSensitive),
      );
    });
  }

  QueryBuilder<CronJob, CronJob, QAfterFilterCondition>
  scheduleLessThanOrEqualTo(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<CronJob, CronJob, QAfterFilterCondition> scheduleBetween(
    String lower,
    String upper, {
    bool caseSensitive = true,
  }) {
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

  QueryBuilder<CronJob, CronJob, QAfterFilterCondition> scheduleStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
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

  QueryBuilder<CronJob, CronJob, QAfterFilterCondition> scheduleEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
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

  QueryBuilder<CronJob, CronJob, QAfterFilterCondition> scheduleContains(
    String value, {
    bool caseSensitive = true,
  }) {
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

  QueryBuilder<CronJob, CronJob, QAfterFilterCondition> scheduleMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
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

  QueryBuilder<CronJob, CronJob, QAfterFilterCondition> scheduleIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const EqualCondition(property: 2, value: ''),
      );
    });
  }

  QueryBuilder<CronJob, CronJob, QAfterFilterCondition> scheduleIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const GreaterCondition(property: 2, value: ''),
      );
    });
  }

  QueryBuilder<CronJob, CronJob, QAfterFilterCondition> commandEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(property: 3, value: value, caseSensitive: caseSensitive),
      );
    });
  }

  QueryBuilder<CronJob, CronJob, QAfterFilterCondition> commandGreaterThan(
    String value, {
    bool caseSensitive = true,
  }) {
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

  QueryBuilder<CronJob, CronJob, QAfterFilterCondition>
  commandGreaterThanOrEqualTo(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<CronJob, CronJob, QAfterFilterCondition> commandLessThan(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessCondition(property: 3, value: value, caseSensitive: caseSensitive),
      );
    });
  }

  QueryBuilder<CronJob, CronJob, QAfterFilterCondition>
  commandLessThanOrEqualTo(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<CronJob, CronJob, QAfterFilterCondition> commandBetween(
    String lower,
    String upper, {
    bool caseSensitive = true,
  }) {
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

  QueryBuilder<CronJob, CronJob, QAfterFilterCondition> commandStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
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

  QueryBuilder<CronJob, CronJob, QAfterFilterCondition> commandEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
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

  QueryBuilder<CronJob, CronJob, QAfterFilterCondition> commandContains(
    String value, {
    bool caseSensitive = true,
  }) {
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

  QueryBuilder<CronJob, CronJob, QAfterFilterCondition> commandMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
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

  QueryBuilder<CronJob, CronJob, QAfterFilterCondition> commandIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const EqualCondition(property: 3, value: ''),
      );
    });
  }

  QueryBuilder<CronJob, CronJob, QAfterFilterCondition> commandIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const GreaterCondition(property: 3, value: ''),
      );
    });
  }

  QueryBuilder<CronJob, CronJob, QAfterFilterCondition> workingDirEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(property: 4, value: value, caseSensitive: caseSensitive),
      );
    });
  }

  QueryBuilder<CronJob, CronJob, QAfterFilterCondition> workingDirGreaterThan(
    String value, {
    bool caseSensitive = true,
  }) {
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

  QueryBuilder<CronJob, CronJob, QAfterFilterCondition>
  workingDirGreaterThanOrEqualTo(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<CronJob, CronJob, QAfterFilterCondition> workingDirLessThan(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessCondition(property: 4, value: value, caseSensitive: caseSensitive),
      );
    });
  }

  QueryBuilder<CronJob, CronJob, QAfterFilterCondition>
  workingDirLessThanOrEqualTo(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<CronJob, CronJob, QAfterFilterCondition> workingDirBetween(
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

  QueryBuilder<CronJob, CronJob, QAfterFilterCondition> workingDirStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
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

  QueryBuilder<CronJob, CronJob, QAfterFilterCondition> workingDirEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
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

  QueryBuilder<CronJob, CronJob, QAfterFilterCondition> workingDirContains(
    String value, {
    bool caseSensitive = true,
  }) {
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

  QueryBuilder<CronJob, CronJob, QAfterFilterCondition> workingDirMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
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

  QueryBuilder<CronJob, CronJob, QAfterFilterCondition> workingDirIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const EqualCondition(property: 4, value: ''),
      );
    });
  }

  QueryBuilder<CronJob, CronJob, QAfterFilterCondition> workingDirIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const GreaterCondition(property: 4, value: ''),
      );
    });
  }

  QueryBuilder<CronJob, CronJob, QAfterFilterCondition> enabledEqualTo(
    bool value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(property: 5, value: value),
      );
    });
  }

  QueryBuilder<CronJob, CronJob, QAfterFilterCondition> lastRunAtIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const IsNullCondition(property: 6));
    });
  }

  QueryBuilder<CronJob, CronJob, QAfterFilterCondition> lastRunAtIsNotNull() {
    return QueryBuilder.apply(not(), (query) {
      return query.addFilterCondition(const IsNullCondition(property: 6));
    });
  }

  QueryBuilder<CronJob, CronJob, QAfterFilterCondition> lastRunAtEqualTo(
    DateTime? value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(property: 6, value: value),
      );
    });
  }

  QueryBuilder<CronJob, CronJob, QAfterFilterCondition> lastRunAtGreaterThan(
    DateTime? value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterCondition(property: 6, value: value),
      );
    });
  }

  QueryBuilder<CronJob, CronJob, QAfterFilterCondition>
  lastRunAtGreaterThanOrEqualTo(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterOrEqualCondition(property: 6, value: value),
      );
    });
  }

  QueryBuilder<CronJob, CronJob, QAfterFilterCondition> lastRunAtLessThan(
    DateTime? value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(LessCondition(property: 6, value: value));
    });
  }

  QueryBuilder<CronJob, CronJob, QAfterFilterCondition>
  lastRunAtLessThanOrEqualTo(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessOrEqualCondition(property: 6, value: value),
      );
    });
  }

  QueryBuilder<CronJob, CronJob, QAfterFilterCondition> lastRunAtBetween(
    DateTime? lower,
    DateTime? upper,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        BetweenCondition(property: 6, lower: lower, upper: upper),
      );
    });
  }

  QueryBuilder<CronJob, CronJob, QAfterFilterCondition> lastStatusIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const IsNullCondition(property: 7));
    });
  }

  QueryBuilder<CronJob, CronJob, QAfterFilterCondition> lastStatusIsNotNull() {
    return QueryBuilder.apply(not(), (query) {
      return query.addFilterCondition(const IsNullCondition(property: 7));
    });
  }

  QueryBuilder<CronJob, CronJob, QAfterFilterCondition> lastStatusEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(property: 7, value: value, caseSensitive: caseSensitive),
      );
    });
  }

  QueryBuilder<CronJob, CronJob, QAfterFilterCondition> lastStatusGreaterThan(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterCondition(
          property: 7,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<CronJob, CronJob, QAfterFilterCondition>
  lastStatusGreaterThanOrEqualTo(String? value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterOrEqualCondition(
          property: 7,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<CronJob, CronJob, QAfterFilterCondition> lastStatusLessThan(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessCondition(property: 7, value: value, caseSensitive: caseSensitive),
      );
    });
  }

  QueryBuilder<CronJob, CronJob, QAfterFilterCondition>
  lastStatusLessThanOrEqualTo(String? value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessOrEqualCondition(
          property: 7,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<CronJob, CronJob, QAfterFilterCondition> lastStatusBetween(
    String? lower,
    String? upper, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        BetweenCondition(
          property: 7,
          lower: lower,
          upper: upper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<CronJob, CronJob, QAfterFilterCondition> lastStatusStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        StartsWithCondition(
          property: 7,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<CronJob, CronJob, QAfterFilterCondition> lastStatusEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EndsWithCondition(
          property: 7,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<CronJob, CronJob, QAfterFilterCondition> lastStatusContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        ContainsCondition(
          property: 7,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<CronJob, CronJob, QAfterFilterCondition> lastStatusMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        MatchesCondition(
          property: 7,
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<CronJob, CronJob, QAfterFilterCondition> lastStatusIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const EqualCondition(property: 7, value: ''),
      );
    });
  }

  QueryBuilder<CronJob, CronJob, QAfterFilterCondition> lastStatusIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const GreaterCondition(property: 7, value: ''),
      );
    });
  }

  QueryBuilder<CronJob, CronJob, QAfterFilterCondition> lastExitCodeIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const IsNullCondition(property: 8));
    });
  }

  QueryBuilder<CronJob, CronJob, QAfterFilterCondition>
  lastExitCodeIsNotNull() {
    return QueryBuilder.apply(not(), (query) {
      return query.addFilterCondition(const IsNullCondition(property: 8));
    });
  }

  QueryBuilder<CronJob, CronJob, QAfterFilterCondition> lastExitCodeEqualTo(
    int? value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(property: 8, value: value),
      );
    });
  }

  QueryBuilder<CronJob, CronJob, QAfterFilterCondition> lastExitCodeGreaterThan(
    int? value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterCondition(property: 8, value: value),
      );
    });
  }

  QueryBuilder<CronJob, CronJob, QAfterFilterCondition>
  lastExitCodeGreaterThanOrEqualTo(int? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterOrEqualCondition(property: 8, value: value),
      );
    });
  }

  QueryBuilder<CronJob, CronJob, QAfterFilterCondition> lastExitCodeLessThan(
    int? value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(LessCondition(property: 8, value: value));
    });
  }

  QueryBuilder<CronJob, CronJob, QAfterFilterCondition>
  lastExitCodeLessThanOrEqualTo(int? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessOrEqualCondition(property: 8, value: value),
      );
    });
  }

  QueryBuilder<CronJob, CronJob, QAfterFilterCondition> lastExitCodeBetween(
    int? lower,
    int? upper,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        BetweenCondition(property: 8, lower: lower, upper: upper),
      );
    });
  }

  QueryBuilder<CronJob, CronJob, QAfterFilterCondition> createdAtIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const IsNullCondition(property: 9));
    });
  }

  QueryBuilder<CronJob, CronJob, QAfterFilterCondition> createdAtIsNotNull() {
    return QueryBuilder.apply(not(), (query) {
      return query.addFilterCondition(const IsNullCondition(property: 9));
    });
  }

  QueryBuilder<CronJob, CronJob, QAfterFilterCondition> createdAtEqualTo(
    DateTime? value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(property: 9, value: value),
      );
    });
  }

  QueryBuilder<CronJob, CronJob, QAfterFilterCondition> createdAtGreaterThan(
    DateTime? value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterCondition(property: 9, value: value),
      );
    });
  }

  QueryBuilder<CronJob, CronJob, QAfterFilterCondition>
  createdAtGreaterThanOrEqualTo(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterOrEqualCondition(property: 9, value: value),
      );
    });
  }

  QueryBuilder<CronJob, CronJob, QAfterFilterCondition> createdAtLessThan(
    DateTime? value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(LessCondition(property: 9, value: value));
    });
  }

  QueryBuilder<CronJob, CronJob, QAfterFilterCondition>
  createdAtLessThanOrEqualTo(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessOrEqualCondition(property: 9, value: value),
      );
    });
  }

  QueryBuilder<CronJob, CronJob, QAfterFilterCondition> createdAtBetween(
    DateTime? lower,
    DateTime? upper,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        BetweenCondition(property: 9, lower: lower, upper: upper),
      );
    });
  }
}

extension CronJobQueryObject
    on QueryBuilder<CronJob, CronJob, QFilterCondition> {}

extension CronJobQuerySortBy on QueryBuilder<CronJob, CronJob, QSortBy> {
  QueryBuilder<CronJob, CronJob, QAfterSortBy> sortById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(0);
    });
  }

  QueryBuilder<CronJob, CronJob, QAfterSortBy> sortByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(0, sort: Sort.desc);
    });
  }

  QueryBuilder<CronJob, CronJob, QAfterSortBy> sortByName({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(1, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<CronJob, CronJob, QAfterSortBy> sortByNameDesc({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(1, sort: Sort.desc, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<CronJob, CronJob, QAfterSortBy> sortBySchedule({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(2, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<CronJob, CronJob, QAfterSortBy> sortByScheduleDesc({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(2, sort: Sort.desc, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<CronJob, CronJob, QAfterSortBy> sortByCommand({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(3, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<CronJob, CronJob, QAfterSortBy> sortByCommandDesc({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(3, sort: Sort.desc, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<CronJob, CronJob, QAfterSortBy> sortByWorkingDir({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(4, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<CronJob, CronJob, QAfterSortBy> sortByWorkingDirDesc({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(4, sort: Sort.desc, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<CronJob, CronJob, QAfterSortBy> sortByEnabled() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(5);
    });
  }

  QueryBuilder<CronJob, CronJob, QAfterSortBy> sortByEnabledDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(5, sort: Sort.desc);
    });
  }

  QueryBuilder<CronJob, CronJob, QAfterSortBy> sortByLastRunAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(6);
    });
  }

  QueryBuilder<CronJob, CronJob, QAfterSortBy> sortByLastRunAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(6, sort: Sort.desc);
    });
  }

  QueryBuilder<CronJob, CronJob, QAfterSortBy> sortByLastStatus({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(7, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<CronJob, CronJob, QAfterSortBy> sortByLastStatusDesc({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(7, sort: Sort.desc, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<CronJob, CronJob, QAfterSortBy> sortByLastExitCode() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(8);
    });
  }

  QueryBuilder<CronJob, CronJob, QAfterSortBy> sortByLastExitCodeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(8, sort: Sort.desc);
    });
  }

  QueryBuilder<CronJob, CronJob, QAfterSortBy> sortByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(9);
    });
  }

  QueryBuilder<CronJob, CronJob, QAfterSortBy> sortByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(9, sort: Sort.desc);
    });
  }
}

extension CronJobQuerySortThenBy
    on QueryBuilder<CronJob, CronJob, QSortThenBy> {
  QueryBuilder<CronJob, CronJob, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(0);
    });
  }

  QueryBuilder<CronJob, CronJob, QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(0, sort: Sort.desc);
    });
  }

  QueryBuilder<CronJob, CronJob, QAfterSortBy> thenByName({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(1, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<CronJob, CronJob, QAfterSortBy> thenByNameDesc({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(1, sort: Sort.desc, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<CronJob, CronJob, QAfterSortBy> thenBySchedule({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(2, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<CronJob, CronJob, QAfterSortBy> thenByScheduleDesc({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(2, sort: Sort.desc, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<CronJob, CronJob, QAfterSortBy> thenByCommand({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(3, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<CronJob, CronJob, QAfterSortBy> thenByCommandDesc({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(3, sort: Sort.desc, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<CronJob, CronJob, QAfterSortBy> thenByWorkingDir({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(4, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<CronJob, CronJob, QAfterSortBy> thenByWorkingDirDesc({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(4, sort: Sort.desc, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<CronJob, CronJob, QAfterSortBy> thenByEnabled() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(5);
    });
  }

  QueryBuilder<CronJob, CronJob, QAfterSortBy> thenByEnabledDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(5, sort: Sort.desc);
    });
  }

  QueryBuilder<CronJob, CronJob, QAfterSortBy> thenByLastRunAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(6);
    });
  }

  QueryBuilder<CronJob, CronJob, QAfterSortBy> thenByLastRunAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(6, sort: Sort.desc);
    });
  }

  QueryBuilder<CronJob, CronJob, QAfterSortBy> thenByLastStatus({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(7, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<CronJob, CronJob, QAfterSortBy> thenByLastStatusDesc({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(7, sort: Sort.desc, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<CronJob, CronJob, QAfterSortBy> thenByLastExitCode() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(8);
    });
  }

  QueryBuilder<CronJob, CronJob, QAfterSortBy> thenByLastExitCodeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(8, sort: Sort.desc);
    });
  }

  QueryBuilder<CronJob, CronJob, QAfterSortBy> thenByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(9);
    });
  }

  QueryBuilder<CronJob, CronJob, QAfterSortBy> thenByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(9, sort: Sort.desc);
    });
  }
}

extension CronJobQueryWhereDistinct
    on QueryBuilder<CronJob, CronJob, QDistinct> {
  QueryBuilder<CronJob, CronJob, QAfterDistinct> distinctByName({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(1, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<CronJob, CronJob, QAfterDistinct> distinctBySchedule({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(2, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<CronJob, CronJob, QAfterDistinct> distinctByCommand({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(3, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<CronJob, CronJob, QAfterDistinct> distinctByWorkingDir({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(4, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<CronJob, CronJob, QAfterDistinct> distinctByEnabled() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(5);
    });
  }

  QueryBuilder<CronJob, CronJob, QAfterDistinct> distinctByLastRunAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(6);
    });
  }

  QueryBuilder<CronJob, CronJob, QAfterDistinct> distinctByLastStatus({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(7, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<CronJob, CronJob, QAfterDistinct> distinctByLastExitCode() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(8);
    });
  }

  QueryBuilder<CronJob, CronJob, QAfterDistinct> distinctByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(9);
    });
  }
}

extension CronJobQueryProperty1 on QueryBuilder<CronJob, CronJob, QProperty> {
  QueryBuilder<CronJob, int, QAfterProperty> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(0);
    });
  }

  QueryBuilder<CronJob, String, QAfterProperty> nameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(1);
    });
  }

  QueryBuilder<CronJob, String, QAfterProperty> scheduleProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(2);
    });
  }

  QueryBuilder<CronJob, String, QAfterProperty> commandProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(3);
    });
  }

  QueryBuilder<CronJob, String, QAfterProperty> workingDirProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(4);
    });
  }

  QueryBuilder<CronJob, bool, QAfterProperty> enabledProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(5);
    });
  }

  QueryBuilder<CronJob, DateTime?, QAfterProperty> lastRunAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(6);
    });
  }

  QueryBuilder<CronJob, String?, QAfterProperty> lastStatusProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(7);
    });
  }

  QueryBuilder<CronJob, int?, QAfterProperty> lastExitCodeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(8);
    });
  }

  QueryBuilder<CronJob, DateTime?, QAfterProperty> createdAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(9);
    });
  }
}

extension CronJobQueryProperty2<R> on QueryBuilder<CronJob, R, QAfterProperty> {
  QueryBuilder<CronJob, (R, int), QAfterProperty> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(0);
    });
  }

  QueryBuilder<CronJob, (R, String), QAfterProperty> nameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(1);
    });
  }

  QueryBuilder<CronJob, (R, String), QAfterProperty> scheduleProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(2);
    });
  }

  QueryBuilder<CronJob, (R, String), QAfterProperty> commandProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(3);
    });
  }

  QueryBuilder<CronJob, (R, String), QAfterProperty> workingDirProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(4);
    });
  }

  QueryBuilder<CronJob, (R, bool), QAfterProperty> enabledProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(5);
    });
  }

  QueryBuilder<CronJob, (R, DateTime?), QAfterProperty> lastRunAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(6);
    });
  }

  QueryBuilder<CronJob, (R, String?), QAfterProperty> lastStatusProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(7);
    });
  }

  QueryBuilder<CronJob, (R, int?), QAfterProperty> lastExitCodeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(8);
    });
  }

  QueryBuilder<CronJob, (R, DateTime?), QAfterProperty> createdAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(9);
    });
  }
}

extension CronJobQueryProperty3<R1, R2>
    on QueryBuilder<CronJob, (R1, R2), QAfterProperty> {
  QueryBuilder<CronJob, (R1, R2, int), QOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(0);
    });
  }

  QueryBuilder<CronJob, (R1, R2, String), QOperations> nameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(1);
    });
  }

  QueryBuilder<CronJob, (R1, R2, String), QOperations> scheduleProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(2);
    });
  }

  QueryBuilder<CronJob, (R1, R2, String), QOperations> commandProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(3);
    });
  }

  QueryBuilder<CronJob, (R1, R2, String), QOperations> workingDirProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(4);
    });
  }

  QueryBuilder<CronJob, (R1, R2, bool), QOperations> enabledProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(5);
    });
  }

  QueryBuilder<CronJob, (R1, R2, DateTime?), QOperations> lastRunAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(6);
    });
  }

  QueryBuilder<CronJob, (R1, R2, String?), QOperations> lastStatusProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(7);
    });
  }

  QueryBuilder<CronJob, (R1, R2, int?), QOperations> lastExitCodeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(8);
    });
  }

  QueryBuilder<CronJob, (R1, R2, DateTime?), QOperations> createdAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(9);
    });
  }
}
