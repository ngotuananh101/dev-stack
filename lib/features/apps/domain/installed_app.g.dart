// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'installed_app.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetInstalledAppCollection on Isar {
  IsarCollection<InstalledApp> get installedApps => this.collection();
}

const InstalledAppSchema = CollectionSchema(
  name: r'InstalledApp',
  id: 9146148135859156626,
  properties: {
    r'addedToPath': PropertySchema(
      id: 0,
      name: r'addedToPath',
      type: IsarType.bool,
    ),
    r'appId': PropertySchema(
      id: 1,
      name: r'appId',
      type: IsarType.string,
    ),
    r'appName': PropertySchema(
      id: 2,
      name: r'appName',
      type: IsarType.string,
    ),
    r'autoStartService': PropertySchema(
      id: 3,
      name: r'autoStartService',
      type: IsarType.bool,
    ),
    r'cliFilePath': PropertySchema(
      id: 4,
      name: r'cliFilePath',
      type: IsarType.string,
    ),
    r'execFilePath': PropertySchema(
      id: 5,
      name: r'execFilePath',
      type: IsarType.string,
    ),
    r'installedAt': PropertySchema(
      id: 6,
      name: r'installedAt',
      type: IsarType.dateTime,
    ),
    r'location': PropertySchema(
      id: 7,
      name: r'location',
      type: IsarType.string,
    ),
    r'status': PropertySchema(
      id: 8,
      name: r'status',
      type: IsarType.string,
    ),
    r'version': PropertySchema(
      id: 9,
      name: r'version',
      type: IsarType.string,
    )
  },
  estimateSize: _installedAppEstimateSize,
  serialize: _installedAppSerialize,
  deserialize: _installedAppDeserialize,
  deserializeProp: _installedAppDeserializeProp,
  idName: r'id',
  indexes: {
    r'appId': IndexSchema(
      id: -6867569882656943350,
      name: r'appId',
      unique: true,
      replace: true,
      properties: [
        IndexPropertySchema(
          name: r'appId',
          type: IndexType.hash,
          caseSensitive: true,
        )
      ],
    ),
    r'addedToPath': IndexSchema(
      id: 4463128705234900207,
      name: r'addedToPath',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'addedToPath',
          type: IndexType.value,
          caseSensitive: false,
        )
      ],
    )
  },
  links: {},
  embeddedSchemas: {},
  getId: _installedAppGetId,
  getLinks: _installedAppGetLinks,
  attach: _installedAppAttach,
  version: '3.1.0+1',
);

