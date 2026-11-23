# README 预览维护

这些图片来自当前 Flutter 页面和虚构的课程、姓名、成绩数据。`android-homework-native*.png` 在 Android 15 模拟器原生运行后，通过 ADB 截取设备屏幕，包含真实系统状态栏；其余手机图为 Windows 上的 Android 布局组件渲染，桌面图包括完整壳层和单页组件渲染。

在 Windows 完成锁文件依赖安装后运行：

```powershell
pwsh -File scripts/capture-readme.ps1
```

脚本使用项目 Flutter 入口、`--no-pub` 和现有 `CAPTURE_*` 开关，测试通过后才将选定 PNG 复制到本目录，结束时恢复工作目录和环境变量。生成时使用 Windows 本机字体，详见 [字体说明](../../test/fixtures/fonts/README.md)。中间图片保留在被忽略的 `build/` 和 `.tools/`，不整批提交。

| 图片 | 真实页面与生成入口 |
| --- | --- |
| `windows-rollcall.png`、`windows-history.png`、`windows-tools.png` | `desktop_workspace_test.dart`，完整 AdaptiveShell，1120 × 780 |
| `android-rollcall.png`、`android-rollcall-dark.png` | `mobile_campus_design_test.dart`，手机签到页及真实导航组件，390 × 844 |
| `android-homework.png`、`android-homework-dark.png`、`windows-homework.png` | `readme_preview_test.dart`，HomeworkHubPage；手机 390 × 844、桌面 1120 × 780 |
| `android-homework-native.png`、`android-homework-native-dark.png` | `tool/preview_homework.dart`，Android 15 模拟器原生运行，1080 × 2340；与组件测试共用 `test/fixtures/homework_preview.dart` 的数据与 Provider 替身 |
| `windows-gpa.png` | `gpa_page_test.dart`，GpaPage，960 × 1000 |

提交前逐张实看：没有真实身份或凭据，没有加载中/错误占位、调试横幅或失焦菜单；文案、导航、功能范围与当前源码一致。截图中的历史日期和测试课程是演示数据，不代表在线业务状态。功能范围与版本变化以根目录 [README](../../README.md) 和 [CHANGELOG](../../CHANGELOG.md) 为准。

## 原生手机作业图

组件测试的 `RenderRepaintBoundary.toImage()` 不包含 Android 系统合成层。需要完整手机屏幕时，使用独立 `.preview` 包运行生产作业页面，不在 Widget 测试里手绘时间、电池或通知栏。截图入口不启动真实账号，凭据使用内存存储，演示数据和普通组件测试共用。

在已连接的 Android 模拟器上运行以下命令，`<device-id>` 替换为 `adb devices` 的实际设备标识：

```powershell
$previousPreview = $env:XMU_ANDROID_PREVIEW
try {
    $env:XMU_ANDROID_PREVIEW = 'true'
    & D:/Dev/Flutter-xmu/bin/flutter.bat run --no-pub -d <device-id> -t tool/preview_homework.dart --no-resident
    python scripts/capture_android_preview.py --device <device-id> --output build/readme-preview/android-homework-native.png
    & D:/Dev/Flutter-xmu/bin/flutter.bat run --no-pub -d <device-id> -t tool/preview_homework.dart --no-resident --dart-define=PREVIEW_DARK=true
    python scripts/capture_android_preview.py --device <device-id> --output build/readme-preview/android-homework-native-dark.png
} finally {
    $env:XMU_ANDROID_PREVIEW = $previousPreview
}
```

使用手机纵向尺寸与合适密度，例如 1080 × 2340 / 443 dpi。不得拉伸横屏图冒充手机图。捕获脚本核对前台包，通过 Android 官方 SystemUI Demo 协议整理系统栏，然后 `adb exec-out screencap -p` 保存原始 PNG；完成或出错均退出 Demo 并恢复原设置。不同厂商可能不完整支持 Demo，必须实看通知图标，不能直接发布含私人通知的截图。实看通过后再复制两张 PNG 到本目录，更新网站构建。普通 `capture-readme.ps1` 不覆盖这两张原生图。

依据：[Flutter 截图范围](https://api.flutter.dev/flutter/rendering/RenderRepaintBoundary/toImage.html)、[Android 屏幕截图](https://developer.android.com/studio/debug/am-screenshot)、[AOSP Demo 协议](https://android.googlesource.com/platform/frameworks/base/+/android16-qpr1-release/packages/SystemUI/docs/demo_mode.md)。系统栏与页面原生渲染已核，不扩展为真实登录、通知、定位或课堂提交验收。
