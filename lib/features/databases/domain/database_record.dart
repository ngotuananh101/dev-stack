import 'package:isar/isar.dart';

part 'database_record.g.dart';

@collection
class DatabaseRecord {
  Id id = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  late String name;

  late String username;
  late String password;
  late String engineAppId; // e.g., 'mysql', 'mariadb', 'mongodb'
  String? note;
  
  late DateTime createdAt;

  DatabaseRecord();
}
