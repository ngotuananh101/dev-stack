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

/// Whether the sidebar should be collapsed given the current content width.
///
/// Extracted so the window-width breakpoint is unit-testable without spinning
/// up the whole MainScreen widget tree. Below [kSidebarCollapseBreakpoint] the
/// 240px sidebar eats too much of the page, so it folds to its 64px icon-only
/// width; at or above it, the user's manual choice is restored.
bool computeSidebarCollapse(double contentWidth, bool currentlyCollapsed) {
  if (contentWidth < kSidebarCollapseBreakpoint && !currentlyCollapsed) {
    return true;
  }
  if (contentWidth >= kSidebarCollapseBreakpoint && currentlyCollapsed) {
    return false;
  }
  return currentlyCollapsed;
}

/// Window content width below which the sidebar auto-collapses.
const double kSidebarCollapseBreakpoint = 960;
