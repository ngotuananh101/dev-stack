// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_settings.dart';

// **************************************************************************
// _IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, invalid_use_of_protected_member, lines_longer_than_80_chars, constant_identifier_names, avoid_js_rounded_ints, no_leading_underscores_for_local_identifiers, require_trailing_commas, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_in_if_null_operators, library_private_types_in_public_api, prefer_const_constructors
// ignore_for_file: type=lint

extension GetAppSettingsCollection on Isar {
  IsarCollection<int, AppSettings> get appSettings => this.collection();
}

final AppSettingsSchema = IsarGeneratedSchema(
  schema: IsarSchema(
    name: 'AppSettings',
    idName: 'id',
    embedded: false,
    properties: [
      IsarPropertySchema(name: 'baseDir', type: IsarType.string),
      IsarPropertySchema(name: 'siteTemplate', type: IsarType.string),
      IsarPropertySchema(name: 'autoCreateSite', type: IsarType.bool),
      IsarPropertySchema(name: 'minimizeToTray', type: IsarType.bool),
      IsarPropertySchema(name: 'autoStartWithWindows', type: IsarType.bool),
      IsarPropertySchema(name: 'isSslInstalled', type: IsarType.bool),
      IsarPropertySchema(name: 'allowLanAccess', type: IsarType.bool),
      IsarPropertySchema(name: 'ngrokDefaultToken', type: IsarType.string),
      IsarPropertySchema(name: 'cloudflareDefaultToken', type: IsarType.string),
    ],
    indexes: [],
  ),
  converter: IsarObjectConverter<int, AppSettings>(
    serialize: serializeAppSettings,
    deserialize: deserializeAppSettings,
    deserializeProperty: deserializeAppSettingsProp,
  ),
  getEmbeddedSchemas: () => [],
);

@isarProtected
int serializeAppSettings(IsarWriter writer, AppSettings object) {
  IsarCore.writeString(writer, 1, object.baseDir);
  IsarCore.writeString(writer, 2, object.siteTemplate);
  IsarCore.writeBool(writer, 3, value: object.autoCreateSite);
  IsarCore.writeBool(writer, 4, value: object.minimizeToTray);
  IsarCore.writeBool(writer, 5, value: object.autoStartWithWindows);
  IsarCore.writeBool(writer, 6, value: object.isSslInstalled);
  IsarCore.writeBool(writer, 7, value: object.allowLanAccess);
  {
    final value = object.ngrokDefaultToken;
    if (value == null) {
      IsarCore.writeNull(writer, 8);
    } else {
      IsarCore.writeString(writer, 8, value);
    }
  }
  {
    final value = object.cloudflareDefaultToken;
    if (value == null) {
      IsarCore.writeNull(writer, 9);
    } else {
      IsarCore.writeString(writer, 9, value);
    }
  }
  return object.id;
}

@isarProtected
AppSettings deserializeAppSettings(IsarReader reader) {
  final object = AppSettings();
  object.id = IsarCore.readId(reader);
  object.baseDir = IsarCore.readString(reader, 1) ?? '';
  object.siteTemplate = IsarCore.readString(reader, 2) ?? '';
  object.autoCreateSite = IsarCore.readBool(reader, 3);
  object.minimizeToTray = IsarCore.readBool(reader, 4);
  object.autoStartWithWindows = IsarCore.readBool(reader, 5);
  object.isSslInstalled = IsarCore.readBool(reader, 6);
  object.allowLanAccess = IsarCore.readBool(reader, 7);
  object.ngrokDefaultToken = IsarCore.readString(reader, 8);
  object.cloudflareDefaultToken = IsarCore.readString(reader, 9);
  return object;
}

@isarProtected
dynamic deserializeAppSettingsProp(IsarReader reader, int property) {
  switch (property) {
    case 0:
      return IsarCore.readId(reader);
    case 1:
      return IsarCore.readString(reader, 1) ?? '';
    case 2:
      return IsarCore.readString(reader, 2) ?? '';
    case 3:
      return IsarCore.readBool(reader, 3);
    case 4:
      return IsarCore.readBool(reader, 4);
    case 5:
      return IsarCore.readBool(reader, 5);
    case 6:
      return IsarCore.readBool(reader, 6);
    case 7:
      return IsarCore.readBool(reader, 7);
    case 8:
      return IsarCore.readString(reader, 8);
    case 9:
      return IsarCore.readString(reader, 9);
    default:
      throw ArgumentError('Unknown property: $property');
  }
}

