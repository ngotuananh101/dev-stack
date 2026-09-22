// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'site_model.dart';

// **************************************************************************
// _IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, invalid_use_of_protected_member, lines_longer_than_80_chars, constant_identifier_names, avoid_js_rounded_ints, no_leading_underscores_for_local_identifiers, require_trailing_commas, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_in_if_null_operators, library_private_types_in_public_api, prefer_const_constructors
// ignore_for_file: type=lint

extension GetSiteModelCollection on Isar {
  IsarCollection<int, SiteModel> get siteModels => this.collection();
}

final SiteModelSchema = IsarGeneratedSchema(
  schema: IsarSchema(
    name: 'SiteModel',
    idName: 'id',
    embedded: false,
    properties: [
      IsarPropertySchema(name: 'domain', type: IsarType.string),
      IsarPropertySchema(name: 'rootDir', type: IsarType.string),
      IsarPropertySchema(name: 'siteType', type: IsarType.string),
      IsarPropertySchema(name: 'phpVersion', type: IsarType.string),
      IsarPropertySchema(name: 'phpPort', type: IsarType.long),
      IsarPropertySchema(name: 'proxyTarget', type: IsarType.string),
      IsarPropertySchema(name: 'command', type: IsarType.string),
      IsarPropertySchema(name: 'port', type: IsarType.long),
      IsarPropertySchema(name: 'autoStart', type: IsarType.bool),
      IsarPropertySchema(name: 'useSsl', type: IsarType.bool),
      IsarPropertySchema(name: 'createdAt', type: IsarType.dateTime),
    ],
    indexes: [
      IsarIndexSchema(
        name: 'domain',
        properties: ["domain"],
        unique: true,
        hash: false,
      ),
    ],
  ),
  converter: IsarObjectConverter<int, SiteModel>(
    serialize: serializeSiteModel,
    deserialize: deserializeSiteModel,
    deserializeProperty: deserializeSiteModelProp,
  ),
  getEmbeddedSchemas: () => [],
);

@isarProtected
int serializeSiteModel(IsarWriter writer, SiteModel object) {
  IsarCore.writeString(writer, 1, object.domain);
  IsarCore.writeString(writer, 2, object.rootDir);
  IsarCore.writeString(writer, 3, object.siteType);
  {
    final value = object.phpVersion;
    if (value == null) {
      IsarCore.writeNull(writer, 4);
    } else {
      IsarCore.writeString(writer, 4, value);
    }
  }
  IsarCore.writeLong(writer, 5, object.phpPort ?? -9223372036854775808);
  {
    final value = object.proxyTarget;
    if (value == null) {
      IsarCore.writeNull(writer, 6);
    } else {
      IsarCore.writeString(writer, 6, value);
    }
  }
  {
    final value = object.command;
    if (value == null) {
      IsarCore.writeNull(writer, 7);
    } else {
      IsarCore.writeString(writer, 7, value);
    }
  }
  IsarCore.writeLong(writer, 8, object.port ?? -9223372036854775808);
  IsarCore.writeBool(writer, 9, value: object.autoStart);
  IsarCore.writeBool(writer, 10, value: object.useSsl);
  IsarCore.writeLong(
    writer,
    11,
    object.createdAt?.toUtc().microsecondsSinceEpoch ?? -9223372036854775808,
  );
  return object.id;
}

@isarProtected
SiteModel deserializeSiteModel(IsarReader reader) {
  final int _id;
  _id = IsarCore.readId(reader);
  final String _domain;
  _domain = IsarCore.readString(reader, 1) ?? '';
  final String _rootDir;
  _rootDir = IsarCore.readString(reader, 2) ?? '';
  final String _siteType;
  _siteType = IsarCore.readString(reader, 3) ?? 'php';
  final String? _phpVersion;
  _phpVersion = IsarCore.readString(reader, 4);
  final int? _phpPort;
  {
    final value = IsarCore.readLong(reader, 5);
    if (value == -9223372036854775808) {
      _phpPort = null;
    } else {
      _phpPort = value;
    }
  }
  final String? _proxyTarget;
  _proxyTarget = IsarCore.readString(reader, 6);
  final String? _command;
  _command = IsarCore.readString(reader, 7);
  final int? _port;
  {
    final value = IsarCore.readLong(reader, 8);
    if (value == -9223372036854775808) {
      _port = null;
    } else {
      _port = value;
    }
  }
  final bool _autoStart;
  _autoStart = IsarCore.readBool(reader, 9);
  final bool _useSsl;
  _useSsl = IsarCore.readBool(reader, 10);
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
  final object = SiteModel(
    id: _id,
    domain: _domain,
    rootDir: _rootDir,
    siteType: _siteType,
    phpVersion: _phpVersion,
    phpPort: _phpPort,
    proxyTarget: _proxyTarget,
    command: _command,
    port: _port,
    autoStart: _autoStart,
    useSsl: _useSsl,
    createdAt: _createdAt,
  );
  return object;
}

