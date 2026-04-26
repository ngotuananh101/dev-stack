// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'site_model.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetSiteModelCollection on Isar {
  IsarCollection<SiteModel> get siteModels => this.collection();
}

const SiteModelSchema = CollectionSchema(
  name: r'SiteModel',
  id: 2283781731892198758,
  properties: {
    r'createdAt': PropertySchema(
      id: 0,
      name: r'createdAt',
      type: IsarType.dateTime,
    ),
    r'domain': PropertySchema(
      id: 1,
      name: r'domain',
      type: IsarType.string,
    ),
    r'phpPort': PropertySchema(
      id: 2,
      name: r'phpPort',
      type: IsarType.long,
    ),
    r'phpVersion': PropertySchema(
      id: 3,
      name: r'phpVersion',
      type: IsarType.string,
    ),
    r'proxyTarget': PropertySchema(
      id: 4,
      name: r'proxyTarget',
      type: IsarType.string,
    ),
    r'rootDir': PropertySchema(
      id: 5,
      name: r'rootDir',
      type: IsarType.string,
    ),
    r'siteType': PropertySchema(
      id: 6,
      name: r'siteType',
      type: IsarType.string,
    ),
    r'useSsl': PropertySchema(
      id: 7,
      name: r'useSsl',
      type: IsarType.bool,
    )
  },
  estimateSize: _siteModelEstimateSize,
  serialize: _siteModelSerialize,
  deserialize: _siteModelDeserialize,
  deserializeProp: _siteModelDeserializeProp,
  idName: r'id',
  indexes: {
    r'domain': IndexSchema(
      id: 1163864941618423784,
      name: r'domain',
      unique: true,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'domain',
          type: IndexType.hash,
          caseSensitive: true,
        )
      ],
    )
  },
  links: {},
  embeddedSchemas: {},
  getId: _siteModelGetId,
  getLinks: _siteModelGetLinks,
  attach: _siteModelAttach,
  version: '3.1.0+1',
);

int _siteModelEstimateSize(
  SiteModel object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.domain.length * 3;
  {
    final value = object.phpVersion;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.proxyTarget;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.rootDir.length * 3;
  bytesCount += 3 + object.siteType.length * 3;
  return bytesCount;
}

void _siteModelSerialize(
  SiteModel object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeDateTime(offsets[0], object.createdAt);
  writer.writeString(offsets[1], object.domain);
  writer.writeLong(offsets[2], object.phpPort);
  writer.writeString(offsets[3], object.phpVersion);
  writer.writeString(offsets[4], object.proxyTarget);
  writer.writeString(offsets[5], object.rootDir);
  writer.writeString(offsets[6], object.siteType);
  writer.writeBool(offsets[7], object.useSsl);
}

SiteModel _siteModelDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = SiteModel(
    createdAt: reader.readDateTimeOrNull(offsets[0]),
    domain: reader.readString(offsets[1]),
    id: id,
    phpPort: reader.readLongOrNull(offsets[2]),
    phpVersion: reader.readStringOrNull(offsets[3]),
    proxyTarget: reader.readStringOrNull(offsets[4]),
    rootDir: reader.readString(offsets[5]),
    siteType: reader.readStringOrNull(offsets[6]) ?? 'php',
    useSsl: reader.readBoolOrNull(offsets[7]) ?? false,
  );
  return object;
}

