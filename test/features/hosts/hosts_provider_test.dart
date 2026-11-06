import 'dart:async';
import 'dart:io';

import 'package:dev_stack/features/hosts/data/hosts_provider.dart';
import 'package:dev_stack/features/hosts/data/hosts_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Holds the save open until [finishSave] is called, the way pkexec does while
/// it waits for the user's password.
class _SlowSaveRepository extends HostsRepository {
  final _saveDone = Completer<bool>();
  final saved = <String>[];

  void finishSave() => _saveDone.complete(true);

  @override
  Future<String> readHostsRaw() async => '127.0.0.1 localhost';

  @override
  Future<bool> saveHostsRaw(
    String content, {
    bool? isLinux,
    bool skipDirectWrite = false,
    Future<ProcessResult> Function(String, List<String>)? runProcess,
  }) {
    saved.add(content);
    return _saveDone.future;
  }
}

void main() {
  test('save reports success when the provider is disposed while elevation is pending', () async {
    final repository = _SlowSaveRepository();
    final container = ProviderContainer(
      overrides: [hostsRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);

    // The Hosts page reads the notifier without watching the provider, so
    // nothing keeps the auto-dispose provider alive during the save.
    final notifier = container.read(hostsProvider.notifier);
    notifier.updateText('127.0.0.1 app.test');
    final saving = notifier.save();

    await container.pump();
    expect(container.exists(hostsProvider), isFalse);

    repository.finishSave();
    expect(await saving, isTrue);
    expect(repository.saved, equals(['127.0.0.1 app.test']));
  });
}
