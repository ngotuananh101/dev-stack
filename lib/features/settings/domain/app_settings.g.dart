// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_settings.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetAppSettingsCollection on Isar {
  IsarCollection<AppSettings> get appSettings => this.collection();
}

const AppSettingsSchema = CollectionSchema(
  name: r'AppSettings',
  id: -5633561779022347008,
  properties: {
    r'allowLanAccess': PropertySchema(
      id: 0,
      name: r'allowLanAccess',
      type: IsarType.bool,
    ),
    r'autoCreateSite': PropertySchema(
      id: 1,
      name: r'autoCreateSite',
      type: IsarType.bool,
    ),
    r'autoStartWithWindows': PropertySchema(
      id: 2,
      name: r'autoStartWithWindows',
      type: IsarType.bool,
    ),
    r'baseDir': PropertySchema(
      id: 3,
      name: r'baseDir',
      type: IsarType.string,
    ),
    r'isSslInstalled': PropertySchema(
      id: 4,
      name: r'isSslInstalled',
      type: IsarType.bool,
    ),
    r'minimizeToTray': PropertySchema(
      id: 5,
      name: r'minimizeToTray',
      type: IsarType.bool,
    ),
    r'siteTemplate': PropertySchema(
      id: 6,
      name: r'siteTemplate',
      type: IsarType.string,
    )
  },
  estimateSize: _appSettingsEstimateSize,
  serialize: _appSettingsSerialize,
  deserialize: _appSettingsDeserialize,
  deserializeProp: _appSettingsDeserializeProp,
  idName: r'id',
  indexes: {},
  links: {},
  embeddedSchemas: {},
  getId: _appSettingsGetId,
  getLinks: _appSettingsGetLinks,
  attach: _appSettingsAttach,
  version: '3.1.0+1',
);

int _appSettingsEstimateSize(
  AppSettings object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.baseDir.length * 3;
  bytesCount += 3 + object.siteTemplate.length * 3;
  return bytesCount;
}

void _appSettingsSerialize(
  AppSettings object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeBool(offsets[0], object.allowLanAccess);
  writer.writeBool(offsets[1], object.autoCreateSite);
  writer.writeBool(offsets[2], object.autoStartWithWindows);
  writer.writeString(offsets[3], object.baseDir);
  writer.writeBool(offsets[4], object.isSslInstalled);
  writer.writeBool(offsets[5], object.minimizeToTray);
  writer.writeString(offsets[6], object.siteTemplate);
}

AppSettings _appSettingsDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = AppSettings();
  object.allowLanAccess = reader.readBool(offsets[0]);
  object.autoCreateSite = reader.readBool(offsets[1]);
  object.autoStartWithWindows = reader.readBool(offsets[2]);
  object.baseDir = reader.readString(offsets[3]);
  object.id = id;
  object.isSslInstalled = reader.readBool(offsets[4]);
  object.minimizeToTray = reader.readBool(offsets[5]);
  object.siteTemplate = reader.readString(offsets[6]);
  return object;
}

P _appSettingsDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readBool(offset)) as P;
    case 1:
      return (reader.readBool(offset)) as P;
    case 2:
      return (reader.readBool(offset)) as P;
    case 3:
      return (reader.readString(offset)) as P;
    case 4:
      return (reader.readBool(offset)) as P;
    case 5:
      return (reader.readBool(offset)) as P;
    case 6:
      return (reader.readString(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _appSettingsGetId(AppSettings object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _appSettingsGetLinks(AppSettings object) {
  return [];
}

void _appSettingsAttach(
    IsarCollection<dynamic> col, Id id, AppSettings object) {
  object.id = id;
}

extension AppSettingsQueryWhereSort
    on QueryBuilder<AppSettings, AppSettings, QWhere> {
  QueryBuilder<AppSettings, AppSettings, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension AppSettingsQueryWhere
    on QueryBuilder<AppSettings, AppSettings, QWhereClause> {
  QueryBuilder<AppSettings, AppSettings, QAfterWhereClause> idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: id,
        upper: id,
      ));
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterWhereClause> idNotEqualTo(
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

  QueryBuilder<AppSettings, AppSettings, QAfterWhereClause> idGreaterThan(Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterWhereClause> idLessThan(Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterWhereClause> idBetween(
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
}

extension AppSettingsQueryFilter
    on QueryBuilder<AppSettings, AppSettings, QFilterCondition> {
  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
      allowLanAccessEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'allowLanAccess',
        value: value,
      ));
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
      autoCreateSiteEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'autoCreateSite',
        value: value,
      ));
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
      autoStartWithWindowsEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'autoStartWithWindows',
        value: value,
      ));
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition> baseDirEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'baseDir',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
      baseDirGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'baseDir',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition> baseDirLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'baseDir',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition> baseDirBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'baseDir',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
      baseDirStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'baseDir',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition> baseDirEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'baseDir',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition> baseDirContains(
      String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'baseDir',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition> baseDirMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'baseDir',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
      baseDirIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'baseDir',
        value: '',
      ));
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
      baseDirIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'baseDir',
        value: '',
      ));
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition> idEqualTo(
      Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition> idGreaterThan(
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

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition> idLessThan(
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

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition> idBetween(
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

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
      isSslInstalledEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'isSslInstalled',
        value: value,
      ));
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
      minimizeToTrayEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'minimizeToTray',
        value: value,
      ));
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
      siteTemplateEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'siteTemplate',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
      siteTemplateGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'siteTemplate',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
      siteTemplateLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'siteTemplate',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
      siteTemplateBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'siteTemplate',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
      siteTemplateStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'siteTemplate',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
      siteTemplateEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'siteTemplate',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
      siteTemplateContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'siteTemplate',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
      siteTemplateMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'siteTemplate',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
      siteTemplateIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'siteTemplate',
        value: '',
      ));
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
      siteTemplateIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'siteTemplate',
        value: '',
      ));
    });
  }
}