P _siteModelDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readDateTimeOrNull(offset)) as P;
    case 1:
      return (reader.readString(offset)) as P;
    case 2:
      return (reader.readLongOrNull(offset)) as P;
    case 3:
      return (reader.readStringOrNull(offset)) as P;
    case 4:
      return (reader.readStringOrNull(offset)) as P;
    case 5:
      return (reader.readString(offset)) as P;
    case 6:
      return (reader.readStringOrNull(offset) ?? 'php') as P;
    case 7:
      return (reader.readBoolOrNull(offset) ?? false) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _siteModelGetId(SiteModel object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _siteModelGetLinks(SiteModel object) {
  return [];
}

void _siteModelAttach(IsarCollection<dynamic> col, Id id, SiteModel object) {
  object.id = id;
}

extension SiteModelByIndex on IsarCollection<SiteModel> {
  Future<SiteModel?> getByDomain(String domain) {
    return getByIndex(r'domain', [domain]);
  }

  SiteModel? getByDomainSync(String domain) {
    return getByIndexSync(r'domain', [domain]);
  }

  Future<bool> deleteByDomain(String domain) {
    return deleteByIndex(r'domain', [domain]);
  }

  bool deleteByDomainSync(String domain) {
    return deleteByIndexSync(r'domain', [domain]);
  }

  Future<List<SiteModel?>> getAllByDomain(List<String> domainValues) {
    final values = domainValues.map((e) => [e]).toList();
    return getAllByIndex(r'domain', values);
  }

  List<SiteModel?> getAllByDomainSync(List<String> domainValues) {
    final values = domainValues.map((e) => [e]).toList();
    return getAllByIndexSync(r'domain', values);
  }

  Future<int> deleteAllByDomain(List<String> domainValues) {
    final values = domainValues.map((e) => [e]).toList();
    return deleteAllByIndex(r'domain', values);
  }

  int deleteAllByDomainSync(List<String> domainValues) {
    final values = domainValues.map((e) => [e]).toList();
    return deleteAllByIndexSync(r'domain', values);
  }

  Future<Id> putByDomain(SiteModel object) {
    return putByIndex(r'domain', object);
  }

  Id putByDomainSync(SiteModel object, {bool saveLinks = true}) {
    return putByIndexSync(r'domain', object, saveLinks: saveLinks);
  }

  Future<List<Id>> putAllByDomain(List<SiteModel> objects) {
    return putAllByIndex(r'domain', objects);
  }

  List<Id> putAllByDomainSync(List<SiteModel> objects,
      {bool saveLinks = true}) {
    return putAllByIndexSync(r'domain', objects, saveLinks: saveLinks);
  }
}

extension SiteModelQueryWhereSort
    on QueryBuilder<SiteModel, SiteModel, QWhere> {
  QueryBuilder<SiteModel, SiteModel, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension SiteModelQueryWhere
    on QueryBuilder<SiteModel, SiteModel, QWhereClause> {
  QueryBuilder<SiteModel, SiteModel, QAfterWhereClause> idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: id,
        upper: id,
      ));
    });
  }

  QueryBuilder<SiteModel, SiteModel, QAfterWhereClause> idNotEqualTo(Id id) {
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

  QueryBuilder<SiteModel, SiteModel, QAfterWhereClause> idGreaterThan(Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<SiteModel, SiteModel, QAfterWhereClause> idLessThan(Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<SiteModel, SiteModel, QAfterWhereClause> idBetween(
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

  QueryBuilder<SiteModel, SiteModel, QAfterWhereClause> domainEqualTo(
      String domain) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'domain',
        value: [domain],
      ));
    });
  }

  QueryBuilder<SiteModel, SiteModel, QAfterWhereClause> domainNotEqualTo(
      String domain) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'domain',
              lower: [],
              upper: [domain],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'domain',
              lower: [domain],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'domain',
              lower: [domain],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'domain',
              lower: [],
              upper: [domain],
              includeUpper: false,
            ));
      }
    });
  }
}