sealed class _AppSettingsUpdate {
  bool call({
    required int id,
    String? baseDir,
    String? siteTemplate,
    bool? autoCreateSite,
    bool? minimizeToTray,
    bool? autoStartWithWindows,
    bool? isSslInstalled,
    bool? allowLanAccess,
    String? ngrokDefaultToken,
    String? cloudflareDefaultToken,
  });
}

class _AppSettingsUpdateImpl implements _AppSettingsUpdate {
  const _AppSettingsUpdateImpl(this.collection);

  final IsarCollection<int, AppSettings> collection;

  @override
  bool call({
    required int id,
    Object? baseDir = ignore,
    Object? siteTemplate = ignore,
    Object? autoCreateSite = ignore,
    Object? minimizeToTray = ignore,
    Object? autoStartWithWindows = ignore,
    Object? isSslInstalled = ignore,
    Object? allowLanAccess = ignore,
    Object? ngrokDefaultToken = ignore,
    Object? cloudflareDefaultToken = ignore,
  }) {
    return collection.updateProperties(
          [id],
          {
            if (baseDir != ignore) 1: baseDir as String?,
            if (siteTemplate != ignore) 2: siteTemplate as String?,
            if (autoCreateSite != ignore) 3: autoCreateSite as bool?,
            if (minimizeToTray != ignore) 4: minimizeToTray as bool?,
            if (autoStartWithWindows != ignore)
              5: autoStartWithWindows as bool?,
            if (isSslInstalled != ignore) 6: isSslInstalled as bool?,
            if (allowLanAccess != ignore) 7: allowLanAccess as bool?,
            if (ngrokDefaultToken != ignore) 8: ngrokDefaultToken as String?,
            if (cloudflareDefaultToken != ignore)
              9: cloudflareDefaultToken as String?,
          },
        ) >
        0;
  }
}

sealed class _AppSettingsUpdateAll {
  int call({
    required List<int> id,
    String? baseDir,
    String? siteTemplate,
    bool? autoCreateSite,
    bool? minimizeToTray,
    bool? autoStartWithWindows,
    bool? isSslInstalled,
    bool? allowLanAccess,
    String? ngrokDefaultToken,
    String? cloudflareDefaultToken,
  });
}

class _AppSettingsUpdateAllImpl implements _AppSettingsUpdateAll {
  const _AppSettingsUpdateAllImpl(this.collection);

  final IsarCollection<int, AppSettings> collection;

  @override
  int call({
    required List<int> id,
    Object? baseDir = ignore,
    Object? siteTemplate = ignore,
    Object? autoCreateSite = ignore,
    Object? minimizeToTray = ignore,
    Object? autoStartWithWindows = ignore,
    Object? isSslInstalled = ignore,
    Object? allowLanAccess = ignore,
    Object? ngrokDefaultToken = ignore,
    Object? cloudflareDefaultToken = ignore,
  }) {
    return collection.updateProperties(id, {
      if (baseDir != ignore) 1: baseDir as String?,
      if (siteTemplate != ignore) 2: siteTemplate as String?,
      if (autoCreateSite != ignore) 3: autoCreateSite as bool?,
      if (minimizeToTray != ignore) 4: minimizeToTray as bool?,
      if (autoStartWithWindows != ignore) 5: autoStartWithWindows as bool?,
      if (isSslInstalled != ignore) 6: isSslInstalled as bool?,
      if (allowLanAccess != ignore) 7: allowLanAccess as bool?,
      if (ngrokDefaultToken != ignore) 8: ngrokDefaultToken as String?,
      if (cloudflareDefaultToken != ignore)
        9: cloudflareDefaultToken as String?,
    });
  }
}

extension AppSettingsUpdate on IsarCollection<int, AppSettings> {
  _AppSettingsUpdate get update => _AppSettingsUpdateImpl(this);

  _AppSettingsUpdateAll get updateAll => _AppSettingsUpdateAllImpl(this);
}

sealed class _AppSettingsQueryUpdate {
  int call({
    String? baseDir,
    String? siteTemplate,
    bool? autoCreateSite,
    bool? minimizeToTray,
    bool? autoStartWithWindows,
    bool? isSslInstalled,
    bool? allowLanAccess,
    String? ngrokDefaultToken,
    String? cloudflareDefaultToken,
  });
}

