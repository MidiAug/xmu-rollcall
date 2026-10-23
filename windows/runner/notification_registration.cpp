#include "notification_registration.h"

#include <shlobj.h>
#include <propkey.h>
#include <propvarutil.h>
#include <wrl/client.h>

#include <filesystem>

namespace xmu {
using Microsoft::WRL::ComPtr;

HRESULT StampOwnedNotificationShortcut(const NotificationIdentity& identity,
                                      const std::wstring& shortcut) {
  CLSID activator{};
  auto hr = CLSIDFromString(identity.activator.c_str(), &activator);
  if (FAILED(hr)) return hr;
  if (identity.app_id.empty() || identity.executable.empty()) return E_INVALIDARG;
  ComPtr<IShellLinkW> link;
  hr = CoCreateInstance(CLSID_ShellLink, nullptr, CLSCTX_INPROC_SERVER,
                         IID_PPV_ARGS(&link));
  if (FAILED(hr)) return hr;
  ComPtr<IPersistFile> file;
  hr = link.As(&file);
  if (FAILED(hr)) return hr;
  hr = file->Load(shortcut.c_str(), STGM_READWRITE);
  if (FAILED(hr)) return hr;
  wchar_t target[32768]{};
  hr = link->GetPath(target, ARRAYSIZE(target), nullptr, SLGP_RAWPATH);
  if (FAILED(hr)) return hr;
  if (_wcsicmp(target, identity.executable.c_str()) != 0) return S_FALSE;

  ComPtr<IPropertyStore> properties;
  hr = link.As(&properties);
  if (FAILED(hr)) return hr;
  PROPVARIANT property{};
  hr = InitPropVariantFromString(identity.app_id.c_str(), &property);
  if (SUCCEEDED(hr)) hr = properties->SetValue(PKEY_AppUserModel_ID, property);
  PropVariantClear(&property);
  if (FAILED(hr)) return hr;
  hr = InitPropVariantFromCLSID(activator, &property);
  if (SUCCEEDED(hr)) {
    hr = properties->SetValue(PKEY_AppUserModel_ToastActivatorCLSID, property);
  }
  PropVariantClear(&property);
  if (FAILED(hr)) return hr;
  hr = properties->Commit();
  if (FAILED(hr)) return hr;
  hr = link->SetIconLocation(identity.executable.c_str(), 0);
  if (FAILED(hr)) return hr;
  return file->Save(shortcut.c_str(), TRUE);
}

NotificationIdentity CurrentNotificationIdentity() {
  wchar_t executable[32768]{};
  const auto length = GetModuleFileNameW(nullptr, executable, ARRAYSIZE(executable));
  if (length == 0 || length >= ARRAYSIZE(executable)) return {};
  return {kNotificationAppId, kNotificationActivator, executable};
}

HRESULT StampCurrentNotificationShortcuts(bool require_start_shortcut) {
  const auto identity = CurrentNotificationIdentity();
  PWSTR programs = nullptr;
  auto hr = SHGetKnownFolderPath(FOLDERID_Programs, KF_FLAG_DEFAULT, nullptr,
                                  &programs);
  if (FAILED(hr)) return hr;
  const auto shortcut = std::filesystem::path(programs) / L"厦大签到" /
                        L"厦大签到.lnk";
  CoTaskMemFree(programs);
  hr = StampOwnedNotificationShortcut(identity, shortcut.wstring());
  if (require_start_shortcut && hr != S_OK) {
    return FAILED(hr) ? hr : E_FAIL;
  }

  PWSTR desktop = nullptr;
  if (SUCCEEDED(SHGetKnownFolderPath(FOLDERID_Desktop, KF_FLAG_DEFAULT, nullptr,
                                    &desktop))) {
    const auto desktop_shortcut =
        std::filesystem::path(desktop) / L"厦大签到.lnk";
    CoTaskMemFree(desktop);
    StampOwnedNotificationShortcut(identity, desktop_shortcut.wstring());
  }
  return S_OK;
}

}  // namespace xmu
