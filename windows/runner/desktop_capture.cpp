#include "desktop_capture.h"
#include <dwmapi.h>
#include <windowsx.h>
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>
#include <algorithm>
#include <optional>
#include <vector>

namespace {
using Value = flutter::EncodableValue;
using Map = flutter::EncodableMap;
HWND main_window = nullptr;

// This plugin contains no UI. Flutter owns and paints the separate scan window.
class DesktopCapture : public flutter::Plugin {
 public:
  DesktopCapture(flutter::PluginRegistrarWindows* registrar, bool primary)
      : registrar_(registrar), root_(GetAncestor(registrar->GetView()->GetNativeWindow(), GA_ROOT)) {
    if (primary) main_window = root_;
    channel_ = std::make_unique<flutter::MethodChannel<Value>>(registrar->messenger(),
        "xmu_rollcall/desktop_capture", &flutter::StandardMethodCodec::GetInstance());
    channel_->SetMethodCallHandler([this](const auto& call, auto result) {
      if (call.method_name() == "configure") {
        Configure();
        result->Success();
      } else if (call.method_name() == "capture") {
        Capture(call.arguments(), std::move(result));
      } else if (call.method_name() == "startDrag") {
        // Windows owns the cursor/window offset throughout the modal move loop.
        // Flutter-local deltas change as the window moves and feed back jitter.
        ReleaseCapture();
        SendMessage(root_, WM_SYSCOMMAND, SC_MOVE | HTCAPTION, 0);
        result->Success();
      } else if (call.method_name() == "show") {
        ShowWindow(root_, SW_SHOWNORMAL);
        SetForegroundWindow(root_);
        result->Success();
      } else if (call.method_name() == "hide") {
        ShowWindow(root_, SW_HIDE);
        result->Success();
      } else {
        result->NotImplemented();
      }
    });
    delegate_ = registrar_->RegisterTopLevelWindowProcDelegate(
        [this](HWND window, UINT message, WPARAM w, LPARAM l) -> std::optional<LRESULT> {
      if (window != root_ || !configured_) return std::nullopt;
      if (message == WM_CLOSE) {
        channel_->InvokeMethod("closeRequested", nullptr);
        return 0;
      }
      if (message == WM_NCCALCSIZE) return 0;
      if (message == WM_ENTERSIZEMOVE || message == WM_EXITSIZEMOVE) {
        moving_ = message == WM_ENTERSIZEMOVE;
        channel_->InvokeMethod("interactionChanged", std::make_unique<Value>(moving_));
      }
      if (message == WM_GETMINMAXINFO) {
        const double scale = GetDpiForWindow(root_) / 96.0;
        auto* limits = reinterpret_cast<MINMAXINFO*>(l);
        limits->ptMinTrackSize = POINT{static_cast<LONG>(340 * scale), static_cast<LONG>(420 * scale)};
        limits->ptMaxTrackSize = POINT{static_cast<LONG>(1000 * scale), static_cast<LONG>(1100 * scale)};
        return 0;
      }
      if (message == WM_NCHITTEST) {
        POINT point{GET_X_LPARAM(l), GET_Y_LPARAM(l)};
        ScreenToClient(root_, &point);
        RECT client{};
        GetClientRect(root_, &client);
        const int edge = MulDiv(7, GetDpiForWindow(root_), 96);
        if (point.x < edge && point.y < edge) return HTTOPLEFT;
        if (point.x >= client.right - edge && point.y < edge) return HTTOPRIGHT;
        if (point.x < edge && point.y >= client.bottom - edge) return HTBOTTOMLEFT;
        if (point.x >= client.right - edge && point.y >= client.bottom - edge) return HTBOTTOMRIGHT;
        if (point.x < edge) return HTLEFT;
        if (point.x >= client.right - edge) return HTRIGHT;
        if (point.y < edge) return HTTOP;
        if (point.y >= client.bottom - edge) return HTBOTTOM;
      }
      return std::nullopt;
    });
  }
  ~DesktopCapture() override { registrar_->UnregisterTopLevelWindowProcDelegate(delegate_); }

