#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>
#include <shobjidl.h>

#include "flutter_window.h"
#include "notification_registration.h"
#include "utils.h"

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  // Use the same identity as the notification sender before creating any UI.
  // Otherwise Windows may resolve the small header icon from an inferred ID.
  if (FAILED(::SetCurrentProcessExplicitAppUserModelID(xmu::kNotificationAppId))) {
    ::OutputDebugStringW(L"Could not set xmu-rollcall AppUserModelID.\n");
  }

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  const bool register_only = command_line_arguments.size() == 1 &&
      command_line_arguments.front() == "--register-notifications";
  const auto registered = xmu::StampCurrentNotificationShortcuts(register_only);
  if (register_only) {
    ::CoUninitialize();
    return SUCCEEDED(registered) ? EXIT_SUCCESS : EXIT_FAILURE;
  }
  if (FAILED(registered)) {
    ::OutputDebugStringW(L"Could not configure notification shortcut identity.\n");
  }

  flutter::DartProject project(L"data");

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1280, 720);
  if (!window.Create(L"厦大签到", origin, size)) {
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
