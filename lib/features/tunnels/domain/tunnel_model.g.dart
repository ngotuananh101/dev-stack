// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tunnel_model.dart';

// **************************************************************************
// _IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, invalid_use_of_protected_member, lines_longer_than_80_chars, constant_identifier_names, avoid_js_rounded_ints, no_leading_underscores_for_local_identifiers, require_trailing_commas, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_in_if_null_operators, library_private_types_in_public_api, prefer_const_constructors
// ignore_for_file: type=lint

extension GetTunnelModelCollection on Isar {
  IsarCollection<int, TunnelModel> get tunnelModels => this.collection();
}

final TunnelModelSchema = IsarGeneratedSchema(
  schema: IsarSchema(
    name: 'TunnelModel',
    idName: 'id',
    embedded: false,
    properties: [
      IsarPropertySchema(name: 'name', type: IsarType.string),
      IsarPropertySchema(name: 'provider', type: IsarType.string),
      IsarPropertySchema(name: 'targetType', type: IsarType.string),
      IsarPropertySchema(name: 'targetSiteDomain', type: IsarType.string),
      IsarPropertySchema(name: 'targetPort', type: IsarType.long),
      IsarPropertySchema(name: 'authToken', type: IsarType.string),
      IsarPropertySchema(name: 'customDomain', type: IsarType.string),
      IsarPropertySchema(name: 'autoStart', type: IsarType.bool),
      IsarPropertySchema(name: 'createdAt', type: IsarType.dateTime),
      IsarPropertySchema(name: 'lastActiveAt', type: IsarType.dateTime),
    ],
    indexes: [
      IsarIndexSchema(
        name: 'provider',
        properties: ["provider"],
        unique: false,
        hash: false,
      ),
    ],
  ),
  converter: IsarObjectConverter<int, TunnelModel>(
    serialize: serializeTunnelModel,
    deserialize: deserializeTunnelModel,
    deserializeProperty: deserializeTunnelModelProp,
  ),
  getEmbeddedSchemas: () => [],
);

@isarProtected
int serializeTunnelModel(IsarWriter writer, TunnelModel object) {
  IsarCore.writeString(writer, 1, object.name);
  IsarCore.writeString(writer, 2, object.provider);
  IsarCore.writeString(writer, 3, object.targetType);
  {
    final value = object.targetSiteDomain;
    if (value == null) {
      IsarCore.writeNull(writer, 4);
    } else {
      IsarCore.writeString(writer, 4, value);
    }
  }
  IsarCore.writeLong(writer, 5, object.targetPort);
  {
    final value = object.authToken;
    if (value == null) {
      IsarCore.writeNull(writer, 6);
    } else {
      IsarCore.writeString(writer, 6, value);
    }
  }
  {
    final value = object.customDomain;
    if (value == null) {
      IsarCore.writeNull(writer, 7);
    } else {
      IsarCore.writeString(writer, 7, value);
    }
  }
  IsarCore.writeBool(writer, 8, value: object.autoStart);
  IsarCore.writeLong(
    writer,
    9,
    object.createdAt?.toUtc().microsecondsSinceEpoch ?? -9223372036854775808,
  );
  IsarCore.writeLong(
    writer,
    10,
    object.lastActiveAt?.toUtc().microsecondsSinceEpoch ?? -9223372036854775808,
  );
  return object.id;
}

@isarProtected
TunnelModel deserializeTunnelModel(IsarReader reader) {
  final int _id;
  _id = IsarCore.readId(reader);
  final String _name;
  _name = IsarCore.readString(reader, 1) ?? '';
  final String _provider;
  _provider = IsarCore.readString(reader, 2) ?? 'cloudflare';
  final String _targetType;
  _targetType = IsarCore.readString(reader, 3) ?? 'site';
  final String? _targetSiteDomain;
  _targetSiteDomain = IsarCore.readString(reader, 4);
  final int _targetPort;
  {
    final value = IsarCore.readLong(reader, 5);
    if (value == -9223372036854775808) {
      _targetPort = 80;
    } else {
      _targetPort = value;
    }
  }
  final String? _authToken;
  _authToken = IsarCore.readString(reader, 6);
  final String? _customDomain;
  _customDomain = IsarCore.readString(reader, 7);
  final bool _autoStart;
  _autoStart = IsarCore.readBool(reader, 8);
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
  final DateTime? _lastActiveAt;
  {
    final value = IsarCore.readLong(reader, 10);
    if (value == -9223372036854775808) {
      _lastActiveAt = null;
    } else {
      _lastActiveAt = DateTime.fromMicrosecondsSinceEpoch(
        value,
        isUtc: true,
      ).toLocal();
    }
  }
  final object = TunnelModel(
    id: _id,
    name: _name,
    provider: _provider,
    targetType: _targetType,
    targetSiteDomain: _targetSiteDomain,
    targetPort: _targetPort,
    authToken: _authToken,
    customDomain: _customDomain,
    autoStart: _autoStart,
    createdAt: _createdAt,
    lastActiveAt: _lastActiveAt,
  );
  return object;
}

