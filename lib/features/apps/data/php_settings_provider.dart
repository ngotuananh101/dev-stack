import 'dart:io';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../domain/app_model.dart';

part 'php_settings_provider.g.dart';

@riverpod
class PhpSettings extends _$PhpSettings {
  @override
  void build() {}

  File? _getPhpIni(AppModel app) {
    if (app.location == null) return null;
    return File('${app.location}${Platform.pathSeparator}php.ini');
  }

  Future<String> readPhpIni(AppModel app) async {
    final file = _getPhpIni(app);
    if (file == null || !await file.exists()) return '';
    return await file.readAsString();
  }

  Future<void> savePhpIni(AppModel app, String content) async {
    final file = _getPhpIni(app);
    if (file == null) return;
    await file.writeAsString(content);
  }

  Future<List<PhpExtension>> getExtensions(AppModel app) async {
    if (app.location == null) return [];
    
    final extDir = Directory('${app.location}${Platform.pathSeparator}ext');
    if (!await extDir.exists()) return [];

    final iniContent = await readPhpIni(app);
    final List<FileSystemEntity> entities = await extDir.list().toList();
    final dllFiles = entities.where((f) => f.path.toLowerCase().endsWith('.dll')).toList();

    final List<PhpExtension> extensions = [];
    
    for (final file in dllFiles) {
      final fileName = file.path.split(Platform.pathSeparator).last;
      
      String name = fileName.replaceAll('.dll', '');
      if (name.startsWith('php_')) {
        name = name.substring(4);
      }

      // Check if it's a zend extension (like opcache)
      bool isZend = name.toLowerCase() == 'opcache' || name.toLowerCase() == 'xdebug';

      String typePrefix = isZend ? 'zend_extension' : 'extension';

      // Match extension=name or extension=php_name.dll or extension="name"
      final enabledRegex = RegExp(r'^' + typePrefix + r'\s*=\s*"? (?:php_)?' + name + r'(?:\.dll)?"?', multiLine: true, caseSensitive: false);
      final disabledRegex = RegExp(r'^;\s*' + typePrefix + r'\s*=\s*"? (?:php_)?' + name + r'(?:\.dll)?"?', multiLine: true, caseSensitive: false);

      bool isEnabled = enabledRegex.hasMatch(iniContent);
      bool isFoundInIni = isEnabled || disabledRegex.hasMatch(iniContent);
      
      extensions.add(PhpExtension(
        name: name,
        fileName: fileName,
        isEnabled: isEnabled,
        isFoundInIni: isFoundInIni,
        isZend: isZend,
      ));
    }

    // Sort: Enabled first, then by name
    extensions.sort((a, b) {
      if (a.isEnabled != b.isEnabled) return a.isEnabled ? -1 : 1;
      return a.name.compareTo(b.name);
    });

    return extensions;
  }

  Future<void> toggleExtension(AppModel app, PhpExtension ext, bool enable) async {
    final file = _getPhpIni(app);
    if (file == null || !await file.exists()) return;

    String content = await file.readAsString();
    final name = ext.name;
    final typePrefix = ext.isZend ? 'zend_extension' : 'extension';

    // Regex to find the extension line (commented or not)
    final regex = RegExp(r'^;?\s*' + typePrefix + r'\s*=\s*"? (?:php_)?' + name + r'(?:\.dll)?"?', multiLine: true, caseSensitive: false);

    if (regex.hasMatch(content)) {
      if (enable) {
        // Uncomment
        content = content.replaceFirstMapped(regex, (match) {
          String line = match.group(0)!;
          if (line.startsWith(';')) {
            line = line.substring(1).trimLeft();
          }
          return line;
        });
      } else {
        // Comment
        content = content.replaceFirstMapped(regex, (match) {
          final line = match.group(0)!;
          if (!line.startsWith(';')) {
            return ';$line';
          }
          return line;
        });
      }
    } else if (enable) {
      // Add new line if not found and enabling
      // Find the extensions section if possible, or just append
      if (content.contains('Dynamic Extensions')) {
        content = content.replaceFirst('; Dynamic Extensions', '; Dynamic Extensions\n$typePrefix=$name');
      } else {
        content += '\n$typePrefix=$name';
      }
    }

    await file.writeAsString(content);
  }
}

class PhpExtension {
  final String name;
  final String fileName;
  final bool isEnabled;
  final bool isFoundInIni;
  final bool isZend;

  PhpExtension({
    required this.name,
    required this.fileName,
    required this.isEnabled,
    required this.isFoundInIni,
    required this.isZend,
  });
}
