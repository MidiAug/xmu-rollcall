<div align="center">

<img src="assets/icon/app_icon.png" width="88" alt="厦大签到图标" />

# 厦大签到

**上课看签到，下课看作业。**

一个给厦门大学畅课（TronClass）用的小客户端。手机随手查看，电脑也能用。

[![Flutter](https://img.shields.io/badge/Flutter-3.44-02569B?logo=flutter&logoColor=white)](https://flutter.dev/)
[![Platforms](https://img.shields.io/badge/平台-Android%20%2F%20Windows-5356FF)](#界面预览)
[![Checks](https://github.com/MidiAug/xmu-rollcall/actions/workflows/checks.yml/badge.svg)](https://github.com/MidiAug/xmu-rollcall/actions/workflows/checks.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-64748B)](LICENSE)

[看看界面](#界面预览) / [有什么功能](#日常会用到的) / [下载安装](#下载安装) / [运行起来](#运行起来) / [反馈问题](https://github.com/MidiAug/xmu-rollcall/issues)

</div>

## 界面预览

用现有 Flutter 页面和演示数据渲染，展示手机与 Windows 布局；截图中的姓名、课程和作业状态均为虚构示例。

### Android

先看正在签到的这门课。数字码、已签到人数和刷新倒计时放在一起；完成签到后，数字码仍会保留。每张图只展示一门正在签到的课程。

<table>
  <tr>
    <th>待签到</th>
    <th>已签到（深色模式）</th>
    <th>课后看作业</th>
  </tr>
  <tr>
    <td align="center"><img src="assets/screenshots/android-rollcall.png" width="240" alt="Android 单门课程待签到演示，显示数字码与已签到人数" /></td>
    <td align="center"><img src="assets/screenshots/android-rollcall-dark.png" width="240" alt="同一门课签到后的深色界面，保留数字码并隐藏人数" /></td>
    <td align="center"><img src="assets/screenshots/android-homework.png" width="240" alt="Android 作业页，展示进行中与已截止作业" /></td>
  </tr>
</table>

### Windows

电脑上也能直接查看当前签到，使用侧栏切换页面。支持托盘驻留、系统通知和桌面二维码识别。

![Windows 单门课程正在签到演示](assets/screenshots/windows-rollcall.png)

<details>
<summary>再看看作业与签到记录</summary>

| 作业一眼看清 | 签到记录慢慢查 |
| :---: | :---: |
| ![Windows 作业页](assets/screenshots/windows-homework.png) | ![Windows 签到记录页](assets/screenshots/windows-history.png) |

</details>

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

## 下载安装

[v0.1.0 发布页](https://github.com/MidiAug/xmu-rollcall/releases/tag/v0.1.0)

| 平台 | 下载 | 怎么用 |
| --- | --- | --- |
| Android | [APK 安装包](https://github.com/MidiAug/xmu-rollcall/releases/download/v0.1.0/xmu-rollcall-0.1.0-android.apk) | 下载后在手机上安装。 |
| Windows x64 | [安装程序](https://github.com/MidiAug/xmu-rollcall/releases/download/v0.1.0/xmu-rollcall-0.1.0-windows-x64-setup.exe) | 运行安装程序，按提示安装。 |
| Windows x64 | [便携版 ZIP](https://github.com/MidiAug/xmu-rollcall/releases/download/v0.1.0/xmu-rollcall-0.1.0-windows-x64.zip) | 完整解压后运行 `xmu_rollcall.exe`，请保留同目录的 DLL 和 `data` 文件夹。 |

Android 当前沿用项目开发签名；Windows 安装程序尚无发布者数字签名。覆盖更新需使用同一 Android 签名。

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

# Windows NSIS 安装包与便携 ZIP
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

普通测试使用模拟数据；真实账号、设备权限和后台行为需要单独做实机检查。GitHub Actions 在 Windows 和 Linux 上运行静态分析、单元/组件及模拟会话集成测试；主分支通过后自动生成 Android 测试 APK 和 Windows 安装包/便携 ZIP。版本标签经过正式签名与产物校验后生成 Release 草稿，更新说明自动取自 [CHANGELOG.md](CHANGELOG.md) 对应版本，确认设备验收后手动发布。详见 [CI/CD 与签名配置](.github/CI_CD.md)。

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