@isarProtected
dynamic deserializeTunnelModelProp(IsarReader reader, int property) {
  switch (property) {
    case 0:
      return IsarCore.readId(reader);
    case 1:
      return IsarCore.readString(reader, 1) ?? '';
    case 2:
      return IsarCore.readString(reader, 2) ?? 'cloudflare';
    case 3:
      return IsarCore.readString(reader, 3) ?? 'site';
    case 4:
      return IsarCore.readString(reader, 4);
    case 5:
      {
        final value = IsarCore.readLong(reader, 5);
        if (value == -9223372036854775808) {
          return 80;
        } else {
          return value;
        }
      }
    case 6:
      return IsarCore.readString(reader, 6);
    case 7:
      return IsarCore.readString(reader, 7);
    case 8:
      return IsarCore.readBool(reader, 8);
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
    case 10:
      {
        final value = IsarCore.readLong(reader, 10);
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

sealed class _TunnelModelUpdate {
  bool call({
    required int id,
    String? name,
    String? provider,
    String? targetType,
    String? targetSiteDomain,
    int? targetPort,
    String? authToken,
    String? customDomain,
    bool? autoStart,
    DateTime? createdAt,
    DateTime? lastActiveAt,
  });
}

class _TunnelModelUpdateImpl implements _TunnelModelUpdate {
  const _TunnelModelUpdateImpl(this.collection);

  final IsarCollection<int, TunnelModel> collection;

  @override
  bool call({
    required int id,
    Object? name = ignore,
    Object? provider = ignore,
    Object? targetType = ignore,
    Object? targetSiteDomain = ignore,
    Object? targetPort = ignore,
    Object? authToken = ignore,
    Object? customDomain = ignore,
    Object? autoStart = ignore,
    Object? createdAt = ignore,
    Object? lastActiveAt = ignore,
  }) {
    return collection.updateProperties(
          [id],
          {
            if (name != ignore) 1: name as String?,
            if (provider != ignore) 2: provider as String?,
            if (targetType != ignore) 3: targetType as String?,
            if (targetSiteDomain != ignore) 4: targetSiteDomain as String?,
            if (targetPort != ignore) 5: targetPort as int?,
            if (authToken != ignore) 6: authToken as String?,
            if (customDomain != ignore) 7: customDomain as String?,
            if (autoStart != ignore) 8: autoStart as bool?,
            if (createdAt != ignore) 9: createdAt as DateTime?,
            if (lastActiveAt != ignore) 10: lastActiveAt as DateTime?,
          },
        ) >
        0;
  }
}

sealed class _TunnelModelUpdateAll {
  int call({
    required List<int> id,
    String? name,
    String? provider,
    String? targetType,
    String? targetSiteDomain,
    int? targetPort,
    String? authToken,
    String? customDomain,
    bool? autoStart,
    DateTime? createdAt,
    DateTime? lastActiveAt,
  });
}

class _TunnelModelUpdateAllImpl implements _TunnelModelUpdateAll {
  const _TunnelModelUpdateAllImpl(this.collection);

  final IsarCollection<int, TunnelModel> collection;

  @override
  int call({
    required List<int> id,
    Object? name = ignore,
    Object? provider = ignore,
    Object? targetType = ignore,
    Object? targetSiteDomain = ignore,
    Object? targetPort = ignore,
    Object? authToken = ignore,
    Object? customDomain = ignore,
    Object? autoStart = ignore,
    Object? createdAt = ignore,
    Object? lastActiveAt = ignore,
  }) {
    return collection.updateProperties(id, {
      if (name != ignore) 1: name as String?,
      if (provider != ignore) 2: provider as String?,
      if (targetType != ignore) 3: targetType as String?,
      if (targetSiteDomain != ignore) 4: targetSiteDomain as String?,
      if (targetPort != ignore) 5: targetPort as int?,
      if (authToken != ignore) 6: authToken as String?,
      if (customDomain != ignore) 7: customDomain as String?,
      if (autoStart != ignore) 8: autoStart as bool?,
      if (createdAt != ignore) 9: createdAt as DateTime?,
      if (lastActiveAt != ignore) 10: lastActiveAt as DateTime?,
    });
  }
}

extension TunnelModelUpdate on IsarCollection<int, TunnelModel> {
  _TunnelModelUpdate get update => _TunnelModelUpdateImpl(this);

  _TunnelModelUpdateAll get updateAll => _TunnelModelUpdateAllImpl(this);
}

sealed class _TunnelModelQueryUpdate {
  int call({
    String? name,
    String? provider,
    String? targetType,
    String? targetSiteDomain,
    int? targetPort,
    String? authToken,
    String? customDomain,
    bool? autoStart,
    DateTime? createdAt,
    DateTime? lastActiveAt,
  });
}

class _TunnelModelQueryUpdateImpl implements _TunnelModelQueryUpdate {
  const _TunnelModelQueryUpdateImpl(this.query, {this.limit});

  final IsarQuery<TunnelModel> query;
  final int? limit;

  @override
  int call({
    Object? name = ignore,
    Object? provider = ignore,
    Object? targetType = ignore,
    Object? targetSiteDomain = ignore,
    Object? targetPort = ignore,
    Object? authToken = ignore,
    Object? customDomain = ignore,
    Object? autoStart = ignore,
    Object? createdAt = ignore,
    Object? lastActiveAt = ignore,
  }) {
    return query.updateProperties(limit: limit, {
      if (name != ignore) 1: name as String?,
      if (provider != ignore) 2: provider as String?,
      if (targetType != ignore) 3: targetType as String?,
      if (targetSiteDomain != ignore) 4: targetSiteDomain as String?,
      if (targetPort != ignore) 5: targetPort as int?,
      if (authToken != ignore) 6: authToken as String?,
      if (customDomain != ignore) 7: customDomain as String?,
      if (autoStart != ignore) 8: autoStart as bool?,
      if (createdAt != ignore) 9: createdAt as DateTime?,
      if (lastActiveAt != ignore) 10: lastActiveAt as DateTime?,
    });
  }
}

extension TunnelModelQueryUpdate on IsarQuery<TunnelModel> {
  _TunnelModelQueryUpdate get updateFirst =>
      _TunnelModelQueryUpdateImpl(this, limit: 1);

  _TunnelModelQueryUpdate get updateAll => _TunnelModelQueryUpdateImpl(this);
}

class _TunnelModelQueryBuilderUpdateImpl implements _TunnelModelQueryUpdate {
  const _TunnelModelQueryBuilderUpdateImpl(this.query, {this.limit});

  final QueryBuilder<TunnelModel, TunnelModel, QOperations> query;
  final int? limit;

  @override
  int call({
    Object? name = ignore,
    Object? provider = ignore,
    Object? targetType = ignore,
    Object? targetSiteDomain = ignore,
    Object? targetPort = ignore,
    Object? authToken = ignore,
    Object? customDomain = ignore,
    Object? autoStart = ignore,
    Object? createdAt = ignore,
    Object? lastActiveAt = ignore,
  }) {
    final q = query.build();
    try {
      return q.updateProperties(limit: limit, {
        if (name != ignore) 1: name as String?,
        if (provider != ignore) 2: provider as String?,
        if (targetType != ignore) 3: targetType as String?,
        if (targetSiteDomain != ignore) 4: targetSiteDomain as String?,
        if (targetPort != ignore) 5: targetPort as int?,
        if (authToken != ignore) 6: authToken as String?,
        if (customDomain != ignore) 7: customDomain as String?,
        if (autoStart != ignore) 8: autoStart as bool?,
        if (createdAt != ignore) 9: createdAt as DateTime?,
        if (lastActiveAt != ignore) 10: lastActiveAt as DateTime?,
      });
    } finally {
      q.close();
    }
  }
}

extension TunnelModelQueryBuilderUpdate
    on QueryBuilder<TunnelModel, TunnelModel, QOperations> {
  _TunnelModelQueryUpdate get updateFirst =>
      _TunnelModelQueryBuilderUpdateImpl(this, limit: 1);

  _TunnelModelQueryUpdate get updateAll =>
      _TunnelModelQueryBuilderUpdateImpl(this);
}

extension TunnelModelQueryFilter
    on QueryBuilder<TunnelModel, TunnelModel, QFilterCondition> {
  QueryBuilder<TunnelModel, TunnelModel, QAfterFilterCondition> idEqualTo(
    int value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(property: 0, value: value),
      );
    });
  }

  QueryBuilder<TunnelModel, TunnelModel, QAfterFilterCondition> idGreaterThan(
    int value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterCondition(property: 0, value: value),
      );
    });
  }

  QueryBuilder<TunnelModel, TunnelModel, QAfterFilterCondition>
  idGreaterThanOrEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterOrEqualCondition(property: 0, value: value),
      );
    });
  }

  QueryBuilder<TunnelModel, TunnelModel, QAfterFilterCondition> idLessThan(
    int value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(LessCondition(property: 0, value: value));
    });
  }

  QueryBuilder<TunnelModel, TunnelModel, QAfterFilterCondition>
  idLessThanOrEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessOrEqualCondition(property: 0, value: value),
      );
    });
  }

  QueryBuilder<TunnelModel, TunnelModel, QAfterFilterCondition> idBetween(
    int lower,
    int upper,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        BetweenCondition(property: 0, lower: lower, upper: upper),
      );
    });
  }

  QueryBuilder<TunnelModel, TunnelModel, QAfterFilterCondition> nameEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(property: 1, value: value, caseSensitive: caseSensitive),
      );
    });
  }

  QueryBuilder<TunnelModel, TunnelModel, QAfterFilterCondition> nameGreaterThan(
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

  QueryBuilder<TunnelModel, TunnelModel, QAfterFilterCondition>
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

  QueryBuilder<TunnelModel, TunnelModel, QAfterFilterCondition> nameLessThan(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessCondition(property: 1, value: value, caseSensitive: caseSensitive),
      );
    });
  }

  QueryBuilder<TunnelModel, TunnelModel, QAfterFilterCondition>
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

  QueryBuilder<TunnelModel, TunnelModel, QAfterFilterCondition> nameBetween(
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

  QueryBuilder<TunnelModel, TunnelModel, QAfterFilterCondition> nameStartsWith(
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

  QueryBuilder<TunnelModel, TunnelModel, QAfterFilterCondition> nameEndsWith(
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

  QueryBuilder<TunnelModel, TunnelModel, QAfterFilterCondition> nameContains(
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

  QueryBuilder<TunnelModel, TunnelModel, QAfterFilterCondition> nameMatches(
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

  QueryBuilder<TunnelModel, TunnelModel, QAfterFilterCondition> nameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const EqualCondition(property: 1, value: ''),
      );
    });
  }

  QueryBuilder<TunnelModel, TunnelModel, QAfterFilterCondition>
  nameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const GreaterCondition(property: 1, value: ''),
      );
    });
  }

  QueryBuilder<TunnelModel, TunnelModel, QAfterFilterCondition> providerEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(property: 2, value: value, caseSensitive: caseSensitive),
      );
    });
  }

  QueryBuilder<TunnelModel, TunnelModel, QAfterFilterCondition>
  providerGreaterThan(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<TunnelModel, TunnelModel, QAfterFilterCondition>
  providerGreaterThanOrEqualTo(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<TunnelModel, TunnelModel, QAfterFilterCondition>
  providerLessThan(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessCondition(property: 2, value: value, caseSensitive: caseSensitive),
      );
    });
  }

  QueryBuilder<TunnelModel, TunnelModel, QAfterFilterCondition>
  providerLessThanOrEqualTo(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<TunnelModel, TunnelModel, QAfterFilterCondition> providerBetween(
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

  QueryBuilder<TunnelModel, TunnelModel, QAfterFilterCondition>
  providerStartsWith(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<TunnelModel, TunnelModel, QAfterFilterCondition>
  providerEndsWith(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<TunnelModel, TunnelModel, QAfterFilterCondition>
  providerContains(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<TunnelModel, TunnelModel, QAfterFilterCondition> providerMatches(
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

  QueryBuilder<TunnelModel, TunnelModel, QAfterFilterCondition>
  providerIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const EqualCondition(property: 2, value: ''),
      );
    });
  }

  QueryBuilder<TunnelModel, TunnelModel, QAfterFilterCondition>
  providerIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const GreaterCondition(property: 2, value: ''),
      );
    });
  }

  QueryBuilder<TunnelModel, TunnelModel, QAfterFilterCondition>
  targetTypeEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(property: 3, value: value, caseSensitive: caseSensitive),
      );
    });
  }

  QueryBuilder<TunnelModel, TunnelModel, QAfterFilterCondition>
  targetTypeGreaterThan(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<TunnelModel, TunnelModel, QAfterFilterCondition>
  targetTypeGreaterThanOrEqualTo(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<TunnelModel, TunnelModel, QAfterFilterCondition>
  targetTypeLessThan(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessCondition(property: 3, value: value, caseSensitive: caseSensitive),
      );
    });
  }

  QueryBuilder<TunnelModel, TunnelModel, QAfterFilterCondition>
  targetTypeLessThanOrEqualTo(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<TunnelModel, TunnelModel, QAfterFilterCondition>
  targetTypeBetween(String lower, String upper, {bool caseSensitive = true}) {
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

  QueryBuilder<TunnelModel, TunnelModel, QAfterFilterCondition>
  targetTypeStartsWith(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<TunnelModel, TunnelModel, QAfterFilterCondition>
  targetTypeEndsWith(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<TunnelModel, TunnelModel, QAfterFilterCondition>
  targetTypeContains(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<TunnelModel, TunnelModel, QAfterFilterCondition>
  targetTypeMatches(String pattern, {bool caseSensitive = true}) {
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

  QueryBuilder<TunnelModel, TunnelModel, QAfterFilterCondition>
  targetTypeIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const EqualCondition(property: 3, value: ''),
      );
    });
  }

  QueryBuilder<TunnelModel, TunnelModel, QAfterFilterCondition>
  targetTypeIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const GreaterCondition(property: 3, value: ''),
      );
    });
  }

  QueryBuilder<TunnelModel, TunnelModel, QAfterFilterCondition>
  targetSiteDomainIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const IsNullCondition(property: 4));
    });
  }

  QueryBuilder<TunnelModel, TunnelModel, QAfterFilterCondition>
  targetSiteDomainIsNotNull() {
    return QueryBuilder.apply(not(), (query) {
      return query.addFilterCondition(const IsNullCondition(property: 4));
    });
  }

  QueryBuilder<TunnelModel, TunnelModel, QAfterFilterCondition>
  targetSiteDomainEqualTo(String? value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(property: 4, value: value, caseSensitive: caseSensitive),
      );
    });
  }

  QueryBuilder<TunnelModel, TunnelModel, QAfterFilterCondition>
  targetSiteDomainGreaterThan(String? value, {bool caseSensitive = true}) {
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

  QueryBuilder<TunnelModel, TunnelModel, QAfterFilterCondition>
  targetSiteDomainGreaterThanOrEqualTo(
    String? value, {
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

  QueryBuilder<TunnelModel, TunnelModel, QAfterFilterCondition>
  targetSiteDomainLessThan(String? value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessCondition(property: 4, value: value, caseSensitive: caseSensitive),
      );
    });
  }

  QueryBuilder<TunnelModel, TunnelModel, QAfterFilterCondition>
  targetSiteDomainLessThanOrEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
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

  QueryBuilder<TunnelModel, TunnelModel, QAfterFilterCondition>
  targetSiteDomainBetween(
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

  QueryBuilder<TunnelModel, TunnelModel, QAfterFilterCondition>
  targetSiteDomainStartsWith(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<TunnelModel, TunnelModel, QAfterFilterCondition>
  targetSiteDomainEndsWith(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<TunnelModel, TunnelModel, QAfterFilterCondition>
  targetSiteDomainContains(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<TunnelModel, TunnelModel, QAfterFilterCondition>
  targetSiteDomainMatches(String pattern, {bool caseSensitive = true}) {
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

  QueryBuilder<TunnelModel, TunnelModel, QAfterFilterCondition>
  targetSiteDomainIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const EqualCondition(property: 4, value: ''),
      );
    });
  }

  QueryBuilder<TunnelModel, TunnelModel, QAfterFilterCondition>
  targetSiteDomainIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const GreaterCondition(property: 4, value: ''),
      );
    });
  }

  QueryBuilder<TunnelModel, TunnelModel, QAfterFilterCondition>
  targetPortEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(property: 5, value: value),
      );
    });
  }

  QueryBuilder<TunnelModel, TunnelModel, QAfterFilterCondition>
  targetPortGreaterThan(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterCondition(property: 5, value: value),
      );
    });
  }

  QueryBuilder<TunnelModel, TunnelModel, QAfterFilterCondition>
  targetPortGreaterThanOrEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterOrEqualCondition(property: 5, value: value),
      );
    });
  }

  QueryBuilder<TunnelModel, TunnelModel, QAfterFilterCondition>
  targetPortLessThan(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(LessCondition(property: 5, value: value));
    });
  }

  QueryBuilder<TunnelModel, TunnelModel, QAfterFilterCondition>
  targetPortLessThanOrEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessOrEqualCondition(property: 5, value: value),
      );
    });
  }

  QueryBuilder<TunnelModel, TunnelModel, QAfterFilterCondition>
  targetPortBetween(int lower, int upper) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        BetweenCondition(property: 5, lower: lower, upper: upper),
      );
    });
  }

  QueryBuilder<TunnelModel, TunnelModel, QAfterFilterCondition>
  authTokenIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const IsNullCondition(property: 6));
    });
  }

  QueryBuilder<TunnelModel, TunnelModel, QAfterFilterCondition>
  authTokenIsNotNull() {
    return QueryBuilder.apply(not(), (query) {
      return query.addFilterCondition(const IsNullCondition(property: 6));
    });
  }

  QueryBuilder<TunnelModel, TunnelModel, QAfterFilterCondition>
  authTokenEqualTo(String? value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(property: 6, value: value, caseSensitive: caseSensitive),
      );
    });
  }

  QueryBuilder<TunnelModel, TunnelModel, QAfterFilterCondition>
  authTokenGreaterThan(String? value, {bool caseSensitive = true}) {
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

  QueryBuilder<TunnelModel, TunnelModel, QAfterFilterCondition>
  authTokenGreaterThanOrEqualTo(String? value, {bool caseSensitive = true}) {
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

  QueryBuilder<TunnelModel, TunnelModel, QAfterFilterCondition>
  authTokenLessThan(String? value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessCondition(property: 6, value: value, caseSensitive: caseSensitive),
      );
    });
  }

  QueryBuilder<TunnelModel, TunnelModel, QAfterFilterCondition>
  authTokenLessThanOrEqualTo(String? value, {bool caseSensitive = true}) {
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

  QueryBuilder<TunnelModel, TunnelModel, QAfterFilterCondition>
  authTokenBetween(String? lower, String? upper, {bool caseSensitive = true}) {
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

  QueryBuilder<TunnelModel, TunnelModel, QAfterFilterCondition>
  authTokenStartsWith(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<TunnelModel, TunnelModel, QAfterFilterCondition>
  authTokenEndsWith(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<TunnelModel, TunnelModel, QAfterFilterCondition>
  authTokenContains(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<TunnelModel, TunnelModel, QAfterFilterCondition>
  authTokenMatches(String pattern, {bool caseSensitive = true}) {
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

  QueryBuilder<TunnelModel, TunnelModel, QAfterFilterCondition>
  authTokenIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const EqualCondition(property: 6, value: ''),
      );
    });
  }

  QueryBuilder<TunnelModel, TunnelModel, QAfterFilterCondition>
  authTokenIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const GreaterCondition(property: 6, value: ''),
      );
    });
  }

  QueryBuilder<TunnelModel, TunnelModel, QAfterFilterCondition>
  customDomainIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const IsNullCondition(property: 7));
    });
  }

  QueryBuilder<TunnelModel, TunnelModel, QAfterFilterCondition>
  customDomainIsNotNull() {
    return QueryBuilder.apply(not(), (query) {
      return query.addFilterCondition(const IsNullCondition(property: 7));
    });
  }

  QueryBuilder<TunnelModel, TunnelModel, QAfterFilterCondition>
  customDomainEqualTo(String? value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(property: 7, value: value, caseSensitive: caseSensitive),
      );
    });
  }

  QueryBuilder<TunnelModel, TunnelModel, QAfterFilterCondition>
  customDomainGreaterThan(String? value, {bool caseSensitive = true}) {
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

  QueryBuilder<TunnelModel, TunnelModel, QAfterFilterCondition>
  customDomainGreaterThanOrEqualTo(String? value, {bool caseSensitive = true}) {
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

  QueryBuilder<TunnelModel, TunnelModel, QAfterFilterCondition>
  customDomainLessThan(String? value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessCondition(property: 7, value: value, caseSensitive: caseSensitive),
      );
    });
  }

  QueryBuilder<TunnelModel, TunnelModel, QAfterFilterCondition>
  customDomainLessThanOrEqualTo(String? value, {bool caseSensitive = true}) {
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

  QueryBuilder<TunnelModel, TunnelModel, QAfterFilterCondition>
  customDomainBetween(
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

  QueryBuilder<TunnelModel, TunnelModel, QAfterFilterCondition>
  customDomainStartsWith(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<TunnelModel, TunnelModel, QAfterFilterCondition>
  customDomainEndsWith(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<TunnelModel, TunnelModel, QAfterFilterCondition>
  customDomainContains(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<TunnelModel, TunnelModel, QAfterFilterCondition>
  customDomainMatches(String pattern, {bool caseSensitive = true}) {
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

  QueryBuilder<TunnelModel, TunnelModel, QAfterFilterCondition>
  customDomainIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const EqualCondition(property: 7, value: ''),
      );
    });
  }

  QueryBuilder<TunnelModel, TunnelModel, QAfterFilterCondition>
  customDomainIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const GreaterCondition(property: 7, value: ''),
      );
    });
  }

  QueryBuilder<TunnelModel, TunnelModel, QAfterFilterCondition>
  autoStartEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(property: 8, value: value),
      );
    });
  }

  QueryBuilder<TunnelModel, TunnelModel, QAfterFilterCondition>
  createdAtIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const IsNullCondition(property: 9));
    });
  }

  QueryBuilder<TunnelModel, TunnelModel, QAfterFilterCondition>
  createdAtIsNotNull() {
    return QueryBuilder.apply(not(), (query) {
      return query.addFilterCondition(const IsNullCondition(property: 9));
    });
  }

  QueryBuilder<TunnelModel, TunnelModel, QAfterFilterCondition>
  createdAtEqualTo(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(property: 9, value: value),
      );
    });
  }

  QueryBuilder<TunnelModel, TunnelModel, QAfterFilterCondition>
  createdAtGreaterThan(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterCondition(property: 9, value: value),
      );
    });
  }

  QueryBuilder<TunnelModel, TunnelModel, QAfterFilterCondition>
  createdAtGreaterThanOrEqualTo(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterOrEqualCondition(property: 9, value: value),
      );
    });
  }

  QueryBuilder<TunnelModel, TunnelModel, QAfterFilterCondition>
  createdAtLessThan(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(LessCondition(property: 9, value: value));
    });
  }

  QueryBuilder<TunnelModel, TunnelModel, QAfterFilterCondition>
  createdAtLessThanOrEqualTo(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessOrEqualCondition(property: 9, value: value),
      );
    });
  }

  QueryBuilder<TunnelModel, TunnelModel, QAfterFilterCondition>
  createdAtBetween(DateTime? lower, DateTime? upper) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        BetweenCondition(property: 9, lower: lower, upper: upper),
      );
    });
  }

  QueryBuilder<TunnelModel, TunnelModel, QAfterFilterCondition>
  lastActiveAtIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const IsNullCondition(property: 10));
    });
  }

  QueryBuilder<TunnelModel, TunnelModel, QAfterFilterCondition>
  lastActiveAtIsNotNull() {
    return QueryBuilder.apply(not(), (query) {
      return query.addFilterCondition(const IsNullCondition(property: 10));
    });
  }

  QueryBuilder<TunnelModel, TunnelModel, QAfterFilterCondition>
  lastActiveAtEqualTo(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(property: 10, value: value),
      );
    });
  }

  QueryBuilder<TunnelModel, TunnelModel, QAfterFilterCondition>
  lastActiveAtGreaterThan(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterCondition(property: 10, value: value),
      );
    });
  }

  QueryBuilder<TunnelModel, TunnelModel, QAfterFilterCondition>
  lastActiveAtGreaterThanOrEqualTo(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterOrEqualCondition(property: 10, value: value),
      );
    });
  }

  QueryBuilder<TunnelModel, TunnelModel, QAfterFilterCondition>
  lastActiveAtLessThan(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessCondition(property: 10, value: value),
      );
    });
  }

  QueryBuilder<TunnelModel, TunnelModel, QAfterFilterCondition>
  lastActiveAtLessThanOrEqualTo(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessOrEqualCondition(property: 10, value: value),
      );
    });
  }

  QueryBuilder<TunnelModel, TunnelModel, QAfterFilterCondition>
  lastActiveAtBetween(DateTime? lower, DateTime? upper) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        BetweenCondition(property: 10, lower: lower, upper: upper),
      );
    });
  }
}

