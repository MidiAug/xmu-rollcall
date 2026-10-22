<div align="center">

<img src="assets/icon/app_icon.png" width="88" alt="厦大签到图标" />

# 厦大签到

**上课看签到，下课看作业。**

一个给厦门大学畅课（TronClass）用的小客户端。手机随手查看，电脑也能用。

[![Flutter](https://img.shields.io/badge/Flutter-3.44-02569B?logo=flutter&logoColor=white)](https://flutter.dev/)
[![Platforms](https://img.shields.io/badge/平台-Android%20%2F%20Windows-5356FF)](#界面预览)
[![Checks](https://github.com/MidiAug/xmu-rollcall/actions/workflows/checks.yml/badge.svg)](https://github.com/MidiAug/xmu-rollcall/actions/workflows/checks.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-64748B)](LICENSE)

[看看界面](#界面预览) / [有什么功能](#日常会用到的) / [运行起来](#运行起来) / [反馈问题](https://github.com/MidiAug/xmu-rollcall/issues)

</div>

## 界面预览

用现有 Flutter 页面和演示数据渲染，展示手机与 Windows 布局；截图中的姓名、课程和作业状态均为虚构示例。

### Android

签到、作业、我的，常用入口放在底部。浅色和深色都可以选，也可以跟随系统。

<table>
  <tr>
    <th>浅色模式</th>
    <th>深色模式</th>
  </tr>
  <tr>
    <td align="center"><img src="assets/screenshots/android-homework.png" width="280" alt="Android 浅色作业页：进行中与已截止作业，以及提交和成绩状态" /></td>
    <td align="center"><img src="assets/screenshots/android-homework-dark.png" width="280" alt="Android 深色作业页演示" /></td>
  </tr>
</table>

### Windows

同一套账号和功能，换成适合电脑的侧栏布局。支持托盘驻留、系统通知和桌面二维码识别。

| 作业一眼看清 | 签到记录慢慢查 |
| :---: | :---: |
| ![Windows 作业页](assets/screenshots/windows-homework.png) | ![Windows 签到记录页](assets/screenshots/windows-history.png) |

点击图片可以查看大图。

## 日常会用到的

| 想做什么 | 这里可以 |
| --- | --- |
| **看看老师开没开签到** | 查看数字、雷达和二维码签到，复制数字码、确认位置或扫码提交。 |
| **翻翻之前的签到** | 按课程、状态、类型和最近 7 天 / 30 天筛选，筛选项旁边直接显示记录数。 |
| **今天还有什么作业** | 进行中和已截止分开展示，截止时间、提交情况、成绩状态放在同一行。助教课程单独展示。 |
| **看这学期的课** | 按当前身份展示本学期课表，不把入学以来的课程都搬出来。 |
| **切换协助身份** | 各身份的登录会话与缓存独立保存，签到和作业跟随所选身份。 |
| **少盯一会儿屏幕** | Android 后台提醒，Windows 通知与托盘；数字自动签到需要自行开启。 |

重新打开页面时，会优先显示已有缓存，再按需要更新。签到卡片在对应课堂的课前、课后各 25 分钟内恢复上次状态，并重新确认；作业按课后、截止和待办变化补查，避免来回切页就重扫所有课程。

## 运行起来

目前主要在 **Android 和 Windows** 上开发与验证。仓库也保留了 iOS、macOS、Linux 工程，但这些平台还没有完成完整实机验收。

准备 **Flutter 3.44.0 / Dart 3.12**，以及目标平台所需的开发工具：

```powershell
git clone https://github.com/MidiAug/xmu-rollcall.git
cd xmu-rollcall
flutter pub get

# 连接手机后，选择设备运行
flutter run

# 或者在 Windows 上运行
flutter run -d windows
```

使用厦大统一身份认证账号登录；遇到验证码时按页面提示处理。相机扫码需要相机权限，后台提醒需要允许通知，并按系统提示设置后台运行。

<details>
<summary><strong>自己打包、更新和跑测试</strong></summary>

### 构建安装包

```powershell
# Android APK
flutter build apk --release

# Windows
flutter build windows --release
```

也可以用项目脚本，产物会放到 `dist/`：

```powershell
# Android APK
powershell -ExecutionPolicy Bypass -File scripts/package-android.ps1

# Windows NSIS 安装包
powershell -ExecutionPolicy Bypass -File scripts/package-windows.ps1
```

Windows 构建需要 Visual Studio 的 C++ 桌面开发工具；安装包还需要 NSIS，打包脚本可在缺少 NSIS 时下载便携工具。

### 给手机覆盖更新

```powershell
powershell -ExecutionPolicy Bypass -File scripts/install-phone.ps1 -Mode release
```

脚本使用 `adb install -r` 保留登录和设置。更新时请沿用相同签名和构建模式；如果手机装的是 debug 版，参数也用 `-Mode debug`。

### 本地检查

```powershell
flutter analyze
flutter test
```

普通测试使用模拟数据；真实账号、设备权限和后台行为需要单独做实机检查。GitHub Actions 会在 Windows 和 Linux 上运行静态分析与单元、组件测试。

</details>

## 遇到问题了？

欢迎到 [Issues](https://github.com/MidiAug/xmu-rollcall/issues) 描述发生了什么，附上系统版本、操作步骤和截图会更容易定位。

应用里的“我的 → 数据与诊断”可以清理缓存、导出诊断日志。日志已做脱敏，分享前也请检查是否含有不想公开的个人信息；不要在 Issue 中提交账号密码、Cookie 或登录令牌。

账号凭据使用系统安全存储，课表、作业和签到缓存保存在本机。

## 感谢这些项目

开发时从这些项目中得到了不少帮助：

- [wilinz/tronclass_plus](https://github.com/wilinz/tronclass_plus)：Flutter 客户端架构、网络与位置交互的参考。
- [KrsMt-0113/XMU-Rollcall-Bot](https://github.com/KrsMt-0113/XMU-Rollcall-Bot)、[dangzitou/xmu-rollcall-bot](https://github.com/dangzitou/xmu-rollcall-bot)：厦大畅课接口参考。
- [KrsMt-0113/xmulogin](https://github.com/KrsMt-0113/xmulogin)：厦大统一身份认证参考。

## 许可与说明

本项目采用 [MIT License](LICENSE)。

这是非官方客户端，与厦门大学及畅课官方无隶属关系。请遵守学校规定，确认签到内容与位置真实有效。自动签到默认关闭，需要为当前账号主动配置。
