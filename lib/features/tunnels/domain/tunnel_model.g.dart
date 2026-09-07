// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tunnel_model.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetTunnelModelCollection on Isar {
  IsarCollection<TunnelModel> get tunnelModels => this.collection();
}

const TunnelModelSchema = CollectionSchema(
  name: r'TunnelModel',
  id: -2758526310305884580,
  properties: {
    r'authToken': PropertySchema(
      id: 0,
      name: r'authToken',
      type: IsarType.string,
    ),
    r'autoStart': PropertySchema(
      id: 1,
      name: r'autoStart',
      type: IsarType.bool,
    ),
    r'createdAt': PropertySchema(
      id: 2,
      name: r'createdAt',
      type: IsarType.dateTime,
    ),
    r'customDomain': PropertySchema(
      id: 3,
      name: r'customDomain',
      type: IsarType.string,
    ),
    r'lastActiveAt': PropertySchema(
      id: 4,
      name: r'lastActiveAt',
      type: IsarType.dateTime,
    ),
    r'name': PropertySchema(
      id: 5,
      name: r'name',
      type: IsarType.string,
    ),
    r'provider': PropertySchema(
      id: 6,
      name: r'provider',
      type: IsarType.string,
    ),
    r'targetPort': PropertySchema(
      id: 7,
      name: r'targetPort',
      type: IsarType.long,
    ),
    r'targetSiteDomain': PropertySchema(
      id: 8,
      name: r'targetSiteDomain',
      type: IsarType.string,
    ),
    r'targetType': PropertySchema(
      id: 9,
      name: r'targetType',
      type: IsarType.string,
    )
  },
  estimateSize: _tunnelModelEstimateSize,
  serialize: _tunnelModelSerialize,
  deserialize: _tunnelModelDeserialize,
  deserializeProp: _tunnelModelDeserializeProp,
  idName: r'id',
  indexes: {
    r'provider': IndexSchema(
      id: -6343122774420421053,
      name: r'provider',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'provider',
          type: IndexType.hash,
          caseSensitive: true,
        )
      ],
    )
  },
  links: {},
  embeddedSchemas: {},
  getId: _tunnelModelGetId,
  getLinks: _tunnelModelGetLinks,
  attach: _tunnelModelAttach,
  version: '3.1.0+1',
);

int _tunnelModelEstimateSize(
  TunnelModel object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  {
    final value = object.authToken;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.customDomain;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.name.length * 3;
  bytesCount += 3 + object.provider.length * 3;
  {
    final value = object.targetSiteDomain;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.targetType.length * 3;
  return bytesCount;
}

void _tunnelModelSerialize(
  TunnelModel object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeString(offsets[0], object.authToken);
  writer.writeBool(offsets[1], object.autoStart);
  writer.writeDateTime(offsets[2], object.createdAt);
  writer.writeString(offsets[3], object.customDomain);
  writer.writeDateTime(offsets[4], object.lastActiveAt);
  writer.writeString(offsets[5], object.name);
  writer.writeString(offsets[6], object.provider);
  writer.writeLong(offsets[7], object.targetPort);
  writer.writeString(offsets[8], object.targetSiteDomain);
  writer.writeString(offsets[9], object.targetType);
}

TunnelModel _tunnelModelDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = TunnelModel(
    authToken: reader.readStringOrNull(offsets[0]),
    autoStart: reader.readBoolOrNull(offsets[1]) ?? false,
    createdAt: reader.readDateTimeOrNull(offsets[2]),
    customDomain: reader.readStringOrNull(offsets[3]),
    id: id,
    lastActiveAt: reader.readDateTimeOrNull(offsets[4]),
    name: reader.readString(offsets[5]),
    provider: reader.readStringOrNull(offsets[6]) ?? 'cloudflare',
    targetPort: reader.readLongOrNull(offsets[7]) ?? 80,
    targetSiteDomain: reader.readStringOrNull(offsets[8]),
    targetType: reader.readStringOrNull(offsets[9]) ?? 'site',
  );
  return object;
}

P _tunnelModelDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readStringOrNull(offset)) as P;
    case 1:
      return (reader.readBoolOrNull(offset) ?? false) as P;
    case 2:
      return (reader.readDateTimeOrNull(offset)) as P;
    case 3:
      return (reader.readStringOrNull(offset)) as P;
    case 4:
      return (reader.readDateTimeOrNull(offset)) as P;
    case 5:
      return (reader.readString(offset)) as P;
    case 6:
      return (reader.readStringOrNull(offset) ?? 'cloudflare') as P;
    case 7:
      return (reader.readLongOrNull(offset) ?? 80) as P;
    case 8:
      return (reader.readStringOrNull(offset)) as P;
    case 9:
      return (reader.readStringOrNull(offset) ?? 'site') as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _tunnelModelGetId(TunnelModel object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _tunnelModelGetLinks(TunnelModel object) {
  return [];
}

void _tunnelModelAttach(
    IsarCollection<dynamic> col, Id id, TunnelModel object) {
  object.id = id;
}

extension TunnelModelQueryWhereSort
    on QueryBuilder<TunnelModel, TunnelModel, QWhere> {
  QueryBuilder<TunnelModel, TunnelModel, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension TunnelModelQueryWhere
    on QueryBuilder<TunnelModel, TunnelModel, QWhereClause> {
  QueryBuilder<TunnelModel, TunnelModel, QAfterWhereClause> idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: id,
        upper: id,
      ));
    });
  }

  QueryBuilder<TunnelModel, TunnelModel, QAfterWhereClause> idNotEqualTo(
      Id id) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            )
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            );
      } else {
        return query
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            )
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            );
      }
    });
  }

  QueryBuilder<TunnelModel, TunnelModel, QAfterWhereClause> idGreaterThan(Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<TunnelModel, TunnelModel, QAfterWhereClause> idLessThan(Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<TunnelModel, TunnelModel, QAfterWhereClause> idBetween(
    Id lowerId,
    Id upperId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: lowerId,
        includeLower: includeLower,
        upper: upperId,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<TunnelModel, TunnelModel, QAfterWhereClause> providerEqualTo(
      String provider) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'provider',
        value: [provider],
      ));
    });
  }

  QueryBuilder<TunnelModel, TunnelModel, QAfterWhereClause> providerNotEqualTo(
      String provider) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'provider',
              lower: [],
              upper: [provider],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'provider',
              lower: [provider],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'provider',
              lower: [provider],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'provider',
              lower: [],
              upper: [provider],
              includeUpper: false,
            ));
      }
    });
  }
}

