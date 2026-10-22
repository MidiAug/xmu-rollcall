# 厦大签到

面向厦门大学畅课（TronClass）的轻量多端客户端，用于查看课堂签到、作业和本学期课表。

基于 Flutter 开发，手机使用底部导航，电脑使用侧栏和托盘。

## 功能

- **课堂签到**：查看数字、雷达和二维码签到，支持数字码复制、位置确认和扫码提交。
- **签到记录**：按课程、状态、类型和最近 7 天 / 30 天筛选，显示各选项对应的记录数量。
- **作业**：按进行中、已截止分组，查看个人提交和批改状态；助教、教师课程独立展示。
- **本学期课表**：按当前账号展示本学期课程，避免扫描往年课程。
- **多身份协助**：导入、切换和管理协助身份，各身份的会话与缓存相互隔离。
- **检测与提醒**：支持 Android 后台提醒、Windows 系统通知和托盘操作；数字自动签到需主动开启。
- **本机缓存**：先显示已有数据，再按需要更新；网络失败时尽量保留上次内容。

签到卡片会在对应课堂的课前、课后各 25 分钟内恢复上次状态，并在进入后重新确认。作业页保留跨页面缓存，自动检查有节流，完整课程作业按课后、截止或待办变化更新。

## 平台

| 平台 | 当前验证情况 |
| --- | --- |
| Android | 已构建并进行过真机检查，支持相机扫码和后台提醒 |
| Windows | 已构建，支持侧栏、桌面通知和托盘，已检查宽屏布局 |
| iOS / macOS / Linux | 保留对应工程，尚未完成完整实机验收 |

## 从源码运行

准备 Flutter SDK（附带 Dart 3.12 或更高版本）和目标平台的开发工具。

```powershell
git clone https://github.com/MidiAug/xmu-rollcall.git
cd xmu-rollcall
flutter pub get

# 查看可用设备
flutter devices

# 运行并选择设备
flutter run

# Windows
flutter run -d windows
```

Android 使用学校统一身份认证账号登录；遇到验证码时按页面提示处理。使用雷达签到前需要确认位置，相机扫码需要授予相机权限。

## 构建与更新

```powershell
# Android APK
flutter build apk --release

# Windows
flutter build windows --release
```

项目也提供打包脚本，产物保存在 `dist/`：

```powershell
# Android
powershell -ExecutionPolicy Bypass -File scripts/package-android.ps1

# Windows NSIS 安装包
powershell -ExecutionPolicy Bypass -File scripts/package-windows.ps1
```

Windows 打包需要 Visual Studio 的 C++ 桌面开发工具和 NSIS；脚本可在缺少 NSIS 时下载便携工具。

给已连接的手机覆盖安装时，可使用下面的脚本保留登录和设置：

```powershell
powershell -ExecutionPolicy Bypass -File scripts/install-phone.ps1 -Mode release
```

更新时请沿用相同签名和构建模式。

## 测试

```powershell
flutter analyze
flutter test
```

真实平台的集成检查需要单独配置账号与设备；普通测试使用模拟数据。源码、测试、必要资源和构建配置纳入版本管理，个人开发文档、Agent 配置、参考仓库、抓包和构建产物保留在本机。

## 数据与使用

账号凭据使用系统安全存储。课表、作业与签到缓存保存在本机，可在“我的 → 数据与诊断”清理。诊断日志经过脱敏处理，分享前仍建议自行核对内容。

本项目是非官方客户端，与学校及畅课官方无隶属关系。请遵守学校规定，确认签到内容与位置真实有效。自动签到默认关闭，需要使用者为当前账号主动配置。

## 致谢

- [wilinz/tronclass_plus](https://github.com/wilinz/tronclass_plus)：Flutter 客户端分层、网络与位置交互的参考。
- [KrsMt-0113/XMU-Rollcall-Bot](https://github.com/KrsMt-0113/XMU-Rollcall-Bot)、[dangzitou/xmu-rollcall-bot](https://github.com/dangzitou/xmu-rollcall-bot)：厦大畅课接口参考。
- [KrsMt-0113/xmulogin](https://github.com/KrsMt-0113/xmulogin)：厦大统一身份认证参考。

本项目按厦大畅课环境实现，并非上述项目的 fork。
