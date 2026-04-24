import 'package:isar/isar.dart';

part 'site_model.g.dart';

@collection
class SiteModel {
  Id id = Isar.autoIncrement;

  @Index(unique: true)
  late String domain; // Site name/domain (e.g. example.test)

  late String rootDir; // Root directory path
  
  late String phpVersion; // e.g. "8.2", "8.1"
  
  late int phpPort; // The CGI port for this site
  
  bool useSsl = false;
  
  DateTime? createdAt;

  SiteModel({
    required this.domain,
    required this.rootDir,
    required this.phpVersion,
    required this.phpPort,
    this.useSsl = false,
    this.createdAt,
  });
}
