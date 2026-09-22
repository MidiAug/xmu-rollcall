# xmu-rollcall

厦门大学数字化教学平台（TronClass / `lnt.xmu.edu.cn`）**多端签到客户端**，技术栈为 **Flutter**（Android / iOS / Windows / macOS / Linux 同仓）。

> 当前阶段：**Phase 1–2 实现中** — 自适应壳、混合主题、WebView/Cookie 登录、签到列表与数字/雷达应答、可配置监控轮询已落地；真网验收见 ACCEPTANCE。

## 目标（摘要）

- 统一身份认证登录数字化教学平台
- 监控进行中的签到任务（数字 / 雷达；二维码 Phase 3）
- 桌面侧栏 + 移动底栏；协议层与 UI 分离
- 默认可信客户端行为（稳定 deviceId、轮询 ≥ 15s + jitter）

请遵守学校规定与平台服务条款；签到提交默认需使用者确认，使用者对提交内容的真实性负责。

## 文档入口（SPC）

| 类型 | 路径 |
|------|------|
| 规格 SPEC | [docs/spec/SPEC.md](./docs/spec/SPEC.md) |
| 验收 | [docs/spec/ACCEPTANCE.md](./docs/spec/ACCEPTANCE.md) |
| 路线图 | [docs/spec/ROADMAP.md](./docs/spec/ROADMAP.md) |
| 架构 | [docs/ARCHITECTURE.md](./docs/ARCHITECTURE.md) |
| 登录 ADR | [docs/decisions/ADR-002-login.md](./docs/decisions/ADR-002-login.md) |
| 可信客户端 | [docs/knowledge-base/01-client-trust-and-automation-signals.md](./docs/knowledge-base/01-client-trust-and-automation-signals.md) |

## 常用命令

```powershell
cd D:\Project\_My\xmu-rollcall
flutter pub get
flutter run -d windows   # 或 android
flutter test
flutter analyze lib test
```

## 目录结构

```
lib/
  app/           # MaterialApp、AdaptiveShell
  core/          # theme / network / storage / identity
  features/      # auth / rollcall / monitor / history / settings
  platform/      # Phase 3 通知/托盘占位
```

## 登录说明

- **Android / iOS / macOS**：内嵌 WebView 走 IDS OAuth（ADR-002）
- **Windows / Linux**：打开系统浏览器 + 粘贴 `lnt.xmu.edu.cn` Cookie（同一会话存储）

## 状态

| Phase | 内容 | 状态 |
|-------|------|------|
| 0 | 文档 / reference / 脚手架 | ✅ |
| 1 | 壳 + 主题 + 登录会话 | 🔄 待真网 AC |
| 2 | 签到 + 监控轮询 | 🔄 待真网 AC |
| 3 | 通知 / 托盘 / 二维码 | ❌ |
