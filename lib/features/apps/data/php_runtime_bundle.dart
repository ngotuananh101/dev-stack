import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart' as crypto;
import 'package:path/path.dart' as p;

class PhpSharedModule {
  final String name;
  final String directive;
  final String path;
  final String sha256;

  const PhpSharedModule({
    required this.name,
    required this.directive,
    required this.path,
    required this.sha256,
  });

  Future<void> validateHash() async {
    final hash = await crypto.sha256.bind(File(path).openRead()).first;
    if (hash.toString() != sha256) {
      throw FormatException('SHA256 mismatch for PHP module $name.');
    }
  }
}

/// Validates the producer's portable PHP contract without executing the bundle.
class PhpRuntimeBundle {
  final String root;
  final String version;
  final Map<String, String> _paths;
  final List<PhpSharedModule> sharedModules;

  PhpRuntimeBundle._(this.root, this.version, this._paths, this.sharedModules);

  static const _files = [
    'cli',
    'fpm',
    'extension_manager',
    'cli_binary',
    'fpm_binary',
    'php_ini',
  ];
  static const _directories = ['cli_scan_dir', 'fpm_scan_dir', 'extension_dir'];
  static const _launchers = {
    'cli': 'bin/php',
    'fpm': 'bin/php-fpm',
    'extension_manager': 'bin/php-ext',
  };

  /// Only an absent manifest is a legacy installation; invalid manifests fail closed.
  static PhpRuntimeBundle? load(String root) {
    final manifestPath = p.join(root, 'manifest.json');
    if (FileSystemEntity.typeSync(manifestPath, followLinks: false) ==
        FileSystemEntityType.notFound) {
      return null;
    }
    try {
      final canonicalRoot = Directory(root).resolveSymbolicLinksSync();
      final manifest = _containedPath(
        canonicalRoot,
        'manifest.json',
        directory: false,
      );
      final data = jsonDecode(File(manifest).readAsStringSync());
      if (data is! Map<String, dynamic> ||
          data['schema_version'] != 1 ||
          data['runtime'] != 'php' ||
          data['architecture'] != 'x86_64' ||
          data['target'] != 'musl-dynamic' ||
          data['verification'] != 'PASSED') {
        throw const FormatException(
          'Unsupported portable PHP manifest identity.',
        );
      }
      final php = data['php'];
      final version = php is Map ? php['version'] : null;
      final staticModules = php is Map ? php['static_modules'] : null;
      if (version is! String ||
          !RegExp(r'^\d+\.\d+\.\d+$').hasMatch(version) ||
          staticModules is! List ||
          staticModules.any((name) => name is! String || name.trim().isEmpty)) {
        throw const FormatException(
          'Invalid PHP version or static module registry.',
        );
      }
      final paths = data['paths'];
      if (paths is! Map) throw const FormatException('Missing PHP paths.');
      final resolved = <String, String>{};
      for (final key in [..._files, ..._directories]) {
        final value = paths[key];
        if (_launchers.containsKey(key) &&
            (value != _launchers[key] ||
                FileSystemEntity.typeSync(
                      p.join(canonicalRoot, value as String),
                      followLinks: false,
                    ) !=
                    FileSystemEntityType.file ||
                File(p.join(canonicalRoot, value)).resolveSymbolicLinksSync() !=
                    p.join(canonicalRoot, value))) {
          throw FormatException(
            'PHP $key must be a regular bundle launcher ${_launchers[key]}.',
          );
        }
        resolved[key] = _containedPath(
          canonicalRoot,
          value,
          directory: _directories.contains(key),
        );
      }
      final rawModules = data['shared_modules'];
      if (rawModules is! List) {
        throw const FormatException('Missing shared module registry.');
      }
      final modules = <PhpSharedModule>[];
      final names = <String>{};
      final modulePaths = <String>{};
      final staticNames = staticModules
          .cast<String>()
          .map((name) => name.toLowerCase().replaceFirst('zend ', ''))
          .toSet();
      for (final entry in rawModules) {
        if (entry is! Map) {
          throw const FormatException('Invalid shared module entry.');
        }
        final name = entry['name'];
        final directive = entry['directive'];
        final hash = entry['sha256'];
        final defaults = entry['enabled_by_default'];
        if (name is! String ||
            !RegExp(r'^[a-z][a-z0-9_]*$').hasMatch(name) ||
            !names.add(name) ||
            staticNames.contains(name) ||
            (directive != 'extension' && directive != 'zend_extension') ||
            hash is! String ||
            !RegExp(r'^[a-fA-F0-9]{64}$').hasMatch(hash) ||
            defaults is! Map ||
            defaults['cli'] is! bool ||
            defaults['fpm'] is! bool) {
          throw const FormatException(
            'Invalid or duplicate shared module metadata.',
          );
        }
        final modulePath = _containedPath(
          canonicalRoot,
          entry['path'],
          directory: false,
        );
        if (!modulePath.endsWith('.so') ||
            !p.isWithin(resolved['extension_dir']!, modulePath) ||
            !modulePaths.add(modulePath)) {
          throw const FormatException(
            'Shared modules must be unique .so files in extension_dir.',
          );
        }
        modules.add(
          PhpSharedModule(
            name: name,
            directive: directive as String,
            path: modulePath,
            sha256: hash.toLowerCase(),
          ),
        );
      }
      return PhpRuntimeBundle._(
        canonicalRoot,
        version,
        Map.unmodifiable(resolved),
        List.unmodifiable(modules),
      );
    } on FileSystemException catch (e) {
      throw FormatException('Invalid PHP bundle file: ${e.path}');
    }
  }

  static String _containedPath(
    String root,
    dynamic relative, {
    required bool directory,
  }) {
    if (relative is! String ||
        relative.isEmpty ||
        p.posix.isAbsolute(relative) ||
        relative.contains('\\') ||
        RegExp(r'[\x00-\x1f\x7f:]').hasMatch(relative) ||
        relative
            .split('/')
            .any((part) => part.isEmpty || part == '.' || part == '..')) {
      throw const FormatException(
        'PHP bundle paths must be safe root-relative paths.',
      );
    }
    final path = p.join(root, relative);
    final type = FileSystemEntity.typeSync(path);
    if (type !=
        (directory
            ? FileSystemEntityType.directory
            : FileSystemEntityType.file)) {
      throw FormatException(
        'Missing or wrong file type for PHP bundle path: $relative',
      );
    }
    final resolved = directory
        ? Directory(path).resolveSymbolicLinksSync()
        : File(path).resolveSymbolicLinksSync();
    if (!p.isWithin(root, resolved)) {
      throw FormatException('PHP path escapes the bundle root: $relative');
    }
    // Return the declared launcher path, not a resolved backing binary path.
    return path;
  }

  String pathFor(String key) =>
      _paths[key] ??
      (throw ArgumentError.value(key, 'key', 'Unknown PHP path'));

  Future<void> validateInstallation(String expectedVersion) async {
    if (version != expectedVersion) {
      throw FormatException(
        'PHP bundle version $version does not match $expectedVersion.',
      );
    }
    for (final module in sharedModules) {
      await module.validateHash();
    }
  }
}
