# xmu-rollcall

厦门大学数字化教学平台（TronClass / `lnt.xmu.edu.cn`）**多端签到客户端**，技术栈为 **Flutter**（Android / iOS / Windows / macOS / Linux 同仓）。

> 当前阶段：**Phase 1–2 实现中** — 自适应壳、混合主题、WebView/Cookie 登录、签到列表与数字/雷达应答、可配置监控轮询已落地；真网验收见 ACCEPTANCE。

## 目标（摘要）

- 统一身份认证登录数字化教学平台
- 监控进行中的签到任务（数字 / 雷达；二维码 Phase 3）
- 桌面侧栏 + 移动底栏；协议层与 UI 分离
- 默认可信客户端行为（稳定 deviceId、轮询 ≥ 15s + jitter）

请遵守学校规定与平台服务条款；签到提交默认需使用者确认，使用者对提交内容的真实性负责。本项目为非官方客户端，与学校 / 畅课官方无关。

## 致谢

架构与 Flutter 客户端形态上，参考借鉴了 [@wilinz](https://github.com/wilinz) 的 [tronclass_plus](https://github.com/wilinz/tronclass_plus) 很多——分层、`dio`、WebView Cookie、雷达选点等对照帮了大忙；本仓协议与登录仍按厦大畅课（`lnt.xmu.edu.cn` + IDS）自研，并非对方 fork。感谢开源。

厦大畅课协议与登录另对照过 [KrsMt-0113/XMU-Rollcall-Bot](https://github.com/KrsMt-0113/XMU-Rollcall-Bot)、[dangzitou/xmu-rollcall-bot](https://github.com/dangzitou/xmu-rollcall-bot)、[KrsMt-0113/xmulogin](https://github.com/KrsMt-0113/xmulogin) 等，详见 `reference/README.md`。

## 常用命令

```powershell
git clone <your-fork-or-url> xmu-rollcall
cd xmu-rollcall
flutter pub get
flutter run -d windows   # 或 android
flutter test
flutter analyze lib test
```

## 导出安装包（本机）

产物在 `dist/`（已 gitignore）：

```powershell
# Android APK
powershell -ExecutionPolicy Bypass -File scripts\package-android.ps1

# Windows MSIX（需本机可 `flutter build windows`；首次安装可能要信任测试证书）
powershell -ExecutionPolicy Bypass -File scripts\package-windows.ps1

# 两端一起
powershell -ExecutionPolicy Bypass -File scripts\package-all.ps1
```

## 目录结构

```
lib/
  app/           # MaterialApp、AdaptiveShell
  core/          # theme / network / storage / identity
  features/      # auth / rollcall / monitor / history / settings
  platform/      # 桌面关窗三态 / 托盘 / 发现通知
```

## 登录说明

- **Android / iOS / macOS**：内嵌 WebView 走 IDS OAuth
- **Windows / Linux**：打开系统浏览器 + 粘贴 `lnt.xmu.edu.cn` Cookie（同一会话存储）

## 开发备注

- `docs/`：规格 / 调研 / 抓包等**仅本机**，不入公开 git（开发过程材料）。
- `.cursor/rules/`：给 Cursor 代理用的仓内约定，可选读。
- `reference/`：对照克隆默认 gitignore；见 [reference/README.md](./reference/README.md)。

## 状态

| Phase | 内容 | 状态 |
|-------|------|------|
| 0 | 脚手架 / 对照材料 | ✅ |
| 1 | 壳 + 主题 + 登录会话 | 🔄 待真网验收 |
| 2 | 签到 + 监控轮询 | 🔄 待真网验收 |
| 3 | 托盘/关窗/发现通知 + 二维码 | 🔄 托盘切片已合；QR 待勾 |
