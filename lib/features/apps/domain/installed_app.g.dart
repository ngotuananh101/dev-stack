// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'installed_app.dart';

// **************************************************************************
// _IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, invalid_use_of_protected_member, lines_longer_than_80_chars, constant_identifier_names, avoid_js_rounded_ints, no_leading_underscores_for_local_identifiers, require_trailing_commas, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_in_if_null_operators, library_private_types_in_public_api, prefer_const_constructors
// ignore_for_file: type=lint

extension GetInstalledAppCollection on Isar {
  IsarCollection<int, InstalledApp> get installedApps => this.collection();
}

final InstalledAppSchema = IsarGeneratedSchema(
  schema: IsarSchema(
    name: 'InstalledApp',
    idName: 'id',
    embedded: false,
    properties: [
      IsarPropertySchema(name: 'appId', type: IsarType.string),
      IsarPropertySchema(name: 'appName', type: IsarType.string),
      IsarPropertySchema(name: 'location', type: IsarType.string),
      IsarPropertySchema(name: 'status', type: IsarType.string),
      IsarPropertySchema(name: 'version', type: IsarType.string),
      IsarPropertySchema(name: 'installedAt', type: IsarType.dateTime),
      IsarPropertySchema(name: 'execFilePath', type: IsarType.string),
      IsarPropertySchema(name: 'cliFilePath', type: IsarType.string),
      IsarPropertySchema(name: 'addedToPath', type: IsarType.bool),
      IsarPropertySchema(name: 'autoStartService', type: IsarType.bool),
      IsarPropertySchema(name: 'groupName', type: IsarType.string),
      IsarPropertySchema(name: 'isDefault', type: IsarType.bool),
      IsarPropertySchema(name: 'extraInfoJson', type: IsarType.string),
    ],
    indexes: [
      IsarIndexSchema(
        name: 'appId',
        properties: ["appId"],
        unique: true,
        hash: false,
      ),
      IsarIndexSchema(
        name: 'addedToPath',
        properties: ["addedToPath"],
        unique: false,
        hash: false,
      ),
      IsarIndexSchema(
        name: 'groupName',
        properties: ["groupName"],
        unique: false,
        hash: false,
      ),
    ],
  ),
  converter: IsarObjectConverter<int, InstalledApp>(
    serialize: serializeInstalledApp,
    deserialize: deserializeInstalledApp,
    deserializeProperty: deserializeInstalledAppProp,
  ),
  getEmbeddedSchemas: () => [],
);

@isarProtected
int serializeInstalledApp(IsarWriter writer, InstalledApp object) {
  IsarCore.writeString(writer, 1, object.appId);
  IsarCore.writeString(writer, 2, object.appName);
  IsarCore.writeString(writer, 3, object.location);
  IsarCore.writeString(writer, 4, object.status);
  {
    final value = object.version;
    if (value == null) {
      IsarCore.writeNull(writer, 5);
    } else {
      IsarCore.writeString(writer, 5, value);
    }
  }
  IsarCore.writeLong(
    writer,
    6,
    object.installedAt?.toUtc().microsecondsSinceEpoch ?? -9223372036854775808,
  );
  {
    final value = object.execFilePath;
    if (value == null) {
      IsarCore.writeNull(writer, 7);
    } else {
      IsarCore.writeString(writer, 7, value);
    }
  }
  {
    final value = object.cliFilePath;
    if (value == null) {
      IsarCore.writeNull(writer, 8);
    } else {
      IsarCore.writeString(writer, 8, value);
    }
  }
  IsarCore.writeBool(writer, 9, value: object.addedToPath);
  IsarCore.writeBool(writer, 10, value: object.autoStartService);
  {
    final value = object.groupName;
    if (value == null) {
      IsarCore.writeNull(writer, 11);
    } else {
      IsarCore.writeString(writer, 11, value);
    }
  }
  IsarCore.writeBool(writer, 12, value: object.isDefault);
  {
    final value = object.extraInfoJson;
    if (value == null) {
      IsarCore.writeNull(writer, 13);
    } else {
      IsarCore.writeString(writer, 13, value);
    }
  }
  return object.id;
}

@isarProtected
InstalledApp deserializeInstalledApp(IsarReader reader) {
  final String _appId;
  _appId = IsarCore.readString(reader, 1) ?? '';
  final String _appName;
  _appName = IsarCore.readString(reader, 2) ?? '';
  final String _location;
  _location = IsarCore.readString(reader, 3) ?? '';
  final String _status;
  _status = IsarCore.readString(reader, 4) ?? '';
  final String? _version;
  _version = IsarCore.readString(reader, 5);
  final DateTime? _installedAt;
  {
    final value = IsarCore.readLong(reader, 6);
    if (value == -9223372036854775808) {
      _installedAt = null;
    } else {
      _installedAt = DateTime.fromMicrosecondsSinceEpoch(
        value,
        isUtc: true,
      ).toLocal();
    }
  }
  final String? _execFilePath;
  _execFilePath = IsarCore.readString(reader, 7);
  final String? _cliFilePath;
  _cliFilePath = IsarCore.readString(reader, 8);
  final bool _addedToPath;
  _addedToPath = IsarCore.readBool(reader, 9);
  final bool _autoStartService;
  _autoStartService = IsarCore.readBool(reader, 10);
  final String? _groupName;
  _groupName = IsarCore.readString(reader, 11);
  final bool _isDefault;
  _isDefault = IsarCore.readBool(reader, 12);
  final String? _extraInfoJson;
  _extraInfoJson = IsarCore.readString(reader, 13);
  final object = InstalledApp(
    appId: _appId,
    appName: _appName,
    location: _location,
    status: _status,
    version: _version,
    installedAt: _installedAt,
    execFilePath: _execFilePath,
    cliFilePath: _cliFilePath,
    addedToPath: _addedToPath,
    autoStartService: _autoStartService,
    groupName: _groupName,
    isDefault: _isDefault,
    extraInfoJson: _extraInfoJson,
  );
  object.id = IsarCore.readId(reader);
  return object;
}