class _AppSettingsQueryUpdateImpl implements _AppSettingsQueryUpdate {
  const _AppSettingsQueryUpdateImpl(this.query, {this.limit});

  final IsarQuery<AppSettings> query;
  final int? limit;

  @override
  int call({
    Object? baseDir = ignore,
    Object? siteTemplate = ignore,
    Object? autoCreateSite = ignore,
    Object? minimizeToTray = ignore,
    Object? autoStartWithWindows = ignore,
    Object? isSslInstalled = ignore,
    Object? allowLanAccess = ignore,
    Object? ngrokDefaultToken = ignore,
    Object? cloudflareDefaultToken = ignore,
  }) {
    return query.updateProperties(limit: limit, {
      if (baseDir != ignore) 1: baseDir as String?,
      if (siteTemplate != ignore) 2: siteTemplate as String?,
      if (autoCreateSite != ignore) 3: autoCreateSite as bool?,
      if (minimizeToTray != ignore) 4: minimizeToTray as bool?,
      if (autoStartWithWindows != ignore) 5: autoStartWithWindows as bool?,
      if (isSslInstalled != ignore) 6: isSslInstalled as bool?,
      if (allowLanAccess != ignore) 7: allowLanAccess as bool?,
      if (ngrokDefaultToken != ignore) 8: ngrokDefaultToken as String?,
      if (cloudflareDefaultToken != ignore)
        9: cloudflareDefaultToken as String?,
    });
  }
}

extension AppSettingsQueryUpdate on IsarQuery<AppSettings> {
  _AppSettingsQueryUpdate get updateFirst =>
      _AppSettingsQueryUpdateImpl(this, limit: 1);

  _AppSettingsQueryUpdate get updateAll => _AppSettingsQueryUpdateImpl(this);
}

class _AppSettingsQueryBuilderUpdateImpl implements _AppSettingsQueryUpdate {
  const _AppSettingsQueryBuilderUpdateImpl(this.query, {this.limit});

  final QueryBuilder<AppSettings, AppSettings, QOperations> query;
  final int? limit;

  @override
  int call({
    Object? baseDir = ignore,
    Object? siteTemplate = ignore,
    Object? autoCreateSite = ignore,
    Object? minimizeToTray = ignore,
    Object? autoStartWithWindows = ignore,
    Object? isSslInstalled = ignore,
    Object? allowLanAccess = ignore,
    Object? ngrokDefaultToken = ignore,
    Object? cloudflareDefaultToken = ignore,
  }) {
    final q = query.build();
    try {
      return q.updateProperties(limit: limit, {
        if (baseDir != ignore) 1: baseDir as String?,
        if (siteTemplate != ignore) 2: siteTemplate as String?,
        if (autoCreateSite != ignore) 3: autoCreateSite as bool?,
        if (minimizeToTray != ignore) 4: minimizeToTray as bool?,
        if (autoStartWithWindows != ignore) 5: autoStartWithWindows as bool?,
        if (isSslInstalled != ignore) 6: isSslInstalled as bool?,
        if (allowLanAccess != ignore) 7: allowLanAccess as bool?,
        if (ngrokDefaultToken != ignore) 8: ngrokDefaultToken as String?,
        if (cloudflareDefaultToken != ignore)
          9: cloudflareDefaultToken as String?,
      });
    } finally {
      q.close();
    }
  }
}

extension AppSettingsQueryBuilderUpdate
    on QueryBuilder<AppSettings, AppSettings, QOperations> {
  _AppSettingsQueryUpdate get updateFirst =>
      _AppSettingsQueryBuilderUpdateImpl(this, limit: 1);

  _AppSettingsQueryUpdate get updateAll =>
      _AppSettingsQueryBuilderUpdateImpl(this);
}

