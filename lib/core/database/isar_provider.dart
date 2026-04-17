import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../features/dashboard/domain/environment_model.dart';
import '../../features/apps/domain/app_model.dart';

part 'isar_provider.g.dart';

class IsarInstance {
  static Isar? _instance;

  static Future<Isar> getInstance() async {
    if (_instance != null) {
      return _instance!;
    }

    final dir = await getApplicationDocumentsDirectory();
    _instance = await Isar.open(
      [
        EnvironmentModelSchema,
        AppModelSchema,
      ],
      directory: dir.path,
    );
    return _instance!;
  }

  static Future<void> close() async {
    await _instance?.close();
    _instance = null;
  }
}

@Riverpod(keepAlive: true)
Future<Isar> isar(IsarRef ref) async {
  return await IsarInstance.getInstance();
}
