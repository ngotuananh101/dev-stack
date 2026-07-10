import '../../features/sites/domain/batch_models.dart';

/// Runs [task] over [items] with at most [concurrency] tasks in flight at once,
/// using a worker-pool (as one task finishes the next is admitted). Results are
/// returned indexed by the item's original position. If [cancel] is triggered,
/// no further tasks are admitted; items that never started keep a `null` slot.
Future<List<R?>> runBounded<T, R>(
  List<T> items,
  int concurrency,
  Future<R> Function(T item, int index) task, {
  CancelToken? cancel,
}) async {
  final results = List<R?>.filled(items.length, null);
  var nextIndex = 0;
  final workerCount = concurrency < 1 ? 1 : concurrency;

  Future<void> worker() async {
    while (true) {
      if (cancel?.isCancelled ?? false) return;
      final index = nextIndex;
      if (index >= items.length) return;
      nextIndex++;
      results[index] = await task(items[index], index);
    }
  }

  final workers = <Future<void>>[];
  final count = workerCount < items.length ? workerCount : items.length;
  for (var i = 0; i < count; i++) {
    workers.add(worker());
  }
  await Future.wait(workers);
  return results;
}
