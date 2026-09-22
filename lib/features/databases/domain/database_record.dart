import 'package:isar_plus/isar_plus.dart';

part 'database_record.g.dart';

@collection
class DatabaseRecord {
  int id = 0; // isar_plus: 0 signals auto-increment

  @Index(unique: true)
  late String name;

  late String username;
  late String password;
  late String engineAppId; // e.g., 'mysql', 'mariadb', 'mongodb'
  String? note;
  
  late DateTime createdAt;

  DatabaseRecord();
}