@isarProtected
dynamic deserializeInstalledAppProp(IsarReader reader, int property) {
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
      return IsarCore.readString(reader, 8);
    case 9:
      return IsarCore.readBool(reader, 9);
    case 10:
      return IsarCore.readBool(reader, 10);
    case 11:
      return IsarCore.readString(reader, 11);
    case 12:
      return IsarCore.readBool(reader, 12);
    case 13:
      return IsarCore.readString(reader, 13);
    default:
      throw ArgumentError('Unknown property: $property');
  }
}

sealed class _InstalledAppUpdate {
  bool call({
    required int id,
    String? appId,
    String? appName,
    String? location,
    String? status,
    String? version,
    DateTime? installedAt,
    String? execFilePath,
    String? cliFilePath,
    bool? addedToPath,
    bool? autoStartService,
    String? groupName,
    bool? isDefault,
    String? extraInfoJson,
  });
}

class _InstalledAppUpdateImpl implements _InstalledAppUpdate {
  const _InstalledAppUpdateImpl(this.collection);

  final IsarCollection<int, InstalledApp> collection;

  @override
  bool call({
    required int id,
    Object? appId = ignore,
    Object? appName = ignore,
    Object? location = ignore,
    Object? status = ignore,
    Object? version = ignore,
    Object? installedAt = ignore,
    Object? execFilePath = ignore,
    Object? cliFilePath = ignore,
    Object? addedToPath = ignore,
    Object? autoStartService = ignore,
    Object? groupName = ignore,
    Object? isDefault = ignore,
    Object? extraInfoJson = ignore,
  }) {
    return collection.updateProperties(
          [id],
          {
            if (appId != ignore) 1: appId as String?,
            if (appName != ignore) 2: appName as String?,
            if (location != ignore) 3: location as String?,
            if (status != ignore) 4: status as String?,
            if (version != ignore) 5: version as String?,
            if (installedAt != ignore) 6: installedAt as DateTime?,
            if (execFilePath != ignore) 7: execFilePath as String?,
            if (cliFilePath != ignore) 8: cliFilePath as String?,
            if (addedToPath != ignore) 9: addedToPath as bool?,
            if (autoStartService != ignore) 10: autoStartService as bool?,
            if (groupName != ignore) 11: groupName as String?,
            if (isDefault != ignore) 12: isDefault as bool?,
            if (extraInfoJson != ignore) 13: extraInfoJson as String?,
          },
        ) >
        0;
  }
}

sealed class _InstalledAppUpdateAll {
  int call({
    required List<int> id,
    String? appId,
    String? appName,
    String? location,
    String? status,
    String? version,
    DateTime? installedAt,
    String? execFilePath,
    String? cliFilePath,
    bool? addedToPath,
    bool? autoStartService,
    String? groupName,
    bool? isDefault,
    String? extraInfoJson,
  });
}

class _InstalledAppUpdateAllImpl implements _InstalledAppUpdateAll {
  const _InstalledAppUpdateAllImpl(this.collection);

  final IsarCollection<int, InstalledApp> collection;

  @override
  int call({
    required List<int> id,
    Object? appId = ignore,
    Object? appName = ignore,
    Object? location = ignore,
    Object? status = ignore,
    Object? version = ignore,
    Object? installedAt = ignore,
    Object? execFilePath = ignore,
    Object? cliFilePath = ignore,
    Object? addedToPath = ignore,
    Object? autoStartService = ignore,
    Object? groupName = ignore,
    Object? isDefault = ignore,
    Object? extraInfoJson = ignore,
  }) {
    return collection.updateProperties(id, {
      if (appId != ignore) 1: appId as String?,
      if (appName != ignore) 2: appName as String?,
      if (location != ignore) 3: location as String?,
      if (status != ignore) 4: status as String?,
      if (version != ignore) 5: version as String?,
      if (installedAt != ignore) 6: installedAt as DateTime?,
      if (execFilePath != ignore) 7: execFilePath as String?,
      if (cliFilePath != ignore) 8: cliFilePath as String?,
      if (addedToPath != ignore) 9: addedToPath as bool?,
      if (autoStartService != ignore) 10: autoStartService as bool?,
      if (groupName != ignore) 11: groupName as String?,
      if (isDefault != ignore) 12: isDefault as bool?,
      if (extraInfoJson != ignore) 13: extraInfoJson as String?,
    });
  }
}

