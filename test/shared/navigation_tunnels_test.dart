import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dev_stack/shared/providers/navigation_provider.dart';

void main() {
  test('navigationProvider supports tunnels tab', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(navigationProvider), equals(NavigationTab.apps));

    container.read(navigationProvider.notifier).setTab(NavigationTab.tunnels);
    expect(container.read(navigationProvider), equals(NavigationTab.tunnels));
  });
}