@isarProtected
dynamic deserializeSiteModelProp(IsarReader reader, int property) {
  switch (property) {
    case 0:
      return IsarCore.readId(reader);
    case 1:
      return IsarCore.readString(reader, 1) ?? '';
    case 2:
      return IsarCore.readString(reader, 2) ?? '';
    case 3:
      return IsarCore.readString(reader, 3) ?? 'php';
    case 4:
      return IsarCore.readString(reader, 4);
    case 5:
      {
        final value = IsarCore.readLong(reader, 5);
        if (value == -9223372036854775808) {
          return null;
        } else {
          return value;
        }
      }
    case 6:
      return IsarCore.readString(reader, 6);
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
      return IsarCore.readBool(reader, 9);
    case 10:
      return IsarCore.readBool(reader, 10);
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

sealed class _SiteModelUpdate {
  bool call({
    required int id,
    String? domain,
    String? rootDir,
    String? siteType,
    String? phpVersion,
    int? phpPort,
    String? proxyTarget,
    String? command,
    int? port,
    bool? autoStart,
    bool? useSsl,
    DateTime? createdAt,
  });
}

class _SiteModelUpdateImpl implements _SiteModelUpdate {
  const _SiteModelUpdateImpl(this.collection);

  final IsarCollection<int, SiteModel> collection;

  @override
  bool call({
    required int id,
    Object? domain = ignore,
    Object? rootDir = ignore,
    Object? siteType = ignore,
    Object? phpVersion = ignore,
    Object? phpPort = ignore,
    Object? proxyTarget = ignore,
    Object? command = ignore,
    Object? port = ignore,
    Object? autoStart = ignore,
    Object? useSsl = ignore,
    Object? createdAt = ignore,
  }) {
    return collection.updateProperties(
          [id],
          {
            if (domain != ignore) 1: domain as String?,
            if (rootDir != ignore) 2: rootDir as String?,
            if (siteType != ignore) 3: siteType as String?,
            if (phpVersion != ignore) 4: phpVersion as String?,
            if (phpPort != ignore) 5: phpPort as int?,
            if (proxyTarget != ignore) 6: proxyTarget as String?,
            if (command != ignore) 7: command as String?,
            if (port != ignore) 8: port as int?,
            if (autoStart != ignore) 9: autoStart as bool?,
            if (useSsl != ignore) 10: useSsl as bool?,
            if (createdAt != ignore) 11: createdAt as DateTime?,
          },
        ) >
        0;
  }
}

sealed class _SiteModelUpdateAll {
  int call({
    required List<int> id,
    String? domain,
    String? rootDir,
    String? siteType,
    String? phpVersion,
    int? phpPort,
    String? proxyTarget,
    String? command,
    int? port,
    bool? autoStart,
    bool? useSsl,
    DateTime? createdAt,
  });
}

class _SiteModelUpdateAllImpl implements _SiteModelUpdateAll {
  const _SiteModelUpdateAllImpl(this.collection);

  final IsarCollection<int, SiteModel> collection;

  @override
  int call({
    required List<int> id,
    Object? domain = ignore,
    Object? rootDir = ignore,
    Object? siteType = ignore,
    Object? phpVersion = ignore,
    Object? phpPort = ignore,
    Object? proxyTarget = ignore,
    Object? command = ignore,
    Object? port = ignore,
    Object? autoStart = ignore,
    Object? useSsl = ignore,
    Object? createdAt = ignore,
  }) {
    return collection.updateProperties(id, {
      if (domain != ignore) 1: domain as String?,
      if (rootDir != ignore) 2: rootDir as String?,
      if (siteType != ignore) 3: siteType as String?,
      if (phpVersion != ignore) 4: phpVersion as String?,
      if (phpPort != ignore) 5: phpPort as int?,
      if (proxyTarget != ignore) 6: proxyTarget as String?,
      if (command != ignore) 7: command as String?,
      if (port != ignore) 8: port as int?,
      if (autoStart != ignore) 9: autoStart as bool?,
      if (useSsl != ignore) 10: useSsl as bool?,
      if (createdAt != ignore) 11: createdAt as DateTime?,
    });
  }
}

extension SiteModelUpdate on IsarCollection<int, SiteModel> {
  _SiteModelUpdate get update => _SiteModelUpdateImpl(this);

  _SiteModelUpdateAll get updateAll => _SiteModelUpdateAllImpl(this);
}

sealed class _SiteModelQueryUpdate {
  int call({
    String? domain,
    String? rootDir,
    String? siteType,
    String? phpVersion,
    int? phpPort,
    String? proxyTarget,
    String? command,
    int? port,
    bool? autoStart,
    bool? useSsl,
    DateTime? createdAt,
  });
}

class _SiteModelQueryUpdateImpl implements _SiteModelQueryUpdate {
  const _SiteModelQueryUpdateImpl(this.query, {this.limit});

  final IsarQuery<SiteModel> query;
  final int? limit;

  @override
  int call({
    Object? domain = ignore,
    Object? rootDir = ignore,
    Object? siteType = ignore,
    Object? phpVersion = ignore,
    Object? phpPort = ignore,
    Object? proxyTarget = ignore,
    Object? command = ignore,
    Object? port = ignore,
    Object? autoStart = ignore,
    Object? useSsl = ignore,
    Object? createdAt = ignore,
  }) {
    return query.updateProperties(limit: limit, {
      if (domain != ignore) 1: domain as String?,
      if (rootDir != ignore) 2: rootDir as String?,
      if (siteType != ignore) 3: siteType as String?,
      if (phpVersion != ignore) 4: phpVersion as String?,
      if (phpPort != ignore) 5: phpPort as int?,
      if (proxyTarget != ignore) 6: proxyTarget as String?,
      if (command != ignore) 7: command as String?,
      if (port != ignore) 8: port as int?,
      if (autoStart != ignore) 9: autoStart as bool?,
      if (useSsl != ignore) 10: useSsl as bool?,
      if (createdAt != ignore) 11: createdAt as DateTime?,
    });
  }
}

extension SiteModelQueryUpdate on IsarQuery<SiteModel> {
  _SiteModelQueryUpdate get updateFirst =>
      _SiteModelQueryUpdateImpl(this, limit: 1);

  _SiteModelQueryUpdate get updateAll => _SiteModelQueryUpdateImpl(this);
}

class _SiteModelQueryBuilderUpdateImpl implements _SiteModelQueryUpdate {
  const _SiteModelQueryBuilderUpdateImpl(this.query, {this.limit});

  final QueryBuilder<SiteModel, SiteModel, QOperations> query;
  final int? limit;

  @override
  int call({
    Object? domain = ignore,
    Object? rootDir = ignore,
    Object? siteType = ignore,
    Object? phpVersion = ignore,
    Object? phpPort = ignore,
    Object? proxyTarget = ignore,
    Object? command = ignore,
    Object? port = ignore,
    Object? autoStart = ignore,
    Object? useSsl = ignore,
    Object? createdAt = ignore,
  }) {
    final q = query.build();
    try {
      return q.updateProperties(limit: limit, {
        if (domain != ignore) 1: domain as String?,
        if (rootDir != ignore) 2: rootDir as String?,
        if (siteType != ignore) 3: siteType as String?,
        if (phpVersion != ignore) 4: phpVersion as String?,
        if (phpPort != ignore) 5: phpPort as int?,
        if (proxyTarget != ignore) 6: proxyTarget as String?,
        if (command != ignore) 7: command as String?,
        if (port != ignore) 8: port as int?,
        if (autoStart != ignore) 9: autoStart as bool?,
        if (useSsl != ignore) 10: useSsl as bool?,
        if (createdAt != ignore) 11: createdAt as DateTime?,
      });
    } finally {
      q.close();
    }
  }
}

extension SiteModelQueryBuilderUpdate
    on QueryBuilder<SiteModel, SiteModel, QOperations> {
  _SiteModelQueryUpdate get updateFirst =>
      _SiteModelQueryBuilderUpdateImpl(this, limit: 1);

  _SiteModelQueryUpdate get updateAll => _SiteModelQueryBuilderUpdateImpl(this);
}

extension SiteModelQueryFilter
    on QueryBuilder<SiteModel, SiteModel, QFilterCondition> {
  QueryBuilder<SiteModel, SiteModel, QAfterFilterCondition> idEqualTo(
    int value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(property: 0, value: value),
      );
    });
  }

  QueryBuilder<SiteModel, SiteModel, QAfterFilterCondition> idGreaterThan(
    int value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterCondition(property: 0, value: value),
      );
    });
  }

  QueryBuilder<SiteModel, SiteModel, QAfterFilterCondition>
  idGreaterThanOrEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterOrEqualCondition(property: 0, value: value),
      );
    });
  }

  QueryBuilder<SiteModel, SiteModel, QAfterFilterCondition> idLessThan(
    int value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(LessCondition(property: 0, value: value));
    });
  }

  QueryBuilder<SiteModel, SiteModel, QAfterFilterCondition> idLessThanOrEqualTo(
    int value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessOrEqualCondition(property: 0, value: value),
      );
    });
  }

  QueryBuilder<SiteModel, SiteModel, QAfterFilterCondition> idBetween(
    int lower,
    int upper,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        BetweenCondition(property: 0, lower: lower, upper: upper),
      );
    });
  }

  QueryBuilder<SiteModel, SiteModel, QAfterFilterCondition> domainEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(property: 1, value: value, caseSensitive: caseSensitive),
      );
    });
  }

  QueryBuilder<SiteModel, SiteModel, QAfterFilterCondition> domainGreaterThan(
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

  QueryBuilder<SiteModel, SiteModel, QAfterFilterCondition>
  domainGreaterThanOrEqualTo(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<SiteModel, SiteModel, QAfterFilterCondition> domainLessThan(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessCondition(property: 1, value: value, caseSensitive: caseSensitive),
      );
    });
  }

  QueryBuilder<SiteModel, SiteModel, QAfterFilterCondition>
  domainLessThanOrEqualTo(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<SiteModel, SiteModel, QAfterFilterCondition> domainBetween(
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

  QueryBuilder<SiteModel, SiteModel, QAfterFilterCondition> domainStartsWith(
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

  QueryBuilder<SiteModel, SiteModel, QAfterFilterCondition> domainEndsWith(
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

  QueryBuilder<SiteModel, SiteModel, QAfterFilterCondition> domainContains(
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

  QueryBuilder<SiteModel, SiteModel, QAfterFilterCondition> domainMatches(
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

  QueryBuilder<SiteModel, SiteModel, QAfterFilterCondition> domainIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const EqualCondition(property: 1, value: ''),
      );
    });
  }

  QueryBuilder<SiteModel, SiteModel, QAfterFilterCondition> domainIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const GreaterCondition(property: 1, value: ''),
      );
    });
  }

  QueryBuilder<SiteModel, SiteModel, QAfterFilterCondition> rootDirEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(property: 2, value: value, caseSensitive: caseSensitive),
      );
    });
  }

  QueryBuilder<SiteModel, SiteModel, QAfterFilterCondition> rootDirGreaterThan(
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

  QueryBuilder<SiteModel, SiteModel, QAfterFilterCondition>
  rootDirGreaterThanOrEqualTo(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<SiteModel, SiteModel, QAfterFilterCondition> rootDirLessThan(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessCondition(property: 2, value: value, caseSensitive: caseSensitive),
      );
    });
  }

  QueryBuilder<SiteModel, SiteModel, QAfterFilterCondition>
  rootDirLessThanOrEqualTo(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<SiteModel, SiteModel, QAfterFilterCondition> rootDirBetween(
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

  QueryBuilder<SiteModel, SiteModel, QAfterFilterCondition> rootDirStartsWith(
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

  QueryBuilder<SiteModel, SiteModel, QAfterFilterCondition> rootDirEndsWith(
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

  QueryBuilder<SiteModel, SiteModel, QAfterFilterCondition> rootDirContains(
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

  QueryBuilder<SiteModel, SiteModel, QAfterFilterCondition> rootDirMatches(
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

  QueryBuilder<SiteModel, SiteModel, QAfterFilterCondition> rootDirIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const EqualCondition(property: 2, value: ''),
      );
    });
  }

  QueryBuilder<SiteModel, SiteModel, QAfterFilterCondition>
  rootDirIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const GreaterCondition(property: 2, value: ''),
      );
    });
  }

  QueryBuilder<SiteModel, SiteModel, QAfterFilterCondition> siteTypeEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(property: 3, value: value, caseSensitive: caseSensitive),
      );
    });
  }

  QueryBuilder<SiteModel, SiteModel, QAfterFilterCondition> siteTypeGreaterThan(
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

  QueryBuilder<SiteModel, SiteModel, QAfterFilterCondition>
  siteTypeGreaterThanOrEqualTo(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<SiteModel, SiteModel, QAfterFilterCondition> siteTypeLessThan(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessCondition(property: 3, value: value, caseSensitive: caseSensitive),
      );
    });
  }

  QueryBuilder<SiteModel, SiteModel, QAfterFilterCondition>
  siteTypeLessThanOrEqualTo(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<SiteModel, SiteModel, QAfterFilterCondition> siteTypeBetween(
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

  QueryBuilder<SiteModel, SiteModel, QAfterFilterCondition> siteTypeStartsWith(
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

  QueryBuilder<SiteModel, SiteModel, QAfterFilterCondition> siteTypeEndsWith(
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

  QueryBuilder<SiteModel, SiteModel, QAfterFilterCondition> siteTypeContains(
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

  QueryBuilder<SiteModel, SiteModel, QAfterFilterCondition> siteTypeMatches(
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

  QueryBuilder<SiteModel, SiteModel, QAfterFilterCondition> siteTypeIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const EqualCondition(property: 3, value: ''),
      );
    });
  }

  QueryBuilder<SiteModel, SiteModel, QAfterFilterCondition>
  siteTypeIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const GreaterCondition(property: 3, value: ''),
      );
    });
  }

  QueryBuilder<SiteModel, SiteModel, QAfterFilterCondition> phpVersionIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const IsNullCondition(property: 4));
    });
  }

  QueryBuilder<SiteModel, SiteModel, QAfterFilterCondition>
  phpVersionIsNotNull() {
    return QueryBuilder.apply(not(), (query) {
      return query.addFilterCondition(const IsNullCondition(property: 4));
    });
  }

  QueryBuilder<SiteModel, SiteModel, QAfterFilterCondition> phpVersionEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(property: 4, value: value, caseSensitive: caseSensitive),
      );
    });
  }

  QueryBuilder<SiteModel, SiteModel, QAfterFilterCondition>
  phpVersionGreaterThan(String? value, {bool caseSensitive = true}) {
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

  QueryBuilder<SiteModel, SiteModel, QAfterFilterCondition>
  phpVersionGreaterThanOrEqualTo(String? value, {bool caseSensitive = true}) {
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

  QueryBuilder<SiteModel, SiteModel, QAfterFilterCondition> phpVersionLessThan(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessCondition(property: 4, value: value, caseSensitive: caseSensitive),
      );
    });
  }

  QueryBuilder<SiteModel, SiteModel, QAfterFilterCondition>
  phpVersionLessThanOrEqualTo(String? value, {bool caseSensitive = true}) {
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

  QueryBuilder<SiteModel, SiteModel, QAfterFilterCondition> phpVersionBetween(
    String? lower,
    String? upper, {
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

  QueryBuilder<SiteModel, SiteModel, QAfterFilterCondition>
  phpVersionStartsWith(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<SiteModel, SiteModel, QAfterFilterCondition> phpVersionEndsWith(
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

  QueryBuilder<SiteModel, SiteModel, QAfterFilterCondition> phpVersionContains(
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

  QueryBuilder<SiteModel, SiteModel, QAfterFilterCondition> phpVersionMatches(
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

  QueryBuilder<SiteModel, SiteModel, QAfterFilterCondition>
  phpVersionIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const EqualCondition(property: 4, value: ''),
      );
    });
  }

  QueryBuilder<SiteModel, SiteModel, QAfterFilterCondition>
  phpVersionIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const GreaterCondition(property: 4, value: ''),
      );
    });
  }

  QueryBuilder<SiteModel, SiteModel, QAfterFilterCondition> phpPortIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const IsNullCondition(property: 5));
    });
  }

  QueryBuilder<SiteModel, SiteModel, QAfterFilterCondition> phpPortIsNotNull() {
    return QueryBuilder.apply(not(), (query) {
      return query.addFilterCondition(const IsNullCondition(property: 5));
    });
  }

  QueryBuilder<SiteModel, SiteModel, QAfterFilterCondition> phpPortEqualTo(
    int? value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(property: 5, value: value),
      );
    });
  }

  QueryBuilder<SiteModel, SiteModel, QAfterFilterCondition> phpPortGreaterThan(
    int? value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterCondition(property: 5, value: value),
      );
    });
  }

  QueryBuilder<SiteModel, SiteModel, QAfterFilterCondition>
  phpPortGreaterThanOrEqualTo(int? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterOrEqualCondition(property: 5, value: value),
      );
    });
  }

  QueryBuilder<SiteModel, SiteModel, QAfterFilterCondition> phpPortLessThan(
    int? value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(LessCondition(property: 5, value: value));
    });
  }

  QueryBuilder<SiteModel, SiteModel, QAfterFilterCondition>
  phpPortLessThanOrEqualTo(int? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessOrEqualCondition(property: 5, value: value),
      );
    });
  }

  QueryBuilder<SiteModel, SiteModel, QAfterFilterCondition> phpPortBetween(
    int? lower,
    int? upper,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        BetweenCondition(property: 5, lower: lower, upper: upper),
      );
    });
  }

  QueryBuilder<SiteModel, SiteModel, QAfterFilterCondition>
  proxyTargetIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const IsNullCondition(property: 6));
    });
  }

  QueryBuilder<SiteModel, SiteModel, QAfterFilterCondition>
  proxyTargetIsNotNull() {
    return QueryBuilder.apply(not(), (query) {
      return query.addFilterCondition(const IsNullCondition(property: 6));
    });
  }

  QueryBuilder<SiteModel, SiteModel, QAfterFilterCondition> proxyTargetEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(property: 6, value: value, caseSensitive: caseSensitive),
      );
    });
  }

  QueryBuilder<SiteModel, SiteModel, QAfterFilterCondition>
  proxyTargetGreaterThan(String? value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterCondition(
          property: 6,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SiteModel, SiteModel, QAfterFilterCondition>
  proxyTargetGreaterThanOrEqualTo(String? value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterOrEqualCondition(
          property: 6,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SiteModel, SiteModel, QAfterFilterCondition> proxyTargetLessThan(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessCondition(property: 6, value: value, caseSensitive: caseSensitive),
      );
    });
  }

  QueryBuilder<SiteModel, SiteModel, QAfterFilterCondition>
  proxyTargetLessThanOrEqualTo(String? value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessOrEqualCondition(
          property: 6,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SiteModel, SiteModel, QAfterFilterCondition> proxyTargetBetween(
    String? lower,
    String? upper, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        BetweenCondition(
          property: 6,
          lower: lower,
          upper: upper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SiteModel, SiteModel, QAfterFilterCondition>
  proxyTargetStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        StartsWithCondition(
          property: 6,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SiteModel, SiteModel, QAfterFilterCondition> proxyTargetEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EndsWithCondition(
          property: 6,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SiteModel, SiteModel, QAfterFilterCondition> proxyTargetContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        ContainsCondition(
          property: 6,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SiteModel, SiteModel, QAfterFilterCondition> proxyTargetMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        MatchesCondition(
          property: 6,
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SiteModel, SiteModel, QAfterFilterCondition>
  proxyTargetIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const EqualCondition(property: 6, value: ''),
      );
    });
  }

  QueryBuilder<SiteModel, SiteModel, QAfterFilterCondition>
  proxyTargetIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const GreaterCondition(property: 6, value: ''),
      );
    });
  }

  QueryBuilder<SiteModel, SiteModel, QAfterFilterCondition> commandIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const IsNullCondition(property: 7));
    });
  }

  QueryBuilder<SiteModel, SiteModel, QAfterFilterCondition> commandIsNotNull() {
    return QueryBuilder.apply(not(), (query) {
      return query.addFilterCondition(const IsNullCondition(property: 7));
    });
  }

  QueryBuilder<SiteModel, SiteModel, QAfterFilterCondition> commandEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(property: 7, value: value, caseSensitive: caseSensitive),
      );
    });
  }

  QueryBuilder<SiteModel, SiteModel, QAfterFilterCondition> commandGreaterThan(
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

  QueryBuilder<SiteModel, SiteModel, QAfterFilterCondition>
  commandGreaterThanOrEqualTo(String? value, {bool caseSensitive = true}) {
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

  QueryBuilder<SiteModel, SiteModel, QAfterFilterCondition> commandLessThan(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessCondition(property: 7, value: value, caseSensitive: caseSensitive),
      );
    });
  }

  QueryBuilder<SiteModel, SiteModel, QAfterFilterCondition>
  commandLessThanOrEqualTo(String? value, {bool caseSensitive = true}) {
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

  QueryBuilder<SiteModel, SiteModel, QAfterFilterCondition> commandBetween(
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

  QueryBuilder<SiteModel, SiteModel, QAfterFilterCondition> commandStartsWith(
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

  QueryBuilder<SiteModel, SiteModel, QAfterFilterCondition> commandEndsWith(
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

  QueryBuilder<SiteModel, SiteModel, QAfterFilterCondition> commandContains(
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

  QueryBuilder<SiteModel, SiteModel, QAfterFilterCondition> commandMatches(
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

  QueryBuilder<SiteModel, SiteModel, QAfterFilterCondition> commandIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const EqualCondition(property: 7, value: ''),
      );
    });
  }

  QueryBuilder<SiteModel, SiteModel, QAfterFilterCondition>
  commandIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const GreaterCondition(property: 7, value: ''),
      );
    });
  }

  QueryBuilder<SiteModel, SiteModel, QAfterFilterCondition> portIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const IsNullCondition(property: 8));
    });
  }

  QueryBuilder<SiteModel, SiteModel, QAfterFilterCondition> portIsNotNull() {
    return QueryBuilder.apply(not(), (query) {
      return query.addFilterCondition(const IsNullCondition(property: 8));
    });
  }

  QueryBuilder<SiteModel, SiteModel, QAfterFilterCondition> portEqualTo(
    int? value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(property: 8, value: value),
      );
    });
  }

  QueryBuilder<SiteModel, SiteModel, QAfterFilterCondition> portGreaterThan(
    int? value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterCondition(property: 8, value: value),
      );
    });
  }

  QueryBuilder<SiteModel, SiteModel, QAfterFilterCondition>
  portGreaterThanOrEqualTo(int? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterOrEqualCondition(property: 8, value: value),
      );
    });
  }

  QueryBuilder<SiteModel, SiteModel, QAfterFilterCondition> portLessThan(
    int? value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(LessCondition(property: 8, value: value));
    });
  }

  QueryBuilder<SiteModel, SiteModel, QAfterFilterCondition>
  portLessThanOrEqualTo(int? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessOrEqualCondition(property: 8, value: value),
      );
    });
  }

  QueryBuilder<SiteModel, SiteModel, QAfterFilterCondition> portBetween(
    int? lower,
    int? upper,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        BetweenCondition(property: 8, lower: lower, upper: upper),
      );
    });
  }

  QueryBuilder<SiteModel, SiteModel, QAfterFilterCondition> autoStartEqualTo(
    bool value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(property: 9, value: value),
      );
    });
  }

  QueryBuilder<SiteModel, SiteModel, QAfterFilterCondition> useSslEqualTo(
    bool value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(property: 10, value: value),
      );
    });
  }

  QueryBuilder<SiteModel, SiteModel, QAfterFilterCondition> createdAtIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const IsNullCondition(property: 11));
    });
  }

  QueryBuilder<SiteModel, SiteModel, QAfterFilterCondition>
  createdAtIsNotNull() {
    return QueryBuilder.apply(not(), (query) {
      return query.addFilterCondition(const IsNullCondition(property: 11));
    });
  }

  QueryBuilder<SiteModel, SiteModel, QAfterFilterCondition> createdAtEqualTo(
    DateTime? value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(property: 11, value: value),
      );
    });
  }

  QueryBuilder<SiteModel, SiteModel, QAfterFilterCondition>
  createdAtGreaterThan(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterCondition(property: 11, value: value),
      );
    });
  }

  QueryBuilder<SiteModel, SiteModel, QAfterFilterCondition>
  createdAtGreaterThanOrEqualTo(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterOrEqualCondition(property: 11, value: value),
      );
    });
  }

  QueryBuilder<SiteModel, SiteModel, QAfterFilterCondition> createdAtLessThan(
    DateTime? value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessCondition(property: 11, value: value),
      );
    });
  }

  QueryBuilder<SiteModel, SiteModel, QAfterFilterCondition>
  createdAtLessThanOrEqualTo(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessOrEqualCondition(property: 11, value: value),
      );
    });
  }

  QueryBuilder<SiteModel, SiteModel, QAfterFilterCondition> createdAtBetween(
    DateTime? lower,
    DateTime? upper,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        BetweenCondition(property: 11, lower: lower, upper: upper),
      );
    });
  }
}