int _installedAppEstimateSize(
  InstalledApp object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.appId.length * 3;
  bytesCount += 3 + object.appName.length * 3;
  {
    final value = object.cliFilePath;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.execFilePath;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.location.length * 3;
  bytesCount += 3 + object.status.length * 3;
  {
    final value = object.version;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  return bytesCount;
}

void _installedAppSerialize(
  InstalledApp object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeBool(offsets[0], object.addedToPath);
  writer.writeString(offsets[1], object.appId);
  writer.writeString(offsets[2], object.appName);
  writer.writeBool(offsets[3], object.autoStartService);
  writer.writeString(offsets[4], object.cliFilePath);
  writer.writeString(offsets[5], object.execFilePath);
  writer.writeDateTime(offsets[6], object.installedAt);
  writer.writeString(offsets[7], object.location);
  writer.writeString(offsets[8], object.status);
  writer.writeString(offsets[9], object.version);
}

InstalledApp _installedAppDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = InstalledApp(
    addedToPath: reader.readBoolOrNull(offsets[0]) ?? false,
    appId: reader.readString(offsets[1]),
    appName: reader.readString(offsets[2]),
    autoStartService: reader.readBoolOrNull(offsets[3]) ?? false,
    cliFilePath: reader.readStringOrNull(offsets[4]),
    execFilePath: reader.readStringOrNull(offsets[5]),
    installedAt: reader.readDateTimeOrNull(offsets[6]),
    location: reader.readString(offsets[7]),
    status: reader.readString(offsets[8]),
    version: reader.readStringOrNull(offsets[9]),
  );
  object.id = id;
  return object;
}

P _installedAppDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readBoolOrNull(offset) ?? false) as P;
    case 1:
      return (reader.readString(offset)) as P;
    case 2:
      return (reader.readString(offset)) as P;
    case 3:
      return (reader.readBoolOrNull(offset) ?? false) as P;
    case 4:
      return (reader.readStringOrNull(offset)) as P;
    case 5:
      return (reader.readStringOrNull(offset)) as P;
    case 6:
      return (reader.readDateTimeOrNull(offset)) as P;
    case 7:
      return (reader.readString(offset)) as P;
    case 8:
      return (reader.readString(offset)) as P;
    case 9:
      return (reader.readStringOrNull(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _installedAppGetId(InstalledApp object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _installedAppGetLinks(InstalledApp object) {
  return [];
}

void _installedAppAttach(
    IsarCollection<dynamic> col, Id id, InstalledApp object) {
  object.id = id;
}

extension InstalledAppByIndex on IsarCollection<InstalledApp> {
  Future<InstalledApp?> getByAppId(String appId) {
    return getByIndex(r'appId', [appId]);
  }

  InstalledApp? getByAppIdSync(String appId) {
    return getByIndexSync(r'appId', [appId]);
  }

  Future<bool> deleteByAppId(String appId) {
    return deleteByIndex(r'appId', [appId]);
  }

  bool deleteByAppIdSync(String appId) {
    return deleteByIndexSync(r'appId', [appId]);
  }

  Future<List<InstalledApp?>> getAllByAppId(List<String> appIdValues) {
    final values = appIdValues.map((e) => [e]).toList();
    return getAllByIndex(r'appId', values);
  }

  List<InstalledApp?> getAllByAppIdSync(List<String> appIdValues) {
    final values = appIdValues.map((e) => [e]).toList();
    return getAllByIndexSync(r'appId', values);
  }

  Future<int> deleteAllByAppId(List<String> appIdValues) {
    final values = appIdValues.map((e) => [e]).toList();
    return deleteAllByIndex(r'appId', values);
  }

  int deleteAllByAppIdSync(List<String> appIdValues) {
    final values = appIdValues.map((e) => [e]).toList();
    return deleteAllByIndexSync(r'appId', values);
  }

  Future<Id> putByAppId(InstalledApp object) {
    return putByIndex(r'appId', object);
  }

  Id putByAppIdSync(InstalledApp object, {bool saveLinks = true}) {
    return putByIndexSync(r'appId', object, saveLinks: saveLinks);
  }

  Future<List<Id>> putAllByAppId(List<InstalledApp> objects) {
    return putAllByIndex(r'appId', objects);
  }

  List<Id> putAllByAppIdSync(List<InstalledApp> objects,
      {bool saveLinks = true}) {
    return putAllByIndexSync(r'appId', objects, saveLinks: saveLinks);
  }
}

extension InstalledAppQueryWhereSort
    on QueryBuilder<InstalledApp, InstalledApp, QWhere> {
  QueryBuilder<InstalledApp, InstalledApp, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterWhere> anyAddedToPath() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'addedToPath'),
      );
    });
  }
}

extension InstalledAppQueryWhere
    on QueryBuilder<InstalledApp, InstalledApp, QWhereClause> {
  QueryBuilder<InstalledApp, InstalledApp, QAfterWhereClause> idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: id,
        upper: id,
      ));
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterWhereClause> idNotEqualTo(
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

  QueryBuilder<InstalledApp, InstalledApp, QAfterWhereClause> idGreaterThan(
      Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterWhereClause> idLessThan(Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterWhereClause> idBetween(
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

  QueryBuilder<InstalledApp, InstalledApp, QAfterWhereClause> appIdEqualTo(
      String appId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'appId',
        value: [appId],
      ));
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterWhereClause> appIdNotEqualTo(
      String appId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'appId',
              lower: [],
              upper: [appId],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'appId',
              lower: [appId],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'appId',
              lower: [appId],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'appId',
              lower: [],
              upper: [appId],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterWhereClause>
      addedToPathEqualTo(bool addedToPath) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'addedToPath',
        value: [addedToPath],
      ));
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterWhereClause>
      addedToPathNotEqualTo(bool addedToPath) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'addedToPath',
              lower: [],
              upper: [addedToPath],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'addedToPath',
              lower: [addedToPath],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'addedToPath',
              lower: [addedToPath],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'addedToPath',
              lower: [],
              upper: [addedToPath],
              includeUpper: false,
            ));
      }
    });
  }
}

