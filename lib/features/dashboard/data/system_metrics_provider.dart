import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../domain/system_metrics.dart';

part 'system_metrics_provider.g.dart';

@riverpod
class SystemMetricsNotifier extends _$SystemMetricsNotifier {
  late Timer _timer;
  final Random _random = Random();

  @override
  SystemMetrics build() {
    _timer = Timer.periodic(const Duration(seconds: 3), (timer) {
      _updateMetrics();
    });

    ref.onDispose(() {
      _timer.cancel();
    });

    _fetchIpAddress();

    return SystemMetrics(
      cpuUsage: 24.2,
      cpuHistory: List.generate(20, (index) => 20.0 + _random.nextDouble() * 30),
      memoryUsed: 6.8,
      memoryTotal: 16.0,
      storageUsed: 245.0,
      storageTotal: 512.0,
      ipAddress: 'SCANNING...',
      diskReadHistory: List.generate(20, (index) => _random.nextDouble() * 10),
      diskWriteHistory: List.generate(20, (index) => _random.nextDouble() * 5),
      networkUploadHistory: List.generate(20, (index) => _random.nextDouble() * 2),
      networkDownloadHistory: List.generate(20, (index) => _random.nextDouble() * 15),
    );
  }

  Future<void> _fetchIpAddress() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
      );
      
      for (var interface in interfaces) {
        for (var addr in interface.addresses) {
          if (!addr.isLoopback) {
            state = state.copyWith(ipAddress: addr.address);
            return;
          }
        }
      }
      state = state.copyWith(ipAddress: '127.0.0.1');
    } catch (e) {
      state = state.copyWith(ipAddress: 'UNKNOWN');
    }
  }

  void _updateMetrics() {
    final newCpu = 10.0 + _random.nextDouble() * 60;
    final newCpuHistory = List<double>.from(state.cpuHistory)..removeAt(0)..add(newCpu);
    
    final newDiskRead = _random.nextDouble() * 25;
    final newDiskWrite = _random.nextDouble() * 15;
    final newNetUp = _random.nextDouble() * 5;
    final newNetDown = _random.nextDouble() * 40;

    state = state.copyWith(
      cpuUsage: newCpu,
      cpuHistory: newCpuHistory,
      memoryUsed: 6.0 + _random.nextDouble() * 4,
      storageUsed: state.storageUsed + _random.nextDouble() * 0.1,
      diskReadHistory: List<double>.from(state.diskReadHistory)..removeAt(0)..add(newDiskRead),
      diskWriteHistory: List<double>.from(state.diskWriteHistory)..removeAt(0)..add(newDiskWrite),
      networkUploadHistory: List<double>.from(state.networkUploadHistory)..removeAt(0)..add(newNetUp),
      networkDownloadHistory: List<double>.from(state.networkDownloadHistory)..removeAt(0)..add(newNetDown),
    );
  }
}
