#ifndef RUNNER_NOTIFICATION_REGISTRATION_H_
#define RUNNER_NOTIFICATION_REGISTRATION_H_

#include <windows.h>
#include <string>

namespace xmu {

inline constexpr wchar_t kNotificationAppId[] = L"cn.edu.xmu.rollcall";
inline constexpr wchar_t kNotificationActivator[] =
    L"{1a7ff90c-8c39-4cad-9d09-702731e97bba}";

struct NotificationIdentity {
  std::wstring app_id;
  std::wstring activator;
  std::wstring executable;
};

// Only update existing shortcuts targeting this executable. A debug/portable
// build must never create an entry or retarget the installed app's shortcut.
HRESULT StampOwnedNotificationShortcut(const NotificationIdentity& identity,
                                      const std::wstring& shortcut);
NotificationIdentity CurrentNotificationIdentity();
HRESULT StampCurrentNotificationShortcuts(bool require_start_shortcut);

}  // namespace xmu

#endif  // RUNNER_NOTIFICATION_REGISTRATION_H_