extension TunnelModelQueryFilter
    on QueryBuilder<TunnelModel, TunnelModel, QFilterCondition> {
  QueryBuilder<TunnelModel, TunnelModel, QAfterFilterCondition>
      authTokenIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'authToken',
      ));
    });
  }

  QueryBuilder<TunnelModel, TunnelModel, QAfterFilterCondition>
      authTokenIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'authToken',
      ));
    });
  }

  QueryBuilder<TunnelModel, TunnelModel, QAfterFilterCondition>
      authTokenEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'authToken',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TunnelModel, TunnelModel, QAfterFilterCondition>
      authTokenGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'authToken',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TunnelModel, TunnelModel, QAfterFilterCondition>
      authTokenLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'authToken',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TunnelModel, TunnelModel, QAfterFilterCondition>
      authTokenBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'authToken',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TunnelModel, TunnelModel, QAfterFilterCondition>
      authTokenStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'authToken',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TunnelModel, TunnelModel, QAfterFilterCondition>
      authTokenEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'authToken',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TunnelModel, TunnelModel, QAfterFilterCondition>
      authTokenContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'authToken',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TunnelModel, TunnelModel, QAfterFilterCondition>
      authTokenMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'authToken',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TunnelModel, TunnelModel, QAfterFilterCondition>
      authTokenIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'authToken',
        value: '',
      ));
    });
  }

  QueryBuilder<TunnelModel, TunnelModel, QAfterFilterCondition>
      authTokenIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'authToken',
        value: '',
      ));
    });
  }

  QueryBuilder<TunnelModel, TunnelModel, QAfterFilterCondition>
      autoStartEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'autoStart',
        value: value,
      ));
    });
  }

  QueryBuilder<TunnelModel, TunnelModel, QAfterFilterCondition>
      createdAtIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'createdAt',
      ));
    });
  }

  QueryBuilder<TunnelModel, TunnelModel, QAfterFilterCondition>
      createdAtIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'createdAt',
      ));
    });
  }

  QueryBuilder<TunnelModel, TunnelModel, QAfterFilterCondition>
      createdAtEqualTo(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'createdAt',
        value: value,
      ));
    });
  }

  QueryBuilder<TunnelModel, TunnelModel, QAfterFilterCondition>
      createdAtGreaterThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'createdAt',
        value: value,
      ));
    });
  }

  QueryBuilder<TunnelModel, TunnelModel, QAfterFilterCondition>
      createdAtLessThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'createdAt',
        value: value,
      ));
    });
  }

  QueryBuilder<TunnelModel, TunnelModel, QAfterFilterCondition>
      createdAtBetween(
    DateTime? lower,
    DateTime? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'createdAt',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<TunnelModel, TunnelModel, QAfterFilterCondition>
      customDomainIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'customDomain',
      ));
    });
  }

  QueryBuilder<TunnelModel, TunnelModel, QAfterFilterCondition>
      customDomainIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'customDomain',
      ));
    });
  }

  QueryBuilder<TunnelModel, TunnelModel, QAfterFilterCondition>
      customDomainEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'customDomain',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TunnelModel, TunnelModel, QAfterFilterCondition>
      customDomainGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'customDomain',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TunnelModel, TunnelModel, QAfterFilterCondition>
      customDomainLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'customDomain',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TunnelModel, TunnelModel, QAfterFilterCondition>
      customDomainBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'customDomain',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TunnelModel, TunnelModel, QAfterFilterCondition>
      customDomainStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'customDomain',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TunnelModel, TunnelModel, QAfterFilterCondition>
      customDomainEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'customDomain',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TunnelModel, TunnelModel, QAfterFilterCondition>
      customDomainContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'customDomain',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TunnelModel, TunnelModel, QAfterFilterCondition>
      customDomainMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'customDomain',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TunnelModel, TunnelModel, QAfterFilterCondition>
      customDomainIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'customDomain',
        value: '',
      ));
    });
  }

  QueryBuilder<TunnelModel, TunnelModel, QAfterFilterCondition>
      customDomainIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'customDomain',
        value: '',
      ));
    });
  }

  QueryBuilder<TunnelModel, TunnelModel, QAfterFilterCondition> idEqualTo(
      Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<TunnelModel, TunnelModel, QAfterFilterCondition> idGreaterThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<TunnelModel, TunnelModel, QAfterFilterCondition> idLessThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<TunnelModel, TunnelModel, QAfterFilterCondition> idBetween(
    Id lower,
    Id upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'id',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<TunnelModel, TunnelModel, QAfterFilterCondition>
      lastActiveAtIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'lastActiveAt',
      ));
    });
  }

  QueryBuilder<TunnelModel, TunnelModel, QAfterFilterCondition>
      lastActiveAtIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'lastActiveAt',
      ));
    });
  }

  QueryBuilder<TunnelModel, TunnelModel, QAfterFilterCondition>
      lastActiveAtEqualTo(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'lastActiveAt',
        value: value,
      ));
    });
  }

  QueryBuilder<TunnelModel, TunnelModel, QAfterFilterCondition>
      lastActiveAtGreaterThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'lastActiveAt',
        value: value,
      ));
    });
  }

  QueryBuilder<TunnelModel, TunnelModel, QAfterFilterCondition>
      lastActiveAtLessThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'lastActiveAt',
        value: value,
      ));
    });
  }

  QueryBuilder<TunnelModel, TunnelModel, QAfterFilterCondition>
      lastActiveAtBetween(
    DateTime? lower,
    DateTime? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'lastActiveAt',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<TunnelModel, TunnelModel, QAfterFilterCondition> nameEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'name',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TunnelModel, TunnelModel, QAfterFilterCondition> nameGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'name',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TunnelModel, TunnelModel, QAfterFilterCondition> nameLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'name',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TunnelModel, TunnelModel, QAfterFilterCondition> nameBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'name',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TunnelModel, TunnelModel, QAfterFilterCondition> nameStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'name',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TunnelModel, TunnelModel, QAfterFilterCondition> nameEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'name',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TunnelModel, TunnelModel, QAfterFilterCondition> nameContains(
      String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'name',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TunnelModel, TunnelModel, QAfterFilterCondition> nameMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'name',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TunnelModel, TunnelModel, QAfterFilterCondition> nameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'name',
        value: '',
      ));
    });
  }

  QueryBuilder<TunnelModel, TunnelModel, QAfterFilterCondition>
      nameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'name',
        value: '',
      ));
    });
  }

  QueryBuilder<TunnelModel, TunnelModel, QAfterFilterCondition> providerEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'provider',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TunnelModel, TunnelModel, QAfterFilterCondition>
      providerGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'provider',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TunnelModel, TunnelModel, QAfterFilterCondition>
      providerLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'provider',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TunnelModel, TunnelModel, QAfterFilterCondition> providerBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'provider',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TunnelModel, TunnelModel, QAfterFilterCondition>
      providerStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'provider',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TunnelModel, TunnelModel, QAfterFilterCondition>
      providerEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'provider',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TunnelModel, TunnelModel, QAfterFilterCondition>
      providerContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'provider',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TunnelModel, TunnelModel, QAfterFilterCondition> providerMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'provider',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TunnelModel, TunnelModel, QAfterFilterCondition>
      providerIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'provider',
        value: '',
      ));
    });
  }

  QueryBuilder<TunnelModel, TunnelModel, QAfterFilterCondition>
      providerIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'provider',
        value: '',
      ));
    });
  }

  QueryBuilder<TunnelModel, TunnelModel, QAfterFilterCondition>
      targetPortEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'targetPort',
        value: value,
      ));
    });
  }

  QueryBuilder<TunnelModel, TunnelModel, QAfterFilterCondition>
      targetPortGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'targetPort',
        value: value,
      ));
    });
  }

  QueryBuilder<TunnelModel, TunnelModel, QAfterFilterCondition>
      targetPortLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'targetPort',
        value: value,
      ));
    });
  }

  QueryBuilder<TunnelModel, TunnelModel, QAfterFilterCondition>
      targetPortBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'targetPort',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<TunnelModel, TunnelModel, QAfterFilterCondition>
      targetSiteDomainIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'targetSiteDomain',
      ));
    });
  }

  QueryBuilder<TunnelModel, TunnelModel, QAfterFilterCondition>
      targetSiteDomainIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'targetSiteDomain',
      ));
    });
  }

  QueryBuilder<TunnelModel, TunnelModel, QAfterFilterCondition>
      targetSiteDomainEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'targetSiteDomain',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TunnelModel, TunnelModel, QAfterFilterCondition>
      targetSiteDomainGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'targetSiteDomain',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TunnelModel, TunnelModel, QAfterFilterCondition>
      targetSiteDomainLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'targetSiteDomain',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TunnelModel, TunnelModel, QAfterFilterCondition>
      targetSiteDomainBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'targetSiteDomain',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TunnelModel, TunnelModel, QAfterFilterCondition>
      targetSiteDomainStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'targetSiteDomain',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TunnelModel, TunnelModel, QAfterFilterCondition>
      targetSiteDomainEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'targetSiteDomain',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TunnelModel, TunnelModel, QAfterFilterCondition>
      targetSiteDomainContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'targetSiteDomain',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TunnelModel, TunnelModel, QAfterFilterCondition>
      targetSiteDomainMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'targetSiteDomain',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TunnelModel, TunnelModel, QAfterFilterCondition>
      targetSiteDomainIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'targetSiteDomain',
        value: '',
      ));
    });
  }

  QueryBuilder<TunnelModel, TunnelModel, QAfterFilterCondition>
      targetSiteDomainIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'targetSiteDomain',
        value: '',
      ));
    });
  }

  QueryBuilder<TunnelModel, TunnelModel, QAfterFilterCondition>
      targetTypeEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'targetType',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TunnelModel, TunnelModel, QAfterFilterCondition>
      targetTypeGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'targetType',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TunnelModel, TunnelModel, QAfterFilterCondition>
      targetTypeLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'targetType',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TunnelModel, TunnelModel, QAfterFilterCondition>
      targetTypeBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'targetType',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TunnelModel, TunnelModel, QAfterFilterCondition>
      targetTypeStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'targetType',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TunnelModel, TunnelModel, QAfterFilterCondition>
      targetTypeEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'targetType',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TunnelModel, TunnelModel, QAfterFilterCondition>
      targetTypeContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'targetType',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TunnelModel, TunnelModel, QAfterFilterCondition>
      targetTypeMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'targetType',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TunnelModel, TunnelModel, QAfterFilterCondition>
      targetTypeIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'targetType',
        value: '',
      ));
    });
  }

  QueryBuilder<TunnelModel, TunnelModel, QAfterFilterCondition>
      targetTypeIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'targetType',
        value: '',
      ));
    });
  }
}

