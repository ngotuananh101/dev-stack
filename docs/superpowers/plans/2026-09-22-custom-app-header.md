# Custom App Header & Frameless Window Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the operating-system title bar with a unified, cross-platform 36px app header containing the app icon, title, a drag-to-move region, and Lucide-based window controls (minimize, maximize/restore, close), with frameless window initialization across Windows and Linux.

**Architecture:** Initialize `windowManager` with `TitleBarStyle.hidden` and wrap the app in `VirtualWindowFrameInit()` for border and edge resize handling. Insert a full-width `AppHeader` (36px tall) at the top of the app scaffold above the existing `Row(Sidebar, content)`. Strip the native `GtkHeaderBar` construction from the Linux runner so the window is undecorated from frame zero. Strip the redundant logo block from `Sidebar`.

**Tech Stack:** Flutter 3.47+, Dart 3.13+, `window_manager 0.5.1`, `lucide_icons_flutter 3.1.20`, C++ / GTK3 (Linux runner), Win32 C++ (Windows runner).

**Spec:** `docs/superpowers/specs/2026-09-22-custom-app-header-design.md`

## Global Constraints

- Header height: exactly 36.0 px, spanning the full window width.
- Window control buttons: 46.0 px wide by 36.0 px high, matching Windows 11 caption metric.
- Token discipline: only `AppColors`, `AppTextSize`, `AppRadius` tokens — zero literal `Color(...)` or numeric font size literals in new Dart code.
- Close semantics: close button invokes `windowManager.close()` (never `destroy()`), preserving the `minimizeToTray` shutdown route in `window_service.dart`.
- Maximize toggle: icons are `LucideIcons.square` (when not maximized) and `LucideIcons.copy` (when maximized). Maximize state initialized to `false` and updated strictly via `WindowListener.onWindowMaximize` and `WindowListener.onWindowUnmaximize` (no platform calls in `initState`/`build`, keeping widget tests synchronous and isolated).
- Test baseline: `test/widget_test.dart` and `test/shared/app_header_test.dart` must pass; `flutter analyze` must report 0 issues.

---

### Task 1: Create `AppHeader` Widget and Unit Tests (TDD)

**Files:**
- Create: `lib/shared/layouts/app_header.dart`
- Test: `test/shared/app_header_test.dart`

**Interfaces:**
- Consumes:
  - `AppColors` from `lib/core/theme/app_colors.dart` (`background`, `border`, `surfaceLight`, `textPrimary`, `textSecondary`, `textOnColor`, `error`, `accent`)
  - `AppTextSize` from `lib/core/theme/app_text_size.dart` (`sm`)
  - `AppRadius` from `lib/core/theme/app_radius.dart` (`xs`, `sm`)
  - `LucideIcons` from `package:lucide_icons_flutter/lucide_icons.dart` (`minus`, `square`, `copy`, `x`)
  - `windowManager`, `DragToMoveArea`, `WindowListener` from `package:window_manager/window_manager.dart`
- Produces:
  - `class AppHeader extends StatefulWidget` (in `lib/shared/layouts/app_header.dart`)
  - `const double kAppHeaderHeight = 36.0;`

- [ ] **Step 1: Write the failing test**

Create `test/shared/app_header_test.dart`:

