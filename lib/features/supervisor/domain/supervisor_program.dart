import 'dart:convert';

import 'package:isar_plus/isar_plus.dart';

part 'supervisor_program.g.dart';

@collection
class SupervisorProgram {
  int id = 0; // Primary key. Set via collection.autoIncrement() on insert.

  @Index(unique: true)
  late String name;

  late String command; // e.g. "php artisan queue:work"
  String workingDir = '';

  /// Extra environment variables, merged over the parent environment. Stored
  /// as a flat JSON object following the existing `*Json` convention.
  String environmentJson = '{}';

  bool autoStart = false; // start when the app opens
  bool autoRestart = true; // watchdog on/off
  int maxRestarts = 5; // max restarts inside restartWindowSeconds
  int restartWindowSeconds = 60;
  int restartDelaySeconds = 2; // base backoff delay
  bool enabled = true; // master switch (disabled = never starts)

  DateTime? createdAt;

  SupervisorProgram({
    this.id = 0,
    required this.name,
    required this.command,
    this.workingDir = '',
    this.environmentJson = '{}',
    this.autoStart = false,
    this.autoRestart = true,
    this.maxRestarts = 5,
    this.restartWindowSeconds = 60,
    this.restartDelaySeconds = 2,
    this.enabled = true,
    this.createdAt,
  });

  /// Decodes [environmentJson] into a map, returning an empty map when the
  /// stored blob is malformed (a corrupt record must not crash the watchdog).
  Map<String, String> envVars() {
    try {
      final decoded = jsonDecode(environmentJson);
      if (decoded is Map) {
        return decoded.map((k, v) => MapEntry(k.toString(), v.toString()));
      }
    } catch (_) {
      // Fall through to the empty map.
    }
    return const {};
  }
}
