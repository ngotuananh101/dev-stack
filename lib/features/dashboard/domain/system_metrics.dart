class SystemMetrics {
  final double cpuUsage;
  final List<double> cpuHistory;
  final double memoryUsed;
  final double memoryTotal;
  final double storageUsed;
  final double storageTotal;
  final String ipAddress;

  SystemMetrics({
    required this.cpuUsage,
    required this.cpuHistory,
    required this.memoryUsed,
    required this.memoryTotal,
    required this.storageUsed,
    required this.storageTotal,
    required this.ipAddress,
  });

  double get memoryPercentage => (memoryUsed / memoryTotal) * 100;
  double get storagePercentage => (storageUsed / storageTotal) * 100;

  SystemMetrics copyWith({
    double? cpuUsage,
    List<double>? cpuHistory,
    double? memoryUsed,
    double? memoryTotal,
    double? storageUsed,
    double? storageTotal,
    String? ipAddress,
  }) {
    return SystemMetrics(
      cpuUsage: cpuUsage ?? this.cpuUsage,
      cpuHistory: cpuHistory ?? this.cpuHistory,
      memoryUsed: memoryUsed ?? this.memoryUsed,
      memoryTotal: memoryTotal ?? this.memoryTotal,
      storageUsed: storageUsed ?? this.storageUsed,
      storageTotal: storageTotal ?? this.storageTotal,
      ipAddress: ipAddress ?? this.ipAddress,
    );
  }
}