extension SiteModelQueryObject
    on QueryBuilder<SiteModel, SiteModel, QFilterCondition> {}

extension SiteModelQuerySortBy on QueryBuilder<SiteModel, SiteModel, QSortBy> {
  QueryBuilder<SiteModel, SiteModel, QAfterSortBy> sortById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(0);
    });
  }

  QueryBuilder<SiteModel, SiteModel, QAfterSortBy> sortByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(0, sort: Sort.desc);
    });
  }

  QueryBuilder<SiteModel, SiteModel, QAfterSortBy> sortByDomain({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(1, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<SiteModel, SiteModel, QAfterSortBy> sortByDomainDesc({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(1, sort: Sort.desc, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<SiteModel, SiteModel, QAfterSortBy> sortByRootDir({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(2, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<SiteModel, SiteModel, QAfterSortBy> sortByRootDirDesc({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(2, sort: Sort.desc, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<SiteModel, SiteModel, QAfterSortBy> sortBySiteType({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(3, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<SiteModel, SiteModel, QAfterSortBy> sortBySiteTypeDesc({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(3, sort: Sort.desc, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<SiteModel, SiteModel, QAfterSortBy> sortByPhpVersion({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(4, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<SiteModel, SiteModel, QAfterSortBy> sortByPhpVersionDesc({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(4, sort: Sort.desc, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<SiteModel, SiteModel, QAfterSortBy> sortByPhpPort() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(5);
    });
  }

  QueryBuilder<SiteModel, SiteModel, QAfterSortBy> sortByPhpPortDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(5, sort: Sort.desc);
    });
  }

  QueryBuilder<SiteModel, SiteModel, QAfterSortBy> sortByProxyTarget({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(6, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<SiteModel, SiteModel, QAfterSortBy> sortByProxyTargetDesc({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(6, sort: Sort.desc, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<SiteModel, SiteModel, QAfterSortBy> sortByCommand({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(7, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<SiteModel, SiteModel, QAfterSortBy> sortByCommandDesc({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(7, sort: Sort.desc, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<SiteModel, SiteModel, QAfterSortBy> sortByPort() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(8);
    });
  }

  QueryBuilder<SiteModel, SiteModel, QAfterSortBy> sortByPortDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(8, sort: Sort.desc);
    });
  }

  QueryBuilder<SiteModel, SiteModel, QAfterSortBy> sortByAutoStart() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(9);
    });
  }

  QueryBuilder<SiteModel, SiteModel, QAfterSortBy> sortByAutoStartDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(9, sort: Sort.desc);
    });
  }

  QueryBuilder<SiteModel, SiteModel, QAfterSortBy> sortByUseSsl() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(10);
    });
  }

  QueryBuilder<SiteModel, SiteModel, QAfterSortBy> sortByUseSslDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(10, sort: Sort.desc);
    });
  }

  QueryBuilder<SiteModel, SiteModel, QAfterSortBy> sortByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(11);
    });
  }

  QueryBuilder<SiteModel, SiteModel, QAfterSortBy> sortByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(11, sort: Sort.desc);
    });
  }
}

extension SiteModelQuerySortThenBy
    on QueryBuilder<SiteModel, SiteModel, QSortThenBy> {
  QueryBuilder<SiteModel, SiteModel, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(0);
    });
  }

  QueryBuilder<SiteModel, SiteModel, QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(0, sort: Sort.desc);
    });
  }

  QueryBuilder<SiteModel, SiteModel, QAfterSortBy> thenByDomain({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(1, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<SiteModel, SiteModel, QAfterSortBy> thenByDomainDesc({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(1, sort: Sort.desc, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<SiteModel, SiteModel, QAfterSortBy> thenByRootDir({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(2, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<SiteModel, SiteModel, QAfterSortBy> thenByRootDirDesc({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(2, sort: Sort.desc, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<SiteModel, SiteModel, QAfterSortBy> thenBySiteType({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(3, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<SiteModel, SiteModel, QAfterSortBy> thenBySiteTypeDesc({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(3, sort: Sort.desc, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<SiteModel, SiteModel, QAfterSortBy> thenByPhpVersion({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(4, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<SiteModel, SiteModel, QAfterSortBy> thenByPhpVersionDesc({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(4, sort: Sort.desc, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<SiteModel, SiteModel, QAfterSortBy> thenByPhpPort() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(5);
    });
  }

  QueryBuilder<SiteModel, SiteModel, QAfterSortBy> thenByPhpPortDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(5, sort: Sort.desc);
    });
  }

  QueryBuilder<SiteModel, SiteModel, QAfterSortBy> thenByProxyTarget({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(6, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<SiteModel, SiteModel, QAfterSortBy> thenByProxyTargetDesc({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(6, sort: Sort.desc, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<SiteModel, SiteModel, QAfterSortBy> thenByCommand({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(7, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<SiteModel, SiteModel, QAfterSortBy> thenByCommandDesc({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(7, sort: Sort.desc, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<SiteModel, SiteModel, QAfterSortBy> thenByPort() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(8);
    });
  }

  QueryBuilder<SiteModel, SiteModel, QAfterSortBy> thenByPortDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(8, sort: Sort.desc);
    });
  }

  QueryBuilder<SiteModel, SiteModel, QAfterSortBy> thenByAutoStart() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(9);
    });
  }

  QueryBuilder<SiteModel, SiteModel, QAfterSortBy> thenByAutoStartDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(9, sort: Sort.desc);
    });
  }

  QueryBuilder<SiteModel, SiteModel, QAfterSortBy> thenByUseSsl() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(10);
    });
  }

  QueryBuilder<SiteModel, SiteModel, QAfterSortBy> thenByUseSslDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(10, sort: Sort.desc);
    });
  }

  QueryBuilder<SiteModel, SiteModel, QAfterSortBy> thenByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(11);
    });
  }

  QueryBuilder<SiteModel, SiteModel, QAfterSortBy> thenByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(11, sort: Sort.desc);
    });
  }
}

extension SiteModelQueryWhereDistinct
    on QueryBuilder<SiteModel, SiteModel, QDistinct> {
  QueryBuilder<SiteModel, SiteModel, QAfterDistinct> distinctByDomain({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(1, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<SiteModel, SiteModel, QAfterDistinct> distinctByRootDir({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(2, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<SiteModel, SiteModel, QAfterDistinct> distinctBySiteType({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(3, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<SiteModel, SiteModel, QAfterDistinct> distinctByPhpVersion({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(4, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<SiteModel, SiteModel, QAfterDistinct> distinctByPhpPort() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(5);
    });
  }

  QueryBuilder<SiteModel, SiteModel, QAfterDistinct> distinctByProxyTarget({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(6, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<SiteModel, SiteModel, QAfterDistinct> distinctByCommand({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(7, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<SiteModel, SiteModel, QAfterDistinct> distinctByPort() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(8);
    });
  }

  QueryBuilder<SiteModel, SiteModel, QAfterDistinct> distinctByAutoStart() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(9);
    });
  }

  QueryBuilder<SiteModel, SiteModel, QAfterDistinct> distinctByUseSsl() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(10);
    });
  }

  QueryBuilder<SiteModel, SiteModel, QAfterDistinct> distinctByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(11);
    });
  }
}

extension SiteModelQueryProperty1
    on QueryBuilder<SiteModel, SiteModel, QProperty> {
  QueryBuilder<SiteModel, int, QAfterProperty> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(0);
    });
  }

  QueryBuilder<SiteModel, String, QAfterProperty> domainProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(1);
    });
  }

  QueryBuilder<SiteModel, String, QAfterProperty> rootDirProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(2);
    });
  }

  QueryBuilder<SiteModel, String, QAfterProperty> siteTypeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(3);
    });
  }

  QueryBuilder<SiteModel, String?, QAfterProperty> phpVersionProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(4);
    });
  }

  QueryBuilder<SiteModel, int?, QAfterProperty> phpPortProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(5);
    });
  }

  QueryBuilder<SiteModel, String?, QAfterProperty> proxyTargetProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(6);
    });
  }

  QueryBuilder<SiteModel, String?, QAfterProperty> commandProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(7);
    });
  }

  QueryBuilder<SiteModel, int?, QAfterProperty> portProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(8);
    });
  }

  QueryBuilder<SiteModel, bool, QAfterProperty> autoStartProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(9);
    });
  }

  QueryBuilder<SiteModel, bool, QAfterProperty> useSslProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(10);
    });
  }

  QueryBuilder<SiteModel, DateTime?, QAfterProperty> createdAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(11);
    });
  }
}

