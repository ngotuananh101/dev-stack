import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'error_provider.g.dart';

@Riverpod(keepAlive: true)
class AppError extends _$AppError {
  @override
  String? build() => null;

  void setError(String? message) {
    state = message;
  }

  void clearError() {
    state = null;
  }
}
