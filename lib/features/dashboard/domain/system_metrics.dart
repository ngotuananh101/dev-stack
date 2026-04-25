class SystemMetrics {
  final double cpuUsage;
  final List<double> cpuHistory;
  final double memoryUsed;
  final double memoryTotal;
  final double storageUsed;
  final double storageTotal;
  final String ipAddress;
  final List<double> diskReadHistory;
  final List<double> diskWriteHistory;
  final List<double> networkUploadHistory;
  final List<double> networkDownloadHistory;

  SystemMetrics({
    required this.cpuUsage,
    required this.cpuHistory,
    required this.memoryUsed,
    required this.memoryTotal,
    required this.storageUsed,
    required this.storageTotal,
    required this.ipAddress,
    required this.diskReadHistory,
    required this.diskWriteHistory,
    required this.networkUploadHistory,
    required this.networkDownloadHistory,
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
    List<double>? diskReadHistory,
    List<double>? diskWriteHistory,
    List<double>? networkUploadHistory,
    List<double>? networkDownloadHistory,
  }) {
    return SystemMetrics(
      cpuUsage: cpuUsage ?? this.cpuUsage,
      cpuHistory: cpuHistory ?? this.cpuHistory,
      memoryUsed: memoryUsed ?? this.memoryUsed,
      memoryTotal: memoryTotal ?? this.memoryTotal,
      storageUsed: storageUsed ?? this.storageUsed,
      storageTotal: storageTotal ?? this.storageTotal,
      ipAddress: ipAddress ?? this.ipAddress,
      diskReadHistory: diskReadHistory ?? this.diskReadHistory,
      diskWriteHistory: diskWriteHistory ?? this.diskWriteHistory,
      networkUploadHistory: networkUploadHistory ?? this.networkUploadHistory,
      networkDownloadHistory:
          networkDownloadHistory ?? this.networkDownloadHistory,
    );
  }
}
