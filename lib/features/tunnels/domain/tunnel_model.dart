import 'package:isar_plus/isar_plus.dart';

part 'tunnel_model.g.dart';

@collection
class TunnelModel {
  int id = 0; // Primary key. Set via collection.autoIncrement() on insert.

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
    this.id = 0, // Set to collection.autoIncrement() on insert.
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
