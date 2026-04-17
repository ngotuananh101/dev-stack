import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'navigation_provider.g.dart';

enum NavigationTab {
  dashboard,
  apps,
  sites,
  databases,
  hosts,
  logs,
  settings,
}

@riverpod
class Navigation extends _$Navigation {
  @override
  NavigationTab build() {
    return NavigationTab.dashboard;
  }

  void setTab(NavigationTab tab) {
    state = tab;
  }
}