extension InstalledAppUpdate on IsarCollection<int, InstalledApp> {
  _InstalledAppUpdate get update => _InstalledAppUpdateImpl(this);

  _InstalledAppUpdateAll get updateAll => _InstalledAppUpdateAllImpl(this);
}

sealed class _InstalledAppQueryUpdate {
  int call({
    String? appId,
    String? appName,
    String? location,
    String? status,
    String? version,
    DateTime? installedAt,
    String? execFilePath,
    String? cliFilePath,
    bool? addedToPath,
    bool? autoStartService,
    String? groupName,
    bool? isDefault,
    String? extraInfoJson,
  });
}

class _InstalledAppQueryUpdateImpl implements _InstalledAppQueryUpdate {
  const _InstalledAppQueryUpdateImpl(this.query, {this.limit});

  final IsarQuery<InstalledApp> query;
  final int? limit;

  @override
  int call({
    Object? appId = ignore,
    Object? appName = ignore,
    Object? location = ignore,
    Object? status = ignore,
    Object? version = ignore,
    Object? installedAt = ignore,
    Object? execFilePath = ignore,
    Object? cliFilePath = ignore,
    Object? addedToPath = ignore,
    Object? autoStartService = ignore,
    Object? groupName = ignore,
    Object? isDefault = ignore,
    Object? extraInfoJson = ignore,
  }) {
    return query.updateProperties(limit: limit, {
      if (appId != ignore) 1: appId as String?,
      if (appName != ignore) 2: appName as String?,
      if (location != ignore) 3: location as String?,
      if (status != ignore) 4: status as String?,
      if (version != ignore) 5: version as String?,
      if (installedAt != ignore) 6: installedAt as DateTime?,
      if (execFilePath != ignore) 7: execFilePath as String?,
      if (cliFilePath != ignore) 8: cliFilePath as String?,
      if (addedToPath != ignore) 9: addedToPath as bool?,
      if (autoStartService != ignore) 10: autoStartService as bool?,
      if (groupName != ignore) 11: groupName as String?,
      if (isDefault != ignore) 12: isDefault as bool?,
      if (extraInfoJson != ignore) 13: extraInfoJson as String?,
    });
  }
}

extension InstalledAppQueryUpdate on IsarQuery<InstalledApp> {
  _InstalledAppQueryUpdate get updateFirst =>
      _InstalledAppQueryUpdateImpl(this, limit: 1);

  _InstalledAppQueryUpdate get updateAll => _InstalledAppQueryUpdateImpl(this);
}

class _InstalledAppQueryBuilderUpdateImpl implements _InstalledAppQueryUpdate {
  const _InstalledAppQueryBuilderUpdateImpl(this.query, {this.limit});

  final QueryBuilder<InstalledApp, InstalledApp, QOperations> query;
  final int? limit;

  @override
  int call({
    Object? appId = ignore,
    Object? appName = ignore,
    Object? location = ignore,
    Object? status = ignore,
    Object? version = ignore,
    Object? installedAt = ignore,
    Object? execFilePath = ignore,
    Object? cliFilePath = ignore,
    Object? addedToPath = ignore,
    Object? autoStartService = ignore,
    Object? groupName = ignore,
    Object? isDefault = ignore,
    Object? extraInfoJson = ignore,
  }) {
    final q = query.build();
    try {
      return q.updateProperties(limit: limit, {
        if (appId != ignore) 1: appId as String?,
        if (appName != ignore) 2: appName as String?,
        if (location != ignore) 3: location as String?,
        if (status != ignore) 4: status as String?,
        if (version != ignore) 5: version as String?,
        if (installedAt != ignore) 6: installedAt as DateTime?,
        if (execFilePath != ignore) 7: execFilePath as String?,
        if (cliFilePath != ignore) 8: cliFilePath as String?,
        if (addedToPath != ignore) 9: addedToPath as bool?,
        if (autoStartService != ignore) 10: autoStartService as bool?,
        if (groupName != ignore) 11: groupName as String?,
        if (isDefault != ignore) 12: isDefault as bool?,
        if (extraInfoJson != ignore) 13: extraInfoJson as String?,
      });
    } finally {
      q.close();
    }
  }
}

extension InstalledAppQueryBuilderUpdate
    on QueryBuilder<InstalledApp, InstalledApp, QOperations> {
  _InstalledAppQueryUpdate get updateFirst =>
      _InstalledAppQueryBuilderUpdateImpl(this, limit: 1);

  _InstalledAppQueryUpdate get updateAll =>
      _InstalledAppQueryBuilderUpdateImpl(this);
}