extension AppSettingsQueryObject
    on QueryBuilder<AppSettings, AppSettings, QFilterCondition> {}

extension AppSettingsQueryLinks
    on QueryBuilder<AppSettings, AppSettings, QFilterCondition> {}

extension AppSettingsQuerySortBy
    on QueryBuilder<AppSettings, AppSettings, QSortBy> {
  QueryBuilder<AppSettings, AppSettings, QAfterSortBy> sortByAllowLanAccess() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'allowLanAccess', Sort.asc);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy>
      sortByAllowLanAccessDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'allowLanAccess', Sort.desc);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy> sortByAutoCreateSite() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'autoCreateSite', Sort.asc);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy>
      sortByAutoCreateSiteDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'autoCreateSite', Sort.desc);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy>
      sortByAutoStartWithWindows() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'autoStartWithWindows', Sort.asc);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy>
      sortByAutoStartWithWindowsDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'autoStartWithWindows', Sort.desc);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy> sortByBaseDir() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'baseDir', Sort.asc);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy> sortByBaseDirDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'baseDir', Sort.desc);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy> sortByIsSslInstalled() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isSslInstalled', Sort.asc);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy>
      sortByIsSslInstalledDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isSslInstalled', Sort.desc);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy> sortByMinimizeToTray() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'minimizeToTray', Sort.asc);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy>
      sortByMinimizeToTrayDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'minimizeToTray', Sort.desc);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy> sortBySiteTemplate() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'siteTemplate', Sort.asc);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy>
      sortBySiteTemplateDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'siteTemplate', Sort.desc);
    });
  }
}

extension AppSettingsQuerySortThenBy
    on QueryBuilder<AppSettings, AppSettings, QSortThenBy> {
  QueryBuilder<AppSettings, AppSettings, QAfterSortBy> thenByAllowLanAccess() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'allowLanAccess', Sort.asc);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy>
      thenByAllowLanAccessDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'allowLanAccess', Sort.desc);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy> thenByAutoCreateSite() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'autoCreateSite', Sort.asc);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy>
      thenByAutoCreateSiteDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'autoCreateSite', Sort.desc);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy>
      thenByAutoStartWithWindows() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'autoStartWithWindows', Sort.asc);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy>
      thenByAutoStartWithWindowsDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'autoStartWithWindows', Sort.desc);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy> thenByBaseDir() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'baseDir', Sort.asc);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy> thenByBaseDirDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'baseDir', Sort.desc);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy> thenByIsSslInstalled() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isSslInstalled', Sort.asc);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy>
      thenByIsSslInstalledDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isSslInstalled', Sort.desc);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy> thenByMinimizeToTray() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'minimizeToTray', Sort.asc);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy>
      thenByMinimizeToTrayDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'minimizeToTray', Sort.desc);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy> thenBySiteTemplate() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'siteTemplate', Sort.asc);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy>
      thenBySiteTemplateDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'siteTemplate', Sort.desc);
    });
  }
}

extension AppSettingsQueryWhereDistinct
    on QueryBuilder<AppSettings, AppSettings, QDistinct> {
  QueryBuilder<AppSettings, AppSettings, QDistinct> distinctByAllowLanAccess() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'allowLanAccess');
    });
  }

  QueryBuilder<AppSettings, AppSettings, QDistinct> distinctByAutoCreateSite() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'autoCreateSite');
    });
  }

  QueryBuilder<AppSettings, AppSettings, QDistinct>
      distinctByAutoStartWithWindows() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'autoStartWithWindows');
    });
  }

  QueryBuilder<AppSettings, AppSettings, QDistinct> distinctByBaseDir(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'baseDir', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QDistinct> distinctByIsSslInstalled() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'isSslInstalled');
    });
  }

  QueryBuilder<AppSettings, AppSettings, QDistinct> distinctByMinimizeToTray() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'minimizeToTray');
    });
  }

  QueryBuilder<AppSettings, AppSettings, QDistinct> distinctBySiteTemplate(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'siteTemplate', caseSensitive: caseSensitive);
    });
  }
}

extension AppSettingsQueryProperty
    on QueryBuilder<AppSettings, AppSettings, QQueryProperty> {
  QueryBuilder<AppSettings, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<AppSettings, bool, QQueryOperations> allowLanAccessProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'allowLanAccess');
    });
  }

  QueryBuilder<AppSettings, bool, QQueryOperations> autoCreateSiteProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'autoCreateSite');
    });
  }

  QueryBuilder<AppSettings, bool, QQueryOperations>
      autoStartWithWindowsProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'autoStartWithWindows');
    });
  }

  QueryBuilder<AppSettings, String, QQueryOperations> baseDirProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'baseDir');
    });
  }

  QueryBuilder<AppSettings, bool, QQueryOperations> isSslInstalledProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'isSslInstalled');
    });
  }

  QueryBuilder<AppSettings, bool, QQueryOperations> minimizeToTrayProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'minimizeToTray');
    });
  }

  QueryBuilder<AppSettings, String, QQueryOperations> siteTemplateProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'siteTemplate');
    });
  }
}
