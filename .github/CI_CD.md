# CI/CD 与发布

## 日常开发

锁文件当前使用 `https://pub.flutter-io.cn`。复用的 Flutter 安装动作在严格安装步骤显式使用相同的 `PUB_HOSTED_URL`，避免云端默认源与锁文件不同而重新解析依赖；版本和内容哈希仍由 `--enforce-lockfile` 验证。

- PR → `Flutter checks`：校验工作流、测试产物验证脚本，在 Linux / Windows 执行锁文件安装、静态分析、全部 Flutter 测试（包括 mock integration）。真实校园网络探测保持关闭。
- Windows 另运行 `scripts/test-windows-notification-registration.ps1`：以隔离快捷方式核验通知应用身份、激活标识、图标和入口归属，不启动应用或修改用户入口；此检查不代表系统横幅图标或退出后通知点击已经通过。
- 合入 `main` → 同样检查通过后，自动构建 Android 测试 APK、Windows x64 NSIS 安装器和便携 ZIP。到该次 Actions 运行的 Artifacts 下载，保留 7 天；不会自动安装。
- 连续推送会取消同一分支或 PR 的旧检查，避免重复占用构建资源。手动运行 `Flutter checks` 可选择待验证分支，在合入 `main` 前也能生成测试包。

Android 测试包使用独立应用 ID `cn.edu.xmu.rollcall.xmu_rollcall.preview` 和临时开发签名，可与正式版并存，不读取正式版登录数据。不同 runner 的测试包签名可能不同，不能保证测试包之间覆盖升级。Windows 测试包与正式版使用同一安装位置，仅在主动安装后替换程序。

## 配置 Android 固定签名（首次）

在仓库 **Settings → Secrets and variables → Actions → Repository secrets** 配置：

| Secret | 内容 |
| --- | --- |
| `ANDROID_KEYSTORE_BASE64` | 现有固定签名 keystore 的 Base64 内容 |
| `ANDROID_KEYSTORE_PASSWORD` | keystore 密码 |
| `ANDROID_KEY_ALIAS` | 签名 alias |
| `ANDROID_KEY_PASSWORD` | 签名 key 密码 |

Base64 仅为传输编码，不是加密。不要提交 keystore、密码或编码结果。工作流仅在 Android 正式构建步骤解码至 runner 临时目录，构建后清理。PR 和测试包不接收签名 secrets；测试 job 不接收任何签名凭据。

Android 从早期版本沿用同一开发证书以保持覆盖升级兼容；正式 CI 将该密钥作为固定签名配置，禁止临时生成替代密钥。`manifest` 的 `release` 表示使用固定密钥的正式构建，不表示更换了证书或获得第三方认证。首次配置前必须用 Android SDK 的 `apksigner verify --print-certs <现有APK>` 核对证书与原有密钥；私钥仅存本机受保护目录及 GitHub Actions 加密 secrets。离线备份固定 keystore 与密码。

本地正式签名可设置 `XMU_ANDROID_KEYSTORE_PATH`（绝对路径）、`XMU_ANDROID_KEYSTORE_PASSWORD`、`XMU_ANDROID_KEY_ALIAS`、`XMU_ANDROID_KEY_PASSWORD` 后执行：

```powershell
pwsh -File scripts/package-android.ps1 -RequireSigning
```

未加 `-RequireSigning` 的本机开发打包仍支持原有开发签名；CI 的版本发布始终加此参数，缺项时禁止回退。

## 版本与构建编号

日常提交不递增应用版本，修复和功能先汇总到 `Unreleased`，需要向用户交付一批变化时再确定正式版本。修复批次递增 PATCH（如 0.1.3 → 0.1.4），功能批次递增 MINOR（如 0.1.9 → 0.2.0）；MAJOR 留给需要迁移或存在兼容性变化的里程碑。当前 0.x 阶段仍按这套应用交付约定组织。各段是整数，0.1.9 后可用 0.1.10，不是小数位。

