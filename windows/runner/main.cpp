#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <flutter_windows.h>
#include <Windows.h>

#include <algorithm>

#include "flutter_window.h"
#include "utils.h"

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  // Single instance protection using a named mutex
  const wchar_t mutex_name[] = L"Ponta_DevStack_SingleInstance_Mutex";
  HANDLE hMutex = CreateMutex(NULL, TRUE, mutex_name);

  if (GetLastError() == ERROR_ALREADY_EXISTS) {
    // Another instance is already running
    HWND hWnd = FindWindow(L"FLUTTER_RUNNER_WIN32_WINDOW", nullptr);
    if (!hWnd) {
      hWnd = FindWindow(nullptr, L"DevStack Dashboard");
    }
    
    if (hWnd) {
      // Bring the existing window to front
      if (IsIconic(hWnd)) {
        ShowWindow(hWnd, SW_RESTORE);
      } else {
        ShowWindow(hWnd, SW_SHOW);
      }
      SetForegroundWindow(hWnd);
      SetFocus(hWnd);
      BringWindowToTop(hWnd);
    }
    ReleaseMutex(hMutex);
    CloseHandle(hMutex);
    return 0; // Exit this instance
  }
  (void)hMutex; // Suppress unused variable warning

  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  // The runner shows the window on the first frame; `--minimized` (auto-start
  // at login) must stay in the tray instead of popping over the user's work.
  for (const auto& argument : command_line_arguments) {
    if (argument == "--minimized") {
      window.set_show_on_first_frame(false);
      break;
    }
  }
  // The window is created at its final size and position: Dart no longer
  // resizes, centers, or shows it (see the comment in `lib/main.dart`), so
  // the runner has to create it right, or the first frame is drawn for the
  // wrong size and the window opens blank until a resize. The origin is
  // centered on the primary monitor's work area, in logical pixels — the
  // same units `Win32Window::Create` expects, so it can apply its DPI
  // scaling exactly as before. The origin is clamped to the work area so a
  // display smaller than the window cannot push it off-screen (Point takes
  // unsigned ints, so a negative offset would wrap).
  const int window_width = 1024;
  const int window_height = 640;
  HMONITOR monitor = MonitorFromPoint({0, 0}, MONITOR_DEFAULTTOPRIMARY);
  MONITORINFO monitor_info = {};
  monitor_info.cbSize = sizeof(monitor_info);
  GetMonitorInfo(monitor, &monitor_info);
  const RECT work_area = monitor_info.rcWork;
  const UINT dpi = FlutterDesktopGetDpiForMonitor(monitor);
  const double scale_factor = dpi / 96.0;
  const int work_width =
      static_cast<int>((work_area.right - work_area.left) / scale_factor);
  const int work_height =
      static_cast<int>((work_area.bottom - work_area.top) / scale_factor);
  const int work_left = static_cast<int>(work_area.left / scale_factor);
  const int work_top = static_cast<int>(work_area.top / scale_factor);
  Win32Window::Point origin(
      static_cast<unsigned int>(
          std::max(0, work_left + (work_width - window_width) / 2)),
      static_cast<unsigned int>(
          std::max(0, work_top + (work_height - window_height) / 2)));
  Win32Window::Size size(window_width, window_height);
  if (!window.Create(L"Ponta DevStack", origin, size)) {
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  return EXIT_SUCCESS;
}