extension TunnelModelQueryObject
    on QueryBuilder<TunnelModel, TunnelModel, QFilterCondition> {}

extension TunnelModelQuerySortBy
    on QueryBuilder<TunnelModel, TunnelModel, QSortBy> {
  QueryBuilder<TunnelModel, TunnelModel, QAfterSortBy> sortById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(0);
    });
  }

  QueryBuilder<TunnelModel, TunnelModel, QAfterSortBy> sortByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(0, sort: Sort.desc);
    });
  }

  QueryBuilder<TunnelModel, TunnelModel, QAfterSortBy> sortByName({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(1, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<TunnelModel, TunnelModel, QAfterSortBy> sortByNameDesc({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(1, sort: Sort.desc, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<TunnelModel, TunnelModel, QAfterSortBy> sortByProvider({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(2, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<TunnelModel, TunnelModel, QAfterSortBy> sortByProviderDesc({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(2, sort: Sort.desc, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<TunnelModel, TunnelModel, QAfterSortBy> sortByTargetType({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(3, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<TunnelModel, TunnelModel, QAfterSortBy> sortByTargetTypeDesc({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(3, sort: Sort.desc, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<TunnelModel, TunnelModel, QAfterSortBy> sortByTargetSiteDomain({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(4, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<TunnelModel, TunnelModel, QAfterSortBy>
  sortByTargetSiteDomainDesc({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(4, sort: Sort.desc, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<TunnelModel, TunnelModel, QAfterSortBy> sortByTargetPort() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(5);
    });
  }

  QueryBuilder<TunnelModel, TunnelModel, QAfterSortBy> sortByTargetPortDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(5, sort: Sort.desc);
    });
  }

  QueryBuilder<TunnelModel, TunnelModel, QAfterSortBy> sortByAuthToken({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(6, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<TunnelModel, TunnelModel, QAfterSortBy> sortByAuthTokenDesc({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(6, sort: Sort.desc, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<TunnelModel, TunnelModel, QAfterSortBy> sortByCustomDomain({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(7, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<TunnelModel, TunnelModel, QAfterSortBy> sortByCustomDomainDesc({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(7, sort: Sort.desc, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<TunnelModel, TunnelModel, QAfterSortBy> sortByAutoStart() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(8);
    });
  }

  QueryBuilder<TunnelModel, TunnelModel, QAfterSortBy> sortByAutoStartDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(8, sort: Sort.desc);
    });
  }

  QueryBuilder<TunnelModel, TunnelModel, QAfterSortBy> sortByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(9);
    });
  }

  QueryBuilder<TunnelModel, TunnelModel, QAfterSortBy> sortByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(9, sort: Sort.desc);
    });
  }

  QueryBuilder<TunnelModel, TunnelModel, QAfterSortBy> sortByLastActiveAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(10);
    });
  }

  QueryBuilder<TunnelModel, TunnelModel, QAfterSortBy>
  sortByLastActiveAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(10, sort: Sort.desc);
    });
  }
}

extension TunnelModelQuerySortThenBy
    on QueryBuilder<TunnelModel, TunnelModel, QSortThenBy> {
  QueryBuilder<TunnelModel, TunnelModel, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(0);
    });
  }

  QueryBuilder<TunnelModel, TunnelModel, QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(0, sort: Sort.desc);
    });
  }

  QueryBuilder<TunnelModel, TunnelModel, QAfterSortBy> thenByName({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(1, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<TunnelModel, TunnelModel, QAfterSortBy> thenByNameDesc({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(1, sort: Sort.desc, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<TunnelModel, TunnelModel, QAfterSortBy> thenByProvider({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(2, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<TunnelModel, TunnelModel, QAfterSortBy> thenByProviderDesc({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(2, sort: Sort.desc, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<TunnelModel, TunnelModel, QAfterSortBy> thenByTargetType({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(3, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<TunnelModel, TunnelModel, QAfterSortBy> thenByTargetTypeDesc({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(3, sort: Sort.desc, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<TunnelModel, TunnelModel, QAfterSortBy> thenByTargetSiteDomain({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(4, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<TunnelModel, TunnelModel, QAfterSortBy>
  thenByTargetSiteDomainDesc({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(4, sort: Sort.desc, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<TunnelModel, TunnelModel, QAfterSortBy> thenByTargetPort() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(5);
    });
  }

  QueryBuilder<TunnelModel, TunnelModel, QAfterSortBy> thenByTargetPortDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(5, sort: Sort.desc);
    });
  }

  QueryBuilder<TunnelModel, TunnelModel, QAfterSortBy> thenByAuthToken({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(6, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<TunnelModel, TunnelModel, QAfterSortBy> thenByAuthTokenDesc({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(6, sort: Sort.desc, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<TunnelModel, TunnelModel, QAfterSortBy> thenByCustomDomain({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(7, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<TunnelModel, TunnelModel, QAfterSortBy> thenByCustomDomainDesc({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(7, sort: Sort.desc, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<TunnelModel, TunnelModel, QAfterSortBy> thenByAutoStart() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(8);
    });
  }

  QueryBuilder<TunnelModel, TunnelModel, QAfterSortBy> thenByAutoStartDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(8, sort: Sort.desc);
    });
  }

  QueryBuilder<TunnelModel, TunnelModel, QAfterSortBy> thenByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(9);
    });
  }

  QueryBuilder<TunnelModel, TunnelModel, QAfterSortBy> thenByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(9, sort: Sort.desc);
    });
  }

  QueryBuilder<TunnelModel, TunnelModel, QAfterSortBy> thenByLastActiveAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(10);
    });
  }

  QueryBuilder<TunnelModel, TunnelModel, QAfterSortBy>
  thenByLastActiveAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(10, sort: Sort.desc);
    });
  }
}

extension TunnelModelQueryWhereDistinct
    on QueryBuilder<TunnelModel, TunnelModel, QDistinct> {
  QueryBuilder<TunnelModel, TunnelModel, QAfterDistinct> distinctByName({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(1, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<TunnelModel, TunnelModel, QAfterDistinct> distinctByProvider({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(2, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<TunnelModel, TunnelModel, QAfterDistinct> distinctByTargetType({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(3, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<TunnelModel, TunnelModel, QAfterDistinct>
  distinctByTargetSiteDomain({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(4, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<TunnelModel, TunnelModel, QAfterDistinct>
  distinctByTargetPort() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(5);
    });
  }

  QueryBuilder<TunnelModel, TunnelModel, QAfterDistinct> distinctByAuthToken({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(6, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<TunnelModel, TunnelModel, QAfterDistinct>
  distinctByCustomDomain({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(7, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<TunnelModel, TunnelModel, QAfterDistinct> distinctByAutoStart() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(8);
    });
  }

  QueryBuilder<TunnelModel, TunnelModel, QAfterDistinct> distinctByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(9);
    });
  }

  QueryBuilder<TunnelModel, TunnelModel, QAfterDistinct>
  distinctByLastActiveAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(10);
    });
  }
}

extension TunnelModelQueryProperty1
    on QueryBuilder<TunnelModel, TunnelModel, QProperty> {
  QueryBuilder<TunnelModel, int, QAfterProperty> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(0);
    });
  }

  QueryBuilder<TunnelModel, String, QAfterProperty> nameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(1);
    });
  }

  QueryBuilder<TunnelModel, String, QAfterProperty> providerProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(2);
    });
  }

  QueryBuilder<TunnelModel, String, QAfterProperty> targetTypeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(3);
    });
  }

  QueryBuilder<TunnelModel, String?, QAfterProperty>
  targetSiteDomainProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(4);
    });
  }

  QueryBuilder<TunnelModel, int, QAfterProperty> targetPortProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(5);
    });
  }

  QueryBuilder<TunnelModel, String?, QAfterProperty> authTokenProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(6);
    });
  }

  QueryBuilder<TunnelModel, String?, QAfterProperty> customDomainProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(7);
    });
  }

  QueryBuilder<TunnelModel, bool, QAfterProperty> autoStartProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(8);
    });
  }

  QueryBuilder<TunnelModel, DateTime?, QAfterProperty> createdAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(9);
    });
  }

  QueryBuilder<TunnelModel, DateTime?, QAfterProperty> lastActiveAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(10);
    });
  }
}

