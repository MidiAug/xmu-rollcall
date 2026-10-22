#include "flutter_window.h"

#include <optional>

#include "flutter/generated_plugin_registrant.h"
#include "desktop_capture.h"
#include <desktop_multi_window/desktop_multi_window_plugin.h>
#include <desktop_drop/desktop_drop_plugin.h>
#include <file_selector_windows/file_selector_windows.h>

namespace {

// Flutter Windows accessibility bridge desyncs on scroll / tab / tooltip
// (flutter/flutter#182444: "N will not be in the tree and is not the new root").
// Once WM_GETOBJECT activates the bridge, every semantics update can spam ERROR.
// Swallow probes so the native AXTree never comes up. Narrator/UIA will not see
// this window; fine for this utility until upstream is fixed.
constexpr UINT kWmGetObject = 0x003D;

WNDPROC g_flutter_view_proc = nullptr;

LRESULT CALLBACK FlutterViewProcGuard(HWND hwnd, UINT message, WPARAM wparam,
                                      LPARAM lparam) {
  if (message == kWmGetObject) {
    return 0;
  }
  return CallWindowProc(g_flutter_view_proc, hwnd, message, wparam, lparam);
}

}  // namespace

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  DesktopMultiWindowSetWindowCreatedCallback([](void* controller) {
    auto* view = reinterpret_cast<flutter::FlutterViewController*>(controller);
    // Only scanner dependencies: a secondary engine must not initialize tray,
    // account storage, background monitoring, or main-window window_manager.
    DesktopDropPluginRegisterWithRegistrar(view->engine()->GetRegistrarForPlugin("DesktopDropPlugin"));
    FileSelectorWindowsRegisterWithRegistrar(view->engine()->GetRegistrarForPlugin("FileSelectorWindows"));
    RegisterDesktopCapture(view->engine()->GetRegistrarForPlugin("XmuDesktopCapture"));
  });
  SetChildContent(flutter_controller_->view()->GetNativeWindow());
  RegisterDesktopCapture(flutter_controller_->engine()->GetRegistrarForPlugin("XmuDesktopCapture"), true);

  // Intercept MSAA/UIA on the Flutter view HWND (top-level alone is not enough).
  HWND view = flutter_controller_->view()->GetNativeWindow();
  g_flutter_view_proc = reinterpret_cast<WNDPROC>(SetWindowLongPtr(
      view, GWLP_WNDPROC, reinterpret_cast<LONG_PTR>(FlutterViewProcGuard)));

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }
  g_flutter_view_proc = nullptr;

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  if (message == kWmGetObject) {
    return 0;
  }

  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
