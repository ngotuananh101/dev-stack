import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

/// Remembers which sets of build libraries the user has already said no to,
/// so the app asks once instead of on every install.
///
/// A decline key is the missing package names, sorted and joined with `,`,
/// so a different missing set asks again. This lives in its own JSON file
/// rather than in [AppSettings]: adding a property to an Isar collection
/// changes its schema, and this app resets the database when the schema
/// does not match — losing every site, app and tunnel to record a single
/// boolean is not a trade worth making.
class PyenvBuildDepsDeclines {
  PyenvBuildDepsDeclines(this.path);

  final String path;

  File get _file => File(path);

  /// Returns the decline keys in the file, or an empty set when it is missing
  /// or unreadable. A corrupt file must not block installation forever.
  Future<Set<String>> read() async {
    try {
      if (!await _file.exists()) return <String>{};
      final decoded = jsonDecode(await _file.readAsString());
      if (decoded is! Map) return <String>{};
      final declines = decoded['declines'];
      if (declines is! List) return <String>{};
      return declines.whereType<String>().toSet();
    } catch (e) {
      debugPrint('[PYENV] Could not read build-deps declines: $e');
      return <String>{};
    }
  }

  Future<bool> isDeclined(String key) async => (await read()).contains(key);

  /// Records [key] as declined, keeping any other entries.
  Future<void> decline(String key) async {
    final declines = await read()
      ..add(key);
    await _write(declines);
  }

  /// Forgets every decline, so the user is asked again.
  Future<void> clear() async {
    if (await _file.exists()) {
      await _file.delete();
    }
  }

  Future<void> _write(Set<String> declines) async {
    try {
      await _file.parent.create(recursive: true);
      await _file.writeAsString(
        const JsonEncoder.withIndent(
          '  ',
        ).convert({'declines': declines.toList()..sort()}),
      );
    } catch (e) {
      // Failing to remember the answer only means asking again next time.
      debugPrint('[PYENV] Could not save build-deps declines: $e');
    }
  }
}