extension SiteModelQueryProperty2<R>
    on QueryBuilder<SiteModel, R, QAfterProperty> {
  QueryBuilder<SiteModel, (R, int), QAfterProperty> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(0);
    });
  }

  QueryBuilder<SiteModel, (R, String), QAfterProperty> domainProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(1);
    });
  }

  QueryBuilder<SiteModel, (R, String), QAfterProperty> rootDirProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(2);
    });
  }

  QueryBuilder<SiteModel, (R, String), QAfterProperty> siteTypeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(3);
    });
  }

  QueryBuilder<SiteModel, (R, String?), QAfterProperty> phpVersionProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(4);
    });
  }

  QueryBuilder<SiteModel, (R, int?), QAfterProperty> phpPortProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(5);
    });
  }

  QueryBuilder<SiteModel, (R, String?), QAfterProperty> proxyTargetProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(6);
    });
  }

  QueryBuilder<SiteModel, (R, String?), QAfterProperty> commandProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(7);
    });
  }

  QueryBuilder<SiteModel, (R, int?), QAfterProperty> portProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(8);
    });
  }

  QueryBuilder<SiteModel, (R, bool), QAfterProperty> autoStartProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(9);
    });
  }

  QueryBuilder<SiteModel, (R, bool), QAfterProperty> useSslProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(10);
    });
  }

  QueryBuilder<SiteModel, (R, DateTime?), QAfterProperty> createdAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(11);
    });
  }
}