extension AppSettingsQueryFilter
    on QueryBuilder<AppSettings, AppSettings, QFilterCondition> {
  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition> idEqualTo(
    int value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(property: 0, value: value),
      );
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition> idGreaterThan(
    int value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterCondition(property: 0, value: value),
      );
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
  idGreaterThanOrEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterOrEqualCondition(property: 0, value: value),
      );
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition> idLessThan(
    int value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(LessCondition(property: 0, value: value));
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
  idLessThanOrEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessOrEqualCondition(property: 0, value: value),
      );
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition> idBetween(
    int lower,
    int upper,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        BetweenCondition(property: 0, lower: lower, upper: upper),
      );
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition> baseDirEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(property: 1, value: value, caseSensitive: caseSensitive),
      );
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
  baseDirGreaterThan(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
  baseDirGreaterThanOrEqualTo(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition> baseDirLessThan(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessCondition(property: 1, value: value, caseSensitive: caseSensitive),
      );
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
  baseDirLessThanOrEqualTo(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition> baseDirBetween(
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

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
  baseDirStartsWith(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition> baseDirEndsWith(
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

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition> baseDirContains(
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

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition> baseDirMatches(
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

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
  baseDirIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const EqualCondition(property: 1, value: ''),
      );
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
  baseDirIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const GreaterCondition(property: 1, value: ''),
      );
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
  siteTemplateEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(property: 2, value: value, caseSensitive: caseSensitive),
      );
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
  siteTemplateGreaterThan(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
  siteTemplateGreaterThanOrEqualTo(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
  siteTemplateLessThan(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessCondition(property: 2, value: value, caseSensitive: caseSensitive),
      );
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
  siteTemplateLessThanOrEqualTo(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
  siteTemplateBetween(String lower, String upper, {bool caseSensitive = true}) {
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

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
  siteTemplateStartsWith(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
  siteTemplateEndsWith(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
  siteTemplateContains(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
  siteTemplateMatches(String pattern, {bool caseSensitive = true}) {
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

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
  siteTemplateIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const EqualCondition(property: 2, value: ''),
      );
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
  siteTemplateIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const GreaterCondition(property: 2, value: ''),
      );
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
  autoCreateSiteEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(property: 3, value: value),
      );
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
  minimizeToTrayEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(property: 4, value: value),
      );
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
  autoStartWithWindowsEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(property: 5, value: value),
      );
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
  isSslInstalledEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(property: 6, value: value),
      );
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
  allowLanAccessEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(property: 7, value: value),
      );
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
  ngrokDefaultTokenIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const IsNullCondition(property: 8));
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
  ngrokDefaultTokenIsNotNull() {
    return QueryBuilder.apply(not(), (query) {
      return query.addFilterCondition(const IsNullCondition(property: 8));
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
  ngrokDefaultTokenEqualTo(String? value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(property: 8, value: value, caseSensitive: caseSensitive),
      );
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
  ngrokDefaultTokenGreaterThan(String? value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterCondition(
          property: 8,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
  ngrokDefaultTokenGreaterThanOrEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterOrEqualCondition(
          property: 8,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
  ngrokDefaultTokenLessThan(String? value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessCondition(property: 8, value: value, caseSensitive: caseSensitive),
      );
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
  ngrokDefaultTokenLessThanOrEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessOrEqualCondition(
          property: 8,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
  ngrokDefaultTokenBetween(
    String? lower,
    String? upper, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        BetweenCondition(
          property: 8,
          lower: lower,
          upper: upper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
  ngrokDefaultTokenStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        StartsWithCondition(
          property: 8,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
  ngrokDefaultTokenEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EndsWithCondition(
          property: 8,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
  ngrokDefaultTokenContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        ContainsCondition(
          property: 8,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
  ngrokDefaultTokenMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        MatchesCondition(
          property: 8,
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
  ngrokDefaultTokenIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const EqualCondition(property: 8, value: ''),
      );
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
  ngrokDefaultTokenIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const GreaterCondition(property: 8, value: ''),
      );
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
  cloudflareDefaultTokenIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const IsNullCondition(property: 9));
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
  cloudflareDefaultTokenIsNotNull() {
    return QueryBuilder.apply(not(), (query) {
      return query.addFilterCondition(const IsNullCondition(property: 9));
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
  cloudflareDefaultTokenEqualTo(String? value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(property: 9, value: value, caseSensitive: caseSensitive),
      );
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
  cloudflareDefaultTokenGreaterThan(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterCondition(
          property: 9,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
  cloudflareDefaultTokenGreaterThanOrEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterOrEqualCondition(
          property: 9,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
  cloudflareDefaultTokenLessThan(String? value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessCondition(property: 9, value: value, caseSensitive: caseSensitive),
      );
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
  cloudflareDefaultTokenLessThanOrEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessOrEqualCondition(
          property: 9,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
  cloudflareDefaultTokenBetween(
    String? lower,
    String? upper, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        BetweenCondition(
          property: 9,
          lower: lower,
          upper: upper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
  cloudflareDefaultTokenStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        StartsWithCondition(
          property: 9,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
  cloudflareDefaultTokenEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EndsWithCondition(
          property: 9,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
  cloudflareDefaultTokenContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        ContainsCondition(
          property: 9,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
  cloudflareDefaultTokenMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        MatchesCondition(
          property: 9,
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
  cloudflareDefaultTokenIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const EqualCondition(property: 9, value: ''),
      );
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
  cloudflareDefaultTokenIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const GreaterCondition(property: 9, value: ''),
      );
    });
  }
}

extension AppSettingsQueryObject
    on QueryBuilder<AppSettings, AppSettings, QFilterCondition> {}

extension AppSettingsQuerySortBy
    on QueryBuilder<AppSettings, AppSettings, QSortBy> {
  QueryBuilder<AppSettings, AppSettings, QAfterSortBy> sortById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(0);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy> sortByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(0, sort: Sort.desc);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy> sortByBaseDir({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(1, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy> sortByBaseDirDesc({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(1, sort: Sort.desc, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy> sortBySiteTemplate({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(2, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy> sortBySiteTemplateDesc({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(2, sort: Sort.desc, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy> sortByAutoCreateSite() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(3);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy>
  sortByAutoCreateSiteDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(3, sort: Sort.desc);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy> sortByMinimizeToTray() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(4);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy>
  sortByMinimizeToTrayDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(4, sort: Sort.desc);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy>
  sortByAutoStartWithWindows() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(5);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy>
  sortByAutoStartWithWindowsDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(5, sort: Sort.desc);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy> sortByIsSslInstalled() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(6);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy>
  sortByIsSslInstalledDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(6, sort: Sort.desc);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy> sortByAllowLanAccess() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(7);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy>
  sortByAllowLanAccessDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(7, sort: Sort.desc);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy> sortByNgrokDefaultToken({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(8, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy>
  sortByNgrokDefaultTokenDesc({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(8, sort: Sort.desc, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy>
  sortByCloudflareDefaultToken({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(9, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy>
  sortByCloudflareDefaultTokenDesc({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(9, sort: Sort.desc, caseSensitive: caseSensitive);
    });
  }
}

extension AppSettingsQuerySortThenBy
    on QueryBuilder<AppSettings, AppSettings, QSortThenBy> {
  QueryBuilder<AppSettings, AppSettings, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(0);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(0, sort: Sort.desc);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy> thenByBaseDir({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(1, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy> thenByBaseDirDesc({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(1, sort: Sort.desc, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy> thenBySiteTemplate({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(2, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy> thenBySiteTemplateDesc({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(2, sort: Sort.desc, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy> thenByAutoCreateSite() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(3);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy>
  thenByAutoCreateSiteDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(3, sort: Sort.desc);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy> thenByMinimizeToTray() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(4);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy>
  thenByMinimizeToTrayDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(4, sort: Sort.desc);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy>
  thenByAutoStartWithWindows() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(5);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy>
  thenByAutoStartWithWindowsDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(5, sort: Sort.desc);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy> thenByIsSslInstalled() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(6);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy>
  thenByIsSslInstalledDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(6, sort: Sort.desc);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy> thenByAllowLanAccess() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(7);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy>
  thenByAllowLanAccessDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(7, sort: Sort.desc);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy> thenByNgrokDefaultToken({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(8, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy>
  thenByNgrokDefaultTokenDesc({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(8, sort: Sort.desc, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy>
  thenByCloudflareDefaultToken({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(9, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy>
  thenByCloudflareDefaultTokenDesc({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(9, sort: Sort.desc, caseSensitive: caseSensitive);
    });
  }
}

extension AppSettingsQueryWhereDistinct
    on QueryBuilder<AppSettings, AppSettings, QDistinct> {
  QueryBuilder<AppSettings, AppSettings, QAfterDistinct> distinctByBaseDir({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(1, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterDistinct>
  distinctBySiteTemplate({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(2, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterDistinct>
  distinctByAutoCreateSite() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(3);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterDistinct>
  distinctByMinimizeToTray() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(4);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterDistinct>
  distinctByAutoStartWithWindows() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(5);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterDistinct>
  distinctByIsSslInstalled() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(6);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterDistinct>
  distinctByAllowLanAccess() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(7);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterDistinct>
  distinctByNgrokDefaultToken({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(8, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterDistinct>
  distinctByCloudflareDefaultToken({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(9, caseSensitive: caseSensitive);
    });
  }
}

extension AppSettingsQueryProperty1
    on QueryBuilder<AppSettings, AppSettings, QProperty> {
  QueryBuilder<AppSettings, int, QAfterProperty> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(0);
    });
  }

  QueryBuilder<AppSettings, String, QAfterProperty> baseDirProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(1);
    });
  }

  QueryBuilder<AppSettings, String, QAfterProperty> siteTemplateProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(2);
    });
  }

  QueryBuilder<AppSettings, bool, QAfterProperty> autoCreateSiteProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(3);
    });
  }

  QueryBuilder<AppSettings, bool, QAfterProperty> minimizeToTrayProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(4);
    });
  }

  QueryBuilder<AppSettings, bool, QAfterProperty>
  autoStartWithWindowsProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(5);
    });
  }

  QueryBuilder<AppSettings, bool, QAfterProperty> isSslInstalledProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(6);
    });
  }

  QueryBuilder<AppSettings, bool, QAfterProperty> allowLanAccessProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(7);
    });
  }

  QueryBuilder<AppSettings, String?, QAfterProperty>
  ngrokDefaultTokenProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(8);
    });
  }

  QueryBuilder<AppSettings, String?, QAfterProperty>
  cloudflareDefaultTokenProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(9);
    });
  }
}

extension AppSettingsQueryProperty2<R>
    on QueryBuilder<AppSettings, R, QAfterProperty> {
  QueryBuilder<AppSettings, (R, int), QAfterProperty> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(0);
    });
  }

  QueryBuilder<AppSettings, (R, String), QAfterProperty> baseDirProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(1);
    });
  }

  QueryBuilder<AppSettings, (R, String), QAfterProperty>
  siteTemplateProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(2);
    });
  }

  QueryBuilder<AppSettings, (R, bool), QAfterProperty>
  autoCreateSiteProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(3);
    });
  }

  QueryBuilder<AppSettings, (R, bool), QAfterProperty>
  minimizeToTrayProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(4);
    });
  }

  QueryBuilder<AppSettings, (R, bool), QAfterProperty>
  autoStartWithWindowsProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(5);
    });
  }

  QueryBuilder<AppSettings, (R, bool), QAfterProperty>
  isSslInstalledProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(6);
    });
  }

  QueryBuilder<AppSettings, (R, bool), QAfterProperty>
  allowLanAccessProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(7);
    });
  }

  QueryBuilder<AppSettings, (R, String?), QAfterProperty>
  ngrokDefaultTokenProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(8);
    });
  }

  QueryBuilder<AppSettings, (R, String?), QAfterProperty>
  cloudflareDefaultTokenProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(9);
    });
  }
}

extension AppSettingsQueryProperty3<R1, R2>
    on QueryBuilder<AppSettings, (R1, R2), QAfterProperty> {
  QueryBuilder<AppSettings, (R1, R2, int), QOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(0);
    });
  }

  QueryBuilder<AppSettings, (R1, R2, String), QOperations> baseDirProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(1);
    });
  }

  QueryBuilder<AppSettings, (R1, R2, String), QOperations>
  siteTemplateProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(2);
    });
  }

  QueryBuilder<AppSettings, (R1, R2, bool), QOperations>
  autoCreateSiteProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(3);
    });
  }

  QueryBuilder<AppSettings, (R1, R2, bool), QOperations>
  minimizeToTrayProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(4);
    });
  }

  QueryBuilder<AppSettings, (R1, R2, bool), QOperations>
  autoStartWithWindowsProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(5);
    });
  }

  QueryBuilder<AppSettings, (R1, R2, bool), QOperations>
  isSslInstalledProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(6);
    });
  }

  QueryBuilder<AppSettings, (R1, R2, bool), QOperations>
  allowLanAccessProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(7);
    });
  }

  QueryBuilder<AppSettings, (R1, R2, String?), QOperations>
  ngrokDefaultTokenProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(8);
    });
  }

  QueryBuilder<AppSettings, (R1, R2, String?), QOperations>
  cloudflareDefaultTokenProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(9);
    });
  }
}
