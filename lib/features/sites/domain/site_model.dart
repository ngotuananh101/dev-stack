import 'package:isar_plus/isar_plus.dart';

part 'site_model.g.dart';

@collection
class SiteModel {
  int id = 0; // isar_plus: 0 signals auto-increment

  @Index(unique: true)
  late String domain; // Site name/domain (e.g. example.test)

  late String rootDir; // Root directory path
  
  String siteType = 'php'; // 'php', 'static', 'proxy', 'cli'

  String? phpVersion; // e.g. "8.2", "8.1"

  int? phpPort; // The CGI port for this site

  String? proxyTarget; // e.g. "http://localhost:3000"

  String? command; // CLI command to run (e.g. "npm run dev")
  int? port; // Custom port for CLI sites
  bool autoStart = false; // Whether to auto-start the CLI site

  bool useSsl = false;
  
  DateTime? createdAt;

  SiteModel({
    this.id = 0, // isar_plus: 0 signals auto-increment
    required this.domain,
    required this.rootDir,
    this.siteType = 'php',
    this.phpVersion,
    this.phpPort,
    this.proxyTarget,
    this.command,
    this.port,
    this.autoStart = false,
    this.useSsl = false,
    this.createdAt,
  });
}