```dart
import 'package:dev_stack/core/theme/app_colors.dart';
import 'package:dev_stack/shared/layouts/app_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:window_manager/window_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('window_manager');
  final methodCalls = <String>[];

  setUp(() {
    methodCalls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      methodCalls.add(call.method);
      if (call.method == 'isMaximized') return false;
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  Future<void> pumpHeader(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark().copyWith(
          scaffoldBackgroundColor: AppColors.background,
        ),
        home: const Scaffold(
          body: Column(
            children: [
              AppHeader(),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('AppHeader renders brand icon, title, and three window controls',
      (tester) async {
    await pumpHeader(tester);

    expect(find.text('Ponta DevStack'), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
    expect(find.byType(DragToMoveArea), findsOneWidget);
    expect(find.byIcon(LucideIcons.minus), findsOneWidget);
    expect(find.byIcon(LucideIcons.square), findsOneWidget);
    expect(find.byIcon(LucideIcons.x), findsOneWidget);

    final headerBox = tester.renderObject<RenderBox>(find.byType(AppHeader));
    expect(headerBox.size.height, equals(kAppHeaderHeight));
  });

  testWidgets('tapping minimize button invokes windowManager.minimize()',
      (tester) async {
    await pumpHeader(tester);

    await tester.tap(find.byIcon(LucideIcons.minus));
    await tester.pump();

    expect(methodCalls, contains('minimize'));
  });

  testWidgets('tapping maximize button invokes windowManager.maximize() when not maximized',
      (tester) async {
    await pumpHeader(tester);

    await tester.tap(find.byIcon(LucideIcons.square));
    await tester.pump();

    expect(methodCalls, contains('maximize'));
  });

  testWidgets('tapping close button invokes windowManager.close() and NEVER destroy()',
      (tester) async {
    await pumpHeader(tester);

    await tester.tap(find.byIcon(LucideIcons.x));
    await tester.pump();

    expect(methodCalls, contains('close'));
    expect(methodCalls, isNot(contains('destroy')));
  });

  testWidgets('onWindowMaximize and onWindowUnmaximize swap maximize icon',
      (tester) async {
    await pumpHeader(tester);

    expect(find.byIcon(LucideIcons.square), findsOneWidget);
    expect(find.byIcon(LucideIcons.copy), findsNothing);

    // Simulate platform event maximize
    final codec = const StandardMethodCodec();
    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
      'window_manager',
      codec.encodeMethodCall(
        const MethodCall('onEvent', {'eventName': 'maximize'}),
      ),
      (_) {},
    );
    await tester.pump();

    expect(find.byIcon(LucideIcons.copy), findsOneWidget);
    expect(find.byIcon(LucideIcons.square), findsNothing);

    // Tapping while maximized calls unmaximize
    await tester.tap(find.byIcon(LucideIcons.copy));
    await tester.pump();
    expect(methodCalls, contains('unmaximize'));

    // Simulate platform event unmaximize
    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
      'window_manager',
      codec.encodeMethodCall(
        const MethodCall('onEvent', {'eventName': 'unmaximize'}),
      ),
      (_) {},
    );
    await tester.pump();

    expect(find.byIcon(LucideIcons.square), findsOneWidget);
    expect(find.byIcon(LucideIcons.copy), findsNothing);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/shared/app_header_test.dart`
Expected: FAIL with compilation error (cannot find `lib/shared/layouts/app_header.dart`).

- [ ] **Step 3: Implement `AppHeader`**

