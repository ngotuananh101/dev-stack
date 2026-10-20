import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'sidebar_provider.g.dart';

/// Whether the navigation sidebar is collapsed to its icon-only width.
///
/// A narrow window leaves the main content very little room while the sidebar
/// still holds its full 240px, so the user can fold it away to 64px.
@riverpod
class SidebarCollapsed extends _$SidebarCollapsed {
  @override
  bool build() => false;

  void toggle() => state = !state;

  void setCollapsed(bool collapsed) => state = collapsed;
}
