#ifndef RUNNER_FLUTTER_WINDOW_H_
#define RUNNER_FLUTTER_WINDOW_H_

#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>

#include <memory>

#include "win32_window.h"

// A window that does nothing but host a Flutter view.
class FlutterWindow : public Win32Window {
 public:
  // Creates a new FlutterWindow hosting a Flutter view running |project|.
  explicit FlutterWindow(const flutter::DartProject& project);
  virtual ~FlutterWindow();

  // When false, the window is created but not shown on the first Flutter
  // frame (used for `--minimized` auto-start).
  void set_show_on_first_frame(bool value) { show_on_first_frame_ = value; }

 protected:
  // Win32Window:
  bool OnCreate() override;
  void OnDestroy() override;
  LRESULT MessageHandler(HWND window, UINT const message, WPARAM const wparam,
                         LPARAM const lparam) noexcept override;

 private:
  // The project to run.
  flutter::DartProject project_;

  // The Flutter instance hosted by this window.
  std::unique_ptr<flutter::FlutterViewController> flutter_controller_;

  // False when `--minimized` was passed (auto-start): the first frame must not
  // present the window, which would pop it over the user's work. The tray icon
  // is what the user clicks to bring it back.
  bool show_on_first_frame_ = true;
};

#endif  // RUNNER_FLUTTER_WINDOW_H_
