import 'package:isar_plus/isar_plus.dart';

part 'cron_job.g.dart';

@collection
class CronJob {
  int id = 0; // Primary key. Set via collection.autoIncrement() on insert.

  @Index(unique: true)
  late String name;

  late String schedule; // "*/5 * * * *" or "@daily"
  late String command;
  String workingDir = '';
  bool enabled = true;

  DateTime? lastRunAt;
  String? lastStatus; // 'success' | 'failed' | 'running'
  int? lastExitCode;
  DateTime? createdAt;

  CronJob({
    this.id = 0,
    required this.name,
    required this.schedule,
    required this.command,
    this.workingDir = '',
    this.enabled = true,
    this.lastRunAt,
    this.lastStatus,
    this.lastExitCode,
    this.createdAt,
  });
}
