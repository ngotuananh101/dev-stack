import 'package:dev_stack/shared/providers/sidebar_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('collapses when narrowing below the breakpoint', () {
    expect(computeSidebarCollapse(959, false), isTrue);
  });

  test('stays collapsed when still narrow', () {
    expect(computeSidebarCollapse(959, true), isTrue);
  });

  test('expands when widening back past the breakpoint', () {
    expect(computeSidebarCollapse(960, true), isFalse);
  });

  test('does not auto-collapse when already collapsed by choice at width', () {
    expect(computeSidebarCollapse(1200, false), isFalse);
  });

  test('manually collapsed at width auto-expands on resize up', () {
    expect(computeSidebarCollapse(1200, true), isFalse);
  });
}
