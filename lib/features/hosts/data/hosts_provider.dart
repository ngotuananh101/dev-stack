import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'hosts_repository.dart';

part 'hosts_provider.g.dart';

@riverpod
class HostsNotifier extends _$HostsNotifier {
  final _repository = HostsRepository();

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
    if (success) {
      ref.invalidateSelf();
    }
    return success;
  }

  Future<bool> isAdmin() async {
    return _repository.checkAdmin();
  }
}
