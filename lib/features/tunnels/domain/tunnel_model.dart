import 'package:isar/isar.dart';

part 'tunnel_model.g.dart';

@collection
class TunnelModel {
  Id id = Isar.autoIncrement;

  late String name;

  @Index()
  late String provider; // 'cloudflare' | 'ngrok'

  late String targetType; // 'site' | 'port'

  String? targetSiteDomain;
  int targetPort = 80;

  String? authToken;
  String? customDomain;

  bool autoStart = false;

  DateTime? createdAt;
  DateTime? lastActiveAt;

  TunnelModel({
    this.id = Isar.autoIncrement,
    required this.name,
    this.provider = 'cloudflare',
    this.targetType = 'site',
    this.targetSiteDomain,
    this.targetPort = 80,
    this.authToken,
    this.customDomain,
    this.autoStart = false,
    this.createdAt,
    this.lastActiveAt,
  });
}
