# xmu-rollcall

厦门大学数字化教学平台（TronClass / `lnt.xmu.edu.cn`）**多端签到客户端**，技术栈为 **Flutter**（Android / iOS / Windows / macOS / Linux 同仓）。

> 当前阶段：**SPC Phase 0→1 过渡** — 文档、Cursor 规则、reference 克隆与 Flutter 脚手架已就绪；业务功能未实现。

## 目标（摘要）

- 统一身份认证登录数字化教学平台
- 监控进行中的签到任务（数字 / 雷达 / 二维码等）
- 桌面端与移动端同一套业务层；平台差异放在 `lib/platform/`
- 协议以开源参考 + 官方接口行为为准，见 `reference/` 与 `docs/research/`

请遵守学校规定与平台服务条款；默认以**本人到课、本人操作**为前提（见 `.cursor/rules/00-project.mdc`）。

## 文档入口（SPC）

| 类型 | 路径 |
|------|------|
| 文档索引 | [docs/README.md](./docs/README.md) |
| 愿景 | [docs/spec/VISION.md](./docs/spec/VISION.md) |
| **规格 SPEC** | [docs/spec/SPEC.md](./docs/spec/SPEC.md) |
| **验收** | [docs/spec/ACCEPTANCE.md](./docs/spec/ACCEPTANCE.md) |
| **路线图** | [docs/spec/ROADMAP.md](./docs/spec/ROADMAP.md) |
| 调研 | [docs/research/INDEX.md](./docs/research/INDEX.md) |
| 参考克隆 | [reference/README.md](./reference/README.md) |

## Cursor 规则

`.cursor/rules/*.mdc` — 请以本目录为 Cursor 工作区根打开。约定对齐 DeepTale（Flutter）+ cursor-desktop-bridge（SPC）。

## 常用命令

```powershell
$root = 'D:\Project\_My\xmu-rollcall'
cd $root

flutter pub get
flutter run -d windows   # 或 android 等
flutter test

# 克隆 / 补全参考仓
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\bootstrap-reference-repos.ps1 -NoProxy
# 若直连失败：
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\bootstrap-reference-repos.ps1 -ProxyPort 10808
```

## 目录结构

```
xmu-rollcall/
├── .cursor/rules/       # Cursor MDC
├── docs/                # Spec / 调研 / ADR / 台账
├── reference/           # 外部开源对照（gitignore）
├── scripts/
├── lib/                 # Flutter（现为默认计数器脚手架）
├── android|ios|windows|macos|linux/
└── test/
```

## 平台范围

**只做畅课 / TronClass**（`lnt.xmu.edu.cn`、`c-mobile.xmu.edu.cn`）。  
旧教务签到（含本机 `JiaoWuCheckin`）已过期，**不参考、不实现**。详见 [docs/research/02-platform-scope.md](./docs/research/02-platform-scope.md)。

扩展开源与 **防机器痕迹** 知识库：

- [docs/research/03-extended-landscape.md](./docs/research/03-extended-landscape.md)
- [docs/knowledge-base/01-client-trust-and-automation-signals.md](./docs/knowledge-base/01-client-trust-and-automation-signals.md)

## 本机相关材料

| 材料 | 路径 | 备注 |
|------|------|------|
| 畅课 API 手记 | `D:\Project\XMUSignIn\` | 可用 |
| 旧教务签到 uni-app | `D:\Project\_My\JiaoWuCheckin\` | **排除** |

## 状态

| Phase | 内容 | 状态 |
|-------|------|------|
| 0 | README / MDC / SPEC / reference | 基本完成 |
| 0.5 | `flutter create` 多端脚手架 | 完成 |
| 1 | 登录会话 | 未开始 |
| 2 | 签到监控 + 数字/雷达 | 未开始 |
| 3 | UX / 推送 / 二维码 | 未开始 |
