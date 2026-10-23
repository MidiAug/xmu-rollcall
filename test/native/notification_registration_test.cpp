#include <windows.h>
#include <shlobj.h>
#include <propkey.h>
#include <wrl/client.h>

#include <filesystem>
#include <iostream>
#include <stdexcept>
#include <string>

#include "../../windows/runner/notification_registration.h"

using Microsoft::WRL::ComPtr;

namespace {
void Require(bool condition, const char* message) {
  if (!condition) throw std::runtime_error(message);
}

ComPtr<IShellLinkW> LoadLink(const std::wstring& path) {
  ComPtr<IShellLinkW> link;
  Require(SUCCEEDED(CoCreateInstance(CLSID_ShellLink, nullptr,
      CLSCTX_INPROC_SERVER, IID_PPV_ARGS(&link))), "create shell link");
  ComPtr<IPersistFile> file;
  Require(SUCCEEDED(link.As(&file)), "link persistence");
  Require(SUCCEEDED(file->Load(path.c_str(), STGM_READ)), "load shortcut");
  return link;
}

void CreateLink(const std::wstring& path, const std::wstring& target) {
  ComPtr<IShellLinkW> link;
  Require(SUCCEEDED(CoCreateInstance(CLSID_ShellLink, nullptr,
      CLSCTX_INPROC_SERVER, IID_PPV_ARGS(&link))), "create shell link");
  Require(SUCCEEDED(link->SetPath(target.c_str())), "set target");
  Require(SUCCEEDED(link->SetArguments(L"--preserve-this")), "set arguments");
  ComPtr<IPersistFile> file;
  Require(SUCCEEDED(link.As(&file)), "link persistence");
  Require(SUCCEEDED(file->Save(path.c_str(), TRUE)), "save shortcut");
}

struct Fixture {
  xmu::NotificationIdentity identity = xmu::CurrentNotificationIdentity();
  std::wstring shortcut = (std::filesystem::path(identity.executable).parent_path() /
      (L"测试入口-" + std::to_wstring(GetCurrentProcessId()) + L".lnk")).wstring();
  ~Fixture() { DeleteFileW(shortcut.c_str()); }
};

void TestShortcutIdentity() {
  Fixture f;
  Require(FAILED(xmu::StampOwnedNotificationShortcut(f.identity, f.shortcut)),
          "do not create missing shortcuts");
  CreateLink(f.shortcut, f.identity.executable);
  auto invalid = f.identity;
  invalid.activator = L"invalid GUID";
  Require(FAILED(xmu::StampOwnedNotificationShortcut(invalid, f.shortcut)),
          "reject invalid activator");
  Require(xmu::StampOwnedNotificationShortcut(f.identity, f.shortcut) == S_OK,
          "stamp owned shortcut");
  auto link = LoadLink(f.shortcut);
  ComPtr<IPropertyStore> properties;
  Require(SUCCEEDED(link.As(&properties)), "shortcut properties");
  PROPVARIANT value{};
  Require(SUCCEEDED(properties->GetValue(PKEY_AppUserModel_ID, &value)) &&
      value.vt == VT_LPWSTR && std::wstring(value.pwszVal) == f.identity.app_id,
      "shortcut AppID matches sender");
  PropVariantClear(&value);
  CLSID clsid{};
  CLSIDFromString(f.identity.activator.c_str(), &clsid);
  Require(SUCCEEDED(properties->GetValue(PKEY_AppUserModel_ToastActivatorCLSID,
                                          &value)) && value.vt == VT_CLSID &&
      *value.puuid == clsid, "shortcut activation CLSID");
  PropVariantClear(&value);
  wchar_t args[256]{};
  link->GetArguments(args, ARRAYSIZE(args));
  Require(std::wstring(args) == L"--preserve-this", "preserve shortcut arguments");
  wchar_t icon[32768]{};
  int icon_index = -1;
  link->GetIconLocation(icon, ARRAYSIZE(icon), &icon_index);
  Require(std::wstring(icon) == f.identity.executable && icon_index == 0,
          "shortcut uses executable icon");
  link.Reset();
  properties.Reset();
  Require(xmu::StampOwnedNotificationShortcut(f.identity, f.shortcut) == S_OK,
          "repeat registration remains usable");
  const auto original = f.identity.executable;
  f.identity.executable += L".different-build.exe";
  Require(xmu::StampOwnedNotificationShortcut(f.identity, f.shortcut) == S_FALSE,
          "never retarget another build's shortcut");
  link = LoadLink(f.shortcut);
  wchar_t target[32768]{};
  link->GetPath(target, ARRAYSIZE(target), nullptr, SLGP_RAWPATH);
  Require(std::wstring(target) == original, "foreign target unchanged");
  std::cout << "PASS: shortcut AppID, activator, icon, arguments, ownership, Unicode and spaced paths\n";
}
}  // namespace

int wmain() {
  if (FAILED(CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED))) return 1;
  int result = 0;
  try { TestShortcutIdentity(); }
  catch (const std::exception& error) { std::cerr << error.what() << '\n'; result = 1; }
  CoUninitialize();
  return result;
}