extension InstalledAppQueryFilter
    on QueryBuilder<InstalledApp, InstalledApp, QFilterCondition> {
  QueryBuilder<InstalledApp, InstalledApp, QAfterFilterCondition>
      addedToPathEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'addedToPath',
        value: value,
      ));
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterFilterCondition> appIdEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'appId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterFilterCondition>
      appIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'appId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterFilterCondition> appIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'appId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterFilterCondition> appIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'appId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterFilterCondition>
      appIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'appId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterFilterCondition> appIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'appId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterFilterCondition> appIdContains(
      String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'appId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterFilterCondition> appIdMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'appId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterFilterCondition>
      appIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'appId',
        value: '',
      ));
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterFilterCondition>
      appIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'appId',
        value: '',
      ));
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterFilterCondition>
      appNameEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'appName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterFilterCondition>
      appNameGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'appName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterFilterCondition>
      appNameLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'appName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterFilterCondition>
      appNameBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'appName',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterFilterCondition>
      appNameStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'appName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterFilterCondition>
      appNameEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'appName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterFilterCondition>
      appNameContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'appName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterFilterCondition>
      appNameMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'appName',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterFilterCondition>
      appNameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'appName',
        value: '',
      ));
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterFilterCondition>
      appNameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'appName',
        value: '',
      ));
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterFilterCondition>
      autoStartServiceEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'autoStartService',
        value: value,
      ));
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterFilterCondition>
      cliFilePathIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'cliFilePath',
      ));
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterFilterCondition>
      cliFilePathIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'cliFilePath',
      ));
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterFilterCondition>
      cliFilePathEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'cliFilePath',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterFilterCondition>
      cliFilePathGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'cliFilePath',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterFilterCondition>
      cliFilePathLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'cliFilePath',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterFilterCondition>
      cliFilePathBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'cliFilePath',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterFilterCondition>
      cliFilePathStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'cliFilePath',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterFilterCondition>
      cliFilePathEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'cliFilePath',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterFilterCondition>
      cliFilePathContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'cliFilePath',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterFilterCondition>
      cliFilePathMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'cliFilePath',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterFilterCondition>
      cliFilePathIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'cliFilePath',
        value: '',
      ));
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterFilterCondition>
      cliFilePathIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'cliFilePath',
        value: '',
      ));
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterFilterCondition>
      execFilePathIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'execFilePath',
      ));
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterFilterCondition>
      execFilePathIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'execFilePath',
      ));
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterFilterCondition>
      execFilePathEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'execFilePath',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterFilterCondition>
      execFilePathGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'execFilePath',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterFilterCondition>
      execFilePathLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'execFilePath',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterFilterCondition>
      execFilePathBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'execFilePath',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterFilterCondition>
      execFilePathStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'execFilePath',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterFilterCondition>
      execFilePathEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'execFilePath',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterFilterCondition>
      execFilePathContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'execFilePath',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterFilterCondition>
      execFilePathMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'execFilePath',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterFilterCondition>
      execFilePathIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'execFilePath',
        value: '',
      ));
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterFilterCondition>
      execFilePathIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'execFilePath',
        value: '',
      ));
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterFilterCondition> idEqualTo(
      Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterFilterCondition> idGreaterThan(
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

  QueryBuilder<InstalledApp, InstalledApp, QAfterFilterCondition> idLessThan(
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

  QueryBuilder<InstalledApp, InstalledApp, QAfterFilterCondition> idBetween(
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

  QueryBuilder<InstalledApp, InstalledApp, QAfterFilterCondition>
      installedAtIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'installedAt',
      ));
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterFilterCondition>
      installedAtIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'installedAt',
      ));
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterFilterCondition>
      installedAtEqualTo(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'installedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterFilterCondition>
      installedAtGreaterThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'installedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterFilterCondition>
      installedAtLessThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'installedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterFilterCondition>
      installedAtBetween(
    DateTime? lower,
    DateTime? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'installedAt',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterFilterCondition>
      locationEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'location',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterFilterCondition>
      locationGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'location',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterFilterCondition>
      locationLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'location',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterFilterCondition>
      locationBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'location',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterFilterCondition>
      locationStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'location',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterFilterCondition>
      locationEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'location',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterFilterCondition>
      locationContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'location',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterFilterCondition>
      locationMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'location',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterFilterCondition>
      locationIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'location',
        value: '',
      ));
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterFilterCondition>
      locationIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'location',
        value: '',
      ));
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterFilterCondition> statusEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'status',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterFilterCondition>
      statusGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'status',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterFilterCondition>
      statusLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'status',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterFilterCondition> statusBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'status',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterFilterCondition>
      statusStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'status',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterFilterCondition>
      statusEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'status',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterFilterCondition>
      statusContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'status',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterFilterCondition> statusMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'status',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterFilterCondition>
      statusIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'status',
        value: '',
      ));
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterFilterCondition>
      statusIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'status',
        value: '',
      ));
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterFilterCondition>
      versionIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'version',
      ));
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterFilterCondition>
      versionIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'version',
      ));
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterFilterCondition>
      versionEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'version',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterFilterCondition>
      versionGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'version',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterFilterCondition>
      versionLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'version',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterFilterCondition>
      versionBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'version',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterFilterCondition>
      versionStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'version',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterFilterCondition>
      versionEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'version',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterFilterCondition>
      versionContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'version',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterFilterCondition>
      versionMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'version',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterFilterCondition>
      versionIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'version',
        value: '',
      ));
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterFilterCondition>
      versionIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'version',
        value: '',
      ));
    });
  }
}

