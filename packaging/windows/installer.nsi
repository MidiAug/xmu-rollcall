; xmu-rollcall Windows NSIS installer (current-user, no publisher cert).
; Align with xmu-sports: program dir under %LOCALAPPDATA%\Programs\...
;
; Build via scripts\package-windows.ps1 which passes:
;   /DPRODUCT_VERSION=0.1.0
;   /DRELEASE_DIR=...\build\windows\x64\runner\Release
;   /DOUT_FILE=...\dist\xmu-rollcall-0.1.0-windows-x64-setup.exe

Unicode true
ManifestDPIAware true

!ifndef PRODUCT_VERSION
  !define PRODUCT_VERSION "0.1.0"
!endif
!ifndef RELEASE_DIR
  !error "RELEASE_DIR must be defined (Flutter Release folder)"
!endif
!ifndef OUT_FILE
  !error "OUT_FILE must be defined"
!endif

!define PRODUCT_NAME "厦大签到"
!define PRODUCT_FOLDER "xmu-rollcall"
!define MAIN_EXE "xmu_rollcall.exe"
!define UNINST_KEY "Software\Microsoft\Windows\CurrentVersion\Uninstall\${PRODUCT_FOLDER}"

Name "${PRODUCT_NAME}"
OutFile "${OUT_FILE}"
InstallDir "$LOCALAPPDATA\Programs\${PRODUCT_FOLDER}"
RequestExecutionLevel user
SetCompressor /SOLID lzma

!include "MUI2.nsh"
!include "LogicLib.nsh"

!define MUI_ABORTWARNING
!ifdef INSTALLER_ICON
  !define MUI_ICON "${INSTALLER_ICON}"
  !define MUI_UNICON "${INSTALLER_ICON}"
!endif

!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES
!insertmacro MUI_LANGUAGE "SimpChinese"
!insertmacro MUI_LANGUAGE "English"

VIProductVersion "${PRODUCT_VERSION}.0"
VIAddVersionKey /LANG=${LANG_ENGLISH} "ProductName" "${PRODUCT_NAME}"
VIAddVersionKey /LANG=${LANG_ENGLISH} "FileDescription" "${PRODUCT_NAME}"
VIAddVersionKey /LANG=${LANG_ENGLISH} "LegalCopyright" "xmu-rollcall"
VIAddVersionKey /LANG=${LANG_ENGLISH} "FileVersion" "${PRODUCT_VERSION}"
VIAddVersionKey /LANG=${LANG_ENGLISH} "ProductVersion" "${PRODUCT_VERSION}"

Function .onInit
  FindWindow $0 "FLUTTER_RUNNER_WIN32_WINDOW" "${PRODUCT_NAME}"
  ${If} $0 != 0
    MessageBox MB_OK|MB_ICONEXCLAMATION "请先从窗口或系统托盘退出厦大签到，再运行安装程序。" /SD IDOK
    Abort
  ${EndIf}
FunctionEnd

Section "Install"
  SetOutPath "$INSTDIR"

  ; Replace owned files in place; do not erase the chosen directory.
  ; Repair shortcuts created by pre-UTF-8 installer builds.
  ReadRegStr $0 HKCU "${UNINST_KEY}" "DisplayName"
  ${If} $0 == "鍘﹀ぇ绛惧埌"
    Delete "$DESKTOP\$0.lnk"
    Delete "$SMPROGRAMS\$0\$0.lnk"
    Delete "$SMPROGRAMS\$0\Uninstall.lnk"
    RMDir "$SMPROGRAMS\$0"
  ${EndIf}

  SetOutPath "$INSTDIR"
  File /r "${RELEASE_DIR}\*.*"

  WriteUninstaller "$INSTDIR\Uninstall.exe"

  CreateDirectory "$SMPROGRAMS\${PRODUCT_NAME}"
  CreateShortCut "$SMPROGRAMS\${PRODUCT_NAME}\${PRODUCT_NAME}.lnk" "$INSTDIR\${MAIN_EXE}"
  CreateShortCut "$SMPROGRAMS\${PRODUCT_NAME}\Uninstall.lnk" "$INSTDIR\Uninstall.exe"
  CreateShortCut "$DESKTOP\${PRODUCT_NAME}.lnk" "$INSTDIR\${MAIN_EXE}"

  WriteRegStr HKCU "${UNINST_KEY}" "DisplayName" "${PRODUCT_NAME}"
  WriteRegStr HKCU "${UNINST_KEY}" "DisplayVersion" "${PRODUCT_VERSION}"
  WriteRegStr HKCU "${UNINST_KEY}" "Publisher" "xmu-rollcall"
  WriteRegStr HKCU "${UNINST_KEY}" "InstallLocation" "$INSTDIR"
  WriteRegStr HKCU "${UNINST_KEY}" "DisplayIcon" "$INSTDIR\${MAIN_EXE}"
  WriteRegStr HKCU "${UNINST_KEY}" "UninstallString" '"$INSTDIR\Uninstall.exe"'
  WriteRegDWORD HKCU "${UNINST_KEY}" "NoModify" 1
  WriteRegDWORD HKCU "${UNINST_KEY}" "NoRepair" 1
SectionEnd

Section "Uninstall"
  Delete "$DESKTOP\${PRODUCT_NAME}.lnk"
  RMDir /r "$SMPROGRAMS\${PRODUCT_NAME}"
  RMDir /r "$INSTDIR"
  DeleteRegKey HKCU "${UNINST_KEY}"
SectionEnd
