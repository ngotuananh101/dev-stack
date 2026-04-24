class SiteModel {
  final String id;
  final String name;
  final String path;
  final String phpVersion;
  final bool hasSsl;

  SiteModel({
    required this.id,
    required this.name,
    required this.path,
    required this.phpVersion,
    required this.hasSsl,
  });
}