extension InstalledAppQueryObject
    on QueryBuilder<InstalledApp, InstalledApp, QFilterCondition> {}

extension InstalledAppQueryLinks
    on QueryBuilder<InstalledApp, InstalledApp, QFilterCondition> {}

extension InstalledAppQuerySortBy
    on QueryBuilder<InstalledApp, InstalledApp, QSortBy> {
  QueryBuilder<InstalledApp, InstalledApp, QAfterSortBy> sortByAddedToPath() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'addedToPath', Sort.asc);
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterSortBy>
      sortByAddedToPathDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'addedToPath', Sort.desc);
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterSortBy> sortByAppId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'appId', Sort.asc);
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterSortBy> sortByAppIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'appId', Sort.desc);
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterSortBy> sortByAppName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'appName', Sort.asc);
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterSortBy> sortByAppNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'appName', Sort.desc);
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterSortBy>
      sortByAutoStartService() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'autoStartService', Sort.asc);
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterSortBy>
      sortByAutoStartServiceDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'autoStartService', Sort.desc);
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterSortBy> sortByCliFilePath() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cliFilePath', Sort.asc);
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterSortBy>
      sortByCliFilePathDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cliFilePath', Sort.desc);
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterSortBy> sortByExecFilePath() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'execFilePath', Sort.asc);
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterSortBy>
      sortByExecFilePathDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'execFilePath', Sort.desc);
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterSortBy> sortByInstalledAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'installedAt', Sort.asc);
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterSortBy>
      sortByInstalledAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'installedAt', Sort.desc);
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterSortBy> sortByLocation() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'location', Sort.asc);
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterSortBy> sortByLocationDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'location', Sort.desc);
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterSortBy> sortByStatus() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'status', Sort.asc);
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterSortBy> sortByStatusDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'status', Sort.desc);
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterSortBy> sortByVersion() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'version', Sort.asc);
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterSortBy> sortByVersionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'version', Sort.desc);
    });
  }
}

