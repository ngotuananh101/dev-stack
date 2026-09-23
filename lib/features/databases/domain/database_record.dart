import 'package:isar_plus/isar_plus.dart';

part 'database_record.g.dart';

@collection
class DatabaseRecord {
  int id = 0; // Primary key. Set via collection.autoIncrement() on insert.

  @Index(unique: true)
  late String name;

  late String username;
  late String password;
  late String engineAppId; // e.g., 'mysql', 'mariadb', 'mongodb'
  String? note;
  
  late DateTime createdAt;

  DatabaseRecord();
}