extension TunnelModelQueryProperty2<R>
    on QueryBuilder<TunnelModel, R, QAfterProperty> {
  QueryBuilder<TunnelModel, (R, int), QAfterProperty> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(0);
    });
  }

  QueryBuilder<TunnelModel, (R, String), QAfterProperty> nameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(1);
    });
  }

  QueryBuilder<TunnelModel, (R, String), QAfterProperty> providerProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(2);
    });
  }

  QueryBuilder<TunnelModel, (R, String), QAfterProperty> targetTypeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(3);
    });
  }

  QueryBuilder<TunnelModel, (R, String?), QAfterProperty>
  targetSiteDomainProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(4);
    });
  }

  QueryBuilder<TunnelModel, (R, int), QAfterProperty> targetPortProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(5);
    });
  }

  QueryBuilder<TunnelModel, (R, String?), QAfterProperty> authTokenProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(6);
    });
  }

  QueryBuilder<TunnelModel, (R, String?), QAfterProperty>
  customDomainProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(7);
    });
  }

  QueryBuilder<TunnelModel, (R, bool), QAfterProperty> autoStartProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(8);
    });
  }

  QueryBuilder<TunnelModel, (R, DateTime?), QAfterProperty>
  createdAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(9);
    });
  }

  QueryBuilder<TunnelModel, (R, DateTime?), QAfterProperty>
  lastActiveAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(10);
    });
  }
}

