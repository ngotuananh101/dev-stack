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
  return TunnelSessionsNotifier(manager);
});

class TunnelSessionsNotifier extends StateNotifier<Map<int, TunnelSession>> {
  final TunnelManagerService _manager;

  TunnelSessionsNotifier(this._manager) : super(_manager.currentSessions) {
    _manager.sessionsStream.listen((sessions) {
      state = sessions;
    });
  }

  Future<void> start(TunnelModel tunnel) => _manager.startTunnel(tunnel);
  Future<void> stop(int tunnelId) => _manager.stopTunnel(tunnelId);
  Future<void> delete(int tunnelId) => _manager.deleteTunnel(tunnelId);
}
