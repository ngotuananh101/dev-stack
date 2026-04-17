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
    _timer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _updateMetrics();
    });

    ref.onDispose(() {
      _timer.cancel();
    });

    _fetchIpAddress();

    return SystemMetrics(
      cpuUsage: 24.2,
      cpuHistory: List.generate(15, (index) => 20.0 + _random.nextDouble() * 30),
      memoryUsed: 6.8,
      memoryTotal: 16.0,
      storageUsed: 245.0,
      storageTotal: 512.0,
      ipAddress: 'SCANNING...',
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
    final newHistory = List<double>.from(state.cpuHistory)..removeAt(0)..add(newCpu);
    
    state = state.copyWith(
      cpuUsage: newCpu,
      cpuHistory: newHistory,
      memoryUsed: 6.0 + _random.nextDouble() * 4,
      storageUsed: state.storageUsed + _random.nextDouble() * 0.1, // Slight increase
    );
  }
}