extension SiteModelQueryProperty3<R1, R2>
    on QueryBuilder<SiteModel, (R1, R2), QAfterProperty> {
  QueryBuilder<SiteModel, (R1, R2, int), QOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(0);
    });
  }

  QueryBuilder<SiteModel, (R1, R2, String), QOperations> domainProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(1);
    });
  }

  QueryBuilder<SiteModel, (R1, R2, String), QOperations> rootDirProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(2);
    });
  }

  QueryBuilder<SiteModel, (R1, R2, String), QOperations> siteTypeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(3);
    });
  }

  QueryBuilder<SiteModel, (R1, R2, String?), QOperations> phpVersionProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(4);
    });
  }

  QueryBuilder<SiteModel, (R1, R2, int?), QOperations> phpPortProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(5);
    });
  }

  QueryBuilder<SiteModel, (R1, R2, String?), QOperations>
  proxyTargetProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(6);
    });
  }

  QueryBuilder<SiteModel, (R1, R2, String?), QOperations> commandProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(7);
    });
  }

  QueryBuilder<SiteModel, (R1, R2, int?), QOperations> portProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(8);
    });
  }

  QueryBuilder<SiteModel, (R1, R2, bool), QOperations> autoStartProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(9);
    });
  }

  QueryBuilder<SiteModel, (R1, R2, bool), QOperations> useSslProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(10);
    });
  }

  QueryBuilder<SiteModel, (R1, R2, DateTime?), QOperations>
  createdAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(11);
    });
  }
}