Create `lib/shared/layouts/app_header.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:window_manager/window_manager.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_text_size.dart';

const double kAppHeaderHeight = 36.0;
const double kWindowCaptionButtonWidth = 46.0;

class AppHeader extends StatefulWidget {
  const AppHeader({super.key});

  @override
  State<AppHeader> createState() => _AppHeaderState();
}

class _AppHeaderState extends State<AppHeader> with WindowListener {
  bool _isMaximized = false;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  @override
  void onWindowMaximize() {
    if (mounted) setState(() => _isMaximized = true);
  }

  @override
  void onWindowUnmaximize() {
    if (mounted) setState(() => _isMaximized = false);
  }

  void _handleMinimize() {
    windowManager.minimize();
  }

  void _handleMaximizeToggle() {
    if (_isMaximized) {
      windowManager.unmaximize();
    } else {
      windowManager.maximize();
    }
  }

  void _handleClose() {
    windowManager.close();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: kAppHeaderHeight,
      decoration: const BoxDecoration(
        color: AppColors.background,
        border: Border(
          bottom: BorderSide(color: AppColors.border, width: 1.0),
        ),
      ),
      child: Row(
        children: [
          _buildBrand(),
          Expanded(
            child: DragToMoveArea(
              child: const SizedBox(
                height: kAppHeaderHeight,
                width: double.infinity,
              ),
            ),
          ),
          _buildWindowControls(),
        ],
      ),
    );
  }

  Widget _buildBrand() {
    return Padding(
      padding: const EdgeInsets.only(left: 12.0, right: 8.0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 22,
            height: 22,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(AppRadius.xs),
            ),
            child: Image.asset(
              'assets/images/icon.png',
              width: 16,
              height: 16,
            ),
          ),
          const SizedBox(width: 8),
          const Text(
            'Ponta DevStack',
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: AppTextSize.sm,
              color: AppColors.textPrimary,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWindowControls() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _WindowControlButton(
          icon: LucideIcons.minus,
          tooltip: 'Minimize',
          onTap: _handleMinimize,
        ),
        _WindowControlButton(
          icon: _isMaximized ? LucideIcons.copy : LucideIcons.square,
          tooltip: _isMaximized ? 'Restore' : 'Maximize',
          iconSize: _isMaximized ? 12.0 : 13.0,
          onTap: _handleMaximizeToggle,
        ),
        _WindowControlButton(
          icon: LucideIcons.x,
          tooltip: 'Close',
          isClose: true,
          onTap: _handleClose,
        ),
      ],
    );
  }
}

class _WindowControlButton extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool isClose;
  final double iconSize;

  const _WindowControlButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.isClose = false,
    this.iconSize = 14.0,
  });

  @override
  State<_WindowControlButton> createState() => _WindowControlButtonState();
}

class _WindowControlButtonState extends State<_WindowControlButton> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    final bgColor = _isHovering
        ? (widget.isClose ? AppColors.error : AppColors.surfaceLight)
        : Colors.transparent;

    final iconColor = _isHovering
        ? (widget.isClose ? AppColors.textOnColor : AppColors.textPrimary)
        : AppColors.textSecondary;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: Tooltip(
        message: widget.tooltip,
        waitDuration: const Duration(milliseconds: 600),
        child: Material(
          color: bgColor,
          child: InkWell(
            onTap: widget.onTap,
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
            child: SizedBox(
              width: kWindowCaptionButtonWidth,
              height: kAppHeaderHeight,
              child: Center(
                child: Icon(
                  widget.icon,
                  size: widget.iconSize,
                  color: iconColor,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run unit tests to verify they pass**

Run: `flutter test test/shared/app_header_test.dart`
Expected: 5 tests pass.

- [ ] **Step 5: Run static analysis**

Run: `flutter analyze lib/shared/layouts/app_header.dart test/shared/app_header_test.dart`
Expected: No issues found!

- [ ] **Step 6: Commit**

```bash
git add lib/shared/layouts/app_header.dart test/shared/app_header_test.dart
git commit -m "feat(ui): add custom AppHeader widget with window controls and unit tests"
```

---

### Task 2: Refactor `Sidebar` to Remove Redundant Logo Block

**Files:**
- Modify: `lib/shared/layouts/sidebar.dart:10-40,65-115`
- Test: `test/widget_test.dart`

**Interfaces:**
- Consumes:
  - Existing `Sidebar` consumers in `lib/main.dart`
- Produces:
  - `class Sidebar extends ConsumerWidget` (logo-free, list padding adjusted)

- [ ] **Step 1: Check existing sidebar implementation**

Read lines 15-50 of `lib/shared/layouts/sidebar.dart` to verify current `_buildLogo()` and padding structure.

- [ ] **Step 2: Modify `lib/shared/layouts/sidebar.dart`**

Remove `_buildLogo()` method and its surrounding `SizedBox` spacers in `Column.children`. Change the `ListView` padding to `EdgeInsets.symmetric(horizontal: 16, vertical: 12)`.

```dart
// In lib/shared/layouts/sidebar.dart:
// Replace Column(children: [ const SizedBox(height: 24), _buildLogo(), const SizedBox(height: 32), Expanded(...) ])
// With:
    return Container(
      width: 240,
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border(right: BorderSide(color: AppColors.border)),
      ),
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          _buildNavItem(
            LucideIcons.layoutGrid,
            'Apps',
            isActive: currentTab == NavigationTab.apps,
            onTap: () => ref
                .read(navigationProvider.notifier)
                .setTab(NavigationTab.apps),
          ),
          _buildNavItem(
            LucideIcons.globe,
            'Sites',
            isActive: currentTab == NavigationTab.sites,
            onTap: () => ref
                .read(navigationProvider.notifier)
                .setTab(NavigationTab.sites),
          ),
          _buildNavItem(
            LucideIcons.database,
            'Databases',
            isActive: currentTab == NavigationTab.databases,
            onTap: () => ref
                .read(navigationProvider.notifier)
                .setTab(NavigationTab.databases),
          ),
          _buildNavItem(
            LucideIcons.radio,
            'Tunnels',
            isActive: currentTab == NavigationTab.tunnels,
            onTap: () => ref
                .read(navigationProvider.notifier)
                .setTab(NavigationTab.tunnels),
          ),
          _buildNavItem(
            LucideIcons.terminal,
            'Logs',
            isActive: currentTab == NavigationTab.logs,
            onTap: () => ref
                .read(navigationProvider.notifier)
                .setTab(NavigationTab.logs),
          ),
          _buildNavItem(
            LucideIcons.fileText,
            'Hosts',
            isActive: currentTab == NavigationTab.hosts,
            onTap: () => ref
                .read(navigationProvider.notifier)
                .setTab(NavigationTab.hosts),
          ),
          _buildNavItem(
            LucideIcons.settings,
            'Settings',
            isActive: currentTab == NavigationTab.settings,
            onTap: () => ref
                .read(navigationProvider.notifier)
                .setTab(NavigationTab.settings),
          ),
        ],
      ),
    );
