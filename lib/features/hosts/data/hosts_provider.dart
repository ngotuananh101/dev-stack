import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'hosts_repository.dart';

part 'hosts_provider.g.dart';

final hostsRepositoryProvider = Provider<HostsRepository>((ref) => HostsRepository());

@riverpod
class Hosts extends _$Hosts {
  HostsRepository get _repository => ref.read(hostsRepositoryProvider);

  @override
  Future<String> build() async {
    return _repository.readHostsRaw();
  }

  void updateText(String text) {
    state = AsyncValue.data(text);
  }

  Future<bool> save() async {
    final current = state.value ?? '';
    final success = await _repository.saveHostsRaw(current);
    // The page only reads this auto-dispose provider, so it can be disposed
    // while pkexec/UAC waits for the password. The file is already written by
    // then; there is just no state left to refresh.
    if (success && ref.mounted) {
      ref.invalidateSelf();
    }
    return success;
  }

  Future<bool> isAdmin() async {
    return _repository.checkAdmin();
  }
}