extension SiteModelQueryFilter
    on QueryBuilder<SiteModel, SiteModel, QFilterCondition> {
  QueryBuilder<SiteModel, SiteModel, QAfterFilterCondition> createdAtIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'createdAt',
      ));
    });
  }

  QueryBuilder<SiteModel, SiteModel, QAfterFilterCondition>
      createdAtIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'createdAt',
      ));
    });
  }

  QueryBuilder<SiteModel, SiteModel, QAfterFilterCondition> createdAtEqualTo(
      DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'createdAt',
        value: value,
      ));
    });
  }

  QueryBuilder<SiteModel, SiteModel, QAfterFilterCondition>
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

  QueryBuilder<SiteModel, SiteModel, QAfterFilterCondition> createdAtLessThan(
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

  QueryBuilder<SiteModel, SiteModel, QAfterFilterCondition> createdAtBetween(
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

  QueryBuilder<SiteModel, SiteModel, QAfterFilterCondition> domainEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'domain',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SiteModel, SiteModel, QAfterFilterCondition> domainGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'domain',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SiteModel, SiteModel, QAfterFilterCondition> domainLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'domain',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SiteModel, SiteModel, QAfterFilterCondition> domainBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'domain',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SiteModel, SiteModel, QAfterFilterCondition> domainStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'domain',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SiteModel, SiteModel, QAfterFilterCondition> domainEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'domain',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SiteModel, SiteModel, QAfterFilterCondition> domainContains(
      String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'domain',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SiteModel, SiteModel, QAfterFilterCondition> domainMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'domain',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SiteModel, SiteModel, QAfterFilterCondition> domainIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'domain',
        value: '',
      ));
    });
  }

  QueryBuilder<SiteModel, SiteModel, QAfterFilterCondition> domainIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'domain',
        value: '',
      ));
    });
  }

  QueryBuilder<SiteModel, SiteModel, QAfterFilterCondition> idEqualTo(
      Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<SiteModel, SiteModel, QAfterFilterCondition> idGreaterThan(
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

  QueryBuilder<SiteModel, SiteModel, QAfterFilterCondition> idLessThan(
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

  QueryBuilder<SiteModel, SiteModel, QAfterFilterCondition> idBetween(
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

  QueryBuilder<SiteModel, SiteModel, QAfterFilterCondition> phpPortIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'phpPort',
      ));
    });
  }

  QueryBuilder<SiteModel, SiteModel, QAfterFilterCondition> phpPortIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'phpPort',
      ));
    });
  }

  QueryBuilder<SiteModel, SiteModel, QAfterFilterCondition> phpPortEqualTo(
      int? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'phpPort',
        value: value,
      ));
    });
  }

  QueryBuilder<SiteModel, SiteModel, QAfterFilterCondition> phpPortGreaterThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'phpPort',
        value: value,
      ));
    });
  }

  QueryBuilder<SiteModel, SiteModel, QAfterFilterCondition> phpPortLessThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'phpPort',
        value: value,
      ));
    });
  }

  QueryBuilder<SiteModel, SiteModel, QAfterFilterCondition> phpPortBetween(
    int? lower,
    int? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'phpPort',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<SiteModel, SiteModel, QAfterFilterCondition> phpVersionIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'phpVersion',
      ));
    });
  }

  QueryBuilder<SiteModel, SiteModel, QAfterFilterCondition>
      phpVersionIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'phpVersion',
      ));
    });
  }

  QueryBuilder<SiteModel, SiteModel, QAfterFilterCondition> phpVersionEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'phpVersion',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SiteModel, SiteModel, QAfterFilterCondition>
      phpVersionGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'phpVersion',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SiteModel, SiteModel, QAfterFilterCondition> phpVersionLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'phpVersion',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SiteModel, SiteModel, QAfterFilterCondition> phpVersionBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'phpVersion',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SiteModel, SiteModel, QAfterFilterCondition>
      phpVersionStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'phpVersion',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SiteModel, SiteModel, QAfterFilterCondition> phpVersionEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'phpVersion',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SiteModel, SiteModel, QAfterFilterCondition> phpVersionContains(
      String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'phpVersion',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SiteModel, SiteModel, QAfterFilterCondition> phpVersionMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'phpVersion',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SiteModel, SiteModel, QAfterFilterCondition>
      phpVersionIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'phpVersion',
        value: '',
      ));
    });
  }

  QueryBuilder<SiteModel, SiteModel, QAfterFilterCondition>
      phpVersionIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'phpVersion',
        value: '',
      ));
    });
  }

  QueryBuilder<SiteModel, SiteModel, QAfterFilterCondition>
      proxyTargetIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'proxyTarget',
      ));
    });
  }

  QueryBuilder<SiteModel, SiteModel, QAfterFilterCondition>
      proxyTargetIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'proxyTarget',
      ));
    });
  }

  QueryBuilder<SiteModel, SiteModel, QAfterFilterCondition> proxyTargetEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'proxyTarget',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SiteModel, SiteModel, QAfterFilterCondition>
      proxyTargetGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'proxyTarget',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SiteModel, SiteModel, QAfterFilterCondition> proxyTargetLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'proxyTarget',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SiteModel, SiteModel, QAfterFilterCondition> proxyTargetBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'proxyTarget',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SiteModel, SiteModel, QAfterFilterCondition>
      proxyTargetStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'proxyTarget',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SiteModel, SiteModel, QAfterFilterCondition> proxyTargetEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'proxyTarget',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SiteModel, SiteModel, QAfterFilterCondition> proxyTargetContains(
      String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'proxyTarget',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SiteModel, SiteModel, QAfterFilterCondition> proxyTargetMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'proxyTarget',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SiteModel, SiteModel, QAfterFilterCondition>
      proxyTargetIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'proxyTarget',
        value: '',
      ));
    });
  }

  QueryBuilder<SiteModel, SiteModel, QAfterFilterCondition>
      proxyTargetIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'proxyTarget',
        value: '',
      ));
    });
  }

  QueryBuilder<SiteModel, SiteModel, QAfterFilterCondition> rootDirEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'rootDir',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SiteModel, SiteModel, QAfterFilterCondition> rootDirGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'rootDir',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SiteModel, SiteModel, QAfterFilterCondition> rootDirLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'rootDir',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SiteModel, SiteModel, QAfterFilterCondition> rootDirBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'rootDir',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SiteModel, SiteModel, QAfterFilterCondition> rootDirStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'rootDir',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SiteModel, SiteModel, QAfterFilterCondition> rootDirEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'rootDir',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SiteModel, SiteModel, QAfterFilterCondition> rootDirContains(
      String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'rootDir',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SiteModel, SiteModel, QAfterFilterCondition> rootDirMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'rootDir',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SiteModel, SiteModel, QAfterFilterCondition> rootDirIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'rootDir',
        value: '',
      ));
    });
  }

  QueryBuilder<SiteModel, SiteModel, QAfterFilterCondition>
      rootDirIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'rootDir',
        value: '',
      ));
    });
  }

  QueryBuilder<SiteModel, SiteModel, QAfterFilterCondition> siteTypeEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'siteType',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SiteModel, SiteModel, QAfterFilterCondition> siteTypeGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'siteType',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SiteModel, SiteModel, QAfterFilterCondition> siteTypeLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'siteType',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SiteModel, SiteModel, QAfterFilterCondition> siteTypeBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'siteType',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SiteModel, SiteModel, QAfterFilterCondition> siteTypeStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'siteType',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SiteModel, SiteModel, QAfterFilterCondition> siteTypeEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'siteType',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SiteModel, SiteModel, QAfterFilterCondition> siteTypeContains(
      String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'siteType',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SiteModel, SiteModel, QAfterFilterCondition> siteTypeMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'siteType',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SiteModel, SiteModel, QAfterFilterCondition> siteTypeIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'siteType',
        value: '',
      ));
    });
  }

  QueryBuilder<SiteModel, SiteModel, QAfterFilterCondition>
      siteTypeIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'siteType',
        value: '',
      ));
    });
  }

  QueryBuilder<SiteModel, SiteModel, QAfterFilterCondition> useSslEqualTo(
      bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'useSsl',
        value: value,
      ));
    });
  }
}