extension TunnelModelQueryObject
    on QueryBuilder<TunnelModel, TunnelModel, QFilterCondition> {}

extension TunnelModelQueryLinks
    on QueryBuilder<TunnelModel, TunnelModel, QFilterCondition> {}

extension TunnelModelQuerySortBy
    on QueryBuilder<TunnelModel, TunnelModel, QSortBy> {
  QueryBuilder<TunnelModel, TunnelModel, QAfterSortBy> sortByAuthToken() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'authToken', Sort.asc);
    });
  }

  QueryBuilder<TunnelModel, TunnelModel, QAfterSortBy> sortByAuthTokenDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'authToken', Sort.desc);
    });
  }

  QueryBuilder<TunnelModel, TunnelModel, QAfterSortBy> sortByAutoStart() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'autoStart', Sort.asc);
    });
  }

  QueryBuilder<TunnelModel, TunnelModel, QAfterSortBy> sortByAutoStartDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'autoStart', Sort.desc);
    });
  }

  QueryBuilder<TunnelModel, TunnelModel, QAfterSortBy> sortByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.asc);
    });
  }

  QueryBuilder<TunnelModel, TunnelModel, QAfterSortBy> sortByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.desc);
    });
  }

  QueryBuilder<TunnelModel, TunnelModel, QAfterSortBy> sortByCustomDomain() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'customDomain', Sort.asc);
    });
  }

  QueryBuilder<TunnelModel, TunnelModel, QAfterSortBy>
      sortByCustomDomainDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'customDomain', Sort.desc);
    });
  }

  QueryBuilder<TunnelModel, TunnelModel, QAfterSortBy> sortByLastActiveAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastActiveAt', Sort.asc);
    });
  }

  QueryBuilder<TunnelModel, TunnelModel, QAfterSortBy>
      sortByLastActiveAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastActiveAt', Sort.desc);
    });
  }

  QueryBuilder<TunnelModel, TunnelModel, QAfterSortBy> sortByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'name', Sort.asc);
    });
  }

  QueryBuilder<TunnelModel, TunnelModel, QAfterSortBy> sortByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'name', Sort.desc);
    });
  }

  QueryBuilder<TunnelModel, TunnelModel, QAfterSortBy> sortByProvider() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'provider', Sort.asc);
    });
  }

  QueryBuilder<TunnelModel, TunnelModel, QAfterSortBy> sortByProviderDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'provider', Sort.desc);
    });
  }

  QueryBuilder<TunnelModel, TunnelModel, QAfterSortBy> sortByTargetPort() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'targetPort', Sort.asc);
    });
  }

  QueryBuilder<TunnelModel, TunnelModel, QAfterSortBy> sortByTargetPortDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'targetPort', Sort.desc);
    });
  }

  QueryBuilder<TunnelModel, TunnelModel, QAfterSortBy>
      sortByTargetSiteDomain() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'targetSiteDomain', Sort.asc);
    });
  }

  QueryBuilder<TunnelModel, TunnelModel, QAfterSortBy>
      sortByTargetSiteDomainDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'targetSiteDomain', Sort.desc);
    });
  }

  QueryBuilder<TunnelModel, TunnelModel, QAfterSortBy> sortByTargetType() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'targetType', Sort.asc);
    });
  }

  QueryBuilder<TunnelModel, TunnelModel, QAfterSortBy> sortByTargetTypeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'targetType', Sort.desc);
    });
  }
}

