# xmu-rollcall

厦门大学数字化教学平台（TronClass / `lnt.xmu.edu.cn`）**多端签到客户端**，技术栈为 **Flutter**（Android / iOS / Windows / macOS / Linux 同仓）。

> 当前阶段：**Phase 1–2 实现中** — 自适应壳、登录会话、签到列表与数字/雷达应答、可配置监控轮询已落地。

## 目标（摘要）

- 统一身份认证登录数字化教学平台
- 监控进行中的签到任务（数字 / 雷达；二维码进行中）
- 桌面侧栏 + 移动底栏
- 默认可信客户端行为（稳定 deviceId、轮询带间隔与抖动）

请遵守学校规定与平台服务条款；签到提交默认需使用者确认，使用者对提交内容的真实性负责。本项目为非官方客户端，与学校 / 畅课官方无关。

## 致谢

架构与 Flutter 客户端形态上，参考借鉴了 [@wilinz](https://github.com/wilinz) 的 [tronclass_plus](https://github.com/wilinz/tronclass_plus) 很多——分层、网络层、WebView Cookie、雷达选点等对照帮了大忙；本仓协议与登录仍按厦大畅课（`lnt.xmu.edu.cn` + IDS）自研，并非对方 fork。感谢开源。

厦大畅课协议与登录另对照过 [KrsMt-0113/XMU-Rollcall-Bot](https://github.com/KrsMt-0113/XMU-Rollcall-Bot)、[dangzitou/xmu-rollcall-bot](https://github.com/dangzitou/xmu-rollcall-bot)、[KrsMt-0113/xmulogin](https://github.com/KrsMt-0113/xmulogin) 等。

## 使用（开发运行）

```powershell
git clone <your-fork-or-url> xmu-rollcall
cd xmu-rollcall
flutter pub get
flutter run -d windows   # 或 android
```

## 导出安装包

产物在 `dist/`：

```powershell
# Android APK
powershell -ExecutionPolicy Bypass -File scripts\package-android.ps1

# Windows NSIS 安装包（current-user → %LOCALAPPDATA%\Programs\xmu-rollcall）
powershell -ExecutionPolicy Bypass -File scripts\package-windows.ps1

# 两端一起
powershell -ExecutionPolicy Bypass -File scripts\package-all.ps1
```

Windows 使用 **NSIS**（与 `xmu-sports` 同族），双击 `*-windows-setup.exe` 即可，**不需要** MSIX 发布者证书。脚本会在缺少 `makensis` 时从 NuGet 拉便携 NSIS 到 `.tools/`。

## 登录说明

- **Android / iOS / macOS**：应用内打开统一身份认证登录
- **Windows / Linux**：用系统浏览器登录后，将 `lnt.xmu.edu.cn` 的 Cookie 粘贴回应用

## 状态

| Phase | 内容 | 状态 |
|-------|------|------|
| 1 | 壳 + 主题 + 登录会话 | 进行中 |
| 2 | 签到 + 监控轮询 | 进行中 |
| 3 | 托盘 / 关窗 / 发现通知 + 二维码 | 部分完成 |
