import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A container that lives for the whole test process, used only to hand out a
/// real [Ref] via [testRef].
final ProviderContainer _refContainer = ProviderContainer();

final Provider<Ref> _refProbe = Provider<Ref>((ref) => ref);

/// Returns a real [Ref] for tests.
///
/// Riverpod 3 sealed the [Ref] class, so the previous
/// `class _FakeRef implements Ref` trick no longer compiles. Several services
/// (e.g. `AppInstallerService`) take a [Ref] in their constructor but never
/// touch it in the code paths under test, so any live [Ref] is a drop-in
/// replacement.
///
/// The returned [Ref] belongs to a process-wide [ProviderContainer] that is
/// never disposed, which keeps it valid for the lifetime of the test run.
Ref testRef() => _refContainer.read(_refProbe);
