#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <Windows.h>

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
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1280, 720);
  if (!window.Create(L"dev_stack", origin, size)) {
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