extension TunnelModelQuerySortThenBy
    on QueryBuilder<TunnelModel, TunnelModel, QSortThenBy> {
  QueryBuilder<TunnelModel, TunnelModel, QAfterSortBy> thenByAuthToken() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'authToken', Sort.asc);
    });
  }

  QueryBuilder<TunnelModel, TunnelModel, QAfterSortBy> thenByAuthTokenDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'authToken', Sort.desc);
    });
  }

  QueryBuilder<TunnelModel, TunnelModel, QAfterSortBy> thenByAutoStart() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'autoStart', Sort.asc);
    });
  }

  QueryBuilder<TunnelModel, TunnelModel, QAfterSortBy> thenByAutoStartDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'autoStart', Sort.desc);
    });
  }

  QueryBuilder<TunnelModel, TunnelModel, QAfterSortBy> thenByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.asc);
    });
  }

  QueryBuilder<TunnelModel, TunnelModel, QAfterSortBy> thenByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.desc);
    });
  }

  QueryBuilder<TunnelModel, TunnelModel, QAfterSortBy> thenByCustomDomain() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'customDomain', Sort.asc);
    });
  }

  QueryBuilder<TunnelModel, TunnelModel, QAfterSortBy>
      thenByCustomDomainDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'customDomain', Sort.desc);
    });
  }

  QueryBuilder<TunnelModel, TunnelModel, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<TunnelModel, TunnelModel, QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<TunnelModel, TunnelModel, QAfterSortBy> thenByLastActiveAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastActiveAt', Sort.asc);
    });
  }

  QueryBuilder<TunnelModel, TunnelModel, QAfterSortBy>
      thenByLastActiveAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastActiveAt', Sort.desc);
    });
  }

  QueryBuilder<TunnelModel, TunnelModel, QAfterSortBy> thenByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'name', Sort.asc);
    });
  }

  QueryBuilder<TunnelModel, TunnelModel, QAfterSortBy> thenByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'name', Sort.desc);
    });
  }

  QueryBuilder<TunnelModel, TunnelModel, QAfterSortBy> thenByProvider() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'provider', Sort.asc);
    });
  }

  QueryBuilder<TunnelModel, TunnelModel, QAfterSortBy> thenByProviderDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'provider', Sort.desc);
    });
  }

  QueryBuilder<TunnelModel, TunnelModel, QAfterSortBy> thenByTargetPort() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'targetPort', Sort.asc);
    });
  }

  QueryBuilder<TunnelModel, TunnelModel, QAfterSortBy> thenByTargetPortDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'targetPort', Sort.desc);
    });
  }

  QueryBuilder<TunnelModel, TunnelModel, QAfterSortBy>
      thenByTargetSiteDomain() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'targetSiteDomain', Sort.asc);
    });
  }

  QueryBuilder<TunnelModel, TunnelModel, QAfterSortBy>
      thenByTargetSiteDomainDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'targetSiteDomain', Sort.desc);
    });
  }

  QueryBuilder<TunnelModel, TunnelModel, QAfterSortBy> thenByTargetType() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'targetType', Sort.asc);
    });
  }

  QueryBuilder<TunnelModel, TunnelModel, QAfterSortBy> thenByTargetTypeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'targetType', Sort.desc);
    });
  }
}