 private:
  void Configure() {
    configured_ = true;
    SetWindowTextW(root_, L"厦大签到 · 扫码签到");
    LONG_PTR style = GetWindowLongPtr(root_, GWL_STYLE);
    SetWindowLongPtr(root_, GWL_STYLE, (style & ~(WS_CAPTION | WS_MAXIMIZEBOX | WS_MINIMIZEBOX)) | WS_THICKFRAME);
    SetWindowLongPtr(root_, GWL_EXSTYLE, (GetWindowLongPtr(root_, GWL_EXSTYLE) & ~WS_EX_TOOLWINDOW) | WS_EX_APPWINDOW);
    // DWM composes the Flutter engine's transparent pixels against the desktop.
    HRGN region = CreateRectRgn(0, 0, -1, -1);
    DWM_BLURBEHIND blur{};
    blur.dwFlags = DWM_BB_ENABLE | DWM_BB_BLURREGION;
    blur.fEnable = TRUE;
    blur.hRgnBlur = region;
    DwmEnableBlurBehindWindow(root_, &blur);
    DeleteObject(region);
    const double scale = GetDpiForWindow(root_) / 96.0;
    const int width = static_cast<int>(420 * scale), height = static_cast<int>(548 * scale);
    RECT parent{};
    GetWindowRect(main_window ? main_window : root_, &parent);
    MONITORINFO monitor{};
    monitor.cbSize = sizeof(monitor);
    GetMonitorInfo(MonitorFromWindow(main_window ? main_window : root_, MONITOR_DEFAULTTONEAREST), &monitor);
    const int x = std::clamp(static_cast<int>(parent.right) - width / 2,
        static_cast<int>(monitor.rcWork.left), std::max(static_cast<int>(monitor.rcWork.left), static_cast<int>(monitor.rcWork.right) - width));
    const int y = std::max(static_cast<int>(monitor.rcWork.top), (static_cast<int>(monitor.rcWork.top + monitor.rcWork.bottom) - height) / 2);
    SetWindowPos(root_, HWND_TOPMOST, x, y, width, height, SWP_FRAMECHANGED | SWP_NOACTIVATE);
  }

  void Capture(const Value* arguments, std::unique_ptr<flutter::MethodResult<Value>> result) {
    if (!configured_ || moving_ || !IsWindowVisible(root_) || IsIconic(root_) || !arguments || !std::holds_alternative<Map>(*arguments)) {
      result->Success();
      return;
    }
    const auto& args = std::get<Map>(*arguments);
    const double scale = GetDpiForWindow(root_) / 96.0;
    auto number = [&](const char* key) { return std::get<double>(args.at(Value(key))); };
    const int width = static_cast<int>(number("width") * scale);
    const int height = static_cast<int>(number("height") * scale);
    POINT point{static_cast<LONG>(number("x") * scale), static_cast<LONG>(number("y") * scale)};
    RECT client{};
    GetClientRect(root_, &client);
    if (width <= 0 || height <= 0 || width > 2048 || height > 2048 || point.x < 0 || point.y < 0 || point.x + width > client.right || point.y + height > client.bottom) {
      result->Error("invalid_region", "识别区域超出窗口范围");
      return;
    }
    ClientToScreen(root_, &point);
    HDC screen = GetDC(nullptr);
    HDC memory = CreateCompatibleDC(screen);
    BITMAPINFO bitmap{};
    bitmap.bmiHeader.biSize = sizeof(BITMAPINFOHEADER);
    bitmap.bmiHeader.biWidth = width;
    bitmap.bmiHeader.biHeight = -height;
    bitmap.bmiHeader.biPlanes = 1;
    bitmap.bmiHeader.biBitCount = 32;
    void* pixels = nullptr;
    HBITMAP dib = CreateDIBSection(screen, &bitmap, DIB_RGB_COLORS, &pixels, nullptr, 0);
    bool captured = false;
    std::vector<uint8_t> bytes;
    if (dib && pixels && memory) {
      HGDIOBJ old = SelectObject(memory, dib);
      if (BitBlt(memory, 0, 0, width, height, screen, point.x, point.y, SRCCOPY | CAPTUREBLT)) {
        GdiFlush();
        const auto* begin = static_cast<const uint8_t*>(pixels);
        bytes.assign(begin, begin + static_cast<size_t>(width) * height * 4);
        captured = true;
      }
      SelectObject(memory, old);
    }
    if (dib) DeleteObject(dib);
    if (memory) DeleteDC(memory);
    ReleaseDC(nullptr, screen);
    if (captured) result->Success(Value(Map{{Value("width"), Value(width)}, {Value("height"), Value(height)}, {Value("bgra"), Value(std::move(bytes))}}));
    else result->Error("capture_failed", "无法读取屏幕区域");
  }

  flutter::PluginRegistrarWindows* registrar_;
  HWND root_;
  int delegate_ = -1;
  bool configured_ = false;
  bool moving_ = false;
  std::unique_ptr<flutter::MethodChannel<Value>> channel_;
};
}  // namespace

void RegisterDesktopCapture(FlutterDesktopPluginRegistrarRef registrar, bool primary) {
  auto* windows = flutter::PluginRegistrarManager::GetInstance()->GetRegistrar<flutter::PluginRegistrarWindows>(registrar);
  windows->AddPlugin(std::make_unique<DesktopCapture>(windows, primary));
}
