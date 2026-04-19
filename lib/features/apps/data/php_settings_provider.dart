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

  Future<List<PhpExtension>> getExtensions(AppModel app, [String? iniContent]) async {
    if (app.location == null) return [];
    
    final extDir = Directory('${app.location}${Platform.pathSeparator}ext');
    if (!await extDir.exists()) return [];

    final content = iniContent ?? await readPhpIni(app);
    final List<FileSystemEntity> entities = await extDir.list().toList();
    final dllFiles = entities.where((f) => f.path.toLowerCase().endsWith('.dll')).toList();

    // Optimize: Parse ini once to find all extension lines
    final activeExtensions = <String>{};
    final disabledExtensions = <String>{};
    
    // Regex to match extension/zend_extension lines and capture the name
    // Matches: extension=mbstring, ;extension=curl, zend_extension="opcache"
    final extLineRegex = RegExp(
      r'^;?\s*(?:extension|zend_extension)\s*=\s*"?\s*(?:php_)?([^"\r\n]+?)(?:\.dll)?"?\s*$', 
      multiLine: true, 
      caseSensitive: false
    );
    
    final matches = extLineRegex.allMatches(content);
    for (final match in matches) {
      final fullLine = match.group(0)!;
      String name = match.group(1)!.toLowerCase();
      
      // If it's an absolute path, extract the filename
      if (name.contains('\\') || name.contains('/')) {
        name = name.split(RegExp(r'[\\/]')).last;
        // Clean up php_ prefix and .dll if present in filename
        name = name.replaceAll('.dll', '').replaceFirst('php_', '');
      }
      
      if (fullLine.trim().startsWith(';')) {
        disabledExtensions.add(name);
      } else {
        activeExtensions.add(name);
      }
    }

    final List<PhpExtension> extensions = [];
    
    for (final file in dllFiles) {
      final fileName = file.path.split(Platform.pathSeparator).last;
      
      String name = fileName.replaceAll('.dll', '');
      if (name.startsWith('php_')) {
        name = name.substring(4);
      }
      final lowerName = name.toLowerCase();

      // Skip opcache and xdebug as requested
      if (lowerName == 'opcache' || lowerName == 'xdebug') continue;

      bool isZend = lowerName == 'xdebug'; // opcache is usually internal or also zend
      bool isEnabled = activeExtensions.contains(lowerName);
      bool isFoundInIni = isEnabled || disabledExtensions.contains(lowerName);
      
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
    if (file == null || !await file.exists() || app.location == null) return;

    String content = await file.readAsString();
    final name = ext.name;
    
    // 1. Remove ALL existing lines for this extension (enabled or commented)
    // This cleans up any previous attempts or manual edits to avoid duplication
    // Handles both short names and absolute paths
    final searchRegex = RegExp(
      r'^;?\s*(?:extension|zend_extension)\s*=\s*"?\s*(?:[^"\r\n]*?[\\/])?(?:php_)?' + RegExp.escape(name) + r'(?:\.dll)?"?\s*$\r?\n?', 
      multiLine: true, 
      caseSensitive: false
    );
    content = content.replaceAll(searchRegex, '');

    if (enable) {
      final type = ext.isZend ? 'zend_extension' : 'extension';
      final extPath = '${app.location}${Platform.pathSeparator}ext${Platform.pathSeparator}${ext.fileName}';
      final newLine = '$type="$extPath"';
      
      // 2. Try to insert after opcache for organization, else append
      final opcacheRegex = RegExp(r'^;?\s*zend_extension\s*=\s*"?\s*opcache(?:\.dll)?"?\s*$', multiLine: true, caseSensitive: false);
      
      if (opcacheRegex.hasMatch(content)) {
        content = content.replaceFirstMapped(opcacheRegex, (match) {
          return '${match.group(0)}\n$newLine';
        });
      } else {
        content += '\n$newLine';
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
