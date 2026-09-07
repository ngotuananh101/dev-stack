import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';
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
    StateNotifierProvider<TunnelSessionsNotifier, Map<int, TunnelSession>>((ref) {
  final manager = ref.watch(tunnelManagerServiceProvider);
  final notifier = TunnelSessionsNotifier(manager);
  ref.onDispose(() => notifier.dispose());
  return notifier;
});

class TunnelSessionsNotifier extends StateNotifier<Map<int, TunnelSession>> {
  final TunnelManagerService _manager;
  StreamSubscription<Map<int, TunnelSession>>? _subscription;

  TunnelSessionsNotifier(this._manager) : super(_manager.currentSessions) {
    _subscription = _manager.sessionsStream.listen((sessions) {
      state = sessions;
    });
  }

  Future<void> start(TunnelModel tunnel) => _manager.startTunnel(tunnel);
  Future<void> stop(int tunnelId) => _manager.stopTunnel(tunnelId);
  Future<void> delete(int tunnelId) => _manager.deleteTunnel(tunnelId);

  @override
  void dispose() {
    _subscription?.cancel();
    _subscription = null;
    super.dispose();
  }
}