extension InstalledAppQuerySortThenBy
    on QueryBuilder<InstalledApp, InstalledApp, QSortThenBy> {
  QueryBuilder<InstalledApp, InstalledApp, QAfterSortBy> thenByAddedToPath() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'addedToPath', Sort.asc);
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterSortBy>
      thenByAddedToPathDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'addedToPath', Sort.desc);
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterSortBy> thenByAppId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'appId', Sort.asc);
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterSortBy> thenByAppIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'appId', Sort.desc);
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterSortBy> thenByAppName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'appName', Sort.asc);
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterSortBy> thenByAppNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'appName', Sort.desc);
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterSortBy>
      thenByAutoStartService() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'autoStartService', Sort.asc);
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterSortBy>
      thenByAutoStartServiceDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'autoStartService', Sort.desc);
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterSortBy> thenByCliFilePath() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cliFilePath', Sort.asc);
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterSortBy>
      thenByCliFilePathDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cliFilePath', Sort.desc);
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterSortBy> thenByExecFilePath() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'execFilePath', Sort.asc);
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterSortBy>
      thenByExecFilePathDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'execFilePath', Sort.desc);
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterSortBy> thenByInstalledAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'installedAt', Sort.asc);
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterSortBy>
      thenByInstalledAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'installedAt', Sort.desc);
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterSortBy> thenByLocation() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'location', Sort.asc);
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterSortBy> thenByLocationDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'location', Sort.desc);
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterSortBy> thenByStatus() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'status', Sort.asc);
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterSortBy> thenByStatusDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'status', Sort.desc);
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterSortBy> thenByVersion() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'version', Sort.asc);
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterSortBy> thenByVersionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'version', Sort.desc);
    });
  }
}

extension InstalledAppQueryWhereDistinct
    on QueryBuilder<InstalledApp, InstalledApp, QDistinct> {
  QueryBuilder<InstalledApp, InstalledApp, QDistinct> distinctByAddedToPath() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'addedToPath');
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QDistinct> distinctByAppId(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'appId', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QDistinct> distinctByAppName(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'appName', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QDistinct>
      distinctByAutoStartService() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'autoStartService');
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QDistinct> distinctByCliFilePath(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'cliFilePath', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QDistinct> distinctByExecFilePath(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'execFilePath', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QDistinct> distinctByInstalledAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'installedAt');
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QDistinct> distinctByLocation(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'location', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QDistinct> distinctByStatus(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'status', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QDistinct> distinctByVersion(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'version', caseSensitive: caseSensitive);
    });
  }
}

extension InstalledAppQueryProperty
    on QueryBuilder<InstalledApp, InstalledApp, QQueryProperty> {
  QueryBuilder<InstalledApp, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<InstalledApp, bool, QQueryOperations> addedToPathProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'addedToPath');
    });
  }

  QueryBuilder<InstalledApp, String, QQueryOperations> appIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'appId');
    });
  }

  QueryBuilder<InstalledApp, String, QQueryOperations> appNameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'appName');
    });
  }

  QueryBuilder<InstalledApp, bool, QQueryOperations>
      autoStartServiceProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'autoStartService');
    });
  }

  QueryBuilder<InstalledApp, String?, QQueryOperations> cliFilePathProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'cliFilePath');
    });
  }

  QueryBuilder<InstalledApp, String?, QQueryOperations> execFilePathProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'execFilePath');
    });
  }

  QueryBuilder<InstalledApp, DateTime?, QQueryOperations>
      installedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'installedAt');
    });
  }

  QueryBuilder<InstalledApp, String, QQueryOperations> locationProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'location');
    });
  }

  QueryBuilder<InstalledApp, String, QQueryOperations> statusProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'status');
    });
  }

  QueryBuilder<InstalledApp, String?, QQueryOperations> versionProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'version');
    });
  }
}
