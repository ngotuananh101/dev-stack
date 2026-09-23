import 'package:isar_plus/isar_plus.dart';

part 'tunnel_model.g.dart';

@collection
class TunnelModel {
  int id = 0; // isar_plus: 0 signals auto-increment

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
    this.id = 0, // isar_plus: 0 signals auto-increment
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