extension TunnelModelQueryWhereDistinct
    on QueryBuilder<TunnelModel, TunnelModel, QDistinct> {
  QueryBuilder<TunnelModel, TunnelModel, QDistinct> distinctByAuthToken(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'authToken', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<TunnelModel, TunnelModel, QDistinct> distinctByAutoStart() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'autoStart');
    });
  }

  QueryBuilder<TunnelModel, TunnelModel, QDistinct> distinctByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'createdAt');
    });
  }

  QueryBuilder<TunnelModel, TunnelModel, QDistinct> distinctByCustomDomain(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'customDomain', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<TunnelModel, TunnelModel, QDistinct> distinctByLastActiveAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'lastActiveAt');
    });
  }

  QueryBuilder<TunnelModel, TunnelModel, QDistinct> distinctByName(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'name', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<TunnelModel, TunnelModel, QDistinct> distinctByProvider(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'provider', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<TunnelModel, TunnelModel, QDistinct> distinctByTargetPort() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'targetPort');
    });
  }

  QueryBuilder<TunnelModel, TunnelModel, QDistinct> distinctByTargetSiteDomain(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'targetSiteDomain',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<TunnelModel, TunnelModel, QDistinct> distinctByTargetType(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'targetType', caseSensitive: caseSensitive);
    });
  }
}