```

Delete the private helper `Widget _buildLogo()` entirely.

- [ ] **Step 3: Run static analysis and widget test**

Run: `flutter analyze lib/shared/layouts/sidebar.dart`
Run: `flutter test test/widget_test.dart`
Expected: PASS, 0 issues.

- [ ] **Step 4: Commit**

```bash
git add lib/shared/layouts/sidebar.dart
git commit -m "refactor(ui): remove redundant logo block from sidebar"
```

---

### Task 3: Integrate `AppHeader` and `VirtualWindowFrameInit` in `lib/main.dart`

**Files:**
- Modify: `lib/main.dart:50-95,145-165`
- Test: `test/widget_test.dart`
- Test: `test/shared/app_header_test.dart`

**Interfaces:**
- Consumes:
  - `VirtualWindowFrameInit()` from `package:window_manager/window_manager.dart`
  - `AppHeader` from `lib/shared/layouts/app_header.dart`
  - `TitleBarStyle.hidden` from `package:window_manager/window_manager.dart`
- Produces:
  - Frameless `WindowOptions`
  - Full-width `AppHeader` mounted above `Row(Sidebar(), content)`
  - `builder: VirtualWindowFrameInit()` registered on `MaterialApp`

- [ ] **Step 1: Update `WindowOptions` in `lib/main.dart`**

Change `titleBarStyle: TitleBarStyle.normal` to:
```dart
    titleBarStyle: TitleBarStyle.hidden,
    windowButtonVisibility: false,
```

- [ ] **Step 2: Update `MyApp.build` in `lib/main.dart`**

Add import `'package:window_manager/window_manager.dart';` (already present) and register `builder`:
```dart
class MyApp extends StatelessWidget {
  final String appVersion;
  const MyApp({super.key, required this.appVersion});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ponta DevStack v$appVersion',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      builder: VirtualWindowFrameInit(),
      home: const MainScreen(),
    );
  }
}
```

- [ ] **Step 3: Update `MainScreen.build` in `lib/main.dart`**

Import `shared/layouts/app_header.dart`. Modify the `Scaffold` body:
```dart
    return Scaffold(
      body: Column(
        children: [
          const AppHeader(),
          Expanded(
            child: Row(
              children: [
                const Sidebar(),
                Expanded(child: _buildPage(currentTab)),
              ],
            ),
          ),
        ],
      ),
    );
```

- [ ] **Step 4: Run tests and static analysis**

Run: `flutter analyze lib/main.dart`
Run: `flutter test test/widget_test.dart test/shared/app_header_test.dart`
Expected: PASS, 0 issues.

- [ ] **Step 5: Commit**

```bash
git add lib/main.dart
git commit -m "feat(ui): mount AppHeader and register VirtualWindowFrameInit in main.dart"
```

---

### Task 4: Strip `GtkHeaderBar` in Linux Runner & Synchronize Windows Title

**Files:**
- Modify: `linux/runner/my_application.cc:55-80`
- Modify: `windows/runner/main.cpp:55-65`
- Modify: `docs/linux-support-notes.md`

**Interfaces:**
- Consumes: GTK3 window APIs in `linux/runner/my_application.cc`, Win32 API in `windows/runner/main.cpp`
- Produces: Undecorated GtkWindow on Linux from creation; synchronized Win32 window title `Ponta DevStack`

- [ ] **Step 1: Modify `linux/runner/my_application.cc`**

Locate the `use_header_bar` block in `my_application_activate`:

```cpp
  // Use a header bar when running in GNOME as this is the common style used
  // by applications and is the setup most users will be using (e.g. Ubuntu
  // desktop).
  // If running on X and not using GNOME then just use a traditional title bar
  // in case the window manager does more exotic layout, e.g. tiling.
  // If running on Wayland assume the header bar will work (may need changing
  // if future cases occur).
  gboolean use_header_bar = TRUE;
