import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar_plus/isar_plus.dart';
import '../../../core/database/isar_provider.dart';
import '../domain/tunnel_model.dart';
import '../domain/tunnel_session.dart';
import 'tunnel_manager_service.dart';

final tunnelsStreamProvider = StreamProvider<List<TunnelModel>>((ref) async* {
  final isarAsync = ref.watch(isarProvider);
  final isar = isarAsync.value;
  if (isar == null) {
    yield [];
    return;
  }

  yield* isar.tunnelModels.where().watch(fireImmediately: true);
});

final tunnelSessionsProvider =
    NotifierProvider<TunnelSessionsNotifier, Map<int, TunnelSession>>(
  TunnelSessionsNotifier.new,
);

class TunnelSessionsNotifier extends Notifier<Map<int, TunnelSession>> {
  late TunnelManagerService _manager;
  StreamSubscription<Map<int, TunnelSession>>? _subscription;

  @override
  Map<int, TunnelSession> build() {
    _manager = ref.watch(tunnelManagerServiceProvider);

    // sessionsStream is a broadcast stream, so it replays nothing on listen:
    // seed from the manager's current map and follow it from here.
    _subscription = _manager.sessionsStream.listen((sessions) {
      state = sessions;
    });

    ref.onDispose(() {
      _subscription?.cancel();
      _subscription = null;
    });

    return _manager.currentSessions;
  }

  Future<void> start(TunnelModel tunnel) => _manager.startTunnel(tunnel);
  Future<void> stop(int tunnelId) => _manager.stopTunnel(tunnelId);
  Future<void> delete(int tunnelId) => _manager.deleteTunnel(tunnelId);
}