extension TunnelModelQueryProperty
    on QueryBuilder<TunnelModel, TunnelModel, QQueryProperty> {
  QueryBuilder<TunnelModel, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<TunnelModel, String?, QQueryOperations> authTokenProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'authToken');
    });
  }

  QueryBuilder<TunnelModel, bool, QQueryOperations> autoStartProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'autoStart');
    });
  }

  QueryBuilder<TunnelModel, DateTime?, QQueryOperations> createdAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'createdAt');
    });
  }

  QueryBuilder<TunnelModel, String?, QQueryOperations> customDomainProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'customDomain');
    });
  }

  QueryBuilder<TunnelModel, DateTime?, QQueryOperations>
      lastActiveAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'lastActiveAt');
    });
  }

  QueryBuilder<TunnelModel, String, QQueryOperations> nameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'name');
    });
  }

  QueryBuilder<TunnelModel, String, QQueryOperations> providerProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'provider');
    });
  }

  QueryBuilder<TunnelModel, int, QQueryOperations> targetPortProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'targetPort');
    });
  }

  QueryBuilder<TunnelModel, String?, QQueryOperations>
      targetSiteDomainProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'targetSiteDomain');
    });
  }

  QueryBuilder<TunnelModel, String, QQueryOperations> targetTypeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'targetType');
    });
  }
}
