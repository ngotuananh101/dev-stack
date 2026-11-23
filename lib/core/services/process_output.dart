import 'dart:async';
import 'dart:convert';

/// Drains a managed child's pipe. Discarded output stays as raw bytes rather
/// than paying for UTF-8 decoding, but still drains to prevent backpressure.
/// The caller owns cancellation and receives pipe errors in either mode.
StreamSubscription<dynamic> listenToProcessOutput(
  Stream<List<int>> output, {
  required bool discard,
  required void Function(String) onData,
  required void Function(Object) onError,
}) {
  if (discard) {
    return output.listen((_) {}, onError: onError, cancelOnError: false);
  }
  return output
      .transform(utf8.decoder)
      .listen(onData, onError: onError, cancelOnError: false);
}
