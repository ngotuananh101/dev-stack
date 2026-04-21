class RedisKey {
  final String key;
  final String value;
  final String type;
  final int length;
  final String ttl;

  RedisKey({
    required this.key,
    required this.value,
    required this.type,
    required this.length,
    required this.ttl,
  });
}
