import 'dart:io';

import 'package:dev_stack/features/tunnels/data/tunnel_downloader_service.dart';
import 'package:dev_stack/features/tunnels/data/tunnel_manager_service.dart';
import 'package:dev_stack/features/tunnels/domain/tunnel_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_plus/isar_plus.dart';

String? _isarLibraryPath() {
  final libName = Platform.isWindows
      ? 'isar_plus.dll'
      : (Platform.isLinux ? 'libisar_plus.so' : null);
  if (libName == null) return null;

  final pubCache = Platform.environment['PUB_CACHE'] ??
      (Platform.isWindows
          ? '${Platform.environment['LOCALAPPDATA']}\\Pub\\Cache'
          : '${Platform.environment['HOME']}/.pub-cache');
  final hosted = Directory('$pubCache/hosted/pub.dev');
  if (!hosted.existsSync()) return null;

  for (final entry in hosted.listSync()) {
    if (entry is! Directory) continue;
    if (!entry.path.contains('isar_plus_flutter_libs-')) continue;
    final candidate = File(
      '${entry.path}/${Platform.isWindows ? 'windows' : 'linux'}/$libName',
    );
    if (candidate.existsSync()) return candidate.path;
  }
  return null;
}

class _FakeDownloader extends TunnelDownloaderService {
  _FakeDownloader()
      : super(baseDirResolver: () => '', isWindowsResolver: () => true);

  @override
  Future<bool> isBinaryDownloaded(String provider) async => true;

  @override
  String getBinaryPath(String provider) => 'fake_binary';
}

void main() {
  late Isar isar;
  late TunnelManagerService manager;
  final libraryPath = _isarLibraryPath();

  setUp(() {
    final tempDir = Directory.systemTemp.createTempSync('devstack_tunnels_test_');
    addTearDown(() => tempDir.deleteSync(recursive: true));

    Isar.initialize(libraryPath);
    isar = Isar.open(
      schemas: [TunnelModelSchema],
      directory: tempDir.path,
      name: 'tunnels_repo_test_${DateTime.now().microsecondsSinceEpoch}',
    );
    addTearDown(isar.close);

    manager = TunnelManagerService(
      isar: isar,
      downloader: _FakeDownloader(),
      startProcessFn: (exec, args) async => FakeManagedProcess(0),
      stopProcessFn: (pid) async {},
    );
    addTearDown(manager.dispose);
  });

  group('TunnelManagerService.saveTunnel', () {
    test(
      'saving multiple tunnels with default id=0 assigns unique IDs and does not overwrite',
      () async {
        final tunnel1 = TunnelModel(name: 'Tunnel 1', targetPort: 80);
        final tunnel2 = TunnelModel(name: 'Tunnel 2', targetPort: 81);

        final saved1 = await manager.saveTunnel(tunnel1);
        final saved2 = await manager.saveTunnel(tunnel2);

        expect(saved1.id, isNot(equals(0)));
        expect(saved2.id, isNot(equals(0)));
        expect(saved1.id, isNot(equals(saved2.id)));

        final all = isar.tunnelModels.where().findAll();
        expect(all.length, equals(2));
      },
      skip: libraryPath == null ? 'Isar native library not available' : false,
    );
  });
}
