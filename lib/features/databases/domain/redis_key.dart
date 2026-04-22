class RedisKey {
  final String key;
  final String value;
  final String type;
  final int length;
  final String ttl;
  final int rawTtl;

  RedisKey({
    required this.key,
    required this.value,
    required this.type,
    required this.length,
    required this.ttl,
    required this.rawTtl,
  });
}