`X.Y.Z` 是用户可见版本，`+BUILD` 对应 Android 的递增 `versionCode`；每次正式分发新包都必须增加 BUILD，日常编辑不需要增加。测试包用提交与 Actions 运行编号定位，Android preview 与正式版独立安装。已经发布的版本、标签和安装包不可回填修改；后续变化进入下一批，不因为每一处小改动重新发版。

参考：[Semantic Versioning](https://semver.org/)、[Android 版本管理](https://developer.android.com/studio/publish/versioning)。

## 准备一个版本

1. 平时完成有意义的功能、修复或维护调整时，把面向用户或维护者的摘要加入根目录 `CHANGELOG.md` 的 `Unreleased`，按 Added / Changed / Fixed 等分类；同一变化可合并，不必每次保存代码都记一条。纯格式、无行为变化的小重构可不记，PR 中说明原因。
2. 发版前修改 `pubspec.yaml` 的 `version: X.Y.Z+BUILD`，递增版本和 Android build number；将本次条目移到对应的 `## [X.Y.Z] - YYYY-MM-DD` 下，并保留新的 `Unreleased` 区。代码与日志一起提交并合入 `main`。
3. 主分支 CI 通过后，在该提交创建并推送 `vX.Y.Z` 标签（例如源码 `0.1.2+3` 对应 `v0.1.2`）。标签必须指向 `main` 已包含的提交；不要移动已用标签。
4. `Release draft` 会验证标签、主分支归属、对应版本的非空 changelog 和签名配置，再重新运行同一套质量门禁、构建两端产物。缺少版本更新说明时，预检失败，不会用 `Unreleased` 或 Git 提交列表替代。
5. 验证两个 manifest 的完整版本（含 BUILD）、来源提交、签名模式、精确文件集合、大小及 SHA-256，并检查 ZIP 完整性后，把 changelog 对应版本的正文写入 **Release 草稿**。重试时同步刷新草稿正文；已经公开的 Release 不会被更新。
6. 在草稿下载并完成 Android 覆盖安装、Windows 安装/便携运行等设备验收，核对哈希后，手动发布。自动构建通过不等于真实登录、定位、通知和签到验收通过。

首个自动化版本应使用新版本号，不复用现有公开版本。Windows 产物目前没有 Authenticode 发布者签名。

发布资产共 6 个：APK、Windows 安装器、Windows ZIP、`manifest-android.json`、`manifest-windows.json`、`SHA256SUMS`。manifest 记录完整版本、源码 commit、平台、签名模式、文件大小及 SHA-256。Linux 可运行 `sha256sum --check SHA256SUMS`；Windows 可用 `Get-FileHash -Algorithm SHA256 <文件>` 比对。

## 应用内更新

「我的 → 关于」读取 `MidiAug/xmu-rollcall` 的 GitHub 最新公开稳定 Release；保存草稿、推送标签或发布预发布版本不会被提示为正式更新。每次新发版应递增 `X.Y.Z`，Android 的 `BUILD` 也必须大于旧版；不复用旧标签或替换已发布文件。

请通过本工作流生成并保留现有 6 个资产和精确名称。应用按平台清单核对版本、签名模式、大小、SHA-256，并选择 Android 正式 APK 或 Windows x64 setup EXE；GitHub 提供资产 digest 时还会比对。匿名 REST API 限流时只尝试一次 GitHub 的 latest/download 清单备用路径，保持相同平台、版本、大小和哈希检查，此时完整说明通过发布页查看。检查和下载不需要 GitHub 登录，不携带校园账号信息。网络异常、缺少清单或旧式发布时，可打开官方发布页手动下载。

Android 由系统交互安装，先检查包名、versionCode 与签名兼容；不兼容时提示联系维护者，不引导卸载。首次使用旧开发签名包的用户仍需要匹配的原签名密钥。Windows 用户确认后启动安装器并退出，安装器通过 `/UPDATEPID` 等待旧进程，按注册的安装位置更新；便携用户使用安装器会转为安装版。没有静默安装参数，Windows 仍可能显示系统发布者提示。

新功能不能回填到已安装旧版；首次需手动安装包含更新功能的版本。启动和回到前台会按需静默检查，同进程中成功结果缓存6小时、失败退避30分钟，合并并发请求；不在后台持续轮询。关于页和菜单共用检查状态，已确认的新版本显示“有更新”，网络失败保留上次已知新版，下一次成功结果可清除提示；手动检查可绕过时间间隔。下载期间离页取消未完成文件，共享检查可继续完成；完成文件在应用缓存中，安装前重新校验。本机模拟测试与构建不代替 Android 来源权限/覆盖安装、Windows 向导与重启验收。

## 失败与重试

- 任何检查或任一平台构建失败，均不生成 Release 草稿；缺签名在预检阶段立即失败。
- 修复 secrets 或临时构建故障后，重跑失败任务；也可手动运行 `Release draft` 并选择原版本标签。选择分支会被拒绝，源码变更应使用新版本标签。
- 重试只允许更新同标签的草稿。已公开 Release 拒绝替换文件。下载/上传故障可重跑草稿 job，避免重复编译。
- 草稿阶段有 `contents: write` 权限，其余工作流为 `contents: read`；所有 checkout 禁用持久凭据。第三方 Actions 固定到提交 SHA，Dependabot 每周提出更新 PR，不自动合并。

建议在仓库规则中保护 `main`，要求 `Workflow and delivery checks` 和 Linux / Windows Flutter 检查通过，再合并 PR；先在远端观察一次成功运行，按实际检查名称配置，避免配置不存在的门禁。仓库设置与正式发布应单独确认后启用。

## 本地验证自动化本身

```powershell
python -m unittest discover -s scripts/ci -p 'test_*.py' -v
python scripts/ci/changelog.py
actionlint
flutter pub get --enforce-lockfile
flutter analyze --no-pub
flutter test --no-pub
pwsh -File scripts/package-android.ps1 -Preview -NoPub
pwsh -File scripts/package-windows.ps1 -NoPub
```

产物校验脚本只依赖 Python 标准库，不需要安装额外包。

整理好版本条目后，可在本机预览将写入 Release 的正文：`python scripts/ci/changelog.py --tag vX.Y.Z`。根目录 `CHANGELOG.md` 是公开发布说明的来源；被 Git 忽略的 `docs/CHANGELOG.md` 继续用于本地详细开发记录。

若本机代理导致测试启动时出现 `Invalid WebSocket upgrade request`，在当前终端为回环地址设置 `$env:NO_PROXY='localhost,127.0.0.1,::1'` 后重跑；不需要开启真实校园网测试。

Flutter SDK 版本集中在 `.github/actions/setup-flutter/action.yml`，质量检查与两端打包共用，更新 SDK 时同步本地开发版本。

参考：[GitHub 工作流复用](https://docs.github.com/en/actions/how-tos/reuse-automations/reuse-workflows)、[工作流安全](https://docs.github.com/en/actions/reference/security/secure-use)、[Flutter Android 签名](https://docs.flutter.dev/deployment/android)、[GitHub Release CLI](https://cli.github.com/manual/gh_release_create)。

## 更新网络与下载加速

检查网络设置有限时：API 7秒、网络检查总20秒，控制器25秒兜底。限流、连接/响应超时或5xx可改查GitHub官方latest/download清单。网络故障不会取消已确认更新，手动重试重新建立请求；诊断含update.check/http/download事件的关联ID、状态及耗时，不记录签名下载URL查询参数。

“我的 → 更新下载线路”默认官方，可主动选择备选节点或填写HTTPS节点首页，也可从说明弹窗进入。节点仅转发清单中已确认的公开安装包；版本/大小/SHA-256清单只从GitHub取得。选择的节点网络失败或404时尝试官方一次；安装包校验失败直接停止，不回退跳过校验。下载中保存新线路会取消旧下载、清理部分文件并重新下载。备选节点与目录来自用户指定的[GitHub Proxy](https://github.akams.cn/)，服务可用性随网络变化；不会后台批量测速或自动把账号请求发给节点。