extension SiteModelQueryObject
    on QueryBuilder<SiteModel, SiteModel, QFilterCondition> {}

extension SiteModelQueryLinks
    on QueryBuilder<SiteModel, SiteModel, QFilterCondition> {}

extension SiteModelQuerySortBy on QueryBuilder<SiteModel, SiteModel, QSortBy> {
  QueryBuilder<SiteModel, SiteModel, QAfterSortBy> sortByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.asc);
    });
  }

  QueryBuilder<SiteModel, SiteModel, QAfterSortBy> sortByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.desc);
    });
  }

  QueryBuilder<SiteModel, SiteModel, QAfterSortBy> sortByDomain() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'domain', Sort.asc);
    });
  }

  QueryBuilder<SiteModel, SiteModel, QAfterSortBy> sortByDomainDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'domain', Sort.desc);
    });
  }

  QueryBuilder<SiteModel, SiteModel, QAfterSortBy> sortByPhpPort() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'phpPort', Sort.asc);
    });
  }

  QueryBuilder<SiteModel, SiteModel, QAfterSortBy> sortByPhpPortDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'phpPort', Sort.desc);
    });
  }

  QueryBuilder<SiteModel, SiteModel, QAfterSortBy> sortByPhpVersion() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'phpVersion', Sort.asc);
    });
  }

  QueryBuilder<SiteModel, SiteModel, QAfterSortBy> sortByPhpVersionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'phpVersion', Sort.desc);
    });
  }

  QueryBuilder<SiteModel, SiteModel, QAfterSortBy> sortByProxyTarget() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'proxyTarget', Sort.asc);
    });
  }

  QueryBuilder<SiteModel, SiteModel, QAfterSortBy> sortByProxyTargetDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'proxyTarget', Sort.desc);
    });
  }

  QueryBuilder<SiteModel, SiteModel, QAfterSortBy> sortByRootDir() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'rootDir', Sort.asc);
    });
  }

  QueryBuilder<SiteModel, SiteModel, QAfterSortBy> sortByRootDirDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'rootDir', Sort.desc);
    });
  }

  QueryBuilder<SiteModel, SiteModel, QAfterSortBy> sortBySiteType() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'siteType', Sort.asc);
    });
  }

  QueryBuilder<SiteModel, SiteModel, QAfterSortBy> sortBySiteTypeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'siteType', Sort.desc);
    });
  }

  QueryBuilder<SiteModel, SiteModel, QAfterSortBy> sortByUseSsl() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'useSsl', Sort.asc);
    });
  }

  QueryBuilder<SiteModel, SiteModel, QAfterSortBy> sortByUseSslDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'useSsl', Sort.desc);
    });
  }
}