extension InstalledAppQueryFilter
    on QueryBuilder<InstalledApp, InstalledApp, QFilterCondition> {
  QueryBuilder<InstalledApp, InstalledApp, QAfterFilterCondition> idEqualTo(
    int value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(property: 0, value: value),
      );
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterFilterCondition> idGreaterThan(
    int value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterCondition(property: 0, value: value),
      );
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterFilterCondition>
  idGreaterThanOrEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterOrEqualCondition(property: 0, value: value),
      );
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterFilterCondition> idLessThan(
    int value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(LessCondition(property: 0, value: value));
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterFilterCondition>
  idLessThanOrEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessOrEqualCondition(property: 0, value: value),
      );
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterFilterCondition> idBetween(
    int lower,
    int upper,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        BetweenCondition(property: 0, lower: lower, upper: upper),
      );
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterFilterCondition> appIdEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(property: 1, value: value, caseSensitive: caseSensitive),
      );
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterFilterCondition>
  appIdGreaterThan(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<InstalledApp, InstalledApp, QAfterFilterCondition>
  appIdGreaterThanOrEqualTo(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<InstalledApp, InstalledApp, QAfterFilterCondition> appIdLessThan(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessCondition(property: 1, value: value, caseSensitive: caseSensitive),
      );
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterFilterCondition>
  appIdLessThanOrEqualTo(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<InstalledApp, InstalledApp, QAfterFilterCondition> appIdBetween(
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

  QueryBuilder<InstalledApp, InstalledApp, QAfterFilterCondition>
  appIdStartsWith(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<InstalledApp, InstalledApp, QAfterFilterCondition> appIdEndsWith(
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

  QueryBuilder<InstalledApp, InstalledApp, QAfterFilterCondition> appIdContains(
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

  QueryBuilder<InstalledApp, InstalledApp, QAfterFilterCondition> appIdMatches(
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

  QueryBuilder<InstalledApp, InstalledApp, QAfterFilterCondition>
  appIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const EqualCondition(property: 1, value: ''),
      );
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterFilterCondition>
  appIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const GreaterCondition(property: 1, value: ''),
      );
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterFilterCondition>
  appNameEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(property: 2, value: value, caseSensitive: caseSensitive),
      );
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterFilterCondition>
  appNameGreaterThan(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<InstalledApp, InstalledApp, QAfterFilterCondition>
  appNameGreaterThanOrEqualTo(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<InstalledApp, InstalledApp, QAfterFilterCondition>
  appNameLessThan(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessCondition(property: 2, value: value, caseSensitive: caseSensitive),
      );
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterFilterCondition>
  appNameLessThanOrEqualTo(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<InstalledApp, InstalledApp, QAfterFilterCondition>
  appNameBetween(String lower, String upper, {bool caseSensitive = true}) {
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

  QueryBuilder<InstalledApp, InstalledApp, QAfterFilterCondition>
  appNameStartsWith(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<InstalledApp, InstalledApp, QAfterFilterCondition>
  appNameEndsWith(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<InstalledApp, InstalledApp, QAfterFilterCondition>
  appNameContains(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<InstalledApp, InstalledApp, QAfterFilterCondition>
  appNameMatches(String pattern, {bool caseSensitive = true}) {
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

  QueryBuilder<InstalledApp, InstalledApp, QAfterFilterCondition>
  appNameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const EqualCondition(property: 2, value: ''),
      );
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterFilterCondition>
  appNameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const GreaterCondition(property: 2, value: ''),
      );
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterFilterCondition>
  locationEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(property: 3, value: value, caseSensitive: caseSensitive),
      );
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterFilterCondition>
  locationGreaterThan(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<InstalledApp, InstalledApp, QAfterFilterCondition>
  locationGreaterThanOrEqualTo(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<InstalledApp, InstalledApp, QAfterFilterCondition>
  locationLessThan(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessCondition(property: 3, value: value, caseSensitive: caseSensitive),
      );
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterFilterCondition>
  locationLessThanOrEqualTo(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<InstalledApp, InstalledApp, QAfterFilterCondition>
  locationBetween(String lower, String upper, {bool caseSensitive = true}) {
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

  QueryBuilder<InstalledApp, InstalledApp, QAfterFilterCondition>
  locationStartsWith(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<InstalledApp, InstalledApp, QAfterFilterCondition>
  locationEndsWith(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<InstalledApp, InstalledApp, QAfterFilterCondition>
  locationContains(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<InstalledApp, InstalledApp, QAfterFilterCondition>
  locationMatches(String pattern, {bool caseSensitive = true}) {
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

  QueryBuilder<InstalledApp, InstalledApp, QAfterFilterCondition>
  locationIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const EqualCondition(property: 3, value: ''),
      );
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterFilterCondition>
  locationIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const GreaterCondition(property: 3, value: ''),
      );
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterFilterCondition> statusEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(property: 4, value: value, caseSensitive: caseSensitive),
      );
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterFilterCondition>
  statusGreaterThan(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<InstalledApp, InstalledApp, QAfterFilterCondition>
  statusGreaterThanOrEqualTo(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<InstalledApp, InstalledApp, QAfterFilterCondition>
  statusLessThan(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessCondition(property: 4, value: value, caseSensitive: caseSensitive),
      );
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterFilterCondition>
  statusLessThanOrEqualTo(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<InstalledApp, InstalledApp, QAfterFilterCondition> statusBetween(
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

  QueryBuilder<InstalledApp, InstalledApp, QAfterFilterCondition>
  statusStartsWith(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<InstalledApp, InstalledApp, QAfterFilterCondition>
  statusEndsWith(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<InstalledApp, InstalledApp, QAfterFilterCondition>
  statusContains(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<InstalledApp, InstalledApp, QAfterFilterCondition> statusMatches(
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

  QueryBuilder<InstalledApp, InstalledApp, QAfterFilterCondition>
  statusIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const EqualCondition(property: 4, value: ''),
      );
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterFilterCondition>
  statusIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const GreaterCondition(property: 4, value: ''),
      );
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterFilterCondition>
  versionIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const IsNullCondition(property: 5));
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterFilterCondition>
  versionIsNotNull() {
    return QueryBuilder.apply(not(), (query) {
      return query.addFilterCondition(const IsNullCondition(property: 5));
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterFilterCondition>
  versionEqualTo(String? value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(property: 5, value: value, caseSensitive: caseSensitive),
      );
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterFilterCondition>
  versionGreaterThan(String? value, {bool caseSensitive = true}) {
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

  QueryBuilder<InstalledApp, InstalledApp, QAfterFilterCondition>
  versionGreaterThanOrEqualTo(String? value, {bool caseSensitive = true}) {
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

  QueryBuilder<InstalledApp, InstalledApp, QAfterFilterCondition>
  versionLessThan(String? value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessCondition(property: 5, value: value, caseSensitive: caseSensitive),
      );
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterFilterCondition>
  versionLessThanOrEqualTo(String? value, {bool caseSensitive = true}) {
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

  QueryBuilder<InstalledApp, InstalledApp, QAfterFilterCondition>
  versionBetween(String? lower, String? upper, {bool caseSensitive = true}) {
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

  QueryBuilder<InstalledApp, InstalledApp, QAfterFilterCondition>
  versionStartsWith(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<InstalledApp, InstalledApp, QAfterFilterCondition>
  versionEndsWith(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<InstalledApp, InstalledApp, QAfterFilterCondition>
  versionContains(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<InstalledApp, InstalledApp, QAfterFilterCondition>
  versionMatches(String pattern, {bool caseSensitive = true}) {
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

  QueryBuilder<InstalledApp, InstalledApp, QAfterFilterCondition>
  versionIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const EqualCondition(property: 5, value: ''),
      );
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterFilterCondition>
  versionIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const GreaterCondition(property: 5, value: ''),
      );
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterFilterCondition>
  installedAtIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const IsNullCondition(property: 6));
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterFilterCondition>
  installedAtIsNotNull() {
    return QueryBuilder.apply(not(), (query) {
      return query.addFilterCondition(const IsNullCondition(property: 6));
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterFilterCondition>
  installedAtEqualTo(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(property: 6, value: value),
      );
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterFilterCondition>
  installedAtGreaterThan(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterCondition(property: 6, value: value),
      );
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterFilterCondition>
  installedAtGreaterThanOrEqualTo(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterOrEqualCondition(property: 6, value: value),
      );
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterFilterCondition>
  installedAtLessThan(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(LessCondition(property: 6, value: value));
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterFilterCondition>
  installedAtLessThanOrEqualTo(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessOrEqualCondition(property: 6, value: value),
      );
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterFilterCondition>
  installedAtBetween(DateTime? lower, DateTime? upper) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        BetweenCondition(property: 6, lower: lower, upper: upper),
      );
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterFilterCondition>
  execFilePathIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const IsNullCondition(property: 7));
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterFilterCondition>
  execFilePathIsNotNull() {
    return QueryBuilder.apply(not(), (query) {
      return query.addFilterCondition(const IsNullCondition(property: 7));
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterFilterCondition>
  execFilePathEqualTo(String? value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(property: 7, value: value, caseSensitive: caseSensitive),
      );
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterFilterCondition>
  execFilePathGreaterThan(String? value, {bool caseSensitive = true}) {
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

  QueryBuilder<InstalledApp, InstalledApp, QAfterFilterCondition>
  execFilePathGreaterThanOrEqualTo(String? value, {bool caseSensitive = true}) {
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

  QueryBuilder<InstalledApp, InstalledApp, QAfterFilterCondition>
  execFilePathLessThan(String? value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessCondition(property: 7, value: value, caseSensitive: caseSensitive),
      );
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterFilterCondition>
  execFilePathLessThanOrEqualTo(String? value, {bool caseSensitive = true}) {
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

  QueryBuilder<InstalledApp, InstalledApp, QAfterFilterCondition>
  execFilePathBetween(
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

  QueryBuilder<InstalledApp, InstalledApp, QAfterFilterCondition>
  execFilePathStartsWith(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<InstalledApp, InstalledApp, QAfterFilterCondition>
  execFilePathEndsWith(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<InstalledApp, InstalledApp, QAfterFilterCondition>
  execFilePathContains(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<InstalledApp, InstalledApp, QAfterFilterCondition>
  execFilePathMatches(String pattern, {bool caseSensitive = true}) {
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

  QueryBuilder<InstalledApp, InstalledApp, QAfterFilterCondition>
  execFilePathIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const EqualCondition(property: 7, value: ''),
      );
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterFilterCondition>
  execFilePathIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const GreaterCondition(property: 7, value: ''),
      );
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterFilterCondition>
  cliFilePathIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const IsNullCondition(property: 8));
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterFilterCondition>
  cliFilePathIsNotNull() {
    return QueryBuilder.apply(not(), (query) {
      return query.addFilterCondition(const IsNullCondition(property: 8));
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterFilterCondition>
  cliFilePathEqualTo(String? value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(property: 8, value: value, caseSensitive: caseSensitive),
      );
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterFilterCondition>
  cliFilePathGreaterThan(String? value, {bool caseSensitive = true}) {
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

  QueryBuilder<InstalledApp, InstalledApp, QAfterFilterCondition>
  cliFilePathGreaterThanOrEqualTo(String? value, {bool caseSensitive = true}) {
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

  QueryBuilder<InstalledApp, InstalledApp, QAfterFilterCondition>
  cliFilePathLessThan(String? value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessCondition(property: 8, value: value, caseSensitive: caseSensitive),
      );
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterFilterCondition>
  cliFilePathLessThanOrEqualTo(String? value, {bool caseSensitive = true}) {
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

  QueryBuilder<InstalledApp, InstalledApp, QAfterFilterCondition>
  cliFilePathBetween(
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

  QueryBuilder<InstalledApp, InstalledApp, QAfterFilterCondition>
  cliFilePathStartsWith(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<InstalledApp, InstalledApp, QAfterFilterCondition>
  cliFilePathEndsWith(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<InstalledApp, InstalledApp, QAfterFilterCondition>
  cliFilePathContains(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<InstalledApp, InstalledApp, QAfterFilterCondition>
  cliFilePathMatches(String pattern, {bool caseSensitive = true}) {
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

  QueryBuilder<InstalledApp, InstalledApp, QAfterFilterCondition>
  cliFilePathIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const EqualCondition(property: 8, value: ''),
      );
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterFilterCondition>
  cliFilePathIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const GreaterCondition(property: 8, value: ''),
      );
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterFilterCondition>
  addedToPathEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(property: 9, value: value),
      );
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterFilterCondition>
  autoStartServiceEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(property: 10, value: value),
      );
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterFilterCondition>
  groupNameIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const IsNullCondition(property: 11));
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterFilterCondition>
  groupNameIsNotNull() {
    return QueryBuilder.apply(not(), (query) {
      return query.addFilterCondition(const IsNullCondition(property: 11));
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterFilterCondition>
  groupNameEqualTo(String? value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(
          property: 11,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterFilterCondition>
  groupNameGreaterThan(String? value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterCondition(
          property: 11,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterFilterCondition>
  groupNameGreaterThanOrEqualTo(String? value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterOrEqualCondition(
          property: 11,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterFilterCondition>
  groupNameLessThan(String? value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessCondition(property: 11, value: value, caseSensitive: caseSensitive),
      );
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterFilterCondition>
  groupNameLessThanOrEqualTo(String? value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessOrEqualCondition(
          property: 11,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterFilterCondition>
  groupNameBetween(String? lower, String? upper, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        BetweenCondition(
          property: 11,
          lower: lower,
          upper: upper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterFilterCondition>
  groupNameStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        StartsWithCondition(
          property: 11,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterFilterCondition>
  groupNameEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EndsWithCondition(
          property: 11,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterFilterCondition>
  groupNameContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        ContainsCondition(
          property: 11,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterFilterCondition>
  groupNameMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        MatchesCondition(
          property: 11,
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterFilterCondition>
  groupNameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const EqualCondition(property: 11, value: ''),
      );
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterFilterCondition>
  groupNameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const GreaterCondition(property: 11, value: ''),
      );
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterFilterCondition>
  isDefaultEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(property: 12, value: value),
      );
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterFilterCondition>
  extraInfoJsonIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const IsNullCondition(property: 13));
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterFilterCondition>
  extraInfoJsonIsNotNull() {
    return QueryBuilder.apply(not(), (query) {
      return query.addFilterCondition(const IsNullCondition(property: 13));
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterFilterCondition>
  extraInfoJsonEqualTo(String? value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(
          property: 13,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterFilterCondition>
  extraInfoJsonGreaterThan(String? value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterCondition(
          property: 13,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterFilterCondition>
  extraInfoJsonGreaterThanOrEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterOrEqualCondition(
          property: 13,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterFilterCondition>
  extraInfoJsonLessThan(String? value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessCondition(property: 13, value: value, caseSensitive: caseSensitive),
      );
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterFilterCondition>
  extraInfoJsonLessThanOrEqualTo(String? value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessOrEqualCondition(
          property: 13,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterFilterCondition>
  extraInfoJsonBetween(
    String? lower,
    String? upper, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        BetweenCondition(
          property: 13,
          lower: lower,
          upper: upper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterFilterCondition>
  extraInfoJsonStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        StartsWithCondition(
          property: 13,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterFilterCondition>
  extraInfoJsonEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EndsWithCondition(
          property: 13,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterFilterCondition>
  extraInfoJsonContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        ContainsCondition(
          property: 13,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterFilterCondition>
  extraInfoJsonMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        MatchesCondition(
          property: 13,
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterFilterCondition>
  extraInfoJsonIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const EqualCondition(property: 13, value: ''),
      );
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterFilterCondition>
  extraInfoJsonIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const GreaterCondition(property: 13, value: ''),
      );
    });
  }
}

extension InstalledAppQueryObject
    on QueryBuilder<InstalledApp, InstalledApp, QFilterCondition> {}

extension InstalledAppQuerySortBy
    on QueryBuilder<InstalledApp, InstalledApp, QSortBy> {
  QueryBuilder<InstalledApp, InstalledApp, QAfterSortBy> sortById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(0);
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterSortBy> sortByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(0, sort: Sort.desc);
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterSortBy> sortByAppId({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(1, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterSortBy> sortByAppIdDesc({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(1, sort: Sort.desc, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterSortBy> sortByAppName({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(2, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterSortBy> sortByAppNameDesc({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(2, sort: Sort.desc, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterSortBy> sortByLocation({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(3, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterSortBy> sortByLocationDesc({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(3, sort: Sort.desc, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterSortBy> sortByStatus({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(4, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterSortBy> sortByStatusDesc({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(4, sort: Sort.desc, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterSortBy> sortByVersion({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(5, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterSortBy> sortByVersionDesc({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(5, sort: Sort.desc, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterSortBy> sortByInstalledAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(6);
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterSortBy>
  sortByInstalledAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(6, sort: Sort.desc);
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterSortBy> sortByExecFilePath({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(7, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterSortBy>
  sortByExecFilePathDesc({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(7, sort: Sort.desc, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterSortBy> sortByCliFilePath({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(8, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterSortBy> sortByCliFilePathDesc({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(8, sort: Sort.desc, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterSortBy> sortByAddedToPath() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(9);
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterSortBy>
  sortByAddedToPathDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(9, sort: Sort.desc);
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterSortBy>
  sortByAutoStartService() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(10);
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterSortBy>
  sortByAutoStartServiceDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(10, sort: Sort.desc);
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterSortBy> sortByGroupName({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(11, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterSortBy> sortByGroupNameDesc({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(11, sort: Sort.desc, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterSortBy> sortByIsDefault() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(12);
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterSortBy> sortByIsDefaultDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(12, sort: Sort.desc);
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterSortBy> sortByExtraInfoJson({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(13, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterSortBy>
  sortByExtraInfoJsonDesc({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(13, sort: Sort.desc, caseSensitive: caseSensitive);
    });
  }
}

extension InstalledAppQuerySortThenBy
    on QueryBuilder<InstalledApp, InstalledApp, QSortThenBy> {
  QueryBuilder<InstalledApp, InstalledApp, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(0);
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(0, sort: Sort.desc);
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterSortBy> thenByAppId({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(1, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterSortBy> thenByAppIdDesc({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(1, sort: Sort.desc, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterSortBy> thenByAppName({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(2, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterSortBy> thenByAppNameDesc({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(2, sort: Sort.desc, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterSortBy> thenByLocation({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(3, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterSortBy> thenByLocationDesc({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(3, sort: Sort.desc, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterSortBy> thenByStatus({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(4, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterSortBy> thenByStatusDesc({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(4, sort: Sort.desc, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterSortBy> thenByVersion({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(5, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterSortBy> thenByVersionDesc({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(5, sort: Sort.desc, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterSortBy> thenByInstalledAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(6);
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterSortBy>
  thenByInstalledAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(6, sort: Sort.desc);
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterSortBy> thenByExecFilePath({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(7, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterSortBy>
  thenByExecFilePathDesc({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(7, sort: Sort.desc, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterSortBy> thenByCliFilePath({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(8, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterSortBy> thenByCliFilePathDesc({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(8, sort: Sort.desc, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterSortBy> thenByAddedToPath() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(9);
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterSortBy>
  thenByAddedToPathDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(9, sort: Sort.desc);
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterSortBy>
  thenByAutoStartService() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(10);
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterSortBy>
  thenByAutoStartServiceDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(10, sort: Sort.desc);
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterSortBy> thenByGroupName({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(11, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterSortBy> thenByGroupNameDesc({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(11, sort: Sort.desc, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterSortBy> thenByIsDefault() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(12);
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterSortBy> thenByIsDefaultDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(12, sort: Sort.desc);
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterSortBy> thenByExtraInfoJson({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(13, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterSortBy>
  thenByExtraInfoJsonDesc({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(13, sort: Sort.desc, caseSensitive: caseSensitive);
    });
  }
}

extension InstalledAppQueryWhereDistinct
    on QueryBuilder<InstalledApp, InstalledApp, QDistinct> {
  QueryBuilder<InstalledApp, InstalledApp, QAfterDistinct> distinctByAppId({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(1, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterDistinct> distinctByAppName({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(2, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterDistinct> distinctByLocation({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(3, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterDistinct> distinctByStatus({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(4, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterDistinct> distinctByVersion({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(5, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterDistinct>
  distinctByInstalledAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(6);
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterDistinct>
  distinctByExecFilePath({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(7, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterDistinct>
  distinctByCliFilePath({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(8, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterDistinct>
  distinctByAddedToPath() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(9);
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterDistinct>
  distinctByAutoStartService() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(10);
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterDistinct> distinctByGroupName({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(11, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterDistinct>
  distinctByIsDefault() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(12);
    });
  }

  QueryBuilder<InstalledApp, InstalledApp, QAfterDistinct>
  distinctByExtraInfoJson({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(13, caseSensitive: caseSensitive);
    });
  }
}

extension InstalledAppQueryProperty1
    on QueryBuilder<InstalledApp, InstalledApp, QProperty> {
  QueryBuilder<InstalledApp, int, QAfterProperty> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(0);
    });
  }

  QueryBuilder<InstalledApp, String, QAfterProperty> appIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(1);
    });
  }

  QueryBuilder<InstalledApp, String, QAfterProperty> appNameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(2);
    });
  }

  QueryBuilder<InstalledApp, String, QAfterProperty> locationProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(3);
    });
  }

  QueryBuilder<InstalledApp, String, QAfterProperty> statusProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(4);
    });
  }

  QueryBuilder<InstalledApp, String?, QAfterProperty> versionProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(5);
    });
  }

  QueryBuilder<InstalledApp, DateTime?, QAfterProperty> installedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(6);
    });
  }

  QueryBuilder<InstalledApp, String?, QAfterProperty> execFilePathProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(7);
    });
  }

  QueryBuilder<InstalledApp, String?, QAfterProperty> cliFilePathProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(8);
    });
  }

  QueryBuilder<InstalledApp, bool, QAfterProperty> addedToPathProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(9);
    });
  }

  QueryBuilder<InstalledApp, bool, QAfterProperty> autoStartServiceProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(10);
    });
  }

  QueryBuilder<InstalledApp, String?, QAfterProperty> groupNameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(11);
    });
  }

  QueryBuilder<InstalledApp, bool, QAfterProperty> isDefaultProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(12);
    });
  }

  QueryBuilder<InstalledApp, String?, QAfterProperty> extraInfoJsonProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(13);
    });
  }
}

extension InstalledAppQueryProperty2<R>
    on QueryBuilder<InstalledApp, R, QAfterProperty> {
  QueryBuilder<InstalledApp, (R, int), QAfterProperty> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(0);
    });
  }

  QueryBuilder<InstalledApp, (R, String), QAfterProperty> appIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(1);
    });
  }

  QueryBuilder<InstalledApp, (R, String), QAfterProperty> appNameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(2);
    });
  }

  QueryBuilder<InstalledApp, (R, String), QAfterProperty> locationProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(3);
    });
  }

  QueryBuilder<InstalledApp, (R, String), QAfterProperty> statusProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(4);
    });
  }

  QueryBuilder<InstalledApp, (R, String?), QAfterProperty> versionProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(5);
    });
  }

  QueryBuilder<InstalledApp, (R, DateTime?), QAfterProperty>
  installedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(6);
    });
  }

  QueryBuilder<InstalledApp, (R, String?), QAfterProperty>
  execFilePathProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(7);
    });
  }

  QueryBuilder<InstalledApp, (R, String?), QAfterProperty>
  cliFilePathProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(8);
    });
  }

  QueryBuilder<InstalledApp, (R, bool), QAfterProperty> addedToPathProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(9);
    });
  }

  QueryBuilder<InstalledApp, (R, bool), QAfterProperty>
  autoStartServiceProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(10);
    });
  }

  QueryBuilder<InstalledApp, (R, String?), QAfterProperty> groupNameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(11);
    });
  }

  QueryBuilder<InstalledApp, (R, bool), QAfterProperty> isDefaultProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(12);
    });
  }

  QueryBuilder<InstalledApp, (R, String?), QAfterProperty>
  extraInfoJsonProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(13);
    });
  }
}

extension InstalledAppQueryProperty3<R1, R2>
    on QueryBuilder<InstalledApp, (R1, R2), QAfterProperty> {
  QueryBuilder<InstalledApp, (R1, R2, int), QOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(0);
    });
  }

  QueryBuilder<InstalledApp, (R1, R2, String), QOperations> appIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(1);
    });
  }

  QueryBuilder<InstalledApp, (R1, R2, String), QOperations> appNameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(2);
    });
  }

  QueryBuilder<InstalledApp, (R1, R2, String), QOperations> locationProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(3);
    });
  }

  QueryBuilder<InstalledApp, (R1, R2, String), QOperations> statusProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(4);
    });
  }

  QueryBuilder<InstalledApp, (R1, R2, String?), QOperations> versionProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(5);
    });
  }

  QueryBuilder<InstalledApp, (R1, R2, DateTime?), QOperations>
  installedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(6);
    });
  }

  QueryBuilder<InstalledApp, (R1, R2, String?), QOperations>
  execFilePathProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(7);
    });
  }

  QueryBuilder<InstalledApp, (R1, R2, String?), QOperations>
  cliFilePathProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(8);
    });
  }

  QueryBuilder<InstalledApp, (R1, R2, bool), QOperations>
  addedToPathProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(9);
    });
  }

  QueryBuilder<InstalledApp, (R1, R2, bool), QOperations>
  autoStartServiceProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(10);
    });
  }

  QueryBuilder<InstalledApp, (R1, R2, String?), QOperations>
  groupNameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(11);
    });
  }

  QueryBuilder<InstalledApp, (R1, R2, bool), QOperations> isDefaultProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(12);
    });
  }

  QueryBuilder<InstalledApp, (R1, R2, String?), QOperations>
  extraInfoJsonProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(13);
    });
  }
}