extension TunnelModelQueryProperty3<R1, R2>
    on QueryBuilder<TunnelModel, (R1, R2), QAfterProperty> {
  QueryBuilder<TunnelModel, (R1, R2, int), QOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(0);
    });
  }

  QueryBuilder<TunnelModel, (R1, R2, String), QOperations> nameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(1);
    });
  }

  QueryBuilder<TunnelModel, (R1, R2, String), QOperations> providerProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(2);
    });
  }

  QueryBuilder<TunnelModel, (R1, R2, String), QOperations>
  targetTypeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(3);
    });
  }

  QueryBuilder<TunnelModel, (R1, R2, String?), QOperations>
  targetSiteDomainProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(4);
    });
  }

  QueryBuilder<TunnelModel, (R1, R2, int), QOperations> targetPortProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(5);
    });
  }

  QueryBuilder<TunnelModel, (R1, R2, String?), QOperations>
  authTokenProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(6);
    });
  }

  QueryBuilder<TunnelModel, (R1, R2, String?), QOperations>
  customDomainProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(7);
    });
  }

  QueryBuilder<TunnelModel, (R1, R2, bool), QOperations> autoStartProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(8);
    });
  }

  QueryBuilder<TunnelModel, (R1, R2, DateTime?), QOperations>
  createdAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(9);
    });
  }

  QueryBuilder<TunnelModel, (R1, R2, DateTime?), QOperations>
  lastActiveAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(10);
    });
  }
}