#ifdef GDK_WINDOWING_X11
  GdkScreen* screen = gtk_window_get_screen(window);
  if (GDK_IS_X11_SCREEN(screen)) {
    const gchar* wm_name = gdk_x11_screen_get_window_manager_name(screen);
    if (g_strcmp0(wm_name, "GNOME Shell") != 0) {
      use_header_bar = FALSE;
    }
  }
#endif
  if (use_header_bar) {
    auto* header_bar = GTK_HEADER_BAR(gtk_header_bar_new());
    gtk_widget_show(GTK_WIDGET(header_bar));
    gtk_header_bar_set_title(header_bar, "Ponta DevStack");
    gtk_header_bar_set_show_close_button(header_bar, TRUE);
    gtk_window_set_titlebar(window, GTK_WIDGET(header_bar));
  }
```

Replace the entire block with a comment explaining that the window is undecorated and uses Flutter-side custom chrome:

```cpp
  // The application renders its own cross-platform header bar in Flutter
  // (AppHeader) and initializes frameless via window_manager. We intentionally
  // do not attach a GtkHeaderBar here to avoid a native titlebar flashing on
  // first frame before Dart hides it.
```

Keep `gtk_window_set_title(window, "Ponta DevStack");` intact so task switchers and compositors keep the correct title.

- [ ] **Step 2: Modify `windows/runner/main.cpp`**

In `wWinMain`, change:
```cpp
  if (!window.Create(L"dev_stack", origin, size)) {
```
to:
```cpp
  if (!window.Create(L"Ponta DevStack", origin, size)) {
```

- [ ] **Step 3: Document the change in `docs/linux-support-notes.md`**

Append a subsection under `## Runtime limitations`:

```markdown
### Window Chrome & Frameless Titlebar
- As of 2026-09-22, DevStack uses a Flutter-rendered custom header (`AppHeader`)
  across all platforms.
- `linux/runner/my_application.cc` no longer creates a `GtkHeaderBar` on startup.
- If native window decorations are required for troubleshooting on a specific
  compositor, revert the `use_header_bar` block in `my_application.cc` and set
  `titleBarStyle: TitleBarStyle.normal` in `lib/main.dart`.
```

- [ ] **Step 4: Verify C++ syntax with dry run compile check**

Run: `git diff linux/runner/my_application.cc windows/runner/main.cpp`
Ensure no stray brackets or malformed directives.

- [ ] **Step 5: Commit**

```bash
git add linux/runner/my_application.cc windows/runner/main.cpp docs/linux-support-notes.md
git commit -m "feat(desktop): remove GtkHeaderBar on Linux and sync Win32 window title"
```

---

### Task 5: Full Regression & Manual Wayland Verification

**Files:**
- Test: All test suites (`flutter test`)
- Analyze: Whole repo (`flutter analyze`)

**Interfaces:**
- Verifies all components working cohesively.

- [ ] **Step 1: Run full automated test suite**

Run: `flutter test`
Expected: All existing tests pass (including tunnel tests, site tests, theme token tests, and the new `app_header_test.dart`).

- [ ] **Step 2: Run full codebase static analysis**

Run: `flutter analyze`
Expected: `No issues found!`.

- [ ] **Step 3: Manual Wayland verification (on this machine)**

Run: `flutter run -d linux` (or launch built binary) in a separate terminal.
Verify:
1. Window launches without an OS titlebar or GtkHeaderBar.
2. AppHeader is visible at the top with icon and "Ponta DevStack".
3. Left-click and drag in the middle region moves the window smoothly across Wayland display.
4. Double-clicking the middle region toggles maximize/unmaximize.
5. Control buttons:
   - Hover on `−` shows tooltip "Minimize", click minimizes.
   - Hover on `□` shows tooltip "Maximize", click maximizes, icon changes to copy/restore glyph.
   - Click copy/restore returns window to normal size.
   - Hover on `✕` turns red with white icon, click invokes close handler (hiding to tray if `minimizeToTray` is true, or exiting gracefully).
6. 4 outer edges and corners allow resizing the window when not maximized.

- [ ] **Step 4: Update today's journal in `.remember/`**

Document the completed custom header implementation and the manual Wayland verification findings.
