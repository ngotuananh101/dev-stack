import 'package:isar/isar.dart';

part 'environment_model.g.dart';

@collection
class EnvironmentModel {
  Id id = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  late String name;
  
  late String host;
  late String runtime;
  
  @Enumerated(EnumType.name)
  late EnvironmentStatus status;
  
  late List<String> tags;

  EnvironmentModel({
    this.id = Isar.autoIncrement,
    required this.name,
    required this.host,
    required this.runtime,
    required this.status,
    required this.tags,
  });
}

enum EnvironmentStatus {
  stable,
  restarting,
  stopped,
}