extension SiteModelQuerySortThenBy
    on QueryBuilder<SiteModel, SiteModel, QSortThenBy> {
  QueryBuilder<SiteModel, SiteModel, QAfterSortBy> thenByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.asc);
    });
  }

  QueryBuilder<SiteModel, SiteModel, QAfterSortBy> thenByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.desc);
    });
  }

  QueryBuilder<SiteModel, SiteModel, QAfterSortBy> thenByDomain() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'domain', Sort.asc);
    });
  }

  QueryBuilder<SiteModel, SiteModel, QAfterSortBy> thenByDomainDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'domain', Sort.desc);
    });
  }

  QueryBuilder<SiteModel, SiteModel, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<SiteModel, SiteModel, QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<SiteModel, SiteModel, QAfterSortBy> thenByPhpPort() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'phpPort', Sort.asc);
    });
  }

  QueryBuilder<SiteModel, SiteModel, QAfterSortBy> thenByPhpPortDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'phpPort', Sort.desc);
    });
  }

  QueryBuilder<SiteModel, SiteModel, QAfterSortBy> thenByPhpVersion() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'phpVersion', Sort.asc);
    });
  }

  QueryBuilder<SiteModel, SiteModel, QAfterSortBy> thenByPhpVersionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'phpVersion', Sort.desc);
    });
  }

  QueryBuilder<SiteModel, SiteModel, QAfterSortBy> thenByProxyTarget() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'proxyTarget', Sort.asc);
    });
  }

  QueryBuilder<SiteModel, SiteModel, QAfterSortBy> thenByProxyTargetDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'proxyTarget', Sort.desc);
    });
  }

  QueryBuilder<SiteModel, SiteModel, QAfterSortBy> thenByRootDir() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'rootDir', Sort.asc);
    });
  }

  QueryBuilder<SiteModel, SiteModel, QAfterSortBy> thenByRootDirDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'rootDir', Sort.desc);
    });
  }

  QueryBuilder<SiteModel, SiteModel, QAfterSortBy> thenBySiteType() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'siteType', Sort.asc);
    });
  }

  QueryBuilder<SiteModel, SiteModel, QAfterSortBy> thenBySiteTypeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'siteType', Sort.desc);
    });
  }

  QueryBuilder<SiteModel, SiteModel, QAfterSortBy> thenByUseSsl() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'useSsl', Sort.asc);
    });
  }

  QueryBuilder<SiteModel, SiteModel, QAfterSortBy> thenByUseSslDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'useSsl', Sort.desc);
    });
  }
}

extension SiteModelQueryWhereDistinct
    on QueryBuilder<SiteModel, SiteModel, QDistinct> {
  QueryBuilder<SiteModel, SiteModel, QDistinct> distinctByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'createdAt');
    });
  }

  QueryBuilder<SiteModel, SiteModel, QDistinct> distinctByDomain(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'domain', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<SiteModel, SiteModel, QDistinct> distinctByPhpPort() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'phpPort');
    });
  }

  QueryBuilder<SiteModel, SiteModel, QDistinct> distinctByPhpVersion(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'phpVersion', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<SiteModel, SiteModel, QDistinct> distinctByProxyTarget(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'proxyTarget', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<SiteModel, SiteModel, QDistinct> distinctByRootDir(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'rootDir', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<SiteModel, SiteModel, QDistinct> distinctBySiteType(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'siteType', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<SiteModel, SiteModel, QDistinct> distinctByUseSsl() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'useSsl');
    });
  }
}

extension SiteModelQueryProperty
    on QueryBuilder<SiteModel, SiteModel, QQueryProperty> {
  QueryBuilder<SiteModel, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<SiteModel, DateTime?, QQueryOperations> createdAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'createdAt');
    });
  }

  QueryBuilder<SiteModel, String, QQueryOperations> domainProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'domain');
    });
  }

  QueryBuilder<SiteModel, int?, QQueryOperations> phpPortProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'phpPort');
    });
  }

  QueryBuilder<SiteModel, String?, QQueryOperations> phpVersionProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'phpVersion');
    });
  }

  QueryBuilder<SiteModel, String?, QQueryOperations> proxyTargetProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'proxyTarget');
    });
  }

  QueryBuilder<SiteModel, String, QQueryOperations> rootDirProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'rootDir');
    });
  }

  QueryBuilder<SiteModel, String, QQueryOperations> siteTypeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'siteType');
    });
  }

  QueryBuilder<SiteModel, bool, QQueryOperations> useSslProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'useSsl');
    });
  }
}
